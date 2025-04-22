#!/bin/bash
set -e

# Create required directories
mkdir -p monitoring/{prometheus,loki,promtail,tempo,pyroscope,grafana,otel-collector}
mkdir -p monitoring/grafana/{dashboards,provisioning}
mkdir -p monitoring/grafana/provisioning/{datasources,dashboards}

echo "Setting up the LGTM stack configuration..."

# Copy configuration files
echo "Prometheus configuration..."
cp -f monitoring/prometheus/prometheus.yml monitoring/prometheus/prometheus.yml

echo "Loki configuration..."
cp -f monitoring/loki/loki-config.yml monitoring/loki/loki-config.yml

echo "Promtail configuration..."
cp -f monitoring/promtail/promtail-config.yml monitoring/promtail/promtail-config.yml

echo "Tempo configuration..."
cp -f monitoring/tempo/tempo-config.yml monitoring/tempo/tempo-config.yml

echo "Pyroscope configuration..."
cp -f monitoring/pyroscope/pyroscope-config.yml monitoring/pyroscope/pyroscope-config.yml

echo "OpenTelemetry Collector configuration..."
cp -f monitoring/otel-collector/otel-collector-config.yml monitoring/otel-collector/otel-collector-config.yml

echo "Grafana configuration..."
cp -f monitoring/grafana/provisioning/datasources/datasources.yml monitoring/grafana/provisioning/datasources/datasources.yml
cp -f monitoring/grafana/provisioning/dashboards/dashboards.yml monitoring/grafana/provisioning/dashboards/dashboards.yml
cp -f monitoring/grafana/dashboards/node-exporter.json monitoring/grafana/dashboards/node-exporter.json

echo "Setting up cadvisor for container metrics..."
cat << EOF > docker-compose.cadvisor.yml
services:
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.47.2
    restart: always
    privileged: true
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    ports:
      - "192.168.3.2:8084:20001"
    networks:
      - traefik_network
    command:
      - '--docker_only=true'
      - '--storage_duration=1m0s'
      - '--housekeeping_interval=10s'

  node-exporter:
    image: prom/node-exporter:v1.6.1
    restart: always
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "192.168.3.2:9100:9100"
    networks:
      - traefik_network

networks:
  traefik_network:
    external: true
EOF

echo "Adding cadvisor and node-exporter to docker-compose.yml..."
cat docker-compose.cadvisor.yml >> docker-compose.yml
rm docker-compose.cadvisor.yml

echo "Setup complete!"
echo ""
echo "Start the monitoring stack with:"
echo "docker compose up -d"
echo ""
echo "Access the interfaces at:"
echo "- Grafana: http://192.168.3.2:3000"
echo "- Prometheus: http://192.168.3.2:9090"
echo "- Pyroscope: http://192.168.3.2:4040"
echo "- Loki: http://192.168.3.2:3100"
echo ""
echo "Remember to set your Grafana admin password in the .env file."

# Make the script executable
chmod +x monitoring/setup-monitoring.sh 