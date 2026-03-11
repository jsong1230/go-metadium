---
name: init-claude-md
description: >
  CLAUDE.md 대화형 초기 설정.
  프로젝트 파일 자동 탐색 → 섹션별 질문 → CLAUDE.md 완성.
---

CLAUDE.md의 `{{placeholder}}`를 프로젝트에 맞게 대화형으로 채웁니다.

## Step 1: 프로젝트 파일 탐색

다음 파일들을 자동 탐색하여 기본값을 준비합니다:
- `package.json` — 프로젝트 이름, scripts, 의존성
- `requirements.txt` / `pyproject.toml` / `Pipfile` — Python
- `go.mod` / `Cargo.toml` / `build.gradle` / `pom.xml` — 기타 언어
- `docker-compose.yml` — DB, 캐시 등 인프라 서비스
- `tsconfig.json` / `jsconfig.json` — TS/JS 설정
- 디렉토리 구조 — 실제 프로젝트 레이아웃

## Step 2: 섹션별 대화형 질문

**중요:** 한꺼번에 모든 질문을 하지 말고, 섹션별로 순차 진행.

### 2.1 프로젝트 개요
- 프로젝트 이름 (package.json에서 추출, 없으면 디렉토리명)
- 프로젝트 설명 (한 줄 요약)
→ `{{PROJECT_NAME}}`, `{{한 줄 설명}}` 치환

### 2.2 기술 스택
탐색 결과를 기반으로 기본값 제안:
- Backend / Frontend / DB 카테고리별 제시
- "탐색 결과 이외에 사용/도입 예정인 기술이 있나요?"
- "사용하지 않는 카테고리가 있으면 알려주세요"
→ `{{기술}}` (Backend/Frontend/DB) 치환. 미사용 카테고리는 행 삭제.

### 2.3 디렉토리 구조
실제 디렉토리 탐색 → 현재 구조 제시 → 사용자 확인/수정
→ `디렉토리` 섹션 업데이트

### 2.4 실행 방법
package.json scripts 등에서 자동 추출:
- 개발 서버 (`npm run dev` 등)
- 테스트 (`npm test` 등)
- 빌드 (`npm run build` 등)
→ `{{dev command}}`, `{{test command}}`, `{{build command}}` 치환

### 2.5 프로젝트 관리 방식

선택지를 제시:
- **file** (기본값): plan.md 체크리스트 사용
- **jira**: Jira MCP로 이슈 관리
- **linear**: Linear MCP로 이슈 관리

#### jira 또는 linear 선택 시 — MCP 연결 확인

**Step A: settings.json 확인**
`.claude/settings.json`에 `enableAllProjectMcpServers: true`가 있는지 확인.
없으면 추가를 안내.

**Step B: .mcp.json 서버 키 확인**
프로젝트 루트 `.mcp.json`의 `mcpServers`에서 해당 서버 키 탐색:
- jira: `jira`, `atlassian` 등
- linear: `linear` 등

서버 키가 없으면 → Step D로 이동

**Step C: 연결 검증**
경량 MCP 호출로 실제 연결 테스트:
- Jira: 프로젝트 목록 조회
- Linear: 팀 목록 조회

성공 → CLAUDE.md에 기록:
  - 방식: jira (또는 linear)
  - 연결 확인: ✅
  프로젝트 키/팀 선택은 /init-project에서 진행됩니다.
실패(인증 오류, 네트워크 등) → Step D로 이동

**Step D: 미설정/실패 시 안내**

```
⚠️ {jira|linear} MCP 연결을 확인할 수 없습니다.

다음 단계에서 설정이 필요합니다:

[Jira — Atlassian Remote MCP]
1. claude mcp add --transport sse atlassian --scope project https://mcp.atlassian.com/v1/sse
2. bash .claude/scripts/sync-mcp-permissions.sh
3. Claude Code 재시작
4. /mcp 명령으로 서버 확인 → 브라우저에서 Atlassian OAuth 인증

[Linear]
1. claude mcp add --transport http linear --scope project https://mcp.linear.app/mcp
2. bash .claude/scripts/sync-mcp-permissions.sh
3. Claude Code 재시작
4. /mcp 명령으로 서버 확인 → 브라우저에서 OAuth 인증

→ CLAUDE.md에는 선택한 모드(jira/linear)를 기록하고 진행.
  `연결 확인: ⏳ (MCP 설정 후 /init-project에서 검증)`
```

→ `프로젝트 관리` 섹션 업데이트 (선택된 모드 + 연결 확인 완료 여부 포함)

## Step 3: CLAUDE.md 생성

1. 현재 CLAUDE.md 읽기
2. 모든 `{{...}}` placeholder를 사용자 답변으로 치환
3. 미사용 카테고리 행 삭제 (예: DB 없으면 DB 행 제거)
4. 결과를 사용자에게 보여주고 확인 후 저장

## Step 4: 완료 안내

```
✅ CLAUDE.md 설정 완료!

(jira/linear 선택 + 연결 미확인 시에만 표시)
⚠️ PM 도구 MCP 설정이 필요합니다:
  Jira:   claude mcp add --transport sse atlassian --scope project https://mcp.atlassian.com/v1/sse
  Linear: claude mcp add --transport http linear --scope project https://mcp.linear.app/mcp
  등록 후: bash .claude/scripts/sync-mcp-permissions.sh
Claude Code 재시작 → /mcp 명령으로 서버 확인 → 브라우저 OAuth 인증
상세: fullstack-agent-setup-v2.md Part 8 .mcp.json 섹션 참조

다음 단계:
1. (PM MCP 설정 완료 후) /init-project — 프로젝트 기획 + PM 프로젝트 연결
2. /init-dev → /design → /auto-dev
```

## 구현 가이드

- 섹션별 순차 진행: 2.1 → 2.2 → ... → 2.5 → Step 3
- 자동 탐색 우선: 파일에서 정보 추출하여 기본값 제안
- placeholder가 없는 CLAUDE.md: 내용 확인 후 필요 시에만 업데이트 제안

$ARGUMENTS는 무시합니다 (이 스킬은 인자를 받지 않음).
