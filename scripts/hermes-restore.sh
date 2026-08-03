#!/usr/bin/env bash
# hermes-restore.sh — restore Hermes + 9Router from backup (local or R2)
#
# Usage:
#   hermes-restore.sh list                    # list available backups
#   hermes-restore.sh latest                  # restore newest local zips
#   hermes-restore.sh <full-zip>              # restore from a specific local full zip
#   hermes-restore.sh --from-r2 <full-zip>    # pull + restore from R2
#
# Restores: hermes_full_*.zip (state.db, skills, config, .env, cron, sessions...)
#           hermes_state_*.zip (memory_store.db, config, cron)
#           9router_*.zip (~/.9router)
#
# SAFETY: never overwrites live config/.env/auth without --force.
#   Pass --force to overwrite existing config.yaml / .env / auth.json.
#   DBs (state.db, memory_store.db) are only restored if missing or --force.
#   Hermes should be STOPPED before restoring DBs.

set -euo pipefail

BACKUP_ROOT="${HERMES_BACKUP_ROOT:-$HOME/hermes-backups}"
RCLONE_REMOTE="${RCLONE_REMOTE:-r2-crypt}"
HERMES_HOME="$HOME/.hermes"
FORCE=0
FROM_R2=0

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --from-r2) FROM_R2=1 ;;
  esac
done

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

pick_zip() {
  # $1 = glob prefix; prints newest matching zip
  ls -1t "$BACKUP_ROOT"/${1}_*.zip 2>/dev/null | head -1 || true
}

fetch_from_r2() {
  # $1 = basename of zip to fetch
  local name="$1"
  if [ ! -f "$BACKUP_ROOT/$name" ]; then
    log "pulling $name from R2..."
    rclone copy "$RCLONE_REMOTE:hermes-backups/$name" "$BACKUP_ROOT/" 2>&1
  fi
}

case "${1:-list}" in
  list)
    echo "=== local backups in $BACKUP_ROOT ==="
    ls -1t "$BACKUP_ROOT"/*.zip 2>/dev/null | xargs -n1 basename || echo "(none)"
    echo ""
    echo "=== R2 backups ==="
    rclone lsf "$RCLONE_REMOTE:hermes-backups/" 2>/dev/null || echo "(rclone unavailable)"
    exit 0
    ;;

  latest)
    FULL=$(pick_zip hermes_full)
    STATE=$(pick_zip hermes_state)
    NINE=$(pick_zip 9router)
    [ -n "$FULL" ] || { log "no full backup found locally"; exit 1; }
    log "restoring: $FULL"
    RESTORE_ZIPS=("$FULL")
    [ -n "$STATE" ] && RESTORE_ZIPS+=("$STATE")
    [ -n "$NINE" ] && RESTORE_ZIPS+=("$NINE")
    ;;

  *)
    if [ -f "${1:-}" ]; then
      RESTORE_ZIPS=("$1")
    else
      # try R2
      if [ "$FROM_R2" = "1" ]; then
        fetch_from_r2 "$1"
        RESTORE_ZIPS=("$BACKUP_ROOT/$1")
      else
        log "backup not found: $1 (use list, latest, or a .zip path)"
        exit 1
      fi
    fi
    ;;
esac

# --- sanity: refuse restore over live Hermes for DBs unless forced ---
if [ -f "$HERMES_HOME/state.db" ] && [ "$FORCE" != "1" ]; then
  log "WARNING: live state.db exists. Restoring will REPLACE it."
  log "Stop Hermes first. Re-run with --force to proceed."
  exit 1
fi

for ZIP in "${RESTORE_ZIPS[@]}"; do
  log "=== restoring $ZIP ==="
  STAGE="$(mktemp -d)"
  unzip -q "$ZIP" -d "$STAGE"
  BASE="$(basename "$ZIP")"

  case "$BASE" in
    hermes_full_*)
      # full zip: entries are relative to ~/.hermes
      if [ "$FORCE" = "1" ]; then
        cp -a "$STAGE"/. "$HERMES_HOME"/
      else
        # safe overlay: never clobber config/.env/auth; restore DBs only if missing
        for f in config.yaml .env auth.json gateway_state.json channel_directory.json; do
          if [ -f "$STAGE/$f" ] && [ ! -f "$HERMES_HOME/$f" ]; then
            cp -a "$STAGE/$f" "$HERMES_HOME/$f"
          fi
        done
        for d in skills sessions profiles plugins cron pairing platforms memories scripts docs hooks agent state; do
          [ -d "$STAGE/$d" ] && cp -a "$STAGE/$d" "$HERMES_HOME"/
        done
        for db in state.db memory_store.db kanban.db projects.db verification_evidence.db; do
          if [ -f "$STAGE/$db" ] && [ ! -f "$HERMES_HOME/$db" ]; then
            cp -a "$STAGE/$db" "$HERMES_HOME/$db"
          fi
        done
      fi
      log "hermes restored to $HERMES_HOME"
      ;;

    hermes_state_*)
      # state bundle: memory_store.db + config.yaml + cron/jobs.json
      if [ -f "$STAGE/memory_store.db" ]; then
        if [ "$FORCE" = "1" ] || [ ! -f "$HERMES_HOME/memory_store.db" ]; then
          cp -a "$STAGE/memory_store.db" "$HERMES_HOME/memory_store.db"
          log "memory_store.db restored"
        fi
      fi
      if [ -f "$STAGE/config.yaml" ] && { [ "$FORCE" = "1" ] || [ ! -f "$HERMES_HOME/config.yaml" ]; }; then
        cp -a "$STAGE/config.yaml" "$HERMES_HOME/config.yaml"
        log "config.yaml restored"
      fi
      if [ -d "$STAGE/cron" ]; then
        mkdir -p "$HERMES_HOME/cron"
        cp -a "$STAGE/cron/." "$HERMES_HOME/cron/"
        log "cron/ restored"
      fi
      ;;

    9router_*)
      # 9router zip: entries are relative to ~ (i.e. .9router/...)
      if [ -d "$STAGE/.9router" ]; then
        if [ "$FORCE" = "1" ] || [ ! -d "$HOME/.9router" ]; then
          cp -a "$STAGE/.9router" "$HOME"/
          log ".9router restored to $HOME/.9router"
        fi
      fi
      ;;
  esac
  rm -rf "$STAGE"
done

log "=== restore complete ==="
log "Next: stop/restart Hermes. Verify: hermes doctor"
