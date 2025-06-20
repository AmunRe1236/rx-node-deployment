#!/bin/bash

# GENTLEMAN I7 Laptop Tailscale Setup
# Installiert und konfiguriert Tailscale auf dem I7 Laptop für vollständiges Mesh

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

log "${BLUE}🕸️ GENTLEMAN I7 Laptop Tailscale Setup${NC}"
log "${BLUE}=====================================${NC}"

# Erkenne das Betriebssystem
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    log "${BLUE}📱 macOS erkannt${NC}"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    log "${BLUE}🐧 Linux erkannt${NC}"
else
    log "${RED}❌ Unbekanntes Betriebssystem: $OSTYPE${NC}"
    exit 1
fi

# Überprüfe ob Tailscale bereits installiert ist
log "${YELLOW}🔍 Überprüfe Tailscale-Installation...${NC}"
if command -v tailscale >/dev/null 2>&1; then
    log "${GREEN}✅ Tailscale bereits installiert${NC}"
    CURRENT_STATUS=$(tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo 'NotRunning')
    log "${BLUE}📊 Aktueller Status: $CURRENT_STATUS${NC}"
    
    if [ "$CURRENT_STATUS" = "Running" ]; then
        log "${GREEN}✅ Tailscale läuft bereits${NC}"
        tailscale status
        exit 0
    fi
else
    log "${YELLOW}📦 Tailscale nicht gefunden, installiere...${NC}"
    
    if [ "$OS" = "macos" ]; then
        # macOS Installation
        log "${BLUE}🍎 Installiere Tailscale auf macOS...${NC}"
        if command -v brew >/dev/null 2>&1; then
            brew install tailscale
        else
            log "${YELLOW}⚠️ Homebrew nicht gefunden${NC}"
            log "${BLUE}📋 Manuelle Installation erforderlich:${NC}"
            echo "1. Öffne: https://tailscale.com/download/mac"
            echo "2. Lade Tailscale.pkg herunter"
            echo "3. Installiere das Paket"
            echo "4. Führe dieses Skript erneut aus"
            exit 1
        fi
    elif [ "$OS" = "linux" ]; then
        # Linux Installation
        log "${BLUE}🐧 Installiere Tailscale auf Linux...${NC}"
        curl -fsSL https://tailscale.com/install.sh | sh
    fi
    
    if [ $? -eq 0 ]; then
        log "${GREEN}✅ Tailscale erfolgreich installiert${NC}"
    else
        log "${RED}❌ Tailscale-Installation fehlgeschlagen${NC}"
        exit 1
    fi
fi

# Auth-Key Setup
log "${YELLOW}🔑 Auth-Key Setup erforderlich...${NC}"
log "${BLUE}📋 Führe folgende Schritte aus:${NC}"
log "${YELLOW}1. Öffne https://login.tailscale.com/admin/settings/keys${NC}"
log "${YELLOW}2. Klicke 'Generate auth key'${NC}"
log "${YELLOW}3. Aktiviere 'Reusable' und 'Ephemeral' (optional)${NC}"
log "${YELLOW}4. Kopiere den generierten Key${NC}"

echo ""
read -p "Hast du einen Auth-Key generiert? Füge ihn hier ein: " AUTH_KEY

if [ -z "$AUTH_KEY" ]; then
    log "${RED}❌ Kein Auth-Key eingegeben${NC}"
    exit 1
fi

# Verbinde I7 mit Tailscale
log "${BLUE}🔗 Verbinde I7 Laptop mit Tailscale...${NC}"

if [ "$OS" = "macos" ]; then
    sudo tailscale up --authkey="$AUTH_KEY" --hostname="i7-laptop-macos"
elif [ "$OS" = "linux" ]; then
    sudo tailscale up --authkey="$AUTH_KEY" --hostname="i7-laptop-linux"
fi

if [ $? -eq 0 ]; then
    log "${GREEN}✅ I7 Laptop erfolgreich mit Tailscale verbunden${NC}"
else
    log "${RED}❌ Tailscale-Verbindung fehlgeschlagen${NC}"
    exit 1
fi

# Überprüfe Tailscale-Status
log "${BLUE}📊 Überprüfe Tailscale-Status...${NC}"
I7_TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
I7_HOSTNAME=$(tailscale status --json 2>/dev/null | jq -r '.Self.HostName' 2>/dev/null || echo 'unknown')

log "${GREEN}✅ I7 Laptop Tailscale-Konfiguration:${NC}"
log "${BLUE}   IP: $I7_TAILSCALE_IP${NC}"
log "${BLUE}   Hostname: $I7_HOSTNAME${NC}"

# Zeige aktuellen Tailscale-Status
log "${BLUE}📊 Aktueller Tailscale-Status:${NC}"
tailscale status

log "${GREEN}🎉 I7 Laptop Tailscale-Setup abgeschlossen!${NC}"
log "${BLUE}📱 Der I7 Laptop sollte jetzt in deiner Tailscale-App sichtbar sein${NC}"

# Teste Verbindungen zu anderen Nodes
log "${YELLOW}🔍 Teste Verbindungen zu anderen Nodes...${NC}"

# Teste M1 Mac
M1_IP="100.96.219.28"
if ping -c 1 -W 3 "$M1_IP" >/dev/null 2>&1; then
    log "${GREEN}✅ Ping zum M1 Mac ($M1_IP) erfolgreich${NC}"
else
    log "${YELLOW}⚠️ Ping zum M1 Mac ($M1_IP) fehlgeschlagen${NC}"
fi

# Teste iPhone
IPHONE_IP="100.123.55.36"
if ping -c 1 -W 3 "$IPHONE_IP" >/dev/null 2>&1; then
    log "${GREEN}✅ Ping zum iPhone ($IPHONE_IP) erfolgreich${NC}"
else
    log "${YELLOW}⚠️ Ping zum iPhone ($IPHONE_IP) fehlgeschlagen${NC}"
fi

log "${GREEN}🎯 Setup abgeschlossen! I7 Laptop ist jetzt im Tailscale Mesh${NC}" 