#!/bin/bash

# GENTLEMAN M1 Mac - RX Node Remote Control
# Steuert die RX Node über den M1 Mac als zentralen Knotenpunkt

set -euo pipefail

# Konfiguration
M1_API_HOST="localhost"
M1_API_PORT="8765"
SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging Funktion
log() {
    echo -e "${LOG_PREFIX} $1"
}

# Erfolg Logging
log_success() {
    echo -e "${LOG_PREFIX} ${GREEN}✅ $1${NC}"
}

# Fehler Logging
log_error() {
    echo -e "${LOG_PREFIX} ${RED}❌ $1${NC}" >&2
}

# Warning Logging
log_warning() {
    echo -e "${LOG_PREFIX} ${YELLOW}⚠️ $1${NC}"
}

# Info Logging
log_info() {
    echo -e "${LOG_PREFIX} ${BLUE}ℹ️ $1${NC}"
}

# Prüfe ob M1 Handshake Server läuft
check_m1_server() {
    if ! curl -s --max-time 3 "http://${M1_API_HOST}:${M1_API_PORT}/health" > /dev/null 2>&1; then
        log_error "M1 Handshake Server nicht erreichbar (${M1_API_HOST}:${M1_API_PORT})"
        log_info "Starte den Server mit: ./handshake_m1.sh"
        return 1
    fi
    return 0
}

# API Call Funktion
call_m1_api() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    
    local url="http://${M1_API_HOST}:${M1_API_PORT}${endpoint}"
    
    if [[ "$method" == "POST" && -n "$data" ]]; then
        curl -s --max-time 10 -X POST \
             -H "Content-Type: application/json" \
             -d "$data" \
             "$url"
    elif [[ "$method" == "POST" ]]; then
        curl -s --max-time 10 -X POST "$url"
    else
        curl -s --max-time 10 "$url"
    fi
}

# RX Node Status prüfen
rx_node_status() {
    log_info "🎯 Prüfe RX Node Status über M1 Mac..."
    
    if ! check_m1_server; then
        return 1
    fi
    
    local response
    if ! response=$(call_m1_api "/admin/rx-node/status" "GET"); then
        log_error "API-Aufruf fehlgeschlagen"
        return 1
    fi
    
    # Parse JSON Response
    local status message target_ip target_mac
    status=$(echo "$response" | jq -r '.status // "unknown"')
    message=$(echo "$response" | jq -r '.message // "Keine Nachricht"')
    target_ip=$(echo "$response" | jq -r '.target_ip // "unbekannt"')
    target_mac=$(echo "$response" | jq -r '.target_mac // "unbekannt"')
    
    echo ""
    echo -e "${PURPLE}🎯 GENTLEMAN RX Node Status (über M1 Mac)${NC}"
    echo "=============================================="
    echo -e "📍 RX Node IP: ${CYAN}${target_ip}${NC}"
    echo -e "🔮 MAC-Adresse: ${CYAN}${target_mac}${NC}"
    
    if [[ "$status" == "online" ]]; then
        log_success "RX Node: ONLINE"
        echo -e "💬 ${message}"
        
        # Zeige Details falls verfügbar
        local uptime
        uptime=$(echo "$response" | jq -r '.details.uptime // ""')
        if [[ -n "$uptime" && "$uptime" != "null" ]]; then
            echo ""
            echo -e "${BLUE}📊 System-Info:${NC}"
            echo "$uptime"
        fi
    else
        log_error "RX Node: OFFLINE"
        echo -e "💬 ${message}"
        
        local error
        error=$(echo "$response" | jq -r '.details.error // ""')
        if [[ -n "$error" && "$error" != "null" ]]; then
            echo -e "🚨 Fehler: ${error}"
        fi
    fi
    
    echo ""
}

# RX Node herunterfahren
rx_node_shutdown() {
    local delay_minutes="${1:-1}"
    
    log_info "🎯 Fahre RX Node über M1 Mac herunter..."
    
    if ! check_m1_server; then
        return 1
    fi
    
    # Erstelle JSON-Payload
    local payload
    payload=$(jq -n \
        --arg source "M1 RX Control Script" \
        --argjson delay_minutes "$delay_minutes" \
        '{
            source: $source,
            delay_minutes: $delay_minutes
        }')
    
    local response
    if ! response=$(call_m1_api "/admin/rx-node/shutdown" "POST" "$payload"); then
        log_error "API-Aufruf fehlgeschlagen"
        return 1
    fi
    
    # Parse Response
    local status message
    status=$(echo "$response" | jq -r '.status // "unknown"')
    message=$(echo "$response" | jq -r '.message // "Keine Nachricht"')
    
    if [[ "$status" == "success" ]]; then
        log_success "RX Node Shutdown erfolgreich geplant"
        echo -e "💬 ${message}"
        log_info "⏰ RX Node wird in ${delay_minutes} Minute(n) heruntergefahren"
    else
        log_error "RX Node Shutdown fehlgeschlagen"
        echo -e "💬 ${message}"
        return 1
    fi
}

