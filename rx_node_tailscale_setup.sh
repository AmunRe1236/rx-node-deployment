#!/bin/bash

# GENTLEMAN RX Node Tailscale Setup
# Installiert und konfiguriert Tailscale auf der RX Node für vollständiges Mesh

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

log "${BLUE}🕸️ GENTLEMAN RX Node Tailscale Setup${NC}"
log "${BLUE}====================================${NC}"

# Überprüfe SSH-Verbindung zur RX Node
log "${YELLOW}🔍 Teste SSH-Verbindung zur RX Node...${NC}"
if ! ssh -o ConnectTimeout=5 rx-node "echo 'SSH OK'" >/dev/null 2>&1; then
    log "${RED}❌ SSH-Verbindung zur RX Node fehlgeschlagen${NC}"
    log "${YELLOW}💡 Stelle sicher, dass du im Heimnetz bist${NC}"
    exit 1
fi
log "${GREEN}✅ SSH-Verbindung zur RX Node erfolgreich${NC}"

# Überprüfe ob Tailscale bereits installiert ist
log "${YELLOW}🔍 Überprüfe Tailscale-Installation...${NC}"
if ssh rx-node "which tailscale" >/dev/null 2>&1; then
    log "${GREEN}✅ Tailscale bereits installiert${NC}"
    CURRENT_STATUS=$(ssh rx-node "tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo 'NotRunning'")
    log "${BLUE}📊 Aktueller Status: $CURRENT_STATUS${NC}"
else
    log "${YELLOW}📦 Tailscale nicht gefunden, installiere...${NC}"
    
    # Installiere Tailscale auf Arch Linux
    log "${BLUE}🔧 Installiere Tailscale auf Arch Linux...${NC}"
    ssh rx-node "
        # Update package database
        sudo pacman -Sy --noconfirm
        
        # Install Tailscale
        sudo pacman -S --noconfirm tailscale
        
        # Enable and start tailscaled service
        sudo systemctl enable tailscaled
        sudo systemctl start tailscaled
        
        # Verify installation
        which tailscale && tailscale version
    "
    
    if [ $? -eq 0 ]; then
        log "${GREEN}✅ Tailscale erfolgreich installiert${NC}"
    else
        log "${RED}❌ Tailscale-Installation fehlgeschlagen${NC}"
        exit 1
    fi
fi

# Generiere Auth-Key Anweisungen
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

# Verbinde RX Node mit Tailscale
log "${BLUE}🔗 Verbinde RX Node mit Tailscale...${NC}"
ssh rx-node "sudo tailscale up --authkey='$AUTH_KEY' --hostname='rx-node-archlinux'"

if [ $? -eq 0 ]; then
    log "${GREEN}✅ RX Node erfolgreich mit Tailscale verbunden${NC}"
else
    log "${RED}❌ Tailscale-Verbindung fehlgeschlagen${NC}"
    exit 1
fi

# Überprüfe Tailscale-Status auf RX Node
log "${BLUE}📊 Überprüfe Tailscale-Status...${NC}"
RX_TAILSCALE_IP=$(ssh rx-node "tailscale ip -4" 2>/dev/null || echo "unknown")
RX_HOSTNAME=$(ssh rx-node "tailscale status --json 2>/dev/null | jq -r '.Self.HostName' 2>/dev/null || echo 'unknown'")

log "${GREEN}✅ RX Node Tailscale-Konfiguration:${NC}"
log "${BLUE}   IP: $RX_TAILSCALE_IP${NC}"
log "${BLUE}   Hostname: $RX_HOSTNAME${NC}"

# Teste Verbindung vom M1 Mac zur RX Node über Tailscale
log "${YELLOW}🔍 Teste Tailscale-Verbindung...${NC}"
if ping -c 1 -W 3 "$RX_TAILSCALE_IP" >/dev/null 2>&1; then
    log "${GREEN}✅ Ping zur RX Node über Tailscale erfolgreich${NC}"
else
    log "${YELLOW}⚠️ Ping zur RX Node über Tailscale fehlgeschlagen (kann normal sein)${NC}"
fi

# Aktualisiere lokalen Tailscale-Status
log "${BLUE}🔄 Aktualisiere lokalen Tailscale-Status...${NC}"
tailscale status

log "${GREEN}🎉 RX Node Tailscale-Setup abgeschlossen!${NC}"
log "${BLUE}📱 Die RX Node sollte jetzt in deiner Tailscale-App sichtbar sein${NC}"

# Erstelle SSH-Konfiguration für Tailscale
log "${BLUE}🔧 Aktualisiere SSH-Konfiguration...${NC}"
if ! grep -q "Host rx-node-tailscale" ~/.ssh/config 2>/dev/null; then
    cat >> ~/.ssh/config << EOF

# RX Node via Tailscale
Host rx-node-tailscale
    HostName $RX_TAILSCALE_IP
    User amo9n11
    IdentityFile ~/.ssh/gentleman_secure
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
    log "${GREEN}✅ SSH-Konfiguration für Tailscale hinzugefügt${NC}"
else
    log "${BLUE}ℹ️ SSH-Konfiguration bereits vorhanden${NC}"
fi

log "${GREEN}🎯 Setup abgeschlossen! RX Node ist jetzt im Tailscale Mesh${NC}" 