#!/bin/bash

# GENTLEMAN RX Node Setup (Arch Linux)
# Komplettes Setup für die RX Node als AI/Computing Node

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
log "${PURPLE}🖥️ GENTLEMAN RX NODE SETUP (ARCH LINUX)${NC}"
log "${PURPLE}=======================================${NC}"
echo ""

# Überprüfe ob wir auf Arch Linux sind
if [ ! -f /etc/arch-release ]; then
    log "${RED}❌ Dieses Script ist nur für Arch Linux gedacht${NC}"
    exit 1
fi

log "${GREEN}✅ Arch Linux erkannt - Setup wird gestartet${NC}"
echo ""

# 1. System Update
log "${BLUE}📦 1. System Update${NC}"
log "${YELLOW}🔄 Aktualisiere System...${NC}"
sudo pacman -Syu --noconfirm
echo ""

# 2. Base Packages
log "${BLUE}📦 2. Base Packages${NC}"
log "${YELLOW}🔄 Installiere Basis-Pakete...${NC}"
sudo pacman -S --noconfirm \
    git curl wget jq \
    python python-pip \
    openssh \
    base-devel \
    htop neofetch \
    docker docker-compose \
    || log "${YELLOW}⚠️ Einige Pakete konnten nicht installiert werden${NC}"
echo ""

# 3. Repository Setup
log "${BLUE}📦 3. Repository Setup${NC}"
if [ ! -d "Gentleman" ]; then
    log "${YELLOW}🔄 Klone GENTLEMAN Repository...${NC}"
    git clone https://github.com/AmunRe1236/rx-node-deployment.git Gentleman
    cd Gentleman
else
    log "${GREEN}✅ Repository bereits vorhanden${NC}"
    cd Gentleman
    log "${YELLOW}🔄 Aktualisiere Repository...${NC}"
    git pull origin master
fi
echo ""

# 4. Python Setup
log "${BLUE}🐍 4. Python Setup${NC}"
log "${YELLOW}🔄 Installiere Python Dependencies...${NC}"
pip install --user flask requests psutil wakeonlan || log "${YELLOW}⚠️ Einige Python Packages konnten nicht installiert werden${NC}"
echo ""

# 5. Tailscale Setup
log "${BLUE}🕸️ 5. Tailscale Setup${NC}"
if ! command -v tailscale >/dev/null 2>&1; then
    log "${YELLOW}📦 Installiere Tailscale...${NC}"
    sudo pacman -S --noconfirm tailscale
    sudo systemctl enable tailscaled
    sudo systemctl start tailscaled
else
    log "${GREEN}✅ Tailscale bereits installiert${NC}"
fi

# Tailscale Status überprüfen
if ! sudo tailscale status >/dev/null 2>&1; then
    log "${YELLOW}🔗 Tailscale Setup erforderlich${NC}"
    log "${BLUE}📋 Gehe zu: https://login.tailscale.com/admin/settings/keys${NC}"
    echo ""
    echo "Generiere einen Auth-Key und führe dann aus:"
    echo "sudo tailscale up --authkey='DEIN_KEY' --hostname='rx-node-archlinux'"
    echo ""
    echo "Nach der Konfiguration führe dieses Script erneut aus."
    read -p "Drücke Enter wenn Tailscale konfiguriert ist..."
else
    log "${GREEN}✅ Tailscale bereits konfiguriert${NC}"
fi

# Hole Tailscale IP
RX_TAILSCALE_IP=$(sudo tailscale ip -4 2>/dev/null || echo "")
if [ -n "$RX_TAILSCALE_IP" ]; then
    log "${GREEN}✅ RX Node Tailscale IP: $RX_TAILSCALE_IP${NC}"
else
    log "${YELLOW}⚠️ Tailscale IP nicht verfügbar${NC}"
fi
echo ""