# RX Node aufwecken
rx_node_wakeup() {
    log_info "🔋 Wecke RX Node über M1 Mac auf..."
    
    if ! check_m1_server; then
        return 1
    fi
    
    # Erstelle JSON-Payload
    local payload
    payload=$(jq -n \
        --arg source "M1 RX Control Script" \
        '{
            source: $source
        }')
    
    local response
    if ! response=$(call_m1_api "/admin/rx-node/wakeup" "POST" "$payload"); then
        log_error "API-Aufruf fehlgeschlagen"
        return 1
    fi
    
    # Parse Response
    local status message method
    status=$(echo "$response" | jq -r '.status // "unknown"')
    message=$(echo "$response" | jq -r '.message // "Keine Nachricht"')
    method=$(echo "$response" | jq -r '.method // "unbekannt"')
    
    if [[ "$status" == "success" ]]; then
        log_success "Wake-on-LAN Packet erfolgreich gesendet"
        echo -e "💬 ${message}"
        log_info "🔧 Methode: ${method}"
        log_info "⏳ Warte auf RX Node Boot-Vorgang..."
        
        # Warte kurz und prüfe dann Status
        sleep 10
        echo ""
        rx_node_status
    else
        log_error "Wake-on-LAN fehlgeschlagen"
        echo -e "💬 ${message}"
        return 1
    fi
}

# Hilfe anzeigen
show_help() {
    echo -e "${PURPLE}🎯 GENTLEMAN M1 Mac - RX Node Remote Control${NC}"
    echo "=============================================="
    echo ""
    echo "Steuert die RX Node über den M1 Mac als zentralen Knotenpunkt."
    echo "Der M1 Mac fungiert als Gateway und API-Endpunkt für die RX Node Steuerung."
    echo ""
    echo -e "${CYAN}Verwendung:${NC}"
    echo "  $SCRIPT_NAME <command> [options]"
    echo ""
    echo -e "${CYAN}Befehle:${NC}"
    echo "  status                    - RX Node Status prüfen"
    echo "  shutdown [delay_minutes]  - RX Node herunterfahren (Standard: 1 Min)"
    echo "  wakeup                    - RX Node aufwecken (Wake-on-LAN)"
    echo "  help                      - Diese Hilfe anzeigen"
    echo ""
    echo -e "${CYAN}Beispiele:${NC}"
    echo "  $SCRIPT_NAME status       # Status der RX Node prüfen"
    echo "  $SCRIPT_NAME shutdown     # RX Node in 1 Minute herunterfahren"
    echo "  $SCRIPT_NAME shutdown 5   # RX Node in 5 Minuten herunterfahren"
    echo "  $SCRIPT_NAME wakeup       # RX Node aufwecken"
    echo ""
    echo -e "${YELLOW}Voraussetzungen:${NC}"
    echo "• M1 Handshake Server muss laufen (./handshake_m1.sh)"
    echo "• SSH-Zugriff vom M1 Mac zur RX Node"
    echo "• Wake-on-LAN für RX Node aktiviert"
    echo ""
    echo -e "${BLUE}Netzwerk-Konfiguration:${NC}"
    echo "• M1 Mac API: ${M1_API_HOST}:${M1_API_PORT}"
    echo "• RX Node IP: 192.168.68.117"
    echo "• RX Node MAC: 30:9c:23:5f:44:a8"
}

# Main Funktion
main() {
    case "${1:-help}" in
        "status")
            rx_node_status
            ;;
        "shutdown")
            local delay="${2:-1}"
            if ! [[ "$delay" =~ ^[0-9]+$ ]]; then
                log_error "Ungültiger Delay-Wert: $delay (muss eine Zahl sein)"
                exit 1
            fi
            rx_node_shutdown "$delay"
            ;;
        "wakeup")
            rx_node_wakeup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unbekannter Befehl: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Prüfe Dependencies
if ! command -v curl > /dev/null 2>&1; then
    log_error "curl ist nicht installiert"
    exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
    log_error "jq ist nicht installiert (brew install jq)"
    exit 1
fi

# Führe Main-Funktion aus
main "$@" 

