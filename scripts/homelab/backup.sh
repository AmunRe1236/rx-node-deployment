#!/bin/bash
echo "💾 Backing up GENTLEMAN Homelab..."

BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup configurations
cp -r config "$BACKUP_DIR/"
cp .env.homelab "$BACKUP_DIR/"
cp docker-compose.homelab.yml "$BACKUP_DIR/"

# Backup Docker volumes
docker run --rm -v gentleman-homelab_gitea-data:/data -v "$PWD/$BACKUP_DIR":/backup alpine tar czf /backup/gitea-data.tar.gz -C /data .
docker run --rm -v gentleman-homelab_nextcloud-data:/data -v "$PWD/$BACKUP_DIR":/backup alpine tar czf /backup/nextcloud-data.tar.gz -C /data .
docker run --rm -v gentleman-homelab_homeassistant-config:/data -v "$PWD/$BACKUP_DIR":/backup alpine tar czf /backup/homeassistant-config.tar.gz -C /data .
docker run --rm -v gentleman-homelab_vaultwarden-data:/data -v "$PWD/$BACKUP_DIR":/backup alpine tar czf /backup/vaultwarden-data.tar.gz -C /data .

echo "✅ Backup completed: $BACKUP_DIR"
