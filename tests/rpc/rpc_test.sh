#!/usr/bin/env bash
# rpc_test.sh - go-metadium(gmet) 노드 RPC 테스트 스크립트
#
# 사용법:
#   ./rpc_test.sh                   # 기본값: http://127.0.0.1:8588
#   ./rpc_test.sh http://127.0.0.1:8590   # RocksDB 노드
#   ./rpc_test.sh http://127.0.0.1:8588 http://127.0.0.1:8590  # 둘 다 테스트

set -euo pipefail

# ─── 색상 정의 ───────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── 유틸리티 함수 ────────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
    local label="$1"
    echo -e "  ${GREEN}[PASS]${RESET} ${label}"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    local label="$1"
    local detail="${2:-}"
    echo -e "  ${RED}[FAIL]${RESET} ${label}"
    if [[ -n "$detail" ]]; then
        echo -e "         ${RED}↳ ${detail}${RESET}"
    fi
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
    local label="$1"
    local detail="${2:-}"
    echo -e "  ${YELLOW}[WARN]${RESET} ${label}"
    if [[ -n "$detail" ]]; then
        echo -e "         ${YELLOW}↳ ${detail}${RESET}"
    fi
    WARN_COUNT=$((WARN_COUNT + 1))
}

section() {
    echo ""
    echo -e "${CYAN}${BOLD}━━━ $1 ━━━${RESET}"
}

# JSON-RPC 호출 함수
# 반환: HTTP body (stdout), 상태코드 ($RPC_STATUS)
RPC_STATUS=0
rpc_call() {
    local url="$1"
    local method="$2"
    local params="${3:-[]}"
    local timeout="${4:-10}"

    local payload
    payload=$(printf '{"jsonrpc":"2.0","method":"%s","params":%s,"id":1}' "$method" "$params")

    local response
    response=$(curl -s --max-time "$timeout" \
        -X POST \
        -H "Content-Type: application/json" \
        --data "$payload" \
        "$url" 2>/dev/null) || true

    RPC_STATUS=$?
    echo "$response"
}

# python3로 JSON 필드 추출
# 사용: json_get "$json" "result"
json_get() {
    local json="$1"
    local field="$2"
    python3 -c "
import json, sys
try:
    data = json.loads('''$json''')
    val = data.get('$field')
    if val is None:
        sys.exit(1)
    print(val)
except Exception as e:
    sys.exit(1)
" 2>/dev/null
}

# JSON에 특정 키가 존재하는지 확인 (exit code)
json_has() {
    local json="$1"
    local field="$2"
    python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    if '$field' in data and data['$field'] is not None:
        sys.exit(0)
    sys.exit(1)
except:
    sys.exit(1)
" <<< "$json" 2>/dev/null
}

# JSON error 필드 확인
json_has_error() {
    local json="$1"
    python3 -c "
import json, sys
try:
    data = json.loads('''$json''')
    if 'error' in data:
        print(data['error'].get('message','unknown error'))
        sys.exit(0)
    sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null
}

# hex → decimal 변환
hex_to_dec() {
    python3 -c "print(int('$1', 16))" 2>/dev/null || echo "?"
}

