#!/bin/bash
set -e

DATADIR="${DATADIR:-/data/geth}"
GENESIS="${GENESIS:-/data/genesis.json}"

# genesis로 초기화 (chaindata 없을 때만)
if [ ! -d "$DATADIR/geth/chaindata" ]; then
    echo "[entrypoint] Initializing node with genesis: $GENESIS"
    gmet init --datadir "$DATADIR" "$GENESIS"
    echo "[entrypoint] Init complete."
fi

echo "[entrypoint] Starting gmet with args: $@"
exec gmet --datadir "$DATADIR" "$@"
