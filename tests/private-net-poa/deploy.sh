#!/usr/bin/env bash
# deploy.sh - Phase 2: 거버넌스 컨트랙트 배포
#
# 전제조건:
#   - setup.sh, start.sh 실행 완료 (3노드 실행 중)
#   - node1이 bootnode로 블록 생성 중
#
# 실행: ./deploy.sh
# 옵션: GMET_BIN=/path/to/gmet ./deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GMET_BIN="${GMET_BIN:-/data/jsong/gmet-rocksdb}"
GOVERNANCE_JS="/data/jsong/go-metadium/metadium/contracts/MetadiumGovernance.js"
DEPLOY_JS="/data/jsong/go-metadium/metadium/scripts/deploy-governance.js"
NODE1_RPC="http://localhost:8545"
CHAINID=1337
PASSWORD="privatenet123"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
err()  { echo "[ERROR] $*" >&2; exit 1; }

[[ -x "$GMET_BIN" ]] || err "gmet 바이너리 없음: $GMET_BIN"
[[ -f "$GOVERNANCE_JS" ]] || err "MetadiumGovernance.js 없음: $GOVERNANCE_JS"
[[ -f "$DEPLOY_JS" ]] || err "deploy-governance.js 없음: $DEPLOY_JS"
[[ -f "genesis.json" ]] || err "genesis.json 없음. setup.sh를 먼저 실행하세요."
[[ -f "data/node1/keystore" || -d "data/node1/keystore" ]] || err "keystore 없음. setup.sh를 먼저 실행하세요."

log "=== Phase 2: 거버넌스 컨트랙트 배포 ==="

# node1 RPC 확인
BLOCK=$(curl -sf -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  "$NODE1_RPC" 2>/dev/null | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d['result'],16))" 2>/dev/null || echo "0")
[[ "$BLOCK" -gt 0 ]] || err "node1 RPC 응답 없음. start.sh를 먼저 실행하세요."
log "현재 블록: $BLOCK"

# 각 노드의 enode ID 수집 (128자 공개키 형식)
log "노드 ID 수집 중..."
get_enode_id() {
  local port="$1"
  curl -sf -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' \
    "http://localhost:${port}" 2>/dev/null | \
    python3 -c "import sys,json,re; d=json.load(sys.stdin); m=re.match(r'enode://([a-f0-9]{128})@', d['result']['enode']); print(m.group(1) if m else '')" 2>/dev/null
}

NODE1_ID=$(get_enode_id 8545)
NODE2_ID=$(get_enode_id 8546)
NODE3_ID=$(get_enode_id 8547)

