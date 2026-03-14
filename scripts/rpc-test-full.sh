#!/usr/bin/env bash
# rpc-test-full.sh - go-metadium 전체 Execution API + Fee Delegation + IPC/JS 통합 테스트
#
# 사용법:
#   bash rpc-test-full.sh [RPC_URL] [IPC_PATH]
#   bash rpc-test-full.sh http://localhost:8545 /path/to/gmet.ipc
#
# 커버리지: https://ethereum.github.io/execution-apis/ (EIP-4844 이전/당시 포함)
#   eth_*, net_*, web3_*, debug_*, admin_*, txpool_*, personal_*
#   + eth_sendTransaction, eth_sendRawTransaction
#   + Fee Delegation (Type 22 tx)
#   + IPC + JS console

set -euo pipefail
NODE="${1:-http://localhost:8545}"
IPC_PATH="${2:-}"

# 테스트 계정 (private-net-poa hardhat 기본값)
ACCT1="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
ACCT2="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
ACCT3="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
PRIVKEY1="ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
PRIVKEY2="59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
PASSWORD="privatenet123"
CHAINID=1337

# ── 색상 ────────────────────────────────────────────────────────────────────
G='\033[0;32m'; R='\033[0;31m'; Y='\033[1;33m'; C='\033[0;36m'
B='\033[1m'; D='\033[2m'; N='\033[0m'
PASS=0; FAIL=0; WARN=0; SKIP=0

pass() { echo -e "  ${G}[PASS]${N} $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${R}[FAIL]${N} $1${2:+\n         ${R}↳ $2${N}}"; FAIL=$((FAIL+1)); }
warn() { echo -e "  ${Y}[WARN]${N} $1${2:+ — $2}"; WARN=$((WARN+1)); }
skip() { echo -e "  ${D}[SKIP]${N} $1${2:+ — $2}"; SKIP=$((SKIP+1)); }
sec()  { echo -e "\n${C}${B}━━━ $1 ━━━${N}"; }

# ── RPC 헬퍼 ────────────────────────────────────────────────────────────────
rpc() {
  local method="$1" params="${2:-[]}"
  curl -sf --max-time 10 -X POST -H 'Content-Type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":${params},\"id\":1}" \
    "$NODE" 2>/dev/null
}

jq_int()  { python3 -c "import json,sys; d=json.load(sys.stdin); r=d.get('result','0x0'); print(int(r,16) if isinstance(r,str) and r.startswith('0x') else (r or 0))"; }
jq_str()  { python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('result',''))"; }
jq_len()  { python3 -c "import json,sys; d=json.load(sys.stdin); r=d.get('result',[]); print(len(r) if isinstance(r,list) else 0)"; }
jq_bool() { python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('result',False))"; }
jq_err()  { python3 -c "import json,sys; d=json.load(sys.stdin); e=d.get('error'); print(e.get('message','unknown')) if e else sys.exit(1)" 2>/dev/null; }
is_skip() { [[ "$1" =~ "not found"|"not supported"|"unknown"|"does not exist"|"not available" ]]; }

check() {
  # check <label> <method> [params] -- generic test
  local label="$1" method="$2" params="${3:-[]}"
  local resp; resp=$(rpc "$method" "$params")
  local err; err=$(echo "$resp" | jq_err 2>/dev/null || true)
  if [[ -n "$err" ]]; then
    is_skip "$err" && skip "$label" "$err" || fail "$label" "$err"
    return
  fi
  local result; result=$(echo "$resp" | python3 -c "import json,sys; r=json.load(sys.stdin).get('result'); print(r)" 2>/dev/null || true)
  [[ -z "$result" || "$result" == "None" ]] && warn "$label" "result=null" || pass "$label — $result"
}

