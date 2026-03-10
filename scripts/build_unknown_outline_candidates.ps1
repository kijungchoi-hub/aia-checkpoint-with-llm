param(
  [string]$InputCsv = "data/CHECKPOINT_OUTLINE_SOURCE_260202.csv",
  [string]$OutputCsv = "data\CHECKPOINT_UNKNOWN_OUTLINE_CANDIDATES_260202.csv",
  [string]$OutputDetailCsv = "data\CHECKPOINT_UNKNOWN_OUTLINE_SOURCE_260202.csv"
)

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "build_unknown_outline_candidates.js"
node $scriptPath $InputCsv $OutputCsv $OutputDetailCsv
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
