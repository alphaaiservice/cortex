---
description: "Configure automated backup schedules, test restore procedures, and generate disaster recovery runbooks. Usage: /backup-dr [setup | test-restore | runbook | status]"
---

# Backup & Disaster Recovery

Action: **$ARGUMENTS** (default: `setup`)

Parse $ARGUMENTS:
- `setup` — Configure automated backups for all detected databases
- `test-restore` — Run a restore verification against the latest backup
- `runbook` — Generate a disaster recovery runbook
- `status` — Show current backup health and last restore test results
- No argument = `setup`

---

## Step 0: Detect Data Stores

Before anything, discover what needs backing up.

```bash
echo "=== Project Root ==="
pwd

echo "=== Docker Compose Services ==="
cat docker-compose*.yml docker/docker-compose*.yml 2>/dev/null | grep -E "^\s+\w+:" | head -30

echo "=== MySQL/MariaDB ==="
grep -rn "mysql\|mariadb\|DATABASE_URL.*mysql" .env* docker-compose*.yml docker/docker-compose*.yml 2>/dev/null | head -10

echo "=== MongoDB ==="
grep -rn "mongodb\|MONGO_URI\|MONGO_URL" .env* docker-compose*.yml docker/docker-compose*.yml 2>/dev/null | head -10

echo "=== Redis ==="
grep -rn "redis://\|REDIS_URL\|REDIS_HOST" .env* docker-compose*.yml docker/docker-compose*.yml 2>/dev/null | head -10

echo "=== S3/MinIO ==="
grep -rn "minio\|S3_BUCKET\|AWS_S3\|STORAGE_BUCKET" .env* docker-compose*.yml docker/docker-compose*.yml 2>/dev/null | head -10

echo "=== Existing Backup Scripts ==="
find . -maxdepth 3 -name "*backup*" -o -name "*restore*" -o -name "*dump*" 2>/dev/null | grep -v node_modules | grep -v .git

echo "=== Cron Jobs ==="
crontab -l 2>/dev/null || echo "No crontab"
ls /etc/cron.d/*backup* 2>/dev/null || echo "No backup cron jobs"
```

Build a list of data stores to back up:
- **MySQL/MariaDB** → `mysqldump`
- **MongoDB** → `mongodump`
- **Redis** → `redis-cli BGSAVE` + copy RDB
- **S3/MinIO** → `mc mirror` (MinIO Client)
- **File uploads** → `tar` or `rsync`

---

## Step 1: Create Backup Directory Structure

```
backup/
├── scripts/
│   ├── backup-all.sh              # Master backup orchestrator
│   ├── backup-mysql.sh            # MySQL/MariaDB backup
│   ├── backup-mongodb.sh          # MongoDB backup
│   ├── backup-redis.sh            # Redis RDB snapshot
│   ├── backup-files.sh            # File/upload storage backup
│   ├── restore-mysql.sh           # MySQL restore
│   ├── restore-mongodb.sh         # MongoDB restore
│   ├── restore-redis.sh           # Redis restore
│   ├── restore-files.sh           # File restore
│   ├── verify-backup.sh           # Verify backup integrity
│   └── cleanup-old-backups.sh     # Retention policy enforcement
├── config/
│   ├── backup.env                 # Backup configuration (encrypted)
│   └── retention-policy.yml       # Retention rules
├── logs/
│   └── .gitkeep
└── DR_RUNBOOK.md                  # Disaster recovery procedures
```

---

## Step 2: Generate MySQL Backup Script

