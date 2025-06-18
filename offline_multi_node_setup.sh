#!/bin/bash

# 🌐 GENTLEMAN Offline Multi-Node Setup
# Konfiguration für Multi-Node System mit offline Nodes
# Usage: ./offline_multi_node_setup.sh

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

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
    echo -e "${PURPLE}║  🌐 GENTLEMAN OFFLINE MULTI-NODE SETUP                       ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Detect current node
detect_current_node() {
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
    case "$current_ip" in
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

# Setup SSH keys for current node
setup_local_ssh() {
    log_header
    echo -e "${CYAN}🔑 SSH Key Setup für aktuellen Node${NC}"
    
    local ssh_key="$HOME/.ssh/gentleman_key"
    local ssh_pub_key="$HOME/.ssh/gentleman_key.pub"
    
    # Create SSH key if not exists
    if [ ! -f "$ssh_key" ]; then
        log_info "Erstelle neuen SSH Key..."
        ssh-keygen -t ed25519 -f "$ssh_key" -N "" -C "gentleman-$(detect_current_node)-$(date +%Y%m%d)"
        log_success "SSH Key erstellt: $ssh_key"
    else
        log_info "SSH Key bereits vorhanden: $ssh_key"
    fi
    
    # Set permissions
    chmod 600 "$ssh_key"
    chmod 644 "$ssh_pub_key"
    
    # Add to SSH agent
    ssh-add "$ssh_key" 2>/dev/null || log_warning "SSH Agent nicht verfügbar"
    
    log_success "SSH Key Setup abgeschlossen"
    
    # Display public key for manual distribution
    echo
    echo -e "${YELLOW}📋 Public Key für andere Nodes:${NC}"
    echo "----------------------------------------"
    cat "$ssh_pub_key"
    echo "----------------------------------------"
    echo
    log_info "Speichere diesen Key für spätere Verteilung an andere Nodes"
}

# Setup GENTLEMAN Protocol for current node
setup_gentleman_protocol() {
    log_header
    echo -e "${CYAN}🎩 GENTLEMAN Protocol Setup${NC}"
    
    local current_node=$(detect_current_node)
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
    
    # Update GENTLEMAN config based on current node
    if [ -f "talking_gentleman_config.json" ]; then
        # Backup original config
        cp talking_gentleman_config.json talking_gentleman_config.json.backup
        
        # Update config for current node
        cat > talking_gentleman_config.json << EOF
{
  "node_id": "${current_node}-$(hostname)-$(date +%s)",
  "role": "$(case $current_node in
    i7_node) echo "client" ;;
    rx_node) echo "primary_trainer" ;;
    m1_mac) echo "coordinator" ;;
    *) echo "unknown" ;;
  esac)",
  "ip_address": "$current_ip",
  "port": 8008,
  "discovery_port": 8009,
  "encryption": {
    "enabled": true,
    "algorithm": "AES-256-GCM"
  },
  "capabilities": [
    "knowledge_query",
    "cluster_sync",
    "offline_inference",
    "semantic_search"
  ],
  "known_nodes": {
    "i7_node": {
      "ip": "192.168.68.105",
      "port": 8008,
      "role": "client",
      "status": "$([ "$current_ip" = "192.168.68.105" ] && echo "online" || echo "unknown")"
    },
    "rx_node": {
      "ip": "192.168.68.117",
      "port": 8008,
      "role": "primary_trainer",
      "status": "offline"
    },
    "m1_mac": {
      "ip": "192.168.68.111",
      "port": 8007,
      "role": "coordinator",
      "status": "$(ping -c 1 192.168.68.111 >/dev/null 2>&1 && echo "online" || echo "offline")"
    }
  },
  "offline_mode": {
    "enabled": true,
    "fallback_nodes": [],
    "local_inference": true
  }
}
EOF
        log_success "GENTLEMAN Config für $current_node aktualisiert"
    else
        log_error "GENTLEMAN Config nicht gefunden"
    fi
}

