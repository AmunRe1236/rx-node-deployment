#!/bin/bash

# GENTLEMAN Tailscale Quick Connect
echo "🔗 GENTLEMAN Tailscale Connect"
echo "=============================="
echo ""

if [ $# -eq 0 ]; then
    echo "Verwendung: $0 <node-name>"
    echo ""
    echo "Verfügbare Nodes:"
    tailscale status | while read line; do
        if [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            node_name=$(echo "$line" | awk '{print $2}')
            node_ip=$(echo "$line" | awk '{print $1}')
            echo "  • $node_name ($node_ip)"
        fi
    done
    echo ""
    echo "Beispiele:"
    echo "  $0 archlinux      # Verbinde zur RX Node"
    echo "  $0 i7-laptop      # Verbinde zum I7 Laptop"
    exit 1
fi

node_name="$1"
node_ip=$(tailscale status | grep "$node_name" | awk '{print $1}')

if [ -n "$node_ip" ]; then
    echo "🔐 Verbinde zu $node_name ($node_ip)..."
    
    # Spezielle SSH-Konfigurationen für bekannte Nodes
    case "$node_name" in
        "archlinux"|"rx-node")
            ssh "amo9n11@$node_ip"
            ;;
        "i7-laptop"|"ubuntu")
            ssh "$node_ip"
            ;;
        *)
            ssh "$node_ip"
            ;;
    esac
else
    echo "❌ Node '$node_name' nicht gefunden"
    echo ""
    echo "Verfügbare Nodes:"
    tailscale status | while read line; do
        if [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            node_name=$(echo "$line" | awk '{print $2}')
            node_ip=$(echo "$line" | awk '{print $1}')
            echo "  • $node_name ($node_ip)"
        fi
    done
fi 

# GENTLEMAN Tailscale Quick Connect
echo "🔗 GENTLEMAN Tailscale Connect"
echo "=============================="
echo ""

if [ $# -eq 0 ]; then
    echo "Verwendung: $0 <node-name>"
    echo ""
    echo "Verfügbare Nodes:"
    tailscale status | while read line; do
        if [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            node_name=$(echo "$line" | awk '{print $2}')
            node_ip=$(echo "$line" | awk '{print $1}')
            echo "  • $node_name ($node_ip)"
        fi
    done
    echo ""
    echo "Beispiele:"
    echo "  $0 archlinux      # Verbinde zur RX Node"
    echo "  $0 i7-laptop      # Verbinde zum I7 Laptop"
    exit 1
fi

node_name="$1"
node_ip=$(tailscale status | grep "$node_name" | awk '{print $1}')

if [ -n "$node_ip" ]; then
    echo "🔐 Verbinde zu $node_name ($node_ip)..."
    
    # Spezielle SSH-Konfigurationen für bekannte Nodes
    case "$node_name" in
        "archlinux"|"rx-node")
            ssh "amo9n11@$node_ip"
            ;;
        "i7-laptop"|"ubuntu")
            ssh "$node_ip"
            ;;
        *)
            ssh "$node_ip"
            ;;
    esac
else
    echo "❌ Node '$node_name' nicht gefunden"
    echo ""
    echo "Verfügbare Nodes:"
    tailscale status | while read line; do
        if [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            node_name=$(echo "$line" | awk '{print $2}')
            node_ip=$(echo "$line" | awk '{print $1}')
            echo "  • $node_name ($node_ip)"
        fi
    done
fi 
 