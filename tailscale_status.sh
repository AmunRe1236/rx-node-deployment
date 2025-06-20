#!/bin/bash

# GENTLEMAN Tailscale Status
echo "🌐 GENTLEMAN Tailscale Network Status"
echo "======================================"
echo ""

if tailscale status >/dev/null 2>&1; then
    echo "✅ Tailscale: Verbunden"
    echo ""
    
    # Zeige alle Nodes
    echo "📱 Verfügbare Nodes:"
    tailscale status | while read line; do
        if [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            node_ip=$(echo "$line" | awk '{print $1}')
            node_name=$(echo "$line" | awk '{print $2}')
            node_user=$(echo "$line" | awk '{print $3}')
            node_os=$(echo "$line" | awk '{print $4}')
            echo "  • $node_name ($node_os): $node_ip"
        fi
    done
    
    echo ""
    echo "🎯 GENTLEMAN Services:"
    local_ip=$(tailscale ip -4)
    echo "  • M1 Handshake Server: http://$local_ip:8765"
    echo "  • SSH zu diesem Mac: ssh $(whoami)@$local_ip"
    echo "  • Deine Tailscale IP: $local_ip"
    
else
    echo "❌ Tailscale: Nicht verbunden"
    echo "Führe aus: sudo tailscale up"
fi 

# GENTLEMAN Tailscale Status
echo "🌐 GENTLEMAN Tailscale Network Status"
echo "======================================"
echo ""

if tailscale status >/dev/null 2>&1; then
    echo "✅ Tailscale: Verbunden"
    echo ""
    
    # Zeige alle Nodes
    echo "📱 Verfügbare Nodes:"
    tailscale status | while read line; do
        if [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            node_ip=$(echo "$line" | awk '{print $1}')
            node_name=$(echo "$line" | awk '{print $2}')
            node_user=$(echo "$line" | awk '{print $3}')
            node_os=$(echo "$line" | awk '{print $4}')
            echo "  • $node_name ($node_os): $node_ip"
        fi
    done
    
    echo ""
    echo "🎯 GENTLEMAN Services:"
    local_ip=$(tailscale ip -4)
    echo "  • M1 Handshake Server: http://$local_ip:8765"
    echo "  • SSH zu diesem Mac: ssh $(whoami)@$local_ip"
    echo "  • Deine Tailscale IP: $local_ip"
    
else
    echo "❌ Tailscale: Nicht verbunden"
    echo "Führe aus: sudo tailscale up"
fi 
 