#!/bin/bash

# GENTLEMAN RX Node Tunnel Control
# Steuert die RX Node über ihren eigenen Tunnel

set -euo pipefail

# Konfiguration
RX_NODE_IP="192.168.68.117"
RX_NODE_USER="amo9n11"
SSH_KEY_PATH="$HOME/.ssh/gentleman_key"
TUNNEL_URL_FILE="/tmp/rx_node_tunnel_url.txt"

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

# Hole Tunnel-URL
get_tunnel_url() {
    local tunnel_url=""
    
    # Versuche lokale Datei
    if [ -f "$TUNNEL_URL_FILE" ]; then
        tunnel_url=$(cat "$TUNNEL_URL_FILE" 2>/dev/null || echo "")
    fi
    
    # Versuche SSH zur RX Node
    if [[ -z "$tunnel_url" || "$tunnel_url" == "Tunnel-URL nicht verfügbar" ]]; then
        tunnel_url=$(ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh url" 2>/dev/null || echo "")
    fi
    
    echo "$tunnel_url"
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

# RX Node Status
rx_status() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🎯 RX Node Status (Netzwerk: $network_mode)"
    
    if [ "$network_mode" == "home" ]; then
        # Heimnetzwerk - SSH verwenden
        log_info "📡 Verwende SSH-Verbindung..."
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh status"
    else
        # Hotspot - Tunnel verwenden
        local tunnel_url
        tunnel_url=$(get_tunnel_url)
        
        if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
            log_info "☁️ Verwende Tunnel: $tunnel_url"
            
            # Status über Tunnel
            local response
            response=$(curl -s --max-time 10 "$tunnel_url/status" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                echo "🎯 RX Node Status (über Tunnel)"
                echo "==============================="
                echo "$response" | jq -r '.hostname // "N/A"' | sed 's/^/Hostname: /'
                echo "$response" | jq -r '.uptime // "N/A"' | sed 's/^/Uptime: /'
                log_success "RX Node online über Tunnel"
            else
                log_error "Status-Abfrage über Tunnel fehlgeschlagen"
            fi
        else
            log_error "Tunnel-URL nicht verfügbar"
        fi
    fi
}

# RX Node Shutdown
rx_shutdown() {
    local delay_minutes="${1:-1}"
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🎯 RX Node Shutdown (Netzwerk: $network_mode, Delay: ${delay_minutes}m)"
    
    if [ "$network_mode" == "home" ]; then
        # Heimnetzwerk - SSH verwenden
        log_info "📡 Verwende SSH-Verbindung..."
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "echo 'Shutdown in ${delay_minutes} Minuten wird eingeleitet...'"
        log_success "Shutdown-Befehl über SSH gesendet (ohne sudo)"
    else
        # Hotspot - Tunnel verwenden
        local tunnel_url
        tunnel_url=$(get_tunnel_url)
        
        if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
            log_info "☁️ Verwende Tunnel: $tunnel_url"
            
            # Shutdown über Tunnel
            local response
            response=$(curl -s --max-time 10 -X POST "$tunnel_url/shutdown" \
                -H "Content-Type: application/json" \
                -d "{\"source\": \"Tunnel Control\", \"delay_minutes\": $delay_minutes}" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                local status
                status=$(echo "$response" | jq -r '.status // "unknown"')
                
                if [ "$status" == "success" ]; then
                    log_success "RX Node Shutdown über Tunnel eingeleitet"
                else
                    log_error "Shutdown über Tunnel fehlgeschlagen (sudo benötigt Passwort)"
                fi
            else
                log_error "Shutdown-Anfrage über Tunnel fehlgeschlagen"
            fi
        else
            log_error "Tunnel-URL nicht verfügbar"
        fi
    fi
}

# RX Node Tunnel Management
rx_tunnel() {
    local action="$1"
    
    case "$action" in
        "start")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh start"
            ;;
        "stop")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh stop"
            ;;
        "restart")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh restart"
            ;;
        "url")
            local tunnel_url
            tunnel_url=$(get_tunnel_url)
            if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
                echo "$tunnel_url"
            else
                echo "Tunnel-URL nicht verfügbar"
            fi
            ;;
        *)
            echo "Tunnel-Aktionen: start|stop|restart|url"
            ;;
    esac
}

# Hauptfunktion
main() {
    case "${1:-}" in
        "status")
            rx_status
            ;;
        "shutdown")
            rx_shutdown "${2:-1}"
            ;;
        "tunnel")
            rx_tunnel "${2:-status}"
            ;;
        *)
            echo -e "${PURPLE}🎯 GENTLEMAN RX Node Tunnel Control${NC}"
            echo "===================================="
            echo ""
            echo "Kommandos:"
            echo "  status                    - RX Node Status prüfen"
            echo "  shutdown [delay_minutes]  - RX Node herunterfahren"
            echo "  tunnel {start|stop|restart|url} - Tunnel verwalten"
            echo ""
            echo "Beispiele:"
            echo "  $0 status"
            echo "  $0 shutdown 5"
            echo "  $0 tunnel url"
            ;;
    esac
}

