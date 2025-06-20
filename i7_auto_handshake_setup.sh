#!/bin/bash

# 🤝 GENTLEMAN I7 Auto-Handshake Setup
# ====================================
# Automatische Handshake-Konfiguration für i7 Node

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/i7_auto_handshake.log"
PID_FILE="$SCRIPT_DIR/i7_auto_handshake.pid"

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
            log_warning "I7 Auto-Handshake läuft bereits (PID: $pid)"
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

# Teste M1 Konnektivität
test_m1_connectivity() {
    log_info "🔍 Teste Verbindung zum M1 Handshake Server..."
    
    local m1_host="192.168.68.111"
    local handshake_port="8765"
    local tunnel_url="https://century-pam-every-trouble.trycloudflare.com"
    
    # Ping Test
    if ping -c 1 -W 3000 "$m1_host" > /dev/null 2>&1; then
        log_success "M1 Host erreichbar"
        
        # Port Test für lokale Verbindung
        if nc -z -w 3 "$m1_host" "$handshake_port" 2>/dev/null; then
            log_success "M1 Handshake Server Port erreichbar"
            
            # Health Check lokal
            if curl -s -f --max-time 5 "http://$m1_host:$handshake_port/health" > /dev/null 2>&1; then
                log_success "M1 Handshake Server Health Check OK"
                return 0
            fi
        fi
    fi
    
    # Fallback: Teste Cloudflare Tunnel
    log_info "🌐 Teste Cloudflare Tunnel Verbindung..."
    if curl -s -f --max-time 8 "$tunnel_url/health" > /dev/null 2>&1; then
        log_success "M1 Handshake Server über Tunnel erreichbar"
        return 0
    else
        log_error "M1 Server weder lokal noch über Tunnel erreichbar"
        return 1
    fi
}

# I7 Handshake Client starten
start_i7_handshake_client() {
    log_info "🚀 Starte I7 Handshake Client..."
    
    # Prüfe ob Python-Script existiert
    if [[ ! -f "$SCRIPT_DIR/i7_handshake_client.py" ]]; then
        log_error "i7_handshake_client.py nicht gefunden"
        return 1
    fi
    
    # Stoppe alte Instanzen
    pkill -f "i7_handshake_client.py" 2>/dev/null
    sleep 2
    
    # Starte neuen Client
    nohup python3 "$SCRIPT_DIR/i7_handshake_client.py" --daemon > "$SCRIPT_DIR/i7_handshake_client.log" 2>&1 &
    local client_pid=$!
    
    # Warte kurz und prüfe ob Client läuft
    sleep 3
    if ps -p "$client_pid" > /dev/null 2>&1; then
        log_success "I7 Handshake Client gestartet (PID: $client_pid)"
        return 0
    else
        log_error "I7 Handshake Client konnte nicht gestartet werden"
        return 1
    fi
}

# Git Sync Client starten
start_git_sync_client() {
    log_info "🔄 Starte Git Sync Client..."
    
    # Prüfe ob Sync-Script existiert
    if [[ -f "$SCRIPT_DIR/i7_gitea_sync_client.py" ]]; then
        # Stoppe alte Instanzen
        pkill -f "i7_gitea_sync_client.py" 2>/dev/null
        sleep 2
        
        # Starte neuen Sync Client
        nohup python3 "$SCRIPT_DIR/i7_gitea_sync_client.py" --daemon > "$SCRIPT_DIR/i7_git_sync.log" 2>&1 &
        local sync_pid=$!
        
        # Warte kurz und prüfe
        sleep 3
        if ps -p "$sync_pid" > /dev/null 2>&1; then
            log_success "Git Sync Client gestartet (PID: $sync_pid)"
            return 0
        else
            log_warning "Git Sync Client konnte nicht gestartet werden"
            return 1
        fi
    else
        log_warning "Git Sync Client nicht gefunden - überspringe"
        return 0
    fi
}

# Health Check für alle Services
health_check() {
    local max_retries=5
    local retry=0
    
    while [[ $retry -lt $max_retries ]]; do
        # Teste M1 Verbindung
        if curl -s http://192.168.68.111:8765/health > /dev/null 2>&1; then
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
    local monitor_interval=60  # Sekunden zwischen Checks
    
    log_info "🔄 Starte kontinuierlichen Service-Monitor..."
    
    while true; do
        # Prüfe ob Handshake Client noch läuft
        if ! pgrep -f "i7_handshake_client.py" > /dev/null; then
            log_warning "Handshake Client nicht mehr aktiv - starte neu..."
            start_i7_handshake_client
        fi
        
        # Prüfe ob Git Sync Client noch läuft (optional)
        if [[ -f "$SCRIPT_DIR/i7_gitea_sync_client.py" ]] && ! pgrep -f "i7_gitea_sync_client.py" > /dev/null; then
            log_warning "Git Sync Client nicht mehr aktiv - starte neu..."
            start_git_sync_client
        fi
        
        # Health Check
        if health_check; then
            log_info "🤝 Alle Services laufen ordnungsgemäß"
        else
            log_error "Service-Problem erkannt - starte Services neu..."
            start_i7_handshake_client
            start_git_sync_client
        fi
        
        sleep $monitor_interval
    done
}

