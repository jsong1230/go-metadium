# Go Metadium - Feature Backlog

> Last Updated: 2026-03-10
> Project Phase: Phase 0 (Infrastructure) - In Progress

---

## Status Legend
- ⏳ Pending - Feature not started
- 🔄 In Progress - Feature being developed
- ✅ Completed - Feature fully implemented and tested
- ⏸️ On Hold - Feature temporarily paused
- ❌ Cancelled - Feature cancelled

---

## Core Features (Implemented)

### F-01: Core Blockchain Engine
- **Status**: ✅ Completed
- **Priority**: Must Have
- **Description**: Core blockchain implementation based on go-ethereum fork
- **Components**:
  - Block processing and validation
  - State management with Merkle Patricia Trie
  - Transaction pool management
  - State transitions
- **Files**: `core/`, `trie/`, `eth/`
- **Acceptance Criteria**:
  - Blocks can be processed and validated correctly
  - State transitions are deterministic
  - Transaction pool manages pending transactions
  - State DB stores world state efficiently

---

### F-02: Clique Consensus (Proof of Authority)
- **Status**: ✅ Completed
- **Priority**: Must Have
- **Description**: PoA-based consensus algorithm with governance-controlled signers
- **Components**:
  - Signer management through governance contracts
  - Block sealing and authorization
  - Snapshot management for fast validation
- **Files**: `consensus/clique/`
- **Acceptance Criteria**:
  - Only authorized signers can create blocks
  - Signer list can be updated via governance
  - Block verification is efficient using snapshots
  - Fork recovery works correctly

---

### F-03: P2P Networking
- **Status**: ✅ Completed
- **Priority**: Must Have
- **Description**: devp2p-based peer discovery and communication
- **Components**:
  - Node discovery (discv4, discv5)
  - Peer management and connection handling
  - RLPx encrypted transport protocol
  - NAT traversal support
- **Files**: `p2p/`, `enode/`, `enr/`, `rlpx/`
- **Acceptance Criteria**:
  - Nodes can discover peers via DHT
  - Encrypted P2P communication works
  - NAT traversal enables connection behind firewalls
  - Peer connection management handles churn

---

### F-04: JSON-RPC API
- **Status**: ✅ Completed
- **Priority**: Must Have
- **Description**: Ethereum-compatible JSON-RPC API with Metadium extensions
- **Components**:
  - HTTP, WebSocket, IPC transports
  - Standard eth_, net_, web3_ APIs
  - Personal account management APIs
- **Files**: `rpc/`, `internal/ethapi/`
- **Acceptance Criteria**:
  - All standard Ethereum JSON-RPC methods work
  - Account management APIs are functional
  - Multiple transports (HTTP/WS/IPC) work correctly
  - API authentication and CORS are configurable

---

### F-05: Account Management
- **Status**: ✅ Completed
- **Priority**: Must Have
- **Description**: Keystore, wallet, and key management
- **Components**:
  - Encrypted keystore files
  - Account creation and import/export
  - Transaction signing
- **Files**: `accounts/`, `signer/`
- **Acceptance Criteria**:
  - Accounts can be created and encrypted
  - Transactions can be signed securely
  - Keystore files follow standard format
  - Account import/export works correctly

---

## Metadium-Specific Features (Implemented)

### F-06: Fee Delegation Transactions
- **Status**: ✅ Completed
- **Priority**: Must Have (Metadium Core)
- **Description**: Third-party fee payment for transactions
- **Components**:
  - FeeDelegateDynamicFeeTx (Type 22)
  - FeePayer signature handling
  - RPC API extensions
- **Files**: `core/types/feedelegate_dynamic_fee_tx.go`, `core/types/transaction_signing.go`, `internal/ethapi/api.go`
- **Acceptance Criteria**:
  - Sender creates and signs transaction
  - FeePayer adds their signature
  - Network validates both signatures
  - Fee is charged to feePayer address
  - RPC methods `personal.signTransaction` and `personal.signRawFeeDelegateTransaction` work
- **Documentation**: `/FEEDELEGATION.md`

---

