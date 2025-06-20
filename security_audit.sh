#!/bin/bash

echo "🔒 GENTLEMAN Security Audit"
echo "=========================="

echo "SSH-Key Permissions:"
ls -la ~/.ssh/gentleman_secure*

echo -e "\nSSH-Konfiguration:"
cat ~/.ssh/config | grep -A 10 "rx-node"

echo -e "\nRX Node offene Ports:"
ssh rx-node "netstat -tlnp 2>/dev/null | grep LISTEN" || echo "SSH-Verbindung fehlgeschlagen"

echo -e "\nLaufende Tunnel-Services:"
ssh rx-node "ps aux | grep -E '(cloudflared|python.*tunnel)' | grep -v grep" || echo "SSH-Verbindung fehlgeschlagen"
