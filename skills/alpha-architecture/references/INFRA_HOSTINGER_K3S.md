# Self-Hosted K3s Infrastructure Reference

> This file is a pattern reference for self-hosted K3s clusters. Commands (`/gen-ci`, `/gen-infra`, `/deploy`, `/auto-build`) will ask the user for their specific node IPs, hostnames, and configuration before generating manifests.

---

## User Configuration Required

Before using any templates or commands in this document, you **must** provide the following values. Every placeholder below appears in manifests, scripts, and commands throughout this reference.

| Placeholder              | Description                                                        | Example                |
| ------------------------ | ------------------------------------------------------------------ | ---------------------- |
| `${GATEWAY_NODE_IP}`     | WireGuard VPN IP of the gateway/edge node (Node 1)                | `10.0.0.1`             |
| `${APP_NODE_IP}`         | WireGuard VPN IP of the application/compute node (Node 2)         | `10.0.0.2`             |
| `${REDIS_NODE_IP}`       | WireGuard VPN IP of the Redis/cache node (Node 3)                 | `10.0.0.3`             |
| `${DB_NODE_IP}`          | WireGuard VPN IP of the database/storage node (Node 4)            | `10.0.0.4`             |
| `${GATEWAY_HOST}`        | Hostname of the gateway node                                       | `edge01`               |
| `${APP_HOST}`            | Hostname of the application node                                   | `app01`                |
| `${REDIS_HOST}`          | Hostname of the Redis node                                         | `redis01`              |
| `${DB_HOST}`             | Hostname of the database node                                      | `db01`                 |
| `${VPS1_PUBLIC_IP}`      | Public IP address of VPS 1 (primary gateway)                       | `203.0.113.10`         |
| `${VPS4_PUBLIC_IP}`      | Public IP address of VPS 4 (failover gateway)                      | `203.0.113.20`         |
| `${YOUR_DOMAIN}`         | Your root domain (used for DNS, Cloudflare, IngressRoute matching) | `example.cloud`        |
| `${RUNNER_NAME}`         | Name of the self-hosted GitHub Actions runner                      | `my-runner`            |
| `${ORG_NAME}`            | GitHub organization or Docker registry organization name           | `my-org`               |
| `${VPN_SUBNET}`          | WireGuard VPN subnet CIDR                                         | `10.0.0.0/24`          |
| `${REGISTRY_PORT}`       | Port for the private Docker registry                               | `5000`                 |
| `${NFS_EXPORT_PATH}`     | NFS export path on the database/storage node                       | `/mnt/k3s_shared_storage` |

---

## Architecture Overview

4 VPS nodes connected via WireGuard mesh VPN (`${VPN_SUBNET}`):

| VPS   | Hostname          | WireGuard IP        | Resources    | Role                                                                    |
| ----- | ----------------- | ------------------- | ------------ | ----------------------------------------------------------------------- |
| VPS 1 | `${GATEWAY_HOST}` | `${GATEWAY_NODE_IP}`| 8GB / 100GB  | Primary Gateway -- HAProxy, Prometheus, K3s CP1, Cloudflare Origin A    |
| VPS 2 | `${APP_HOST}`     | `${APP_NODE_IP}`    | 32GB / 400GB | App Engine -- K3s CP2 + Worker (main compute), Docker CE, GitHub Runner |
| VPS 3 | `${REDIS_HOST}`   | `${REDIS_NODE_IP}`  | 8GB / 100GB  | Speed Layer -- Dedicated Redis (Docker)                                 |
| VPS 4 | `${DB_HOST}`      | `${DB_NODE_IP}`     | 8GB / 100GB  | Data Layer -- MySQL, MongoDB, NFS, Docker Registry, HAProxy, Cloudflare Origin B |

### Node Responsibilities

**`${GATEWAY_HOST}` (VPS 1)** -- The front door. All public traffic arrives here first via Cloudflare.
HAProxy terminates TLS using Cloudflare Origin Certificates and forwards plain HTTP to
Traefik inside the K3s cluster. Prometheus scrapes all nodes over WireGuard. Also acts as
K3s control-plane node 1 for HA.

**`${APP_HOST}` (VPS 2)** -- The workhorse. Dual role: K3s control-plane node 2 AND the primary
worker node where application pods are scheduled. Docker CE is installed for image builds.
The self-hosted GitHub Actions runner (`${RUNNER_NAME}`) runs here.

**`${REDIS_HOST}` (VPS 3)** -- Speed layer. Runs a single Redis 7 instance via Docker Compose,
exposed on port 6379. Used for application caching (db 0), Celery broker (db 1), and
Celery result backend (db 2). Redis persistence is configured with both RDB snapshots
(every 60s if >= 100 keys changed) and AOF.

**`${DB_HOST}` (VPS 4)** -- Data layer. Runs MySQL 8 (port 3306) and MongoDB 7 (port 27017)
as Docker containers. Also hosts the private Docker registry (port `${REGISTRY_PORT}`) and NFS server
for shared persistent volumes. Acts as the secondary HAProxy gateway for Cloudflare
failover (Origin B).

