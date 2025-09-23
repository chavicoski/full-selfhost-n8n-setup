#!/bin/bash

# N8N PostgreSQL Backup Script
# This script creates a backup of the n8n database

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# Set defaults
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-n8n-ai-stack}
POSTGRES_DB=${POSTGRES_DB:-n8n}
POSTGRES_USER=${POSTGRES_USER:-postgres}
BACKUP_DIR="./backups"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/n8n_backup_$TIMESTAMP.sql"

echo "Creating backup of n8n database..."
echo "Backup file: $BACKUP_FILE"

# Create database backup
docker exec "${COMPOSE_PROJECT_NAME}_postgres" pg_dump \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    --verbose \
    --no-password > "$BACKUP_FILE"

# Compress the backup
gzip "$BACKUP_FILE"
BACKUP_FILE="$BACKUP_FILE.gz"

echo "Backup completed successfully!"
echo "Backup saved to: $BACKUP_FILE"
echo "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"

# Optional: Clean up old backups (keep last 7 days)
find "$BACKUP_DIR" -name "n8n_backup_*.sql.gz" -mtime +7 -delete 2>/dev/null || true

echo "Backup process finished."