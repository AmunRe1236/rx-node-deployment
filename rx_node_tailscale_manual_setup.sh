#!/bin/bash

# GENTLEMAN RX Node Tailscale Manual Setup
# Zeigt die Befehle an, die auf der RX Node ausgeführt werden müssen

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktion
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "${BLUE}🕸️ GENTLEMAN RX Node Tailscale Manual Setup${NC}"
log "${BLUE}===========================================${NC}"

log "${YELLOW}📋 Führe folgende Schritte aus:${NC}"
echo ""

log "${BLUE}1. SSH zur RX Node:${NC}"
echo "   ssh rx-node"
echo ""

log "${BLUE}2. Installiere Tailscale auf der RX Node:${NC}"
echo "   sudo pacman -Sy"
echo "   sudo pacman -S tailscale"
echo "   sudo systemctl enable tailscaled"
echo "   sudo systemctl start tailscaled"
echo ""

log "${BLUE}3. Generiere Auth-Key:${NC}"
echo "   Öffne: https://login.tailscale.com/admin/settings/keys"
echo "   Klicke 'Generate auth key'"
echo "   Aktiviere 'Reusable' (optional)"
echo "   Kopiere den generierten Key"
echo ""

log "${BLUE}4. Verbinde RX Node mit Tailscale:${NC}"
echo "   sudo tailscale up --authkey='DEIN_AUTH_KEY' --hostname='rx-node-archlinux'"
echo ""

log "${BLUE}5. Überprüfe Status:${NC}"
echo "   tailscale status"
echo "   tailscale ip -4"
echo ""

log "${YELLOW}🔄 Nach der Installation auf der RX Node:${NC}"
echo ""

# Erstelle Verification Script
cat > verify_rx_tailscale.sh << 'EOF'
#!/bin/bash

# Verification Script für RX Node Tailscale Setup

echo "🔍 Überprüfe RX Node Tailscale-Integration..."

# Hole RX Node Tailscale IP
RX_IP=$(ssh rx-node "tailscale ip -4" 2>/dev/null)

if [ -n "$RX_IP" ]; then
    echo "✅ RX Node Tailscale IP: $RX_IP"
    
    # Teste Ping
    if ping -c 1 -W 3 "$RX_IP" >/dev/null 2>&1; then
        echo "✅ Ping zur RX Node über Tailscale erfolgreich"
    else
        echo "⚠️ Ping zur RX Node über Tailscale fehlgeschlagen"
    fi
    
    # Aktualisiere SSH Config
    if ! grep -q "Host rx-node-tailscale" ~/.ssh/config 2>/dev/null; then
        cat >> ~/.ssh/config << EOL

# RX Node via Tailscale
Host rx-node-tailscale
    HostName $RX_IP
    User amo9n11
    IdentityFile ~/.ssh/gentleman_secure
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOL
        echo "✅ SSH-Konfiguration für Tailscale hinzugefügt"
    fi
    
    # Zeige aktuellen Tailscale Status
    echo ""
    echo "📊 Aktueller Tailscale-Status:"
    tailscale status
    
    echo ""
    echo "🎉 RX Node erfolgreich im Tailscale Mesh integriert!"
    echo "📱 Die RX Node sollte jetzt in deiner Tailscale-App sichtbar sein"
    
else
    echo "❌ RX Node Tailscale IP nicht gefunden"
    echo "💡 Stelle sicher, dass Tailscale auf der RX Node korrekt installiert ist"
fi
EOF

chmod +x verify_rx_tailscale.sh

log "${GREEN}6. Führe Verification aus:${NC}"
echo "   ./verify_rx_tailscale.sh"
echo ""

log "${YELLOW}💡 Tipp: Du kannst auch direkt SSH zur RX Node machen:${NC}"
echo "   ssh rx-node"
echo "   Dann die Befehle direkt dort ausführen"
echo ""

log "${BLUE}📋 Verification Script erstellt: verify_rx_tailscale.sh${NC}" 