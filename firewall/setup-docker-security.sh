#!/bin/bash
# Script to enhance Docker security

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

echo "Setting up Docker security enhancements..."

# Create a directory for Docker security files
mkdir -p /opt/docker-security

# Create the Docker socket proxy configuration
echo "Setting up Docker socket proxy for safer access..."
cat > /opt/docker-security/docker-socket-proxy.yml << EOF
version: '3'

services:
  socket-proxy:
    image: tecnativa/docker-socket-proxy:latest
    container_name: docker-socket-proxy
    restart: always
    environment:
      CONTAINERS: 1
      NETWORKS: 1
      SERVICES: 1
      TASKS: 1
      VOLUMES: 1
      IMAGES: 1
      INFO: 1
      VERSION: 1
      AUTH: 1
      DISTRIBUTION: 1
      POST: 0
      BUILD: 0
      COMMIT: 0
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - proxy
    ports:
      - "127.0.0.1:2375:2375"

networks:
  proxy:
    driver: bridge
EOF

# Create instructions for modifying docker-compose files
cat > /opt/docker-security/docker-compose-update-instructions.txt << EOF
# Instructions for updating your docker-compose.yml files

To make your containers more secure:

1. Replace direct Docker socket mounts with the socket proxy:

   CHANGE THIS:
   volumes:
     - /var/run/docker.sock:/var/run/docker.sock:ro

   TO THIS:
   extra_hosts:
     - "docker-socket:127.0.0.1"
   environment:
     - DOCKER_HOST=tcp://docker-socket:2375

2. Add user namespaces when possible:

   user: "1000:1000"  # Use a non-root user ID

3. Limit container capabilities:

   cap_drop:
     - ALL
   cap_add:
     - NET_BIND_SERVICE  # Only add what's needed

4. Set resource limits:

   deploy:
     resources:
       limits:
         cpus: '0.50'
         memory: 512M
EOF

# Create the Docker daemon configuration file with security enhancements
echo "Configuring Docker daemon security settings..."
cat > /etc/docker/daemon.json << EOF
{
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "name": "nofile",
      "hard": 64000,
      "soft": 64000
    }
  }
}
EOF

# Create script to run security audit
cat > /opt/docker-security/docker-security-audit.sh << EOF
#!/bin/bash
# Script to audit Docker security

echo "============================================="
echo "Docker Security Audit"
echo "============================================="
echo "Date: \$(date)"
echo

echo "Docker version:"
docker version --format '{{.Server.Version}}'
echo

echo "Docker info:"
docker info | grep -E 'Security Options|Logging Driver|Cgroup Driver|Storage Driver'
echo

echo "Running containers:"
docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"
echo

echo "Checking for privileged containers:"
docker ps --quiet | xargs docker inspect --format '{{ .Name }} is privileged: {{ .HostConfig.Privileged }}' | grep "true"
echo

echo "Checking for containers with sensitive mounts:"
docker ps --quiet | xargs docker inspect --format '{{ .Name }}: {{ range .HostConfig.Binds }}{{ . }} {{ end }}' | grep -E "docker.sock|/proc|/sys|/dev"
echo

echo "Checking for containers without resource limits:"
docker ps --quiet | xargs docker inspect --format '{{ .Name }} has memory limit: {{ .HostConfig.Memory }}, CPU limit: {{ .HostConfig.NanoCpus }}'
echo

echo "Security scanning complete"
EOF

# Make the audit script executable
chmod +x /opt/docker-security/docker-security-audit.sh

# Start Docker socket proxy
echo "Starting Docker socket proxy..."
# Check which docker compose command is available
if command -v docker compose &> /dev/null; then
  cd /opt/docker-security && docker compose -f docker-socket-proxy.yml up -d
elif command -v docker-compose &> /dev/null; then
  cd /opt/docker-security && docker-compose -f docker-socket-proxy.yml up -d
else
  echo "WARNING: Neither 'docker compose' nor 'docker-compose' command found."
  echo "Please install Docker Compose and then start the Docker socket proxy manually with:"
  echo "cd /opt/docker-security && docker compose -f docker-socket-proxy.yml up -d"
fi

# Restart Docker to apply daemon settings
echo "Restarting Docker to apply security changes..."
systemctl restart docker

echo "Docker security enhancements have been applied."
echo "Please review the instructions in /opt/docker-security/docker-compose-update-instructions.txt"
echo "to update your docker-compose files."
echo
echo "You can run a Docker security audit with:"
echo "  sudo /opt/docker-security/docker-security-audit.sh" 