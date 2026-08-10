#!/usr/bin/env bash
# =============================================================================
# Oh My Zsh + Powerlevel10k Setup Installer
# Installs the exact dev setup from seanpham99's machine on a fresh Ubuntu box.
#
#   Mandatory: Shell/OS → Core tooling (apt) → Runtimes → configs
#   Optional:  Docker, uv, AI/dev agents (npm globals)
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/seanpham99/dotfiles/main/install.sh)
#   INTERACTIVE=0 bash install.sh                # non-interactive (flags only)
#   bash install.sh --with-ai-agents --no-docker # scripted, no prompts
# =============================================================================

set -euo pipefail

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
ok()   { echo -e "${GREEN}${BOLD}[ OK ]${RESET}  $*"; }
warn() { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
die()  { echo -e "${RED}${BOLD}[FAIL]${RESET}  $*" >&2; exit 1; }

# ── guard: Ubuntu only ───────────────────────────────────────────────────────
if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
  die "This installer is designed for Ubuntu only."
fi

# ── guard: not root ──────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] || die "Do NOT run this script as root. Run as your normal user."

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   Oh My Zsh + Powerlevel10k Setup Installer  ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${RESET}"
echo ""

REPO_RAW="https://raw.githubusercontent.com/seanpham99/dotfiles/main"

# ── options state ────────────────────────────────────────────────────────────
INSTALL_DOCKER=1
INSTALL_UV=1
INSTALL_AI_AGENTS=0

# ── flags (scripted runs) ────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-ai-agents) INSTALL_AI_AGENTS=1 ;;
    --no-docker)      INSTALL_DOCKER=0 ;;
    --no-uv)          INSTALL_UV=0 ;;
    --help|-h)
      echo "Usage: install.sh [OPTIONS]"
      echo "  --with-ai-agents  install AI/dev agents (tokless, codegraph, opencode)"
      echo "  --no-docker       skip Docker Engine install"
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
  echo -e "  ${CYAN}Mandatory:${RESET}"
  echo "    [1] apt: zsh, git, curl, wget, zip, unzip, fontconfig"
  echo "    [2] MesloLGS Nerd Fonts (required by Powerlevel10k)"
  echo "    [3] Oh My Zsh + Powerlevel10k theme + plugins"
  echo "    [4] .zshrc / .p10k.zsh / .zsh_aliases (existing .zshrc backed up)"
  echo "    [5] zsh as your default shell"
  echo "    [6] Node.js LTS + npm via nvm"
  echo "    [7] global secret-scan git hook"
  echo ""
  echo -e "  ${YELLOW}Optional:${RESET}"
  echo "    [A] Docker Engine + compose plugin"
  echo "    [B] uv/uvx (Python package manager, PEP 668)"
  echo "    [C] AI/dev agents: tokless, codegraph, opencode (npm globals)"
  echo ""
  read -rp "    Install Docker? [Y/n] " ans;    [[ "${ans,,}" == "n" ]] && INSTALL_DOCKER=0 || INSTALL_DOCKER=1
  read -rp "    Install uv/uvx? [Y/n] " ans;    [[ "${ans,,}" == "n" ]] && INSTALL_UV=0 || INSTALL_UV=1
  read -rp "    Install AI/dev agents? [y/N] " ans; [[ "${ans,,}" == "y" ]] && INSTALL_AI_AGENTS=1 || INSTALL_AI_AGENTS=0
  echo ""
  read -rp "  Start installation? [Y/n] " ans
  [[ "${ans,,}" == "n" ]] && die "Aborted by user."
  echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════
#  MANDATORY
# ═══════════════════════════════════════════════════════════════════════════

# ── 1. Core tooling (apt) ───────────────────────────────────────────────────
log "Updating apt & installing zsh, git, curl, wget, zip, unzip, fontconfig..."
sudo apt-get update -qq
sudo apt-get install -y -qq zsh git curl wget zip unzip fontconfig
ok "Core tooling installed."

# ── 2. Nerd Font (MesloLGS NF – required by Powerlevel10k) ──────────────────
log "Installing MesloLGS Nerd Fonts (required by Powerlevel10k)..."
FONT_DIR="$HOME/.local/share/fonts/MesloLGS"
mkdir -p "$FONT_DIR"

FONTS=(
  "MesloLGS%20NF%20Regular.ttf"
  "MesloLGS%20NF%20Bold.ttf"
  "MesloLGS%20NF%20Italic.ttf"
  "MesloLGS%20NF%20Bold%20Italic.ttf"
)
FONT_BASE="https://github.com/romkatv/powerlevel10k-media/raw/master"
for f in "${FONTS[@]}"; do
  fname="${f//%20/ }"
  if [[ ! -f "$FONT_DIR/$fname" ]]; then
    curl -fsSL "${FONT_BASE}/${f}" -o "$FONT_DIR/$fname"
  fi
done
fc-cache -f "$FONT_DIR"
ok "Nerd Fonts installed."

# ── 3. Oh My Zsh ─────────────────────────────────────────────────────────────
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  warn "Oh My Zsh is already installed – skipping."
else
  log "Installing Oh My Zsh..."
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ok "Oh My Zsh installed."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ── 4. Powerlevel10k theme ───────────────────────────────────────────────────
log "Installing Powerlevel10k theme..."
P10K_DIR="$ZSH_CUSTOM/themes/powerlevel10k"
if [[ -d "$P10K_DIR" ]]; then
  warn "Powerlevel10k already present – pulling latest..."
  git -C "$P10K_DIR" pull --ff-only --quiet
else
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi
ok "Powerlevel10k ready."

