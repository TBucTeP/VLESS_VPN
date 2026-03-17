#!/usr/bin/env bash
#
# Backup VPN config, keys, and client data
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${PROJECT_DIR}/backup_${TIMESTAMP}.tar.gz"

echo "Creating backup..."

FILES_TO_BACKUP=""

# Standalone files
[ -d "${PROJECT_DIR}/config" ] && FILES_TO_BACKUP="$FILES_TO_BACKUP config"
[ -d "${PROJECT_DIR}/output" ] && FILES_TO_BACKUP="$FILES_TO_BACKUP output"
[ -f "${PROJECT_DIR}/.env" ] && FILES_TO_BACKUP="$FILES_TO_BACKUP .env"
[ -f "${PROJECT_DIR}/xray_config.json" ] && FILES_TO_BACKUP="$FILES_TO_BACKUP xray_config.json"

# Marzban data
if [ -d "/var/lib/marzban" ]; then
    echo "  Including Marzban data (/var/lib/marzban)..."
    MARZBAN_BACKUP="${PROJECT_DIR}/.marzban_data"
    rm -rf "$MARZBAN_BACKUP"
    cp -r /var/lib/marzban "$MARZBAN_BACKUP"
    FILES_TO_BACKUP="$FILES_TO_BACKUP .marzban_data"
fi

if [ -z "$FILES_TO_BACKUP" ]; then
    echo "Nothing to backup"
    exit 1
fi

cd "$PROJECT_DIR"
tar -czf "$BACKUP_FILE" $FILES_TO_BACKUP
rm -rf "${PROJECT_DIR}/.marzban_data" 2>/dev/null || true

SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo ""
echo "  Backup created: $BACKUP_FILE ($SIZE)"
echo ""
echo "  Copy to local machine:"
echo "  scp root@server:${BACKUP_FILE} ."
echo ""
