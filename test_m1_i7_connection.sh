#!/bin/bash

# GENTLEMAN Cluster - M1 ↔ I7 Back-to-Back Connection Test
# Testet vollständige Konnektivität zwischen M1 Mac und I7 Node über Nebula VPN

# Entferne set -e um bei Fehlern weiterzumachen
# set -e

echo "🔗 GENTLEMAN M1 ↔ I7 Back-to-Back Connection Test"
echo "================================================="

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

# Test-Ergebnisse (kompatibel mit macOS bash)
test_results=()

# Hilfsfunktion für Test-Durchführung
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="${3:-0}"
    
    log "🧪 Test: $test_name"
    
    if eval "$test_command" > /dev/null 2>&1; then
        if [ "$expected_result" = "0" ]; then
            success "✅ $test_name - PASSED"
            echo "$test_name:PASS" >> /tmp/test_results.log
            return 0
        else
            warning "⚠️ $test_name - UNEXPECTED SUCCESS"
            echo "$test_name:WARN" >> /tmp/test_results.log
            return 1
        fi
    else
        if [ "$expected_result" = "0" ]; then
            error "❌ $test_name - FAILED"
            echo "$test_name:FAIL" >> /tmp/test_results.log
            return 1
        else
            success "✅ $test_name - EXPECTED FAILURE"
            echo "$test_name:PASS" >> /tmp/test_results.log
            return 0
        fi
    fi
}

# System-Informationen sammeln
gather_system_info() {
    log "📊 Sammle System-Informationen..."
    
    echo ""
    info "🖥️ M1 Mac (Coordinator):"
    info "   Lokale IP: $M1_LOCAL_IP"
    info "   VPN IP: $M1_VPN_IP"
    info "   Rolle: Git Server, Handshake Server, Nebula Lighthouse"
    
    echo ""
    info "💻 I7 Node (Development):"
    info "   Lokale IP: $I7_LOCAL_IP"
    info "   VPN IP: $I7_VPN_IP"
    info "   Rolle: Git Client, Development Node"
    
    echo ""
    info "🔧 Test-Konfiguration:"
    info "   Git Daemon Port: $GIT_DAEMON_PORT"
    info "   Handshake Port: $HANDSHAKE_PORT"
    info "   Gitea Port: $GITEA_PORT"
}

# Netzwerk-Konnektivitätstests
test_network_connectivity() {
    log "🌐 Teste Netzwerk-Konnektivität..."
    
    # Lokale Netzwerk-Konnektivität
    run_test "M1 Ping (Lokal)" "ping -c 1 -W 3000 $M1_LOCAL_IP"
    run_test "I7 Ping (Lokal)" "ping -c 1 -W 3000 $I7_LOCAL_IP"
    
    # VPN-Konnektivität (falls Nebula läuft) - macOS kompatibel
    if ifconfig | grep -q "$M1_VPN_IP\|$I7_VPN_IP"; then
        run_test "M1 Ping (VPN)" "ping -c 1 -W 3000 $M1_VPN_IP"
        run_test "I7 Ping (VPN)" "ping -c 1 -W 3000 $I7_VPN_IP"
    else
        warning "⚠️ Nebula VPN Interface nicht gefunden - überspringe VPN-Tests"
    fi
}

# Port-Konnektivitätstests
test_port_connectivity() {
    log "🔌 Teste Port-Konnektivität..."
    
    # Git Daemon Tests - teste localhost und externe IP
    run_test "Git Daemon (Localhost)" "nc -z -w 3 localhost $GIT_DAEMON_PORT"
    run_test "Git Daemon (M1 Lokal)" "nc -z -w 3 $M1_LOCAL_IP $GIT_DAEMON_PORT"
    run_test "Git Daemon (M1 VPN)" "nc -z -w 3 $M1_VPN_IP $GIT_DAEMON_PORT"
    
    # Handshake Server Tests
    run_test "Handshake Server (M1 Lokal)" "nc -z -w 3 $M1_LOCAL_IP $HANDSHAKE_PORT"
    run_test "Handshake Server (M1 VPN)" "nc -z -w 3 $M1_VPN_IP $HANDSHAKE_PORT"
    
    # Gitea Server Tests
    run_test "Gitea Server (Localhost)" "nc -z -w 3 localhost $GITEA_PORT"
}

# Git-Service Tests
test_git_services() {
    log "📦 Teste Git-Services..."
    
    # Git Daemon Tests - Localhost zuerst
    if nc -z -w 3 localhost $GIT_DAEMON_PORT; then
        run_test "Git ls-remote (Localhost)" "timeout 10 git ls-remote git://localhost:$GIT_DAEMON_PORT/Gentleman"
    fi
    
    # Git Daemon Tests - M1 Lokal IP
    if nc -z -w 3 $M1_LOCAL_IP $GIT_DAEMON_PORT; then
        run_test "Git ls-remote (M1 Lokal)" "timeout 10 git ls-remote git://$M1_LOCAL_IP:$GIT_DAEMON_PORT/Gentleman"
    fi
    
    # Git Daemon Tests - M1 VPN IP
    if nc -z -w 3 $M1_VPN_IP $GIT_DAEMON_PORT; then
        run_test "Git ls-remote (M1 VPN)" "timeout 10 git ls-remote git://$M1_VPN_IP:$GIT_DAEMON_PORT/Gentleman"
    fi
    
    # Gitea API Tests
    if nc -z -w 3 localhost $GITEA_PORT; then
        run_test "Gitea Health Check" "curl -s -f --max-time 5 http://localhost:$GITEA_PORT/api/healthz"
        run_test "Gitea Version API" "curl -s -f --max-time 5 http://localhost:$GITEA_PORT/api/v1/version"
    fi
}

