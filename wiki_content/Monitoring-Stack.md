# Monitoring Stack

Dinky Server includes a comprehensive monitoring stack to help you track the health and performance of your server and services.

## Components

The monitoring stack consists of:

1. **Prometheus**: Time-series database for metrics collection
2. **Grafana**: Visualization and dashboarding
3. **Node Exporter**: System metrics collection
4. **cAdvisor**: Container metrics collection
5. **Alertmanager**: Alert routing and notification

## Accessing Monitoring

### Grafana Dashboard

Access the Grafana dashboard at:

```
https://grafana.yourdomain.com
```

Default login credentials:
- Username: `admin`
- Password: The password set in your `.env` file under `GRAFANA_ADMIN_PASSWORD`

### Prometheus Interface

Access the Prometheus interface at:

```
https://prometheus.yourdomain.com
```

## Available Dashboards

The following pre-configured dashboards are available:

1. **System Overview**: CPU, memory, disk usage, and network traffic
2. **Container Metrics**: Resource usage by container
3. **Traefik Dashboard**: Proxy traffic and response times
4. **Mail Server**: Mail service metrics (queue size, deliveries, etc.)
5. **Pi-hole**: Ad blocking statistics

## Configuring Alerts

Alerts can be configured in Prometheus to notify you of potential issues:

1. Navigate to Grafana
2. Go to Alerting > Alert Rules
3. Create a new alert rule based on your requirements

Default alert channels include:
- Email notifications
- Slack notifications (requires configuration)
- Discord notifications (requires configuration)

## Adding Custom Metrics

To add custom metrics to your monitoring stack:

1. Create a new exporter or use an existing one for the service you want to monitor
2. Add the exporter to the `docker-compose.monitoring.yml` file
3. Add a new scrape job to the `prometheus/prometheus.yml` file
4. Restart the monitoring stack:
   ```bash
   docker-compose -f services/docker-compose.monitoring.yml restart
   ```

## Troubleshooting

### Common Issues

#### Grafana Not Loading

1. Check if the Grafana container is running:
   ```bash
   docker ps | grep grafana
   ```
2. Check Grafana logs:
   ```bash
   docker logs dinky_grafana
   ```

#### Missing Metrics

1. Verify that Prometheus can reach the exporter:
   ```bash
   curl http://exporter:port/metrics
   ```
2. Check the Prometheus targets page to see if any targets are down:
   ```
   https://prometheus.yourdomain.com/targets
   ```

#### High Resource Usage

If the monitoring stack is using too many resources:

1. Adjust retention periods in `prometheus/prometheus.yml`
2. Reduce scrape intervals for less critical metrics
3. Consider using remote storage for long-term metrics retention

## Advanced Configuration

For advanced configuration options, see the following files:

- `monitoring/prometheus/prometheus.yml`: Prometheus configuration
- `monitoring/grafana/provisioning/`: Grafana provisioning files
- `monitoring/alertmanager/alertmanager.yml`: Alert manager configuration

## Related Documentation

- [Official Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Official Grafana Documentation](https://grafana.com/docs/)
- [Troubleshooting Guide](Troubleshooting#monitoring) 