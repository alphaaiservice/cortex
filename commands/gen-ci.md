---
description: "Generate CI/CD pipelines for GitHub Actions, GitLab CI, or Bitbucket Pipelines. Auto-detects stack from project. Usage: /gen-ci [github-actions|gitlab-ci|bitbucket] [--full]"
---

# CI/CD Pipeline Generator

Generate production-quality CI/CD pipelines for: **$ARGUMENTS**

Parse `$ARGUMENTS` to determine:
- **Platform**: `github-actions` (default if not specified), `gitlab-ci`, or `bitbucket`
- **Mode**: `--full` flag means generate ALL pipeline files including Docker files, security scans, release automation, and deployment pipelines. Without `--full`, generate only the core CI pipeline (lint, test, build).

---

## Step 1: Detect Project Stack

Run all detection tasks in parallel using Agent tool (mode = "bypassPermissions"). Scan the project root and subdirectories to build a complete technology profile.

### 1A: Detect Backend Stack

Search for these files and extract relevant information:

```bash
# Python detection
ls requirements.txt pyproject.toml setup.py setup.cfg Pipfile poetry.lock 2>/dev/null

# If Python found, detect framework
grep -l "fastapi\|FastAPI" requirements.txt pyproject.toml 2>/dev/null
grep -l "django\|Django" requirements.txt pyproject.toml 2>/dev/null
grep -l "flask\|Flask" requirements.txt pyproject.toml 2>/dev/null

# Node.js detection
ls package.json pnpm-lock.yaml yarn.lock package-lock.json bun.lockb 2>/dev/null

# Go detection
ls go.mod go.sum 2>/dev/null

# Rust detection
ls Cargo.toml Cargo.lock 2>/dev/null

# Java detection
ls pom.xml build.gradle build.gradle.kts 2>/dev/null
```

Record the **Python version** from `pyproject.toml` (`requires-python`) or `.python-version` file. Default to `3.11` and `3.12` for matrix testing.

Record the **Node version** from `package.json` (`engines.node`) or `.nvmrc` or `.node-version`. Default to `20` and `22` for matrix testing.

Record the **Java version** from `build.gradle.kts` (`sourceCompatibility`) or `.java-version`. Default to `21` for testing.

**NestJS detection**: If `package.json` contains `@nestjs/core`, this is a NestJS backend. Use `pnpm` commands and NestJS-specific CI steps (build, lint, test:e2e).

**Spring Boot detection**: If `build.gradle.kts` or `pom.xml` contains `spring-boot`, this is a Spring Boot backend. Use `./gradlew` commands for build, test, and quality checks (checkstyle, spotbugs).

### 1B: Detect Frontend Stack

```bash
# Next.js
grep -l "next" package.json 2>/dev/null
# React Native / Expo
grep -l "react-native\|expo" package.json 2>/dev/null
# Vite / Vue
grep -l "vite\|vue" package.json 2>/dev/null
# Angular
grep -l "@angular/core" package.json 2>/dev/null
```

### 1C: Detect Package Manager

```bash
# Check lock files to determine package manager
ls pnpm-lock.yaml 2>/dev/null && echo "pnpm"
ls yarn.lock 2>/dev/null && echo "yarn"
ls bun.lockb 2>/dev/null && echo "bun"
ls package-lock.json 2>/dev/null && echo "npm"
```

Use the detected package manager throughout all pipeline commands. Map accordingly:
- `npm` -> `npm ci`, `npm run lint`, `npm run build`, `npm test`
- `pnpm` -> `pnpm install --frozen-lockfile`, `pnpm lint`, `pnpm build`, `pnpm test`
- `yarn` -> `yarn install --frozen-lockfile`, `yarn lint`, `yarn build`, `yarn test`
- `bun` -> `bun install --frozen-lockfile`, `bun lint`, `bun run build`, `bun test`

### 1D: Detect Test Runner

```bash
# Python test runners
grep -l "pytest" requirements.txt pyproject.toml 2>/dev/null && echo "pytest"
grep -l "unittest" requirements.txt 2>/dev/null && echo "unittest"
grep -l "tox" requirements.txt pyproject.toml tox.ini 2>/dev/null && echo "tox"

# JS/TS test runners
grep -l "jest" package.json 2>/dev/null && echo "jest"
grep -l "vitest" package.json 2>/dev/null && echo "vitest"
grep -l "playwright" package.json 2>/dev/null && echo "playwright"
grep -l "cypress" package.json 2>/dev/null && echo "cypress"
grep -l "mocha" package.json 2>/dev/null && echo "mocha"
```

