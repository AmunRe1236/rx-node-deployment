#!/bin/bash
# Check status of all nodes in offline-compatible mode

echo "🌐 GENTLEMAN Multi-Node Status (Offline-kompatibel)"
echo "=================================================="

# Current node info
CURRENT_IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
echo "📍 Aktueller Node: $(hostname) ($CURRENT_IP)"

# Check each node
echo ""
echo "🔍 Node Status:"

# i7 Node
if [ "$CURRENT_IP" = "192.168.68.105" ]; then
    echo "✅ i7 Node (192.168.68.105): LOKAL - ONLINE"
else
    ping -c 1 -W 1 192.168.68.105 >/dev/null 2>&1 && echo "✅ i7 Node (192.168.68.105): ONLINE" || echo "❌ i7 Node (192.168.68.105): OFFLINE"
fi

# RX Node
if [ "$CURRENT_IP" = "192.168.68.117" ]; then
    echo "✅ RX Node (192.168.68.117): LOKAL - ONLINE"
else
    ping -c 1 -W 1 192.168.68.117 >/dev/null 2>&1 && echo "✅ RX Node (192.168.68.117): ONLINE" || echo "❌ RX Node (192.168.68.117): OFFLINE"
fi

# M1 Mac
if [ "$CURRENT_IP" = "192.168.68.111" ]; then
    echo "✅ M1 Mac (192.168.68.111): LOKAL - ONLINE"
else
    ping -c 1 -W 1 192.168.68.111 >/dev/null 2>&1 && echo "✅ M1 Mac (192.168.68.111): ONLINE" || echo "❌ M1 Mac (192.168.68.111): OFFLINE"
fi

echo ""
echo "🎩 GENTLEMAN Protocol Status:"
curl -s --connect-timeout 3 http://localhost:8008/status >/dev/null 2>&1 && echo "✅ GENTLEMAN Protocol: AKTIV" || echo "❌ GENTLEMAN Protocol: INAKTIV"

echo ""
echo "💡 Offline-Modus: Aktiviert für isolierte Node-Operation"
