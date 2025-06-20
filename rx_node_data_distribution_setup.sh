#!/bin/bash

# 🎯 RX NODE DATENVERTEILUNG SETUP
# =================================
# Optimale Lösung für RX Node Datenzugriff via M1 Mac Hub

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M1_HOST="192.168.68.111"
OBSIDIAN_SYNC_PORT="3030"
GIT_DAEMON_PORT="9418"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_info() {
    log "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    log "${GREEN}✅ $1${NC}"
}

log_error() {
    log "${RED}❌ $1${NC}"
}

# 1. M1 Mac als zentraler Daten-Hub einrichten
setup_m1_data_hub() {
    log_info "🖥️ Richte M1 Mac als zentralen Daten-Hub ein..."
    
    # Obsidian Sync Container auf M1 starten
    ssh amonbaumgartner@$M1_HOST "cd /Users/amonbaumgartner/Gentleman && docker run -d \
        --name obsidian-sync \
        --restart unless-stopped \
        -p $OBSIDIAN_SYNC_PORT:3000 \
        -v /Users/amonbaumgartner/Documents/Obsidian:/app/data \
        -v /Users/amonbaumgartner/Gentleman:/app/gentleman \
        --network host \
        nginx:alpine || echo 'Container bereits vorhanden'"
    
    # Git Daemon für Repository-Sync
    ssh amonbaumgartner@$M1_HOST "cd /Users/amonbaumgartner/Gentleman && \
        git daemon --reuseaddr --base-path=. --export-all --verbose --enable=receive-pack --port=$GIT_DAEMON_PORT &"
    
    log_success "M1 Daten-Hub konfiguriert"
}

# 2. Obsidian Ordner auf M1 synchronisieren
sync_obsidian_to_m1() {
    log_info "📂 Synchronisiere Obsidian Daten zum M1 Mac..."
    
    # Prüfe lokale Obsidian Ordner
    local obsidian_dirs=(
        "$HOME/Documents/Obsidian"
        "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
        "$HOME/Desktop/Obsidian"
    )
    
    for dir in "${obsidian_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "Gefunden: $dir"
            
            # Synchronisiere zu M1
            rsync -avz --progress "$dir/" amonbaumgartner@$M1_HOST:/Users/amonbaumgartner/Documents/Obsidian/
            log_success "Obsidian Daten zu M1 synchronisiert"
            return 0
        fi
    done
    
    log_error "Kein Obsidian Ordner gefunden"
    return 1
}

# 3. Gentleman Repository erweitern
extend_gentleman_repo() {
    log_info "📦 Erweitere Gentleman Repository für RX Node Zugriff..."
    
    # Erstelle Datenverzeichnisse
    mkdir -p data/{obsidian,shared,rx-cache}
    
    # .gitignore für Daten anpassen
    cat >> .gitignore << 'EOF'

# RX Node Daten
data/obsidian/
data/rx-cache/
*.log
*.pid
EOF

    # RX Node Daten-Sync Script
    cat > rx_data_sync.py << 'EOF'
#!/usr/bin/env python3
"""
RX Node Daten-Synchronisation
Holt Daten vom M1 Mac Hub
"""

import requests
import json
import os
import subprocess
from pathlib import Path

class RXDataSync:
    def __init__(self):
        self.m1_host = "192.168.68.111"
        self.handshake_port = 8765
        self.obsidian_port = 3030
        self.data_dir = Path("data")
        
    def sync_from_m1(self):
        """Synchronisiere alle Daten vom M1 Hub"""
        try:
            # 1. Repository Updates
            subprocess.run(['git', 'pull', f'git://{self.m1_host}:9418/'], check=True)
            
            # 2. Obsidian Daten (falls verfügbar)
            self._sync_obsidian_data()
            
            # 3. Handshake Status
            self._get_cluster_status()
            
            return True
        except Exception as e:
            print(f"Sync Fehler: {e}")
            return False
    
    def _sync_obsidian_data(self):
        """Synchronisiere Obsidian Daten"""
        try:
            # rsync von M1
            subprocess.run([
                'rsync', '-avz', '--delete',
                f'amonbaumgartner@{self.m1_host}:/Users/amonbaumgartner/Documents/Obsidian/',
                'data/obsidian/'
            ], check=True)
            print("✅ Obsidian Daten synchronisiert")
        except:
            print("⚠️ Obsidian Sync nicht verfügbar")
    
    def _get_cluster_status(self):
        """Hole Cluster Status"""
        try:
            response = requests.get(f"http://{self.m1_host}:{self.handshake_port}/status")
            status = response.json()
            
            with open('data/cluster_status.json', 'w') as f:
                json.dump(status, f, indent=2)
            
            print("✅ Cluster Status aktualisiert")
        except:
            print("⚠️ Cluster Status nicht verfügbar")

if __name__ == "__main__":
    sync = RXDataSync()
    sync.sync_from_m1()
EOF

    chmod +x rx_data_sync.py
    log_success "Repository für RX Node erweitert"
}

