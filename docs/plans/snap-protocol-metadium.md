# Snap Protocol Support for Metadium Network -- 변경 설계서

## 1. 현재 상태 분석

### 1.1 문제 요약

Metadium 노드가 snap sync를 수행할 수 없다. `--syncmode snap` (기본값)으로 시작하더라도 실제로는 snap 프로토콜 핸드셰이크가 이루어지지 않아, 연결된 피어 중 snap-capable 피어가 0개로 남아 결국 full sync로 폴백된다.

### 1.2 근본 원인: 프로토콜 이름 불일치

devp2p capability negotiation은 프로토콜 이름(`Name`)과 버전(`Version`)의 쌍으로 동작한다. 양쪽 피어가 동일한 `(Name, Version)` 쌍을 가져야 해당 프로토콜이 활성화된다.

**현재 상태:**

| 프로토콜 | ProtocolName | 피어가 advertise하는 caps |
|----------|-------------|-------------------------|
| eth (Metadium) | `"meta"` | `meta/65`, `meta/66` |
| snap | `"snap"` | `snap/1` |

**핵심 문제:** `registerSnapExtension()` (`eth/peerset.go:76-78`)에서 snap 피어가 연결될 때, 해당 피어가 `eth.ProtocolName` (= `"meta"`)을 실행 중인지 확인한다:

```go
func (ps *peerSet) registerSnapExtension(peer *snap.Peer) error {
    if !peer.RunningCap(eth.ProtocolName, eth.ProtocolVersions) {
        return errSnapWithoutEth
    }
    // ...
}
```

`RunningCap()` (`p2p/peer.go:183-192`)는 `p.running` 맵에서 프로토콜 이름으로 조회한다. 이 맵은 `matchProtocols()` (`p2p/peer.go:388`)에서 양쪽 피어의 capability를 매칭하여 생성된다.

**동작 흐름:**

1. 로컬 노드가 `Protocols()` (`eth/backend.go:525-531`)를 통해 `[meta/65, meta/66, snap/1]` capability를 등록
2. 원격 Metadium 피어도 `[meta/65, meta/66, snap/1]`을 advertise
3. devp2p 핸드셰이크에서 양쪽이 capability를 교환
4. `matchProtocols()`가 공통 capability를 매칭:
   - `meta/66` -- 매칭 성공 (양쪽 모두 "meta" 프로토콜 지원)
   - `snap/1` -- 매칭 성공 (양쪽 모두 "snap" 프로토콜 지원)
5. snap 피어 연결 시 `registerSnapExtension()`이 호출됨
6. `peer.RunningCap("meta", [66, 65])` -- **이것은 성공해야 함**

이론적으로는 동작해야 하지만, 실제 Metadium 네트워크에서 snap이 동작하지 않는 이유는 다음과 같다:

### 1.3 실제 실패 원인 (단계별)

**원인 A: 기존 Metadium 노드들이 snap 프로토콜을 등록하지 않음**

현재 Metadium 네트워크의 노드들은 go-metadium 바이너리를 사용하고 있지만, 해당 바이너리의 `Protocols()` 함수에서 snap 프로토콜이 등록되는 조건은 `s.config.SnapshotCache > 0`이다 (`eth/backend.go:527`). 기존 노드 설정에 따라 snapshot cache가 비활성화되어 있을 수 있다.

그러나 더 중요한 문제는:

**원인 B: Snapshot 데이터 부재**

snap 프로토콜은 state snapshot 데이터를 기반으로 동작한다. `ServiceGetAccountRangeQuery()` (`eth/protocols/snap/handler.go:283-341`)에서:

```go
it, err := chain.Snapshots().AccountIterator(req.Root, req.Origin)
if err != nil {
    return nil, nil  // snapshot 없으면 빈 응답 반환
}
```

기존 Metadium 노드들이 full sync로 동기화된 경우, snapshot 데이터가 생성되지 않았을 가능성이 높다. snap 프로토콜 자체는 등록되어도 실제 데이터를 서빙할 수 없다.