# GENTLEMAN M1 Mac - RX Node Remote Control
# Steuert die RX Node über den M1 Mac als zentralen Knotenpunkt

set -euo pipefail

# Konfiguration
M1_API_HOST="localhost"
M1_API_PORT="8765"
SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging Funktion
log() {
    echo -e "${LOG_PREFIX} $1"
}

# Erfolg Logging
log_success() {
    echo -e "${LOG_PREFIX} ${GREEN}✅ $1${NC}"
}

# Fehler Logging
log_error() {
    echo -e "${LOG_PREFIX} ${RED}❌ $1${NC}" >&2
}

# Warning Logging
log_warning() {
    echo -e "${LOG_PREFIX} ${YELLOW}⚠️ $1${NC}"
}

# Info Logging
log_info() {
    echo -e "${LOG_PREFIX} ${BLUE}ℹ️ $1${NC}"
}

# Prüfe ob M1 Handshake Server läuft
check_m1_server() {
    if ! curl -s --max-time 3 "http://${M1_API_HOST}:${M1_API_PORT}/health" > /dev/null 2>&1; then
        log_error "M1 Handshake Server nicht erreichbar (${M1_API_HOST}:${M1_API_PORT})"
        log_info "Starte den Server mit: ./handshake_m1.sh"
        return 1
    fi
    return 0
}

# API Call Funktion
call_m1_api() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    
    local url="http://${M1_API_HOST}:${M1_API_PORT}${endpoint}"
    
    if [[ "$method" == "POST" && -n "$data" ]]; then
        curl -s --max-time 10 -X POST \
             -H "Content-Type: application/json" \
             -d "$data" \
             "$url"
    elif [[ "$method" == "POST" ]]; then
        curl -s --max-time 10 -X POST "$url"
    else
        curl -s --max-time 10 "$url"
    fi
}

# RX Node Status prüfen
rx_node_status() {
    log_info "🎯 Prüfe RX Node Status über M1 Mac..."
    
    if ! check_m1_server; then
        return 1
    fi
    
    local response
    if ! response=$(call_m1_api "/admin/rx-node/status" "GET"); then
        log_error "API-Aufruf fehlgeschlagen"
        return 1
    fi
    
    # Parse JSON Response
    local status message target_ip target_mac
    status=$(echo "$response" | jq -r '.status // "unknown"')
    message=$(echo "$response" | jq -r '.message // "Keine Nachricht"')
    target_ip=$(echo "$response" | jq -r '.target_ip // "unbekannt"')
    target_mac=$(echo "$response" | jq -r '.target_mac // "unbekannt"')
    
    echo ""
    echo -e "${PURPLE}🎯 GENTLEMAN RX Node Status (über M1 Mac)${NC}"
    echo "=============================================="
    echo -e "📍 RX Node IP: ${CYAN}${target_ip}${NC}"
    echo -e "🔮 MAC-Adresse: ${CYAN}${target_mac}${NC}"
    
    if [[ "$status" == "online" ]]; then
        log_success "RX Node: ONLINE"
        echo -e "💬 ${message}"
        
        # Zeige Details falls verfügbar
        local uptime
        uptime=$(echo "$response" | jq -r '.details.uptime // ""')
        if [[ -n "$uptime" && "$uptime" != "null" ]]; then
            echo ""
            echo -e "${BLUE}📊 System-Info:${NC}"
            echo "$uptime"
        fi
    else
        log_error "RX Node: OFFLINE"
        echo -e "💬 ${message}"
        
        local error
        error=$(echo "$response" | jq -r '.details.error // ""')
        if [[ -n "$error" && "$error" != "null" ]]; then
            echo -e "🚨 Fehler: ${error}"
        fi
    fi
    
    echo ""
}

# RX Node herunterfahren
rx_node_shutdown() {
    local delay_minutes="${1:-1}"
    
    log_info "🎯 Fahre RX Node über M1 Mac herunter..."
    
    if ! check_m1_server; then
        return 1
    fi
    
    # Erstelle JSON-Payload
    local payload
    payload=$(jq -n \
        --arg source "M1 RX Control Script" \
        --argjson delay_minutes "$delay_minutes" \
        '{
            source: $source,
            delay_minutes: $delay_minutes
        }')
    
    local response
    if ! response=$(call_m1_api "/admin/rx-node/shutdown" "POST" "$payload"); then
        log_error "API-Aufruf fehlgeschlagen"
        return 1
    fi
    
    # Parse Response
    local status message
    status=$(echo "$response" | jq -r '.status // "unknown"')
    message=$(echo "$response" | jq -r '.message // "Keine Nachricht"')
    
    if [[ "$status" == "success" ]]; then
        log_success "RX Node Shutdown erfolgreich geplant"
        echo -e "💬 ${message}"
        log_info "⏰ RX Node wird in ${delay_minutes} Minute(n) heruntergefahren"
    else
        log_error "RX Node Shutdown fehlgeschlagen"
        echo -e "💬 ${message}"
        return 1
    fi
}

