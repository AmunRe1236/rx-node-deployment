#!/bin/bash
echo "🎩 Starting GENTLEMAN Homelab..."

# Load environment
set -a
source .env.homelab
set +a

# Start core services first
echo "Starting core infrastructure..."
docker-compose -f docker-compose.homelab.yml up -d \
    gitea-db gitea \
    nextcloud-db nextcloud \
    mosquitto \
    prometheus grafana loki \
    traefik

# Wait for core services
sleep 30

# Start application services
echo "Starting application services..."
docker-compose -f docker-compose.homelab.yml up -d \
    homeassistant \
    protonmail-bridge \
    pihole \
    vaultwarden \
    jellyfin \
    truenas-sync \
    homelab-bridge

# Start monitoring and maintenance
echo "Starting monitoring services..."
docker-compose -f docker-compose.homelab.yml up -d \
    watchtower \
    healthchecks

echo "✅ GENTLEMAN Homelab started!"
echo ""
echo "🌐 Access your services:"
echo "  Git Server:      http://git.gentleman.local:3000"
echo "  Nextcloud:       http://cloud.gentleman.local:8080"
echo "  Home Assistant:  http://ha.gentleman.local:8123"
echo "  Media Server:    http://media.gentleman.local:8096"
echo "  Password Manager: http://vault.gentleman.local:8082"
echo "  DNS Admin:       http://dns.gentleman.local:8081"
echo "  Monitoring:      http://localhost:3001"
echo "  Proxy Dashboard: http://proxy.gentleman.local:8083"
echo ""