### 1E: Detect Linter and Type Checker

```bash
# Python linters
grep -l "ruff" requirements.txt pyproject.toml 2>/dev/null && echo "ruff"
grep -l "flake8" requirements.txt 2>/dev/null && echo "flake8"
grep -l "pylint" requirements.txt 2>/dev/null && echo "pylint"
grep -l "black" requirements.txt pyproject.toml 2>/dev/null && echo "black"
grep -l "isort" requirements.txt pyproject.toml 2>/dev/null && echo "isort"
grep -l "mypy" requirements.txt pyproject.toml 2>/dev/null && echo "mypy"

# JS/TS linters
grep -l "eslint" package.json 2>/dev/null && echo "eslint"
grep -l "biome" package.json 2>/dev/null && echo "biome"
grep -l "prettier" package.json 2>/dev/null && echo "prettier"
ls tsconfig.json 2>/dev/null && echo "tsc"
```

### 1F: Detect Databases and Services

```bash
# Docker compose services
cat docker-compose.yml docker-compose.yaml compose.yml compose.yaml 2>/dev/null | grep -E "mysql|mariadb|postgres|mongodb|mongo|redis|meilisearch|elasticsearch|rabbitmq|kafka|minio"

# Python dependencies referencing databases
grep -iE "sqlalchemy|asyncmy|pymysql|psycopg|pymongo|motor|beanie|redis|meilisearch|elasticsearch|celery|pika" requirements.txt pyproject.toml 2>/dev/null

# Environment files referencing databases
grep -iE "DATABASE_URL|MYSQL|MONGO|REDIS|MEILI|ELASTIC|RABBIT|KAFKA" .env.example .env.sample 2>/dev/null
```

### 1G: Detect Docker Configuration

```bash
ls Dockerfile Dockerfile.* .dockerignore 2>/dev/null
ls docker-compose.yml docker-compose.yaml compose.yml compose.yaml 2>/dev/null
```

### 1H: Detect Existing CI/CD

```bash
# Check for existing pipelines to avoid overwriting
ls .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null
ls .gitlab-ci.yml 2>/dev/null
ls bitbucket-pipelines.yml 2>/dev/null
ls Jenkinsfile 2>/dev/null
ls .circleci/config.yml 2>/dev/null

# K3s deployment detection
ls k8s/*.yaml 2>/dev/null
grep -l "traefik.io/v1alpha1" k8s/*.yaml 2>/dev/null && echo "K3s with Traefik IngressRoute detected"
grep -lE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+" k8s/*.yaml Dockerfile 2>/dev/null && echo "Private registry detected"
```

If existing CI/CD files are found, WARN the user and ask for confirmation before overwriting. List each existing file and its purpose.

### 1I: Build Detection Summary

After all parallel scans complete, compile a detection summary object:

```
DETECTED STACK:
  Backend:          [FastAPI / Django / Express / Go / etc.]
  Frontend:         [Next.js / React Native / Vue / etc.]
  Languages:        [Python 3.11, 3.12 / Node 20, 22 / etc.]
  Package Manager:  [pip / pnpm / yarn / npm / bun]
  Test Runner:      [pytest / jest / vitest / playwright]
  Linters:          [ruff / eslint / biome / mypy / tsc]
  Databases:        [MySQL 8.0 / MongoDB 7 / Redis 7 / etc.]
  Search:           [Meilisearch / Elasticsearch / none]
  Queue:            [Celery+Redis / RabbitMQ / none]
  Deployment:       [K3s self-hosted / GHCR / ECR / DockerHub / none]
  Docker:           [Dockerfile found / not found]
  Existing CI:      [none / list files]
```

Use this summary to drive all subsequent pipeline generation.

---

## Step 2: Generate Pipeline Files

Based on the detected platform from `$ARGUMENTS`, generate the appropriate pipeline files.

---

### Platform A: GitHub Actions (`.github/workflows/`)

Create the `.github/workflows/` directory if it does not exist.

#### File 1: `.github/workflows/ci.yml` — Main CI Pipeline

