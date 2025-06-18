#!/bin/bash

# 🔥 i7 Node Firewall Solution - HTTP Connectivity Fix
# Löst macOS Firewall-Probleme für GENTLEMAN Protocol externe Erreichbarkeit

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🔥 I7 NODE FIREWALL SOLUTION                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# Configuration
PYTHON_PATH="/usr/local/Cellar/python@3.13/3.13.3_1/Frameworks/Python.framework/Versions/3.13/Resources/Python.app/Contents/MacOS/Python"
GENTLEMAN_PORT="8008"
BACKUP_DIR="$HOME/.firewall_backup"

echo "🔧 Implementiere i7 Node Firewall-Lösung..."
echo ""

# Backup aktueller Firewall-Zustand
backup_firewall_state() {
    echo "💾 Backup aktueller Firewall-Konfiguration..."
    mkdir -p "$BACKUP_DIR"
    
    # Firewall Status sichern
    /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate > "$BACKUP_DIR/firewall_state.txt" 2>/dev/null
    /usr/libexec/ApplicationFirewall/socketfilterfw --listapps > "$BACKUP_DIR/firewall_apps.txt" 2>/dev/null
    
    echo "✅ Backup erstellt in: $BACKUP_DIR"
}

# Python für Firewall freigeben
configure_python_firewall() {
    echo "🐍 Konfiguriere Python für externe HTTP-Verbindungen..."
    
    # Alle Python-Varianten zur Firewall hinzufügen
    echo "📝 Füge Python-Binaries zur Firewall hinzu:"
    
    # Hauptpython-Binary
    echo "   - Hauptpython: $PYTHON_PATH"
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$PYTHON_PATH" 2>/dev/null
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock "$PYTHON_PATH" 2>/dev/null
    
    # Alternative Python-Pfade
    local python_paths=(
        "/usr/local/bin/python3"
        "/usr/bin/python3"
        "/usr/local/Cellar/python@3.13/3.13.3_1/bin/python3"
        "$(which python3)"
    )
    
    for path in "${python_paths[@]}"; do
        if [ -f "$path" ]; then
            echo "   - Python: $path"
            sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$path" 2>/dev/null
            sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock "$path" 2>/dev/null
        fi
    done
    
    echo "✅ Python Firewall-Freigaben konfiguriert"
}

# Port-spezifische Firewall-Konfiguration
configure_port_firewall() {
    echo "🌐 Konfiguriere Port-spezifische Firewall-Regeln..."
    
    # Da macOS Application Firewall keine direkten Port-Regeln unterstützt,
    # konfigurieren wir über pfctl (Packet Filter)
    
    echo "📝 Erstelle temporäre pfctl-Regel für Port $GENTLEMAN_PORT:"
    
    # Temporäre pfctl-Regel (falls pfctl aktiv ist)
    if pfctl -s info >/dev/null 2>&1; then
        echo "   - pfctl ist aktiv, erstelle Regel..."
        # Einfache Regel um eingehende Verbindungen auf Port 8008 zu erlauben
        echo "pass in proto tcp from any to any port $GENTLEMAN_PORT" | sudo pfctl -f - 2>/dev/null || true
    else
        echo "   - pfctl nicht aktiv (normal bei macOS Application Firewall)"
    fi
    
    echo "✅ Port-Konfiguration abgeschlossen"
}

# Firewall-Status testen
test_firewall_configuration() {
    echo "🧪 Teste Firewall-Konfiguration..."
    
    # Lokaler HTTP-Test
    echo "📡 Lokaler HTTP-Test:"
    if curl -s --connect-timeout 3 "http://localhost:$GENTLEMAN_PORT/status" >/dev/null; then
        echo "✅ Lokal erreichbar: http://localhost:$GENTLEMAN_PORT"
    else
        echo "❌ Lokal nicht erreichbar"
        return 1
    fi
    
    # Netzwerk-Interface Test
    echo "📡 Netzwerk-Interface Test:"
    local my_ip=$(ifconfig | grep 'inet 192.168.68.' | awk '{print $2}' | head -1)
    if [ ! -z "$my_ip" ]; then
        echo "   - Teste eigene IP: $my_ip:$GENTLEMAN_PORT"
        if curl -s --connect-timeout 3 "http://$my_ip:$GENTLEMAN_PORT/status" >/dev/null; then
            echo "✅ Über eigene IP erreichbar: http://$my_ip:$GENTLEMAN_PORT"
            return 0
        else
            echo "❌ Über eigene IP nicht erreichbar"
        fi
    fi
    
    return 1
}

# Alternative Lösung: SSH Tunnel Setup
setup_ssh_tunnel_alternative() {
    echo "🚇 Setup SSH Tunnel Alternative..."
    
    cat > "$HOME/Gentleman/ssh_tunnel_to_i7.sh" << 'EOF'
#!/bin/bash
# SSH Tunnel zum i7 Node für M1 Mac
# Verwendung vom M1 Mac: ssh -L 8105:localhost:8008 amonbaumgartner@192.168.68.105
# Dann: curl http://localhost:8105/status

echo "🚇 SSH Tunnel zu i7 Node"
echo "Port-Weiterleitung: localhost:8105 → i7:8008"
echo "Verwende: ssh -L 8105:localhost:8008 amonbaumgartner@192.168.68.105"
echo "Dann: curl http://localhost:8105/status"
EOF
    
    chmod +x "$HOME/Gentleman/ssh_tunnel_to_i7.sh"
    echo "✅ SSH Tunnel Script erstellt: ~/Gentleman/ssh_tunnel_to_i7.sh"
}

