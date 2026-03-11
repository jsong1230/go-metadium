---
name: fix
description: >
  경량 수정. 버그 수정, 단순 작업에 사용. 인자 필수 (수정 내용 지정).
  설계/태스크 생성 없이 직접 수정.
disable-model-invocation: true
---

경량 수정을 수행합니다. 복잡한 기능 개발은 /feat → /dev를 사용하세요.

## Step 1: 수정 범위 파악

1. 수정 내용 분석: $ARGUMENTS
2. 관련 파일 탐색 (Glob, Grep)
3. 수정 범위가 단순한지 확인:
   - 단순 버그 수정, 설정 변경, 텍스트 수정 → 직접 수정
   - 새 기능 추가, DB 스키마 변경, 여러 파일 대규모 수정 → /feat → /dev 사용 권장

## Step 2: 수정 실행

적절한 에이전트 직접 호출:
- backend/ 관련 → backend-dev
- frontend/ 관련 → frontend-dev
- 인프라 관련 → devops-engineer
- 두 곳 모두 → 각각 순차 호출

## Step 3: 검증

1. 관련 테스트 실행 (test-runner)
2. 빌드 에러 확인

## Step 4: 완료

- "수정 완료. /commit으로 커밋하세요" 안내

수정 내용: $ARGUMENTS
