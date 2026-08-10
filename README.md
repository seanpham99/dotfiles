# dotfiles

My personal **zsh + Oh My Zsh + Powerlevel10k** configuration, packaged as a
one-command installer for fresh Ubuntu machines.

## What gets installed

| Component | Details |
|---|---|
| **zsh** | via `apt` |
| **Oh My Zsh** | latest from official installer |
| **Powerlevel10k** | theme with saved config (`.p10k.zsh`) |
| **zsh-autosuggestions** | fish-like suggestions |
| **zsh-syntax-highlighting** | syntax colouring as you type |
| **MesloLGS NF** | Nerd Font required by Powerlevel10k |
| **Global secret-scan git hook** | Tier 1 blocks `.env`/`config.yaml` in every repo; Tier 2 opt-in content scan (`git config secretguard.full 1`) |
| **Node.js LTS + npm** | via nvm |
| **uv/uvx** | Python package manager (PEP 668) — optional, default on |
| **Docker Engine + compose** | optional, default on |
| **AI/dev agents** | tokless, codegraph, opencode (npm globals) — optional, default off |

> **Ubuntu only.** Do **not** run as root.
>
> **Side effects:** this installer replaces `~/.zshrc`, changes your login shell to `zsh`, installs Docker (if selected), and sets a global Git hook via `core.hooksPath`. Review the [install script](install.sh) before running.

## Quick install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/seanpham99/dotfiles/main/install.sh)
```

## Post-install steps

1. Set your terminal font to **MesloLGS NF**
2. Log out / log back in (or run `exec zsh`)
3. If the prompt looks off, run `p10k configure`

## Files

| File | Purpose |
|---|---|
| `install.sh` | One-shot installer script |
| `.zshrc` | Main zsh config |
| `.p10k.zsh` | Powerlevel10k prompt config |
| `update.sh` | Pull latest configs & plugin updates |
| `scripts/install-git-hooks.sh` | Global secret-scan hook installer |
