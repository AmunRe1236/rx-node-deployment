#!/bin/bash

# 🌐 M1 Mac Coordinator with SSH Tunnel Support
# Erweiterte Version mit i7 Node SSH Port Forwarding

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🌐 M1 MAC COORDINATOR + SSH TUNNEL SUPPORT                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# Node Definitionen
M1_MAC_IP="192.168.68.111"
I7_NODE_IP="192.168.68.105"
RX_NODE_IP="192.168.68.117"
GENTLEMAN_PORT="8008"
I7_TUNNEL_PORT="8105"

echo "🔧 M1 Mac Coordinator mit SSH Tunnel Support..."
echo ""

# SSH Tunnel zu i7 Node starten
start_i7_tunnel() {
    echo "🚇 Starte SSH Tunnel zu i7 Node..."
    
    # Prüfe ob Tunnel bereits läuft
    if lsof -i :$I7_TUNNEL_PORT >/dev/null 2>&1; then
        echo "✅ SSH Tunnel bereits aktiv auf Port $I7_TUNNEL_PORT"
        return 0
    fi
    
    # Starte SSH Tunnel im Hintergrund
    echo "🔗 Erstelle SSH Port Forwarding: localhost:$I7_TUNNEL_PORT → i7:$GENTLEMAN_PORT"
    ssh -i ~/.ssh/gentleman_key -L $I7_TUNNEL_PORT:localhost:$GENTLEMAN_PORT -N -f amonbaumgartner@$I7_NODE_IP 2>/dev/null
    
    # Warte und prüfe
    sleep 2
    if lsof -i :$I7_TUNNEL_PORT >/dev/null 2>&1; then
        echo "✅ SSH Tunnel erfolgreich gestartet"
        return 0
    else
        echo "❌ SSH Tunnel Start fehlgeschlagen"
        return 1
    fi
}

# SSH Tunnel stoppen
stop_i7_tunnel() {
    echo "🛑 Stoppe SSH Tunnel zu i7 Node..."
    pkill -f "ssh.*$I7_TUNNEL_PORT:localhost:$GENTLEMAN_PORT" 2>/dev/null
    sleep 1
    echo "✅ SSH Tunnel gestoppt"
}

# Node Discovery mit SSH Tunnel Support
discover_nodes_with_tunnel() {
    echo "🔍 Node Discovery mit SSH Tunnel Support:"
    echo ""
    
    local nodes_found=0
    
    # Test i7 Node via SSH Tunnel
    echo "🚇 Teste i7 Node via SSH Tunnel (localhost:$I7_TUNNEL_PORT):"
    if curl -s --connect-timeout 3 "http://localhost:$I7_TUNNEL_PORT/status" >/dev/null 2>&1; then
        echo "✅ i7 Node erreichbar via SSH Tunnel"
        local i7_info=$(curl -s "http://localhost:$I7_TUNNEL_PORT/status" 2>/dev/null)
        echo "   📋 Details: $i7_info"
        nodes_found=$((nodes_found + 1))
    else
        echo "❌ i7 Node nicht erreichbar via SSH Tunnel"
    fi
    echo ""
    
    # Test RX Node direkt
    echo "📡 Teste RX Node direkt ($RX_NODE_IP:$GENTLEMAN_PORT):"
    if curl -s --connect-timeout 3 "http://$RX_NODE_IP:$GENTLEMAN_PORT/status" >/dev/null 2>&1; then
        echo "✅ RX Node erreichbar direkt"
        local rx_info=$(curl -s "http://$RX_NODE_IP:$GENTLEMAN_PORT/status" 2>/dev/null)
        echo "   📋 Details: $rx_info"
        nodes_found=$((nodes_found + 1))
    else
        echo "❌ RX Node nicht erreichbar"
    fi
    echo ""
    
    echo "📊 Discovery Ergebnis: $nodes_found/2 Nodes erreichbar"
    return $nodes_found
}

