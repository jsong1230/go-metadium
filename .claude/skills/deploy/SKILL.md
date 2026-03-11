---
name: deploy
description: >
  배포. devops-engineer를 호출하여 Docker/CI/CD/클라우드 배포.
  신규/기존 프로젝트 타입에 따라 배포 전략 분기.
disable-model-invocation: true
---

배포를 수행합니다.

## 프로젝트 타입 판단

- docs/system/system-design.md 존재 → 신규 프로젝트
- docs/system/system-analysis.md 존재 → 기존 프로젝트

## 실행 흐름

### Step 1: 배포 전 검증 (공통)
- 테스트 전체 통과 확인 (npm test)
- 빌드 성공 확인 (npm run build)
- 환경변수 확인 (.env.example ↔ 실제 환경변수)
- **Docker 설정 검증** (Dockerfile / docker-compose.yml 있는 경우):
  - `docker compose config` 실행 → YAML 문법 오류 없음 확인
  - Dockerfile에 BuildKit 캐시 마운트(`--mount=type=cache`) 사용 여부 확인
  - DB 이미지 버전 메이저+마이너 명시 확인 (`latest`/메이저만 지정 시 배포 중단 후 수정)
  - DB/Redis healthcheck 정의 여부 확인

### Step 2: 인프라 구성
- **신규 프로젝트**: devops-engineer가 Docker 컨테이너 + CI/CD 파이프라인 신규 구축
- **기존 프로젝트**: devops-engineer가 기존 인프라 분석 + 변경 영향 확인 + 롤백 계획 수립

### Step 3: 스테이징 배포
- devops-engineer: 스테이징 환경 배포
- 헬스체크 (API /health 또는 메인 URL)
- 기존 프로젝트: 기존 기능 정상 동작 확인

### Step 4: 프로덕션 배포 (사용자 확인 후)
사용자에게 확인 요청:
"스테이징 확인이 완료되었습니다. 프로덕션 배포를 진행할까요? (y/n)"
승인 후:
- **신규 프로젝트**: 프로덕션 배포
- **기존 프로젝트**: 롤백 절차 준비 후 프로덕션 배포

### Step 5: 배포 후 확인
- 헬스체크 + 기본 동작 확인
- **기존 프로젝트**: 기존 기능 정상 동작 확인
- docs/infra/{topic}.md 업데이트
- **PM 도구 연동 시**: 배포(M-last) 마일스톤 → Done으로 갱신

## 배포 환경: $ARGUMENTS