### F-07: Governance System
- **Status**: ✅ Completed
- **Priority**: Must Have (Metadium Core)
- **Description**: On-chain governance via smart contracts
- **Components**:
  - Registry contract (service registry)
  - Gov contract (governance logic)
  - Staking contract (validator staking)
  - EnvStorage contract (environment parameters)
  - TRS contract (transaction restrictions)
- **Files**: `metadium/governance_abi.go`, `metadium/governance_legacy_abi.go`, `metadium/admin.go`, `metadium/metclient/`
- **Acceptance Criteria**:
  - Governance proposals can be created and voted
  - Validator set is managed via governance
  - Network parameters are configurable via governance
  - Staking rewards are distributed correctly
  - TRS can restrict transactions based on rules

---

### F-08: ETCD-based Node Coordination
- **Status**: ✅ Completed
- **Priority**: Must Have (Metadium Core)
- **Description**: Distributed coordination for validator nodes
- **Components**:
  - Embedded etcd server in each node
  - Peer-to-peer etcd clustering
  - Leader election for miner selection
  - Auto-compaction for storage management
- **Files**: `metadium/etcdutil.go`
- **Acceptance Criteria**:
  - Nodes form etcd cluster automatically
  - Leader election works reliably
  - Node membership is synchronized
  - Auto-compaction prevents storage bloat
  - Etcd data can be backed up and restored

---

### F-09: Metadium Mining
- **Status**: ✅ Completed
- **Priority**: Must Have (Metadium Core)
- **Description**: Governance-based block producer selection
- **Components**:
  - Validator rotation based on governance
  - Block generation with Metadium-specific parameters
  - Reward distribution (45% miner, 10% maintenance, 45% reward pool)
- **Files**: `metadium/miner/`
- **Acceptance Criteria**:
  - Validators are selected according to governance rules
  - Blocks are generated at correct intervals
  - Block rewards are distributed correctly
  - Mining can be started/stopped via RPC

---

### F-10: Transaction Restriction Service (TRS)
- **Status**: ✅ Completed
- **Priority**: Should Have
- **Description**: On-chain transaction filtering and restriction
- **Components**:
  - Address-level restrictions
  - Contract-level restrictions
  - Governance-managed rules
- **Files**: `metadium/`, governance contracts
- **Acceptance Criteria**:
  - Restricted addresses cannot send transactions
  - Restricted contracts cannot be called
  - Rules can be updated via governance
  - Restrictions are enforced at transaction pool level

---

### F-11: VRF (Verifiable Random Function)
- **Status**: ✅ Completed
- **Priority**: Should Have
- **Description**: Cryptographically secure random number generation
- **Components**:
  - VRF proof generation
  - VRF proof verification
  - Block producer selection using VRF
- **Files**: `github.com/yoseplee/vrf` dependency, `docs/vrf.md`
- **Acceptance Criteria**:
  - VRF proofs can be generated and verified
  - Randomness is unpredictable and unbiased
  - Block producer selection is provably random
- **Documentation**: `/docs/vrf.md`

---

## Infrastructure Features (Implemented)

### F-12: Database Layer (RocksDB/LevelDB)
- **Status**: ✅ Completed
- **Priority**: Must Have
- **Description**: Pluggable database backend with RocksDB (Linux) and LevelDB (Cross-platform)
- **Components**:
  - Database abstraction interface
  - RocksDB implementation (Linux only)
  - LevelDB implementation (default for non-Linux)
  - Batch operations and iterators
- **Files**: `ethdb/`, `rocksdb/` (submodule)
- **Acceptance Criteria**:
  - Database interface is consistent across backends
  - RocksDB is used on Linux for performance
  - LevelDB works on all platforms
  - Batch operations are atomic
  - Iterators support prefix-based queries

---

### F-13: Light Client Support (LES)
- **Status**: ✅ Completed
- **Priority**: Could Have
- **Description**: Light Ethereum Subprotocol for resource-constrained nodes
- **Components**:
  - Light sync mode
  - LES protocol implementation
  - Request/response handling for data retrieval
