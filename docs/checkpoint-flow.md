# 체크포인트 분류 전체 흐름

이 문서는 `README.md`의 전체 flowchart를 단계별로 풀어서 설명합니다. 각 단계에서 어떤 입력 파일을 사용하고, 어떤 스크립트를 실행하며, 어떤 출력 파일이 생성되는지 빠르게 확인할 수 있도록 정리했습니다.

정밀한 Top1 목차 탐색 고도화 방안은 [advanced-retrieval-design.md](advanced-retrieval-design.md) 문서를 참고합니다.

## 1. 상담 데이터 전처리 및 분류 입력 생성

목적:
상담 원본 CSV에서 예상 질문을 보강하고, 중복을 정리한 뒤, LLM 분류에 사용할 JSONL 데이터를 생성합니다.

흐름:

1. 원본 상담 데이터 입력
   - 입력 파일: [`data/CHECKPOINT_TALK_202508.csv`](../data/CHECKPOINT_TALK_202508.csv)
2. 예상 질문 3개 생성
   - 스크립트: [`scripts/enrich_checkpoint_talk_with_3_questions.ps1`](../scripts/enrich_checkpoint_talk_with_3_questions.ps1)
   - 역할: 각 상담 건에 대해 고객이 할 가능성이 높은 질문 3개를 생성합니다.
3. 빈 질문 보완
   - 스크립트: [`scripts/fill_blank_questions_unique.ps1`](../scripts/fill_blank_questions_unique.ps1)
   - 역할: 비어 있는 질문 칼럼만 채우고, 기존 질문과 중복되지 않도록 보완합니다.
4. 질문 중복 제거
   - 스크립트: [`scripts/dedupe_questions_by_title.ps1`](../scripts/dedupe_questions_by_title.ps1)
   - 역할: 동일 제목 또는 유사 묶음 안에서 중복 질문을 제거합니다.
5. 분류용 JSONL 생성
   - 스크립트: [`scripts/build_checkpoint_talk_data.ps1`](../scripts/build_checkpoint_talk_data.ps1)
   - 추가 입력:
     - [`data/Domain_Code_Table.csv`](../data/Domain_Code_Table.csv)
     - [`data/checkpoint_alias_map.csv`](../data/checkpoint_alias_map.csv)
   - 출력 파일: [`data/checkpoint_talk_data.jsonl`](../data/checkpoint_talk_data.jsonl)
   - 역할: 상담 CSV를 도메인/토픽 분류용 JSONL로 변환합니다.

최종 산출물:

- [`data/checkpoint_talk_data.jsonl`](../data/checkpoint_talk_data.jsonl)

## 2. 도메인 분류 결과를 아웃라인 데이터로 변환

목적:
도메인 분류 결과를 바탕으로 체크포인트별 질문 묶음과 출처 데이터를 생성합니다.

흐름:

1. 도메인 분류 결과 입력
   - 입력 파일: [`data/CHECKPOINT_DOMAIN_260202.csv`](../data/CHECKPOINT_DOMAIN_260202.csv)
2. 체크포인트 기준 데이터 결합
   - 입력 파일: [`data/CHECKPOINT_202508.csv`](../data/CHECKPOINT_202508.csv)
3. 아웃라인 데이터 생성
   - 스크립트: [`scripts/build_checkpoint_outline_data.ps1`](../scripts/build_checkpoint_outline_data.ps1)
   - 출력 파일:
     - [`data/CHECKPOINT_OUTLINE_260202.csv`](../data/CHECKPOINT_OUTLINE_260202.csv)
     - [`data/CHECKPOINT_OUTLINE_SOURCE_260202.csv`](../data/CHECKPOINT_OUTLINE_SOURCE_260202.csv)

출력 설명:

- [`data/CHECKPOINT_OUTLINE_260202.csv`](../data/CHECKPOINT_OUTLINE_260202.csv)
  - 체크포인트별 대표 질문, 유사 질문, 예시 질문 등을 모은 아웃라인 데이터입니다.
- [`data/CHECKPOINT_OUTLINE_SOURCE_260202.csv`](../data/CHECKPOINT_OUTLINE_SOURCE_260202.csv)
  - 질문 단위의 매핑 상세 결과입니다.
  - 어떤 항목이 `MATCHED`인지, 어떤 항목이 `UNKNOWN`인지 추적할 때 사용합니다.

## 3. UNKNOWN 후보 추출

목적:
기존 아웃라인에 매핑되지 않은 질문을 따로 추려 후속 검토나 신규 아웃라인 후보 생성에 활용합니다.

흐름:

1. 아웃라인 출처 데이터 입력
   - 입력 파일: [`data/CHECKPOINT_OUTLINE_SOURCE_260202.csv`](../data/CHECKPOINT_OUTLINE_SOURCE_260202.csv)
2. 미분류 후보 생성
   - 스크립트: [`scripts/build_unknown_outline_candidates.ps1`](../scripts/build_unknown_outline_candidates.ps1)
   - 출력 파일:
     - [`data/CHECKPOINT_UNKNOWN_OUTLINE_CANDIDATES_260202.csv`](../data/CHECKPOINT_UNKNOWN_OUTLINE_CANDIDATES_260202.csv)
     - [`data/CHECKPOINT_UNKNOWN_OUTLINE_SOURCE_260202.csv`](../data/CHECKPOINT_UNKNOWN_OUTLINE_SOURCE_260202.csv)

출력 설명:

- [`data/CHECKPOINT_UNKNOWN_OUTLINE_CANDIDATES_260202.csv`](../data/CHECKPOINT_UNKNOWN_OUTLINE_CANDIDATES_260202.csv)
  - 신규 아웃라인 후보 검토용 요약 데이터입니다.
