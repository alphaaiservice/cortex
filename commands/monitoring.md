---
description: "Set up Prometheus + Grafana monitoring stack with pre-configured dashboards, alerts, and application metrics. Usage: /monitoring [setup | dashboard | alerts | status]"
---

# Monitoring Stack Setup (Prometheus + Grafana)

Action: **$ARGUMENTS** (default: `setup`)

## Step 1: Assess Current Monitoring State

```bash
echo "=== Check for existing monitoring ==="
ls -la docker/docker-compose*.yml 2>/dev/null
ls -la monitoring/ prometheus/ grafana/ 2>/dev/null
grep -rn "prometheus\|grafana\|metrics" docker/ 2>/dev/null
grep -rn "prometheus_client\|starlette_exporter" requirements*.txt pyproject.toml 2>/dev/null
echo ""
echo "=== Check if Docker is running ==="
docker info --format '{{.ServerVersion}}' 2>/dev/null || echo "Docker not running"
```

## Step 2: Create Monitoring Directory Structure

```
monitoring/
├── prometheus/
│   ├── prometheus.yml              # Main Prometheus config
│   ├── alerts/
│   │   ├── app_alerts.yml          # Application-level alerts
│   │   ├── infra_alerts.yml        # Infrastructure alerts
│   │   └── business_alerts.yml     # Business metric alerts
│   └── recording_rules.yml        # Pre-computed metrics
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── prometheus.yml      # Auto-configure Prometheus datasource
│   │   └── dashboards/
│   │       ├── dashboard.yml       # Dashboard provisioning config
│   │       ├── app-overview.json   # Application overview dashboard
│   │       ├── api-performance.json # API endpoint performance
│   │       ├── database.json       # Database metrics dashboard
│   │       └── infrastructure.json # System resource dashboard
│   └── grafana.ini                 # Grafana server config
├── alertmanager/
│   └── alertmanager.yml            # Alert routing and notifications
└── docker-compose.monitoring.yml   # Monitoring stack compose file
```

## Step 3: Generate Prometheus Configuration

Create `monitoring/prometheus/prometheus.yml`:
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  scrape_timeout: 10s

rule_files:
  - "alerts/*.yml"
  - "recording_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'app'
    metrics_path: '/metrics'
    scrape_interval: 10s
    static_configs:
      - targets: ['app:8000']
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: 'app'

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  - job_name: 'mysql'
    static_configs:
      - targets: ['mysql-exporter:9104']

  - job_name: 'mongodb'
    static_configs:
      - targets: ['mongodb-exporter:9216']
```

## Step 4: Generate Alert Rules

Create `monitoring/prometheus/alerts/app_alerts.yml`:
```yaml
groups:
  - name: application
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected (> 5%)"
          description: "Error rate is {{ $value | humanizePercentage }} for {{ $labels.instance }}"

      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High P95 latency (> 1s)"
          description: "P95 latency is {{ $value }}s for {{ $labels.instance }}"

      - alert: AppDown
        expr: up{job="app"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Application is down"
          description: "{{ $labels.instance }} has been down for more than 1 minute"

      - alert: HighMemoryUsage
        expr: process_resident_memory_bytes{job="app"} > 500 * 1024 * 1024
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage (> 500MB)"

      - alert: HighCPUUsage
        expr: rate(process_cpu_seconds_total{job="app"}[5m]) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage (> 80%)"
```

Create `monitoring/prometheus/alerts/infra_alerts.yml`:
```yaml
groups:
  - name: infrastructure
    rules:
      - alert: HostHighCPU
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Host CPU > 85%"

      - alert: HostHighMemory
        expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Host memory > 85%"

      - alert: HostDiskSpaceLow
        expr: (1 - node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"}) * 100 > 85
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Disk space > 85% used"

      - alert: RedisDown
        expr: up{job="redis"} == 0
        for: 1m
        labels:
          severity: critical

      - alert: MySQLDown
        expr: up{job="mysql"} == 0
        for: 1m
        labels:
          severity: critical

      - alert: MongoDBDown
        expr: up{job="mongodb"} == 0
        for: 1m
        labels:
          severity: critical
```

## Step 5: Generate Docker Compose for Monitoring

Create `monitoring/docker-compose.monitoring.yml`:
```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus/alerts:/etc/prometheus/alerts
      - ./prometheus/recording_rules.yml:/etc/prometheus/recording_rules.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    restart: unless-stopped
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin}
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
    restart: unless-stopped
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml
    restart: unless-stopped
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
    restart: unless-stopped
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    restart: unless-stopped
    networks:
      - monitoring

  redis-exporter:
    image: oliver006/redis_exporter:latest
    container_name: redis-exporter
    ports:
      - "9121:9121"
    environment:
      - REDIS_ADDR=redis://redis:6379
    restart: unless-stopped
    networks:
      - monitoring

volumes:
  prometheus_data:
  grafana_data:

networks:
  monitoring:
    driver: bridge
```

## Step 6: Add Application Metrics (FastAPI)

Add to `requirements.txt`:
```
prometheus-client>=0.20.0
starlette-exporter>=0.21.0
```

Add to `app/main.py`:
```python
from starlette_exporter import PrometheusMiddleware, handle_metrics

app.add_middleware(
    PrometheusMiddleware,
    app_name="your_app",
    group_paths=True,
    filter_unhandled_paths=True,
    prefix="app",
)
app.add_route("/metrics", handle_metrics)
```

## Step 7: Generate Grafana Datasource Provisioning

Create `monitoring/grafana/provisioning/datasources/prometheus.yml`:
```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
```

## Step 8: Generate Alertmanager Config

Create `monitoring/alertmanager/alertmanager.yml`:
```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default'
  routes:
    - match:
        severity: critical
      receiver: 'critical'
      repeat_interval: 5m
    - match:
        severity: warning
      receiver: 'default'

receivers:
  - name: 'default'
    # Configure your notification channel:
    # slack_configs:
    #   - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
    #     channel: '#alerts'
    # email_configs:
    #   - to: 'team@example.com'

  - name: 'critical'
    # Configure urgent notification channel
    # pagerduty_configs:
    #   - service_key: 'YOUR_PAGERDUTY_KEY'
```

## Step 9: Launch & Verify

```bash
cd monitoring
docker-compose -f docker-compose.monitoring.yml up -d

echo ""
echo "=== Verifying services ==="
sleep 10
echo "Prometheus: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:9090/-/healthy)"
echo "Grafana:    $(curl -s -o /dev/null -w '%{http_code}' http://localhost:3001/api/health)"
echo "Alertmanager: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:9093/-/healthy)"
```

## Step 10: Summary Report

```
╔═══════════════════════════════════════════════════╗
║        MONITORING STACK DEPLOYED                  ║
╠═══════════════════════════════════════════════════╣
║ Prometheus:     http://localhost:9090             ║
║ Grafana:        http://localhost:3001             ║
║                 (admin / admin)                   ║
║ Alertmanager:   http://localhost:9093             ║
║ Node Exporter:  http://localhost:9100/metrics     ║
║ cAdvisor:       http://localhost:8080             ║
╠═══════════════════════════════════════════════════╣
║ Alert Rules:    [count] configured               ║
║ Dashboards:     [count] provisioned              ║
║ Exporters:      Node, cAdvisor, Redis, MySQL     ║
╚═══════════════════════════════════════════════════╝
```

Next steps:
1. Configure alert notification channels in `alertmanager.yml`
2. Import additional Grafana dashboards from grafana.com
3. Add custom application metrics with `prometheus_client`
4. Set up Grafana teams and access controls for production