This is the core pipeline that runs on every pull request and push to main/develop.

The generated file MUST include:

**Trigger configuration:**
- Run on `pull_request` targeting `main` and `develop` branches
- Run on `push` to `main` and `develop` branches
- Path filtering: ignore changes to `*.md`, `docs/**`, `.github/**/*.md`

**Concurrency:**
- Group by `${{ github.workflow }}-${{ github.ref }}`
- Cancel in-progress runs on new push (`cancel-in-progress: true`)

**Environment variables at workflow level:**
- `FORCE_COLOR: 1` (colored output in CI logs)
- `CI: true`

**Job 1: lint**
- Runs on `ubuntu-latest`
- Steps:
  1. Checkout code with `actions/checkout@v4`
  2. Setup language runtime (Python via `actions/setup-python@v5` or Node via `actions/setup-node@v4`) with version from detection
  3. Cache dependencies (pip cache at `~/.cache/pip`, or pnpm store, or npm cache at `~/.npm`)
  4. Install dependencies
  5. Run linter (detected linter: ruff check, eslint, biome, etc.)
  6. Run formatter check (ruff format --check, prettier --check, etc.)

**Job 2: type-check** (if mypy or tsc detected)
- Depends on: `lint`
- Steps:
  1. Checkout, setup runtime, cache, install
  2. Run type checker (`mypy .` or `tsc --noEmit`)

**Job 3: test**
- Depends on: `lint`
- Strategy matrix: Python `[3.11, 3.12]` or Node `[20, 22]` based on detection
- Service containers (based on detected databases):
  - MySQL 8.0: port 3306, health check with `mysqladmin ping`, env vars for root password and test database
  - MongoDB 7: port 27017, no auth for tests
  - Redis 7: port 6379, health check with `redis-cli ping`
  - Meilisearch: port 7700, master key set to `test-master-key`
- Steps:
  1. Checkout code
  2. Setup runtime with matrix version
  3. Cache dependencies
  4. Install dependencies
  5. Wait for service health (if services are used)
  6. Run tests with coverage: `pytest --cov=. --cov-report=xml --cov-report=html -v` or `npm test -- --coverage`
  7. Upload coverage report as artifact using `actions/upload-artifact@v4`
- Environment variables for test job:
  - `DATABASE_URL: mysql+asyncmy://root:testpass@localhost:3306/test_db` (if MySQL detected)
  - `MONGODB_URL: mongodb://localhost:27017/test_db` (if MongoDB detected)
  - `REDIS_URL: redis://localhost:6379/0` (if Redis detected)
  - `MEILISEARCH_URL: http://localhost:7700` (if Meilisearch detected)
  - `MEILISEARCH_MASTER_KEY: test-master-key` (if Meilisearch detected)
  - `ENVIRONMENT: test`

**Job 4: build**
- Depends on: `test`
- Steps:
  1. Checkout code
  2. Setup runtime, cache, install
  3. Build application (`npm run build`, `python -m build`, etc.)
  4. If Docker detected: build Docker image (without push) to verify it builds
  5. Upload build artifacts using `actions/upload-artifact@v4`

#### File 2: `.github/workflows/cd.yml` — Deployment Pipeline (only with `--full`)

This pipeline handles deployment to staging and production.

**Trigger configuration:**
- Run on `push` to `main` branch (production)
- Run on `push` to `develop` branch (staging)
- Run on `workflow_dispatch` for manual triggers with environment input

**Job 1: build-and-push**
- Runs on `ubuntu-latest`
- Permissions: `contents: read`, `packages: write`, `id-token: write`
- Steps:
  1. Checkout code
  2. Set up Docker Buildx with `docker/setup-buildx-action@v3`
  3. Login to container registry (GHCR by default) with `docker/login-action@v3`
  4. Extract metadata (tags, labels) with `docker/metadata-action@v5`
  5. Build and push with `docker/build-push-action@v5`:
     - Multi-platform: `linux/amd64,linux/arm64`
     - Cache: `type=gha` (GitHub Actions cache)
     - Tags: branch name, commit SHA, `latest` for main
  6. Output image digest for verification