# Create offline node management scripts
create_offline_scripts() {
    log_header
    echo -e "${CYAN}📝 Offline Node Management Scripts${NC}"
    
    # Node status checker
    cat > check_offline_nodes.sh << 'EOF'
#!/bin/bash
# Check status of all nodes in offline-compatible mode

echo "🌐 GENTLEMAN Multi-Node Status (Offline-kompatibel)"
echo "=================================================="

# Current node info
CURRENT_IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
echo "📍 Aktueller Node: $(hostname) ($CURRENT_IP)"

# Check each node
echo ""
echo "🔍 Node Status:"

# i7 Node
if [ "$CURRENT_IP" = "192.168.68.105" ]; then
    echo "✅ i7 Node (192.168.68.105): LOKAL - ONLINE"
else
    ping -c 1 -W 1 192.168.68.105 >/dev/null 2>&1 && echo "✅ i7 Node (192.168.68.105): ONLINE" || echo "❌ i7 Node (192.168.68.105): OFFLINE"
fi

# RX Node
if [ "$CURRENT_IP" = "192.168.68.117" ]; then
    echo "✅ RX Node (192.168.68.117): LOKAL - ONLINE"
else
    ping -c 1 -W 1 192.168.68.117 >/dev/null 2>&1 && echo "✅ RX Node (192.168.68.117): ONLINE" || echo "❌ RX Node (192.168.68.117): OFFLINE"
fi

# M1 Mac
if [ "$CURRENT_IP" = "192.168.68.111" ]; then
    echo "✅ M1 Mac (192.168.68.111): LOKAL - ONLINE"
else
    ping -c 1 -W 1 192.168.68.111 >/dev/null 2>&1 && echo "✅ M1 Mac (192.168.68.111): ONLINE" || echo "❌ M1 Mac (192.168.68.111): OFFLINE"
fi

echo ""
echo "🎩 GENTLEMAN Protocol Status:"
curl -s --connect-timeout 3 http://localhost:8008/status >/dev/null 2>&1 && echo "✅ GENTLEMAN Protocol: AKTIV" || echo "❌ GENTLEMAN Protocol: INAKTIV"

echo ""
echo "💡 Offline-Modus: Aktiviert für isolierte Node-Operation"
EOF

    chmod +x check_offline_nodes.sh
    log_success "Node Status Checker erstellt"
    
    # SSH key distribution helper
    cat > distribute_ssh_key.sh << 'EOF'
#!/bin/bash
# Helper script to distribute SSH keys when nodes come online

echo "🔑 SSH Key Distribution Helper"
echo "============================="

if [ ! -f "$HOME/.ssh/gentleman_key.pub" ]; then
    echo "❌ SSH Public Key nicht gefunden!"
    exit 1
fi

echo "📋 Aktueller Public Key:"
echo "----------------------------------------"
cat "$HOME/.ssh/gentleman_key.pub"
echo "----------------------------------------"
echo ""

echo "📝 Anweisungen für manuelle Verteilung:"
echo "1. Kopiere den obigen Public Key"
echo "2. Auf Ziel-Node: mkdir -p ~/.ssh"
echo "3. Auf Ziel-Node: echo 'COPIED_KEY' >> ~/.ssh/authorized_keys"
echo "4. Auf Ziel-Node: chmod 600 ~/.ssh/authorized_keys"
echo ""

echo "🎯 Ziel-Nodes:"
echo "- RX Node: amo9n11@192.168.68.117"
echo "- M1 Mac: amonbaumgartner@192.168.68.111"
echo "- i7 Node: amonbaumgartner@192.168.68.105"
EOF

    chmod +x distribute_ssh_key.sh
    log_success "SSH Key Distribution Helper erstellt"
    
    # Offline GENTLEMAN starter
    cat > start_offline_gentleman.sh << 'EOF'
#!/bin/bash
# Start GENTLEMAN Protocol in offline mode

echo "🎩 Starte GENTLEMAN Protocol (Offline-Modus)"
echo "==========================================="

# Check if config exists
if [ ! -f "talking_gentleman_config.json" ]; then
    echo "❌ GENTLEMAN Config nicht gefunden!"
    exit 1
fi

# Start in background
echo "🚀 Starte GENTLEMAN Protocol..."
python3 talking_gentleman_protocol.py --start &
GENTLEMAN_PID=$!

echo "✅ GENTLEMAN Protocol gestartet (PID: $GENTLEMAN_PID)"
echo "📍 Port: 8008"
echo "🔍 Status: http://localhost:8008/status"

# Wait and check
sleep 3
if curl -s --connect-timeout 3 http://localhost:8008/status >/dev/null 2>&1; then
    echo "✅ GENTLEMAN Protocol erfolgreich gestartet!"
else
    echo "❌ GENTLEMAN Protocol Start fehlgeschlagen"
fi
EOF

    chmod +x start_offline_gentleman.sh
    log_success "Offline GENTLEMAN Starter erstellt"
}

