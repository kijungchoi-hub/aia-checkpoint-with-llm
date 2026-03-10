param(
  [string]$InputCsv = "data/CHECKPOINT_OUTLINE_SOURCE_260202.csv",
  [string]$OutputCsv = "data/CHECKPOINT_CLASSIFIER_TEST_RESULTS_260202.csv",
  [string]$Model = $(if ($env:OPENAI_MODEL) { $env:OPENAI_MODEL } else { "gpt-4.1-mini" }),
  [int]$MaxRows = 0,
  [int]$MaxContentRows = 120
)

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "test_checkpoint_classifier_from_outline.js"
node $scriptPath $InputCsv $OutputCsv $Model $MaxRows $MaxContentRows
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
