.PHONY: help setup install test mail-setup mail-start mail-stop mail-restart mail-test mail-logs test-all

# Get architecture
ARCH := $(shell uname -m)
ifeq ($(ARCH),arm64)
    # M1/M2/M3 Mac
    export DOCKER_PLATFORM := linux/arm64
else ifeq ($(ARCH),x86_64)
    # Intel Mac or Linux
    export DOCKER_PLATFORM := linux/amd64
else
    # Default to ARM64
    export DOCKER_PLATFORM := linux/arm64
endif

# Default target
help:
	@echo "Dinky Server Management Commands:"
	@echo ""
	@echo "Installation:"
	@echo "  make setup         - Initialize the environment (runs initialize.sh)"
	@echo "  make install       - Install Dinky Server (runs install.sh)"
	@echo "  make test          - Test Dinky Server installation (runs test.sh)"
	@echo "  make test-all      - Run comprehensive tests (runs test-all-components.sh)"
	@echo ""
	@echo "Mail Service Management:"
	@echo "  make mail-setup    - Setup mail services for local testing"
	@echo "  make mail-start    - Start mail services locally"
	@echo "  make mail-stop     - Stop mail services"
	@echo "  make mail-restart  - Restart mail services"
	@echo "  make mail-test     - Test mail services"
	@echo "  make mail-logs     - View mail service logs"
	@echo ""
	@echo "Detected architecture: $(ARCH)"
	@echo "Using Docker platform: $(DOCKER_PLATFORM)"

# Main installation wrappers
setup:
	@echo "Initializing Dinky Server environment..."
	@sudo ./scripts/initialize.sh

install:
	@echo "Installing Dinky Server..."
	@sudo ./scripts/install.sh

test:
	@echo "Testing Dinky Server installation..."
	@sudo ./scripts/test.sh

test-all:
	@echo "Running comprehensive tests..."
	@sudo ./scripts/test-all-components.sh

# Mail service management commands
mail-setup:
	@echo "Setting up mail services..."
	@mkdir -p services/mail-server/sasl
	@touch services/mail-server/sasl/sasl_passwd
	@chmod 600 services/mail-server/sasl/sasl_passwd
	@docker network inspect dinky-network >/dev/null 2>&1 || docker network create dinky-network
	@echo "Mail services setup complete."

mail-start: mail-setup
	@echo "Starting mail services..."
	@echo "Using Docker platform: $(DOCKER_PLATFORM)"
	@docker compose down mail-server mail-api --remove-orphans 2>/dev/null || true
	@DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker compose build mail-server mail-api
	@DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 SERVER_IP=127.0.0.1 RESTART_POLICY=no docker compose up -d mail-server mail-api
	@grep -q "mail-api.local" /etc/hosts || sudo sh -c 'echo "127.0.0.1 mail-api.local" >> /etc/hosts'
	@echo "Mail services started successfully."
	@echo "- Mail API available at: http://mail-api.local:20001"
	@echo "- Mail server ports: 25, 587"

mail-stop:
	@echo "Stopping mail services..."
	@docker compose down mail-server mail-api
	@echo "Mail services stopped."

mail-restart: mail-stop mail-start
	@echo "Mail services restarted successfully."

mail-test:
	@echo "Testing mail services..."
	@echo "Testing mail-api container..."
	@docker exec -it mail-api wget -q -O- http://localhost:20001/health || echo "Mail API health check failed."
	@echo "Testing mail-server container..."
	@docker exec -it mail-server sh -c "postconf -n" > /dev/null || echo "Mail server configuration check failed."
	@echo "Mail services test complete."

mail-logs:
	@echo "Viewing mail server logs..."
	@docker logs mail-server 2>&1 || echo "Mail server not running"
	@echo ""
	@echo "Viewing mail API logs..."
	@docker logs mail-api 2>&1 || echo "Mail API not running"

# Send a test email - Usage: make mail-send-test EMAIL=your@email.com
mail-send-test:
	@if [ -z "$(EMAIL)" ]; then \
		echo "Please specify an email address: make mail-send-test EMAIL=your@email.com"; \
		exit 1; \
	fi
	@echo "Sending test email to $(EMAIL)..."
	@sudo ./scripts/send-test-email.sh $(EMAIL) 