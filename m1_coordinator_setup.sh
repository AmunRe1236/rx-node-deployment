#!/bin/bash

# 🌐 M1 Mac Coordinator Setup - Multi-Node HTTP Connectivity
# Konfiguriert M1 Mac als zentraler Coordinator für GENTLEMAN Multi-Node System

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🌐 M1 MAC COORDINATOR SETUP                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# Node Definitionen
M1_MAC_IP="192.168.68.111"
I7_NODE_IP="192.168.68.105"
RX_NODE_IP="192.168.68.117"
GENTLEMAN_PORT="8008"

echo "🔧 Konfiguriere M1 Mac als Multi-Node Coordinator..."
echo ""

# HTTP Connectivity Test Function
test_node_http() {
    local node_name="$1"
    local node_ip="$2"
    local port="$3"
    
    echo "📡 Teste HTTP Connectivity zu $node_name ($node_ip:$port):"
    
    if curl -s --connect-timeout 5 "http://$node_ip:$port/status" > /dev/null; then
        echo "✅ $node_name HTTP: ERREICHBAR"
        return 0
    else
        echo "❌ $node_name HTTP: NICHT ERREICHBAR"
        return 1
    fi
}

# SSH Connectivity Test Function  
test_node_ssh() {
    local node_name="$1"
    local ssh_target="$2"
    
    echo "🔑 Teste SSH Connectivity zu $node_name:"
    
    if ssh -i ~/.ssh/gentleman_key -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$ssh_target" "echo 'SSH OK'" >/dev/null 2>&1; then
        echo "✅ $node_name SSH: ERREICHBAR"
        return 0
    else
        echo "❌ $node_name SSH: NICHT ERREICHBAR"
        return 1
    fi
}

# Multi-Node Status Check Function
get_node_status() {
    local node_name="$1"
    local node_ip="$2"
    local port="$3"
    
    echo "📊 $node_name Status:"
    local status=$(curl -s --connect-timeout 3 "http://$node_ip:$port/status" 2>/dev/null)
    
    if [ ! -z "$status" ]; then
        echo "✅ Response: $status"
    else
        echo "❌ Keine Response"
    fi
    echo ""
}

# Coordinator Configuration
setup_coordinator_config() {
    echo "📝 Erstelle Coordinator Konfiguration..."
    
    cat > ~/Gentleman/coordinator_config.json << EOF
{
    "coordinator": {
        "node_id": "m1-coordinator",
        "role": "coordinator", 
        "ip": "$M1_MAC_IP",
        "port": $GENTLEMAN_PORT
    },
    "nodes": {
        "i7_node": {
            "node_id": "i7-client",
            "role": "client",
            "ip": "$I7_NODE_IP", 
            "port": $GENTLEMAN_PORT,
            "ssh_user": "amonbaumgartner",
            "capabilities": ["cpu_processing", "local_storage"]
        },
        "rx_node": {
            "node_id": "rx-trainer", 
            "role": "ai_trainer",
            "ip": "$RX_NODE_IP",
            "port": $GENTLEMAN_PORT,
            "ssh_user": "amo9n11",
            "capabilities": ["gpu_training", "ai_inference"]
        }
    },
    "connectivity": {
        "ssh_key": "~/.ssh/gentleman_key",
        "timeout": 5,
        "retry_attempts": 3
    }
}
EOF
    
    echo "✅ Coordinator Config erstellt: ~/Gentleman/coordinator_config.json"
}

# Cross-Node HTTP Test Function
test_cross_node_http() {
    echo "🌐 Cross-Node HTTP Connectivity Tests:"
    echo ""
    
    # Test zu i7 Node
    get_node_status "i7 Node" "$I7_NODE_IP" "$GENTLEMAN_PORT"
    
    # Test zu RX Node  
    get_node_status "RX Node" "$RX_NODE_IP" "$GENTLEMAN_PORT"
    
    # Lokaler M1 Test
    get_node_status "M1 Mac (local)" "localhost" "$GENTLEMAN_PORT"
}

# Remote Node Service Check via SSH
check_remote_services() {
    echo "🔧 Remote Node Service Check via SSH:"
    echo ""
    
    # Check i7 Node
    echo "📡 i7 Node Service Status:"
    ssh -i ~/.ssh/gentleman_key -o ConnectTimeout=5 amonbaumgartner@$I7_NODE_IP "ps aux | grep -v grep | grep talking_gentleman || echo 'Service nicht aktiv'"
    echo ""
    
    # Check RX Node
    echo "📡 RX Node Service Status:"  
    ssh -i ~/.ssh/gentleman_key -o ConnectTimeout=5 amo9n11@$RX_NODE_IP "ps aux | grep -v grep | grep talking_gentleman || echo 'Service nicht aktiv'"
    echo ""
}

# Node Discovery Function
discover_nodes() {
    echo "🔍 Node Discovery - Suche aktive GENTLEMAN Nodes:"
    echo ""
    
    local nodes_found=0
    
    # Scan für aktive Nodes im Netzwerk
    for ip in $I7_NODE_IP $RX_NODE_IP; do
        echo "🔎 Scanne $ip:$GENTLEMAN_PORT..."
        
        if curl -s --connect-timeout 2 "http://$ip:$GENTLEMAN_PORT/status" > /dev/null 2>&1; then
            echo "✅ Node gefunden: $ip:$GENTLEMAN_PORT"
            nodes_found=$((nodes_found + 1))
            
            # Hole Node Details
            local node_info=$(curl -s "http://$ip:$GENTLEMAN_PORT/status" 2>/dev/null)
            echo "   📋 Details: $node_info"
        else
            echo "❌ Keine Response von $ip:$GENTLEMAN_PORT"
        fi
        echo ""
    done
    
    echo "📊 Discovery Ergebnis: $nodes_found/2 Nodes gefunden"
    return $nodes_found
}

# Main Setup Function
main() {
    echo "🚀 Starte M1 Mac Coordinator Setup..."
    echo ""
    
    # 1. SSH Connectivity Tests
    echo "🔑 SSH Connectivity Tests:"
    test_node_ssh "i7 Node" "amonbaumgartner@$I7_NODE_IP"
    test_node_ssh "RX Node" "amo9n11@$RX_NODE_IP"
    echo ""
    
    # 2. Setup Coordinator Config
    setup_coordinator_config
    echo ""
    
    # 3. Node Discovery
    discover_nodes
    echo ""
    
    # 4. HTTP Connectivity Tests
    test_cross_node_http
    echo ""
    
    # 5. Remote Service Check
    check_remote_services
    
    echo "🎯 M1 Mac Coordinator Setup abgeschlossen!"
    echo ""
    echo "📋 Verfügbare Coordinator Kommandos:"
    echo "   curl -s http://localhost:$GENTLEMAN_PORT/status"
    echo "   curl -s http://$I7_NODE_IP:$GENTLEMAN_PORT/status" 
    echo "   curl -s http://$RX_NODE_IP:$GENTLEMAN_PORT/status"
    echo ""
    echo "🌐 Multi-Node Management:"
    echo "   ssh amonbaumgartner@$I7_NODE_IP 'curl -s http://localhost:$GENTLEMAN_PORT/status'"
    echo "   ssh amo9n11@$RX_NODE_IP 'curl -s http://localhost:$GENTLEMAN_PORT/status'"
}

# Script ausführen
main "$@" 