#!/bin/bash

# GENTLEMAN AI Client
# Nutzt RX Node AI Services über Tailscale

# Konfiguration
RX_NODE_IP=""  # Wird automatisch ermittelt
AI_PORT="8765"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Finde RX Node in Tailscale
find_rx_node() {
    RX_NODE_IP=$(tailscale status | grep "archlinux" | awk '{print $1}')
    
    if [ -z "$RX_NODE_IP" ]; then
        log_error "RX Node nicht im Tailscale Netzwerk gefunden"
        echo "Verfügbare Nodes:"
        tailscale status
        return 1
    fi
    
    log_success "RX Node gefunden: $RX_NODE_IP"
    return 0
}

# AI Health Check
ai_health() {
    if ! find_rx_node; then return 1; fi
    
    log_info "🔍 Prüfe AI Server Status..."
    
    response=$(curl -s --max-time 5 "http://$RX_NODE_IP:$AI_PORT/health")
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "AI Server ist erreichbar"
    else
        log_error "AI Server nicht erreichbar"
        return 1
    fi
}

# AI Status
ai_status() {
    if ! find_rx_node; then return 1; fi
    
    log_info "📊 Hole AI System Status..."
    
    response=$(curl -s --max-time 5 "http://$RX_NODE_IP:$AI_PORT/ai/status")
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
    else
        log_error "Konnte AI Status nicht abrufen"
        return 1
    fi
}

# Text Processing
ai_text() {
    if ! find_rx_node; then return 1; fi
    
    local text="$1"
    if [ -z "$text" ]; then
        echo "Verwendung: $0 text '<text>'"
        return 1
    fi
    
    log_info "📝 Verarbeite Text über AI..."
    
    response=$(curl -s --max-time 10 \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$text\"}" \
        "http://$RX_NODE_IP:$AI_PORT/ai/text/process")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Text verarbeitet"
    else
        log_error "Text-Verarbeitung fehlgeschlagen"
        return 1
    fi
}

# Data Computation
ai_compute() {
    if ! find_rx_node; then return 1; fi
    
    local numbers="$1"
    local operation="${2:-sum}"
    
    if [ -z "$numbers" ]; then
        echo "Verwendung: $0 compute '[1,2,3,4,5]' [sum|average|max]"
        return 1
    fi
    
    log_info "🔢 Führe Berechnung aus..."
    
    response=$(curl -s --max-time 10 \
        -H "Content-Type: application/json" \
        -d "{\"numbers\": $numbers, \"operation\": \"$operation\"}" \
        "http://$RX_NODE_IP:$AI_PORT/ai/compute")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Berechnung abgeschlossen"
    else
        log_error "Berechnung fehlgeschlagen"
        return 1
    fi
}

# Hauptfunktion
main() {
    case "${1:-health}" in
        "health")
            ai_health
            ;;
        "status")
            ai_status
            ;;
        "text")
            ai_text "$2"
            ;;
        "compute")
            ai_compute "$2" "$3"
            ;;
        "find")
            find_rx_node
            ;;
        *)
            echo "🤖 GENTLEMAN AI Client"
            echo "====================="
            echo ""
            echo "Kommandos:"
            echo "  health              - AI Server Health Check"
            echo "  status              - AI System Status"
            echo "  text '<text>'       - Text Processing"
            echo "  compute '[nums]' op - Data Computation"
            echo "  find                - Finde RX Node"
            echo ""
            echo "Beispiele:"
            echo "  $0 health"
            echo "  $0 status"
            echo "  $0 text 'Hello World'"
            echo "  $0 compute '[1,2,3,4,5]' sum"
            echo "  $0 compute '[10,20,30]' average"
            ;;
    esac
}

main "$@"
