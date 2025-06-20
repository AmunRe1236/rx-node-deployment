#!/bin/bash

# 🤝 GENTLEMAN M1 Auto-Handshake Setup
# =====================================
# Automatische Konfiguration für kontinuierliche Handshake-Verbindung

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/auto_handshake.log"
PID_FILE="$SCRIPT_DIR/auto_handshake.pid"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    log "${GREEN}✅ $1${NC}"
}

log_warning() {
    log "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    log "${RED}❌ $1${NC}"
}

# Prüfe ob bereits läuft
check_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log_warning "Auto-Handshake läuft bereits (PID: $pid)"
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# Repository Update
update_repo() {
    log_info "🔄 Aktualisiere Repository..."
    
    cd "$SCRIPT_DIR"
    
    # Versuche verschiedene Git-Remotes
    if git pull origin master 2>/dev/null; then
        log_success "Repository von GitHub aktualisiert"
    elif git pull gitea master 2>/dev/null; then
        log_success "Repository von Gitea aktualisiert"
    elif git pull daemon master 2>/dev/null; then
        log_success "Repository von Git Daemon aktualisiert"
    else
        log_warning "Repository-Update fehlgeschlagen - verwende lokale Version"
    fi
}

# Handshake Server starten
start_handshake_server() {
    log_info "🚀 Starte Handshake Server..."
    
    # Stoppe alte Instanzen
    pkill -f "m1_handshake_server.py" 2>/dev/null
    sleep 2
    
    # Starte neuen Server
    nohup python3 "$SCRIPT_DIR/m1_handshake_server.py" --host 0.0.0.0 --port 8765 > "$SCRIPT_DIR/handshake_server.log" 2>&1 &
    local server_pid=$!
    
    # Warte kurz und prüfe ob Server läuft
    sleep 3
    if ps -p "$server_pid" > /dev/null 2>&1; then
        log_success "Handshake Server gestartet (PID: $server_pid)"
        return 0
    else
        log_error "Handshake Server konnte nicht gestartet werden"
        return 1
    fi
}

# Cloudflare Tunnel starten
start_cloudflare_tunnel() {
    log_info "☁️  Starte Cloudflare Tunnel..."
    
    # Prüfe ob cloudflared verfügbar ist
    if ! command -v cloudflared &> /dev/null; then
        log_warning "cloudflared nicht gefunden - installiere..."
        curl -L --output /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64
        chmod +x /tmp/cloudflared
        sudo mv /tmp/cloudflared /usr/local/bin/
    fi
    
    # Stoppe alte Tunnel
    pkill -f "cloudflared tunnel" 2>/dev/null
    sleep 2
    
    # Starte neuen Tunnel
    nohup cloudflared tunnel --url http://localhost:8765 > "$SCRIPT_DIR/cloudflare_tunnel.log" 2>&1 &
    local tunnel_pid=$!
    
    # Warte auf URL
    sleep 10
    local tunnel_url=$(grep -o 'https://[^[:space:]]*\.trycloudflare\.com' "$SCRIPT_DIR/cloudflare_tunnel.log" | tail -1)
    
    if [[ -n "$tunnel_url" ]]; then
        log_success "Cloudflare Tunnel aktiv: $tunnel_url"
        echo "$tunnel_url" > "$SCRIPT_DIR/current_tunnel_url.txt"
        return 0
    else
        log_error "Cloudflare Tunnel URL nicht gefunden"
        return 1
    fi
}

# Health Check
health_check() {
    local max_retries=5
    local retry=0
    
    while [[ $retry -lt $max_retries ]]; do
        if curl -s http://localhost:8765/health > /dev/null 2>&1; then
            log_success "Health Check erfolgreich"
            return 0
        fi
        
        retry=$((retry + 1))
        log_warning "Health Check fehlgeschlagen (Versuch $retry/$max_retries)"
        sleep 5
    done
    
    log_error "Health Check nach $max_retries Versuchen fehlgeschlagen"
    return 1
}

