# Go Metadium - Development Roadmap

> Last Updated: 2026-03-10
> Current Version: Bokbunja (Merge-equivalent)
> Target Version: Elderflower (Shanghai + Cancun)

---

## Current Status

### System Overview
Go Metadium is a Go-based blockchain client forked from go-ethereum, customized for the Metadium network with:
- **Consensus**: Stake-based Proof of Authority (SPoA) with Clique
- **Governance**: On-chain smart contract governance
- **Unique Features**: Fee Delegation, ETCD coordination, TRS, VRF
- **Network**: Mainnet (Chain ID: 11) and Testnet

### Current Implementation State

| Component | Status | Notes |
|-----------|--------|-------|
| Core Blockchain Engine | ✅ Fully Implemented | Based on go-ethereum |
| Clique Consensus | ✅ Fully Implemented | Modified for governance |
| P2P Networking | ✅ Fully Implemented | devp2p with discv4/v5 |
| JSON-RPC API | ✅ Fully Implemented | Ethereum-compatible |
| Account Management | ✅ Fully Implemented | Keystore + signer |
| Fee Delegation | ✅ Fully Implemented | Type 22 TX |
| Governance System | ✅ Fully Implemented | 5 contracts |
| ETCD Coordination | ✅ Fully Implemented | Embedded etcd |
| Metadium Mining | ✅ Fully Implemented | Validator rotation |
| TRS | ✅ Fully Implemented | Transaction restrictions |
| VRF | ✅ Fully Implemented | Random validator selection |
| Database Layer | ✅ Fully Implemented | RocksDB/LevelDB |
| Light Client (LES) | ✅ Fully Implemented | Optional sync mode |
| GraphQL API | ✅ Fully Implemented | Flexible queries |
| CLI Tools | ✅ Fully Implemented | gmet, bootnode, account tools |

### Gap Analysis vs Latest go-ethereum

| Area | Current (go-metadium) | Target (go-ethereum Prague) | Gap |
|------|----------------------|----------------------------|-----|
| Go Version | 1.19 → 1.21 ✅ | 1.21+ | Resolved |
| EVM Version | London | Prague | 3 major upgrades behind |
| TX Types | 0, 1, 2, 22 | 0, 1, 2, 3 | Missing Blob TX |
| Opcodes | Up to RANDOM | +20 new opcodes | PUSH0, MCOPY, TLOAD/TSTORE, BLOBHASH, etc. |
| Precompiles | 0x01-0x09 | 0x01-0x0A | Missing KZG (0x0A) |
| Consensus | SPoA (Clique) | PoS (Beacon) | Different model (intentional) |

### Technical Debt

| Issue | Priority | Impact | Status |
|-------|----------|--------|--------|
| RocksDB cross-platform build | Medium | MacOS/Windows can't use RocksDB | Use LevelDB fallback |
| ETCD embedded memory | Medium | Higher memory usage | Monitor and tune |
| Governance ABI generation | High | Build-time dependency on JS | F-27 addresses this |
| Test coverage for metadium/ | High | Limited testing | F-28 addresses this |
| Documentation gaps | Medium | Developer onboarding | F-29 addresses this |

---

## Development Strategy

### Approach
1. **Incremental Forking**: Single hardfork for Shanghai + Cancun (Elderflower)
2. **Feature Preservation**: All Metadium-specific features remain intact
3. **SPoA Adaptation**: PoS-specific EIPs excluded, timing adjusted
4. **Backward Compatibility**: Fee Delegation and governance continue working
5. **Test-Driven**: Comprehensive testing before mainnet deployment

### Branch Strategy
```
master (stable production)
│
├── feature/phase0-infra ✅        ← Go 1.21 upgrade (COMPLETED)
├── feature/phase1-elderflower      ← Shanghai + Cancun (IN PLANNING)
└── feature/phase2-figberry         ← Prague (FUTURE)
```

### Deployment Sequence
1. Feature branch development
2. Merge to master after testing
3. Testnet deployment with fork block number
4. 3-4 weeks monitoring
5. Mainnet hardfork date via governance vote
6. Mainnet activation

---

## Milestones

