#!/bin/bash

# GENTLEMAN Hotspot Node Control
# Steuert beide Nodes (I7 Laptop & RX Node) über Hotspot-Tunnel

set -euo pipefail

# Konfiguration
M1_TUNNEL_URL_FILE="/tmp/m1_tunnel_url.txt"
RX_TUNNEL_URL_FILE="/tmp/rx_node_tunnel_url.txt"
I7_LAPTOP_MAC="80:e8:2c:fd:12:34"  # Beispiel MAC - muss angepasst werden
RX_NODE_MAC="30:9c:23:5f:44:a8"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}⚠️ $1${NC}"
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

# Hole M1 Tunnel-URL
get_m1_tunnel_url() {
    local tunnel_url=""
    
    # Versuche lokale Datei
    if [ -f "$M1_TUNNEL_URL_FILE" ]; then
        tunnel_url=$(cat "$M1_TUNNEL_URL_FILE" 2>/dev/null || echo "")
    fi
    
    # Fallback: Prüfe ob cloudflared läuft und starte neuen Tunnel
    if [[ -z "$tunnel_url" || "$tunnel_url" == "Tunnel nicht verfügbar" ]]; then
        log_info "Starte M1 Cloudflare Tunnel..."
        # Starte Tunnel im Hintergrund und hole URL
        nohup cloudflared tunnel --url http://localhost:8765 > /tmp/m1_tunnel.log 2>&1 &
        sleep 10
        tunnel_url=$(grep -o 'https://.*\.trycloudflare\.com' /tmp/m1_tunnel.log | head -1 || echo "")
        if [ -n "$tunnel_url" ]; then
            echo "$tunnel_url" > "$M1_TUNNEL_URL_FILE"
        fi
    fi
    
    echo "$tunnel_url"
}

# Hole RX Node Tunnel-URL
get_rx_tunnel_url() {
    local tunnel_url=""
    
    if [ -f "$RX_TUNNEL_URL_FILE" ]; then
        tunnel_url=$(cat "$RX_TUNNEL_URL_FILE" 2>/dev/null || echo "")
    fi
    
    echo "$tunnel_url"
}

# I7 Laptop Status über M1 Tunnel
i7_status() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "💻 I7 Laptop Status (Netzwerk: $network_mode)"
    
    if [ "$network_mode" == "hotspot" ]; then
        local m1_tunnel_url
        m1_tunnel_url=$(get_m1_tunnel_url)
        
        if [[ -n "$m1_tunnel_url" && "$m1_tunnel_url" != "Tunnel nicht verfügbar" ]]; then
            log_info "☁️ Verwende M1 Tunnel: $m1_tunnel_url"
            
            # Status über M1 Tunnel
            local response
            response=$(curl -s --max-time 10 "$m1_tunnel_url/nodes" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                echo "💻 I7 Laptop Status (über M1 Tunnel)"
                echo "====================================="
                echo "$response" | jq -r '.nodes[] | select(.node_type == "i7") | "Hostname: " + .hostname + "\nLast Seen: " + (.last_seen | tostring) + "\nStatus: Online"' 2>/dev/null || echo "I7 Laptop nicht in Cluster registriert"
                log_success "M1 Handshake Server erreichbar über Tunnel"
            else
                log_error "Status-Abfrage über M1 Tunnel fehlgeschlagen"
            fi
        else
            log_error "M1 Tunnel-URL nicht verfügbar"
        fi
    else
        log_info "📡 Im Heimnetzwerk - verwende direkte Verbindung"
        ./m1_rx_node_control.sh status || echo "Direkter Zugriff fehlgeschlagen"
    fi
}

