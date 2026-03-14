# EIP-7702 × Fee Delegation 상호작용 설계

## 배경

Metadium은 기존에 Fee Delegation (Type 22, `FeeDelegateDynamicFeeTx`)을 지원한다.
다음 HF(Prague)에서 EIP-7702 (`SetCodeTx`, Type 4)를 도입함에 따라,
두 기능의 상호작용을 명시적으로 정의한다.

---

## 지원 케이스

### 케이스 1: sender가 EIP-7702 EOA → Type 22 발생 ✅

```
sender (7702 코드 설정됨) --[Type 22]--> to
feePayer → 가스 납부
```

**동작**:
- sender.nonce 증가, feePayer가 가스 납부 — 기존 Type 22 로직 그대로
- sender에 설정된 7702 코드는 sender EOA가 CALL될 때만 실행됨
- Type 22는 sender를 CALL하지 않으므로 7702 코드 실행 없음

**결론**: 코드 변경 없이 기존 동작 유지.

---

### 케이스 2: feePayer가 EIP-7702 EOA → Type 22 발생 ✅

```
sender --[Type 22]--> to
feePayer (7702 코드 설정됨) → 가스 납부
```

**동작**:
- feePayer는 가스 차감/환불만 수행 — `buyGas()`, `refundGas()` 잔액 연산만
- feePayer.code는 접근하지 않으므로 7702 코드 실행 없음

**결론**: 코드 변경 없이 기존 동작 유지.

---

### 케이스 3: Type 4 (SetCode) tx + feePayer ✅ — 신규 Type 23

```
sender --[Type 23: FeeDelegateSetCodeTx]--> to
  authorization_list: [EOA → contract_code]
feePayer → 가스 납부
```

**설계 목적**:
- 신규 사용자 온보딩 시 서비스가 EOA 코드 설정 가스를 대납
- "스마트 계정 설정 + 가스 대납"을 한 tx로 처리

**구조** (`core/types/feedelegate_setcode_tx.go`):

```go
// FeeDelegateSetCodeTxType = 23 (0x17)
type FeeDelegateSetCodeTx struct {
    SenderTx SetCodeTx        // EIP-7702 inner tx (authorization_list 포함)
    FeePayer *common.Address  `rlp:"nil"`
    FV       *big.Int         // feePayer V
    FR       *big.Int         // feePayer R
    FS       *big.Int         // feePayer S
}
```

**검증 규칙**:
1. feePayer ∉ authorization_list (케이스 4 금지 규칙과 동일)
2. feePayer 잔액 ≥ gas × gasFeeCap
3. sender 잔액 ≥ value

**서명 흐름**:
```
1. sender가 SetCodeTx (Type 4)에 서명
2. feePayer가 (sender_signed_tx + feePayer_address)에 서명
   → FeeDelegateSetCodeTx (Type 23) 완성
3. eth_sendRawTransaction으로 브로드캐스트
```

**RPC**:
- `eth_signRawFeeDelegateSetCodeTransaction` — 기존 `eth_signRawFeeDelegateTransaction`과 동일 패턴, SetCodeTx 지원 추가

---

### 케이스 4: feePayer ∈ authorization_list ❌ 금지

```
authorization_list: [..., EOA_A → contract_code, ...]
feePayer: EOA_A   ← 금지
```

**금지 이유**:
- EIP-7702 처리 순서상 authorization이 tx 실행 전에 먼저 처리됨
- authorization 처리 시 EOA_A.nonce 증가
- 이후 feePayer로 가스 납부 시 EOA_A의 nonce가 이미 변경된 상태
- nonce 불일치 및 replay protection 혼란 야기

**오류 처리**:
- `state_transition.go` `buyGas()`에서 검증 추가
- 오류: `ErrFeePayerInAuthorizationList`

```go
// buyGas()에 추가
if st.msg.FeePayer() != nil && st.msg.AuthorizationList() != nil {
    feePayer := *st.msg.FeePayer()
    for _, auth := range st.msg.AuthorizationList() {
        if auth.Address == feePayer {
            return ErrFeePayerInAuthorizationList
        }
    }
}
```

---

### 케이스 5: 같은 블록에서 Type 4 + Type 22 동시 처리 ✅

```
tx1 (Type 4): EOA_A.code = contract_X
tx2 (Type 22): feePayer = EOA_A
```

**동작**: tx는 순차 처리되므로 tx1 완료 후 tx2 실행. 잔액/nonce 정상.

**결론**: 코드 변경 없이 기존 동작 유지.

---

## 지원 매트릭스

| 케이스 | 설명 | 지원 여부 | 코드 변경 |
|--------|------|-----------|-----------|
| 1 | sender가 7702 EOA → Type 22 | ✅ | 없음 |
| 2 | feePayer가 7702 EOA → Type 22 | ✅ | 없음 |
| 3 | Type 4 (SetCode) + feePayer | ✅ | Type 23 신규 추가 |
| 4 | feePayer ∈ authorization_list | ❌ | 검증 오류 추가 |
| 5 | 같은 블록 Type 4 + Type 22 | ✅ | 없음 |

---

## 구현 범위 (다음 HF)

### 신규 추가
- `core/types/feedelegate_setcode_tx.go` — `FeeDelegateSetCodeTx` (Type 23)
- `core/types/transaction_signing.go` — `feeDelegateSetCodeSigner`
- `internal/ethapi/api.go` — `SignRawFeeDelegateSetCodeTransaction` RPC

### 수정
- `core/types/transaction.go` — `FeeDelegateSetCodeTxType = 23` 상수 추가
- `core/state_transition.go` — 케이스 4 검증 (`ErrFeePayerInAuthorizationList`)
- `core/tx_pool.go` — Type 23 tx 처리
- `FEEDELEGATION.md` — Type 23 섹션 추가

### 변경 없음 (케이스 1, 2, 5)
- `buyGas()` / `refundGas()` — feePayer 로직 그대로
- `transaction_signing.go` — feeDelegateSigner 그대로