- [`data/CHECKPOINT_UNKNOWN_OUTLINE_SOURCE_260202.csv`](../data/CHECKPOINT_UNKNOWN_OUTLINE_SOURCE_260202.csv)
  - 후보가 어떤 원본 질문에서 나왔는지 추적하기 위한 상세 데이터입니다.

## 4. 프롬프트 검증 및 분류 실행

목적:
프롬프트 구성을 확인하고, 실제 사용자 질문과 LLM 답변을 입력으로 받아 도메인/토픽 코드를 예측합니다.

입력:

- 프롬프트 설정: [`data/checkpoint_prompt.json`](../data/checkpoint_prompt.json)
- 분류용 기준 데이터: [`data/checkpoint_talk_data.jsonl`](../data/checkpoint_talk_data.jsonl)
- 도메인 코드 매핑: [`data/Domain_Code_Table.csv`](../data/Domain_Code_Table.csv)
- 실시간 입력:
  - `UserQuestion`
  - `LlmAnswer`
  - `DomainText`

관련 스크립트:

- [`scripts/test_checkpoint_prompt.ps1`](../scripts/test_checkpoint_prompt.ps1)
  - 목적: 프롬프트 템플릿과 참조 데이터 조합이 의도대로 구성되는지 확인
- [`scripts/test_prompt_with_expected_questions.ps1`](../scripts/test_prompt_with_expected_questions.ps1)
  - 목적: 예상 질문 컬럼이 프롬프트에 적절히 반영되는지 확인
- [`scripts/run_checkpoint_classification.ps1`](../scripts/run_checkpoint_classification.ps1)
  - 목적: Responses API를 호출해 `domain_code`, `topic_code`를 예측

최종 출력:

- `domain_code`
- `topic_code`

## 5. 아웃라인 기반 분류 검증

목적:
아웃라인 데이터가 실제 분류 품질 검증에 활용 가능한지 테스트합니다.

흐름:

1. 입력 파일
   - [`data/CHECKPOINT_OUTLINE_SOURCE_260202.csv`](../data/CHECKPOINT_OUTLINE_SOURCE_260202.csv)
2. 검증 기준
   - [`data/CHECKPOINT_OUTLINE_260202.csv`](../data/CHECKPOINT_OUTLINE_260202.csv)
3. 테스트 스크립트
   - [`scripts/test_checkpoint_classifier_from_outline.ps1`](../scripts/test_checkpoint_classifier_from_outline.ps1)

## 6. 전체 실행 순서 요약

권장 순서:

1. [`scripts/enrich_checkpoint_talk_with_3_questions.ps1`](../scripts/enrich_checkpoint_talk_with_3_questions.ps1)
2. [`scripts/fill_blank_questions_unique.ps1`](../scripts/fill_blank_questions_unique.ps1)
3. [`scripts/dedupe_questions_by_title.ps1`](../scripts/dedupe_questions_by_title.ps1)
4. [`scripts/build_checkpoint_talk_data.ps1`](../scripts/build_checkpoint_talk_data.ps1)
5. [`scripts/build_checkpoint_outline_data.ps1`](../scripts/build_checkpoint_outline_data.ps1)
6. [`scripts/build_unknown_outline_candidates.ps1`](../scripts/build_unknown_outline_candidates.ps1)
7. [`scripts/test_checkpoint_prompt.ps1`](../scripts/test_checkpoint_prompt.ps1)
8. [`scripts/test_prompt_with_expected_questions.ps1`](../scripts/test_prompt_with_expected_questions.ps1)
9. [`scripts/test_checkpoint_classifier_from_outline.ps1`](../scripts/test_checkpoint_classifier_from_outline.ps1)
10. [`scripts/run_checkpoint_classification.ps1`](../scripts/run_checkpoint_classification.ps1)

## 7. 파일별 역할 요약

- [`data/CHECKPOINT_TALK_202508.csv`](../data/CHECKPOINT_TALK_202508.csv)
  - 상담 원본 데이터
- [`data/Domain_Code_Table.csv`](../data/Domain_Code_Table.csv)
  - 도메인 코드 매핑 테이블
- [`data/checkpoint_alias_map.csv`](../data/checkpoint_alias_map.csv)
  - 제목 또는 항목 별칭 정규화용 매핑
- [`data/checkpoint_talk_data.jsonl`](../data/checkpoint_talk_data.jsonl)
  - 분류기 입력용 JSONL
- [`data/CHECKPOINT_DOMAIN_260202.csv`](../data/CHECKPOINT_DOMAIN_260202.csv)
  - 도메인 분류 결과
- [`data/CHECKPOINT_OUTLINE_260202.csv`](../data/CHECKPOINT_OUTLINE_260202.csv)
  - 체크포인트별 질문 아웃라인
- [`data/CHECKPOINT_OUTLINE_SOURCE_260202.csv`](../data/CHECKPOINT_OUTLINE_SOURCE_260202.csv)
  - 아웃라인 생성 상세 출처
- [`data/CHECKPOINT_UNKNOWN_OUTLINE_CANDIDATES_260202.csv`](../data/CHECKPOINT_UNKNOWN_OUTLINE_CANDIDATES_260202.csv)
  - 미분류 후보 요약
- [`data/CHECKPOINT_UNKNOWN_OUTLINE_SOURCE_260202.csv`](../data/CHECKPOINT_UNKNOWN_OUTLINE_SOURCE_260202.csv)
  - 미분류 후보 상세 출처
- [`data/checkpoint_prompt.json`](../data/checkpoint_prompt.json)
  - 분류 프롬프트 설정
