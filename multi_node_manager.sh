#!/bin/bash

# 🌐 GENTLEMAN Multi-Node Manager
# Zentrale Verwaltung für SSH, Key Rotation und Node Koordination
# Usage: ./multi_node_manager.sh [command]

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
CONFIG_FILE="key_rotation_config.json"
SSH_KEY="$HOME/.ssh/gentleman_key"
SSH_PUB_KEY="$HOME/.ssh/gentleman_key.pub"

# Node definitions from config
I7_NODE="192.168.68.105"
RX_NODE="192.168.68.117"
M1_MAC="192.168.68.111"

# Current node detection
CURRENT_IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
CURRENT_HOSTNAME=$(hostname)

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_header() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║  🌐 GENTLEMAN MULTI-NODE MANAGER                             ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Detect current node role
detect_current_node() {
    case "$CURRENT_IP" in
        "192.168.68.105")
            echo "i7_node"
            ;;
        "192.168.68.117")
            echo "rx_node"
            ;;
        "192.168.68.111")
            echo "m1_mac"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Test SSH connectivity to a node
test_ssh_connection() {
    local target_ip=$1
    local target_user=$2
    local node_name=$3
    
    log_info "Teste SSH-Verbindung zu $node_name ($target_ip)..."
    
    if ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes \
       "$target_user@$target_ip" "echo 'SSH Test erfolgreich' && hostname && date" 2>/dev/null; then
        log_success "$node_name SSH: Verbindung erfolgreich"
        return 0
    else
        log_error "$node_name SSH: Verbindung fehlgeschlagen"
        return 1
    fi
}

# Test all node connections
test_all_connections() {
    log_header
    echo -e "${CYAN}🔍 Multi-Node Connectivity Test${NC}"
    echo "📍 Aktueller Node: $CURRENT_HOSTNAME ($CURRENT_IP)"
    echo "🎭 Node-Rolle: $(detect_current_node)"
    echo
    
    local success_count=0
    local total_nodes=0
    
    # Test RX Node (if not current)
    if [ "$CURRENT_IP" != "$RX_NODE" ]; then
        total_nodes=$((total_nodes + 1))
        if test_ssh_connection "$RX_NODE" "amo9n11" "RX Node"; then
            success_count=$((success_count + 1))
        fi
    fi
    
    # Test M1 Mac (if not current)
    if [ "$CURRENT_IP" != "$M1_MAC" ]; then
        total_nodes=$((total_nodes + 1))
        if test_ssh_connection "$M1_MAC" "amo9n11" "M1 Mac"; then
            success_count=$((success_count + 1))
        fi
    fi
    
    # Test i7 Node (if not current)
    if [ "$CURRENT_IP" != "$I7_NODE" ]; then
        total_nodes=$((total_nodes + 1))
        if test_ssh_connection "$I7_NODE" "amonbaumgartner" "i7 Node"; then
            success_count=$((success_count + 1))
        fi
    fi
    
    echo
    echo -e "${PURPLE}📊 Connectivity Summary:${NC}"
    echo "✅ Erfolgreiche Verbindungen: $success_count/$total_nodes"
    
    if [ $success_count -eq $total_nodes ]; then
        log_success "Alle Node-Verbindungen funktional!"
        return 0
    else
        log_warning "Einige Node-Verbindungen haben Probleme"
        return 1
    fi
}

# Setup SSH keys for multi-node access
setup_ssh_keys() {
    log_header
    echo -e "${CYAN}🔑 SSH Key Setup für Multi-Node Zugriff${NC}"
    
    # Check if SSH key exists
    if [ ! -f "$SSH_KEY" ]; then
        log_info "Erstelle neuen SSH Key..."
        ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "gentleman-multi-node-$(date +%Y%m%d)"
        log_success "SSH Key erstellt: $SSH_KEY"
    else
        log_info "SSH Key bereits vorhanden: $SSH_KEY"
    fi
    
    # Set correct permissions
    chmod 600 "$SSH_KEY"
    chmod 644 "$SSH_PUB_KEY"
    
    log_success "SSH Key Berechtigungen gesetzt"
    
    # Display public key for manual distribution
    echo
    echo -e "${YELLOW}📋 Public Key für andere Nodes:${NC}"
    echo "----------------------------------------"
    cat "$SSH_PUB_KEY"
    echo "----------------------------------------"
    echo
    log_info "Kopiere diesen Public Key in die ~/.ssh/authorized_keys der anderen Nodes"
}

# Rotate SSH keys
rotate_ssh_keys() {
    log_header
    echo -e "${CYAN}🔄 SSH Key Rotation${NC}"
    
    # Backup current key
    if [ -f "$SSH_KEY" ]; then
        local backup_dir="$HOME/.ssh/backups"
        mkdir -p "$backup_dir"
        local timestamp=$(date +%Y%m%d_%H%M%S)
        cp "$SSH_KEY" "$backup_dir/gentleman_key_$timestamp"
        cp "$SSH_PUB_KEY" "$backup_dir/gentleman_key_$timestamp.pub"
        log_success "Alte Keys gesichert: $backup_dir/gentleman_key_$timestamp"
    fi
    
    # Generate new key
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "gentleman-rotated-$(date +%Y%m%d)"
    chmod 600 "$SSH_KEY"
    chmod 644 "$SSH_PUB_KEY"
    
    log_success "Neue SSH Keys generiert"
    
    # Display new public key
    echo
    echo -e "${YELLOW}📋 Neuer Public Key für Verteilung:${NC}"
    echo "----------------------------------------"
    cat "$SSH_PUB_KEY"
    echo "----------------------------------------"
    
    log_warning "WICHTIG: Verteile den neuen Public Key an alle Nodes!"
}

