# Dinky Server - Data Retention Policy

## Overview

This document outlines the data retention policies configured across all monitoring components in Dinky Server. The retention settings are designed to balance storage efficiency with operational visibility requirements.

## Retention Settings

### Prometheus (Metrics)
- **Retention Time**: 30 days (`--storage.tsdb.retention.time=30d`)
- **Retention Size**: 10GB (`--storage.tsdb.retention.size=10GB`)
- **Cleanup**: Automatic based on time or size limit (whichever is reached first)
- **Admin API**: Enabled for manual cleanup operations

### Loki (Logs)
- **Retention Period**: 30 days (`retention_period: 30d`)
- **Compaction**: Enabled with 10-minute intervals
- **Delete Delay**: 2 hours before actual deletion
- **Worker Count**: 150 concurrent deletion workers
- **Query Limits**: 500 max series per query

### Tempo (Traces)
- **Block Retention**: 7 days/168 hours (`block_retention: 168h`)
- **Compacted Block Retention**: 1 hour
- **Max Block Size**: ~100GB
- **Storage**: Local filesystem with automatic cleanup

### Pyroscope (Profiles)
- **Profile Retention**: 30 days/720 hours (`profile-retention: 720h`)
- **Cleanup**: Enabled with 1-hour intervals
- **Storage**: Local filesystem with automatic cleanup

## Rationale

### Why Different Retention Periods?

1. **Traces (7 days)**: High-volume data, primarily used for immediate debugging
2. **Metrics & Logs (30 days)**: Medium-volume, essential for trend analysis and incident investigation
3. **Profiles (30 days)**: Low-volume, important for performance analysis over time

### Storage Considerations

- **Prometheus**: Size-limited (10GB) to prevent disk exhaustion
- **Loki**: Time-based with efficient compaction
- **Tempo**: Time-based with large block sizes for performance
- **Pyroscope**: Time-based with automatic cleanup

## Configuration Files

- **Prometheus**: `docker-compose.yml` command parameters
- **Loki**: `monitoring/loki/loki-config.yml`
- **Tempo**: `monitoring/tempo/tempo-config.yml`
- **Pyroscope**: `monitoring/pyroscope/pyroscope-config.yml`
- **Alertmanager**: `monitoring/prometheus/alertmanager.yml`

> **Note**: To enable alerts, add Alertmanager service to `docker-compose.yml` and include `alertmanager_data` volume.

## Manual Cleanup

### Prometheus
```bash
# Force cleanup (admin API must be enabled)
curl -X POST http://localhost:9090/api/v1/admin/tsdb/delete_series?match[]={__name__=~".+"}
curl -X POST http://localhost:9090/api/v1/admin/tsdb/clean_tombstones
```

### Loki
```bash
# Delete logs for specific labels
curl -X POST "http://localhost:3100/loki/api/v1/delete?query={job=\"example\"}&start=2024-01-01T00:00:00.000Z&end=2024-01-02T00:00:00.000Z"
```

### Docker Volume Cleanup
```bash
# Stop services
make stop

# Remove all data volumes (WARNING: This deletes ALL monitoring data)
docker volume rm dinky-dev-prometheus_data dinky-dev-loki_data dinky-dev-tempo_data dinky-dev-pyroscope_data

# Restart services
make start
```

## Monitoring Retention Status

Check retention status in Grafana dashboards:
- **Prometheus**: Storage usage and retention metrics
- **Loki**: Ingestion rate and retention stats
- **Tempo**: Block statistics and cleanup metrics
- **Pyroscope**: Profile count and retention status

## Alerts

The monitoring stack includes alerts for:
- High storage usage (>80% warning, >95% critical)
- Retention cleanup failures
- Compaction issues
- Data ingestion problems

See `monitoring/prometheus/alert_rules.yml` for complete alert definitions. 