**Job 2: deploy-staging**
- Depends on: `build-and-push`
- Condition: `github.ref == 'refs/heads/develop'` OR manual trigger with `staging`
- Environment: `staging` (with URL)
- Steps:
  1. Deploy using SSH, kubectl, AWS ECS, or docker-compose (based on project detection)
  2. Run smoke tests against staging URL
  3. Post deployment status to Slack/Discord

**Job 3: deploy-production**
- Depends on: `build-and-push`
- Condition: `github.ref == 'refs/heads/main'` OR manual trigger with `production`
- Environment: `production` (with URL and **required reviewers** for manual approval)
- Steps:
  1. Deploy using the same method as staging
  2. Run smoke tests against production URL
  3. Post deployment status to Slack/Discord
  4. Create GitHub deployment record

**Notifications job:**
- Runs `if: failure()` at the end
- Sends Slack notification via `slackapi/slack-github-action@v1` or Discord webhook
- Includes: workflow name, branch, commit, actor, failure link

#### File 3: `.github/workflows/security.yml` — Security Scanning (only with `--full`)

**Trigger configuration:**
- Run on `schedule`: weekly on Monday at 09:00 UTC (`cron: '0 9 * * 1'`)
- Run on `pull_request` (on dependency file changes only)
- Run on `workflow_dispatch` for manual triggers

**Job 1: dependency-audit**
- Steps:
  1. Checkout code
  2. If Python: run `pip-audit --strict --desc` and `safety check`
  3. If Node: run `npm audit --audit-level=high` or `pnpm audit --audit-level=high`
  4. Upload audit results as artifact

**Job 2: container-scan** (if Dockerfile detected)
- Steps:
  1. Build Docker image locally
  2. Run Trivy container scan with `aquasecurity/trivy-action@master`:
     - Severity: `CRITICAL,HIGH`
     - Format: `sarif` for GitHub Security tab integration
  3. Upload SARIF results with `github/codeql-action/upload-sarif@v3`

**Job 3: secret-scan**
- Steps:
  1. Run `trufflesecurity/trufflehog@main` to detect leaked secrets
  2. Run `gitleaks/gitleaks-action@v2` as backup scanner

**Job 4: code-quality**
- Steps:
  1. Run CodeQL analysis with `github/codeql-action@v3` for detected languages
  2. Upload SARIF results

#### File 4: `.github/workflows/release.yml` — Release Automation (only with `--full`)

**Trigger configuration:**
- Run on `push` with tags matching `v*.*.*` (semver tags)

**Job 1: release**
- Permissions: `contents: write`
- Steps:
  1. Checkout code with full history (`fetch-depth: 0`)
  2. Generate changelog from commits since last tag using conventional commits format
  3. Create GitHub Release with `softprops/action-gh-release@v1`:
     - Auto-generate release notes
     - Attach build artifacts
     - Mark as pre-release if tag contains `-rc`, `-beta`, `-alpha`
  4. If Python: publish to PyPI with `pypa/gh-action-pypi-publish@release/v1`
  5. If Node: publish to npm with `npm publish`
  6. Build and push Docker image tagged with the release version

#### File 5: `.github/workflows/deploy.yml` — K3s Self-Hosted Runner Deployment (only with `--full` AND K3s detected)

**Auto-detect K3s deployment**: If the project has a `k8s/` directory with Traefik IngressRoute manifests, OR if the user specifies `--k3s` flag, generate this deployment workflow for a self-hosted K3s cluster.

**IMPORTANT — Before generating K3s deployment, ask the user for their cluster configuration:**
> "Before generating K3s deployment, I need your cluster configuration. Please provide:
> 1. **Registry address** — private Docker registry IP and port (e.g., `10.0.0.4:5000`)
> 2. **Node IPs** — gateway node, app node, database node, Redis node
> 3. **Database endpoint** — DB host IP or hostname
> 4. **Runner name** — self-hosted GitHub Actions runner label
> 5. **Domain** — your deployment domain (e.g., `example.com`)
> 6. **Organization name** — used for image naming and namespaces"

Store the user's answers in these variables and substitute them throughout the generated workflow:
- `${REGISTRY_IP}` — registry host IP
- `${REGISTRY_PORT}` — registry port
- `${GATEWAY_NODE_IP}` — gateway/edge node IP
- `${APP_NODE_IP}` — application node IP
- `${DB_NODE_IP}` — database node IP
- `${REDIS_NODE_IP}` — Redis node IP
- `${RUNNER_NAME}` — self-hosted runner label
- `${YOUR_DOMAIN}` — deployment domain
- `${ORG_NAME}` — organization/team name

