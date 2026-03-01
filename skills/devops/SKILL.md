---
name: devops
description: "Auto-invoked when creating Docker files, CI/CD pipelines, deployment configs, Kubernetes manifests, or infrastructure code. Enforces Alpha AI DevOps standards."
---

# DevOps Standards

This skill enforces production-grade DevOps practices across all Alpha AI infrastructure. Every Dockerfile, CI/CD pipeline, Kubernetes manifest, and deployment configuration MUST comply with these standards.

---

## 1. Docker

### 1.1 Base Image Rules
- ALWAYS use specific image tags (e.g., `python:3.11-slim`, NOT `python:latest`)
- Prefer `-slim` or `-alpine` variants for smaller images
- Pin the exact digest when maximum reproducibility is needed
- NEVER use `latest` tag in production Dockerfiles
```dockerfile
# WRONG
FROM python:latest
FROM node:alpine

# CORRECT
FROM python:3.11-slim
FROM node:20.11-alpine3.19
```

### 1.2 Multi-Stage Builds
- Use multi-stage builds for ALL production images
- Build dependencies in a builder stage, copy only artifacts to final stage
- Final stage should contain only runtime dependencies
```dockerfile
# REQUIRED: Multi-stage build pattern
# Stage 1: Build
FROM python:3.11-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

COPY . .

# Stage 2: Production
FROM python:3.11-slim AS production

RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

WORKDIR /app

COPY --from=builder /install /usr/local
COPY --from=builder /build/app ./app

USER appuser

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

### 1.3 Non-Root User
- EVERY Dockerfile MUST run as a non-root user
- Create a dedicated application user and group
- Set proper ownership on application files
- Use `USER` directive before `CMD`/`ENTRYPOINT`
```dockerfile
# REQUIRED: Non-root user setup
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser
COPY --chown=appuser:appuser . /app
USER appuser
```

### 1.4 HEALTHCHECK
- EVERY Dockerfile MUST include a HEALTHCHECK instruction
- Use appropriate intervals (30s default)
- Include a start period for initialization time
- Set reasonable timeout and retry counts
```dockerfile
# REQUIRED: Health check patterns

# Python FastAPI
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Node.js
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1) })" || exit 1

