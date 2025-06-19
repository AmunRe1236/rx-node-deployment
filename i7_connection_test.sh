#!/bin/bash

# GENTLEMAN I7 Node - M1 Connection Test Client
# Testet die Verbindung vom I7 Node zum M1 Mac über Nebula VPN

set -e

echo "💻 GENTLEMAN I7 → M1 Connection Test Client"
echo "=========================================="

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Test-Konfiguration
M1_LOCAL_IP="192.168.68.111"
M1_VPN_IP="192.168.100.1"
I7_LOCAL_IP="192.168.68.105"
I7_VPN_IP="192.168.100.30"

GIT_DAEMON_PORT="9418"
HANDSHAKE_PORT="8765"
GITEA_PORT="3010"

# I7 Node spezifische Tests
test_i7_to_m1_connectivity() {
    log "🔗 Teste I7 → M1 Konnektivität..."
    
    # Basis-Netzwerk Tests
    info "🌐 Teste Netzwerk-Erreichbarkeit..."
    
    if ping -c 3 -W 5000 $M1_LOCAL_IP > /dev/null 2>&1; then
        success "✅ M1 Mac über lokales Netzwerk erreichbar"
        local latency=$(ping -c 3 $M1_LOCAL_IP | tail -1 | awk -F'/' '{print $5}')
        info "   📊 Lokale Latenz: ${latency}ms"
    else
        error "❌ M1 Mac über lokales Netzwerk nicht erreichbar"
        return 1
    fi
    
    # VPN-Konnektivität (falls aktiv)
    if ip route show | grep -q "192.168.100"; then
        info "🔒 Nebula VPN Route gefunden - teste VPN-Konnektivität..."
        
        if ping -c 3 -W 5000 $M1_VPN_IP > /dev/null 2>&1; then
            success "✅ M1 Mac über Nebula VPN erreichbar"
            local vpn_latency=$(ping -c 3 $M1_VPN_IP | tail -1 | awk -F'/' '{print $5}')
            info "   📊 VPN Latenz: ${vpn_latency}ms"
        else
            warning "⚠️ M1 Mac über VPN nicht erreichbar"
        fi
    else
        warning "⚠️ Nebula VPN Route nicht gefunden"
    fi
}

# Service-Erreichbarkeit Tests
test_m1_services() {
    log "🔧 Teste M1 Services vom I7 aus..."
    
    # Git Daemon Test
    info "📦 Teste Git Daemon..."
    if nc -z -w 5 $M1_LOCAL_IP $GIT_DAEMON_PORT; then
        success "✅ Git Daemon (lokal) erreichbar"
        
        # Teste Git ls-remote
        if timeout 15 git ls-remote git://$M1_LOCAL_IP:$GIT_DAEMON_PORT/Gentleman > /dev/null 2>&1; then
            success "✅ Git Repository Zugriff funktioniert"
        else
            warning "⚠️ Git Repository Zugriff fehlgeschlagen"
        fi
    else
        error "❌ Git Daemon (lokal) nicht erreichbar"
    fi
    
    # VPN Git Daemon Test
    if nc -z -w 5 $M1_VPN_IP $GIT_DAEMON_PORT; then
        success "✅ Git Daemon (VPN) erreichbar"
    else
        warning "⚠️ Git Daemon (VPN) nicht erreichbar"
    fi
    
    # Handshake Server Test
    info "🤝 Teste Handshake Server..."
    if nc -z -w 5 $M1_LOCAL_IP $HANDSHAKE_PORT; then
        success "✅ Handshake Server (lokal) erreichbar"
        
        # Teste Handshake API
        if curl -s -f --max-time 10 http://$M1_LOCAL_IP:$HANDSHAKE_PORT/health > /dev/null; then
            success "✅ Handshake Server API funktioniert"
        else
            warning "⚠️ Handshake Server API nicht erreichbar"
        fi
    else
        error "❌ Handshake Server (lokal) nicht erreichbar"
    fi
    
    # VPN Handshake Server Test
    if nc -z -w 5 $M1_VPN_IP $HANDSHAKE_PORT; then
        success "✅ Handshake Server (VPN) erreichbar"
    else
        warning "⚠️ Handshake Server (VPN) nicht erreichbar"
    fi
}

