# Dinky Server - Local Development Makefile
# For testing and development on macOS/Linux without sudo requirements
#
# Note: docker-compose.dev.yml is auto-generated (not in git)
# All commands automatically create it if missing - perfect for new developers!

.PHONY: help setup start stop restart logs status clean reset

# Default target
.DEFAULT_GOAL := help

# Colors for output
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m

# Development configuration
DEV_ENV_FILE := .env.dev
COMPOSE_FILE := docker-compose.dev.yml
PROJECT_NAME := dev

# Auto-detect Docker Compose command
DOCKER_COMPOSE := $(shell if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then echo "docker compose"; elif command -v docker-compose >/dev/null 2>&1; then echo "docker-compose"; else echo ""; fi)

# Check if Docker Compose is available
check-docker-compose:
	@if [ -z "$(DOCKER_COMPOSE)" ]; then \
		echo "$(RED)Error: Neither 'docker compose' nor 'docker-compose' is available$(NC)"; \
		echo "$(YELLOW)Please install Docker Compose first$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Using: $(DOCKER_COMPOSE)$(NC)"

help: ## Show this help message
	@echo "$(CYAN)Dinky Server Development Commands:$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make start      # Start all services (includes LGTMA stack)"
	@echo "  make status     # Check service health"
	@echo "  make logs       # Follow all logs"

	@echo "  make clean      # Stop and clean everything"

setup: check-docker-compose ## Create development configuration files
	@echo "$(CYAN)Setting up development environment...$(NC)"
	@if [ ! -f $(DEV_ENV_FILE) ]; then \
		echo "$(YELLOW)Creating development environment file...$(NC)"; \
		echo "TZ=UTC" > $(DEV_ENV_FILE); \
		echo "PIHOLE_PASSWORD=admin123" >> $(DEV_ENV_FILE); \
		echo "GRAFANA_PASSWORD=admin123" >> $(DEV_ENV_FILE); \
		echo "ENVIRONMENT=development" >> $(DEV_ENV_FILE); \
		echo "$(GREEN)Created $(DEV_ENV_FILE)$(NC)"; \
	fi
	@if [ ! -f $(COMPOSE_FILE) ]; then \
		echo "$(YELLOW)Creating development compose file...$(NC)"; \
		$(MAKE) _create-dev-compose; \
		echo "$(GREEN)Development compose file created: $(COMPOSE_FILE)$(NC)"; \
	fi
	@docker network create traefik_network 2>/dev/null || echo "$(YELLOW)Network traefik_network already exists$(NC)"
	@echo "$(GREEN)✓ Development environment ready!$(NC)"

start: setup check-docker-compose ## Start all development services
	@echo "$(CYAN)Starting development services...$(NC)"
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) --env-file $(DEV_ENV_FILE) -p $(PROJECT_NAME) up -d
	@echo "$(GREEN)✓ Development services started!$(NC)"
	@echo ""
	@$(MAKE) status

stop: setup check-docker-compose ## Stop all development services
	@echo "$(CYAN)Stopping development services...$(NC)"
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) -p $(PROJECT_NAME) down
	@echo "$(YELLOW)Ensuring all dev containers are stopped...$(NC)"
	@docker ps -q --filter name=dev- | xargs -r docker stop -t 10 2>/dev/null || true
	@docker ps -aq --filter name=dev- | xargs -r docker rm -f 2>/dev/null || true
	@echo "$(GREEN)✓ Development services stopped!$(NC)"

restart: stop start ## Restart all development services

logs: setup check-docker-compose ## Show logs from all services
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) -p $(PROJECT_NAME) logs -f

logs-%: setup check-docker-compose ## View logs for specific service
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) -p $(PROJECT_NAME) logs -f $*

status: setup check-docker-compose ## Show status of all services
	@echo "$(CYAN)Development Services Status:$(NC)"
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) -p $(PROJECT_NAME) ps
	@echo ""
	@echo "$(CYAN)Service Health Check:$(NC)"
	@echo -n "Traefik:    "; curl -s http://localhost:8080/api/version >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Pi-hole:    "; curl -s http://localhost:8081 >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Grafana:    "; curl -s http://localhost:3000 >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Prometheus: "; curl -s http://localhost:9090 >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Alertmanager: "; curl -s http://localhost:9093 >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Loki:       "; curl -s http://localhost:3100/ready >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Tempo:      "; curl -s http://localhost:3200/ready >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Pyroscope:  "; curl -s http://localhost:4040 >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "OTEL Collector: "; docker ps | grep -q dev-otel-collector && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not running$(NC)"

	@echo -n "Blackbox Exporter: "; curl -s http://localhost:9115/metrics >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Example API:"; curl -s http://localhost:3003 >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Example Site:"; curl -s http://localhost:3004 >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo ""
	@echo "$(YELLOW)LGTM Stack Testing:$(NC)"
	@echo "$(CYAN)Use external tools or manual testing for LGTM validation$(NC)"

