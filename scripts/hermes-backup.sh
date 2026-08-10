#!/usr/bin/env bash
# hermes-backup.sh — Hermes + 9Router backup → local dir → encrypted R2 (rclone)
# Usage: hermes-backup.sh [daily|weekly]
# Daily:  hermes backup --quick + 9router zip → rclone push → prune
# Weekly: full hermes backup + 9router zip → rclone push → prune

set -euo pipefail

MODE="${1:-daily}"
BACKUP_ROOT="${HERMES_BACKUP_ROOT:-$HOME/hermes-backups}"
RCLONE_REMOTE="${RCLONE_REMOTE:-r2-crypt}"      # crypt remote (encrypted at rest)
R2_BUCKET="${R2_BUCKET_NAME:-hermes-backup}"    # bucket name
KEEP_FULL="${KEEP_FULL:-5}"                     # weekly full zips to keep locally
KEEP_9R="${KEEP_9R:-30}"                        # 9router zips to keep locally
LOG_DIR="$HOME/.hermes/logs"
LOG_FILE="$LOG_DIR/hermes-backup.log"
ENV_FILE="$HOME/.hermes/backup.env"
HERMES_ENV="$HOME/.hermes/.env"
STAMP="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP_ROOT" "$LOG_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

# --- load R2 creds (never echo) ---
for f in "$HERMES_ENV" "$ENV_FILE"; do
  if [ -f "$f" ]; then
    set -a; source "$f"; set +a
  else
    log "ERROR: env file missing: $f"; exit 1
  fi
done
: "${R2_ACCESS_KEY_ID:?missing}"; : "${R2_SECRET_ACCESS_KEY:?missing}"

log "=== START $MODE backup ==="

# --- 9router zip (daily + weekly) ---
NINE_ZIP="$BACKUP_ROOT/9router_${STAMP}.zip"
if [ -d "$HOME/.9router" ]; then
  (cd "$HOME" && zip -qr "$NINE_ZIP" .9router -x ".9router/db/*-wal" -x ".9router/db/*-shm" -x ".9router/tailscale/*") \
    && log "9router zip: $NINE_ZIP" \
    || log "WARN: 9router zip failed"
fi

if [ "$MODE" = "weekly" ]; then
  # --- full backup: curated include set (irreplaceable state only) ---
  FULL_ZIP="$BACKUP_ROOT/hermes_full_${STAMP}.zip"
  STAGE="$(mktemp -d "$BACKUP_ROOT/.stage_${STAMP}.XXXXXX")"
  # 0. agentmemory shared store (iii-engine data dir; AGENTMEMORY_DATA_DIR if set)
  AM_DATA="${AGENTMEMORY_DATA_DIR:-$HOME/data}"
  if [ -d "$AM_DATA" ]; then
    mkdir -p "$STAGE/agentmemory-store"
    rsync -a "$AM_DATA/" "$STAGE/agentmemory-store/" 2>/dev/null \
      && log "staged agentmemory store: $AM_DATA" \
      || log "WARN: agentmemory store stage failed ($AM_DATA)"
  fi
  # 1. copy include set; exclude regenerable/transient trees + ALL live DBs
  rsync -a \
    --exclude 'hermes-agent' --exclude 'state-snapshots' \
    --exclude 'artifact' --exclude 'webui' --exclude 'lsp' --exclude 'bin' \
    --exclude 'logs' --exclude 'cache' --exclude 'backups' \
    --exclude 'models_dev_cache.json' --exclude 'webui.log' \
    --exclude '__pycache__' --exclude '.git' --exclude 'node_modules' \
    --exclude '*.db' --exclude '*.db-wal' --exclude '*.db-shm' --exclude '*.db-journal' \
    --exclude '*.pyc' \
    "$HOME/.hermes/" "$STAGE/" || { log "ERROR: rsync stage failed"; rm -rf "$STAGE"; exit 1; }
  # 2. WAL-safe DB snapshots directly from SOURCE (live DB -> consistent copy)
  python3 - "$STAGE" "$HOME/.hermes" <<'PYEOF' >> "$LOG_FILE" 2>&1 || true
import sqlite3, sys
from pathlib import Path
stage, srcroot = Path(sys.argv[1]), Path(sys.argv[2])
for db in srcroot.rglob("*.db"):
    if db.stat().st_size == 0:
        continue
    rel = db.relative_to(srcroot)
    if any(part in ("hermes-agent","state-snapshots","artifact","webui","lsp","bin","logs","cache","backups",".venv","venv","node_modules") for part in rel.parts):
        continue
    dst = stage / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    tmp = dst.with_name(dst.name + ".tmp")
    try:
        src = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        dstc = sqlite3.connect(str(tmp))
        src.backup(dstc)
        dstc.close(); src.close()
        tmp.replace(dst)
    except Exception as exc:
        print(f"DB snapshot failed {rel}: {exc}")
PYEOF
  # 3. zip stage (entries relative to .hermes root; zip dereferences symlinks -> content captured)
  (cd "$STAGE" && zip -qr "$FULL_ZIP" .) \
    && log "full hermes backup: $FULL_ZIP" \
    || log "ERROR: full zip failed"
  rm -rf "$STAGE"
else
  # --- quick snapshot (daily) + bundle critical state for R2 ---
  hermes backup --quick >/dev/null 2>&1 \
    && log "quick snapshot OK" \
    || log "ERROR: hermes quick backup failed"
  LATEST_SNAP="$(ls -1dt "$HOME/.hermes/state-snapshots"/*/ 2>/dev/null | head -1)"
  if [ -n "$LATEST_SNAP" ]; then
    STATE_ZIP="$BACKUP_ROOT/hermes_state_${STAMP}.zip"
    (cd "$LATEST_SNAP" && zip -qr "$STATE_ZIP" memory_store.db config.yaml cron/jobs.json 2>/dev/null) \
      && log "state bundle: $STATE_ZIP" \
      || log "WARN: state bundle zip failed"
  fi
fi

# --- prune local (9router daily, full weekly) ---
if [ "$MODE" = "weekly" ]; then
  ls -1t "$BACKUP_ROOT"/hermes_full_*.zip 2>/dev/null | tail -n +$((KEEP_FULL+1)) | xargs -r rm -f || true
fi
ls -1t "$BACKUP_ROOT"/9router_*.zip 2>/dev/null | tail -n +$((KEEP_9R+1)) | xargs -r rm -f || true
ls -1t "$BACKUP_ROOT"/hermes_state_*.zip 2>/dev/null | tail -n +$((KEEP_9R+1)) | xargs -r rm -f || true

# --- push to encrypted R2 ---
if command -v rclone >/dev/null 2>&1; then
  rclone copy "$BACKUP_ROOT" "$RCLONE_REMOTE:$(basename "$BACKUP_ROOT")" \
    --include "*.zip" --transfers 4 --log-file "$LOG_FILE" 2>&1 \
    && log "rclone push OK" \
    || log "ERROR: rclone push failed"
else
  log "WARN: rclone not found, skipping push"
fi

log "=== END $MODE backup ==="
