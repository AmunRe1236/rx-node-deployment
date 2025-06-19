#!/bin/bash

# GENTLEMAN Cluster - I7 Sync Start Script
# Startet den Gitea Sync Client für den I7 Node

set -e

echo "🚀 GENTLEMAN I7 Gitea Sync Client Starter"
echo "=========================================="

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Basis-Verzeichnis
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Log-Funktion
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Prüfe Python Installation
log "🐍 Prüfe Python Installation..."
if ! command -v python3 &> /dev/null; then
    error "Python3 nicht gefunden!"
    exit 1
fi

# Prüfe Git Installation
log "📦 Prüfe Git Installation..."
if ! command -v git &> /dev/null; then
    error "Git nicht gefunden!"
    exit 1
fi

# Installiere Python Dependencies
log "📥 Installiere Python Dependencies..."
if [ -f "requirements.txt" ]; then
    pip3 install -r requirements.txt > /dev/null 2>&1 || {
        warning "Einige Dependencies konnten nicht installiert werden"
    }
fi

# Prüfe ob Sync Client existiert
if [ ! -f "i7_gitea_sync_client.py" ]; then
    error "i7_gitea_sync_client.py nicht gefunden!"
    exit 1
fi

# Mache Python-Skript ausführbar
chmod +x i7_gitea_sync_client.py

# Test Konnektivität zum M1 Mac
log "🔗 Teste Konnektivität zum M1 Mac (192.168.68.111)..."
if ping -c 1 192.168.68.111 > /dev/null 2>&1; then
    success "✅ M1 Mac erreichbar"
else
    warning "⚠️ M1 Mac nicht erreichbar - starte trotzdem (Retry-Mechanismus aktiv)"
fi

# Stoppe eventuell laufende Sync Clients
log "🛑 Stoppe alte Sync Client Instanzen..."
pkill -f "i7_gitea_sync_client.py" 2>/dev/null || true

# Starte Sync Client
log "🚀 Starte I7 Gitea Sync Client..."

# Option für einmaligen Sync
if [ "$1" = "--once" ]; then
    log "▶️ Einmaliger Sync wird ausgeführt..."
    python3 i7_gitea_sync_client.py --once
    exit $?
fi

# Option für Daemon Mode
if [ "$1" = "--daemon" ]; then
    log "👹 Starte Sync Client als Daemon..."
    nohup python3 i7_gitea_sync_client.py > /tmp/i7_sync_daemon.log 2>&1 &
    SYNC_PID=$!
    echo $SYNC_PID > /tmp/i7_sync.pid
    success "✅ Sync Client gestartet (PID: $SYNC_PID)"
    success "📄 Logs: /tmp/i7_sync_daemon.log"
    exit 0
fi

# Standard: Interaktiver Modus
log "🖥️ Starte Sync Client im interaktiven Modus..."
log "💡 Drücke Ctrl+C zum Beenden"
echo ""

python3 i7_gitea_sync_client.py

success "✅ Sync Client beendet" 