# 4. Docker-basierte Datenverteilung (Alternative)
setup_docker_data_distribution() {
    log_info "🐳 Richte Docker-basierte Datenverteilung ein..."
    
    # Docker Compose für Datenverteilung
    cat > docker-compose.data-sync.yml << 'EOF'
version: '3.8'

services:
  gentleman-data-hub:
    image: nginx:alpine
    container_name: gentleman-data-hub
    ports:
      - "8080:80"
    volumes:
      - ./data:/usr/share/nginx/html/data:ro
      - ./:/usr/share/nginx/html/repo:ro
    environment:
      - NGINX_HOST=0.0.0.0
      - NGINX_PORT=80
    restart: unless-stopped
    
  obsidian-sync:
    image: linuxserver/obsidian
    container_name: obsidian-sync
    ports:
      - "3030:3000"
    volumes:
      - ./data/obsidian:/config
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    restart: unless-stopped
    
  git-server:
    image: gitea/gitea:latest
    container_name: git-server
    ports:
      - "3010:3000"
      - "2222:22"
    volumes:
      - ./data/git:/data
      - ./:/data/git/repositories/gentleman
    environment:
      - USER_UID=1000
      - USER_GID=1000
    restart: unless-stopped
EOF

    log_success "Docker Datenverteilung konfiguriert"
}

# 5. RX Node Zugriffs-Script
create_rx_access_script() {
    log_info "📡 Erstelle RX Node Zugriffs-Script..."
    
    cat > rx_node_access.sh << 'EOF'
#!/bin/bash

# 🚀 RX NODE ZUGRIFF
# ==================
# Zugriff auf alle Gentleman Daten via M1 Hub

M1_HOST="192.168.68.111"
VPN_IP="10.0.0.1"

echo "🎯 RX NODE DATEN-ZUGRIFF"
echo "========================"

# 1. Verbindungstest
echo "🔍 Teste Verbindung..."
if ping -c 1 $M1_HOST > /dev/null 2>&1; then
    echo "✅ M1 Mac erreichbar (LAN)"
    HOST=$M1_HOST
elif ping -c 1 $VPN_IP > /dev/null 2>&1; then
    echo "✅ M1 Mac erreichbar (VPN)"
    HOST=$VPN_IP
else
    echo "❌ M1 Mac nicht erreichbar"
    exit 1
fi

# 2. Verfügbare Services
echo ""
echo "📊 Verfügbare Services:"
echo "  • Handshake Server: http://$HOST:8765"
echo "  • Obsidian Sync: http://$HOST:3030"
echo "  • Git Daemon: git://$HOST:9418"
echo "  • Daten Hub: http://$HOST:8080"

# 3. Daten synchronisieren
echo ""
echo "🔄 Synchronisiere Daten..."
python3 rx_data_sync.py

# 4. Status anzeigen
echo ""
echo "📈 Cluster Status:"
curl -s http://$HOST:8765/status | python3 -m json.tool 2>/dev/null || echo "Status nicht verfügbar"

echo ""
echo "✅ RX Node Zugriff bereit!"
EOF

    chmod +x rx_node_access.sh
    log_success "RX Node Zugriffs-Script erstellt"
}

# Hauptfunktion
main() {
    echo "🎯 RX NODE DATENVERTEILUNG SETUP"
    echo "================================="
    echo ""
    
    log_info "Wähle Setup-Option:"
    echo "1) Komplettes Setup (empfohlen)"
    echo "2) Nur M1 Daten-Hub"
    echo "3) Nur Docker-basiert"
    echo "4) Nur RX Zugriffs-Scripts"
    
    read -p "Option (1-4): " choice
    
    case $choice in
        1)
            setup_m1_data_hub
            sync_obsidian_to_m1
            extend_gentleman_repo
            setup_docker_data_distribution
            create_rx_access_script
            ;;
        2)
            setup_m1_data_hub
            sync_obsidian_to_m1
            ;;
        3)
            setup_docker_data_distribution
            ;;
        4)
            create_rx_access_script
            ;;
        *)
            log_error "Ungültige Option"
            exit 1
            ;;
    esac
    
    echo ""
    log_success "🎉 RX Node Datenverteilung Setup abgeschlossen!"
    echo ""
    echo "📋 Nächste Schritte:"
    echo "  1. RX Node: ./rx_node_access.sh ausführen"
    echo "  2. Obsidian: http://$M1_HOST:3030 öffnen"
    echo "  3. Cluster: http://$M1_HOST:8765/status prüfen"
}

