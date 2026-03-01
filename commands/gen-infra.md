---
description: "Generate Infrastructure as Code: Docker Compose, Kubernetes manifests, K3s manifests, Terraform configs, or Helm charts. Usage: /gen-infra [docker|k8s|k3s|terraform|helm] [--env=production]"
---

# Infrastructure as Code Generator

Target: **$ARGUMENTS**

Parse `$ARGUMENTS` to extract:
- **Infrastructure type**: `docker` | `k8s` | `k3s` | `terraform` | `helm` (default: `docker`)
- **Environment**: `--env=development` | `--env=staging` | `--env=production` (default: `development`)

If `$ARGUMENTS` is empty, default to `docker --env=development`.

---

## Step 1: Detect Application Services

Scan the project to identify all services. Run these in parallel using Agent tool (mode = "bypassPermissions"):

### Scan 1: Backend Detection
```bash
echo "=== Python/FastAPI Backend ==="
ls -la app/ src/ backend/ 2>/dev/null
cat requirements*.txt pyproject.toml setup.py 2>/dev/null | head -100

echo ""
echo "=== Node.js/NestJS Backend ==="
ls -la src/main.ts nest-cli.json 2>/dev/null
cat package.json 2>/dev/null | grep -E "nestjs|@nestjs" | head -20

echo ""
echo "=== Java/Spring Boot Backend ==="
ls -la build.gradle.kts pom.xml src/main/java 2>/dev/null
cat build.gradle.kts 2>/dev/null | head -50

echo ""
echo "=== Dockerfile ==="
ls -la Dockerfile docker/Dockerfile 2>/dev/null

echo ""
echo "=== Node/Next.js Frontend ==="
ls -la frontend/ web/ client/ next.config* package.json 2>/dev/null
cat package.json 2>/dev/null | head -50
```

### Scan 2: Database & Services Detection
```bash
echo "=== Database Configs ==="
grep -rn "mysql\|MySQL\|asyncmy\|sqlalchemy" . --include="*.py" --include="*.toml" --include="*.txt" -l 2>/dev/null | head -10
grep -rn "mongo\|MongoDB\|beanie\|motor\|pymongo" . --include="*.py" --include="*.toml" --include="*.txt" -l 2>/dev/null | head -10
grep -rn "redis\|Redis" . --include="*.py" --include="*.toml" --include="*.txt" -l 2>/dev/null | head -10

echo ""
echo "=== Additional Services ==="
grep -rn "meilisearch\|MeiliSearch" . --include="*.py" --include="*.toml" --include="*.txt" -l 2>/dev/null | head -5
grep -rn "celery\|Celery" . --include="*.py" --include="*.toml" --include="*.txt" -l 2>/dev/null | head -5
grep -rn "minio\|MinIO\|S3\|boto3" . --include="*.py" --include="*.toml" --include="*.txt" -l 2>/dev/null | head -5
grep -rn "qdrant\|Qdrant" . --include="*.py" --include="*.toml" --include="*.txt" -l 2>/dev/null | head -5
grep -rn "langfuse\|Langfuse" . --include="*.py" --include="*.toml" --include="*.txt" -l 2>/dev/null | head -5
grep -rn "flower" . --include="*.py" --include="*.toml" --include="*.txt" -l 2>/dev/null | head -5
```

### Scan 3: Existing Infrastructure
```bash
echo "=== Existing Docker/K8s/Terraform ==="
ls -la docker-compose*.yml docker-compose*.yaml 2>/dev/null
ls -la Dockerfile* docker/Dockerfile* 2>/dev/null
ls -la k8s/ kubernetes/ 2>/dev/null
ls -la terraform/ infra/ 2>/dev/null
ls -la helm/ charts/ 2>/dev/null
ls -la .env* 2>/dev/null
ls -la nginx/ nginx.conf 2>/dev/null
```

### Service Registry

Build a service registry from the scan results. The full Alpha AI stack includes these services:

| Service | Image | Internal Port | Health Endpoint |
|---------|-------|---------------|-----------------|
| Backend (FastAPI\|NestJS\|Spring Boot) | Custom build | 8000\|3000\|8080 | `/health` |
| Frontend (Next.js) | Custom build | 3000 | `/api/health` |
| MySQL 8.0 | `mysql:8.0` | 3306 | `mysqladmin ping` |
| MongoDB 7 | `mongo:7` | 27017 | `mongosh --eval "db.adminCommand('ping')"` |
| Redis 7 | `redis:7-alpine` | 6379 | `redis-cli ping` |
| Meilisearch | `getmeili/meilisearch:v1.6` | 7700 | `/health` |
| Task Worker (Celery\|BullMQ\|Spring @Async) | Custom build | N/A | Framework-specific |
| Task Scheduler (Beat\|BullMQ\|@Scheduled) | Custom build | N/A | PID/health check |
| Flower (Python only) | `mher/flower:2.0` | 5555 | `/healthcheck` |
| MinIO | `minio/minio:latest` | 9000/9001 | `/minio/health/live` |
| Qdrant | `qdrant/qdrant:v1.7` | 6333/6334 | `/healthz` |
| Langfuse | `langfuse/langfuse:2` | 3100 | `/api/public/health` |
| Nginx | `nginx:1.25-alpine` | 80/443 | `curl localhost` |
| Prometheus | `prom/prometheus:latest` | 9090 | `/-/healthy` |
| Grafana | `grafana/grafana:latest` | 3001 | `/api/health` |

Only include services that are detected in the project scan. If a service is referenced in code but has no existing configuration, include it with sensible defaults.

---

## Step 2: Docker Compose Generation (docker)

**Only execute this step if the infrastructure type is `docker`.**

Generate three environment-specific Docker Compose files plus a shared base, Dockerfiles, and environment templates.

### 2.1: Backend Dockerfile

Create `docker/Dockerfile.backend`:
```dockerfile
# ==============================================================================
# Multi-stage build for FastAPI backend
# ==============================================================================

# Stage 1: Base with dependencies
FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements*.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Development (with hot-reload tools)
FROM base AS development

RUN pip install --no-cache-dir debugpy watchfiles
COPY . .
EXPOSE 8000 5678

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

# Stage 3: Production (optimized)
FROM base AS production

COPY . .

RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4", "--loop", "uvloop", "--http", "httptools"]
```

### 2.2: Frontend Dockerfile

Create `docker/Dockerfile.frontend`:
```dockerfile
# ==============================================================================
# Multi-stage build for Next.js frontend
# ==============================================================================

# Stage 1: Dependencies
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* yarn.lock* pnpm-lock.yaml* ./
RUN \
    if [ -f yarn.lock ]; then yarn install --frozen-lockfile; \
    elif [ -f package-lock.json ]; then npm ci; \
    elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm install --frozen-lockfile; \
    else npm install; \
    fi

# Stage 2: Development
FROM node:20-alpine AS development
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
ENV NEXT_TELEMETRY_DISABLED=1
CMD ["npm", "run", "dev"]

# Stage 3: Builder
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# Stage 4: Production
FROM node:20-alpine AS production
WORKDIR /app

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
ENV PORT=3000 HOSTNAME="0.0.0.0"

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

CMD ["node", "server.js"]
```

### 2.3: Nginx Configuration

Create `docker/nginx/nginx.conf`:
```nginx
upstream backend {
    server backend:8000;
}

upstream frontend {
    server frontend:3000;
}

server {
    listen 80;
    server_name _;
    client_max_body_size 100M;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # API routes -> Backend
    location /api/ {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # WebSocket support
    location /ws/ {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400;
    }

    # Health endpoint
    location /health {
        proxy_pass http://backend/health;
    }

    # Metrics (internal only in production)
    location /metrics {
        proxy_pass http://backend/metrics;
    }

    # Flower (Celery monitoring)
    location /flower/ {
        proxy_pass http://flower:5555/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # MinIO console
    location /minio-console/ {
        proxy_pass http://minio:9001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Everything else -> Frontend
    location / {
        proxy_pass http://frontend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;
}
```

### 2.4: Development Docker Compose

Create `docker-compose.yml` (development environment):

