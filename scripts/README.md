# Hermes Backup & Restore Scripts

Automated backup of Hermes agent state + 9Router settings → local dir → encrypted R2, with a restore script for disaster recovery.

## Files

| Script | Purpose |
|---|---|
| `hermes-backup.sh` | Daily (quick snapshot + state bundle + 9router) + weekly (full curated zip) → local + R2 |
| `hermes-restore.sh` | Restore Hermes + 9Router from local backups or pull from R2 |

## Requirements

- `hermes` CLI (Hermes Agent)
- `rclone` configured with:
  - S3 remote pointing at Cloudflare R2 (`r2-storage`, `no_check_bucket=true`)
  - Crypt remote over it for encryption at rest (`r2-crypt`)
- R2 credentials:
  - `R2_ACCESS_KEY_ID` + `R2_SECRET_ACCESS_KEY` in `~/.hermes/.env`
  - `R2_ACCOUNT_ID`, `R2_BUCKET_NAME`, `R2_CRYPT_PASSWORD`(+2) in `~/.hermes/backup.env` (0600)

## Backup

```bash
# Daily: quick snapshot + memory/config/cron bundle + 9router zip → R2
hermes-backup.sh daily

# Weekly: full curated zip (state.db, skills, config, sessions, DBs WAL-safe) + 9router → R2
hermes-backup.sh weekly
```

Configuration via env vars: `HERMES_BACKUP_ROOT`, `RCLONE_REMOTE`, `R2_BUCKET_NAME`, `KEEP_FULL`, `KEEP_9R`.

Log: `~/.hermes/logs/hermes-backup.log`

### What's backed up (weekly full)

**Kept** (irreplaceable): `state.db` (conversation history), `memory_store.db` (holographic memory), `skills/` (+`.agents/skills/`), `sessions/`, `profiles/`, `plugins/`, `config.yaml`, `.env`, `auth.json`, `cron/`, `kanban.db`, `projects.db`, `verification_evidence.db`, `pairing/`, `platforms/`, `scripts/`, `docs/`, `hooks/`.

**Skipped** (regenerable): `hermes-agent/` (codebase), `state-snapshots/` (recursive snapshot copies), `artifact/`, `webui/`, `lsp/`, `bin/`, `logs/`, `cache/`, `backups/`, `models_dev_cache.json`.

DBs are snapshotted WAL-safe via `sqlite3.backup()` from source — consistent even while Hermes runs.

## Restore

```bash
hermes-restore.sh list                    # list available backups (local + R2)
hermes-restore.sh latest                  # restore newest local (safe overlay)
hermes-restore.sh <zip-name>              # restore a specific backup
hermes-restore.sh --from-r2 <zip-name>    # pull from R2 first, then restore
hermes-restore.sh --force                 # overwrite existing config/.env/DBs (STOP Hermes first!)
```

Safety: without `--force`, restore never clobbers existing `config.yaml`/`.env`/`auth.json`, and only restores DBs if missing. With `--force` it overlays everything — stop Hermes before restoring DBs.

## Cron wiring (no_agent jobs)

```
hermes-backup-daily:  30 2 * * *   → hermes-backup-daily.sh   (wraps: hermes-backup.sh daily)
hermes-backup-weekly: 30 2 * * 0   → hermes-backup-weekly.sh  (wraps: hermes-backup.sh weekly)
```

Cron script paths must be relative to `~/.hermes/scripts/`.