# Handshake-System Tests
test_handshake_system() {
    log "🤝 Teste Handshake-System..."
    
    # Handshake Server Tests
    if nc -z -w 3 $M1_LOCAL_IP $HANDSHAKE_PORT; then
        run_test "Handshake Health (M1 Lokal)" "curl -s -f --max-time 5 http://$M1_LOCAL_IP:$HANDSHAKE_PORT/health"
        run_test "Handshake Status (M1 Lokal)" "curl -s -f --max-time 5 http://$M1_LOCAL_IP:$HANDSHAKE_PORT/status"
    fi
    
    if nc -z -w 3 $M1_VPN_IP $HANDSHAKE_PORT; then
        run_test "Handshake Health (M1 VPN)" "curl -s -f --max-time 5 http://$M1_VPN_IP:$HANDSHAKE_PORT/health"
        run_test "Handshake Status (M1 VPN)" "curl -s -f --max-time 5 http://$M1_VPN_IP:$HANDSHAKE_PORT/status"
    fi
}

# Nebula VPN Status
test_nebula_vpn() {
    log "🔒 Teste Nebula VPN Status..."
    
    # Prüfe Nebula Prozesse
    if pgrep -f nebula > /dev/null; then
        success "✅ Nebula Prozess läuft"
        echo "Nebula Process:PASS" >> /tmp/test_results.log
        
        # Zeige Nebula Status (falls verfügbar)
        if command -v nebula-cert &> /dev/null; then
            info "📋 Nebula Informationen verfügbar"
        fi
        
        # Prüfe VPN Interface
        if ifconfig | grep -q "192.168.100"; then
            success "✅ Nebula VPN Interface aktiv"
            echo "Nebula Interface:PASS" >> /tmp/test_results.log
            
            # Zeige VPN Interface Details
            info "🔍 VPN Interface Details:"
            ifconfig | grep -A 2 -B 2 "192.168.100" || true
        else
            warning "⚠️ Nebula VPN Interface nicht gefunden"
            echo "Nebula Interface:WARN" >> /tmp/test_results.log
        fi
    else
        warning "⚠️ Nebula Prozess nicht gefunden"
        echo "Nebula Process:WARN" >> /tmp/test_results.log
    fi
}

# Docker Services Tests
test_docker_services() {
    log "🐳 Teste Docker Services..."
    
    if command -v docker &> /dev/null; then
        if docker ps > /dev/null 2>&1; then
            success "✅ Docker läuft"
            echo "Docker:PASS" >> /tmp/test_results.log
            
            # Prüfe Gitea Container
            if docker ps --format "{{.Names}}" | grep -q "gentleman-git-server"; then
                success "✅ Gitea Container läuft"
                echo "Gitea Container:PASS" >> /tmp/test_results.log
                
                # Container Status Details
                info "📋 Gitea Container Status:"
                docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep gentleman || true
            else
                warning "⚠️ Gitea Container nicht gefunden"
                echo "Gitea Container:WARN" >> /tmp/test_results.log
            fi
        else
            error "❌ Docker Daemon nicht erreichbar"
            echo "Docker:FAIL" >> /tmp/test_results.log
        fi
    else
        warning "⚠️ Docker nicht installiert"
        echo "Docker:WARN" >> /tmp/test_results.log
    fi
}

# Simuliere I7 Sync Client Test
test_i7_sync_simulation() {
    log "🔄 Simuliere I7 Sync Client..."
    
    # Teste I7 Sync Client Skript
    if [ -f "i7_gitea_sync_client.py" ]; then
        run_test "I7 Sync Client (Test-Modus)" "timeout 10 python3 i7_gitea_sync_client.py --once"
        
        if [ -f "start_i7_sync.sh" ]; then
            success "✅ I7 Sync Starter verfügbar"
            echo "I7 Sync Scripts:PASS" >> /tmp/test_results.log
        fi
    else
        warning "⚠️ I7 Sync Client Skript nicht gefunden"
        echo "I7 Sync Scripts:WARN" >> /tmp/test_results.log
    fi
}