**Load reference**: Read `skills/alpha-architecture/references/INFRA_HOSTINGER_K3S.md` for infrastructure details.

**Trigger configuration:**
- Run on `push` to `main` branch only (production deployment)

**Environment variables:**
- `REGISTRY: ${REGISTRY_IP}:${REGISTRY_PORT}` — Private Docker registry (WireGuard/internal network)
- `APP_NAME` — K8s deployment name (auto-detect from project name or k8s/ manifests)
- `APP_NAMESPACE` — K8s namespace (default: `default`)
- `IMAGE_NAME` — Registry image path: `${ORG_NAME}/{app-name}` (no host prefix)

**Job: build-and-deploy**
- `runs-on: self-hosted` — Uses the `${RUNNER_NAME}` runner on the app node (NOT `ubuntu-latest`)
- `timeout-minutes: 15`

**Steps:**
1. Checkout code (`actions/checkout@v4`)
2. Set image tag: `sha=${GITHUB_SHA::8}`, `image=${REGISTRY}/${IMAGE_NAME}`
3. Build Docker image: tag with both `:sha` and `:latest`
4. Push to private registry: `docker push` both tags to `${REGISTRY_IP}:${REGISTRY_PORT}`
5. Apply K8s manifests: `kubectl apply -f k8s/`
6. Update deployment image: `kubectl set image deployment/APP_NAME` + `kubectl rollout status --timeout=120s`
7. Update Celery workers (if present): check if `APP_NAME-celery-worker` deployment exists, if so update image. Same for `APP_NAME-celery-beat`.
8. Cleanup old Docker images: `docker image prune -f --filter "until=24h"` (runs `if: always()`)

**Important K3s-specific notes (include as YAML comments):**
- Runner is self-hosted on the app node (`${APP_NODE_IP}`) — has direct access to kubectl and private registry
- No docker login needed — registry is on internal/WireGuard network (HTTP, no auth)
- No separate Docker setup step needed — Docker CE is pre-installed on runner
- kubectl is pre-configured with K3s kubeconfig on the app node
- Celery worker/beat use the SAME image as the backend app

---

### Platform B: GitLab CI (`.gitlab-ci.yml`)

Generate a single `.gitlab-ci.yml` file at the project root.

The generated file MUST include:

**Global configuration:**
```yaml
stages:
  - lint
  - type-check
  - test
  - build
  - security
  - deploy-staging
  - deploy-production

default:
  image: python:3.12-slim  # or node:22-slim based on detection
  interruptible: true

variables:
  PIP_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pip"
  CI: "true"
  FORCE_COLOR: "1"

cache:
  key: "${CI_COMMIT_REF_SLUG}"
  paths:
    - .cache/pip/    # or node_modules/ or .pnpm-store/
    - .venv/
```

**Workflow rules:**
- Run on merge requests
- Run on push to main/develop
- Run on tags
- Do NOT run duplicate pipelines (deduplicate merge request + push)

**lint job:**
- Stage: lint
- Script: install dependencies, run linter, run formatter check
- Rules: run on merge requests and pushes to main/develop

**type-check job:**
- Stage: type-check
- Needs: `lint`
- Script: run mypy or tsc
- Allow failure: false

**test job:**
- Stage: test
- Needs: `lint`
- Parallel matrix for language versions
- Services (based on detection):
  - `mysql:8.0` with alias `mysql`
  - `mongo:7` with alias `mongodb`
  - `redis:7-alpine` with alias `redis`
  - `getmeili/meilisearch:latest` with alias `meilisearch`
- Variables for service connections (using GitLab service aliases)
- Script: run tests with coverage
- Artifacts: coverage report XML and HTML, expire in 7 days
- Coverage regex for GitLab coverage badge extraction

**build job:**
- Stage: build
- Needs: `test`
- Script: build application, build Docker image
- Artifacts: build output, expire in 3 days

**security job (only with `--full`):**
- Stage: security
- Script: pip-audit / npm audit, Trivy scan
- Allow failure: true (advisory)
- Rules: run on schedules and merge requests
- Artifacts: security report

