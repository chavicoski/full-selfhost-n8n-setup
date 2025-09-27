#!/bin/bash

# ==============================================================================
# N8N AI STACK DATABASE BACKUP SCRIPT
# ==============================================================================
#
# PURPOSE:
#   Creates compressed backups of the n8n PostgreSQL database with automatic
#   retention management and error handling.
#
# REQUIREMENTS:
#   - Docker and Docker Compose running
#   - PostgreSQL container must be healthy
#   - Write permissions to backup directory
#
# CONFIGURATION:
#   Environment variables (from .env file):
#   - COMPOSE_PROJECT_NAME: Container name prefix (default: n8n-ai-stack)
#   - POSTGRES_DB: Database name (default: n8n)
#   - POSTGRES_USER: Database user (default: postgres)
#
# USAGE:
#   ./scripts/backup.sh
#
# EXAMPLES:
#   # Basic backup
#   ./scripts/backup.sh
#
#   # Backup with custom environment
#   COMPOSE_PROJECT_NAME=my-n8n ./scripts/backup.sh
#
# OUTPUT:
#   - Backup file: ./backups/n8n_backup_YYYYMMDD_HHMMSS.sql.gz
#   - Automatic cleanup: Removes backups older than 7 days
#
# EXIT CODES:
#   0: Success
#   1: Error (container not running, backup failed, etc.)
#
# ==============================================================================

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# Set defaults
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-n8n-ai-stack}
POSTGRES_DB=${POSTGRES_DB:-n8n}
POSTGRES_USER=${POSTGRES_USER:-postgres}
BACKUP_DIR="${N8N_BACKUPS_PATH:-./backups}"

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