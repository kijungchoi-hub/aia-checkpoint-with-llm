# AIA Checkpoint With LLM

이 저장소는 체크포인트 상담 데이터를 정리하고, 체크포인트명과 도메인 코드를 매핑한 뒤, LLM 프롬프트 기반 분류와 고객 예상 질문 생성을 수행하는 PowerShell 작업 모음입니다.

주요 용도는 다음과 같습니다.

- `CHECKPOINT_TALK` CSV 데이터를 후처리해 JSONL 참조 데이터 생성
- 체크포인트 제목을 `topic_code`, `domain_code`에 연결
- 상담 문맥을 바탕으로 고객 예상 질문 1개 또는 3개 생성
- 사용자 질문, LLM 응답, 도메인 후보를 입력으로 체크포인트 분류 프롬프트 실행

## 디렉터리 구조

- [`data`](/C:/Workspace/Development/workspace_for_ai/AIA/aia-checkpoint-with-llm/data): 원본 CSV, 코드 매핑 테이블, 프롬프트 템플릿, 중간 산출물
- [`scripts`](/C:/Workspace/Development/workspace_for_ai/AIA/aia-checkpoint-with-llm/scripts): 데이터 가공, 예상 질문 생성, 중복 제거, 프롬프트 테스트, 분류 실행 스크립트

## 주요 데이터 파일

- [`data/CHECKPOINT_TALK_202508.csv`](/C:/Workspace/Development/workspace_for_ai/AIA/aia-checkpoint-with-llm/data/CHECKPOINT_TALK_202508.csv): 체크포인트/상담 원본 데이터
- [`data/Domain_Code_Table.csv`](/C:/Workspace/Development/workspace_for_ai/AIA/aia-checkpoint-with-llm/data/Domain_Code_Table.csv): 체크포인트 코드와 도메인 코드 매핑 테이블
- [`data/checkpoint_alias_map.csv`](/C:/Workspace/Development/workspace_for_ai/AIA/aia-checkpoint-with-llm/data/checkpoint_alias_map.csv): 제목 alias 매핑
- [`data/checkpoint_prompt.json`](/C:/Workspace/Development/workspace_for_ai/AIA/aia-checkpoint-with-llm/data/checkpoint_prompt.json): 분류용 프롬프트 템플릿
- [`data/checkpoint_talk_data.jsonl`](/C:/Workspace/Development/workspace_for_ai/AIA/aia-checkpoint-with-llm/data/checkpoint_talk_data.jsonl): 가공된 JSONL 데이터

## 주요 스크립트

- [`scripts/build_checkpoint_talk_data.ps1`](/C:/Workspace/Development/workspace_for_ai/AIA/aia-checkpoint-with-llm/scripts/build_checkpoint_talk_data.ps1): 원본 CSV와 매핑 정보를 합쳐 JSONL 생성
- [`scripts/enrich_checkpoint_talk_with_expected_question.ps1`](/C:/Workspace/Development/workspace_for_ai/AIA/aia-checkpoint-with-llm/scripts/enrich_checkpoint_talk_with_expected_question.ps1): 고객 예상 질문 1개 생성
- [`scripts/enrich_checkpoint_talk_with_3_questions.ps1`](/C:/Workspace/Development/workspace_for_ai/AIA/aia-checkpoint-with-llm/scripts/enrich_checkpoint_talk_with_3_questions.ps1): 고객 예상 질문 3개 생성
- [`scripts/dedupe_questions_by_title.ps1`](/C:/Workspace/Development/workspace_for_ai/AIA/aia-checkpoint-with-llm/scripts/dedupe_questions_by_title.ps1): 같은 제목 내 질문 중복 제거
- [`scripts/run_checkpoint_classification.ps1`](/C:/Workspace/Development/workspace_for_ai/AIA/aia-checkpoint-with-llm/scripts/run_checkpoint_classification.ps1): OpenAI Responses API로 체크포인트 분류 수행
- [`scripts/test_checkpoint_prompt.ps1`](/C:/Workspace/Development/workspace_for_ai/AIA/aia-checkpoint-with-llm/scripts/test_checkpoint_prompt.ps1): 샘플 입력 기준 프롬프트/규칙 테스트
- [`scripts/test_prompt_with_expected_questions.ps1`](/C:/Workspace/Development/workspace_for_ai/AIA/aia-checkpoint-with-llm/scripts/test_prompt_with_expected_questions.ps1): 예상 질문 컬럼 기반 프롬프트 렌더링 검증

## 작업 흐름

일반적인 처리 순서는 아래와 같습니다.

1. 원본 `CHECKPOINT_TALK` CSV를 준비합니다.
2. 필요하면 예상 질문 컬럼을 생성합니다.
3. 질문 중복을 제거합니다.
4. 체크포인트 데이터를 JSONL로 변환합니다.
5. 분류 프롬프트를 테스트하거나 실제 분류를 실행합니다.

## 실행 환경

- Windows PowerShell 또는 PowerShell 7
- CSV 읽기를 위한 기본 .NET / `Microsoft.VisualBasic.FileIO.TextFieldParser`
- OpenAI API 호출이 필요한 경우 `OPENAI_API_KEY` 환경 변수
- 기본 모델: `gpt-4.1-mini`

