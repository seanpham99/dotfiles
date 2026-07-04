#!/usr/bin/env bash
# =============================================================================
# Oh My Zsh + Powerlevel10k Installer
# Installs the exact zsh setup from seanpham99's machine on a fresh Ubuntu box.
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

# ── 1. System packages ───────────────────────────────────────────────────────
log "Updating apt & installing zsh, git, curl, fonts-powerline..."
sudo apt-get update -qq
sudo apt-get install -y -qq zsh git curl wget fontconfig unzip
ok "System packages installed."

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
  # Add to /etc/shells if missing
  grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
  chsh -s "$ZSH_PATH"
  ok "Default shell changed to zsh (takes effect on next login)."
else
  ok "zsh is already the default shell."
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
