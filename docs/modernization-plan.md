# go-metadium 현대화 마스터 플랜

> 작성일: 2026-03-10
> 최종 수정: 2026-03-10
> 브랜치: feature/eip-4844

---

## 현재 상태 요약

| 항목 | go-metadium | go-ethereum (최신) | 차이 |
|------|------------|-------------------|------|
| 기반 포크 | Merge (2022) | Prague (2025) | 3세대 뒤처짐 |
| Go 버전 | 1.19 → **1.21 완료** | 1.21+ | - |
| TX 타입 | 0, 1, 2, 22 | 0, 1, 2, 3 | Blob TX 없음 |
| Opcode | RANDOM까지 | MCOPY, BLOBHASH 등 | 20+ opcode 차이 |
| Precompile | 0x01~0x09 | 0x01~0x0A | KZG 없음 |

---

## Metadium 고유 기능 (반드시 보존)

1. **Fee Delegation** (TX 타입 22) - Applepie 포크 이후 핵심 기능
2. **ETCD 기반 검증자 로테이션** - 합의 메커니즘
3. **온체인 거버넌스** (governance contract)
4. **보상 배분 시스템** (45% 광부 / 10% 유지보수 / 45% 보상풀)
5. **TRS** (Transaction Restriction Service)

---

## SPoA vs PoS: EIP 적용 가능성 분석

Metadium은 **SPoA (Stake-based Proof of Authority)** 를 사용하며, 이더리움은 **PoS**로 전환했습니다.
일부 EIP는 PoS Beacon Chain에 강하게 의존하므로 적용 여부를 사전에 판단해야 합니다.

### EIP 분류

| 분류 | EIP | 내용 | 판정 |
|------|-----|------|------|
| ✅ 안전 | EIP-3651 | Warm COINBASE | EVM 가스 계산, SPoA도 COINBASE 있음 |
| ✅ 안전 | EIP-3855 | PUSH0 opcode | 순수 EVM 명령어 |
| ✅ 안전 | EIP-3860 | initcode 크기 제한 | 순수 EVM 실행 제한 |
| ✅ 안전 | EIP-1153 | TLOAD/TSTORE | 순수 EVM 일시 저장소 |
| ✅ 안전 | EIP-5656 | MCOPY opcode | 순수 EVM 명령어 |
| ✅ 안전 | EIP-6780 | SELFDESTRUCT 제한 | 순수 EVM 동작 변경 |
| ✅ 안전 | EIP-7702 | EOA 임시 코드 설정 | EVM 레벨, 합의 무관 |
| ⚠️ 부분 | EIP-4844 | Blob 트랜잭션 | EVM 부분은 안전, P2P 전파 조정 필요 |
| ❌ 제외 | EIP-4895 | Validator Withdrawals | Beacon Chain 전용, SPoA 해당 없음 |
| ❌ 제외 | EIP-4788 | Beacon Block Root | Beacon Chain 전용, SPoA 해당 없음 |
| ❌ 제외 | EIP-7251 | 검증자 최대 잔액 | PoS 검증자 전용 |

### EIP-4844 세부 적용 범위

```
구성요소                          SPoA 적용 여부
─────────────────────────────────────────────────
BlobTx 타입 (타입 3)              ✅ 그대로 구현
KZG point evaluation precompile  ✅ 그대로 구현
BLOBHASH / BLOBBASEFEE opcode    ✅ 그대로 구현
Blob 가스 마켓 (별도 기저 수수료)  ✅ 그대로 구현
Blob 데이터 P2P 전파              ⚠️ SPoA 블록 타이밍에 맞게 조정
Blob 보존 기간 (slot 기반 18일)   ⚠️ 블록 수 기반으로 재계산
KZG trusted setup (ceremony)     ⚠️ 이더리움 기존 설정 재사용 가능
```

> KZG ceremony는 이더리움의 것을 재사용해도 보안상 문제 없음