# I7 Laptop Shutdown über M1 Tunnel
i7_shutdown() {
    local delay_minutes="${1:-1}"
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "💻 I7 Laptop Shutdown (Netzwerk: $network_mode, Delay: ${delay_minutes}m)"
    
    if [ "$network_mode" == "hotspot" ]; then
        local m1_tunnel_url
        m1_tunnel_url=$(get_m1_tunnel_url)
        
        if [[ -n "$m1_tunnel_url" && "$m1_tunnel_url" != "Tunnel nicht verfügbar" ]]; then
            log_info "☁️ Verwende M1 Tunnel: $m1_tunnel_url"
            
            # Shutdown über M1 Tunnel
            local response
            response=$(curl -s --max-time 10 -X POST "$m1_tunnel_url/admin/shutdown" \
                -H "Content-Type: application/json" \
                -d "{\"target\": \"i7\", \"delay_minutes\": $delay_minutes, \"source\": \"Hotspot Control\"}" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                local status
                status=$(echo "$response" | jq -r '.status // "unknown"')
                
                if [ "$status" == "success" ]; then
                    log_success "I7 Laptop Shutdown über M1 Tunnel eingeleitet"
                else
                    log_error "I7 Shutdown über M1 Tunnel fehlgeschlagen"
                    echo "$response" | jq . 2>/dev/null || echo "$response"
                fi
            else
                log_error "I7 Shutdown-Anfrage über M1 Tunnel fehlgeschlagen"
            fi
        else
            log_error "M1 Tunnel-URL nicht verfügbar"
        fi
    else
        log_info "📡 Im Heimnetzwerk - verwende direkte Verbindung"
        ./m1_rx_node_control.sh shutdown "$delay_minutes" || echo "Direkter Zugriff fehlgeschlagen"
    fi
}

# I7 Laptop Wake-on-LAN über M1 Tunnel
i7_wakeup() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "💻 I7 Laptop Wake-on-LAN (Netzwerk: $network_mode)"
    
    if [ "$network_mode" == "hotspot" ]; then
        local m1_tunnel_url
        m1_tunnel_url=$(get_m1_tunnel_url)
        
        if [[ -n "$m1_tunnel_url" && "$m1_tunnel_url" != "Tunnel nicht verfügbar" ]]; then
            log_info "☁️ Verwende M1 Tunnel: $m1_tunnel_url"
            
            # Wake-on-LAN über M1 Tunnel
            local response
            response=$(curl -s --max-time 10 -X POST "$m1_tunnel_url/admin/bootup" \
                -H "Content-Type: application/json" \
                -d "{\"target\": \"i7\", \"mac_address\": \"$I7_LAPTOP_MAC\", \"source\": \"Hotspot Control\"}" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                local status
                status=$(echo "$response" | jq -r '.status // "unknown"')
                
                if [ "$status" == "success" ]; then
                    log_success "I7 Laptop Wake-on-LAN über M1 Tunnel gesendet"
                else
                    log_error "I7 Wake-on-LAN über M1 Tunnel fehlgeschlagen"
                    echo "$response" | jq . 2>/dev/null || echo "$response"
                fi
            else
                log_error "I7 Wake-on-LAN-Anfrage über M1 Tunnel fehlgeschlagen"
            fi
        else
            log_error "M1 Tunnel-URL nicht verfügbar"
        fi
    else
        log_info "📡 Im Heimnetzwerk - verwende direkte Verbindung"
        ./m1_rx_node_control.sh wakeup || echo "Direkter Zugriff fehlgeschlagen"
    fi
}

# RX Node Status
rx_status() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🖥️ RX Node Status (Netzwerk: $network_mode)"
    
    if [ "$network_mode" == "hotspot" ]; then
        local rx_tunnel_url
        rx_tunnel_url=$(get_rx_tunnel_url)
        
        if [[ -n "$rx_tunnel_url" && "$rx_tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
            log_info "☁️ Verwende RX Tunnel: $rx_tunnel_url"
            
            # Status über RX Tunnel
            local response
            response=$(curl -s --max-time 10 "$rx_tunnel_url/status" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                echo "🖥️ RX Node Status (über Tunnel)"
                echo "==============================="
                echo "$response" | jq -r '.hostname // "N/A"' | sed 's/^/Hostname: /'
                echo "$response" | jq -r '.uptime // "N/A"' | sed 's/^/Uptime: /'
                log_success "RX Node online über Tunnel"
            else
                log_error "RX Status-Abfrage über Tunnel fehlgeschlagen"
            fi
        else
            log_error "RX Tunnel-URL nicht verfügbar"
        fi
    else
        log_info "📡 Im Heimnetzwerk - verwende direkte Verbindung"
        ./rx_node_tunnel_control.sh status || echo "Direkter Zugriff fehlgeschlagen"
    fi
}

# RX Node Shutdown
rx_shutdown() {
    local delay_minutes="${1:-1}"
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🖥️ RX Node Shutdown (Netzwerk: $network_mode, Delay: ${delay_minutes}m)"
    
    if [ "$network_mode" == "hotspot" ]; then
        local rx_tunnel_url
        rx_tunnel_url=$(get_rx_tunnel_url)
        
        if [[ -n "$rx_tunnel_url" && "$rx_tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
            log_info "☁️ Verwende RX Tunnel: $rx_tunnel_url"
            
            # Shutdown über RX Tunnel
            local response
            response=$(curl -s --max-time 10 -X POST "$rx_tunnel_url/shutdown" \
                -H "Content-Type: application/json" \
                -d "{\"source\": \"Hotspot Control\", \"delay_minutes\": $delay_minutes}" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                local status
                status=$(echo "$response" | jq -r '.status // "unknown"')
                
                if [ "$status" == "success" ]; then
                    log_success "RX Node Shutdown über Tunnel eingeleitet"
                else
                    log_error "RX Shutdown über Tunnel fehlgeschlagen (sudo benötigt Passwort)"
                    echo "$response" | jq . 2>/dev/null || echo "$response"
                fi
            else
                log_error "RX Shutdown-Anfrage über Tunnel fehlgeschlagen"
            fi
        else
            log_error "RX Tunnel-URL nicht verfügbar"
        fi
    else
        log_info "📡 Im Heimnetzwerk - verwende direkte Verbindung"
        ./rx_node_tunnel_control.sh shutdown "$delay_minutes" || echo "Direkter Zugriff fehlgeschlagen"
    fi
}

# RX Node Wake-on-LAN (über M1 da RX Node offline ist)
rx_wakeup() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🖥️ RX Node Wake-on-LAN (Netzwerk: $network_mode)"
    
    if [ "$network_mode" == "hotspot" ]; then
        local m1_tunnel_url
        m1_tunnel_url=$(get_m1_tunnel_url)
        
        if [[ -n "$m1_tunnel_url" && "$m1_tunnel_url" != "Tunnel nicht verfügbar" ]]; then
            log_info "☁️ Verwende M1 Tunnel für Wake-on-LAN: $m1_tunnel_url"
            
            # Wake-on-LAN über M1 Tunnel
            local response
            response=$(curl -s --max-time 10 -X POST "$m1_tunnel_url/admin/rx-node/wakeup" \
                -H "Content-Type: application/json" \
                -d "{\"mac_address\": \"$RX_NODE_MAC\", \"source\": \"Hotspot Control\"}" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                local status
                status=$(echo "$response" | jq -r '.status // "unknown"')
                
                if [ "$status" == "success" ]; then
                    log_success "RX Node Wake-on-LAN über M1 Tunnel gesendet"
                else
                    log_error "RX Wake-on-LAN über M1 Tunnel fehlgeschlagen"
                    echo "$response" | jq . 2>/dev/null || echo "$response"
                fi
            else
                log_error "RX Wake-on-LAN-Anfrage über M1 Tunnel fehlgeschlagen"
            fi
        else
            log_error "M1 Tunnel-URL nicht verfügbar"
        fi
    else
        log_info "📡 Im Heimnetzwerk - verwende direkte Verbindung"
        ./m1_rx_node_control.sh wakeup || echo "Direkter Zugriff fehlgeschlagen"
    fi
}

# Beide Nodes Status
all_status() {
    echo -e "${PURPLE}🎯 GENTLEMAN Hotspot Node Control - Status${NC}"
    echo "==========================================="
    echo ""
    
    local network_mode
    network_mode=$(detect_network_mode)
    
    echo -e "${CYAN}Netzwerk-Modus: $network_mode${NC}"
    echo ""
    
    # Tunnel URLs anzeigen
    if [ "$network_mode" == "hotspot" ]; then
        echo -e "${CYAN}Verfügbare Tunnel:${NC}"
        local m1_url=$(get_m1_tunnel_url)
        local rx_url=$(get_rx_tunnel_url)
        
        echo "• M1 Tunnel: ${m1_url:-'Nicht verfügbar'}"
        echo "• RX Tunnel: ${rx_url:-'Nicht verfügbar'}"
        echo ""
    fi
    
    # I7 Status
    i7_status
    echo ""
    
    # RX Status
    rx_status
}

# Beide Nodes herunterfahren
all_shutdown() {
    local delay_minutes="${1:-1}"
    
    echo -e "${PURPLE}🎯 GENTLEMAN Hotspot Node Control - Shutdown${NC}"
    echo "============================================="
    echo ""
    
    log_info "Fahre beide Nodes herunter (Delay: ${delay_minutes}m)..."
    echo ""
    
    # I7 Shutdown
    i7_shutdown "$delay_minutes"
    echo ""
    
    # RX Shutdown
    rx_shutdown "$delay_minutes"
    echo ""
    
    log_success "Shutdown-Befehle für beide Nodes gesendet!"
}

# Beide Nodes aufwecken
all_wakeup() {
    echo -e "${PURPLE}🎯 GENTLEMAN Hotspot Node Control - Wake-on-LAN${NC}"
    echo "================================================"
    echo ""
    
    log_info "Wecke beide Nodes auf..."
    echo ""
    
    # I7 Wake-on-LAN
    i7_wakeup
    echo ""
    
    # RX Wake-on-LAN
    rx_wakeup
    echo ""
    
    log_success "Wake-on-LAN-Befehle für beide Nodes gesendet!"
}

# Tunnel-Status
tunnel_status() {
    echo -e "${PURPLE}🎯 GENTLEMAN Tunnel Status${NC}"
    echo "==========================="
    echo ""
    
    local network_mode
    network_mode=$(detect_network_mode)
    
    echo -e "${CYAN}Netzwerk-Modus: $network_mode${NC}"
    echo ""
    
    if [ "$network_mode" == "hotspot" ]; then
        echo -e "${CYAN}M1 Handshake Server Tunnel:${NC}"
        local m1_url=$(get_m1_tunnel_url)
        if [[ -n "$m1_url" && "$m1_url" != "Tunnel nicht verfügbar" ]]; then
            echo "✅ Verfügbar: $m1_url"
            # Teste Health Check
            if curl -s --max-time 5 "$m1_url/health" >/dev/null 2>&1; then
                echo "✅ Health Check: OK"
            else
                echo "❌ Health Check: Fehlgeschlagen"
            fi
        else
            echo "❌ Nicht verfügbar"
        fi
        
        echo ""
        echo -e "${CYAN}RX Node Tunnel:${NC}"
        local rx_url=$(get_rx_tunnel_url)
        if [[ -n "$rx_url" && "$rx_url" != "Tunnel-URL nicht verfügbar" ]]; then
            echo "✅ Verfügbar: $rx_url"
            # Teste Health Check
            if curl -s --max-time 5 "$rx_url/health" >/dev/null 2>&1; then
                echo "✅ Health Check: OK"
            else
                echo "❌ Health Check: Fehlgeschlagen"
            fi
        else
            echo "❌ Nicht verfügbar"
        fi
    else
        echo "📡 Im Heimnetzwerk - Tunnel nicht erforderlich"
    fi
}

# Hauptfunktion
main() {
    case "${1:-}" in
        "i7")
            case "${2:-}" in
                "status") i7_status ;;
                "shutdown") i7_shutdown "${3:-1}" ;;
                "wakeup") i7_wakeup ;;
                *) echo "I7 Aktionen: status|shutdown [delay]|wakeup" ;;
            esac
            ;;
        "rx")
            case "${2:-}" in
                "status") rx_status ;;
                "shutdown") rx_shutdown "${3:-1}" ;;
                "wakeup") rx_wakeup ;;
                *) echo "RX Aktionen: status|shutdown [delay]|wakeup" ;;
            esac
            ;;
        "all")
            case "${2:-}" in
                "status") all_status ;;
                "shutdown") all_shutdown "${3:-1}" ;;
                "wakeup") all_wakeup ;;
                *) echo "All Aktionen: status|shutdown [delay]|wakeup" ;;
            esac
            ;;
        "tunnels")
            tunnel_status
            ;;
        "ssh")
            case "${2:-}" in
                "i7")
                    log_info "🔐 SSH-Verbindung zum I7 Laptop..."
                    local network_mode
                    network_mode=$(detect_network_mode)
                    if [ "$network_mode" == "home" ]; then
                        log_info "📡 Direkter SSH-Zugriff im Heimnetzwerk"
                        ssh -i "$SSH_KEY_PATH" "$I7_USER@$I7_IP"
                    else
                        log_error "SSH zu I7 im Hotspot-Modus nicht verfügbar"
                        log_info "💡 Verwende: ssh -i ~/.ssh/gentleman_key amon@172.20.10.6"
                    fi
                    ;;
                "rx")
                    log_info "🔐 SSH-Verbindung zur RX Node..."
                    if command -v ./rx_ssh_tunnel_control.sh >/dev/null 2>&1; then
                        ./rx_ssh_tunnel_control.sh connect
                    else
                        log_error "RX SSH-Tunnel Control nicht gefunden"
                        log_info "💡 Führe aus: ./rx_node_ssh_tunnel_setup.sh"
                    fi
                    ;;
                *)
                    echo "SSH Optionen: i7|rx"
                    echo "Beispiele:"
                    echo "  $0 ssh i7     - SSH zum I7 Laptop"
                    echo "  $0 ssh rx     - SSH zur RX Node"
                    ;;
            esac
            ;;
        *)
            echo -e "${PURPLE}🎯 GENTLEMAN Hotspot Node Control${NC}"
            echo "=================================="
            echo ""
            echo "Kommandos:"
            echo "  i7 {status|shutdown|wakeup}     - I7 Laptop steuern"
            echo "  rx {status|shutdown|wakeup}     - RX Node steuern"
            echo "  all {status|shutdown|wakeup}    - Beide Nodes steuern"
            echo "  tunnels                         - Tunnel-Status prüfen"
            echo "  ssh {i7|rx}                     - SSH-Verbindung zu Node"
            echo ""
            echo "Beispiele:"
            echo "  $0 all status                   - Status beider Nodes"
            echo "  $0 all shutdown 5               - Beide Nodes in 5min herunterfahren"
            echo "  $0 i7 wakeup                    - I7 Laptop aufwecken"
            echo "  $0 rx shutdown 1                - RX Node in 1min herunterfahren"
            echo "  $0 tunnels                      - Tunnel-Status prüfen"
            echo "  $0 ssh rx                       - SSH zur RX Node"
            ;;
    esac
}

