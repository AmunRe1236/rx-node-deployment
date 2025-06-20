#!/usr/bin/env bash

# GENTLEMAN M1 Mac Central Hub Setup
# Komplettes Setup für den M1 Mac als zentraler Knoten des Mesh-Netzwerks

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging-Funktion
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Header
clear
log "${PURPLE}🖥️ GENTLEMAN M1 MAC CENTRAL HUB SETUP${NC}"
log "${PURPLE}====================================${NC}"
echo ""

# Überprüfe ob wir auf einem M1 Mac sind
if [[ $(uname -m) != "arm64" ]] || [[ $(uname) != "Darwin" ]]; then
    log "${RED}❌ Dieses Script ist nur für M1 Macs gedacht${NC}"
    exit 1
fi

log "${GREEN}✅ M1 Mac erkannt - Setup wird gestartet${NC}"
echo ""

# 1. Repository Setup
log "${BLUE}📦 1. Repository Setup${NC}"
if [ ! -d ".git" ]; then
    log "${YELLOW}🔄 Klone GENTLEMAN Repository...${NC}"
    cd ..
    git clone https://github.com/AmunRe1236/rx-node-deployment.git Gentleman
    cd Gentleman
else
    log "${GREEN}✅ Repository bereits vorhanden${NC}"
    log "${YELLOW}🔄 Aktualisiere Repository...${NC}"
    git pull origin master
fi
echo ""

# 2. Python Dependencies
log "${BLUE}📦 2. Python Dependencies${NC}"
log "${YELLOW}🔄 Installiere Python Dependencies...${NC}"

# Überprüfe Python 3
if ! command -v python3 >/dev/null 2>&1; then
    log "${RED}❌ Python 3 nicht gefunden${NC}"
    log "${YELLOW}💡 Installiere Python 3 über Homebrew...${NC}"
    if ! command -v brew >/dev/null 2>&1; then
        log "${YELLOW}🍺 Installiere Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install python3
fi

# Installiere Python Packages
pip3 install --user flask requests psutil wakeonlan jq || log "${YELLOW}⚠️ Einige Python Packages konnten nicht installiert werden${NC}"
echo ""

# 3. Homebrew Tools
log "${BLUE}📦 3. Homebrew Tools${NC}"
if ! command -v brew >/dev/null 2>&1; then
    log "${YELLOW}🍺 Installiere Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

log "${YELLOW}🔄 Installiere erforderliche Tools...${NC}"
brew install jq curl wget cloudflared tailscale || log "${YELLOW}⚠️ Einige Tools konnten nicht installiert werden${NC}"
echo ""

# 4. Tailscale Setup
log "${BLUE}🕸️ 4. Tailscale Setup${NC}"
if ! command -v tailscale >/dev/null 2>&1; then
    log "${YELLOW}📦 Installiere Tailscale...${NC}"
    brew install tailscale
fi

# Überprüfe Tailscale Status
if ! tailscale status >/dev/null 2>&1; then
    log "${YELLOW}🔗 Tailscale Setup erforderlich${NC}"
    log "${BLUE}📋 Öffne https://login.tailscale.com/admin/settings/keys${NC}"
    echo ""
    read -p "Generiere einen Auth-Key und füge ihn hier ein: " AUTH_KEY
    
    if [ -n "$AUTH_KEY" ]; then
        sudo tailscale up --authkey="$AUTH_KEY" --hostname="m1-mac-central-hub"
        log "${GREEN}✅ Tailscale konfiguriert${NC}"
    else
        log "${RED}❌ Kein Auth-Key eingegeben${NC}"
    fi
else
    log "${GREEN}✅ Tailscale bereits konfiguriert${NC}"
fi

# Hole Tailscale IP
M1_TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
if [ -n "$M1_TAILSCALE_IP" ]; then
    log "${GREEN}✅ M1 Mac Tailscale IP: $M1_TAILSCALE_IP${NC}"
else
    log "${YELLOW}⚠️ Tailscale IP nicht verfügbar${NC}"
fi
echo ""

# 5. SSH Setup
log "${BLUE}🔐 5. SSH Setup${NC}"
if [ ! -f ~/.ssh/gentleman_secure ]; then
    log "${YELLOW}🔑 Generiere SSH-Schlüssel...${NC}"
    ssh-keygen -t ed25519 -f ~/.ssh/gentleman_secure -N "" -C "gentleman-m1-$(date +%Y%m%d)"
    log "${GREEN}✅ SSH-Schlüssel generiert${NC}"
else
    log "${GREEN}✅ SSH-Schlüssel bereits vorhanden${NC}"
fi

# SSH Config
if ! grep -q "Host rx-node" ~/.ssh/config 2>/dev/null; then
    log "${YELLOW}📝 Erstelle SSH-Konfiguration...${NC}"
    mkdir -p ~/.ssh
    cat >> ~/.ssh/config << EOF

# GENTLEMAN Nodes
Host rx-node
    HostName 192.168.68.117
    User amo9n11
    IdentityFile ~/.ssh/gentleman_secure
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host rx-node-tailscale
    HostName rx-node-tailscale
    User amo9n11
    IdentityFile ~/.ssh/gentleman_secure
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
    log "${GREEN}✅ SSH-Konfiguration erstellt${NC}"
else
    log "${GREEN}✅ SSH-Konfiguration bereits vorhanden${NC}"
fi
echo ""

# 6. Handshake Server Setup
log "${BLUE}🤝 6. Handshake Server Setup${NC}"
if [ ! -f "m1_handshake_server.py" ]; then
    log "${RED}❌ Handshake Server Script nicht gefunden${NC}"