# Performance und Latenz Tests
test_performance() {
    log "⚡ Teste Performance und Latenz..."
    
    # Ping-Latenz Tests
    if ping -c 1 -W 3000 $M1_LOCAL_IP > /dev/null 2>&1; then
        local latency=$(ping -c 3 $M1_LOCAL_IP | tail -1 | awk -F'/' '{print $5}')
        info "📊 M1 Lokal Latenz: ${latency}ms"
    fi
    
    if ping -c 1 -W 3000 $M1_VPN_IP > /dev/null 2>&1; then
        local vpn_latency=$(ping -c 3 $M1_VPN_IP | tail -1 | awk -F'/' '{print $5}')
        info "📊 M1 VPN Latenz: ${vpn_latency}ms"
    fi
    
    # Git Clone Performance Test (klein)
    if nc -z -w 3 $M1_LOCAL_IP $GIT_DAEMON_PORT; then
        local start_time=$(date +%s)
        if timeout 30 git ls-remote git://$M1_LOCAL_IP:$GIT_DAEMON_PORT/Gentleman > /dev/null 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            info "📊 Git ls-remote Dauer: ${duration}s"
            echo "Git Performance:PASS" >> /tmp/test_results.log
        else
            echo "Git Performance:FAIL" >> /tmp/test_results.log
        fi
    fi
}

# Test-Zusammenfassung
print_test_summary() {
    echo ""
    log "📋 Test-Zusammenfassung:"
    echo "========================================"
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local warned_tests=0
    
    if [ -f "/tmp/test_results.log" ]; then
        while IFS=':' read -r test_name result; do
            total_tests=$((total_tests + 1))
            
            case "$result" in
                "PASS")
                    success "✅ $test_name"
                    passed_tests=$((passed_tests + 1))
                    ;;
                "FAIL")
                    error "❌ $test_name"
                    failed_tests=$((failed_tests + 1))
                    ;;
                "WARN")
                    warning "⚠️ $test_name"
                    warned_tests=$((warned_tests + 1))
                    ;;
            esac
        done < /tmp/test_results.log
    fi
    
    echo ""
    info "📊 Test-Statistiken:"
    info "   Gesamt: $total_tests"
    success "   Erfolgreich: $passed_tests"
    warning "   Warnungen: $warned_tests"
    error "   Fehlgeschlagen: $failed_tests"
    
    echo ""
    if [ $failed_tests -eq 0 ]; then
        success "🎉 Alle kritischen Tests bestanden!"
        
        if [ $warned_tests -eq 0 ]; then
            success "🏆 Perfekte M1 ↔ I7 Konnektivität!"
        else
            warning "⚠️ Einige optionale Services nicht verfügbar"
        fi
        
        return 0
    else
        error "❌ Einige Tests fehlgeschlagen"
        return 1
    fi
}

# Empfehlungen basierend auf Test-Ergebnissen
print_recommendations() {
    echo ""
    log "💡 Empfehlungen:"
    echo "========================================"
    
    if [ -f "/tmp/test_results.log" ]; then
        if grep -q "Docker:FAIL" /tmp/test_results.log; then
            info "🐳 Docker starten: open -a Docker"
        fi
        
        if grep -q "Gitea Container:WARN" /tmp/test_results.log; then
            info "🏗️ Gitea starten: ./gentleman_gitea_setup.sh start"
        fi
        
        if grep -q "Nebula Process:WARN" /tmp/test_results.log; then
            info "🔒 Nebula VPN starten: Prüfe Nebula-Konfiguration"
        fi
        
        if grep -q "Git Performance:FAIL" /tmp/test_results.log; then
            info "📦 Git Daemon starten: Prüfe Git Daemon-Konfiguration"
        fi
    fi
    
    echo ""
    info "🔧 Nützliche Befehle:"
    info "   Status prüfen: ./test_m1_i7_connection.sh --quick"
    info "   Services starten: ./gentleman_gitea_setup.sh start"
    info "   I7 Sync testen: ./start_i7_sync.sh --once"
}

# Hauptfunktion
main() {
    # Reset test results
    rm -f /tmp/test_results.log
    
    case "${1:-full}" in
        "--quick" | "-q")
            log "🚀 Schneller Konnektivitätstest..."
            gather_system_info
            test_network_connectivity
            test_port_connectivity
            print_test_summary
            ;;
        "--network" | "-n")
            log "🌐 Netzwerk-Tests..."
            gather_system_info
            test_network_connectivity
            test_nebula_vpn
            print_test_summary
            ;;
        "--services" | "-s")
            log "🔧 Service-Tests..."
            test_docker_services
            test_git_services
            test_handshake_system
            print_test_summary
            ;;
        "--performance" | "-p")
            log "⚡ Performance-Tests..."
            test_network_connectivity
            test_performance
            print_test_summary
            ;;
        *)
            # Vollständiger Test
            log "🚀 Starte vollständigen M1 ↔ I7 Back-to-Back Test..."
            
            gather_system_info
            test_network_connectivity
            test_port_connectivity
            test_nebula_vpn
            test_docker_services
            test_git_services
            test_handshake_system
            test_i7_sync_simulation
            test_performance
            
            print_test_summary
            print_recommendations
            ;;
    esac
    
    echo ""
    log "🎯 Back-to-Back Test abgeschlossen!"
}

# Führe Hauptfunktion aus
main "$@" 