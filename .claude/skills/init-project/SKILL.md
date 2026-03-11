---
name: init-project
description: >
  프로젝트 초기화. 상태를 자동 감지하여 신규/기존 프로젝트 타입 결정.
  기획 + 시스템 설계/분석만 수행. 환경 구성은 /init-dev에서.
disable-model-invocation: true
---

프로젝트 상태를 자동 감지하여 적절한 초기화를 수행합니다.

## Step 0: PM 도구 연결 확인

CLAUDE.md의 `프로젝트 관리` 섹션 확인:

| 방식 | 처리 |
|------|------|
| `file` (또는 미설정) | → Step 1로 진행 |
| `jira` / `linear` | → 아래 검증 수행 |

### 0-1. MCP 연결 검증

경량 MCP 호출로 연결 테스트:
- Jira: 프로젝트 목록 조회
- Linear: 팀 목록 조회

실패 시:
```
⚠️ {jira|linear} MCP에 연결할 수 없습니다.
설정을 확인하세요:
1. .env — API 토큰
2. .mcp.json — 서버 설정
3. Claude Code 재시작 여부

어떻게 할까요?
  1. file 모드로 전환 후 진행
  2. 중단 (MCP 설정 후 재실행)
```

### 0-2. PM 프로젝트 선택/생성

[Jira]
1. MCP로 프로젝트 목록 조회
2. 사용자에게 선택지 제시:
   - 기존 프로젝트 목록에서 선택
   - 신규 프로젝트 생성 (프로젝트 이름, 키 입력 → MCP로 생성)
3. CLAUDE.md에 프로젝트 키 기록: `프로젝트 키: PROJ`

[Linear]
1. MCP로 팀 목록 조회 → 사용자에게 팀 선택
2. 선택한 팀의 Project 목록 조회
3. 사용자에게 선택지 제시:
   - 기존 Project에서 선택
   - 신규 Project 생성 (이름 입력 → MCP로 생성)
4. CLAUDE.md에 팀 slug + Project ID 기록: `팀: team-slug`, `프로젝트: project-id`

→ CLAUDE.md 업데이트:
  - 연결 확인: ✅
  - 프로젝트 키/팀 정보 기록

### 0-3. 완료 → Step 1로 진행

## Step 1: 프로젝트 타입 감지

다음을 확인하여 타입을 결정합니다:
1. 소스 코드 파일 존재 여부 (frontend/, backend/, src/ 등)
2. 기존 운영 코드베이스 여부

**타입 결정:**
| 조건 | 타입 |
|------|------|
| 코드 없음 (또는 참조용 코드만 있고 직접 빌드 예정) | 신규 프로젝트 |
| 이미 운영 중인 코드베이스가 있음 | 기존 프로젝트 |

감지된 타입을 사용자에게 알리고 확인을 받습니다.

## Step 2-A: 신규 프로젝트

### 사전 대화 (project-planner 호출 전)
에이전트가 직접 사용자와 대화하여 요구사항을 수집합니다:

1. 유사 서비스/앱의 일반적인 기능 목록을 제안하고 사용자에게 선택/추가/제외 요청
   - 예: "날씨 앱에는 보통 이런 기능이 있어요: 도시 검색, 현재 날씨, 5일 예보, 즐겨찾기... 어떤 기능이 필요하세요?"
   - 사용자가 미처 생각하지 못한 기능을 유사 앱 사례 기반으로 제안
2. **외부 API/서비스 필요 여부 확인 및 선택지 제시** (에이전트 임의 결정 금지):
   - 외부 의존성 후보를 제시하고 사용자 선택을 받은 후 진행
   - 예: "날씨 데이터 API로 OpenWeatherMap 사용을 고려 중입니다. 다른 API를 원하시면 알려주세요: WeatherAPI.com, AccuWeather, Open-Meteo 등"
3. 핵심 기능 및 기술 의존성 확정 → 대화 결과를 project-planner에 전달

### project-planner 에이전트 호출
1. 사전 대화 결과(확정된 기능 목록 + 외부 의존성) 전달
2. docs/project/prd.md 작성
3. docs/project/features.md 작성 (인수조건 포함)
4. docs/project/roadmap.md 작성

### system-architect 에이전트 호출 (신규 설계)
1. prd.md 기반으로 시스템 아키텍처 설계
2. docs/system/system-design.md 신규 작성
3. 참조용 코드가 있으면 참조 분석 모드로 기존 코드 패턴 반영

## Step 2-B: 기존 프로젝트

### system-architect 에이전트 호출 (기존 코드 분석)
1. 기존 코드베이스 전체 분석
2. docs/system/system-analysis.md 작성

### project-planner 에이전트 호출 (변경/추가 목적)
1. system-analysis.md 기반으로 변경/추가 목적 정리
2. docs/project/features.md 작성 (변경 기능만)
3. docs/project/roadmap.md 작성

## Step 3: 사용자 검토 및 조정

### 3-1. 문서 요약 제시
- PRD 핵심 (프로젝트 개요, 핵심 기능, 기술 스택)
- 기능 백로그 전체 테이블 (features.md)
- 마일스톤 구조 (roadmap.md)
- 시스템 설계 개요 (system-design.md, 신규인 경우)
- **외부 의존성 목록** (별도 섹션으로 하이라이트):
  - 사용 예정인 외부 API/서비스 목록 제시
  - "이 외부 서비스를 사용하는 것이 맞는지" 명시적으로 확인 요청
  - 예: "외부 의존성: OpenWeatherMap API — 변경을 원하시면 지금 알려주세요"

### 3-2. 피드백 루프
사용자가 "확정"이라 할 때까지 반복:

1. 사용자 피드백 수집 (자유 대화)
   - 기능 추가/삭제/수정, 우선순위 변경, 인수조건 수정, 마일스톤 재배치
2. project-planner 에이전트 호출 (수정 모드)
3. system-architect 에이전트 호출 (기술/아키텍처 변경 시에만)
4. 변경 결과 요약 제시 → "추가 조정 또는 확정?"

### 3-3. 확정 후 PM 등록 + 완료 검증 + 안내

PM 도구가 `linear` 또는 `jira`인 경우 (CLAUDE.md `프로젝트 관리` 섹션 확인):
- product-manager 에이전트 호출 (모드 3: 초기 등록)
  - 마일스톤 + 기능 이슈 생성
  - **생성된 이슈 ID를 features.md 각 기능 행에 역기록**: `<!-- LINEAR:ISSUE-ID -->` 또는 `<!-- JIRA:PROJ-123 -->`
  - 역기록이 없으면 /feat, /dev 단계에서 PM 도구 상태 동기화 불가

**완료 검증 (자체 체크)**:
- docs/project/prd.md Section 2(핵심 기능 요약) ↔ features.md 기능 목록 동기화 여부
- features.md에 인프라/횡단 관심사 항목 혼입 없음 (에러 처리, 로깅, CI/CD 등)
- features.md의 모든 기능에 인수조건이 있음
- PM 모드가 linear/jira인 경우: features.md 각 행에 PM ID 주석 (`<!-- LINEAR:... -->`) 있음
- 검증 결과 요약 보고 (⚠️ 항목 있으면 수정 제안)

안내:
- "나중에 기획 조정: /revise-project"
- "다음 단계: /init-dev → /design"

추가 지시사항: $ARGUMENTS
