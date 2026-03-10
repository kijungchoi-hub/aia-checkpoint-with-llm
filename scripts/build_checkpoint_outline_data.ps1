param(
  [string]$InputCsv = "data/CHECKPOINT_DOMAIN_260202.csv",
  [string]$CheckpointCsv = "data/CHECKPOINT_202508.csv",
  [string]$OutputCsv = "data/CHECKPOINT_OUTLINE_260202.csv",
  [string]$OutputDetailCsv = "data/CHECKPOINT_OUTLINE_SOURCE_260202.csv"
)

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "build_checkpoint_outline_data.js"
node $scriptPath $InputCsv $CheckpointCsv $OutputCsv $OutputDetailCsv
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
