param(
  [string]$InputCsv = "data/CHECKPOINT_TALK_202508.csv",
  [string]$OutputCsv = "data/CHECKPOINT_TALK_202508.csv"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName Microsoft.VisualBasic

function U([string]$s) {
  return [regex]::Unescape($s)
}

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

function Escape-Csv([string]$text) {
  if ($null -eq $text) { return "" }
  $needsQuote = $text.Contains(",") -or $text.Contains("`"") -or $text.Contains("`r") -or $text.Contains("`n")
  if ($needsQuote) {
    return '"' + ($text -replace '"', '""') + '"'
  }
  return $text
}

function Build-QuestionSet([string]$title, [string]$checkpoint, [string]$talk) {
  $titleN = Normalize-Text $title
  $cpN = Normalize-Text (Strip-Checkpoint $checkpoint)
  $talkN = Normalize-Text $talk
  $text = "$titleN $cpN $talkN"

  $q1 = U("\uC774 \uC5C5\uBB34\uB294 \uC5B4\uB5BB\uAC8C \uC2E0\uCCAD\uD558\uBA74 \uB418\uB098\uC694?")
  $q2 = U("\uCC98\uB9AC \uC2DC \uD544\uC694\uD55C \uC815\uBCF4\uB098 \uC11C\uB958\uAC00 \uBB34\uC5C7\uC778\uAC00\uC694?")
  $q3 = U("\uCC98\uB9AC \uBC29\uBC95\uACFC \uC18C\uC694\uC2DC\uAC04\uC744 \uC548\uB0B4\uD574 \uC8FC\uC138\uC694.")

  if ($text -match "\uC8FC\uC18C|\uC5F0\uB77D\uCC98|\uD734\uB300\uD3F0|\uC804\uD654\uBC88\uD638") {
    $q1 = U("\uC8FC\uC18C\uB098 \uC5F0\uB77D\uCC98 \uBCC0\uACBD\uC740 \uC5B4\uB5BB\uAC8C \uC9C4\uD589\uD558\uBA74 \uB418\uB098\uC694?")
    $q2 = U("\uBCF8\uC778\uD655\uC778 \uBC29\uBC95\uACFC \uD544\uC694\uD55C \uC815\uBCF4\uB97C \uC54C\uB824\uC8FC\uC138\uC694.")
    $q3 = U("\uBCC0\uACBD \uBC18\uC601\uC740 \uC5B8\uC81C\uBD80\uD130 \uD655\uC778\uD560 \uC218 \uC788\uB098\uC694?")
  } elseif ($text -match "\uC99D\uAD8C|\uC57D\uAD00|\uC7AC\uBC1C\uD589|\uBC1C\uAE09|\uC99D\uBA85\uC11C") {
    $q1 = U("\uC99D\uAD8C/\uC57D\uAD00/\uC99D\uBA85\uC11C \uBC1C\uAE09\uC740 \uC5B4\uB5BB\uAC8C \uC2E0\uCCAD\uD558\uBA74 \uB418\uB098\uC694?")
    $q2 = U("\uC218\uB839 \uAC00\uB2A5\uD55C \uBC29\uC2DD(\uBB38\uC790/\uC774\uBA54\uC77C/\uC6B0\uD3B8 \uB4F1)\uC744 \uC54C\uB824\uC8FC\uC138\uC694.")
    $q3 = U("\uBC1C\uAE09 \uC644\uB8CC\uAE4C\uC9C0 \uBCF4\uD1B5 \uBA87 \uBD84 \uB610\uB294 \uBA70\uCE60 \uAC78\uB9AC\uB098\uC694?")
  } elseif ($text -match "\uACC4\uC88C|\uC774\uCCB4|\uCE74\uB4DC|\uB0A9\uC785|\uCD9C\uAE08|\uC790\uB3D9\uC1A1\uAE08") {
    $q1 = U("\uB0A9\uC785 \uACC4\uC88C/\uCE74\uB4DC \uBCC0\uACBD\uC774\uB098 \uB4F1\uB85D\uC740 \uC5B4\uB5BB\uAC8C \uD558\uBA74 \uB418\uB098\uC694?")
    $q2 = U("\uACC4\uC88C/\uCE74\uB4DC \uC815\uBCF4\uB294 \uC5B4\uB5A4 \uD56D\uBAA9\uC744 \uC900\uBE44\uD558\uBA74 \uB418\uB098\uC694?")
    $q3 = U("\uC801\uC6A9 \uC2DC\uC810\uACFC \uCCAD\uAD6C \uC77C\uC815\uC740 \uC5B4\uB5BB\uAC8C \uB418\uB098\uC694?")
  } elseif ($text -match "\uD574\uC9C0|\uCDE8\uC18C|\uCCAD\uC57D\uCCA0\uD68C|\uD488\uC9C8\uBCF4\uC99D") {
    $q1 = U("\uD574\uC9C0/\uCDE8\uC18C \uC2E0\uCCAD\uC740 \uC5B4\uB5BB\uAC8C \uD558\uBA74 \uB418\uB098\uC694?")
    $q2 = U("\uD574\uC9C0 \uC2DC \uD655\uC778\uD574\uC57C \uD560 \uC870\uAC74\uC774\uB098 \uD544\uC694\uC11C\uB958\uAC00 \uC788\uB098\uC694?")
    $q3 = U("\uD658\uAE09\uAE08 \uC9C0\uAE09 \uC2DC\uC810\uACFC \uACF5\uC81C \uD56D\uBAA9\uC744 \uC54C\uB824\uC8FC\uC138\uC694.")
  } elseif ($text -match "\uB300\uCD9C|APL|\uC57D\uAD00\uB300\uCD9C") {
    $q1 = U("\uBCF4\uD5D8\uACC4\uC57D\uB300\uCD9C \uC2E0\uCCAD\uC740 \uC5B4\uB5BB\uAC8C \uC9C4\uD589\uD558\uBA74 \uB418\uB098\uC694?")
    $q2 = U("\uC774\uC790 \uACC4\uC0B0 \uAE30\uC900\uACFC \uC0C1\uD658 \uC870\uAC74\uC744 \uC54C\uB824\uC8FC\uC138\uC694.")
    $q3 = U("\uB300\uCD9C\uAE08 \uC9C0\uAE09\uAE4C\uC9C0 \uC18C\uC694\uB418\uB294 \uC2DC\uAC04\uC740 \uC5BC\uB9C8\uC778\uAC00\uC694?")
  } elseif ($text -match "\uBCF4\uD5D8\uAE08|\uCCAD\uAD6C|\uC9C4\uB2E8|\uC218\uC220|\uC785\uC6D0") {
    $q1 = U("\uBCF4\uD5D8\uAE08 \uCCAD\uAD6C \uC811\uC218\uB294 \uC5B4\uB5BB\uAC8C \uD558\uBA74 \uB418\uB098\uC694?")
    $q2 = U("\uC9C4\uB2E8\uC11C \uB4F1 \uD544\uC694 \uC11C\uB958 \uAE30\uC900\uC744 \uAD6C\uCCB4\uC801\uC73C\uB85C \uC54C\uB824\uC8FC\uC138\uC694.")
    $q3 = U("\uC2EC\uC0AC\uC640 \uC9C0\uAE09\uAE4C\uC9C0 \uC608\uC0C1 \uAE30\uAC04\uC740 \uC5B4\uB5BB\uAC8C \uB418\uB098\uC694?")
  } elseif ($text -match "\uBA85\uC758|\uC218\uC775\uC790|\uD0DC\uC544|\uC815\uC815|\uBCC0\uACBD") {
    $q1 = U("\uACC4\uC57D\uC790/\uC218\uC775\uC790 \uC815\uBCF4 \uBCC0\uACBD\uC740 \uC5B4\uB5BB\uAC8C \uD558\uBA74 \uB418\uB098\uC694?")
    $q2 = U("\uBCC0\uACBD \uC2E0\uCCAD \uC2DC \uD544\uC694\uD55C \uD655\uC778 \uC790\uB8CC\uB97C \uC54C\uB824\uC8FC\uC138\uC694.")
    $q3 = U("\uBCC0\uACBD\uB41C \uB0B4\uC6A9\uC740 \uC5B8\uC81C\uBD80\uD130 \uBC18\uC601\uB418\uB098\uC694?")
  } elseif ($text -match "\uC5F0\uAE08|\uC804\uD658|\uC9C0\uAE09") {
    $q1 = U("\uC5F0\uAE08 \uC2E0\uCCAD/\uBCC0\uACBD\uC740 \uC5B4\uB5BB\uAC8C \uD558\uBA74 \uB418\uB098\uC694?")
    $q2 = U("\uC5F0\uAE08 \uC9C0\uAE09 \uBC29\uC2DD\uACFC \uC120\uD0DD \uAC00\uB2A5 \uD56D\uBAA9\uC744 \uC54C\uB824\uC8FC\uC138\uC694.")
    $q3 = U("\uBCC0\uACBD \uB610\uB294 \uC2E0\uCCAD \uD6C4 \uC801\uC6A9 \uC2DC\uC810\uC740 \uC5B8\uC81C\uC778\uAC00\uC694?")
  }

  if ($talkN -match "ARS|SMS|\uBCF8\uC778|\uC778\uC99D|\uB3D9\uC758") {
    $q2 = U("\uBCF8\uC778\uC778\uC99D\uC740 \uC5B4\uB5BB\uAC8C \uC9C4\uD589\uD558\uBA70, \uC2E4\uD328 \uC2DC \uC5B4\uB5BB\uAC8C \uD558\uBA74 \uB418\uB098\uC694?")
  } elseif ($talkN -match "\uC11C\uB958|\uC0AC\uBCF8|\uC6D0\uBCF8|\uC99D\uBA85\uC11C|\uBC1C\uAE09") {
    $q2 = U("\uD544\uC694 \uC11C\uB958 \uC885\uB958\uC640 \uBC1C\uAE09 \uAE30\uC900\uC744 \uC54C\uB824\uC8FC\uC138\uC694.")
  } elseif ($talkN -match "\uBB38\uC790|\uC774\uBA54\uC77C|\uD329\uC2A4|\uC6B0\uD3B8|\uC218\uB839") {
    $q2 = U("\uC811\uC218 \uD6C4 \uC218\uB839 \uBC29\uC2DD\uC740 \uC5B4\uB5BB\uAC8C \uC120\uD0DD\uD560 \uC218 \uC788\uB098\uC694?")
  }

  if ($talkN -match "\uC18C\uC694|\uBD84|\uD3C9\uC77C|\uC989\uC2DC|5~7\uC77C|10~15\uBD84|\uC9C0\uAE09") {
    $q3 = U("\uC804\uCCB4 \uCC98\uB9AC\uAC00 \uC644\uB8CC\uB418\uAE30\uAE4C\uC9C0 \uBCF4\uD1B5 \uC5BC\uB9C8\uB098 \uAC78\uB9AC\uB098\uC694?")
  }

  return @($q1, $q2, $q3)
}

if (-not (Test-Path $InputCsv)) {
  throw "Input CSV not found: $InputCsv"
}

$col1 = U("\uACE0\uAC1D\uC608\uC0C1\uC9C8\uBB381")
$col2 = U("\uACE0\uAC1D\uC608\uC0C1\uC9C8\uBB382")
$col3 = U("\uACE0\uAC1D\uC608\uC0C1\uC9C8\uBB383")

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

function Get-OrAddColumnIndex([object[]]$header, [string]$name) {
  for ($i = 0; $i -lt $header.Count; $i++) {
    if ((Normalize-Text $header[$i]) -eq $name) { return $i }
  }
  $header += $name
  return ($header.Count - 1)
}

$idx1 = -1; $idx2 = -1; $idx3 = -1
for ($i = 0; $i -lt $headerRow.Count; $i++) {
  $h = Normalize-Text $headerRow[$i]
  if ($h -eq $col1) { $idx1 = $i }
  if ($h -eq $col2) { $idx2 = $i }
  if ($h -eq $col3) { $idx3 = $i }
}
if ($idx1 -lt 0) { $headerRow += $col1; $idx1 = $headerRow.Count - 1 }
if ($idx2 -lt 0) { $headerRow += $col2; $idx2 = $headerRow.Count - 1 }
if ($idx3 -lt 0) { $headerRow += $col3; $idx3 = $headerRow.Count - 1 }

$outLines = New-Object System.Collections.Generic.List[string]
$outLines.Add(($titleRow | ForEach-Object { Escape-Csv $_ }) -join ",") | Out-Null
$outLines.Add(($headerRow | ForEach-Object { Escape-Csv $_ }) -join ",") | Out-Null

$currentTitle = ""
$updated = 0
for ($r = 2; $r -lt $rows.Count; $r++) {
  $vals = @($rows[$r])
  while ($vals.Count -lt 5) { $vals += "" }
  while ($vals.Count -le $idx3) { $vals += "" }

  $title = if ($vals.Count -ge 2) { [string]$vals[1] } else { "" }
  $checkpoint = if ($vals.Count -ge 3) { [string]$vals[2] } else { "" }
  $talk = if ($vals.Count -ge 5) { [string]$vals[4] } else { "" }

  if (Normalize-Text $title) { $currentTitle = $title }

  if ((Normalize-Text $checkpoint) -or (Normalize-Text $talk)) {
    $qs = Build-QuestionSet $currentTitle $checkpoint $talk
    $vals[$idx1] = $qs[0]
    $vals[$idx2] = $qs[1]
    $vals[$idx3] = $qs[2]
    $updated++
  } else {
    $vals[$idx1] = ""
    $vals[$idx2] = ""
    $vals[$idx3] = ""
  }

  $outLines.Add(($vals | ForEach-Object { Escape-Csv ([string]$_) }) -join ",") | Out-Null
}

Set-Content -Path $OutputCsv -Value $outLines -Encoding UTF8
Write-Host "Updated CSV: $OutputCsv"
Write-Host "Columns: $col1, $col2, $col3"
Write-Host "Rows updated: $updated"
