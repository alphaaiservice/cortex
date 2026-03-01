---
description: "Prepare and execute deployment with pre-flight checks, security scan, and post-deploy health verification. Usage: /deploy <environment> (staging|production)"
---

# Deployment Automation

Deploy to: **$ARGUMENTS**

Parse $ARGUMENTS:
- **Environment**: `staging`, `production`, `dev`, or custom environment name
- **Default**: If no argument given, ask the user which environment

⚠️ **SAFETY**: This command performs pre-flight checks but will ASK FOR CONFIRMATION before any destructive or deployment action.

---

## Step 1: Pre-Flight Checks

Run all checks in parallel using Agent tool:

### Check 1: Git Status
```bash
echo "=== Branch ==="
git branch --show-current
echo "=== Status ==="
git status --short
echo "=== Unpushed Commits ==="
git log origin/$(git branch --show-current)..HEAD --oneline 2>/dev/null
echo "=== Last 5 Commits ==="
git log --oneline -5
```
- Ensure working directory is clean
- Ensure on correct branch (main for production, develop for staging)
- Ensure all commits are pushed

### Check 2: Tests Pass
```bash
npm test 2>&1 || pytest 2>&1 || go test ./... 2>&1 || cargo test 2>&1
```

### Check 3: Build Succeeds
```bash
npm run build 2>&1 || python -m py_compile *.py 2>&1 || go build ./... 2>&1
```

### Check 4: Lint Clean
```bash
npm run lint 2>&1 || flake8 . 2>&1 || golangci-lint run 2>&1
```

### Check 5: Basic Dependency Security
```bash
npm audit --audit-level=high 2>&1 || safety check 2>&1 || pip audit 2>&1
```

### Check 6: Environment Verification
- Verify all required env vars are set for target environment
- Check .env.example vs actual environment
- Verify external service connectivity (if possible)

---

## Step 2: Full Security Scan (MANDATORY for Production)

If deploying to **production**, run a comprehensive security scan BEFORE proceeding.
If deploying to **staging**, this step is optional but recommended.

### 2a. Secret Detection
Scan all source files for accidentally committed secrets:
```bash
echo "=== Scanning for Hardcoded Secrets ==="
grep -rn --include="*.py" --include="*.ts" --include="*.js" --include="*.json" --include="*.yaml" --include="*.yml" --include="*.env*" \
  -E "(password|secret|api_key|apikey|token|private_key|access_key)\s*[:=]\s*['\"][^'\"]{8,}" \
  --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=__pycache__ \
  . 2>/dev/null | grep -vi "example\|placeholder\|changeme\|your_\|xxx\|test" | head -20
```
**If secrets found**: BLOCKER — list the files and line numbers, STOP deployment.

### 2b. OWASP Top 10 Quick Scan
For Python (FastAPI) projects:
```bash
echo "=== OWASP Quick Scan ==="
# SQL Injection: raw SQL queries without parameterization
grep -rn "execute.*f['\"]" --include="*.py" --exclude-dir=.venv . 2>/dev/null | head -10
# XSS: unescaped output
grep -rn "innerHTML\|dangerouslySetInnerHTML\|v-html" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.vue" . 2>/dev/null | head -10
# Insecure deserialization
grep -rn "pickle\.load\|yaml\.load\b" --include="*.py" --exclude-dir=.venv . 2>/dev/null | head -10
```

### 2c. Auth Configuration Check
```bash
echo "=== Auth Security Check ==="
# Verify JWT uses HTTP-only cookies (not localStorage)
grep -rn "localStorage\|sessionStorage" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" . 2>/dev/null | grep -i "token\|jwt\|auth" | head -10
# Verify CORS is configured
grep -rn "CORSMiddleware\|cors" --include="*.py" . 2>/dev/null | head -5
# Verify CSRF protection
grep -rn "csrf\|CSRFProtect" --include="*.py" . 2>/dev/null | head -5
```

### 2d. Security Scan Report
```
╔══════════════════════════════════════════════╗
║      SECURITY SCAN (Pre-Deploy)              ║
╠══════════════════════════════════════════════╣
║ Secret Detection:  ✅ PASS / 🔴 BLOCKER     ║
║ OWASP Quick Scan:  ✅ PASS / 🟡 WARNING     ║
║ Auth Security:     ✅ PASS / 🟡 WARNING     ║
║ Dependency Audit:  ✅ PASS / 🟡 WARNING     ║
╠══════════════════════════════════════════════╣
║ Overall:  ✅ CLEAR / 🔴 BLOCKED              ║
╚══════════════════════════════════════════════╝
```