Create `backup/scripts/backup-mysql.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───
BACKUP_DIR="${BACKUP_ROOT:-/backups}/mysql"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/mysql_${TIMESTAMP}.sql.gz"
RETENTION_DAYS="${MYSQL_BACKUP_RETENTION_DAYS:-30}"

# Load from environment or .env
DB_HOST="${MYSQL_HOST:-localhost}"
DB_PORT="${MYSQL_PORT:-3306}"
DB_USER="${MYSQL_USER:-root}"
DB_PASSWORD="${MYSQL_PASSWORD}"
DB_NAME="${MYSQL_DATABASE}"

# ─── Pre-flight ───
mkdir -p "${BACKUP_DIR}"
echo "[$(date)] Starting MySQL backup: ${DB_NAME}@${DB_HOST}"

# ─── Backup ───
mysqldump \
  --host="${DB_HOST}" \
  --port="${DB_PORT}" \
  --user="${DB_USER}" \
  --password="${DB_PASSWORD}" \
  --single-transaction \
  --routines \
  --triggers \
  --events \
  --set-gtid-purged=OFF \
  "${DB_NAME}" | gzip > "${BACKUP_FILE}"

# ─── Verify ───
if [ -f "${BACKUP_FILE}" ] && [ "$(stat -f%z "${BACKUP_FILE}" 2>/dev/null || stat -c%s "${BACKUP_FILE}")" -gt 100 ]; then
  echo "[$(date)] MySQL backup successful: ${BACKUP_FILE} ($(du -h "${BACKUP_FILE}" | cut -f1))"

  # Generate checksum
  sha256sum "${BACKUP_FILE}" > "${BACKUP_FILE}.sha256"

  # Log result
  echo "${TIMESTAMP},mysql,${DB_NAME},success,${BACKUP_FILE}" >> "${BACKUP_DIR}/../logs/backup-log.csv"
else
  echo "[$(date)] ERROR: MySQL backup failed or is empty"
  echo "${TIMESTAMP},mysql,${DB_NAME},FAILED," >> "${BACKUP_DIR}/../logs/backup-log.csv"
  exit 1
fi

# ─── Cleanup old backups ───
find "${BACKUP_DIR}" -name "mysql_*.sql.gz" -mtime +${RETENTION_DAYS} -delete
find "${BACKUP_DIR}" -name "mysql_*.sql.gz.sha256" -mtime +${RETENTION_DAYS} -delete
echo "[$(date)] Cleaned backups older than ${RETENTION_DAYS} days"
```

---

## Step 3: Generate MongoDB Backup Script

Create `backup/scripts/backup-mongodb.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───
BACKUP_DIR="${BACKUP_ROOT:-/backups}/mongodb"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/mongo_${TIMESTAMP}"
BACKUP_FILE="${BACKUP_PATH}.tar.gz"
RETENTION_DAYS="${MONGO_BACKUP_RETENTION_DAYS:-30}"

MONGO_URI="${MONGO_URI:-mongodb://localhost:27017}"
MONGO_DB="${MONGO_DATABASE}"

# ─── Pre-flight ───
mkdir -p "${BACKUP_DIR}"
echo "[$(date)] Starting MongoDB backup: ${MONGO_DB}"

# ─── Backup ───
mongodump \
  --uri="${MONGO_URI}" \
  --db="${MONGO_DB}" \
  --out="${BACKUP_PATH}" \
  --gzip

# ─── Archive ───
tar -czf "${BACKUP_FILE}" -C "${BACKUP_DIR}" "mongo_${TIMESTAMP}"
rm -rf "${BACKUP_PATH}"

# ─── Verify ───
if [ -f "${BACKUP_FILE}" ] && [ "$(stat -f%z "${BACKUP_FILE}" 2>/dev/null || stat -c%s "${BACKUP_FILE}")" -gt 100 ]; then
  echo "[$(date)] MongoDB backup successful: ${BACKUP_FILE} ($(du -h "${BACKUP_FILE}" | cut -f1))"
  sha256sum "${BACKUP_FILE}" > "${BACKUP_FILE}.sha256"
  echo "${TIMESTAMP},mongodb,${MONGO_DB},success,${BACKUP_FILE}" >> "${BACKUP_DIR}/../logs/backup-log.csv"
else
  echo "[$(date)] ERROR: MongoDB backup failed"
  echo "${TIMESTAMP},mongodb,${MONGO_DB},FAILED," >> "${BACKUP_DIR}/../logs/backup-log.csv"
  exit 1
fi

# ─── Cleanup ───
find "${BACKUP_DIR}" -name "mongo_*.tar.gz" -mtime +${RETENTION_DAYS} -delete
find "${BACKUP_DIR}" -name "mongo_*.tar.gz.sha256" -mtime +${RETENTION_DAYS} -delete
```

---

## Step 4: Generate Redis Backup Script

