#!/usr/bin/env bash
# =============================================================================
# Shared agent layer installer — vendor-neutral pieces every agent harness
# (Claude Code, omp, ...) points at:
#   ~/.agents/hooks/   guard hooks (PreToolUse contract: JSON on stdin, exit 2 blocks)
#   ~/.agents/skills/  canonical skills dir (contents managed by `npx skills`)
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/seanpham99/dotfiles/main/agents/install.sh)
#   bash agents/install.sh                       # from a clone
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log() { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
ok()  { echo -e "${GREEN}${BOLD}[ OK ]${RESET}  $*"; }

REPO_RAW="https://raw.githubusercontent.com/seanpham99/dotfiles/main/agents"
FILES=(hooks/readonly-shell.sh)

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
if [[ -z "$SRC" || ! -f "$SRC/hooks/readonly-shell.sh" ]]; then
  SRC="$(mktemp -d)"; trap 'rm -rf "$SRC"' EXIT
  log "Downloading shared agent hooks from repo..."
  for f in "${FILES[@]}"; do
    mkdir -p "$SRC/$(dirname "$f")"
    curl -fsSL "$REPO_RAW/$f" -o "$SRC/$f"
  done
fi

DEST="$HOME/.agents"
BACKUP="$DEST/backups/dotfiles-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$DEST/hooks" "$DEST/skills"
for f in $(cd "$SRC" && ls hooks/*.sh); do
  if [[ -e "$DEST/$f" ]]; then mkdir -p "$BACKUP/hooks"; cp -a "$DEST/$f" "$BACKUP/$f"; fi
  install -m 755 "$SRC/$f" "$DEST/$f"
done
ok "Shared hooks installed to ~/.agents/hooks."
[[ -d "$BACKUP" ]] && log "Previous hooks backed up to $BACKUP"
exit 0
