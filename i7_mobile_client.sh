#!/bin/bash

# 🚀 GENTLEMAN I7 Mobile Client
# ============================
# Intelligenter Handshake Client für I7 Node
# - Automatische Erkennung: Heimnetz vs. Mobile
# - Fallback zwischen lokalem und öffentlichem Server
# - Robuste Netzwerk-Behandlung

set -e

# Konfiguration
M1_LOCAL_HOST="192.168.68.111"
M1_LOCAL_PORT="8765"
M1_PUBLIC_URL="https://graphical-founder-cleveland-vulnerable.trycloudflare.com"
I7_NODE_ID="i7-development-node"
LOG_FILE="/tmp/i7_mobile_client.log"
PID_FILE="/tmp/i7_mobile_client.pid"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging Funktion
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1" >> "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ $1" >> "$LOG_FILE"
}

# Netzwerk-Erkennung
detect_network_mode() {
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    
    if [[ "$current_ip" =~ ^192\.168\.68\. ]]; then
        echo "home"
    elif [[ "$current_ip" =~ ^172\.20\.10\. ]]; then
        echo "hotspot"
    else
        echo "unknown"
    fi
}

# Teste lokalen M1 Server
test_local_server() {
    if curl -s --connect-timeout 5 "http://$M1_LOCAL_HOST:$M1_LOCAL_PORT/health" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Teste öffentlichen M1 Server
test_public_server() {
    if curl -s --connect-timeout 10 "$M1_PUBLIC_URL/health" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Bestimme besten Handshake-Endpoint
determine_handshake_endpoint() {
    local network_mode=$(detect_network_mode)
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    
    log "🔍 Netzwerk-Erkennung: $network_mode (IP: $current_ip)"
    
    case "$network_mode" in
        "home")
            if test_local_server; then
                echo "http://$M1_LOCAL_HOST:$M1_LOCAL_PORT"
                log "✅ Verwende lokalen M1 Server (Heimnetz)"
                return 0
            elif test_public_server; then
                echo "$M1_PUBLIC_URL"
                warning "Fallback auf öffentlichen Server (Heimnetz, aber lokal nicht erreichbar)"
                return 0
            else
                error "Kein M1 Server erreichbar (Heimnetz)"
                return 1
            fi
            ;;
        "hotspot")
            if test_public_server; then
                echo "$M1_PUBLIC_URL"
                log "✅ Verwende öffentlichen M1 Server (Hotspot-Modus)"
                return 0
            else
                error "Öffentlicher M1 Server nicht erreichbar (Hotspot-Modus)"
                return 1
            fi
            ;;
        *)
            # Unbekanntes Netzwerk - teste beide
            if test_local_server; then
                echo "http://$M1_LOCAL_HOST:$M1_LOCAL_PORT"
                log "✅ Verwende lokalen M1 Server (unbekanntes Netzwerk)"
                return 0
            elif test_public_server; then
                echo "$M1_PUBLIC_URL"
                warning "Verwende öffentlichen M1 Server (unbekanntes Netzwerk)"
                return 0
            else
                error "Kein M1 Server erreichbar (unbekanntes Netzwerk)"
                return 1
            fi
            ;;
    esac
}

# Führe einzelnen Handshake durch
perform_handshake() {
    local endpoint=$(determine_handshake_endpoint)
    if [ $? -ne 0 ]; then
        error "Kein erreichbarer Handshake-Endpoint gefunden"
        return 1
    fi
    
    local handshake_url="$endpoint/handshake"
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    
    # Handshake-Daten
    local handshake_data=$(cat << EOF
{
    "node_id": "$I7_NODE_ID",
    "ip_address": "$current_ip",
    "timestamp": $(date +%s),
    "status": "active",
    "capabilities": ["development", "testing"],
    "network_mode": "$(detect_network_mode)"
}
EOF
)
    
    log "🤝 Führe Handshake durch: $handshake_url"
    
    local response=$(curl -s --connect-timeout 10 -X POST \
        -H "Content-Type: application/json" \
        -d "$handshake_data" \
        "$handshake_url" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        success "Handshake erfolgreich: $response"
        return 0
    else
        error "Handshake fehlgeschlagen"
        return 1
    fi
}

# Kontinuierlicher Handshake-Modus
continuous_handshake() {
    log "🔄 Starte kontinuierlichen Handshake-Modus..."
    
    while true; do
        if perform_handshake; then
            success "Handshake-Zyklus abgeschlossen"
        else
            warning "Handshake-Zyklus fehlgeschlagen - Wiederholung in 60 Sekunden"
            sleep 60
            continue
        fi
        
        # Warte 30 Sekunden bis zum nächsten Handshake
        sleep 30
    done
}

# Starte Handshake Client als Daemon
start_daemon() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        warning "I7 Mobile Client läuft bereits (PID: $(cat $PID_FILE))"
        return 1
    fi
    
    log "🚀 Starte I7 Mobile Client Daemon..."
    
    # Starte als Background-Prozess
    nohup bash -c "
        cd $(pwd)
        $0 continuous
    " >> "$LOG_FILE" 2>&1 &
    
    echo $! > "$PID_FILE"
    success "I7 Mobile Client gestartet (PID: $(cat $PID_FILE))"
}