**Requirements for development compose:**
- All services with hot-reload enabled
- Volume mounts for live code editing on backend and frontend
- Debug ports exposed (e.g., 5678 for debugpy)
- Seed data scripts on startup via init volumes
- All ports mapped to host for direct access
- No resource limits (allow unrestricted local development)
- `restart: unless-stopped` on infrastructure services only
- Named volumes for database data persistence
- Single shared network `app-network`
- Environment variables loaded from `.env` file
- MySQL init scripts mounted from `docker/mysql/init/`
- MongoDB init scripts mounted from `docker/mongo/init/`
- Redis persistence enabled with AOF
- Meilisearch with master key from env
- MinIO with default dev credentials
- Qdrant with in-memory storage for fast dev
- Langfuse connected to shared Postgres (or its own SQLite for dev)
- Celery worker with `--autoreload` for development
- Celery Beat with the database scheduler
- Flower with auto-refresh

**Service definitions must include these exact services (adjust based on scan):**

1. **backend** - FastAPI with uvicorn `--reload`, volume mount `./app:/app/app`, debugpy port 5678
2. **frontend** - Next.js with `npm run dev`, volume mount `./frontend:/app`, port 3000
3. **mysql** - MySQL 8.0 with init scripts, port 3306, named volume `mysql_data`
4. **mongodb** - MongoDB 7 with init scripts, port 27017, named volume `mongo_data`
5. **redis** - Redis 7 Alpine with AOF persistence, port 6379, named volume `redis_data`
6. **meilisearch** - Meilisearch latest with master key, port 7700, named volume `meili_data`
7. **celery-worker** - Same image as backend, command overrides to `celery -A app.celery_app worker`, depends on redis + backend
8. **celery-beat** - Same image as backend, command overrides to `celery -A app.celery_app beat`, depends on redis
9. **flower** - Flower for Celery monitoring, port 5555, depends on redis + celery-worker
10. **minio** - MinIO object storage, ports 9000 + 9001 (console), named volume `minio_data`
11. **qdrant** - Qdrant vector DB, ports 6333 + 6334, named volume `qdrant_data`
12. **langfuse** - Langfuse AI observability, port 3100, depends on database
13. **nginx** - Nginx reverse proxy, ports 80 + 443, depends on backend + frontend

**Every infrastructure service (MySQL, MongoDB, Redis, Meilisearch, MinIO, Qdrant) must have:**
- A proper `healthcheck` block with `test`, `interval`, `timeout`, `start_period`, `retries`
- `depends_on` with `condition: service_healthy` where applicable
- Named volumes for data persistence

**Example healthcheck for MySQL:**
```yaml
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p$$MYSQL_ROOT_PASSWORD"]
  interval: 10s
  timeout: 5s
  start_period: 30s
  retries: 5
```

### 2.5: Production Docker Compose

Create `docker-compose.prod.yml` (production environment):

**Requirements for production compose:**
- Multi-stage build targets (`target: production` in build context)
- Resource limits on ALL services (CPU + memory via `deploy.resources.limits`)
- Health checks on ALL services (stricter intervals than dev)
- `restart: always` on all services
- No debug ports exposed
- No volume mounts for source code (code baked into image)
- Secrets management via Docker secrets or environment file
- Logging drivers configured (`json-file` with `max-size` and `max-file`)
- Read-only root filesystem where possible (`read_only: true`)
- Security options: `no-new-privileges: true`
- Named volumes for persistent data only
- Network isolation: separate `frontend-network` and `backend-network`
- Backend + Nginx on both networks, databases on backend-network only

**Resource limits per service (production):**
| Service | CPU Limit | Memory Limit | Memory Reservation |
|---------|-----------|--------------|-------------------|
| Backend | 2.0 | 1G | 512M |
| Frontend | 1.0 | 512M | 256M |
| MySQL | 2.0 | 2G | 1G |
| MongoDB | 2.0 | 2G | 1G |
| Redis | 1.0 | 512M | 256M |
| Meilisearch | 1.0 | 1G | 512M |
| Celery Worker | 2.0 | 1G | 512M |
| Celery Beat | 0.5 | 256M | 128M |
| Flower | 0.5 | 256M | 128M |
| MinIO | 1.0 | 1G | 512M |
| Qdrant | 1.0 | 1G | 512M |
| Langfuse | 1.0 | 512M | 256M |
| Nginx | 0.5 | 256M | 128M |
| Prometheus | 1.0 | 1G | 512M |
| Grafana | 0.5 | 512M | 256M |

**Logging configuration for every service:**
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### 2.6: Testing Docker Compose

Create `docker-compose.test.yml` (CI/testing environment):

**Requirements for testing compose:**
- Ephemeral containers (no named volumes, data does not persist)
- Test database with fixtures loaded on startup
- CI-optimized: no volume mounts, minimal ports exposed
- Lighter resource limits than production
- `--rm` friendly (containers clean up after themselves)
- Backend runs with `pytest` as entrypoint instead of uvicorn
- Test-specific environment variables (test database names, mock API keys)
- Only essential services: backend, MySQL, MongoDB, Redis (no monitoring, no Nginx)
- `tmpfs` for database data (fast, ephemeral)

---

## Step 3: Kubernetes Manifests (k8s)

**Only execute this step if the infrastructure type is `k8s`.**

Generate a complete `k8s/` directory using Kustomize for environment overlays.

### 3.1: Directory Structure

```
k8s/
+-- base/
|   +-- namespace.yaml
|   +-- backend-deployment.yaml
|   +-- backend-service.yaml
|   +-- backend-hpa.yaml
|   +-- frontend-deployment.yaml
|   +-- frontend-service.yaml
|   +-- frontend-hpa.yaml
|   +-- celery-deployment.yaml
|   +-- celery-beat-deployment.yaml
|   +-- mysql-statefulset.yaml
|   +-- mysql-service.yaml
|   +-- mongodb-statefulset.yaml
|   +-- mongodb-service.yaml
|   +-- redis-deployment.yaml
|   +-- redis-service.yaml
|   +-- meilisearch-deployment.yaml
|   +-- meilisearch-service.yaml
|   +-- minio-statefulset.yaml
|   +-- minio-service.yaml
|   +-- qdrant-statefulset.yaml
|   +-- qdrant-service.yaml
|   +-- ingress.yaml
|   +-- configmap.yaml
|   +-- secrets.yaml
|   +-- network-policies.yaml
|   +-- pdb.yaml
|   +-- kustomization.yaml
+-- overlays/
    +-- staging/
    |   +-- kustomization.yaml
    |   +-- patches/
    |       +-- backend-replicas.yaml
    |       +-- resource-limits.yaml
    |       +-- ingress-host.yaml
    +-- production/
        +-- kustomization.yaml
        +-- patches/
            +-- backend-replicas.yaml
            +-- resource-limits.yaml
            +-- ingress-host.yaml
            +-- hpa-scaling.yaml
```

### 3.2: Namespace

Create `k8s/base/namespace.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: alpha-app
  labels:
    app.kubernetes.io/part-of: alpha-platform
    app.kubernetes.io/managed-by: kustomize
```

### 3.3: Backend Deployment

Create `k8s/base/backend-deployment.yaml` with:
- `replicas: 2` (base, overridden per environment)
- Container image placeholder `IMAGE_REGISTRY/backend:IMAGE_TAG`
- Resource requests: `cpu: 250m, memory: 256Mi`
- Resource limits: `cpu: "1", memory: 1Gi`
- Liveness probe: HTTP GET `/health`, `initialDelaySeconds: 30`, `periodSeconds: 10`
- Readiness probe: HTTP GET `/health`, `initialDelaySeconds: 15`, `periodSeconds: 5`
- Startup probe: HTTP GET `/health`, `initialDelaySeconds: 10`, `failureThreshold: 30`, `periodSeconds: 5`
- Environment variables from ConfigMap and Secret references
- Pod anti-affinity: `preferredDuringSchedulingIgnoredDuringExecution` with `topologyKey: kubernetes.io/hostname`
- Security context: `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`
- `topologySpreadConstraints` to spread across nodes
- Volume mount for `/tmp` (emptyDir, since rootfs is read-only)

### 3.4: Backend Service

Create `k8s/base/backend-service.yaml`:
- `type: ClusterIP`
- Port 8000 targeting container port 8000
- Selector matching backend deployment labels

### 3.5: Frontend Deployment & Service

Follow same pattern as backend but with:
- Container port 3000
- Different health endpoint `/api/health`
- Lower resource requests/limits

### 3.6: StatefulSets for Databases

Create StatefulSets (NOT Deployments) for MySQL, MongoDB, MinIO, and Qdrant:
- `volumeClaimTemplates` with storage class placeholder
- Persistent storage: MySQL 20Gi, MongoDB 20Gi, MinIO 50Gi, Qdrant 10Gi
- Headless services for stable network identities
- Init containers for permission setup where needed
- Anti-affinity to spread database pods across nodes

