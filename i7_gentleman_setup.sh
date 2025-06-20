#!/usr/bin/env bash

# GENTLEMAN I7 Laptop Setup (Cross-Platform)

set -e

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [ -f /etc/arch-release ]; then
            DISTRO="arch"
        elif [ -f /etc/debian_version ]; then
            DISTRO="debian"
        else
            DISTRO="unknown"
        fi
    else
        OS="unknown"
    fi
}

clear
log "${PURPLE}💻 GENTLEMAN I7 LAPTOP SETUP${NC}"
log "${PURPLE}============================${NC}"

detect_os
log "${GREEN}✅ System: $OS${NC}"

# Repository Setup
log "${BLUE}📦 Repository Setup${NC}"
if [ ! -d "Gentleman" ]; then
    git clone https://github.com/AmunRe1236/rx-node-deployment.git Gentleman
    cd Gentleman
else
    cd Gentleman
    git pull origin master
fi

# Package Installation
log "${BLUE}📦 Package Installation${NC}"
case $OS in
    "macos")
        if ! command -v brew >/dev/null 2>&1; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install git curl wget jq python3 tailscale
        ;;
    "linux")
        case $DISTRO in
            "arch")
                sudo pacman -S --noconfirm git curl wget jq python python-pip tailscale
                sudo systemctl enable tailscaled
                sudo systemctl start tailscaled
                ;;
            "debian")
                sudo apt update
                sudo apt install -y git curl wget jq python3 python3-pip
                curl -fsSL https://tailscale.com/install.sh | sh
                ;;
        esac
        ;;
esac

# Python Dependencies
pip3 install --user flask requests psutil wakeonlan

# Tailscale Setup
log "${BLUE}🕸️ Tailscale Setup${NC}"
if ! tailscale status >/dev/null 2>&1; then
    log "${YELLOW}Öffne: https://login.tailscale.com/admin/settings/keys${NC}"
    read -p "Auth-Key eingeben: " AUTH_KEY
    if [ -n "$AUTH_KEY" ]; then
        sudo tailscale up --authkey="$AUTH_KEY" --hostname="i7-laptop"
    fi
fi

I7_IP=$(tailscale ip -4 2>/dev/null || echo "")
log "${GREEN}✅ Tailscale IP: $I7_IP${NC}"

# SSH Setup
log "${BLUE}🔐 SSH Setup${NC}"
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "gentleman-i7"
fi

mkdir -p ~/.ssh
cat >> ~/.ssh/config << EOF

# GENTLEMAN Nodes
Host m1-mac
    HostName 100.96.219.28
    User amonbaumgartner
    IdentityFile ~/.ssh/id_ed25519

Host rx-node
    HostName 192.168.68.117
    User amo9n11
    IdentityFile ~/.ssh/id_ed25519
EOF

# Scripts Setup
chmod +x *.sh

# Startup Script
cat > start_gentleman_i7.sh << 'EOF'
#!/usr/bin/env bash
echo "🚀 GENTLEMAN I7 Laptop"
echo "Tailscale: $(tailscale ip -4 2>/dev/null || echo 'N/A')"
echo "Local IP: $(hostname -I | awk '{print $1}' 2>/dev/null || ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')"
EOF

chmod +x start_gentleman_i7.sh

log "${PURPLE}🎉 I7 SETUP ABGESCHLOSSEN!${NC}"
log "${GREEN}Starte mit: ./start_gentleman_i7.sh${NC}" 