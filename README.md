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
| **Claude Code + config** | Claude Code, agentmemory hooks, and the `claude/` config below — optional, default off (`--with-claude`) |

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
| `claude/install.sh` | Claude Code config installer (runs standalone too) |
| `claude/CLAUDE.md` | Global agent instructions → `~/.claude/CLAUDE.md` |
| `claude/settings.json` | Global settings → `~/.claude/settings.json` (placeholders filled at install) |
| `claude/agents/` | Global subagents → `~/.claude/agents/` |

## Claude Code config

Model roles: `opusplan` main (Opus plans, Sonnet executes), Opus advisor, Sonnet subagents, Haiku `Explore`.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/seanpham99/dotfiles/main/claude/install.sh)
AGENTMEMORY_URL=http://<host>:3111 bash claude/install.sh   # point at your agentmemory server
```

- Existing files are backed up to `~/.claude/backups/dotfiles-<timestamp>/`.
- `settings.json` holds no secrets: export `AGENTMEMORY_SECRET` in your shell. `__AGENTMEMORY_PLUGIN_DIR__` and `__AGENTMEMORY_URL__` are filled at install (default URL `http://localhost:3111`).
- Skills live in `~/.agents/skills/` (managed by `npx skills`); the installer symlinks each into `~/.claude/skills/`. Skill contents are not in this repo.
- To capture changes from a live machine, copy `~/.claude/{CLAUDE.md,agents/*}` back here and re-template `settings.json`.

## macOS (lightweight variant)

A slimmed-down setup for macOS — no Powerlevel10k, no Nerd Font, lazy-loaded
nvm. Target: **~200ms** interactive startup.

| Difference | Why |
|---|---|
| `robbyrussell` theme | No Nerd Font dependency, no instant-prompt hack |
| Lazy `nvm` | `nvm`/`node`/`npm`/`npx` load nvm on first call — saves ~300–600ms per shell |
| `macos` OMZ plugin | Built-in helpers (`ofd`, `tab`, `pfs`, `quick-look`) at ~zero cost |
| OMZ auto-update disabled | No update-check delay on shell start |

**Package manager:** prefers Homebrew when present; falls back to macOS system
tools + official curl installers (uv, Docker DMG) when brew is unavailable or
admin rights are missing.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/seanpham99/dotfiles/main/install-macos.sh)
```

Flags: `--with-docker` (Docker Desktop, opt-in), `--with-ai-agents`, `--no-uv`,
`INTERACTIVE=0` for scripted runs.

| File | Purpose |
|---|---|
| `install-macos.sh` | macOS installer (brew optional) |
| `.zshrc.macos` | Lightweight zsh config |
