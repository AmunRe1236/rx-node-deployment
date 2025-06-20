#!/usr/bin/env bash

# GENTLEMAN Mesh Node Control
# Unified control script für alle Nodes im Tailscale Mesh-Netzwerk

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktion
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Hilfe-Funktion
show_help() {
    echo ""
    log "${BLUE}🕸️ GENTLEMAN Mesh Node Control${NC}"
    log "${BLUE}==============================${NC}"
    echo ""
    echo "Usage: $0 <node> <command>"
    echo ""
    echo "Nodes:"
    echo "  m1       - M1 Mac (100.96.219.28)"
    echo "  rx       - RX Node (via Tailscale)"
    echo "  i7       - I7 Laptop (via Tailscale)"
    echo "  all      - Alle verfügbaren Nodes"
    echo ""
    echo "Commands:"
    echo "  status   - Node-Status anzeigen"
    echo "  shutdown - Node herunterfahren"
    echo "  wakeup   - Node aufwecken (Wake-on-LAN)"
    echo "  ping     - Ping-Test zum Node"
    echo "  ssh      - SSH-Verbindung zum Node"
    echo ""
    echo "Mesh Commands:"
    echo "  mesh     - Vollständige Mesh-Überprüfung"
    echo "  setup    - Setup-Anweisungen anzeigen"
    echo ""
    echo "Examples:"
    echo "  $0 rx status     - RX Node Status"
    echo "  $0 all ping      - Ping alle Nodes"
    echo "  $0 mesh          - Mesh-Netzwerk überprüfen"
    echo ""
}

# Node-Konfiguration mit einfachen Arrays
NODE_IPS_m1="100.96.219.28"
NODE_IPS_rx=""
NODE_IPS_i7=""

NODE_SSH_HOSTS_m1="100.96.219.28"
NODE_SSH_HOSTS_rx="rx-node-tailscale"
NODE_SSH_HOSTS_i7=""

NODE_NAMES_m1="M1 Mac"
NODE_NAMES_rx="RX Node"
NODE_NAMES_i7="I7 Laptop"

NODE_MAC_ADDRESSES_m1=""
NODE_MAC_ADDRESSES_rx="30:9c:23:5f:44:a8"
NODE_MAC_ADDRESSES_i7=""

# Hilfsfunktionen für Array-Zugriff
get_node_ip() {
    case $1 in
        "m1") echo "$NODE_IPS_m1" ;;
        "rx") echo "$NODE_IPS_rx" ;;
        "i7") echo "$NODE_IPS_i7" ;;
    esac
}

set_node_ip() {
    case $1 in
        "m1") NODE_IPS_m1="$2" ;;
        "rx") NODE_IPS_rx="$2" ;;
        "i7") NODE_IPS_i7="$2" ;;
    esac
}

get_node_ssh_host() {
    case $1 in
        "m1") echo "$NODE_SSH_HOSTS_m1" ;;
        "rx") echo "$NODE_SSH_HOSTS_rx" ;;
        "i7") echo "$NODE_SSH_HOSTS_i7" ;;
    esac
}

set_node_ssh_host() {
    case $1 in
        "m1") NODE_SSH_HOSTS_m1="$2" ;;
        "rx") NODE_SSH_HOSTS_rx="$2" ;;
        "i7") NODE_SSH_HOSTS_i7="$2" ;;
    esac
}

get_node_name() {
    case $1 in
        "m1") echo "$NODE_NAMES_m1" ;;
        "rx") echo "$NODE_NAMES_rx" ;;
        "i7") echo "$NODE_NAMES_i7" ;;
    esac
}

get_node_mac() {
    case $1 in
        "m1") echo "$NODE_MAC_ADDRESSES_m1" ;;
        "rx") echo "$NODE_MAC_ADDRESSES_rx" ;;
        "i7") echo "$NODE_MAC_ADDRESSES_i7" ;;
    esac
}

