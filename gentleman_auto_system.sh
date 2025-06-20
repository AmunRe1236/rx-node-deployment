#!/bin/bash

# 🚀 GENTLEMAN Auto-Detection System
# ==================================
# Intelligentes System für automatische Netzwerk-Erkennung
# - Automatische Erkennung: Heimnetz vs. Hotspot
# - Dynamisches Service-Management
# - Nahtloser Wechsel zwischen Modi
# - SSH-Zugriff und Handshake-Management

set -e

# Konfiguration
M1_HOST="192.168.68.111"
HANDSHAKE_PORT="8765"
I7_NODE_ID="i7-development-node"
LOG_FILE="/tmp/gentleman_auto.log"
PID_FILE="/tmp/gentleman_auto.pid"
STATE_FILE="/tmp/gentleman_state.txt"

# Netzwerk-Konfigurationen
HOME_NETWORK_PREFIX="192.168.68"
HOTSPOT_NETWORK_PREFIX="172.20.10"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging Funktionen
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1"
    echo -e "${RED}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

warning() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️  $1"
    echo -e "${PURPLE}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

# Netzwerk-Erkennung
detect_network_mode() {
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    
    if [[ "$current_ip" =~ ^$HOME_NETWORK_PREFIX\. ]]; then
        echo "home"
    elif [[ "$current_ip" =~ ^$HOTSPOT_NETWORK_PREFIX\. ]]; then
        echo "hotspot"
    else
        echo "unknown"
    fi
}

# Aktuelle IP-Adresse ermitteln
get_current_ip() {
    ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}'
}

# Letzten bekannten Zustand laden
load_last_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "unknown"
    fi
}

# Aktuellen Zustand speichern
save_current_state() {
    echo "$1" > "$STATE_FILE"
}

# Teste SSH-Verbindung zum M1
test_m1_ssh() {
    ssh -o ConnectTimeout=3 -o BatchMode=yes amonbaumgartner@$M1_HOST "echo 'SSH OK'" >/dev/null 2>&1
}

# Teste lokalen M1 Handshake Server
test_m1_local_handshake() {
    curl -s --connect-timeout 3 "http://$M1_HOST:$HANDSHAKE_PORT/health" >/dev/null 2>&1
}

# Hole öffentliche M1 URL
get_m1_public_url() {
    if test_m1_ssh; then
        ssh amonbaumgartner@$M1_HOST "cd /Users/amonbaumgartner/Gentleman && ./m1_cloudflare_manager.sh url 2>/dev/null" | grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' | head -1
    fi
}

# Teste öffentlichen M1 Handshake Server
test_m1_public_handshake() {
    local public_url=$(get_m1_public_url)
    if [ -n "$public_url" ]; then
        curl -s --connect-timeout 5 "$public_url/health" >/dev/null 2>&1
    else
        return 1
    fi
}

# Heimnetz-Modus aktivieren
activate_home_mode() {
    info "🏠 Aktiviere Heimnetz-Modus..."
    
    # 1. Stelle sicher, dass M1 Services laufen
    if test_m1_ssh; then
        info "📡 Starte M1 Services über SSH..."
        ssh amonbaumgartner@$M1_HOST "cd /Users/amonbaumgartner/Gentleman && ./m1_master_control.sh start >/dev/null 2>&1" || true
        sleep 5
    else
        warning "SSH-Verbindung zum M1 Mac nicht möglich"
    fi
    
    # 2. Starte lokalen I7 Handshake Client
    info "🤝 Starte lokalen I7 Handshake Client..."
    ./i7_auto_handshake_setup.sh stop >/dev/null 2>&1 || true
    sleep 2
    ./i7_auto_handshake_setup.sh start >/dev/null 2>&1 || true
    
    success "Heimnetz-Modus aktiviert"
}

# Hotspot-Modus aktivieren
activate_hotspot_mode() {
    info "📱 Aktiviere Hotspot-Modus..."
    
    # 1. Stoppe lokale Services
    info "🛑 Stoppe lokale Services..."
    ./i7_auto_handshake_setup.sh stop >/dev/null 2>&1 || true
    
    # 2. Starte mobilen I7 Client
    info "🌐 Starte mobilen I7 Client..."
    ./i7_mobile_client.sh stop >/dev/null 2>&1 || true
    sleep 2
    ./i7_mobile_client.sh start >/dev/null 2>&1 || true
    
    success "Hotspot-Modus aktiviert"
}

