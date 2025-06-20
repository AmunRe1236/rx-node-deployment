#!/bin/bash

# GENTLEMAN RX Node SSH Tunnel Control
# Ermöglicht SSH-Zugriff auf RX Node über Cloudflare Tunnel

set -euo pipefail

# Konfiguration
RX_NODE_IP="192.168.68.117"
RX_NODE_USER="amo9n11"
SSH_KEY_PATH="$HOME/.ssh/gentleman_key"
SSH_TUNNEL_URL_FILE="/tmp/rx_ssh_tunnel_url.txt"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}❌ $1${NC}" >&2
}

log_info() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}ℹ️ $1${NC}"
}

# Prüfe Netzwerk-Modus
detect_network_mode() {
    local current_ip
    current_ip=$(ifconfig | grep -E "(192\.168\.68\.|172\.20\.10\.)" | head -1 | awk '{print $2}' || echo "")
    
    if [[ "$current_ip" =~ ^192\.168\.68\. ]]; then
        echo "home"
    elif [[ "$current_ip" =~ ^172\.20\.10\. ]]; then
        echo "hotspot"
    else
        echo "unknown"
    fi
}

# Hole SSH-Tunnel-URL
get_ssh_tunnel_url() {
    local ssh_url=""
    
    # Versuche von RX Node zu holen
    ssh_url=$(ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "cat /tmp/rx_ssh_tunnel_url.txt 2>/dev/null || echo ''" 2>/dev/null || echo "")
    
    echo "$ssh_url"
}

# SSH-Verbindung über Tunnel
ssh_via_tunnel() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🔐 SSH-Verbindung zur RX Node (Netzwerk: $network_mode)"
    
    if [ "$network_mode" == "home" ]; then
        log_info "📡 Im Heimnetzwerk - verwende direkte SSH-Verbindung"
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP"
    else
        log_info "☁️ Im Hotspot - verwende SSH-Tunnel"
        
        local ssh_tunnel_url
        ssh_tunnel_url=$(get_ssh_tunnel_url)
        
        if [[ -n "$ssh_tunnel_url" && "$ssh_tunnel_url" != "SSH URL nicht gefunden" ]]; then
            log_info "🌐 SSH-Tunnel-URL: $ssh_tunnel_url"
            log_info "🔗 Etabliere Tunnel-Verbindung..."
            
            # Starte lokalen Tunnel-Proxy
            cloudflared access tcp --hostname "$ssh_tunnel_url" --url localhost:2222 &
            local proxy_pid=$!
            
            # Warte kurz für Proxy-Initialisierung
            sleep 3
            
            log_info "🔐 Verbinde via SSH über Tunnel..."
            ssh -i "$SSH_KEY_PATH" -p 2222 "$RX_NODE_USER@localhost"
            
            # Stoppe Proxy nach SSH-Session
            kill $proxy_pid 2>/dev/null || true
            
        else
            log_error "SSH-Tunnel-URL nicht verfügbar"
            log_info "💡 Starte SSH-Tunnel auf RX Node:"
            log_info "   ssh rx-node '/tmp/rx_tunnel_manager_extended.sh start'"
        fi
    fi
}

# SSH-Tunnel-Status
ssh_tunnel_status() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    echo -e "${PURPLE}🎯 GENTLEMAN SSH-Tunnel Status${NC}"
    echo "==============================="
    echo ""
    echo -e "${BLUE}Netzwerk-Modus: $network_mode${NC}"
    echo ""
    
    if [ "$network_mode" == "home" ]; then
        log_info "📡 Im Heimnetzwerk - SSH-Tunnel nicht erforderlich"
        log_info "📋 Prüfe RX Node SSH-Tunnel-Services..."
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh status"
    else
        log_info "☁️ Im Hotspot - SSH-Tunnel erforderlich"
        
        local ssh_tunnel_url
        ssh_tunnel_url=$(get_ssh_tunnel_url)
        
        if [[ -n "$ssh_tunnel_url" && "$ssh_tunnel_url" != "SSH URL nicht gefunden" ]]; then
            echo "✅ SSH-Tunnel verfügbar: $ssh_tunnel_url"
            echo ""
            echo "🔗 Verbindung herstellen:"
            echo "  $0 connect"
        else
            echo "❌ SSH-Tunnel nicht verfügbar"
        fi
    fi
}

# SSH-Tunnel verwalten
manage_ssh_tunnel() {
    local action="$1"
    
    case "$action" in
        "start")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh start"
            ;;
        "stop")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh stop"
            ;;
        "restart")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh restart"
            ;;
        "urls")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh urls"
            ;;
        *)
            echo "SSH-Tunnel Aktionen: start|stop|restart|urls"
            ;;
    esac
}

# Hauptfunktion
main() {
    case "${1:-}" in
        "connect"|"ssh")
            ssh_via_tunnel
            ;;
        "status")
            ssh_tunnel_status
            ;;
        "tunnel")
            manage_ssh_tunnel "${2:-status}"
            ;;
        *)
            echo -e "${PURPLE}🎯 GENTLEMAN RX Node SSH-Tunnel Control${NC}"
            echo "========================================"
            echo ""
            echo "Kommandos:"
            echo "  connect                   - SSH-Verbindung zur RX Node"
            echo "  ssh                       - Alias für connect"
            echo "  status                    - SSH-Tunnel Status"
            echo "  tunnel {start|stop|restart|urls} - Tunnel verwalten"
            echo ""
            echo "Beispiele:"
            echo "  $0 connect                - SSH zur RX Node"
            echo "  $0 status                 - Tunnel-Status prüfen"
            echo "  $0 tunnel start           - SSH-Tunnel starten"
            ;;
    esac
}

main "$@"