# 6. SSH Setup
log "${BLUE}🔐 6. SSH Setup${NC}"
if [ ! -f ~/.ssh/id_ed25519 ]; then
    log "${YELLOW}🔑 Generiere SSH-Schlüssel...${NC}"
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "gentleman-rx-$(date +%Y%m%d)"
    log "${GREEN}✅ SSH-Schlüssel generiert${NC}"
else
    log "${GREEN}✅ SSH-Schlüssel bereits vorhanden${NC}"
fi

# SSH Server konfigurieren
sudo systemctl enable sshd
sudo systemctl start sshd

log "${GREEN}✅ SSH Server konfiguriert${NC}"
echo ""

# 7. Docker Setup
log "${BLUE}🐳 7. Docker Setup${NC}"
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

log "${GREEN}✅ Docker konfiguriert${NC}"
echo ""

# 8. Wake-on-LAN Setup
log "${BLUE}🔌 8. Wake-on-LAN Setup${NC}"
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -n "$INTERFACE" ]; then
    log "${YELLOW}🔄 Aktiviere Wake-on-LAN für $INTERFACE...${NC}"
    sudo ethtool -s $INTERFACE wol g 2>/dev/null || log "${YELLOW}⚠️ Wake-on-LAN konnte nicht aktiviert werden${NC}"
    
    # Permanent WoL aktivieren
    echo "ethtool -s $INTERFACE wol g" | sudo tee /etc/systemd/system/wol.service > /dev/null
    log "${GREEN}✅ Wake-on-LAN aktiviert${NC}"
else
    log "${YELLOW}⚠️ Netzwerk-Interface nicht gefunden${NC}"
fi
echo ""

# 9. Firewall Setup
log "${BLUE}🔥 9. Firewall Setup${NC}"
if command -v ufw >/dev/null 2>&1; then
    sudo ufw --force enable
    sudo ufw allow ssh
    sudo ufw allow from 192.168.68.0/24
    sudo ufw allow from 100.0.0.0/8  # Tailscale Netz
    log "${GREEN}✅ Firewall konfiguriert${NC}"
else
    log "${YELLOW}⚠️ UFW nicht verfügbar${NC}"
fi
echo ""

# 10. Scripts Setup
log "${BLUE}🔧 10. Scripts Setup${NC}"
log "${YELLOW}🔄 Mache alle Scripts ausführbar...${NC}"
chmod +x *.sh
log "${GREEN}✅ Alle Scripts sind jetzt ausführbar${NC}"

# Erstelle RX Node Startup Script
cat > start_gentleman_rx.sh << 'EOF'
#!/bin/bash

# GENTLEMAN RX Node Startup Script
echo "🚀 Starte GENTLEMAN RX Node..."

# Überprüfe Services
echo "📊 System Status:"
echo "   Hostname: $(hostname)"
echo "   Uptime: $(uptime -p)"
echo "   Tailscale: $(sudo tailscale ip -4 2>/dev/null || echo 'Nicht verfügbar')"
echo "   Docker: $(sudo systemctl is-active docker)"
echo "   SSH: $(sudo systemctl is-active sshd)"

# Netzwerk Info
echo "   Lokale IP: $(hostname -I | awk '{print $1}')"
echo "   MAC: $(cat /sys/class/net/$(ip route | grep default | awk '{print $5}' | head -1)/address)"

echo ""
echo "🎮 RX Node bereit für:"
echo "   - AI Processing"
echo "   - Heavy Computing"
echo "   - Docker Services"
echo "   - Remote Access via Tailscale"
EOF

chmod +x start_gentleman_rx.sh

log "${GREEN}✅ Startup Script erstellt: start_gentleman_rx.sh${NC}"
echo ""