---

## Traffic Flow

```
Client
  --> Cloudflare CDN + WAF (terminates client-facing SSL, adds security headers)
  --> HAProxy on ${GATEWAY_HOST} :443 (Origin Cert SSL termination, TCP mode for wss://)
      [Failover: HAProxy on ${DB_HOST} :443 via Cloudflare health checks]
  --> Traefik :80 inside K3s (Host-based HTTP routing via IngressRoute CRDs)
  --> K8s Service (ClusterIP)
  --> Application Pod(s)
```

### Traffic flow detail

1. **DNS**: `*.${YOUR_DOMAIN}` A records point to both `${VPS1_PUBLIC_IP}` and `${VPS4_PUBLIC_IP}`.
   Cloudflare proxy is enabled (orange cloud), so actual origin IPs are hidden.
2. **Cloudflare**: SSL mode is "Full (Strict)". Cloudflare terminates client TLS and
   re-encrypts to origin using the Origin Certificate installed on HAProxy.
3. **HAProxy**: Listens on :443 with the Origin Certificate. Routes by SNI/Host header
   to the Traefik backend on the K3s node(s) at port 80.
4. **Traefik**: Deployed as a DaemonSet with `hostPort: 80`. Uses IngressRoute CRDs
   (apiVersion: `traefik.io/v1alpha1`) for Host-based routing.
5. **Service**: Standard ClusterIP services. No LoadBalancer or NodePort needed.
6. **Pod**: Application container with health checks.

### WebSocket Support

For WebSocket connections (e.g., Socket.IO, real-time feeds):
- HAProxy is configured in TCP mode for WebSocket backends
- Cloudflare WebSocket support is enabled at the zone level
- Traefik handles upgrade headers automatically via IngressRoute

---

## Key Design Decisions

- **K3s cluster state stored in MySQL on VPS 4** (not etcd) -- simpler backup/restore,
  leverages existing MySQL infrastructure, one fewer service to manage.
- **Dual K3s control planes** (VPS 1 + VPS 2) for HA -- if `${GATEWAY_HOST}` goes down, `${APP_HOST}`
  still manages the cluster.
- **All inter-VPS traffic uses WireGuard mesh VPN** -- every node has a WireGuard
  interface on the `${VPN_SUBNET}` subnet. No application traffic traverses the public internet
  between nodes.
- **Cloudflare provides automatic gateway failover** between VPS 1 and VPS 4 --
  Cloudflare health checks monitor both origins and routes around failures.
- **Private Docker registry at `${DB_NODE_IP}:${REGISTRY_PORT}`** -- internal WireGuard network only,
  HTTP (no TLS needed because traffic never leaves the encrypted VPN).
- **NFS shared storage from VPS 4** at `${NFS_EXPORT_PATH}` -- used for
  PersistentVolumes that need to be shared across pods/nodes.
- **Databases are NOT in K3s** -- MySQL/MongoDB run on dedicated VPS nodes as Docker
  containers. This avoids StatefulSet complexity and gives databases dedicated resources.
- **Traefik v3 as DaemonSet with hostPort:80** -- no LoadBalancer service needed,
  HAProxy already routes to node IPs directly.
- **HAProxy does SSL termination** with Cloudflare Origin Certificate -- Traefik
  receives plain HTTP, keeping the K3s config simple.
- **No cert-manager** -- Cloudflare handles public certificates, Origin Certificates
  are manually deployed to HAProxy (renewed every 15 years).
- **Self-hosted GitHub runner** -- builds happen on the same machine where Docker and
  kubectl are available, so no image push over the internet.

---

## Database Connections (from K8s pods)

These are the connection strings apps use from inside K3s pods:

| Service        | Host              | Port  | Connection String Pattern                                   |
| -------------- | ----------------- | ----- | ----------------------------------------------------------- |
| MySQL          | `${DB_NODE_IP}`   | 3306  | `mysql://user:pass@${DB_NODE_IP}:3306/db_name`             |
| MongoDB        | `${DB_NODE_IP}`   | 27017 | `mongodb://user:pass@${DB_NODE_IP}:27017/db_name`          |
| Redis          | `${REDIS_NODE_IP}`| 6379  | `redis://${REDIS_NODE_IP}:6379/0`                           |
| Celery Broker  | `${REDIS_NODE_IP}`| 6379  | `redis://${REDIS_NODE_IP}:6379/1`                           |
| Celery Result  | `${REDIS_NODE_IP}`| 6379  | `redis://${REDIS_NODE_IP}:6379/2`                           |

### Database Notes

- All database connections go over WireGuard (`${VPN_SUBNET}` addresses), never over the public internet.
- MySQL authentication uses `mysql_native_password` plugin for compatibility.
- MongoDB uses SCRAM-SHA-256 authentication.
- Redis requires no password by default (network-level security via WireGuard).
  Consider adding password authentication if your security policy requires it.
