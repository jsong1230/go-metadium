#!/usr/bin/env bash
# setup.sh - go-metadium 프라이빗 3노드 네트워크 초기화
# 실행: ./setup.sh
# 옵션: GMET_BIN=/path/to/gmet ./setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GMET_BIN="${GMET_BIN:-/data/jsong/gmet-rocksdb}"
USE_ROCKSDB="${USE_ROCKSDB:-1}"
NETWORKID=1337
PASSWORD="privatenet123"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
err()  { echo "[ERROR] $*" >&2; exit 1; }

[[ -x "$GMET_BIN" ]] || err "gmet 바이너리 없음: $GMET_BIN"

log "=== 프라이빗 네트워크 초기화 시작 (chainId=$NETWORKID, ElderflowerFork=100) ==="

# 기존 데이터 정리
log "기존 데이터 정리..."
rm -rf data/ passwords.txt static-nodes.json

mkdir -p data/node1/geth data/node2/geth data/node3/geth
echo "$PASSWORD" > passwords.txt

# 테스트 계정 private keys (Hardhat 기본값 - 테스트 전용)
PRIVKEYS=(
  "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  "59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
  "5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
)
ACCOUNTS=(
  "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
  "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
)
NODES=(node1 node2 node3)

# 계정 import
log "계정 import 중..."
for i in 0 1 2; do
  node="${NODES[$i]}"
  KEYFILE=$(mktemp /tmp/privkey.XXXXXX)
  echo "${PRIVKEYS[$i]}" > "$KEYFILE"
  "$GMET_BIN" account import \
    --datadir "data/$node" \
    --password passwords.txt \
    --lightkdf \
    "$KEYFILE" 2>/dev/null || true
  rm -f "$KEYFILE"
  log "  $node: ${ACCOUNTS[$i]}"
done

# genesis 초기화
log "genesis 초기화 중..."
for node in "${NODES[@]}"; do
  "$GMET_BIN" init \
    --datadir "data/$node" \
    --userocksdb "$USE_ROCKSDB" \
    genesis.json 2>&1 | grep -E "INFO|WARN|ERROR" | head -3 || true
  log "  $node 초기화 완료"
done

# node1 임시 실행 → enode 추출 → static-nodes.json 생성
log "node1 enode 추출 중..."
"$GMET_BIN" \
  --datadir data/node1 \
  --networkid "$NETWORKID" \
  --port 30399 \
  --http --http.addr 127.0.0.1 --http.port 18545 \
  --http.api admin \
  --nodiscover \
  --userocksdb "$USE_ROCKSDB" \
  --verbosity 1 \
  > /tmp/gmet-setup.log 2>&1 &
NODE1_PID=$!

ENODE=""
for i in $(seq 1 20); do
  sleep 2
  ENODE=$(curl -s -X POST \
    --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' \
    -H "Content-Type: application/json" \
    http://127.0.0.1:18545 2>/dev/null | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d['result']['enode'])" 2>/dev/null || true)
  [[ -n "$ENODE" ]] && break
done

kill "$NODE1_PID" 2>/dev/null || true
wait "$NODE1_PID" 2>/dev/null || true

if [[ -z "$ENODE" ]]; then
  err "enode 추출 실패. /tmp/gmet-setup.log 확인 후 static-nodes.json을 수동으로 작성하세요."
fi

# 내부 Docker IP로 교체
ENODE_FIXED=$(echo "$ENODE" | sed 's/@127\.0\.0\.1:[0-9]*/@172.30.0.11:30303/')
log "node1 enode: $ENODE_FIXED"

cat > static-nodes.json <<EOF
[
  "$ENODE_FIXED"
]
EOF

# 각 노드 datadir에도 복사
for node in "${NODES[@]}"; do
  cp static-nodes.json "data/$node/geth/static-nodes.json"
done

# Docker 이미지 빌드
log "Docker 이미지 빌드 중 (gmet-private:latest)..."
cp "$GMET_BIN" ./gmet
docker build -t gmet-private:latest . 2>&1 | tail -3
rm -f ./gmet
log "이미지 빌드 완료"

log ""
log "=== 초기화 완료 ==="
log ""
log "다음 단계: ./start.sh"
log ""
log "노드 RPC:"
log "  node1: http://localhost:8545"
log "  node2: http://localhost:8546"
log "  node3: http://localhost:8547"
log "ElderflowerFork 활성화: block 100"