# Unknown-Modus (Fallback)
activate_unknown_mode() {
    warning "❓ Unbekanntes Netzwerk - Stoppe alle Services..."
    ./i7_auto_handshake_setup.sh stop >/dev/null 2>&1 || true
    ./i7_mobile_client.sh stop >/dev/null 2>&1 || true
}

# Netzwerk-Wechsel verarbeiten
handle_network_change() {
    local current_mode="$1"
    local last_mode="$2"
    local current_ip=$(get_current_ip)
    
    if [ "$current_mode" = "$last_mode" ]; then
        return 0  # Kein Wechsel
    fi
    
    log "🔄 Netzwerk-Wechsel erkannt: $last_mode → $current_mode (IP: $current_ip)"
    
    case "$current_mode" in
        "home")
            activate_home_mode
            ;;
        "hotspot")
            activate_hotspot_mode
            ;;
        *)
            activate_unknown_mode
            ;;
    esac
    
    save_current_state "$current_mode"
}

# System-Status anzeigen
show_system_status() {
    local current_mode=$(detect_network_mode)
    local current_ip=$(get_current_ip)
    local last_mode=$(load_last_state)
    
    echo
    echo "🤝 GENTLEMAN Auto-Detection System Status"
    echo "=========================================="
    echo
    echo "🌐 Netzwerk-Status:"
    echo "   Aktueller Modus: $current_mode"
    echo "   Aktuelle IP: $current_ip"
    echo "   Letzter Modus: $last_mode"
    echo
    
    case "$current_mode" in
        "home")
            echo "🏠 Heimnetz-Services:"
            if test_m1_ssh; then
                echo "   SSH zu M1: ✅ Erreichbar"
                if test_m1_local_handshake; then
                    echo "   M1 Handshake: ✅ Lokal erreichbar"
                else
                    echo "   M1 Handshake: ❌ Nicht erreichbar"
                fi
            else
                echo "   SSH zu M1: ❌ Nicht erreichbar"
            fi
            
            echo "   I7 Auto-Handshake:"
            ./i7_auto_handshake_setup.sh status 2>/dev/null | grep -E "(AKTIV|INAKTIV)" || echo "   Status unbekannt"
            ;;
            
        "hotspot")
            echo "📱 Hotspot-Services:"
            local public_url=$(get_m1_public_url)
            if [ -n "$public_url" ]; then
                echo "   M1 Öffentliche URL: ✅ $public_url"
                if test_m1_public_handshake; then
                    echo "   M1 Handshake: ✅ Öffentlich erreichbar"
                else
                    echo "   M1 Handshake: ❌ Nicht erreichbar"
                fi
            else
                echo "   M1 Öffentliche URL: ❌ Nicht verfügbar"
            fi
            
            echo "   I7 Mobile Client:"
            ./i7_mobile_client.sh status 2>/dev/null | grep -E "(AKTIV|INAKTIV)" || echo "   Status unbekannt"
            ;;
            
        *)
            echo "❓ Unbekanntes Netzwerk - Services gestoppt"
            ;;
    esac
    
    echo
}

# Kontinuierliches Monitoring
continuous_monitoring() {
    log "🔄 Starte kontinuierliches Netzwerk-Monitoring..."
    
    while true; do
        local current_mode=$(detect_network_mode)
        local last_mode=$(load_last_state)
        
        handle_network_change "$current_mode" "$last_mode"
        
        # Warte 10 Sekunden bis zur nächsten Überprüfung
        sleep 10
    done
}

# Daemon starten
start_daemon() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        warning "GENTLEMAN Auto-System läuft bereits (PID: $(cat $PID_FILE))"
        return 1
    fi
    
    log "🚀 Starte GENTLEMAN Auto-Detection System..."
    
    # Initialer Netzwerk-Check
    local current_mode=$(detect_network_mode)
    handle_network_change "$current_mode" "unknown"
    
    # Starte als Background-Prozess
    nohup bash -c "
        cd $(pwd)
        $0 monitor
    " >> "$LOG_FILE" 2>&1 &
    
    echo $! > "$PID_FILE"
    success "GENTLEMAN Auto-System gestartet (PID: $(cat $PID_FILE))"
}