### M-0: Phase 0 - Infrastructure Foundation ✅ COMPLETED
**Duration**: 1 day (completed)
**Branch**: feature/phase0-infra
**Target**: Prepare codebase for modernization

| Feature | ID | Status | Completion |
|---------|----|--------|------------|
| Go 1.21 Upgrade | F-18 | ✅ Completed | 2026-03-10 |

**Deliverables**:
- Go 1.21 compatibility confirmed
- All tests passing
- No deprecated patterns

**Next Step**: Begin Phase 1 (Elderflower Fork)

---

### M-1: Phase 1 - Elderflower Fork (Shanghai + Cancun)
**Duration**: 8-10 weeks (estimated)
**Branch**: feature/phase1-elderflower
**Target**: Shanghai + Cancun EVM features
**Dependencies**: M-0 complete

| Phase | Feature | ID | Priority | Duration |
|-------|---------|----|----------|----------|
| 1.1 | EIP-3651 - Warm COINBASE | F-19 | Should | 1 week |
| 1.2 | EIP-3855 - PUSH0 Opcode | F-20 | Could | 1 week |
| 1.3 | EIP-3860 - Initcode Size Limit | F-21 | Should | 1 week |
| 1.4 | EIP-1153 - TLOAD/TSTORE | F-22 | Should | 2 weeks |
| 1.5 | EIP-5656 - MCOPY Opcode | F-23 | Could | 1 week |
| 1.6 | EIP-6780 - SELFDESTRUCT Limit | F-24 | Should | 1 week |
| 1.7 | EIP-4844 - Blob Transactions | F-25 | Should | 3 weeks |
| 1.8 | Fee Delegation Blob (Optional) | F-26 | Could | 1 week |
| 1.9 | Integration Testing | F-28 | Should | 2 weeks |
| 1.10 | Documentation Updates | F-29 | Could | 1 week |

**Total Estimated**: 14-16 development weeks (can be parallelized to 8-10 calendar weeks)

**Deliverables**:
- Shanghai EIPs (3651, 3855, 3860) implemented
- Cancun EIPs (1153, 5656, 6780, 4844) implemented
- Blob transaction support with SPoA timing adjustments
- Comprehensive test suite
- Updated documentation
- Testnet deployment package

**Acceptance Criteria**:
- All EIPs work correctly before/after fork block
- Metadium features (Fee Delegation, Governance, ETCD) unaffected
- Blob propagation works with SPoA block timing
- Test suite passes with >80% coverage for new features
- Testnet runs for 3-4 weeks without issues

**Risks**:
- Fee Delegation compatibility with Blob TX - Test thoroughly
- ETCD timing with Blob P2P propagation - Adjust timing
- Blob network load - Limit initial max blob count to 2
- Chain split if validators don't upgrade - Require coordinated upgrade

**Go/No-Go Criteria**:
- ✅ All EIP implementations pass unit tests
- ✅ Fee Delegation works with new TX types
- ✅ Governance and ETCD unaffected
- ✅ Testnet stable for 3+ weeks
- ✅ Governance approves mainnet upgrade
- ❌ Critical bugs in any component
- ❌ Testnet shows instability
- ❌ Governance votes against upgrade

---

### M-2: Phase 2 - Figberry Fork (Prague/Electra)
**Duration**: TBD (Prague spec not finalized)
**Branch**: feature/phase2-figberry
**Target**: Prague EVM features
**Dependencies**: M-1 complete, Prague spec finalized

| Feature | ID | Priority |
|---------|----|----------|
| EIP-7702 - EOA Code Setting | F-31 | Should |
| EIP-2537 - BLS12-381 Precompile | F-32 | Could |
| EIP-7623 - Calldata Gas Adjustment | F-33 | Could |

**Note**: This milestone will be re-planned after Prague specification is finalized.

---

### M-3: Maintenance & Optimization (Ongoing)
**Duration**: Ongoing
**Target**: Continuous improvement

| Feature | ID | Priority |
|---------|----|----------|
| Modern ABI Generation Pipeline | F-27 | Should |
| Enhanced Testing Suite | F-28 | Should |
| Documentation Improvements | F-29 | Could |
| Performance Optimization | F-30 | Could |

---

## Timeline