# Multi-Node Status mit Tunnel Support
get_multi_node_status() {
    echo "📊 Multi-Node Status Check:"
    echo ""
    
    # M1 Mac (lokal)
    echo "🖥️ M1 Mac (localhost:$GENTLEMAN_PORT):"
    local m1_status=$(curl -s --connect-timeout 3 "http://localhost:$GENTLEMAN_PORT/status" 2>/dev/null)
    if [ ! -z "$m1_status" ]; then
        echo "✅ $m1_status"
    else
        echo "❌ Keine Response"
    fi
    echo ""
    
    # i7 Node (via SSH Tunnel)
    echo "💻 i7 Node (via SSH Tunnel localhost:$I7_TUNNEL_PORT):"
    local i7_status=$(curl -s --connect-timeout 3 "http://localhost:$I7_TUNNEL_PORT/status" 2>/dev/null)
    if [ ! -z "$i7_status" ]; then
        echo "✅ $i7_status"
    else
        echo "❌ Keine Response"
    fi
    echo ""
    
    # RX Node (direkt)
    echo "🚀 RX Node (direkt $RX_NODE_IP:$GENTLEMAN_PORT):"
    local rx_status=$(curl -s --connect-timeout 3 "http://$RX_NODE_IP:$GENTLEMAN_PORT/status" 2>/dev/null)
    if [ ! -z "$rx_status" ]; then
        echo "✅ $rx_status"
    else
        echo "❌ Keine Response"
    fi
    echo ""
}

# Cross-Node Kommunikation Test
test_cross_node_communication() {
    echo "🌐 Cross-Node Kommunikation Test:"
    echo ""
    
    # Test: M1 → i7 via SSH Tunnel
    echo "📡 M1 Mac → i7 Node (via SSH Tunnel):"
    if curl -s --connect-timeout 3 "http://localhost:$I7_TUNNEL_PORT/status" >/dev/null; then
        echo "✅ Kommunikation erfolgreich"
    else
        echo "❌ Kommunikation fehlgeschlagen"
    fi
    
    # Test: M1 → RX direkt
    echo "📡 M1 Mac → RX Node (direkt):"
    if curl -s --connect-timeout 3 "http://$RX_NODE_IP:$GENTLEMAN_PORT/status" >/dev/null; then
        echo "✅ Kommunikation erfolgreich"
    else
        echo "❌ Kommunikation fehlgeschlagen"
    fi
    
    # Test: Über SSH zu anderen Nodes
    echo "📡 SSH-basierte Tests:"
    
    # SSH zu i7 und teste RX Node von dort
    echo "   i7 → RX Node:"
    if ssh -i ~/.ssh/gentleman_key -o ConnectTimeout=5 amonbaumgartner@$I7_NODE_IP "curl -s --connect-timeout 3 http://$RX_NODE_IP:$GENTLEMAN_PORT/status" >/dev/null 2>&1; then
        echo "✅ i7 kann RX Node erreichen"
    else
        echo "❌ i7 kann RX Node nicht erreichen"
    fi
    
    # SSH zu RX und teste verfügbare Services
    echo "   RX → Services:"
    if ssh -i ~/.ssh/gentleman_key -o ConnectTimeout=5 amo9n11@$RX_NODE_IP "curl -s --connect-timeout 3 http://localhost:$GENTLEMAN_PORT/status" >/dev/null 2>&1; then
        echo "✅ RX lokale Services funktional"
    else
        echo "❌ RX lokale Services nicht erreichbar"
    fi
    
    echo ""
}