---

## 포크 로드맵 (하드포크 1회)

Shanghai + Cancun을 **단일 포크**로 통합합니다. Phase 1(Durian)과 Phase 2(Elderflower)를 합쳐 Elderflower 하나로 진행합니다.

```
현재: Bokbunja (Merge 레벨)
         │
         ▼
[Phase 0] 기반 정비 ── Go 1.21 업그레이드 ✅ 완료
         │
         ▼
[Phase 1] Elderflower Fork ── Shanghai + Cancun EVM 통합
         │   EIP-3651, 3855, 3860 (Shanghai)
         │   EIP-1153, 5656, 6780 (Cancun)
         │   EIP-4844 (Blob TX, KZG precompile)
         │
         ▼
[Phase 2] Figberry Fork ── Prague 호환 (미래, 스펙 확정 후)
```

> - 포크 이름은 기존 Metadium 전통(과일/음식 이름)을 따름
> - EIP-4895, EIP-4788, EIP-7251은 **전체 제외** (PoS Beacon Chain 전용)
> - Phase 2(Figberry)는 Prague 스펙 확정 후 재검토

---

## Phase 0: 기반 정비 ✅ 완료 (실소요: ~1일)

> 예상 기간: 2~3주 / 실제: 1일 (ioutil 등 deprecated 패턴이 이미 없었음)

### 0-1. Go 버전 업그레이드 ✅
- `go 1.19` → `go 1.21` (go.mod 수정)
- 컴파일 에러 없음, 모든 테스트 통과

### 0-2. ABI 파일 생성 구조 파악 ✅
- `metadium/governance_abi.go`, `governance_legacy_abi.go`는 `.gitignore` 대상 **생성 파일**
- 새 환경에서 빌드 전 반드시 `make` 실행 필요
- `make metadium/governance_abi.go metadium/governance_legacy_abi.go`

### 0-3. 코드 정합성 검토 ✅
- `ioutil` 등 deprecated 패턴 없음 (이미 클린 상태)

---

## Phase 1: Elderflower Fork — Shanghai + Cancun EVM 통합 (8~10주)

### 구현 EIP

| EIP | 출처 | 내용 | 변경 파일 |
|-----|------|------|----------|
| EIP-3651 | Shanghai | Warm COINBASE | `core/state_transition.go` |
| EIP-3855 | Shanghai | PUSH0 opcode (0x5F) | `core/vm/jump_table.go`, `opcodes.go` |
| EIP-3860 | Shanghai | initcode 크기 제한 (49152 bytes) | `core/vm/evm.go` |
| EIP-1153 | Cancun | TLOAD/TSTORE (일시 저장소) | `core/vm/` |
| EIP-5656 | Cancun | MCOPY opcode | `core/vm/jump_table.go`, `opcodes.go` |
| EIP-6780 | Cancun | SELFDESTRUCT 제한 (동일 TX 내에서만) | `core/vm/instructions.go` |
| EIP-4844 | Cancun | Blob 트랜잭션 (EVM 부분) | 아래 별도 기술 |

### 제외 EIP

| EIP | 제외 이유 |
|-----|----------|
| EIP-4895 | Beacon Chain 검증자 인출 — SPoA에 해당 없음 |
| EIP-4788 | Beacon Block Root 노출 — SPoA에 Beacon Chain 없음 |

### EIP-4844 구현 범위 (SPoA 조정)

```
구현:
  core/types/blob_tx.go          → BlobTx 구조체 (타입 3)
  core/types/tx_blob.go          → BlobSidecar, BlobTxWrapper
  core/vm/opcodes.go             → BLOBHASH(0x49), BLOBBASEFEE(0x4a)
  core/vm/jump_table.go          → cancunInstructionSet
  core/vm/contracts.go           → KZG point evaluation precompile (0x0a)
  params/config.go               → ElderflowerBlock
  params/protocol_params.go      → BlobTxMinBlobGasprice, BlobTxBlobGasPerBlob 등
  core/blockchain.go             → blob sidecar 처리

SPoA 맞춤 조정:
  - Blob 보존 기간: slot 수 기반 → 블록 수 기반으로 변환
  - Blob P2P 전파: PoS slot 타이밍 제거, 블록 생성 시점 기준으로 재설계
  - 초기 max blob count: 2/블록으로 제한 (네트워크 부하 관리)
```