# Erkenne aktuelle Node-IPs
detect_node_ips() {
    # RX Node IP via SSH
    RX_IP=$(ssh rx-node "tailscale ip -4" 2>/dev/null || echo "")
    if [ -n "$RX_IP" ]; then
        set_node_ip "rx" "$RX_IP"
        set_node_ssh_host "rx" "$RX_IP"
    fi
    
    # I7 Laptop IP (falls verfügbar)
    CURRENT_IP=$(tailscale ip -4 2>/dev/null || echo "")
    if [ "$CURRENT_IP" != "$(get_node_ip m1)" ] && [ -n "$CURRENT_IP" ]; then
        set_node_ip "i7" "$CURRENT_IP"
        set_node_ssh_host "i7" "$CURRENT_IP"
    fi
}

# Ping-Test
ping_node() {
    local node=$1
    local ip=$(get_node_ip "$node")
    local name=$(get_node_name "$node")
    
    if [ -z "$ip" ]; then
        log "${RED}❌ $name: IP nicht verfügbar${NC}"
        return 1
    fi
    
    if ping -c 1 -W 3 "$ip" >/dev/null 2>&1; then
        log "${GREEN}✅ $name ($ip): Online${NC}"
        return 0
    else
        log "${RED}❌ $name ($ip): Offline${NC}"
        return 1
    fi
}

# Node-Status
node_status() {
    local node=$1
    local ip=$(get_node_ip "$node")
    local name=$(get_node_name "$node")
    local ssh_host=$(get_node_ssh_host "$node")
    
    if [ -z "$ip" ]; then
        log "${RED}❌ $name: Nicht im Tailscale-Netz${NC}"
        return 1
    fi
    
    log "${BLUE}📊 $name Status:${NC}"
    
    # Ping-Test
    if ping -c 1 -W 3 "$ip" >/dev/null 2>&1; then
        log "${GREEN}   ✅ Ping: Online${NC}"
        
        # SSH-Test (falls verfügbar)
        if [ -n "$ssh_host" ] && [ "$node" != "m1" ]; then
            if ssh -o ConnectTimeout=5 "$ssh_host" "echo 'SSH OK'" >/dev/null 2>&1; then
                log "${GREEN}   ✅ SSH: Verfügbar${NC}"
                
                # System-Info via SSH
                HOSTNAME=$(ssh "$ssh_host" "hostname" 2>/dev/null || echo "unknown")
                UPTIME=$(ssh "$ssh_host" "uptime -p" 2>/dev/null || echo "unknown")
                log "${BLUE}   📋 Hostname: $HOSTNAME${NC}"
                log "${BLUE}   ⏰ Uptime: $UPTIME${NC}"
            else
                log "${YELLOW}   ⚠️ SSH: Nicht verfügbar${NC}"
            fi
        fi
    else
        log "${RED}   ❌ Ping: Offline${NC}"
    fi
    
    log "${BLUE}   🌐 IP: $ip${NC}"
}

# Node herunterfahren
shutdown_node() {
    local node=$1
    local name=$(get_node_name "$node")
    local ssh_host=$(get_node_ssh_host "$node")
    
    if [ -z "$(get_node_ip "$node")" ]; then
        log "${RED}❌ $name: Nicht im Tailscale-Netz${NC}"
        return 1
    fi
    
    case $node in
        "m1")
            log "${YELLOW}⚠️ M1 Mac Shutdown über lokale API...${NC}"
            curl -s -X POST "http://localhost:8765/admin/shutdown" || log "${RED}❌ Shutdown fehlgeschlagen${NC}"
            ;;
        "rx"|"i7")
            if [ -n "$ssh_host" ]; then
                log "${YELLOW}🛑 $name wird heruntergefahren...${NC}"
                ssh "$ssh_host" "sudo shutdown -h now" 2>/dev/null || log "${RED}❌ Shutdown fehlgeschlagen${NC}"
            else
                log "${RED}❌ SSH-Host für $name nicht verfügbar${NC}"
            fi
            ;;
    esac
}

# Node aufwecken (Wake-on-LAN)
wakeup_node() {
    local node=$1
    local name=$(get_node_name "$node")
    local mac=$(get_node_mac "$node")
    
    if [ -z "$mac" ]; then
        log "${RED}❌ $name: MAC-Adresse nicht verfügbar${NC}"
        return 1
    fi
    
    log "${BLUE}🔌 $name wird aufgeweckt...${NC}"
    
    # Wake-on-LAN über M1 Mac API
    if curl -s -X POST "http://localhost:8765/admin/bootup" \
        -H "Content-Type: application/json" \
        -d "{\"mac_address\":\"$mac\"}" | grep -q "success"; then
        log "${GREEN}✅ Wake-on-LAN Signal gesendet${NC}"
    else
        log "${RED}❌ Wake-on-LAN fehlgeschlagen${NC}"
    fi
}

