---
name: doc-rules
description: >
  문서 체계 + 문서화 규칙 참조 스킬. 문서 작업 시 자동 참조.
user-invocable: false
---

# 문서 체계 + 문서화 규칙

## 프로젝트 디렉토리 골격

파이프라인이 관리하는 고정 구조. 소스 코드 디렉토리(`{frontend}/`, `{backend}/` 등)는 기술 스택에 따라 다르며 `docs/system/system-design.md` (또는 `system-analysis.md`) § 3에서 정의.

```
{프로젝트}/
├── .claude/                      # Claude Code 설정
│   ├── agents/                   # 커스텀 에이전트
│   ├── skills/                   # 스킬 (task + reference)
│   ├── scripts/                  # worktree-setup.sh, worktree-merge.sh
│   └── settings.json
├── .worktrees/                   # Agent Team 병렬 작업용 (.gitignore됨)
│   ├── {기능명}-backend/         # backend-dev worktree
│   └── {기능명}-frontend/        # frontend-dev worktree
├── docs/
│   ├── project/                  # 1단계: 프로젝트 기획
│   ├── system/                   # 2단계: 시스템 레벨 + 2.5단계: 전체 설계
│   ├── specs/{기능명}/           # 3단계: 기능별 사전 문서
│   ├── api/                      # 4단계: 사후 문서 — API
│   ├── db/                       # 4단계: 사후 문서 — DB
│   ├── components/               # 4단계: 사후 문서 — 컴포넌트 (선택)
│   ├── tests/{기능명}/           # 품질 검증 + 테스트 결과
│   └── infra/                    # 인프라 문서
├── CLAUDE.md
└── CHANGELOG.md
```

## 4단계 문서 라이프사이클

### 1단계: 프로젝트 기획 문서 (프로젝트 시작 시)
- `docs/project/prd.md` — PRD (project-planner)
- `docs/project/features.md` — 기능 백로그 + 인수조건 (project-planner)
- `docs/project/roadmap.md` — 마일스톤 로드맵 (project-planner)

### 2단계: 시스템 레벨 문서 (init-project 시 1회)
**Greenfield:**
- `docs/system/system-design.md` — 시스템 아키텍처 설계 (system-architect)

**Brownfield:**
- `docs/system/system-analysis.md` — 시스템 분석 (system-architect)

### 2.5단계: 전체 설계 문서 (docs/system/) — /design 스킬 산출물
- 작성 시점: /init-dev 완료 후, /feat 시작 전 (1회)
- 담당: architect (ERD, API 컨벤션), ui-designer (디자인 시스템, 네비게이션, 글로벌 와이어프레임)
- 목적: 기능 단위 설계의 일관성 기준 제공
- 문서:
  - `docs/system/erd.md` — DB 엔티티 관계도 + 테이블 개요
  - `docs/system/design-system.md` — 디자인 가이드 + 색상/타이포/컴포넌트/레이아웃 토큰
  - `docs/system/api-conventions.md` — 응답 포맷/인증 패턴/버전 체계/에러 코드
  - `docs/system/navigation.md` — 전체 화면 흐름 + 라우팅 구조
  - `docs/system/wireframes/shell.html` — 글로벌 레이아웃 와이어프레임 (셸 구조)
- 규칙: /feat 스킬은 이 5개 문서를 반드시 참조

### 3단계: 기능 레벨 사전 문서 (구현 전, /feat 시)
**Greenfield:**
- `docs/specs/{기능명}/design.md` — 기능 상세 설계 (architect). erd.md, api-conventions.md, design-system.md, navigation.md 참조
- `docs/specs/{기능명}/test-spec.md` — 테스트 명세 (architect)
- `docs/specs/{기능명}/ui-spec.md` — UI 설계서 (ui-designer, 프론트엔드 변경 시). design-system.md, navigation.md 참조
- `docs/specs/{기능명}/wireframes/*.html` — HTML 프로토타입 (ui-designer, 프론트엔드 변경 시)
- `docs/specs/{기능명}/plan.md` — 구현 태스크 목록 (product-manager)

**Brownfield:**
- `docs/specs/{기능명}/change-design.md` — 변경 설계 + 영향 분석 (architect). erd.md, api-conventions.md 참조
- `docs/specs/{기능명}/test-spec.md` — 테스트 명세 (architect)
- `docs/specs/{기능명}/ui-spec.md` — UI 설계서 (ui-designer, 프론트엔드 변경 시). design-system.md, navigation.md 참조
- `docs/specs/{기능명}/wireframes/*.html` — HTML 프로토타입 (ui-designer, 프론트엔드 변경 시)
- `docs/specs/{기능명}/plan.md` — 구현 태스크 목록 (product-manager)

### 4단계: 사후 기술 문서 (구현 직후, 코드와 100% 일치)
- `docs/api/{기능명}.md` — API 스펙 확정본 (backend-dev)
- `docs/db/{기능명}.md` — DB 스키마 확정본 (backend-dev)
- `docs/components/{컴포넌트명}.md` — 컴포넌트 문서 (frontend-dev, 선택)
- `docs/tests/{기능명}/{timestamp}.md` — 테스트 + QG 검증 결과 (test-runner + quality-gate)
- `docs/tests/full-report-{date}.md` — 전체 프로젝트 테스트 결과 (/test 시)

## 에이전트별 문서 책임
| 에이전트 | 작성 문서 |
|----------|-----------|
| project-planner | prd.md, features.md, roadmap.md |
| system-architect | system-design.md 또는 system-analysis.md |
| architect | design.md, change-design.md, test-spec.md, erd.md, api-conventions.md (/design) |
| ui-designer | ui-spec.md, wireframes/*.html, design-system.md, navigation.md (/design) |
| product-manager | plan.md |
| backend-dev | docs/api/, docs/db/ |
| frontend-dev | docs/components/ (선택) |
| test-runner | docs/tests/{기능명}/, full-report-*.md |
| quality-gate | docs/tests/{기능명}/ (QG 결과 append) |
| /wrap-up (스킬) | CHANGELOG.md |

## Greenfield vs Brownfield 비교
| 항목 | Greenfield | Brownfield |
|------|-----------|-----------|
| 시스템 레벨 | system-design.md | system-analysis.md |
| 기능 레벨 | design.md | change-design.md |
| 영향 분석 | 불필요 | 필수 |
| 회귀 테스트 | 불필요 | 필수 |
