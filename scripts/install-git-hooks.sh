#!/usr/bin/env bash
# =============================================================================
# Secret-scan global git hook installer — two-tier protection for EVERY repo.
#
#   Tier 1 (always on): path guard — blocks committing .env / config.yaml
#                       at ANY depth. Near-zero false positives. This is the
#                       real leak vector (copying a live config into a repo).
#   Tier 2 (opt-in):    content scan — real token patterns in staged files.
#                       Enabled per-repo via  git config secretguard.full 1
#                       (or a `.secret-guard` marker file at repo root).
#
# Installs a shared hook into ~/.hermes/git-hooks/ and points
# `git config --global core.hooksPath` at it. Every repo on this machine
# inherits the path guard; sensitive repos opt into the content scan.
#
# Usage:
#   bash scripts/install-git-hooks.sh            # install (idempotent)
#   bash scripts/install-git-hooks.sh --uninstall
#   git config secretguard.full 1                # opt a repo into Tier 2
#
# =============================================================================
set -euo pipefail

HOOKS_DIR="$HOME/.hermes/git-hooks"
HOOK_FILE="$HOOKS_DIR/pre-commit"

# ── colours (dotfiles convention) ───────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log()  { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
ok()   { echo -e "${GREEN}${BOLD}[ OK ]${RESET}  $*"; }
warn() { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
die()  { echo -e "${RED}${BOLD}[FAIL]${RESET}  $*" >&2; exit 1; }

# ── uninstall ───────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--uninstall" ]]; then
  git config --global --unset core.hooksPath 2>/dev/null || true
  rm -rf "$HOOKS_DIR"
  ok "Removed global hook ($HOOKS_DIR) and unset core.hooksPath."
  echo "   Existing repos keep their local .git/hooks (if any) untouched."
  exit 0
fi

# ── the hook body ───────────────────────────────────────────────────────────
# Written as a heredoc with a QUOTED delimiter so the body can contain
# literal single quotes (git config secretguard.full 1 etc.) without
# breaking the outer script. ${VAR} is escaped as \${VAR} so bash does NOT
# expand it at install time — the installed hook expands it at commit time.
HOOK_BODY=$(cat <<'HOOK_EOF'
#!/usr/bin/env bash
# Secret-scan pre-commit hook (global, via core.hooksPath).
# Tier 1 (always):  block .env / config.yaml at any depth — near-zero FP.
# Tier 2 (opt-in):  content scan for real credential patterns.
#   Enable per-repo:  git config secretguard.full 1
set -euo pipefail

# ── Tier 1: path guard (always on) ─────────────────────────────────────────
STAGED="$(git diff --cached --name-only)"
BLOCKED="$(printf "%s\n" "$STAGED" | grep -E "(^|/)(config\.ya?ml|config/[^/]*\.ya?ml|\.env)$" || true)"
if [[ -n "$BLOCKED" ]]; then
  echo "❌ SECRET GUARD: blocked commit of live config/env files:"
  echo "$BLOCKED"
  echo "   Config/env files must never be committed. Use a template with"
  echo "   \${VAR} references, or a .env.example (no secrets)."
  echo "   Fix: git reset HEAD <file>  and  remove the file from the index."
  exit 1
fi

# ── Tier 2: content scan (opt-in) ──────────────────────────────────────────
if [[ "$(git config --get secretguard.full 2>/dev/null)" != "1" ]] && \
   [[ ! -f "$(git rev-parse --show-toplevel 2>/dev/null)/.secret-guard" ]]; then
  exit 0   # Tier 2 not enabled for this repo
fi

PATTERNS=(
  "ghp_[A-Za-z0-9]{20,}"
  "gho_[A-Za-z0-9]{20,}"
  "github_pat_[A-Za-z0-9_]{20,}"
  "xox[bpo]-[A-Za-z0-9-]{10,}"
  "ATATT3[A-Za-z0-9]"
  "ctx7sk-[A-Za-z0-9-]{10,}"
  "tvly-[A-Za-z0-9-]{10,}"
  "figd_[A-Za-z0-9]{10,}"
  "AKIA[0-9A-Z]{16}"
  "sk-[A-Za-z0-9]{20,}"
)

# Files allowed to contain redacted doc examples / template refs.
ALLOWED_PATH_REGEX="(^|/)(docs?|tests?|examples?|scripts?)/|README[^/]*$|\.md$|\.example$|\.template$"

FAIL=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if [[ "$f" =~ $ALLOWED_PATH_REGEX ]]; then continue; fi
  if [[ ! -f "$f" ]]; then continue; fi
  for pat in "${PATTERNS[@]}"; do
    if grep -E "$pat" "$f" >/dev/null 2>&1; then
      echo "❌ SECRET GUARD: possible credential in staged file: $f"
      grep -nE "$pat" "$f" | head -3 | sed "s/^/    /"
      FAIL=1
    fi
  done
done <<< "$STAGED"

if [[ "$FAIL" != "0" ]]; then
  echo "   Refusing to commit. Remove/redact the secret, or disable the"
  echo "   content scan for this repo:  git config secretguard.full 0"
  echo "   (Tier 1 path guard stays on — .env/config.yaml still blocked.)"
  exit 1
fi
exit 0
HOOK_EOF
)

# ── install ─────────────────────────────────────────────────────────────────
mkdir -p "$HOOKS_DIR"
cat > "$HOOK_FILE" <<EOF
$HOOK_BODY
EOF
chmod +x "$HOOK_FILE"

git config --global core.hooksPath "$HOOKS_DIR"

ok "Global secret-scan hook installed:"
echo "   $HOOK_FILE"
echo "   core.hooksPath = $(git config --global core.hooksPath)"
echo ""
echo "Tier 1 (path guard) active for EVERY repo on this machine."
echo "Tier 2 (content scan): opt in per repo with:"
echo "   git config secretguard.full 1"
echo "   # or: touch .secret-guard   (at repo root)"
echo ""
echo "Escalation hatch (any repo): git commit --no-verify"
echo ""
echo "Test:  bash $HOOK_FILE   (no staged changes → exits 0)"
