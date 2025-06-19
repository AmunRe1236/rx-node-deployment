#!/bin/bash

# GENTLEMAN Cluster - M1 Handshake Server Starter
# Startet den Handshake Koordinations-Server auf dem M1 Mac

set -e

echo "🤝 GENTLEMAN M1 Handshake Server Starter"
echo "========================================"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Basis-Verzeichnis
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Log-Funktionen
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

# Installiere Python Dependencies
log "📥 Installiere Python Dependencies..."
if [ -f "requirements.txt" ]; then
    pip3 install -r requirements.txt > /dev/null 2>&1 || {
        warning "Einige Dependencies konnten nicht installiert werden"
    }
fi

# Prüfe ob Handshake Server existiert
if [ ! -f "m1_handshake_server.py" ]; then
    error "m1_handshake_server.py nicht gefunden!"
    exit 1
fi

# Mache Python-Skript ausführbar
chmod +x m1_handshake_server.py

# Stoppe eventuell laufende Handshake Server
log "🛑 Stoppe alte Handshake Server Instanzen..."
pkill -f "m1_handshake_server.py" 2>/dev/null || true

# Warte kurz
sleep 2

# Server Konfiguration
SERVER_HOST="0.0.0.0"
SERVER_PORT="8765"

# Option für Daemon Mode
if [ "$1" = "--daemon" ]; then
    log "👹 Starte Handshake Server als Daemon..."
    nohup python3 m1_handshake_server.py --host "$SERVER_HOST" --port "$SERVER_PORT" > /tmp/m1_handshake_daemon.log 2>&1 &
    SERVER_PID=$!
    echo $SERVER_PID > /tmp/m1_handshake.pid
    success "✅ Handshake Server gestartet (PID: $SERVER_PID)"
    success "📄 Logs: /tmp/m1_handshake_daemon.log"
    success "🌐 Server läuft auf: http://$SERVER_HOST:$SERVER_PORT"
    
    # Kurzer Test der Endpoints
    sleep 3
    log "🧪 Teste Server Endpoints..."
    
    if curl -s "http://localhost:$SERVER_PORT/health" > /dev/null; then
        success "✅ Health Check erfolgreich"
    else
        warning "⚠️ Health Check fehlgeschlagen"
    fi
    
    echo ""
    success "🎯 Handshake Server bereit für Cluster-Kommunikation!"
    echo ""
    echo "Verfügbare Endpoints:"
    echo "  • POST http://localhost:$SERVER_PORT/handshake - Node Registrierung"
    echo "  • GET  http://localhost:$SERVER_PORT/status    - Cluster Status"
    echo "  • GET  http://localhost:$SERVER_PORT/nodes     - Aktive Nodes"
    echo "  • GET  http://localhost:$SERVER_PORT/health    - Health Check"
    echo ""
    
    exit 0
fi

# Option für Status Check
if [ "$1" = "--status" ]; then
    log "📊 Prüfe Handshake Server Status..."
    
    if [ -f "/tmp/m1_handshake.pid" ]; then
        SERVER_PID=$(cat /tmp/m1_handshake.pid)
        if ps -p $SERVER_PID > /dev/null; then
            success "✅ Handshake Server läuft (PID: $SERVER_PID)"
            
            # Test Health Endpoint
            if curl -s "http://localhost:$SERVER_PORT/health" > /dev/null; then
                success "✅ Server antwortet auf Health Checks"
                
                # Zeige Cluster Status
                log "📡 Cluster Status:"
                curl -s "http://localhost:$SERVER_PORT/status" | python3 -m json.tool 2>/dev/null || echo "Status nicht verfügbar"
            else
                warning "⚠️ Server antwortet nicht auf Health Checks"
            fi
        else
            error "❌ Server PID existiert nicht mehr"
        fi
    else
        error "❌ Keine PID-Datei gefunden - Server läuft nicht"
    fi
    
    exit 0
fi

# Option für Stop
if [ "$1" = "--stop" ]; then
    log "🛑 Stoppe Handshake Server..."
    
    pkill -f "m1_handshake_server.py" 2>/dev/null && {
        success "✅ Server gestoppt"
    } || {
        warning "⚠️ Kein laufender Server gefunden"
    }
    
    # Aufräumen
    rm -f /tmp/m1_handshake.pid
    exit 0
fi

# Standard: Interaktiver Modus
log "🖥️ Starte Handshake Server im interaktiven Modus..."
log "💡 Drücke Ctrl+C zum Beenden"
log "🌐 Server wird auf $SERVER_HOST:$SERVER_PORT gestartet"
echo ""

python3 m1_handshake_server.py --host "$SERVER_HOST" --port "$SERVER_PORT"

success "✅ Handshake Server beendet" 