#!/bin/bash

# GENTLEMAN AMD AI Client
# Optimiert für AMD RX 6700 XT AI Server

# Konfiguration
RX_NODE_IP=""
AI_PORT="8765"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Finde RX Node
find_rx_node() {
    # Erst Tailscale versuchen
    RX_NODE_IP=$(tailscale status 2>/dev/null | grep "archlinux" | awk '{print $1}')
    
    if [ -z "$RX_NODE_IP" ]; then
        # Fallback auf lokales Netzwerk
        RX_NODE_IP="192.168.68.117"
        log_info "Nutze lokale IP: $RX_NODE_IP"
    else
        log_success "RX Node über Tailscale gefunden: $RX_NODE_IP"
    fi
}

# AMD GPU Status
gpu_status() {
    find_rx_node
    log_info "📊 Hole AMD GPU Status..."
    
    response=$(curl -s --max-time 10 "http://$RX_NODE_IP:$AI_PORT/gpu/status")
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
    else
        log_error "GPU Status nicht verfügbar"
        return 1
    fi
}

# Text Generation
generate_text() {
    find_rx_node
    local prompt="$1"
    local max_length="${2:-100}"
    
    if [ -z "$prompt" ]; then
        echo "Verwendung: $0 generate '<prompt>' [max_length]"
        return 1
    fi
    
    log_info "🤖 Generiere Text mit AMD GPU..."
    
    response=$(curl -s --max-time 30 \
        -H "Content-Type: application/json" \
        -d "{\"prompt\": \"$prompt\", \"max_length\": $max_length}" \
        "http://$RX_NODE_IP:$AI_PORT/ai/text/generate")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Text generiert"
    else
        log_error "Text-Generierung fehlgeschlagen"
        return 1
    fi
}

# Sentiment Analysis
analyze_sentiment() {
    find_rx_node
    local text="$1"
    
    if [ -z "$text" ]; then
        echo "Verwendung: $0 sentiment '<text>'"
        return 1
    fi
    
    log_info "😊 Analysiere Sentiment..."
    
    response=$(curl -s --max-time 15 \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$text\"}" \
        "http://$RX_NODE_IP:$AI_PORT/ai/text/sentiment")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Sentiment analysiert"
    else
        log_error "Sentiment-Analyse fehlgeschlagen"
        return 1
    fi
}

# Text Summarization
summarize_text() {
    find_rx_node
    local text="$1"
    local max_length="${2:-150}"
    
    if [ -z "$text" ]; then
        echo "Verwendung: $0 summarize '<text>' [max_length]"
        return 1
    fi
    
    log_info "📄 Erstelle Zusammenfassung..."
    
    response=$(curl -s --max-time 30 \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$text\", \"max_length\": $max_length}" \
        "http://$RX_NODE_IP:$AI_PORT/ai/text/summarize")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Text zusammengefasst"
    else
        log_error "Zusammenfassung fehlgeschlagen"
        return 1
    fi
}

# GPU Benchmark
benchmark() {
    find_rx_node
    log_info "🏃 Starte AMD GPU Benchmark..."
    
    response=$(curl -s --max-time 60 "http://$RX_NODE_IP:$AI_PORT/ai/benchmark")
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Benchmark abgeschlossen"
    else
        log_error "Benchmark fehlgeschlagen"
        return 1
    fi
}

# Health Check
health() {
    find_rx_node
    log_info "🔍 Prüfe AMD AI Server..."
    
    response=$(curl -s --max-time 5 "http://$RX_NODE_IP:$AI_PORT/health")
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "AMD AI Server ist erreichbar"
    else
        log_error "AMD AI Server nicht erreichbar"
        return 1
    fi
}

# Hauptfunktion
main() {
    case "${1:-health}" in
        "health")
            health
            ;;
        "gpu"|"status")
            gpu_status
            ;;
        "generate"|"gen")
            generate_text "$2" "$3"
            ;;
        "sentiment")
            analyze_sentiment "$2"
            ;;
        "summarize"|"sum")
            summarize_text "$2" "$3"
            ;;
        "benchmark"|"bench")
            benchmark
            ;;
        *)
            echo -e "${PURPLE}🤖 GENTLEMAN AMD AI Client${NC}"
            echo "================================"
            echo ""
            echo "Kommandos:"
            echo "  health                    - AI Server Health Check"
            echo "  gpu|status                - AMD GPU Status"
            echo "  generate '<prompt>' [len] - Text Generation"
            echo "  sentiment '<text>'        - Sentiment Analysis"
            echo "  summarize '<text>' [len]  - Text Summarization"
            echo "  benchmark                 - GPU Benchmark"
            echo ""
            echo "Beispiele:"
            echo "  $0 health"
            echo "  $0 gpu"
            echo "  $0 generate 'Erkläre mir KI' 200"
            echo "  $0 sentiment 'Ich liebe dieses Produkt!'"
            echo "  $0 summarize 'Langer Text hier...' 100"
            echo "  $0 benchmark"
            ;;
    esac
}

main "$@"