- **Files**: `les/`, `light/`
- **Acceptance Criteria**:
  - Light clients can sync chain headers
  - State proofs can be requested and verified
  - LES peers can serve data
  - Light mode uses significantly less storage

---

### F-14: GraphQL API
- **Status**: ✅ Completed
- **Priority**: Could Have
- **Description**: GraphQL interface for flexible queries
- **Components**:
  - GraphQL schema definition
  - Query resolver implementation
  - Subscription support
- **Files**: `graphql/`
- **Acceptance Criteria**:
  - GraphQL queries work correctly
  - Schema covers common use cases
  - Subscriptions stream real-time updates
  - Performance is acceptable for complex queries

---

## CLI Tools (Implemented)

### F-15: Main CLI (gmet)
- **Status**: ✅ Completed
- **Priority**: Must Have
- **Description**: Main command-line interface for running Metadium nodes
- **Components**:
  - Node startup and management
  - Configuration handling
  - Console mode (JavaScript REPL)
- **Files**: `cmd/gmet/`, `console/`
- **Acceptance Criteria**:
  - Nodes can be started with various sync modes
  - Configuration files are supported
  - Console mode provides interactive access
  - All standard flags work correctly

---

### F-16: Bootnode
- **Status**: ✅ Completed
- **Priority**: Should Have
- **Description**: Lightweight bootnode for network bootstrap
- **Components**:
  - P2P discovery only (no blockchain)
  - Static peer list management
- **Files**: `cmd/bootnode/`
- **Acceptance Criteria**:
  - Bootnode can serve peer discovery
  - Bootnode is lightweight and efficient
  - Multiple bootnodes can be configured

---

### F-17: Account Generation Tools
- **Status**: ✅ Completed
- **Priority**: Should Have
- **Description**: Tools for generating Metadium accounts and node keys
- **Components**:
  - `gmet metadium new-account` - Create encrypted account
  - `gmet metadium new-nodekey` - Create node key
  - `gmet metadium nodeid` - Get node ID from key
- **Files**: `cmd/gmet/metadium_commands.go`
- **Acceptance Criteria**:
  - Accounts can be created with encryption
  - Node keys can be generated
  - Node IDs can be derived from keys
  - Keys can be exported and imported

---

## New Features (Planned)

### F-18: Go 1.21 Upgrade
- **Status**: ✅ Completed
- **Priority**: Must Have
- **Description**: Upgrade Go version from 1.19 to 1.21 for performance and compatibility
- **Components**:
  - Update go.mod
  - Verify all tests pass
  - Update build scripts
- **Files**: `go.mod`, `Makefile`
- **Acceptance Criteria**:
  - All code compiles with Go 1.21
  - All tests pass
  - No deprecated patterns remain
  - Performance is maintained or improved
- **Dependencies**: None
- **Milestone**: M-0 (Phase 0 - Infrastructure)

---

### F-19: EIP-3651 - Warm COINBASE
- **Status**: ⏳ Pending
- **Priority**: Should Have
- **Description**: Reduce gas cost for accessing COINBASE address
- **Components**:
  - Modify gas calculation in state transition
  - Track COINBASE access per transaction
- **Files**: `core/state_transition.go`, `params/`
- **Acceptance Criteria**:
  - COINBASE access costs less gas in same transaction
  - Gas cost is 100 (cold) -> 2 (warm)
  - Backward compatible before fork block
  - Tests verify gas cost changes
- **Dependencies**: F-18
- **Milestone**: M-1 (Phase 1 - Camellia Fork)

---

### F-20: EIP-3855 - PUSH0 Opcode
- **Status**: ⏳ Pending
- **Priority**: Could Have
- **Description**: Add PUSH0 opcode (0x5F) to push zero bytes more efficiently
- **Components**:
  - Add opcode 0x5F to instruction table
  - Implement PUSH0 behavior (push 0 as single byte)
- **Files**: `core/vm/jump_table.go`, `core/vm/opcodes.go`
- **Acceptance Criteria**:
  - PUSH0 (0x5F) is recognized
  - Pushes zero value to stack
  - Gas cost is 2 (same as PUSH1)
  - Smart contracts can use PUSH0
  - Tests verify opcode behavior
