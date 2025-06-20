#!/bin/bash

# GENTLEMAN RX Node Tailscale Setup
# Einfache Version für manuelle Ausführung auf RX Node

echo "🎯 GENTLEMAN RX Node Tailscale Setup"
echo "====================================="
echo ""

# Farben
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}ℹ️ Dieses Script führt Tailscale Setup auf der RX Node aus${NC}"
echo -e "${YELLOW}⚠️ Sudo-Passwort wird mehrfach benötigt${NC}"
echo ""

# 1. Tailscale Installation
echo -e "${BLUE}📦 Schritt 1: Tailscale Installation...${NC}"
sudo pacman -S tailscale --noconfirm
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Tailscale installiert${NC}"
else
    echo "❌ Tailscale Installation fehlgeschlagen"
    exit 1
fi

# 2. Tailscale Service starten
echo -e "${BLUE}🚀 Schritt 2: Tailscale Service aktivieren...${NC}"
sudo systemctl enable tailscaled
sudo systemctl start tailscaled
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Tailscale Service gestartet${NC}"
else
    echo "❌ Tailscale Service Start fehlgeschlagen"
    exit 1
fi

# 3. Warte kurz
sleep 2

# 4. Tailscale Status prüfen
echo -e "${BLUE}📊 Schritt 3: Service Status...${NC}"
systemctl status tailscaled --no-pager -l

# 5. Tailscale Netzwerk beitreten
echo ""
echo -e "${YELLOW}🔗 Schritt 4: Tailscale Netzwerk beitreten...${NC}"
echo -e "${BLUE}ℹ️ Browser wird sich öffnen für Login mit baumgartneramon@gmail.com${NC}"
echo ""

sudo tailscale up --advertise-routes=192.168.68.0/24 --accept-routes

# 6. Final Status
echo ""
echo -e "${BLUE}📊 Final Status Check:${NC}"
echo "Tailscale Status:"
tailscale status

echo ""
echo "Tailscale IP:"
tailscale ip -4

echo ""
echo -e "${GREEN}🎉 Tailscale Setup abgeschlossen!${NC}"
echo -e "${BLUE}💡 RX Node ist jetzt über Tailscale erreichbar${NC}" 

# GENTLEMAN RX Node Tailscale Setup
# Einfache Version für manuelle Ausführung auf RX Node

echo "🎯 GENTLEMAN RX Node Tailscale Setup"
echo "====================================="
echo ""

# Farben
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}ℹ️ Dieses Script führt Tailscale Setup auf der RX Node aus${NC}"
echo -e "${YELLOW}⚠️ Sudo-Passwort wird mehrfach benötigt${NC}"
echo ""

# 1. Tailscale Installation
echo -e "${BLUE}📦 Schritt 1: Tailscale Installation...${NC}"
sudo pacman -S tailscale --noconfirm
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Tailscale installiert${NC}"
else
    echo "❌ Tailscale Installation fehlgeschlagen"
    exit 1
fi

# 2. Tailscale Service starten
echo -e "${BLUE}🚀 Schritt 2: Tailscale Service aktivieren...${NC}"
sudo systemctl enable tailscaled
sudo systemctl start tailscaled
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Tailscale Service gestartet${NC}"
else
    echo "❌ Tailscale Service Start fehlgeschlagen"
    exit 1
fi

# 3. Warte kurz
sleep 2

# 4. Tailscale Status prüfen
echo -e "${BLUE}📊 Schritt 3: Service Status...${NC}"
systemctl status tailscaled --no-pager -l

# 5. Tailscale Netzwerk beitreten
echo ""
echo -e "${YELLOW}🔗 Schritt 4: Tailscale Netzwerk beitreten...${NC}"
echo -e "${BLUE}ℹ️ Browser wird sich öffnen für Login mit baumgartneramon@gmail.com${NC}"
echo ""

sudo tailscale up --advertise-routes=192.168.68.0/24 --accept-routes

# 6. Final Status
echo ""
echo -e "${BLUE}📊 Final Status Check:${NC}"
echo "Tailscale Status:"
tailscale status

echo ""
echo "Tailscale IP:"
tailscale ip -4

echo ""
echo -e "${GREEN}🎉 Tailscale Setup abgeschlossen!${NC}"
echo -e "${BLUE}💡 RX Node ist jetzt über Tailscale erreichbar${NC}" 
 