- For new applications, request database credentials from the infrastructure team.
  Each app gets its own database and user with least-privilege permissions.

---

## Docker Registry

- **URL**: `${DB_NODE_IP}:${REGISTRY_PORT}`
- **Protocol**: HTTP (insecure registry, but only accessible via WireGuard)
- **Image naming**: `${DB_NODE_IP}:${REGISTRY_PORT}/{org}/{app-name}:{tag}`
- **K3s configured** with registry mirror at `/etc/rancher/k3s/registries.yaml`
- **Garbage collection**: Runs daily at 3:00 AM on `${DB_HOST}` via cron

### K3s Registry Configuration

The following is deployed on all K3s nodes at `/etc/rancher/k3s/registries.yaml`:

```yaml
mirrors:
  "${DB_NODE_IP}:${REGISTRY_PORT}":
    endpoint:
      - "http://${DB_NODE_IP}:${REGISTRY_PORT}"
```

### Docker Daemon Configuration (`${APP_HOST}`)

On `${APP_HOST}` where builds happen, `/etc/docker/daemon.json` includes:

```json
{
  "insecure-registries": ["${DB_NODE_IP}:${REGISTRY_PORT}"]
}
```

### Image Tagging Convention

- **CI builds**: `${DB_NODE_IP}:${REGISTRY_PORT}/{org}/{app-name}:{git-sha-8-chars}`
- **Latest**: `${DB_NODE_IP}:${REGISTRY_PORT}/{org}/{app-name}:latest` (always tagged alongside SHA)
- **Manual builds**: `${DB_NODE_IP}:${REGISTRY_PORT}/{org}/{app-name}:manual-{date}`

---

## CI/CD Pipeline

```
Push to GitHub (main branch)
  --> Self-hosted runner on ${APP_HOST} (${RUNNER_NAME})
  --> Docker build on ${APP_HOST}
  --> Docker push to ${DB_NODE_IP}:${REGISTRY_PORT}/{org}/{app-name}:{sha}
  --> kubectl apply -f k8s/ (apply all manifests)
  --> kubectl set image deployment/{name} (rolling update with new tag)
  --> kubectl rollout status (wait for rollout)
  --> Update Celery workers/beat if they exist
  --> Cleanup old Docker images
```

### GitHub Actions Workflow Template (.github/workflows/deploy.yml)

```yaml
name: Build & Deploy to K3s

on:
  push:
    branches: [main]

env:
  REGISTRY: ${DB_NODE_IP}:${REGISTRY_PORT}
  APP_NAME: APP_NAME_HERE          # K8s deployment name
  APP_NAMESPACE: default           # K8s namespace
  IMAGE_NAME: ${ORG_NAME}/APP_NAME # Registry image path

jobs:
  build-and-deploy:
    runs-on: self-hosted
    timeout-minutes: 15

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set image tag
        id: tag
        run: |
          echo "sha=${GITHUB_SHA::8}" >> "$GITHUB_OUTPUT"
          echo "image=${REGISTRY}/${IMAGE_NAME}" >> "$GITHUB_OUTPUT"

      - name: Build Docker image
        run: |
          docker build \
            -t ${{ steps.tag.outputs.image }}:${{ steps.tag.outputs.sha }} \
            -t ${{ steps.tag.outputs.image }}:latest \
            .

      - name: Push to private registry
        run: |
          docker push ${{ steps.tag.outputs.image }}:${{ steps.tag.outputs.sha }}
          docker push ${{ steps.tag.outputs.image }}:latest

      - name: Apply K8s manifests
        run: kubectl apply -f k8s/

      - name: Update deployment image
        run: |
          kubectl -n ${{ env.APP_NAMESPACE }} set image \
            deployment/${{ env.APP_NAME }} \
            ${{ env.APP_NAME }}=${{ steps.tag.outputs.image }}:${{ steps.tag.outputs.sha }}
          kubectl -n ${{ env.APP_NAMESPACE }} rollout status \
            deployment/${{ env.APP_NAME }} --timeout=120s

      - name: Update Celery workers (if present)
        run: |
          if kubectl -n ${{ env.APP_NAMESPACE }} get deployment ${{ env.APP_NAME }}-celery-worker &>/dev/null; then
            kubectl -n ${{ env.APP_NAMESPACE }} set image \
              deployment/${{ env.APP_NAME }}-celery-worker \
              worker=${{ steps.tag.outputs.image }}:${{ steps.tag.outputs.sha }}
            kubectl -n ${{ env.APP_NAMESPACE }} rollout status \
              deployment/${{ env.APP_NAME }}-celery-worker --timeout=120s
          fi
          if kubectl -n ${{ env.APP_NAMESPACE }} get deployment ${{ env.APP_NAME }}-celery-beat &>/dev/null; then
            kubectl -n ${{ env.APP_NAMESPACE }} set image \
              deployment/${{ env.APP_NAME }}-celery-beat \
              beat=${{ steps.tag.outputs.image }}:${{ steps.tag.outputs.sha }}
            kubectl -n ${{ env.APP_NAMESPACE }} rollout status \
              deployment/${{ env.APP_NAME }}-celery-beat --timeout=120s
          fi

      - name: Cleanup old Docker images
        if: always()
        run: docker image prune -f --filter "until=24h" 2>/dev/null || true
```

