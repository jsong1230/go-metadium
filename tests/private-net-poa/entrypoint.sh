#!/bin/bash
set -e

DATADIR="${DATADIR:-/data/geth}"
GENESIS="${GENESIS:-/data/genesis.json}"

# $@에서 --consensusmethod 값 추출 (기본값: 2=PoA)
CONSENSUS_METHOD=2
prev=""
for arg in "$@"; do
  if [[ "$prev" == "--consensusmethod" ]]; then CONSENSUS_METHOD="$arg"; fi
  prev="$arg"
done

# genesis로 초기화 (chaindata 없을 때만)
# gmet init도 동일한 consensusmethod로 실행해야 헤더 RLP 포맷이 일치함
if [ ! -d "$DATADIR/geth/chaindata" ]; then
    echo "[entrypoint] Initializing node with genesis: $GENESIS (consensusmethod=$CONSENSUS_METHOD)"
    gmet init --datadir "$DATADIR" --consensusmethod "$CONSENSUS_METHOD" "$GENESIS"
    echo "[entrypoint] Init complete."
fi

echo "[entrypoint] Starting gmet..."
exec gmet --datadir "$DATADIR" "$@"
