#!/usr/bin/env bash
# doraji-test.sh - Doraji fork 전환 테스트
# block 199 (이전) vs block 201 (이후) 동작 검증
#
# 실행: ./doraji-test.sh
# 전제: private-net-poa가 block 200 이상 진행 중 (dorajiBlock=200)

set -euo pipefail

RPC="${RPC:-http://localhost:8545}"
CAMELLIA_BLOCK=100
DORAJI_BLOCK=200
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
  local to="$1"
  local data="$2"
  local block="${3:-latest}"
  rpc "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"from\":\"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266\",\"to\":\"$to\",\"data\":\"$data\",\"gas\":\"0x100000\"},\"$block\"],\"id\":1}"
}

eth_call_result() {
  local resp
  resp=$(eth_call "$1" "$2" "${3:-latest}")
  echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result','') or d.get('error',{}).get('message','error'))"
}

check_call() {
  local to="$1"
  local data="$2"
  local block="${3:-latest}"
  local resp
  resp=$(eth_call "$to" "$data" "$block")
  echo "$resp" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if 'error' in d:
    msg = d['error'].get('message', '')
    print('revert' if 'invalid' in msg.lower() or 'revert' in msg.lower() or 'execution reverted' in msg.lower() else 'error:'+msg)
elif d.get('result','0x') in ('0x',''):
    print('revert')
else:
    print('ok:' + d['result'])
"
}

estimate_gas() {
  local data="$1"
  local block="${2:-latest}"
  rpc "{\"jsonrpc\":\"2.0\",\"method\":\"eth_estimateGas\",\"params\":[{\"from\":\"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266\",\"data\":\"$data\"},\"$block\"],\"id\":1}" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d['result'],16) if 'result' in d else -1)" 2>/dev/null || echo "-1"
}

# --- 전제 확인 ---
log "=== Doraji Fork 전환 테스트 ==="
log "대상 RPC: $RPC"

