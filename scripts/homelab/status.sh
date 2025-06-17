#!/bin/bash
echo "🎩 GENTLEMAN Homelab Status"
echo "═══════════════════════════════════════════════════════════════"

docker-compose -f docker-compose.homelab.yml ps

echo ""
echo "🌐 Service URLs:"
echo "  Git Server:      http://git.gentleman.local:3000"
echo "  Nextcloud:       http://cloud.gentleman.local:8080"
echo "  Home Assistant:  http://ha.gentleman.local:8123"
echo "  Media Server:    http://media.gentleman.local:8096"
echo "  Password Manager: http://vault.gentleman.local:8082"
echo "  DNS Admin:       http://dns.gentleman.local:8081"
echo "  Monitoring:      http://localhost:3001"
echo "  Proxy Dashboard: http://proxy.gentleman.local:8083"
echo "  Health Monitor:  http://health.gentleman.local:8084"
echo "  Homelab Bridge:  http://bridge.gentleman.local:8090"
