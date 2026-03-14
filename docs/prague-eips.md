# Prague HF EIP 설계

Metadium 다음 HF (Camellia 이후). PoS 전용 EIP (6110, 7685, 7002, 7251) 제외.

---

## EIP-2537: BLS12-381 프리컴파일

### 현재 상태

구현체(`PrecompiledContractsBLS`)는 이미 존재하지만 **어떤 fork에도 활성화되지 않음**.
두 가지 수정이 필요하다.

#### 문제 1 — 프리컴파일 주소 오류

현재 코드는 구버전 EIP-2537 초안 기준으로 0x0a부터 시작한다.
0x0a는 Camellia에서 KZG4844 프리컴파일로 사용 중.
Prague 최종 스펙은 **0x0b부터** 시작한다.

```
현재 (잘못됨)          Prague 최종 스펙
0x0a: G1Add      →    0x0b: G1Add
0x0b: G1Mul      →    0x0c: G1Mul
0x0c: G1MultiExp →    0x0d: G1MultiExp
0x0d: G2Add      →    0x0e: G2Add
0x0e: G2Mul      →    0x0f: G2Mul
0x0f: G2MultiExp →    0x10: G2MultiExp
0x10: Pairing    →    0x11: Pairing
0x11: MapG1      →    0x12: MapG1
0x12: MapG2      →    0x13: MapG2
```

#### 문제 2 — 가스 비용 구버전

Prague에서 가스 비용이 재조정됐다.

| 연산 | 현재 | Prague 최종 |
|------|------|-------------|
| G1Add | 600 | 375 |
| G1Mul | 12000 | 14400 |
| G2Add | 4500 | 600 |
| G2Mul | 55000 | 57600 |
| PairingBase | 115000 | 43300 |
| PairingPerPair | 23000 | 32600 |
| MapG1 | 5500 | 5500 (동일) |
| MapG2 | 110000 | 75000 |

### 구현 범위

**`core/vm/contracts.go`**:
```go
// PrecompiledContractsPrague = Camellia + BLS12-381 (0x0b~0x13)
var PrecompiledContractsPrague = map[common.Address]PrecompiledContract{
    // Camellia 그대로 (0x01~0x0a)
    ...
    // EIP-2537 BLS12-381 (0x0b~0x13)
    common.BytesToAddress([]byte{11}): &bls12381G1Add{},
    common.BytesToAddress([]byte{12}): &bls12381G1Mul{},
    common.BytesToAddress([]byte{13}): &bls12381G1MultiExp{},
    common.BytesToAddress([]byte{14}): &bls12381G2Add{},
    common.BytesToAddress([]byte{15}): &bls12381G2Mul{},
    common.BytesToAddress([]byte{16}): &bls12381G2MultiExp{},
    common.BytesToAddress([]byte{17}): &bls12381Pairing{},
    common.BytesToAddress([]byte{18}): &bls12381MapG1{},
    common.BytesToAddress([]byte{19}): &bls12381MapG2{},
}
```

**`params/protocol_params.go`** — 가스 상수 업데이트:
```go
Bls12381G1AddGas          uint64 = 375
Bls12381G1MulGas          uint64 = 14400
Bls12381G2AddGas          uint64 = 600
Bls12381G2MulGas          uint64 = 57600
Bls12381PairingBaseGas    uint64 = 43300
Bls12381PairingPerPairGas uint64 = 32600
Bls12381MapG1Gas          uint64 = 5500   // 동일
Bls12381MapG2Gas          uint64 = 75000
```

**`core/vm/evm.go`** — `precompile()` 함수에 Prague 분기 추가:
```go
case evm.chainRules.IsPrague:
    precompiles = PrecompiledContractsPrague
case evm.chainRules.IsCamellia:
    precompiles = PrecompiledContractsCamellia
```

**주의**: 기존 `PrecompiledContractsBLS`는 테스트 전용으로 유지. 주소가 다르므로 Prague 맵에는 사용하지 않고 새로 정의.

---

## EIP-7691: Blob Throughput 증가

### 현재 상태 (Camellia)

```go
TargetBlobGasPerBlock     = 393216   // 3 blobs × 131072
MaxBlobGasPerBlock        = 786432   // 6 blobs × 131072
BlobBaseFeeUpdateFraction = 3338477
```

### Prague 변경

```go
TargetBlobGasPerBlock     = 786432   // 6 blobs × 131072 (2배)
MaxBlobGasPerBlock        = 1179648  // 9 blobs × 131072 (1.5배)
BlobBaseFeeUpdateFraction = 5007716  // blob base fee 조정 속도 변경
```

### 구현 범위

파라미터를 fork별로 분리해야 한다 → EIP-7840과 함께 처리 (아래 참고).

단독 처리 시:
- `params/protocol_params.go`에 Prague용 상수 추가
- `consensus/clique/clique.go` `Prepare()` — ExcessBlobGas 계산에 Prague 분기 추가
- `core/block_validator.go` — `ValidateBody()` blob gas limit 검증 분기

---

## EIP-7840: Blob Schedule을 ChainConfig에 추가

### 현재 상태

Blob 파라미터가 `protocol_params.go`에 전역 상수로 하드코딩.
fork별로 다른 값을 쓸 수 없는 구조.

### 설계

**`params/config.go`** — BlobSchedule 타입 추가:
```go
type BlobSchedule struct {
    Target               uint64 // target blob count per block
    Max                  uint64 // max blob count per block
    BaseFeeUpdateFraction uint64
}

type ChainConfig struct {
    ...
    // Blob schedule per fork (EIP-7840)
    CamelliaBlobSchedule *BlobSchedule `json:"camelliaBlobSchedule,omitempty"`
    PragueBlobSchedule      *BlobSchedule `json:"pragueBlobSchedule,omitempty"`
}
```

