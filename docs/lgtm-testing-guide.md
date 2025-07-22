# LGTM Stack Testing Guide

Hello, well, after many days I am back working on this. The current status is the following. I have LGTM stack as you can see in the docker-compose.yml

At the moment I also have 2 websites running (nahuelsantos.com and loopingbyte.com), a service (postfix email) and an rest API, contact-api. Considering all this, I need you to explain me how the LGTM stack should be working, since this is all new for me. What I need you to explain me is:
* What does prometheus suppose do? How can I see this in the http://dinky:9090/ (where I can see prometheus UI)
* What does grafana suppose do? How can I see this in the http://dinky:3000/ (where I can see grafana UI)
* What does loki suppose do? How can I see this in the http://dinky:3100/ (where I can see loki)
* What does tempo suppose do? How can I see this in the http://dinky:3200/ (where I can see tempo)
* What does blackbox-exporter suppose do? How can I see it's doing what it's suppose to do?
* What does cadvisor suppose do? How can I see it's doing what it's suppose to do?
* What does otel-collector suppose do? How can I see it's doing what it's suppose to do?
* What does pyroscope suppose do? How can I see it's doing what it's suppose to do?
* What does Promtail suppose do? How can I see it's doing what it's suppose to do?
* What does alertmanager suppose do? How can I see it's doing what it's suppose to do?
* What does node-exporter suppose do? How can I see it's doing what it's suppose to do?

I need to have a clear understanding about how to check that all the setup is working with the current sites, services and apis. Once this is clear, I need clear instructions on how to create sinthetic data to test all this without the necessity of sites and apis. And then I need everything to be set up in a way that the system automatically discovers any new service, api or site installed in the server. 

Do you have any questions?
  
  
This guide provides commands to test each component of the LGTM (Loki, Grafana, Tempo, Monitoring) stack and validate service integrations.

## Prerequisites

- All services running via `docker compose up -d`
- Server accessible at `192.168.3.2`
- `jq` installed for JSON parsing
- `curl` for API testing
- Grafana credentials: `admin / Etching-Backspace1-Poach`

## Service Health Checks

### 1. Basic Service Availability

```bash
# Check all services are running
docker compose ps

# Check specific service logs
docker logs --tail 20 <service-name>

# Check service resource usage
docker stats --no-stream
```

### 2. Prometheus Monitoring

```bash
# Test Prometheus API
curl -s "http://192.168.3.2:9090/api/v1/query?query=up" | jq '.data.result | length'

# Check all targets status
curl -s "http://192.168.3.2:9090/api/v1/targets" | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'

# Check unhealthy targets
curl -s "http://192.168.3.2:9090/api/v1/targets" | jq '.data.activeTargets[] | select(.health != "up") | {job: .labels.job, health: .health, lastError: .lastError}'

# Test website monitoring (blackbox-exporter)
curl -s "http://192.168.3.2:9090/api/v1/query?query=probe_success" | jq '.data.result[] | {instance: .metric.instance, job: .metric.job, status: .value[1]}'

# Check website response times
curl -s "http://192.168.3.2:9090/api/v1/query?query=probe_duration_seconds" | jq '.data.result[] | {instance: .metric.instance, duration: .value[1]}'

# Check HTTP status codes
curl -s "http://192.168.3.2:9090/api/v1/query?query=probe_http_status_code" | jq '.data.result[] | {instance: .metric.instance, code: .value[1]}'

# Check container metrics
curl -s "http://192.168.3.2:9090/api/v1/query?query=container_memory_usage_bytes" | jq '.data.result | length'

# Check node metrics (hardware)
curl -s "http://192.168.3.2:9090/api/v1/query?query=node_load1" | jq '.data.result[] | {instance: .metric.instance, load: .value[1]}'

# Test specific service metrics (example: contact-api)
curl -s "http://192.168.3.2:9090/api/v1/query?query=go_memstats_alloc_bytes{job=\"contact-api\"}" | jq '.data.result[] | {job: .metric.job, memory: .value[1]}'
```

### 3. Loki Log Aggregation