else
    log "${GREEN}✅ Handshake Server verfügbar${NC}"
    
    # Teste Server
    if pgrep -f "m1_handshake_server.py" >/dev/null; then
        log "${GREEN}✅ Handshake Server läuft bereits${NC}"
    else
        log "${YELLOW}🚀 Starte Handshake Server...${NC}"
        python3 m1_handshake_server.py &
        sleep 2
        if pgrep -f "m1_handshake_server.py" >/dev/null; then
            log "${GREEN}✅ Handshake Server gestartet${NC}"
        else
            log "${RED}❌ Handshake Server konnte nicht gestartet werden${NC}"
        fi
    fi
fi
echo ""

# 7. Scripts ausführbar machen
log "${BLUE}🔧 7. Scripts Setup${NC}"
log "${YELLOW}🔄 Mache alle Scripts ausführbar...${NC}"
chmod +x *.sh
log "${GREEN}✅ Alle Scripts sind jetzt ausführbar${NC}"
echo ""

# 8. Netzwerk-Konfiguration
log "${BLUE}🌐 8. Netzwerk-Konfiguration${NC}"
CURRENT_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
log "${BLUE}📍 Aktuelle IP: $CURRENT_IP${NC}"

if [[ $CURRENT_IP == 192.168.68.* ]]; then
    log "${GREEN}✅ Im Heimnetzwerk (192.168.68.x)${NC}"
elif [[ $CURRENT_IP == 172.20.10.* ]]; then
    log "${YELLOW}📱 Im Hotspot-Modus (172.20.10.x)${NC}"
else
    log "${BLUE}🌍 In anderem Netzwerk ($CURRENT_IP)${NC}"
fi
echo ""

# 9. System-Tests
log "${BLUE}🧪 9. System-Tests${NC}"

# Test Tailscale
if [ -n "$M1_TAILSCALE_IP" ]; then
    log "${GREEN}✅ Tailscale: Funktionsfähig${NC}"
else
    log "${RED}❌ Tailscale: Nicht konfiguriert${NC}"
fi

# Test Handshake Server
if curl -s http://localhost:8765/health >/dev/null 2>&1; then
    log "${GREEN}✅ Handshake Server: Online${NC}"
else
    log "${RED}❌ Handshake Server: Offline${NC}"
fi

# Test SSH zu RX Node (falls im Heimnetz)
if [[ $CURRENT_IP == 192.168.68.* ]]; then
    if ssh -o ConnectTimeout=3 rx-node "echo 'SSH OK'" >/dev/null 2>&1; then
        log "${GREEN}✅ SSH zur RX Node: Verfügbar${NC}"
    else
        log "${YELLOW}⚠️ SSH zur RX Node: Nicht verfügbar (Setup erforderlich)${NC}"
    fi
fi
echo ""

# 10. Finale Konfiguration
log "${PURPLE}🎯 10. Finale Konfiguration${NC}"

# Erstelle Startup Script
cat > start_gentleman_m1.sh << 'EOF'
#!/usr/bin/env bash

# GENTLEMAN M1 Startup Script
echo "🚀 Starte GENTLEMAN M1 Central Hub..."

# Starte Handshake Server falls nicht läuft
if ! pgrep -f "m1_handshake_server.py" >/dev/null; then
    echo "🤝 Starte Handshake Server..."
    python3 m1_handshake_server.py &
    sleep 2
fi

# Zeige Status
echo "📊 System Status:"
echo "   Tailscale: $(tailscale ip -4 2>/dev/null || echo 'Nicht verfügbar')"
echo "   Handshake Server: $(curl -s http://localhost:8765/health >/dev/null 2>&1 && echo 'Online' || echo 'Offline')"
echo "   Netzwerk: $(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')"

echo ""
echo "🎮 Verfügbare Commands:"
echo "   ./mesh_node_control.sh all status    - Status aller Nodes"
echo "   ./tailscale_mesh_summary.sh          - Vollständige Übersicht"
echo "   ./mesh_node_control.sh setup         - Setup-Anweisungen"
EOF

chmod +x start_gentleman_m1.sh

log "${GREEN}✅ Startup Script erstellt: start_gentleman_m1.sh${NC}"
echo ""

# Zusammenfassung
log "${PURPLE}🎉 M1 MAC SETUP ABGESCHLOSSEN!${NC}"
log "${PURPLE}==============================${NC}"
echo ""

log "${GREEN}✅ Installierte Komponenten:${NC}"
echo "   - Python 3 und Dependencies"
echo "   - Homebrew und Tools (jq, curl, wget, cloudflared)"
echo "   - Tailscale Mesh Networking"
echo "   - SSH-Konfiguration"
echo "   - Handshake Server"
echo "   - Alle GENTLEMAN Scripts"
echo ""

log "${BLUE}🎮 Nächste Schritte:${NC}"
echo "   1. Führe aus: ./start_gentleman_m1.sh"
echo "   2. Überprüfe Status: ./tailscale_mesh_summary.sh"
echo "   3. Setup andere Nodes: ./mesh_node_control.sh setup"
echo ""

log "${YELLOW}📋 Wichtige Scripts:${NC}"
echo "   ./mesh_node_control.sh          - Unified Node Control"
echo "   ./tailscale_mesh_summary.sh     - System Overview"
echo "   ./start_gentleman_m1.sh         - M1 Startup"
echo "   ./handshake_m1.sh               - Handshake Server"
echo ""

if [ -n "$M1_TAILSCALE_IP" ]; then
    log "${GREEN}🌐 M1 Mac ist bereit als Central Hub (IP: $M1_TAILSCALE_IP)${NC}"
else
    log "${YELLOW}⚠️ Tailscale Setup noch nicht vollständig${NC}"
fi

echo ""
log "${BLUE}📱 Überprüfe auch: https://login.tailscale.com/admin/machines${NC}" 