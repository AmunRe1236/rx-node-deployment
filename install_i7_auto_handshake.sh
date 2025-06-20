#!/bin/bash

# 🚀 GENTLEMAN I7 Auto-Handshake Installer
# ========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_FILE="com.gentleman.i7-handshake.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

# Farben
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 GENTLEMAN I7 Auto-Handshake Installer${NC}"
echo "========================================"

# Prüfe ob bereits installiert
if launchctl list | grep -q "com.gentleman.i7-handshake"; then
    echo -e "${YELLOW}⚠️  I7 Auto-Handshake Service bereits installiert${NC}"
    echo "Möchtest du ihn neu installieren? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Installation abgebrochen"
        exit 0
    fi
    
    echo -e "${BLUE}🛑 Stoppe bestehenden Service...${NC}"
    launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_FILE" 2>/dev/null
    launchctl remove com.gentleman.i7-handshake 2>/dev/null
fi

# Prüfe Voraussetzungen
echo -e "${BLUE}🔍 Prüfe Voraussetzungen...${NC}"

# Python3 Check
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python3 nicht gefunden!${NC}"
    echo "Bitte installiere Python3: brew install python"
    exit 1
fi

# Requests Module Check
if ! python3 -c "import requests" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Python requests Modul fehlt - installiere...${NC}"
    pip3 install requests
fi

# M1 Konnektivität Test
echo -e "${BLUE}🔗 Teste M1 Handshake Server Verbindung...${NC}"
if curl -s -f --max-time 5 "http://192.168.68.111:8765/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ M1 Handshake Server erreichbar${NC}"
else
    echo -e "${YELLOW}⚠️  M1 Handshake Server nicht erreichbar${NC}"
    echo "Der Service wird trotzdem installiert und versucht automatisch zu verbinden."
fi

# Mache Scripts ausführbar
chmod +x "$SCRIPT_DIR/i7_auto_handshake_setup.sh"
chmod +x "$SCRIPT_DIR/i7_handshake_client.py"

# Erstelle LaunchAgents Verzeichnis
mkdir -p "$LAUNCH_AGENTS_DIR"

# Kopiere plist-Datei
echo -e "${BLUE}📄 Installiere LaunchAgent...${NC}"
cp "$SCRIPT_DIR/$PLIST_FILE" "$LAUNCH_AGENTS_DIR/"

# Lade LaunchAgent
echo -e "${BLUE}🔄 Aktiviere I7 Auto-Handshake Service...${NC}"
launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_FILE"

# Prüfe Status
sleep 3
if launchctl list | grep -q "com.gentleman.i7-handshake"; then
    echo -e "${GREEN}✅ I7 Auto-Handshake Service erfolgreich installiert!${NC}"
    echo ""
    echo "📋 Verfügbare Befehle:"
    echo "  ./i7_auto_handshake_setup.sh status   - Status anzeigen"
    echo "  ./i7_auto_handshake_setup.sh stop     - Service stoppen"
    echo "  ./i7_auto_handshake_setup.sh restart  - Service neu starten"
    echo "  ./i7_auto_handshake_setup.sh test     - Konfiguration testen"
    echo ""
    echo "📁 Log-Dateien:"
    echo "  i7_handshake_daemon.log        - Service Output"
    echo "  i7_handshake_daemon_error.log  - Service Errors"
    echo "  i7_auto_handshake.log          - Handshake Logs"
    echo "  i7_handshake_client.log        - Client Logs"
    echo ""
    echo -e "${BLUE}🔧 Service Management:${NC}"
    echo "  launchctl unload ~/Library/LaunchAgents/$PLIST_FILE  # Deaktivieren"
    echo "  launchctl load ~/Library/LaunchAgents/$PLIST_FILE    # Aktivieren"
    
    # Teste Handshake
    echo ""
    echo -e "${BLUE}🧪 Teste I7 Handshake...${NC}"
    if ./i7_auto_handshake_setup.sh test; then
        echo -e "${GREEN}✅ Handshake-Test erfolgreich${NC}"
    else
        echo -e "${YELLOW}⚠️  Handshake-Test fehlgeschlagen - prüfe M1 Server${NC}"
    fi
    
    # Zeige aktuellen Status
    echo ""
    echo -e "${BLUE}📊 Aktueller Status:${NC}"
    ./i7_auto_handshake_setup.sh status
    
else
    echo -e "${RED}❌ Installation fehlgeschlagen${NC}"
    exit 1
fi 