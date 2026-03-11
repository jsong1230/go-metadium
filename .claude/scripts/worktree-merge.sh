#!/bin/bash
set -e

NO_DELETE=false
SQUASH=false
POSITIONAL=()

for arg in "$@"; do
  case $arg in
    --no-delete) NO_DELETE=true ;;
    --squash)    SQUASH=true ;;
    *)           POSITIONAL+=("$arg") ;;
  esac
done
set -- "${POSITIONAL[@]}"

FEATURE_NAME="${1:?기능명을 입력하세요}"
shift
MEMBERS=("$@")

if [ ${#MEMBERS[@]} -eq 0 ]; then
  echo "❌ 팀원을 하나 이상 지정하세요"
  exit 1
fi

TARGET_BRANCH=$(git branch --show-current)
MERGE_FAILED=()

for MEMBER in "${MEMBERS[@]}"; do
  BRANCH_NAME="feature/${FEATURE_NAME}-${MEMBER}"
  WORKTREE_PATH=".worktrees/${FEATURE_NAME}-${MEMBER}"

  echo "--- ${MEMBER} ---"

  if [ -d "$WORKTREE_PATH" ]; then
    cd "$WORKTREE_PATH"
    if [ -n "$(git status --porcelain)" ]; then
      git add -A
      git commit -m "feat: ${FEATURE_NAME} - ${MEMBER} 작업 완료"
    fi
    cd - > /dev/null
  fi

  MERGE_CMD="git merge"
  $SQUASH && MERGE_CMD="git merge --squash"

  if $MERGE_CMD "$BRANCH_NAME" -m "merge: feature/${FEATURE_NAME}-${MEMBER}" 2>/dev/null; then
    $SQUASH && git commit -m "feat: ${FEATURE_NAME} - ${MEMBER} (squash)"
    echo "  ✅ 머지 완료"

    # Prisma 마이그레이션 적용 (스키마 변경이 있을 때)
    if command -v npx &> /dev/null; then
      for PRISMA_DIR in . backend; do
        if [ -f "$PRISMA_DIR/prisma/schema.prisma" ]; then
          echo "  🗃️  Prisma 마이그레이션 확인 중..."
          (cd "$PRISMA_DIR" && npx prisma migrate deploy 2>/dev/null || true)
          break
        fi
      done
    fi

    if ! $NO_DELETE; then
      git worktree remove "$WORKTREE_PATH" 2>/dev/null || rm -rf "$WORKTREE_PATH"
      git branch -d "$BRANCH_NAME" 2>/dev/null || true
      echo "  🧹 정리 완료"
    fi
  else
    echo "  ❌ 머지 충돌! 브랜치($BRANCH_NAME)를 보존합니다."
    MERGE_FAILED+=("$MEMBER")
    git merge --abort 2>/dev/null || true
    # 충돌 시 브랜치와 worktree를 보존 (사용자가 직접 해결할 수 있도록)
    echo "  💡 수동 해결 후:"
    echo "     git merge $BRANCH_NAME"
    echo "     # 충돌 파일 수정 후:"
    echo "     git add -A && git commit -m 'merge: ${FEATURE_NAME}-${MEMBER} (conflict resolved)'"
    echo "     # 정리 (worktree-merge.sh가 중단되어 자동 정리 안 됨):"
    echo "     git worktree remove $WORKTREE_PATH"
    echo "     git branch -d $BRANCH_NAME"
    continue
  fi
done

echo "========================================="
if [ ${#MERGE_FAILED[@]} -eq 0 ]; then
  echo "✅ 모든 머지 완료!"
else
  echo "⚠️  머지 실패 (브랜치 보존됨): ${MERGE_FAILED[*]}"
  echo "   수동으로 충돌을 해결한 후 재시도하세요."
fi
echo ""
git log --oneline -10
