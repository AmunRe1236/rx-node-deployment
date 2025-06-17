#!/bin/bash
echo "🛑 Stopping GENTLEMAN Homelab..."

docker-compose -f docker-compose.homelab.yml down

echo "✅ GENTLEMAN Homelab stopped!"
