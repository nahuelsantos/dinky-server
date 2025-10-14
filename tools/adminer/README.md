# Adminer - Database Management Tool

Lightweight database administration tool with support for SQLite, MySQL, PostgreSQL, and more. **ARM64 compatible** for Raspberry Pi.

## Quick Start

```bash
cd tools/adminer
docker-compose up -d
```

**Access**: http://192.168.1.129:3500 or http://dinky:3500

### Connect to The Game Database

1. Open Adminer in your browser
2. Select **"SQLite 3"** from the System dropdown
3. **Server**: Leave empty
4. **Username**: Leave empty
5. **Password**: Leave empty
6. **Database**: `/data/game.db`
7. Click **"Login"**

### Stop Adminer

```bash
cd tools/adminer
docker-compose down
```

## Features

- Simple, lightweight interface
- SQL query editor with syntax highlighting
- Table browsing and editing
- Export data (SQL, CSV)
- Schema visualization
- Multi-database support (SQLite, MySQL, PostgreSQL, etc.)
- **ARM64/Raspberry Pi compatible**

## Useful Queries for The Game

### Top Players
```sql
SELECT username, score, wins, losses 
FROM users 
ORDER BY score DESC 
LIMIT 10;
```

### Recent Activity (Last 7 Days)
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
    wins,
    losses,
    ROUND(CAST(wins AS FLOAT) / NULLIF(wins + losses, 0) * 100, 2) as win_rate
FROM users
WHERE wins + losses > 0
ORDER BY score DESC;
```

### Badge Distribution
```sql
SELECT 
    b.name as badge_name,
    b.rarity,
    COUNT(ub.user_id) as earned_count
FROM badges b
LEFT JOIN user_badges ub ON b.id = ub.badge_id
GROUP BY b.id
ORDER BY earned_count DESC;
```

## Configuration

- **Port**: 3500
- **Database Access**: Read-only (connected via Docker volume)
- **Multi-arch**: Supports both AMD64 and ARM64

### How It Works

Adminer accesses The Game database through Docker's named volume:

```yaml
volumes:
  - the-game-data:/data:ro  # Read-only access to The Game's volume
```

The volume name must match The Game's volume. To verify:
```bash
docker volume ls | grep the-game
```

## Security Notes

- Database mounted as read-only for safety
- Only accessible on local network
- No authentication required (protected by network isolation)
- Consider adding Traefik authentication if exposing externally

## Troubleshooting

### Can't access port 3500?
```bash
sudo netstat -tlnp | grep 3500
```

### Database not visible?
```bash
docker exec adminer ls -la /data
```

### Update Adminer
```bash
docker-compose pull && docker-compose up -d
```

### Check logs
```bash
docker logs adminer
```

## Why Adminer Instead of DbGate?

- ✅ **ARM64 compatible** - Works on Raspberry Pi
- ✅ **Lightweight** - Single PHP file, minimal resources
- ✅ **Stable** - Mature, well-maintained project
- ✅ **Multi-database** - Supports SQLite, MySQL, PostgreSQL, and more
- ✅ **Simple** - No complex setup required

DbGate has ARM64 compatibility issues with its SQLite plugin, making it unsuitable for Raspberry Pi deployments.

## Related Docs

- [Tools Guide](../../docs/tools-guide.md) - Managing admin tools
- [Main README](../../README.md) - Dinky Server overview
