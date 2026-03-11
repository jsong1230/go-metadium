---
name: init-dev
description: >
  개발 환경 구성. devops-engineer를 호출하여 프로젝트 스캐폴딩 또는 기존 환경 구성.
  /init-project 완료 후 실행. 로컬 개발 서버 기동은 사용자가 명시적으로 요청한 경우에만 실행.
disable-model-invocation: true
---

개발 환경을 구성합니다.

## 로컬 개발 서버 규칙

**로컬 개발 서버 기동은 사용자가 명시적으로 요청한 경우에만 실행**. 기본 /init-dev는:
- 의존성 설치 (npm install 등)
- 환경변수 파일 생성 (.env.example → .env)
- DB 마이그레이션 (있는 경우)
- 디렉토리 구조 생성

서버 기동은 하지 않음. 사용자가 "서버 시작해줘"라고 요청하면 그때 실행.

## Step 1: 상태 확인

다음을 확인하여 동작을 결정합니다:
1. 소스 코드 파일 존재 여부
2. docs/system/system-design.md 존재 여부

**동작 결정:**
| 조건 | 동작 |
|------|------|
| 코드 없음 + system-design.md 있음 | 신규 스캐폴딩 |
| 코드 있음 | 기존 환경 구성 |
| system-design.md 없음 | "/init-project를 먼저 실행하세요" 안내 |

## Step 2-A: 신규 프로젝트 스캐폴딩

devops-engineer 에이전트 호출:
1. docs/system/system-design.md 읽기
2. 프로젝트 디렉토리 구조 생성
3. package.json / 의존성 파일 생성 및 설치
4. 로컬 DB docker-compose 구성
5. .env.example 생성 및 .env.local로 복사 (DB 연결 정보 자동 설정)
   - **Prisma CLI용 `.env` 도 함께 생성** (DATABASE_URL 포함):
     - Next.js 런타임은 `.env.local`을 읽고, Prisma CLI(`migrate`, `generate`, `studio`)는 `.env`만 읽음
     - 두 파일 모두 생성해야 `npm run db:migrate`가 정상 동작
6. CLAUDE.md 실행 방법 섹션 업데이트
7. 테스트 인프라 구성 (system-design.md 기술 스택 기반)
   - 테스트 러너 설치 (Jest/Vitest 등)
   - UI 포함 프로젝트: Playwright 설치 + `playwright.config.ts` 생성 + `npx playwright install`
   - E2E 테스트 디렉토리 생성 (예: `frontend/e2e/` 또는 `e2e/`)

## Step 2-B: 기존 프로젝트 환경 구성

devops-engineer 에이전트 호출:
1. 기존 설정 파일 확인
2. 의존성 설치 (`npm install` 등)
3. .env.example 기반 환경변수 가이드 제공
4. 테스트 인프라 확인 (playwright.config.ts 미존재 + UI 프로젝트 → Playwright 설치 + 설정 생성)

## Step 3: 완료 확인

- 의존성 설치 완료 확인
- 환경변수 파일 생성 확인:
  - `.env.local` 존재 확인 (Next.js 런타임용)
  - `.env` 파일 존재 확인 (Prisma CLI 호환 — DATABASE_URL 포함 여부)
- **Docker 설정 검증** (docker-compose.yml이 생성/수정된 경우):
  - `docker compose config` 실행 → YAML 문법 오류 없음 확인
  - DB 이미지 버전 메이저+마이너 명시 확인 (`postgres:16.6-alpine` 등, `latest`/메이저만 지정 금지)
  - DB/Redis healthcheck 정의 확인
  - `docker volume ls`로 기존 볼륨 목록 확인 → DB 버전 변경 시 볼륨 충돌 여부 대조
- **환경 검증** (docker-compose.yml이 생성/수정된 경우):
  1. `docker compose up -d` 실행 → 컨테이너 정상 기동 확인
  2. DB 마이그레이션 실행 (`npm run db:migrate` 또는 `npx prisma migrate dev --name init`) → 성공 확인
  3. DB 연결 테스트 (간단한 ping 쿼리 또는 마이그레이션 성공 여부로 확인)
  4. 실패 시: 오류 내용과 함께 중단 (사용자에게 보고)
- **Warning/Error 처리 기준**:
  - **Error**: 즉시 수정 또는 보고 후 중단
  - **Warning**: 수정하지 않고 목록으로 보고만 함 ("다음 경고가 있으나 런타임에 영향 없음")
- **테스트 인프라 검증** (UI 포함 프로젝트):
  - playwright.config.ts 존재 확인
  - E2E 디렉토리 존재 확인
  - `npx playwright test --list` → 정상 동작 확인
- "다음 단계: /design"

추가 지시사항: $ARGUMENTS
