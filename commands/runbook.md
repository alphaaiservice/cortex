---
description: "Generate operational runbooks and playbooks for incident response, routine maintenance, and disaster recovery. Usage: /runbook [--type=incident|maintenance|disaster-recovery|all]"
---

# Operational Runbook Generator

Generate comprehensive, production-quality runbooks for this project.

$ARGUMENTS = runbook type to generate (default: `all`). Accepted values: `incident`, `maintenance`, `disaster-recovery`, `all`.

Parse $ARGUMENTS to determine which runbook types to generate. If no argument is provided or `--type=all`, generate all four runbook documents.

---

## Step 1: Analyze Infrastructure

Before generating any runbook content, perform a thorough infrastructure discovery. Run all of the following checks in parallel using the Agent tool.

### 1A: Detect Container & Orchestration Services

```bash
echo "=== Docker Detection ==="
ls -la docker-compose*.yml docker/docker-compose*.yml docker/Dockerfile* Dockerfile* 2>/dev/null || echo "No Docker files found"

echo ""
echo "=== Kubernetes Detection ==="
ls -la k8s/ kubernetes/ helm/ charts/ *.yaml 2>/dev/null || echo "No K8s manifests found"
find . -maxdepth 3 -name "*.yaml" -exec grep -l "kind: Deployment\|kind: Service\|kind: Ingress" {} \; 2>/dev/null

echo ""
echo "=== Cloud Run / App Engine / ECS ==="
ls -la app.yaml cloudbuild.yaml buildspec.yml ecs-task-definition.json 2>/dev/null || echo "No cloud deploy manifests found"
cat Procfile 2>/dev/null || echo "No Procfile"
```

### 1B: Identify Databases

```bash
echo "=== MySQL/PostgreSQL ==="
grep -rn "mysql\|postgresql\|psycopg\|asyncmy\|sqlalchemy\|DATABASE_URL\|DB_HOST" .env* config/ app/core/ app/db/ settings* 2>/dev/null | head -20

echo ""
echo "=== MongoDB ==="
grep -rn "mongodb\|MONGO_URI\|pymongo\|motor\|beanie\|MongoClient" .env* config/ app/core/ app/db/ settings* 2>/dev/null | head -20

echo ""
echo "=== Redis ==="
grep -rn "redis\|REDIS_URL\|REDIS_HOST\|redis.asyncio\|aioredis" .env* config/ app/core/ settings* 2>/dev/null | head -20

echo ""
echo "=== Other Databases ==="
grep -rn "elasticsearch\|qdrant\|meilisearch\|cassandra\|dynamodb" .env* config/ app/ 2>/dev/null | head -10
```

### 1C: Identify External Services

```bash
echo "=== Payment Providers ==="
grep -rn "razorpay\|stripe\|paypal\|RAZORPAY_KEY\|STRIPE_KEY" .env* config/ app/ 2>/dev/null | head -10

echo ""
echo "=== Cloud Storage ==="
grep -rn "S3\|boto3\|GCS\|BUCKET\|minio\|cloudinary" .env* config/ app/ 2>/dev/null | head -10

echo ""
echo "=== Error Tracking & Analytics ==="
grep -rn "sentry\|SENTRY_DSN\|posthog\|POSTHOG\|newrelic\|datadog" .env* config/ app/ 2>/dev/null | head -10

echo ""
echo "=== Email & Notifications ==="
grep -rn "SMTP\|sendgrid\|SES\|fastapi-mail\|FCM\|firebase\|twilio" .env* config/ app/ 2>/dev/null | head -10

echo ""
echo "=== Auth Providers ==="
grep -rn "oauth\|google.*client\|github.*client\|AUTH0\|CLERK\|authlib" .env* config/ app/ 2>/dev/null | head -10
```

### 1D: Check Monitoring Stack

```bash
echo "=== Prometheus ==="
ls -la monitoring/ prometheus/ 2>/dev/null
grep -rn "prometheus\|PROMETHEUS" docker-compose*.yml docker/ monitoring/ 2>/dev/null | head -10

echo ""
echo "=== Grafana ==="
grep -rn "grafana\|GRAFANA" docker-compose*.yml docker/ monitoring/ 2>/dev/null | head -10

echo ""
echo "=== Application Metrics ==="
grep -rn "starlette_exporter\|prometheus_client\|metrics\|health" app/ 2>/dev/null | head -10

echo ""
echo "=== Logging ==="
grep -rn "logging\|loguru\|structlog\|LOG_LEVEL\|ELK\|fluentd" app/ config/ 2>/dev/null | head -10
```

### 1E: Identify Backup Systems

```bash
echo "=== Backup Scripts ==="
ls -la scripts/backup* backup/ cron/ 2>/dev/null || echo "No backup scripts found"

echo ""
echo "=== Cron Jobs ==="
crontab -l 2>/dev/null || echo "No crontab"
ls -la cron* *.cron 2>/dev/null || echo "No cron files"

echo ""
echo "=== Celery / Task Queue ==="
grep -rn "celery\|CELERY_BROKER\|BROKER_URL\|celery_app\|shared_task" app/ config/ .env* 2>/dev/null | head -10
```

### 1F: Map Service Dependencies

```bash
echo "=== Docker Compose Services ==="
grep -E "^\s+\w+:" docker-compose*.yml docker/docker-compose*.yml 2>/dev/null | grep -v "#" | head -30

echo ""
echo "=== Internal API Calls ==="
grep -rn "httpx\|aiohttp\|requests\.get\|requests\.post\|INTERNAL_API\|SERVICE_URL" app/ 2>/dev/null | head -15

echo ""
echo "=== Environment Variables (service URLs) ==="
grep -rn "_URL\|_HOST\|_PORT\|_ENDPOINT" .env.example .env.sample 2>/dev/null | head -20

echo ""
echo "=== Requirements / Dependencies ==="
cat requirements.txt 2>/dev/null || cat pyproject.toml 2>/dev/null | head -60
```

After all discovery tasks complete, store the findings in memory. Use these findings to customize every runbook section with project-specific details (actual service names, actual database types, actual external services, actual port numbers, actual Docker container names).

---

## Step 2: Generate Incident Response Runbook

Create the file `docs/runbooks/INCIDENT_RESPONSE.md` with the following structure. Replace all placeholders with actual values discovered in Step 1. If a service was not detected, omit that section or mark it as "Not applicable to this project."

The file MUST contain ALL of the following sections with complete, actionable content:

