#!/usr/bin/env bash
#
# Restore VPN from backup
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

BACKUP_FILE="${1:-}"

if [ -z "$BACKUP_FILE" ]; then
    # Find latest backup
    BACKUP_FILE=$(ls -t "${PROJECT_DIR}"/backup_*.tar.gz 2>/dev/null | head -1)
    if [ -z "$BACKUP_FILE" ]; then
        echo "Usage: $0 <backup_file.tar.gz>"
        echo "No backup files found in project directory"
        exit 1
    fi
    echo "Using latest backup: $BACKUP_FILE"
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "Restoring from: $BACKUP_FILE"
read -p "This will overwrite current config. Continue? [y/N] " confirm
if [ "${confirm}" != "y" ] && [ "${confirm}" != "Y" ]; then
    echo "Cancelled"
    exit 0
fi

cd "$PROJECT_DIR"
tar -xzf "$BACKUP_FILE"

# Restore Marzban data if present
if [ -d "${PROJECT_DIR}/.marzban_data" ]; then
    echo "  Restoring Marzban data to /var/lib/marzban..."
    mkdir -p /var/lib/marzban
    cp -r "${PROJECT_DIR}/.marzban_data/"* /var/lib/marzban/
    rm -rf "${PROJECT_DIR}/.marzban_data"
fi

echo ""
echo "  Restore complete!"
echo ""
echo "  Start the server: make up"
echo "  (or: make up MARZBAN=1)"
echo ""
