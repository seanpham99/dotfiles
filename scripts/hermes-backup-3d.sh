#!/usr/bin/env bash
# Wrapper: full Hermes backup every 3 days (cron, no_agent — script only, no LLM)
export PATH="$HOME/bin:$PATH"
$HOME/.hermes/scripts/hermes-backup.sh weekly
rc=$?
echo "hermes-backup-3day rc=$rc $(date -u '+%Y-%m-%dT%H:%M:%SZ') log=~/.hermes/logs/hermes-backup.log"
exit $rc