```markdown
# Incident Response Runbook
**Project**: [project name from discovery]
**Generated**: [current date]
**Last Updated**: [current date]
**Owner**: Operations Team

---

## Table of Contents
1. [Severity Levels](#severity-levels)
2. [On-Call Procedures](#on-call-procedures)
3. [Incident Lifecycle](#incident-lifecycle)
4. [Common Incidents](#common-incidents)
   - [INC-01: API Server Down](#inc-01-api-server-down)
   - [INC-02: Database Connection Failure](#inc-02-database-connection-failure)
   - [INC-03: High Response Times](#inc-03-high-response-times)
   - [INC-04: Memory / CPU Spike](#inc-04-memory--cpu-spike)
   - [INC-05: Authentication Failures](#inc-05-authentication-failures)
   - [INC-06: Payment System Down](#inc-06-payment-system-down)
   - [INC-07: Celery Workers Stuck](#inc-07-celery-workers-stuck)
   - [INC-08: Disk Space Full](#inc-08-disk-space-full)
5. [Escalation Matrix](#escalation-matrix)
6. [Communication Templates](#communication-templates)
7. [Post-Mortem Template](#post-mortem-template)

---

## Severity Levels

| Level | Name | Description | Response Time | Notification | Examples |
|-------|------|-------------|---------------|--------------|----------|
| **SEV1** | Critical Outage | Complete service outage, all users affected, data loss risk | **Immediate** (within 5 min) | Page on-call + Slack #incidents + Email leadership | Full API down, database corruption, security breach |
| **SEV2** | Major Degradation | Partial outage, major feature unavailable, significant user impact | **30 minutes** | Slack #incidents + Email on-call team | Payment processing down, auth failures for subset of users, one region offline |
| **SEV3** | Minor Degradation | Degraded performance, minor feature broken, limited user impact | **2 hours** | Slack #alerts | Slow response times, non-critical background jobs failing, minor UI bugs |
| **SEV4** | Low Impact | Cosmetic issues, single-user reports, monitoring noise | **24 hours** | Ticket creation | Typos, minor logging errors, single failed webhook |

---

## On-Call Procedures

### Rotation Schedule
- **Primary on-call**: Rotates weekly (Monday 09:00 to Monday 09:00)
- **Secondary on-call**: Previous week's primary (backup escalation)
- **Escalation timeout**: If primary does not acknowledge within 10 minutes, page secondary

### When Paged
1. **Acknowledge** the alert within 5 minutes
2. **Assess** the severity using the table above
3. **Communicate** in the #incidents Slack channel: "Investigating [brief description]. SEV[X]. I am Incident Commander."
4. **Diagnose** using the relevant runbook section below
5. **Resolve** or **Escalate** if unable to resolve within 30 minutes
6. **Update** the status page every 15 minutes during SEV1/SEV2

### Incident Commander Responsibilities
- Own the incident from detection to resolution
- Coordinate response across teams
- Provide regular status updates
- Ensure post-mortem is scheduled within 48 hours
- Update this runbook if new failure modes are discovered

---

## Incident Lifecycle

```
Detection --> Triage --> Diagnosis --> Resolution --> Post-Mortem
    |            |           |             |              |
  Alert      Assign      Run the      Fix applied     Document
  fires      severity    playbook     & verified      learnings
             & IC role   commands
```

1. **Detection**: Alert from monitoring, customer report, or health check failure
2. **Triage**: Determine severity, assign Incident Commander, open incident channel
3. **Diagnosis**: Follow the relevant runbook section, gather evidence
4. **Resolution**: Apply fix, verify, monitor for recurrence (30 min soak time)
5. **Post-Mortem**: Document timeline, root cause, action items (within 48 hours)

---

## Common Incidents

### INC-01: API Server Down

**Symptoms**: Health check returns non-200, 502/503 from load balancer, users report "service unavailable"

**Severity**: SEV1

**Detection**:
```bash
# Check health endpoint
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health

# Check if container is running
docker ps --filter "name=[app-container-name]"

# Check Cloud Run / K8s pod status (if applicable)
# gcloud run services describe [service] --region [region] --format 'value(status.conditions)'
# kubectl get pods -l app=[app-name] -n [namespace]
```

**Diagnosis**:
```bash
# Step 1: Check container/process logs
docker logs --tail 100 [app-container-name] 2>&1

# Step 2: Check if the process is running
docker exec [app-container-name] ps aux | grep uvicorn

# Step 3: Check port binding
docker exec [app-container-name] netstat -tlnp 2>/dev/null || ss -tlnp

# Step 4: Check resource usage
docker stats --no-stream [app-container-name]

# Step 5: Check recent deployments
git log --oneline -5

# Step 6: Check systemd service status (if bare metal)
# systemctl status [service-name]
```

**Resolution**:
```bash
# Option A: Restart the container
docker restart [app-container-name]

# Option B: Rebuild and restart
docker-compose up -d --build [service-name]

# Option C: Rollback to previous version (Cloud Run)
# gcloud run services update-traffic [service] --region [region] --to-revisions [previous-revision]=100

# Option D: Rollback to previous version (Docker)
# docker pull [image]:[previous-tag]
# docker-compose up -d

# Verify recovery
sleep 10
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health
```

**Post-Resolution**:
- Monitor for 30 minutes to confirm stability
- Check error rates in monitoring dashboard
- Review recent changes that may have caused the failure
- Schedule post-mortem if SEV1/SEV2

---

### INC-02: Database Connection Failure

**Symptoms**: "Connection refused", "Too many connections", query timeouts, 500 errors on data-dependent endpoints

**Severity**: SEV1 (if all DB access fails) or SEV2 (if intermittent)

**Detection**:
```bash
# MySQL connection test
docker exec [mysql-container] mysqladmin ping -u root -p"$MYSQL_ROOT_PASSWORD" 2>&1

# MongoDB connection test
docker exec [mongo-container] mongosh --eval "db.adminCommand('ping')" 2>&1

# Redis connection test
docker exec [redis-container] redis-cli ping

# Check from the application container
docker exec [app-container-name] python -c "
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
engine = create_async_engine('$DATABASE_URL')
async def check():
    async with engine.connect() as conn:
        result = await conn.execute('SELECT 1')
        print('DB OK:', result.scalar())
asyncio.run(check())
"
```

**Diagnosis**:
```bash
# Step 1: Check if database container is running
docker ps --filter "name=mysql\|mongo\|postgres"

# Step 2: Check database logs
docker logs --tail 50 [db-container-name]

# Step 3: Check connection count (MySQL)
docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW STATUS LIKE 'Threads_connected';"
docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW VARIABLES LIKE 'max_connections';"

# Step 4: Check disk space on database volume
docker exec [db-container-name] df -h /var/lib/mysql 2>/dev/null || docker exec [db-container-name] df -h /data/db 2>/dev/null

# Step 5: Check replication status (if applicable)
docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G" 2>/dev/null

# Step 6: Check for long-running queries (MySQL)
docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SHOW PROCESSLIST;"

# Step 7: Check MongoDB status
docker exec [mongo-container] mongosh --eval "db.serverStatus().connections" 2>/dev/null
```

**Resolution**:
```bash
# Option A: Kill long-running queries (MySQL)
docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
SELECT GROUP_CONCAT(id) FROM information_schema.processlist WHERE time > 300 AND command != 'Sleep' INTO @ids;
-- Review before killing: SHOW PROCESSLIST;
-- KILL [process_id];
"

# Option B: Increase connection limits temporarily
docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SET GLOBAL max_connections = 500;"

# Option C: Restart the database
docker restart [db-container-name]

# Option D: Failover to replica (if available)
# Promote replica, update connection string, restart app

# Verify recovery
docker exec [mysql-container] mysqladmin ping -u root -p"$MYSQL_ROOT_PASSWORD"
```

**Data Recovery** (if corruption detected):
```bash
# Stop writes immediately
# Restore from most recent backup (see DISASTER_RECOVERY.md)
# Verify data integrity after restore
```

---

### INC-03: High Response Times

**Symptoms**: P95 latency > 2 seconds, users report slowness, monitoring alerts on latency

**Severity**: SEV2 (if affecting most users) or SEV3 (if limited scope)

**Detection**:
```bash
# Quick latency check on key endpoints
time curl -s -o /dev/null -w "HTTP %{http_code} | Total: %{time_total}s | TTFB: %{time_starttransfer}s\n" http://localhost:8000/health
time curl -s -o /dev/null -w "HTTP %{http_code} | Total: %{time_total}s | TTFB: %{time_starttransfer}s\n" http://localhost:8000/api/v1/[key-endpoint]

# Check Prometheus metrics (if available)
curl -s http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,rate(http_request_duration_seconds_bucket[5m]))
```

**Diagnosis**:
```bash
# Step 1: Check slow query log (MySQL)
docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;
SHOW VARIABLES LIKE 'slow_query_log_file';
"
# Then tail the slow query log:
docker exec [mysql-container] tail -50 /var/lib/mysql/[hostname]-slow.log

