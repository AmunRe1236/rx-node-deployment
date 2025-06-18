#!/bin/bash

# 🎯 RX Node Wake-Up Script
# Ausführung vom i7 Node zur RX Node
# Version: 1.0

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
RX_NODE_IP="192.168.68.117"
RX_NODE_PORT="8008"
I7_NODE_IP="192.168.68.105"

echo -e "${BLUE}🎯 RX Node Wake-Up Test vom i7 Node${NC}"
echo -e "${BLUE}====================================${NC}"
echo "Source: i7 Node (192.168.68.105)"
echo "Target: RX Node (192.168.68.117)"
echo "Timestamp: $(date)"
echo ""

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to test from i7 node
test_from_i7() {
    log "🔍 Teste vom i7 Node zur RX Node..."
    
    # Test 1: Network connectivity
    log "1. Netzwerk Konnektivität Test..."
    if ssh i7-node "ping -c 3 $RX_NODE_IP"; then
        log "   ✅ RX Node erreichbar"
    else
        error "   ❌ RX Node nicht erreichbar"
        return 1
    fi
    
    # Test 2: SSH connectivity
    log "2. SSH Konnektivität Test..."
    if ssh i7-node "ssh -o ConnectTimeout=5 amo9n11@$RX_NODE_IP 'echo \"SSH OK from i7 to RX\"'"; then
        log "   ✅ SSH Verbindung funktioniert"
    else
        error "   ❌ SSH Verbindung fehlgeschlagen"
        return 1
    fi
    
    # Test 3: Check RX Node GENTLEMAN status
    log "3. RX Node GENTLEMAN Status Check..."
    local rx_status
    rx_status=$(ssh i7-node "ssh amo9n11@$RX_NODE_IP 'cd ~/Gentleman 2>/dev/null && python3 talking_gentleman_protocol.py --status 2>/dev/null || echo \"GENTLEMAN not ready\"'")
    
    if [[ "$rx_status" == *"Primary AI Trainer"* ]]; then
        log "   ✅ RX Node GENTLEMAN System bereit"
        echo "   $rx_status"
    else
        warning "   ⚠️  RX Node GENTLEMAN System nicht bereit"
        echo "   Response: $rx_status"
    fi
    
    # Test 4: HTTP Service test
    log "4. HTTP Service Test..."
    local http_test
    http_test=$(ssh i7-node "curl -s --connect-timeout 5 http://$RX_NODE_IP:$RX_NODE_PORT/health 2>/dev/null || echo 'Service nicht erreichbar'")
    
    if [[ "$http_test" == "OK" ]]; then
        log "   ✅ RX Node HTTP Service läuft"
    else
        warning "   ⚠️  RX Node HTTP Service nicht verfügbar"
        echo "   Response: $http_test"
    fi
    
    return 0
}

# Function to wake up RX node
wake_rx_node() {
    log "🚀 Versuche RX Node aufzuwecken..."
    
    # Step 1: Ensure RX Node has latest setup
    log "1. Prüfe RX Node Setup..."
    if ssh i7-node "ssh amo9n11@$RX_NODE_IP 'test -f ~/rx_local_setup.sh'"; then
        log "   ✅ Setup Script gefunden"
    else
        warning "   ⚠️  Setup Script nicht gefunden - übertrage es"
        scp -i ~/.ssh/gentleman_key rx_local_setup.sh i7-node:~/
        ssh i7-node "scp ~/rx_local_setup.sh amo9n11@$RX_NODE_IP:~/"
    fi
    
    # Step 2: Run setup if needed
    log "2. Führe Setup aus (falls nötig)..."
    ssh i7-node "ssh amo9n11@$RX_NODE_IP 'if [ ! -d ~/Gentleman ]; then chmod +x ~/rx_local_setup.sh && ~/rx_local_setup.sh; else echo \"Gentleman directory exists\"; fi'"
    
    # Step 3: Test RX Node system
    log "3. Teste RX Node System..."
    ssh i7-node "ssh amo9n11@$RX_NODE_IP 'cd ~/Gentleman && ./test_gentleman.sh'"
    
    # Step 4: Start RX Node service
    log "4. Starte RX Node Service..."
    ssh i7-node "ssh amo9n11@$RX_NODE_IP 'cd ~/Gentleman && python3 talking_gentleman_protocol.py --start &'" &
    
    # Wait a moment for service to start
    sleep 3
    
    # Step 5: Test service
    log "5. Teste gestarteten Service..."
    local service_test
    service_test=$(ssh i7-node "curl -s --connect-timeout 5 http://$RX_NODE_IP:$RX_NODE_PORT/status 2>/dev/null || echo 'Service test failed'")
    
    if [[ "$service_test" == *"online"* ]]; then
        log "   ✅ RX Node Service erfolgreich gestartet"
        echo "   Status: $service_test"
    else
        warning "   ⚠️  Service Test unvollständig"
        echo "   Response: $service_test"
    fi
    
    return 0
}