### Gantt Chart (Estimated)

```
Week  1-2:  Go 1.21 Upgrade                           ✅ DONE
Week  3-4:  EIP-3651, EIP-3855, EIP-3860
Week  5-6:  EIP-1153 (TLOAD/TSTORE)
Week  7-8:  EIP-5656, EIP-6780
Week  9-11: EIP-4844 (Blob Transactions) - Parallel with others
Week  12:   Fee Delegation Blob (Optional)
Week  13-14: Integration Testing
Week  15:   Documentation Updates
Week  16:   Testnet Deployment
Week  17-20: Testnet Monitoring (3-4 weeks)
Week  21:   Governance Vote
Week  22:   Mainnet Upgrade (if approved)
Week  23+:  Post-Upgrade Monitoring
```

**Total Estimated Time**: ~22 weeks (5.5 months) from start to mainnet

**Parallelization Opportunities**:
- EIP-3651, 3855, 3860 can be developed in parallel (Week 3-4)
- EIP-5656, 6780 can be developed in parallel (Week 7-8)
- EIP-4844 development overlaps with other EIPs (Week 9-11)

**Critical Path**:
1. Go 1.21 Upgrade ✅
2. EIP-4844 (Blob Transactions) - 3 weeks
3. Integration Testing - 2 weeks
4. Testnet Monitoring - 4 weeks
5. Governance Vote - 1 week

**Total Critical Path**: ~10 weeks after Go 1.21 upgrade

---

## Testing Strategy

### Test Pyramid
```
          ▲
         / \
        /E2E\          10%
       /-----\
      /Integ.\        20%
     /---------\
    /  Unit     \     70%
   /-------------\
```

### Test Coverage Targets

| Component | Current | Target | Priority |
|-----------|---------|--------|----------|
| Core Blockchain | N/A | 80% | High |
| Fee Delegation | N/A | 80% | High |
| Governance | N/A | 80% | High |
| ETCD Coordination | N/A | 80% | High |
| EIP-3651 | N/A | 80% | High |
| EIP-3855 | N/A | 80% | Medium |
| EIP-3860 | N/A | 80% | High |
| EIP-1153 | N/A | 80% | High |
| EIP-5656 | N/A | 80% | Medium |
| EIP-6780 | N/A | 80% | High |
| EIP-4844 | N/A | 80% | High |
| RPC API | N/A | 70% | Medium |

### Test Categories

1. **Unit Tests**: Test individual components in isolation
   - Opcodes
   - Precompiles
   - Transaction types
   - Gas calculations

2. **Integration Tests**: Test component interactions
   - Fee Delegation + new TX types
   - Governance + new parameters
   - ETCD + blob propagation
   - Fork block transitions

3. **Regression Tests**: Ensure existing features work
   - Metadium core features
   - Fee Delegation
   - Governance contracts
   - ETCD coordination

4. **E2E Tests**: Test full transaction flows
   - Blob transaction lifecycle
   - Fee Delegation with blobs
   - Governance proposals
   - Validator rotation

5. **Performance Tests**: Test under load
   - Throughput with blobs
   - Memory usage
   - ETCD storage growth
   - Network propagation delays

### Testnet Deployment Plan

1. **Testnet 1 (Development)**: Single validator, basic functionality
   - Duration: 1 week
   - Goal: Verify basic EIP implementations

2. **Testnet 2 (Multi-validator)**: 3-5 validators, full governance
   - Duration: 2-3 weeks
   - Goal: Verify multi-node behavior, governance, ETCD

3. **Testnet 3 (Stress Test)**: 10+ validators, high transaction load
   - Duration: 1-2 weeks
   - Goal: Verify performance under load

---

## Risk Management

### Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Fee Delegation broken by fork | Medium | High | Comprehensive testing, backward compatibility checks |
| ETCD timing issues with blobs | Medium | Medium | Adjust SPoA timing, separate tests |
| Chain split during upgrade | Low | Critical | Coordinated upgrade, governance vote |
| Blob storage overload | Medium | Medium | Limit max blob count, monitor storage |
| Performance degradation | Low | Medium | Benchmark before/after, optimize hot paths |
| Governance contract incompatibility | Low | High | Verify Solidity version, test with latest compiler |
| Testnet instability | Medium | Medium | Extend testing period, fix critical issues |
| Community rejection | Low | High | Transparent communication, governance vote |

