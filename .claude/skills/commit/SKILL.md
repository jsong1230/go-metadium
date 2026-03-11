---
name: commit
description: >
  Git 커밋 자동화. 변경사항 분석 후 논리적 단위로 분리하여 커밋.
  인자로 커밋 메시지 힌트 제공 가능.
disable-model-invocation: true
---

변경사항을 분석하고 Git 커밋을 생성합니다.

## Step 1: 변경사항 확인

```
git status
git diff
git diff --staged
```

## Step 2: 논리적 단위로 분리

변경사항을 다음 카테고리로 분류:
- 구현 코드 (feat: / fix: / refactor:)
- 설계 문서 (docs/specs/) (docs:)
- 기술 문서 (docs/api/, docs/db/, docs/components/) (docs:)
- 테스트 코드 (test:)
- 인프라/설정 (chore:)

## Step 3: 커밋 메시지 작성

Conventional Commits + 한국어 본문:
- `feat: 사용자 인증 API 구현`
- `docs: 사용자 인증 설계서 작성`
- `docs: 사용자 인증 API 스펙 확정`
- `test: 사용자 인증 테스트 추가`

## Step 4: 사용자 확인 후 커밋 실행

커밋 계획을 보여주고 사용자 확인 후 실행

> **git add 주의**: 특정 파일 제외 시 `git add -A -- ':!.env.local'` 문법은 zsh에서 오류 발생.
> 올바른 방법: `git add . && git restore --staged .env.local`

## Step 5: 완료 안내

- ⚠️ push 안내: `git push`로 원격에 반영하세요

추가 지시사항: $ARGUMENTS
