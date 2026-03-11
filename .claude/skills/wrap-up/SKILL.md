---
name: wrap-up
description: >
  마무리. 미완성 문서 점검 + 최종 커밋. 기능 개발 완료 후 또는 세션 종료 전 실행.
disable-model-invocation: true
---

개발 세션을 마무리합니다.

## Step 1: 문서 점검

다음 문서가 최신 상태인지 확인합니다:

#### 전체 설계 문서 점검 (docs/system/)
- [ ] erd.md 존재 및 최신 상태
- [ ] design-system.md 존재 및 최신 상태
- [ ] api-conventions.md 존재 및 최신 상태
- [ ] navigation.md 존재 및 최신 상태
- [ ] wireframes/shell.html 존재 및 최신 상태
누락 시 → architect 또는 ui-designer에게 요청

### 사전 문서 (docs/specs/)
- [ ] 완료된 기능들의 design.md / change-design.md 존재 여부
- [ ] plan.md의 태스크가 모두 [x]로 완료 표시 여부

### 사후 기술 문서
- [ ] 완료된 기능들의 docs/api/ 문서 존재 여부
- [ ] 완료된 기능들의 docs/db/ 문서 존재 여부

### features.md
- [ ] 완료된 기능들의 상태가 "✅ 완료"인지

### 누락된 문서 처리
- API 문서 누락 → backend-dev에게 docs/api/ 작성 요청
- 기능 상태 미업데이트 → features.md 업데이트

## Step 2: CHANGELOG.md 작성

### 2-1. 데이터 수집

다음 소스를 읽어 CHANGELOG 작성에 필요한 정보를 수집한다:

1. **git log**: `git log --oneline --date-order` — 전체 커밋 이력
2. **roadmap.md**: `docs/project/roadmap.md` — 마일스톤 → 버전 매핑
3. **features.md**: `docs/project/features.md` — 기능 목록 및 완료 상태

### 2-2. 버전 구조 결정

roadmap.md의 마일스톤을 버전에 매핑한다:

| 마일스톤 | 버전 | 설명 |
|----------|------|------|
| Milestone 1 | 0.1.0 | 첫 번째 기능 마일스톤 |
| Milestone 2 | 0.2.0 | 두 번째 기능 마일스톤 |
| Milestone N | 0.N.0 | N번째 기능 마일스톤 |
| 미완료 기능 | [Unreleased] | 아직 마일스톤 미완료 |

> M0(프로젝트 기반 구축)은 CHANGELOG에 포함하지 않는다 (사용자 facing 변경 아님).
> 마일스톤 완료 날짜는 해당 마일스톤 마지막 커밋의 날짜를 사용한다.
> 각 커밋이 속하는 마일스톤은 커밋 메시지의 기능 ID(F-XX)와 features.md의 마일스톤 컬럼을 cross-reference하여 결정한다.
> 기능 ID가 없는 커밋(인프라, 배포 등)은 해당 작업의 성격에 맞는 마일스톤에 배치한다.

### 2-3. 커밋 분류

git log의 각 커밋을 Keep a Changelog 카테고리로 분류한다:

| prefix | 카테고리 | 설명 |
|--------|----------|------|
| `feat:` | **Added** | 새 기능 |
| `fix:` | **Fixed** | 버그 수정 |
| `refactor:`, `perf:` | **Changed** | 기존 기능 변경/개선 |
| 기능 제거 | **Removed** | 제거된 기능 |
| 보안 수정 | **Security** | 보안 관련 수정 |

> `docs:`, `test:`, `chore:` 커밋은 사용자 facing이 아니므로 제외.
> 단, 배포(`chore: Docker/CI/CD`), 헬스체크 엔드포인트 등 사용자에게 의미 있는 chore는 포함.
> 파이프라인 내부 fix (`fix(pipeline):`, `fix: [NNN]` 대괄호 번호 형식, 에이전트 동작 수정) 커밋은 사용자 facing이 아니므로 제외.

### 2-4. CHANGELOG 작성

Keep a Changelog 형식으로 CHANGELOG.md를 작성한다:

```
# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- ...

## [{버전}] - {YYYY-MM-DD}

### Added
- **{기능 ID} {기능명}**: {설명}
  - {세부 항목 1}
  - {세부 항목 2}

### Fixed
- {수정 내용}: {설명}

### Changed
- {변경 내용}: {설명}
```

규칙:
- 버전은 최신이 위, 과거가 아래
- 각 버전 사이에 `---` 구분선
- 기능은 features.md의 ID(F-01 등)와 이름을 포함
- 주요 feat 커밋은 기능별로 그룹화하여 기술
- fix 커밋 중 사용자 영향이 있는 것만 포함 (내부 파이프라인 fix는 제외)
- CHANGELOG.md가 없으면 신규 생성
- 기존 CHANGELOG.md가 있고 버전 체계가 동일하면 업데이트 (신규 버전/항목만 추가)
- 기존 CHANGELOG.md의 버전 체계가 다르면 (예: 기능 단위 vs 마일스톤 단위) 전면 재작성

### 2-5. 검증

- [ ] 모든 완료된 마일스톤이 버전으로 매핑되었는가
- [ ] 모든 사용자 facing feat 커밋이 Added에 포함되었는가
- [ ] 사용자 영향 fix 커밋이 Fixed에 포함되었는가
- [ ] 날짜가 실제 커밋 날짜와 일치하는가

## Step 3: 최종 커밋

/commit 흐름 실행 (미커밋 변경사항 모두 커밋)

## Step 4: 완료 안내

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
마무리 완료
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

이번 세션 완료 기능:
- {완료 기능 목록}

문서 상태: 모두 최신 / {누락 항목}

남은 기능:
- {다음 기능 목록}

다음 단계: git push / /auto-dev
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

추가 지시사항: $ARGUMENTS
