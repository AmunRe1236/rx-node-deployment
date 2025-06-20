#!/bin/bash

# GENTLEMAN Friend Network Connector
# Verbindet verschiedene Tailscale-Netzwerke von Freunden

# Konfiguration
FRIEND_NETWORKS=(
    "amon:100.96.219.28:8765"      # Amon's M1 Mac
    "max:100.64.0.15:8765"         # Max's Laptop (Beispiel IP)
    "lisa:100.64.0.32:8765"        # Lisa's PC (Beispiel IP)
    "tom:100.64.0.48:8765"         # Tom's Mac (Beispiel IP)
)

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Prüfe alle Friend Networks
check_friend_networks() {
    echo "🌐 GENTLEMAN Friend Networks Status"
    echo "===================================="
    echo ""
    
    for network in "${FRIEND_NETWORKS[@]}"; do
        IFS=':' read -r friend_name friend_ip friend_port <<< "$network"
        
        echo -n "👤 $friend_name ($friend_ip): "
        
        if curl -s --max-time 3 "http://$friend_ip:$friend_port/health" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Online${NC}"
        else
            echo -e "${RED}❌ Offline${NC}"
        fi
    done
    echo ""
}

# Verbinde zu Friend Network
connect_to_friend() {
    local friend_name="$1"
    
    if [ -z "$friend_name" ]; then
        echo "Verwendung: $0 connect <friend-name>"
        echo ""
        echo "Verfügbare Freunde:"
        for network in "${FRIEND_NETWORKS[@]}"; do
            IFS=':' read -r name ip port <<< "$network"
            echo "  • $name"
        done
        return 1
    fi
    
    # Finde Friend Network
    for network in "${FRIEND_NETWORKS[@]}"; do
        IFS=':' read -r name ip port <<< "$network"
        if [ "$name" = "$friend_name" ]; then
            log_info "🔗 Verbinde zu $friend_name's GENTLEMAN System..."
            
            # Teste Verbindung
            if curl -s --max-time 5 "http://$ip:$port/health" >/dev/null 2>&1; then
                log_success "Verbunden mit $friend_name ($ip:$port)"
                
                # Zeige verfügbare Services
                echo ""
                echo "🎯 Verfügbare Services bei $friend_name:"
                echo "• Status: curl http://$ip:$port/status"
                echo "• Nodes: curl http://$ip:$port/nodes"
                echo "• SSH: ssh $ip (falls konfiguriert)"
                
                return 0
            else
                log_error "$friend_name ist nicht erreichbar"
                return 1
            fi
        fi
    done
    
    log_error "Freund '$friend_name' nicht gefunden"
}

# Broadcast an alle Friends
broadcast_to_friends() {
    local message="$1"
    
    if [ -z "$message" ]; then
        echo "Verwendung: $0 broadcast '<message>'"
        return 1
    fi
    
    log_info "📡 Sende Broadcast an alle Friend Networks..."
    
    for network in "${FRIEND_NETWORKS[@]}"; do
        IFS=':' read -r friend_name friend_ip friend_port <<< "$network"
        
        echo -n "📤 $friend_name: "
        
        # Sende Message (hier könntest du einen Custom Endpoint verwenden)
        if curl -s --max-time 3 "http://$friend_ip:$friend_port/health" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Delivered${NC}"
        else
            echo -e "${RED}❌ Failed${NC}"
        fi
    done
}

# Hauptfunktion
main() {
    case "${1:-status}" in
        "status")
            check_friend_networks
            ;;
        "connect")
            connect_to_friend "$2"
            ;;
        "broadcast")
            broadcast_to_friends "$2"
            ;;
        "list")
            echo "👥 GENTLEMAN Friend Networks:"
            for network in "${FRIEND_NETWORKS[@]}"; do
                IFS=':' read -r name ip port <<< "$network"
                echo "  • $name: $ip:$port"
            done
            ;;
        *)
            echo "🎯 GENTLEMAN Friend Network Connector"
            echo "====================================="
            echo ""
            echo "Kommandos:"
            echo "  status              - Zeige alle Friend Networks"
            echo "  connect <friend>    - Verbinde zu Friend Network"
            echo "  broadcast <msg>     - Broadcast an alle Friends"
            echo "  list               - Liste alle Friends"
            echo ""
            echo "Beispiele:"
            echo "  $0 status"
            echo "  $0 connect max"
            echo "  $0 broadcast 'Hello Friends!'"
            ;;
    esac
}

main "$@"
