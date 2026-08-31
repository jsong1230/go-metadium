#!/usr/bin/env python3
"""Field-level RPC A/B diff: oracle (pre-rebase gmet) vs candidate (m1.1.3).

For each sampled block, fetch the same objects from both nodes and compare
recursively. Differences are classified:

  MISSING_IN_CAND  — field the oracle returns that the candidate dropped
                     (the #105 class; always a finding)
  VALUE_MISMATCH   — same field, different value (always a finding)
  MISSING_IN_ORACLE— field only the candidate has (new in 1.1.x; collected
                     for review, not a failure by itself)

Usage:
  rpc-ab-diff.py --oracle http://127.0.0.1:8546 --cand http://127.0.0.1:8545 \
                 --start 100000000 --end 117200000 --samples 2000 [--seed 42]

Only chain-data reads are compared (blocks, txs, receipts, logs). State reads
are skipped: both nodes are full-synced, so historical state is pruned.
"""
import argparse, json, random, sys, urllib.request
from collections import defaultdict

def rpc(url, method, params, timeout=30):
    body = json.dumps({"jsonrpc": "2.0", "method": method,
                       "params": params, "id": 1}).encode()
    req = urllib.request.Request(url, data=body,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        out = json.loads(r.read())
    if "error" in out:
        return ("__rpc_error__", out["error"].get("message", ""))
    return out.get("result")

def walk(path, a, b, report, method):
    """Recursively compare oracle value `a` against candidate value `b`."""
    if isinstance(a, dict) and isinstance(b, dict):
        for k in a:
            if k not in b:
                report[(method, f"{path}.{k}", "MISSING_IN_CAND")].append(a[k])
            else:
                walk(f"{path}.{k}", a[k], b[k], report, method)
        for k in b:
            if k not in a:
                report[(method, f"{path}.{k}", "MISSING_IN_ORACLE")].append(b[k])
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            report[(method, f"{path}.len", "VALUE_MISMATCH")].append((len(a), len(b)))
            return
        for x, y in zip(a, b):
            walk(f"{path}[*]", x, y, report, method)
    else:
        if a != b:
            report[(method, path, "VALUE_MISMATCH")].append((a, b))

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--oracle", required=True)
    p.add_argument("--cand", required=True)
    p.add_argument("--start", type=int, required=True)
    p.add_argument("--end", type=int, required=True)
    p.add_argument("--samples", type=int, default=1000)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--max-tx-per-block", type=int, default=20)
    args = p.parse_args()

    rng = random.Random(args.seed)
    blocks = sorted(rng.sample(range(args.start, args.end + 1),
                               min(args.samples, args.end - args.start + 1)))
    report = defaultdict(list)
    errors = []
    blocks_done = txs_done = 0

    for n in blocks:
        tag = hex(n)
        try:
            ob = rpc(args.oracle, "eth_getBlockByNumber", [tag, True])
            cb = rpc(args.cand, "eth_getBlockByNumber", [tag, True])
        except Exception as e:
            errors.append((n, "getBlock", str(e))); continue
        if isinstance(ob, tuple) or isinstance(cb, tuple):
            errors.append((n, "getBlock", (ob, cb))); continue
        walk("block", ob, cb, report, "eth_getBlockByNumber")
        blocks_done += 1

        txs = (ob or {}).get("transactions", [])[: args.max_tx_per_block]
        for tx in txs:
            h = tx["hash"] if isinstance(tx, dict) else tx
            for method in ("eth_getTransactionByHash", "eth_getTransactionReceipt"):
                try:
                    o = rpc(args.oracle, method, [h])
                    c = rpc(args.cand, method, [h])
                except Exception as e:
                    errors.append((h, method, str(e))); continue
                if isinstance(o, tuple) or isinstance(c, tuple):
                    errors.append((h, method, (o, c))); continue
                walk("obj", o, c, report, method)
            txs_done += 1

        try:
            ol = rpc(args.oracle, "eth_getLogs", [{"fromBlock": tag, "toBlock": tag}])
            cl = rpc(args.cand, "eth_getLogs", [{"fromBlock": tag, "toBlock": tag}])
            if not isinstance(ol, tuple) and not isinstance(cl, tuple):
                walk("logs", ol, cl, report, "eth_getLogs")
        except Exception as e:
            errors.append((n, "eth_getLogs", str(e)))

        bhash = (ob or {}).get("hash")
        extra = [("eth_getBlockByHash", [bhash, True]),
                 ("eth_getBlockTransactionCountByNumber", [tag]),
                 ("eth_getReceiptsByHash", [bhash])]
        if txs:
            extra.append(("eth_getTransactionByBlockNumberAndIndex", [tag, "0x0"]))
        for method, params in extra:
            try:
                o = rpc(args.oracle, method, params)
                c = rpc(args.cand, method, params)
            except Exception as e:
                errors.append((n, method, str(e))); continue
            if isinstance(o, tuple) or isinstance(c, tuple):
                errors.append((n, method, (o, c))); continue
            walk("obj", o, c, report, method)

        if blocks_done % 100 == 0:
            print(f"... {blocks_done}/{len(blocks)} blocks, {txs_done} txs",
                  file=sys.stderr)

    print(f"\n=== RPC A/B diff: {blocks_done} blocks, {txs_done} txs compared ===")
    findings = {k: v for k, v in report.items() if k[2] != "MISSING_IN_ORACLE"}
    newfields = {k: v for k, v in report.items() if k[2] == "MISSING_IN_ORACLE"}
    if not findings:
        print("FINDINGS: none — no dropped fields, no value mismatches.")
    else:
        print(f"FINDINGS ({len(findings)} distinct):")
        for (m, path, kind), vals in sorted(findings.items()):
            print(f"  [{kind}] {m} {path}  x{len(vals)}  e.g. {vals[0]!r}"[:300])
    if newfields:
        print(f"\nNew-in-candidate fields (review list, not failures):")
        for (m, path, _), vals in sorted(newfields.items()):
            print(f"  {m} {path}  x{len(vals)}  e.g. {vals[0]!r}"[:200])
    if errors:
        print(f"\nRPC/transport errors: {len(errors)} (first 5)")
        for e in errors[:5]:
            print(f"  {e!r}"[:200])
    sys.exit(1 if findings else 0)

if __name__ == "__main__":
    main()