### CI/CD Notes

- The runner is registered at the **org level** (`${ORG_NAME}`), so all repos
  in the org can use `runs-on: self-hosted`.
- Runner labels: `self-hosted`, `Linux`, `X64`.
- `kubectl` on `${APP_HOST}` is pre-configured with the K3s kubeconfig.
- Docker socket is available to the runner (no Docker-in-Docker needed).
- Timeout is 15 minutes -- if a build/deploy exceeds this, investigate resource issues.

---

## K8s Manifest Templates

### Backend Deployment + Service + IngressRoute

```yaml
# k8s/backend.yaml -- Replace ALL_CAPS placeholders
---
apiVersion: v1
kind: Secret
metadata:
  name: APP_NAME-env
  namespace: APP_NAMESPACE
type: Opaque
stringData:
  DATABASE_URL: "mysql://USER:PASS@${DB_NODE_IP}:3306/DB_NAME"
  MONGODB_URL: "mongodb://USER:PASS@${DB_NODE_IP}:27017/DB_NAME"
  REDIS_URL: "redis://${REDIS_NODE_IP}:6379/0"
  CELERY_BROKER_URL: "redis://${REDIS_NODE_IP}:6379/1"
  CELERY_RESULT_BACKEND: "redis://${REDIS_NODE_IP}:6379/2"
  SECRET_KEY: "CHANGE_ME"

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: APP_NAME
  namespace: APP_NAMESPACE
  labels:
    app: APP_NAME
spec:
  replicas: 2
  selector:
    matchLabels:
      app: APP_NAME
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  template:
    metadata:
      labels:
        app: APP_NAME
    spec:
      containers:
        - name: APP_NAME
          image: ${DB_NODE_IP}:${REGISTRY_PORT}/ORG/APP_NAME:latest
          ports:
            - containerPort: APP_PORT
          envFrom:
            - secretRef:
                name: APP_NAME-env
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: "1"
              memory: 512Mi
          readinessProbe:
            httpGet:
              path: /health
              port: APP_PORT
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: APP_PORT
            initialDelaySeconds: 10
            periodSeconds: 30
          imagePullPolicy: Always

---
apiVersion: v1
kind: Service
metadata:
  name: APP_NAME
  namespace: APP_NAMESPACE
spec:
  selector:
    app: APP_NAME
  ports:
    - port: 80
      targetPort: APP_PORT

---
# IMPORTANT: Use Traefik IngressRoute (NOT nginx Ingress)
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: APP_NAME
  namespace: APP_NAMESPACE
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`APP_SUBDOMAIN.${YOUR_DOMAIN}`)
      kind: Rule
      services:
        - name: APP_NAME
          port: 80
```

### Celery Worker + Beat

```yaml
# k8s/celery.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: APP_NAME-celery-worker
  namespace: APP_NAMESPACE
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
        - name: worker
          image: ${DB_NODE_IP}:${REGISTRY_PORT}/ORG/APP_NAME:latest
          command: ["celery", "-A", "CELERY_APP_MODULE", "worker", "--loglevel=info", "--concurrency=4"]
          envFrom:
            - secretRef:
                name: APP_NAME-env
          resources:
            requests:
              cpu: 200m
              memory: 256Mi
            limits:
              cpu: "2"
              memory: 1Gi
          livenessProbe:
            exec:
              command: ["celery", "-A", "CELERY_APP_MODULE", "inspect", "ping", "--timeout", "10"]
            initialDelaySeconds: 30
            periodSeconds: 60
            timeoutSeconds: 15

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: APP_NAME-celery-beat
  namespace: APP_NAMESPACE
spec:
  replicas: 1   # MUST be exactly 1
  selector:
    matchLabels:
      app: APP_NAME-celery-beat
  template:
    metadata:
      labels:
        app: APP_NAME-celery-beat
    spec:
      containers:
        - name: beat
          image: ${DB_NODE_IP}:${REGISTRY_PORT}/ORG/APP_NAME:latest
          command: ["celery", "-A", "CELERY_APP_MODULE", "beat", "--loglevel=info"]
          envFrom:
            - secretRef:
                name: APP_NAME-env
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 256Mi
```

### NFS PersistentVolume (for shared storage)