# SSH-Verbindung
ssh_node() {
    local node=$1
    local name=$(get_node_name "$node")
    local ssh_host=$(get_node_ssh_host "$node")
    
    if [ -z "$ssh_host" ]; then
        log "${RED}❌ $name: SSH-Host nicht verfügbar${NC}"
        return 1
    fi
    
    log "${BLUE}🔗 Verbinde zu $name...${NC}"
    ssh "$ssh_host"
}

# Mesh-Überprüfung
check_mesh() {
    log "${BLUE}🕸️ Führe vollständige Mesh-Überprüfung aus...${NC}"
    ./verify_complete_mesh.sh
}

# Setup-Anweisungen
show_setup() {
    log "${BLUE}🛠️ GENTLEMAN Tailscale Mesh Setup${NC}"
    log "${BLUE}==================================${NC}"
    echo ""
    log "${YELLOW}Verfügbare Setup-Scripts:${NC}"
    echo ""
    echo "1. RX Node Integration:"
    echo "   ./rx_node_tailscale_manual_setup.sh"
    echo ""
    echo "2. I7 Laptop Integration:"
    echo "   ./i7_tailscale_setup.sh"
    echo ""
    echo "3. Mesh-Überprüfung:"
    echo "   ./verify_complete_mesh.sh"
    echo ""
    echo "4. RX Node Verification:"
    echo "   ./verify_rx_tailscale.sh"
    echo ""
    log "${YELLOW}Manuelle Schritte:${NC}"
    echo ""
    echo "1. Öffne https://login.tailscale.com/admin/machines"
    echo "2. Überprüfe alle Geräte sind verbunden"
    echo "3. Teste Verbindungen zwischen den Geräten"
    echo ""
}

# Hauptlogik
if [ $# -lt 1 ]; then
    show_help
    exit 1
fi

NODE=$1
COMMAND=${2:-status}

# Spezielle Commands
case $NODE in
    "mesh")
        check_mesh
        exit 0
        ;;
    "setup")
        show_setup
        exit 0
        ;;
    "help"|"-h"|"--help")
        show_help
        exit 0
        ;;
esac

# Erkenne Node-IPs
detect_node_ips

# Validiere Node
if [ "$NODE" != "all" ] && [ -z "$(get_node_name "$NODE")" ]; then
    log "${RED}❌ Unbekannte Node: $NODE${NC}"
    show_help
    exit 1
fi

# Führe Command aus
case $COMMAND in
    "status")
        if [ "$NODE" = "all" ]; then
            for node in m1 rx i7; do
                node_status "$node"
                echo ""
            done
        else
            node_status "$NODE"
        fi
        ;;
    "ping")
        if [ "$NODE" = "all" ]; then
            for node in m1 rx i7; do
                ping_node "$node"
            done
        else
            ping_node "$NODE"
        fi
        ;;
    "shutdown")
        if [ "$NODE" = "all" ]; then
            log "${YELLOW}⚠️ Shutdown aller Nodes...${NC}"
            for node in m1 rx i7; do
                shutdown_node "$node"
            done
        else
            shutdown_node "$NODE"
        fi
        ;;
    "wakeup")
        if [ "$NODE" = "all" ]; then
            log "${BLUE}🔌 Wake-up aller Nodes...${NC}"
            for node in m1 rx i7; do
                wakeup_node "$node"
            done
        else
            wakeup_node "$NODE"
        fi
        ;;
    "ssh")
        if [ "$NODE" = "all" ]; then
            log "${RED}❌ SSH nicht für 'all' verfügbar${NC}"
            exit 1
        else
            ssh_node "$NODE"
        fi
        ;;
    *)
        log "${RED}❌ Unbekanntes Command: $COMMAND${NC}"
        show_help
        exit 1
        ;;
esac 