# Daemon stoppen
stop_daemon() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$PID_FILE"
            
            # Stoppe auch alle Sub-Services
            ./i7_auto_handshake_setup.sh stop >/dev/null 2>&1 || true
            ./i7_mobile_client.sh stop >/dev/null 2>&1 || true
            
            success "GENTLEMAN Auto-System gestoppt (PID: $pid)"
        else
            warning "GENTLEMAN Auto-System war nicht aktiv"
            rm -f "$PID_FILE"
        fi
    else
        warning "Keine PID-Datei gefunden"
    fi
}

# Hauptfunktion
main() {
    case "$1" in
        "start")
            start_daemon
            ;;
        "stop")
            stop_daemon
            ;;
        "restart")
            stop_daemon
            sleep 3
            start_daemon
            ;;
        "status")
            show_system_status
            ;;
        "monitor")
            # Interner Aufruf für kontinuierliches Monitoring
            continuous_monitoring
            ;;
        "force-home")
            log "🏠 Erzwinge Heimnetz-Modus..."
            activate_home_mode
            ;;
        "force-hotspot")
            log "📱 Erzwinge Hotspot-Modus..."
            activate_hotspot_mode
            ;;
        *)
            echo
            echo "🤝 GENTLEMAN Auto-Detection System"
            echo "=================================="
            echo
            echo "Intelligentes System für automatische Netzwerk-Erkennung"
            echo "und dynamisches Service-Management zwischen Heimnetz und Hotspot."
            echo
            echo "Usage: $0 {start|stop|restart|status|force-home|force-hotspot}"
            echo
            echo "Befehle:"
            echo "  start        - Starte Auto-Detection System"
            echo "  stop         - Stoppe Auto-Detection System"
            echo "  restart      - Neustart des Systems"
            echo "  status       - Zeige System-Status"
            echo "  force-home   - Erzwinge Heimnetz-Modus"
            echo "  force-hotspot- Erzwinge Hotspot-Modus"
            echo
            echo "🏠 Heimnetz-Modus:"
            echo "   - SSH-Zugriff zu M1 Mac"
            echo "   - Lokaler Handshake-Server"
            echo "   - Direkte Netzwerk-Verbindungen"
            echo
            echo "📱 Hotspot-Modus:"
            echo "   - Öffentlicher Zugriff über Cloudflare Tunnel"
            echo "   - Mobile Handshake-Clients"
            echo "   - Internet-basierte Verbindungen"
            echo
            exit 1
            ;;
    esac
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 

# 🚀 GENTLEMAN Auto-Detection System
# ==================================
# Intelligentes System für automatische Netzwerk-Erkennung
# - Automatische Erkennung: Heimnetz vs. Hotspot
# - Dynamisches Service-Management
# - Nahtloser Wechsel zwischen Modi
# - SSH-Zugriff und Handshake-Management

set -e

# Konfiguration
M1_HOST="192.168.68.111"
HANDSHAKE_PORT="8765"
I7_NODE_ID="i7-development-node"
LOG_FILE="/tmp/gentleman_auto.log"
PID_FILE="/tmp/gentleman_auto.pid"
STATE_FILE="/tmp/gentleman_state.txt"

# Netzwerk-Konfigurationen
HOME_NETWORK_PREFIX="192.168.68"
HOTSPOT_NETWORK_PREFIX="172.20.10"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging Funktionen
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1"
    echo -e "${RED}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

warning() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️  $1"
    echo -e "${PURPLE}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

# Netzwerk-Erkennung
detect_network_mode() {
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    
    if [[ "$current_ip" =~ ^$HOME_NETWORK_PREFIX\. ]]; then
        echo "home"
    elif [[ "$current_ip" =~ ^$HOTSPOT_NETWORK_PREFIX\. ]]; then
        echo "hotspot"
    else
        echo "unknown"
    fi
}

# Aktuelle IP-Adresse ermitteln
get_current_ip() {
    ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}'
}

# Letzten bekannten Zustand laden
load_last_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "unknown"
    fi
}

# Aktuellen Zustand speichern
save_current_state() {
    echo "$1" > "$STATE_FILE"
}

# Teste SSH-Verbindung zum M1
test_m1_ssh() {
    ssh -o ConnectTimeout=3 -o BatchMode=yes amonbaumgartner@$M1_HOST "echo 'SSH OK'" >/dev/null 2>&1
}

# Teste lokalen M1 Handshake Server
test_m1_local_handshake() {
    curl -s --connect-timeout 3 "http://$M1_HOST:$HANDSHAKE_PORT/health" >/dev/null 2>&1
}

