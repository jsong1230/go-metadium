#!/usr/bin/env bash
# setup.sh - go-metadium PoA 프라이빗 3노드 네트워크 초기화
# 실행: ./setup.sh
# 옵션: GMET_BIN=/path/to/gmet ./setup.sh
#
# Phase 1: node1(bootnode)만 블록 생성, node2/3는 동기화
# Phase 2: 거버넌스 컨트랙트 배포 후 다른 노드 추가 (별도 작업)

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

log "=== PoA 프라이빗 네트워크 초기화 시작 (chainId=$NETWORKID, CamelliaFork=100) ==="

# 기존 데이터 정리
log "기존 데이터 정리..."
rm -rf data/ passwords.txt static-nodes.json genesis.json
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

# node1 nodekey 생성 (bootnode → ID가 genesis extraData에 들어감)
log "node1 nodekey 생성 중..."
NODEKEY=$(openssl rand -hex 32)
echo "$NODEKEY" > data/node1/geth/nodekey
chmod 600 data/node1/geth/nodekey

# Python으로 node1의 node ID 계산 (secp256k1 public key 64바이트 = 128 hex chars)
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

ENODE="enode://${NODE1_ID}@172.31.0.11:30303"
log "node1 enode: $ENODE"

# static-nodes.json 생성 (각 노드의 geth 디렉토리에도 복사 - macOS virtiofs 중첩마운트 우회)
cat > static-nodes.json <<EOF
[
  "$ENODE"
]
EOF
for node in node1 node2 node3; do
  cp static-nodes.json "data/$node/geth/static-nodes.json"
done
log "static-nodes.json 생성 완료"

# PoA genesis.json 생성
# extraData = "0x" + node1_id (128 hex chars) → bootnode 식별자
log "genesis.json 생성 중 (extraData=node1_id)..."
cat > genesis.json <<EOF
{
  "alloc": {
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266": {
      "balance": "0x56BC75E2D63100000000"
    },
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8": {
      "balance": "0x56BC75E2D63100000000"
    },
    "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC": {
      "balance": "0x56BC75E2D63100000000"
    }
  },
  "coinbase": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  "config": {
    "chainId": 1337,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "muirGlacierBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0,
    "avocadoBlock": 0,
    "pangyoBlock": 0,
    "applepieBlock": 0,
    "bokbunjaBlock": 0,
    "camelliaBlock": 100
  },
  "difficulty": "0x1",
  "extraData": "0x${NODE1_ID}",
  "gasLimit": "0x10000000",
  "minerNodeId": "0x0",
  "minerNodeSig": "0x0",
  "mixhash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "nonce": "0x0000000000000042",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "rewards": "0x",
  "timestamp": "0x00"
}
EOF
log "genesis.json 생성 완료 (bootNodeId=${NODE1_ID:0:16}...)"

# password.txt를 각 노드 data 디렉토리에 복사 (--unlock 사용 시 필요)
log "password.txt 각 노드에 복사 중..."
for node in node1 node2 node3; do
  cp passwords.txt "data/$node/password.txt"
done

# Docker 이미지 빌드
# BASE_IMAGE: go-metadium-rocksdb-test:latest (macOS), gmet-poa:latest (Linux)
log "Docker 이미지 빌드 중 (gmet-poa:latest)..."
cp "$GMET_BIN" ./gmet
if docker image inspect go-metadium-rocksdb-test:latest &>/dev/null; then
  BASE_IMAGE="go-metadium-rocksdb-test:latest"
else
  BASE_IMAGE="gmet-poa:latest"
fi
log "  베이스 이미지: $BASE_IMAGE"
docker build --build-arg BASE_IMAGE="$BASE_IMAGE" -t gmet-poa:latest . 2>&1 | tail -3
rm -f ./gmet
log "이미지 빌드 완료"

log ""
log "=== PoA 초기화 완료 ==="
log ""
log "다음 단계: ./start.sh"
log ""
log "노드 RPC:"
log "  node1 (bootnode): http://localhost:8545"
log "  node2 (sync):     http://localhost:8546"
log "  node3 (sync):     http://localhost:8547"
log ""
log "Phase 1: node1이 블록 생성 (거버넌스 없이 bootnode 단독 채굴)"
log "CamelliaFork 활성화: block 100 (약 3-4분 후)"