# Simple curl-based (if curl is installed)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1
```

### 1.5 Layer Optimization
- COPY requirements/package.json FIRST, then application code (layer caching)
- Combine RUN commands to reduce layers
- Clean up package manager caches in the SAME layer as installation
- Use `.dockerignore` to exclude unnecessary files
```dockerfile
# REQUIRED: Layer caching optimization
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Application code changes often; copy LAST
COPY . .
```

```dockerfile
# REQUIRED: Clean up in same layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential=12.9 \
        libpq-dev=15.* \
    && rm -rf /var/lib/apt/lists/*
```

### 1.6 .dockerignore
- EVERY project with a Dockerfile MUST have a `.dockerignore`
- Exclude version control, IDE files, test artifacts, documentation
```
# REQUIRED: .dockerignore minimum content
.git
.gitignore
.env
.env.*
__pycache__
*.pyc
*.pyo
.pytest_cache
.mypy_cache
.coverage
htmlcov
node_modules
.next
dist
build
*.md
docs/
tests/
.vscode
.idea
docker-compose*.yml
Dockerfile*
```

### 1.7 Package Pinning
- Pin apt/apk package versions
- Use `--no-install-recommends` for apt
- Use `--no-cache` for apk
```dockerfile
# REQUIRED: Package pinning
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl=7.88.* \
        ca-certificates=20230311 \
    && rm -rf /var/lib/apt/lists/*

# Alpine variant
RUN apk add --no-cache \
    curl=8.5.0-r0 \
    ca-certificates=20240226-r0
```

---

## 2. Docker Compose

### 2.1 Service Health Checks
- ALL services MUST have a `healthcheck` configuration
- Use `depends_on` with `condition: service_healthy` for dependencies
```yaml
# REQUIRED: Docker Compose service pattern
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    ports:
      - "${API_PORT:-8000}:8000"
    env_file:
      - .env
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: "1.0"
        reservations:
          memory: 256M
          cpus: "0.25"
```

### 2.2 Restart Policy
- ALL services MUST have `restart: unless-stopped`
- Exception: one-off migration/seed containers use `restart: "no"`

### 2.3 Dependency Ordering
- Use `depends_on` with `condition: service_healthy` (NOT just `depends_on`)
- Databases and caches start before application services
- Message queues start before consumers

### 2.4 Volumes
- Use named volumes for ALL persistent data
- NEVER use bind mounts for production data
- Bind mounts are acceptable for local development source code only
```yaml
# REQUIRED: Named volumes
volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local

services:
  postgres:
    image: postgres:16.1-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
```

### 2.5 Environment Variables
- Use `.env` files for ALL environment variables (NEVER hardcode)
- Document all required variables in `.env.example`
- Use variable substitution with defaults: `${VAR:-default}`
```yaml
# REQUIRED: Environment file usage
services:
  api:
    env_file:
      - .env
    environment:
      - DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@postgres:5432/${DB_NAME}
```

### 2.6 Resource Limits
- Set memory limits on ALL services
- Set CPU limits on ALL services
- Set reservations for minimum guaranteed resources
```yaml
# REQUIRED: Resource limits
deploy:
  resources:
    limits:
      memory: 1G
      cpus: "1.0"
    reservations:
      memory: 256M
      cpus: "0.25"
```

### 2.7 Environment Separation
- Maintain separate compose files: `docker-compose.yml` (base), `docker-compose.dev.yml`, `docker-compose.prod.yml`
- Use `docker compose -f docker-compose.yml -f docker-compose.prod.yml up` for production
- Dev overrides may include: source bind mounts, debug ports, hot reload

---

## 3. CI/CD Pipelines

### 3.1 Required Pipeline Stages
Every pipeline MUST include these stages in order:
1. **Lint** - Code formatting and style (ruff, eslint, prettier)
2. **Type Check** - Static type analysis (mypy, tsc)
3. **Test** - Unit and integration tests (pytest, jest)
4. **Build** - Docker image build
5. **Security Scan** - Vulnerability scanning (Trivy, pip-audit, npm audit)
6. **Deploy** - Staging (automatic), Production (manual approval)

### 3.2 Pipeline Template (GitHub Actions)
```yaml
# REQUIRED: CI/CD pipeline structure
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  PYTHON_VERSION: "3.11"
  NODE_VERSION: "20"
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}
          cache: 'pip'
      - name: Install linting tools
        run: pip install ruff black isort
      - name: Run ruff
        run: ruff check .
      - name: Check formatting
        run: black --check . && isort --check .

  type-check:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}
          cache: 'pip'
      - name: Install dependencies
        run: pip install -r requirements.txt && pip install mypy
      - name: Run mypy
        run: mypy app/ --strict

  test:
    runs-on: ubuntu-latest
    needs: type-check
    services:
      postgres:
        image: postgres:16.1-alpine
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test_db
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7.2-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}
          cache: 'pip'
      - name: Install dependencies
        run: pip install -r requirements.txt -r requirements-dev.txt
      - name: Run tests
        run: pytest --cov=app --cov-report=xml -n auto
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/test_db
          REDIS_URL: redis://localhost:6379
      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: coverage.xml

  build:
    runs-on: ubuntu-latest
    needs: test
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.ref == 'refs/heads/main' }}
          tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  security-scan:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4
      - name: Run Trivy image scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          format: 'sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'
      - name: Run pip-audit
        run: |
          pip install pip-audit
          pip-audit -r requirements.txt

  deploy-staging:
    runs-on: ubuntu-latest
    needs: [security-scan]
    if: github.ref == 'refs/heads/main'
    environment: staging
    steps:
      - name: Deploy to staging
        run: |
          echo "Deploy to staging environment"
          # kubectl set image deployment/app app=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}

  deploy-production:
    runs-on: ubuntu-latest
    needs: [deploy-staging]
    if: github.ref == 'refs/heads/main'
    environment:
      name: production
      url: https://api.example.com
    steps:
      - name: Deploy to production
        run: |
          echo "Deploy to production environment"
          # kubectl set image deployment/app app=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
```

### 3.3 Caching
- Cache pip/npm dependencies between pipeline runs
- Cache Docker layers using GitHub Actions cache or BuildKit cache
- Cache test databases when possible

### 3.4 Parallel Execution
- Run lint and type-check in parallel when they have no dependency
- Run test suites in parallel (`pytest -n auto`, Jest `--maxWorkers`)
- Build multiple Docker images in parallel if independent

### 3.5 Fail Fast
- Stop the pipeline immediately on lint/type-check failures
- Do NOT proceed to build/deploy if tests fail
- Use `needs` dependencies to enforce ordering

### 3.6 Rollback Mechanism
- Tag every production deployment with the git SHA
- Maintain the previous 5 production image tags
- Define a rollback procedure (manual or automated)
- Test rollback procedures quarterly

---

## 4. Kubernetes

### 4.1 Resource Requests and Limits
- EVERY container MUST have resource requests AND limits
- Requests = guaranteed resources, Limits = maximum allowed
- Start conservative, tune based on actual usage metrics
```yaml
# REQUIRED: Resource specification
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### 4.2 Health Probes
- EVERY deployment MUST have liveness AND readiness probes
- Liveness: restart container if unhealthy
- Readiness: stop sending traffic if not ready
- Optional: startup probe for slow-starting containers
```yaml
# REQUIRED: Health probes
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 30
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health/ready
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3

startupProbe:
  httpGet:
    path: /health
    port: 8000
  failureThreshold: 30
  periodSeconds: 10
```

### 4.3 Pod Disruption Budgets
- ALL production deployments MUST have a PodDisruptionBudget
- Ensure at least 1 pod is always available during voluntary disruptions
```yaml
# REQUIRED: PDB for HA
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: api
```

### 4.4 Horizontal Pod Autoscaler
- Use HPA for all production workloads that can scale horizontally
- Scale on CPU utilization (target 70%) and custom metrics
```yaml
# REQUIRED: HPA configuration
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

### 4.5 Configuration Management
- Use ConfigMaps for non-sensitive configuration
- Use Secrets for ALL sensitive data (encrypted at rest)
- NEVER store secrets in environment variables in manifest files
- Reference secrets from external secret stores when possible (Vault, AWS SSM)
```yaml
# REQUIRED: Config and secrets pattern
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
data:
  LOG_LEVEL: "info"
  WORKERS: "4"
  DB_POOL_SIZE: "20"

---
apiVersion: v1
kind: Secret
metadata:
  name: api-secrets
type: Opaque
data:
  DATABASE_URL: <base64-encoded>
  JWT_SECRET: <base64-encoded>
  REDIS_URL: <base64-encoded>
```

### 4.6 Network Policies
- Implement network policies for namespace isolation
- Default deny all ingress, explicitly allow required traffic
- Restrict egress to only necessary external services
```yaml
# REQUIRED: Default deny ingress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
    - Ingress

---
# Allow traffic from specific sources
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-ingress
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: nginx-ingress
      ports:
        - protocol: TCP
          port: 8000
```

### 4.7 Pod Anti-Affinity
- Spread pods across nodes for high availability
- Use `preferredDuringSchedulingIgnoredDuringExecution` for flexible scheduling
```yaml
# REQUIRED: Pod anti-affinity
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - api
          topologyKey: kubernetes.io/hostname
```

### 4.8 Complete Deployment Template
```yaml
# REQUIRED: Full deployment template
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    app: api
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  template:
    metadata:
      labels:
        app: api
        version: v1
    spec:
      serviceAccountName: api-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
        - name: api
          image: ghcr.io/alpha-ai/api:sha-abc123
          ports:
            - containerPort: 8000
              protocol: TCP
          envFrom:
            - configMapRef:
                name: api-config
            - secretRef:
                name: api-secrets
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8000
            initialDelaySeconds: 5
            periodSeconds: 10
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - api
                topologyKey: kubernetes.io/hostname
```

---

## 5. Monitoring & Observability

### 5.1 Prometheus Metrics
- Expose `/metrics` endpoint on EVERY service
- Include standard metrics: request count, latency histogram, error rate
- Add business-specific custom metrics
```python
# REQUIRED: Prometheus metrics for FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

instrumentator = Instrumentator(
    should_group_status_codes=True,
    should_instrument_requests_inprogress=True,
    excluded_handlers=["/health", "/metrics"],
    inprogress_name="http_requests_inprogress",
    inprogress_labels=True,
)

instrumentator.instrument(app).expose(app, endpoint="/metrics")
```

### 5.2 Structured Logging
- ALL logs MUST be structured JSON format
- Include: timestamp, level, service, trace_id, message, context
- Ship logs to centralized aggregator (ELK, Loki, CloudWatch)
```python
# REQUIRED: Structured logging configuration
import structlog

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),
    ],
    logger_factory=structlog.PrintLoggerFactory(),
)
```

### 5.3 Alerting Rules
Define alerts for every production service:
- **High Error Rate**: >5% 5xx responses in 5 minutes
- **High Latency**: p95 response time >1s for 5 minutes
- **Low Disk Space**: <20% free disk on any volume
- **High Memory**: >85% memory utilization for 10 minutes
- **Pod Restarts**: >3 restarts in 15 minutes
- **Deployment Failed**: rollout not progressing for 10 minutes
```yaml
# REQUIRED: Prometheus alerting rules
groups:
  - name: api-alerts
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }} for the last 5 minutes"

      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High p95 latency detected"
```

### 5.4 Grafana Dashboards
- Create a dashboard for EVERY deployed service
- Include: request rate, error rate, latency percentiles, resource usage
- Include deployment markers (annotations)
- Set up on-call rotation with PagerDuty/OpsGenie integration

---

## 6. Infrastructure as Code

### 6.1 Terraform Standards
- Use remote state storage (S3 + DynamoDB locking)
- Separate state files per environment
- Use modules for reusable components
- Pin provider versions
- Tag ALL resources
```hcl
# REQUIRED: Terraform provider pinning
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
  }

  backend "s3" {
    bucket         = "alpha-ai-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### 6.2 Resource Tagging
- ALL cloud resources MUST be tagged with: Environment, Service, Team, ManagedBy
```hcl
# REQUIRED: Default tags
locals {
  common_tags = {
    Environment = var.environment
    Service     = var.service_name
    Team        = "alpha-ai"
    ManagedBy   = "terraform"
    Repository  = "alpha-ai/infrastructure"
  }
}
```

---

## 7. DevOps Checklist for Code Reviews

Every PR touching infrastructure code MUST verify:

- [ ] Dockerfiles use specific image tags (not `latest`)
- [ ] Dockerfiles include HEALTHCHECK
- [ ] Dockerfiles use non-root USER
- [ ] Multi-stage builds for production images
- [ ] .dockerignore file present and comprehensive
- [ ] Docker Compose services have health checks
- [ ] Docker Compose services have restart policies
- [ ] Docker Compose services have resource limits
- [ ] CI pipeline includes all required stages (lint, test, build, scan, deploy)
- [ ] Kubernetes manifests have resource requests AND limits
- [ ] Kubernetes manifests have liveness AND readiness probes
- [ ] Secrets are NOT hardcoded anywhere
- [ ] Environment variables come from .env files or secrets managers
- [ ] Monitoring metrics are exposed
- [ ] Alerting rules are defined
- [ ] Rollback procedure is documented