Create `backup/scripts/backup-redis.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_ROOT:-/backups}/redis"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/redis_${TIMESTAMP}.rdb.gz"
RETENTION_DAYS="${REDIS_BACKUP_RETENTION_DAYS:-14}"

REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"

mkdir -p "${BACKUP_DIR}"
echo "[$(date)] Starting Redis backup"

# Trigger background save
if [ -n "${REDIS_PASSWORD}" ]; then
  redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" BGSAVE
else
  redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" BGSAVE
fi

# Wait for save to complete
sleep 5

# Find and copy the RDB file
REDIS_RDB_PATH=$(redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" ${REDIS_PASSWORD:+-a "${REDIS_PASSWORD}"} CONFIG GET dir | tail -1)
REDIS_RDB_FILE=$(redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" ${REDIS_PASSWORD:+-a "${REDIS_PASSWORD}"} CONFIG GET dbfilename | tail -1)

if [ -f "${REDIS_RDB_PATH}/${REDIS_RDB_FILE}" ]; then
  gzip -c "${REDIS_RDB_PATH}/${REDIS_RDB_FILE}" > "${BACKUP_FILE}"
  sha256sum "${BACKUP_FILE}" > "${BACKUP_FILE}.sha256"
  echo "[$(date)] Redis backup successful: ${BACKUP_FILE}"
  echo "${TIMESTAMP},redis,,success,${BACKUP_FILE}" >> "${BACKUP_DIR}/../logs/backup-log.csv"
else
  echo "[$(date)] ERROR: Redis RDB file not found at ${REDIS_RDB_PATH}/${REDIS_RDB_FILE}"
  echo "${TIMESTAMP},redis,,FAILED," >> "${BACKUP_DIR}/../logs/backup-log.csv"
  exit 1
fi

# ─── Cleanup ───
find "${BACKUP_DIR}" -name "redis_*.rdb.gz" -mtime +${RETENTION_DAYS} -delete
```

---

## Step 5: Generate Master Backup Orchestrator

Create `backup/scripts/backup-all.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/../logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/backup_${TIMESTAMP}.log"

mkdir -p "${LOG_DIR}"

# Load environment
if [ -f "${SCRIPT_DIR}/../config/backup.env" ]; then
  set -a
  source "${SCRIPT_DIR}/../config/backup.env"
  set +a
fi

echo "╔══════════════════════════════════════════════╗" | tee -a "${LOG_FILE}"
echo "║     BACKUP STARTED: $(date)        ║" | tee -a "${LOG_FILE}"
echo "╚══════════════════════════════════════════════╝" | tee -a "${LOG_FILE}"

FAILED=0
TOTAL=0
SUCCEEDED=0

# ─── MySQL Backup ───
if [ -n "${MYSQL_DATABASE:-}" ]; then
  TOTAL=$((TOTAL + 1))
  echo "[MySQL] Starting..." | tee -a "${LOG_FILE}"
  if bash "${SCRIPT_DIR}/backup-mysql.sh" >> "${LOG_FILE}" 2>&1; then
    echo "[MySQL] ✅ Success" | tee -a "${LOG_FILE}"
    SUCCEEDED=$((SUCCEEDED + 1))
  else
    echo "[MySQL] ❌ Failed" | tee -a "${LOG_FILE}"
    FAILED=$((FAILED + 1))
  fi
fi

# ─── MongoDB Backup ───
if [ -n "${MONGO_DATABASE:-}" ]; then
  TOTAL=$((TOTAL + 1))
  echo "[MongoDB] Starting..." | tee -a "${LOG_FILE}"
  if bash "${SCRIPT_DIR}/backup-mongodb.sh" >> "${LOG_FILE}" 2>&1; then
    echo "[MongoDB] ✅ Success" | tee -a "${LOG_FILE}"
    SUCCEEDED=$((SUCCEEDED + 1))
  else
    echo "[MongoDB] ❌ Failed" | tee -a "${LOG_FILE}"
    FAILED=$((FAILED + 1))
  fi
fi

# ─── Redis Backup ───
if [ -n "${REDIS_HOST:-}" ]; then
  TOTAL=$((TOTAL + 1))
  echo "[Redis] Starting..." | tee -a "${LOG_FILE}"
  if bash "${SCRIPT_DIR}/backup-redis.sh" >> "${LOG_FILE}" 2>&1; then
    echo "[Redis] ✅ Success" | tee -a "${LOG_FILE}"
    SUCCEEDED=$((SUCCEEDED + 1))
  else
    echo "[Redis] ❌ Failed" | tee -a "${LOG_FILE}"
    FAILED=$((FAILED + 1))
  fi
fi

# ─── File Storage Backup ───
if [ -n "${UPLOADS_DIR:-}" ]; then
  TOTAL=$((TOTAL + 1))
  echo "[Files] Starting..." | tee -a "${LOG_FILE}"
  if bash "${SCRIPT_DIR}/backup-files.sh" >> "${LOG_FILE}" 2>&1; then
    echo "[Files] ✅ Success" | tee -a "${LOG_FILE}"
    SUCCEEDED=$((SUCCEEDED + 1))
  else
    echo "[Files] ❌ Failed" | tee -a "${LOG_FILE}"
    FAILED=$((FAILED + 1))
  fi
fi

# ─── Summary ───
echo "" | tee -a "${LOG_FILE}"
echo "╔══════════════════════════════════════════════╗" | tee -a "${LOG_FILE}"
echo "║     BACKUP COMPLETE                          ║" | tee -a "${LOG_FILE}"
echo "╠══════════════════════════════════════════════╣" | tee -a "${LOG_FILE}"
echo "║  Total:     ${TOTAL}                                ║" | tee -a "${LOG_FILE}"
echo "║  Succeeded: ${SUCCEEDED}                                ║" | tee -a "${LOG_FILE}"
echo "║  Failed:    ${FAILED}                                ║" | tee -a "${LOG_FILE}"
echo "╚══════════════════════════════════════════════╝" | tee -a "${LOG_FILE}"

if [ "${FAILED}" -gt 0 ]; then
  echo "WARNING: ${FAILED} backup(s) failed. Check ${LOG_FILE}" | tee -a "${LOG_FILE}"
  exit 1
fi
```

