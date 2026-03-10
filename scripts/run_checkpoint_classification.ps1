param(
  [Parameter(Mandatory = $true)]
  [string]$UserQuestion,
  [Parameter(Mandatory = $true)]
  [string]$LlmAnswer,
  [Parameter(Mandatory = $true)]
  [string]$DomainText,
  [string]$Model = $(if ($env:OPENAI_MODEL) { $env:OPENAI_MODEL } else { "gpt-4.1-mini" }),
  [string]$PromptPath = "data/checkpoint_prompt.json",
  [string]$MappingCsvPath = "data/Domain_Code_Table.csv",
  [string]$TalkJsonlPath = "data/checkpoint_talk_data.jsonl",
  [int]$MaxContentRows = 120,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Get-PromptTemplate([string]$path) {
  $obj = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
  if ($null -ne $obj.prompt) { return [string]$obj.prompt }
  if ($null -ne $obj.prompt_lines) { return ($obj.prompt_lines -join "`n") }
  throw "Prompt file must contain 'prompt' or 'prompt_lines': $path"
}

function Get-DomainCandidates([string]$domainText) {
  $matches = [regex]::Matches($domainText.ToUpperInvariant(), "DOM\d{3}")
  $codes = @()
  foreach ($m in $matches) {
    if ($codes -notcontains $m.Value) { $codes += $m.Value }
  }
  return $codes
}

function To-Line([string]$text) {
  if ([string]::IsNullOrWhiteSpace($text)) { return "" }
  return (($text -replace "\r\n|\r|\n", " ") -replace "\s+", " ").Trim()
}

if (-not (Test-Path $PromptPath)) { throw "Prompt not found: $PromptPath" }
if (-not (Test-Path $MappingCsvPath)) { throw "Mapping CSV not found: $MappingCsvPath" }
if (-not (Test-Path $TalkJsonlPath)) { throw "Talk JSONL not found: $TalkJsonlPath" }

$domainCandidates = Get-DomainCandidates $DomainText

$promptTemplate = Get-PromptTemplate $PromptPath
$mapping = Get-Content -Encoding UTF8 $MappingCsvPath |
  Select-Object -Skip 1 |
  ConvertFrom-Csv -Header checkpoint_code,checkpoint_name,domain_code,domain_name

$mappingFiltered = if ($domainCandidates.Count -gt 0) {
  $mapping | Where-Object { $domainCandidates -contains $_.domain_code }
} else {
  $mapping
}

$checkpointData = ($mappingFiltered | ForEach-Object {
  "checkpoint_code=$($_.checkpoint_code), checkpoint_name=$($_.checkpoint_name), domain_code=$($_.domain_code)"
}) -join "`n"

$talkRows = Get-Content -Encoding UTF8 $TalkJsonlPath | ForEach-Object { $_ | ConvertFrom-Json }
$talkFiltered = if ($domainCandidates.Count -gt 0) {
  $talkRows | Where-Object { $domainCandidates -contains $_.domain_code }
} else {
  $talkRows
}

$contentRows = $talkFiltered |
  Where-Object { -not [string]::IsNullOrWhiteSpace($_.checkpoint) } |
  Select-Object -First $MaxContentRows

$talkOnlyRows = $talkFiltered |
  Where-Object { -not [string]::IsNullOrWhiteSpace($_.talk) } |
  Select-Object -First $MaxContentRows

$checkpointContentData = ($contentRows | ForEach-Object {
  "checkpoint_code=$($_.topic_code), checkpoint=$([string](To-Line $_.checkpoint))"
}) -join "`n"

$checkpointTalkData = ($talkOnlyRows | ForEach-Object {
  "checkpoint=$([string](To-Line $_.checkpoint)), talk=$([string](To-Line $_.talk))"
}) -join "`n"

$rendered = $promptTemplate.
  Replace("{{USER_QUESTION}}", $UserQuestion).
  Replace("{{LLM_ANSWER}}", $LlmAnswer).
  Replace("{{DOMAIN_TEXT}}", $DomainText).
  Replace("{{CHECKPOINT_DATA}}", $checkpointData).
  Replace("{{CHECKPOINT_CONTENT_DATA}}", $checkpointContentData).
  Replace("{{CHECKPOINT_TALK_DATA}}", $checkpointTalkData)

if ($rendered -match "{{[A-Z_]+}}") {
  throw "Unresolved placeholder detected in prompt."
}

if ($DryRun) {
  Write-Host "[DRY RUN] Rendered prompt preview (first 1500 chars):"
  $preview = if ($rendered.Length -gt 1500) { $rendered.Substring(0, 1500) + "..." } else { $rendered }
  Write-Host $preview
  return
}

if (-not $env:OPENAI_API_KEY) {
  throw "OPENAI_API_KEY is not set."
}

$baseUrl = if ($env:OPENAI_BASE_URL) { $env:OPENAI_BASE_URL.TrimEnd("/") } else { "https://api.openai.com/v1" }
$uri = "$baseUrl/responses"

$headers = @{
  "Authorization" = "Bearer $($env:OPENAI_API_KEY)"
  "Content-Type" = "application/json"
}

$body = @{
  model = $Model
  temperature = 0
  input = @(
    @{
      role = "user"
      content = @(
        @{
          type = "input_text"
          text = $rendered
        }
      )
    }
  )
} | ConvertTo-Json -Depth 10

$resp = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body -TimeoutSec 120

$outputText = $null
if ($resp.output_text) {
  $outputText = [string]$resp.output_text
} elseif ($resp.output -and $resp.output.Count -gt 0) {
  foreach ($item in $resp.output) {
    if ($item.content) {
      foreach ($c in $item.content) {
        if ($c.type -eq "output_text" -and $c.text) {
          $outputText = [string]$c.text
          break
        }
      }
    }
    if ($outputText) { break }
  }
}

if (-not $outputText) {
  throw "No output text returned from API."
}

Write-Host $outputText
