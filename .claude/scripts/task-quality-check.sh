#!/usr/bin/env bash
# TaskCompleted 훅: 태스크 완료 전 품질 게이트
# TypeScript 타입 오류 또는 테스트 실패 시 exit 2로 완료 차단

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
FAILED=0

cd "$PROJECT_DIR" || exit 0

# TypeScript 타입 체크 (tsconfig.json이 있는 경우)
if [ -f "tsconfig.json" ]; then
  echo "🔍 TypeScript 타입 체크..."
  if ! npx tsc --noEmit 2>&1; then
    echo "❌ TypeScript 오류 발견 — 태스크 완료 차단"
    FAILED=1
  else
    echo "✅ TypeScript 타입 체크 통과"
  fi
fi

# 테스트 실행 (package.json에 test 스크립트가 있는 경우)
if [ -f "package.json" ] && grep -q '"test"' package.json; then
  echo "🔍 테스트 실행..."
  if ! npm test -- --run 2>&1; then
    echo "❌ 테스트 실패 — 태스크 완료 차단"
    FAILED=1
  else
    echo "✅ 테스트 통과"
  fi
fi

if [ $FAILED -eq 1 ]; then
  echo ""
  echo "품질 게이트 실패: 위의 오류를 수정한 후 다시 시도하세요."
  exit 2
fi

echo "✅ 품질 게이트 통과"
exit 0
