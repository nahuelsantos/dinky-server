# SQLite Web

A lightweight web-based SQLite database browser.

## Quick Start

```bash
docker-compose up -d
```

Access the web interface at [http://dinky:3500](http://dinky:3500).

## Configuration

The `docker-compose.yml` is configured to connect to `the-game`'s SQLite database.

### Database Volume

The volume `../../the-game/data` is mounted to `/db` inside the container. This path assumes that `the-game` and `dinky-server` repositories are cloned into the same parent directory.

- **Host Path**: `../the-game/data`
- **Container Path**: `/db`

The `sqlite-web` command in the `docker-compose.yml` specifies the database file to open, e.g., `/db/game.db`.