**deploy-staging job (only with `--full`):**
- Stage: deploy-staging
- Environment: staging (with URL)
- Needs: `build`
- Rules: only on `develop` branch
- Script: deploy to staging, run smoke tests

**deploy-production job (only with `--full`):**
- Stage: deploy-production
- Environment: production (with URL)
- Needs: `build`
- Rules: only on `main` branch, `when: manual` (manual approval gate)
- Script: deploy to production, run smoke tests

---

### Platform C: Bitbucket Pipelines (`bitbucket-pipelines.yml`)

Generate a single `bitbucket-pipelines.yml` file at the project root.

The generated file MUST include:

**Global configuration:**
```yaml
image: python:3.12-slim  # or node:22-slim based on detection

definitions:
  caches:
    pip: ~/.cache/pip
    pnpm: ~/.local/share/pnpm/store
  services:
    mysql:
      image: mysql:8.0
      variables:
        MYSQL_ROOT_PASSWORD: testpass
        MYSQL_DATABASE: test_db
      memory: 1024
    mongodb:
      image: mongo:7
      memory: 1024
    redis:
      image: redis:7-alpine
      memory: 512
    meilisearch:
      image: getmeili/meilisearch:latest
      variables:
        MEILI_MASTER_KEY: test-master-key
      memory: 512
```

**Pipelines:**

**pull-requests (all branches):**
- Step 1: Lint
  - Caches: pip or node
  - Script: install, lint, format check
- Step 2: Test
  - Caches: pip or node
  - Services: detected databases
  - Script: run tests with coverage
  - Artifacts: coverage reports (max 5 days)
- Step 3: Build
  - Caches: pip or node, docker
  - Script: build application
  - Artifacts: build output

**branches main (only with `--full`):**
- Step 1: Lint + Test + Build (same as PR)
- Step 2: Build Docker Image
  - Script: build and push to registry
  - Caches: docker
- Step 3: Deploy to Staging
  - Deployment: staging
  - Script: deploy
  - Trigger: automatic
- Step 4: Deploy to Production
  - Deployment: production
  - Script: deploy
  - Trigger: manual

**branches develop:**
- Same as main but deploys only to staging (no production step)

**tags v*.*.*  (only with `--full`):**
- Full pipeline: lint, test, build, push Docker with version tag, create release

**Custom pipelines (only with `--full`):**
- `security-scan`: manual trigger for security audit
  - Script: pip-audit / npm audit, Trivy scan

---

## Step 3: Ensure Pipeline Features Are Included

Verify every generated pipeline includes ALL of these features. Go through this checklist and add any missing features:

### Feature 1: Caching
- Python: cache `~/.cache/pip` and `.venv/` directory
- Node: cache based on package manager (`~/.npm`, `~/.local/share/pnpm/store`, or `~/.cache/yarn`)
- Docker: use BuildKit cache mounts and platform-specific layer caching
- Cache key should include OS, language version, and lockfile hash

### Feature 2: Matrix Testing
- Python projects: test against `3.11` and `3.12` (or versions detected from pyproject.toml)
- Node projects: test against `20` and `22` (or versions detected from package.json engines)
- If both Python and Node are detected (e.g., FastAPI + Next.js monorepo), create separate test jobs for each

### Feature 3: Service Containers
Only include services that were actually detected in Step 1. For each service:
- **MySQL 8.0**: port 3306, root password from secrets, test database creation, health check with `mysqladmin ping -h 127.0.0.1`
- **MongoDB 7**: port 27017, no auth for test environment
- **Redis 7**: port 6379, health check with `redis-cli ping`
- **Meilisearch**: port 7700, master key set for tests, health check with `curl http://localhost:7700/health`
- **PostgreSQL 16** (if detected instead of MySQL): port 5432, test user and database
- **RabbitMQ** (if detected): port 5672, management port 15672
- **Elasticsearch** (if detected): port 9200, single-node mode

### Feature 4: Environment Variables
- All secrets referenced via platform secret stores (`${{ secrets.X }}` for GitHub, `$CI_VARIABLE` for GitLab, `$VARIABLE` for Bitbucket)
- Required secrets documented in the summary output:
  - `DATABASE_URL` — database connection string
  - `MONGODB_URL` — MongoDB connection string
  - `REDIS_URL` — Redis connection string
  - `DOCKER_REGISTRY` — container registry URL
  - `DOCKER_USERNAME` — registry username
  - `DOCKER_PASSWORD` — registry password/token
  - `SLACK_WEBHOOK_URL` — for notifications
  - `DEPLOY_SSH_KEY` — for SSH-based deployment
  - Any project-specific secrets detected from `.env.example`