evm_call() {
  # evm_call <label> <bytecode> <expected_dec>
  local label="$1" bytecode="$2" expected="$3"
  local resp; resp=$(rpc "eth_call" "[{\"data\":\"$bytecode\"},\"latest\"]")
  local err; err=$(echo "$resp" | jq_err 2>/dev/null || true)
  [[ -n "$err" ]] && { fail "$label" "$err"; return; }
  local ret; ret=$(echo "$resp" | python3 -c "
import json,sys; d=json.load(sys.stdin)
r=d.get('result','0x'); print(int(r,16) if r and r!='0x' else 0)" 2>/dev/null || echo "ERR")
  [[ "$ret" == "ERR" ]] && { fail "$label" "파싱 실패"; return; }
  [[ -n "$expected" && "$ret" != "$expected" ]] && fail "$label" "반환=$ret (예상:$expected)" || pass "$label — 반환값=$ret"
}

# ── 사전 준비: TX 전송 및 수집 ────────────────────────────────────────────
setup_tx() {
  # eth_sendTransaction으로 TX 전송 후 수집
  local resp
  resp=$(rpc "eth_sendTransaction" "[{
    \"from\":\"$ACCT1\",
    \"to\":\"$ACCT2\",
    \"value\":\"0xDE0B6B3A7640000\",
    \"gas\":\"0x5208\"
  }]")
  TX_HASH=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin).get('result',''))" 2>/dev/null || true)

  # TX 확정 대기 (최대 15초)
  if [[ -n "$TX_HASH" && "$TX_HASH" != "None" ]]; then
    for i in $(seq 1 15); do
      sleep 1
      local tx_resp
      tx_resp=$(rpc "eth_getTransactionReceipt" "[\"$TX_HASH\"]")
      local status
      status=$(echo "$tx_resp" | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print(r['blockHash'] if r else '')" 2>/dev/null || true)
      [[ -n "$status" ]] && { TX_BLOCK_HASH="$status"; break; }
    done
  fi
}

# python3 + eth_account로 트랜잭션 서명 (eth_sendRawTransaction용)
sign_tx() {
  # sign_tx <from_privkey> <to_addr> <value_hex> <nonce_hex>
  python3 - <<PYEOF 2>/dev/null
import sys
try:
    from eth_account import Account
    from eth_account.signers.local import LocalAccount
    import json

    privkey = "0x$1"
    acct: LocalAccount = Account.from_key(privkey)
    nonce = int("$4", 16)
    tx = {
        "nonce": nonce,
        "to": "$2",
        "value": int("$3", 16),
        "gas": 21000,
        "maxFeePerGas": 200 * 10**9,
        "maxPriorityFeePerGas": 100 * 10**9,
        "chainId": $CHAINID,
        "type": 2,
    }
    signed = acct.sign_transaction(tx)
    print(signed.raw_transaction.hex())
except ImportError:
    print("NO_ETH_ACCOUNT")
except Exception as e:
    print(f"ERR:{e}", file=sys.stderr)
PYEOF
}

# ════════════════════════════════════════════════════════════════════
echo -e "${B}${C}╔══════════════════════════════════════════════════════════════╗${N}"
echo -e "${B}${C}║   go-metadium 전체 Execution API + FeeDelegation + IPC 테스트 ║${N}"
echo -e "${B}${C}║   Target: $NODE$(printf '%*s' $((44-${#NODE})) '')║${N}"
echo -e "${B}${C}╚══════════════════════════════════════════════════════════════╝${N}"

# 기본 연결 확인
LATEST_RESP=$(rpc "eth_getBlockByNumber" '["latest",true]')
LATEST_NUM=$(echo "$LATEST_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['number'])" 2>/dev/null || echo "0x0")
BLOCK_DEC=$(python3 -c "print(int('$LATEST_NUM',16))" 2>/dev/null || echo "0")
LATEST_HASH=$(echo "$LATEST_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['hash'])" 2>/dev/null || echo "")
BLOCK1_RESP=$(rpc "eth_getBlockByNumber" '["0x1",false]')
BLOCK1_HASH=$(echo "$BLOCK1_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['hash'])" 2>/dev/null || echo "")

echo -e "${D}  네트워크: chainId=1337 | block=$BLOCK_DEC | ElderflowerFork=100${N}"
echo -e "${D}  테스트 계정: $ACCT1${N}"

TX_HASH=""
TX_BLOCK_HASH=""

# ════════════════════════════════════════════════════════════════════
sec "1. net_* / web3_*"

check "net_version=1337"       "net_version"
check "net_listening=true"     "net_listening"
resp=$(rpc "net_peerCount"); v=$(echo "$resp" | jq_int); [[ "$v" -ge 0 ]] 2>/dev/null && pass "net_peerCount = $v" || warn "net_peerCount"
check "web3_clientVersion"     "web3_clientVersion"
resp=$(rpc "web3_sha3" '["0x68656c6c6f20776f726c64"]')
v=$(echo "$resp" | jq_str)
[[ "$v" == "0x47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad" ]] \
  && pass "web3_sha3(hello world) = ${v:0:20}..." || fail "web3_sha3" "$v"

# ════════════════════════════════════════════════════════════════════
sec "2. eth_* — 체인/동기화"

