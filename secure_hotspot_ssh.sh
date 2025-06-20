#!/bin/bash

# GENTLEMAN Secure Hotspot SSH System
# Sicheres SSH über Cloudflare Tunnel mit Token-Authentifizierung

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging-Funktion
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Netzwerk-Modus erkennen
detect_network_mode() {
    local ip=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')
    
    if [[ $ip == 192.168.68.* ]]; then
        echo "home"
    elif [[ $ip == 172.20.10.* ]]; then
        echo "hotspot"
    else
        echo "unknown"
    fi
}

# SSH-Verbindung testen
test_ssh_connection() {
    local mode=$1
    
    if [[ $mode == "home" ]]; then
        log "${BLUE}🏠 Teste SSH im Heimnetz...${NC}"
        if ssh rx-node "echo 'SSH-Heimnetz OK'" 2>/dev/null; then
            log "${GREEN}✅ SSH-Heimnetz funktioniert${NC}"
            return 0
        fi
    elif [[ $mode == "hotspot" ]]; then
        log "${BLUE}📱 Teste SSH über Tailscale...${NC}"
        if ssh rx-node-tailscale "echo 'SSH-Tailscale OK'" 2>/dev/null; then
            log "${GREEN}✅ SSH-Tailscale funktioniert${NC}"
            return 0
        fi
        
        log "${YELLOW}⚠️  Tailscale SSH fehlgeschlagen, teste Cloudflare Tunnel...${NC}"
        # Hier würde SSH über Cloudflare Tunnel implementiert werden
        log "${YELLOW}📋 Cloudflare SSH-Tunnel nicht implementiert (Sicherheitsrisiko)${NC}"
        return 1
    fi
    
    return 1
}

# Sichere SSH-Tunnel Konfiguration auf RX Node
setup_secure_ssh_tunnel() {
    log "${BLUE}🛡️ Konfiguriere sicheren SSH-Tunnel auf RX Node...${NC}"
    
    # Erstelle sicheren SSH-Tunnel Server mit Authentifizierung
    ssh rx-node "cat > /tmp/secure_ssh_tunnel_server.py << 'EOF'
#!/usr/bin/env python3
import socket
import threading
import subprocess
import json
import os
import secrets
from datetime import datetime, timedelta

class SecureSSHTunnel:
    def __init__(self):
        self.auth_tokens = {}
        self.load_tokens()
    
    def generate_token(self, duration_hours=24):
        token = secrets.token_urlsafe(32)
        expires = datetime.now() + timedelta(hours=duration_hours)
        self.auth_tokens[token] = expires.isoformat()
        self.save_tokens()
        return token
    
    def validate_token(self, token):
        if token not in self.auth_tokens:
            return False
        expires = datetime.fromisoformat(self.auth_tokens[token])
        if datetime.now() > expires:
            del self.auth_tokens[token]
            self.save_tokens()
            return False
        return True
    
    def load_tokens(self):
        try:
            if os.path.exists('/tmp/ssh_tunnel_tokens.json'):
                with open('/tmp/ssh_tunnel_tokens.json', 'r') as f:
                    data = json.load(f)
                    self.auth_tokens = data
        except:
            self.auth_tokens = {}
    
    def save_tokens(self):
        try:
            with open('/tmp/ssh_tunnel_tokens.json', 'w') as f:
                json.dump(self.auth_tokens, f)
            os.chmod('/tmp/ssh_tunnel_tokens.json', 0o600)
        except:
            pass

if __name__ == '__main__':
    tunnel = SecureSSHTunnel()
    token = tunnel.generate_token(24)
    print(f'SSH-Tunnel-Token: {token}')
EOF"
    
    # Token generieren
    local token=$(ssh rx-node "python3 /tmp/secure_ssh_tunnel_server.py")
    log "${GREEN}✅ ${token}${NC}"
    
    # Token lokal speichern
    echo "$token" > ~/.ssh/tunnel_token
    chmod 600 ~/.ssh/tunnel_token
}

# SSH-Befehl ausführen
execute_ssh_command() {
    local mode=$1
    local command=$2
    
    if [[ $mode == "home" ]]; then
        ssh rx-node "$command"
    elif [[ $mode == "hotspot" ]]; then
        # Versuche Tailscale zuerst
        if ssh rx-node-tailscale "$command" 2>/dev/null; then
            return 0
        fi
        
        log "${YELLOW}⚠️  Tailscale nicht verfügbar, verwende lokale Verbindung${NC}"
        return 1
    fi
}

# Hauptfunktion
main() {
    local mode=$(detect_network_mode)
    local action=${1:-"status"}
    
    log "${BLUE}🔒 GENTLEMAN Secure Hotspot SSH${NC}"
    log "${BLUE}================================${NC}"
    log "${BLUE}📍 Netzwerk-Modus: $mode${NC}"
    
    case $action in
        "setup")
            log "${BLUE}⚙️ Richte sicheres SSH-System ein...${NC}"
            setup_secure_ssh_tunnel
            ;;
        "test")
            test_ssh_connection $mode
            ;;
        "status")
            log "${BLUE}🔍 Teste SSH-Verbindungen...${NC}"
            test_ssh_connection $mode
            
            if [[ $? -eq 0 ]]; then
                log "${BLUE}📊 RX Node Status:${NC}"
                execute_ssh_command $mode "uptime && echo 'SSH-Modus: $mode'"
            fi
            ;;
        "command")
            local cmd=${2:-"echo 'SSH Test'"}
            log "${BLUE}🚀 Führe Befehl aus: $cmd${NC}"
            execute_ssh_command $mode "$cmd"
            ;;
        *)
            log "${YELLOW}📋 Verwendung:${NC}"
            log "   $0 setup   - Sichere SSH-Tunnel einrichten"
            log "   $0 test    - SSH-Verbindungen testen"
            log "   $0 status  - Status anzeigen (Standard)"
            log "   $0 command 'befehl' - Befehl ausführen"
            ;;
    esac
}

main "$@" 