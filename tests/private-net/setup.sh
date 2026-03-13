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

# 계정 keystore import (각 노드 datadir에)
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

# node1 nodekey 생성 (enode 계산용 - gmet 실행 없이)
log "node1 nodekey 생성 중..."
NODEKEY=$(openssl rand -hex 32)
echo "$NODEKEY" > data/node1/geth/nodekey
chmod 600 data/node1/geth/nodekey

# Python으로 node1 enode 계산 (gmet 실행 불필요)
NODE1_ID=$(python3 - <<PYEOF
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.backends import default_backend
privkey = ec.derive_private_key(int("$NODEKEY", 16), ec.SECP256K1(), default_backend())
pub = privkey.public_key().public_numbers()
x = pub.x.to_bytes(32, 'big').hex()
y = pub.y.to_bytes(32, 'big').hex()
print(x + y)
PYEOF
)

ENODE="enode://${NODE1_ID}@172.30.0.11:30303"
log "node1 enode: $ENODE"

# static-nodes.json 생성
cat > static-nodes.json <<EOF
[
  "$ENODE"
]
EOF
log "static-nodes.json 생성 완료"

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