```yaml
# k8s/nfs-pv.yaml -- Use when pods need shared file storage
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: APP_NAME-nfs-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: ${DB_NODE_IP}
    path: ${NFS_EXPORT_PATH}/APP_NAME
  persistentVolumeReclaimPolicy: Retain

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: APP_NAME-nfs-pvc
  namespace: APP_NAMESPACE
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  volumeName: APP_NAME-nfs-pv
  storageClassName: ""
```

### CronJob Template

```yaml
# k8s/cronjob.yaml -- For periodic tasks (alternative to Celery Beat)
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: APP_NAME-TASK_NAME
  namespace: APP_NAMESPACE
spec:
  schedule: "0 */6 * * *"   # Every 6 hours
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 2
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: task
              image: ${DB_NODE_IP}:${REGISTRY_PORT}/ORG/APP_NAME:latest
              command: ["python", "manage.py", "TASK_COMMAND"]
              envFrom:
                - secretRef:
                    name: APP_NAME-env
              resources:
                requests:
                  cpu: 100m
                  memory: 128Mi
                limits:
                  cpu: 500m
                  memory: 512Mi
```

---

## Deployment Steps (Manual)

```bash
# 1. Create the application database (run on ${DB_HOST})
# MySQL:
docker exec -i mysql mysql -uroot -p'ROOT_PASS' \
  -e "CREATE DATABASE myapp; CREATE USER 'myapp'@'%' IDENTIFIED BY 'SECURE_PASS'; GRANT ALL ON myapp.* TO 'myapp'@'%'; FLUSH PRIVILEGES;"

# MongoDB:
docker exec -i mongodb mongosh --eval '
  use myapp;
  db.createUser({user: "myapp", pwd: "SECURE_PASS", roles: [{role: "readWrite", db: "myapp"}]});
'

# 2. Create K8s secret for the app
kubectl create secret generic myapp-env \
  --from-literal=DATABASE_URL="mysql://myapp:SECURE_PASS@${DB_NODE_IP}:3306/myapp" \
  --from-literal=MONGODB_URL="mongodb://myapp:SECURE_PASS@${DB_NODE_IP}:27017/myapp" \
  --from-literal=REDIS_URL="redis://${REDIS_NODE_IP}:6379/0" \
  --from-literal=CELERY_BROKER_URL="redis://${REDIS_NODE_IP}:6379/1" \
  --from-literal=CELERY_RESULT_BACKEND="redis://${REDIS_NODE_IP}:6379/2" \
  --from-literal=SECRET_KEY="$(openssl rand -hex 32)"

# 3. Build and push the Docker image
docker build -t ${DB_NODE_IP}:${REGISTRY_PORT}/${ORG_NAME}/myapp:v1 .
docker push ${DB_NODE_IP}:${REGISTRY_PORT}/${ORG_NAME}/myapp:v1

# 4. Apply manifests
kubectl apply -f k8s/

# 5. Verify pods are running
kubectl get pods -l app=myapp
kubectl logs deployment/myapp -f

# 6. Check via Traefik (from any K3s node)
curl -H "Host: myapp.${YOUR_DOMAIN}" http://${GATEWAY_NODE_IP}/health

# 7. Add HAProxy backend rule (on ${GATEWAY_HOST} and ${DB_HOST})
# Edit /etc/haproxy/haproxy.cfg to add the new backend
# Then reload: systemctl reload haproxy

# 8. Add Cloudflare DNS record
# A record: myapp.${YOUR_DOMAIN} -> ${VPS1_PUBLIC_IP} (VPS1) + ${VPS4_PUBLIC_IP} (VPS4)
# Enable Cloudflare proxy (orange cloud)
```

---

## Rollback

```bash
# Check rollout history
kubectl rollout history deployment/APP_NAME

# Rollback to previous revision
kubectl rollout undo deployment/APP_NAME

# Rollback to a specific revision
kubectl rollout undo deployment/APP_NAME --to-revision=N

# Verify rollback succeeded
kubectl rollout status deployment/APP_NAME

# If Celery workers also need rollback
kubectl rollout undo deployment/APP_NAME-celery-worker
kubectl rollout undo deployment/APP_NAME-celery-beat
```

---

## Monitoring

### Prometheus Targets

Prometheus runs on `${GATEWAY_HOST}` and scrapes the following over WireGuard:

- K3s API server metrics (`${GATEWAY_NODE_IP}:6443`, `${APP_NODE_IP}:6443`)
- Node Exporter on all 4 nodes (port 9100)
- Traefik metrics (port 8080 on K3s nodes)
- Redis Exporter on `${REDIS_HOST}` (port 9121)
- MySQL Exporter on `${DB_HOST}` (port 9104)
- MongoDB Exporter on `${DB_HOST}` (port 9216)
- HAProxy stats on `${GATEWAY_HOST}` and `${DB_HOST}` (port 8404)

### Recommended Monitoring Stack

Deploy Grafana, Traefik dashboard, and HAProxy stats behind your Cloudflare-proxied domain
for centralized observability. Typical subdomains:

- `grafana.${YOUR_DOMAIN}` -- Cluster metrics, app dashboards
- `traefik.${YOUR_DOMAIN}` -- Ingress routes, request metrics
- HAProxy stats endpoint on `:8404/stats` -- Backend health, connection stats

### Health Check Endpoints

Every application deployed to the cluster MUST expose:

- `GET /health` -- Returns 200 OK when the app is healthy (used by readiness/liveness probes)
- `GET /health` should check database connectivity if the app uses databases

---

## Domain Setup (for new apps)

1. **Cloudflare DNS**: Add A records for the new subdomain pointing to:
   - VPS1: `${VPS1_PUBLIC_IP}`
   - VPS4: `${VPS4_PUBLIC_IP}`
   - Enable Cloudflare proxy (orange cloud icon)

2. **HAProxy Configuration**: Add backend rule on **both** `${GATEWAY_HOST}` and `${DB_HOST}`:
   ```
   # In /etc/haproxy/haproxy.cfg, add to the frontend section:
   acl host_myapp hdr(host) -i myapp.${YOUR_DOMAIN}
   use_backend myapp_backend if host_myapp

   # Add the backend section:
   backend myapp_backend
       server ${APP_HOST} ${APP_NODE_IP}:80 check
       server ${GATEWAY_HOST} ${GATEWAY_NODE_IP}:80 check backup
   ```
   Then reload: `systemctl reload haproxy`

3. **K8s IngressRoute**: Create an IngressRoute matching `Host(\`myapp.${YOUR_DOMAIN}\`)` -- this is included in the backend.yaml template above.

4. **Verify end-to-end**: `curl https://myapp.${YOUR_DOMAIN}/health`

---

## WireGuard VPN Details

### Network Layout

```
${GATEWAY_NODE_IP}/24  -- ${GATEWAY_HOST}  (wg0)
${APP_NODE_IP}/24      -- ${APP_HOST}      (wg0)
${REDIS_NODE_IP}/24    -- ${REDIS_HOST}    (wg0)
${DB_NODE_IP}/24       -- ${DB_HOST}       (wg0)
```

### Mesh Topology

Every node has a direct WireGuard peer connection to every other node (full mesh).
This means any node can reach any other node directly -- no routing through a central
gateway. If one node goes down, the remaining nodes still communicate.

### Configuration Location

WireGuard configs are at `/etc/wireguard/wg0.conf` on each node. The interface is
managed by systemd: `systemctl status wg-quick@wg0`.

---

## NFS Shared Storage

- **NFS Server**: `${DB_HOST}` (`${DB_NODE_IP}`)
- **Export Path**: `${NFS_EXPORT_PATH}`
- **Mount on K3s nodes**: Handled via PV/PVC (see NFS PersistentVolume template above)
- **Use cases**: Shared media uploads, ML model files, static assets

### Creating a new NFS share for an app

```bash
# On ${DB_HOST}:
mkdir -p ${NFS_EXPORT_PATH}/myapp
chown 1000:1000 ${NFS_EXPORT_PATH}/myapp
# The ${NFS_EXPORT_PATH} directory is already exported via /etc/exports
# Sub-directories are automatically accessible
```

---

## Important Constraints

These constraints MUST be followed by all deployment commands (`/gen-ci`, `/gen-infra`,
`/deploy`, `/auto-build`):

- **NO nginx Ingress** -- always use Traefik IngressRoute (`apiVersion: traefik.io/v1alpha1`)
- **NO LoadBalancer services** -- Traefik uses `hostPort:80`, HAProxy routes traffic to node IPs
- **NO databases in K3s** -- MySQL/MongoDB run on VPS4, Redis on VPS3 (dedicated Docker)
- **NO public Docker registry** -- use `${DB_NODE_IP}:${REGISTRY_PORT}` (WireGuard-only, HTTP)
- **NO cert-manager** -- SSL terminates at HAProxy with Cloudflare Origin Certificate
- **NO NodePort services** -- all traffic enters via HAProxy -> Traefik -> ClusterIP Service
- **GitHub runner is self-hosted** -- use `runs-on: self-hosted` (NOT `ubuntu-latest`)
- **Image cleanup** -- Registry GC runs daily at 3:00 AM on `${DB_HOST}`, Docker prune at 4:00 AM on `${APP_HOST}`
- **Runner labels**: `self-hosted`, `Linux`, `X64` -- registered at org `${ORG_NAME}`
- **Always tag with git SHA** -- every image must be tagged with the 8-char git SHA for traceability
- **Always include latest tag** -- push both `:{sha}` and `:latest` tags
- **Replicas minimum**: Production deployments should have at least 2 replicas for availability
- **Celery Beat replicas**: MUST be exactly 1 (never scale beat horizontally)
- **Health endpoints**: Every app MUST expose `GET /health` for probes
- **Resource limits**: Every container MUST have resource requests and limits defined
- **Rolling updates**: Use `maxUnavailable: 0, maxSurge: 1` for zero-downtime deployments
- **Namespace**: Use `default` namespace unless there is a specific reason to isolate

