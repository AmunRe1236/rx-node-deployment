#!/usr/bin/env bash

# GENTLEMAN Tailscale Mesh Setup - Zusammenfassung
# Finales Setup und Übersicht über das vollständige Mesh-System

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
log "${PURPLE}🕸️ GENTLEMAN TAILSCALE MESH SYSTEM${NC}"
log "${PURPLE}===================================${NC}"
echo ""

# Aktueller Status
log "${BLUE}📊 Aktueller Tailscale-Status:${NC}"
if command -v tailscale >/dev/null 2>&1; then
    tailscale status
else
    log "${RED}❌ Tailscale nicht installiert${NC}"
fi
echo ""

# Node-Übersicht
log "${BLUE}🖥️ GENTLEMAN Node-Architektur:${NC}"
echo ""

log "${GREEN}✅ M1 Mac (Central Hub):${NC}"
echo "   - IP: 100.96.219.28"
echo "   - Rolle: Handshake Server, Central Control"
echo "   - Services: Wake-on-LAN, Node Management"
echo "   - Status: ✅ Aktiv"
echo ""

log "${YELLOW}📱 iPhone:${NC}"
echo "   - IP: 100.123.55.36"
echo "   - Rolle: Mobile Control"
echo "   - Status: ✅ Verbunden"
echo ""

log "${CYAN}🖥️ RX Node (Arch Linux):${NC}"
echo "   - IP: Noch nicht konfiguriert"
echo "   - Rolle: AI Processing, Heavy Computing"
echo "   - MAC: 30:9c:23:5f:44:a8"
echo "   - Status: ⚠️ Tailscale Setup erforderlich"
echo ""

log "${BLUE}💻 I7 Laptop:${NC}"
echo "   - IP: Noch nicht konfiguriert"
echo "   - Rolle: Secondary Node, Development"
echo "   - Status: ⚠️ Tailscale Setup erforderlich"
echo ""

# Setup-Anweisungen
log "${PURPLE}🛠️ SETUP-ANWEISUNGEN:${NC}"
echo ""

log "${YELLOW}1. RX Node Tailscale Integration:${NC}"
echo "   a) SSH zur RX Node:"
echo "      ssh rx-node"
echo ""
echo "   b) Installiere Tailscale:"
echo "      sudo pacman -Sy"
echo "      sudo pacman -S tailscale"
echo "      sudo systemctl enable tailscaled"
echo "      sudo systemctl start tailscaled"
echo ""
echo "   c) Generiere Auth-Key:"
echo "      https://login.tailscale.com/admin/settings/keys"
echo ""
echo "   d) Verbinde mit Tailscale:"
echo "      sudo tailscale up --authkey='DEIN_KEY' --hostname='rx-node-archlinux'"
echo ""
echo "   e) Verification:"
echo "      ./verify_rx_tailscale.sh"
echo ""

log "${YELLOW}2. I7 Laptop Tailscale Integration:${NC}"
echo "   a) Führe Setup-Script aus:"
echo "      ./i7_tailscale_setup.sh"
echo ""
echo "   b) Folge den Anweisungen für Auth-Key"
echo ""

log "${YELLOW}3. Vollständige Mesh-Überprüfung:${NC}"
echo "   ./mesh_node_control.sh mesh"
echo ""

# Verfügbare Commands
log "${PURPLE}🎮 VERFÜGBARE COMMANDS:${NC}"
echo ""

log "${GREEN}Mesh Control:${NC}"
echo "   ./mesh_node_control.sh all status     - Status aller Nodes"
echo "   ./mesh_node_control.sh all ping       - Ping alle Nodes"
echo "   ./mesh_node_control.sh rx shutdown    - RX Node herunterfahren"
echo "   ./mesh_node_control.sh rx wakeup      - RX Node aufwecken"
echo "   ./mesh_node_control.sh rx ssh         - SSH zur RX Node"
echo ""

log "${GREEN}Setup & Verification:${NC}"
echo "   ./rx_node_tailscale_manual_setup.sh   - RX Node Setup-Anweisungen"
echo "   ./i7_tailscale_setup.sh               - I7 Laptop Setup"
echo "   ./verify_complete_mesh.sh             - Vollständige Mesh-Überprüfung"
echo "   ./verify_rx_tailscale.sh              - RX Node Verification"
echo ""

# Netzwerk-Modi
log "${PURPLE}🌐 NETZWERK-MODI:${NC}"
echo ""

log "${GREEN}Heimnetz-Modus:${NC}"
echo "   - Direkte SSH-Verbindungen"
echo "   - Lokale IP-Adressen (192.168.68.x)"
echo "   - Schnellste Verbindungen"
echo ""

log "${BLUE}Hotspot-Modus:${NC}"
echo "   - Tailscale Mesh-Verbindungen"
echo "   - Tailscale IPs (100.x.x.x)"
echo "   - Funktioniert überall"
echo ""

# Vorteile
log "${PURPLE}🎯 VORTEILE DES TAILSCALE MESH:${NC}"
echo ""
echo "   ✅ Keine Port-Forwarding erforderlich"
echo "   ✅ Funktioniert hinter CGNAT"
echo "   ✅ Ende-zu-Ende verschlüsselt"
echo "   ✅ Automatisches Routing"
echo "   ✅ Cross-Platform Support"
echo "   ✅ Kostenlos für bis zu 20 Geräte"
echo "   ✅ Einfache Verwaltung über Web-Interface"
echo ""

# Nächste Schritte
log "${PURPLE}🚀 NÄCHSTE SCHRITTE:${NC}"
echo ""
echo "1. RX Node Tailscale Setup durchführen"
echo "2. I7 Laptop integrieren (falls gewünscht)"
echo "3. Mesh-Verbindungen testen"
echo "4. AI-Services über Tailscale konfigurieren"
echo "5. Friend-Network erweitern (optional)"
echo ""

# Status-Check
log "${BLUE}📋 Aktueller Setup-Status:${NC}"
echo ""

# M1 Mac
if ping -c 1 -W 1 100.96.219.28 >/dev/null 2>&1; then
    log "${GREEN}✅ M1 Mac: Online und bereit${NC}"
else
    log "${YELLOW}⚠️ M1 Mac: Tailscale Status überprüfen${NC}"
fi

# iPhone
if ping -c 1 -W 1 100.123.55.36 >/dev/null 2>&1; then
    log "${GREEN}✅ iPhone: Online im Mesh${NC}"
else
    log "${YELLOW}⚠️ iPhone: Verbindung überprüfen${NC}"
fi

# RX Node
if ssh -o ConnectTimeout=2 rx-node "tailscale ip -4" >/dev/null 2>&1; then
    RX_IP=$(ssh rx-node "tailscale ip -4" 2>/dev/null)
    log "${GREEN}✅ RX Node: Tailscale aktiv ($RX_IP)${NC}"
else
    log "${RED}❌ RX Node: Tailscale Setup erforderlich${NC}"
fi

# I7 Laptop
CURRENT_IP=$(tailscale ip -4 2>/dev/null || echo "")
if [ "$CURRENT_IP" != "100.96.219.28" ] && [ -n "$CURRENT_IP" ]; then
    log "${GREEN}✅ I7 Laptop: Im Mesh integriert ($CURRENT_IP)${NC}"
else
    log "${YELLOW}⚠️ I7 Laptop: Setup erforderlich oder ist M1 Mac${NC}"
fi

echo ""
log "${PURPLE}🎉 GENTLEMAN Tailscale Mesh System bereit für den Einsatz!${NC}"
log "${BLUE}📱 Überprüfe auch https://login.tailscale.com/admin/machines${NC}" 