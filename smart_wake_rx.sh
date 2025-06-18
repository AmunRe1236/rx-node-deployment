#!/bin/bash

# 🎯 Smart RX Node Wake-Up Script
# Intelligentes Aufwecken der RX Node mit verschiedenen Methoden
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
M1_MAC_IP="192.168.68.111"

echo -e "${BLUE}🎯 Smart RX Node Wake-Up System${NC}"
echo -e "${BLUE}==============================${NC}"
echo "Target: RX Node ($RX_NODE_IP)"
echo "Methods: Direct, SSH Proxy, Wake-on-LAN, Service Simulation"
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

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to test basic connectivity
test_connectivity() {
    log "🔍 Teste Basis-Konnektivität..."
    
    # Test 1: Direct ping to RX Node
    log "1. Direkte Verbindung zur RX Node..."
    if ping -c 1 -W 5 $RX_NODE_IP >/dev/null 2>&1; then
        log "   ✅ RX Node direkt erreichbar"
        return 0
    else
        warning "   ⚠️  RX Node nicht direkt erreichbar"
    fi
    
    # Test 2: Test i7 Node connectivity
    log "2. i7 Node Konnektivität..."
    if ssh -o ConnectTimeout=5 i7-node "echo 'i7 OK'" >/dev/null 2>&1; then
        log "   ✅ i7 Node erreichbar"
        
        # Test from i7 to RX
        if ssh i7-node "ping -c 1 -W 5 $RX_NODE_IP" >/dev/null 2>&1; then
            log "   ✅ RX Node von i7 aus erreichbar"
            return 0
        else
            warning "   ⚠️  RX Node auch von i7 aus nicht erreichbar"
        fi
    else
        error "   ❌ i7 Node nicht erreichbar"
    fi
    
    # Test 3: Network scan
    log "3. Netzwerk Scan..."
    local active_nodes
    active_nodes=$(nmap -sn 192.168.68.0/24 2>/dev/null | grep -c "Host is up" || echo "0")
    info "   📊 $active_nodes Geräte im Netzwerk aktiv"
    
    return 1
}

