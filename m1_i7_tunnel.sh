#!/bin/bash
# 🚇 SSH Port Forwarding zu i7 Node - M1 Mac Script
# Ermöglicht HTTP Zugriff auf i7 Node via SSH Tunnel

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🚇 M1 MAC → I7 NODE SSH TUNNEL                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"

echo "📡 SSH Port Forwarding zu i7 Node"
echo "🔗 Lokaler Port: 8105 → i7 Node Port: 8008"
echo "📋 Nach dem Start verfügbar: curl http://localhost:8105/status"
echo ""

# Prüfe ob Port bereits verwendet wird
if lsof -i :8105 >/dev/null 2>&1; then
    echo "⚠️ Port 8105 bereits in Verwendung, stoppe bestehende Verbindung..."
    pkill -f "ssh.*8105:localhost:8008"
    sleep 2
fi

echo "🚀 Starte SSH Tunnel..."
echo "💡 Zum Beenden: Ctrl+C"
echo ""

# SSH Tunnel mit Port Forwarding
ssh -i ~/.ssh/gentleman_key -L 8105:localhost:8008 -N amonbaumgartner@192.168.68.105 