#!/bin/bash

# 🎩 GENTLEMAN I7 Node Manual Setup
# Funktioniert ohne Homebrew - alternative Installationen
# Version: 1.0

echo "🎩 GENTLEMAN I7 Node Manual Setup"
echo "================================="
echo ""

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ Dieses Script ist für macOS designed"
    exit 1
fi

echo "🔍 Prüfe System..."
echo "   OS: $(uname -s)"
echo "   Version: $(sw_vers -productVersion)"
echo "   Arch: $(uname -m)"
echo ""

# Step 1: Install Homebrew if not present
if ! command -v brew &> /dev/null; then
    echo "🍺 Installiere Homebrew..."
    echo "⚠️  Administrator-Rechte erforderlich"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for current session
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
    
    echo "✅ Homebrew installiert"
else
    echo "✅ Homebrew bereits installiert"
fi

# Step 2: Install WireGuard tools
echo "🔐 Installiere WireGuard Tools..."
if ! command -v wg &> /dev/null; then
    brew install wireguard-tools
    echo "✅ WireGuard Tools installiert"
else
    echo "✅ WireGuard Tools bereits vorhanden"
fi

# Step 3: Create WireGuard directory
echo "📁 Erstelle WireGuard Verzeichnis..."
sudo mkdir -p /opt/homebrew/etc/wireguard
sudo chown $(whoami):staff /opt/homebrew/etc/wireguard
echo "✅ WireGuard Verzeichnis erstellt"

# Step 4: Copy WireGuard config if present
if [[ -f ~/i7_wireguard_client.conf ]]; then
    echo "📋 Kopiere WireGuard Konfiguration..."
    cp ~/i7_wireguard_client.conf /opt/homebrew/etc/wireguard/
    echo "✅ WireGuard Konfiguration kopiert"
else
    echo "⚠️  WireGuard Konfiguration nicht gefunden (~/i7_wireguard_client.conf)"
    echo "   Manuell vom M1 Mac kopieren!"
fi

# Step 5: Install Git if not present
if ! command -v git &> /dev/null; then
    echo "📚 Installiere Git..."
    brew install git
    echo "✅ Git installiert"
else
    echo "✅ Git bereits vorhanden"
fi

# Step 6: Setup GENTLEMAN repository access
echo "🎩 Konfiguriere GENTLEMAN Repository Zugriff..."

# Test Git daemon connectivity
M1_MAC_IP="192.168.68.111"
GIT_PORT="9418"

echo "🔍 Teste Git Daemon Verbindung zu $M1_MAC_IP:$GIT_PORT..."
if nc -z "$M1_MAC_IP" "$GIT_PORT" 2>/dev/null; then
    echo "✅ Git Daemon erreichbar"
    
    # Clone GENTLEMAN repository
    if [[ ! -d ~/Gentleman ]]; then
        echo "📥 Clone GENTLEMAN Repository..."
        git clone "git://$M1_MAC_IP:$GIT_PORT/Gentleman" ~/Gentleman
        echo "✅ Repository geklont"
    else
        echo "📁 Repository bereits vorhanden - aktualisiere..."
        cd ~/Gentleman
        git pull
        echo "✅ Repository aktualisiert"
    fi
else
    echo "⚠️  Git Daemon nicht erreichbar"
    echo "   Prüfe ob Git Daemon auf M1 Mac läuft"
    echo "   Fallback: Manuelle Git-Konfiguration erforderlich"
fi

# Step 7: Install additional tools
echo "🔧 Installiere zusätzliche Tools..."

# Install netcat for connectivity tests
if ! command -v nc &> /dev/null; then
    brew install netcat
    echo "✅ Netcat installiert"
fi

# Install Python packages for GENTLEMAN system
echo "🐍 Installiere Python Dependencies..."
python3 -m pip install --user requests urllib3 numpy pandas matplotlib

echo ""
echo "🎉 I7 Node Setup abgeschlossen!"
echo ""
echo "📋 Nächste Schritte:"
echo "1. 🔐 WireGuard starten: sudo wg-quick up i7_wireguard_client"
echo "2. 🔍 VPN testen: sudo wg show"
echo "3. 📡 Connectivity: ping 192.168.68.111"
echo "4. 📚 Git verwenden: cd ~/Gentleman && git pull"
echo ""
echo "🎯 I7 Node ist bereit für das GENTLEMAN Cluster!" 