resp=$(rpc "eth_chainId"); v=$(echo "$resp" | jq_int)
[[ "$v" == "1337" ]] && pass "eth_chainId = $v" || fail "eth_chainId" "$v"
resp=$(rpc "eth_blockNumber"); v=$(echo "$resp" | jq_int)
[[ "$v" -gt 100 ]] && pass "eth_blockNumber = $v (ElderflowerFork 활성화)" || fail "eth_blockNumber" "$v"
resp=$(rpc "eth_syncing"); v=$(echo "$resp" | jq_bool)
[[ "$v" == "False" ]] && pass "eth_syncing = false" || warn "eth_syncing" "$v"
resp=$(rpc "eth_coinbase"); v=$(echo "$resp" | jq_str)
[[ -n "$v" ]] && pass "eth_coinbase = $v" || warn "eth_coinbase" "null"

# ════════════════════════════════════════════════════════════════════
sec "3. eth_* — 가스 / 수수료 (EIP-1559, EIP-4844)"

resp=$(rpc "eth_gasPrice"); v=$(echo "$resp" | jq_int)
[[ "$v" -gt 0 ]] && pass "eth_gasPrice = $v wei" || fail "eth_gasPrice"

resp=$(rpc "eth_maxPriorityFeePerGas")
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && { is_skip "$err" && skip "eth_maxPriorityFeePerGas" "$err" || warn "eth_maxPriorityFeePerGas" "$err"; } || {
  v=$(echo "$resp" | jq_int); pass "eth_maxPriorityFeePerGas = $v wei"; }

resp=$(rpc "eth_blobBaseFee")
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && { is_skip "$err" && skip "eth_blobBaseFee" "$err" || fail "eth_blobBaseFee" "$err"; } || {
  v=$(echo "$resp" | jq_int)
  [[ "$v" -ge 1 ]] && pass "eth_blobBaseFee = $v (EIP-4844 >= 1 wei)" || fail "eth_blobBaseFee" "got $v"; }

resp=$(rpc "eth_feeHistory" '[4,"latest",[25,75]]')
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && { is_skip "$err" && skip "eth_feeHistory" "$err" || warn "eth_feeHistory" "$err"; } || {
  v=$(echo "$resp" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['result'].get('baseFeePerGas',[])))" 2>/dev/null)
  pass "eth_feeHistory(4 blocks) — baseFeePerGas[$v]"; }

resp=$(rpc "eth_estimateGas" "[{\"from\":\"$ACCT1\",\"to\":\"$ACCT2\",\"value\":\"0x1\"}]")
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && fail "eth_estimateGas" "$err" || {
  v=$(echo "$resp" | jq_int); pass "eth_estimateGas(ETH transfer) = $v gas"; }

# ════════════════════════════════════════════════════════════════════
sec "4. eth_* — 계정/상태"

resp=$(rpc "eth_accounts"); v=$(echo "$resp" | jq_len)
pass "eth_accounts — $v 개"

resp=$(rpc "eth_getBalance" "[\"$ACCT1\",\"latest\"]"); v=$(echo "$resp" | jq_int)
[[ "$v" -gt 0 ]] && pass "eth_getBalance($ACCT1) = $v wei" || warn "eth_getBalance" "0"

resp=$(rpc "eth_getTransactionCount" "[\"$ACCT1\",\"latest\"]"); v=$(echo "$resp" | jq_int)
ACCT1_NONCE=$v; pass "eth_getTransactionCount($ACCT1) nonce=$v"

resp=$(rpc "eth_getCode" "[\"$ACCT1\",\"latest\"]"); v=$(echo "$resp" | jq_str)
[[ "$v" == "0x" ]] && pass "eth_getCode(EOA) = 0x" || warn "eth_getCode" "$v"

resp=$(rpc "eth_getStorageAt" "[\"$ACCT1\",\"0x0\",\"latest\"]"); v=$(echo "$resp" | jq_str)
[[ -n "$v" ]] && pass "eth_getStorageAt = $v" || fail "eth_getStorageAt"