### Feature 5: Branch Protection
- CI pipeline runs on pull requests to `main` and `develop`
- CD pipeline runs on push to `main` (production) and `develop` (staging)
- Release pipeline runs on version tags only
- Security pipeline runs weekly on schedule and on dependency file changes

### Feature 6: Docker Build and Push (only with `--full`)
- Use Docker Buildx for multi-platform builds (`linux/amd64,linux/arm64`)
- Push to GHCR (`ghcr.io`) by default, with comments showing how to switch to ECR or DockerHub
- Tag strategy: branch name, commit SHA short, `latest` for main, semver for tags
- Use BuildKit cache for faster builds

### Feature 7: Deploy Stages (only with `--full`)
- Staging: automatic deployment on push to develop
- Production: manual approval required (GitHub environment protection rules, GitLab `when: manual`, Bitbucket manual trigger)
- Include rollback comments/instructions in the pipeline
- Include smoke test step after each deployment

### Feature 8: Notifications (only with `--full`)
- On failure: send notification to Slack webhook or Discord webhook
- Include: workflow name, branch, commit message, author, link to failed run
- Configurable via secrets (notification is skipped if webhook URL secret is not set)

### Feature 9: Artifact Upload
- Test coverage reports (XML for CI integration, HTML for human review)
- Build artifacts (compiled output, Docker image digest)
- Security scan reports (SARIF format where supported)
- Retention: 7 days for test reports, 30 days for release artifacts

### Feature 10: Concurrency Control
- GitHub Actions: use `concurrency` group to cancel in-progress runs
- GitLab CI: use `interruptible: true` on jobs
- Bitbucket: use `max-time` on steps

---

## Step 4: Generate Docker Files (if missing)

Check if Docker files already exist. Only generate missing files.

### `Dockerfile` (for backend, if not present)

Generate a multi-stage Dockerfile following these rules:

**For Python/FastAPI:**
- Stage 1 (`builder`): install dependencies in a virtual environment
- Stage 2 (`runner`): copy only the venv and application code
- Use `python:3.12-slim` as base
- Run as non-root user (`appuser`)
- Include `HEALTHCHECK` instruction
- Expose detected port (default 8000 for FastAPI)
- Use `gunicorn` with `uvicorn` workers for production
- Include proper `.dockerignore`

**For Node.js/Next.js:**
- Stage 1 (`deps`): install dependencies
- Stage 2 (`builder`): build the application
- Stage 3 (`runner`): copy standalone build output only
- Use `node:22-alpine` as base
- Run as non-root user (`nextjs`)
- Enable Next.js standalone output mode
- Include `HEALTHCHECK` instruction
- Expose port 3000

### `Dockerfile.frontend` (if both backend and frontend detected, and not present)

Generate a separate frontend Dockerfile using the Next.js multi-stage pattern above.

### `.dockerignore` (if not present)

Generate a comprehensive `.dockerignore`:
```
node_modules
.next
.git
.github
.gitlab
*.md
.env
.env.*
!.env.example
__pycache__
*.pyc
.pytest_cache
.mypy_cache
.ruff_cache
coverage
htmlcov
.vscode
.idea
*.log
tmp
temp
dist
build
.DS_Store
```

---

## Step 5: Output Summary

After generating all files, print the following summary. Replace placeholders with actual values from detection and generation.