# Kontinuierlicher Handshake Loop
handshake_loop() {
    local handshake_interval=30  # Sekunden zwischen Handshakes
    
    log_info "🔄 Starte kontinuierlichen Handshake Loop..."
    
    while true; do
        # Prüfe ob Services noch laufen
        if ! pgrep -f "m1_handshake_server.py" > /dev/null; then
            log_warning "Handshake Server nicht mehr aktiv - starte neu..."
            start_handshake_server
        fi
        
        if ! pgrep -f "cloudflared tunnel" > /dev/null; then
            log_warning "Cloudflare Tunnel nicht mehr aktiv - starte neu..."
            start_cloudflare_tunnel
        fi
        
        # Health Check
        if health_check; then
            log_info "🤝 Handshake erfolgreich"
        else
            log_error "Handshake fehlgeschlagen - Services werden neu gestartet"
            start_handshake_server
            start_cloudflare_tunnel
        fi
        
        sleep $handshake_interval
    done
}

# Stoppe alle Services
stop_services() {
    log_info "🛑 Stoppe Auto-Handshake Services..."
    
    # Stoppe Handshake Loop
    if [[ -f "$PID_FILE" ]]; then
        local main_pid=$(cat "$PID_FILE")
        kill "$main_pid" 2>/dev/null
        rm -f "$PID_FILE"
    fi
    
    # Stoppe Services
    pkill -f "m1_handshake_server.py" 2>/dev/null
    pkill -f "cloudflared tunnel" 2>/dev/null
    
    log_success "Alle Services gestoppt"
}

# Status anzeigen
show_status() {
    echo "🤝 GENTLEMAN M1 Auto-Handshake Status"
    echo "===================================="
    
    # Main Process
    if [[ -f "$PID_FILE" ]] && ps -p "$(cat "$PID_FILE")" > /dev/null 2>&1; then
        echo "✅ Auto-Handshake: AKTIV (PID: $(cat "$PID_FILE"))"
    else
        echo "❌ Auto-Handshake: INAKTIV"
    fi
    
    # Handshake Server
    if pgrep -f "m1_handshake_server.py" > /dev/null; then
        echo "✅ Handshake Server: AKTIV"
    else
        echo "❌ Handshake Server: INAKTIV"
    fi
    
    # Cloudflare Tunnel
    if pgrep -f "cloudflared tunnel" > /dev/null; then
        echo "✅ Cloudflare Tunnel: AKTIV"
        if [[ -f "$SCRIPT_DIR/current_tunnel_url.txt" ]]; then
            echo "   📡 URL: $(cat "$SCRIPT_DIR/current_tunnel_url.txt")"
        fi
    else
        echo "❌ Cloudflare Tunnel: INAKTIV"
    fi
    
    # Health Check
    if curl -s http://localhost:8765/health > /dev/null 2>&1; then
        echo "✅ Health Check: OK"
    else
        echo "❌ Health Check: FAIL"
    fi
}

# Main Function
main() {
    case "${1:-start}" in
        "start")
            if check_running; then
                exit 1
            fi
            
            log_info "🚀 Starte GENTLEMAN M1 Auto-Handshake..."
            
            # Repository aktualisieren
            update_repo
            
            # Services starten
            if start_handshake_server && start_cloudflare_tunnel; then
                # PID speichern
                echo $$ > "$PID_FILE"
                
                log_success "Auto-Handshake Setup abgeschlossen"
                
                # Kontinuierlicher Loop
                handshake_loop
            else
                log_error "Auto-Handshake Setup fehlgeschlagen"
                exit 1
            fi
            ;;
        
        "stop")
            stop_services
            ;;
        
        "status")
            show_status
            ;;
        
        "restart")
            stop_services
            sleep 2
            exec "$0" start
            ;;
        
        *)
            echo "Usage: $0 {start|stop|status|restart}"
            echo ""
            echo "🤝 GENTLEMAN M1 Auto-Handshake Manager"
            echo "====================================="
            echo "start   - Startet Auto-Handshake Services"
            echo "stop    - Stoppt alle Services"
            echo "status  - Zeigt aktuellen Status"
            echo "restart - Startet Services neu"
            exit 1
            ;;
    esac
}

# Trap für sauberes Beenden
trap 'stop_services; exit 0' SIGTERM SIGINT

# Script ausführen
main "$@" 