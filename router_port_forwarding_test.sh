#!/bin/bash

echo "🔧 GENTLEMAN Router Port-Forwarding Diagnose"
echo "============================================="
echo ""

# Aktuelle Konfiguration
PUBLIC_IP=$(curl -s ifconfig.me)
GATEWAY=$(route -n get default | grep gateway | awk '{print $2}')
LOCAL_IP="192.168.68.105"

echo "📊 Aktuelle Netzwerk-Konfiguration:"
echo "- M1 Mac lokale IP: $LOCAL_IP"
echo "- Router Gateway: $GATEWAY" 
echo "- Öffentliche IP: $PUBLIC_IP"
echo ""

# Lokale Service Tests
echo "🔍 Lokale Service Tests:"
echo "------------------------"
for port in 8765 3010 9418; do
    echo -n "Port $port: "
    if nc -z localhost $port 2>/dev/null; then
        echo "✅ LÄUFT"
    else
        echo "❌ OFFLINE"
    fi
done
echo ""

# Interne Netzwerk Tests
echo "🌐 Interne Netzwerk Tests (von M1 Mac):"
echo "---------------------------------------"
for port in 8765 3010 9418; do
    echo -n "Port $port über $LOCAL_IP: "
    if nc -z $LOCAL_IP $port 2>/dev/null; then
        echo "✅ ERREICHBAR"
    else
        echo "❌ BLOCKIERT"
    fi
done
echo ""

# Externe Tests
echo "🌍 Externe Tests (öffentliche IP):"
echo "----------------------------------"
for port in 8765 3010 9418; do
    echo -n "Port $port über $PUBLIC_IP: "
    timeout 3 nc -z $PUBLIC_IP $port 2>/dev/null && echo "✅ ERREICHBAR" || echo "❌ BLOCKIERT"
done
echo ""

# Router Konfiguration Checkliste
echo "✅ Router Port-Forwarding Checkliste:"
echo "====================================="
echo "1. Router Admin Panel: http://$GATEWAY"
echo "2. Benötigte Weiterleitungen:"
echo "   - Port 8765 TCP → $LOCAL_IP:8765 (Handshake)"
echo "   - Port 3010 TCP → $LOCAL_IP:3010 (Gitea)" 
echo "   - Port 9418 TCP → $LOCAL_IP:9418 (Git)"
echo ""
echo "3. Überprüfung:"
echo "   - Zielsystem IP: $LOCAL_IP ✓"
echo "   - Protokoll: TCP ✓"
echo "   - Status: AKTIVIERT ?"
echo ""

# Schnelle Router-Tests
echo "🔧 Router Diagnose:"
echo "==================="
echo "Ping zum Router..."
if ping -c 2 $GATEWAY >/dev/null 2>&1; then
    echo "✅ Router erreichbar"
else
    echo "❌ Router nicht erreichbar"
fi

echo ""
echo "Router Admin Interface Test..."
if curl -m 3 -s http://$GATEWAY >/dev/null 2>&1; then
    echo "✅ Router Web Interface erreichbar"
    echo "🌐 Öffne: http://$GATEWAY"
else
    echo "❌ Router Web Interface nicht erreichbar"
fi

echo ""
echo "📋 NÄCHSTE SCHRITTE:"
echo "==================="
echo "1. Router Admin Panel öffnen: http://$GATEWAY"
echo "2. Suche nach: 'Port Forwarding', 'Virtual Server' oder 'NAT'"
echo "3. Konfiguriere die drei Ports wie oben angegeben"
echo "4. Aktiviere die Regeln"
echo "5. Führe diesen Test erneut aus: ./router_port_forwarding_test.sh"
echo ""
echo "🎯 Nach erfolgreicher Konfiguration sind diese URLs aktiv:"
echo "- Mobile Handshake: http://$PUBLIC_IP:8765/health"
echo "- Gitea Web UI: http://$PUBLIC_IP:3010"
echo "- Git Repository: git://$PUBLIC_IP:9418/Gentleman" 