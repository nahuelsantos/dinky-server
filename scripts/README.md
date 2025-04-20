# Dinky Server Scripts

This directory contains utility scripts for managing and maintaining your Dinky Server installation.

## Directory Structure Scripts

### restructure-directories.sh

This script reorganizes your Dinky Server files according to the new directory structure:

```
/opt/dinky-server/
├── sites/           # All websites
├── apis/            # Shared APIs
├── services/        # Background services
├── monitoring/      # Monitoring stack
├── infrastructure/  # Core infrastructure
└── scripts/         # Deployment scripts
```

Usage:
```bash
./restructure-directories.sh
```

### validate-structure.sh

Validates that your directory structure is correctly set up.

Usage:
```bash
./validate-structure.sh
```

## Site Management

### setup-site.sh

This script helps set up a new website in your Dinky server with all the required configuration.

Usage:
```bash
./setup-site.sh [site_name] [domain] [git_repo]
```

Arguments:
- `site_name` - Name of the site directory (e.g., nahuelsantos)
- `domain` - Domain for the site (e.g., nahuelsantos.com)
- `git_repo` - Git repository URL (optional)

Examples:
```bash
./setup-site.sh nahuelsantos nahuelsantos.com https://github.com/nahuelsantos/nahuelsantos-website.git
./setup-site.sh loopingbyte loopingbyte.com
```

The script will:
1. Create a directory for the site in `/opt/dinky-server/sites/`
2. Clone the Git repository if provided
3. Create a site-specific environment file
4. Create a sample docker-compose.yml if one doesn't exist
5. Configure the site to work with the mail service

## Environment Management

### environment-manager.sh

This script helps manage environment variables across your Dinky server components.

Usage:
```bash
./environment-manager.sh [command] [arguments]
```

Commands:
- `setup-env [component]` - Create environment files for a component based on templates
- `update-env [component] [var]` - Update a specific environment variable
- `list-env [component]` - List all environment files and their values
- `backup-env` - Create a timestamped backup of all environment files

Components:
- `main` - Main server environment variables
- `mail` - Mail service environment variables
- `monitoring` - Monitoring stack environment variables
- `traefik` - Traefik environment variables
- `cloudflared` - Cloudflared environment variables
- `site-[name]` - Environment for a specific site (e.g., site-nahuelsantos)

Examples:
```bash
./environment-manager.sh setup-env mail
./environment-manager.sh update-env mail MAIL_DOMAIN=example.com
./environment-manager.sh list-env
```

## Service Testing Scripts

### test-mail-service.sh

Tests the mail service configuration and functionality.

Usage:
```bash
./test-mail-service.sh
```

The script will:
1. Check if mail-server and mail-api containers are running
2. Test the mail-api health endpoint
3. Test sending an email through the API
4. Check mail server configuration

## Backup Scripts

Backup scripts are stored in the `backup/` subdirectory.

### Environment Backups

The `environment-manager.sh` script creates timestamped backups of all environment files when you run:

```bash
./environment-manager.sh backup-env
```

Backups are stored in:
```
/opt/dinky-server/scripts/backup/env_TIMESTAMP/
``` 