main "$@"

# GENTLEMAN Hotspot Node Control
# Steuert beide Nodes (I7 Laptop & RX Node) über Hotspot-Tunnel

set -euo pipefail

# Konfiguration
M1_TUNNEL_URL_FILE="/tmp/m1_tunnel_url.txt"
RX_TUNNEL_URL_FILE="/tmp/rx_node_tunnel_url.txt"
I7_LAPTOP_MAC="80:e8:2c:fd:12:34"  # Beispiel MAC - muss angepasst werden
RX_NODE_MAC="30:9c:23:5f:44:a8"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}⚠️ $1${NC}"
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

# Hole M1 Tunnel-URL
get_m1_tunnel_url() {
    local tunnel_url=""
    
    # Versuche lokale Datei
    if [ -f "$M1_TUNNEL_URL_FILE" ]; then
        tunnel_url=$(cat "$M1_TUNNEL_URL_FILE" 2>/dev/null || echo "")
    fi
    
    # Fallback: Prüfe ob cloudflared läuft und starte neuen Tunnel
    if [[ -z "$tunnel_url" || "$tunnel_url" == "Tunnel nicht verfügbar" ]]; then
        log_info "Starte M1 Cloudflare Tunnel..."
        # Starte Tunnel im Hintergrund und hole URL
        nohup cloudflared tunnel --url http://localhost:8765 > /tmp/m1_tunnel.log 2>&1 &
        sleep 10
        tunnel_url=$(grep -o 'https://.*\.trycloudflare\.com' /tmp/m1_tunnel.log | head -1 || echo "")
        if [ -n "$tunnel_url" ]; then
            echo "$tunnel_url" > "$M1_TUNNEL_URL_FILE"
        fi
    fi
    
    echo "$tunnel_url"
}