If 🔴 BLOCKER found: STOP deployment. List exact issues with file:line.
If only 🟡 WARNINGS for production: Ask user to confirm they accept the risks.
If staging: Proceed with warnings noted.

---

## Step 3: Pre-Flight Report

Generate a clear report combining Step 1 and Step 2:

```
╔══════════════════════════════════════════════╗
║     DEPLOYMENT PRE-FLIGHT CHECK              ║
╠══════════════════════════════════════════════╣
║ Environment:  [staging/production]           ║
║ Branch:       [current branch]               ║
║ Last Commit:  [hash] [message]               ║
╠══════════════════════════════════════════════╣
║ Tests:        ✅ PASS / ❌ FAIL              ║
║ Build:        ✅ PASS / ❌ FAIL              ║
║ Lint:         ✅ PASS / ❌ FAIL              ║
║ Security:     ✅ PASS / ⚠️ WARN / 🔴 BLOCK ║
║ Git Status:   ✅ CLEAN / ❌ DIRTY            ║
║ Env Vars:     ✅ SET / ❌ MISSING            ║
╚══════════════════════════════════════════════╝
```

If ANY critical check fails → **STOP and report the failures**.

---

## Step 4: Deployment Steps

If all checks pass, guide through deployment:

### For K3s Cluster:

**Auto-detect**: If `k8s/` directory exists with Traefik IngressRoute manifests, use K3s deployment.
**Reference**: Load `skills/alpha-architecture/references/INFRA_HOSTINGER_K3S.md` for infrastructure details.

> **IMPORTANT — Before deploying to a K3s cluster, Claude MUST ask the user for their infrastructure details:**
>
> - **Registry IP and port** (e.g., `10.0.0.4:5000`) → used as `${REGISTRY_IP}:${REGISTRY_PORT}`
> - **Gateway node IP** (e.g., the node running Traefik/ingress) → used as `${GATEWAY_NODE_IP}`
> - **App node IP** (e.g., the node running application workloads) → used as `${APP_NODE_IP}`
> - **DB node IP** (if applicable) → used as `${DB_NODE_IP}`
> - **Redis node IP** (if applicable) → used as `${REDIS_NODE_IP}`
> - **Domain name** → used as `${YOUR_DOMAIN}`
> - **CI/CD runner name** (if applicable) → used as `${RUNNER_NAME}`
> - **Cluster node hostnames** (e.g., `edge01`, `app01`) → used in summary
>
> Do NOT assume any IPs, hostnames, or domains. Always collect these from the user first.

1. **Build Docker Image**:
```bash
# Build with commit SHA tag
IMAGE_TAG=$(git rev-parse --short HEAD)
APP_NAME="$(basename $(pwd))"
IMAGE="${REGISTRY_IP}:${REGISTRY_PORT}/alphaai-platform/${APP_NAME}"

docker build -t ${IMAGE}:${IMAGE_TAG} -t ${IMAGE}:latest .
```

2. **Push to Private Registry**:
```bash
# No docker login needed — registry is on WireGuard network
docker push ${IMAGE}:${IMAGE_TAG}
docker push ${IMAGE}:latest
```

3. **Apply K8s Manifests**:
```bash
kubectl apply -f k8s/
```

4. **Rolling Update**:
```bash
kubectl set image deployment/${APP_NAME} ${APP_NAME}=${IMAGE}:${IMAGE_TAG}
kubectl rollout status deployment/${APP_NAME} --timeout=120s
```

5. **Update Celery Workers** (if present):
```bash
# Worker
if kubectl get deployment ${APP_NAME}-celery-worker &>/dev/null; then
  kubectl set image deployment/${APP_NAME}-celery-worker worker=${IMAGE}:${IMAGE_TAG}
  kubectl rollout status deployment/${APP_NAME}-celery-worker --timeout=120s
fi

# Beat
if kubectl get deployment ${APP_NAME}-celery-beat &>/dev/null; then
  kubectl set image deployment/${APP_NAME}-celery-beat beat=${IMAGE}:${IMAGE_TAG}
  kubectl rollout status deployment/${APP_NAME}-celery-beat --timeout=120s
fi
```

6. **Verify Deployment**:
```bash
kubectl get pods -l app=${APP_NAME}
kubectl logs deployment/${APP_NAME} --tail=20
```

7. **Rollback** (if health check fails):
```bash
kubectl rollout undo deployment/${APP_NAME}
# Also rollback workers if needed:
kubectl rollout undo deployment/${APP_NAME}-celery-worker 2>/dev/null
kubectl rollout undo deployment/${APP_NAME}-celery-beat 2>/dev/null
```

### For Docker-based deployments:
1. Build the Docker image with version tag
2. Push to container registry
3. Update deployment manifest / docker-compose
4. Trigger rolling update