# Service Neustart mit korrekter Konfiguration
restart_gentleman_service() {
    echo "🔄 GENTLEMAN Service Neustart..."
    
    # Stoppe alten Service
    echo "🛑 Stoppe alten Service..."
    pkill -f "talking_gentleman_protocol.py" 2>/dev/null
    sleep 2
    
    # Starte Service mit expliziter Bind-Konfiguration
    echo "🚀 Starte Service mit Firewall-optimierter Konfiguration..."
    cd "$HOME/Gentleman"
    nohup python3 talking_gentleman_protocol.py --start > gentleman_firewall.log 2>&1 &
    
    sleep 3
    
    # Prüfe Service-Status
    if ps aux | grep -v grep | grep "talking_gentleman_protocol.py" >/dev/null; then
        echo "✅ Service erfolgreich gestartet"
        return 0
    else
        echo "❌ Service-Start fehlgeschlagen"
        return 1
    fi
}

# Firewall-Regel Verification
verify_firewall_rules() {
    echo "🔍 Verifiziere Firewall-Regeln..."
    
    echo "📋 Python Applications in Firewall:"
    /usr/libexec/ApplicationFirewall/socketfilterfw --listapps | grep -i python || echo "   Keine Python-Apps gefunden"
    
    echo ""
    echo "📋 Firewall Global State:"
    /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
    
    echo ""
    echo "📋 Port Binding:"
    netstat -an | grep ":$GENTLEMAN_PORT " | head -5
}

# M1 Mac Connectivity Test
test_m1_connectivity() {
    echo "🔗 Teste M1 Mac Connectivity..."
    
    local my_ip=$(ifconfig | grep 'inet 192.168.68.' | awk '{print $2}' | head -1)
    
    if [ ! -z "$my_ip" ]; then
        echo "📡 Teste von M1 Mac (192.168.68.111) zu i7 ($my_ip:$GENTLEMAN_PORT):"
        
        # Test via SSH vom M1 Mac
        if ssh -i ~/.ssh/gentleman_key amonbaumgartner@192.168.68.111 "curl -s --connect-timeout 5 http://$my_ip:$GENTLEMAN_PORT/status" >/dev/null 2>&1; then
            echo "✅ M1 Mac kann i7 Node erreichen!"
            return 0
        else
            echo "❌ M1 Mac kann i7 Node nicht erreichen"
            return 1
        fi
    else
        echo "❌ Konnte eigene IP nicht ermitteln"
        return 1
    fi
}

# Hauptfunktion
main() {
    echo "🚀 Starte i7 Firewall-Lösung Implementation..."
    echo ""
    
    # 1. Backup
    backup_firewall_state
    echo ""
    
    # 2. Python Firewall konfigurieren
    configure_python_firewall
    echo ""
    
    # 3. Port Firewall konfigurieren
    configure_port_firewall
    echo ""
    
    # 4. Service Neustart
    if restart_gentleman_service; then
        echo ""
        
        # 5. Firewall-Test
        if test_firewall_configuration; then
            echo ""
            echo "🎉 Firewall-Konfiguration erfolgreich!"
            
            # 6. M1 Connectivity Test
            echo ""
            if test_m1_connectivity; then
                echo ""
                echo "🎯 LÖSUNG ERFOLGREICH! M1 Mac kann i7 Node erreichen!"
            else
                echo ""
                echo "⚠️ M1 Connectivity Test fehlgeschlagen - nutze SSH Tunnel Alternative"
                setup_ssh_tunnel_alternative
            fi
        else
            echo ""
            echo "⚠️ Firewall-Test fehlgeschlagen - erstelle SSH Tunnel Alternative"
            setup_ssh_tunnel_alternative
        fi
    else
        echo ""
        echo "❌ Service-Neustart fehlgeschlagen"
        return 1
    fi
    
    echo ""
    echo "🔍 Finale Konfiguration:"
    verify_firewall_rules
    
    echo ""
    echo "📋 Test-Kommandos:"
    echo "   # Lokal:"
    echo "   curl -s http://localhost:$GENTLEMAN_PORT/status"
    echo ""
    echo "   # Von M1 Mac:"
    echo "   ssh amonbaumgartner@192.168.68.111 'curl -s http://192.168.68.105:$GENTLEMAN_PORT/status'"
    echo ""
    echo "   # SSH Tunnel Alternative (vom M1 Mac):"
    echo "   ssh -L 8105:localhost:8008 amonbaumgartner@192.168.68.105"
    echo "   # Dann: curl http://localhost:8105/status"
    
    echo ""
    echo "🎯 i7 Firewall-Lösung Implementation abgeschlossen!"
}

# Script ausführen
main "$@" 