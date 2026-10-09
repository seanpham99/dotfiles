#!/usr/bin/env bash
# =============================================================================
# omp (oh-my-pi) config installer — the repo-guards extension and the scout /
# advisor agent overrides. Installs the shared ~/.agents layer first, because
# repo-guards runs those hook scripts.
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/seanpham99/dotfiles/main/omp/install.sh)
#   bash omp/install.sh                          # from a clone
#
# Model roles, MCP servers and auth stay machine-local (config.yml, mcp.json).
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log() { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
ok()  { echo -e "${GREEN}${BOLD}[ OK ]${RESET}  $*"; }

ROOT_RAW="https://raw.githubusercontent.com/seanpham99/dotfiles/main"
FILES=(extensions/repo-guards.ts agents/scout.md agents/advisor.md)

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
if [[ -n "$SRC" && -f "$SRC/extensions/repo-guards.ts" ]]; then
  bash "$SRC/../agents/install.sh"
else
  bash <(curl -fsSL "$ROOT_RAW/agents/install.sh")
  SRC="$(mktemp -d)"; trap 'rm -rf "$SRC"' EXIT
  log "Downloading omp config from repo..."
  for f in "${FILES[@]}"; do
    mkdir -p "$SRC/$(dirname "$f")"
    curl -fsSL "$ROOT_RAW/omp/$f" -o "$SRC/$f"
  done
fi

DEST="$HOME/.omp/agent"
BACKUP="$DEST/backups/dotfiles-$(date +%Y%m%d_%H%M%S)"
for f in "${FILES[@]}"; do
  mkdir -p "$DEST/$(dirname "$f")"
  if [[ -e "$DEST/$f" ]]; then mkdir -p "$BACKUP/$(dirname "$f")"; cp -a "$DEST/$f" "$BACKUP/$f"; fi
  install -m 644 "$SRC/$f" "$DEST/$f"
done
ok "omp repo-guards extension and agent overrides installed."
[[ -d "$BACKUP" ]] && log "Previous files backed up to $BACKUP"
exit 0
