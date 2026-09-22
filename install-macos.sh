#!/usr/bin/env bash
# =============================================================================
# Oh My Zsh (lightweight) Setup Installer — macOS
# Installs the optimized zsh setup: robbyrussell theme, lazy nvm, no p10k.
#
#   Mandatory: core tooling (brew if present, else system) → Oh My Zsh →
#              plugins → .zshrc → nvm (lazy)
#   Optional:  uv, Docker Desktop, AI/dev agents (npm globals)
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/seanpham99/dotfiles/main/install-macos.sh)
#   INTERACTIVE=0 bash install-macos.sh                # non-interactive
#   bash install-macos.sh --with-ai-agents --no-uv     # scripted, no prompts
# =============================================================================

set -euo pipefail

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
ok()   { echo -e "${GREEN}${BOLD}[ OK ]${RESET}  $*"; }
warn() { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
die()  { echo -e "${RED}${BOLD}[FAIL]${RESET}  $*" >&2; exit 1; }

# ── guard: macOS only ────────────────────────────────────────────────────────
[[ "$(uname -s)" == "Darwin" ]] || die "This installer is designed for macOS only."

# ── guard: not root ──────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] || die "Do NOT run this script as root. Run as your normal user."

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║  Oh My Zsh (lightweight) Installer — macOS   ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${RESET}"
echo ""

REPO_RAW="https://raw.githubusercontent.com/seanpham99/dotfiles/main"

# ── options state ────────────────────────────────────────────────────────────
INSTALL_UV=1
INSTALL_DOCKER=0
INSTALL_AI_AGENTS=0

# ── flags (scripted runs) ────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-ai-agents) INSTALL_AI_AGENTS=1 ;;
    --with-docker)    INSTALL_DOCKER=1 ;;
    --no-uv)          INSTALL_UV=0 ;;
    --help|-h)
      echo "Usage: install-macos.sh [OPTIONS]"
      echo "  --with-ai-agents  install AI/dev agents (tokless, codegraph, opencode)"
      echo "  --with-docker     install Docker Desktop (cask)"
      echo "  --no-uv           skip uv/uvx install"
      echo "  INTERACTIVE=0     skip the TUI, use flags/defaults"
      exit 0 ;;
    *) warn "Unknown flag: $1 (ignored)" ;;
  esac
  shift
done

# ── TUI: show the plan, let the user choose optional software ────────────────
if [[ "${INTERACTIVE:-1}" == "1" ]] && [[ -t 0 ]]; then
  echo -e "${BOLD}This installer will set up:${RESET}"
  echo ""
  echo "    [1] Core tooling: git, curl (via brew if available, else macOS system tools)"
  echo "    [2] Oh My Zsh + zsh-autosuggestions + zsh-syntax-highlighting"
  echo "    [3] .zshrc.macos → ~/.zshrc (existing .zshrc backed up)"
  echo "    [4] zsh as your default shell (macOS default already)"
  echo "    [5] nvm + Node.js LTS (lazy-loaded — zero startup cost)"
  echo "    [6] global secret-scan git hook"
  echo ""
  echo -e "  ${YELLOW}Optional:${RESET}"
  echo "    [A] uv/uvx (Python package manager)"
  echo "    [B] Docker Desktop (cask, heavy)"
  echo "    [C] AI/dev agents: tokless, codegraph, opencode (npm globals)"
  echo ""
  read -rp "    Install uv/uvx? [Y/n] " ans;        [[ "${ans,,}" == "n" ]] && INSTALL_UV=0 || INSTALL_UV=1
  read -rp "    Install Docker Desktop? [y/N] " ans; [[ "${ans,,}" == "y" ]] && INSTALL_DOCKER=1 || INSTALL_DOCKER=0
  read -rp "    Install AI/dev agents? [y/N] " ans;  [[ "${ans,,}" == "y" ]] && INSTALL_AI_AGENTS=1 || INSTALL_AI_AGENTS=0
  echo ""
  read -rp "  Start installation? [Y/n] " ans
  [[ "${ans,,}" == "n" ]] && die "Aborted by user."
  echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════
#  MANDATORY
# ═══════════════════════════════════════════════════════════════════════════

# ── 1. Core tooling ─────────────────────────────────────────────────────────
# Prefer Homebrew when present; fall back to macOS system tools (git/curl/zsh
# ship with macOS + Command Line Tools) when brew is unavailable or can't be
# installed (e.g. no admin rights).
HAVE_BREW=0
if command -v brew >/dev/null 2>&1; then
  HAVE_BREW=1
  ok "Homebrew found: $(brew --version | head -1)"
