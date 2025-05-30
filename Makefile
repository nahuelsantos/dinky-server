# Dinky Server - Local Development Makefile
# For testing and development on macOS/Linux without sudo requirements
#
# Note: docker-compose.dev.yml is auto-generated (not in git)
# All commands automatically create it if missing - perfect for new developers!

.PHONY: help dev-up dev-down dev-restart dev-logs dev-status dev-clean dev-reset dev-core dev-monitoring dev-apis dev-sites

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
PROJECT_NAME := dinky-dev

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
	@echo "$(CYAN)Dinky Server - Local Development$(NC)"
	@echo "$(CYAN)================================$(NC)"
	@echo ""
	@echo "$(GREEN)Essential Commands:$(NC)"
	@echo "  $(CYAN)dev-up$(NC)         Start all services"
	@echo "  $(CYAN)dev-down$(NC)       Stop all services"
	@echo "  $(CYAN)dev-status$(NC)     Check service status"
	@echo "  $(CYAN)dev-logs$(NC)       View all logs"
	@echo "  $(CYAN)dev-clean$(NC)      Clean everything"
	@echo ""
	@echo "$(GREEN)Service Groups:$(NC)"
	@echo "  $(CYAN)dev-core$(NC)       Core only (Traefik, Pi-hole)"
	@echo "  $(CYAN)dev-monitoring$(NC) Monitoring stack only"
	@echo ""
	@echo "$(YELLOW)Service URLs (after dev-up):$(NC)"
	@echo "  Traefik Dashboard: http://localhost:8080"
	@echo "  Pi-hole Admin:     http://localhost:8081"
	@echo "  Grafana:          http://localhost:3000"
	@echo "  Prometheus:       http://localhost:9090"
	@echo "  Loki:             http://localhost:3100"
	@echo "  Tempo:            http://localhost:3200"
	@echo "  Pyroscope:        http://localhost:4040"
	@echo "  Example API:      http://localhost:3001"
	@echo "  Example Site:     http://localhost:3002"
	@echo ""
	@echo "$(YELLOW)Tip: Use 'make dev-up' to start everything, 'make dev-status' to check health$(NC)"
	@echo "$(GREEN)Note: All files auto-created on first run - perfect for new developers!$(NC)"

dev-setup: ## Initial setup for development environment
	@echo "$(CYAN)Setting up development environment...$(NC)"
	@if [ ! -f "$(DEV_ENV_FILE)" ]; then \
		echo "$(YELLOW)Creating development environment file...$(NC)"; \
		cp .env.example $(DEV_ENV_FILE) 2>/dev/null || echo "# Development Environment" > $(DEV_ENV_FILE); \
		echo "SERVER_IP=localhost" >> $(DEV_ENV_FILE); \
		echo "TZ=UTC" >> $(DEV_ENV_FILE); \
		echo "DOMAIN_NAME=localhost" >> $(DEV_ENV_FILE); \
		echo "PIHOLE_PASSWORD=admin123" >> $(DEV_ENV_FILE); \
		echo "GRAFANA_PASSWORD=admin123" >> $(DEV_ENV_FILE); \
		echo "MAIL_DOMAIN=localhost" >> $(DEV_ENV_FILE); \
		echo "DEFAULT_FROM=test@localhost" >> $(DEV_ENV_FILE); \
		echo "DEFAULT_TO=admin@localhost" >> $(DEV_ENV_FILE); \
		echo "$(GREEN)Development environment file created: $(DEV_ENV_FILE)$(NC)"; \
	fi
	@if [ ! -f "$(COMPOSE_FILE)" ]; then \
		echo "$(YELLOW)Creating development compose file (auto-generated, not in git)...$(NC)"; \
		$(MAKE) _create-dev-compose; \
		echo "$(GREEN)Development compose file created: $(COMPOSE_FILE)$(NC)"; \
	fi
	@docker network create traefik_network 2>/dev/null || echo "$(YELLOW)Network traefik_network already exists$(NC)"
	@echo "$(GREEN)✓ Development environment ready!$(NC)"