**원인 C: handler.go의 snap sync 폴백 로직**

`eth/handler.go:150-169`에서 이미 Metadium 전용 workaround가 적용되어 있다:

```go
if config.Sync == downloader.FullSync {
    // Metadium: Respect the user's explicit --syncmode full flag.
    // The original geth logic auto-switches to snap sync when
    // fullBlock==0 && fastBlock>0, but Metadium network peers do not
    // support the snap protocol, making snap sync impossible.
```

그리고 `eth/handler.go:330-343`에서 snap 피어 없이 5개 이상의 피어가 연결되면 snap sync를 비활성화하는 로직이 있다:

```go
if snp == 0 && all >= 5 {
    log.Warn("No snap-capable peers found...")
    atomic.StoreUint32(&h.snapSync, 0)
}
```

이 모든 것은 snap 프로토콜이 네트워크 레벨에서 실질적으로 비활성 상태임을 확인해 준다.

### 1.4 결론

snap 프로토콜 코드 자체는 go-metadium에 존재하지만, **네트워크 부트스트랩 문제**로 인해 동작하지 않는다:
1. 기존 노드들은 snapshot 데이터를 가지고 있지 않다
2. Snapshot 데이터가 없는 노드는 snap 요청에 빈 응답을 보낸다
3. 새 노드가 snap sync를 시도해도 유효한 데이터를 받을 수 없다
4. 결과적으로 모든 노드가 full sync로 폴백한다

---

## 2. 변경 범위

### 2.1 변경 유형
- 수정: 기존 코드의 설정 변경 + snap 부트스트랩 지원
- 신규 추가: 없음 (snap 프로토콜 코드는 이미 존재)

### 2.2 영향 받는 모듈

| 모듈 | 파일 | 변경 내용 |
|------|------|-----------|
| eth 백엔드 | `eth/backend.go` | snap 프로토콜 등록 조건 확인/보장 |
| handler | `eth/handler.go` | snap sync 폴백 로직 조정 |
| 설정 | `eth/ethconfig/config.go` | SnapshotCache 기본값 확인 |
| 노드 운영 | (문서/스크립트) | 기존 노드 snapshot 재생성 절차 |

---

## 3. 구현 단계

### Phase 0: 진단 및 확인 (변경 없음)

**목적:** 현재 코드에서 snap 프로토콜이 정말 등록되는지 확인

1. `eth/ethconfig/config.go`에서 `SnapshotCache` 기본값 확인
2. 테스트넷 노드 2개를 시작하여 실제로 교환되는 capability 목록 확인
3. `admin.peers` RPC로 연결된 피어의 caps 확인

**확인 명령:**
```bash
# 노드 시작 후
geth attach --exec 'admin.peers' ipc:geth.ipc
# 출력에서 caps 필드 확인: ["meta/65", "meta/66", "snap/1"] 이 포함되어야 함
```

### Phase 1: Snapshot 생성 보장

**목적:** 기존 full sync 노드에서 snapshot 데이터를 생성하여 snap 서빙 가능하게 만들기

snap 프로토콜이 유용하려면 네트워크에 최소 1개 이상의 노드가 완전한 state snapshot을 보유해야 한다.

**작업 내용:**

1. **기존 노드에서 snapshot 재생성 트리거:**
   - `debug.snapshot()` 또는 노드 재시작 시 `--snapshot` 플래그 확인
   - `core.CacheConfig.SnapshotLimit`가 0보다 큰 값으로 설정되어야 함
   - 기본 설정 확인: `eth/ethconfig/config.go`의 `Defaults.SnapshotCache`

2. **snapshot 생성 확인:**
   - `debug_getAccessibleState` RPC로 현재 state 접근 가능 여부 확인
   - snapshot 생성에는 시간이 소요됨 (state 크기에 비례)

**변경 파일:** 없음 (운영 절차 변경)

### Phase 2: 네트워크 부트스트랩

