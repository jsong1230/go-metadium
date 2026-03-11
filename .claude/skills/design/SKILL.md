---
name: design
description: 전체 설계 스킬 — DB ERD, UI 디자인 시스템, API 컨벤션, 네비게이션/라우팅 구조 설계
user-invocable: true
disable-model-invocation: true
---

# /design — 전체 설계

## 개요
프로젝트 전체의 설계 기준을 수립하는 스킬. `/init-dev` 완료 후, `/feat` 시작 전 **1회** 실행.
기능별 설계(/feat)의 일관성 기준이 되는 5개 문서를 생성.

## 전제조건
다음 중 하나 이상 존재해야 함:
- `docs/system/system-design.md` (신규 프로젝트)
- `docs/system/system-analysis.md` (기존 프로젝트)
- `docs/project/features.md`

없으면: "/init-project를 먼저 실행하세요."

## 산출물 (docs/system/)
| 문서 | 담당 에이전트 | 내용 |
|---|---|---|
| `erd.md` | architect | DB 엔티티 관계도 + 테이블 개요 |
| `design-system.md` | ui-designer | 디자인 가이드 + 색상/타이포/컴포넌트/레이아웃 토큰 |
| `api-conventions.md` | architect | 응답 포맷/인증 패턴/버전 체계/에러 코드 |
| `navigation.md` | ui-designer | 전체 화면 흐름 + 라우팅 구조 |
| `wireframes/shell.html` | ui-designer | 글로벌 레이아웃 와이어프레임 (셸 구조) |

## 실행 흐름

### Step 1: 전제조건 확인
- system-design.md 또는 system-analysis.md + features.md 존재 확인
- 없으면 중단 + /init-project 안내

### Step 2: 프로젝트 타입 판단
- `docs/system/system-design.md` 존재 → **신규 프로젝트 모드**
- `docs/system/system-analysis.md` 존재 → **기존 프로젝트 모드**

### Step 3: architect → `docs/system/erd.md`
- 신규: features.md 기반 전체 엔티티 + 관계 설계 (Mermaid ERD)
- 기존: 현재 스키마 분석 + 변경/추가 엔티티 계획

### Step 4: ui-designer → `docs/system/design-system.md`
- 신규: 디자인 철학·무드·레퍼런스 정의 → 색상 팔레트, 타이포그래피, 스페이싱, 컴포넌트 스타일 설계
- 기존: 기존 UI 패턴 분석 → 디자인 철학 정리 + 통일된 디자인 시스템 정의

### Step 5: architect → `docs/system/api-conventions.md`
- 신규: API 응답 포맷, 인증 패턴, 버전 체계, 에러 코드 설계
- 기존: 기존 API 패턴 분석 + 컨벤션 표준화

### Step 6: ui-designer → `docs/system/navigation.md`
- 신규: 전체 화면 목록, URL 구조, 네비게이션 흐름도 (Mermaid)
- 기존: 기존 라우팅 분석 + 변경/추가 계획

### Step 6.5: ui-designer → `docs/system/wireframes/shell.html`
- navigation.md 기반으로 전체 레이아웃 셸 HTML 프로토타입 생성
- 헤더, 사이드바/네비게이션, 메인 콘텐츠 영역, 푸터 구조
- 반응형 (모바일 375px + 데스크톱 1280px) 포함
- Tailwind CSS CDN + Vanilla JS
- 신규: 전체 레이아웃 신규 설계
- 기존: 기존 레이아웃 분석 + 재현

### Step 7: 사용자 리뷰
5개 문서 완성 후 요약 제시:
```
✅ 전체 설계 완료
- erd.md: {엔티티 수}개 테이블
- design-system.md: {색상/타이포/컴포넌트 토큰 수}개 토큰
- api-conventions.md: {API 패턴} 정의
- navigation.md: {화면 수}개 화면
- wireframes/shell.html: 레이아웃 셸 프로토타입
- PM 등록: {모드} — Jira: {Epic 수}개 Epic + {Story 수}개 Story / Linear: {Milestone 수}개 Milestone + {Issue 수}개 Issue

수정이 필요하면 /revise-design을 사용하세요.
다음 단계: /auto-dev 또는 /feat {기능명}
```

### Step 7.1: 완료 검증 (자체 체크)

5개 문서 완성 후 자동 검증:
- 5개 문서 모두 존재: `erd.md`, `design-system.md`, `api-conventions.md`, `navigation.md`, `wireframes/shell.html`
- `erd.md` — features.md의 각 기능(F-01~F-NN)을 처리할 테이블/관계 커버 여부
- `navigation.md` — features.md의 각 기능에 대응하는 화면 경로 포함 여부
- `wireframes/shell.html` — Desktop/Mobile 토글 버튼 포함 여부
- 검증 결과를 사용자에게 보고: ✅ 커버됨 / ⚠️ 미커버 항목 있으면 수정 제안

### Step 7.5: 1차 태스크 세분화 + PM 도구 등록

> **PM 도구 연동 시**: M0(프로젝트 기반 구축) 마일스톤이 있으면 → 완료 처리
> - Linear: `targetDate`를 오늘 날짜로 설정 (Linear 마일스톤은 별도 Done 상태가 없고 연결 이슈 기반 자동 계산. M0는 연결 이슈가 없으므로 targetDate로 도달 시점 마킹)
> - Jira: Epic → Done으로 상태 변경

product-manager 에이전트 호출 (모드 3: 백로그 PM 등록):
1. docs/project/features.md + roadmap.md 읽기
2. CLAUDE.md의 `프로젝트 관리` 섹션 확인 (file / jira / linear)
   - file → PM 등록 건너뜀
   - jira/linear → MCP 연결 테스트 후 진행
     - 연결 실패 시: "PM 도구에 연결할 수 없어 PM 등록을 건너뜁니다. 나중에 수동으로 등록하거나 /init-project를 다시 실행하세요." 경고 후 계속 진행
3. PM 도구 등록:
   - `file` 모드: features.md 체크리스트 그대로 사용 (추가 작업 없음)
   - `jira` 모드: 마일스톤 → Epic, 기능 → Story 생성 (MCP 미응답 시 file fallback)
   - `linear` 모드: 마일스톤 → Milestone, 기능 → Issue 생성 (MCP 미응답 시 file fallback)
4. features.md에 PM 도구 ID 매핑 주석 추가 (예: `<!-- JIRA:PROJ-123 -->` 또는 `<!-- LINEAR:ISSUE-abc123 -->`)

## 주의사항
- 이 스킬은 /feat 이전에 1회만 실행 (이미 존재하면 /revise-design 사용)
- 5개 문서 모두 완성 후에만 완료 처리
- 기존 docs/system/erd.md 존재 시: "/design이 이미 실행된 것 같습니다. 수정이 필요하면 /revise-design을 사용하세요."
