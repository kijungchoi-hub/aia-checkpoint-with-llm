param(
  [string]$InputCsv = "data/CHECKPOINT_TALK_202508.csv",
  [string]$OutputCsv = "data/CHECKPOINT_TALK_202508.csv"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName Microsoft.VisualBasic

function U([string]$s) { [regex]::Unescape($s) }

function Normalize-Text([string]$text) {
  if ([string]::IsNullOrWhiteSpace($text)) { return "" }
  $t = $text -replace "\r\n|\n|\r", " "
  $t = $t -replace "\s+", " "
  return $t.Trim()
}

function Escape-Csv([string]$text) {
  if ($null -eq $text) { return "" }
  $needsQuote = $text.Contains(",") -or $text.Contains("`"") -or $text.Contains("`r") -or $text.Contains("`n")
  if ($needsQuote) { return '"' + ($text -replace '"', '""') + '"' }
  return $text
}

function Get-Keywords([string]$text) {
  $src = Normalize-Text $text
  if (-not $src) { return @() }
  $set = New-Object System.Collections.Generic.HashSet[string]
  $ms = [regex]::Matches($src, "[\p{L}\p{Nd}]{2,}")
  foreach ($m in $ms) {
    $w = $m.Value
    if ($w -match "^\d+$") { continue }
    [void]$set.Add($w)
  }
  return @($set)
}

function Get-Candidates([string]$title, [string]$checkpoint, [string]$talk) {
  $ctx = Normalize-Text "$title $checkpoint $talk"
  $ks = Get-Keywords $ctx

  $c = New-Object System.Collections.Generic.List[string]
  $c.Add((U("\uC774 \uC5C5\uBB34 \uC2E0\uCCAD \uC808\uCC28\uB294 \uC5B4\uB5BB\uAC8C \uC9C4\uD589\uB418\uB098\uC694?")))
  $c.Add((U("\uCC98\uB9AC \uC2DC \uD655\uC778\uD574\uC57C \uD560 \uC8FC\uC694 \uD56D\uBAA9\uC740 \uBB34\uC5C7\uC778\uAC00\uC694?")))
  $c.Add((U("\uD544\uC694 \uC11C\uB958\uC640 \uC900\uBE44 \uC815\uBCF4\uB97C \uC54C\uB824\uC8FC\uC138\uC694.")))
  $c.Add((U("\uCC98\uB9AC \uC644\uB8CC\uAE4C\uC9C0 \uC18C\uC694 \uAE30\uAC04\uC740 \uBCF4\uD1B5 \uC5BC\uB9C8\uB098 \uAC78\uB9AC\uB098\uC694?")))
  $c.Add((U("\uC811\uC218 \uD6C4 \uC9C4\uD589 \uC0C1\uD0DC\uB294 \uC5B4\uB5BB\uAC8C \uD655\uC778\uD560 \uC218 \uC788\uB098\uC694?")))
  $c.Add((U("\uCC98\uB9AC \uACFC\uC815\uC5D0\uC11C \uCD94\uAC00 \uC548\uB0B4 \uC0AC\uD56D\uC774 \uC788\uC73C\uBA74 \uBB34\uC5C7\uC778\uAC00\uC694?")))
  $c.Add((U("\uC2E0\uCCAD \uD6C4 \uBC18\uC601 \uC2DC\uC810\uC740 \uC5B8\uC81C\uBD80\uD130 \uD655\uC778 \uAC00\uB2A5\uD55C\uAC00\uC694?")))

  if ($ks.Count -gt 0) {
    $k1 = $ks[0]
    $c.Add([string]::Format((U("'{0}' \uAD00\uB828 \uD655\uC778 \uC808\uCC28\uB294 \uC5B4\uB5BB\uAC8C \uB418\uB098\uC694?")), $k1))
    $c.Add([string]::Format((U("'{0}' \uAD00\uB828 \uC694\uCCAD \uC2DC \uD544\uC218 \uD655\uC778\uC0AC\uD56D\uC774 \uC788\uB098\uC694?")), $k1))
  }
  if ($ks.Count -gt 1) {
    $k2 = $ks[1]
    $c.Add([string]::Format((U("'{0}' \uCC98\uB9AC \uC2DC \uC8FC\uC758\uD574\uC57C \uD560 \uC810\uC740 \uBB34\uC5C7\uC778\uAC00\uC694?")), $k2))
    $c.Add([string]::Format((U("'{0}' \uC815\uBCF4\uB294 \uC5B4\uB5A4 \uD615\uC2DD\uC73C\uB85C \uC81C\uCD9C\uD558\uBA74 \uB418\uB098\uC694?")), $k2))
  }
  if ($ks.Count -gt 2) {
    $k3 = $ks[2]
    $c.Add([string]::Format((U("'{0}' \uCC98\uB9AC\uAC00 \uC9C0\uC5F0\uB418\uB294 \uACBD\uC6B0 \uB300\uC751 \uBC29\uBC95\uC740 \uBB34\uC5C7\uC778\uAC00\uC694?")), $k3))
  }
  if ($ks.Count -gt 3) {
    $k4 = $ks[3]
    $c.Add([string]::Format((U("'{0}' \uAD00\uB828 \uC548\uB0B4\uB294 \uC5B4\uB5A4 \uC21C\uC11C\uB85C \uBC1B\uC744 \uC218 \uC788\uB098\uC694?")), $k4))
  }

  return @($c)
}

if (-not (Test-Path $InputCsv)) { throw "Input CSV not found: $InputCsv" }

$parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new($InputCsv, [System.Text.Encoding]::UTF8)
$parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
$parser.SetDelimiters(",")
$parser.HasFieldsEnclosedInQuotes = $true
$parser.TrimWhiteSpace = $false

$rows = New-Object System.Collections.Generic.List[object]
while (-not $parser.EndOfData) {
  $rows.Add(@($parser.ReadFields())) | Out-Null
}
$parser.Close()

if ($rows.Count -lt 2) { throw "Unexpected CSV format." }

$titleRow = @($rows[0])
$headerRow = @($rows[1])

$idxNo = 0
$idxTitle = 1
$idxCheckpoint = 2
$idxTalk = 4
$idxQ1 = $headerRow.Count - 3
$idxQ2 = $headerRow.Count - 2
$idxQ3 = $headerRow.Count - 1
if ($idxQ1 -lt 0) { throw "Question columns not found." }

$usedByTitle = @{}
$currentTitle = ""

# preload used questions per title
for ($r = 2; $r -lt $rows.Count; $r++) {
  $vals = @($rows[$r])
  while ($vals.Count -le $idxQ3) { $vals += "" }
  $noVal = Normalize-Text ([string]$vals[$idxNo])
  $titleVal = Normalize-Text ([string]$vals[$idxTitle])
  if ($titleVal -and $noVal -match '^\d+$') { $currentTitle = $titleVal }
  if (-not $currentTitle) { continue }
  if (-not $usedByTitle.ContainsKey($currentTitle)) {
    $usedByTitle[$currentTitle] = New-Object System.Collections.Generic.HashSet[string]
  }
  $used = $usedByTitle[$currentTitle]
  foreach ($idx in @($idxQ1, $idxQ2, $idxQ3)) {
    $q = Normalize-Text ([string]$vals[$idx])
    if ($q) { [void]$used.Add($q) }
  }
}

$outLines = New-Object System.Collections.Generic.List[string]
$outLines.Add(($titleRow | ForEach-Object { Escape-Csv $_ }) -join ",") | Out-Null
$outLines.Add(($headerRow | ForEach-Object { Escape-Csv $_ }) -join ",") | Out-Null

$currentTitle = ""
$filled = 0

for ($r = 2; $r -lt $rows.Count; $r++) {
  $vals = @($rows[$r])
  while ($vals.Count -le $idxQ3) { $vals += "" }

  $noVal = Normalize-Text ([string]$vals[$idxNo])
  $titleVal = Normalize-Text ([string]$vals[$idxTitle])
  if ($titleVal -and $noVal -match '^\d+$') { $currentTitle = $titleVal }

  if (-not $currentTitle) {
    $outLines.Add(($vals | ForEach-Object { Escape-Csv ([string]$_) }) -join ",") | Out-Null
    continue
  }

  if (-not $usedByTitle.ContainsKey($currentTitle)) {
    $usedByTitle[$currentTitle] = New-Object System.Collections.Generic.HashSet[string]
  }
  $used = $usedByTitle[$currentTitle]

  $checkpoint = Normalize-Text ([string]$vals[$idxCheckpoint])
  $talk = Normalize-Text ([string]$vals[$idxTalk])
  if ($checkpoint -or $talk) {
    $cands = Get-Candidates $currentTitle $checkpoint $talk

    foreach ($idx in @($idxQ1, $idxQ2, $idxQ3)) {
      $q = Normalize-Text ([string]$vals[$idx])
      if ($q) { continue }

      $picked = ""
      foreach ($cand in $cands) {
        $candN = Normalize-Text $cand
        if (-not $candN) { continue }
        if ($used.Contains($candN)) { continue }
        $picked = $candN
        break
      }

      if (-not $picked) {
        $n = 1
        do {
          $picked = [string]::Format((U("\uCD94\uAC00 \uD655\uC778 \uC0AC\uD56D({0})\uC740 \uBB34\uC5C7\uC778\uAC00\uC694?")), $n)
          $n++
        } while ($used.Contains($picked))
      }

      $vals[$idx] = $picked
      [void]$used.Add($picked)
      $filled++
    }
  }

  $outLines.Add(($vals | ForEach-Object { Escape-Csv ([string]$_) }) -join ",") | Out-Null
}

Set-Content -Path $OutputCsv -Value $outLines -Encoding UTF8
Write-Host "Updated CSV: $OutputCsv"
Write-Host "Filled blank questions: $filled"
