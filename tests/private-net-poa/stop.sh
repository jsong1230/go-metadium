#!/usr/bin/env bash
# stop.sh - PoA 프라이빗 네트워크 중지
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

CLEAN=false
for arg in "$@"; do
  [[ "$arg" == "--clean" || "$arg" == "--remove-volumes" ]] && CLEAN=true
done

log "=== PoA 프라이빗 네트워크 중지 ==="

if $CLEAN; then
  log "컨테이너 + 데이터 전체 삭제..."
  docker compose down 2>/dev/null || true
  rm -rf data/ static-nodes.json passwords.txt genesis.json gmet
  log "완전 초기화 완료 (재시작하려면 ./setup.sh 실행)"
else
  docker compose down 2>/dev/null || true
  log "중지 완료 (데이터 유지 - 재시작: ./start.sh)"
  log "데이터까지 삭제: ./stop.sh --clean"
fi