# Hole RX Node Tunnel-URL
get_rx_tunnel_url() {
    local tunnel_url=""
    
    if [ -f "$RX_TUNNEL_URL_FILE" ]; then
        tunnel_url=$(cat "$RX_TUNNEL_URL_FILE" 2>/dev/null || echo "")
    fi
    
    echo "$tunnel_url"
}

# I7 Laptop Status über M1 Tunnel
i7_status() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "💻 I7 Laptop Status (Netzwerk: $network_mode)"
    
    if [ "$network_mode" == "hotspot" ]; then
        local m1_tunnel_url
        m1_tunnel_url=$(get_m1_tunnel_url)
        
        if [[ -n "$m1_tunnel_url" && "$m1_tunnel_url" != "Tunnel nicht verfügbar" ]]; then
            log_info "☁️ Verwende M1 Tunnel: $m1_tunnel_url"
            
            # Status über M1 Tunnel
            local response
            response=$(curl -s --max-time 10 "$m1_tunnel_url/nodes" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                echo "💻 I7 Laptop Status (über M1 Tunnel)"
                echo "====================================="
                echo "$response" | jq -r '.nodes[] | select(.node_type == "i7") | "Hostname: " + .hostname + "\nLast Seen: " + (.last_seen | tostring) + "\nStatus: Online"' 2>/dev/null || echo "I7 Laptop nicht in Cluster registriert"
                log_success "M1 Handshake Server erreichbar über Tunnel"
            else
                log_error "Status-Abfrage über M1 Tunnel fehlgeschlagen"
            fi
        else
            log_error "M1 Tunnel-URL nicht verfügbar"
        fi
    else
        log_info "📡 Im Heimnetzwerk - verwende direkte Verbindung"
        ./m1_rx_node_control.sh status || echo "Direkter Zugriff fehlgeschlagen"
    fi
}

