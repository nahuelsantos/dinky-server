#!/bin/bash
set -e

# Get SERVER_IP from environment or use localhost as fallback
SERVER_IP=${SERVER_IP:-localhost}

# Create required directories
mkdir -p monitoring/{prometheus,loki,promtail,tempo,pyroscope,grafana,otel-collector,blackbox}
mkdir -p monitoring/grafana/{dashboards,provisioning}
mkdir -p monitoring/grafana/provisioning/{datasources,dashboards}

echo "Setting up the LGTM stack configuration..."

# REMOVED: Self-referencing copy commands that served no purpose
echo "Configuration files are already in place..."

echo "Setting up cadvisor for container metrics..."

# Check if cadvisor and node-exporter are already in docker-compose.yml
if ! grep -q "cadvisor:" docker-compose.yml; then
    echo "Adding cadvisor and node-exporter services..."
    
    # Create temporary file with just the service definitions
    cat << EOF > /tmp/monitoring-services.yml

  # Container Metrics (added by monitoring setup)
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
      - "${SERVER_IP}:8082:8080" 
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
      - "${SERVER_IP}:9100:9100"
    networks:
      - traefik_network

  blackbox-exporter:
    image: prom/blackbox-exporter:v0.25.0
    container_name: blackbox-exporter
    restart: always
    ports:
      - "${SERVER_IP}:9115:9115"
    volumes:
      - ./monitoring/blackbox:/etc/blackbox_exporter
    networks:
      - traefik_network
    command:
      - '--config.file=/etc/blackbox_exporter/config.yml'
EOF
    
    # Find the line number where volumes: section starts (after services but before volumes)
    volumes_line=$(grep -n "^volumes:" docker-compose.yml | head -1 | cut -d: -f1)
    
    if [ -n "$volumes_line" ]; then
        # Insert the services before the volumes section
        head -n $((volumes_line - 1)) docker-compose.yml > /tmp/docker-compose-new.yml
        cat /tmp/monitoring-services.yml >> /tmp/docker-compose-new.yml
        tail -n +$volumes_line docker-compose.yml >> /tmp/docker-compose-new.yml
        mv /tmp/docker-compose-new.yml docker-compose.yml
    else
        echo "Warning: Could not find volumes section, appending to end"
        cat /tmp/monitoring-services.yml >> docker-compose.yml
    fi
    
    # Clean up temp file
    rm /tmp/monitoring-services.yml
    
    echo "✓ Added cadvisor, node-exporter, and blackbox-exporter services"
else
    echo "✓ Monitoring services already present in docker-compose.yml"
fi

echo "Setup complete!"
echo ""
echo "Start the monitoring stack with:"
echo "docker compose up -d"
echo ""
echo "Access the interfaces at:"
echo "- Grafana: http://${SERVER_IP}:3000"
echo "- Prometheus: http://${SERVER_IP}:9090"
echo "- Pyroscope: http://${SERVER_IP}:4040"
echo "- Loki: http://${SERVER_IP}:3100"
echo "- cAdvisor: http://${SERVER_IP}:8082"
echo "- Node Exporter: http://${SERVER_IP}:9100"
echo "- Blackbox Exporter: http://${SERVER_IP}:9115"
echo ""
echo "Remember to set your Grafana admin password in the .env file."

# Make the script executable
chmod +x monitoring/setup-monitoring.sh 