---

## Step 6: Generate Restore Scripts

Create `backup/scripts/restore-mysql.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_ROOT:-/backups}/mysql"
BACKUP_FILE="${1:-$(ls -t "${BACKUP_DIR}"/mysql_*.sql.gz 2>/dev/null | head -1)}"

if [ -z "${BACKUP_FILE}" ] || [ ! -f "${BACKUP_FILE}" ]; then
  echo "ERROR: No backup file specified or found"
  echo "Usage: restore-mysql.sh [backup-file.sql.gz]"
  echo "Available backups:"
  ls -lh "${BACKUP_DIR}"/mysql_*.sql.gz 2>/dev/null || echo "  No backups found"
  exit 1
fi

DB_HOST="${MYSQL_HOST:-localhost}"
DB_PORT="${MYSQL_PORT:-3306}"
DB_USER="${MYSQL_USER:-root}"
DB_PASSWORD="${MYSQL_PASSWORD}"
DB_NAME="${MYSQL_DATABASE}"

echo "╔══════════════════════════════════════════════╗"
echo "║  MYSQL RESTORE                               ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  Source:   $(basename "${BACKUP_FILE}")"
echo "║  Target:   ${DB_NAME}@${DB_HOST}:${DB_PORT}"
echo "║  Size:     $(du -h "${BACKUP_FILE}" | cut -f1)"
echo "╚══════════════════════════════════════════════╝"

# Verify checksum if available
if [ -f "${BACKUP_FILE}.sha256" ]; then
  echo "Verifying checksum..."
  if sha256sum --check "${BACKUP_FILE}.sha256"; then
    echo "Checksum verified ✅"
  else
    echo "ERROR: Checksum mismatch! Backup may be corrupted."
    exit 1
  fi
fi

echo ""
echo "WARNING: This will OVERWRITE the database '${DB_NAME}'."
echo "Press Ctrl+C within 10 seconds to cancel..."
sleep 10

echo "Restoring..."
gunzip -c "${BACKUP_FILE}" | mysql \
  --host="${DB_HOST}" \
  --port="${DB_PORT}" \
  --user="${DB_USER}" \
  --password="${DB_PASSWORD}" \
  "${DB_NAME}"

echo "MySQL restore completed successfully ✅"
echo "Restored from: ${BACKUP_FILE}"
```

Create `backup/scripts/restore-mongodb.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_ROOT:-/backups}/mongodb"
BACKUP_FILE="${1:-$(ls -t "${BACKUP_DIR}"/mongo_*.tar.gz 2>/dev/null | head -1)}"

if [ -z "${BACKUP_FILE}" ] || [ ! -f "${BACKUP_FILE}" ]; then
  echo "ERROR: No backup file found"
  exit 1
fi

MONGO_URI="${MONGO_URI:-mongodb://localhost:27017}"
MONGO_DB="${MONGO_DATABASE}"
TEMP_DIR=$(mktemp -d)

echo "Restoring MongoDB from: $(basename "${BACKUP_FILE}")"
echo "WARNING: This will DROP and recreate '${MONGO_DB}'. Ctrl+C to cancel..."
sleep 10

tar -xzf "${BACKUP_FILE}" -C "${TEMP_DIR}"
mongorestore \
  --uri="${MONGO_URI}" \
  --db="${MONGO_DB}" \
  --drop \
  --gzip \
  "${TEMP_DIR}/mongo_"*/"${MONGO_DB}"

rm -rf "${TEMP_DIR}"
echo "MongoDB restore completed successfully ✅"
```

---

## Step 7: Generate Verify Script

