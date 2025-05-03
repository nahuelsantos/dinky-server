This guide helps you diagnose and fix common issues with Dinky Server.

## General Troubleshooting Steps

1. **Check service status**:
   ```bash
   docker ps
   ```
   Look for containers in an unhealthy state or that have restarted multiple times.

2. **View logs**:
   ```bash
   docker-compose -f services/docker-compose.[service].yml logs -f
   ```
   Replace `[service]` with the relevant service file (e.g., mail, traefik).

3. **Restart services**:
   ```bash
   docker-compose -f services/docker-compose.[service].yml restart
   ```

4. **Check Docker networks**:
   ```bash
   docker network ls
   docker network inspect dinky
   ```

## Common Issues

### Installation Issues

#### Docker Network Conflicts

**Symptoms**: Error creating networks, services can't connect to each other.

**Solution**:
```bash
# Remove existing networks
docker network prune

# Recreate the network
docker network create dinky
```

#### Permission Issues

**Symptoms**: Error accessing volumes, permission denied errors.

**Solution**:
```bash
# Fix permissions on data directories
sudo chown -R 1000:1000 /path/to/volume/data
```

### Mail Service Issues

#### Emails Not Being Delivered

**Symptoms**: Outgoing emails not reaching recipients, stuck in queue.

**Solutions**:

1. Check mail server logs:
   ```bash
   docker-compose -f services/docker-compose.mail.prod.yml logs mail-server
   ```

2. Verify DNS configuration:
   - Ensure MX records are correctly set up
   - Verify SPF, DKIM, and DMARC records if configured

3. Check SMTP relay configuration:
   - Verify Gmail credentials if using Gmail SMTP relay
   - Check port 587 is open for outgoing traffic

4. View the mail queue:
   ```bash
   docker exec -it mail-server mailq
   ```

#### Authentication Failures

**Symptoms**: Unable to log in to webmail, API authentication errors.

**Solutions**:

1. Reset admin password:
   ```bash
   docker exec -it mail-server setup email add admin@yourdomain.com yourpassword
   ```

2. Check environment variables in `.env` file:
   - Ensure MAIL_ADMIN_PASSWORD is correctly set
   - Verify MAIL_DOMAIN matches your domain

### Web and API Issues

#### API Not Responding

**Symptoms**: API endpoints return 502 or connection refused errors.

**Solutions**:

1. Check API logs:
   ```bash
   docker-compose -f services/docker-compose.api.yml logs api
   ```

2. Verify API container is running:
   ```bash
   docker ps | grep api
   ```

3. Restart the API:
   ```bash
   docker-compose -f services/docker-compose.api.yml restart api
   ```

#### Website Not Loading

**Symptoms**: Website shows 404, 502, or does not load at all.

**Solutions**:

1. Check Traefik logs:
   ```bash
   docker-compose -f services/docker-compose.traefik.yml logs traefik
   ```

2. Verify Traefik routes:
   - Check Traefik dashboard at http://localhost:8080 (development)
   - Ensure containers have proper labels for routing

3. Check website container status:
   ```bash
   docker ps | grep web
   ```

### Monitoring Issues

#### Grafana Not Accessible

**Symptoms**: Unable to access Grafana dashboard.

**Solutions**:

1. Check Grafana logs:
   ```bash
   docker-compose -f services/docker-compose.monitoring.yml logs grafana
   ```

2. Reset Grafana admin password:
   ```bash
   docker exec -it grafana grafana-cli admin reset-admin-password newpassword
   ```

#### Prometheus Not Collecting Metrics

**Symptoms**: No data in Grafana dashboards, alerts not firing.

**Solutions**:

1. Check Prometheus targets:
   - Access Prometheus at http://localhost:9090/targets
   - Look for targets in "DOWN" state

2. Verify Prometheus configuration:
   ```bash
   docker-compose -f services/docker-compose.monitoring.yml exec prometheus promtool check config /etc/prometheus/prometheus.yml
   ```

## Advanced Troubleshooting

### Viewing Container Details

```bash
docker inspect <container_name>
```

### Accessing Container Shell

```bash
docker exec -it <container_name> /bin/bash
# or
docker exec -it <container_name> /bin/sh
```

### Checking Resource Usage

```bash
docker stats
```

### Restarting All Services

```bash
docker compose up -d
```

### Complete Reset

If you need to start fresh:

```bash
# Stop all containers
docker compose -f services/docker-compose.traefik.yml down
docker compose -f services/docker-compose.mail.yml down
docker compose -f services/docker-compose.monitoring.yml down
docker compose -f services/docker-compose.api.yml down

# Remove volumes (CAUTION: This will delete all data)
docker volume prune -f

# Redeploy
docker compose up -d
```

## Getting Help

If you're still experiencing issues:

1. Check the [GitHub Issues](https://github.com/nahuelsantos/dinky-server/issues) for similar problems
2. Open a new issue with detailed information about your problem
3. Include logs, error messages, and steps to reproduce the issue 