# Step 2: Check Redis cache hit rate
docker exec [redis-container] redis-cli INFO stats | grep -E "keyspace_hits|keyspace_misses"
# Calculate hit rate: hits / (hits + misses) * 100

# Step 3: Check Celery queue depth
docker exec [redis-container] redis-cli LLEN celery 2>/dev/null

# Step 4: Check system resources
docker stats --no-stream

# Step 5: Check active connections and open file descriptors
docker exec [app-container-name] cat /proc/1/fd 2>/dev/null | wc -l

# Step 6: Check for N+1 queries (review recent logs)
docker logs --tail 200 [app-container-name] 2>&1 | grep -i "SELECT\|query" | head -30

# Step 7: Check MongoDB slow operations
docker exec [mongo-container] mongosh --eval "db.currentOp({'secs_running': {'\$gt': 2}})" 2>/dev/null
```

**Resolution**:
```bash
# Option A: Clear / warm Redis cache
docker exec [redis-container] redis-cli FLUSHDB  # CAUTION: clears all keys in current DB
# Or selectively: docker exec [redis-container] redis-cli DEL [specific-key-pattern]

# Option B: Scale horizontally (Docker Compose)
docker-compose up -d --scale [app-service]=3

# Option C: Scale horizontally (Cloud Run)
# gcloud run services update [service] --region [region] --min-instances 2 --max-instances 20

# Option D: Optimize the slow queries (add indexes)
docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
EXPLAIN SELECT ... ;  -- Paste the slow query here
-- Add index: ALTER TABLE [table] ADD INDEX idx_[column] ([column]);
"

# Option E: Restart application (clears connection pools)
docker restart [app-container-name]
```

---

### INC-04: Memory / CPU Spike

**Symptoms**: Container OOMKilled, high CPU usage alerts, service unresponsive under load

**Severity**: SEV2

**Detection**:
```bash
# Check container resource usage
docker stats --no-stream

# Check for OOM events
docker inspect [app-container-name] --format='{{.State.OOMKilled}}'
dmesg | grep -i "oom\|killed" | tail -10

# Check host resources
free -h
top -bn1 | head -20
df -h
```

**Diagnosis**:
```bash
# Step 1: Identify resource-heavy process
docker exec [app-container-name] ps aux --sort=-%mem | head -10
docker exec [app-container-name] ps aux --sort=-%cpu | head -10

# Step 2: Check for memory leaks (Python)
docker exec [app-container-name] python -c "
import tracemalloc
tracemalloc.start()
# Your suspect code here
snapshot = tracemalloc.take_snapshot()
for stat in snapshot.statistics('lineno')[:10]:
    print(stat)
" 2>/dev/null || echo "Cannot run tracemalloc in this context"

# Step 3: Check Celery worker memory
docker exec [celery-container] celery -A [app] inspect stats 2>/dev/null | grep -A5 "rusage"

# Step 4: Check number of Gunicorn/Uvicorn workers
docker exec [app-container-name] ps aux | grep -c "uvicorn\|gunicorn"

# Step 5: Check connection pool sizes
docker logs --tail 50 [app-container-name] 2>&1 | grep -i "pool\|connection"
```

**Resolution**:
```bash
# Option A: Increase memory limits (Docker Compose)
# Edit docker-compose.yml: mem_limit: 1g -> mem_limit: 2g
docker-compose up -d [service-name]

# Option B: Reduce worker count
# Edit Gunicorn/Uvicorn config: workers = 2 (instead of 4)
docker restart [app-container-name]

# Option C: Restart the offending container (immediate relief)
docker restart [app-container-name]

# Option D: Scale out instead of up (Cloud Run)
# gcloud run services update [service] --memory 1Gi --cpu 2

# Long-term fixes:
# - Profile memory usage with py-spy or memray
# - Add Celery worker max-tasks-per-child (auto-restart after N tasks)
# - Implement connection pool limits in SQLAlchemy (pool_size, max_overflow)
# - Add Redis memory limits (maxmemory policy)
```

---

### INC-05: Authentication Failures

**Symptoms**: Mass login failures, "401 Unauthorized" spike, token validation errors, users report being logged out

**Severity**: SEV2

**Detection**:
```bash
# Check for 401 spike in logs
docker logs --tail 500 [app-container-name] 2>&1 | grep -c "401\|Unauthorized\|token.*invalid\|token.*expired"

# Check Redis (token blacklist / session store)
docker exec [redis-container] redis-cli DBSIZE
docker exec [redis-container] redis-cli KEYS "blacklist:*" 2>/dev/null | head -10
docker exec [redis-container] redis-cli KEYS "session:*" 2>/dev/null | head -10

# Check if JWT secret is accessible
docker exec [app-container-name] python -c "import os; print('JWT_SECRET set:', bool(os.getenv('JWT_SECRET_KEY', os.getenv('SECRET_KEY'))))"
```

**Diagnosis**:
```bash
# Step 1: Check if Redis is reachable from app
docker exec [app-container-name] python -c "
import redis
r = redis.from_url('$REDIS_URL')
r.ping()
print('Redis connection OK')
" 2>&1

# Step 2: Verify JWT secret has not changed
# Compare current secret hash with expected (do NOT print the actual secret)
docker exec [app-container-name] python -c "
import os, hashlib
secret = os.getenv('JWT_SECRET_KEY', os.getenv('SECRET_KEY', ''))
print('Secret hash:', hashlib.sha256(secret.encode()).hexdigest()[:16])
"

# Step 3: Check token expiry configuration
docker exec [app-container-name] python -c "
import os
print('Access token lifetime:', os.getenv('ACCESS_TOKEN_EXPIRE_MINUTES', 'not set'))
print('Refresh token lifetime:', os.getenv('REFRESH_TOKEN_EXPIRE_DAYS', 'not set'))
"

# Step 4: Check OAuth provider status (if applicable)
curl -s -o /dev/null -w "%{http_code}" https://accounts.google.com/.well-known/openid-configuration

# Step 5: Check for clock skew (JWT validation depends on time)
docker exec [app-container-name] date
date
```

**Resolution**:
```bash
# Option A: Restart Redis (if token store is corrupted)
docker restart [redis-container]

# Option B: Flush token blacklist (if legitimate tokens are being rejected)
docker exec [redis-container] redis-cli KEYS "blacklist:*" | xargs docker exec -i [redis-container] redis-cli DEL

# Option C: Emergency - invalidate all tokens and force re-login
# Rotate JWT secret (WARNING: logs out ALL users)
# Update .env with new JWT_SECRET_KEY
# Restart application
docker restart [app-container-name]

# Option D: Fix clock skew
# Sync NTP: ntpdate pool.ntp.org (on host)
```

---

### INC-06: Payment System Down

**Symptoms**: Razorpay/Stripe webhook failures, payment confirmation delays, customers charged but not activated

**Severity**: SEV1

**Detection**:
```bash
# Check webhook endpoint
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/v1/payments/webhook

# Check recent webhook logs
docker logs --tail 200 [app-container-name] 2>&1 | grep -i "webhook\|razorpay\|stripe\|payment"

# Check Razorpay API status
curl -s -o /dev/null -w "%{http_code}" https://api.razorpay.com/v1/
```

**Diagnosis**:
```bash
# Step 1: Check if webhook endpoint is responding
curl -X POST -H "Content-Type: application/json" -d '{"test": true}' http://localhost:8000/api/v1/payments/webhook 2>&1

# Step 2: Check for webhook signature validation failures
docker logs --tail 300 [app-container-name] 2>&1 | grep -i "signature\|verification\|webhook.*fail"

