---
name: revise-design
description: 전체 설계 수정 스킬 — erd.md, design-system.md, api-conventions.md, navigation.md, wireframes/shell.html 수정
user-invocable: true
disable-model-invocation: true
---

# /revise-design — 전체 설계 수정

## 개요
/design으로 생성된 전체 설계 문서를 수정. 수정 후 영향받는 기능 설계(/feat 산출물)에 대한 cascade 경고 제공.

## 전제조건
다음 4개 핵심 문서가 존재해야 함 (/design 실행 완료 확인):
- `docs/system/erd.md`
- `docs/system/design-system.md`
- `docs/system/api-conventions.md`
- `docs/system/navigation.md`

없으면: "/design을 먼저 실행하세요."

`docs/system/wireframes/shell.html` 미존재 시: 수정이 아닌 **신규 생성**으로 처리 (ui-designer에게 생성 요청)

## Arguments
`/revise-design [변경 설명]` — 생략 시 대화형으로 수집

## 실행 흐름

### Step 1: 전제조건 확인
핵심 4개 문서 존재 확인. 없으면 중단.
wireframes/shell.html 미존재 시 → 사용자에게 신규 생성 여부 확인.

### Step 2: 변경 의도 수집
$ARGUMENTS 또는 대화형으로:
- 어떤 문서를 수정? (erd / design-system / api-conventions / navigation / wireframes/shell.html)
- 무엇을 왜 수정?

### Step 3: 변경 계획 제시 → 사용자 승인
```
수정 계획:
- [문서명]: [변경 내용]

이 변경으로 영향받을 수 있는 기능: [기능명 목록]
계속 진행하시겠습니까? (y/n)
```

### Step 4: 해당 에이전트로 문서 업데이트
- erd.md / api-conventions.md 변경 → architect
- design-system.md / navigation.md / wireframes/shell.html 변경 → ui-designer

### Step 5: Cascade 확인
변경된 문서가 이미 완료된 기능의 설계에 영향을 미치는지 확인:
- docs/specs/*/design.md에서 변경된 ERD/API 컨벤션 참조 확인
- docs/specs/*/ui-spec.md에서 변경된 디자인 시스템/네비게이션 참조 확인

영향 발견 시:
```
⚠️  Cascade 경고
다음 기능의 설계 문서가 영향받을 수 있습니다:
- {기능명}: {영향 내용}

/revise-feat {기능명}으로 각 기능의 설계를 업데이트하세요.
```

### Step 5.5: PM 도구 동기화

features.md 변경이 감지된 경우 (/revise-project 후 호출 등):

product-manager 에이전트 호출 (모드 3: 백로그 PM 동기화):
1. CLAUDE.md `프로젝트 관리` 섹션 확인
2. `file` 모드: 추가 작업 없음
3. `jira`/`linear` 모드:
   - 신규 기능 → Story/Issue 생성
   - 삭제된 기능 → Story/Issue 닫기
   - 수정된 기능 → Story/Issue 업데이트
   - 마일스톤 변경 → Epic(Jira) / Milestone(Linear) 업데이트
4. features.md PM ID 매핑 갱신

### Step 6: 완료
```
✅ 전체 설계 수정 완료
수정된 문서: [문서명]
cascade 영향 기능: [기능명] (→ /revise-feat 필요)
추가 조정이 필요하면 /revise-design을 다시 실행하세요.
```