# RX Node aufwecken
rx_node_wakeup() {
    log_info "🔋 Wecke RX Node über M1 Mac auf..."
    
    if ! check_m1_server; then
        return 1
    fi
    
    # Erstelle JSON-Payload
    local payload
    payload=$(jq -n \
        --arg source "M1 RX Control Script" \
        '{
            source: $source
        }')
    
    local response
    if ! response=$(call_m1_api "/admin/rx-node/wakeup" "POST" "$payload"); then
        log_error "API-Aufruf fehlgeschlagen"
        return 1
    fi
    
    # Parse Response
    local status message method
    status=$(echo "$response" | jq -r '.status // "unknown"')
    message=$(echo "$response" | jq -r '.message // "Keine Nachricht"')
    method=$(echo "$response" | jq -r '.method // "unbekannt"')
    
    if [[ "$status" == "success" ]]; then
        log_success "Wake-on-LAN Packet erfolgreich gesendet"
        echo -e "💬 ${message}"
        log_info "🔧 Methode: ${method}"
        log_info "⏳ Warte auf RX Node Boot-Vorgang..."
        
        # Warte kurz und prüfe dann Status
        sleep 10
        echo ""
        rx_node_status
    else
        log_error "Wake-on-LAN fehlgeschlagen"
        echo -e "💬 ${message}"
        return 1
    fi
}

# Hilfe anzeigen
show_help() {
    echo -e "${PURPLE}🎯 GENTLEMAN M1 Mac - RX Node Remote Control${NC}"
    echo "=============================================="
    echo ""
    echo "Steuert die RX Node über den M1 Mac als zentralen Knotenpunkt."
    echo "Der M1 Mac fungiert als Gateway und API-Endpunkt für die RX Node Steuerung."
    echo ""
    echo -e "${CYAN}Verwendung:${NC}"
    echo "  $SCRIPT_NAME <command> [options]"
    echo ""
    echo -e "${CYAN}Befehle:${NC}"
    echo "  status                    - RX Node Status prüfen"
    echo "  shutdown [delay_minutes]  - RX Node herunterfahren (Standard: 1 Min)"
    echo "  wakeup                    - RX Node aufwecken (Wake-on-LAN)"
    echo "  help                      - Diese Hilfe anzeigen"
    echo ""
    echo -e "${CYAN}Beispiele:${NC}"
    echo "  $SCRIPT_NAME status       # Status der RX Node prüfen"
    echo "  $SCRIPT_NAME shutdown     # RX Node in 1 Minute herunterfahren"
    echo "  $SCRIPT_NAME shutdown 5   # RX Node in 5 Minuten herunterfahren"
    echo "  $SCRIPT_NAME wakeup       # RX Node aufwecken"
    echo ""
    echo -e "${YELLOW}Voraussetzungen:${NC}"
    echo "• M1 Handshake Server muss laufen (./handshake_m1.sh)"
    echo "• SSH-Zugriff vom M1 Mac zur RX Node"
    echo "• Wake-on-LAN für RX Node aktiviert"
    echo ""
    echo -e "${BLUE}Netzwerk-Konfiguration:${NC}"
    echo "• M1 Mac API: ${M1_API_HOST}:${M1_API_PORT}"
    echo "• RX Node IP: 192.168.68.117"
    echo "• RX Node MAC: 30:9c:23:5f:44:a8"
}

# Main Funktion
main() {
    case "${1:-help}" in
        "status")
            rx_node_status
            ;;
        "shutdown")
            local delay="${2:-1}"
            if ! [[ "$delay" =~ ^[0-9]+$ ]]; then
                log_error "Ungültiger Delay-Wert: $delay (muss eine Zahl sein)"
                exit 1
            fi
            rx_node_shutdown "$delay"
            ;;
        "wakeup")
            rx_node_wakeup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unbekannter Befehl: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Prüfe Dependencies
if ! command -v curl > /dev/null 2>&1; then
    log_error "curl ist nicht installiert"
    exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
    log_error "jq ist nicht installiert (brew install jq)"
    exit 1
fi

# Führe Main-Funktion aus
main "$@" 
 