---

## Troubleshooting

### Common Issues

**Pod stuck in ImagePullBackOff**
```bash
# Check if the image exists in the registry
curl http://${DB_NODE_IP}:${REGISTRY_PORT}/v2/ORG/APP_NAME/tags/list
# Check K3s can reach the registry
kubectl run test --image=busybox --rm -it -- wget -qO- http://${DB_NODE_IP}:${REGISTRY_PORT}/v2/_catalog
```

**Pod stuck in CrashLoopBackOff**
```bash
# Check logs
kubectl logs deployment/APP_NAME --previous
# Check events
kubectl describe pod -l app=APP_NAME
```

**Cannot reach app from Cloudflare**
```bash
# 1. Check pod is running
kubectl get pods -l app=APP_NAME
# 2. Check service endpoints
kubectl get endpoints APP_NAME
# 3. Check IngressRoute
kubectl get ingressroute APP_NAME -o yaml
# 4. Check Traefik is routing
curl -H "Host: APP_SUBDOMAIN.${YOUR_DOMAIN}" http://${GATEWAY_NODE_IP}/health
# 5. Check HAProxy backend health
# Access HAProxy stats via the stats endpoint on port 8404
```

**Database connection refused**
```bash
# Check WireGuard is up
ping ${DB_NODE_IP}
# Check MySQL is running on ${DB_HOST}
docker ps | grep mysql
# Check port is accessible
nc -zv ${DB_NODE_IP} 3306
```

**Redis connection refused**
```bash
# Check WireGuard is up
ping ${REDIS_NODE_IP}
# Check Redis is running on ${REDIS_HOST}
docker ps | grep redis
# Check port is accessible
nc -zv ${REDIS_NODE_IP} 6379
# Test Redis connection
redis-cli -h ${REDIS_NODE_IP} ping
```

**Disk space issues on `${APP_HOST}`**
```bash
# Check Docker disk usage
docker system df
# Prune unused images/containers/volumes
docker system prune -a --volumes -f
# Check K3s containerd images
crictl images | sort -k4 -h
```

**WireGuard connectivity issues**
```bash
# Check WireGuard interface status
wg show wg0
# Check if peers are connected (latest handshake should be recent)
wg show wg0 latest-handshakes
# Restart WireGuard interface
systemctl restart wg-quick@wg0
# Test connectivity to all nodes
ping ${GATEWAY_NODE_IP}
ping ${APP_NODE_IP}
ping ${REDIS_NODE_IP}
ping ${DB_NODE_IP}
```

**K3s cluster issues**
```bash
# Check K3s service status
systemctl status k3s
# Check K3s logs
journalctl -u k3s -f --lines=50
# Check node status
kubectl get nodes -o wide
# Check system pods
kubectl get pods -n kube-system
```

### Useful Commands

```bash
# View all running pods
kubectl get pods -A

# View resource usage
kubectl top pods
kubectl top nodes

# View Traefik routes
kubectl get ingressroute -A

# View all secrets
kubectl get secrets

# Port-forward for local debugging
kubectl port-forward deployment/APP_NAME 8080:APP_PORT

# Execute into a running pod
kubectl exec -it deployment/APP_NAME -- /bin/sh

# View K3s cluster info
kubectl cluster-info
kubectl get nodes -o wide

# Check K3s token (for adding new nodes)
cat /var/lib/rancher/k3s/server/token

# View all Docker images in the private registry
curl -s http://${DB_NODE_IP}:${REGISTRY_PORT}/v2/_catalog | python3 -m json.tool

# List tags for a specific image
curl -s http://${DB_NODE_IP}:${REGISTRY_PORT}/v2/${ORG_NAME}/APP_NAME/tags/list | python3 -m json.tool

# Check HAProxy configuration syntax
haproxy -c -f /etc/haproxy/haproxy.cfg

# View Traefik access logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik -f

# Check Cloudflare Origin Certificate expiry (on ${GATEWAY_HOST} or ${DB_HOST})
openssl x509 -in /etc/haproxy/certs/origin.pem -noout -dates
```

---

## Adding a New Node to the Cluster

If you need to scale beyond 4 nodes, follow this pattern:

1. **Provision the new VPS** with the same OS (Ubuntu 22.04+ recommended).

2. **Assign a WireGuard IP** from the `${VPN_SUBNET}` subnet (e.g., next available IP).

3. **Configure WireGuard** on the new node and add it as a peer on all existing nodes:
   ```bash
   # On the new node: generate keys
   wg genkey | tee privatekey | wg pubkey > publickey

   # On each existing node: add the new peer to /etc/wireguard/wg0.conf
   # Then reload: systemctl reload wg-quick@wg0
   ```