# Step 3: Check payment-related database tables
docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
SELECT status, COUNT(*) FROM payments WHERE created_at > NOW() - INTERVAL 1 HOUR GROUP BY status;
SELECT * FROM payments WHERE status = 'pending' AND created_at > NOW() - INTERVAL 2 HOUR ORDER BY created_at DESC LIMIT 10;
"

# Step 4: Check Razorpay webhook secret
docker exec [app-container-name] python -c "
import os
print('Razorpay Key ID set:', bool(os.getenv('RAZORPAY_KEY_ID')))
print('Razorpay Key Secret set:', bool(os.getenv('RAZORPAY_KEY_SECRET')))
print('Webhook Secret set:', bool(os.getenv('RAZORPAY_WEBHOOK_SECRET')))
"

# Step 5: Check for network issues reaching payment provider
docker exec [app-container-name] curl -s -o /dev/null -w "%{http_code}" https://api.razorpay.com/v1/ 2>&1
```

**Resolution**:
```bash
# Option A: Restart the application (if webhook endpoint is down)
docker restart [app-container-name]

# Option B: Manual payment reconciliation
# 1. Log into Razorpay Dashboard
# 2. Export recent payments (last 2 hours)
# 3. Compare with database records
# 4. Run reconciliation script:
docker exec [app-container-name] python -m app.scripts.reconcile_payments --since "2h" 2>/dev/null

# Option C: Re-register webhooks (if endpoint URL changed)
# Update webhook URL in Razorpay Dashboard -> Settings -> Webhooks
```

**Customer Communication Template**:
```
Subject: Payment Processing Delay - [Date]

We are currently experiencing a delay in payment processing.
Your payment has been received and will be reflected in your
account within [X] hours. No action is required on your part.

If you have been charged but your account has not been updated
after [X] hours, please contact support@[domain] with your
transaction ID.
```

---

### INC-07: Celery Workers Stuck

**Symptoms**: Background tasks not executing, queues growing, scheduled tasks missed, emails not sending

**Severity**: SEV2

**Detection**:
```bash
# Check Celery worker status
docker exec [celery-container] celery -A [app] inspect ping 2>&1

# Check queue depth
docker exec [redis-container] redis-cli LLEN celery
docker exec [redis-container] redis-cli LLEN celery-high-priority 2>/dev/null
docker exec [redis-container] redis-cli LLEN celery-low-priority 2>/dev/null

# Check if worker container is running
docker ps --filter "name=celery\|worker"
```

**Diagnosis**:
```bash
# Step 1: Check worker logs
docker logs --tail 100 [celery-container]

# Step 2: Check active tasks
docker exec [celery-container] celery -A [app] inspect active 2>&1

# Step 3: Check reserved (prefetched) tasks
docker exec [celery-container] celery -A [app] inspect reserved 2>&1

# Step 4: Check scheduled tasks
docker exec [celery-container] celery -A [app] inspect scheduled 2>&1

# Step 5: Check Redis broker connectivity
docker exec [celery-container] python -c "
import redis
r = redis.from_url('$CELERY_BROKER_URL')
r.ping()
print('Broker connection OK')
"

# Step 6: Check Celery Beat (scheduler) status
docker ps --filter "name=beat\|scheduler"
docker logs --tail 50 [celery-beat-container] 2>/dev/null
```

**Resolution**:
```bash
# Option A: Restart Celery workers
docker restart [celery-container]

# Option B: Purge stuck tasks (CAUTION: tasks will be lost)
docker exec [celery-container] celery -A [app] purge -f

# Option C: Restart Redis broker
docker restart [redis-container]
# Then restart Celery workers
docker restart [celery-container]

# Option D: Scale Celery workers
docker-compose up -d --scale celery-worker=3

# Option E: Restart Celery Beat (if scheduled tasks are missed)
docker restart [celery-beat-container]

# Verify recovery
sleep 10
docker exec [celery-container] celery -A [app] inspect ping
docker exec [redis-container] redis-cli LLEN celery
```

**Dead Letter Queue Handling**:
```bash
# Check for failed tasks in DLQ
docker exec [redis-container] redis-cli LLEN celery-dlq 2>/dev/null

# Inspect failed tasks
docker exec [redis-container] redis-cli LRANGE celery-dlq 0 5 2>/dev/null

# Requeue failed tasks (after fixing the root cause)
# docker exec [celery-container] python -m app.scripts.requeue_dlq
```

---

### INC-08: Disk Space Full

**Symptoms**: Write failures, database crashes, log rotation failures, "No space left on device" errors

**Severity**: SEV1 (if database affected) or SEV2 (if only logs)

**Detection**:
```bash
# Check host disk usage
df -h

# Check Docker disk usage
docker system df