- **Dependencies**: F-18
- **Milestone**: M-1 (Phase 1 - Camellia Fork)

---

### F-21: EIP-3860 - Initcode Size Limit
- **Status**: ⏳ Pending
- **Priority**: Should Have
- **Description**: Limit initcode size to 49152 bytes
- **Components**:
  - Add initcode size validation
  - Revert if initcode exceeds limit
- **Files**: `core/vm/evm.go`, `core/vm/contract.go`
- **Acceptance Criteria**:
  - Initcode > 49152 bytes reverts
  - Gas calculation accounts for limit
  - Error message is clear
  - Tests verify limit enforcement
- **Dependencies**: F-18
- **Milestone**: M-1 (Phase 1 - Camellia Fork)

---

### F-22: EIP-1153 - TLOAD/TSTORE Opcodes
- **Status**: ⏳ Pending
- **Priority**: Should Have
- **Description**: Add transient storage opcodes for temporary data
- **Components**:
  - Add TLOAD (0x5B) and TSTORE (0x5C) opcodes
  - Implement transient storage (cleared after transaction)
  - Gas pricing for transient storage
- **Files**: `core/vm/jump_table.go`, `core/vm/opcodes.go`, `core/vm/evm.go`
- **Acceptance Criteria**:
  - TLOAD/TSTORE opcodes work correctly
  - Transient storage is cleared after transaction
  - Gas cost is appropriate (100 warm, 2500 cold)
  - Smart contracts can use transient storage
  - Tests verify behavior and gas costs
- **Dependencies**: F-18
- **Milestone**: M-1 (Phase 1 - Camellia Fork)

---

### F-23: EIP-5656 - MCOPY Opcode
- **Status**: ⏳ Pending
- **Priority**: Could Have
- **Description**: Add MCOPY opcode for efficient memory copying
- **Components**:
  - Add MCOPY (0x5E) opcode
  - Implement memory copy logic
  - Gas calculation based on word count
- **Files**: `core/vm/jump_table.go`, `core/vm/opcodes.go`, `core/vm/memory.go`
- **Acceptance Criteria**:
  - MCOPY opcode copies memory regions
  - Source and destination can overlap
  - Gas cost is 3 + 3*words
  - Smart contracts can use MCOPY
  - Tests verify behavior and gas costs
- **Dependencies**: F-18
- **Milestone**: M-1 (Phase 1 - Camellia Fork)

---

### F-24: EIP-6780 - SELFDESTRUCT Limitation
- **Status**: ⏳ Pending
- **Priority**: Should Have
- **Description**: Limit SELFDESTRUCT to only destroy contracts created in same transaction
- **Components**:
  - Modify SELFDESTRUCT behavior
  - Track contract creation in transaction
  - Refund gas only if contract created in same tx
- **Files**: `core/vm/instructions.go`, `core/vm/evm.go`
- **Acceptance Criteria**:
  - SELFDESTRUCT only destroys contracts created in same transaction
  - Gas refund is 24000 (same contract) or 0 (different)
  - Contract storage is cleared correctly
  - Tests verify behavior
- **Dependencies**: F-18
- **Milestone**: M-1 (Phase 1 - Camellia Fork)

---

### F-25: EIP-4844 - Blob Transactions
- **Status**: ⏳ Pending
- **Priority**: Should Have
- **Description**: Add blob transaction type (Type 3) for large data storage
- **Components**:
  - BlobTx structure and RLP encoding
  - Blob sidecar handling
  - BLOBHASH and BLOBBASEFEE opcodes
  - KZG point evaluation precompile (0x0A)
  - Blob gas pricing and market
  - P2P blob propagation (SPoA adjusted)
- **Files**:
  - `core/types/blob_tx.go`, `core/types/tx_blob.go`
  - `core/vm/opcodes.go`, `core/vm/jump_table.go`
  - `core/vm/contracts.go` (KZG precompile)
  - `params/config.go`, `params/protocol_params.go`
  - `core/blockchain.go`
