#!/bin/bash
echo "🔄 Updating GENTLEMAN Homelab..."

# Pull latest images
docker-compose -f docker-compose.homelab.yml pull

# Restart services with new images
docker-compose -f docker-compose.homelab.yml up -d

echo "✅ GENTLEMAN Homelab updated!"