dev-up: dev-setup check-docker-compose ## Start all development services
	@echo "$(CYAN)Starting development services...$(NC)"
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) --env-file $(DEV_ENV_FILE) -p $(PROJECT_NAME) up -d
	@echo "$(GREEN)✓ Development services started!$(NC)"
	@echo ""
	@$(MAKE) dev-status

dev-down: dev-setup check-docker-compose ## Stop all development services
	@echo "$(CYAN)Stopping development services...$(NC)"
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) -p $(PROJECT_NAME) down
	@echo "$(GREEN)✓ Development services stopped!$(NC)"

dev-restart: dev-down dev-up ## Restart all development services

dev-logs: dev-setup check-docker-compose ## Show logs from all services
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) -p $(PROJECT_NAME) logs -f

dev-logs-%: dev-setup check-docker-compose ## View logs for specific service
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) -p $(PROJECT_NAME) logs -f $*

dev-status: dev-setup check-docker-compose ## Show status of all services
	@echo "$(CYAN)Development Services Status:$(NC)"
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) -p $(PROJECT_NAME) ps
	@echo ""
	@echo "$(CYAN)Service Health Check:$(NC)"
	@echo -n "Traefik:    "; curl -s http://localhost:8080/api/version >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Pi-hole:    "; curl -s http://localhost:8081 >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Grafana:    "; curl -s http://localhost:3000 >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Prometheus: "; curl -s http://localhost:9090 >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Loki:       "; curl -s http://localhost:3100/ready >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Tempo:      "; curl -s http://localhost:3200/ready >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Pyroscope:  "; curl -s http://localhost:4040 >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "OTEL Collector: "; docker ps | grep -q dinky-dev-otel-collector && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not running$(NC)"
	@echo -n "Example API:"; curl -s http://localhost:3001 >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "Example Site:"; curl -s http://localhost:3002 >/dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not responding$(NC)"

dev-clean: dev-setup dev-down ## Stop services and remove containers/volumes
	@echo "$(CYAN)Cleaning development environment...$(NC)"
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) -p $(PROJECT_NAME) down -v --remove-orphans
	@docker system prune -f
	@echo "$(GREEN)✓ Development environment cleaned!$(NC)"

dev-reset: dev-clean dev-setup ## Complete reset of development environment
	@echo "$(CYAN)Resetting development environment...$(NC)"
	@rm -f $(DEV_ENV_FILE) $(COMPOSE_FILE)
	@echo "$(GREEN)✓ Development environment reset!$(NC)"

dev-core: dev-setup check-docker-compose ## Start only core services (Traefik, Pi-hole)
	@echo "$(CYAN)Starting core services...$(NC)"
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) --env-file $(DEV_ENV_FILE) -p $(PROJECT_NAME) up -d traefik pihole
	@echo "$(GREEN)✓ Core services started!$(NC)"

dev-monitoring: dev-setup check-docker-compose ## Start only monitoring services
	@echo "$(CYAN)Starting monitoring services...$(NC)"
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) --env-file $(DEV_ENV_FILE) -p $(PROJECT_NAME) up -d prometheus grafana loki tempo pyroscope otel-collector
	@echo "$(GREEN)✓ Monitoring services started!$(NC)"

dev-apis: dev-setup check-docker-compose ## Start only API services
	@echo "$(CYAN)Starting API services...$(NC)"
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) --env-file $(DEV_ENV_FILE) -p $(PROJECT_NAME) up -d example-api
	@echo "$(GREEN)✓ API services started!$(NC)"

dev-sites: dev-setup check-docker-compose ## Start only site services
	@echo "$(CYAN)Starting site services...$(NC)"
	@$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) --env-file $(DEV_ENV_FILE) -p $(PROJECT_NAME) up -d example-site
	@echo "$(GREEN)✓ Site services started!$(NC)"