- **Acceptance Criteria**:
  - BlobTx (Type 3) can be created and sent
  - Blob data is stored in sidecar (not state)
  - BLOBHASH opcode returns blob hashes
  - BLOBBASEFEE opcode returns blob gas price
  - KZG precompile verifies blob proofs
  - Blob gas pricing follows EIP-4844 formula
  - P2P propagation works with SPoA timing
  - Blob retention period is block-based (not slot-based)
  - Initial max blob count is 2 per block
  - Tests verify all components
- **Dependencies**: F-18, F-06 (Fee Delegation compatibility)
- **Milestone**: M-1 (Phase 1 - Camellia Fork)

---

### F-26: Fee Delegation with Blob Transactions
- **Status**: ⏳ Pending
- **Priority**: Could Have
- **Description**: Extend Fee Delegation to support Blob transactions
- **Components**:
  - FeeDelegateBlobTx (Type 23)
  - FeePayer signature for blob txs
  - RPC API extensions
- **Files**: `core/types/feedelegate_blob_tx.go`, `core/types/transaction.go`, `internal/ethapi/api.go`
- **Acceptance Criteria**:
  - FeeDelegateBlobTx can be created
  - Both sender and feePayer signatures are validated
  - RPC methods support blob fee delegation
  - Tests verify correctness
- **Dependencies**: F-06, F-25
- **Milestone**: M-1 (Phase 1 - Camellia Fork) or M-2 (Phase 2)

---

### F-27: Modern ABI Generation Pipeline
- **Status**: ⏳ Pending
- **Priority**: Should Have
- **Description**: Improve governance contract ABI generation from Solidity
- **Components**:
  - Automated ABI generation from contracts
  - Versioning for legacy vs modern ABI
  - Build-time validation
- **Files**: `metadium/contracts/`, `Makefile`, `build/`
- **Acceptance Criteria**:
  - ABIs are generated from Solidity contracts
  - Legacy and modern ABIs are both supported
  - Build fails if ABI generation fails
  - Clear documentation for contract updates
- **Dependencies**: None
- **Milestone**: M-0 (Phase 0 - Infrastructure)

---

### F-28: Enhanced Testing Suite
- **Status**: ⏳ Pending
- **Priority**: Should Have
- **Description**: Comprehensive test coverage for Metadium-specific features
- **Components**:
  - Fee Delegation test suite
  - Governance contract tests
  - ETCD coordination tests
  - Integration tests
- **Files**: `metadium/*_test.go`, `tests/`
- **Acceptance Criteria**:
  - Fee Delegation has >80% coverage
  - Governance has >80% coverage
  - ETCD has >80% coverage
  - Integration tests cover critical paths
  - All tests pass consistently
- **Dependencies**: None
- **Milestone**: M-0 (Phase 0 - Infrastructure)

---

### F-29: Documentation Improvements
- **Status**: ⏳ Pending
- **Priority**: Could Have
- **Description**: Improve project documentation for developers and operators
- **Components**:
  - Architecture diagrams
  - Fee Delegation workflow documentation
  - Governance setup guide
  - ETCD configuration guide
  - API reference documentation
- **Files**: `docs/`
- **Acceptance Criteria**:
  - Architecture overview is clear
  - Fee Delegation has end-to-end guide
  - Governance setup is documented
  - ETCD configuration is documented
  - API reference is complete
- **Dependencies**: None
- **Milestone**: M-0 (Phase 0 - Infrastructure)

---

### F-30: Performance Optimization
- **Status**: ⏳ Pending
- **Priority**: Could Have
- **Description**: Optimize performance bottlenecks
- **Components**:
  - ETCD compaction tuning
  - State caching improvements
  - Database query optimization
  - Memory usage profiling
- **Files**: `metadium/etcdutil.go`, `core/state/`, `ethdb/`
- **Acceptance Criteria**:
  - ETCD storage growth is controlled
  - State access is faster
  - Database queries are optimized
  - Memory usage is reduced
  - Benchmarks show improvement
- **Dependencies**: F-18, F-28
- **Milestone**: M-0 (Phase 0 - Infrastructure) or M-1

---

## Future Features (Prague Phase)

