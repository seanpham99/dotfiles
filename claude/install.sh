#!/usr/bin/env bash
# =============================================================================
# Claude Code config installer — global CLAUDE.md, settings.json, agents, and
# the ~/.agents/skills -> ~/.claude/skills symlink layout.
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/seanpham99/dotfiles/main/claude/install.sh)
#   bash claude/install.sh                       # from a clone
#   AGENTMEMORY_URL=http://host:3111 bash claude/install.sh
#
# Existing files are backed up to ~/.claude/backups/dotfiles-<timestamp>/.
# The agentmemory secret is never stored here: settings.json reads
# ${AGENTMEMORY_SECRET} from your environment.
# =============================================================================

set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
BOLD='\033[1m'; RESET='\033[0m'
log()  { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
ok()   { echo -e "${GREEN}${BOLD}[ OK ]${RESET}  $*"; }
warn() { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
die()  { echo -e "${RED}${BOLD}[FAIL]${RESET}  $*" >&2; exit 1; }

REPO_RAW="https://raw.githubusercontent.com/seanpham99/dotfiles/main/claude"
FILES=(CLAUDE.md settings.json agents/Explore.md)
AGENTMEMORY_URL="${AGENTMEMORY_URL:-http://localhost:3111}"

command -v jq >/dev/null || die "jq is required (sudo apt-get install -y jq)."

# ── source: the clone this script sits in, else download ────────────────────
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
if [[ -z "$SRC" || ! -f "$SRC/settings.json" ]]; then
  SRC="$(mktemp -d)"; trap 'rm -rf "$SRC"' EXIT
  log "Downloading Claude config from repo..."
  for f in "${FILES[@]}"; do
    mkdir -p "$SRC/$(dirname "$f")"
    curl -fsSL "$REPO_RAW/$f" -o "$SRC/$f"
  done
fi

CLAUDE="$HOME/.claude"
BACKUP="$CLAUDE/backups/dotfiles-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$CLAUDE/agents"

backup() {
  if [[ -e "$1" ]]; then
    mkdir -p "$BACKUP/$(dirname "${1#"$CLAUDE"/}")"
    cp -a "$1" "$BACKUP/${1#"$CLAUDE"/}"
  fi
}

# ── 1. CLAUDE.md + agents ───────────────────────────────────────────────────
for f in CLAUDE.md agents/*.md; do
  [[ -e "$SRC/$f" ]] || continue
  backup "$CLAUDE/$f"
  install -m 644 "$SRC/$f" "$CLAUDE/$f"
done
# codebase-discoverer is folded into Explore (Bash + output rules)
backup "$CLAUDE/agents/codebase-discoverer.md"
rm -f "$CLAUDE/agents/codebase-discoverer.md"
ok "CLAUDE.md and agents installed."

# ── 2. settings.json (fill machine-specific placeholders) ───────────────────
PLUGIN_DIR=""
if command -v npm >/dev/null; then
  PLUGIN_DIR="$(npm root -g 2>/dev/null)/@agentmemory/agentmemory/plugin"
fi
if [[ -z "$PLUGIN_DIR" || ! -d "$PLUGIN_DIR/scripts" ]]; then
  warn "agentmemory plugin not found; its hooks will fail until you run: npm i -g @agentmemory/agentmemory"
  PLUGIN_DIR="${PLUGIN_DIR:-$HOME/.npm-global/lib/node_modules/@agentmemory/agentmemory/plugin}"
fi
backup "$CLAUDE/settings.json"
jq --arg p "$PLUGIN_DIR" --arg u "$AGENTMEMORY_URL" \
  'walk(if type=="string" then (gsub("__AGENTMEMORY_PLUGIN_DIR__"; $p) | gsub("__AGENTMEMORY_URL__"; $u)) else . end)' \
  "$SRC/settings.json" > "$CLAUDE/settings.json.tmp"
mv "$CLAUDE/settings.json.tmp" "$CLAUDE/settings.json"
ok "settings.json installed (agentmemory at $AGENTMEMORY_URL)."
[[ -n "${AGENTMEMORY_SECRET:-}" ]] || warn "AGENTMEMORY_SECRET is not set; export it in ~/.zshenv for the agentmemory MCP server."

# ── 3. skills: ~/.agents/skills is canonical, ~/.claude/skills links into it ─
mkdir -p "$HOME/.agents/skills" "$CLAUDE/skills"
linked=0
for d in "$HOME/.agents/skills"/*/; do
  [[ -d "$d" ]] || continue
  n="$(basename "$d")"
  t="$CLAUDE/skills/$n"
  if [[ -e "$t" && ! -L "$t" ]]; then
    warn "skills/$n is a real directory; left as is."
    continue
  fi
  ln -sfn "../../.agents/skills/$n" "$t"
  linked=$((linked+1))
done
find "$CLAUDE/skills" -maxdepth 1 -xtype l -delete
ok "Linked $linked skills from ~/.agents/skills."

[[ -d "$BACKUP" ]] && log "Previous files backed up to $BACKUP"
echo ""
echo -e "${GREEN}${BOLD}Claude Code config installed. Start a new claude session to load it.${RESET}"