# Check node services
check_node_services() {
    log_header
    echo -e "${CYAN}🔍 Node Services Status Check${NC}"
    echo "📍 Aktueller Node: $(detect_current_node) ($CURRENT_IP)"
    echo
    
    # Check GENTLEMAN Protocol
    if curl -s --connect-timeout 3 "http://localhost:8008/status" > /dev/null 2>&1; then
        log_success "GENTLEMAN Protocol (Port 8008): Aktiv"
    else
        log_error "GENTLEMAN Protocol (Port 8008): Inaktiv"
    fi
    
    # Check LM Studio (port depends on node)
    local lm_port
    case "$(detect_current_node)" in
        "i7_node")
            lm_port=1235
            ;;
        "rx_node")
            lm_port=1234
            ;;
        "m1_mac")
            lm_port=8007
            ;;
    esac
    
    if [ -n "$lm_port" ]; then
        if curl -s --connect-timeout 3 "http://localhost:$lm_port/v1/models" > /dev/null 2>&1; then
            log_success "LM Studio (Port $lm_port): Aktiv"
        else
            log_error "LM Studio (Port $lm_port): Inaktiv"
        fi
    fi
    
    # Check Git Daemon (M1 Mac only)
    if [ "$(detect_current_node)" = "m1_mac" ]; then
        if pgrep -f "git daemon" > /dev/null; then
            log_success "Git Daemon: Aktiv"
        else
            log_error "Git Daemon: Inaktiv"
        fi
    fi
}

# Deploy to remote node
deploy_to_node() {
    local target_ip=$1
    local target_user=$2
    local node_name=$3
    
    log_info "Deploying zu $node_name ($target_ip)..."
    
    # Copy essential files
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no \
        "key_rotation_config.json" \
        "multi_node_manager.sh" \
        "$target_user@$target_ip:~/Gentleman/" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_success "$node_name: Deployment erfolgreich"
    else
        log_error "$node_name: Deployment fehlgeschlagen"
    fi
}

# Deploy to all nodes
deploy_all() {
    log_header
    echo -e "${CYAN}🚀 Multi-Node Deployment${NC}"
    
    # Deploy to RX Node (if not current)
    if [ "$CURRENT_IP" != "$RX_NODE" ]; then
        deploy_to_node "$RX_NODE" "amo9n11" "RX Node"
    fi
    
    # Deploy to M1 Mac (if not current)
    if [ "$CURRENT_IP" != "$M1_MAC" ]; then
        deploy_to_node "$M1_MAC" "amo9n11" "M1 Mac"
    fi
    
    # Deploy to i7 Node (if not current)
    if [ "$CURRENT_IP" != "$I7_NODE" ]; then
        deploy_to_node "$I7_NODE" "amonbaumgartner" "i7 Node"
    fi
}

# Main menu
show_menu() {
    log_header
    echo -e "${CYAN}🎛️  Multi-Node Manager Menü${NC}"
    echo
    echo "1. 🔍 Test All Connections"
    echo "2. 🔑 Setup SSH Keys"
    echo "3. 🔄 Rotate SSH Keys"
    echo "4. 🔍 Check Node Services"
    echo "5. 🚀 Deploy to All Nodes"
    echo "6. 📊 Full System Status"
    echo "7. ❌ Exit"
    echo
}

# Full system status
full_system_status() {
    log_header
    echo -e "${CYAN}📊 GENTLEMAN Multi-Node System Status${NC}"
    echo
    
    check_node_services
    echo
    test_all_connections
    
    echo
    echo -e "${PURPLE}🌐 Node Architecture:${NC}"
    echo "├── i7 Node (192.168.68.105): CPU Inferenz, Client"
    echo "├── RX Node (192.168.68.117): GPU Inferenz, Primary Trainer"
    echo "└── M1 Mac (192.168.68.111): Koordinator, Git Server"
}

# Main execution
case "${1:-menu}" in
    "test"|"t")
        test_all_connections
        ;;
    "setup"|"s")
        setup_ssh_keys
        ;;
    "rotate"|"r")
        rotate_ssh_keys
        ;;
    "services"|"srv")
        check_node_services
        ;;
    "deploy"|"d")
        deploy_all
        ;;
    "status"|"st")
        full_system_status
        ;;
    "menu"|"m"|*)
        while true; do
            show_menu
            read -p "Wähle eine Option (1-7): " choice
            case $choice in
                1) test_all_connections ;;
                2) setup_ssh_keys ;;
                3) rotate_ssh_keys ;;
                4) check_node_services ;;
                5) deploy_all ;;
                6) full_system_status ;;
                7) echo "Auf Wiedersehen!"; exit 0 ;;
                *) log_error "Ungültige Auswahl" ;;
            esac
            echo
            read -p "Drücke Enter um fortzufahren..."
        done
        ;;
esac 