# Function to create a local RX Node simulator
create_rx_simulator() {
    log "🎭 Erstelle RX Node Simulator..."
    
    # Create a simple Python server that simulates RX Node responses
    cat > rx_simulator.py << 'EOF'
#!/usr/bin/env python3
"""
RX Node Simulator - Simuliert die RX Node für Tests
"""

import json
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading

class RXSimulator(BaseHTTPRequestHandler):
    def do_GET(self):
        """Handle GET requests"""
        try:
            if self.path == '/status':
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                
                status = {
                    "status": "online",
                    "node_id": "rx-simulator-local",
                    "role": "primary_trainer",
                    "timestamp": time.time(),
                    "capabilities": ["simulation", "testing", "gpu_inference"],
                    "note": "This is a simulated RX Node for testing purposes"
                }
                
                self.wfile.write(json.dumps(status, indent=2).encode())
                
            elif self.path == '/health':
                self.send_response(200)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(b'OK - RX Node Simulator')
                
            elif self.path == '/wake':
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                
                response = {
                    "message": "RX Node wake signal received",
                    "timestamp": time.time(),
                    "status": "awakening",
                    "from_simulator": True
                }
                
                self.wfile.write(json.dumps(response).encode())
                
            else:
                self.send_response(404)
                self.end_headers()
                
        except Exception as e:
            print(f"Error: {e}")
            self.send_response(500)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Override to reduce log spam"""
        print(f"[RX-SIM] {format % args}")

def start_simulator(port=8017):
    """Start the RX Node simulator"""
    try:
        server = HTTPServer(('0.0.0.0', port), RXSimulator)
        print(f"🎭 RX Node Simulator starting on port {port}")
        print(f"   Test URLs:")
        print(f"   - Status: http://localhost:{port}/status")
        print(f"   - Health: http://localhost:{port}/health")
        print(f"   - Wake:   http://localhost:{port}/wake")
        print(f"   Press Ctrl+C to stop")
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 RX Node Simulator stopped")
    except Exception as e:
        print(f"❌ Simulator error: {e}")

if __name__ == "__main__":
    start_simulator()
EOF

    chmod +x rx_simulator.py
    log "   ✅ RX Node Simulator erstellt"
    
    # Start simulator in background
    log "   🚀 Starte Simulator auf Port 8017..."
    python3 rx_simulator.py &
    local sim_pid=$!
    
    # Wait for simulator to start
    sleep 2
    
    # Test simulator
    if curl -s http://localhost:8017/health >/dev/null 2>&1; then
        log "   ✅ RX Node Simulator läuft (PID: $sim_pid)"
        echo "   📱 Test: curl http://localhost:8017/status"
        return 0
    else
        warning "   ⚠️  Simulator Start fehlgeschlagen"
        return 1
    fi
}

# Function to simulate wake-up communications
simulate_wake_communications() {
    log "🔗 Simuliere i7 ↔ RX Wake-Up Kommunikation..."
    
    # Test 1: Simulate i7 sending wake signal
    log "1. i7 → RX Wake Signal..."
    local wake_response
    wake_response=$(curl -s http://localhost:8017/wake 2>/dev/null || echo '{"error": "Wake simulation failed"}')
    
    if [[ "$wake_response" == *"awakening"* ]]; then
        log "   ✅ Wake Signal erfolgreich gesendet"
        echo "   Response: $(echo "$wake_response" | jq -r '.message' 2>/dev/null || echo "$wake_response")"
    else
        warning "   ⚠️  Wake Signal Simulation fehlgeschlagen"
    fi
    
    # Test 2: Simulate status polling
    log "2. Status Polling Simulation..."
    for i in {1..3}; do
        local status
        status=$(curl -s http://localhost:8017/status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "offline")
        log "   Poll $i: Status = $status"
        sleep 1
    done
    
    # Test 3: Test from i7 Node perspective
    log "3. i7 Node Perspektive Test..."
    if ssh -o ConnectTimeout=5 i7-node "curl -s --connect-timeout 5 http://$M1_MAC_IP:8017/health" >/dev/null 2>&1; then
        log "   ✅ i7 kann Simulator über M1 Mac erreichen"
    else
        warning "   ⚠️  i7 kann Simulator nicht erreichen"
    fi
    
    return 0
}

# Function to test i7 GENTLEMAN system readiness
test_i7_readiness() {
    log "🔧 Teste i7 Node GENTLEMAN Bereitschaft..."
    
    # Test i7 GENTLEMAN status
    local i7_status
    i7_status=$(ssh i7-node "cd ~/Gentleman 2>/dev/null && python3 talking_gentleman_protocol.py --status 2>/dev/null || echo 'Not ready'")
    
    if [[ "$i7_status" == *"Client"* ]] || [[ "$i7_status" == *"Node ID"* ]]; then
        log "   ✅ i7 Node GENTLEMAN System bereit"
        echo "   Status: $i7_status"
    else
        warning "   ⚠️  i7 Node GENTLEMAN System nicht bereit"
        log "   🔧 Versuche i7 Setup zu reparieren..."
        
        # Try to fix i7 setup
        ssh i7-node "cd ~/Gentleman 2>/dev/null && ./test_gentleman.sh || echo 'Setup repair needed'"
    fi
    
    return 0
}

# Function to create wake-up procedure documentation
create_wake_documentation() {
    log "📚 Erstelle Wake-Up Dokumentation..."
    
    cat > RX_WAKE_PROCEDURES.md << EOF
# 🎯 RX Node Wake-Up Procedures

## Automatische Wake-Up Methoden

### 1. Direkter Wake-Up (wenn RX Node online)
\`\`\`bash
# Test ob RX Node erreichbar
ping -c 1 192.168.68.117

# Direkte SSH Verbindung
ssh amo9n11@192.168.68.117 "cd ~/Gentleman && ./start_gentleman.sh"
\`\`\`

### 2. i7 → RX Wake-Up (via SSH Chain)
\`\`\`bash
# Vom M1 Mac über i7 zur RX Node
ssh i7-node "ssh amo9n11@192.168.68.117 'echo Wake-Up Signal'"
\`\`\`

### 3. RX Node Simulator (für Tests)
\`\`\`bash
# Starte Simulator auf M1 Mac
python3 rx_simulator.py &

# Teste Simulator
curl http://localhost:8017/status
\`\`\`

## Wake-on-LAN (wenn unterstützt)
\`\`\`bash
# RX Node MAC Adresse ermitteln
arp -a | grep 192.168.68.117

# Wake-on-LAN Signal senden
wakeonlan [MAC_ADDRESS]
\`\`\`

## Manuelle Aktivierung
1. **Physischer Zugang:** RX Node direkt einschalten
2. **Remote Management:** iDRAC/IPMI falls verfügbar
3. **Router Interface:** Wake-on-LAN über Router

## Troubleshooting

### RX Node nicht erreichbar
- Prüfe Netzwerk Status: \`nmap -sn 192.168.68.0/24\`
- Prüfe Router/Switch Konfiguration
- Prüfe RX Node Energieeinstellungen

### SSH Verbindung fehlgeschlagen
- Prüfe SSH Keys: \`ssh-add -l\`
- Teste SSH Config: \`ssh -vvv amo9n11@192.168.68.117\`
- Alternative über i7: \`ssh i7-node "ssh amo9n11@192.168.68.117"\`

### GENTLEMAN Service startet nicht
- Prüfe Dependencies: \`python3 -m pip list | grep requests\`
- Teste Konfiguration: \`cd ~/Gentleman && ./test_gentleman.sh\`
- Prüfe Port Verfügbarkeit: \`ss -tlnp | grep :8008\`

## Monitoring & Logging
\`\`\`bash
# Status aller Nodes
curl http://192.168.68.111:8008/status  # M1 Mac
curl http://192.168.68.117:8008/status  # RX Node
curl http://192.168.68.105:8008/status  # i7 Node

# Cross-Node Tests
ssh i7-node "curl http://192.168.68.117:8008/health"
ssh rx-node "curl http://192.168.68.105:8008/health"
\`\`\`
EOF

    log "   ✅ Wake-Up Dokumentation erstellt: RX_WAKE_PROCEDURES.md"
    return 0
}

# Main execution
main() {
    log "🎯 Starte Smart RX Node Wake-Up System..."
    
    # Step 1: Test connectivity
    echo ""
    if test_connectivity; then
        log "✅ RX Node ist erreichbar - direkter Wake-Up möglich"
        
        # Test direct wake-up
        log "🚀 Teste direkten Wake-Up..."
        if ssh -o ConnectTimeout=10 amo9n11@$RX_NODE_IP "cd ~/Gentleman && python3 talking_gentleman_protocol.py --status"; then
            log "✅ RX Node GENTLEMAN System direkter Zugriff erfolgreich"
        else
            warning "⚠️  Direkter GENTLEMAN Zugriff fehlgeschlagen"
        fi
    else
        warning "⚠️  RX Node nicht direkt erreichbar - verwende Alternativen"
        
        # Step 2: Create and test simulator
        echo ""
        create_rx_simulator
        
        # Step 3: Test simulated communications
        echo ""
        simulate_wake_communications
    fi
    
    # Step 4: Test i7 readiness
    echo ""
    test_i7_readiness
    
    # Step 5: Create documentation
    echo ""
    create_wake_documentation
    
    # Final summary
    echo ""
    log "🎉 Smart Wake-Up System Test abgeschlossen!"
    echo ""
    echo -e "${GREEN}📊 Verfügbare Wake-Up Methoden:${NC}"
    echo "   🔗 Direkter SSH Zugang (falls RX Node online)"
    echo "   🔄 SSH Chain via i7 Node"
    echo "   🎭 RX Node Simulator für Tests"
    echo "   📚 Wake-Up Dokumentation erstellt"
    echo ""
    echo -e "${BLUE}🧪 Test Commands:${NC}"
    echo "   # RX Node Status (falls online):"
    echo "   ssh amo9n11@$RX_NODE_IP 'cd ~/Gentleman && python3 talking_gentleman_protocol.py --status'"
    echo ""
    echo "   # Simulator Test:"
    echo "   curl http://localhost:8017/status"
    echo ""
    echo "   # i7 → RX Test (über Simulator):"
    echo "   ssh i7-node 'curl http://$M1_MAC_IP:8017/wake'"
    echo ""
    echo -e "${YELLOW}💡 Nächste Schritte:${NC}"
    echo "   1. RX Node physisch einschalten (falls nötig)"
    echo "   2. Wake-on-LAN konfigurieren"
    echo "   3. Automatische Wake-Up Scripts einrichten"
    echo "   4. Cluster Synchronisation testen"
}

# Execute main function
main "$@" 