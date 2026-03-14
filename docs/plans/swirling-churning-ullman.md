# EIP-4844 Blob Transaction 전체 통합 계획

## Context
BlobTx 타입, Gas Market 계산, BLOBHASH/BLOBBASEFEE 옵코드, KZG 프리컴파일 stub은 구현됐지만,
블록 생성·검증·실행 파이프라인에 통합되지 않았다. 이 계획은 Camellia 포크에서 EIP-4844가
실제로 동작하도록 전체 파이프라인을 연결한다.

---

## Phase 1: 버그 수정

### 1-1. `params/protocol_params.go`
| 상수 | 현재 값 | 수정값 |
|------|---------|--------|
| `MaxBlobGasPerBlock` | 262144 | 786432 (6 blobs × 131072) |
| `BlobBaseFeeUpdateFraction` | 3 | 3338477 (EIP-4844 표준) |

- 중복 상수 `BlobGaspriceUpdateFraction = 3338477` 제거

### 1-2. `core/types/block.go`
- `headerToHeaderRlp()`: `ExcessBlobGas: h.ExcessBlobGas` 추가
- `headerRlpToHeader()`: `ExcessBlobGas: h.ExcessBlobGas` 추가
- `CopyHeader()`: ExcessBlobGas deep copy 추가
  ```go
  if h.ExcessBlobGas != nil {
      cpy.ExcessBlobGas = new(big.Int).Set(h.ExcessBlobGas)
  }
  ```
- `headerMarshaling` struct: `ExcessBlobGas *hexutil.Big` 필드 추가
- `gen_header_json.go` 재생성 필요 (`go generate ./core/types/`)

> Phase 1 완료 후 `blob_gas_market_test.go` 수치 재확인 필요 (BlobBaseFeeUpdateFraction 변경 영향)

---

## Phase 2: 블록 생성 파이프라인

### 2-1. `core/types/transaction.go`
**공개 accessor 추가:**
```go
func (tx *Transaction) BlobHashes() []common.Hash { return tx.inner.blobHashes() }
func (tx *Transaction) MaxFeePerBlobGas() *big.Int {
    if b, ok := tx.inner.(*BlobTx); ok && b.MaxFeePerBlobGas != nil {
        return b.MaxFeePerBlobGas.ToBig()
    }
    return nil
}
```

**`Cost()` 수정** — blob gas 비용 포함:
```go
if blobCost := tx.inner.blobGasCost(); blobCost != nil {
    total.Add(total, blobCost)
}
```

**`Message` struct 확장:**
```go
blobHashes       []common.Hash
maxFeePerBlobGas *big.Int
```
- `AsMessage()`: BlobTxType일 때 두 필드 채우기
- 공개 accessor `BlobHashes()`, `MaxFeePerBlobGas()` 추가

### 2-2. `core/evm.go`
**`NewEVMBlockContext()`**에 ExcessBlobGas 설정:
```go
ExcessBlobGas: header.ExcessBlobGas,
```

**`NewEVMTxContext()`**에 BlobHashes 설정:
```go
BlobHashes: msg.BlobHashes(),
```

### 2-3. `consensus/clique/clique.go` — `Prepare()`
Camellia 활성 시 신규 블록에 ExcessBlobGas 설정:
```go
if chain.Config().IsCamellia(header.Number) {
    parentBlobGasUsed := calcBlobGasUsed(parent.Transactions()) // 부모 블록 blob gas 계산
    header.ExcessBlobGas = types.CalcExcessBlobGas(parent.ExcessBlobGas, parentBlobGasUsed)
}
```
> 헬퍼 함수 `calcBlobGasUsed(txs []*types.Transaction) uint64` 추가

### 2-4. `core/vm/instructions.go` — `opBlobBaseFee` 리팩토링
중복 fakeexponential 구현 제거 → `types.CalcBlobBaseFee()` 호출로 교체:
```go
blobBaseFee := ctypes.CalcBlobBaseFee(interpreter.evm.Context.ExcessBlobGas)
v, _ := uint256.FromBig(blobBaseFee)
scope.Stack.push(v)
```

---

## Phase 3: 블록 검증 파이프라인

### 3-1. `core/state_transition.go`
**`Message` 인터페이스 확장:**
```go
BlobHashes() []common.Hash
MaxFeePerBlobGas() *big.Int
```

**`preCheck()`에 blob fee 검증 추가:**
```go
if chain.IsCamellia(blockNum) && len(msg.BlobHashes()) > 0 {
    blobBaseFee := types.CalcBlobBaseFee(st.evm.Context.ExcessBlobGas)
    if msg.MaxFeePerBlobGas() == nil || msg.MaxFeePerBlobGas().Cmp(blobBaseFee) < 0 {
        return ErrBlobFeeCapTooLow
    }
    if len(msg.BlobHashes()) > int(params.MaxBlobsPerTransaction) {
        return ErrBlobCountExceeded
    }
}
```