# 11. AMD GPU Setup (optional)
log "${BLUE}🎮 11. AMD GPU Setup (optional)${NC}"
if lspci | grep -i amd >/dev/null; then
    log "${GREEN}✅ AMD GPU erkannt${NC}"
    
    read -p "Möchtest du AMD GPU Support installieren? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "${YELLOW}🔄 Installiere AMD GPU Support...${NC}"
        sudo pacman -S --noconfirm \
            mesa \
            vulkan-radeon \
            libva-mesa-driver \
            mesa-vdpau \
            rocm-opencl-runtime \
            || log "${YELLOW}⚠️ Einige AMD Pakete konnten nicht installiert werden${NC}"
        
        log "${GREEN}✅ AMD GPU Support installiert${NC}"
    fi
else
    log "${BLUE}ℹ️ Keine AMD GPU erkannt${NC}"
fi
echo ""

# 12. System Info
log "${BLUE}📋 12. System Information${NC}"
CURRENT_IP=$(hostname -I | awk '{print $1}')
MAC_ADDRESS=$(cat /sys/class/net/$(ip route | grep default | awk '{print $5}' | head -1)/address)

log "${BLUE}📍 RX Node Informationen:${NC}"
echo "   Hostname: $(hostname)"
echo "   Lokale IP: $CURRENT_IP"
echo "   MAC: $MAC_ADDRESS"
echo "   Tailscale IP: $RX_TAILSCALE_IP"
echo "   SSH Port: 22"
echo "   User: $(whoami)"
echo ""

# 13. System Tests
log "${BLUE}🧪 13. System Tests${NC}"

# Test Tailscale
if [ -n "$RX_TAILSCALE_IP" ]; then
    log "${GREEN}✅ Tailscale: Funktionsfähig${NC}"
else
    log "${RED}❌ Tailscale: Nicht konfiguriert${NC}"
fi

# Test Docker
if sudo systemctl is-active docker >/dev/null; then
    log "${GREEN}✅ Docker: Aktiv${NC}"
else
    log "${RED}❌ Docker: Nicht aktiv${NC}"
fi

# Test SSH
if sudo systemctl is-active sshd >/dev/null; then
    log "${GREEN}✅ SSH: Aktiv${NC}"
else
    log "${RED}❌ SSH: Nicht aktiv${NC}"
fi
echo ""

# Zusammenfassung
log "${PURPLE}🎉 RX NODE SETUP ABGESCHLOSSEN!${NC}"
log "${PURPLE}===============================${NC}"
echo ""

log "${GREEN}✅ Installierte Komponenten:${NC}"
echo "   - Arch Linux System Updates"
echo "   - Python 3 und Dependencies"
echo "   - Tailscale Mesh Networking"
echo "   - SSH Server"
echo "   - Docker und Docker Compose"
echo "   - Wake-on-LAN"
echo "   - Firewall (UFW)"
echo "   - GENTLEMAN Scripts"
if lspci | grep -i amd >/dev/null && [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "   - AMD GPU Support"
fi
echo ""

log "${BLUE}🎮 Nächste Schritte:${NC}"
echo "   1. Führe aus: ./start_gentleman_rx.sh"
echo "   2. Teste Verbindung vom M1 Mac"
echo "   3. Konfiguriere AI Services (optional)"
echo ""

log "${YELLOW}📋 Wichtige Informationen für M1 Mac:${NC}"
echo "   SSH: ssh amo9n11@$CURRENT_IP"
echo "   Tailscale SSH: ssh amo9n11@$RX_TAILSCALE_IP"
echo "   MAC für WoL: $MAC_ADDRESS"
echo ""

log "${BLUE}🔗 SSH Public Key für M1 Mac:${NC}"
if [ -f ~/.ssh/id_ed25519.pub ]; then
    cat ~/.ssh/id_ed25519.pub
    echo ""
    echo "Kopiere diesen Key zum M1 Mac mit:"
    echo "ssh-copy-id -i ~/.ssh/id_ed25519.pub amo9n11@M1_MAC_IP"
fi

echo ""
log "${GREEN}🌐 RX Node ist bereit als AI/Computing Node!${NC}"
log "${BLUE}📱 Überprüfe auch: https://login.tailscale.com/admin/machines${NC}" 