# Check specific volumes
docker volume ls
docker system df -v 2>/dev/null | head -30
```

**Diagnosis**:
```bash
# Step 1: Find largest directories
du -sh /var/lib/docker/* 2>/dev/null | sort -rh | head -10
du -sh /var/log/* 2>/dev/null | sort -rh | head -10

# Step 2: Check Docker container logs size
for container in $(docker ps --format '{{.Names}}'); do
  size=$(docker inspect --format='{{.LogPath}}' "$container" | xargs ls -lh 2>/dev/null | awk '{print $5}')
  echo "$container: $size"
done

# Step 3: Check for large files in project
find . -type f -size +100M 2>/dev/null | head -10

# Step 4: Check database data directory size
docker exec [mysql-container] du -sh /var/lib/mysql 2>/dev/null
docker exec [mongo-container] du -sh /data/db 2>/dev/null
```

**Resolution**:
```bash
# Option A: Clean Docker resources (SAFE - only removes unused items)
docker system prune -f
docker volume prune -f
docker image prune -a -f  # CAUTION: removes all unused images

# Option B: Truncate large log files
truncate -s 0 /var/lib/docker/containers/[container-id]/*-json.log

# Option C: Configure Docker log rotation (permanent fix)
# Create or edit /etc/docker/daemon.json:
# {
#   "log-driver": "json-file",
#   "log-opts": {
#     "max-size": "50m",
#     "max-file": "3"
#   }
# }
# Then: systemctl restart docker

# Option D: Clean application temp files
find /tmp -type f -mtime +7 -delete 2>/dev/null
find . -name "*.pyc" -delete 2>/dev/null
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null

# Option E: Expand storage (cloud)
# AWS: Modify EBS volume size
# GCP: gcloud compute disks resize [disk] --size [new-size]
```

---

## Escalation Matrix

| Severity | First Response | Escalation After | Escalate To | Final Escalation |
|----------|---------------|-------------------|-------------|------------------|
| SEV1 | On-call Engineer | 15 minutes | Engineering Lead | CTO (30 min) |
| SEV2 | On-call Engineer | 30 minutes | Engineering Lead | VP Engineering (1 hr) |
| SEV3 | On-call Engineer | 2 hours | Team Lead | Engineering Lead (4 hr) |
| SEV4 | Next business day | 48 hours | Team Lead | -- |

---

## Communication Templates

### Status Page Update (SEV1/SEV2)
```
Title: [Service] Degradation/Outage
Status: Investigating / Identified / Monitoring / Resolved

[Time UTC] - We are investigating reports of [brief description].
[Time UTC] - We have identified the issue as [root cause summary]. A fix is being deployed.
[Time UTC] - A fix has been deployed. We are monitoring for stability.
[Time UTC] - This incident has been resolved. Total duration: [X] minutes.
```

### Slack #incidents Channel
```
:rotating_light: INCIDENT [SEV level]
What: [1-line description]
Impact: [Who/what is affected]
IC: @[your name]
Status: Investigating
Thread: [link to this thread for updates]
```

### Customer Email (SEV1 Only)
```
Subject: Service Disruption - [Date]

Dear Customer,

We experienced a service disruption on [date] from [start time] to [end time] UTC.

What happened: [Brief, non-technical explanation]
Impact: [What users experienced]
Resolution: [What we did to fix it]
Prevention: [What we are doing to prevent recurrence]

We sincerely apologize for the inconvenience.

[Company Name] Engineering Team
```

---

## Post-Mortem Template

```markdown
# Post-Mortem: [Incident Title]

**Date**: [Date]
**Severity**: SEV[X]
**Duration**: [Start time] to [End time] ([X] minutes)
**Incident Commander**: [Name]
**Author**: [Name]

## Summary
[2-3 sentences describing what happened and the impact]

## Timeline (all times UTC)
| Time | Event |
|------|-------|
| HH:MM | [First detection / alert] |
| HH:MM | [Incident declared, IC assigned] |
| HH:MM | [Key diagnostic step] |
| HH:MM | [Root cause identified] |
| HH:MM | [Fix applied] |
| HH:MM | [Service restored, monitoring] |
| HH:MM | [Incident closed] |

## Root Cause
[Detailed technical explanation of what went wrong and why]

## Impact
- **Users affected**: [Number / percentage]
- **Duration**: [X] minutes
- **Revenue impact**: [If applicable]
- **Data loss**: [Yes/No, details]

## What Went Well
- [Thing 1]
- [Thing 2]

## What Went Poorly
- [Thing 1]
- [Thing 2]

## Action Items
| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
| [Preventive action 1] | [Name] | [Date] | Open |
| [Preventive action 2] | [Name] | [Date] | Open |
| [Monitoring improvement] | [Name] | [Date] | Open |
```
```

---

## Step 3: Generate Maintenance Runbook

Create the file `docs/runbooks/MAINTENANCE.md` with the following structure. Customize all commands and checks based on infrastructure discovered in Step 1.

```markdown
# Maintenance Runbook
**Project**: [project name]
**Generated**: [current date]
**Last Updated**: [current date]

---

## Table of Contents
1. [Daily Tasks](#daily-tasks)
2. [Weekly Tasks](#weekly-tasks)
3. [Monthly Tasks](#monthly-tasks)
4. [Quarterly Tasks](#quarterly-tasks)

---

## Daily Tasks

### Health Checks (Automated or Manual - 5 min)
```bash
#!/bin/bash
# daily-health-check.sh

echo "=== Service Health ==="
curl -sf http://localhost:8000/health && echo " [OK]" || echo " [FAIL]"

echo "=== Database Connectivity ==="
docker exec [mysql-container] mysqladmin ping -u root -p"$MYSQL_ROOT_PASSWORD" 2>&1 | tail -1
docker exec [redis-container] redis-cli ping

echo "=== Disk Usage ==="
df -h / | tail -1
docker system df --format "table {{.Type}}\t{{.Size}}\t{{.Reclaimable}}"

echo "=== Container Status ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -20

echo "=== Error Log Summary (last 24h) ==="
docker logs --since 24h [app-container-name] 2>&1 | grep -ci "error\|exception\|critical"
echo " errors in last 24 hours"

echo "=== Celery Queue Depth ==="
docker exec [redis-container] redis-cli LLEN celery 2>/dev/null || echo "N/A"
```

### Log Review (5 min)
```bash
# Review application errors from last 24 hours
docker logs --since 24h [app-container-name] 2>&1 | grep -i "error\|exception\|critical" | tail -20

# Review database errors
docker logs --since 24h [mysql-container] 2>&1 | grep -i "error\|warning" | tail -10

# Review Celery errors
docker logs --since 24h [celery-container] 2>&1 | grep -i "error\|exception\|retry" | tail -10
```

### Backup Verification (2 min)
```bash
# Verify most recent backup exists and is non-empty
ls -lah /backups/mysql/latest/ 2>/dev/null || echo "No MySQL backups found"
ls -lah /backups/mongodb/latest/ 2>/dev/null || echo "No MongoDB backups found"

# Check backup age (should be < 24 hours)
find /backups/ -name "*.sql.gz" -mtime -1 | head -5
find /backups/ -name "*.archive" -mtime -1 | head -5
```

---

## Weekly Tasks

### Dependency Security Scan (15 min - every Monday)
```bash
# Python dependency audit
pip audit 2>/dev/null || safety check 2>/dev/null

# Check for outdated packages
pip list --outdated 2>/dev/null | head -20

# Node.js dependency audit (if applicable)
npm audit 2>/dev/null
npm outdated 2>/dev/null | head -20

# Docker image vulnerability scan
docker scout cves [image-name]:latest 2>/dev/null || trivy image [image-name]:latest 2>/dev/null
```

### Performance Review (15 min - every Wednesday)
```bash
# Check P95 response times (from Prometheus)
curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,rate(http_request_duration_seconds_bucket[7d]))" 2>/dev/null

# Check error rate for the week
curl -s "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{status=~'5..'}[7d]))/sum(rate(http_requests_total[7d]))" 2>/dev/null

# Check slow queries (MySQL)
docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 20;
" 2>/dev/null

# Check Redis memory usage trend
docker exec [redis-container] redis-cli INFO memory | grep -E "used_memory_human|used_memory_peak_human|maxmemory_human"
```

### Disk Cleanup (10 min - every Friday)
```bash
# Clean Docker build cache
docker builder prune -f --filter "until=168h"

# Remove dangling images
docker image prune -f

# Clean old container logs (keep last 7 days)
find /var/lib/docker/containers/ -name "*.log" -mtime +7 -exec truncate -s 0 {} \; 2>/dev/null

# Clean Python cache
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
find . -name "*.pyc" -delete 2>/dev/null

# Clean temp uploads
find /tmp -type f -mtime +3 -delete 2>/dev/null

# Report freed space
docker system df
```

---

## Monthly Tasks

### SSL Certificate Check (First Monday of month)
```bash
# Check certificate expiry for all domains
for domain in [prod-domain] [staging-domain]; do
  echo "=== $domain ==="
  echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null
  echo ""
done

# Alert if any cert expires within 30 days
for domain in [prod-domain] [staging-domain]; do
  expiry=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry" +%s 2>/dev/null)
  now_epoch=$(date +%s)
  days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
  echo "$domain: $days_left days until expiry"
  if [ "$days_left" -lt 30 ]; then
    echo "  WARNING: Certificate expires in less than 30 days!"
  fi
done
```

### Credential Rotation (Second Monday of month)
```
Checklist:
[ ] Rotate database passwords (MySQL, MongoDB)
[ ] Rotate Redis password
[ ] Rotate API keys (Razorpay, S3, Sentry, etc.)
[ ] Rotate JWT signing secret (will log out all users - schedule during maintenance window)
[ ] Rotate OAuth client secrets
[ ] Update secrets in deployment environment (Docker secrets / K8s secrets / Cloud Secret Manager)
[ ] Verify all services still authenticate after rotation
[ ] Update password manager / vault entries
```

### Load Testing (Third Monday of month)
```bash
# Install k6 or locust if not present
# pip install locust

# Run baseline load test (adjust URL and endpoints)
# Using curl for a basic smoke test:
echo "=== Sequential Load Test (10 requests) ==="
for i in $(seq 1 10); do
  curl -s -o /dev/null -w "Request $i: %{http_code} in %{time_total}s\n" http://localhost:8000/api/v1/[key-endpoint]
done

echo ""
echo "=== Concurrent Load Test (using ab or hey) ==="
# ab -n 100 -c 10 http://localhost:8000/health
# hey -n 200 -c 20 http://localhost:8000/health
```

### Database Maintenance (Last Friday of month)
```bash
# MySQL: Optimize tables
docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
SELECT table_name, data_length/1024/1024 AS data_mb, index_length/1024/1024 AS index_mb
FROM information_schema.tables
WHERE table_schema = '[database_name]'
ORDER BY data_length DESC;
"

# MySQL: Analyze tables for query optimizer
docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
SELECT CONCAT('ANALYZE TABLE ', table_name, ';') FROM information_schema.tables WHERE table_schema = '[database_name]';
"

# MongoDB: Run compact (requires downtime or secondary)
docker exec [mongo-container] mongosh --eval "db.runCommand({compact: '[collection_name]'})" 2>/dev/null

# Redis: Check memory fragmentation
docker exec [redis-container] redis-cli INFO memory | grep "mem_fragmentation_ratio"
```

---

## Quarterly Tasks

### Disaster Recovery Drill (First week of quarter)
```
Checklist:
[ ] Restore database from backup to test environment
[ ] Verify data integrity after restore
[ ] Measure actual RTO (Recovery Time Objective)
[ ] Measure actual RPO (Recovery Point Objective)
[ ] Test DNS failover procedure
[ ] Test service rebuild from scratch
[ ] Document any gaps found
[ ] Update DISASTER_RECOVERY.md with findings
```

### Architecture Review (Mid-quarter)
```
Checklist:
[ ] Review service dependency map - any new single points of failure?
[ ] Review database schema changes - any missing indexes?
[ ] Review API endpoint performance - any endpoints consistently slow?
[ ] Review error rate trends - any systemic issues?
[ ] Review infrastructure costs - any optimization opportunities?
[ ] Review technical debt backlog - prioritize items
[ ] Update architecture diagrams if changed
```

### Capacity Planning (End of quarter)
```
Checklist:
[ ] Review growth metrics (users, requests, data volume)
[ ] Project resource needs for next quarter
[ ] Check database storage growth rate
[ ] Check API traffic growth rate
[ ] Plan scaling actions (vertical/horizontal)
[ ] Budget approval for infrastructure changes
[ ] Update monitoring thresholds based on new baselines
```
```

---

## Step 4: Generate Disaster Recovery Runbook

Create the file `docs/runbooks/DISASTER_RECOVERY.md` with the following structure:

```markdown
# Disaster Recovery Runbook
**Project**: [project name]
**Generated**: [current date]
**Last Updated**: [current date]

---

## Table of Contents
1. [Recovery Objectives](#recovery-objectives)
2. [Backup Strategy](#backup-strategy)
3. [Recovery Procedures](#recovery-procedures)
4. [Service Rebuild from Scratch](#service-rebuild-from-scratch)
5. [DNS Failover](#dns-failover)
6. [Data Consistency Verification](#data-consistency-verification)
7. [Communication Plan](#communication-plan)

---

## Recovery Objectives

| Metric | Target | Actual (Last Drill) |
|--------|--------|---------------------|
| **RPO** (Recovery Point Objective) | 1 hour | [Fill after DR drill] |
| **RTO** (Recovery Time Objective) | 4 hours | [Fill after DR drill] |
| **MTTR** (Mean Time to Recovery) | 2 hours | [Fill after DR drill] |

**RPO = Maximum acceptable data loss**. If RPO is 1 hour, backups must run at least hourly.
**RTO = Maximum acceptable downtime**. If RTO is 4 hours, full service must be restored within 4 hours.

---

## Backup Strategy

### Database Backups

#### MySQL
```bash
# Automated backup script (run via cron every hour)
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/mysql"
DB_NAME="[database_name]"
RETENTION_DAYS=30

mkdir -p "$BACKUP_DIR"

# Full dump with compression
docker exec [mysql-container] mysqldump \
  -u root -p"$MYSQL_ROOT_PASSWORD" \
  --single-transaction \
  --routines \
  --triggers \
  --events \
  "$DB_NAME" | gzip > "$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz"

# Verify backup is non-empty
if [ -s "$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz" ]; then
  echo "Backup successful: ${DB_NAME}_${TIMESTAMP}.sql.gz ($(du -h "$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz" | cut -f1))"
  # Upload to remote storage (S3/GCS)
  # aws s3 cp "$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz" s3://[bucket]/mysql-backups/
  # gsutil cp "$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz" gs://[bucket]/mysql-backups/
else
  echo "BACKUP FAILED: Empty backup file"
  # Send alert
fi

# Clean old backups
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
```

#### MongoDB
```bash
# Automated backup script
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/mongodb"
DB_NAME="[database_name]"
RETENTION_DAYS=30

mkdir -p "$BACKUP_DIR"

# Full dump
docker exec [mongo-container] mongodump \
  --db "$DB_NAME" \
  --archive="/tmp/${DB_NAME}_${TIMESTAMP}.archive" \
  --gzip

docker cp [mongo-container]:/tmp/${DB_NAME}_${TIMESTAMP}.archive "$BACKUP_DIR/"

# Verify and upload
if [ -s "$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.archive" ]; then
  echo "Backup successful: ${DB_NAME}_${TIMESTAMP}.archive"
  # Upload to remote storage
else
  echo "BACKUP FAILED"
fi

find "$BACKUP_DIR" -name "*.archive" -mtime +$RETENTION_DAYS -delete
```

#### Redis (if persistent data)
```bash
# Trigger RDB snapshot
docker exec [redis-container] redis-cli BGSAVE
sleep 5

# Copy dump file
docker cp [redis-container]:/data/dump.rdb /backups/redis/dump_$(date +%Y%m%d_%H%M%S).rdb
```

### Backup Schedule

| Database | Frequency | Retention | Storage |
|----------|-----------|-----------|---------|
| MySQL (full) | Every 1 hour | 30 days | Local + S3/GCS |
| MySQL (binlog) | Continuous | 7 days | Local |
| MongoDB | Every 1 hour | 30 days | Local + S3/GCS |
| Redis | Every 6 hours | 7 days | Local |
| File uploads | Sync to S3/GCS | Indefinite | S3/GCS |

---

## Recovery Procedures

### Procedure 1: MySQL Restore from Backup

```bash
#!/bin/bash
# mysql-restore.sh <backup-file>

BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: ./mysql-restore.sh <backup-file.sql.gz>"
  echo "Available backups:"
  ls -lah /backups/mysql/*.sql.gz | tail -10
  exit 1
fi

echo "WARNING: This will replace all data in [database_name]."
echo "Backup file: $BACKUP_FILE"
echo "Press Ctrl+C to abort, or wait 10 seconds to continue..."
sleep 10

# Step 1: Stop application (prevent writes during restore)
docker stop [app-container-name] [celery-container]

# Step 2: Restore the backup
echo "Restoring from $BACKUP_FILE ..."
gunzip -c "$BACKUP_FILE" | docker exec -i [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" [database_name]

# Step 3: Verify restore
echo "Verifying..."
docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
SELECT COUNT(*) AS user_count FROM [database_name].users;
SELECT COUNT(*) AS total_tables FROM information_schema.tables WHERE table_schema = '[database_name]';
"

# Step 4: Restart application
docker start [app-container-name] [celery-container]

echo "Restore complete. Verify application functionality manually."
```

### Procedure 2: MongoDB Restore from Backup

```bash
#!/bin/bash
# mongodb-restore.sh <backup-file>

BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: ./mongodb-restore.sh <backup-file.archive>"
  echo "Available backups:"
  ls -lah /backups/mongodb/*.archive | tail -10
  exit 1
fi

echo "WARNING: This will replace all data in [database_name]."
sleep 10

# Step 1: Stop application
docker stop [app-container-name] [celery-container]

# Step 2: Copy backup into container
docker cp "$BACKUP_FILE" [mongo-container]:/tmp/restore.archive

# Step 3: Restore
docker exec [mongo-container] mongorestore \
  --archive=/tmp/restore.archive \
  --gzip \
  --drop \
  --db [database_name]

# Step 4: Verify
docker exec [mongo-container] mongosh --eval "
use [database_name];
db.getCollectionNames().forEach(function(c) {
  print(c + ': ' + db[c].countDocuments() + ' documents');
});
"

# Step 5: Restart application
docker start [app-container-name] [celery-container]
```

### Procedure 3: Redis Restore

```bash
# Step 1: Stop Redis
docker stop [redis-container]

# Step 2: Replace dump file
docker cp /backups/redis/[backup-file].rdb [redis-container]:/data/dump.rdb

# Step 3: Restart Redis
docker start [redis-container]

# Step 4: Verify
docker exec [redis-container] redis-cli DBSIZE
```

---

## Service Rebuild from Scratch

If the entire environment is lost, follow this procedure to rebuild from zero.

### Prerequisites
- Access to source code repository (Git)
- Access to backup storage (S3/GCS)
- Access to cloud provider console
- DNS management access
- Environment variables / secrets (from vault or secure storage)

### Rebuild Steps

```bash
# Step 1: Provision infrastructure
# (Use Terraform/Pulumi if available, otherwise manual)
# - Compute instance (VM, Cloud Run, ECS)
# - Database instance (RDS, Cloud SQL, or Docker)
# - Redis instance (ElastiCache, Memorystore, or Docker)
# - Load balancer
# - SSL certificate

# Step 2: Clone repository
git clone [repository-url]
cd [project-directory]
git checkout main

# Step 3: Set up environment variables
# Copy from secure vault/password manager to .env
# Verify all required variables are set:
# DATABASE_URL, REDIS_URL, JWT_SECRET_KEY, RAZORPAY_KEY_ID, etc.

# Step 4: Build and start services
docker-compose build
docker-compose up -d

# Step 5: Run database migrations
docker exec [app-container-name] alembic upgrade head

# Step 6: Restore data from backups
./scripts/mysql-restore.sh /backups/mysql/[latest-backup].sql.gz
./scripts/mongodb-restore.sh /backups/mongodb/[latest-backup].archive

# Step 7: Verify service health
curl -s http://localhost:8000/health
docker exec [mysql-container] mysqladmin ping -u root -p"$MYSQL_ROOT_PASSWORD"
docker exec [redis-container] redis-cli ping

# Step 8: Update DNS (if new IP)
# Update A/CNAME records to point to new infrastructure

# Step 9: Verify SSL
curl -s -o /dev/null -w "%{http_code}" https://[domain]/health

# Step 10: Run smoke tests
# Test key user flows: login, main feature, payment (sandbox)

# Step 11: Monitor closely for 2 hours
# Watch error rates, latency, and resource usage
```

### Estimated Rebuild Times

| Component | Time Estimate |
|-----------|--------------|
| Infrastructure provisioning | 30-60 min |
| Code deployment | 10-15 min |
| Database restore (MySQL) | 15-60 min (depends on size) |
| Database restore (MongoDB) | 15-60 min (depends on size) |
| DNS propagation | 5-60 min (depends on TTL) |
| Smoke testing & verification | 30 min |
| **Total estimated RTO** | **2-4 hours** |

---

## DNS Failover

### If Primary Region Fails

```bash
# Step 1: Verify primary is actually down (not just a monitoring blip)
curl -s -o /dev/null -w "%{http_code}" https://[primary-domain]/health
# Confirm failure from multiple locations

# Step 2: Update DNS to point to failover region
# Using your DNS provider's API or console:

# Cloudflare example:
# curl -X PATCH "https://api.cloudflare.com/client/v4/zones/[zone_id]/dns_records/[record_id]" \
#   -H "Authorization: Bearer [api_token]" \
#   -H "Content-Type: application/json" \
#   --data '{"content":"[failover-ip]"}'

# AWS Route53 example:
# aws route53 change-resource-record-sets --hosted-zone-id [zone_id] --change-batch '{...}'

# Step 3: Lower TTL (if not already low)
# Set TTL to 60 seconds during incident

# Step 4: Verify DNS propagation
dig +short [domain]
nslookup [domain]

# Step 5: Verify failover is serving traffic
curl -s -o /dev/null -w "%{http_code}" https://[domain]/health
```

---

## Data Consistency Verification

After any restore or failover, run these checks:

```bash
#!/bin/bash
# verify-data-consistency.sh

echo "=== MySQL Data Integrity ==="
docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
-- Check table counts
SELECT table_name, table_rows FROM information_schema.tables
WHERE table_schema = '[database_name]' ORDER BY table_rows DESC;

-- Check for corrupted tables
CHECK TABLE users, payments, [other-critical-tables];

-- Verify foreign key relationships
SELECT COUNT(*) AS orphaned_records FROM [child_table] c
LEFT JOIN [parent_table] p ON c.parent_id = p.id
WHERE p.id IS NULL;
"

echo ""
echo "=== MongoDB Data Integrity ==="
docker exec [mongo-container] mongosh --eval "
use [database_name];
// Check collection counts
db.getCollectionNames().forEach(function(c) {
  print(c + ': ' + db[c].countDocuments() + ' documents');
});

// Validate collections
db.getCollectionNames().forEach(function(c) {
  var result = db.runCommand({validate: c});
  print(c + ': ' + (result.valid ? 'VALID' : 'INVALID'));
});
"

echo ""
echo "=== Cross-Database Consistency ==="
# Verify user counts match across MySQL and MongoDB (if applicable)
MYSQL_USERS=$(docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -sN -e "SELECT COUNT(*) FROM [database_name].users;")
MONGO_PROFILES=$(docker exec [mongo-container] mongosh --quiet --eval "use [database_name]; db.user_profiles.countDocuments()")
echo "MySQL users: $MYSQL_USERS"
echo "MongoDB profiles: $MONGO_PROFILES"

echo ""
echo "=== Payment Reconciliation ==="
docker exec [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
SELECT status, COUNT(*), SUM(amount) FROM [database_name].payments
WHERE created_at > NOW() - INTERVAL 24 HOUR
GROUP BY status;
"
```

---

## Communication Plan

### Internal Communication

| Audience | Channel | Frequency | Owner |
|----------|---------|-----------|-------|
| Engineering team | Slack #incidents | Real-time updates | Incident Commander |
| Leadership | Slack #leadership + Email | Every 30 min (SEV1) | Engineering Lead |
| Support team | Slack #support | On status change | Incident Commander |
| All staff | Email | Once at start, once at resolution | Communications |

### External Communication

| Audience | Channel | Frequency | Owner |
|----------|---------|-----------|-------|
| All users | Status page | Every 15 min (SEV1) | Incident Commander |
| Affected users | Email | At start + resolution | Support Lead |
| Enterprise clients | Direct call/email | Within 1 hour | Account Manager |
| Public | Twitter/X | At start + resolution (SEV1 only) | Communications |

### Communication Timeline for Major Disaster

```
T+0 min   : Disaster detected. Incident Commander assigned.
T+5 min   : Internal Slack: "Major incident declared. DR procedure initiated."
T+15 min  : Status page updated: "Investigating service disruption."
T+30 min  : Leadership briefed. Support team notified.
T+60 min  : Customer email sent (if user-facing impact).
T+[ongoing]: Status page updated every 15 minutes.
T+[resolved]: All channels notified of resolution.
T+48 hours : Post-mortem published internally.
T+72 hours : Customer post-mortem summary (if SEV1).
```
```

---

## Step 5: Generate Quick Reference Card

Create the file `docs/runbooks/QUICK_REFERENCE.md` with the following structure:

```markdown
# Quick Reference Card
**Project**: [project name]
**Generated**: [current date]

---

## Emergency Contacts

| Role | Name | Contact | Backup |
|------|------|---------|--------|
| On-Call Engineer | [TBD] | [phone/Slack] | [TBD] |
| Engineering Lead | [TBD] | [phone/Slack] | [TBD] |
| CTO / VP Engineering | [TBD] | [phone/Slack] | [TBD] |
| DevOps / Infrastructure | [TBD] | [phone/Slack] | [TBD] |
| Database Admin | [TBD] | [phone/Slack] | [TBD] |

---

## Service URLs

| Service | Production | Staging |
|---------|-----------|---------|
| Application | https://[prod-domain] | https://[staging-domain] |
| API Base | https://[prod-domain]/api/v1 | https://[staging-domain]/api/v1 |
| Health Check | https://[prod-domain]/health | https://[staging-domain]/health |
| API Docs | https://[prod-domain]/docs | https://[staging-domain]/docs |
| Prometheus | http://[monitoring-host]:9090 | -- |
| Grafana | http://[monitoring-host]:3001 | -- |
| Alertmanager | http://[monitoring-host]:9093 | -- |
| Sentry | https://[sentry-url] | -- |
| PostHog | https://[posthog-url] | -- |

---

## Common Commands

### Service Management
```bash
# Restart all services
docker-compose restart

# Restart specific service
docker restart [container-name]

# View running containers
docker ps

# View logs (last 100 lines, follow)
docker logs --tail 100 -f [container-name]

# Check service health
curl -s http://localhost:8000/health | python -m json.tool

# Scale a service
docker-compose up -d --scale [service]=N
```

### Database Commands
```bash
# MySQL shell
docker exec -it [mysql-container] mysql -u root -p"$MYSQL_ROOT_PASSWORD" [database_name]

# MongoDB shell
docker exec -it [mongo-container] mongosh [database_name]

# Redis CLI
docker exec -it [redis-container] redis-cli

# Run migrations
docker exec [app-container] alembic upgrade head

# Check migration status
docker exec [app-container] alembic current
```

### Cache Management
```bash
# Clear entire Redis cache
docker exec [redis-container] redis-cli FLUSHALL

# Clear specific Redis database
docker exec [redis-container] redis-cli -n [db-number] FLUSHDB

# Check Redis memory usage
docker exec [redis-container] redis-cli INFO memory

# Check cache key count
docker exec [redis-container] redis-cli DBSIZE

# Find keys by pattern
docker exec [redis-container] redis-cli KEYS "cache:*" | head -20
```

### Celery / Background Tasks
```bash
# Check worker status
docker exec [celery-container] celery -A [app] inspect ping

# View active tasks
docker exec [celery-container] celery -A [app] inspect active

# View queue length
docker exec [redis-container] redis-cli LLEN celery

# Purge all pending tasks (CAUTION)
docker exec [celery-container] celery -A [app] purge -f

# Restart workers
docker restart [celery-container]
```

### Deployment
```bash
# Pull latest code and rebuild
git pull origin main
docker-compose build
docker-compose up -d

# Rollback to previous image
docker-compose down
git checkout [previous-commit]
docker-compose build
docker-compose up -d

# Cloud Run deploy
# gcloud run deploy [service] --image [image-uri] --region [region]
```

### Debugging
```bash
# Enter a running container
docker exec -it [container-name] /bin/bash

# Check environment variables
docker exec [container-name] env | sort

# Run a Python shell in the app context
docker exec -it [app-container] python

# Check network connectivity from container
docker exec [app-container] curl -s http://[other-service]:port/health

# Check DNS resolution inside container
docker exec [app-container] nslookup [hostname]
```

---

## Monitoring Dashboards

| Dashboard | URL | Purpose |
|-----------|-----|---------|
| Application Overview | [Grafana URL]/d/app-overview | Request rate, error rate, latency |
| API Performance | [Grafana URL]/d/api-performance | Per-endpoint metrics |
| Database | [Grafana URL]/d/database | Query performance, connections |
| Infrastructure | [Grafana URL]/d/infrastructure | CPU, memory, disk, network |
| Celery | [Grafana URL]/d/celery | Task throughput, failures |

---

## Useful Shell Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Project shortcuts
alias dc="docker-compose"
alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
alias dlogs="docker logs --tail 100 -f"

# Quick health check
alias hc="curl -s http://localhost:8000/health | python -m json.tool"

# Database shells
alias mysh="docker exec -it [mysql-container] mysql -u root -p'$MYSQL_ROOT_PASSWORD' [database_name]"
alias mgsh="docker exec -it [mongo-container] mongosh [database_name]"
alias rdsh="docker exec -it [redis-container] redis-cli"

# Quick restart
alias restart-app="docker restart [app-container-name]"
alias restart-celery="docker restart [celery-container]"
alias restart-all="docker-compose restart"

# Monitoring
alias errors="docker logs --since 1h [app-container-name] 2>&1 | grep -i error | tail -20"
alias slow="docker exec [mysql-container] mysql -u root -p'$MYSQL_ROOT_PASSWORD' -e 'SHOW PROCESSLIST;'"
alias qlen="docker exec [redis-container] redis-cli LLEN celery"
```

---

## Key File Locations

| What | Path |
|------|------|
| Application code | `./app/` |
| Docker configuration | `./docker/` or `./docker-compose.yml` |
| Environment variables | `./.env` |
| Database migrations | `./alembic/` or `./migrations/` |
| Backup scripts | `./scripts/backup/` |
| Monitoring config | `./monitoring/` |
| Nginx config | `./nginx/` or `./docker/nginx/` |
| SSL certificates | `/etc/letsencrypt/` or managed by cloud provider |
| Application logs | `docker logs [container]` or `./logs/` |
| Runbooks (this file) | `./docs/runbooks/` |
```

---

## Step 6: Output Summary

After generating all files, display a summary:

```
========================================================
  OPERATIONAL RUNBOOKS GENERATED
========================================================

  Files Created:
  -------------------------------------------------------
  docs/runbooks/INCIDENT_RESPONSE.md
    - 8 incident playbooks (API, DB, latency, memory,
      auth, payments, Celery, disk)
    - 4 severity levels with response times
    - On-call procedures and escalation matrix
    - Communication templates
    - Post-mortem template

  docs/runbooks/MAINTENANCE.md
    - Daily: health checks, log review, backup verification
    - Weekly: security scan, performance review, disk cleanup
    - Monthly: SSL check, credential rotation, load testing
    - Quarterly: DR drill, architecture review, capacity planning

  docs/runbooks/DISASTER_RECOVERY.md
    - RPO/RTO targets defined
    - MySQL/MongoDB/Redis backup & restore procedures
    - Full service rebuild from scratch procedure
    - DNS failover procedure
    - Data consistency verification scripts
    - Communication plan with timeline

  docs/runbooks/QUICK_REFERENCE.md
    - Emergency contacts (fill in your team)
    - Service URLs (prod, staging, monitoring)
    - Common commands (restart, logs, cache, DB)
    - Monitoring dashboard links
    - Shell aliases for quick access

  Infrastructure Detected:
  -------------------------------------------------------
  [List services, databases, external services found]

  Next Steps:
  -------------------------------------------------------
  1. Fill in placeholder values (container names, domains,
     database names) with your actual values
  2. Fill in the Emergency Contacts table
  3. Set up automated backup scripts from DISASTER_RECOVERY.md
  4. Schedule maintenance tasks (cron or CI pipeline)
  5. Run a DR drill to establish actual RTO/RPO baselines
  6. Share runbooks with the team and review together
  7. Set a reminder to update these runbooks quarterly

========================================================
```

Report the discovered infrastructure details and confirm which runbook types were generated based on $ARGUMENTS.
