---
name: agent-routing
description: >
  에이전트 역할/라우팅 + 파이프라인 실행 가이드 참조 스킬. 자동 참조.
user-invocable: false
---

# 에이전트 라우팅 + 파이프라인 가이드

## 에이전트 10개 역할

### 프로젝트 기획 (/init-project, /revise-project)
- `project-planner` — PRD + features.md(인수조건) + roadmap 작성/수정
- `system-architect` — Greenfield: 시스템 설계 / Brownfield: 시스템 분석 / 조건부 업데이트

### 전체 설계 (/design, /revise-design)
- `architect` — ERD + API 컨벤션 (erd.md, api-conventions.md)
- `ui-designer` — 디자인 시스템 + 네비게이션 + 글로벌 와이어프레임 (design-system.md, navigation.md, wireframes/shell.html)

### 반복 (기능마다, /feat + /dev)
- `product-manager` — 백로그 관리 + 기능 선택 + 병렬 판단 + plan.md 작성
- `architect` — 기능 상세 설계 + 테스트 명세 (design.md / change-design.md). erd.md, api-conventions.md 참조
- `ui-designer` — UI 설계 + HTML 프로토타입 (ui-spec.md + wireframes/*.html). design-system.md, navigation.md 참조
- `backend-dev` — 백엔드 구현 + TDD GREEN + API/DB 문서
- `frontend-dev` — 프론트엔드 구현 + TDD GREEN + 컴포넌트 문서
- `test-runner` — RED(구현 전 실패 테스트) + 검증(구현 후 PASS 확인)
- `quality-gate` — 보안 + 성능 + 코드/설계/문서 리뷰 통합

### 온디맨드 (/init-dev, /deploy)
- `devops-engineer` — 프로젝트 스캐폴딩, 환경 구성, Docker/CI/CD 배포

## 파이프라인 Skills

**전체 흐름:** `/init-project → /init-dev → /design → /feat → /dev → /auto-dev → /test → /deploy`

### /init-project
프로젝트 상태 자동 감지:
- 코드 없음, 문서 없음 → 신규: planner → system-architect(설계)
- 코드 있음, system 문서 없음 → Brownfield: system-architect(분석) → planner(기능 정리)
- system-design.md 존재 → 리뉴얼: system-architect(재분석) → planner(신규 features 추가)

### /init-dev
- 신규: system-design.md 기반 스캐폴딩 + 의존성 + 로컬 서버
- 기존: 의존성 설치 + 환경변수 + 로컬 서버 확인

### /design
- architect → erd.md + api-conventions.md (ERD, API 컨벤션)
- ui-designer → design-system.md + navigation.md + wireframes/shell.html (디자인 시스템, 네비게이션, 글로벌 레이아웃 와이어프레임)
- /init-dev 이후, /feat 이전 1회 실행

### /feat (구 /spec)
0. product-manager → 다음 기능 추천 (인자 없는 경우)
1. architect → design.md (GF) / change-design.md (BF) + 테스트 명세. erd.md, api-conventions.md 참조
2. ui-designer → ui-spec.md + wireframes/*.html (프론트엔드 변경 시). design-system.md, navigation.md 참조
3. product-manager → plan.md (태스크 분해)

### /dev (TDD: RED → GREEN → REFACTOR)
1. 태스크 → In Progress
2. test-runner → 실패하는 테스트 작성 (RED)
3. Agent Team (worktree 병렬):
   - backend-dev → 테스트 PASS하도록 구현 (GREEN)
   - frontend-dev → 테스트 PASS하도록 구현 (GREEN)
4. worktree-merge.sh
5. quality-gate → 보안 + 성능 + 코드 리뷰 (REFACTOR)
6. 태스크 → Done

### /revise-project
프로젝트 기획 조정 (/init-project 후):
- 변경 의도 파악 → 승인 → project-planner(수정) → system-architect(조건부)

### /revise-design
전체 설계 수정 (/design 후):
- 변경 의도 파악 → 승인 → architect/ui-designer → cascade: 영향받는 기능의 /revise-feat 안내

### /revise-feat (구 /revise-spec)
기능 설계 조정 (/feat 후):
- 변경 의도 파악 → 승인 → architect/product-manager/ui-designer → cascade 시 project-planner

### /auto-dev
product-manager가 백로그에서 다음 기능 추천 → /feat → /dev 반복 (병렬 배치 포함)

### /test
전체 프로젝트: 단위 + 통합 + E2E + 회귀 테스트 실행

### /deploy
devops-engineer → Docker/CI/CD/클라우드 배포

### /fix
경량 수정 → 태스크 등록 → 수정 → 완료

### /commit
변경사항 분석 → 논리적 단위로 분리 → Conventional Commits

### /wrap-up
문서 점검(미완성 문서 확인) + 최종 커밋
