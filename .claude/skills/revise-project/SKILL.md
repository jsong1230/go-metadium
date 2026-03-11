---
name: revise-project
description: >
  프로젝트 기획 문서(PRD/기능 백로그/로드맵) 조정.
  /init-project 완료 후 요구사항 변경이 필요할 때 사용.
disable-model-invocation: true
---

## 현재 기획 상태 (자동 주입)
!`head -20 docs/project/features.md 2>/dev/null || echo "features.md 없음 - /init-project 먼저 실행"`

## Step 0: 전제조건 확인
- docs/project/prd.md 존재 확인
- 없으면 → "/init-project를 먼저 실행하세요" 안내 후 종료

## Step 1: 현재 상태 파악 + 변경 의도 수집
1. docs/project/prd.md, features.md, roadmap.md 읽기
2. 현재 기획 요약 제시
3. $ARGUMENTS 또는 대화를 통해 변경 의도 파악

변경 유형:
| 유형 | 영향 문서 |
|------|-----------|
| 기능 추가/제거/수정 | prd + features + roadmap |
| 우선순위/마일스톤 변경 | features + roadmap |
| 기술/아키텍처 변경 | prd + system-design |

## Step 2: 변경 계획 제시 → 사용자 승인
- 변경 사항 목록 + 영향 문서 정리
- 이미 설계 완료된 기능(docs/specs/ 존재) 영향 시 경고
- 사용자 승인 후 진행

## Step 3: 문서 업데이트

### project-planner 에이전트 호출 (수정 모드)
- prd.md + features.md + roadmap.md 업데이트

### system-architect 에이전트 호출 (조건부)
- 기술/아키텍처 변경 시에만 system-design.md 업데이트

## Step 4: 결과 제시 + 추가 조정
- 변경 요약 제시
- "추가 조정이 있으면 계속, 완료되면 확정"
- 확정 시 → "다음 단계: /init-dev 또는 /feat" 안내

## Step 5: Cascade 안내
변경된 PRD/features.md가 전체 설계나 기능 설계에 영향을 미치는지 확인:

**전체 설계 영향** (features.md의 기능 범위나 기술 스택 변경):
"⚠️ 전체 설계 영향 감지
변경된 기능 범위/요구사항이 전체 설계에 영향을 줄 수 있습니다.
→ /revise-design으로 설계 문서 검토 + PM 도구 동기화를 진행하세요.
  예: /revise-design revise-project로 인한 변경분 반영"

**features.md만 변경** (설계 영향 없어도 PM 동기화 필요):
"⚠️ features.md가 변경되었습니다 (기능 추가/취소/보류 포함).
PM 도구 동기화를 위해 → /revise-design pm-sync를 실행하세요."

**기능 설계 영향** (특정 기능의 인수조건 변경):
"⚠️ 기능 설계 영향 감지
다음 기능의 설계가 영향받을 수 있습니다: {기능명}
→ /revise-feat {기능명}으로 design.md, ui-spec.md 업데이트하세요."

추가 지시사항: $ARGUMENTS