# I7 Sync Client Test
test_i7_sync_client() {
    log "🔄 Teste I7 Sync Client..."
    
    if [ -f "i7_gitea_sync_client.py" ]; then
        info "📋 I7 Sync Client gefunden - teste Funktionalität..."
        
        # Test-Modus Ausführung
        if timeout 30 python3 i7_gitea_sync_client.py --once 2>/dev/null; then
            success "✅ I7 Sync Client funktioniert"
        else
            warning "⚠️ I7 Sync Client Test fehlgeschlagen"
        fi
        
        # Prüfe Log-Datei
        if [ -f "/tmp/i7_gitea_sync.log" ]; then
            local log_size=$(stat -f%z "/tmp/i7_gitea_sync.log" 2>/dev/null || echo "0")
            if [ "$log_size" -gt 0 ]; then
                info "📋 Sync Log-Datei: ${log_size} Bytes"
                info "   Letzte Einträge:"
                tail -3 /tmp/i7_gitea_sync.log | sed 's/^/   /'
            fi
        fi
    else
        warning "⚠️ I7 Sync Client nicht gefunden"
    fi
}

# Simuliere Handshake Request
test_handshake_request() {
    log "🤝 Simuliere Handshake Request..."
    
    local handshake_data=$(cat <<EOF
{
    "node_id": "i7-development-node",
    "ip": "$I7_LOCAL_IP",
    "vpn_ip": "$I7_VPN_IP",
    "status": "active",
    "timestamp": $(date +%s),
    "capabilities": ["development", "git-client", "nebula-client"]
}
EOF
)
    
    # Lokaler Handshake
    if nc -z -w 3 $M1_LOCAL_IP $HANDSHAKE_PORT; then
        info "📡 Sende Handshake Request (lokal)..."
        local response=$(curl -s --max-time 10 -X POST \
            -H "Content-Type: application/json" \
            -d "$handshake_data" \
            http://$M1_LOCAL_IP:$HANDSHAKE_PORT/handshake)
        
        if [ $? -eq 0 ]; then
            success "✅ Handshake Request erfolgreich"
            info "   Response: $response"
        else
            warning "⚠️ Handshake Request fehlgeschlagen"
        fi
    fi
    
    # VPN Handshake
    if nc -z -w 3 $M1_VPN_IP $HANDSHAKE_PORT; then
        info "📡 Sende Handshake Request (VPN)..."
        local vpn_response=$(curl -s --max-time 10 -X POST \
            -H "Content-Type: application/json" \
            -d "$handshake_data" \
            http://$M1_VPN_IP:$HANDSHAKE_PORT/handshake)
        
        if [ $? -eq 0 ]; then
            success "✅ VPN Handshake Request erfolgreich"
            info "   Response: $vpn_response"
        else
            warning "⚠️ VPN Handshake Request fehlgeschlagen"
        fi
    fi
}

# Performance Benchmarks
test_i7_performance() {
    log "⚡ Performance Tests vom I7 aus..."
    
    # Git Clone Performance
    info "📦 Git Performance Test..."
    if nc -z -w 3 $M1_LOCAL_IP $GIT_DAEMON_PORT; then
        local temp_dir=$(mktemp -d)
        local start_time=$(date +%s.%N)
        
        if timeout 60 git clone git://$M1_LOCAL_IP:$GIT_DAEMON_PORT/Gentleman "$temp_dir/test-clone" > /dev/null 2>&1; then
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc)
            success "✅ Git Clone erfolgreich"
            info "   📊 Clone Dauer: ${duration}s"
            
            # Cleanup
            rm -rf "$temp_dir"
        else
            warning "⚠️ Git Clone fehlgeschlagen"
        fi
    fi
    
    # HTTP Performance
    info "🌐 HTTP Performance Test..."
    if nc -z -w 3 $M1_LOCAL_IP $HANDSHAKE_PORT; then
        local start_time=$(date +%s.%N)
        
        for i in {1..5}; do
            curl -s --max-time 5 http://$M1_LOCAL_IP:$HANDSHAKE_PORT/health > /dev/null
        done
        
        local end_time=$(date +%s.%N)
        local avg_duration=$(echo "scale=3; ($end_time - $start_time) / 5" | bc)
        info "   📊 Durchschnittliche HTTP Response Zeit: ${avg_duration}s"
    fi
}

# Systeminformationen vom I7
show_i7_system_info() {
    log "📊 I7 Node System-Informationen..."
    
    echo ""
    info "💻 I7 Development Node:"
    info "   Hostname: $(hostname)"
    info "   Lokale IP: $I7_LOCAL_IP"
    info "   VPN IP: $I7_VPN_IP"
    info "   OS: $(uname -s) $(uname -r)"
    
    # Netzwerk Interface Info
    if command -v ip &> /dev/null; then
        info "🌐 Netzwerk Interfaces:"
        ip addr show | grep -E "inet.*192\.168\." | sed 's/^/   /'
    fi
    
    # Nebula Status
    if pgrep -f nebula > /dev/null; then
        success "✅ Nebula VPN läuft"
        
        if ip route show | grep -q "192.168.100"; then
            success "✅ Nebula VPN Route aktiv"
            ip route show | grep "192.168.100" | sed 's/^/   /'
        fi
    else
        warning "⚠️ Nebula VPN nicht aktiv"
    fi
}

# Kontinuierlicher Monitoring-Modus
continuous_monitor() {
    log "📊 Starte kontinuierliches Monitoring..."
    info "   Drücke Ctrl+C zum Beenden"
    
    while true; do
        clear
        echo "💻 I7 → M1 Continuous Monitor $(date)"
        echo "========================================"
        
        # Basis-Konnektivität
        if ping -c 1 -W 3000 $M1_LOCAL_IP > /dev/null 2>&1; then
            echo -e "${GREEN}✅ M1 Mac erreichbar${NC}"
        else
            echo -e "${RED}❌ M1 Mac nicht erreichbar${NC}"
        fi
        
        # Service-Status
        if nc -z -w 2 $M1_LOCAL_IP $GIT_DAEMON_PORT; then
            echo -e "${GREEN}✅ Git Daemon aktiv${NC}"
        else
            echo -e "${RED}❌ Git Daemon inaktiv${NC}"
        fi
        
        if nc -z -w 2 $M1_LOCAL_IP $HANDSHAKE_PORT; then
            echo -e "${GREEN}✅ Handshake Server aktiv${NC}"
        else
            echo -e "${RED}❌ Handshake Server inaktiv${NC}"
        fi
        
        # VPN Status
        if ping -c 1 -W 3000 $M1_VPN_IP > /dev/null 2>&1; then
            echo -e "${GREEN}✅ VPN Verbindung aktiv${NC}"
        else
            echo -e "${YELLOW}⚠️ VPN Verbindung inaktiv${NC}"
        fi
        
        echo ""
        echo "Nächstes Update in 10 Sekunden..."
        sleep 10
    done
}

# Hauptfunktion
main() {
    case "${1:-full}" in
        "--quick" | "-q")
            log "🚀 Schneller I7 → M1 Test..."
            show_i7_system_info
            test_i7_to_m1_connectivity
            ;;
        "--services" | "-s")
            log "🔧 I7 → M1 Service Tests..."
            test_i7_to_m1_connectivity
            test_m1_services
            ;;
        "--sync" | "-y")
            log "🔄 I7 Sync Client Tests..."
            test_i7_sync_client
            test_handshake_request
            ;;
        "--performance" | "-p")
            log "⚡ I7 → M1 Performance Tests..."
            test_i7_to_m1_connectivity
            test_i7_performance
            ;;
        "--monitor" | "-m")
            continuous_monitor
            ;;
        *)
            # Vollständiger Test
            log "🚀 Vollständiger I7 → M1 Connection Test..."
            
            show_i7_system_info
            test_i7_to_m1_connectivity
            test_m1_services
            test_i7_sync_client
            test_handshake_request
            test_i7_performance
            ;;
    esac
    
    echo ""
    log "🎯 I7 → M1 Connection Test abgeschlossen!"
    
    echo ""
    info "🔧 Verfügbare Modi:"
    info "   ./i7_connection_test.sh --quick      # Schneller Test"
    info "   ./i7_connection_test.sh --services   # Service Tests"
    info "   ./i7_connection_test.sh --sync       # Sync Client Tests"
    info "   ./i7_connection_test.sh --performance # Performance Tests"
    info "   ./i7_connection_test.sh --monitor    # Kontinuierliches Monitoring"
}

# Führe Hauptfunktion aus
main "$@" 