### 3.7: Redis Deployment

Redis can use a Deployment (not StatefulSet) for caching use cases:
- Single replica in base (override for HA in production)
- Optional persistence via PVC
- Memory limit matching Kubernetes resource limit

### 3.8: Celery Worker Deployment

- Same image as backend
- Command override: `["celery", "-A", "app.celery_app", "worker", "--loglevel=info", "--concurrency=4"]`
- No service needed (workers do not receive traffic)
- Resource limits: CPU 1, memory 1Gi
- Liveness probe: `celery -A app.celery_app inspect ping`

### 3.9: Celery Beat Deployment

- Single replica ONLY (never scale Beat beyond 1)
- Command override: `["celery", "-A", "app.celery_app", "beat", "--loglevel=info"]`
- `strategy: Recreate` (not RollingUpdate, to avoid duplicate schedulers)

### 3.10: Ingress

Create `k8s/base/ingress.yaml`:
- Ingress class: `nginx` (configurable)
- TLS termination with cert-manager annotation: `cert-manager.io/cluster-issuer: letsencrypt-prod`
- Host placeholder `APP_DOMAIN`
- Path rules: `/api/*` to backend service, `/ws/*` to backend service, `/*` to frontend service
- Annotations for rate limiting, body size, proxy timeouts

### 3.11: ConfigMap

Create `k8s/base/configmap.yaml` with non-sensitive configuration:
- `APP_ENV`, `APP_NAME`, `APP_DEBUG`
- `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_DATABASE`
- `MONGODB_HOST`, `MONGODB_PORT`, `MONGODB_DATABASE`
- `REDIS_HOST`, `REDIS_PORT`
- `MEILISEARCH_HOST`, `MEILISEARCH_PORT`
- `MINIO_ENDPOINT`, `MINIO_BUCKET`
- `QDRANT_HOST`, `QDRANT_PORT`
- `CELERY_BROKER_URL`

### 3.12: Secrets

Create `k8s/base/secrets.yaml` with placeholder values (base64 encoded):
- `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`
- `MONGODB_PASSWORD`
- `REDIS_PASSWORD`
- `MEILISEARCH_MASTER_KEY`
- `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`
- `JWT_SECRET_KEY`
- `APP_SECRET_KEY`

Include a comment: `# WARNING: Replace placeholder values. In production use sealed-secrets, external-secrets, or vault.`

### 3.13: Horizontal Pod Autoscaler

Create `k8s/base/backend-hpa.yaml` and `k8s/base/frontend-hpa.yaml`:
- `minReplicas: 2`, `maxReplicas: 10` (base, overridden per env)
- Target CPU utilization: 70%
- Target memory utilization: 80%
- Scale-down stabilization: 300s
- Scale-up policy: max 2 pods per 60s

### 3.14: Pod Disruption Budget

Create `k8s/base/pdb.yaml`:
- Backend: `minAvailable: 1`
- Frontend: `minAvailable: 1`
- MySQL: `minAvailable: 1`
- Redis: `minAvailable: 1`

### 3.15: Network Policies

Create `k8s/base/network-policies.yaml`:
- Default deny all ingress in the namespace
- Allow backend to access MySQL, MongoDB, Redis, Meilisearch, MinIO, Qdrant
- Allow frontend to access backend only
- Allow ingress controller to access frontend and backend
- Allow Celery workers to access Redis and backend services
- Deny direct external access to databases

### 3.16: Kustomization Files

Create `k8s/base/kustomization.yaml` listing all resources.

Create `k8s/overlays/staging/kustomization.yaml`:
- Base reference: `../../base`
- Namespace override: `alpha-app-staging`
- Common labels: `env: staging`
- Patches: 2 replicas backend, 1 replica frontend, reduced resource limits
- Image transformer with staging registry/tag

Create `k8s/overlays/production/kustomization.yaml`:
- Base reference: `../../base`
- Namespace override: `alpha-app-production`
- Common labels: `env: production`
- Patches: 4 replicas backend, 2 replicas frontend, full resource limits, HPA max 20
- Image transformer with production registry/tag

---

## Step 3B: K3s Manifests (k3s)

**Only execute this step if the infrastructure type is `k3s`.**

> **IMPORTANT: Before generating K3s manifests, Claude MUST ask the user for their infrastructure configuration.** Prompt the user for the following values (provide sensible defaults where appropriate):
>
> | Variable | Description | Example |
> |----------|-------------|---------|
> | `${REGISTRY_IP}` | Private Docker registry IP | `10.0.0.4` |
> | `${REGISTRY_PORT}` | Private Docker registry port | `5000` |
> | `${DB_NODE_IP}` | Database node IP (MySQL/MongoDB) | `10.0.0.4` |
> | `${REDIS_NODE_IP}` | Redis node IP | `10.0.0.3` |
> | `${GATEWAY_NODE_IP}` | Gateway/edge node IP | `10.0.0.1` |
> | `${APP_NODE_IP}` | Application node IP | `10.0.0.2` |
> | `${RUNNER_NAME}` | GitHub Actions self-hosted runner name | `alpha-runner` |
> | `${YOUR_DOMAIN}` | Base domain for the application | `alphaaidev.cloud` |
> | `${ORG_NAME}` | GitHub organization or project org name | `alphaai` |
>
> Use the user's answers to fill in these placeholders throughout the generated manifests. If the user declines to provide values, use the placeholder variables literally (e.g., `${REGISTRY_IP}`) so they can be filled in later.

Generate a flat `k8s/` directory with combined manifests optimized for a VPS + K3s cluster. This uses Traefik IngressRoute (not nginx Ingress), external databases on dedicated VPS nodes (not StatefulSets), a private Docker registry at `${REGISTRY_IP}:${REGISTRY_PORT}`, no cert-manager (SSL terminates at HAProxy), and no Kustomize overlays.

### 3B.1: Directory Structure

```
k8s/
+-- backend.yaml          # Deployment + Service + IngressRoute + Secret
+-- celery.yaml           # Worker + Beat Deployments (if Celery detected)
+-- frontend.yaml         # Deployment + Service + IngressRoute (if frontend detected)
```

### 3B.2: backend.yaml

Create `k8s/backend.yaml` containing four resources in a single file (separated by `---`):

```yaml
# ==============================================================================
# Backend Secret — database credentials & app secrets
# Uses external databases on dedicated VPS nodes via WireGuard network
# ==============================================================================
apiVersion: v1
kind: Secret
metadata:
  name: APP_NAME-backend-secret
  namespace: APP_NAME
type: Opaque
stringData:
  DATABASE_URL: "mysql+asyncmy://APP_NAME_user:CHANGE_ME@${DB_NODE_IP}:3306/APP_NAME_db"
  MONGODB_URL: "mongodb://APP_NAME_user:CHANGE_ME@${DB_NODE_IP}:27017/APP_NAME_db?authSource=admin"
  REDIS_URL: "redis://${REDIS_NODE_IP}:6379/0"
  CELERY_BROKER_URL: "redis://${REDIS_NODE_IP}:6379/1"
  SECRET_KEY: "GENERATE_WITH_openssl_rand_hex_32"
  # Add additional secrets as needed:
  # JWT_SECRET_KEY: "GENERATE_WITH_openssl_rand_hex_64"
  # MEILISEARCH_MASTER_KEY: ""
  # MINIO_ACCESS_KEY: ""
  # MINIO_SECRET_KEY: ""

---
# ==============================================================================
# Backend Deployment
# Image pulled from private registry at ${REGISTRY_IP}:${REGISTRY_PORT}
# ==============================================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: APP_NAME-backend
  namespace: APP_NAME
  labels:
    app: APP_NAME-backend
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app: APP_NAME-backend
  template:
    metadata:
      labels:
        app: APP_NAME-backend
    spec:
      containers:
        - name: backend
          image: ${REGISTRY_IP}:${REGISTRY_PORT}/APP_NAME-backend:latest
          imagePullPolicy: Always
          ports:
            - containerPort: APP_PORT
              name: http
          envFrom:
            - secretRef:
                name: APP_NAME-backend-secret
          env:
            - name: APP_ENV
              value: "production"
            - name: APP_PORT
              value: "APP_PORT"
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: "1"
              memory: 1Gi
          readinessProbe:
            httpGet:
              path: /health
              port: APP_PORT
            initialDelaySeconds: 15
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /health
              port: APP_PORT
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3

---
# ==============================================================================
# Backend Service (ClusterIP — Traefik routes to this)
# ==============================================================================
apiVersion: v1
kind: Service
metadata:
  name: APP_NAME-backend
  namespace: APP_NAME
spec:
  type: ClusterIP
  selector:
    app: APP_NAME-backend
  ports:
    - port: 80
      targetPort: APP_PORT
      protocol: TCP

---
# ==============================================================================
# Backend IngressRoute (Traefik — replaces nginx Ingress)
# SSL terminates at HAProxy, NOT here — entryPoints: web only
# ==============================================================================
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: APP_NAME-backend
  namespace: APP_NAME
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`APP_DOMAIN`)
      kind: Rule
      services:
        - name: APP_NAME-backend
          port: 80
```