# ─── 노드별 테스트 실행 ───────────────────────────────────────────────────────
run_tests() {
    local NODE_URL="$1"
    local NODE_LABEL="${2:-Node}"

    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${BLUE}║  테스트 노드: ${NODE_LABEL}${RESET}"
    echo -e "${BOLD}${BLUE}║  URL: ${NODE_URL}${RESET}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════╝${RESET}"

    # 카운터 초기화 (노드별)
    PASS_COUNT=0
    FAIL_COUNT=0
    WARN_COUNT=0

    # ── 1. 기본 연결 ──────────────────────────────────────────────────────────
    section "1. 기본 연결"

    # net_version
    local resp
    resp=$(rpc_call "$NODE_URL" "net_version")
    if [[ $RPC_STATUS -ne 0 ]] || [[ -z "$resp" ]]; then
        fail "net_version — 노드 연결 실패 (URL: $NODE_URL)"
        echo ""
        echo -e "${RED}${BOLD}[오류] 노드에 연결할 수 없습니다. 나머지 테스트를 건너뜁니다.${RESET}"
        echo ""
        return 1
    fi
    local net_ver
    net_ver=$(json_get "$resp" "result") && pass "net_version = $net_ver" || fail "net_version — 응답 파싱 실패: $resp"

    # net_peerCount
    resp=$(rpc_call "$NODE_URL" "net_peerCount")
    local peer_hex
    peer_hex=$(json_get "$resp" "result") && {
        local peer_dec
        peer_dec=$(hex_to_dec "$peer_hex")
        pass "net_peerCount = $peer_dec (hex: $peer_hex)"
    } || fail "net_peerCount — 응답 파싱 실패: $resp"

    # eth_blockNumber
    resp=$(rpc_call "$NODE_URL" "eth_blockNumber")
    local block_hex
    block_hex=$(json_get "$resp" "result") && {
        local block_dec
        block_dec=$(hex_to_dec "$block_hex")
        pass "eth_blockNumber = $block_dec (hex: $block_hex)"
        LATEST_BLOCK_HEX="$block_hex"
        LATEST_BLOCK_DEC="$block_dec"
    } || fail "eth_blockNumber — 응답 파싱 실패: $resp"

    # ── 2. 블록 조회 ──────────────────────────────────────────────────────────
    section "2. 블록 조회"

    # eth_getBlockByNumber (latest) — 동기화 전에도 작동해야 함
    resp=$(rpc_call "$NODE_URL" "eth_getBlockByNumber" '["latest", false]')
    local err_msg
    err_msg=$(json_has_error "$resp") && warn "eth_getBlockByNumber(latest) — 노드 응답 오류: $err_msg" || {
        python3 -c "
import json, sys
try:
    data = json.loads('''$resp''')
    b = data.get('result')
    if b and 'number' in b:
        num = int(b['number'], 16)
        ts = int(b.get('timestamp','0x0'), 16)
        print(f'블록 #{num}, txs={len(b.get(\"transactions\",[]))}, ts={ts}')
        sys.exit(0)
    sys.exit(1)
except Exception as e:
    sys.exit(1)
" 2>/dev/null | { read -r info && pass "eth_getBlockByNumber(latest) — $info"; } || \
        warn "eth_getBlockByNumber(latest) — 결과 없음 (동기화 중일 수 있음)"
    }

    # eth_getBlockByNumber (genesis = 0x0)
    resp=$(rpc_call "$NODE_URL" "eth_getBlockByNumber" '["0x0", false]')
    err_msg=$(json_has_error "$resp") && warn "eth_getBlockByNumber(0x0) — 오류: $err_msg" || {
        python3 -c "
import json, sys
try:
    data = json.loads('''$resp''')
    b = data.get('result')
    if b and 'number' in b:
        num = int(b['number'], 16)
        h = b.get('hash','')
        print(f'제네시스 블록 hash={h[:18]}...')
        sys.exit(0)
    sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null | { read -r info && pass "eth_getBlockByNumber(0x0) — $info"; GENESIS_HASH=$(python3 -c "import json; d=json.loads('''$resp'''); print(d['result']['hash'])"); } || \
        warn "eth_getBlockByNumber(0x0) — 제네시스 블록 없음"
    }

    # eth_getBlockByNumber (0x1)
    resp=$(rpc_call "$NODE_URL" "eth_getBlockByNumber" '["0x1", false]')
    err_msg=$(json_has_error "$resp") && warn "eth_getBlockByNumber(0x1) — 오류: $err_msg" || {
        python3 -c "
import json, sys
try:
    data = json.loads('''$resp''')
    b = data.get('result')
    if b and 'number' in b:
        num = int(b['number'], 16)
        h = b.get('hash','')
        print(f'블록 #1 hash={h[:18]}...')
        sys.exit(0)
    sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null | { read -r info && pass "eth_getBlockByNumber(0x1) — $info"; BLOCK1_HASH=$(python3 -c "import json; d=json.loads('''$resp'''); print(d['result']['hash'])"); } || \
        warn "eth_getBlockByNumber(0x1) — 블록 없음 (동기화 중)"
    }

    # eth_getBlockByHash (블록 #1 해시 사용, 있으면)
    if [[ -n "${BLOCK1_HASH:-}" ]]; then
        resp=$(rpc_call "$NODE_URL" "eth_getBlockByHash" "[\"$BLOCK1_HASH\", false]")
        err_msg=$(json_has_error "$resp") && fail "eth_getBlockByHash — 오류: $err_msg" || {
            python3 -c "
import json, sys
try:
    data = json.loads('''$resp''')
    b = data.get('result')
    if b and 'number' in b:
        num = int(b['number'], 16)
        print(f'블록 #{num} 조회 성공')
        sys.exit(0)
    sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null | { read -r info && pass "eth_getBlockByHash(block#1) — $info"; } || \
            fail "eth_getBlockByHash — 응답 파싱 실패"
        }
    else
        warn "eth_getBlockByHash — 블록 #1 해시 없음, 테스트 건너뜀"
    fi

    # ── 3. 동기화 상태 ────────────────────────────────────────────────────────
    section "3. 동기화 상태"

    resp=$(rpc_call "$NODE_URL" "eth_syncing")
    err_msg=$(json_has_error "$resp") && fail "eth_syncing — 오류: $err_msg" || {
        python3 -c "
import json, sys
try:
    data = json.loads('''$resp''')
    result = data.get('result')
    if result is False:
        print('동기화 완료 (syncing=false)')
    elif isinstance(result, dict):
        cur = int(result.get('currentBlock','0x0'), 16)
        high = int(result.get('highestBlock','0x0'), 16)
        pct = (cur / high * 100) if high > 0 else 0
        print(f'동기화 중: {cur:,} / {high:,} ({pct:.1f}%)')
    else:
        print(f'알 수 없는 상태: {result}')
    sys.exit(0)
except Exception as e:
    print(f'파싱 오류: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null | { read -r info && pass "eth_syncing — $info"; } || \
        fail "eth_syncing — 응답 파싱 실패: $resp"
    }

    # ── 4. 체인 설정 ──────────────────────────────────────────────────────────
    section "4. 체인 설정"

    # eth_chainId
    resp=$(rpc_call "$NODE_URL" "eth_chainId")
    local chain_hex
    chain_hex=$(json_get "$resp" "result") && {
        local chain_dec
        chain_dec=$(hex_to_dec "$chain_hex")
        pass "eth_chainId = $chain_dec (hex: $chain_hex)"
    } || fail "eth_chainId — 응답 파싱 실패: $resp"

    # ── 5. 가스 ───────────────────────────────────────────────────────────────
    section "5. 가스"

    # eth_gasPrice
    resp=$(rpc_call "$NODE_URL" "eth_gasPrice")
    local gasprice_hex
    gasprice_hex=$(json_get "$resp" "result") && {
        local gasprice_dec
        gasprice_dec=$(hex_to_dec "$gasprice_hex")
        pass "eth_gasPrice = ${gasprice_dec} wei (hex: $gasprice_hex)"
    } || fail "eth_gasPrice — 응답 파싱 실패: $resp"

    # eth_estimateGas (단순 ETH 전송)
    local estimate_params
    estimate_params='[{"from":"0x0000000000000000000000000000000000000001","to":"0x0000000000000000000000000000000000000002","value":"0x1"}]'
    resp=$(rpc_call "$NODE_URL" "eth_estimateGas" "$estimate_params")
    err_msg=$(json_has_error "$resp") && warn "eth_estimateGas — 오류 (정상일 수 있음): $err_msg" || {
        local gas_hex
        gas_hex=$(json_get "$resp" "result") && {
            local gas_dec
            gas_dec=$(hex_to_dec "$gas_hex")
            pass "eth_estimateGas = $gas_dec (hex: $gas_hex)"
        } || warn "eth_estimateGas — 결과 파싱 실패"
    }

    # ── 6. 계정 ───────────────────────────────────────────────────────────────
    section "6. 계정"

    # eth_accounts
    resp=$(rpc_call "$NODE_URL" "eth_accounts")
    err_msg=$(json_has_error "$resp") && warn "eth_accounts — 오류: $err_msg" || {
        python3 -c "
import json, sys
try:
    data = json.loads('''$resp''')
    accs = data.get('result', [])
    print(f'계정 수={len(accs)}' + (f', 첫번째={accs[0]}' if accs else ''))
    sys.exit(0)
except:
    sys.exit(1)
" 2>/dev/null | { read -r info && pass "eth_accounts — $info"; } || \
        warn "eth_accounts — 응답 파싱 실패"
    }

    # eth_getBalance (zero address)
    local TEST_ADDR="0x0000000000000000000000000000000000000000"
    resp=$(rpc_call "$NODE_URL" "eth_getBalance" "[\"$TEST_ADDR\", \"latest\"]")
    err_msg=$(json_has_error "$resp") && warn "eth_getBalance($TEST_ADDR) — 오류: $err_msg" || {
        local bal_hex
        bal_hex=$(json_get "$resp" "result") && {
            local bal_dec
            bal_dec=$(hex_to_dec "$bal_hex")
            pass "eth_getBalance(zero addr) = $bal_dec wei"
        } || warn "eth_getBalance — 결과 파싱 실패"
    }

    # ── 7. Admin API ──────────────────────────────────────────────────────────
    section "7. Admin API"

    # admin_nodeInfo
    resp=$(rpc_call "$NODE_URL" "admin_nodeInfo")
    err_msg=$(json_has_error "$resp") && {
        # admin API가 비활성화된 경우 WARNING
        if echo "$err_msg" | grep -qi "method not found\|not found\|unauthorized\|missing"; then
            warn "admin_nodeInfo — admin API 비활성화됨 (--rpcapi에 admin 포함 필요)"
        else
            fail "admin_nodeInfo — 오류: $err_msg"
        fi
    } || {
        python3 -c "
import json, sys
try:
    data = json.loads('''$resp''')
    ni = data.get('result')
    if ni:
        name = ni.get('name','?')
        enode = ni.get('enode','')[:40]
        print(f'name={name}, enode={enode}...')
        sys.exit(0)
    sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null | { read -r info && pass "admin_nodeInfo — $info"; } || \
        warn "admin_nodeInfo — 응답 파싱 실패"
    }

    # admin_peers
    resp=$(rpc_call "$NODE_URL" "admin_peers")
    err_msg=$(json_has_error "$resp") && {
        if echo "$err_msg" | grep -qi "method not found\|not found\|unauthorized\|missing"; then
            warn "admin_peers — admin API 비활성화됨"
        else
            fail "admin_peers — 오류: $err_msg"
        fi
    } || {
        python3 -c "
import json, sys
try:
    data = json.loads('''$resp''')
    peers = data.get('result', [])
    if isinstance(peers, list):
        print(f'연결된 피어 수={len(peers)}')
        sys.exit(0)
    sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null | { read -r info && pass "admin_peers — $info"; } || \
        warn "admin_peers — 응답 파싱 실패"
    }

    # ── 결과 요약 ─────────────────────────────────────────────────────────────
    local total=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}  테스트 결과 요약: ${NODE_LABEL} (${NODE_URL})${RESET}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  전체: ${total}건  |  ${GREEN}PASS: ${PASS_COUNT}${RESET}  |  ${RED}FAIL: ${FAIL_COUNT}${RESET}  |  ${YELLOW}WARN: ${WARN_COUNT}${RESET}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}[최종 결과: PASS]${RESET} (FAIL 없음)"
    else
        echo -e "  ${RED}${BOLD}[최종 결과: FAIL]${RESET} (${FAIL_COUNT}건 실패)"
    fi
    echo ""

    # FAIL이 있으면 비정상 종료코드 반환 (전체 스크립트 레벨에서 집계용)
    return $FAIL_COUNT
}