# ── 5. zsh-autosuggestions ───────────────────────────────────────────────────
log "Installing zsh-autosuggestions..."
ZSH_AS="$ZSH_CUSTOM/plugins/zsh-autosuggestions"
if [[ -d "$ZSH_AS" ]]; then
  warn "zsh-autosuggestions already present – pulling latest..."
  git -C "$ZSH_AS" pull --ff-only --quiet
else
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AS"
fi
ok "zsh-autosuggestions ready."

# ── 6. zsh-syntax-highlighting ───────────────────────────────────────────────
log "Installing zsh-syntax-highlighting..."
ZSH_SH="$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
if [[ -d "$ZSH_SH" ]]; then
  warn "zsh-syntax-highlighting already present – pulling latest..."
  git -C "$ZSH_SH" pull --ff-only --quiet
else
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_SH"
fi
ok "zsh-syntax-highlighting ready."

# ── 7. Drop configs (.zshrc & .p10k.zsh) ────────────────────────────────────
log "Fetching .zshrc from repo..."
ZSHRC_BACKUP="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
if [[ -f "$HOME/.zshrc" ]]; then
  cp "$HOME/.zshrc" "$ZSHRC_BACKUP"
  warn "Existing .zshrc backed up to $ZSHRC_BACKUP"
fi
curl -fsSL "${REPO_RAW}/.zshrc" -o "$HOME/.zshrc"
ok ".zshrc installed."

log "Fetching .p10k.zsh from repo..."
curl -fsSL "${REPO_RAW}/.p10k.zsh" -o "$HOME/.p10k.zsh"
ok ".p10k.zsh installed."

# ── 8. Create empty .zsh_aliases if missing ──────────────────────────────────
if [[ ! -f "$HOME/.zsh_aliases" ]]; then
  touch "$HOME/.zsh_aliases"
  ok "Created empty ~/.zsh_aliases"
fi

# ── 9. Set zsh as default shell ──────────────────────────────────────────────
ZSH_PATH="$(command -v zsh)"
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
  log "Setting zsh as default shell..."
  grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
  chsh -s "$ZSH_PATH"
  ok "Default shell changed to zsh (takes effect on next login)."
else
  ok "zsh is already the default shell."
fi

# ── 10. Node.js via nvm (LTS) + npm ─────────────────────────────────────────
# ponytail: explicit if/else instead of `set -e` + `> /dev/null` so an nvm
# failure prints WHY and continues/aborts visibly instead of dying silently.
log "Installing Node.js via nvm (LTS)..."
export NVM_DIR="$HOME/.nvm"
if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  log "  Downloading nvm v0.40.1..."
  if ! curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash; then
    die "nvm install failed. Run manually:  curl -fsSL https://nvm.sh | bash"
  fi
fi
# shellcheck disable=SC1091
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

log "  Installing Node LTS (downloads a binary, ~30s)..."
if ! nvm install --lts; then
  warn "nvm install --lts failed, falling back to 'node' alias..."
  nvm install node || die "Node install failed. Check network or run: nvm install --lts"
fi
nvm use --lts >/dev/null 2>&1 || true

# persist for future non-interactive shells
grep -q 'NVM_DIR' "$HOME/.zshrc" || {
  cat >> "$HOME/.zshrc" <<'NVMEOF'

# Node.js via nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
NVMEOF
}
ok "Node $(node --version 2>/dev/null || echo '?') + npm $(npm --version 2>/dev/null || echo '?') via nvm."

# ═══════════════════════════════════════════════════════════════════════════
#  OPTIONAL
# ═══════════════════════════════════════════════════════════════════════════

# ── 11. uv/uvx (Python — PEP 668) ────────────────────────────────────────────
if [[ "$INSTALL_UV" -eq 1 ]]; then
  log "Installing uv/uvx (Python package manager, PEP 668)..."
  if command -v uv >/dev/null 2>&1; then
    ok "uv already installed: $(uv --version)"
  else
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

# ── 12. Install global secret-scan git hook ──────────────────────────────────
log "Installing global secret-scan git hook (Tier 1 path guard for every repo)..."
if curl -fsSL "${REPO_RAW}/scripts/install-git-hooks.sh" -o "$HOME/.hermes/git-hooks-install.sh" 2>/dev/null; then
  bash "$HOME/.hermes/git-hooks-install.sh" 2>&1 | tail -3
  rm -f "$HOME/.hermes/git-hooks-install.sh"
  ok "Global secret-scan hook installed (core.hooksPath)."
else
  warn "Could not fetch install-git-hooks.sh — skipping global hook (not fatal)."
fi

# ── 13. Docker Engine + compose (optional) ───────────────────────────────────
if [[ "$INSTALL_DOCKER" -eq 1 ]]; then
  log "Installing Docker Engine + compose plugin..."
  if command -v docker >/dev/null 2>&1; then
    ok "Docker already installed: $(docker --version)"
  else
    if curl -fsSL https://get.docker.com | sudo bash 2>&1 | tail -3; then
      sudo usermod -aG docker "$USER"
      ok "Docker installed. Re-login for group permissions."
    else
      warn "Docker install failed — continuing (run get.docker.com manually)."
    fi
  fi
else
  log "Skipping Docker."
fi

# ── 14. AI/dev agents (npm globals, optional) ────────────────────────────────
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
echo -e "  1. Set your terminal font to ${CYAN}MesloLGS NF${RESET} (required for Powerlevel10k icons)"
echo -e "  2. Log out and log back in (or run ${CYAN}exec zsh${RESET}) to start using zsh"
echo -e "  3. If the prompt looks off, run ${CYAN}p10k configure${RESET}"
echo ""