# Script ausführen
main "$@" 

# 🎯 RX NODE DATENVERTEILUNG SETUP
# =================================
# Optimale Lösung für RX Node Datenzugriff via M1 Mac Hub

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M1_HOST="192.168.68.111"
OBSIDIAN_SYNC_PORT="3030"
GIT_DAEMON_PORT="9418"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_info() {
    log "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    log "${GREEN}✅ $1${NC}"
}

log_error() {
    log "${RED}❌ $1${NC}"
}

# 1. M1 Mac als zentraler Daten-Hub einrichten
setup_m1_data_hub() {
    log_info "🖥️ Richte M1 Mac als zentralen Daten-Hub ein..."
    
    # Obsidian Sync Container auf M1 starten
    ssh amonbaumgartner@$M1_HOST "cd /Users/amonbaumgartner/Gentleman && docker run -d \
        --name obsidian-sync \
        --restart unless-stopped \
        -p $OBSIDIAN_SYNC_PORT:3000 \
        -v /Users/amonbaumgartner/Documents/Obsidian:/app/data \
        -v /Users/amonbaumgartner/Gentleman:/app/gentleman \
        --network host \
        nginx:alpine || echo 'Container bereits vorhanden'"
    
    # Git Daemon für Repository-Sync
    ssh amonbaumgartner@$M1_HOST "cd /Users/amonbaumgartner/Gentleman && \
        git daemon --reuseaddr --base-path=. --export-all --verbose --enable=receive-pack --port=$GIT_DAEMON_PORT &"
    
    log_success "M1 Daten-Hub konfiguriert"
}

# 2. Obsidian Ordner auf M1 synchronisieren
sync_obsidian_to_m1() {
    log_info "📂 Synchronisiere Obsidian Daten zum M1 Mac..."
    
    # Prüfe lokale Obsidian Ordner
    local obsidian_dirs=(
        "$HOME/Documents/Obsidian"
        "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
        "$HOME/Desktop/Obsidian"
    )
    
    for dir in "${obsidian_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "Gefunden: $dir"
            
            # Synchronisiere zu M1
            rsync -avz --progress "$dir/" amonbaumgartner@$M1_HOST:/Users/amonbaumgartner/Documents/Obsidian/
            log_success "Obsidian Daten zu M1 synchronisiert"
            return 0
        fi
    done
    
    log_error "Kein Obsidian Ordner gefunden"
    return 1
}

# 3. Gentleman Repository erweitern
extend_gentleman_repo() {
    log_info "📦 Erweitere Gentleman Repository für RX Node Zugriff..."
    
    # Erstelle Datenverzeichnisse
    mkdir -p data/{obsidian,shared,rx-cache}
    
    # .gitignore für Daten anpassen
    cat >> .gitignore << 'EOF'

# RX Node Daten
data/obsidian/
data/rx-cache/
*.log
*.pid
EOF

    # RX Node Daten-Sync Script
    cat > rx_data_sync.py << 'EOF'
#!/usr/bin/env python3
"""
RX Node Daten-Synchronisation
Holt Daten vom M1 Mac Hub
"""

import requests
import json
import os
import subprocess
from pathlib import Path

class RXDataSync:
    def __init__(self):
        self.m1_host = "192.168.68.111"
        self.handshake_port = 8765
        self.obsidian_port = 3030
        self.data_dir = Path("data")
        
    def sync_from_m1(self):
        """Synchronisiere alle Daten vom M1 Hub"""
        try:
            # 1. Repository Updates
            subprocess.run(['git', 'pull', f'git://{self.m1_host}:9418/'], check=True)
            
            # 2. Obsidian Daten (falls verfügbar)
            self._sync_obsidian_data()
            
            # 3. Handshake Status
            self._get_cluster_status()
            
            return True
        except Exception as e:
            print(f"Sync Fehler: {e}")
            return False
    
    def _sync_obsidian_data(self):
        """Synchronisiere Obsidian Daten"""
        try:
            # rsync von M1
            subprocess.run([
                'rsync', '-avz', '--delete',
                f'amonbaumgartner@{self.m1_host}:/Users/amonbaumgartner/Documents/Obsidian/',
                'data/obsidian/'
            ], check=True)
            print("✅ Obsidian Daten synchronisiert")
        except:
            print("⚠️ Obsidian Sync nicht verfügbar")
    
    def _get_cluster_status(self):
        """Hole Cluster Status"""
        try:
            response = requests.get(f"http://{self.m1_host}:{self.handshake_port}/status")
            status = response.json()
            
            with open('data/cluster_status.json', 'w') as f:
                json.dump(status, f, indent=2)
            
            print("✅ Cluster Status aktualisiert")
        except:
            print("⚠️ Cluster Status nicht verfügbar")

if __name__ == "__main__":
    sync = RXDataSync()
    sync.sync_from_m1()
EOF

    chmod +x rx_data_sync.py
    log_success "Repository für RX Node erweitert"
}