# Hole öffentliche M1 URL
get_m1_public_url() {
    if test_m1_ssh; then
        ssh amonbaumgartner@$M1_HOST "cd /Users/amonbaumgartner/Gentleman && ./m1_cloudflare_manager.sh url 2>/dev/null" | grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' | head -1
    fi
}

# Teste öffentlichen M1 Handshake Server
test_m1_public_handshake() {
    local public_url=$(get_m1_public_url)
    if [ -n "$public_url" ]; then
        curl -s --connect-timeout 5 "$public_url/health" >/dev/null 2>&1
    else
        return 1
    fi
}

# Heimnetz-Modus aktivieren
activate_home_mode() {
    info "🏠 Aktiviere Heimnetz-Modus..."
    
    # 1. Stelle sicher, dass M1 Services laufen
    if test_m1_ssh; then
        info "📡 Starte M1 Services über SSH..."
        ssh amonbaumgartner@$M1_HOST "cd /Users/amonbaumgartner/Gentleman && ./m1_master_control.sh start >/dev/null 2>&1" || true
        sleep 5
    else
        warning "SSH-Verbindung zum M1 Mac nicht möglich"
    fi
    
    # 2. Starte lokalen I7 Handshake Client
    info "🤝 Starte lokalen I7 Handshake Client..."
    ./i7_auto_handshake_setup.sh stop >/dev/null 2>&1 || true
    sleep 2
    ./i7_auto_handshake_setup.sh start >/dev/null 2>&1 || true
    
    success "Heimnetz-Modus aktiviert"
}

# Hotspot-Modus aktivieren
activate_hotspot_mode() {
    info "📱 Aktiviere Hotspot-Modus..."
    
    # 1. Stoppe lokale Services
    info "🛑 Stoppe lokale Services..."
    ./i7_auto_handshake_setup.sh stop >/dev/null 2>&1 || true
    
    # 2. Starte mobilen I7 Client
    info "🌐 Starte mobilen I7 Client..."
    ./i7_mobile_client.sh stop >/dev/null 2>&1 || true
    sleep 2
    ./i7_mobile_client.sh start >/dev/null 2>&1 || true
    
    success "Hotspot-Modus aktiviert"
}

# Unknown-Modus (Fallback)
activate_unknown_mode() {
    warning "❓ Unbekanntes Netzwerk - Stoppe alle Services..."
    ./i7_auto_handshake_setup.sh stop >/dev/null 2>&1 || true
    ./i7_mobile_client.sh stop >/dev/null 2>&1 || true
}

# Netzwerk-Wechsel verarbeiten
handle_network_change() {
    local current_mode="$1"
    local last_mode="$2"
    local current_ip=$(get_current_ip)
    
    if [ "$current_mode" = "$last_mode" ]; then
        return 0  # Kein Wechsel
    fi
    
    log "🔄 Netzwerk-Wechsel erkannt: $last_mode → $current_mode (IP: $current_ip)"
    
    case "$current_mode" in
        "home")
            activate_home_mode
            ;;
        "hotspot")
            activate_hotspot_mode
            ;;
        *)
            activate_unknown_mode
            ;;
    esac
    
    save_current_state "$current_mode"
}

# System-Status anzeigen
show_system_status() {
    local current_mode=$(detect_network_mode)
    local current_ip=$(get_current_ip)
    local last_mode=$(load_last_state)
    
    echo
    echo "🤝 GENTLEMAN Auto-Detection System Status"
    echo "=========================================="
    echo
    echo "🌐 Netzwerk-Status:"
    echo "   Aktueller Modus: $current_mode"
    echo "   Aktuelle IP: $current_ip"
    echo "   Letzter Modus: $last_mode"
    echo
    
    case "$current_mode" in
        "home")
            echo "🏠 Heimnetz-Services:"
            if test_m1_ssh; then
                echo "   SSH zu M1: ✅ Erreichbar"
                if test_m1_local_handshake; then
                    echo "   M1 Handshake: ✅ Lokal erreichbar"
                else
                    echo "   M1 Handshake: ❌ Nicht erreichbar"
                fi
            else
                echo "   SSH zu M1: ❌ Nicht erreichbar"
            fi
            
            echo "   I7 Auto-Handshake:"
            ./i7_auto_handshake_setup.sh status 2>/dev/null | grep -E "(AKTIV|INAKTIV)" || echo "   Status unbekannt"
            ;;
            
        "hotspot")
            echo "📱 Hotspot-Services:"
            local public_url=$(get_m1_public_url)
            if [ -n "$public_url" ]; then
                echo "   M1 Öffentliche URL: ✅ $public_url"
                if test_m1_public_handshake; then
                    echo "   M1 Handshake: ✅ Öffentlich erreichbar"
                else
                    echo "   M1 Handshake: ❌ Nicht erreichbar"
                fi
            else
                echo "   M1 Öffentliche URL: ❌ Nicht verfügbar"
            fi
            
            echo "   I7 Mobile Client:"
            ./i7_mobile_client.sh status 2>/dev/null | grep -E "(AKTIV|INAKTIV)" || echo "   Status unbekannt"
            ;;
            
        *)
            echo "❓ Unbekanntes Netzwerk - Services gestoppt"
            ;;
    esac
    
    echo
}

