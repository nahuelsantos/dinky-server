.PHONY: help run-local-mail stop-local-mail test-mail-api test-mail-server clean-local-mail logs-mail setup-local-mail restart-local-mail deploy-mail-services

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
	@echo "Local Development Commands:"
	@echo "  make setup-local-mail  - Setup mail services for local testing"
	@echo "  make run-local-mail    - Start mail services locally for testing"
	@echo "  make restart-local-mail - Restart mail services locally"
	@echo "  make stop-local-mail   - Stop local mail services"
	@echo "  make test-mail-api     - Test the mail API endpoint"
	@echo "  make test-mail-server  - Test SMTP server connection"
	@echo "  make logs-mail         - View mail server and API logs"
	@echo "  make clean-local-mail  - Remove local mail service containers and volumes"
	@echo ""
	@echo "Production Deployment Commands:"
	@echo "  make deploy-mail-services - Deploy mail services to Dinky"
	@echo ""
	@echo "Detected architecture: $(ARCH)"
	@echo "Using Docker platform: $(DOCKER_PLATFORM)"

# Setup environment for local mail testing
setup-local-mail:
	@echo "Setting up local mail environment..."
	@echo "Detected architecture: $(ARCH)"
	@echo "Using Docker platform: $(DOCKER_PLATFORM)"
	
	@# Create necessary directories
	@mkdir -p services/mail-server-logs
	@mkdir -p services/mail-server/sasl
	@touch services/mail-server/sasl/sasl_passwd
	
	@# Check if Docker is running
	@docker info > /dev/null 2>&1 || { echo "Error: Docker is not running. Please start Docker and try again."; exit 1; }
	
	@echo "Setup complete. Run 'make run-local-mail' to start services."

# Create local network if it doesn't exist
create-network:
	@echo "Creating docker network if it doesn't exist..."
	@docker network inspect dinky-network >/dev/null 2>&1 || docker network create dinky-network

# Start mail services locally
run-local-mail: setup-local-mail create-network
	@echo "Starting mail services locally..."
	@echo "Using Docker platform: $(DOCKER_PLATFORM)"
	
	@# Clean up any previous failed builds
	@echo "Cleaning up any previous failed builds..."
	@cd services && docker-compose -f docker-compose.mail.yml -f docker-compose.mail.local.yml down --remove-orphans 2>/dev/null || true
	
	@# Build and start the containers
	@cd services && \
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker-compose -f docker-compose.mail.yml -f docker-compose.mail.local.yml build || { \
		echo "Error building services. See above for details."; \
		exit 1; \
	}
	
	@cd services && \
	DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker-compose -f docker-compose.mail.yml -f docker-compose.mail.local.yml up -d || { \
		echo "Error starting services. Checking logs..."; \
		docker-compose -f docker-compose.mail.yml -f docker-compose.mail.local.yml logs; \
		exit 1; \
	}
	
	@echo "Adding mail-api.local to /etc/hosts if needed (requires sudo)..."
	@grep -q "mail-api.local" /etc/hosts || \
	sudo sh -c 'echo "127.0.0.1 mail-api.local" >> /etc/hosts'
	@echo "Mail services are running locally"
	@echo "- Mail API is available at: http://mail-api.local:8080"
	@echo "- SMTP server is available at: localhost:2525 (mapped to internal port 25)"
	@echo "- SMTP submission port is available at: localhost:5587 (mapped to internal port 587)"
	@echo ""
	@echo "To check logs: make logs-mail"
	@echo "To test API: make test-mail-api"
	@echo "To test SMTP server: make test-mail-server"

# Restart mail services
restart-local-mail: stop-local-mail
	@echo "Restarting mail services..."
	@make run-local-mail
	@echo "Services restarted successfully."

# Stop mail services
stop-local-mail:
	@echo "Stopping mail services..."
	@cd services && \
	docker-compose -f docker-compose.mail.yml -f docker-compose.mail.local.yml down
	@echo "Mail services stopped"

# Test mail API
test-mail-api:
	@echo "Testing mail API..."
	@curl -X POST http://mail-api.local:8080/send \
	-H "Content-Type: application/json" \
	-d '{"to":"test@example.com","subject":"Test Email","body":"This is a test email from the local environment"}' || \
	echo "Failed to connect to mail API. Make sure services are running with 'make run-local-mail'"
	@echo ""
	@echo "If the test failed with 'connection refused', try restarting the services with 'make restart-local-mail'"

# Test SMTP server
test-mail-server:
	@echo "Testing SMTP server connection..."
	@(echo "QUIT" | nc localhost 2525) || \
	echo "Failed to connect to SMTP server. Make sure services are running with 'make run-local-mail'"
	@echo "If you saw a greeting message above, the SMTP server is working!"

# View logs
logs-mail:
	@echo "Viewing mail server logs..."
	@docker logs mail-server 2>&1 || echo "Mail server container not running"
	@echo ""
	@echo "Viewing mail API logs..."
	@docker logs mail-api 2>&1 || echo "Mail API container not running"

# Clean up everything
clean-local-mail: stop-local-mail
	@echo "Removing mail service containers and volumes..."
	@cd services && \
	docker-compose -f docker-compose.mail.yml -f docker-compose.mail.local.yml down -v
	@echo "Mail services cleaned up"

# Deploy mail services to production
deploy-mail-services:
	@echo "Preparing to deploy mail services to Dinky..."
	
	@# Check if .env.mail.prod exists
	@if [ ! -f services/.env.mail.prod ]; then \
		echo "Creating production environment file from template..."; \
		cp services/.env.mail services/.env.mail.prod; \
		echo "IMPORTANT: Please edit services/.env.mail.prod with your production settings"; \
		echo "and then run this command again."; \
		exit 1; \
	fi
	
	@echo "Deploying mail services using production configuration..."
	@echo "This will copy files to Dinky and start the services..."
	
	@echo "NOTE: This is a template deployment command. Please modify it to match your SSH setup:"
	@echo "scp -r services/mail-server services/docker-compose.mail.prod.yml services/.env.mail.prod dinky:/path/to/dinky-server/"
	@echo "scp -r apis/mail-api dinky:/path/to/dinky-server/apis/"
	@echo "ssh dinky \"cd /path/to/dinky-server && docker-compose -f services/docker-compose.mail.prod.yml --env-file services/.env.mail.prod up -d\""
	
	@echo ""
	@echo "After deployment, you'll need to update your website configurations to connect to the mail-api"
	@echo "See the examples directory for reference configurations" 