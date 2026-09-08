# Private-PoA block timing

A private Metadium PoA deployment usually wants a different bargain than the
public chain does. The public networks take a fixed cadence from governance and
seal on that clock whether or not anyone sent a transaction. An enterprise chain
is typically idle most of the time and then needs a transaction *confirmed*
quickly -- waiting out the rest of a 5 second slot is the whole latency.

Two node flags restore the behavior early Metadium had (`11be6ec99`, 2018-06-29,
"immediate block generation / empty blocks only after maxidleblockinterval"),
without changing what the public networks do.

| Flag | Unit | Default | Effect |
|---|---|---|---|
| `--metadium.block.idleseal` | ms | `0` (off) | Once the block being built holds at least one transaction, seal it as soon as no new transaction has arrived for this long, instead of holding the slot open to its deadline. |
| `--metadium.block.emptyinterval` | s | `0` (off) | While the pool is empty, produce no block at all until this many seconds have passed since the parent. |

Both default to off, which is exactly the behavior of a build without them.

## Configuring a private PoA network

1. **Block interval is on-chain, not a flag.** The sealer reads
   `EnvStorage.getBlockCreationTime` (milliseconds) through
   `getBlockBuildParameters`. Set it when the governance contracts are deployed
   -- in `tests/private-net-poa` that is `BLOCK_CREATION_TIME=5000 ./deploy.sh`
   -- or change it later by ballot. Note `timeIt` divides it by 1000, so the
   interval has one-second granularity and anything under 1000ms falls back to
   2 seconds.
   `--metadium.block.interval` looks like the knob for this but is dead: the
   value is stored in `params.BlockInterval` and never read.

2. **Set the two flags identically on every sealer.** They only take effect on
   the node that is building a block, so a fleet with mixed values simply gets
   different latency depending on whose turn it is. Non-sealing RPC and full
   nodes ignore them (`commitWork` returns before this code on a non-miner), so
   passing them there is harmless but pointless.

3. **Typical enterprise profile** -- 5 second heartbeat, ~100ms confirmation:

   ```
   # governance (once, at deploy time)
   blockCreationTime = 5000

   # every sealer
   --metadium.block.idleseal 100
   ```

   Add `--metadium.block.emptyinterval <s>` only if the empty-block stream
   itself is a problem (disk growth on a chain that is idle for long stretches).
   It is not needed for latency.

## Measured behavior

3-node PoA private net (`tests/private-net-poa`, LevelDB, one host), governance
`blockCreationTime = 5000`, all three nodes sealing. "Confirm" is wall clock
from `eth_sendTransaction` returning to the receipt being available.

| Configuration | Idle cadence | Confirm (single tx) | 40-tx burst |
|---|---|---|---|
| flags off (public-network behavior) | empty block every 4.3-5.8s | avg 2544ms (min 1962, max 2634) | 1 block, 5657ms |
| `idleseal=100` | empty block every 4.3s | **avg 117ms** (min 117, max 118) | 1 block, **174ms** |
| `idleseal=100` + `emptyinterval=30` | **1 block / ~30s** | **avg 123ms** (min 116, max 127) | 1 block, 179ms |

Across the runs: three nodes stayed in lockstep at the same head, 40 sampled
blocks had no parent-hash break, and the logs carried no `BAD BLOCK`, no panic
and no seal failure. The only ERROR lines were the harness's pre-existing
`static-nodes.json is deprecated` warnings.

## Interactions worth knowing

**The drift correction still owns the empty-block cadence.** `timeIt` compares
recent block density against the nominal interval and either shortens the next
slot (behind: `(interval-1)s + BlockMinBuildTime`) or stretches it (ahead:
`interval + BlockMinBuildTime + 500ms`). That is why the idle cadence above
reads 4.3s or 5.8s rather than a flat 5s. Early sealing feeds this loop -- a
busy chain produces blocks faster than the interval and the correction then
slows the *empty* slots down. It does not blunt the latency win, because
`idleseal` fires relative to the last transaction, not to the slot deadline;
the slot deadline only ever acts as the upper bound.

**With `emptyinterval` on, a transaction block may be trailed by one empty
block.** The withhold decision is taken in `commitWork` from the pool's own
view, before the mining-token gate. A node that has not yet reset its pool after
someone else sealed the transaction still sees it as pending, does not skip, and
builds a round that comes out empty. Deciding after the fill instead -- where
emptiness is known exactly -- was measured and rejected: a round discarded at
that point has already taken the mining token and leaves it to expire (TTL 10s),
which pushed confirmation from 117ms to **4.4s average**. One trailing empty
block is the cheaper trade, and the comment in `commitTransactionsEx` records it
so the next reader does not redo the experiment.

**Timestamps are seconds, and several blocks can share one.** PoA permits it --
the `header.Time <= parent.Time` rejection in `consensus/ethash/consensus.go` is
guarded by `metaminer.IsPoW()` -- so this is consensus-legal. Explorers and
indexers that compute block time by subtracting timestamps will show 0s gaps.

**Finality depth is measured in blocks, not seconds.** `GetFinalizedBlockNumber`
returns `head - (govNodeCount/2 + 1)`. Withholding empty blocks means those
confirmations arrive only as fast as real traffic produces blocks, so on a very
quiet chain a transaction is included in ~100ms but finalized later than the
fixed-cadence chain would have finalized it. Use `emptyinterval` deliberately.

## Why mainnet and testnet are unaffected

- **Off by default.** `params.BlockIdleSealTime` and `params.BlockEmptyInterval`
  are 0, and every new path is behind a `> 0` test. With the flags unset the
  sealer runs the same code it ran before: the idle timer is never created, no
  extra transaction subscription is opened, and `commitWork` gains one integer
  comparison. Measured on the same binary with the flags omitted: idle cadence
  and confirmation latency matched the pre-change baseline.
- **Refused outright on the public chains.** `eth.New` looks up the genesis hash
  and returns an error -- the node exits rather than starting -- if either flag
  is set on a chain whose genesis is `MetadiumMainnetGenesisHash` or
  `MetadiumTestnetGenesisHash`. Keyed on genesis rather than chain id, because a
  private chain may reuse a chain id but never the public genesis.
- **No consensus rule is touched.** Block spacing is not validated by
  `verifyHeader`; producer rotation is height-based
  (`admin.go: ix := int(height/blocksPer) % len(nodes)`); rewards are per block.
  A node running these flags produces blocks that any stock node accepts, and
  the flags change nothing about validation, so a mixed fleet stays in
  agreement -- the sealers just close blocks sooner.
- **Sealer-side only.** Nothing in the import, sync or RPC path reads either
  value.