# 4. Docker-basierte Datenverteilung (Alternative)
setup_docker_data_distribution() {
    log_info "🐳 Richte Docker-basierte Datenverteilung ein..."
    
    # Docker Compose für Datenverteilung
    cat > docker-compose.data-sync.yml << 'EOF'
version: '3.8'

services:
  gentleman-data-hub:
    image: nginx:alpine
    container_name: gentleman-data-hub
    ports:
      - "8080:80"
    volumes:
      - ./data:/usr/share/nginx/html/data:ro
      - ./:/usr/share/nginx/html/repo:ro
    environment:
      - NGINX_HOST=0.0.0.0
      - NGINX_PORT=80
    restart: unless-stopped
    
  obsidian-sync:
    image: linuxserver/obsidian
    container_name: obsidian-sync
    ports:
      - "3030:3000"
    volumes:
      - ./data/obsidian:/config
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    restart: unless-stopped
    
  git-server:
    image: gitea/gitea:latest
    container_name: git-server
    ports:
      - "3010:3000"
      - "2222:22"
    volumes:
      - ./data/git:/data
      - ./:/data/git/repositories/gentleman
    environment:
      - USER_UID=1000
      - USER_GID=1000
    restart: unless-stopped
EOF

    log_success "Docker Datenverteilung konfiguriert"
}

# 5. RX Node Zugriffs-Script
create_rx_access_script() {
    log_info "📡 Erstelle RX Node Zugriffs-Script..."
    
    cat > rx_node_access.sh << 'EOF'
#!/bin/bash

# 🚀 RX NODE ZUGRIFF
# ==================
# Zugriff auf alle Gentleman Daten via M1 Hub

M1_HOST="192.168.68.111"
VPN_IP="10.0.0.1"

echo "🎯 RX NODE DATEN-ZUGRIFF"
echo "========================"

# 1. Verbindungstest
echo "🔍 Teste Verbindung..."
if ping -c 1 $M1_HOST > /dev/null 2>&1; then
    echo "✅ M1 Mac erreichbar (LAN)"
    HOST=$M1_HOST
elif ping -c 1 $VPN_IP > /dev/null 2>&1; then
    echo "✅ M1 Mac erreichbar (VPN)"
    HOST=$VPN_IP
else
    echo "❌ M1 Mac nicht erreichbar"
    exit 1
fi

# 2. Verfügbare Services
echo ""
echo "📊 Verfügbare Services:"
echo "  • Handshake Server: http://$HOST:8765"
echo "  • Obsidian Sync: http://$HOST:3030"
echo "  • Git Daemon: git://$HOST:9418"
echo "  • Daten Hub: http://$HOST:8080"

# 3. Daten synchronisieren
echo ""
echo "🔄 Synchronisiere Daten..."
python3 rx_data_sync.py

# 4. Status anzeigen
echo ""
echo "📈 Cluster Status:"
curl -s http://$HOST:8765/status | python3 -m json.tool 2>/dev/null || echo "Status nicht verfügbar"

echo ""
echo "✅ RX Node Zugriff bereit!"
EOF

    chmod +x rx_node_access.sh
    log_success "RX Node Zugriffs-Script erstellt"
}

# Hauptfunktion
main() {
    echo "🎯 RX NODE DATENVERTEILUNG SETUP"
    echo "================================="
    echo ""
    
    log_info "Wähle Setup-Option:"
    echo "1) Komplettes Setup (empfohlen)"
    echo "2) Nur M1 Daten-Hub"
    echo "3) Nur Docker-basiert"
    echo "4) Nur RX Zugriffs-Scripts"
    
    read -p "Option (1-4): " choice
    
    case $choice in
        1)
            setup_m1_data_hub
            sync_obsidian_to_m1
            extend_gentleman_repo
            setup_docker_data_distribution
            create_rx_access_script
            ;;
        2)
            setup_m1_data_hub
            sync_obsidian_to_m1
            ;;
        3)
            setup_docker_data_distribution
            ;;
        4)
            create_rx_access_script
            ;;
        *)
            log_error "Ungültige Option"
            exit 1
            ;;
    esac
    
    echo ""
    log_success "🎉 RX Node Datenverteilung Setup abgeschlossen!"
    echo ""
    echo "📋 Nächste Schritte:"
    echo "  1. RX Node: ./rx_node_access.sh ausführen"
    echo "  2. Obsidian: http://$M1_HOST:3030 öffnen"
    echo "  3. Cluster: http://$M1_HOST:8765/status prüfen"
}

# Script ausführen
main "$@" 
 