**목적:** 점진적으로 snap-capable 노드 수를 늘려서 네트워크에서 snap sync 가능하게 만들기

**전략:**

1. **시드 노드 준비** (최소 2-3개):
   - full sync 완료 + snapshot 생성 완료 노드
   - `--snapshot` 활성화 상태로 재시작
   - SnapshotCache > 0 확인 (기본값 256MB)

2. **새 노드 테스트:**
   - 빈 데이터 디렉토리로 새 노드 시작
   - `--syncmode snap` (또는 기본값)
   - 시드 노드를 `--bootnodes`로 지정
   - snap sync 진행 상황 모니터링

3. **handler.go 폴백 로직 조정** (선택):
   - 현재 5개 피어 연결 후 snap 피어 0이면 full sync 폴백
   - Metadium 네트워크 크기가 작을 경우 이 임계값 조정 필요할 수 있음

**변경 파일:**
- `eth/handler.go` (L336): 폴백 임계값 조정 (선택적)

### Phase 3: 코드 레벨 개선 (선택적)

현재 코드 분석 결과, snap 프로토콜 코드 자체에 Metadium 특화 수정이 필요한 부분은 발견되지 않았다. 그러나 다음 개선을 고려할 수 있다:

1. **로깅 강화:**
   - snap 프로토콜 등록/연결 시 로깅 추가
   - snapshot 상태 진단 로그

2. **handler.go의 snap sync 폴백 로직 정리:**
   - `eth/handler.go:150-169`: Metadium 주석에 "peers do not support snap protocol"이라고 되어 있지만, 이는 이제 더 이상 정확하지 않음 (snap을 지원하게 될 것이므로)
   - 주석 업데이트 필요

3. **SnapDiscoveryURLs 설정:**
   - `eth/backend.go:256`: `eth.config.SnapDiscoveryURLs`가 비어 있으면 snap 전용 discovery가 동작하지 않음
   - Metadium DNS discovery에 snap 엔트리 추가 고려

---

## 4. 예상 동작 흐름 (변경 후)

### 4.1 시퀀스: snap sync 성공 케이스

```
새 노드                    시드 노드 (snapshot 보유)
   |                           |
   |--- devp2p Hello -------->|  caps: [meta/66, snap/1]
   |<-- devp2p Hello ---------|  caps: [meta/66, snap/1]
   |                           |
   |  matchProtocols() 실행     |
   |  meta/66 매칭, snap/1 매칭  |
   |                           |
   |--- meta/66 Status ------->|  (eth 핸드셰이크)
   |<-- meta/66 Status --------|
   |                           |
   |  runEthPeer() 실행          |
   |  waitSnapExtension() 대기   |
   |                           |
   |  runSnapExtension() 실행    |  (snap/1 연결)
   |  registerSnapExtension()   |
   |    RunningCap("meta", [66,65]) -> true
   |                           |
   |  snap 피어 등록 완료         |
   |                           |
   |--- GetAccountRange ------>|
   |<-- AccountRange ----------|  (snapshot 데이터 응답)
   |                           |
   |--- GetStorageRanges ----->|
   |<-- StorageRanges ---------|
   |                           |
   |  ... snap sync 진행 ...    |
```

### 4.2 시퀀스: snap sync 실패 -> full sync 폴백

```
새 노드                    기존 노드 (snapshot 없음)
   |                           |
   |  snap/1 매칭됨             |
   |  snap 피어로 등록됨         |
   |                           |
   |--- GetAccountRange ------>|
   |<-- AccountRange (빈 응답) -|  chain.Snapshots() == nil
   |                           |
   |  ... 반복 실패 ...         |
   |                           |
   |  downloader가 snap sync    |
   |  실패로 판단                |
   |  full sync 폴백            |
```

---

## 5. 테스트 방법

### 5.1 로컬 2-노드 테스트

