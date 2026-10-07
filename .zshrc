# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# p10k's async worker needs a tty: worker.zsh does `setopt monitor || return`
# and zsh refuses that option without a controlling terminal, printing
# "gitstatus failed to initialize". Non-tty interactive shells (agent/CI
# background commands) get the OMZ plugins without the theme instead.
[[ -t 0 ]] && {
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi
}

# Locale — SSH clients may send LC_CTYPE=UTF-8 (macOS form), invalid on Linux.
# Set early: brew shellenv calls manpath, which warns on a broken locale.
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Homebrew (linuxbrew) — set before OMZ so fpath stays consistent across subshells
if [[ -d /home/linuxbrew/.linuxbrew ]]; then
  export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
  export HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
  export HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"
  path=(/home/linuxbrew/.linuxbrew/bin /home/linuxbrew/.linuxbrew/sbin $path)
  fpath=(/home/linuxbrew/.linuxbrew/share/zsh/site-functions $fpath)
fi

# Skip completion audit check
ZSH_DISABLE_COMPFIX="true"

# Prevent virtualenv activation from modifying PS1 (p10k handles prompt display)
export VIRTUAL_ENV_DISABLE_PROMPT=1

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

[[ -t 0 ]] && ZSH_THEME="powerlevel10k/powerlevel10k" || ZSH_THEME=""

plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

# User configuration

# auto suggest
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8,standout"

# nvm — lazy-load (saves ~300-600ms per shell)
export NVM_DIR="$HOME/.nvm"
nvm() {
  unset -f nvm node npm npx 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm "$@"
}
node() { nvm >/dev/null; node "$@"; }
npm()  { nvm >/dev/null; npm "$@"; }
npx()  { nvm >/dev/null; npx "$@"; }

#-------- Global Alias {{{
globalias() {
  if [[ $LBUFFER =~ '[a-zA-Z0-9]+$' ]]; then
    zle _expand_alias
    zle expand-word
  fi
  zle self-insert
}
zle -N globalias
bindkey " " globalias                 # space key to expand globalalias
# bindkey "^ " magic-space            # control-space to bypass completion
bindkey "^[[Z" magic-space            # shift-tab to bypass completion
bindkey -M isearch " " magic-space    # normal space during searches
[[ -s ~/.zsh_aliases ]] && . ~/.zsh_aliases
#}}}

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Auto-activate local .venv on cd / terminal open
_auto_venv() {
  local target=""
  if [[ -f "$PWD/server/.venv/bin/activate" ]]; then
    target="$PWD/server/.venv"
  elif [[ -f "$PWD/.venv/bin/activate" ]]; then
    target="$PWD/.venv"
  fi

  if [[ -n "$target" && "$VIRTUAL_ENV" != "$target" ]]; then
    source "$target/bin/activate"
  elif [[ -z "$target" && -n "$VIRTUAL_ENV" ]]; then
    deactivate 2>/dev/null
  fi
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _auto_venv
_auto_venv


# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"

# >>> tokless path >>>
# Adds tokless tool bin dirs to PATH (rtk, bun, cargo).
for d in "$HOME/.local/bin" "$HOME/.bun/bin" "$HOME/.cargo/bin"; do
  [ -d "$d" ] && case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
done
export PATH
# <<< tokless path <<<

# >>> zeroclaw >>>
export PATH="$HOME/.cargo/bin:$PATH"
# <<< zeroclaw <<<

# >>> headroom persistent env >>>
export HEADROOM_LOSSLESS="1"
export HEADROOM_PORT="8787"
export HEADROOM_HOST="127.0.0.1"
export HEADROOM_MODE="token"
export HEADROOM_BACKEND="anthropic"
export HEADROOM_TELEMETRY="off"
export ANTHROPIC_BASE_URL="http://127.0.0.1:8787"
export ENABLE_TOOL_SEARCH="true"
export OPENAI_BASE_URL="http://127.0.0.1:8787/v1"
export COPILOT_PROVIDER_TYPE="anthropic"
export COPILOT_PROVIDER_BASE_URL="http://127.0.0.1:8787"
# <<< headroom persistent env <<<

# opencode
export PATH="$HOME/.opencode/bin:$PATH"