# Stoppe Handshake Client
stop_daemon() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$PID_FILE"
            success "I7 Mobile Client gestoppt (PID: $pid)"
        else
            warning "I7 Mobile Client war nicht aktiv"
            rm -f "$PID_FILE"
        fi
    else
        warning "Keine PID-Datei gefunden"
    fi
}

# Status des Clients
client_status() {
    echo "🤝 GENTLEMAN I7 Mobile Client Status"
    echo "===================================="
    
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "✅ Client Status: AKTIV (PID: $(cat $PID_FILE))"
    else
        echo "❌ Client Status: INAKTIV"
    fi
    
    local network_mode=$(detect_network_mode)
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    echo "🌐 Netzwerk: $network_mode (IP: $current_ip)"
    
    local endpoint=$(determine_handshake_endpoint 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "📡 Handshake-Endpoint: $endpoint"
    else
        echo "❌ Kein erreichbarer Handshake-Endpoint"
    fi
    
    if [ -f "$LOG_FILE" ]; then
        echo
        echo "📄 Letzte Log-Einträge:"
        tail -5 "$LOG_FILE"
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
            sleep 2
            start_daemon
            ;;
        "status")
            client_status
            ;;
        "test")
            log "🧪 Teste Handshake-Verbindung..."
            perform_handshake
            ;;
        "continuous")
            # Interner Aufruf für kontinuierlichen Modus
            continuous_handshake
            ;;
        *)
            echo "🤝 GENTLEMAN I7 Mobile Client"
            echo "============================"
            echo
            echo "Usage: $0 {start|stop|restart|status|test}"
            echo
            echo "Befehle:"
            echo "  start    - Starte kontinuierlichen Handshake-Client"
            echo "  stop     - Stoppe Handshake-Client"
            echo "  restart  - Neustart des Clients"
            echo "  status   - Zeige Client-Status"
            echo "  test     - Teste einmaligen Handshake"
            echo
            exit 1
            ;;
    esac
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 

# 🚀 GENTLEMAN I7 Mobile Client
# ============================
# Intelligenter Handshake Client für I7 Node
# - Automatische Erkennung: Heimnetz vs. Mobile
# - Fallback zwischen lokalem und öffentlichem Server
# - Robuste Netzwerk-Behandlung

set -e

# Konfiguration
M1_LOCAL_HOST="192.168.68.111"
M1_LOCAL_PORT="8765"
M1_PUBLIC_URL="https://graphical-founder-cleveland-vulnerable.trycloudflare.com"
I7_NODE_ID="i7-development-node"
LOG_FILE="/tmp/i7_mobile_client.log"
PID_FILE="/tmp/i7_mobile_client.pid"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging Funktion
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1" >> "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ $1" >> "$LOG_FILE"
}

# Netzwerk-Erkennung
detect_network_mode() {
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    
    if [[ "$current_ip" =~ ^192\.168\.68\. ]]; then
        echo "home"
    elif [[ "$current_ip" =~ ^172\.20\.10\. ]]; then
        echo "hotspot"
    else
        echo "unknown"
    fi
}

# Teste lokalen M1 Server
test_local_server() {
    if curl -s --connect-timeout 5 "http://$M1_LOCAL_HOST:$M1_LOCAL_PORT/health" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Teste öffentlichen M1 Server
test_public_server() {
    if curl -s --connect-timeout 10 "$M1_PUBLIC_URL/health" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Bestimme besten Handshake-Endpoint
determine_handshake_endpoint() {
    local network_mode=$(detect_network_mode)
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    
    log "🔍 Netzwerk-Erkennung: $network_mode (IP: $current_ip)"
    
    case "$network_mode" in
        "home")
            if test_local_server; then
                echo "http://$M1_LOCAL_HOST:$M1_LOCAL_PORT"
                log "✅ Verwende lokalen M1 Server (Heimnetz)"
                return 0
            elif test_public_server; then
                echo "$M1_PUBLIC_URL"
                warning "Fallback auf öffentlichen Server (Heimnetz, aber lokal nicht erreichbar)"
                return 0
            else
                error "Kein M1 Server erreichbar (Heimnetz)"
                return 1
            fi
            ;;
        "hotspot")
            if test_public_server; then
                echo "$M1_PUBLIC_URL"
                log "✅ Verwende öffentlichen M1 Server (Hotspot-Modus)"
                return 0
            else
                error "Öffentlicher M1 Server nicht erreichbar (Hotspot-Modus)"
                return 1
            fi
            ;;
        *)
            # Unbekanntes Netzwerk - teste beide
            if test_local_server; then
                echo "http://$M1_LOCAL_HOST:$M1_LOCAL_PORT"
                log "✅ Verwende lokalen M1 Server (unbekanntes Netzwerk)"
                return 0
            elif test_public_server; then
                echo "$M1_PUBLIC_URL"
                warning "Verwende öffentlichen M1 Server (unbekanntes Netzwerk)"
                return 0
            else
                error "Kein M1 Server erreichbar (unbekanntes Netzwerk)"
                return 1
            fi
            ;;
    esac
}