# I7 Laptop Shutdown über M1 Tunnel
i7_shutdown() {
    local delay_minutes="${1:-1}"
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "💻 I7 Laptop Shutdown (Netzwerk: $network_mode, Delay: ${delay_minutes}m)"
    
    if [ "$network_mode" == "hotspot" ]; then
        local m1_tunnel_url
        m1_tunnel_url=$(get_m1_tunnel_url)
        
        if [[ -n "$m1_tunnel_url" && "$m1_tunnel_url" != "Tunnel nicht verfügbar" ]]; then
            log_info "☁️ Verwende M1 Tunnel: $m1_tunnel_url"
            
            # Shutdown über M1 Tunnel
            local response
            response=$(curl -s --max-time 10 -X POST "$m1_tunnel_url/admin/shutdown" \
                -H "Content-Type: application/json" \
                -d "{\"target\": \"i7\", \"delay_minutes\": $delay_minutes, \"source\": \"Hotspot Control\"}" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                local status
                status=$(echo "$response" | jq -r '.status // "unknown"')
                
                if [ "$status" == "success" ]; then
                    log_success "I7 Laptop Shutdown über M1 Tunnel eingeleitet"
                else
                    log_error "I7 Shutdown über M1 Tunnel fehlgeschlagen"
                    echo "$response" | jq . 2>/dev/null || echo "$response"
                fi
            else
                log_error "I7 Shutdown-Anfrage über M1 Tunnel fehlgeschlagen"
            fi
        else
            log_error "M1 Tunnel-URL nicht verfügbar"
        fi
    else
        log_info "📡 Im Heimnetzwerk - verwende direkte Verbindung"
        ./m1_rx_node_control.sh shutdown "$delay_minutes" || echo "Direkter Zugriff fehlgeschlagen"
    fi
}

# I7 Laptop Wake-on-LAN über M1 Tunnel
i7_wakeup() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "💻 I7 Laptop Wake-on-LAN (Netzwerk: $network_mode)"
    
    if [ "$network_mode" == "hotspot" ]; then
        local m1_tunnel_url
        m1_tunnel_url=$(get_m1_tunnel_url)
        
        if [[ -n "$m1_tunnel_url" && "$m1_tunnel_url" != "Tunnel nicht verfügbar" ]]; then
            log_info "☁️ Verwende M1 Tunnel: $m1_tunnel_url"
            
            # Wake-on-LAN über M1 Tunnel
            local response
            response=$(curl -s --max-time 10 -X POST "$m1_tunnel_url/admin/bootup" \
                -H "Content-Type: application/json" \
                -d "{\"target\": \"i7\", \"mac_address\": \"$I7_LAPTOP_MAC\", \"source\": \"Hotspot Control\"}" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                local status
                status=$(echo "$response" | jq -r '.status // "unknown"')
                
                if [ "$status" == "success" ]; then
                    log_success "I7 Laptop Wake-on-LAN über M1 Tunnel gesendet"
                else
                    log_error "I7 Wake-on-LAN über M1 Tunnel fehlgeschlagen"
                    echo "$response" | jq . 2>/dev/null || echo "$response"
                fi
            else
                log_error "I7 Wake-on-LAN-Anfrage über M1 Tunnel fehlgeschlagen"
            fi
        else
            log_error "M1 Tunnel-URL nicht verfügbar"
        fi
    else
        log_info "📡 Im Heimnetzwerk - verwende direkte Verbindung"
        ./m1_rx_node_control.sh wakeup || echo "Direkter Zugriff fehlgeschlagen"
    fi
}

# RX Node Status
rx_status() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🖥️ RX Node Status (Netzwerk: $network_mode)"
    
    if [ "$network_mode" == "hotspot" ]; then
        local rx_tunnel_url
        rx_tunnel_url=$(get_rx_tunnel_url)
        
        if [[ -n "$rx_tunnel_url" && "$rx_tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
            log_info "☁️ Verwende RX Tunnel: $rx_tunnel_url"
            
            # Status über RX Tunnel
            local response
            response=$(curl -s --max-time 10 "$rx_tunnel_url/status" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                echo "🖥️ RX Node Status (über Tunnel)"
                echo "==============================="
                echo "$response" | jq -r '.hostname // "N/A"' | sed 's/^/Hostname: /'
                echo "$response" | jq -r '.uptime // "N/A"' | sed 's/^/Uptime: /'
                log_success "RX Node online über Tunnel"
            else
                log_error "RX Status-Abfrage über Tunnel fehlgeschlagen"
            fi
        else
            log_error "RX Tunnel-URL nicht verfügbar"
        fi
    else
        log_info "📡 Im Heimnetzwerk - verwende direkte Verbindung"
        ./rx_node_tunnel_control.sh status || echo "Direkter Zugriff fehlgeschlagen"
    fi
}

# RX Node Shutdown
rx_shutdown() {
    local delay_minutes="${1:-1}"
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🖥️ RX Node Shutdown (Netzwerk: $network_mode, Delay: ${delay_minutes}m)"
    
    if [ "$network_mode" == "hotspot" ]; then
        local rx_tunnel_url
        rx_tunnel_url=$(get_rx_tunnel_url)
        
        if [[ -n "$rx_tunnel_url" && "$rx_tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
            log_info "☁️ Verwende RX Tunnel: $rx_tunnel_url"
            
            # Shutdown über RX Tunnel
            local response
            response=$(curl -s --max-time 10 -X POST "$rx_tunnel_url/shutdown" \
                -H "Content-Type: application/json" \
                -d "{\"source\": \"Hotspot Control\", \"delay_minutes\": $delay_minutes}" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                local status
                status=$(echo "$response" | jq -r '.status // "unknown"')
                
                if [ "$status" == "success" ]; then
                    log_success "RX Node Shutdown über Tunnel eingeleitet"
                else
                    log_error "RX Shutdown über Tunnel fehlgeschlagen (sudo benötigt Passwort)"
                    echo "$response" | jq . 2>/dev/null || echo "$response"
                fi
            else
                log_error "RX Shutdown-Anfrage über Tunnel fehlgeschlagen"
            fi
        else
            log_error "RX Tunnel-URL nicht verfügbar"
        fi
    else
        log_info "📡 Im Heimnetzwerk - verwende direkte Verbindung"
        ./rx_node_tunnel_control.sh shutdown "$delay_minutes" || echo "Direkter Zugriff fehlgeschlagen"
    fi
}

# RX Node Wake-on-LAN (über M1 da RX Node offline ist)
rx_wakeup() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🖥️ RX Node Wake-on-LAN (Netzwerk: $network_mode)"
    
    if [ "$network_mode" == "hotspot" ]; then
        local m1_tunnel_url
        m1_tunnel_url=$(get_m1_tunnel_url)
        
        if [[ -n "$m1_tunnel_url" && "$m1_tunnel_url" != "Tunnel nicht verfügbar" ]]; then
            log_info "☁️ Verwende M1 Tunnel für Wake-on-LAN: $m1_tunnel_url"
            
            # Wake-on-LAN über M1 Tunnel
            local response
            response=$(curl -s --max-time 10 -X POST "$m1_tunnel_url/admin/rx-node/wakeup" \
                -H "Content-Type: application/json" \
                -d "{\"mac_address\": \"$RX_NODE_MAC\", \"source\": \"Hotspot Control\"}" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                local status
                status=$(echo "$response" | jq -r '.status // "unknown"')
                
                if [ "$status" == "success" ]; then
                    log_success "RX Node Wake-on-LAN über M1 Tunnel gesendet"
                else
                    log_error "RX Wake-on-LAN über M1 Tunnel fehlgeschlagen"
                    echo "$response" | jq . 2>/dev/null || echo "$response"
                fi
            else
                log_error "RX Wake-on-LAN-Anfrage über M1 Tunnel fehlgeschlagen"
            fi
        else
            log_error "M1 Tunnel-URL nicht verfügbar"
        fi
    else
        log_info "📡 Im Heimnetzwerk - verwende direkte Verbindung"
        ./m1_rx_node_control.sh wakeup || echo "Direkter Zugriff fehlgeschlagen"
    fi
}

# Beide Nodes Status
all_status() {
    echo -e "${PURPLE}🎯 GENTLEMAN Hotspot Node Control - Status${NC}"
    echo "==========================================="
    echo ""
    
    local network_mode
    network_mode=$(detect_network_mode)
    
    echo -e "${CYAN}Netzwerk-Modus: $network_mode${NC}"
    echo ""
    
    # Tunnel URLs anzeigen
    if [ "$network_mode" == "hotspot" ]; then
        echo -e "${CYAN}Verfügbare Tunnel:${NC}"
        local m1_url=$(get_m1_tunnel_url)
        local rx_url=$(get_rx_tunnel_url)
        
        echo "• M1 Tunnel: ${m1_url:-'Nicht verfügbar'}"
        echo "• RX Tunnel: ${rx_url:-'Nicht verfügbar'}"
        echo ""
    fi
    
    # I7 Status
    i7_status
    echo ""
    
    # RX Status
    rx_status
}

# Beide Nodes herunterfahren
all_shutdown() {
    local delay_minutes="${1:-1}"
    
    echo -e "${PURPLE}🎯 GENTLEMAN Hotspot Node Control - Shutdown${NC}"
    echo "============================================="
    echo ""
    
    log_info "Fahre beide Nodes herunter (Delay: ${delay_minutes}m)..."
    echo ""
    
    # I7 Shutdown
    i7_shutdown "$delay_minutes"
    echo ""
    
    # RX Shutdown
    rx_shutdown "$delay_minutes"
    echo ""
    
    log_success "Shutdown-Befehle für beide Nodes gesendet!"
}

# Beide Nodes aufwecken
all_wakeup() {
    echo -e "${PURPLE}🎯 GENTLEMAN Hotspot Node Control - Wake-on-LAN${NC}"
    echo "================================================"
    echo ""
    
    log_info "Wecke beide Nodes auf..."
    echo ""
    
    # I7 Wake-on-LAN
    i7_wakeup
    echo ""
    
    # RX Wake-on-LAN
    rx_wakeup
    echo ""
    
    log_success "Wake-on-LAN-Befehle für beide Nodes gesendet!"
}

# Tunnel-Status
tunnel_status() {
    echo -e "${PURPLE}🎯 GENTLEMAN Tunnel Status${NC}"
    echo "==========================="
    echo ""
    
    local network_mode
    network_mode=$(detect_network_mode)
    
    echo -e "${CYAN}Netzwerk-Modus: $network_mode${NC}"
    echo ""
    
    if [ "$network_mode" == "hotspot" ]; then
        echo -e "${CYAN}M1 Handshake Server Tunnel:${NC}"
        local m1_url=$(get_m1_tunnel_url)
        if [[ -n "$m1_url" && "$m1_url" != "Tunnel nicht verfügbar" ]]; then
            echo "✅ Verfügbar: $m1_url"
            # Teste Health Check
            if curl -s --max-time 5 "$m1_url/health" >/dev/null 2>&1; then
                echo "✅ Health Check: OK"
            else
                echo "❌ Health Check: Fehlgeschlagen"
            fi
        else
            echo "❌ Nicht verfügbar"
        fi
        
        echo ""
        echo -e "${CYAN}RX Node Tunnel:${NC}"
        local rx_url=$(get_rx_tunnel_url)
        if [[ -n "$rx_url" && "$rx_url" != "Tunnel-URL nicht verfügbar" ]]; then
            echo "✅ Verfügbar: $rx_url"
            # Teste Health Check
            if curl -s --max-time 5 "$rx_url/health" >/dev/null 2>&1; then
                echo "✅ Health Check: OK"
            else
                echo "❌ Health Check: Fehlgeschlagen"
            fi
        else
            echo "❌ Nicht verfügbar"
        fi
    else
        echo "📡 Im Heimnetzwerk - Tunnel nicht erforderlich"
    fi
}

# Hauptfunktion
main() {
    case "${1:-}" in
        "i7")
            case "${2:-}" in
                "status") i7_status ;;
                "shutdown") i7_shutdown "${3:-1}" ;;
                "wakeup") i7_wakeup ;;
                *) echo "I7 Aktionen: status|shutdown [delay]|wakeup" ;;
            esac
            ;;
        "rx")
            case "${2:-}" in
                "status") rx_status ;;
                "shutdown") rx_shutdown "${3:-1}" ;;
                "wakeup") rx_wakeup ;;
                *) echo "RX Aktionen: status|shutdown [delay]|wakeup" ;;
            esac
            ;;
        "all")
            case "${2:-}" in
                "status") all_status ;;
                "shutdown") all_shutdown "${3:-1}" ;;
                "wakeup") all_wakeup ;;
                *) echo "All Aktionen: status|shutdown [delay]|wakeup" ;;
            esac
            ;;
        "tunnels")
            tunnel_status
            ;;
        "ssh")
            case "${2:-}" in
                "i7")
                    log_info "🔐 SSH-Verbindung zum I7 Laptop..."
                    local network_mode
                    network_mode=$(detect_network_mode)
                    if [ "$network_mode" == "home" ]; then
                        log_info "📡 Direkter SSH-Zugriff im Heimnetzwerk"
                        ssh -i "$SSH_KEY_PATH" "$I7_USER@$I7_IP"
                    else
                        log_error "SSH zu I7 im Hotspot-Modus nicht verfügbar"
                        log_info "💡 Verwende: ssh -i ~/.ssh/gentleman_key amon@172.20.10.6"
                    fi
                    ;;
                "rx")
                    log_info "🔐 SSH-Verbindung zur RX Node..."
                    if command -v ./rx_ssh_tunnel_control.sh >/dev/null 2>&1; then
                        ./rx_ssh_tunnel_control.sh connect
                    else
                        log_error "RX SSH-Tunnel Control nicht gefunden"
                        log_info "💡 Führe aus: ./rx_node_ssh_tunnel_setup.sh"
                    fi
                    ;;
                *)
                    echo "SSH Optionen: i7|rx"
                    echo "Beispiele:"
                    echo "  $0 ssh i7     - SSH zum I7 Laptop"
                    echo "  $0 ssh rx     - SSH zur RX Node"
                    ;;
            esac
            ;;
        *)
            echo -e "${PURPLE}🎯 GENTLEMAN Hotspot Node Control${NC}"
            echo "=================================="
            echo ""
            echo "Kommandos:"
            echo "  i7 {status|shutdown|wakeup}     - I7 Laptop steuern"
            echo "  rx {status|shutdown|wakeup}     - RX Node steuern"
            echo "  all {status|shutdown|wakeup}    - Beide Nodes steuern"
            echo "  tunnels                         - Tunnel-Status prüfen"
            echo "  ssh {i7|rx}                     - SSH-Verbindung zu Node"
            echo ""
            echo "Beispiele:"
            echo "  $0 all status                   - Status beider Nodes"
            echo "  $0 all shutdown 5               - Beide Nodes in 5min herunterfahren"
            echo "  $0 i7 wakeup                    - I7 Laptop aufwecken"
            echo "  $0 rx shutdown 1                - RX Node in 1min herunterfahren"
            echo "  $0 tunnels                      - Tunnel-Status prüfen"
            echo "  $0 ssh rx                       - SSH zur RX Node"
            ;;
    esac
}

main "$@"