환경 변수 예시:

```powershell
$env:OPENAI_API_KEY = "YOUR_API_KEY"
$env:OPENAI_MODEL = "gpt-4.1-mini"
```

## 사용 예시

### 1. JSONL 데이터 생성

```powershell
.\scripts\build_checkpoint_talk_data.ps1
```

입력 파일 기본값:

- `data/CHECKPOINT_TALK_202508.csv`
- `data/Domain_Code_Table.csv`
- `data/checkpoint_alias_map.csv`

출력 파일 기본값:

- `data/checkpoint_talk_data.jsonl`

다른 파일 경로를 쓰려면:

```powershell
.\scripts\build_checkpoint_talk_data.ps1 `
  -InputCsv "data/CHECKPOINT_TALK_202508.csv" `
  -MappingCsv "data/Domain_Code_Table.csv" `
  -AliasCsv "data/checkpoint_alias_map.csv" `
  -OutputJsonl "data/checkpoint_talk_data.jsonl"
```

### 2. 고객 예상 질문 1개 생성

```powershell
.\scripts\enrich_checkpoint_talk_with_expected_question.ps1
```

기본적으로 입력 CSV를 같은 경로에 다시 저장합니다. 다른 출력 경로를 쓰려면:

```powershell
.\scripts\enrich_checkpoint_talk_with_expected_question.ps1 `
  -InputCsv "data/CHECKPOINT_TALK_202508.csv" `
  -OutputCsv "data/CHECKPOINT_TALK_202508.out.csv"
```

### 3. 고객 예상 질문 3개 생성

```powershell
.\scripts\enrich_checkpoint_talk_with_3_questions.ps1
```

이 스크립트는 질문 성격에 맞춰 `고객예상질문1`, `고객예상질문2`, `고객예상질문3` 컬럼을 채웁니다.

### 4. 질문 중복 제거

```powershell
.\scripts\dedupe_questions_by_title.ps1
```

동일 제목 묶음 안에서 이미 등장한 예상 질문은 비워 중복을 제거합니다.

### 5. 프롬프트 테스트

```powershell
.\scripts\test_checkpoint_prompt.ps1
```

또는 예상 질문 컬럼을 포함한 데이터로 프롬프트 렌더링을 확인하려면:

```powershell
.\scripts\test_prompt_with_expected_questions.ps1
```

### 6. 실제 분류 실행

```powershell
.\scripts\run_checkpoint_classification.ps1 `
  -UserQuestion "자동이체 계좌를 변경하고 싶어요." `
  -LlmAnswer "보험료 납입 계좌 변경 업무로 안내할 수 있습니다." `
  -DomainText "DOM003, DOM002, DOM001"
```

프롬프트만 확인하고 API 호출 없이 미리 보려면:

```powershell
.\scripts\run_checkpoint_classification.ps1 `
  -UserQuestion "자동이체 계좌를 변경하고 싶어요." `
  -LlmAnswer "보험료 납입 계좌 변경 업무로 안내할 수 있습니다." `
  -DomainText "DOM003, DOM002, DOM001" `
  -DryRun
```

## 분류 스크립트 동작 방식

`run_checkpoint_classification.ps1`는 아래 순서로 동작합니다.

1. `checkpoint_prompt.json`에서 프롬프트 템플릿을 읽습니다.
2. `DomainText`에서 `DOM001` 같은 도메인 후보를 추출합니다.
3. 매핑 CSV와 JSONL 데이터를 도메인 기준으로 필터링합니다.
4. 사용자 질문, LLM 응답, 도메인 후보, 체크포인트 데이터로 최종 프롬프트를 렌더링합니다.
5. `OPENAI_BASE_URL`이 설정되어 있으면 해당 엔드포인트를, 아니면 `https://api.openai.com/v1`를 사용합니다.
6. Responses API 호출 결과에서 `output_text`를 추출해 출력합니다.

## 주의사항

- 저장소의 텍스트 파일은 UTF-8 인코딩을 기준으로 사용합니다.
- `CHECKPOINT_TALK_202508.csv`는 첫 줄이 섹션 행, 둘째 줄이 헤더라는 형식을 가정합니다.
- 예상 질문 생성 스크립트는 입력 파일을 직접 덮어쓸 수 있으므로 백업 파일을 유지하는 것이 안전합니다.
- OpenAI API를 실제 호출하는 스크립트는 네트워크와 유효한 API 키가 필요합니다.

## 빠른 시작

최소 작업 순서만 보면 아래 3개면 됩니다.

```powershell
.\scripts\enrich_checkpoint_talk_with_3_questions.ps1
.\scripts\dedupe_questions_by_title.ps1
.\scripts\build_checkpoint_talk_data.ps1
```

그 다음 분류 확인:

```powershell
.\scripts\run_checkpoint_classification.ps1 `
  -UserQuestion "주소를 변경하고 싶어요." `
  -LlmAnswer "고객정보 변경 업무로 안내 가능합니다." `
  -DomainText "DOM001, DOM002, DOM003" `
  -DryRun
```