Create `backup/scripts/verify-backup.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Verify the latest backup for each data store without actually restoring to production.
# Creates a temporary database, restores into it, checks row counts, then drops it.

BACKUP_DIR="${BACKUP_ROOT:-/backups}"
VERIFY_DB_NAME="backup_verify_$(date +%s)"
RESULTS=()

echo "╔══════════════════════════════════════════════╗"
echo "║     BACKUP VERIFICATION                      ║"
echo "╚══════════════════════════════════════════════╝"

# ─── MySQL Verification ───
MYSQL_BACKUP=$(ls -t "${BACKUP_DIR}/mysql"/mysql_*.sql.gz 2>/dev/null | head -1)
if [ -n "${MYSQL_BACKUP:-}" ] && [ -f "${MYSQL_BACKUP}" ]; then
  echo ""
  echo "[MySQL] Verifying: $(basename "${MYSQL_BACKUP}")"

  # Check checksum
  if [ -f "${MYSQL_BACKUP}.sha256" ]; then
    if sha256sum --check "${MYSQL_BACKUP}.sha256" > /dev/null 2>&1; then
      echo "  Checksum: ✅ Valid"
    else
      echo "  Checksum: ❌ MISMATCH"
      RESULTS+=("MySQL: ❌ Checksum failed")
    fi
  fi

  # Check file size
  SIZE=$(du -h "${MYSQL_BACKUP}" | cut -f1)
  echo "  Size: ${SIZE}"

  # Test decompression
  if gunzip -t "${MYSQL_BACKUP}" 2>/dev/null; then
    echo "  Integrity: ✅ Valid gzip"
  else
    echo "  Integrity: ❌ Corrupt gzip"
    RESULTS+=("MySQL: ❌ Corrupt archive")
  fi

  # Try restoring to a temporary database
  if [ -n "${MYSQL_HOST:-}" ]; then
    echo "  Restore test: Creating temp database '${VERIFY_DB_NAME}'..."
    mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT:-3306}" -u "${MYSQL_USER:-root}" -p"${MYSQL_PASSWORD}" \
      -e "CREATE DATABASE IF NOT EXISTS ${VERIFY_DB_NAME};" 2>/dev/null

    if gunzip -c "${MYSQL_BACKUP}" | mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT:-3306}" \
      -u "${MYSQL_USER:-root}" -p"${MYSQL_PASSWORD}" "${VERIFY_DB_NAME}" 2>/dev/null; then

      # Count tables and rows
      TABLE_COUNT=$(mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT:-3306}" -u "${MYSQL_USER:-root}" \
        -p"${MYSQL_PASSWORD}" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${VERIFY_DB_NAME}';" 2>/dev/null)
      echo "  Tables restored: ${TABLE_COUNT}"
      echo "  Restore test: ✅ Successful"
      RESULTS+=("MySQL: ✅ Verified (${TABLE_COUNT} tables, ${SIZE})")
    else
      echo "  Restore test: ❌ Failed"
      RESULTS+=("MySQL: ❌ Restore failed")
    fi

    # Cleanup
    mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT:-3306}" -u "${MYSQL_USER:-root}" \
      -p"${MYSQL_PASSWORD}" -e "DROP DATABASE IF EXISTS ${VERIFY_DB_NAME};" 2>/dev/null
  fi
else
  RESULTS+=("MySQL: ⚠️ No backup found")
fi

# ─── MongoDB Verification ───
MONGO_BACKUP=$(ls -t "${BACKUP_DIR}/mongodb"/mongo_*.tar.gz 2>/dev/null | head -1)
if [ -n "${MONGO_BACKUP:-}" ] && [ -f "${MONGO_BACKUP}" ]; then
  echo ""
  echo "[MongoDB] Verifying: $(basename "${MONGO_BACKUP}")"
  SIZE=$(du -h "${MONGO_BACKUP}" | cut -f1)
  echo "  Size: ${SIZE}"

  if tar -tzf "${MONGO_BACKUP}" > /dev/null 2>&1; then
    COLLECTION_COUNT=$(tar -tzf "${MONGO_BACKUP}" | grep -c "\.bson" 2>/dev/null || echo "0")
    echo "  Integrity: ✅ Valid archive (${COLLECTION_COUNT} collections)"
    RESULTS+=("MongoDB: ✅ Verified (${COLLECTION_COUNT} collections, ${SIZE})")
  else
    echo "  Integrity: ❌ Corrupt archive"
    RESULTS+=("MongoDB: ❌ Corrupt archive")
  fi
else
  RESULTS+=("MongoDB: ⚠️ No backup found")
fi

# ─── Redis Verification ───
REDIS_BACKUP=$(ls -t "${BACKUP_DIR}/redis"/redis_*.rdb.gz 2>/dev/null | head -1)
if [ -n "${REDIS_BACKUP:-}" ] && [ -f "${REDIS_BACKUP}" ]; then
  echo ""
  echo "[Redis] Verifying: $(basename "${REDIS_BACKUP}")"
  SIZE=$(du -h "${REDIS_BACKUP}" | cut -f1)
  echo "  Size: ${SIZE}"

  if gunzip -t "${REDIS_BACKUP}" 2>/dev/null; then
    echo "  Integrity: ✅ Valid gzip"
    RESULTS+=("Redis: ✅ Verified (${SIZE})")
  else
    echo "  Integrity: ❌ Corrupt"
    RESULTS+=("Redis: ❌ Corrupt archive")
  fi
else
  RESULTS+=("Redis: ⚠️ No backup found")
fi

# ─── Summary ───
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║     VERIFICATION RESULTS                     ║"
echo "╠══════════════════════════════════════════════╣"
for result in "${RESULTS[@]}"; do
  printf "║  %-42s ║\n" "${result}"
done
echo "╚══════════════════════════════════════════════╝"
```