### TX 타입 번호 정리

```go
const (
    LegacyTxType                = 0   // 기존
    AccessListTxType            = 1   // EIP-2930
    DynamicFeeTxType            = 2   // EIP-1559
    BlobTxType                  = 3   // EIP-4844 NEW
    FeeDelegateDynamicFeeTxType = 22  // Metadium 유지
    // FeeDelegateBlobTxType    = 23  // 향후 필요 시 검토
)
```

### 하드포크 활성화 설정

```go
type ChainConfig struct {
    // ... 기존 필드들 ...
    BokbunjaBlock     *big.Int  // 현재 최신
    ElderflowerBlock  *big.Int  // NEW: Shanghai + Cancun 통합
}

// 테스트넷: 먼저 적용
ElderflowerBlock: big.NewInt(XXXXXXX),

// 메인넷: 거버넌스 투표 후 결정
ElderflowerBlock: nil,  // TBD
```

---

## Phase 2: Figberry Fork — Prague/Electra (미래)

> Prague 스펙이 아직 확정 전이므로 Phase 1 완료 후 재검토

| EIP | 내용 | SPoA 적용 |
|-----|------|----------|
| EIP-7702 | EOA 임시 코드 설정 (AA 기반) | ✅ 구현 예정 |
| EIP-2537 | BLS12-381 precompile | ✅ 구현 예정 |
| EIP-7623 | Calldata 가스 비용 조정 | ✅ 구현 예정 |
| EIP-7251 | 검증자 최대 잔액 증가 | ❌ PoS 전용, 제외 |

---

## 개발 브랜치 전략

```
master (현재 안정)
│
├── feature/phase0-infra        ← Go 1.21 업그레이드 ✅ 완료
├── feature/phase1-elderflower  ← Shanghai + Cancun 통합 포크
└── feature/phase2-figberry     ← Prague 포크 (미래)

배포 순서:
1. 각 브랜치 개발 완료 → master에 머지
2. testnet에 포크 블록 번호 지정 후 배포
3. 3~4주 모니터링
4. mainnet 하드포크 날짜 거버넌스 투표
5. mainnet 활성화
```

---

## 테스트 전략

각 Phase마다:
1. **단위 테스트** — 새 opcode, precompile, TX 타입
2. **통합 테스트** — Fee Delegation + 새 기능 상호작용
3. **포크 전환 테스트** — 포크 블록 전후 동작 검증
4. **리그레션 테스트** — 거버넌스, ETCD, TRS 정상 작동 확인
5. **테스트넷 배포** — 최소 3~4주 운영

---

## 리스크 및 완화 방안

| 리스크 | 가능성 | 완화 방안 |
|--------|--------|----------|
| Fee Delegation 로직 깨짐 | 높음 | 포크 전후 별도 테스트 스위트 유지 |
| ETCD 리더 선출 불안정 | 중간 | 포크 블록 전후 ETCD 상태 snapshot |
| 거버넌스 계약 호환성 | 중간 | 솔리디티 버전 검토, ABI 불변 보장 |
| 네트워크 분기 (체인 스플릿) | 낮음 | 모든 검증자 동시 업그레이드 필수 |
| Blob P2P 전파 타이밍 불일치 | 중간 | SPoA 블록 타이밍 기반으로 재설계 및 별도 테스트 |
| Blob 데이터 네트워크 부하 | 중간 | 초기 max blob count 2/블록으로 제한 |
