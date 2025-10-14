# DbGate - Database Management Tool

Modern web-based database administration tool with support for SQLite and other databases.

## Quick Start

```bash
cd tools/dbgate
docker-compose up -d
```

**Access**: http://192.168.1.129:3500 or http://dinky:3500

### Connect to The Game Database

1. Click **"New Connection"** → Select **"SQLite"**
2. Database File: `/the-game/game.db`
3. Click **"Test Connection"** → **"Save"**

### Stop DbGate

```bash
cd tools/dbgate
docker-compose down
```

## Features

- Modern, intuitive web UI
- SQL editor with syntax highlighting and autocomplete
- Visual query builder
- Schema explorer with ER diagrams
- Import/Export (CSV, JSON, Excel)
- Inline table editing
- Query history and data visualization

## Useful Queries for The Game

### Top Players
```sql
SELECT username, score, wins, losses 
FROM users 
ORDER BY score DESC 
LIMIT 10;
```

### Recent Activity
```sql
SELECT event_type, COUNT(*) as count
FROM analytics
WHERE created_at > datetime('now', '-7 days')
GROUP BY event_type;
```

### User Win Rate
```sql
SELECT 
    username,
    score,
    ROUND(CAST(wins AS FLOAT) / NULLIF(wins + losses, 0) * 100, 2) as win_rate
FROM users
WHERE wins + losses > 0
ORDER BY score DESC;
```

## Configuration

- **Port**: 3500
- **Volume**: `dbgate-data` (stores connections and settings)
- **Database Access**: Read-only by default (`:ro`)

### Mounting Additional Databases

Edit `docker-compose.yml`:

```yaml
volumes:
  - /Users/nahuelsantos/Workspace/nahuelsantos/the-game/data:/the-game:ro
  - /path/to/your/database:/db-name:ro  # Add your databases here
```

Then restart: `docker-compose down && docker-compose up -d`

## Security Notes

- Databases mounted as read-only for safety
- Only accessible on local network
- No authentication by default
- Consider adding auth if exposing externally

## Troubleshooting

**Port in use?**
```bash
sudo netstat -tlnp | grep 3500
```

**Can't see database files?**
```bash
docker exec dbgate ls -la /the-game
```

**Update DbGate:**
```bash
docker-compose pull && docker-compose up -d
```

## Related Docs

- [The Game Database Guide](../../sites/the-game/DATABASE_ACCESS.md) - Specific queries and schema
- [Tools Guide](../../docs/tools-guide.md) - Managing admin tools