---

## Step 8: Generate Backup Configuration

Create `backup/config/backup.env`:
```bash
# ─── Backup Root Directory ───
BACKUP_ROOT=/backups

# ─── MySQL ───
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=CHANGE_ME
MYSQL_DATABASE=your_app_db
MYSQL_BACKUP_RETENTION_DAYS=30

# ─── MongoDB ───
MONGO_URI=mongodb://localhost:27017
MONGO_DATABASE=your_app_db
MONGO_BACKUP_RETENTION_DAYS=30

# ─── Redis ───
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_BACKUP_RETENTION_DAYS=14

# ─── File Storage ───
UPLOADS_DIR=./uploads
FILE_BACKUP_RETENTION_DAYS=30

# ─── Notification (optional) ───
# SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
# ALERT_EMAIL=ops@yourcompany.com
```

Create `backup/config/retention-policy.yml`:
```yaml
retention:
  mysql:
    daily: 30          # Keep daily backups for 30 days
    weekly: 12         # Keep weekly backups (Sunday) for 12 weeks
    monthly: 12        # Keep monthly backups (1st) for 12 months

  mongodb:
    daily: 30
    weekly: 12
    monthly: 12

  redis:
    daily: 14          # Redis backups are smaller; keep 14 days
    weekly: 8

  files:
    daily: 30
    weekly: 12

schedule:
  full_backup: "0 2 * * *"     # Daily at 2 AM
  verify: "0 6 * * 0"         # Weekly on Sunday at 6 AM
  cleanup: "0 3 * * *"        # Daily at 3 AM (after backup)

rpo_target: 24h                # Recovery Point Objective: max 24h data loss
rto_target: 1h                 # Recovery Time Objective: restore within 1h
```

---

## Step 9: Generate Cron Schedule

Set up automated backups:

```bash
# Add to crontab
echo "=== Recommended Crontab Entries ==="
cat << 'CRON'
# ─── Automated Backups (Cortex) ───
# Daily full backup at 2 AM
0 2 * * * cd /path/to/project && bash backup/scripts/backup-all.sh >> backup/logs/cron.log 2>&1

# Weekly backup verification (Sunday 6 AM)
0 6 * * 0 cd /path/to/project && bash backup/scripts/verify-backup.sh >> backup/logs/verify.log 2>&1

# Daily cleanup of expired backups at 3 AM
0 3 * * * cd /path/to/project && bash backup/scripts/cleanup-old-backups.sh >> backup/logs/cleanup.log 2>&1
CRON
```

Ask the user if they want to install these cron entries automatically.

---

## Step 10: Generate Disaster Recovery Runbook

Create `backup/DR_RUNBOOK.md`:

```markdown
# Disaster Recovery Runbook

**Project**: [project name]
**Last Updated**: [today's date]
**RPO Target**: 24 hours (max acceptable data loss)
**RTO Target**: 1 hour (max acceptable downtime)

---

## Severity Levels

| Level | Description | Response Time | Example |
|-------|-------------|---------------|---------|
| SEV-1 | Complete outage, all users affected | Immediate | Database corruption, server down |
| SEV-2 | Partial outage, major feature broken | 15 min | Auth system down, payment failure |
| SEV-3 | Degraded performance | 1 hour | Slow queries, high latency |
| SEV-4 | Minor issue, workaround exists | 4 hours | Non-critical cache failure |

---

## Scenario 1: Database Corruption / Data Loss (SEV-1)

### Symptoms
- Application returning 500 errors on data operations
- Database connection errors in logs
- Missing or corrupted data reported by users

### Recovery Steps

1. **Assess the damage**:
   ```bash
   # Check database status
   mysqladmin -u root -p status
   # Check recent error logs
   tail -100 /var/log/mysql/error.log
   ```

2. **Stop the application** to prevent further damage:
   ```bash
   kubectl scale deployment/app --replicas=0
   # or: docker-compose stop app
   ```

3. **Identify the latest good backup**:
   ```bash
   ls -lht /backups/mysql/mysql_*.sql.gz | head -5
   ```

4. **Restore from backup**:
   ```bash
   bash backup/scripts/restore-mysql.sh /backups/mysql/mysql_YYYYMMDD_HHMMSS.sql.gz
   ```

5. **Verify data integrity**:
   ```bash
   bash backup/scripts/verify-backup.sh
   ```

6. **Restart the application**:
   ```bash
   kubectl scale deployment/app --replicas=3
   # or: docker-compose up -d app
   ```

7. **Monitor for 30 minutes** after recovery.

### Data Loss Assessment
- Check backup timestamp vs incident time
- Calculate data loss window
- Notify affected users if > 1 hour of data lost

---

## Scenario 2: Server / Node Failure (SEV-1)

### Recovery Steps

1. **Check node status**:
   ```bash
   kubectl get nodes
   kubectl describe node <failed-node>
   ```

2. **If K3s node**: Pods will auto-reschedule to healthy nodes.
   ```bash
   kubectl get pods -o wide  # Verify pods moved
   ```

3. **If single-server**: Provision new server, restore from backup.

4. **Restore databases** from latest backup.

5. **Verify all services** are running:
   ```bash
   kubectl get pods --all-namespaces
   curl -s http://localhost:8000/health
   ```

---

## Scenario 3: Accidental Data Deletion (SEV-2)

### Recovery Steps

1. **Identify what was deleted** (check audit logs).

2. **Point-in-time recovery** (if binlog/oplog enabled):
   ```bash
   # MySQL: Replay binlog to just before deletion
   mysqlbinlog --stop-datetime="YYYY-MM-DD HH:MM:SS" binlog.000001 | mysql -u root -p
   ```

3. **Selective restore** from backup:
   - Restore backup to a temporary database
   - Copy only the affected tables/documents back

---

## Scenario 4: Security Breach (SEV-1)

### Immediate Actions (first 15 minutes)

1. **Rotate all secrets**:
   - JWT signing key
   - Database passwords
   - API keys (Razorpay, S3, LLM providers)
   - Redis password

2. **Invalidate all sessions**:
   ```bash
   redis-cli FLUSHDB  # Clear all session/token data
   ```

3. **Review audit logs** for unauthorized access.

4. **Take forensic snapshot** before any changes:
   ```bash
   bash backup/scripts/backup-all.sh  # Preserve current state
   ```

5. **Patch the vulnerability** before bringing services back online.

---

## Emergency Contacts

| Role | Name | Contact |
|------|------|---------|
| On-call engineer | [name] | [phone/slack] |
| Database admin | [name] | [phone/slack] |
| Security lead | [name] | [phone/slack] |
| Cloud provider support | [provider] | [support link] |

---

## Backup Verification Log

| Date | MySQL | MongoDB | Redis | Files | Verified By |
|------|-------|---------|-------|-------|-------------|
| [date] | ✅/❌ | ✅/❌ | ✅/❌ | ✅/❌ | [name] |

---

## Post-Incident Template

After any SEV-1 or SEV-2 incident, complete this:

1. **Incident summary**: What happened?
2. **Timeline**: When detected → when resolved
3. **Impact**: Users affected, data lost, downtime duration
4. **Root cause**: Why did it happen?
5. **Resolution**: How was it fixed?
6. **Action items**: What prevents recurrence?
```

---

## Step 11: Setup for K3s Deployments

If the project uses K3s (detected by `k8s/` directory), generate CronJob manifests:

```yaml
# backup/k8s/backup-cronjob.yml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup
  namespace: default
spec:
  schedule: "0 2 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: mysql:8.0
              command: ["/bin/bash", "-c"]
              args:
                - |
                  mysqldump --host=$MYSQL_HOST --user=$MYSQL_USER --password=$MYSQL_PASSWORD \
                    --single-transaction --routines --triggers $MYSQL_DATABASE | \
                    gzip > /backups/mysql/mysql_$(date +%Y%m%d_%H%M%S).sql.gz
              envFrom:
                - secretRef:
                    name: backup-secrets
              volumeMounts:
                - name: backup-storage
                  mountPath: /backups
          restartPolicy: OnFailure
          volumes:
            - name: backup-storage
              persistentVolumeClaim:
                claimName: backup-pvc
```