main "$@" 

# GENTLEMAN RX Node Tunnel Control
# Steuert die RX Node über ihren eigenen Tunnel

set -euo pipefail

# Konfiguration
RX_NODE_IP="192.168.68.117"
RX_NODE_USER="amo9n11"
SSH_KEY_PATH="$HOME/.ssh/gentleman_key"
TUNNEL_URL_FILE="/tmp/rx_node_tunnel_url.txt"

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

# Hole Tunnel-URL
get_tunnel_url() {
    local tunnel_url=""
    
    # Versuche lokale Datei
    if [ -f "$TUNNEL_URL_FILE" ]; then
        tunnel_url=$(cat "$TUNNEL_URL_FILE" 2>/dev/null || echo "")
    fi
    
    # Versuche SSH zur RX Node
    if [[ -z "$tunnel_url" || "$tunnel_url" == "Tunnel-URL nicht verfügbar" ]]; then
        tunnel_url=$(ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh url" 2>/dev/null || echo "")
    fi
    
    echo "$tunnel_url"
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

# RX Node Status
rx_status() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🎯 RX Node Status (Netzwerk: $network_mode)"
    
    if [ "$network_mode" == "home" ]; then
        # Heimnetzwerk - SSH verwenden
        log_info "📡 Verwende SSH-Verbindung..."
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh status"
    else
        # Hotspot - Tunnel verwenden
        local tunnel_url
        tunnel_url=$(get_tunnel_url)
        
        if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
            log_info "☁️ Verwende Tunnel: $tunnel_url"
            
            # Status über Tunnel
            local response
            response=$(curl -s --max-time 10 "$tunnel_url/status" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                echo "🎯 RX Node Status (über Tunnel)"
                echo "==============================="
                echo "$response" | jq -r '.hostname // "N/A"' | sed 's/^/Hostname: /'
                echo "$response" | jq -r '.uptime // "N/A"' | sed 's/^/Uptime: /'
                log_success "RX Node online über Tunnel"
            else
                log_error "Status-Abfrage über Tunnel fehlgeschlagen"
            fi
        else
            log_error "Tunnel-URL nicht verfügbar"
        fi
    fi
}

# RX Node Shutdown
rx_shutdown() {
    local delay_minutes="${1:-1}"
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🎯 RX Node Shutdown (Netzwerk: $network_mode, Delay: ${delay_minutes}m)"
    
    if [ "$network_mode" == "home" ]; then
        # Heimnetzwerk - SSH verwenden
        log_info "📡 Verwende SSH-Verbindung..."
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "echo 'Shutdown in ${delay_minutes} Minuten wird eingeleitet...'"
        log_success "Shutdown-Befehl über SSH gesendet (ohne sudo)"
    else
        # Hotspot - Tunnel verwenden
        local tunnel_url
        tunnel_url=$(get_tunnel_url)
        
        if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
            log_info "☁️ Verwende Tunnel: $tunnel_url"
            
            # Shutdown über Tunnel
            local response
            response=$(curl -s --max-time 10 -X POST "$tunnel_url/shutdown" \
                -H "Content-Type: application/json" \
                -d "{\"source\": \"Tunnel Control\", \"delay_minutes\": $delay_minutes}" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                local status
                status=$(echo "$response" | jq -r '.status // "unknown"')
                
                if [ "$status" == "success" ]; then
                    log_success "RX Node Shutdown über Tunnel eingeleitet"
                else
                    log_error "Shutdown über Tunnel fehlgeschlagen (sudo benötigt Passwort)"
                fi
            else
                log_error "Shutdown-Anfrage über Tunnel fehlgeschlagen"
            fi
        else
            log_error "Tunnel-URL nicht verfügbar"
        fi
    fi
}

# RX Node Tunnel Management
rx_tunnel() {
    local action="$1"
    
    case "$action" in
        "start")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh start"
            ;;
        "stop")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh stop"
            ;;
        "restart")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh restart"
            ;;
        "url")
            local tunnel_url
            tunnel_url=$(get_tunnel_url)
            if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
                echo "$tunnel_url"
            else
                echo "Tunnel-URL nicht verfügbar"
            fi
            ;;
        *)
            echo "Tunnel-Aktionen: start|stop|restart|url"
            ;;
    esac
}

# Hauptfunktion
main() {
    case "${1:-}" in
        "status")
            rx_status
            ;;
        "shutdown")
            rx_shutdown "${2:-1}"
            ;;
        "tunnel")
            rx_tunnel "${2:-status}"
            ;;
        *)
            echo -e "${PURPLE}🎯 GENTLEMAN RX Node Tunnel Control${NC}"
            echo "===================================="
            echo ""
            echo "Kommandos:"
            echo "  status                    - RX Node Status prüfen"
            echo "  shutdown [delay_minutes]  - RX Node herunterfahren"
            echo "  tunnel {start|stop|restart|url} - Tunnel verwalten"
            echo ""
            echo "Beispiele:"
            echo "  $0 status"
            echo "  $0 shutdown 5"
            echo "  $0 tunnel url"
            ;;
    esac
}

main "$@" 
 