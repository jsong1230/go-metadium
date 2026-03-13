#!/usr/bin/env bash
# start.sh - 프라이빗 네트워크 시작
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
warn() { echo "[$(date '+%H:%M:%S')] [WARN] $*"; }

[[ -f static-nodes.json ]] || { echo "[ERROR] setup.sh를 먼저 실행하세요."; exit 1; }
[[ -f data/node1/geth/nodekey ]] || { echo "[ERROR] setup.sh를 먼저 실행하세요."; exit 1; }

log "=== 프라이빗 네트워크 시작 ==="
docker compose up -d

log "노드 RPC 대기 중..."
for port in 8545 8546 8547; do
  for i in $(seq 1 30); do
    sleep 2
    if curl -sf -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        "http://localhost:$port" &>/dev/null; then
      log "  :$port 응답 OK (${i}번째 시도)"
      break
    fi
  done
done

sleep 5

log ""
log "=== 네트워크 상태 ==="
for port in 8545 8546 8547; do
  BLOCK=$(curl -sf -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    "http://localhost:$port" 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d['result'],16))" 2>/dev/null || echo "?")
  PEERS=$(curl -sf -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
    "http://localhost:$port" 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d['result'],16))" 2>/dev/null || echo "?")
  log "  :$port  block=$BLOCK  peers=$PEERS"
done

log ""
log "ElderflowerFork 활성화 블록: 100"
log ""
log "유용한 명령:"
log "  블록 모니터링: watch -n1 'curl -sf -X POST -H \"Content-Type: application/json\" --data \"{\\\"jsonrpc\\\":\\\"2.0\\\",\\\"method\\\":\\\"eth_blockNumber\\\",\\\"params\\\":[],\\\"id\\\":1}\" http://localhost:8545'"
log "  node1 로그:   docker logs -f gmet-node1"
log "  중지:         ./stop.sh"
log "  전체 초기화:  ./stop.sh --clean && ./setup.sh"