# Setup key rotation for offline mode
setup_offline_key_rotation() {
    log_header
    echo -e "${CYAN}🔄 Offline Key Rotation Setup${NC}"
    
    # Create offline-compatible key rotation config
    cat > offline_key_rotation_config.json << EOF
{
  "offline_mode": true,
  "ssh_keys": {
    "rotation_interval_days": 30,
    "key_type": "ed25519",
    "backup_count": 5,
    "auto_distribute": false
  },
  "current_node": "$(detect_current_node)",
  "nodes": {
    "i7_node": {
      "ip": "192.168.68.105",
      "ssh_user": "amonbaumgartner",
      "role": "client",
      "status": "$([ "$(detect_current_node)" = "i7_node" ] && echo "local" || echo "unknown")"
    },
    "rx_node": {
      "ip": "192.168.68.117",
      "ssh_user": "amo9n11",
      "role": "primary_trainer",
      "status": "offline"
    },
    "m1_mac": {
      "ip": "192.168.68.111",
      "ssh_user": "amonbaumgartner",
      "role": "coordinator",
      "status": "$(ping -c 1 192.168.68.111 >/dev/null 2>&1 && echo "online" || echo "offline")"
    }
  },
  "manual_distribution": {
    "enabled": true,
    "instructions": "Use distribute_ssh_key.sh for manual key distribution"
  }
}
EOF

    log_success "Offline Key Rotation Config erstellt"
}

# Main setup execution
main_setup() {
    log_header
    echo -e "${CYAN}🚀 GENTLEMAN Offline Multi-Node Setup${NC}"
    echo "Aktueller Node: $(detect_current_node)"
    echo "IP Adresse: $(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)"
    echo
    
    # Execute setup steps
    setup_local_ssh
    echo
    setup_gentleman_protocol
    echo
    create_offline_scripts
    echo
    setup_offline_key_rotation
    
    echo
    log_header
    echo -e "${GREEN}🎉 Offline Multi-Node Setup abgeschlossen!${NC}"
    echo
    echo -e "${YELLOW}📋 Verfügbare Kommandos:${NC}"
    echo "• ./check_offline_nodes.sh - Node Status prüfen"
    echo "• ./distribute_ssh_key.sh - SSH Key Verteilung"
    echo "• ./start_offline_gentleman.sh - GENTLEMAN Protocol starten"
    echo "• ./multi_node_manager.sh - Vollständiges Node Management"
    echo
    echo -e "${BLUE}💡 Nächste Schritte:${NC}"
    echo "1. GENTLEMAN Protocol starten: ./start_offline_gentleman.sh"
    echo "2. Node Status prüfen: ./check_offline_nodes.sh"
    echo "3. Bei Node-Wiederherstellung: SSH Keys verteilen"
    echo
    log_success "System bereit für Offline-Operation!"
}

# Execute main setup
main_setup 