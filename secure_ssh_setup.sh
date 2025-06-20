#!/bin/bash

# GENTLEMAN Secure SSH Setup
# Erstellt sichere SSH-Verbindungen mit neuen Keys und Authentifizierung

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

log "${BLUE}🔒 GENTLEMAN Secure SSH Setup${NC}"
log "${BLUE}=================================${NC}"

# Backup alte Keys
BACKUP_DIR="$HOME/.ssh/backup_$(date +%Y%m%d_%H%M%S)"
log "${YELLOW}📦 Erstelle Backup der alten SSH-Keys...${NC}"
mkdir -p "$BACKUP_DIR"
cp -r ~/.ssh/* "$BACKUP_DIR/" 2>/dev/null || true

# Neue sichere SSH-Keys generieren
log "${BLUE}🔑 Generiere neue sichere SSH-Keys...${NC}"
ssh-keygen -t ed25519 -f ~/.ssh/gentleman_secure -N "" -C "gentleman-secure-$(date +%Y%m%d)"

# Neue Konfiguration erstellen
log "${BLUE}⚙️ Erstelle sichere SSH-Konfiguration...${NC}"
cat > ~/.ssh/config << 'EOF'
# GENTLEMAN Secure SSH Configuration
Host rx-node
    HostName 192.168.68.117
    User amo9n11
    Port 22
    IdentityFile ~/.ssh/gentleman_secure
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ConnectTimeout 10

# Tailscale RX Node (für Hotspot-Modus)
Host rx-node-tailscale
    HostName 100.96.219.28
    User amo9n11
    Port 22
    IdentityFile ~/.ssh/gentleman_secure
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ConnectTimeout 10
EOF

# SSH-Key auf RX Node kopieren
log "${BLUE}🚀 Kopiere SSH-Key auf RX Node...${NC}"
if ssh-copy-id -i ~/.ssh/gentleman_secure.pub amo9n11@192.168.68.117; then
    log "${GREEN}✅ SSH-Key erfolgreich kopiert${NC}"
else
    log "${RED}❌ SSH-Key kopieren fehlgeschlagen${NC}"
    exit 1
fi

# SSH-Verbindung testen
log "${BLUE}🔍 Teste SSH-Verbindung...${NC}"
if ssh rx-node "echo 'SSH-Verbindung erfolgreich'"; then
    log "${GREEN}✅ SSH-Verbindung funktioniert${NC}"
else
    log "${RED}❌ SSH-Verbindung fehlgeschlagen${NC}"
    exit 1
fi

# Sichere Tunnel-Konfiguration erstellen
log "${BLUE}🛡️ Erstelle sichere Tunnel-Konfiguration...${NC}"
cat > secure_tunnel_config.py << 'EOF'
#!/usr/bin/env python3
"""
GENTLEMAN Secure Tunnel Configuration
Authentifizierte SSH-Tunnel mit Token-basierter Sicherheit
"""

import os
import secrets
import hashlib
import json
from datetime import datetime, timedelta

class SecureTunnelAuth:
    def __init__(self):
        self.token_file = "/tmp/gentleman_tunnel_tokens.json"
        self.valid_tokens = {}
        self.load_tokens()
    
    def generate_token(self, duration_hours=24):
        """Generiert einen sicheren Token mit Ablaufzeit"""
        token = secrets.token_urlsafe(32)
        expires = datetime.now() + timedelta(hours=duration_hours)
        
        self.valid_tokens[token] = {
            "expires": expires.isoformat(),
            "created": datetime.now().isoformat()
        }
        
        self.save_tokens()
        return token
    
    def validate_token(self, token):
        """Validiert einen Token"""
        if token not in self.valid_tokens:
            return False
        
        expires = datetime.fromisoformat(self.valid_tokens[token]["expires"])
        if datetime.now() > expires:
            del self.valid_tokens[token]
            self.save_tokens()
            return False
        
        return True
    
    def load_tokens(self):
        """Lädt Tokens aus Datei"""
        try:
            if os.path.exists(self.token_file):
                with open(self.token_file, 'r') as f:
                    self.valid_tokens = json.load(f)
        except:
            self.valid_tokens = {}
    
    def save_tokens(self):
        """Speichert Tokens in Datei"""
        try:
            with open(self.token_file, 'w') as f:
                json.dump(self.valid_tokens, f, indent=2)
            os.chmod(self.token_file, 0o600)
        except:
            pass

# Token generieren für aktuellen Benutzer
if __name__ == "__main__":
    auth = SecureTunnelAuth()
    token = auth.generate_token(24)
    print(f"Neuer Tunnel-Token (24h gültig): {token}")
EOF

# Sicherheits-Audit durchführen
log "${BLUE}🔍 Führe Sicherheits-Audit durch...${NC}"
cat > security_audit.sh << 'EOF'
#!/bin/bash

echo "🔒 GENTLEMAN Security Audit"
echo "=========================="

echo "SSH-Key Permissions:"
ls -la ~/.ssh/gentleman_secure*

echo -e "\nSSH-Konfiguration:"
cat ~/.ssh/config | grep -A 10 "rx-node"

echo -e "\nRX Node offene Ports:"
ssh rx-node "netstat -tlnp 2>/dev/null | grep LISTEN" || echo "SSH-Verbindung fehlgeschlagen"

echo -e "\nLaufende Tunnel-Services:"
ssh rx-node "ps aux | grep -E '(cloudflared|python.*tunnel)' | grep -v grep" || echo "SSH-Verbindung fehlgeschlagen"
EOF

chmod +x security_audit.sh

# Sichere Permissions setzen
log "${BLUE}🔐 Setze sichere Permissions...${NC}"
chmod 600 ~/.ssh/gentleman_secure
chmod 644 ~/.ssh/gentleman_secure.pub
chmod 600 ~/.ssh/config
chmod +x secure_tunnel_config.py

log "${GREEN}✅ Secure SSH Setup abgeschlossen!${NC}"
log "${BLUE}📋 Nächste Schritte:${NC}"
log "   1. Teste SSH: ssh rx-node"
log "   2. Führe Audit aus: ./security_audit.sh"
log "   3. Generiere Tunnel-Token: python3 secure_tunnel_config.py"
log "${YELLOW}⚠️  Backup der alten Keys: $BACKUP_DIR${NC}" 