param(
  [string]$InputCsv = "data/CHECKPOINT_TALK_202508.csv",
  [string]$OutputCsv = "data/CHECKPOINT_TALK_202508.csv"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName Microsoft.VisualBasic

function Normalize-Text([string]$text) {
  if ([string]::IsNullOrWhiteSpace($text)) { return "" }
  $t = $text -replace "\r\n|\n|\r", " "
  $t = $t -replace "\s+", " "
  return $t.Trim()
}

function Escape-Csv([string]$text) {
  if ($null -eq $text) { return "" }
  $needsQuote = $text.Contains(",") -or $text.Contains("`"") -or $text.Contains("`r") -or $text.Contains("`n")
  if ($needsQuote) {
    return '"' + ($text -replace '"', '""') + '"'
  }
  return $text
}

if (-not (Test-Path $InputCsv)) {
  throw "Input CSV not found: $InputCsv"
}

$parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new($InputCsv, [System.Text.Encoding]::UTF8)
$parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
$parser.SetDelimiters(",")
$parser.HasFieldsEnclosedInQuotes = $true
$parser.TrimWhiteSpace = $false

$rows = New-Object System.Collections.Generic.List[object]
while (-not $parser.EndOfData) {
  $fields = $parser.ReadFields()
  $rows.Add(@($fields)) | Out-Null
}
$parser.Close()

if ($rows.Count -lt 2) {
  throw "Unexpected CSV format: header rows are missing."
}

$titleRow = @($rows[0])
$headerRow = @($rows[1])

$idxTitle = 1
$idxNo = 0
$idxQ1 = $headerRow.Count - 3
$idxQ2 = $headerRow.Count - 2
$idxQ3 = $headerRow.Count - 1
if ($idxQ1 -lt 0 -or $headerRow.Count -lt 10) {
  throw "Unexpected header layout. Could not locate question columns."
}

$seenByTitle = @{}
$currentTitle = ""
$deduped = 0

$outLines = New-Object System.Collections.Generic.List[string]
$outLines.Add(($titleRow | ForEach-Object { Escape-Csv $_ }) -join ",") | Out-Null
$outLines.Add(($headerRow | ForEach-Object { Escape-Csv $_ }) -join ",") | Out-Null

for ($r = 2; $r -lt $rows.Count; $r++) {
  $vals = @($rows[$r])
  while ($vals.Count -le $idxQ3) { $vals += "" }

  $noVal = Normalize-Text ([string]$vals[$idxNo])
  $title = Normalize-Text ([string]$vals[$idxTitle])
  if ($title -and $noVal -match '^\d+$') { $currentTitle = $title }
  if (-not $currentTitle) {
    $outLines.Add(($vals | ForEach-Object { Escape-Csv ([string]$_) }) -join ",") | Out-Null
    continue
  }

  if (-not $seenByTitle.ContainsKey($currentTitle)) {
    $seenByTitle[$currentTitle] = New-Object System.Collections.Generic.HashSet[string]
  }
  $seen = $seenByTitle[$currentTitle]

  foreach ($idx in @($idxQ1, $idxQ2, $idxQ3)) {
    $q = Normalize-Text ([string]$vals[$idx])
    if (-not $q) { continue }
    if ($seen.Contains($q)) {
      $vals[$idx] = ""
      $deduped++
    } else {
      [void]$seen.Add($q)
    }
  }

  $outLines.Add(($vals | ForEach-Object { Escape-Csv ([string]$_) }) -join ",") | Out-Null
}

Set-Content -Path $OutputCsv -Value $outLines -Encoding UTF8
Write-Host "Updated CSV: $OutputCsv"
Write-Host "Deduped questions: $deduped"