# Internal target to create development compose file
_create-dev-compose:
	@echo "# Development Docker Compose - High Ports, No Security Components" > $(COMPOSE_FILE)
	@echo "services:" >> $(COMPOSE_FILE)
	@echo "  # Core Infrastructure" >> $(COMPOSE_FILE)
	@echo "  traefik:" >> $(COMPOSE_FILE)
	@echo "    image: traefik:v3.0" >> $(COMPOSE_FILE)
	@echo "    container_name: dinky-dev-traefik" >> $(COMPOSE_FILE)
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
	@echo "    container_name: dinky-dev-pihole" >> $(COMPOSE_FILE)
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
	@echo "    container_name: dinky-dev-prometheus" >> $(COMPOSE_FILE)
	@echo "    restart: unless-stopped" >> $(COMPOSE_FILE)
	@echo "    ports:" >> $(COMPOSE_FILE)
	@echo "      - \"9090:9090\"" >> $(COMPOSE_FILE)
	@echo "    volumes:" >> $(COMPOSE_FILE)
	@echo "      - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro" >> $(COMPOSE_FILE)
	@echo "      - prometheus_data:/prometheus" >> $(COMPOSE_FILE)
	@echo "    networks:" >> $(COMPOSE_FILE)
	@echo "      - traefik_network" >> $(COMPOSE_FILE)
	@echo "    command:" >> $(COMPOSE_FILE)
	@echo "      - '--config.file=/etc/prometheus/prometheus.yml'" >> $(COMPOSE_FILE)
	@echo "      - '--storage.tsdb.path=/prometheus'" >> $(COMPOSE_FILE)
	@echo "      - '--web.console.libraries=/etc/prometheus/console_libraries'" >> $(COMPOSE_FILE)
	@echo "      - '--web.console.templates=/etc/prometheus/consoles'" >> $(COMPOSE_FILE)
	@echo "      - '--web.enable-lifecycle'" >> $(COMPOSE_FILE)
	@echo "" >> $(COMPOSE_FILE)
	@echo "  grafana:" >> $(COMPOSE_FILE)
	@echo "    image: grafana/grafana:latest" >> $(COMPOSE_FILE)
	@echo "    container_name: dinky-dev-grafana" >> $(COMPOSE_FILE)
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
	@echo "    container_name: dinky-dev-loki" >> $(COMPOSE_FILE)
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
	@echo "    container_name: dinky-dev-tempo" >> $(COMPOSE_FILE)
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
	@echo "    container_name: dinky-dev-otel-collector" >> $(COMPOSE_FILE)
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
	@echo "    container_name: dinky-dev-pyroscope" >> $(COMPOSE_FILE)
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
	@echo "  # Example Services" >> $(COMPOSE_FILE)
	@echo "  example-api:" >> $(COMPOSE_FILE)
	@echo "    image: nginx:alpine" >> $(COMPOSE_FILE)
	@echo "    container_name: dinky-dev-example-api" >> $(COMPOSE_FILE)
	@echo "    restart: unless-stopped" >> $(COMPOSE_FILE)
	@echo "    ports:" >> $(COMPOSE_FILE)
	@echo "      - \"3001:80\"" >> $(COMPOSE_FILE)
	@echo "    volumes:" >> $(COMPOSE_FILE)
	@echo "      - ./apis/example-api/html:/usr/share/nginx/html:ro" >> $(COMPOSE_FILE)
	@echo "    networks:" >> $(COMPOSE_FILE)
	@echo "      - traefik_network" >> $(COMPOSE_FILE)
	@echo "" >> $(COMPOSE_FILE)
	@echo "  example-site:" >> $(COMPOSE_FILE)
	@echo "    image: nginx:alpine" >> $(COMPOSE_FILE)
	@echo "    container_name: dinky-dev-example-site" >> $(COMPOSE_FILE)
	@echo "    restart: unless-stopped" >> $(COMPOSE_FILE)
	@echo "    ports:" >> $(COMPOSE_FILE)
	@echo "      - \"3002:80\"" >> $(COMPOSE_FILE)
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
	@echo "  grafana_data:" >> $(COMPOSE_FILE)
	@echo "  loki_data:" >> $(COMPOSE_FILE)
	@echo "  tempo_data:" >> $(COMPOSE_FILE)
	@echo "  pyroscope_data:" >> $(COMPOSE_FILE) 