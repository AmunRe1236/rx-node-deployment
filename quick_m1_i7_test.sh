#!/bin/bash

# GENTLEMAN M1 ↔ I7 Quick Back-to-Back Test
# Kompakter Test für die Konnektivität zwischen M1 und I7

echo "🔗 GENTLEMAN M1 ↔ I7 Quick Test"
echo "================================"

# Konfiguration
M1_IP="192.168.68.111"
I7_IP="192.168.68.105"
M1_VPN="192.168.100.1"
I7_VPN="192.168.100.30"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️ $1${NC}"; }

echo ""
info "Teste Basis-Netzwerk Konnektivität..."

# Basis Netzwerk Tests
if ping -c 1 -W 3000 $M1_IP > /dev/null 2>&1; then
    success "M1 Mac ($M1_IP) erreichbar"
else
    error "M1 Mac ($M1_IP) nicht erreichbar"
fi

if ping -c 1 -W 3000 $I7_IP > /dev/null 2>&1; then
    success "I7 Node ($I7_IP) erreichbar"
else
    error "I7 Node ($I7_IP) nicht erreichbar"
fi

echo ""
info "Teste VPN Konnektivität..."

# VPN Tests (falls aktiv)
if ifconfig | grep -q "192.168.100" > /dev/null 2>&1; then
    success "Nebula VPN Interface gefunden"
    
    if ping -c 1 -W 3000 $M1_VPN > /dev/null 2>&1; then
        success "M1 VPN ($M1_VPN) erreichbar"
    else
        warning "M1 VPN ($M1_VPN) nicht erreichbar"
    fi
    
    if ping -c 1 -W 3000 $I7_VPN > /dev/null 2>&1; then
        success "I7 VPN ($I7_VPN) erreichbar"
    else
        warning "I7 VPN ($I7_VPN) nicht erreichbar"
    fi
else
    warning "Nebula VPN Interface nicht aktiv"
fi

echo ""
info "Teste Git Services..."

# Git Daemon Tests
if nc -z -w 3 localhost 9418 2>/dev/null; then
    success "Git Daemon (localhost:9418) erreichbar"
    
    if timeout 10 git ls-remote git://localhost:9418/Gentleman > /dev/null 2>&1; then
        success "Git Repository Zugriff funktioniert"
    else
        warning "Git Repository Zugriff fehlgeschlagen"
    fi
else
    error "Git Daemon (localhost:9418) nicht erreichbar"
fi

if nc -z -w 3 $M1_IP 9418 2>/dev/null; then
    success "Git Daemon ($M1_IP:9418) erreichbar"
else
    warning "Git Daemon ($M1_IP:9418) nicht erreichbar (normal bei localhost-only)"
fi

echo ""
info "Teste Handshake Services..."

# Handshake Server Tests
if nc -z -w 3 $M1_IP 8765 2>/dev/null; then
    success "Handshake Server ($M1_IP:8765) erreichbar"
    
    if curl -s -f --max-time 5 http://$M1_IP:8765/health > /dev/null 2>&1; then
        success "Handshake Server API funktioniert"
    else
        warning "Handshake Server API nicht erreichbar"
    fi
else
    error "Handshake Server ($M1_IP:8765) nicht erreichbar"
fi

echo ""
info "Teste Docker Services..."

# Docker Tests
if command -v docker > /dev/null 2>&1; then
    if docker ps > /dev/null 2>&1; then
        success "Docker läuft"
        
        if docker ps --format "{{.Names}}" | grep -q "gentleman-git-server" 2>/dev/null; then
            success "Gitea Container läuft"
        else
            warning "Gitea Container nicht gefunden"
        fi
    else
        warning "Docker Daemon nicht erreichbar"
    fi
else
    warning "Docker nicht installiert"
fi

# Gitea Web Interface Test
if nc -z -w 3 localhost 3010 2>/dev/null; then
    success "Gitea Webserver (localhost:3010) erreichbar"
else
    warning "Gitea Webserver (localhost:3010) nicht erreichbar"
fi

echo ""
info "Teste I7 Sync Scripts..."

# I7 Sync Scripts
if [ -f "i7_gitea_sync_client.py" ]; then
    success "I7 Sync Client verfügbar"
else
    warning "I7 Sync Client nicht gefunden"
fi

if [ -f "start_i7_sync.sh" ]; then
    success "I7 Sync Starter verfügbar"
else
    warning "I7 Sync Starter nicht gefunden"
fi

echo ""
info "Simuliere Handshake Request..."

# Simuliere I7 Handshake
if nc -z -w 3 $M1_IP 8765 2>/dev/null; then
    handshake_data='{"node_id":"i7-test","ip":"'$I7_IP'","vpn_ip":"'$I7_VPN'","status":"testing"}'
    
    response=$(curl -s --max-time 5 -X POST \
        -H "Content-Type: application/json" \
        -d "$handshake_data" \
        http://$M1_IP:8765/handshake 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        success "Handshake Request erfolgreich"
        info "Response: $response"
    else
        warning "Handshake Request fehlgeschlagen"
    fi
fi

echo ""
echo "🎯 M1 ↔ I7 Back-to-Back Test abgeschlossen!"
echo ""
info "📋 Zusammenfassung:"
info "   • Lokale Netzwerk-Konnektivität getestet"
info "   • VPN-Konnektivität geprüft (falls aktiv)"
info "   • Git Daemon Service getestet"
info "   • Handshake System getestet"
info "   • Docker/Gitea Services geprüft"
info "   • I7 Sync Scripts verifiziert"
echo ""
info "🚀 Nächste Schritte:"
info "   • Für I7 Node: ./i7_connection_test.sh"
info "   • Für VPN Setup: Nebula VPN konfigurieren"
info "   • Für Git extern: Git Daemon auf 0.0.0.0 binden" 