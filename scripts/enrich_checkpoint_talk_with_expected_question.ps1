param(
  [string]$InputCsv = "data/CHECKPOINT_TALK_202508.csv",
  [string]$OutputCsv = "data/CHECKPOINT_TALK_202508.csv",
  [string]$ColumnName = "__DEFAULT__"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName Microsoft.VisualBasic

function Normalize-Text([string]$text) {
  if ([string]::IsNullOrWhiteSpace($text)) { return "" }
  $t = $text -replace "\r\n|\n|\r", " "
  $t = $t -replace "\s+", " "
  return $t.Trim()
}

function Strip-Checkpoint([string]$text) {
  $t = Normalize-Text $text
  if (-not $t) { return "" }
  $t = $t -replace "^\d+([.-]\d+)?\.\s*", ""
  $t = $t -replace "^[-*]\s*", ""
  return $t
}

function Build-ExpectedQuestion([string]$title, [string]$checkpoint, [string]$talk) {
  $titleN = Normalize-Text $title
  $cp = Strip-Checkpoint $checkpoint
  $talkN = Normalize-Text $talk

  $qByTitle = [regex]::Unescape("'{0}'\uAD00\uB828\uD574\uC11C \uACE0\uAC1D\uC774 \uC5B4\uB5BB\uAC8C \uBB38\uC758\uD558\uBA74 \uB420\uAE4C\uC694?")
  $qByCp = [regex]::Unescape("'{0}'\uB294 \uC5B4\uB5BB\uAC8C \uC9C4\uD589\uD558\uBA74 \uB420\uAE4C\uC694?")
  $qGeneric = [regex]::Unescape("\uC774 \uC0C1\uD669\uC5D0\uC11C \uACE0\uAC1D\uC740 \uC5B4\uB5A4 \uC9C8\uBB38\uC744 \uD558\uBA74 \uB420\uAE4C\uC694?")

  if ($talkN) {
    if ($titleN) { return [string]::Format($qByTitle, $titleN) }
    if ($cp) { return [string]::Format($qByCp, $cp) }
    return $qGeneric
  }

  if ($cp) { return [string]::Format($qByCp, $cp) }
  if ($titleN) { return [string]::Format($qByTitle, $titleN) }
  return ""
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

if ($ColumnName -eq "__DEFAULT__") {
  $ColumnName = [regex]::Unescape("\uACE0\uAC1D\uC608\uC0C1\uC9C8\uBB38")
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
$expectedIndex = -1
$legacyIndex = -1
for ($h = 0; $h -lt $headerRow.Count; $h++) {
  $hn = Normalize-Text $headerRow[$h]
  if ($hn -eq $ColumnName) { $expectedIndex = $h; break }
  if ($hn -eq "customer_expected_question") { $legacyIndex = $h }
}
if ($expectedIndex -lt 0) {
  if ($legacyIndex -ge 0) {
    $expectedIndex = $legacyIndex
    $headerRow[$expectedIndex] = $ColumnName
  } else {
    $headerRow += $ColumnName
    $expectedIndex = $headerRow.Count - 1
  }
}

$outLines = New-Object System.Collections.Generic.List[string]
$outLines.Add(($titleRow | ForEach-Object { Escape-Csv $_ }) -join ",") | Out-Null
$outLines.Add(($headerRow | ForEach-Object { Escape-Csv $_ }) -join ",") | Out-Null

$currentTitle = ""
$updated = 0
for ($i = 2; $i -lt $rows.Count; $i++) {
  $vals = @($rows[$i])
  while ($vals.Count -lt 5) { $vals += "" }
  while ($vals.Count -le $expectedIndex) { $vals += "" }

  $title = if ($vals.Count -ge 2) { [string]$vals[1] } else { "" }
  $checkpoint = if ($vals.Count -ge 3) { [string]$vals[2] } else { "" }
  $talk = if ($vals.Count -ge 5) { [string]$vals[4] } else { "" }

  if (Normalize-Text $title) { $currentTitle = $title }
  $expected = ""
  if ((Normalize-Text $checkpoint) -or (Normalize-Text $talk)) {
    $expected = Build-ExpectedQuestion $currentTitle $checkpoint $talk
    if ($expected) { $updated++ }
  }

  $vals[$expectedIndex] = $expected
  $outLines.Add(($vals | ForEach-Object { Escape-Csv ([string]$_) }) -join ",") | Out-Null
}

Set-Content -Path $OutputCsv -Value $outLines -Encoding UTF8
Write-Host "Updated CSV: $OutputCsv"
Write-Host "Column: $ColumnName"
Write-Host "Rows updated: $updated"