# Stoppe alle Services
stop_services() {
    log_info "🛑 Stoppe I7 Auto-Handshake Services..."
    
    # Stoppe Handshake Loop
    if [[ -f "$PID_FILE" ]]; then
        local main_pid=$(cat "$PID_FILE")
        kill "$main_pid" 2>/dev/null
        rm -f "$PID_FILE"
    fi
    
    # Stoppe Services
    pkill -f "i7_handshake_client.py" 2>/dev/null
    pkill -f "i7_gitea_sync_client.py" 2>/dev/null
    
    log_success "Alle Services gestoppt"
}

# Status anzeigen
show_status() {
    echo "🤝 GENTLEMAN I7 Auto-Handshake Status"
    echo "===================================="
    
    # Main Process
    if [[ -f "$PID_FILE" ]] && ps -p "$(cat "$PID_FILE")" > /dev/null 2>&1; then
        echo "✅ Auto-Handshake: AKTIV (PID: $(cat "$PID_FILE"))"
    else
        echo "❌ Auto-Handshake: INAKTIV"
    fi
    
    # Handshake Client
    if pgrep -f "i7_handshake_client.py" > /dev/null; then
        echo "✅ Handshake Client: AKTIV"
    else
        echo "❌ Handshake Client: INAKTIV"
    fi
    
    # Git Sync Client
    if pgrep -f "i7_gitea_sync_client.py" > /dev/null; then
        echo "✅ Git Sync Client: AKTIV"
    else
        echo "❌ Git Sync Client: INAKTIV"
    fi
    
    # M1 Konnektivität
    if curl -s http://192.168.68.111:8765/health > /dev/null 2>&1; then
        echo "✅ M1 Verbindung: OK"
    else
        echo "❌ M1 Verbindung: FAIL"
    fi
    
    # Zeige letzte Log-Einträge
    echo ""
    echo "📋 Letzte Log-Einträge:"
    if [[ -f "$LOG_FILE" ]]; then
        tail -5 "$LOG_FILE" | sed 's/^/   /'
    else
        echo "   Keine Log-Datei gefunden"
    fi
}

# Main Function
main() {
    case "${1:-start}" in
        "start")
            if check_running; then
                exit 1
            fi
            
            log_info "🚀 Starte GENTLEMAN I7 Auto-Handshake..."
            
            # Repository aktualisieren
            update_repo
            
            # M1 Konnektivität testen
            if ! test_m1_connectivity; then
                log_error "M1 Server nicht erreichbar - Setup abgebrochen"
                exit 1
            fi
            
            # Services starten
            if start_i7_handshake_client; then
                start_git_sync_client
                
                # PID speichern
                echo $$ > "$PID_FILE"
                
                log_success "I7 Auto-Handshake Setup abgeschlossen"
                
                # Kontinuierlicher Loop
                handshake_loop
            else
                log_error "I7 Auto-Handshake Setup fehlgeschlagen"
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
        
        "test")
            log_info "🧪 Teste I7 Auto-Handshake Konfiguration..."
            
            # Repository Update
            update_repo
            
            # M1 Konnektivität
            if test_m1_connectivity; then
                log_success "M1 Konnektivitätstest erfolgreich"
            else
                log_error "M1 Konnektivitätstest fehlgeschlagen"
                exit 1
            fi
            
            # Einmaliger Handshake
            if [[ -f "$SCRIPT_DIR/i7_handshake_client.py" ]]; then
                log_info "Teste einmaligen Handshake..."
                if python3 "$SCRIPT_DIR/i7_handshake_client.py" --once; then
                    log_success "Handshake-Test erfolgreich"
                else
                    log_error "Handshake-Test fehlgeschlagen"
                    exit 1
                fi
            fi
            
            log_success "Alle Tests erfolgreich"
            ;;
        
        *)
            echo "Usage: $0 {start|stop|status|restart|test}"
            echo ""
            echo "🤝 GENTLEMAN I7 Auto-Handshake Manager"
            echo "====================================="
            echo "start   - Startet Auto-Handshake Services"
            echo "stop    - Stoppt alle Services"
            echo "status  - Zeigt aktuellen Status"
            echo "restart - Startet Services neu"
            echo "test    - Testet Konfiguration"
            exit 1
            ;;
    esac
}

# Trap für sauberes Beenden
trap 'stop_services; exit 0' SIGTERM SIGINT

# Script ausführen
main "$@" 