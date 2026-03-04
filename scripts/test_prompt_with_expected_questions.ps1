param(
  [string]$PromptPath = "data/checkpoint_prompt.json",
  [string]$TalkCsvPath = "data/CHECKPOINT_TALK_202508.csv",
  [string]$MappingCsvPath = "data/Domain_Code_Table.csv",
  [string]$AliasCsvPath = "data/checkpoint_alias_map.csv",
  [int]$MaxRows = 120
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName Microsoft.VisualBasic

function Normalize-Text([string]$text) {
  if ([string]::IsNullOrWhiteSpace($text)) { return "" }
  $t = $text -replace "\r\n|\n|\r", " "
  $t = $t -replace "\s+", " "
  return $t.Trim()
}

function Normalize-Key([string]$text) {
  $n = Normalize-Text $text
  if (-not $n) { return "" }
  return ($n -replace "[^\p{L}\p{Nd}]", "").ToUpperInvariant()
}

function Get-PromptTemplate([string]$path) {
  $obj = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
  if ($null -ne $obj.prompt) { return [string]$obj.prompt }
  if ($null -ne $obj.prompt_lines) { return ($obj.prompt_lines -join "`n") }
  throw "Prompt file must contain prompt or prompt_lines."
}

if (-not (Test-Path $PromptPath)) { throw "Prompt not found: $PromptPath" }
if (-not (Test-Path $TalkCsvPath)) { throw "Talk CSV not found: $TalkCsvPath" }
if (-not (Test-Path $MappingCsvPath)) { throw "Mapping CSV not found: $MappingCsvPath" }

$promptTemplate = Get-PromptTemplate $PromptPath

$mappingRows = Get-Content -Encoding Default $MappingCsvPath |
  Select-Object -Skip 1 |
  ConvertFrom-Csv -Header checkpoint_code,checkpoint_name,domain_code,domain_name

$mapExact = @{}
$mapNorm = @{}
foreach ($m in $mappingRows) {
  $name = Normalize-Text $m.checkpoint_name
  if (-not $name) { continue }
  $meta = [pscustomobject]@{
    checkpoint_code = $m.checkpoint_code
    checkpoint_name = $name
    domain_code = $m.domain_code
  }
  if (-not $mapExact.ContainsKey($name)) { $mapExact[$name] = $meta }
  $k = Normalize-Key $name
  if ($k -and -not $mapNorm.ContainsKey($k)) { $mapNorm[$k] = $meta }
}

$aliasMap = @{}
if (Test-Path $AliasCsvPath) {
  $aliasRows = Import-Csv -Path $AliasCsvPath
  foreach ($a in $aliasRows) {
    $src = Normalize-Text $a.source_title
    $dst = Normalize-Text $a.target_checkpoint_name
    if (-not $src -or -not $dst) { continue }
    $mapped = $null
    if ($mapExact.ContainsKey($dst)) { $mapped = $mapExact[$dst] }
    if (-not $mapped) {
      $dk = Normalize-Key $dst
      if ($dk -and $mapNorm.ContainsKey($dk)) { $mapped = $mapNorm[$dk] }
    }
    if ($mapped) {
      $aliasMap[$src] = $mapped
      $sk = Normalize-Key $src
      if ($sk) { $aliasMap[$sk] = $mapped }
    }
  }
}

$allCheckpointData = ($mappingRows | ForEach-Object {
  "checkpoint_code=$($_.checkpoint_code), checkpoint_name=$($_.checkpoint_name), domain_code=$($_.domain_code)"
}) -join "`n"

$parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new($TalkCsvPath, [System.Text.Encoding]::UTF8)
$parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
$parser.SetDelimiters(",")
$parser.HasFieldsEnclosedInQuotes = $true
$parser.TrimWhiteSpace = $false

[void]$parser.ReadFields() # section row
$header = $parser.ReadFields()
if ($header.Count -lt 10) { throw "Unexpected talk CSV header layout." }

$idxNo = 0
$idxTitle = 1
$idxCheckpoint = 2
$idxTalk = 4
$idxQ1 = $header.Count - 3
$idxQ2 = $header.Count - 2
$idxQ3 = $header.Count - 1

$currentTitle = ""
$cases = New-Object System.Collections.Generic.List[object]

while (-not $parser.EndOfData) {
  $r = @($parser.ReadFields())
  while ($r.Count -le $idxQ3) { $r += "" }

  $noVal = Normalize-Text $r[$idxNo]
  $title = Normalize-Text $r[$idxTitle]
  $checkpoint = Normalize-Text $r[$idxCheckpoint]
  $talk = Normalize-Text $r[$idxTalk]
  if ($title -and $noVal -match '^\d+$') { $currentTitle = $title }
  if (-not $currentTitle) { continue }
  if (-not $checkpoint -and -not $talk) { continue }

  $meta = $null
  if ($aliasMap.ContainsKey($currentTitle)) {
    $meta = $aliasMap[$currentTitle]
  } elseif ($mapExact.ContainsKey($currentTitle)) {
    $meta = $mapExact[$currentTitle]
  } else {
    $nk = Normalize-Key $currentTitle
    if ($aliasMap.ContainsKey($nk)) { $meta = $aliasMap[$nk] }
    elseif ($mapNorm.ContainsKey($nk)) { $meta = $mapNorm[$nk] }
  }

  if (-not $meta) { continue }

  $domainText = "$($meta.domain_code), DOM002, DOM001"
  foreach ($qIdx in @($idxQ1, $idxQ2, $idxQ3)) {
    $q = Normalize-Text $r[$qIdx]
    if (-not $q) { continue }
    $cases.Add([pscustomobject]@{
      title = $currentTitle
      checkpoint = $checkpoint
      talk = $talk
      question = $q
      domain_text = $domainText
    }) | Out-Null
  }
}
$parser.Close()

if ($cases.Count -eq 0) { throw "No test cases found from 고객예상질문1~3." }

$total = 0
$pass = 0
$fail = 0
$samples = New-Object System.Collections.Generic.List[object]

foreach ($c in $cases | Select-Object -First $MaxRows) {
  $total++
  $rendered = $promptTemplate.
    Replace("{{USER_QUESTION}}", $c.question).
    Replace("{{LLM_ANSWER}}", $c.talk).
    Replace("{{DOMAIN_TEXT}}", $c.domain_text).
    Replace("{{CHECKPOINT_DATA}}", $allCheckpointData).
    Replace("{{CHECKPOINT_CONTENT_DATA}}", "checkpoint=$($c.checkpoint)").
    Replace("{{CHECKPOINT_TALK_DATA}}", "checkpoint=$($c.checkpoint), talk=$($c.talk)")

  $ok = ($rendered -notmatch "{{[A-Z_]+}}")
  if ($ok) { $pass++ } else { $fail++ }

  if ($samples.Count -lt 5) {
    $samples.Add([pscustomobject]@{
      title = $c.title
      question = $c.question
      result = if ($ok) { "PASS" } else { "FAIL" }
      length = $rendered.Length
    }) | Out-Null
  }
}

Write-Host "Prompt Test Result"
Write-Host "Total tested: $total"
Write-Host "Pass: $pass"
Write-Host "Fail: $fail"
Write-Host ""
$samples | Format-Table -AutoSize