**Placeholder replacements:**
- `APP_NAME` — detected project name (e.g., `myapp`)
- `APP_PORT` — detected backend port from scan (default: `8000`)
- `APP_DOMAIN` — application domain (e.g., `api.example.com`)
- `CHANGE_ME` — must be replaced with real passwords before deploy

### 3B.3: celery.yaml

**Only generate this file if Celery is detected in the project scan (Step 1).**

Create `k8s/celery.yaml` containing two Deployments:

```yaml
# ==============================================================================
# Celery Worker Deployment
# Same image as backend, command override to run worker
# ==============================================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: APP_NAME-celery-worker
  namespace: APP_NAME
  labels:
    app: APP_NAME-celery-worker
spec:
  replicas: 2
  selector:
    matchLabels:
      app: APP_NAME-celery-worker
  template:
    metadata:
      labels:
        app: APP_NAME-celery-worker
    spec:
      containers:
        - name: celery-worker
          image: ${REGISTRY_IP}:${REGISTRY_PORT}/APP_NAME-backend:latest
          imagePullPolicy: Always
          command: ["celery", "-A", "app.celery_app", "worker", "--loglevel=info", "--concurrency=4"]
          envFrom:
            - secretRef:
                name: APP_NAME-backend-secret
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: "1"
              memory: 1Gi
          livenessProbe:
            exec:
              command:
                - celery
                - "-A"
                - app.celery_app
                - inspect
                - ping
                - --timeout
                - "10"
            initialDelaySeconds: 30
            periodSeconds: 30
            timeoutSeconds: 15
            failureThreshold: 3

---
# ==============================================================================
# Celery Beat Deployment (scheduler)
# IMPORTANT: Only 1 replica — never scale Beat beyond 1
# ==============================================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: APP_NAME-celery-beat
  namespace: APP_NAME
  labels:
    app: APP_NAME-celery-beat
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: APP_NAME-celery-beat
  template:
    metadata:
      labels:
        app: APP_NAME-celery-beat
    spec:
      containers:
        - name: celery-beat
          image: ${REGISTRY_IP}:${REGISTRY_PORT}/APP_NAME-backend:latest
          imagePullPolicy: Always
          command: ["celery", "-A", "app.celery_app", "beat", "--loglevel=info"]
          envFrom:
            - secretRef:
                name: APP_NAME-backend-secret
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 250m
              memory: 256Mi
```

### 3B.4: frontend.yaml

**Only generate this file if a frontend (Next.js, React, etc.) is detected in the project scan (Step 1).**

Create `k8s/frontend.yaml` containing three resources:

```yaml
# ==============================================================================
# Frontend Deployment
# ==============================================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: APP_NAME-frontend
  namespace: APP_NAME
  labels:
    app: APP_NAME-frontend
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app: APP_NAME-frontend
  template:
    metadata:
      labels:
        app: APP_NAME-frontend
    spec:
      containers:
        - name: frontend
          image: ${REGISTRY_IP}:${REGISTRY_PORT}/APP_NAME-frontend:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 3000
              name: http
          env:
            - name: NODE_ENV
              value: "production"
            - name: NEXT_PUBLIC_API_URL
              value: "https://APP_API_DOMAIN"
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          readinessProbe:
            httpGet:
              path: /api/health
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /api/health
              port: 3000
            initialDelaySeconds: 20
            periodSeconds: 10

---
# ==============================================================================
# Frontend Service (ClusterIP)
# ==============================================================================
apiVersion: v1
kind: Service
metadata:
  name: APP_NAME-frontend
  namespace: APP_NAME
spec:
  type: ClusterIP
  selector:
    app: APP_NAME-frontend
  ports:
    - port: 80
      targetPort: 3000
      protocol: TCP

---
# ==============================================================================
# Frontend IngressRoute (Traefik — separate subdomain or path)
# ==============================================================================
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: APP_NAME-frontend
  namespace: APP_NAME
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`APP_FRONTEND_DOMAIN`)
      kind: Rule
      services:
        - name: APP_NAME-frontend
          port: 80
```

**Additional placeholder:**
- `APP_FRONTEND_DOMAIN` — frontend domain (e.g., `app.example.com` or `example.com`)
- `APP_API_DOMAIN` — backend API domain for the frontend to call (e.g., `api.example.com`)

### 3B.5: CI/CD Workflow

Also generate the CI/CD workflow for K3s deployment. See `/gen-ci --k3s` or load `INFRA_HOSTINGER_K3S.md` for the `deploy.yml` template that builds, pushes to the private registry at `${REGISTRY_IP}:${REGISTRY_PORT}`, and runs `kubectl apply` over SSH.

---

## Step 4: Terraform Configuration (terraform)

**Only execute this step if the infrastructure type is `terraform`.**

Generate a modular Terraform configuration targeting AWS (primary) with clear extension points for GCP.

### 4.1: Directory Structure

```
terraform/
+-- main.tf
+-- variables.tf
+-- outputs.tf
+-- providers.tf
+-- backend.tf
+-- versions.tf
+-- terraform.tfvars.example
+-- environments/
|   +-- staging.tfvars
|   +-- production.tfvars
+-- modules/
    +-- vpc/
    |   +-- main.tf
    |   +-- variables.tf
    |   +-- outputs.tf
    +-- database/
    |   +-- main.tf
    |   +-- variables.tf
    |   +-- outputs.tf
    +-- cache/
    |   +-- main.tf
    |   +-- variables.tf
    |   +-- outputs.tf
    +-- compute/
    |   +-- main.tf
    |   +-- variables.tf
    |   +-- outputs.tf
    +-- storage/
    |   +-- main.tf
    |   +-- variables.tf
    |   +-- outputs.tf
    +-- cdn/
    |   +-- main.tf
    |   +-- variables.tf
    |   +-- outputs.tf
    +-- monitoring/
    |   +-- main.tf
    |   +-- variables.tf
    |   +-- outputs.tf
    +-- dns/
        +-- main.tf
        +-- variables.tf
        +-- outputs.tf
```

### 4.2: Provider and Backend Configuration

