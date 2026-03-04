$ErrorActionPreference = "Stop"

$promptObj = Get-Content -Raw -Encoding UTF8 "data/checkpoint_prompt.json" | ConvertFrom-Json
if ($null -ne $promptObj.prompt) {
  $promptTemplate = [string]$promptObj.prompt
} elseif ($null -ne $promptObj.prompt_lines) {
  $promptTemplate = ($promptObj.prompt_lines -join "`n")
} else {
  throw "checkpoint_prompt.json must contain 'prompt' or 'prompt_lines'."
}

# Extract mapping from Domain_Code_Table.csv (CP949 encoded)
$lines = Get-Content -Encoding Default "data/Domain_Code_Table.csv"
$mapping = $lines |
  Select-Object -Skip 1 |
  ConvertFrom-Csv -Header checkpoint_code,checkpoint_name,domain_code,domain_name

$mapByCheckpoint = @{}
foreach ($m in $mapping) {
  if ($m.checkpoint_code -and $m.domain_code) {
    $mapByCheckpoint[$m.checkpoint_code] = $m
  }
}

# Test seeds: expected topic comes from extracted CSV mapping
$seedCases = @(
  [pscustomobject]@{
    Case = "A"
    ExpectedTopic = "DOM003001"
    UserQuestion = "I want to change the account used for premium auto debit."
    LlmAnswer = "This can be handled under premium payment and account auto debit."
    DomainTop3 = "DOM003, DOM002, DOM001"
  },
  [pscustomobject]@{
    Case = "B"
    ExpectedTopic = "DOM002001"
    UserQuestion = "Can I get my policy documents reissued?"
    LlmAnswer = "This is a contract info request for policy/terms reissue."
    DomainTop3 = "DOM001, DOM002, DOM003"
  },
  [pscustomobject]@{
    Case = "C"
    ExpectedTopic = "DOM001001"
    UserQuestion = "My home address and contact number changed."
    LlmAnswer = "This is customer info update for address/contact change."
    DomainTop3 = "DOM002, DOM001, DOM003"
  },
  [pscustomobject]@{
    Case = "D"
    ExpectedTopic = "DOM003005"
    UserQuestion = "Please stop auto debit."
    LlmAnswer = "This request maps to premium payment auto debit cancellation."
    DomainTop3 = "DOM003, DOM002, DOM001"
  },
  [pscustomobject]@{
    Case = "E"
    ExpectedTopic = "DOM002007"
    UserQuestion = "I want to reduce coverage and remove riders."
    LlmAnswer = "This can be processed as reduction/rider deletion in contract info."
    DomainTop3 = "DOM003, DOM002, DOM001"
  }
)

$cases = foreach ($c in $seedCases) {
  $meta = $mapByCheckpoint[$c.ExpectedTopic]
  if (-not $meta) {
    throw "Expected topic code not found in Domain_Code_Table.csv: $($c.ExpectedTopic)"
  }
  [pscustomobject]@{
    Case = $c.Case
    UserQuestion = $c.UserQuestion
    LlmAnswer = $c.LlmAnswer
    DomainTop3 = $c.DomainTop3
    ExpectedDomain = $meta.domain_code
    ExpectedTopic = $meta.checkpoint_code
  }
}

function Resolve-DomainCandidates([string]$domainTop3) {
  $allowed = @("DOM001", "DOM002", "DOM003")
  $candidates = @()
  foreach ($d in ($domainTop3 -split ",")) {
    $code = $d.Trim().ToUpperInvariant()
    if ($allowed -contains $code) {
      $candidates += $code
    }
  }
  return $candidates
}

function Predict-By-Rule([string]$userQuestion, [string]$llmAnswer, [string]$domainTop3) {
  $text = "$userQuestion`n$llmAnswer".ToLowerInvariant()
  $candidates = Resolve-DomainCandidates $domainTop3
  $domain = "UNKNOWN"
  $topic = "UNKNOWN"

  if ($text -match "address|contact") {
    if ($candidates -contains "DOM001") { $domain = "DOM001"; $topic = "DOM001001" }
  } elseif ($text -match "reissue|policy|terms") {
    if ($candidates -contains "DOM002") { $domain = "DOM002"; $topic = "DOM002001" }
  } elseif ($text -match "reduce|reduction|rider") {
    if ($candidates -contains "DOM002") { $domain = "DOM002"; $topic = "DOM002007" }
  } elseif ($text -match "stop auto debit|cancel auto debit|auto debit cancellation") {
    if ($candidates -contains "DOM003") { $domain = "DOM003"; $topic = "DOM003005" }
  } elseif ($text -match "account auto debit|auto debit.*account") {
    if ($candidates -contains "DOM003") { $domain = "DOM003"; $topic = "DOM003001" }
  }

  return [pscustomobject]@{ domain_code = $domain; topic_code = $topic }
}

$results = foreach ($c in $cases) {
  $rendered = $promptTemplate.
    Replace("{{USER_QUESTION}}", $c.UserQuestion).
    Replace("{{LLM_ANSWER}}", $c.LlmAnswer).
    Replace("{{DOMAIN_TEXT}}", $c.DomainTop3)

  $renderOk = ($rendered -notmatch "{{USER_QUESTION}}|{{LLM_ANSWER}}|{{DOMAIN_TEXT}}")
  $pred = Predict-By-Rule $c.UserQuestion $c.LlmAnswer $c.DomainTop3
  $actual = "$($pred.domain_code)/$($pred.topic_code)"
  $expected = "$($c.ExpectedDomain)/$($c.ExpectedTopic)"

  [pscustomobject]@{
    Case = $c.Case
    PromptRender = if ($renderOk) { "OK" } else { "FAIL" }
    Expected = $expected
    Actual = $actual
    Result = if ($actual -eq $expected) { "PASS" } else { "FAIL" }
  }
}

$results | Format-Table -AutoSize