4. **Join the K3s cluster** as a worker (or agent) node:
   ```bash
   # Get the join token from an existing control-plane node
   cat /var/lib/rancher/k3s/server/token

   # On the new node:
   curl -sfL https://get.k3s.io | K3S_URL=https://${GATEWAY_NODE_IP}:6443 \
     K3S_TOKEN=<token> sh -
   ```

5. **Configure the private registry** on the new node:
   ```bash
   # Create /etc/rancher/k3s/registries.yaml with the registry mirror config
   systemctl restart k3s-agent
   ```

6. **Verify** the node appears in the cluster:
   ```bash
   kubectl get nodes -o wide
   ```

---

## Backup & Recovery

### Database Backups

```bash
# MySQL backup (run on ${DB_HOST})
docker exec mysql mysqldump -uroot -p'ROOT_PASS' --all-databases > /backups/mysql-$(date +%Y%m%d).sql

# MongoDB backup (run on ${DB_HOST})
docker exec mongodb mongodump --out /backups/mongodb-$(date +%Y%m%d)

# Redis backup (run on ${REDIS_HOST})
docker exec redis redis-cli BGSAVE
cp /var/lib/redis/dump.rdb /backups/redis-$(date +%Y%m%d).rdb
```

### K3s Cluster State

Since K3s stores its state in MySQL on `${DB_HOST}`, the MySQL backup includes the
cluster state. To restore a K3s cluster from scratch:

1. Restore MySQL from backup.
2. Install K3s on control-plane nodes pointing to the restored MySQL.
3. Join worker/agent nodes.

### Disaster Recovery Checklist

1. Restore MySQL and MongoDB from latest backups on `${DB_HOST}`.
2. Restore Redis RDB/AOF on `${REDIS_HOST}`.
3. Verify WireGuard mesh is up between all nodes.
4. Verify K3s cluster is healthy (`kubectl get nodes`).
5. Verify all deployments are running (`kubectl get pods -A`).
6. Verify HAProxy is routing traffic on `${GATEWAY_HOST}` and `${DB_HOST}`.
7. Verify Cloudflare health checks are passing for both origins.

---

## Placeholder Reference

When generating manifests, replace these placeholders:

| Placeholder              | Description                                          | Example                          |
| ------------------------ | ---------------------------------------------------- | -------------------------------- |
| `APP_NAME`               | Kubernetes deployment/service name                   | `finance-agent`                  |
| `APP_NAMESPACE`          | Kubernetes namespace                                 | `default`                        |
| `APP_PORT`               | Container port the app listens on                    | `8000`                           |
| `APP_SUBDOMAIN`          | Subdomain prefix for IngressRoute Host matching      | `finance`                        |
| `ORG`                    | Docker registry organization                         | `my-org`                         |
| `USER` / `PASS`          | Database credentials                                 | (from secrets)                   |
| `DB_NAME`                | Database name                                        | `finance_agent`                  |
| `CELERY_APP_MODULE`      | Python module path for Celery app                    | `config.celery_app`              |
| `TASK_NAME`              | CronJob task identifier                              | `cleanup`                        |
| `TASK_COMMAND`           | Management command to run                            | `cleanup_expired`                |
| `CHANGE_ME`              | Secrets that must be replaced                        | `openssl rand -hex 32`           |
| `${GATEWAY_NODE_IP}`     | WireGuard IP of the gateway node (Node 1)            | `10.0.0.1`                       |
| `${APP_NODE_IP}`         | WireGuard IP of the app/compute node (Node 2)        | `10.0.0.2`                       |
| `${REDIS_NODE_IP}`       | WireGuard IP of the Redis node (Node 3)              | `10.0.0.3`                       |
| `${DB_NODE_IP}`          | WireGuard IP of the database node (Node 4)           | `10.0.0.4`                       |
| `${GATEWAY_HOST}`        | Hostname of the gateway node                         | `edge01`                         |
| `${APP_HOST}`            | Hostname of the app node                             | `app01`                          |
| `${REDIS_HOST}`          | Hostname of the Redis node                           | `redis01`                        |
| `${DB_HOST}`             | Hostname of the database node                        | `db01`                           |
| `${VPS1_PUBLIC_IP}`      | Public IP of VPS 1 (primary gateway)                 | `203.0.113.10`                   |
| `${VPS4_PUBLIC_IP}`      | Public IP of VPS 4 (failover gateway)                | `203.0.113.20`                   |
| `${YOUR_DOMAIN}`         | Root domain for DNS and IngressRoute                 | `example.cloud`                  |
| `${RUNNER_NAME}`         | Self-hosted GitHub Actions runner name               | `my-runner`                      |
| `${ORG_NAME}`            | GitHub/Docker registry organization name             | `my-org`                         |
| `${VPN_SUBNET}`          | WireGuard VPN subnet CIDR                            | `10.0.0.0/24`                    |
| `${REGISTRY_PORT}`       | Private Docker registry port                         | `5000`                           |
| `${NFS_EXPORT_PATH}`     | NFS export path on the storage node                  | `/mnt/k3s_shared_storage`        |