[[ -n "$NODE1_ID" && ${#NODE1_ID} -eq 128 ]] || err "node1 ID 가져오기 실패"
[[ -n "$NODE2_ID" && ${#NODE2_ID} -eq 128 ]] || err "node2 ID 가져오기 실패"
[[ -n "$NODE3_ID" && ${#NODE3_ID} -eq 128 ]] || err "node3 ID 가져오기 실패"

log "  node1: ${NODE1_ID:0:16}..."
log "  node2: ${NODE2_ID:0:16}..."
log "  node3: ${NODE3_ID:0:16}..."

# keystore 파일 찾기
KEYSTORE_FILE=$(ls data/node1/keystore/UTC--* 2>/dev/null | head -1)
[[ -n "$KEYSTORE_FILE" ]] || err "keystore 파일 없음"
KEYSTORE_FILE="$SCRIPT_DIR/$KEYSTORE_FILE"
log "keystore: $(basename "$KEYSTORE_FILE")"

# config.json 생성
log "config.json 생성 중..."
cat > config.json <<EOF
{
  "staker":      "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  "ecosystem":   "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  "maintenance": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  "feecollector":"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  "env": {
    "ballotDurationMin":      60,
    "ballotDurationMax":      604800,
    "stakingMin":             1000000000000000000,
    "stakingMax":             100000000000000000000000000,
    "MaxIdleBlockInterval":   5,
    "blockCreationTime":      2000,
    "blockRewardAmount":      1000000000000000000,
    "maxPriorityFeePerGas":   80000000000,
    "rewardDistributionMethod": [4000, 1000, 2500, 2500],
    "maxBaseFee":             50000000000000,
    "blockGasLimit":          268435456,
    "baseFeeMaxChangeRate":   55,
    "gasTargetPercentage":    30
  },
  "members": [
    {
      "addr":     "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
      "stake":    1000000000000000000,
      "name":     "node1",
      "id":       "${NODE1_ID}",
      "ip":       "172.31.0.11",
      "port":     30303,
      "bootnode": true
    },
    {
      "addr":   "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
      "stake":  1000000000000000000,
      "name":   "node2",
      "id":     "${NODE2_ID}",
      "ip":     "172.31.0.12",
      "port":   30304
    },
    {
      "addr":   "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
      "stake":  1000000000000000000,
      "name":   "node3",
      "id":     "${NODE3_ID}",
      "ip":     "172.31.0.13",
      "port":   30305
    }
  ],
  "accounts": [
    {"addr": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "balance": 0},
    {"addr": "0x70997970C51812dc3A010C7d01b50e0d17dc79C8", "balance": 0},
    {"addr": "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC", "balance": 0}
  ]
}
EOF
log "config.json 생성 완료"

# 거버넌스 배포
log ""
log "거버넌스 컨트랙트 배포 시작..."
log "(Registry → EnvStorageImp → Staking → BallotStorage → EnvStorage → GovImp → Gov → TRSList)"
log ""

"$GMET_BIN" attach "$NODE1_RPC" \
  --preload "${GOVERNANCE_JS},${DEPLOY_JS}" \
  --exec "GovernanceDeployer.deploy(\"${KEYSTORE_FILE}\", \"${PASSWORD}\", \"${SCRIPT_DIR}/config.json\", true)" \
  2>&1

DEPLOY_EXIT=$?
if [ $DEPLOY_EXIT -ne 0 ]; then
  log "[WARN] 배포 실패 (exit=$DEPLOY_EXIT). 로그를 확인하세요."
  exit $DEPLOY_EXIT
fi

log ""
log "=== 거버넌스 배포 완료 ==="
log ""

# ETCD 클러스터 초기화
# 거버넌스 감지 후 admin.self가 설정되기까지 최대 10초 대기 후 admin_etcdInit 호출
log "ETCD 클러스터 초기화 중 (node1)..."
ETCD_OK=false
for i in $(seq 1 10); do
  RESULT=$(curl -sf -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"admin_etcdInit","params":[],"id":1}' \
    "$NODE1_RPC" 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print('ok' if 'error' not in d else d['error']['message'])" 2>/dev/null || echo "fail")
  if [ "$RESULT" = "ok" ]; then
    log "  node1 ETCD 초기화 성공 (시도 $i)"
    ETCD_OK=true
    break
  fi
  log "  시도 $i: $RESULT"
  sleep 3
done
$ETCD_OK || err "node1 ETCD 초기화 실패. 수동으로 'admin_etcdInit' RPC를 호출하세요."

# node1 ETCD 준비 대기
sleep 3

# node2, node3를 ETCD 클러스터에 추가 (etcdAutoJoin 가속)
log "node2/node3 ETCD 클러스터 참여 중..."
for node_name in node2 node3; do
  for i in $(seq 1 10); do
    RESULT=$(curl -sf -X POST -H "Content-Type: application/json" \
      --data "{\"jsonrpc\":\"2.0\",\"method\":\"admin_etcdAddMember\",\"params\":[\"$node_name\"],\"id\":1}" \
      "$NODE1_RPC" 2>/dev/null | \
      python3 -c "import sys,json; d=json.load(sys.stdin); print('ok' if 'result' in d and d['result'] else d.get('error',{}).get('message','fail'))" 2>/dev/null || echo "fail")
    if [ "$RESULT" = "ok" ]; then
      log "  $node_name 참여 완료 (시도 $i)"
      break
    fi
    log "  $node_name 시도 $i: $RESULT"
    sleep 3
  done
done

# 최종 상태 확인
sleep 5
log ""
log "=== 최종 노드 상태 ==="
for port in 8545 8546 8547; do
  BLOCK=$(curl -sf -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    "http://localhost:$port" 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d['result'],16))" 2>/dev/null || echo "?")
  MINING=$(curl -sf -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_mining","params":[],"id":1}' \
    "http://localhost:$port" 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'])" 2>/dev/null || echo "?")
  log "  :$port  block=$BLOCK  mining=$MINING"
done