clean: setup stop ## Stop services and remove containers/volumes
	@echo "$(CYAN)Cleaning development environment...$(NC)"
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) -p $(PROJECT_NAME) down -v --remove-orphans
	@echo "$(YELLOW)Ensuring all dev containers are completely removed...$(NC)"
	@docker ps -aq --filter name=dev- | xargs -r docker stop -t 10 2>/dev/null || true
	@docker ps -aq --filter name=dev- | xargs -r docker rm -f 2>/dev/null || true
	@echo "$(YELLOW)Cleaning Docker system...$(NC)"
	@docker system prune -f
	@echo "$(GREEN)✓ Development environment cleaned!$(NC)"

reset: clean setup ## Complete reset of development environment
	@echo "$(CYAN)Resetting development environment...$(NC)"
	@rm -f $(DEV_ENV_FILE) $(COMPOSE_FILE)
	@echo "$(GREEN)✓ Development environment reset!$(NC)"

# Internal target to create development compose file
_create-dev-compose:
	@echo "# Development Docker Compose - High Ports, No Security Components" > $(COMPOSE_FILE)
	@echo "services:" >> $(COMPOSE_FILE)
	@echo "  # Core Infrastructure" >> $(COMPOSE_FILE)
	@echo "  traefik:" >> $(COMPOSE_FILE)
	@echo "    image: traefik:v3.0" >> $(COMPOSE_FILE)
	@echo "    container_name: dev-traefik" >> $(COMPOSE_FILE)
	@echo "    restart: unless-stopped" >> $(COMPOSE_FILE)
	@echo "    ports:" >> $(COMPOSE_FILE)
	@echo "      - \"8080:8080\"  # Dashboard" >> $(COMPOSE_FILE)
	@echo "      - \"8000:80\"    # HTTP" >> $(COMPOSE_FILE)
	@echo "      - \"8443:443\"   # HTTPS" >> $(COMPOSE_FILE)
	@echo "    volumes:" >> $(COMPOSE_FILE)
	@echo "      - /var/run/docker.sock:/var/run/docker.sock:ro" >> $(COMPOSE_FILE)
	@echo "    networks:" >> $(COMPOSE_FILE)
	@echo "      - traefik_network" >> $(COMPOSE_FILE)
	@echo "    command:" >> $(COMPOSE_FILE)
	@echo "      - --api.dashboard=true" >> $(COMPOSE_FILE)
	@echo "      - --api.insecure=true" >> $(COMPOSE_FILE)
	@echo "      - --providers.docker=true" >> $(COMPOSE_FILE)
	@echo "      - --providers.docker.exposedbydefault=false" >> $(COMPOSE_FILE)
	@echo "      - --entrypoints.web.address=:80" >> $(COMPOSE_FILE)
	@echo "      - --entrypoints.websecure.address=:443" >> $(COMPOSE_FILE)
	@echo "" >> $(COMPOSE_FILE)
	@echo "  pihole:" >> $(COMPOSE_FILE)
	@echo "    image: pihole/pihole:latest" >> $(COMPOSE_FILE)
	@echo "    container_name: dev-pihole" >> $(COMPOSE_FILE)
	@echo "    restart: unless-stopped" >> $(COMPOSE_FILE)
	@echo "    ports:" >> $(COMPOSE_FILE)
	@echo "      - \"8081:80\"    # Web interface" >> $(COMPOSE_FILE)
	@echo "      - \"5353:53/tcp\" # DNS" >> $(COMPOSE_FILE)
	@echo "      - \"5353:53/udp\" # DNS" >> $(COMPOSE_FILE)
	@echo "    environment:" >> $(COMPOSE_FILE)
	@echo "      TZ: \$${TZ:-UTC}" >> $(COMPOSE_FILE)
	@echo "      WEBPASSWORD: \$${PIHOLE_PASSWORD:-admin123}" >> $(COMPOSE_FILE)
	@echo "      DNSMASQ_LISTENING: all" >> $(COMPOSE_FILE)
	@echo "    volumes:" >> $(COMPOSE_FILE)
	@echo "      - pihole_etc:/etc/pihole" >> $(COMPOSE_FILE)
	@echo "      - pihole_dnsmasq:/etc/dnsmasq.d" >> $(COMPOSE_FILE)
	@echo "    networks:" >> $(COMPOSE_FILE)
	@echo "      - traefik_network" >> $(COMPOSE_FILE)
	@echo "" >> $(COMPOSE_FILE)
	@echo "  # Monitoring Stack" >> $(COMPOSE_FILE)
	@echo "  prometheus:" >> $(COMPOSE_FILE)
	@echo "    image: prom/prometheus:latest" >> $(COMPOSE_FILE)
	@echo "    container_name: dev-prometheus" >> $(COMPOSE_FILE)
	@echo "    restart: unless-stopped" >> $(COMPOSE_FILE)
	@echo "    ports:" >> $(COMPOSE_FILE)
	@echo "      - \"9090:9090\"" >> $(COMPOSE_FILE)
	@echo "    volumes:" >> $(COMPOSE_FILE)
	@echo "      - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro" >> $(COMPOSE_FILE)
	@echo "      - ./monitoring/prometheus/alert_rules.yml:/etc/prometheus/alert_rules.yml:ro" >> $(COMPOSE_FILE)
	@echo "      - ./monitoring/prometheus/recording_rules.yml:/etc/prometheus/recording_rules.yml:ro" >> $(COMPOSE_FILE)
	@echo "      - prometheus_data:/prometheus" >> $(COMPOSE_FILE)
	@echo "    networks:" >> $(COMPOSE_FILE)
	@echo "      - traefik_network" >> $(COMPOSE_FILE)
	@echo "    command:" >> $(COMPOSE_FILE)
	@echo "      - '--config.file=/etc/prometheus/prometheus.yml'" >> $(COMPOSE_FILE)
	@echo "      - '--storage.tsdb.path=/prometheus'" >> $(COMPOSE_FILE)
	@echo "      - '--storage.tsdb.retention.time=30d'" >> $(COMPOSE_FILE)
	@echo "      - '--storage.tsdb.retention.size=10GB'" >> $(COMPOSE_FILE)
	@echo "      - '--web.console.libraries=/etc/prometheus/console_libraries'" >> $(COMPOSE_FILE)
	@echo "      - '--web.console.templates=/etc/prometheus/consoles'" >> $(COMPOSE_FILE)
	@echo "      - '--web.enable-lifecycle'" >> $(COMPOSE_FILE)
	@echo "      - '--web.enable-admin-api'" >> $(COMPOSE_FILE)
	@echo "" >> $(COMPOSE_FILE)
	@echo "  alertmanager:" >> $(COMPOSE_FILE)
	@echo "    image: prom/alertmanager:v0.28.1" >> $(COMPOSE_FILE)
	@echo "    container_name: dev-alertmanager" >> $(COMPOSE_FILE)
	@echo "    restart: unless-stopped" >> $(COMPOSE_FILE)
	@echo "    ports:" >> $(COMPOSE_FILE)
	@echo "      - \"9093:9093\"" >> $(COMPOSE_FILE)
	@echo "    environment:" >> $(COMPOSE_FILE)
	@echo "      DEFAULT_TO: \$${DEFAULT_TO:-admin@dinky.local}" >> $(COMPOSE_FILE)
	@echo "    volumes:" >> $(COMPOSE_FILE)
	@echo "      - ./monitoring/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro" >> $(COMPOSE_FILE)
	@echo "      - alertmanager_data:/alertmanager" >> $(COMPOSE_FILE)
	@echo "    networks:" >> $(COMPOSE_FILE)
	@echo "      - traefik_network" >> $(COMPOSE_FILE)
	@echo "    command:" >> $(COMPOSE_FILE)
	@echo "      - '--config.file=/etc/alertmanager/alertmanager.yml'" >> $(COMPOSE_FILE)
	@echo "      - '--storage.path=/alertmanager'" >> $(COMPOSE_FILE)
	@echo "" >> $(COMPOSE_FILE)
	@echo "  grafana:" >> $(COMPOSE_FILE)
	@echo "    image: grafana/grafana:latest" >> $(COMPOSE_FILE)
	@echo "    container_name: dev-grafana" >> $(COMPOSE_FILE)
	@echo "    restart: unless-stopped" >> $(COMPOSE_FILE)
	@echo "    ports:" >> $(COMPOSE_FILE)
	@echo "      - \"3000:3000\"" >> $(COMPOSE_FILE)
	@echo "    environment:" >> $(COMPOSE_FILE)
	@echo "      GF_SECURITY_ADMIN_PASSWORD: \$${GRAFANA_PASSWORD:-admin123}" >> $(COMPOSE_FILE)
	@echo "      GF_USERS_ALLOW_SIGN_UP: false" >> $(COMPOSE_FILE)
	@echo "    volumes:" >> $(COMPOSE_FILE)
	@echo "      - grafana_data:/var/lib/grafana" >> $(COMPOSE_FILE)
	@echo "    networks:" >> $(COMPOSE_FILE)
	@echo "      - traefik_network" >> $(COMPOSE_FILE)
	@echo "" >> $(COMPOSE_FILE)
	@echo "  loki:" >> $(COMPOSE_FILE)
	@echo "    image: grafana/loki:latest" >> $(COMPOSE_FILE)
	@echo "    container_name: dev-loki" >> $(COMPOSE_FILE)
	@echo "    restart: unless-stopped" >> $(COMPOSE_FILE)
	@echo "    ports:" >> $(COMPOSE_FILE)
	@echo "      - \"3100:3100\"" >> $(COMPOSE_FILE)
	@echo "    volumes:" >> $(COMPOSE_FILE)
	@echo "      - ./monitoring/loki:/etc/loki:ro" >> $(COMPOSE_FILE)
	@echo "      - loki_data:/loki" >> $(COMPOSE_FILE)
	@echo "    command: -config.file=/etc/loki/loki-config.yml" >> $(COMPOSE_FILE)
	@echo "    networks:" >> $(COMPOSE_FILE)
	@echo "      - traefik_network" >> $(COMPOSE_FILE)
	@echo "" >> $(COMPOSE_FILE)
	@echo "  tempo:" >> $(COMPOSE_FILE)
	@echo "    image: grafana/tempo:latest" >> $(COMPOSE_FILE)
	@echo "    container_name: dev-tempo" >> $(COMPOSE_FILE)
	@echo "    restart: unless-stopped" >> $(COMPOSE_FILE)
	@echo "    ports:" >> $(COMPOSE_FILE)
	@echo "      - \"3200:3200\"" >> $(COMPOSE_FILE)
	@echo "    volumes:" >> $(COMPOSE_FILE)
	@echo "      - ./monitoring/tempo:/etc/tempo:ro" >> $(COMPOSE_FILE)
	@echo "      - tempo_data:/var/tempo" >> $(COMPOSE_FILE)
	@echo "    command: -config.file=/etc/tempo/tempo-config.yml" >> $(COMPOSE_FILE)
	@echo "    networks:" >> $(COMPOSE_FILE)
	@echo "      - traefik_network" >> $(COMPOSE_FILE)
	@echo "" >> $(COMPOSE_FILE)
	@echo "  otel-collector:" >> $(COMPOSE_FILE)
	@echo "    image: otel/opentelemetry-collector-contrib:latest" >> $(COMPOSE_FILE)
	@echo "    container_name: dev-otel-collector" >> $(COMPOSE_FILE)
	@echo "    restart: unless-stopped" >> $(COMPOSE_FILE)
	@echo "    ports:" >> $(COMPOSE_FILE)
	@echo "      - \"4317:4317\"  # OTLP gRPC" >> $(COMPOSE_FILE)
	@echo "      - \"4318:4318\"  # OTLP HTTP" >> $(COMPOSE_FILE)
	@echo "      - \"8888:8888\"  # Metrics" >> $(COMPOSE_FILE)
	@echo "    volumes:" >> $(COMPOSE_FILE)
	@echo "      - ./monitoring/otel-collector:/etc/otel-collector:ro" >> $(COMPOSE_FILE)
	@echo "    command: --config=/etc/otel-collector/otel-collector-config.yml" >> $(COMPOSE_FILE)
	@echo "    networks:" >> $(COMPOSE_FILE)
	@echo "      - traefik_network" >> $(COMPOSE_FILE)
	@echo "" >> $(COMPOSE_FILE)
	@echo "  pyroscope:" >> $(COMPOSE_FILE)
	@echo "    image: grafana/pyroscope:latest" >> $(COMPOSE_FILE)
	@echo "    container_name: dev-pyroscope" >> $(COMPOSE_FILE)
	@echo "    restart: unless-stopped" >> $(COMPOSE_FILE)
	@echo "    ports:" >> $(COMPOSE_FILE)
	@echo "      - \"4040:4040\"" >> $(COMPOSE_FILE)
	@echo "    volumes:" >> $(COMPOSE_FILE)
	@echo "      - ./monitoring/pyroscope:/etc/pyroscope:ro" >> $(COMPOSE_FILE)
	@echo "      - pyroscope_data:/var/lib/pyroscope" >> $(COMPOSE_FILE)
	@echo "    command: server -config=/etc/pyroscope/pyroscope-config.yml" >> $(COMPOSE_FILE)
	@echo "    networks:" >> $(COMPOSE_FILE)
	@echo "      - traefik_network" >> $(COMPOSE_FILE)
	@echo "" >> $(COMPOSE_FILE)
	@echo "  # Blackbox Exporter - HTTP/HTTPS probing" >> $(COMPOSE_FILE)
	@echo "  blackbox-exporter:" >> $(COMPOSE_FILE)
	@echo "    image: prom/blackbox-exporter:v0.25.0" >> $(COMPOSE_FILE)
	@echo "    container_name: dev-blackbox-exporter" >> $(COMPOSE_FILE)
	@echo "    restart: unless-stopped" >> $(COMPOSE_FILE)
	@echo "    ports:" >> $(COMPOSE_FILE)
	@echo "      - \"9115:9115\"" >> $(COMPOSE_FILE)
	@echo "    volumes:" >> $(COMPOSE_FILE)
	@echo "      - ./monitoring/blackbox:/etc/blackbox_exporter" >> $(COMPOSE_FILE)
	@echo "    networks:" >> $(COMPOSE_FILE)
	@echo "      - traefik_network" >> $(COMPOSE_FILE)
	@echo "    command:" >> $(COMPOSE_FILE)
	@echo "      - '--config.file=/etc/blackbox_exporter/config.yml'" >> $(COMPOSE_FILE)
	@echo "" >> $(COMPOSE_FILE)


	@echo "  # Example Services" >> $(COMPOSE_FILE)
	@echo "  example-api:" >> $(COMPOSE_FILE)
	@echo "    image: nginx:alpine" >> $(COMPOSE_FILE)
	@echo "    container_name: dev-example-api" >> $(COMPOSE_FILE)
	@echo "    restart: unless-stopped" >> $(COMPOSE_FILE)
	@echo "    ports:" >> $(COMPOSE_FILE)
	@echo "      - \"3003:80\"" >> $(COMPOSE_FILE)
	@echo "    volumes:" >> $(COMPOSE_FILE)
	@echo "      - ./apis/example-api/html:/usr/share/nginx/html:ro" >> $(COMPOSE_FILE)
	@echo "    networks:" >> $(COMPOSE_FILE)
	@echo "      - traefik_network" >> $(COMPOSE_FILE)
	@echo "" >> $(COMPOSE_FILE)
	@echo "  example-site:" >> $(COMPOSE_FILE)
	@echo "    image: nginx:alpine" >> $(COMPOSE_FILE)
	@echo "    container_name: dev-example-site" >> $(COMPOSE_FILE)
	@echo "    restart: unless-stopped" >> $(COMPOSE_FILE)
	@echo "    ports:" >> $(COMPOSE_FILE)
	@echo "      - \"3004:80\"" >> $(COMPOSE_FILE)
	@echo "    volumes:" >> $(COMPOSE_FILE)
	@echo "      - ./sites/example-site/html:/usr/share/nginx/html:ro" >> $(COMPOSE_FILE)
	@echo "    networks:" >> $(COMPOSE_FILE)
	@echo "      - traefik_network" >> $(COMPOSE_FILE)
	@echo "" >> $(COMPOSE_FILE)
	@echo "networks:" >> $(COMPOSE_FILE)
	@echo "  traefik_network:" >> $(COMPOSE_FILE)
	@echo "    external: true" >> $(COMPOSE_FILE)
	@echo "" >> $(COMPOSE_FILE)
	@echo "volumes:" >> $(COMPOSE_FILE)
	@echo "  pihole_etc:" >> $(COMPOSE_FILE)
	@echo "  pihole_dnsmasq:" >> $(COMPOSE_FILE)
	@echo "  prometheus_data:" >> $(COMPOSE_FILE)
	@echo "  alertmanager_data:" >> $(COMPOSE_FILE)
	@echo "  grafana_data:" >> $(COMPOSE_FILE)
	@echo "  loki_data:" >> $(COMPOSE_FILE)
	@echo "  tempo_data:" >> $(COMPOSE_FILE)
	@echo "  pyroscope_data:" >> $(COMPOSE_FILE)

 