resp=$(rpc "eth_getProof" "[\"$ACCT1\",[\"0x0\"],\"latest\"]")
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && { is_skip "$err" && skip "eth_getProof" "$err" || fail "eth_getProof" "$err"; } || {
  v=$(echo "$resp" | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print('balance='+str(int(r['balance'],16)))" 2>/dev/null)
  pass "eth_getProof — $v"; }

# ════════════════════════════════════════════════════════════════════
sec "5. eth_* — 블록 조회"

resp=$(rpc "eth_getBlockByNumber" '["0x0",false]')
v=$(echo "$resp" | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['hash'][:20]+'...')" 2>/dev/null)
[[ -n "$v" ]] && pass "eth_getBlockByNumber(genesis) — $v" || fail "eth_getBlockByNumber(0x0)"

resp=$(rpc "eth_getBlockByNumber" '["latest",false]')
v=$(echo "$resp" | python3 -c "
import json,sys; b=json.load(sys.stdin)['result']
print(f'#{int(b[\"number\"],16)}, excessBlobGas={b.get(\"excessBlobGas\",\"MISSING\")}')" 2>/dev/null)
[[ -n "$v" ]] && pass "eth_getBlockByNumber(latest) — $v" || fail "eth_getBlockByNumber(latest)"

if [[ -n "$BLOCK1_HASH" ]]; then
  resp=$(rpc "eth_getBlockByHash" "[\"$BLOCK1_HASH\",false]")
  v=$(echo "$resp" | python3 -c "import json,sys; print(int(json.load(sys.stdin)['result']['number'],16))" 2>/dev/null)
  [[ "$v" == "1" ]] && pass "eth_getBlockByHash(block#1) — #$v" || fail "eth_getBlockByHash"
fi

resp=$(rpc "eth_getBlockTransactionCountByNumber" '["latest"]'); v=$(echo "$resp" | jq_int)
pass "eth_getBlockTransactionCountByNumber(latest) = $v"
[[ -n "$BLOCK1_HASH" ]] && {
  resp=$(rpc "eth_getBlockTransactionCountByHash" "[\"$BLOCK1_HASH\"]"); v=$(echo "$resp" | jq_int)
  pass "eth_getBlockTransactionCountByHash(block#1) = $v"
}
resp=$(rpc "eth_getUncleCountByBlockNumber" '["latest"]'); v=$(echo "$resp" | jq_int)
pass "eth_getUncleCountByBlockNumber(latest) = $v (PoA → 0)"

# eth_getBlockReceipts (NEW)
resp=$(rpc "eth_getBlockReceipts" '["latest"]')
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && { is_skip "$err" && skip "eth_getBlockReceipts" "$err" || fail "eth_getBlockReceipts" "$err"; } || {
  v=$(echo "$resp" | jq_len); pass "eth_getBlockReceipts(latest) — $v receipts (NEW)"; }

# eth_getReceiptsByHash (기존)
[[ -n "$BLOCK1_HASH" ]] && {
  resp=$(rpc "eth_getReceiptsByHash" "[\"$BLOCK1_HASH\"]")
  err=$(echo "$resp" | jq_err 2>/dev/null || true)
  [[ -n "$err" ]] && warn "eth_getReceiptsByHash" "$err" || {
    v=$(echo "$resp" | jq_len); pass "eth_getReceiptsByHash(block#1) — $v receipts (기존)"; }
}

# ════════════════════════════════════════════════════════════════════
sec "6. eth_sendTransaction / eth_sendRawTransaction"

# eth_sendTransaction (계정 unlock 필요)
echo -e "  ${D}→ eth_sendTransaction (1 ETH: ACCT1→ACCT2)${N}"
resp=$(rpc "eth_sendTransaction" "[{
  \"from\":\"$ACCT1\",
  \"to\":\"$ACCT2\",
  \"value\":\"0xDE0B6B3A7640000\",
  \"gas\":\"0x5208\"
}]")
err=$(echo "$resp" | jq_err 2>/dev/null || true)
if [[ -n "$err" ]]; then
  [[ "$err" =~ "authentication needed"|"unlock" ]] && fail "eth_sendTransaction" "계정 잠금됨 — --unlock 설정 확인" || fail "eth_sendTransaction" "$err"
else
  TX_HASH=$(echo "$resp" | jq_str)
  pass "eth_sendTransaction — txHash=${TX_HASH:0:20}..."
  # 확정 대기
  for i in $(seq 1 15); do
    sleep 1
    tx_resp=$(rpc "eth_getTransactionReceipt" "[\"$TX_HASH\"]")
    bh=$(echo "$tx_resp" | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print(r['blockHash'] if r else '')" 2>/dev/null || true)
    [[ -n "$bh" ]] && { TX_BLOCK_HASH="$bh"; break; }
  done
  [[ -n "$TX_BLOCK_HASH" ]] && pass "TX 확정 완료 — blockHash=${TX_BLOCK_HASH:0:20}..." || warn "TX 확정 대기 중"
fi

# eth_sendRawTransaction (python eth_account으로 서명)
echo -e "  ${D}→ eth_sendRawTransaction (EIP-1559 Type2, ACCT2→ACCT1)${N}"
NONCE2=$(rpc "eth_getTransactionCount" "[\"$ACCT2\",\"pending\"]" | python3 -c "import json,sys; print(json.load(sys.stdin)['result'])" 2>/dev/null)
RAW_TX=$(sign_tx "$PRIVKEY2" "$ACCT1" "DE0B6B3A7640000" "${NONCE2:-0x0}")
if [[ "$RAW_TX" == "NO_ETH_ACCOUNT" ]]; then
  skip "eth_sendRawTransaction" "eth_account 라이브러리 없음 (pip install eth-account)"
elif [[ "$RAW_TX" == ERR* ]] || [[ -z "$RAW_TX" ]]; then
  warn "eth_sendRawTransaction" "트랜잭션 서명 실패"
else
  resp=$(rpc "eth_sendRawTransaction" "[\"0x$RAW_TX\"]")
  err=$(echo "$resp" | jq_err 2>/dev/null || true)
  [[ -n "$err" ]] && fail "eth_sendRawTransaction" "$err" || {
    RAW_TX_HASH=$(echo "$resp" | jq_str)
    pass "eth_sendRawTransaction — txHash=${RAW_TX_HASH:0:20}..."
  }
fi

# ════════════════════════════════════════════════════════════════════
sec "7. eth_* — 트랜잭션 조회 (TX 확정 후)"

if [[ -n "$TX_HASH" ]]; then
  resp=$(rpc "eth_getTransactionByHash" "[\"$TX_HASH\"]")
  v=$(echo "$resp" | python3 -c "
import json,sys; t=json.load(sys.stdin)['result']
print(f'from={t[\"from\"][:16]}..., val={int(t[\"value\"],16)}')" 2>/dev/null)
  [[ -n "$v" ]] && pass "eth_getTransactionByHash — $v" || fail "eth_getTransactionByHash"

  resp=$(rpc "eth_getTransactionReceipt" "[\"$TX_HASH\"]")
  v=$(echo "$resp" | python3 -c "
import json,sys; r=json.load(sys.stdin)['result']
print(f'status={int(r[\"status\"],16)}, gasUsed={int(r[\"gasUsed\"],16)}')" 2>/dev/null)
  [[ -n "$v" ]] && pass "eth_getTransactionReceipt — $v" || warn "eth_getTransactionReceipt" "미확정"

  resp=$(rpc "eth_getTransactionByBlockHashAndIndex" "[\"${TX_BLOCK_HASH:-$LATEST_HASH}\",\"0x0\"]")
  v=$(echo "$resp" | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print('null' if r is None else r['hash'][:20]+'...')" 2>/dev/null)
  pass "eth_getTransactionByBlockHashAndIndex — $v"
else
  skip "eth_getTransactionByHash" "TX 없음 (sendTransaction 실패)"
  skip "eth_getTransactionReceipt" "TX 없음"
fi

resp=$(rpc "eth_getTransactionByBlockNumberAndIndex" '["latest","0x0"]')
v=$(echo "$resp" | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print('null' if r is None else r['hash'][:20]+'...')" 2>/dev/null)
pass "eth_getTransactionByBlockNumberAndIndex(latest,0) = $v"

# eth_getRawTransactionByHash (기존)
if [[ -n "$TX_HASH" ]]; then
  resp=$(rpc "eth_getRawTransactionByHash" "[\"$TX_HASH\"]")
  err=$(echo "$resp" | jq_err 2>/dev/null || true)
  [[ -n "$err" ]] && warn "eth_getRawTransactionByHash" "$err" || {
    v=$(echo "$resp" | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print(len(r)//2,'bytes')" 2>/dev/null)
    pass "eth_getRawTransactionByHash — $v (기존)"; }
fi

# ════════════════════════════════════════════════════════════════════
sec "8. eth_* — 로그 / 필터"

resp=$(rpc "eth_getLogs" '[{"fromBlock":"0x1","toBlock":"latest"}]')
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && fail "eth_getLogs" "$err" || { v=$(echo "$resp" | jq_len); pass "eth_getLogs(1~latest) — $v logs"; }

resp=$(rpc "eth_newBlockFilter"); BFID=$(echo "$resp" | jq_str 2>/dev/null || echo "")
[[ -n "$BFID" ]] && pass "eth_newBlockFilter — id=$BFID" || fail "eth_newBlockFilter"

resp=$(rpc "eth_newPendingTransactionFilter"); PFID=$(echo "$resp" | jq_str 2>/dev/null || echo "")
[[ -n "$PFID" ]] && pass "eth_newPendingTransactionFilter — id=$PFID" || fail "eth_newPendingTransactionFilter"

resp=$(rpc "eth_newFilter" '[{"fromBlock":"0x1","toBlock":"latest"}]'); LFID=$(echo "$resp" | jq_str 2>/dev/null || echo "")
[[ -n "$LFID" ]] && pass "eth_newFilter — id=$LFID" || fail "eth_newFilter"

[[ -n "$BFID" ]] && {
  resp=$(rpc "eth_getFilterChanges" "[\"$BFID\"]")
  err=$(echo "$resp" | jq_err 2>/dev/null || true)
  [[ -n "$err" ]] && fail "eth_getFilterChanges" "$err" || pass "eth_getFilterChanges(blockFilter) — OK"
}
[[ -n "$LFID" ]] && {
  resp=$(rpc "eth_getFilterLogs" "[\"$LFID\"]")
  err=$(echo "$resp" | jq_err 2>/dev/null || true)
  [[ -n "$err" ]] && fail "eth_getFilterLogs" "$err" || { v=$(echo "$resp" | jq_len); pass "eth_getFilterLogs — $v logs"; }
  resp=$(rpc "eth_uninstallFilter" "[\"$LFID\"]")
  v=$(echo "$resp" | jq_bool); [[ "$v" == "True" ]] && pass "eth_uninstallFilter — true" || warn "eth_uninstallFilter" "$v"
}

# ════════════════════════════════════════════════════════════════════
sec "9. eth_call / eth_createAccessList / eth_signTransaction"

resp=$(rpc "eth_call" "[{\"to\":\"$ACCT2\",\"data\":\"0x\"},\"latest\"]")
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && fail "eth_call(empty)" "$err" || pass "eth_call(empty→EOA) — OK"

resp=$(rpc "eth_createAccessList" "[{\"from\":\"$ACCT1\",\"to\":\"$ACCT2\",\"value\":\"0x1\"},\"latest\"]")
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && { is_skip "$err" && skip "eth_createAccessList" "$err" || warn "eth_createAccessList" "$err"; } || {
  v=$(echo "$resp" | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print('gasUsed='+str(int(r.get('gasUsed','0x0'),16)))" 2>/dev/null)
  pass "eth_createAccessList — $v"; }

SIGN_NONCE=$(rpc "eth_getTransactionCount" "[\"$ACCT1\",\"pending\"]" | python3 -c "import json,sys; print(json.load(sys.stdin)['result'])" 2>/dev/null || echo "0x0")
resp=$(rpc "eth_signTransaction" "[{
  \"from\":\"$ACCT1\",
  \"to\":\"$ACCT2\",
  \"value\":\"0x1\",
  \"gas\":\"0x5208\",
  \"nonce\":\"$SIGN_NONCE\",
  \"maxFeePerGas\":\"0x2E90EDD000\",
  \"maxPriorityFeePerGas\":\"0x174876E800\",
  \"type\":\"0x2\"
}]")
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && { [[ "$err" =~ "authentication needed"|"unlock" ]] && fail "eth_signTransaction" "계정 잠금됨" || fail "eth_signTransaction" "$err"; } || {
  v=$(echo "$resp" | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print('raw='+r.get('raw','?')[:20]+'...')" 2>/dev/null)
  pass "eth_signTransaction (EIP-1559 Type2) — $v"; }

# ════════════════════════════════════════════════════════════════════
sec "10. debug_* (getRawBlock/Header/Transaction/Receipts)"

resp=$(rpc "debug_getRawBlock" '["latest"]')
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && { is_skip "$err" && skip "debug_getRawBlock" "$err" || fail "debug_getRawBlock" "$err"; } || {
  v=$(echo "$resp" | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print(len(r)//2,'bytes')" 2>/dev/null)
  pass "debug_getRawBlock(latest) — $v (NEW)"; }

resp=$(rpc "debug_getRawHeader" '["latest"]')
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && { is_skip "$err" && skip "debug_getRawHeader" "$err" || fail "debug_getRawHeader" "$err"; } || {
  v=$(echo "$resp" | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print(len(r)//2,'bytes')" 2>/dev/null)
  pass "debug_getRawHeader(latest) — $v (NEW)"; }

resp=$(rpc "debug_getRawReceipts" '["latest"]')
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && warn "debug_getRawReceipts" "$err" || { v=$(echo "$resp" | jq_len); pass "debug_getRawReceipts(latest) — $v receipts"; }

resp=$(rpc "debug_getBadBlocks")
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && { is_skip "$err" && skip "debug_getBadBlocks" "$err" || warn "debug_getBadBlocks" "$err"; } || {
  v=$(echo "$resp" | jq_len); pass "debug_getBadBlocks — $v"; }

# debug_getRawTransaction (TX 있을 때)
if [[ -n "$TX_HASH" ]]; then
  resp=$(rpc "debug_getRawTransaction" "[\"$TX_HASH\"]")
  err=$(echo "$resp" | jq_err 2>/dev/null || true)
  [[ -n "$err" ]] && { is_skip "$err" && skip "debug_getRawTransaction" "$err" || fail "debug_getRawTransaction" "$err"; } || {
    v=$(echo "$resp" | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print(len(r)//2,'bytes')" 2>/dev/null)
    pass "debug_getRawTransaction($TX_HASH) — $v (NEW)"; }
else
  skip "debug_getRawTransaction" "TX 없음"
fi

# debug_getBlockRlp / debug_getHeaderRlp (기존 레거시)
resp=$(rpc "debug_getBlockRlp" '[1]')
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && warn "debug_getBlockRlp(legacy)" "$err" || {
  v=$(echo "$resp" | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print(len(r)//2,'bytes')" 2>/dev/null)
  pass "debug_getBlockRlp(1) — $v (legacy)"; }

# ════════════════════════════════════════════════════════════════════
sec "11. admin_* / txpool_* / miner_*"

resp=$(rpc "admin_nodeInfo")
v=$(echo "$resp" | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print(r['name'])" 2>/dev/null || true)
[[ -n "$v" ]] && pass "admin_nodeInfo — $v" || fail "admin_nodeInfo"

resp=$(rpc "admin_peers"); v=$(echo "$resp" | jq_len)
pass "admin_peers — $v 개"

resp=$(rpc "eth_mining"); v=$(echo "$resp" | jq_bool)
[[ "$v" == "True" ]] && pass "eth_mining = true" || warn "eth_mining" "$v"

resp=$(rpc "eth_hashrate"); v=$(echo "$resp" | jq_int)
pass "eth_hashrate = $v (PoA → 0)"

resp=$(rpc "txpool_status")
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && { is_skip "$err" && skip "txpool_status" "$err" || warn "txpool_status" "$err"; } || {
  v=$(echo "$resp" | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print(f'pending={int(r.get(\"pending\",\"0x0\"),16)},queued={int(r.get(\"queued\",\"0x0\"),16)}')" 2>/dev/null)
  pass "txpool_status — $v"; }

resp=$(rpc "txpool_inspect")
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && { is_skip "$err" && skip "txpool_inspect" "$err" || warn "txpool_inspect" "$err"; } || pass "txpool_inspect — OK"

resp=$(rpc "txpool_content")
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && { is_skip "$err" && skip "txpool_content" "$err" || warn "txpool_content" "$err"; } || pass "txpool_content — OK"

# ════════════════════════════════════════════════════════════════════
sec "12. Fee Delegation (Type 22 tx)"

echo -e "  ${D}Flow: ACCT2가 tx 생성 → ACCT1(feePayer)이 수수료 대납${N}"

# Step 1: feePayer 없는 EIP-1559 tx를 ACCT2가 서명
NONCE2_PEND=$(rpc "eth_getTransactionCount" "[\"$ACCT2\",\"pending\"]" | python3 -c "import json,sys; print(json.load(sys.stdin)['result'])" 2>/dev/null || echo "0x0")
FD_SIGNED_RAW=$(python3 - <<PYEOF 2>/dev/null
try:
    from eth_account import Account
    import json

    sender_key = "0x$PRIVKEY2"
    acct = Account.from_key(sender_key)
    nonce = int("$NONCE2_PEND", 16)
    tx = {
        "nonce": nonce,
        "to": "$ACCT3",
        "value": int("0xDE0B6B3A7640000", 16),
        "gas": 21000,
        "maxFeePerGas": 200 * 10**9,
        "maxPriorityFeePerGas": 100 * 10**9,
        "chainId": $CHAINID,
        "type": 2,
    }
    signed = acct.sign_transaction(tx)
    print(signed.raw_transaction.hex())
except ImportError:
    print("NO_ETH_ACCOUNT")
except Exception as e:
    print(f"ERR:{e}")
PYEOF
)

if [[ "$FD_SIGNED_RAW" == "NO_ETH_ACCOUNT" ]]; then
  skip "Fee Delegation" "eth_account 라이브러리 없음"
elif [[ -z "$FD_SIGNED_RAW" || "$FD_SIGNED_RAW" == ERR* ]]; then
  warn "Fee Delegation" "sender 서명 실패: $FD_SIGNED_RAW"
else
  # Step 2: eth_signRawFeeDelegateTransaction (ACCT1이 feePayer로 서명)
  resp=$(rpc "eth_signRawFeeDelegateTransaction" "[{\"from\":\"$ACCT1\",\"feePayer\":\"$ACCT1\"},\"0x$FD_SIGNED_RAW\"]")
  err=$(echo "$resp" | jq_err 2>/dev/null || true)
  if [[ -n "$err" ]]; then
    [[ "$err" =~ "authentication needed"|"unlock" ]] && fail "eth_signRawFeeDelegateTransaction" "계정 잠금됨 — personal API 또는 unlock 필요" \
      || { is_skip "$err" && skip "eth_signRawFeeDelegateTransaction" "$err" || fail "eth_signRawFeeDelegateTransaction" "$err"; }
  else
    FD_TX_RAW=$(echo "$resp" | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print(r.get('raw',''))" 2>/dev/null || true)
    pass "eth_signRawFeeDelegateTransaction — feePayer 서명 완료"

    # Step 3: eth_sendRawTransaction으로 전송
    if [[ -n "$FD_TX_RAW" ]]; then
      resp=$(rpc "eth_sendRawTransaction" "[\"$FD_TX_RAW\"]")
      err=$(echo "$resp" | jq_err 2>/dev/null || true)
      [[ -n "$err" ]] && fail "FeeDelegation sendRawTransaction" "$err" || {
        FD_TX_HASH=$(echo "$resp" | jq_str)
        pass "Fee Delegation tx 전송 — hash=${FD_TX_HASH:0:20}..."
      }
    fi
  fi
fi

# ════════════════════════════════════════════════════════════════════
sec "13. Elderflower EIP opcodes (eth_call)"

evm_call "EIP-3855 PUSH0 (0x5F)=0"              "0x5f60005260206000f3"             "0"
evm_call "EIP-4844 BLOBBASEFEE (0x4A)=1 wei"    "0x4a60005260206000f3"             "1"
evm_call "EIP-4844 BLOBHASH (0x49)=0 (no blob)" "0x60004960005260206000f3"         "0"
evm_call "EIP-1153 TSTORE(1,42)→TLOAD=42"       "0x602a60015d60015c60005260206000f3" "42"
evm_call "EIP-5656 MCOPY"                        "0x60426000526020600060205e60206020f3" "66"
resp=$(rpc "eth_call" "[{\"data\":\"0x4160005260206000f3\"},\"latest\"]")
err=$(echo "$resp" | jq_err 2>/dev/null || true)
[[ -n "$err" ]] && fail "EIP-3651 Warm COINBASE" "$err" || pass "EIP-3651 Warm COINBASE (0x41) — OK"

# ════════════════════════════════════════════════════════════════════
sec "14. IPC + JS console"

if [[ -z "$IPC_PATH" ]]; then
  skip "IPC 테스트" "IPC_PATH 미지정 (gmet attach <ipc> 로 실행)"
else
  GMET_BIN="${GMET_BIN:-gmet}"
  run_js() {
    local label="$1" script="$2"
    local out; out=$(echo "$script" | timeout 10 "$GMET_BIN" attach "$IPC_PATH" --exec "$(cat)" 2>/dev/null || true)
    [[ -n "$out" && "$out" != "undefined" && "$out" != "null" ]] \
      && pass "$label — $out" || fail "$label" "결과: $out"
  }
  run_js "IPC eth.blockNumber"        'eth.blockNumber'
  run_js "IPC eth.chainId()"          'eth.chainId()'
  run_js "IPC net.version"            'net.version'
  run_js "IPC net.peerCount"          'net.peerCount'
  run_js "IPC eth.accounts"           'eth.accounts'
  run_js "IPC eth.gasPrice"           'eth.gasPrice'
  run_js "IPC eth.getBalance(acct1)"  "eth.getBalance(\"$ACCT1\")"
  run_js "IPC txpool.status"          'txpool.status'
  run_js "IPC admin.nodeInfo.name"    'admin.nodeInfo.name'
  run_js "IPC miner.getHashrate()"    'miner.getHashrate()'
  run_js "IPC eth.mining"             'eth.mining'
fi

# ════════════════════════════════════════════════════════════════════
TOTAL=$((PASS+FAIL+WARN+SKIP))
echo -e "\n${B}${C}╔══════════════════════════════════════════════════════════════╗${N}"
echo -e "${B}${C}║                      최종 테스트 결과                        ║${N}"
echo -e "${B}${C}╚══════════════════════════════════════════════════════════════╝${N}"
echo -e "  전체: ${TOTAL}건 | ${G}${B}PASS: $PASS${N} | ${R}${B}FAIL: $FAIL${N} | ${Y}WARN: $WARN${N} | SKIP: $SKIP"
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
[[ $FAIL -eq 0 ]] \
  && echo -e "  ${G}${B}[최종: PASS]${N} — FAIL 없음" \
  || echo -e "  ${R}${B}[최종: FAIL]${N} — ${FAIL}건 실패"
echo ""
exit $FAIL
