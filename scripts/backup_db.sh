#!/bin/bash
# ==============================================================================
# Database & Media Automated Backup Script for Ubuntu
# ==============================================================================

set -e

BACKUP_DIR="${BACKUP_DIR:-/var/backups/creator_platform}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MYSQL_CONTAINER="creator_mysql"
DB_NAME="${MYSQL_DATABASE:-creator_platform}"
DB_USER="${MYSQL_USER:-creator_user}"
DB_PASS="${MYSQL_PASSWORD:-creator_pass@2026}"
RETENTION_DAYS=14

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting MySQL backup from container '$MYSQL_CONTAINER'..."

# Export compressed MySQL dump
docker exec "$MYSQL_CONTAINER" mysqldump -u"$DB_USER" -p"$DB_PASS" --single-transaction --quick --routines "$DB_NAME" | gzip > "$BACKUP_DIR/db_${DB_NAME}_${TIMESTAMP}.sql.gz"

# Also snapshot SQLite DB if present
if [ -f "backend/data/creator_platform.db" ]; then
    echo "[$(date)] Snapshotting SQLite database file..."
    cp backend/data/creator_platform.db "$BACKUP_DIR/sqlite_${TIMESTAMP}.db"
    gzip "$BACKUP_DIR/sqlite_${TIMESTAMP}.db"
fi

# Prune older backups beyond retention window
find "$BACKUP_DIR" -type f -name "*.gz" -mtime +$RETENTION_DAYS -delete

echo "[$(date)] Backup completed successfully: $BACKUP_DIR/db_${DB_NAME}_${TIMESTAMP}.sql.gz"