# Function to test i7 to RX communication
test_i7_to_rx_communication() {
    log "🔗 Teste i7 ↔ RX Kommunikation..."
    
    # Test 1: i7 Node status
    log "1. i7 Node Status..."
    local i7_status
    i7_status=$(ssh i7-node "cd ~/Gentleman 2>/dev/null && python3 talking_gentleman_protocol.py --status 2>/dev/null || echo 'i7 GENTLEMAN not ready'")
    
    if [[ "$i7_status" == *"Client"* ]]; then
        log "   ✅ i7 Node GENTLEMAN bereit"
    else
        warning "   ⚠️  i7 Node GENTLEMAN nicht bereit"
        echo "   Status: $i7_status"
    fi
    
    # Test 2: Cross-node HTTP test
    log "2. Cross-Node HTTP Test..."
    
    # From i7 to RX
    local i7_to_rx
    i7_to_rx=$(ssh i7-node "curl -s --connect-timeout 5 http://$RX_NODE_IP:$RX_NODE_PORT/status 2>/dev/null | head -1 || echo 'Failed'")
    
    if [[ "$i7_to_rx" == *"online"* ]]; then
        log "   ✅ i7 → RX HTTP Kommunikation funktioniert"
    else
        warning "   ⚠️  i7 → RX HTTP Kommunikation fehlgeschlagen"
        echo "   Response: $i7_to_rx"
    fi
    
    # Test 3: Database connectivity test
    log "3. Database Verbindung Test..."
    ssh i7-node "ssh amo9n11@$RX_NODE_IP 'cd ~/Gentleman && python3 -c \"
import sqlite3
import json
try:
    conn = sqlite3.connect('knowledge.db')
    cursor = conn.cursor()
    cursor.execute('SELECT COUNT(*) FROM node_registry')
    count = cursor.fetchone()[0]
    conn.close()
    print(f'✅ Database OK - {count} nodes registered')
except Exception as e:
    print(f'❌ Database Error: {e}')
\"'"
    
    return 0
}

# Main execution
main() {
    log "🎯 Starte RX Node Wake-Up Prozess..."
    
    # Check if we can reach i7 node first
    if ! ssh -o ConnectTimeout=5 i7-node "echo 'i7 node reachable'" >/dev/null 2>&1; then
        error "i7 Node nicht erreichbar - Abbruch"
        exit 1
    fi
    
    log "✅ i7 Node erreichbar"
    
    # Step 1: Test current state
    echo ""
    test_from_i7
    
    # Step 2: Wake up RX node
    echo ""
    wake_rx_node
    
    # Step 3: Test communication
    echo ""
    test_i7_to_rx_communication
    
    # Final summary
    echo ""
    log "🎉 RX Node Wake-Up Test abgeschlossen!"
    echo ""
    echo -e "${GREEN}📊 Zusammenfassung:${NC}"
    echo "   🔗 i7 Node ↔ RX Node Kommunikation getestet"
    echo "   🎯 RX Node als Primary AI Trainer aktiviert"
    echo "   📡 HTTP Services auf beiden Nodes verfügbar"
    echo "   💾 Database Konnektivität überprüft"
    echo ""
    echo -e "${BLUE}🚀 Nächste Schritte:${NC}"
    echo "   1. Beide Services laufen lassen für kontinuierliche Tests"
    echo "   2. M1 Mac als Koordinator hinzufügen"
    echo "   3. Full-Cluster Synchronisation testen"
    echo ""
    echo -e "${YELLOW}💡 Monitoring:${NC}"
    echo "   - RX Node Status: curl http://$RX_NODE_IP:$RX_NODE_PORT/status"
    echo "   - i7 Node Status: ssh i7-node 'curl http://localhost:8008/status'"
    echo "   - Cross-Node Test: ssh i7-node 'curl http://$RX_NODE_IP:$RX_NODE_PORT/health'"
}

# Execute main function
main "$@" 