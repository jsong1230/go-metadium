#!/usr/bin/env bash
# PreCompact 훅: context compaction 직전 파이프라인 상태를 .claude/.pipeline-state에 저장

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_FILE="$PROJECT_DIR/.claude/.pipeline-state"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
BRANCH=$(cd "$PROJECT_DIR" && git branch --show-current 2>/dev/null || echo "unknown")

CURRENT_FEATURE=$(grep "🔄 진행중" "$PROJECT_DIR/docs/project/features.md" 2>/dev/null \
  | head -1 | sed 's/.*| \([^|]*\) |.*/\1/' | xargs 2>/dev/null || echo "없음")

INCOMPLETE_TASKS=$(grep -r '\[ \]\|\[→\]' "$PROJECT_DIR/docs/specs/"*/plan.md 2>/dev/null \
  | wc -l | xargs 2>/dev/null || echo "0")

UNCOMMITTED=$(cd "$PROJECT_DIR" && git status --porcelain 2>/dev/null | wc -l | xargs || echo "0")

cat > "$STATE_FILE" << EOF
timestamp: $TIMESTAMP
branch: $BRANCH
current_feature: $CURRENT_FEATURE
incomplete_tasks: $INCOMPLETE_TASKS
uncommitted_files: $UNCOMMITTED
EOF

echo "파이프라인 상태 저장됨: $STATE_FILE"