# Kontinuierliches Monitoring
continuous_monitoring() {
    log "🔄 Starte kontinuierliches Netzwerk-Monitoring..."
    
    while true; do
        local current_mode=$(detect_network_mode)
        local last_mode=$(load_last_state)
        
        handle_network_change "$current_mode" "$last_mode"
        
        # Warte 10 Sekunden bis zur nächsten Überprüfung
        sleep 10
    done
}

# Daemon starten
start_daemon() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        warning "GENTLEMAN Auto-System läuft bereits (PID: $(cat $PID_FILE))"
        return 1
    fi
    
    log "🚀 Starte GENTLEMAN Auto-Detection System..."
    
    # Initialer Netzwerk-Check
    local current_mode=$(detect_network_mode)
    handle_network_change "$current_mode" "unknown"
    
    # Starte als Background-Prozess
    nohup bash -c "
        cd $(pwd)
        $0 monitor
    " >> "$LOG_FILE" 2>&1 &
    
    echo $! > "$PID_FILE"
    success "GENTLEMAN Auto-System gestartet (PID: $(cat $PID_FILE))"
}

# Daemon stoppen
stop_daemon() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$PID_FILE"
            
            # Stoppe auch alle Sub-Services
            ./i7_auto_handshake_setup.sh stop >/dev/null 2>&1 || true
            ./i7_mobile_client.sh stop >/dev/null 2>&1 || true
            
            success "GENTLEMAN Auto-System gestoppt (PID: $pid)"
        else
            warning "GENTLEMAN Auto-System war nicht aktiv"
            rm -f "$PID_FILE"
        fi
    else
        warning "Keine PID-Datei gefunden"
    fi
}

# Hauptfunktion
main() {
    case "$1" in
        "start")
            start_daemon
            ;;
        "stop")
            stop_daemon
            ;;
        "restart")
            stop_daemon
            sleep 3
            start_daemon
            ;;
        "status")
            show_system_status
            ;;
        "monitor")
            # Interner Aufruf für kontinuierliches Monitoring
            continuous_monitoring
            ;;
        "force-home")
            log "🏠 Erzwinge Heimnetz-Modus..."
            activate_home_mode
            ;;
        "force-hotspot")
            log "📱 Erzwinge Hotspot-Modus..."
            activate_hotspot_mode
            ;;
        *)
            echo
            echo "🤝 GENTLEMAN Auto-Detection System"
            echo "=================================="
            echo
            echo "Intelligentes System für automatische Netzwerk-Erkennung"
            echo "und dynamisches Service-Management zwischen Heimnetz und Hotspot."
            echo
            echo "Usage: $0 {start|stop|restart|status|force-home|force-hotspot}"
            echo
            echo "Befehle:"
            echo "  start        - Starte Auto-Detection System"
            echo "  stop         - Stoppe Auto-Detection System"
            echo "  restart      - Neustart des Systems"
            echo "  status       - Zeige System-Status"
            echo "  force-home   - Erzwinge Heimnetz-Modus"
            echo "  force-hotspot- Erzwinge Hotspot-Modus"
            echo
            echo "🏠 Heimnetz-Modus:"
            echo "   - SSH-Zugriff zu M1 Mac"
            echo "   - Lokaler Handshake-Server"
            echo "   - Direkte Netzwerk-Verbindungen"
            echo
            echo "📱 Hotspot-Modus:"
            echo "   - Öffentlicher Zugriff über Cloudflare Tunnel"
            echo "   - Mobile Handshake-Clients"
            echo "   - Internet-basierte Verbindungen"
            echo
            exit 1
            ;;
    esac
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 
 