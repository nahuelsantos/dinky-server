# Tools Guide

Administrative and development tools for Dinky Server maintenance and troubleshooting.

## Overview

The `tools/` directory contains utilities separate from production services, used for administration, database management, and development.

## Available Tools

### DbGate - Database Management

**Location**: `tools/dbgate/`  
**Port**: 3500  
**Purpose**: Web-based SQLite database administration

**Quick Start:**
```bash
cd tools/dbgate
docker-compose up -d
```

Access at: http://192.168.1.129:3500

**Features:**
- SQL editor with autocomplete
- Visual query builder
- Schema explorer
- Import/Export (CSV, JSON, Excel)
- Data visualization

**Full Documentation**: See `tools/dbgate/README.md`

## Port Allocations

Tools use ports **3500-3599**:

| Port | Tool    |
|------|---------|
| 3500 | DbGate  |

## Common Operations

### Start a Tool
```bash
cd tools/<tool-name>
docker-compose up -d
```

### Stop a Tool
```bash
cd tools/<tool-name>
docker-compose down
```

### View Logs
```bash
cd tools/<tool-name>
docker-compose logs -f
```

### Update a Tool
```bash
cd tools/<tool-name>
docker-compose pull
docker-compose up -d
```

## Adding New Tools

1. Create directory: `tools/tool-name/`
2. Add `docker-compose.yml`
3. Add `README.md` with usage instructions
4. Use ports 3500-3599
5. Update this guide

**Example Structure:**
```
tools/
├── tool-name/
│   ├── docker-compose.yml
│   ├── README.md
│   └── config/
```

## Best Practices

1. **Separate from Production** - Tools are not dependencies
2. **Read-Only by Default** - Mount databases as `:ro`
3. **Local Access Only** - No external exposure unless needed
4. **Document Everything** - Clear README for each tool
5. **Regular Updates** - Keep images updated
6. **Resource Limits** - Set limits if needed

## Troubleshooting

### Port Already in Use
```bash
sudo netstat -tlnp | grep <port>
# Kill process or change port in docker-compose.yml
```

### Can't Connect to Database
```bash
# Verify mount
docker exec <container-name> ls -la /path
```

### Permission Issues
```bash
# Check permissions
ls -la /path/to/mounted/directory
```

### Container Won't Start
```bash
# Check logs
docker logs <container-name>
```

## Related Documentation

- [Sites Guide](sites-guide.md) - Deploying websites
- [APIs Guide](apis-guide.md) - Deploying APIs  
- [LGTM Testing Guide](lgtm-testing-guide.md) - Monitoring stack