```bash
# Test Loki API availability
curl -s "http://192.168.3.2:3100/ready"

# Check Loki metrics
curl -s "http://192.168.3.2:3100/metrics" | grep -c "loki_"

# Query recent logs (last hour) - Cross-platform compatible
NOW=$(date +%s) && START=$((NOW - 3600))
curl -s -G "http://192.168.3.2:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="varlogs"}' \
  --data-urlencode "start=${START}000000000" \
  --data-urlencode "end=${NOW}000000000" | jq '.data.result | length'

# Check container logs  
curl -s -G "http://192.168.3.2:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={container!=""}' \
  --data-urlencode "start=${START}000000000" \
  --data-urlencode "end=${NOW}000000000" | jq '.data.result | length'

# Check available labels
curl -s "http://192.168.3.2:3100/loki/api/v1/labels" | jq '.data[]'

# Check label values for specific label
curl -s "http://192.168.3.2:3100/loki/api/v1/label/container/values" | jq '.data[]'

# Query specific service logs (example: contact-api)
curl -s -G "http://192.168.3.2:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={container="contact-api"}' \
  --data-urlencode "start=${START}000000000" \
  --data-urlencode "end=${NOW}000000000" | jq '.data.result | length'
```

### 4. Tempo Distributed Tracing

```bash
# Test Tempo API
curl -s "http://192.168.3.2:3200/ready"

# Check Tempo metrics
curl -s "http://192.168.3.2:3200/metrics" | grep -c "tempo_"

# Check Tempo configuration
curl -s "http://192.168.3.2:3200/status/config" | jq '.distributor'

# Note: Port 4316 is OTLP protocol (not HTTP), so curl will show protocol error - this is expected
# curl "http://192.168.3.2:4316"  # Expected: HTTP/0.9 response (normal for OTLP)
```

### 5. OpenTelemetry Collector

```bash
# Test OTEL Collector health
curl -s "http://192.168.3.2:13133/"

# Check OTEL Collector metrics (Prometheus format)
curl -s "http://192.168.3.2:8889/metrics" | grep -c "otelcol"

# Check specific OTEL metrics
curl -s "http://192.168.3.2:8889/metrics" | grep "otelcol_receiver_accepted_spans"

# Check zpages (human-readable status)
curl -s "http://192.168.3.2:55679/debug/tracez"

# Check OTEL pipeline status
curl -s "http://192.168.3.2:55679/debug/pipelinez"
```

### 6. Grafana Dashboard

```bash
# Test Grafana API
curl -s "http://192.168.3.2:3000/api/health" | jq '.'

# List dashboards (requires auth)
curl -s -u "admin:Etching-Backspace1-Poach" "http://192.168.3.2:3000/api/search" | jq '.[] | {title: .title, uid: .uid}'

# Check datasources configuration
curl -s -u "admin:Etching-Backspace1-Poach" "http://192.168.3.2:3000/api/datasources" | jq '.[] | {name: .name, type: .type, uid: .uid, url: .url}'

# Test Prometheus datasource connectivity
curl -s -u "admin:Etching-Backspace1-Poach" "http://192.168.3.2:3000/api/datasources/proxy/1/api/v1/query?query=up" | jq '.data.result | length'

# Check dashboard by UID
curl -s -u "admin:Etching-Backspace1-Poach" "http://192.168.3.2:3000/api/dashboards/uid/contact-api" | jq '.dashboard.title'
```

### 7. Alertmanager

```bash
# Test Alertmanager API
curl -s "http://192.168.3.2:9093/api/v1/status" | jq '.'

# Check active alerts
curl -s "http://192.168.3.2:9093/api/v1/alerts" | jq '.data[] | {alertname: .labels.alertname, state: .status.state, summary: .annotations.summary}'

# Check alert rules
curl -s "http://192.168.3.2:9093/api/v1/rules" | jq '.data.groups[] | {name: .name, rules: (.rules | length)}'

# Test silence creation
curl -s "http://192.168.3.2:9093/api/v1/silences" | jq '.'

# Check Alertmanager configuration
curl -s "http://192.168.3.2:9093/api/v1/status" | jq '.data.configYAML'
```

## Service Integration Testing

### 8. Application Metrics Integration

