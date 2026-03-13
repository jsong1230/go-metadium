#!/usr/bin/env bash
# update-node.sh - 서버에서 새 바이너리 빌드 및 노드 재시작
#
# 사용법:
#   (서버에서) bash update-node.sh [--rocksdb|--leveldb] [--datadir <path>] [--restart]
#
# 예시:
#   bash update-node.sh --rocksdb --datadir /data/jsong/gmet-rocksdb-data --restart
#
# 전제조건: Go 1.21+, librocksdb-dev (rocksdb 빌드 시)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

USE_ROCKSDB=0
DATADIR=""
DO_RESTART=0
BINARY_NAME=""
NODE_PID_FILE=""
NODE_CMD=""

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
err()  { echo "[ERROR] $*" >&2; exit 1; }

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rocksdb) USE_ROCKSDB=1; shift ;;
    --leveldb) USE_ROCKSDB=0; shift ;;
    --datadir) DATADIR="$2"; shift 2 ;;
    --restart) DO_RESTART=1; shift ;;
    *) err "Unknown arg: $1" ;;
  esac
done

log "=== go-metadium 노드 업데이트 ==="
log "저장소: $REPO_DIR"

# 최신 코드 pull
cd "$REPO_DIR"
log "git pull origin develop..."
git fetch origin
git checkout develop
git pull origin develop

# 빌드
if [[ $USE_ROCKSDB -eq 1 ]]; then
  BINARY_NAME="gmet-rocksdb"
  log "gmet (RocksDB) 빌드 중..."
  # RocksDB 공유 라이브러리 경로 탐색
  ROCKSDB_LIB=""
  for dir in /usr/lib/x86_64-linux-gnu /usr/lib/aarch64-linux-gnu /usr/local/lib; do
    if ls "$dir"/librocksdb.so* &>/dev/null 2>&1; then
      ROCKSDB_LIB="$dir"
      break
    fi
  done
  [[ -n "$ROCKSDB_LIB" ]] || err "librocksdb 없음. apt install librocksdb-dev 실행 후 재시도"

  CGO_CFLAGS="-I/usr/include" \
  CGO_LDFLAGS="-L$ROCKSDB_LIB -lrocksdb -lsnappy -llz4 -lzstd -lm -lstdc++ -ldl" \
  go build -tags rocksdb -o "$BINARY_NAME" ./cmd/gmet
else
  BINARY_NAME="gmet-leveldb"
  log "gmet (LevelDB) 빌드 중..."
  go build -o "$BINARY_NAME" ./cmd/gmet
fi

log "빌드 완료: $REPO_DIR/$BINARY_NAME ($(ls -lh $BINARY_NAME | awk '{print $5}'))"

# 재시작
if [[ $DO_RESTART -eq 1 ]]; then
  [[ -n "$DATADIR" ]] || err "--restart 시 --datadir 필요"

  # 기존 프로세스 찾기
  PIDS=$(pgrep -f "gmet.*--datadir.*$(basename $DATADIR)" 2>/dev/null || true)
  if [[ -n "$PIDS" ]]; then
    log "기존 프로세스 종료 (PID: $PIDS)..."
    kill $PIDS
    sleep 3
  fi

  log "노드 재시작..."
  log "바이너리를 교체하고 노드를 시작하세요:"
  log "  cp $REPO_DIR/$BINARY_NAME /data/jsong/$BINARY_NAME"
  log "  /data/jsong/$BINARY_NAME [기존 시작 옵션]"
  log ""
  log "detectDb() LOG 파일 문제 방지:"
  log "  --userocksdb 1 플래그를 사용하면 LOG 파일 무관하게 RocksDB 사용"
fi

log "=== 완료 ==="