# Führe einzelnen Handshake durch
perform_handshake() {
    local endpoint=$(determine_handshake_endpoint)
    if [ $? -ne 0 ]; then
        error "Kein erreichbarer Handshake-Endpoint gefunden"
        return 1
    fi
    
    local handshake_url="$endpoint/handshake"
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    
    # Handshake-Daten
    local handshake_data=$(cat << EOF
{
    "node_id": "$I7_NODE_ID",
    "ip_address": "$current_ip",
    "timestamp": $(date +%s),
    "status": "active",
    "capabilities": ["development", "testing"],
    "network_mode": "$(detect_network_mode)"
}
EOF
)
    
    log "🤝 Führe Handshake durch: $handshake_url"
    
    local response=$(curl -s --connect-timeout 10 -X POST \
        -H "Content-Type: application/json" \
        -d "$handshake_data" \
        "$handshake_url" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        success "Handshake erfolgreich: $response"
        return 0
    else
        error "Handshake fehlgeschlagen"
        return 1
    fi
}

# Kontinuierlicher Handshake-Modus
continuous_handshake() {
    log "🔄 Starte kontinuierlichen Handshake-Modus..."
    
    while true; do
        if perform_handshake; then
            success "Handshake-Zyklus abgeschlossen"
        else
            warning "Handshake-Zyklus fehlgeschlagen - Wiederholung in 60 Sekunden"
            sleep 60
            continue
        fi
        
        # Warte 30 Sekunden bis zum nächsten Handshake
        sleep 30
    done
}

# Starte Handshake Client als Daemon
start_daemon() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        warning "I7 Mobile Client läuft bereits (PID: $(cat $PID_FILE))"
        return 1
    fi
    
    log "🚀 Starte I7 Mobile Client Daemon..."
    
    # Starte als Background-Prozess
    nohup bash -c "
        cd $(pwd)
        $0 continuous
    " >> "$LOG_FILE" 2>&1 &
    
    echo $! > "$PID_FILE"
    success "I7 Mobile Client gestartet (PID: $(cat $PID_FILE))"
}

# Stoppe Handshake Client
stop_daemon() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$PID_FILE"
            success "I7 Mobile Client gestoppt (PID: $pid)"
        else
            warning "I7 Mobile Client war nicht aktiv"
            rm -f "$PID_FILE"
        fi
    else
        warning "Keine PID-Datei gefunden"
    fi
}

# Status des Clients
client_status() {
    echo "🤝 GENTLEMAN I7 Mobile Client Status"
    echo "===================================="
    
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "✅ Client Status: AKTIV (PID: $(cat $PID_FILE))"
    else
        echo "❌ Client Status: INAKTIV"
    fi
    
    local network_mode=$(detect_network_mode)
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    echo "🌐 Netzwerk: $network_mode (IP: $current_ip)"
    
    local endpoint=$(determine_handshake_endpoint 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "📡 Handshake-Endpoint: $endpoint"
    else
        echo "❌ Kein erreichbarer Handshake-Endpoint"
    fi
    
    if [ -f "$LOG_FILE" ]; then
        echo
        echo "📄 Letzte Log-Einträge:"
        tail -5 "$LOG_FILE"
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
            sleep 2
            start_daemon
            ;;
        "status")
            client_status
            ;;
        "test")
            log "🧪 Teste Handshake-Verbindung..."
            perform_handshake
            ;;
        "continuous")
            # Interner Aufruf für kontinuierlichen Modus
            continuous_handshake
            ;;
        *)
            echo "🤝 GENTLEMAN I7 Mobile Client"
            echo "============================"
            echo
            echo "Usage: $0 {start|stop|restart|status|test}"
            echo
            echo "Befehle:"
            echo "  start    - Starte kontinuierlichen Handshake-Client"
            echo "  stop     - Stoppe Handshake-Client"
            echo "  restart  - Neustart des Clients"
            echo "  status   - Zeige Client-Status"
            echo "  test     - Teste einmaligen Handshake"
            echo
            exit 1
            ;;
    esac
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 
 