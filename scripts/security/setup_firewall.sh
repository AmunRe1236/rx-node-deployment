#!/bin/bash

# 🔥 GENTLEMAN FIREWALL SETUP
set -e

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux iptables
    echo "🔥 Konfiguriere Linux Firewall (iptables)..."
    
    # Flush existing rules
    sudo iptables -F
    sudo iptables -X
    sudo iptables -t nat -F
    sudo iptables -t nat -X
    
    # Default policies
    sudo iptables -P INPUT DROP
    sudo iptables -P FORWARD DROP
    sudo iptables -P OUTPUT ACCEPT
    
    # Allow loopback
    sudo iptables -A INPUT -i lo -j ACCEPT
    
    # Allow established connections
    sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Allow Nebula VPN
    sudo iptables -A INPUT -i nebula1 -j ACCEPT
    sudo iptables -A INPUT -p udp --dport 4242 -j ACCEPT
    
    # Allow SSH (nur von lokalen Netzwerken)
    sudo iptables -A INPUT -p tcp --dport 22 -s 192.168.0.0/16 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 22 -s 10.0.0.0/8 -j ACCEPT
    
    # Block everything else
    sudo iptables -A INPUT -j DROP
    
    # Save rules
    if command -v iptables-save >/dev/null; then
        sudo iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS pfctl
    echo "🔥 Konfiguriere macOS Firewall (pfctl)..."
    
    # Create pfctl rules
    sudo tee /etc/pf.anchors/gentleman << 'PFEOF'
# Gentleman AI Firewall Rules
scrub-anchor "com.apple/*"
nat-anchor "com.apple/*"
rdr-anchor "com.apple/*"
dummynet-anchor "com.apple/*"
anchor "com.apple/*"
load anchor "com.apple" from "/etc/pf.anchors/com.apple"

# Allow loopback
pass on lo0

# Allow Nebula VPN
pass in on utun100
pass out on utun100

# Allow established connections
pass in proto tcp from any to any port {80, 443, 8001, 8002, 8003, 8004, 8005} keep state
pass out proto tcp from any to any port {80, 443} keep state
pass out proto udp from any to any port {53, 4242} keep state

# Block everything else
block log all
PFEOF
    
    # Load rules
    sudo pfctl -f /etc/pf.anchors/gentleman
    sudo pfctl -e
fi

echo "✅ Firewall konfiguriert"