**`errors.go`에 에러 추가:**
```go
var ErrBlobFeeCapTooLow  = errors.New("max fee per blob gas less than blob base fee")
var ErrBlobCountExceeded = errors.New("blob count exceeds per-transaction limit")
```

### 3-2. `consensus/clique/clique.go` — `verifyCascadingFields()`
```go
if !chain.Config().IsCamellia(header.Number) {
    if header.ExcessBlobGas != nil {
        return errInvalidExcessBlobGas
    }
} else {
    if header.ExcessBlobGas == nil {
        return errMissingExcessBlobGas
    }
    parentBlobGasUsed := calcBlobGasUsed(parent.Transactions())
    expected := types.CalcExcessBlobGas(parent.ExcessBlobGas, parentBlobGasUsed)
    if header.ExcessBlobGas.Cmp(expected) != 0 {
        return fmt.Errorf("invalid excessBlobGas: have %v, want %v", header.ExcessBlobGas, expected)
    }
}
```

### 3-3. `core/block_validator.go` — `ValidateBody()`
```go
if v.config.IsCamellia(header.Number) {
    var totalBlobGas uint64
    for _, tx := range block.Transactions() {
        totalBlobGas += uint64(len(tx.BlobHashes())) * params.BlobTxPerBlobGas
    }
    if totalBlobGas > params.MaxBlobGasPerBlock {
        return fmt.Errorf("blob gas %d exceeds limit %d", totalBlobGas, params.MaxBlobGasPerBlock)
    }
}
```

### 3-4. `core/state_processor.go` — `Process()`
Blob gas 사용량 집계 (다음 블록 ExcessBlobGas 계산용):
```go
var totalBlobGasUsed uint64
for i, tx := range block.Transactions() {
    totalBlobGasUsed += uint64(len(tx.BlobHashes())) * params.BlobTxPerBlobGas
    // ... 기존 트랜잭션 처리 ...
}
// 현재는 로컬 추적만 (향후 BlobGasUsed 헤더 필드 추가 시 기록)
```

---

## Phase 4: 트랜잭션 풀 통합

### `core/tx_pool.go`
**구조체 필드 추가:**
```go
camellia bool // EIP-4844 활성화 플래그
```

**`reset()` 함수에 플래그 업데이트:**
```go
pool.camellia = pool.chainconfig.IsCamellia(next)
```

**`validateTx()`에 blob 검증 추가:**
```go
if tx.Type() == types.BlobTxType {
    if !pool.camellia {
        return ErrTxTypeNotSupported
    }
    if len(tx.BlobHashes()) == 0 {
        return errors.New("blob tx must have at least one blob hash")
    }
    if uint64(len(tx.BlobHashes())) > params.MaxBlobsPerTransaction {
        return ErrBlobCountExceeded
    }
    if tx.To() == nil {
        return errors.New("blob tx must have a recipient")
    }
    // MaxFeePerBlobGas vs current blobBaseFee
    if currentHead := pool.chain.CurrentBlock(); currentHead.ExcessBlobGas != nil {
        blobBaseFee := types.CalcBlobBaseFee(currentHead.ExcessBlobGas)
        if tx.MaxFeePerBlobGas() == nil || tx.MaxFeePerBlobGas().Cmp(blobBaseFee) < 0 {
            return ErrBlobFeeCapTooLow
        }
    }
}
```

---

## 의존성 순서

```
Phase 1 (독립)
  → params 상수, block.go RLP

Phase 2 (Phase 1 이후)
  → transaction.go accessor/Cost/Message
  → evm.go (Message 의존)
  → clique.go Prepare() (CalcExcessBlobGas 의존)
  → instructions.go opBlobBaseFee 리팩토링

Phase 3 (Phase 2 이후)
  → state_transition.go (Message 인터페이스 의존)
  → clique.go verifyCascadingFields
  → block_validator.go (BlobHashes() accessor 의존)
  → state_processor.go

Phase 4 (Phase 3 이후)
  → tx_pool.go (BlobHashes(), MaxFeePerBlobGas(), CalcBlobBaseFee 의존)
```

---

## 수정 파일 목록

| 파일 | 작업 |
|------|------|
| `params/protocol_params.go` | 상수 수정 |
| `core/types/block.go` | RLP/JSON/CopyHeader |
| `core/types/transaction.go` | accessor, Cost(), Message |
| `core/evm.go` | NewEVMBlockContext, NewEVMTxContext |
| `consensus/clique/clique.go` | Prepare(), verifyCascadingFields() |
| `core/vm/instructions.go` | opBlobBaseFee 리팩토링 |
| `core/state_transition.go` | Message 인터페이스, preCheck() |
| `core/block_validator.go` | ValidateBody() |
| `core/state_processor.go` | blob gas 집계 |
| `core/tx_pool.go` | camellia 플래그, validateTx() |

---

## 검증

```bash
# 전체 빌드
go build ./...

# 타입 테스트
go test ./core/types/... -run "BlobTx|BlobGas"

# 컨센서스 테스트
go test ./consensus/clique/...

# 전체 core 테스트
go test ./core/...
```