### F-31: EIP-7702 - EOA Code Setting
- **Status**: ⏳ Pending
- **Priority**: Should Have
- **Description**: Allow EOAs to temporarily set code (Account Abstraction)
- **Components**:
  - EOA code setting mechanism
  - Temporary code execution
  - Account Abstraction support
- **Files**: `core/vm/`, `core/state/`
- **Acceptance Criteria**:
  - EOAs can temporarily set code
  - Code is executed for that transaction only
  - Smart wallets can be implemented
  - Tests verify behavior
- **Dependencies**: F-25 (Phase 1 complete)
- **Milestone**: M-2 (Phase 2 - Figberry Fork)

---

### F-32: EIP-2537 - BLS12-381 Precompile
- **Status**: ⏳ Pending
- **Priority**: Could Have
- **Description**: Add BLS12-381 pairing operations precompile
- **Components**:
  - BLS12-381 precompile implementation
  - Gas pricing for BLS operations
- **Files**: `core/vm/contracts.go`
- **Acceptance Criteria**:
  - BLS12-381 operations work correctly
  - Gas costs are appropriate
  - Smart contracts can use BLS
  - Tests verify correctness
- **Dependencies**: F-25 (Phase 1 complete)
- **Milestone**: M-2 (Phase 2 - Figberry Fork)

---

### F-33: EIP-7623 - Calldata Gas Cost Adjustment
- **Status**: ⏳ Pending
- **Priority**: Could Have
- **Description**: Adjust calldata gas costs for better efficiency
- **Components**:
  - Modified gas cost calculation for calldata
  - Zero vs non-zero byte pricing
- **Files**: `core/vm/evm.go`, `params/`
- **Acceptance Criteria**:
  - Calldata gas costs follow EIP-7623
  - Zero bytes cost less
  - Tests verify gas costs
- **Dependencies**: F-25 (Phase 1 complete)
- **Milestone**: M-2 (Phase 2 - Figberry Fork)

---

## Excluded Features

### F-34: EIP-4895 - Validator Withdrawals
- **Status**: ❌ Cancelled
- **Priority**: N/A
- **Description**: Beacon Chain validator withdrawals
- **Reason**: Metadium uses SPoA, not PoS Beacon Chain. No withdrawals applicable.
- **Files**: N/A

---

### F-35: EIP-4788 - Beacon Block Root
- **Status**: ❌ Cancelled
- **Priority**: N/A
- **Description**: Expose Beacon Block Root in EVM
- **Reason**: Metadium uses SPoA, not PoS Beacon Chain. No beacon blocks exist.
- **Files**: N/A

---

### F-36: EIP-7251 - Validator Max Stake
- **Status**: ❌ Cancelled
- **Priority**: N/A
- **Description**: Increase maximum validator stake for PoS
- **Reason**: Metadium uses SPoA, not PoS. Staking is managed differently via governance.
- **Files**: N/A

---

## Feature Dependencies Graph

```
F-18 (Go 1.21 Upgrade)
    ├── F-19 (EIP-3651)
    ├── F-20 (EIP-3855)
    ├── F-21 (EIP-3860)
    ├── F-22 (EIP-1153)
    ├── F-23 (EIP-5656)
    ├── F-24 (EIP-6780)
    ├── F-25 (EIP-4844) ──┬──> F-26 (Fee Delegation Blob)
    │                    └──> F-31, F-32, F-33 (Prague EIPs)
    └── F-30 (Performance Optimization)

F-06 (Fee Delegation) ──> F-26 (Fee Delegation Blob)

F-28 (Testing Suite) ──> F-30 (Performance Optimization)
```

---

## Notes

- **Metadium Core Features (F-06 to F-11)** must remain unchanged during fork upgrades
- Fee Delegation (F-06) is backward compatible and must continue to work after all forks
- ETCD coordination (F-08) timing needs adjustment for EIP-4844 blob propagation
- All PoS-specific EIPs (4895, 4788, 7251) are excluded as Metadium uses SPoA
- Phase 1 (Camellia) consolidates Shanghai + Cancun EIPs into a single fork
- Phase 2 (Figberry) will be planned after Prague spec is finalized