# ─── 메인 ─────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${BLUE}║      go-metadium (gmet) RPC 테스트 스크립트         ║${RESET}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════╝${RESET}"

    # python3 의존성 확인
    if ! command -v python3 &>/dev/null; then
        echo -e "${RED}[오류] python3가 설치되어 있지 않습니다.${RESET}"
        exit 1
    fi
    # curl 의존성 확인
    if ! command -v curl &>/dev/null; then
        echo -e "${RED}[오류] curl이 설치되어 있지 않습니다.${RESET}"
        exit 1
    fi

    # 인자 처리
    # 인자 없음 → 기본 LevelDB 노드만 테스트
    # 인자 1개  → 해당 URL만 테스트
    # 인자 2개  → 두 URL 모두 테스트
    local URLS=()
    if [[ $# -eq 0 ]]; then
        URLS=("http://127.0.0.1:8588")
    else
        URLS=("$@")
    fi

    local GLOBAL_FAIL=0
    for url in "${URLS[@]}"; do
        BLOCK1_HASH=""
        GENESIS_HASH=""
        LATEST_BLOCK_HEX="0x0"
        LATEST_BLOCK_DEC="0"

        # 노드 레이블 자동 생성
        local label="$url"
        if [[ "$url" == *":8588"* ]]; then
            label="LevelDB 노드 ($url)"
        elif [[ "$url" == *":8590"* ]]; then
            label="RocksDB 노드 ($url)"
        fi

        run_tests "$url" "$label" || GLOBAL_FAIL=$((GLOBAL_FAIL + $?))
    done

    # 다중 노드 최종 요약
    if [[ ${#URLS[@]} -gt 1 ]]; then
        echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}${BLUE}║                 전체 노드 최종 요약                 ║${RESET}"
        echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════╝${RESET}"
        if [[ $GLOBAL_FAIL -eq 0 ]]; then
            echo -e "  ${GREEN}${BOLD}모든 노드 테스트 PASS${RESET}"
        else
            echo -e "  ${RED}${BOLD}일부 노드에서 FAIL 발생 (총 ${GLOBAL_FAIL}건)${RESET}"
        fi
        echo ""
    fi

    exit $GLOBAL_FAIL
}

main "$@"