Create `terraform/versions.tf`:
```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

Create `terraform/backend.tf` with S3 + DynamoDB state locking:
```hcl
terraform {
  backend "s3" {
    bucket         = "alpha-app-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

Create `terraform/providers.tf`:
```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Team        = "alpha-ai"
    }
  }
}
```

### 4.3: Root Variables

Create `terraform/variables.tf` with all top-level variables:
- `project_name` (string, default: "alpha-app")
- `environment` (string, validation: staging or production)
- `aws_region` (string, default: "ap-south-1")
- `vpc_cidr` (string, default: "10.0.0.0/16")
- `availability_zones` (list, default: ["ap-south-1a", "ap-south-1b", "ap-south-1c"])
- `db_instance_class` (string, default: "db.t3.medium")
- `db_name`, `db_username` (strings)
- `redis_node_type` (string, default: "cache.t3.micro")
- `ecs_backend_cpu`, `ecs_backend_memory` (numbers)
- `ecs_frontend_cpu`, `ecs_frontend_memory` (numbers)
- `domain_name` (string)
- `enable_monitoring` (bool, default: true)
- `enable_cdn` (bool, default: true)

### 4.4: VPC Module

Create `terraform/modules/vpc/main.tf`:
- VPC with DNS support and DNS hostnames enabled
- 3 public subnets (for ALB, NAT Gateway)
- 3 private subnets (for ECS tasks, databases)
- 3 database subnets (isolated, for RDS/DocumentDB)
- Internet Gateway for public subnets
- NAT Gateway (single for staging, one per AZ for production) for private subnets
- Route tables for public, private, and database subnets
- VPC Flow Logs to CloudWatch
- VPC Endpoints for S3 and ECR (reduce NAT costs)

### 4.5: Database Module

Create `terraform/modules/database/main.tf`:
- **RDS MySQL 8.0**: Multi-AZ (production), Single-AZ (staging), automated backups 7 days, encryption at rest, parameter group with utf8mb4, subnet group using database subnets, security group allowing port 3306 from private subnets only
- **DocumentDB** (MongoDB-compatible): Cluster with 2 instances (production) or 1 (staging), encryption, backup retention, subnet group, security group allowing port 27017 from private subnets only
- **DB Subnet Group** shared across RDS and DocumentDB

### 4.6: Cache Module

Create `terraform/modules/cache/main.tf`:
- **ElastiCache Redis**: Cluster mode disabled, single node (staging) or 2 replicas (production), encryption in transit and at rest, subnet group, security group, parameter group, automatic failover (production)

### 4.7: Compute Module

Create `terraform/modules/compute/main.tf`:
- **ECS Cluster** with Container Insights enabled
- **ECS Service - Backend**: Fargate launch type, task definition with backend container, ALB target group, auto-scaling (min 2, max 10), CloudWatch log group
- **ECS Service - Frontend**: Fargate, task definition, ALB target group, auto-scaling
- **ECS Service - Celery Worker**: Fargate, no load balancer, auto-scaling based on SQS queue depth
- **ECS Service - Celery Beat**: Fargate, single task (desiredCount: 1)
- **Application Load Balancer**: Public-facing, HTTPS listener with ACM certificate, HTTP->HTTPS redirect, target groups for backend and frontend, path-based routing (`/api/*` to backend, `/*` to frontend)
- **IAM Roles**: ECS task execution role, ECS task role with S3/SQS/Secrets Manager permissions
- **Security Groups**: ALB (80, 443 from internet), ECS tasks (8000, 3000 from ALB SG only)
- **ECR Repositories**: One for backend, one for frontend, lifecycle policies to keep last 10 images

### 4.8: Storage Module

Create `terraform/modules/storage/main.tf`:
- **S3 Bucket** for application uploads: versioning, encryption (AES256), lifecycle rules (transition to IA after 90 days, Glacier after 365 days), CORS configuration, block public access
- **S3 Bucket** for static assets: website hosting enabled, CloudFront OAI access
- **S3 Bucket** for backups: lifecycle rules, cross-region replication (production only)

### 4.9: CDN Module

Create `terraform/modules/cdn/main.tf`:
- **CloudFront Distribution**: Origins for S3 static assets and ALB, cache behaviors, custom error responses, ACM certificate, WAF association (optional), price class

### 4.10: DNS Module

Create `terraform/modules/dns/main.tf`:
- **Route53 Hosted Zone** (or data source if zone exists)
- A record alias to CloudFront distribution
- A record alias to ALB (for API subdomain)
- ACM Certificate with DNS validation
- Certificate validation records

### 4.11: Monitoring Module

Create `terraform/modules/monitoring/main.tf`:
- **CloudWatch Dashboards**: Application overview, ECS metrics, RDS metrics
- **CloudWatch Alarms**: High CPU on ECS, high latency on ALB, 5xx error rate, RDS connections, Redis memory
- **SNS Topic** for alarm notifications
- **CloudWatch Log Groups** for all ECS services with retention periods

### 4.12: Root Main and Outputs

Create `terraform/main.tf` wiring all modules together.

Create `terraform/outputs.tf` exposing:
- VPC ID, subnet IDs
- RDS endpoint, DocumentDB endpoint, Redis endpoint
- ALB DNS name, CloudFront domain
- ECR repository URLs
- S3 bucket names

### 4.13: Environment Tfvars

Create `terraform/environments/staging.tfvars`:
- Smaller instance types, single AZ databases, minimal replicas, monitoring off

Create `terraform/environments/production.tfvars`:
- Production instance types, multi-AZ, full replicas, monitoring on, CDN enabled

Create `terraform/terraform.tfvars.example`:
- All variables with placeholder values and comments

---

## Step 5: Helm Chart (helm)

**Only execute this step if the infrastructure type is `helm`.**

Generate a complete Helm chart for deploying the Alpha AI application stack.

### 5.1: Directory Structure

```
helm/
+-- alpha-app/
    +-- Chart.yaml
    +-- values.yaml
    +-- values-staging.yaml
    +-- values-production.yaml
    +-- .helmignore
    +-- templates/
    |   +-- _helpers.tpl
    |   +-- NOTES.txt
    |   +-- namespace.yaml
    |   +-- backend/
    |   |   +-- deployment.yaml
    |   |   +-- service.yaml
    |   |   +-- hpa.yaml
    |   |   +-- pdb.yaml
    |   +-- frontend/
    |   |   +-- deployment.yaml
    |   |   +-- service.yaml
    |   |   +-- hpa.yaml
    |   +-- celery/
    |   |   +-- worker-deployment.yaml
    |   |   +-- beat-deployment.yaml
    |   +-- databases/
    |   |   +-- mysql-statefulset.yaml
    |   |   +-- mysql-service.yaml
    |   |   +-- mongodb-statefulset.yaml
    |   |   +-- mongodb-service.yaml
    |   |   +-- redis-deployment.yaml
    |   |   +-- redis-service.yaml
    |   +-- services/
    |   |   +-- meilisearch-deployment.yaml
    |   |   +-- meilisearch-service.yaml
    |   |   +-- minio-statefulset.yaml
    |   |   +-- minio-service.yaml
    |   |   +-- qdrant-statefulset.yaml
    |   |   +-- qdrant-service.yaml
    |   +-- ingress.yaml
    |   +-- configmap.yaml
    |   +-- secrets.yaml
    |   +-- network-policies.yaml
    +-- tests/
        +-- test-connection.yaml
```

### 5.2: Chart.yaml

Create `helm/alpha-app/Chart.yaml`:
```yaml
apiVersion: v2
name: alpha-app
description: Alpha AI Full-Stack Application Platform
type: application
version: 0.1.0
appVersion: "1.0.0"
maintainers:
  - name: Alpha AI Service
    email: devops@alphaai.service
keywords:
  - fastapi
  - nextjs
  - fullstack
  - microservices
home: https://github.com/alpha-ai/alpha-app
sources:
  - https://github.com/alpha-ai/alpha-app
```

### 5.3: Helper Templates

Create `helm/alpha-app/templates/_helpers.tpl` with:
- `alpha-app.name` - chart name
- `alpha-app.fullname` - release-prefixed name (truncated to 63 chars)
- `alpha-app.chart` - chart name + version
- `alpha-app.labels` - common labels (app.kubernetes.io/name, instance, version, managed-by, part-of)
- `alpha-app.selectorLabels` - selector labels (name + instance)
- `alpha-app.backendImage` - constructs full backend image reference from registry + repository + tag
- `alpha-app.frontendImage` - constructs full frontend image reference
- `alpha-app.serviceAccountName` - conditional service account name

### 5.4: values.yaml (Default/Development)

Create `helm/alpha-app/values.yaml` with comprehensive defaults:
```yaml
global:
  imageRegistry: ""
  imagePullSecrets: []
  storageClass: ""
  environment: development

backend:
  enabled: true
  replicaCount: 2
  image:
    repository: alpha-app/backend
    tag: latest
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 8000
  resources:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: "1"
      memory: 1Gi
  autoscaling:
    enabled: false
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80
  livenessProbe:
    httpGet:
      path: /health
      port: 8000
    initialDelaySeconds: 30
    periodSeconds: 10
  readinessProbe:
    httpGet:
      path: /health
      port: 8000
    initialDelaySeconds: 15
    periodSeconds: 5
  podDisruptionBudget:
    enabled: true
    minAvailable: 1
  env: {}
  envFrom: []

frontend:
  enabled: true
  replicaCount: 1
  image:
    repository: alpha-app/frontend
    tag: latest
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 3000
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  autoscaling:
    enabled: false
    minReplicas: 1
    maxReplicas: 5
    targetCPUUtilizationPercentage: 70

celery:
  worker:
    enabled: true
    replicaCount: 2
    concurrency: 4
    queues: "default,high_priority"
    resources:
      requests:
        cpu: 250m
        memory: 256Mi
      limits:
        cpu: "1"
        memory: 1Gi
  beat:
    enabled: true
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 250m
        memory: 256Mi

mysql:
  enabled: true
  image:
    repository: mysql
    tag: "8.0"
  auth:
    rootPassword: ""    # Set via secrets
    database: alpha_app
    username: alpha_user
    password: ""        # Set via secrets
  persistence:
    enabled: true
    size: 20Gi
    storageClass: ""
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: "2"
      memory: 2Gi

mongodb:
  enabled: true
  image:
    repository: mongo
    tag: "7"
  auth:
    rootPassword: ""
    database: alpha_app_nosql
    username: alpha_user
    password: ""
  persistence:
    enabled: true
    size: 20Gi
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: "2"
      memory: 2Gi

redis:
  enabled: true
  image:
    repository: redis
    tag: "7-alpine"
  auth:
    password: ""
  persistence:
    enabled: true
    size: 5Gi
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: "1"
      memory: 512Mi

meilisearch:
  enabled: true
  image:
    repository: getmeili/meilisearch
    tag: v1.6
  masterKey: ""
  persistence:
    enabled: true
    size: 10Gi
  resources:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: "1"
      memory: 1Gi

minio:
  enabled: true
  image:
    repository: minio/minio
    tag: latest
  accessKey: ""
  secretKey: ""
  persistence:
    enabled: true
    size: 50Gi
  resources:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: "1"
      memory: 1Gi

qdrant:
  enabled: true
  image:
    repository: qdrant/qdrant
    tag: v1.7
  persistence:
    enabled: true
    size: 10Gi
  resources:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: "1"
      memory: 1Gi

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-body-size: 100m
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
  hosts:
    - host: app.example.com
      paths:
        - path: /api
          pathType: Prefix
          service: backend
        - path: /ws
          pathType: Prefix
          service: backend
        - path: /
          pathType: Prefix
          service: frontend
  tls:
    - secretName: alpha-app-tls
      hosts:
        - app.example.com

networkPolicies:
  enabled: true

serviceAccount:
  create: true
  name: ""
  annotations: {}
```

### 5.5: values-staging.yaml

Create `helm/alpha-app/values-staging.yaml`:
- `global.environment: staging`
- Backend: 2 replicas, autoscaling enabled (min 2, max 5)
- Frontend: 1 replica, autoscaling disabled
- Celery worker: 1 replica
- Databases: smaller persistence sizes
- Ingress host: `staging.app.example.com`

### 5.6: values-production.yaml

Create `helm/alpha-app/values-production.yaml`:
- `global.environment: production`
- Backend: 4 replicas, autoscaling enabled (min 4, max 20)
- Frontend: 2 replicas, autoscaling enabled (min 2, max 10)
- Celery worker: 4 replicas, concurrency 8
- Databases: larger persistence, higher resource limits
- Ingress host: `app.example.com`
- Network policies enabled

### 5.7: NOTES.txt

Create `helm/alpha-app/templates/NOTES.txt`:
```
===============================================================
  Alpha AI Application Platform has been deployed!
===============================================================

Namespace: {{ .Release.Namespace }}
Environment: {{ .Values.global.environment }}

Access the application:
{{- if .Values.ingress.enabled }}
  Application URL: https://{{ (index .Values.ingress.hosts 0).host }}
{{- else }}
  Run: kubectl port-forward svc/{{ include "alpha-app.fullname" . }}-frontend 3000:3000 -n {{ .Release.Namespace }}
  Then visit: http://localhost:3000
{{- end }}

Services deployed:
  Backend:      {{ if .Values.backend.enabled }}Enabled ({{ .Values.backend.replicaCount }} replicas){{ else }}Disabled{{ end }}
  Frontend:     {{ if .Values.frontend.enabled }}Enabled ({{ .Values.frontend.replicaCount }} replicas){{ else }}Disabled{{ end }}
  Celery:       {{ if .Values.celery.worker.enabled }}Enabled ({{ .Values.celery.worker.replicaCount }} workers){{ else }}Disabled{{ end }}
  MySQL:        {{ if .Values.mysql.enabled }}Enabled{{ else }}Disabled (using external){{ end }}
  MongoDB:      {{ if .Values.mongodb.enabled }}Enabled{{ else }}Disabled (using external){{ end }}
  Redis:        {{ if .Values.redis.enabled }}Enabled{{ else }}Disabled (using external){{ end }}
  Meilisearch:  {{ if .Values.meilisearch.enabled }}Enabled{{ else }}Disabled{{ end }}
  MinIO:        {{ if .Values.minio.enabled }}Enabled{{ else }}Disabled (using S3){{ end }}
  Qdrant:       {{ if .Values.qdrant.enabled }}Enabled{{ else }}Disabled{{ end }}

Next steps:
  1. Verify pods: kubectl get pods -n {{ .Release.Namespace }}
  2. Check logs:  kubectl logs -f deployment/{{ include "alpha-app.fullname" . }}-backend -n {{ .Release.Namespace }}
  3. Monitor:     kubectl top pods -n {{ .Release.Namespace }}

To upgrade:
  helm upgrade {{ .Release.Name }} ./helm/alpha-app -f values-{{ .Values.global.environment }}.yaml -n {{ .Release.Namespace }}

To rollback:
  helm rollback {{ .Release.Name }} -n {{ .Release.Namespace }}
```

### 5.8: Test Connection

Create `helm/alpha-app/tests/test-connection.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "alpha-app.fullname" . }}-test-connection"
  labels:
    {{- include "alpha-app.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  containers:
    - name: test-backend
      image: busybox:1.36
      command: ['wget']
      args: ['--spider', '--timeout=5', '{{ include "alpha-app.fullname" . }}-backend:8000/health']
    - name: test-frontend
      image: busybox:1.36
      command: ['wget']
      args: ['--spider', '--timeout=5', '{{ include "alpha-app.fullname" . }}-frontend:3000']
  restartPolicy: Never
```

### 5.9: Template Files

For each template file under `templates/`, generate complete Kubernetes manifests that:
- Use `{{ include "alpha-app.fullname" . }}` for naming
- Use `{{ include "alpha-app.labels" . }}` for labels
- Use `{{ include "alpha-app.selectorLabels" . }}` for selectors
- Wrap resources in `{{- if .Values.<service>.enabled }}` conditionals
- Reference values for all configurable fields (replicas, images, resources, etc.)
- Include all probes, security contexts, and anti-affinity from the K8s step

---

## Step 6: Generate Environment Templates

**Execute this step for ALL infrastructure types.**

### 6.1: .env.example

Create `.env.example` with ALL required variables, grouped by service, with descriptions:

```bash
# ==============================================================================
# Alpha AI Application - Environment Variables
# Copy this file to .env and fill in the values
# ==============================================================================

# --- Application ---
APP_NAME=alpha-app
APP_ENV=development          # development | staging | production
APP_DEBUG=true
APP_SECRET_KEY=              # Generate: openssl rand -hex 32
APP_PORT=8000
APP_WORKERS=4
ALLOWED_HOSTS=localhost,127.0.0.1
CORS_ORIGINS=http://localhost:3000

# --- JWT Authentication ---
JWT_SECRET_KEY=              # Generate: openssl rand -hex 64
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7
JWT_ALGORITHM=HS256

# --- MySQL ---
MYSQL_HOST=mysql
MYSQL_PORT=3306
MYSQL_DATABASE=alpha_app
MYSQL_USER=alpha_user
MYSQL_PASSWORD=              # Set a strong password
MYSQL_ROOT_PASSWORD=         # Set a strong root password
DATABASE_URL=mysql+asyncmy://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DATABASE}

# --- MongoDB ---
MONGODB_HOST=mongodb
MONGODB_PORT=27017
MONGODB_DATABASE=alpha_app_nosql
MONGODB_USER=alpha_user
MONGODB_PASSWORD=            # Set a strong password
MONGODB_URL=mongodb://${MONGODB_USER}:${MONGODB_PASSWORD}@${MONGODB_HOST}:${MONGODB_PORT}/${MONGODB_DATABASE}

# --- Redis ---
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=              # Optional for development
REDIS_URL=redis://:${REDIS_PASSWORD}@${REDIS_HOST}:${REDIS_PORT}/0
CELERY_BROKER_URL=redis://:${REDIS_PASSWORD}@${REDIS_HOST}:${REDIS_PORT}/1
CELERY_RESULT_BACKEND=redis://:${REDIS_PASSWORD}@${REDIS_HOST}:${REDIS_PORT}/2

# --- Meilisearch ---
MEILISEARCH_HOST=meilisearch
MEILISEARCH_PORT=7700
MEILISEARCH_MASTER_KEY=     # Generate: openssl rand -hex 16
MEILISEARCH_URL=http://${MEILISEARCH_HOST}:${MEILISEARCH_PORT}

# --- MinIO (S3-compatible storage) ---
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=            # Change in production
MINIO_BUCKET=alpha-uploads
MINIO_USE_SSL=false
MINIO_CONSOLE_PORT=9001

# --- Qdrant (Vector Database) ---
QDRANT_HOST=qdrant
QDRANT_PORT=6333
QDRANT_GRPC_PORT=6334
QDRANT_URL=http://${QDRANT_HOST}:${QDRANT_PORT}

# --- Langfuse (AI Observability) ---
LANGFUSE_HOST=langfuse
LANGFUSE_PORT=3100
LANGFUSE_PUBLIC_KEY=
LANGFUSE_SECRET_KEY=
LANGFUSE_BASE_URL=http://${LANGFUSE_HOST}:${LANGFUSE_PORT}

# --- Flower (Celery Monitoring) ---
FLOWER_PORT=5555
FLOWER_BASIC_AUTH=admin:     # Set password: admin:yourpassword

# --- Nginx ---
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443

# --- Frontend ---
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_WS_URL=ws://localhost:8000
NEXT_PUBLIC_APP_NAME=Alpha App

# --- Monitoring ---
PROMETHEUS_PORT=9090
GRAFANA_PORT=3001
GRAFANA_ADMIN_PASSWORD=      # Set admin password

# --- Email (SMTP) ---
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASSWORD=
SMTP_FROM_EMAIL=
SMTP_USE_TLS=true

# --- Google OAuth2 ---
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_REDIRECT_URI=http://localhost:8000/api/v1/auth/google/callback

# --- Sentry (Error Tracking) ---
SENTRY_DSN=
SENTRY_ENVIRONMENT=${APP_ENV}

# --- OpenAI / LLM ---
OPENAI_API_KEY=
LITELLM_MASTER_KEY=

# --- Razorpay (Payments) ---
RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=
RAZORPAY_WEBHOOK_SECRET=
```

### 6.2: .env.development

Create `.env.development` with local development defaults (safe to commit):

```bash
# ==============================================================================
# Development Environment Defaults
# These are safe defaults for local Docker development
# ==============================================================================
APP_NAME=alpha-app
APP_ENV=development
APP_DEBUG=true
APP_SECRET_KEY=dev-secret-key-change-in-production
APP_PORT=8000
APP_WORKERS=1
ALLOWED_HOSTS=*
CORS_ORIGINS=http://localhost:3000,http://localhost:80

JWT_SECRET_KEY=dev-jwt-secret-change-in-production
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7
JWT_ALGORITHM=HS256

MYSQL_HOST=mysql
MYSQL_PORT=3306
MYSQL_DATABASE=alpha_app_dev
MYSQL_USER=alpha_dev
MYSQL_PASSWORD=alpha_dev_pass
MYSQL_ROOT_PASSWORD=root_dev_pass
DATABASE_URL=mysql+asyncmy://alpha_dev:alpha_dev_pass@mysql:3306/alpha_app_dev

MONGODB_HOST=mongodb
MONGODB_PORT=27017
MONGODB_DATABASE=alpha_app_dev
MONGODB_USER=alpha_dev
MONGODB_PASSWORD=alpha_dev_pass
MONGODB_URL=mongodb://alpha_dev:alpha_dev_pass@mongodb:27017/alpha_app_dev

REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_URL=redis://redis:6379/0
CELERY_BROKER_URL=redis://redis:6379/1
CELERY_RESULT_BACKEND=redis://redis:6379/2

MEILISEARCH_HOST=meilisearch
MEILISEARCH_PORT=7700
MEILISEARCH_MASTER_KEY=dev-master-key
MEILISEARCH_URL=http://meilisearch:7700

MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_BUCKET=alpha-uploads-dev
MINIO_USE_SSL=false

QDRANT_HOST=qdrant
QDRANT_PORT=6333
QDRANT_GRPC_PORT=6334
QDRANT_URL=http://qdrant:6333

LANGFUSE_HOST=langfuse
LANGFUSE_PORT=3100
LANGFUSE_PUBLIC_KEY=pk-dev
LANGFUSE_SECRET_KEY=sk-dev
LANGFUSE_BASE_URL=http://langfuse:3100

FLOWER_PORT=5555
FLOWER_BASIC_AUTH=admin:admin

NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_WS_URL=ws://localhost:8000
NEXT_PUBLIC_APP_NAME=Alpha App (Dev)

GRAFANA_ADMIN_PASSWORD=admin
```

### 6.3: .env.production.example

Create `.env.production.example` with production placeholders and instructions:

```bash
# ==============================================================================
# Production Environment Configuration
# IMPORTANT: Never commit this file with real values
# Copy to .env.production and fill in actual secrets
# ==============================================================================
APP_NAME=alpha-app
APP_ENV=production
APP_DEBUG=false
APP_SECRET_KEY=<GENERATE: openssl rand -hex 32>
APP_PORT=8000
APP_WORKERS=4
ALLOWED_HOSTS=yourdomain.com,api.yourdomain.com
CORS_ORIGINS=https://yourdomain.com

JWT_SECRET_KEY=<GENERATE: openssl rand -hex 64>
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7
JWT_ALGORITHM=HS256

# --- Use managed database endpoints in production ---
MYSQL_HOST=<RDS_ENDPOINT>
MYSQL_PORT=3306
MYSQL_DATABASE=alpha_app
MYSQL_USER=alpha_prod
MYSQL_PASSWORD=<STRONG_PASSWORD>
MYSQL_ROOT_PASSWORD=<STRONG_ROOT_PASSWORD>
DATABASE_URL=mysql+asyncmy://alpha_prod:<PASSWORD>@<RDS_ENDPOINT>:3306/alpha_app

MONGODB_HOST=<DOCUMENTDB_ENDPOINT>
MONGODB_PORT=27017
MONGODB_DATABASE=alpha_app
MONGODB_USER=alpha_prod
MONGODB_PASSWORD=<STRONG_PASSWORD>
MONGODB_URL=mongodb://alpha_prod:<PASSWORD>@<DOCUMENTDB_ENDPOINT>:27017/alpha_app?tls=true&replicaSet=rs0

REDIS_HOST=<ELASTICACHE_ENDPOINT>
REDIS_PORT=6379
REDIS_PASSWORD=<STRONG_PASSWORD>
REDIS_URL=redis://:<PASSWORD>@<ELASTICACHE_ENDPOINT>:6379/0
CELERY_BROKER_URL=redis://:<PASSWORD>@<ELASTICACHE_ENDPOINT>:6379/1
CELERY_RESULT_BACKEND=redis://:<PASSWORD>@<ELASTICACHE_ENDPOINT>:6379/2

MEILISEARCH_HOST=meilisearch
MEILISEARCH_PORT=7700
MEILISEARCH_MASTER_KEY=<GENERATE: openssl rand -hex 16>

# --- Use S3 instead of MinIO in production ---
MINIO_ENDPOINT=s3.amazonaws.com
MINIO_ACCESS_KEY=<AWS_ACCESS_KEY>
MINIO_SECRET_KEY=<AWS_SECRET_KEY>
MINIO_BUCKET=alpha-app-uploads-prod
MINIO_USE_SSL=true

QDRANT_HOST=qdrant
QDRANT_PORT=6333
QDRANT_URL=http://qdrant:6333

LANGFUSE_HOST=langfuse
LANGFUSE_PORT=3100
LANGFUSE_PUBLIC_KEY=<LANGFUSE_PK>
LANGFUSE_SECRET_KEY=<LANGFUSE_SK>

FLOWER_BASIC_AUTH=admin:<STRONG_PASSWORD>

NEXT_PUBLIC_API_URL=https://api.yourdomain.com
NEXT_PUBLIC_WS_URL=wss://api.yourdomain.com
NEXT_PUBLIC_APP_NAME=Alpha App

GRAFANA_ADMIN_PASSWORD=<STRONG_PASSWORD>

SMTP_HOST=<SES_ENDPOINT>
SMTP_PORT=587
SMTP_USER=<SES_USER>
SMTP_PASSWORD=<SES_PASSWORD>
SMTP_FROM_EMAIL=noreply@yourdomain.com
SMTP_USE_TLS=true

GOOGLE_CLIENT_ID=<OAUTH_CLIENT_ID>
GOOGLE_CLIENT_SECRET=<OAUTH_CLIENT_SECRET>
GOOGLE_REDIRECT_URI=https://yourdomain.com/api/v1/auth/google/callback

SENTRY_DSN=<SENTRY_DSN_URL>
SENTRY_ENVIRONMENT=production

OPENAI_API_KEY=<OPENAI_KEY>
LITELLM_MASTER_KEY=<LITELLM_KEY>

RAZORPAY_KEY_ID=<RAZORPAY_LIVE_KEY>
RAZORPAY_KEY_SECRET=<RAZORPAY_LIVE_SECRET>
RAZORPAY_WEBHOOK_SECRET=<RAZORPAY_WEBHOOK_SECRET>
```

---

## Step 7: Output Summary

After generating all files, display a comprehensive summary.

### For Docker (`docker`):

```
+===============================================================+
|          INFRASTRUCTURE GENERATED: Docker Compose              |
+===============================================================+
| Environment: [development/staging/production]                  |
+===============================================================+

Files created:
  docker/
    Dockerfile.backend          Multi-stage backend (dev + prod targets)
    Dockerfile.frontend         Multi-stage frontend (dev + prod targets)
    nginx/nginx.conf            Reverse proxy configuration

  docker-compose.yml            Development (hot-reload, debug ports)
  docker-compose.prod.yml       Production (resource limits, health checks)
  docker-compose.test.yml       Testing (ephemeral, CI-optimized)

  .env.example                  All variables with descriptions
  .env.development              Local defaults (safe to commit)
  .env.production.example       Production template (never commit real values)

Services configured: [count]
  Backend (FastAPI)       :8000   (debug :5678)
  Frontend (Next.js)      :3000
  MySQL 8.0               :3306
  MongoDB 7               :27017
  Redis 7                 :6379
  Meilisearch             :7700
  Celery Worker           (background)
  Celery Beat             (scheduler)
  Flower                  :5555
  MinIO                   :9000 (console :9001)
  Qdrant                  :6333
  Langfuse                :3100
  Nginx                   :80

Quick start:
  cp .env.development .env
  docker compose up -d
  docker compose ps
  docker compose logs -f backend

Production:
  cp .env.production.example .env
  # Fill in real values
  docker compose -f docker-compose.prod.yml up -d

Testing:
  docker compose -f docker-compose.test.yml run --rm backend pytest
+===============================================================+
```

### For Kubernetes (`k8s`):

```
+===============================================================+
|          INFRASTRUCTURE GENERATED: Kubernetes (Kustomize)      |
+===============================================================+

Files created:
  k8s/base/                     [count] manifests
  k8s/overlays/staging/         Staging patches
  k8s/overlays/production/      Production patches

Resources:
  Deployments:    backend, frontend, celery-worker, celery-beat, redis, meilisearch
  StatefulSets:   mysql, mongodb, minio, qdrant
  Services:       [count] ClusterIP services
  Ingress:        Path-based routing with TLS
  HPA:            Backend + Frontend auto-scaling
  PDB:            Disruption budgets for HA
  NetworkPolicy:  Namespace isolation + service-level rules
  ConfigMap:      Non-sensitive configuration
  Secrets:        Sensitive credentials (replace placeholders!)

Quick start:
  # Staging
  kubectl apply -k k8s/overlays/staging/

  # Production
  kubectl apply -k k8s/overlays/production/

  # Verify
  kubectl get all -n alpha-app-[staging|production]
+===============================================================+
```

### For K3s (`k3s`):

```
+===============================================================+
|          INFRASTRUCTURE GENERATED: K3s (VPS Cluster)           |
+===============================================================+

Files created:
  k8s/
    backend.yaml              Deployment + Service + IngressRoute + Secret
    celery.yaml               Worker + Beat Deployments (if Celery detected)
    frontend.yaml             Deployment + Service + IngressRoute (if frontend)

Architecture:
  Ingress:          Traefik IngressRoute (NOT nginx Ingress)
  SSL:              Terminates at HAProxy (NOT cert-manager)
  Docker Registry:  ${REGISTRY_IP}:${REGISTRY_PORT} (private, WireGuard network)
  MySQL:            ${DB_NODE_IP}:3306 (external, dedicated VPS)
  MongoDB:          ${DB_NODE_IP}:27017 (external, dedicated VPS)
  Redis:            ${REDIS_NODE_IP}:6379 (external, dedicated VPS)

Resources:
  Deployments:    backend (2 replicas), frontend (2), celery-worker (2), celery-beat (1)
  Services:       ClusterIP for backend + frontend
  IngressRoutes:  Traefik routes for backend + frontend
  Secrets:        Database URLs + app secrets (stringData)

Quick start:
  # Create namespace
  kubectl create namespace APP_NAME

  # Edit secrets in backend.yaml (replace CHANGE_ME placeholders)
  vim k8s/backend.yaml

  # Deploy all manifests
  kubectl apply -f k8s/

  # Verify
  kubectl get all -n APP_NAME

  # Check logs
  kubectl logs -f deployment/APP_NAME-backend -n APP_NAME

CI/CD:
  Generate deploy workflow: /gen-ci --k3s
  Or load reference: INFRA_HOSTINGER_K3S.md
+===============================================================+
```

### For Terraform (`terraform`):

```
+===============================================================+
|          INFRASTRUCTURE GENERATED: Terraform (AWS)             |
+===============================================================+

Files created:
  terraform/
    main.tf, variables.tf, outputs.tf, providers.tf, backend.tf, versions.tf
    environments/staging.tfvars, environments/production.tfvars
    modules/vpc/          VPC, subnets, NAT Gateway, VPC endpoints
    modules/database/     RDS MySQL, DocumentDB
    modules/cache/        ElastiCache Redis
    modules/compute/      ECS Fargate, ALB, ECR, auto-scaling
    modules/storage/      S3 buckets (uploads, assets, backups)
    modules/cdn/          CloudFront distribution
    modules/monitoring/   CloudWatch dashboards + alarms
    modules/dns/          Route53 + ACM certificates

Quick start:
  cd terraform
  cp terraform.tfvars.example terraform.tfvars
  # Fill in values

  # Initialize
  terraform init

  # Staging
  terraform plan -var-file=environments/staging.tfvars
  terraform apply -var-file=environments/staging.tfvars

  # Production
  terraform plan -var-file=environments/production.tfvars
  terraform apply -var-file=environments/production.tfvars

  # Destroy (careful!)
  terraform destroy -var-file=environments/staging.tfvars
+===============================================================+
```

### For Helm (`helm`):

```
+===============================================================+
|          INFRASTRUCTURE GENERATED: Helm Chart                  |
+===============================================================+

Files created:
  helm/alpha-app/
    Chart.yaml                  Chart metadata (v0.1.0)
    values.yaml                 Default values (development)
    values-staging.yaml         Staging overrides
    values-production.yaml      Production overrides
    templates/                  [count] template files
    tests/                      Connection tests

Quick start:
  # Development (default values)
  helm install alpha-app ./helm/alpha-app -n alpha-app --create-namespace

  # Staging
  helm install alpha-app ./helm/alpha-app \
    -f helm/alpha-app/values-staging.yaml \
    -n alpha-app-staging --create-namespace

  # Production
  helm install alpha-app ./helm/alpha-app \
    -f helm/alpha-app/values-production.yaml \
    -n alpha-app-production --create-namespace

  # Upgrade
  helm upgrade alpha-app ./helm/alpha-app -f helm/alpha-app/values-production.yaml

  # Test
  helm test alpha-app -n alpha-app

  # Rollback
  helm rollback alpha-app -n alpha-app
+===============================================================+
```

---

## Important Notes

- **Never commit `.env` files with real secrets.** Add `.env` and `.env.production` to `.gitignore`.
- **Docker Compose `depends_on` with `condition: service_healthy`** ensures services start in the correct order. Do not remove health checks.
- **Kubernetes Secrets** in `secrets.yaml` use placeholder values. Replace with sealed-secrets, external-secrets-operator, or HashiCorp Vault in production.
- **Terraform state** contains sensitive data. Always use encrypted remote backends (S3 + KMS).
- **Helm values** files for production should be managed separately and not committed to the main repository with real credentials.
- **Resource limits** are estimated for a medium-scale application. Monitor actual usage and adjust accordingly.
- **Network policies** default to deny-all ingress. Verify all service communication paths are explicitly allowed before deploying.
- **When using `k3s` type:** Databases run on dedicated VPS nodes (not in K3s). Use WireGuard IPs (user-provided) for database connections. Traefik IngressRoute replaces nginx Ingress. SSL terminates at HAProxy, not in K8s. Images are pulled from the private registry at `${REGISTRY_IP}:${REGISTRY_PORT}`. No Kustomize overlays — flat `k8s/` directory for simplicity. **Claude must ask the user for their infrastructure IPs, domain, runner name, and org name before generating manifests.**
