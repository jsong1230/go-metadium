#!/bin/bash
# sync-mcp-permissions.sh
# .mcp.json의 mcpServers 목록을 읽어 settings.json의 permissions.allow를 동기화합니다.
# 사용법: bash sync-mcp-permissions.sh [프로젝트-디렉토리]

set -euo pipefail

TARGET_DIR="${1:-$(pwd)}"
MCP_FILE="$TARGET_DIR/.mcp.json"
SETTINGS_FILE="$TARGET_DIR/.claude/settings.json"

# jq 의존성 확인
if ! command -v jq &> /dev/null; then
  echo "Error: jq가 설치되어 있지 않습니다."
  echo "설치 방법:"
  echo "  macOS:          brew install jq"
  echo "  Ubuntu/Debian:  sudo apt-get install jq"
  echo "  기타:           https://stedolan.github.io/jq/download/"
  exit 1
fi

# .mcp.json 없으면 정상 종료
if [ ! -f "$MCP_FILE" ]; then
  echo "[INFO] .mcp.json이 없습니다. 건너뜁니다."
  exit 0
fi

# settings.json 없으면 오류
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "Error: $SETTINGS_FILE 이 없습니다."
  exit 1
fi

# 서버 이름 추출 (mcpServers 없거나 비어 있으면 빈 문자열)
SERVER_NAMES=$(jq -r '.mcpServers // {} | keys[]' "$MCP_FILE" 2>/dev/null || true)

# 새 mcp__ 항목 JSON 배열 생성
if [ -z "$SERVER_NAMES" ]; then
  NEW_MCP_JSON='[]'
else
  NEW_MCP_JSON=$(echo "$SERVER_NAMES" | jq -R '"mcp__" + . + "__*"' | jq -s '.')
fi

# settings.json 업데이트: 기존 mcp__ 항목 제거 + 새 항목 추가 (멱등성 보장)
UPDATED=$(jq --argjson new_mcp "$NEW_MCP_JSON" \
  '.permissions.allow = ([.permissions.allow[] | select(startswith("mcp__") | not)] + $new_mcp)' \
  "$SETTINGS_FILE")

echo "$UPDATED" > "$SETTINGS_FILE"

# 결과 출력
if [ -z "$SERVER_NAMES" ]; then
  echo "[OK] .mcp.json에 mcpServers가 없습니다. mcp__ 항목을 전부 제거했습니다."
else
  echo "[OK] MCP 권한 동기화 완료:"
  echo "$SERVER_NAMES" | while read -r server; do
    echo "  + mcp__${server}__*"
  done
fi