---

## Step 12: Output Summary

```
╔══════════════════════════════════════════════════════════╗
║     BACKUP & DR CONFIGURED                              ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  Data Stores Detected:                                   ║
║    MySQL:    ✅ Backup + Restore scripts generated       ║
║    MongoDB:  ✅ Backup + Restore scripts generated       ║
║    Redis:    ✅ Backup + Restore scripts generated       ║
║    Files:    ✅ Backup + Restore scripts generated       ║
║                                                          ║
║  Automation:                                             ║
║    Daily backup:       2:00 AM (cron)                    ║
║    Weekly verify:      Sunday 6:00 AM (cron)             ║
║    Retention cleanup:  3:00 AM daily (cron)              ║
║                                                          ║
║  Targets:                                                ║
║    RPO: 24 hours (max data loss)                         ║
║    RTO: 1 hour (max downtime)                            ║
║                                                          ║
║  Generated Files:                                        ║
║    backup/scripts/backup-all.sh (master orchestrator)    ║
║    backup/scripts/backup-{mysql,mongodb,redis,files}.sh  ║
║    backup/scripts/restore-{mysql,mongodb,redis,files}.sh ║
║    backup/scripts/verify-backup.sh                       ║
║    backup/config/backup.env                              ║
║    backup/config/retention-policy.yml                    ║
║    backup/DR_RUNBOOK.md                                  ║
║                                                          ║
║  Next Steps:                                             ║
║    1. Edit backup/config/backup.env with real values     ║
║    2. Install cron entries (shown above)                  ║
║    3. Run first backup: bash backup/scripts/backup-all.sh║
║    4. Verify: bash backup/scripts/verify-backup.sh       ║
║    5. Review DR_RUNBOOK.md with your team                ║
╚══════════════════════════════════════════════════════════╝
```

---

## Scheduled Execution (Recommended)

`/backup-dr` itself is a one-time setup command — you run it once per project to scaffold the backup scripts, DR runbook, and cron entries. After that, **the GENERATED backup scripts** should run on a schedule (this is what Step 9 "Generate Cron Schedule" sets up).

However, **re-running `/backup-dr` periodically** has real value: it catches drift between what your DR runbook claims and what the project actually has (new data stores, deleted services, changed paths).

### Two distinct schedules to set up

**1. The generated backup scripts** (set up by Step 9 of this command)

These run inside your infrastructure (cron in the K3s nodes, GitHub Actions, or wherever your data lives). The command auto-generates the cron entries — you don't need to do this manually. Typical cadence:

| Job | Cadence | Retention |
|-----|---------|-----------|
| MySQL `mysqldump` | Daily 02:00 | 30 daily + 12 monthly + 1 yearly |
| MongoDB `mongodump` | Daily 02:30 | 30 daily + 12 monthly + 1 yearly |
| Redis RDB snapshot | Every 6 hours | 14 days |
| S3/storage cross-region replication | Continuous | n/a |
| Verify (restore test) | Weekly Sunday 03:00 | Pass/fail logged to `.cortex/backup-verify.log` |

**2. Re-running `/backup-dr` itself** (drift detection)

| Cadence | When | Rationale |
|---------|------|-----------|
| **Quarterly** (DEFAULT) | First Monday of each quarter | Catches new data stores added since last setup; updates DR_RUNBOOK.md with current state |
| Post-major-feature | After any feature that adds a data store or storage volume | Ensures backups cover the new surface |
| Pre-audit | Before any SOC2 / ISO27001 / DPDPA audit | DR runbook must reflect current reality |

### How to schedule the drift-detection rerun

**Option A: Claude Code `/schedule` (recommended)**

Type `/schedule` in any Claude Code session. Example: `"first Monday of every 3 months at 10:00 UTC"`.

**Option B: Calendar reminder**

Honestly, for quarterly cadence, a calendar reminder for the on-call engineer to run `/backup-dr` is often more reliable than automation — the rerun is interactive (asks about new data stores) and shouldn't run unattended.

### Mandatory when scheduled

- **ALWAYS** run `bash backup/scripts/verify-backup.sh` weekly. A backup you've never restored is a hope, not a backup.
- **ALWAYS** alert SEV-1 on backup verify failure — a broken backup pipeline is invisible until you need it.
- **ALWAYS** rotate offsite copies on the schedule defined in DR_RUNBOOK.md (lifecycle policies in the backup S3 bucket).
- **NEVER** auto-delete old backups via cron without lifecycle policies + alerts on lifecycle drift.
