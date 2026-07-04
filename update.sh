#!/usr/bin/env bash
# =============================================================================
# Dotfiles Updater — pull the latest .zshrc & .p10k.zsh from the repo
# =============================================================================

set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
ok()   { echo -e "${GREEN}${BOLD}[ OK ]${RESET}  $*"; }
warn() { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }

REPO_RAW="https://raw.githubusercontent.com/seanpham99/dotfiles/main"

log "Updating .zshrc..."
BACKUP="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
cp "$HOME/.zshrc" "$BACKUP"
warn "Old .zshrc backed up → $BACKUP"
curl -fsSL "${REPO_RAW}/.zshrc" -o "$HOME/.zshrc"
ok ".zshrc updated."

log "Updating .p10k.zsh..."
curl -fsSL "${REPO_RAW}/.p10k.zsh" -o "$HOME/.p10k.zsh"
ok ".p10k.zsh updated."

log "Pulling latest plugin updates..."
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
git -C "$ZSH_CUSTOM/themes/powerlevel10k"          pull --ff-only --quiet && ok "powerlevel10k updated."
git -C "$ZSH_CUSTOM/plugins/zsh-autosuggestions"   pull --ff-only --quiet && ok "zsh-autosuggestions updated."
git -C "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" pull --ff-only --quiet && ok "zsh-syntax-highlighting updated."

echo ""
echo -e "${GREEN}${BOLD}All done! Run: ${CYAN}exec zsh${GREEN} to apply changes.${RESET}"
