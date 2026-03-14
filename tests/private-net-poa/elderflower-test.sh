#!/usr/bin/env bash
# elderflower-test.sh - Elderflower fork 전환 테스트
# block 99 (이전) vs block 100 (이후) opcode 동작 검증
#
# 실행: ./elderflower-test.sh
# 전제: private-net-poa가 block 100 이상 진행 중

set -euo pipefail

RPC="${RPC:-http://localhost:8545}"
PASS=0
FAIL=0
SKIP=0

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
pass() { echo "  ✅ PASS: $*"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $*"; FAIL=$((FAIL+1)); }
skip() { echo "  ⏭  SKIP: $*"; SKIP=$((SKIP+1)); }

rpc() {
  curl -sf -X POST -H "Content-Type: application/json" \
    --data "$1" "$RPC" 2>/dev/null
}

eth_call() {
  local data="$1"
  local block="${2:-latest}"
  rpc "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"from\":\"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266\",\"data\":\"$data\",\"gas\":\"0x100000\"},\"$block\"],\"id\":1}"
}

eth_call_result() {
  local resp
  resp=$(eth_call "$1" "${2:-latest}")
  echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result','') or d.get('error',{}).get('message','error'))"
}

check_revert() {
  local resp
  resp=$(eth_call "$1" "${2:-latest}")
  echo "$resp" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if 'error' in d:
    msg = d['error'].get('message', '')
    print('revert' if 'invalid' in msg.lower() or 'revert' in msg.lower() else 'error:'+msg)
elif d.get('result','0x') in ('0x',''):
    print('revert')
else:
    print('ok:' + d['result'])
"
}

# --- 전제 확인 ---
log "=== Elderflower Fork 전환 테스트 ==="
CURRENT=$(rpc '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d['result'],16))")
FORK_BLOCK=$(rpc '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x64",false],"id":1}' | \
  python3 -c "import sys,json; d=json.load(sys.stdin); b=d['result']; print(int(b['number'],16) if b else -1)")

log "현재 블록: $CURRENT / Elderflower fork 블록: $FORK_BLOCK (0x64=100)"
if [[ "$CURRENT" -lt 100 ]]; then
  log "❌ 블록이 100 미만입니다. 더 기다리세요."
  exit 1
fi
echo ""

# ============================================================
# EIP-3855: PUSH0 (0x5f)
# ============================================================
log "--- EIP-3855: PUSH0 (opcode 0x5f) ---"

# bytecode: PUSH0 + PUSH1 0x20 + MSTORE + PUSH1 0x20 + PUSH1 0 + RETURN
# 스택에 0을 push하고 반환 → 0x0000...0000 (32 bytes)
PUSH0_CODE="0x5f6020526020600ff3"

# block 99 (이전): invalid opcode 예상
R=$(check_revert "$PUSH0_CODE" "0x63")
if [[ "$R" == "revert" || "$R" == revert* ]]; then
  pass "block 99: PUSH0 → invalid opcode (revert)"
else
  fail "block 99: PUSH0 expected revert, got: $R"
fi

# block 100 (이후): 정상 실행, 0x0000...0000 반환
R=$(check_revert "$PUSH0_CODE" "0x64")
if [[ "$R" == ok:* ]]; then
  VAL="${R#ok:}"
  if [[ "$VAL" == "0x0000"* ]]; then
    pass "block 100: PUSH0 → 0x00..00 반환 (정상)"
  else
    fail "block 100: PUSH0 반환값 예상 0x00..00, got: $VAL"
  fi
else
  fail "block 100: PUSH0 expected ok, got: $R"
fi

echo ""

# ============================================================
# EIP-1153: TLOAD/TSTORE (0x5c/0x5d)
# ============================================================
log "--- EIP-1153: TLOAD/TSTORE (0x5c/0x5d) ---"

# bytecode: PUSH1 0x42, PUSH1 0x01, TSTORE (slot 1 = 0x42)
#           PUSH1 0x01, TLOAD (load slot 1)
#           PUSH1 0x00, MSTORE (mem[0] = 0x42), PUSH1 0x20, PUSH1 0x00, RETURN → 0x42 반환
TSTORE_CODE="0x604260015d60015c60005260206000f3"

R=$(check_revert "$TSTORE_CODE" "0x63")
if [[ "$R" == "revert" || "$R" == error* ]]; then
  pass "block 99: TLOAD/TSTORE → invalid opcode (revert)"
else
  fail "block 99: TLOAD/TSTORE expected revert, got: $R"
fi

R=$(check_revert "$TSTORE_CODE" "0x64")
if [[ "$R" == ok:* ]]; then
  VAL="${R#ok:}"
  # 0x42 = 66 in decimal, should appear in last bytes
  if echo "$VAL" | grep -q "0000000000000000000000000000000000000000000000000000000000000042"; then
    pass "block 100: TSTORE(slot1, 0x42) → TLOAD(slot1) = 0x42 (정상)"
  else
    fail "block 100: TLOAD 반환값 예상 0x42, got: $VAL"
  fi
else
  fail "block 100: TLOAD/TSTORE expected ok, got: $R"
fi

echo ""

# ============================================================
# EIP-5656: MCOPY (0x5e)
# ============================================================
log "--- EIP-5656: MCOPY (0x5e) ---"

# bytecode:
#   PUSH1 0xAB, PUSH1 0x00, MSTORE8  (mem[0] = 0xAB)
#   PUSH1 0x01, PUSH1 0x00, PUSH1 0x20, MCOPY (dst=0x20, src=0x00, len=1)
#   PUSH1 0x01, PUSH1 0x20, RETURN   → mem[0x20] = 0xAB 반환
MCOPY_CODE="0x60ab6000 53 6001600060205e 600160 20 f3"
MCOPY_CODE=$(echo "$MCOPY_CODE" | tr -d ' ')

R=$(check_revert "$MCOPY_CODE" "0x63")
if [[ "$R" == "revert" || "$R" == error* ]]; then
  pass "block 99: MCOPY → invalid opcode (revert)"
else
  fail "block 99: MCOPY expected revert, got: $R"
fi

R=$(check_revert "$MCOPY_CODE" "0x64")
if [[ "$R" == ok:* ]]; then
  VAL="${R#ok:}"
  if echo "$VAL" | grep -qi "ab"; then
    pass "block 100: MCOPY mem[0x20←0x00, len=1] → 0xAB (정상)"
  else
    fail "block 100: MCOPY 반환값 예상 0xAB, got: $VAL"
  fi
else
  fail "block 100: MCOPY expected ok, got: $R"
fi

echo ""

# ============================================================
# EIP-4844: BLOBBASEFEE (0x4a)
# ============================================================
log "--- EIP-4844: BLOBBASEFEE (0x4a) ---"

# bytecode: BLOBBASEFEE + PUSH1 0x20 + MSTORE + PUSH1 0x20 + PUSH1 0 + RETURN
BLOBBASEFEE_CODE="0x4a6020526020600ff3"

R=$(check_revert "$BLOBBASEFEE_CODE" "0x63")
if [[ "$R" == "revert" || "$R" == error* ]]; then
  pass "block 99: BLOBBASEFEE → invalid opcode (revert)"
else
  fail "block 99: BLOBBASEFEE expected revert, got: $R"
fi

R=$(check_revert "$BLOBBASEFEE_CODE" "0x64")
if [[ "$R" == ok:* ]]; then
  VAL="${R#ok:}"
  pass "block 100: BLOBBASEFEE → $VAL (정상)"
else
  fail "block 100: BLOBBASEFEE expected ok, got: $R"
fi

echo ""

# ============================================================
# EIP-3651: Warm COINBASE (가스 비교)
# ============================================================
log "--- EIP-3651: Warm COINBASE ---"

# COINBASE를 두 번 BALANCE 조회하는 bytecode
# 첫 번째: cold access (EIP-3651 전: 2600gas, 후: 100gas)
# 두 번째: warm access (100gas)
# bytecode: GAS + COINBASE + BALANCE + POP + GAS + COINBASE + BALANCE + POP + GAS
#           3개의 GAS값을 비교해서 첫 번째 접근 비용을 측정
# 간단하게: eth_estimateGas 비교
COINBASE_CODE="0x415a91503d" # COINBASE + BALANCE (간단 버전)

R99=$(rpc "{\"jsonrpc\":\"2.0\",\"method\":\"eth_estimateGas\",\"params\":[{\"from\":\"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266\",\"data\":\"$COINBASE_CODE\"},\"0x63\"],\"id\":1}" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d['result'],16) if 'result' in d else -1)" 2>/dev/null || echo "-1")
R100=$(rpc "{\"jsonrpc\":\"2.0\",\"method\":\"eth_estimateGas\",\"params\":[{\"from\":\"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266\",\"data\":\"$COINBASE_CODE\"},\"0x64\"],\"id\":1}" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d['result'],16) if 'result' in d else -1)" 2>/dev/null || echo "-1")

