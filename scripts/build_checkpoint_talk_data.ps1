param(
  [string]$InputCsv = "data/CHECKPOINT_TALK_202508.csv",
  [string]$MappingCsv = "data/Domain_Code_Table.csv",
  [string]$AliasCsv = "data/checkpoint_alias_map.csv",
  [string]$OutputJsonl = "data/checkpoint_talk_data.jsonl"
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
  $t = Normalize-Text $text
  if (-not $t) { return "" }
  return ($t -replace "[^\p{L}\p{Nd}]", "").ToUpperInvariant()
}

if (-not (Test-Path $InputCsv)) {
  throw "Input file not found: $InputCsv"
}
if (-not (Test-Path $MappingCsv)) {
  throw "Mapping file not found: $MappingCsv"
}

# Mapping file header is Korean; parse with explicit ASCII headers for stability.
$mappingRows = Get-Content -Encoding UTF8 $MappingCsv |
  Select-Object -Skip 1 |
  ConvertFrom-Csv -Header checkpoint_code,checkpoint_name,domain_code,domain_name

$mapExact = @{}
$mapNorm = @{}
foreach ($m in $mappingRows) {
  $name = Normalize-Text $m.checkpoint_name
  if (-not $name) { continue }
  $val = [pscustomobject]@{
    topic_code = Normalize-Text $m.checkpoint_code
    domain_code = Normalize-Text $m.domain_code
    checkpoint_title = $name
  }
  if (-not $mapExact.ContainsKey($name)) { $mapExact[$name] = $val }
  $k = Normalize-Key $name
  if ($k -and -not $mapNorm.ContainsKey($k)) { $mapNorm[$k] = $val }
}

$aliasMap = @{}
if (Test-Path $AliasCsv) {
  $aliasRows = Import-Csv -Path $AliasCsv
  foreach ($a in $aliasRows) {
    $src = Normalize-Text $a.source_title
    $target = Normalize-Text $a.target_checkpoint_name
    if (-not $src -or -not $target) { continue }

    $mappedTarget = $null
    if ($mapExact.ContainsKey($target)) {
      $mappedTarget = $mapExact[$target]
    } else {
      $normTarget = Normalize-Key $target
      if ($normTarget -and $mapNorm.ContainsKey($normTarget)) {
        $mappedTarget = $mapNorm[$normTarget]
      }
    }

    if ($mappedTarget) {
      $aliasMap[$src] = $mappedTarget
      $normSrc = Normalize-Key $src
      if ($normSrc) { $aliasMap[$normSrc] = $mappedTarget }
    }
  }
}

$parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new($InputCsv, [System.Text.Encoding]::UTF8)
$parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
$parser.SetDelimiters(",")
$parser.HasFieldsEnclosedInQuotes = $true
$parser.TrimWhiteSpace = $false

# Row 1: section title, Row 2: header
if (-not $parser.EndOfData) { [void]$parser.ReadFields() }
if ($parser.EndOfData) { throw "Unexpected format: missing header row in $InputCsv" }
[void]$parser.ReadFields()

$currentTitle = ""
$records = New-Object System.Collections.Generic.List[object]
$id = 0

while (-not $parser.EndOfData) {
  $fields = $parser.ReadFields()
  if (-not $fields) { continue }

  $vals = @($fields)
  while ($vals.Count -lt 5) { $vals += "" }

  $no = Normalize-Text $vals[0]
  $title = Normalize-Text $vals[1]
  $checkPoint = Normalize-Text $vals[2]
  $talk = Normalize-Text $vals[4]

  if ($title) { $currentTitle = $title }
  if (-not $currentTitle) { continue }
  if (-not $checkPoint -and -not $talk) { continue }

  $mapped = $null
  if ($aliasMap.ContainsKey($currentTitle)) {
    $mapped = $aliasMap[$currentTitle]
  } elseif ($mapExact.ContainsKey($currentTitle)) {
    $mapped = $mapExact[$currentTitle]
  } else {
    $normTitle = Normalize-Key $currentTitle
    if ($normTitle -and $aliasMap.ContainsKey($normTitle)) {
      $mapped = $aliasMap[$normTitle]
    } elseif ($normTitle -and $mapNorm.ContainsKey($normTitle)) {
      $mapped = $mapNorm[$normTitle]
    }
  }

  $id++
  $records.Add([pscustomobject]@{
    id = $id
    no = $no
    checkpoint_title = $currentTitle
    checkpoint = $checkPoint
    talk = $talk
    topic_code = if ($mapped) { $mapped.topic_code } else { "UNKNOWN" }
    domain_code = if ($mapped) { $mapped.domain_code } else { "UNKNOWN" }
  }) | Out-Null
}

$parser.Close()

$records |
  ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 4 } |
  Set-Content -Encoding UTF8 $OutputJsonl

$total = $records.Count
$resolved = ($records | Where-Object { $_.topic_code -ne "UNKNOWN" }).Count
$unresolved = $total - $resolved

Write-Host "Generated: $OutputJsonl"
Write-Host "Total records: $total"
Write-Host "Mapped records: $resolved"
Write-Host "Unmapped records: $unresolved"