```
╔══════════════════════════════════════════════════════════════════════╗
║  CI/CD PIPELINE GENERATED: [GitHub Actions | GitLab CI | Bitbucket] ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  Detected Stack:                                                     ║
║  ├── Backend:    [FastAPI / Django / Express / etc.]                  ║
║  ├── Frontend:   [Next.js / React Native / etc.]                     ║
║  ├── Languages:  [Python 3.11, 3.12 / Node 20, 22]                  ║
║  ├── Databases:  [MySQL 8.0, MongoDB 7, Redis 7]                     ║
║  ├── Tests:      [pytest / jest / vitest]                            ║
║  └── Linters:    [ruff, mypy / eslint, tsc]                         ║
║                                                                      ║
║  Files Created:                                                      ║
║  ├── [path/to/ci.yml]         — Lint, type-check, test, build       ║
║  ├── [path/to/cd.yml]         — Docker build, push, deploy          ║
║  ├── [path/to/security.yml]   — Weekly security scans               ║
║  ├── [path/to/release.yml]    — Auto-release on semver tag          ║
║  ├── [Dockerfile]             — Multi-stage, non-root, healthcheck  ║
║  ├── [Dockerfile.frontend]    — Next.js standalone build            ║
║  └── [.dockerignore]          — Comprehensive ignore rules          ║
║                                                                      ║
║  Pipeline Stages:                                                    ║
║  Lint --> Type-Check --> Test --> Build --> Security --> Deploy       ║
║                                                                      ║
║  Services Configured:                                                ║
║  ├── MySQL 8.0     (port 3306)                                       ║
║  ├── MongoDB 7     (port 27017)                                      ║
║  ├── Redis 7       (port 6379)                                       ║
║  └── Meilisearch   (port 7700)                                       ║
║                                                                      ║
║  Matrix Testing:                                                     ║
║  ├── Python: [3.11, 3.12]                                            ║
║  └── Node:   [20, 22]                                                ║
║                                                                      ║
║  Deployment:                                                         ║
║  ├── Staging:    auto on push to develop                             ║
║  └── Production: manual approval on push to main                     ║
║                                                                      ║
║  Notifications: Slack/Discord on pipeline failure                    ║
║  Artifacts:     Coverage reports, build artifacts, SARIF scans       ║
║  Caching:       pip/npm/pnpm + Docker layer cache                   ║
║  Concurrency:   Cancel in-progress on new push                      ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║  MANUAL STEPS REQUIRED:                                              ║
║                                                                      ║
║  1. Add these secrets to your CI platform settings:                  ║
║     - DOCKER_USERNAME        (container registry username)           ║
║     - DOCKER_PASSWORD        (container registry password/token)     ║
║     - SLACK_WEBHOOK_URL      (Slack incoming webhook URL)            ║
║     - DEPLOY_SSH_KEY         (SSH private key for deployment)        ║
║     - DATABASE_URL           (production database URL)               ║
║     - MONGODB_URL            (production MongoDB URL)                ║
║     - REDIS_URL              (production Redis URL)                  ║
║                                                                      ║
║  2. Enable branch protection rules:                                  ║
║     - Require status checks to pass before merging                   ║
║     - Require pull request reviews                                   ║
║     - Require branches to be up to date                              ║
║                                                                      ║
║  3. Set up deployment environments:                                  ║
║     - Create 'staging' environment                                   ║
║     - Create 'production' environment with required reviewers        ║
║                                                                      ║
║  4. Verify Docker registry access:                                   ║
║     - Ensure GHCR/ECR/DockerHub credentials are valid                ║
║     - Test: docker login [registry]                                  ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

Adjust the summary:
- Only list files that were actually created (not skipped because they already existed)
- Only list services that were actually detected
- Only list matrix versions that apply to the detected stack
- Only show deployment section if `--full` was specified
- List any files that were SKIPPED because they already existed, with a note

After the summary, provide a brief explanation of how to run the pipeline locally for testing:
- For GitHub Actions: recommend `act` tool (`brew install act && act pull_request`)
- For GitLab CI: recommend `gitlab-runner exec docker [job-name]`
- For Bitbucket: recommend `bbrun` or Docker-based local testing

---

## Important Rules

1. **Do NOT hardcode values** — always use detected stack information from Step 1
2. **Do NOT include services that were not detected** — only add MySQL if MySQL was found, etc.
3. **Use the correct package manager** — never assume npm; use whatever was detected
4. **Include comments in generated YAML** — explain non-obvious configuration choices
5. **Follow YAML best practices** — proper indentation (2 spaces), quoted strings where needed, anchors for repeated blocks
6. **Test command accuracy** — ensure all test/lint/build commands match the actual project tooling
7. **Respect existing files** — never silently overwrite; always warn and confirm
8. **Security first** — never expose secrets in logs, always use platform secret stores
9. **Keep pipelines fast** — use caching aggressively, run independent jobs in parallel, fail fast on lint errors
10. **Production quality** — generated pipelines should work without modification for the detected stack
