#!/bin/sh
# ═══════════════════════════════════════════════════════════
# BACKUP SCRIPT — MinIO
# Запускается каждые 6 часов через cron
# ═══════════════════════════════════════════════════════════

set -e

MINIO_URL="${MINIO_URL:-http://minio:9000}"
MINIO_USER="${MINIO_USER:-minioadmin}"
MINIO_PASS="${MINIO_PASS:-MinioSecure123!}"
DATE=$(date +%Y%m%d_%H%M%S)
HOSTNAME=$(cat /etc/hostname 2>/dev/null || echo "backup-container")

echo "[$(date)] Starting backup process..."

# Настройка MinIO client
mc alias set local "$MINIO_URL" "$MINIO_USER" "$MINIO_PASS" --quiet

# ─────────────────────────────────────
# Бэкап Wazuh логов
# ─────────────────────────────────────
if [ -d "/backup/wazuh-logs" ]; then
    echo "[$(date)] Backing up Wazuh logs..."
    mc mirror --overwrite /backup/wazuh-logs "local/wazuh-backups/${DATE}/" --quiet
    echo "[$(date)] Wazuh logs backup completed"
fi

# ─────────────────────────────────────
# Бэкап Samba данных
# ─────────────────────────────────────
if [ -d "/backup/samba" ]; then
    echo "[$(date)] Backing up Samba AD data..."
    mc mirror --overwrite /backup/samba "local/samba-backups/${DATE}/" --quiet
    echo "[$(date)] Samba backup completed"
fi

# ─────────────────────────────────────
# Проверка целостности бэкапов
# ─────────────────────────────────────
echo "[$(date)] Verifying backups..."
mc ls "local/wazuh-backups/${DATE}/" --quiet && echo "[$(date)] Wazuh backup verified OK"
mc ls "local/samba-backups/${DATE}/" --quiet && echo "[$(date)] Samba backup verified OK"

# ─────────────────────────────────────
# Очистка старых бэкапов (старше 90 дней)
# ─────────────────────────────────────
echo "[$(date)] Cleaning old backups..."
CUTOFF_DATE=$(date -d "90 days ago" +%Y%m%d 2>/dev/null || date -v-90d +%Y%m%d)

mc ls local/wazuh-backups/ --quiet | while read -r line; do
    BACKUP_DATE=$(echo "$line" | awk '{print $NF}' | cut -d'_' -f1)
    if [ "$BACKUP_DATE" -lt "$CUTOFF_DATE" ] 2>/dev/null; then
        BACKUP_NAME=$(echo "$line" | awk '{print $NF}')
        mc rm --recursive --force "local/wazuh-backups/${BACKUP_NAME}" --quiet
        echo "[$(date)] Removed old backup: ${BACKUP_NAME}"
    fi
done

echo "[$(date)] Backup process completed successfully"

# ─────────────────────────────────────
# Ждём следующего запуска (6 часов)
# ─────────────────────────────────────
echo "[$(date)] Next backup in 6 hours..."
sleep 21600
exec "$0"