elif sudo -n true 2>/dev/null; then
  log "Installing Homebrew (passwordless sudo available)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Apple Silicon brew lives in /opt/homebrew; Intel in /usr/local
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  command -v brew >/dev/null 2>&1 && HAVE_BREW=1
else
  warn "Homebrew not installed and no admin rights — using macOS system tools."
fi

if [[ "$HAVE_BREW" -eq 1 ]]; then
  brew list git >/dev/null 2>&1 || brew install git
else
  command -v git  >/dev/null 2>&1 || die "git not found. Install Command Line Tools: xcode-select --install"
  command -v curl >/dev/null 2>&1 || die "curl not found (ships with macOS — something is wrong)."
fi
ok "Core tooling ready (brew=$HAVE_BREW)."

# ── 2. Oh My Zsh ─────────────────────────────────────────────────────────────
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  warn "Oh My Zsh is already installed – skipping."
else
  log "Installing Oh My Zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ok "Oh My Zsh installed."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ── 3. zsh-autosuggestions ───────────────────────────────────────────────────
log "Installing zsh-autosuggestions..."
ZSH_AS="$ZSH_CUSTOM/plugins/zsh-autosuggestions"
if [[ -d "$ZSH_AS" ]]; then
  warn "zsh-autosuggestions already present – pulling latest..."
  git -C "$ZSH_AS" pull --ff-only --quiet
else
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AS"
fi
ok "zsh-autosuggestions ready."

# ── 4. zsh-syntax-highlighting ───────────────────────────────────────────────
log "Installing zsh-syntax-highlighting..."
ZSH_SH="$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
if [[ -d "$ZSH_SH" ]]; then
  warn "zsh-syntax-highlighting already present – pulling latest..."
  git -C "$ZSH_SH" pull --ff-only --quiet
else
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_SH"
fi
ok "zsh-syntax-highlighting ready."

# ── 5. Drop .zshrc.macos → ~/.zshrc ─────────────────────────────────────────
log "Fetching .zshrc.macos from repo..."
ZSHRC_BACKUP="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
if [[ -f "$HOME/.zshrc" ]]; then
  cp "$HOME/.zshrc" "$ZSHRC_BACKUP"
  warn "Existing .zshrc backed up to $ZSHRC_BACKUP"
fi
curl -fsSL "${REPO_RAW}/.zshrc.macos" -o "$HOME/.zshrc"
ok ".zshrc installed (lightweight variant)."

# ── 6. Create empty .zsh_aliases if missing ──────────────────────────────────
if [[ ! -f "$HOME/.zsh_aliases" ]]; then
  touch "$HOME/.zsh_aliases"
  ok "Created empty ~/.zsh_aliases"
fi

# ── 7. zsh as default shell ──────────────────────────────────────────────────
ZSH_PATH="$(command -v zsh)"
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
  log "Setting zsh as default shell..."
  grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
  chsh -s "$ZSH_PATH"
  ok "Default shell changed to zsh (takes effect on next login)."
else
  ok "zsh is already the default shell."
fi

# ── 8. nvm + Node.js LTS (lazy-loaded by .zshrc — zero startup cost) ─────────
log "Installing nvm + Node.js LTS..."
export NVM_DIR="$HOME/.nvm"
if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  log "  Downloading nvm v0.40.1..."
  if ! curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | PROFILE=/dev/null bash; then
    die "nvm install failed. Run manually:  curl -fsSL https://nvm.sh | bash"
  fi
fi
# shellcheck disable=SC1091
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

log "  Installing Node LTS (downloads a binary, ~30s)..."
set +u
if ! nvm install --lts; then
  set -u
  die "nvm install --lts failed. Check network or run: nvm install --lts"
fi
set -u
ok "Node $(node --version 2>/dev/null || echo '?') + npm $(npm --version 2>/dev/null || echo '?') via nvm (lazy-loaded)."

# ── 9. Global secret-scan git hook ───────────────────────────────────────────
log "Installing global secret-scan git hook (Tier 1 path guard for every repo)..."
mkdir -p "$HOME/.hermes"
if curl -fsSL "${REPO_RAW}/scripts/install-git-hooks.sh" -o "$HOME/.hermes/git-hooks-install.sh" 2>/dev/null; then
  bash "$HOME/.hermes/git-hooks-install.sh" 2>&1 | tail -3
  rm -f "$HOME/.hermes/git-hooks-install.sh"
  ok "Global secret-scan hook installed (core.hooksPath)."