```bash
# Test contact-api metrics endpoint
curl -s "http://192.168.3.2:3002/metrics" | head -10

# Check if Prometheus is scraping contact-api
curl -s "http://192.168.3.2:9090/api/v1/query?query=up{job=\"contact-api\"}" | jq '.data.result[] | {instance: .metric.instance, status: .value[1]}'

# Verify Go runtime metrics
curl -s "http://192.168.3.2:9090/api/v1/query?query=go_goroutines{job=\"contact-api\"}" | jq '.data.result[] | {goroutines: .value[1]}'

# Check memory usage
curl -s "http://192.168.3.2:9090/api/v1/query?query=go_memstats_alloc_bytes{job=\"contact-api\"}" | jq '.data.result[] | {memory_bytes: .value[1]}'
```

### 9. OTEL Pipeline Testing

```bash
# Test OTEL Collector receiving metrics
curl -s "http://192.168.3.2:8889/metrics" | grep "otelcol_receiver_accepted_metric_points"

# Test OTEL Collector exporting to Tempo
curl -s "http://192.168.3.2:8889/metrics" | grep "otelcol_exporter_sent_spans"

# Check OTEL Collector pipeline health
curl -s "http://192.168.3.2:55679/debug/pipelinez" | grep -A5 "traces"
```

## Comprehensive Test Script

```bash
#!/bin/bash
# LGTM Stack Health Check

echo "=== LGTM Stack Health Check ==="
echo

# Service availability
echo "1. Checking service availability..."
SERVICES=("prometheus:9090" "loki:3100" "tempo:3200" "grafana:3000" "alertmanager:9093" "otel-collector:13133")
for service in "${SERVICES[@]}"; do
    name=$(echo $service | cut -d: -f1)
    port=$(echo $service | cut -d: -f2)
    if curl -s --connect-timeout 5 "http://192.168.3.2:$port" >/dev/null 2>&1; then
        echo "✅ $name is responding"
    else
        echo "❌ $name is not responding"
    fi
done

echo
echo "2. Checking data availability..."

# Prometheus targets
TARGETS=$(curl -s "http://192.168.3.2:9090/api/v1/query?query=up" 2>/dev/null | jq -r '.data.result | length' 2>/dev/null)
echo "📊 Prometheus monitoring $TARGETS targets"

# Check unhealthy targets
UNHEALTHY=$(curl -s "http://192.168.3.2:9090/api/v1/targets" 2>/dev/null | jq -r '.data.activeTargets[] | select(.health != "up") | .labels.job' 2>/dev/null | wc -l)
if [ "$UNHEALTHY" -gt 0 ]; then
    echo "⚠️  $UNHEALTHY targets are unhealthy"
else
    echo "✅ All targets are healthy"
fi

# Loki logs (last hour)  
NOW=$(date +%s) && START=$((NOW - 3600))
LOGS=$(curl -s -G "http://192.168.3.2:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="varlogs"}' \
  --data-urlencode "start=${START}000000000" \
  --data-urlencode "end=${NOW}000000000" 2>/dev/null | jq -r '.data.result | length' 2>/dev/null)
echo "📝 Loki found $LOGS log streams"

# Check Loki labels
LOKI_LABELS=$(curl -s "http://192.168.3.2:3100/loki/api/v1/labels" 2>/dev/null | jq -r '.data | length' 2>/dev/null)
echo "🏷️  Loki has $LOKI_LABELS different labels"

# OTEL Collector metrics
OTEL_METRICS=$(curl -s "http://192.168.3.2:8889/metrics" 2>/dev/null | grep -c "otelcol" 2>/dev/null || echo "0")
echo "🔄 OTEL Collector has $OTEL_METRICS metrics"

# Website monitoring
WEBSITES_UP=$(curl -s "http://192.168.3.2:9090/api/v1/query?query=probe_success{job=\"website-probes\"}" 2>/dev/null | jq -r '.data.result[] | select(.value[1] == "1") | .metric.instance' 2>/dev/null | wc -l)
WEBSITES_TOTAL=$(curl -s "http://192.168.3.2:9090/api/v1/query?query=probe_success{job=\"website-probes\"}" 2>/dev/null | jq -r '.data.result | length' 2>/dev/null)
echo "🌐 Website monitoring: $WEBSITES_UP/$WEBSITES_TOTAL sites UP"

echo
echo "3. Checking integrations..."

# Contact API integration
CONTACT_API_UP=$(curl -s "http://192.168.3.2:9090/api/v1/query?query=up{job=\"contact-api\"}" 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null)
if [ "$CONTACT_API_UP" = "1" ]; then
    echo "✅ Contact API is integrated and monitored"
    CONTACT_MEMORY=$(curl -s "http://192.168.3.2:9090/api/v1/query?query=go_memstats_alloc_bytes{job=\"contact-api\"}" 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null)
    echo "   Memory usage: $(echo "scale=2; $CONTACT_MEMORY/1024/1024" | bc 2>/dev/null || echo "N/A") MB"
else
    echo "❌ Contact API integration not working"
fi

# Check Grafana dashboards
DASHBOARDS=$(curl -s -u "admin:Etching-Backspace1-Poach" "http://192.168.3.2:3000/api/search" 2>/dev/null | jq -r '. | length' 2>/dev/null)
echo "📊 Grafana has $DASHBOARDS dashboards configured"

echo
echo "4. Dashboard URLs:"
echo "🌐 Grafana: http://192.168.3.2:3000 (admin/Etching-Backspace1-Poach)"
echo "🔥 Prometheus: http://192.168.3.2:9090"
echo "📊 Alertmanager: http://192.168.3.2:9093"
echo "🐳 Portainer: http://192.168.3.2:9000"
echo "📈 Contact API: http://192.168.3.2:3002"

echo
echo "5. Key Grafana Dashboards:"
echo "   • Contact API Dashboard: http://192.168.3.2:3000/d/contact-api"
echo "   • Website Monitoring: http://192.168.3.2:3000/d/website-monitoring"
echo "   • Server Hardware Health: http://192.168.3.2:3000/d/server-hardware-health"

echo
echo "=== Health Check Complete ==="
```

