#!/bin/bash

# 🚀 GENTLEMAN M1 Auto-Handshake Installer
# ========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_FILE="com.gentleman.handshake.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

# Farben
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 GENTLEMAN M1 Auto-Handshake Installer${NC}"
echo "========================================"

# Prüfe ob bereits installiert
if launchctl list | grep -q "com.gentleman.handshake"; then
    echo -e "${YELLOW}⚠️  Auto-Handshake Service bereits installiert${NC}"
    echo "Möchtest du ihn neu installieren? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Installation abgebrochen"
        exit 0
    fi
    
    echo -e "${BLUE}🛑 Stoppe bestehenden Service...${NC}"
    launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_FILE" 2>/dev/null
    launchctl remove com.gentleman.handshake 2>/dev/null
fi

# Erstelle LaunchAgents Verzeichnis
mkdir -p "$LAUNCH_AGENTS_DIR"

# Kopiere plist-Datei
echo -e "${BLUE}📄 Installiere LaunchAgent...${NC}"
cp "$SCRIPT_DIR/$PLIST_FILE" "$LAUNCH_AGENTS_DIR/"

# Lade LaunchAgent
echo -e "${BLUE}🔄 Aktiviere Auto-Handshake Service...${NC}"
launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_FILE"

# Prüfe Status
sleep 3
if launchctl list | grep -q "com.gentleman.handshake"; then
    echo -e "${GREEN}✅ Auto-Handshake Service erfolgreich installiert!${NC}"
    echo ""
    echo "📋 Verfügbare Befehle:"
    echo "  ./auto_handshake_setup.sh status   - Status anzeigen"
    echo "  ./auto_handshake_setup.sh stop     - Service stoppen"
    echo "  ./auto_handshake_setup.sh restart  - Service neu starten"
    echo ""
    echo "📁 Log-Dateien:"
    echo "  handshake_daemon.log        - Service Output"
    echo "  handshake_daemon_error.log  - Service Errors"
    echo "  auto_handshake.log          - Handshake Logs"
    echo "  cloudflare_tunnel.log       - Tunnel Logs"
    echo ""
    echo -e "${BLUE}🔧 Service Management:${NC}"
    echo "  launchctl unload ~/Library/LaunchAgents/$PLIST_FILE  # Deaktivieren"
    echo "  launchctl load ~/Library/LaunchAgents/$PLIST_FILE    # Aktivieren"
    
    # Zeige aktuellen Status
    echo ""
    echo -e "${BLUE}📊 Aktueller Status:${NC}"
    ./auto_handshake_setup.sh status
    
else
    echo -e "${RED}❌ Installation fehlgeschlagen${NC}"
    exit 1
fi 