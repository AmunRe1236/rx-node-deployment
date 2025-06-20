#!/bin/bash

echo "🚀 GENTLEMAN Mobile Access Setup"
echo "================================"
echo ""

# Aktuelle Konfiguration anzeigen
PUBLIC_IP=$(curl -s ifconfig.me)
GATEWAY=$(route -n get default | grep gateway | awk '{print $2}')

echo "📊 Aktuelle Konfiguration:"
echo "- M1 Mac IP: 192.168.68.105"
echo "- Öffentliche IP: $PUBLIC_IP"
echo "- Router Gateway: $GATEWAY"
echo ""

# Service Status prüfen
echo "🔍 Service Status:"
echo -n "- Handshake Server (8765): "
nc -z localhost 8765 && echo "✅ Läuft" || echo "❌ Offline"

echo -n "- Git Daemon (9418): "
nc -z localhost 9418 && echo "✅ Läuft" || echo "❌ Offline"

echo -n "- Gitea Docker (3010): "
nc -z localhost 3010 && echo "✅ Läuft" || echo "❌ Offline"
echo ""

# Menü anzeigen
echo "📋 Wähle eine Option:"
echo "1) ngrok Tunnel (Schnelltest)"
echo "2) Router Port-Forwarding Anleitung"
echo "3) Tailscale VPN Setup"
echo "4) Alle Services prüfen"
echo "5) Test externe Erreichbarkeit"
echo ""

read -p "Deine Wahl (1-5): " choice

case $choice in
    1)
        echo ""
        echo "🚀 ngrok Setup:"
        echo "1. Registriere dich kostenlos: https://ngrok.com/signup"
        echo "2. Hole deinen Authtoken aus dem Dashboard"
        echo "3. Führe aus: ngrok config add-authtoken [DEIN_TOKEN]"
        echo "4. Starte Tunnel: ngrok http 8765"
        echo ""
        echo "Soll ich den Browser öffnen? (y/n)"
        read -p "> " open_browser
        if [[ $open_browser == "y" ]]; then
            open https://ngrok.com/signup
        fi
        
        echo ""
        echo "Hast du bereits einen ngrok Account und Authtoken? (y/n)"
        read -p "> " has_token
        if [[ $has_token == "y" ]]; then
            read -p "Authtoken eingeben: " authtoken
            ngrok config add-authtoken $authtoken
            echo ""
            echo "🚀 Starte ngrok Tunnel für Handshake Service..."
            echo "Drücke Ctrl+C zum Beenden"
            ngrok http 8765
        fi
        ;;
        
    2)
        echo ""
        echo "🔧 Router Port-Forwarding Setup:"
        echo ""
        echo "1. Öffne Router Admin Panel: http://$GATEWAY"
        echo "2. Suche nach 'Port-Forwarding' oder 'Virtual Server'"
        echo "3. Konfiguriere folgende Weiterleitungen:"
        echo ""
        echo "   Service: Handshake"
        echo "   Extern: 8765"
        echo "   Intern: 192.168.68.105:8765"
        echo "   Protokoll: TCP"
        echo ""
        echo "   Service: Git Daemon"
        echo "   Extern: 9418"
        echo "   Intern: 192.168.68.105:9418"
        echo "   Protokoll: TCP"
        echo ""
        echo "   Service: Gitea"
        echo "   Extern: 3010"
        echo "   Intern: 192.168.68.105:3010"
        echo "   Protokoll: TCP"
        echo ""
        echo "Soll ich den Router Admin Panel öffnen? (y/n)"
        read -p "> " open_router
        if [[ $open_router == "y" ]]; then
            open http://$GATEWAY
        fi
        ;;
        
    3)
        echo ""
        echo "🛡️ Tailscale VPN Setup:"
        echo ""
        if ! command -v tailscale &> /dev/null; then
            echo "Installiere Tailscale..."
            brew install tailscale
        else
            echo "✅ Tailscale bereits installiert"
        fi
        
        echo ""
        echo "Starte Tailscale..."
        sudo tailscale up
        
        echo ""
        echo "✅ Tailscale IP:"
        tailscale ip -4
        
        echo ""
        echo "🎯 Services sind jetzt über Tailscale IP erreichbar:"
        TAILSCALE_IP=$(tailscale ip -4)
        echo "- Handshake: http://$TAILSCALE_IP:8765/health"
        echo "- Gitea: http://$TAILSCALE_IP:3010"
        echo "- Git: git://$TAILSCALE_IP:9418/Gentleman"
        ;;
        
    4)
        echo ""
        echo "🔍 Detaillierte Service Prüfung:"
        ./mobile_access_test.sh
        ;;
        
    5)
        echo ""
        echo "🎯 Teste externe Erreichbarkeit:"
        echo "Teste Handshake Service von extern..."
        curl -m 5 "http://$PUBLIC_IP:8765/health" 2>/dev/null && echo "✅ Extern erreichbar!" || echo "❌ Nicht erreichbar - Port-Forwarding benötigt"
        echo ""
        echo "Teste Gitea von extern..."
        curl -m 5 "http://$PUBLIC_IP:3010" 2>/dev/null && echo "✅ Gitea extern erreichbar!" || echo "❌ Gitea nicht erreichbar"
        ;;
        
    *)
        echo "Ungültige Auswahl"
        ;;
esac

echo ""
echo "📱 Mobile Test URLs (nach Setup):"
echo "- ngrok: Wird dynamisch generiert"
echo "- Port-Forwarding: http://$PUBLIC_IP:8765/health"
echo "- Tailscale: http://[TAILSCALE-IP]:8765/health"
echo ""
echo "📖 Vollständige Anleitung: cat GENTLEMAN_MOBILE_ACCESS_GUIDE.md" 