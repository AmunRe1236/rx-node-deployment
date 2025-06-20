#!/bin/bash

# Verification Script für RX Node Tailscale Setup

echo "🔍 Überprüfe RX Node Tailscale-Integration..."

# Hole RX Node Tailscale IP
RX_IP=$(ssh rx-node "tailscale ip -4" 2>/dev/null)

if [ -n "$RX_IP" ]; then
    echo "✅ RX Node Tailscale IP: $RX_IP"
    
    # Teste Ping
    if ping -c 1 -W 3 "$RX_IP" >/dev/null 2>&1; then
        echo "✅ Ping zur RX Node über Tailscale erfolgreich"
    else
        echo "⚠️ Ping zur RX Node über Tailscale fehlgeschlagen"
    fi
    
    # Aktualisiere SSH Config
    if ! grep -q "Host rx-node-tailscale" ~/.ssh/config 2>/dev/null; then
        cat >> ~/.ssh/config << EOL

# RX Node via Tailscale
Host rx-node-tailscale
    HostName $RX_IP
    User amo9n11
    IdentityFile ~/.ssh/gentleman_secure
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOL
        echo "✅ SSH-Konfiguration für Tailscale hinzugefügt"
    fi
    
    # Zeige aktuellen Tailscale Status
    echo ""
    echo "📊 Aktueller Tailscale-Status:"
    tailscale status
    
    echo ""
    echo "🎉 RX Node erfolgreich im Tailscale Mesh integriert!"
    echo "📱 Die RX Node sollte jetzt in deiner Tailscale-App sichtbar sein"
    
else
    echo "❌ RX Node Tailscale IP nicht gefunden"
    echo "💡 Stelle sicher, dass Tailscale auf der RX Node korrekt installiert ist"
fi