# Management Kommandos anzeigen
show_management_commands() {
    echo "📋 Verfügbare Management-Kommandos:"
    echo ""
    echo "🔗 Node Status (mit SSH Tunnel):"
    echo "   curl -s http://localhost:$GENTLEMAN_PORT/status          # M1 Mac"
    echo "   curl -s http://localhost:$I7_TUNNEL_PORT/status         # i7 Node (via SSH Tunnel)"
    echo "   curl -s http://$RX_NODE_IP:$GENTLEMAN_PORT/status       # RX Node"
    echo ""
    echo "🚇 SSH Tunnel Management:"
    echo "   ./m1_i7_tunnel.sh                                       # Manueller SSH Tunnel"
    echo "   pkill -f 'ssh.*$I7_TUNNEL_PORT:localhost:$GENTLEMAN_PORT'  # Tunnel stoppen"
    echo ""
    echo "📡 Remote Node Management:"
    echo "   ssh -i ~/.ssh/gentleman_key amonbaumgartner@$I7_NODE_IP 'curl http://localhost:$GENTLEMAN_PORT/status'"
    echo "   ssh -i ~/.ssh/gentleman_key amo9n11@$RX_NODE_IP 'curl http://localhost:$GENTLEMAN_PORT/status'"
    echo ""
    echo "🔄 Service Management:"
    echo "   ssh -i ~/.ssh/gentleman_key amonbaumgartner@$I7_NODE_IP 'ps aux | grep talking_gentleman'"
    echo "   ssh -i ~/.ssh/gentleman_key amo9n11@$RX_NODE_IP 'ps aux | grep talking_gentleman'"
}

# Hauptfunktion
main() {
    echo "🚀 Starte M1 Mac Coordinator mit SSH Tunnel Support..."
    echo ""
    
    case "${1:-status}" in
        "start")
            echo "🔧 Starte vollständige Coordinator-Konfiguration..."
            echo ""
            
            # 1. SSH Tunnel zu i7 starten
            if start_i7_tunnel; then
                echo ""
                
                # 2. Node Discovery
                discover_nodes_with_tunnel
                echo ""
                
                # 3. Multi-Node Status
                get_multi_node_status
                echo ""
                
                # 4. Cross-Node Tests
                test_cross_node_communication
                echo ""
                
                echo "🎉 M1 Mac Coordinator mit SSH Tunnel erfolgreich gestartet!"
            else
                echo "❌ SSH Tunnel Setup fehlgeschlagen"
                exit 1
            fi
            ;;
            
        "stop")
            echo "🛑 Stoppe M1 Mac Coordinator..."
            stop_i7_tunnel
            echo "✅ Coordinator gestoppt"
            ;;
            
        "status")
            echo "📊 M1 Mac Coordinator Status..."
            echo ""
            
            # Prüfe SSH Tunnel Status
            if lsof -i :$I7_TUNNEL_PORT >/dev/null 2>&1; then
                echo "✅ SSH Tunnel zu i7 Node: AKTIV (Port $I7_TUNNEL_PORT)"
            else
                echo "❌ SSH Tunnel zu i7 Node: INAKTIV"
            fi
            echo ""
            
            # Node Discovery
            discover_nodes_with_tunnel
            echo ""
            
            # Multi-Node Status
            get_multi_node_status
            ;;
            
        "test")
            echo "🧪 M1 Mac Coordinator Tests..."
            echo ""
            
            # Starte SSH Tunnel falls nötig
            start_i7_tunnel
            echo ""
            
            # Cross-Node Tests
            test_cross_node_communication
            ;;
            
        *)
            echo "📋 M1 Mac Coordinator mit SSH Tunnel Support"
            echo ""
            echo "Verwendung: $0 [start|stop|status|test]"
            echo ""
            echo "  start   - Starte Coordinator mit SSH Tunnel"
            echo "  stop    - Stoppe Coordinator und SSH Tunnel"
            echo "  status  - Zeige aktuellen Status"
            echo "  test    - Führe Cross-Node Tests durch"
            echo ""
            ;;
    esac
    
    show_management_commands
    
    echo ""
    echo "🎯 M1 Mac Coordinator mit SSH Tunnel Support aktiv!"
}

# Script ausführen
main "$@" 