### For Vercel/Netlify:
1. Verify framework configuration
2. Trigger deployment via CLI

### For GCP Cloud Run (Detailed):
1. **Authenticate & Configure**:
```bash
# Authenticate with GCP
gcloud auth login
gcloud config set project $GCP_PROJECT_ID
gcloud config set run/region $GCP_REGION

# Enable required APIs
gcloud services enable run.googleapis.com containerregistry.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com
```

2. **Build & Push Container Image**:
```bash
# Option A: Build locally and push to Artifact Registry
export IMAGE_URI="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${REPO_NAME}/${SERVICE_NAME}:${VERSION_TAG}"
docker build -t $IMAGE_URI -f docker/Dockerfile .
docker push $IMAGE_URI

# Option B: Build via Cloud Build (recommended)
gcloud builds submit --tag $IMAGE_URI .
```

3. **Deploy to Cloud Run**:
```bash
gcloud run deploy $SERVICE_NAME \
  --image $IMAGE_URI \
  --platform managed \
  --region $GCP_REGION \
  --allow-unauthenticated \
  --port 8000 \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 10 \
  --set-env-vars "ENV=production,DATABASE_URL=${DATABASE_URL}" \
  --set-secrets "SECRET_KEY=secret-key:latest,DB_PASSWORD=db-password:latest" \
  --timeout 300 \
  --concurrency 80
```

4. **Verify Deployment**:
```bash
# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $GCP_REGION --format 'value(status.url)')
echo "Deployed to: $SERVICE_URL"

# Quick health check
curl -s -o /dev/null -w "%{http_code}" "${SERVICE_URL}/health"

# Check revision status
gcloud run revisions list --service $SERVICE_NAME --region $GCP_REGION --limit 5
```

5. **Traffic Management (for canary/gradual rollout)**:
```bash
# Split traffic between revisions
gcloud run services update-traffic $SERVICE_NAME \
  --region $GCP_REGION \
  --to-revisions "${NEW_REVISION}=10,${OLD_REVISION}=90"

# After verification, shift 100% to new revision
gcloud run services update-traffic $SERVICE_NAME \
  --region $GCP_REGION \
  --to-latest
```

6. **Rollback (if needed)**:
```bash
# List revisions
gcloud run revisions list --service $SERVICE_NAME --region $GCP_REGION

# Rollback to previous revision
gcloud run services update-traffic $SERVICE_NAME \
  --region $GCP_REGION \
  --to-revisions "${PREVIOUS_REVISION}=100"
```

### For GCP (GKE / App Engine):
1. Build with Cloud Build
2. Deploy to GKE or App Engine
3. Verify health endpoint

### For AWS:
1. Package application
2. Deploy via SAM / CDK / ECS
3. Verify health endpoint

---

## Step 5: Post-Deployment Health Check (MANDATORY)

After deployment completes, run a comprehensive health verification. Do NOT skip this step.

### 5a. Endpoint Health
```bash
SERVICE_URL="https://[deployment-url]"

echo "=== Health Endpoint ==="
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${SERVICE_URL}/health" 2>/dev/null)
echo "Health: $HEALTH_STATUS"

echo "=== Readiness Endpoint ==="
READY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${SERVICE_URL}/ready" 2>/dev/null || echo "N/A")
echo "Ready: $READY_STATUS"

echo "=== API Status ==="
API_STATUS=$(curl -s "${SERVICE_URL}/api/status" 2>/dev/null || echo "N/A")
echo "API: $API_STATUS"
```

### For K3s deployments:
```bash
# Check pod health directly
kubectl get pods -l app=${APP_NAME} -o wide
kubectl exec deployment/${APP_NAME} -- curl -s localhost:8000/health

# Check via Traefik (from any K3s node)
APP_HOST=$(grep -o "Host(\`[^)]*\`)" k8s/*.yaml | head -1 | tr -d "Host(\`)")
curl -s -H "Host: ${APP_HOST}" http://${GATEWAY_NODE_IP}/health
curl -s -H "Host: ${APP_HOST}" http://${APP_NODE_IP}/health
```

### 5b. Service Dependency Checks
```bash
echo "=== Service Dependencies ==="
# Check if the app can reach its databases and services
DEPS_STATUS=$(curl -s "${SERVICE_URL}/health/dependencies" 2>/dev/null || echo "N/A")
echo "Dependencies: $DEPS_STATUS"
```

### 5c. Response Time Check
```bash
echo "=== Response Time ==="
for i in 1 2 3 4 5; do
  TIME=$(curl -s -o /dev/null -w "%{time_total}" "${SERVICE_URL}/health" 2>/dev/null)
  echo "Request $i: ${TIME}s"
done
```