```bash
# 노드 A: full sync 완료 노드 (snapshot 보유)
geth --datadir ./nodeA --networkid 11 --port 30303 \
     --snapshot --syncmode full

# snapshot 생성 대기 후...

# 노드 B: 새 노드 (snap sync 시도)
geth --datadir ./nodeB --networkid 11 --port 30304 \
     --syncmode snap --bootnodes "enode://...nodeA..."

# 확인
geth attach ./nodeB/geth.ipc --exec 'admin.peers'
# caps에 "snap/1" 포함 확인
geth attach ./nodeB/geth.ipc --exec 'eth.syncing'
# snap sync 진행 확인
```

### 5.2 기존 테스트넷 검증

1. 테스트넷 시드 노드 1-2개에 snapshot 생성
2. 새 노드로 snap sync 시도
3. sync 완료 시간 측정 (full sync 대비)
4. 동기화 완료 후 state 정합성 검증:
   ```bash
   geth attach --exec 'eth.getBalance("0x...")'
   ```

### 5.3 회귀 테스트

| 기존 기능 | 영향 여부 | 검증 방법 |
|-----------|-----------|-----------|
| full sync | 영향 없음 | `--syncmode full`로 동기화 정상 확인 |
| meta/66 프로토콜 | 영향 없음 | 블록 전파, 트랜잭션 전파 정상 확인 |
| Metadium 커스텀 메시지 (GetStatusEx, EtcdAddMember 등) | 영향 없음 | meta/66 프로토콜 내 동작, snap과 독립 |
| 기존 피어 연결 | 영향 없음 | snap 미지원 피어와의 연결 정상 확인 |

---

## 6. 예상 리스크

### 6.1 높은 리스크

| 리스크 | 설명 | 완화 방법 |
|--------|------|-----------|
| Snapshot 생성 시간 | Metadium mainnet state 크기에 따라 snapshot 생성에 수시간~수일 소요 가능 | 테스트넷에서 먼저 소요 시간 측정, 운영 계획 수립 |
| 디스크 사용량 증가 | Snapshot 데이터가 추가 디스크 공간 소모 (state 크기의 ~50-100%) | 기존 노드의 디스크 여유 공간 확인 필요 |

### 6.2 중간 리스크

| 리스크 | 설명 | 완화 방법 |
|--------|------|-----------|
| 부분 네트워크 호환성 | 일부 노드만 업그레이드된 경우 snap sync가 불안정할 수 있음 | 시드 노드를 충분히 확보한 후 snap sync 권장 |
| Snapshot 정합성 | Metadium의 커스텀 state 변경(metadium 컨트랙트 등)이 snapshot에 정확히 반영되는지 | 동기화 후 state root 비교 검증 |

### 6.3 낮은 리스크

| 리스크 | 설명 | 완화 방법 |
|--------|------|-----------|
| 코드 변경 최소 | snap 프로토콜 코드 자체는 이미 go-ethereum에서 검증됨 | 코드 변경보다 운영 설정이 핵심 |
| 하위 호환성 | snap 미지원 피어와의 연결은 기존대로 동작 (snap 없이 meta/66만 사용) | devp2p 프로토콜 매칭 로직이 이를 처리 |

---

## 7. 핵심 결론

**snap 프로토콜 코드 변경은 거의 불필요하다.** 핵심 문제는 다음 두 가지다:

1. **네트워크에 snapshot을 보유한 노드가 없다** -- 운영 레벨 문제
2. **기존 노드들이 snapshot을 생성하도록 유도해야 한다** -- 설정/재시작 문제

코드 레벨에서 필요한 변경은:
- `eth/handler.go`의 주석 업데이트 (snap 지원 상태 반영)
- 선택적: 폴백 임계값 조정, 로깅 강화

대부분의 작업은 **운영 절차** (기존 노드에 snapshot 생성, 시드 노드 확보, 네트워크 점진적 업그레이드)에 해당한다.

---

## 변경 이력

| 날짜 | 변경 내용 | 이유 |
|------|-----------|------|
| 2026-03-13 | 초기 작성 | snap 프로토콜 지원 분석 및 설계 |