**기본값** (MetadiumMainnetChainConfig, MetadiumTestnetChainConfig에 적용):
```go
CamelliaBlobSchedule: &BlobSchedule{
    Target:               3,       // 3 blobs
    Max:                  6,       // 6 blobs
    BaseFeeUpdateFraction: 3338477,
},
PragueBlobSchedule: &BlobSchedule{
    Target:               6,       // 6 blobs (EIP-7691)
    Max:                  9,       // 9 blobs (EIP-7691)
    BaseFeeUpdateFraction: 5007716, // EIP-7691
},
```

**`params/config.go`** — 헬퍼 함수:
```go
// ActiveBlobSchedule returns the blob schedule for the given block number.
func (c *ChainConfig) ActiveBlobSchedule(blockNum *big.Int) *BlobSchedule {
    if c.IsPrague(blockNum) && c.PragueBlobSchedule != nil {
        return c.PragueBlobSchedule
    }
    if c.IsCamellia(blockNum) && c.CamelliaBlobSchedule != nil {
        return c.CamelliaBlobSchedule
    }
    return nil
}
```

**영향 범위**:
- `consensus/clique/clique.go` — `CalcExcessBlobGas()` 호출 시 schedule 사용
- `core/block_validator.go` — blob gas limit 검증 시 schedule 사용
- `core/tx_pool.go` — blob tx 검증 시 schedule 사용
- `types.CalcBlobBaseFee()` — BlobBaseFeeUpdateFraction 파라미터화

---

## EIP-7623: Calldata Cost 증가 (Floor 규칙)

### 현재 상태

```go
// core/state_transition.go - IntrinsicGas()
nonZeroGas = params.TxDataNonZeroGasEIP2028  // 16
zeroGas    = params.TxDataZeroGas             // 4
intrinsic  = base + nz*16 + z*4
```

### Prague 변경

기존 per-byte 가스 비용은 유지하되, calldata에 대한 **floor 비용**을 추가한다.
calldata가 많을수록 (특히 non-zero byte) floor 비용이 표준 비용보다 높아진다.

```
tokens = nonzero_bytes × 4 + zero_bytes × 1
floor_gas = tokens × TOKEN_COST_PER_UNIT (= 10)

final_gas = max(standard_intrinsic_gas, base_tx_gas + floor_gas)
```

**예시**:
- 1000 nonzero bytes tx:
  - 표준: 21000 + 1000×16 = 37000
  - floor: 21000 + (1000×4)×10 = 21000 + 40000 = 61000
  - 최종: **61000** (floor 적용)

- 100 nonzero bytes tx:
  - 표준: 21000 + 100×16 = 22600
  - floor: 21000 + (100×4)×10 = 21000 + 4000 = 25000
  - 최종: **25000** (floor 적용)

### 구현 범위

**`params/protocol_params.go`** — 상수 추가:
```go
TxDataTokenCostPrague    uint64 = 10 // EIP-7623: cost per token
TxDataNonZeroTokens      uint64 = 4  // EIP-7623: tokens per non-zero byte
TxDataZeroTokens         uint64 = 1  // EIP-7623: tokens per zero byte
```

**`core/state_transition.go`** — `IntrinsicGas()` 시그니처 변경:
```go
func IntrinsicGas(data []byte, accessList types.AccessList,
    isContractCreation bool, isHomestead, isEIP2028, isPrague bool) (uint64, error) {
    ...
    // 기존 표준 계산
    standardGas := base + nz*16 + z*4

    if isPrague {
        tokens := nz*params.TxDataNonZeroTokens + z*params.TxDataZeroTokens
        floorGas := base + tokens*params.TxDataTokenCostPrague
        if floorGas > standardGas {
            return floorGas, nil
        }
    }
    return standardGas, nil
}
```

**`core/state_transition.go`** — `preCheck()` 호출부 수정:
```go
gas, err := IntrinsicGas(st.data, st.msg.AccessList(),
    contractCreation, rules.IsHomestead, rules.IsIstanbul, rules.IsPrague)
```

---

## 구현 우선순위 및 의존 관계

```
EIP-7840 (BlobSchedule 구조)
    └─ EIP-7691 (파라미터 변경) ← 7840 먼저 구현해야 7691이 깔끔

EIP-2537 (BLS 프리컴파일)  ← 독립적, 먼저 시작 가능
EIP-7623 (Calldata floor)  ← 독립적, IntrinsicGas 수정만
```

### 순서 제안

1. **EIP-7840** — BlobSchedule 구조 추가 (파라미터 기반 마련)
2. **EIP-7691** — 7840 기반으로 Prague blob 파라미터 적용
3. **EIP-2537** — 프리컴파일 주소/가스 수정, PrecompiledContractsPrague 추가
4. **EIP-7623** — IntrinsicGas floor 규칙 추가

---

## fork 설정 추가 (모든 EIP 공통)

**`params/config.go`**:
```go
type ChainConfig struct {
    ...
    CamelliaBlock *big.Int `json:"camelliaBlock,omitempty"`
    PragueBlock      *big.Int `json:"pragueBlock,omitempty"`  // 신규
}

func (c *ChainConfig) IsPrague(num *big.Int) bool {
    return isForked(c.PragueBlock, num)
}
```

**`params/config.go`** — Rules 구조체:
```go
type Rules struct {
    ...
    IsCamellia bool
    IsPrague      bool  // 신규
}

func (c *ChainConfig) Rules(num *big.Int) Rules {
    ...
    IsPrague:      c.IsPrague(num),
}
```