### 5d. Smoke Tests
Run basic functionality tests against the deployed environment:
```bash
echo "=== Smoke Tests ==="
# Test authentication endpoint is reachable
curl -s -o /dev/null -w "Auth endpoint: %{http_code}\n" "${SERVICE_URL}/api/v1/auth/login" -X POST -H "Content-Type: application/json" -d '{}' 2>/dev/null

# Test public endpoints
curl -s -o /dev/null -w "Public API: %{http_code}\n" "${SERVICE_URL}/api/v1/public/health" 2>/dev/null

# Test docs endpoint
curl -s -o /dev/null -w "API Docs: %{http_code}\n" "${SERVICE_URL}/docs" 2>/dev/null
```

### 5e. Health Check Report
```
╔══════════════════════════════════════════════╗
║     POST-DEPLOYMENT HEALTH CHECK             ║
╠══════════════════════════════════════════════╣
║ Health Endpoint:   ✅ 200 / ❌ [code]        ║
║ Readiness:         ✅ 200 / ❌ [code]        ║
║ API Status:        ✅ OK / ❌ ERROR          ║
║ Dependencies:      ✅ All OK / ⚠️ Degraded  ║
║ Avg Response Time: [X.XXs]                   ║
║ Smoke Tests:       ✅ [N]/[N] passing        ║
╠══════════════════════════════════════════════╣
║ Overall:  ✅ HEALTHY / ⚠️ DEGRADED / ❌ DOWN ║
╚══════════════════════════════════════════════╝
```

**If ❌ DOWN**: Immediately suggest rollback:
```
🔴 DEPLOYMENT UNHEALTHY — Recommend immediate rollback:
   [Rollback command specific to the deployment platform]
```

**If ⚠️ DEGRADED**: Warn but do not auto-rollback:
```
🟡 DEPLOYMENT DEGRADED — Some services are not responding correctly.
   Investigate: [specific failing checks]
   Consider: /debug [error details]
```

**If ✅ HEALTHY**: Proceed to deployment log.

---

## Step 6: Generate Deployment Log

Create or append to `DEPLOY_LOG.md`:
```markdown
## Deployment [date] [time]
- **Environment**: [target]
- **Version**: [git tag/hash]
- **Branch**: [branch-name]
- **Deployed by**: [user]
- **Pre-flight**: All checks passed
- **Security Scan**: ✅ Clear / ⚠️ [N] warnings accepted
- **Post-Deploy Health**: ✅ Healthy / ⚠️ Degraded / ❌ Down
- **Avg Response Time**: [X.XXs]
- **Status**: ✅ Success / ❌ Failed / ⚠️ Degraded
- **Rollback command**: [command to rollback]
```

---

## Step 7: Update Sprint Plan (if exists)

After successful deployment:

```
1. Check if SPRINT_PLAN.md exists in the project root
2. If found:
   a. Parse the deployment for task references:
      - Check commit messages for sprint task IDs
      - Match deployment type against sprint task descriptions
      - Look for deployment/devops/infrastructure tasks
   b. Update matched tasks: ⬜ → ✅ (mark as deployed)
   c. Update sprint progress counters
   d. Print sprint progress:
      "Sprint [N] Progress: [completed]/[total] tasks ([percentage]%)"
   e. Check if any blocked tasks are now unblocked:
      "✅ Deployment complete → Task [X] is now unblocked"
3. If not found: skip silently
```

---

## Step 8: Deployment Summary

```
╔══════════════════════════════════════════════════════════════╗
║  DEPLOYED ✅                                                 ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Environment:    [staging/production]                         ║
║  Version:        [git tag/hash]                               ║
║  URL:            [deployment URL]                             ║
║                                                               ║
║  Registry:     ${REGISTRY_IP}:${REGISTRY_PORT}/{org}/{app}:{tag}  ║
║  Cluster:      K3s (${GATEWAY_NODE_IP} + ${APP_NODE_IP})  ║
║  Ingress:      Traefik IngressRoute                       ║
║                                                               ║
║  Security Scan:  ✅ Clear (0 blockers, [N] warnings)         ║
║  Health Check:   ✅ Healthy (avg [X.XX]s response)           ║
║  Smoke Tests:    ✅ [N]/[N] passing                          ║
║                                                               ║
║  Sprint Progress: [n]/[total] tasks ([%]%)                   ║
║                                                               ║
║  Rollback:  [rollback command]                               ║
║  Logs:      DEPLOY_LOG.md updated                            ║
╚══════════════════════════════════════════════════════════════╝
```