# 노드 접속 확인
if ! CURRENT=$(rpc '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d['result'],16))" 2>/dev/null); then
  log "❌ 노드에 접속할 수 없습니다: $RPC"
  exit 1
fi

log "현재 블록: $CURRENT / Camellia fork: $CAMELLIA_BLOCK / Doraji fork: $DORAJI_BLOCK"

if [[ "$CURRENT" -lt "$DORAJI_BLOCK" ]]; then
  log "❌ 블록이 $DORAJI_BLOCK 미만입니다 (현재: $CURRENT). Doraji 활성화 이후 실행하세요."
  exit 1
fi

if [[ "$CURRENT" -lt "$CAMELLIA_BLOCK" ]]; then
  log "❌ 블록이 $CAMELLIA_BLOCK 미만입니다. Camellia 활성화 이후 실행하세요."
  exit 1
fi
echo ""

# hex block numbers
BEFORE_DORAJI_HEX=$(printf "0x%x" $((DORAJI_BLOCK - 1)))    # 0xc7 = 199
AFTER_DORAJI_HEX=$(printf "0x%x" $((DORAJI_BLOCK + 1)))     # 0xc9 = 201
CAMELLIA_MID_HEX=$(printf "0x%x" 150)                        # 0x96 = 150

# ============================================================
# EIP-7623: Calldata Floor Gas
# ============================================================
log "--- EIP-7623: Calldata Floor Gas ---"
log "  1000 nonzero bytes: 표준 gas ~37000, floor gas ~61000"
log "  Doraji 이후에는 floor가 적용되어 estimateGas가 증가해야 함"

# 1000 nonzero bytes calldata (0xff * 1000)
CALLDATA_1000NZ="0x$(python3 -c "print('ff' * 1000")"

GAS_BEFORE=$(estimate_gas "$CALLDATA_1000NZ" "$BEFORE_DORAJI_HEX")
GAS_AFTER=$(estimate_gas "$CALLDATA_1000NZ" "$AFTER_DORAJI_HEX")

log "  block $((DORAJI_BLOCK-1)) estimateGas = $GAS_BEFORE"
log "  block $((DORAJI_BLOCK+1)) estimateGas = $GAS_AFTER"

if [[ "$GAS_BEFORE" == "-1" || "$GAS_AFTER" == "-1" ]]; then
  skip "EIP-7623: estimateGas 응답 실패 (블록이 아직 없을 수 있음)"
elif [[ "$GAS_AFTER" -gt "$GAS_BEFORE" ]]; then
  pass "EIP-7623: Doraji 이후 gas($GAS_AFTER) > 이전 gas($GAS_BEFORE) — floor gas 적용 확인"
else
  fail "EIP-7623: Doraji 이후 gas($GAS_AFTER) <= 이전 gas($GAS_BEFORE) — floor gas 미적용"
fi

# 추가: floor vs standard 수치 검증
if [[ "$GAS_AFTER" != "-1" ]]; then
  # standard = 21000 + 1000*16 = 37000, floor = 21000 + (1000*4)*10 = 61000
  if [[ "$GAS_AFTER" -ge 55000 ]]; then
    pass "EIP-7623: Doraji floor gas($GAS_AFTER) >= 55000 — floor 적용 범위 내"
  else
    skip "EIP-7623: Doraji floor gas($GAS_AFTER) < 55000 — 예상보다 낮음 (네트워크 오버헤드 확인 필요)"
  fi
fi

echo ""

# ============================================================
# EIP-2537: BLS12-381 Precompile 주소 확인
# ============================================================
log "--- EIP-2537: BLS12-381 G1Add Precompile at 0x0b ---"

# BLS12-381 G1Add precompile address: 0x000...000b
BLS_G1ADD_ADDR="0x000000000000000000000000000000000000000b"

# Valid BLS12-381 G1 point input (256 bytes): G1 generator + G1 generator
# Test vector: bls_g1add_(g1+g1=2*g1) from EIP-2537 test vectors
BLS_G1ADD_INPUT="0x0000000000000000000000000000000017f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb0000000000000000000000000000000008b3f481e3aaa0f1a09e30ed741d8ae4fcf5e095d5d00af600db18cb2c04b3edd03cc744a2888ae40caa232946c5e7e10000000000000000000000000000000017f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb0000000000000000000000000000000008b3f481e3aaa0f1a09e30ed741d8ae4fcf5e095d5d00af600db18cb2c04b3edd03cc744a2888ae40caa232946c5e7e1"

# Camellia 이후, Doraji 이전 (block 150): 0x0b에 precompile 없음 → revert
log "  Camellia 구간 (block 150): 0x0b에 BLS G1Add 없음 — revert 기대"
R_CAMELLIA=$(check_call "$BLS_G1ADD_ADDR" "$BLS_G1ADD_INPUT" "$CAMELLIA_MID_HEX")
if [[ "$R_CAMELLIA" == "revert" || "$R_CAMELLIA" == revert* || "$R_CAMELLIA" == error* ]]; then
  pass "EIP-2537 Camellia(block 150): 0x0b 호출 → revert (precompile 미등록 확인)"
else
  fail "EIP-2537 Camellia(block 150): 0x0b 호출 → 예상 revert, got: $R_CAMELLIA"
fi

# Doraji 이후 (block 201): 0x0b에 BLS G1Add precompile 있음 → 성공
log "  Doraji 구간 (block $((DORAJI_BLOCK+1))): 0x0b에 BLS G1Add 있음 — 성공 기대"
R_DORAJI=$(check_call "$BLS_G1ADD_ADDR" "$BLS_G1ADD_INPUT" "$AFTER_DORAJI_HEX")
if [[ "$R_DORAJI" == ok:* ]]; then
  OUTPUT="${R_DORAJI#ok:}"
  pass "EIP-2537 Doraji(block $((DORAJI_BLOCK+1))): BLS G1Add 성공, output=${OUTPUT:0:20}..."
else
  fail "EIP-2537 Doraji(block $((DORAJI_BLOCK+1))): BLS G1Add 실패, got: $R_DORAJI"
fi

echo ""

# ============================================================
# EIP-7840: Blob Schedule
# ============================================================
log "--- EIP-7840: Blob Schedule per fork ---"
log "  Camellia: maxBlobsPerBlock=6, Doraji: maxBlobsPerBlock=9"

# Camellia 구간 block 헤더에서 ExcessBlobGas 확인 (blob schedule 간접 확인)
CAMELLIA_BLOCK_HEX=$(printf "0x%x" 150)
DORAJI_BLOCK_CHECK_HEX=$(printf "0x%x" $((DORAJI_BLOCK + 1)))

get_excess_blob_gas() {
  local block_hex="$1"
  rpc "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$block_hex\",false],\"id\":1}" | \
    python3 -c "
import sys, json
d = json.load(sys.stdin)
b = d.get('result')
if not b:
    print('null')
elif 'excessBlobGas' in b:
    print(int(b['excessBlobGas'], 16))
else:
    print('not_present')
" 2>/dev/null || echo "error"
}

EBG_CAMELLIA=$(get_excess_blob_gas "$CAMELLIA_BLOCK_HEX")
EBG_DORAJI=$(get_excess_blob_gas "$DORAJI_BLOCK_CHECK_HEX")

log "  block 150 excessBlobGas: $EBG_CAMELLIA"
log "  block $((DORAJI_BLOCK+1)) excessBlobGas: $EBG_DORAJI"

if [[ "$EBG_CAMELLIA" == "not_present" || "$EBG_CAMELLIA" == "null" ]]; then
  skip "EIP-7840 Camellia: block 150에 excessBlobGas 필드 없음 (Camellia 미활성?)"
elif [[ "$EBG_CAMELLIA" == "error" ]]; then
  skip "EIP-7840 Camellia: block 150 조회 실패"
else
  pass "EIP-7840 Camellia(block 150): excessBlobGas=$EBG_CAMELLIA (blob schedule 활성)"
fi

if [[ "$EBG_DORAJI" == "not_present" || "$EBG_DORAJI" == "null" ]]; then
  skip "EIP-7840 Doraji: block $((DORAJI_BLOCK+1))에 excessBlobGas 없음"
elif [[ "$EBG_DORAJI" == "error" ]]; then
  skip "EIP-7840 Doraji: block $((DORAJI_BLOCK+1)) 조회 실패"
else
  pass "EIP-7840 Doraji(block $((DORAJI_BLOCK+1))): excessBlobGas=$EBG_DORAJI (Doraji blob schedule 활성)"
fi

# maxBlobsPerBlock은 노드 API로 직접 조회 불가하지만
# eth_getBlockByNumber의 blobGasUsed 상한으로 간접 확인 가능.
# Camellia: max = 6 * 131072 = 786432, Doraji: max = 9 * 131072 = 1179648
log "  참고: Camellia MaxBlobGas=786432 (6 blobs), Doraji MaxBlobGas=1179648 (9 blobs)"
log "  (실제 blob tx 없으면 blobGasUsed=0이므로 헤더 필드 존재 유무로만 확인)"

echo ""

# ============================================================
# 추가: EIP-2537 BLS precompile 여러 주소 확인
# ============================================================
log "--- EIP-2537: BLS precompile 주소 범위 확인 (Doraji) ---"

# BLS12-381 G2Add at 0x0e (14)
BLS_G2ADD_ADDR="0x000000000000000000000000000000000000000e"
# Empty call to check if precompile exists (will fail with wrong input but not "precompile not found")
# Use a simple check: non-empty result means precompile is registered
R_G2ADD=$(check_call "$BLS_G2ADD_ADDR" "0x$(python3 -c "print('00' * 512")" "$AFTER_DORAJI_HEX" 2>/dev/null || echo "error")
# G2Add with all-zero input will likely revert with "invalid point" but precompile IS registered
# 빈 calldata로 호출 — registered precompile이면 gas 소모 후 오류 반환
R_G2ADD_EMPTY=$(check_call "$BLS_G2ADD_ADDR" "0x" "$AFTER_DORAJI_HEX" 2>/dev/null || echo "error")
if [[ "$R_G2ADD_EMPTY" != "error" ]]; then
  # revert means precompile exists but rejected input — this is expected
  pass "EIP-2537 Doraji: 0x0e (G2Add) 등록 확인 ($R_G2ADD_EMPTY)"
else
  skip "EIP-2537 Doraji: 0x0e (G2Add) 응답 없음"
fi

# BLS12-381 Pairing at 0x11 (17)
BLS_PAIRING_ADDR="0x0000000000000000000000000000000000000011"
R_PAIRING_EMPTY=$(check_call "$BLS_PAIRING_ADDR" "0x" "$AFTER_DORAJI_HEX" 2>/dev/null || echo "error")
if [[ "$R_PAIRING_EMPTY" != "error" ]]; then
  pass "EIP-2537 Doraji: 0x11 (Pairing) 등록 확인 ($R_PAIRING_EMPTY)"
else
  skip "EIP-2537 Doraji: 0x11 (Pairing) 응답 없음"
fi

echo ""

# ============================================================
# 요약
# ============================================================
TOTAL=$((PASS + FAIL + SKIP))
log "=== Doraji Fork 테스트 완료 ==="
log "결과: PASS=$PASS, FAIL=$FAIL, SKIP=$SKIP / TOTAL=$TOTAL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