### High-Risk Areas

1. **Fee Delegation (F-06)**
   - Risk: Changes to transaction handling break fee delegation
   - Mitigation: Extensive testing with all transaction types
   - Validation: Regression test suite before every deployment

2. **ETCD Coordination (F-08)**
   - Risk: ETCD timing conflicts with blob propagation
   - Mitigation: Adjust timing parameters, test with realistic load
   - Validation: Monitor ETCD during testnet, adjust if needed

3. **Blob Propagation (F-25)**
   - Risk: Large blob data causes network congestion
   - Mitigation: Limit initial max blob count to 2, monitor closely
   - Validation: Network metrics during testnet, adjust limits

4. **Governance Contracts**
   - Risk: ABI changes break existing contracts
   - Mitigation: Verify backward compatibility, use legacy ABI support
   - Validation: Test with existing contract deployments

### Contingency Plans

**If testnet shows critical issues**:
- Extend testnet period
- Roll back problematic changes
- Re-deploy fixed version

**If governance votes against upgrade**:
- Pause mainnet deployment
- Address community concerns
- Re-propose with modifications

**If chain split occurs**:
- Emergency halt coordination
- Investigate root cause
- Coordinate re-org if possible

---

## Success Metrics

### Technical Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Test Coverage | >80% (new features) | Code coverage reports |
| Test Success Rate | 100% | CI/CD test results |
| Testnet Uptime | >99% | Monitoring dashboards |
| Block Propagation Time | <2s | P2P metrics |
| TPS with Blobs | >100 (current baseline) | Performance tests |
| Memory Usage | <2GB per node | Resource monitoring |
| ETCD Storage Growth | <100MB/day | Disk usage metrics |

### Business Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Governance Participation | >50% validators | Governance contract data |
| Community Approval | >67% vote | Governance vote results |
| Mainnet Upgrade Success | 100% | Network health post-upgrade |
| Developer Adoption | Increasing | GitHub stars, issues, PRs |

---

## Communication Plan

### Stakeholders

| Group | Communication Channel | Frequency |
|-------|----------------------|-----------|
| Validators | Discord, Email | Weekly |
| Developers | GitHub, Discord | Bi-weekly |
| Community | Blog, Discord | Monthly |
| Partners | Direct meetings | As needed |

### Milestone Announcements

1. **Phase 1 Start**: Announcement of Elderflower Fork development
2. **Testnet Launch**: Public testnet available for testing
3. **Governance Proposal**: Mainnet upgrade vote initiated
4. **Mainnet Upgrade**: Hardfork execution announcement
5. **Post-Upgrade**: Success summary and lessons learned

---

## Glossary

| Term | Definition |
|------|------------|
| **SPoA** | Stake-based Proof of Authority, Metadium's consensus algorithm |
| **PoA** | Proof of Authority, consensus where signers create blocks |
| **PoS** | Proof of Stake, consensus where validators stake tokens |
| **Hardfork** | Network-wide protocol upgrade, requires all nodes to upgrade |
| **EIP** | Ethereum Improvement Proposal |
| **TX Type** | Transaction type identifier (0=Legacy, 1=AccessList, 2=DynamicFee, 3=Blob, 22=FeeDelegate) |
| **Blob** | Binary Large Object, large data attached to transactions (EIP-4844) |
| **ETCD** | Distributed key-value store used for node coordination |
| **Clique** | PoA consensus algorithm used by Metadium |
| **Fee Delegation** | Metadium feature allowing third-party fee payment |
| **TRS** | Transaction Restriction Service, on-chain transaction filtering |
| **VRF** | Verifiable Random Function, used for random validator selection |

---

## References

- System Analysis: `/docs/system/system-analysis.md`
- Modernization Plan: `/docs/modernization-plan.md`
- Fee Delegation: `/FEEDELEGATION.md`
- VRF Documentation: `/docs/vrf.md`
- Features Backlog: `/docs/project/features.md`

---

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2026-03-10 | 1.0 | Initial roadmap creation |
