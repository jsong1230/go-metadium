#!/bin/bash
# tier3-guard.sh — PreToolUse hook: Tier 3 차단 필터
# Claude Code가 Bash 도구 호출 전 stdin으로 JSON 입력을 전달함.
# 차단 시: stderr에 한국어 메시지 출력 + exit 2
# 통과 시: exit 0

INPUT="$(cat)"
COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"

if [ -z "$COMMAND" ]; then
  exit 0
fi

# --- Tier 3 패턴 검사 ---

# 1. sudo 실행 차단
if echo "$COMMAND" | grep -qE '(^|[;&|`$( ])sudo( |$)'; then
  echo "❌ [Tier3-Guard] sudo 실행은 차단됩니다. 필요한 경우 사용자가 직접 터미널에서 실행하세요." >&2
  exit 2
fi

# 2. 운영 배포 패턴 차단 (prod/production/live 환경 배포 명령)
if echo "$COMMAND" | grep -qiE '(deploy|kubectl apply|helm upgrade|helm install|terraform apply|eb deploy|gcloud.*deploy|aws.*deploy|heroku.*push).*(prod|production|live|main|master)|(prod|production|live).*(deploy|kubectl apply|helm upgrade|helm install|terraform apply)'; then
  echo "❌ [Tier3-Guard] 운영(prod) 배포는 차단됩니다. CI/CD 파이프라인 또는 사용자 직접 실행으로 진행하세요." >&2
  exit 2
fi

# 3. 시스템 경로 쓰기 차단 (/etc, /usr, /var, /sys, /boot)
if echo "$COMMAND" | grep -qE '(>|>>|tee|cp |mv |rm |chmod |chown |install |ln -s?f? )[^;|&]*/(etc|usr|var|sys|boot)/'; then
  echo "❌ [Tier3-Guard] 시스템 경로(/etc, /usr, /var, /sys, /boot) 수정은 금지됩니다." >&2
  exit 2
fi

exit 0