## Troubleshooting

### Common Issues and Solutions

#### 1. No data in Grafana dashboards
**Symptoms:** Dashboard panels show "No data"
**Solutions:**
- Check datasource UID configuration:
  ```bash
  curl -s -u "admin:Etching-Backspace1-Poach" "http://192.168.3.2:3000/api/datasources" | jq '.[] | {name: .name, uid: .uid}'
  ```
- Verify Prometheus targets are UP:
  ```bash
  curl -s "http://192.168.3.2:9090/api/v1/targets" | jq '.data.activeTargets[] | select(.health != "up")'
  ```
- Check time range in dashboards (ensure it matches data availability)
- Restart Grafana to reload dashboard configurations:
  ```bash
  docker compose restart grafana
  ```

#### 2. OTEL Collector connection issues
**Symptoms:** Applications can't send traces/metrics to OTEL Collector
**Solutions:**
- Check OTEL Collector health:
  ```bash
  curl -s "http://192.168.3.2:13133/"
  ```
- Verify port mappings (4318 for HTTP, 4317 for gRPC):
  ```bash
  docker compose ps otel-collector
  ```
- Check OTEL Collector logs:
  ```bash
  docker logs otel-collector --tail 50
  ```
- Test OTLP endpoint:
  ```bash
  # This should show connection refused or protocol error (normal for OTLP)
  curl "http://192.168.3.2:4318"
  ```

#### 3. Loki not receiving logs
**Symptoms:** No logs in Loki/Grafana
**Solutions:**
- Check Promtail container status:
  ```bash
  docker logs promtail --tail 50
  ```
- Verify Docker socket permissions:
  ```bash
  docker compose exec promtail ls -la /var/run/docker.sock
  ```
- Check Promtail configuration:
  ```bash
  docker compose exec promtail cat /etc/promtail/config.yml
  ```
- Test Loki ingestion:
  ```bash
  curl -s "http://192.168.3.2:3100/loki/api/v1/labels" | jq '.data[]'
  ```

#### 4. Website monitoring not working
**Symptoms:** probe_success metrics missing or always 0
**Solutions:**
- Check blackbox-exporter configuration:
  ```bash
  docker logs blackbox-exporter --tail 20
  ```
