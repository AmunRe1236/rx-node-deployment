#!/bin/bash

echo "📱 GENTLEMAN M1 Mobile Access Test"
echo "=================================="
echo ""

# Öffentliche IP ermitteln
PUBLIC_IP=$(curl -s ifconfig.me)
echo "🌐 Öffentliche IP: $PUBLIC_IP"
echo ""

# Router/Gateway ermitteln
GATEWAY=$(route -n get default | grep gateway | awk '{print $2}')
echo "🔧 Router Gateway: $GATEWAY"
echo ""

# Teste lokale Services
echo "🔍 Lokale Service Tests:"
echo "- Handshake Server (8765): $(nc -z localhost 8765 && echo '✅ OK' || echo '❌ FAIL')"
echo "- Git Daemon (9418): $(nc -z localhost 9418 && echo '✅ OK' || echo '❌ FAIL')" 
echo "- Gitea Docker (3010): $(nc -z localhost 3010 && echo '✅ OK' || echo '❌ FAIL')"
echo ""

# UPnP Prüfung
echo "🔌 UPnP Status:"
if command -v upnpc >/dev/null 2>&1; then
    upnpc -l 2>/dev/null | head -10
else
    echo "❌ UPnP Client nicht installiert (brew install miniupnpc)"
fi
echo ""

# Mobile Access Empfehlungen
echo "📋 Mobile Access Setup Optionen:"
echo ""
echo "Option 1: Router Port-Forwarding"
echo "  - Router Admin Panel öffnen ($GATEWAY)"
echo "  - Port 8765 → 192.168.68.105:8765 (Handshake)"
echo "  - Port 9418 → 192.168.68.105:9418 (Git)"
echo "  - Port 3010 → 192.168.68.105:3010 (Gitea)"
echo ""
echo "Option 2: ngrok Tunnel (Schnell-Test)"
echo "  - brew install ngrok"
echo "  - ngrok http 8765 (für Handshake Service)"
echo ""
echo "Option 3: Tailscale VPN (Empfohlen)"
echo "  - brew install tailscale"
echo "  - Sichere Peer-to-Peer Verbindung"
echo ""

# Test von extern simulieren
echo "🎯 Simuliere externe Verbindung:"
echo "curl -m 5 http://$PUBLIC_IP:8765/health 2>/dev/null || echo 'Extern nicht erreichbar - Port-Forwarding benötigt'"

# Mobile Client Test URL generieren
echo ""
echo "📲 Mobile Test URLs (nach Port-Forwarding):"
echo "- Handshake: http://$PUBLIC_IP:8765/health"
echo "- Gitea: http://$PUBLIC_IP:3010"
echo "- Git Clone: git://$PUBLIC_IP:9418/Gentleman" 