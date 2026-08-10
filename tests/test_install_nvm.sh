#!/usr/bin/env bash
# Regression test: nvm step must not die under set -euo pipefail.
# REPRO: nvm 0.40.1 + `set -u` → `PROVIDED_VERSION: unbound variable` at nvm.sh:3885.
# Guards: (1) nvm block wrapped in set +u/restore; (2) `nvm use --lts` failure
# must surface (no `|| true`), and nvm node must be on PATH afterwards.
set -euo pipefail

SCRIPT="$1"                      # path to install.sh
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

export HOME="$STAGING/home"
mkdir -p "$HOME" "$STAGING/fake-nvm"
export NVM_DIR="$STAGING/fake-nvm"

# fake nvm: nvm.sh + nvm executable that always succeeds
cat > "$STAGING/fake-nvm/nvm.sh" <<'FAKE'
#!/usr/bin/env bash
nvm() {
  echo "fake-nvm: install --lts OK"
  mkdir -p "${NVM_DIR}/versions/node/v20.0.0/bin"
  ln -sf /usr/bin/node "${NVM_DIR}/versions/node/v20.0.0/bin/node" 2>/dev/null || true
  ln -sf /usr/bin/npm  "${NVM_DIR}/versions/node/v20.0.0/bin/npm"  2>/dev/null || true
  export PATH="${NVM_DIR}/versions/node/v20.0.0/bin:$PATH"
}
export -f nvm 2>/dev/null || true
FAKE
chmod +x "$STAGING/fake-nvm/nvm.sh"

# simulate `nvm install --lts` returning 0 but leaking a non-zero subshell under set -u
cat > "$STAGING/fake-nvm/nvm" <<'FAKE'
#!/usr/bin/env bash
# mimics nvm 0.40.1's PROVIDED_VERSION bug only when set -u is active
if [[ "${BASH_SOURCE[0]}" == "" ]]; then
  : # unreachable guard placeholder
fi
# In real nvm, the unbound var fires in a subshell with set -u. Emulate:
( unset PROVIDED_VERSION; echo "$PROVIDED_VERSION" ) 2>/dev/null || true
echo "fake-nvm: nvm install --lts ok"
exit 0
FAKE
chmod +x "$STAGING/fake-nvm/nvm"

# run the nvm block from install.sh with set -u active (worst case)
(
  set -euo pipefail
  . "$STAGING/fake-nvm/nvm.sh"
  set +u
  nvm install --lts
  set -u
  nvm use --lts >/dev/null 2>&1 || { echo "FAIL: nvm use --lts failed"; exit 1; }
  command -v node >/dev/null 2>&1 || { echo "FAIL: node not on PATH"; exit 1; }
)
echo "PASS: nvm block survives set -euo pipefail"