- Test blackbox-exporter directly:
  ```bash
  curl -s "http://192.168.3.2:9115/probe?target=https://google.com&module=http_2xx"
  ```
- Verify Prometheus scrape configuration for blackbox jobs
- Check network connectivity from container to target websites

#### 5. Alertmanager not sending alerts
**Symptoms:** Alerts firing but no notifications received
**Solutions:**
- Check Alertmanager configuration:
  ```bash
  curl -s "http://192.168.3.2:9093/api/v1/status" | jq '.data.configYAML'
  ```
- Verify alert rules are loaded:
  ```bash
  curl -s "http://192.168.3.2:9093/api/v1/rules"
  ```
- Check for silenced alerts:
  ```bash
  curl -s "http://192.168.3.2:9093/api/v1/silences"
  ```
- Test email configuration (check SMTP settings)

#### 6. Dashboard datasource UID mismatches
**Symptoms:** Dashboard queries fail with "datasource not found"
**Solutions:**
- Get correct datasource UIDs:
  ```bash
  curl -s -u "admin:Etching-Backspace1-Poach" "http://192.168.3.2:3000/api/datasources" | jq '.[] | {name: .name, uid: .uid}'
  ```
- Update dashboard JSON files with correct UIDs:
  - Prometheus: `PBFA97CFB590B2093`
  - Loki: `P8E80F9AEF21F6940`
  - Tempo: `P214B5B846CF3925F`
- Restart Grafana after dashboard updates

### Performance Monitoring

#### Resource Usage Checks
```bash
# Check container resource usage
docker stats --no-stream

# Check disk usage for volumes
docker system df

# Check memory usage per service
docker compose exec prometheus ps aux --sort=-%mem | head -10

# Check Prometheus TSDB size
curl -s "http://192.168.3.2:9090/api/v1/status/tsdb" | jq '.data.headStats'
```

#### Data Retention Checks
```bash
# Check Prometheus retention
curl -s "http://192.168.3.2:9090/api/v1/status/flags" | jq '.data["storage.tsdb.retention.time"]'

# Check Loki retention (from config)
docker compose exec loki cat /etc/loki/local-config.yaml | grep -A5 retention

# Check Tempo retention
curl -s "http://192.168.3.2:3200/status/config" | jq '.ingester.lifecycler.ring.kvstore'
```

### Log Locations and Debugging

- **Container logs:** `docker logs <container-name>`
- **Service configs:** `dinky-server/monitoring/<service>/`
- **Grafana dashboards:** `dinky-server/monitoring/grafana/dashboards/`
- **Prometheus rules:** `dinky-server/monitoring/prometheus/rules/`
- **Data persistence:** All data stored in Docker volumes
- **OTEL Collector debug:** `http://192.168.3.2:55679/debug/`

### Integration Testing Checklist

When adding new services to monitoring:

1. **✅ Service exposes metrics endpoint** (usually `/metrics`)
2. **✅ Prometheus scrape configuration added** to `prometheus.yml`
3. **✅ Service added to docker-compose.yml** with proper labels
4. **✅ Grafana dashboard created** with correct datasource UIDs
5. **✅ Alert rules defined** for service health/performance
6. **✅ Service logs flowing to Loki** via Promtail
7. **✅ OTEL instrumentation configured** (if using traces)
8. **✅ Test all components** using this guide

### Quick Validation Commands

```bash
# One-liner to check all core services
for port in 9090 3100 3200 3000 9093; do echo -n "Port $port: "; curl -s --connect-timeout 2 "http://192.168.3.2:$port" >/dev/null && echo "✅ UP" || echo "❌ DOWN"; done

# Check all Prometheus targets health
curl -s "http://192.168.3.2:9090/api/v1/targets" | jq -r '.data.activeTargets[] | "\(.labels.job): \(.health)"' | sort

# Quick Loki log count
NOW=$(date +%s) && START=$((NOW - 3600)) && curl -s -G "http://192.168.3.2:3100/loki/api/v1/query_range" --data-urlencode 'query={container!=""}' --data-urlencode "start=${START}000000000" --data-urlencode "end=${NOW}000000000" | jq '.data.result | length'
``` 