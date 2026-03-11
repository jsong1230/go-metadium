---
name: conventions
description: >
  코딩 컨벤션 + Git 규칙 참조 스킬. 관련 작업 시 자동 참조.
user-invocable: false
---

# 코딩 컨벤션 + Git 규칙

## 코딩 컨벤션
- 한국어 주석, 영어 변수명
- 함수형 컴포넌트 + React Server Components 우선
- API 응답 형식: `{ success: boolean, data?: T, error?: string }`
- 에러 핸들링: 커스텀 AppError 클래스 사용
- TypeScript strict mode 준수
- any 타입 금지 / console.log 금지 / 하드코딩 금지

## Git 규칙
- 커밋 메시지: Conventional Commits + 한국어 본문
  - feat: / fix: / refactor: / test: / docs: / chore:
- 하나의 논리적 단위 = 하나의 커밋
- 구현 코드 / 설계 문서 / 기술 문서는 별도 커밋으로 분리
- 작업 브랜치: feature/{기능명}, fix/{이슈명}
- 커밋 전 반드시 테스트 통과 확인
- /auto-dev만 자동 push. 나머지는 커밋 후 사용자가 직접 push

## Git Worktree 규칙 (Agent Team 병렬 작업 시)
- 병렬 작업 시 `.worktrees/` 하위에 팀원별 worktree 생성
- 각 팀원은 자신의 worktree에서만 작업
- 작업 완료 후 main으로 merge → worktree 삭제
- `.worktrees/`는 .gitignore에 포함됨