else
  warn "Could not fetch install-git-hooks.sh — skipping global hook (not fatal)."
fi

# ═══════════════════════════════════════════════════════════════════════════
#  OPTIONAL
# ═══════════════════════════════════════════════════════════════════════════

# ── 10. uv/uvx (Python) ──────────────────────────────────────────────────────
if [[ "$INSTALL_UV" -eq 1 ]]; then
  log "Installing uv/uvx..."
  if command -v uv >/dev/null 2>&1; then
    ok "uv already installed: $(uv --version)"
  elif [[ "$HAVE_BREW" -eq 1 ]]; then
    brew install uv && ok "uv installed: $(uv --version)" \
      || warn "uv install failed — continuing (brew install uv manually)."
  else
    # no brew: official installer drops uv/uvx into ~/.local/bin (no admin needed)
    if curl -fsSL https://astral.sh/uv/install.sh | bash >/dev/null 2>&1; then
      export PATH="$HOME/.local/bin:$PATH"
      ok "uv installed: $(uv --version 2>/dev/null || echo '?')"
    else
      warn "uv install failed — continuing (run astral.sh/uv/install.sh manually)."
    fi
  fi
else
  log "Skipping uv/uvx."
fi

# ── 11. Docker Desktop (optional, heavy) ─────────────────────────────────────
if [[ "$INSTALL_DOCKER" -eq 1 ]]; then
  log "Installing Docker Desktop..."
  if command -v docker >/dev/null 2>&1 || [[ -d /Applications/Docker.app ]]; then
    ok "Docker already installed."
  elif [[ "$HAVE_BREW" -eq 1 ]]; then
    brew install --cask docker \
      && ok "Docker Desktop installed. Launch it once from /Applications." \
      || warn "Docker install failed — continuing (brew install --cask docker)."
  else
    # no brew: download the official DMG and install to /Applications
    # (requires admin rights for /Applications; warns and skips otherwise)
    ARCH="$(uname -m)"; [[ "$ARCH" == "arm64" ]] && DMG_ARCH=arm64 || DMG_ARCH=intel
    DMG_URL="https://desktop.docker.com/mac/main/${DMG_ARCH}/Docker.dmg"
    log "  Downloading Docker Desktop DMG (${DMG_ARCH})..."
    if curl -fsSL "$DMG_URL" -o /tmp/Docker.dmg \
      && hdiutil attach -nobrowse -quiet /tmp/Docker.dmg \
      && cp -R "/Volumes/Docker/Docker.app" /Applications/ 2>/dev/null; then
      hdiutil detach -quiet "/Volumes/Docker" 2>/dev/null || true
      rm -f /tmp/Docker.dmg
      ok "Docker Desktop installed. Launch it once from /Applications."
    else
      hdiutil detach -quiet "/Volumes/Docker" 2>/dev/null || true
      rm -f /tmp/Docker.dmg
      warn "Docker install failed (needs admin rights for /Applications) — download manually from docker.com."
    fi
  fi
else
  log "Skipping Docker Desktop."
fi

# ── 12. AI/dev agents (npm globals, optional) ────────────────────────────────
if [[ "$INSTALL_AI_AGENTS" -eq 1 ]]; then
  log "Installing AI/dev agents (npm globals)..."
  export NVM_DIR="$HOME/.nvm"
  [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
  command -v npm >/dev/null 2>&1 || die "npm not found — Node install failed earlier."

  log "  → tokless"
  if curl -fsSL "https://raw.githubusercontent.com/HoangP8/tokless/main/scripts/install.sh" | bash 2>&1 | tail -2; then
    ok "  tokless installed."
  else
    warn "  tokless install failed — continuing."
  fi

  log "  → codegraph"
  if npm install -g @colbymchenry/codegraph >/dev/null 2>&1; then
    ok "  codegraph installed."
  else
    warn "  codegraph install failed — continuing."
  fi

  log "  → opencode"
  if curl -fsSL https://opencode.ai/install | bash >/dev/null 2>&1; then
    ok "  opencode installed."
  else
    warn "  opencode install failed — continuing."
  fi
else
  log "Skipping AI/dev agents (toggle C in the TUI, or --with-ai-agents)."
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  Installation complete! 🎉${RESET}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${BOLD}Next steps:${RESET}"
echo -e "  1. Open a new terminal tab (or run ${CYAN}exec zsh${RESET})"
echo -e "  2. Measure startup: ${CYAN}time zsh -i -c exit${RESET} — expect ~200ms"
echo -e "  3. No Nerd Font needed — robbyrussell uses plain glyphs"
echo ""