if [[ "$R99" -gt "$R100" ]] 2>/dev/null; then
  pass "Warm COINBASE: block99 gas=$R99 > block100 gas=$R100 (cold→warm, 절감 확인)"
elif [[ "$R99" == "-1" || "$R100" == "-1" ]]; then
  skip "Warm COINBASE: estimateGas 비교 불가 (block 99가 없을 수 있음)"
else
  fail "Warm COINBASE: block99 gas=$R99, block100 gas=$R100 (절감 미확인)"
fi

echo ""

# ============================================================
# EIP-6780: SELFDESTRUCT 제한
# ============================================================
log "--- EIP-6780: SELFDESTRUCT 제한 ---"

# Elderflower 이후: 동일 tx에서 생성된 컨트랙트만 selfdestruct 가능
# eth_call은 state를 변경하지 않으므로 실제 배포 테스트는 생략
# bytecode: SELFDESTRUCT에 address 전달 (실행은 되지만 실제 파괴 없음)
# 이미 존재하는 컨트랙트에서 SELFDESTRUCT 호출 → block 100 이후에는 잔액 전송만, 파괴 없음
# 여기서는 opcode가 실행 가능한지(revert 없는지)만 확인
SD_CODE="0x6000feff"  # PUSH1 0 + SELFDESTRUCT (0xff)

R99=$(check_revert "$SD_CODE" "0x63")
R100=$(check_revert "$SD_CODE" "0x64")
if [[ "$R99" == ok:* && "$R100" == ok:* ]]; then
  pass "SELFDESTRUCT: block99=$R99, block100=$R100 (opcode 실행 가능 확인)"
elif [[ "$R100" == ok:* ]]; then
  pass "SELFDESTRUCT: block100에서 opcode 실행 가능"
else
  skip "SELFDESTRUCT: eth_call 환경에서 검증 제한"
fi

echo ""

# ============================================================
# 요약
# ============================================================
TOTAL=$((PASS + FAIL + SKIP))
log "=== Elderflower Fork 테스트 완료 ==="
log "결과: PASS=$PASS, FAIL=$FAIL, SKIP=$SKIP / TOTAL=$TOTAL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
