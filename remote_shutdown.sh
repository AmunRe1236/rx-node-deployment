#!/bin/bash

# 🔌 GENTLEMAN Remote Shutdown
# ============================
# Remote-Shutdown für RX Node über verschiedene Methoden
# - SSH (wenn verfügbar)
# - HTTP API (über Cloudflare Tunnel)
# - Wake-on-LAN Reverse (Magic Packet)

set -e

# Konfiguration
M1_HOST="192.168.68.111"
M1_PUBLIC_URL="https://graphical-founder-cleveland-vulnerable.trycloudflare.com"
LOG_FILE="/tmp/remote_shutdown.log"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging Funktionen
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1"
    echo -e "${RED}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

warning() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

# Netzwerk-Modus erkennen
detect_network_mode() {
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    
    if [[ "$current_ip" =~ ^192\.168\.68\. ]]; then
        echo "home"
    elif [[ "$current_ip" =~ ^172\.20\.10\. ]]; then
        echo "hotspot"
    else
        echo "unknown"
    fi
}

# SSH-Shutdown (Heimnetz)
shutdown_via_ssh() {
    log "🔌 Versuche SSH-Shutdown..."
    
    if ssh -o ConnectTimeout=5 -o BatchMode=yes amonbaumgartner@$M1_HOST "echo 'SSH OK'" >/dev/null 2>&1; then
        log "📡 SSH-Verbindung erfolgreich - Führe Shutdown durch..."
        
        # Stoppe Services und fahre herunter
        ssh amonbaumgartner@$M1_HOST "
            echo '🛑 Stoppe GENTLEMAN Services...'
            cd /Users/amonbaumgartner/Gentleman
            ./m1_master_control.sh stop >/dev/null 2>&1 || true
            pkill -f 'python3.*handshake' || true
            pkill -f 'cloudflared' || true
            
            echo '🔌 Fahre System herunter...'
            sudo shutdown -h now
        " 2>/dev/null || true
        
        success "SSH-Shutdown-Befehl gesendet"
        return 0
    else
        error "SSH-Verbindung fehlgeschlagen"
        return 1
    fi
}

# HTTP API Shutdown (über Cloudflare Tunnel)
shutdown_via_api() {
    log "🌐 Versuche API-Shutdown über Cloudflare Tunnel..."
    
    # Teste verschiedene mögliche URLs
    local urls=(
        "$M1_PUBLIC_URL"
        "https://graphical-founder-cleveland-vulnerable.trycloudflare.com"
        "https://spas-shopping-tight-sail.trycloudflare.com"
        "https://shock-adapter-silence-fin.trycloudflare.com"
    )
    
    # Versuche aktuelle URL aus Tunnel-Keeper zu holen
    if [ -f /tmp/current_tunnel_url.txt ]; then
        local current_url=$(cat /tmp/current_tunnel_url.txt)
        if [ -n "$current_url" ]; then
            urls=("$current_url" "${urls[@]}")
            log "📡 Verwende aktuelle Tunnel-URL: $current_url"
        fi
    fi
    
    for url in "${urls[@]}"; do
        log "🔍 Teste URL: $url"
        
        # Teste Health Check
        if curl -s --connect-timeout 5 "$url/health" >/dev/null 2>&1; then
            log "✅ URL erreichbar - Sende Shutdown-Befehl..."
            
            # Sende Shutdown-Befehl mit erweiterten Parametern
            local response=$(curl -s --connect-timeout 10 -X POST \
                -H "Content-Type: application/json" \
                -d '{
                    "source":"remote_hotspot_i7",
                    "delay_minutes":1,
                    "timestamp":"'$(date +%s)'",
                    "requester_ip":"'$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')'"
                }' \
                "$url/admin/shutdown" 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                # Parse Response
                local status=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
                
                if [ "$status" = "success" ]; then
                    success "✅ API-Shutdown erfolgreich: $response"
                    return 0
                else
                    warning "⚠️ API-Shutdown Response: $response"
                fi
            else
                warning "Keine Response vom Shutdown-Endpoint auf $url"
            fi
        else
            warning "URL nicht erreichbar: $url"
        fi
    done
    
    error "Alle API-Shutdown-Versuche fehlgeschlagen"
    return 1
}

# HTTP API Bootup (über Cloudflare Tunnel)
bootup_via_api() {
    log "🔋 Versuche API-Bootup über Cloudflare Tunnel..."
    
    # Teste verschiedene mögliche URLs
    local urls=(
        "$M1_PUBLIC_URL"
        "https://graphical-founder-cleveland-vulnerable.trycloudflare.com"
        "https://spas-shopping-tight-sail.trycloudflare.com"
        "https://shock-adapter-silence-fin.trycloudflare.com"
    )
    
    # Versuche aktuelle URL aus Tunnel-Keeper zu holen
    if [ -f /tmp/current_tunnel_url.txt ]; then
        local current_url=$(cat /tmp/current_tunnel_url.txt)
        if [ -n "$current_url" ]; then
            urls=("$current_url" "${urls[@]}")
            log "📡 Verwende aktuelle Tunnel-URL: $current_url"
        fi
    fi
    
    for url in "${urls[@]}"; do
        log "🔍 Teste URL: $url"
        
        # Teste Health Check
        if curl -s --connect-timeout 5 "$url/health" >/dev/null 2>&1; then
            log "✅ URL erreichbar - Sende Bootup-Befehl..."
            
            # Sende Bootup-Befehl
            local response=$(curl -s --connect-timeout 10 -X POST \
                -H "Content-Type: application/json" \
                -d '{
                    "source":"remote_hotspot_i7",
                    "target_ip":"192.168.68.111",
                    "target_mac":"auto",
                    "timestamp":"'$(date +%s)'",
                    "requester_ip":"'$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')'"
                }' \
                "$url/admin/bootup" 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                # Parse Response
                local status=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
                
                if [ "$status" = "success" ]; then
                    success "✅ API-Bootup erfolgreich: $response"
                    return 0
                else
                    warning "⚠️ API-Bootup Response: $response"
                fi
            else
                warning "Keine Response vom Bootup-Endpoint auf $url"
            fi
        else
            warning "URL nicht erreichbar: $url"
        fi
    done
    
    error "Alle API-Bootup-Versuche fehlgeschlagen"
    return 1
}

# Erstelle Shutdown-Endpoint auf M1 (falls SSH verfügbar)
create_shutdown_endpoint() {
    log "🔧 Erstelle Shutdown-Endpoint auf M1..."
    
    if ssh -o ConnectTimeout=5 -o BatchMode=yes amonbaumgartner@$M1_HOST "echo 'SSH OK'" >/dev/null 2>&1; then
        ssh amonbaumgartner@$M1_HOST "
            cd /Users/amonbaumgartner/Gentleman
            cat > m1_shutdown_endpoint.py << 'EOF'
#!/usr/bin/env python3
import json
import subprocess
import sys
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

@app.route('/admin/shutdown', methods=['POST'])
def shutdown_system():
    try:
        data = request.get_json()
        source = data.get('source', 'unknown')
        
        # Log shutdown request
        print(f'🔌 Shutdown-Anfrage von: {source}')
        
        # Stoppe Services
        subprocess.run(['./m1_master_control.sh', 'stop'], capture_output=True)
        subprocess.run(['pkill', '-f', 'python3.*handshake'], capture_output=True)
        subprocess.run(['pkill', '-f', 'cloudflared'], capture_output=True)
        
        # Plane Shutdown in 10 Sekunden
        subprocess.Popen(['sudo', 'shutdown', '-h', '+1'])
        
        return jsonify({
            'status': 'success',
            'message': 'Shutdown in 1 Minute geplant',
            'source': source
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8766, debug=False)
EOF
            chmod +x m1_shutdown_endpoint.py
            
            # Starte Shutdown-Endpoint im Hintergrund
            nohup python3 m1_shutdown_endpoint.py > /tmp/shutdown_endpoint.log 2>&1 &
            echo 'Shutdown-Endpoint gestartet auf Port 8766'
        "
        success "Shutdown-Endpoint auf M1 erstellt"
        return 0
    else
        error "SSH nicht verfügbar für Endpoint-Erstellung"
        return 1
    fi
}

# Network Magic Packet (Alternative)
send_magic_packet() {
    log "📡 Versuche Magic Packet für Remote-Shutdown..."
    
    # Das ist eine vereinfachte Implementierung
    # In der Praxis würde man Wake-on-LAN in Reverse verwenden
    warning "Magic Packet Shutdown nicht implementiert (benötigt spezielle Hardware-Konfiguration)"
    return 1
}

# Hauptfunktion
main() {
    local action="${1:-shutdown}"
    local network_mode=$(detect_network_mode)
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    
    echo
    if [ "$action" = "bootup" ]; then
        echo "🔋 GENTLEMAN Remote Bootup"
        echo "=========================="
    else
        echo "🔌 GENTLEMAN Remote Shutdown"
        echo "============================"
    fi
    echo
    log "🌐 Netzwerk-Modus: $network_mode (IP: $current_ip)"
    echo
    
    case "$network_mode" in
        "home")
            if [ "$action" = "bootup" ]; then
                log "🏠 Heimnetz erkannt - Bootup über SSH nicht nötig (bereits im gleichen Netz)"
                warning "M1 Mac sollte bereits erreichbar sein"
                exit 0
            else
                log "🏠 Heimnetz erkannt - Verwende SSH-Shutdown..."
                if shutdown_via_ssh; then
                    success "✅ RX Node Shutdown erfolgreich über SSH"
                    exit 0
                else
                    error "❌ SSH-Shutdown fehlgeschlagen"
                    exit 1
                fi
            fi
            ;;
        "hotspot")
            if [ "$action" = "bootup" ]; then
                log "📱 Hotspot erkannt - Verwende API-Bootup..."
                if bootup_via_api; then
                    success "✅ RX Node Bootup erfolgreich über API"
                    exit 0
                else
                    error "❌ Alle Remote-Bootup-Methoden fehlgeschlagen"
                    echo
                    echo "💡 Mögliche Lösungen:"
                    echo "   1. M1 Mac manuell einschalten"
                    echo "   2. Wake-on-LAN direkt im Heimnetz versuchen"
                    echo "   3. Prüfen ob Wake-on-LAN aktiviert ist"
                    echo
                    exit 1
                fi
            else
                log "📱 Hotspot erkannt - Verwende API-Shutdown..."
                if shutdown_via_api; then
                    success "✅ RX Node Shutdown erfolgreich über API"
                    exit 0
                else
                    warning "API-Shutdown fehlgeschlagen - Versuche alternative Methoden..."
                    if send_magic_packet; then
                        success "✅ RX Node Shutdown erfolgreich über Magic Packet"
                        exit 0
                    else
                        error "❌ Alle Remote-Shutdown-Methoden fehlgeschlagen"
                        echo
                        echo "💡 Mögliche Lösungen:"
                        echo "   1. Zurück ins Heimnetz wechseln für SSH-Zugriff"
                        echo "   2. M1 Mac manuell ausschalten"
                        echo "   3. Cloudflare Tunnel auf M1 neu starten"
                        echo
                        exit 1
                    fi
                fi
            fi
            ;;
        *)
            if [ "$action" = "bootup" ]; then
                error "❌ Unbekanntes Netzwerk - Bootup nicht möglich"
                echo
                echo "💡 Wechsle ins Heimnetz für direkten Wake-on-LAN"
                echo
            else
                error "❌ Unbekanntes Netzwerk - Shutdown nicht möglich"
                echo
                echo "💡 Wechsle ins Heimnetz für direkten SSH-Zugriff"
                echo
            fi
            exit 1
            ;;
    esac
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 

# 🔌 GENTLEMAN Remote Shutdown
# ============================
# Remote-Shutdown für RX Node über verschiedene Methoden
# - SSH (wenn verfügbar)
# - HTTP API (über Cloudflare Tunnel)
# - Wake-on-LAN Reverse (Magic Packet)

set -e

# Konfiguration
M1_HOST="192.168.68.111"
M1_PUBLIC_URL="https://graphical-founder-cleveland-vulnerable.trycloudflare.com"
LOG_FILE="/tmp/remote_shutdown.log"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging Funktionen
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1"
    echo -e "${RED}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

warning() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

# Netzwerk-Modus erkennen
detect_network_mode() {
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    
    if [[ "$current_ip" =~ ^192\.168\.68\. ]]; then
        echo "home"
    elif [[ "$current_ip" =~ ^172\.20\.10\. ]]; then
        echo "hotspot"
    else
        echo "unknown"
    fi
}

# SSH-Shutdown (Heimnetz)
shutdown_via_ssh() {
    log "🔌 Versuche SSH-Shutdown..."
    
    if ssh -o ConnectTimeout=5 -o BatchMode=yes amonbaumgartner@$M1_HOST "echo 'SSH OK'" >/dev/null 2>&1; then
        log "📡 SSH-Verbindung erfolgreich - Führe Shutdown durch..."
        
        # Stoppe Services und fahre herunter
        ssh amonbaumgartner@$M1_HOST "
            echo '🛑 Stoppe GENTLEMAN Services...'
            cd /Users/amonbaumgartner/Gentleman
            ./m1_master_control.sh stop >/dev/null 2>&1 || true
            pkill -f 'python3.*handshake' || true
            pkill -f 'cloudflared' || true
            
            echo '🔌 Fahre System herunter...'
            sudo shutdown -h now
        " 2>/dev/null || true
        
        success "SSH-Shutdown-Befehl gesendet"
        return 0
    else
        error "SSH-Verbindung fehlgeschlagen"
        return 1
    fi
}

# HTTP API Shutdown (über Cloudflare Tunnel)
shutdown_via_api() {
    log "🌐 Versuche API-Shutdown über Cloudflare Tunnel..."
    
    # Teste verschiedene mögliche URLs
    local urls=(
        "$M1_PUBLIC_URL"
        "https://graphical-founder-cleveland-vulnerable.trycloudflare.com"
        "https://spas-shopping-tight-sail.trycloudflare.com"
        "https://shock-adapter-silence-fin.trycloudflare.com"
    )
    
    # Versuche aktuelle URL aus Tunnel-Keeper zu holen
    if [ -f /tmp/current_tunnel_url.txt ]; then
        local current_url=$(cat /tmp/current_tunnel_url.txt)
        if [ -n "$current_url" ]; then
            urls=("$current_url" "${urls[@]}")
            log "📡 Verwende aktuelle Tunnel-URL: $current_url"
        fi
    fi
    
    for url in "${urls[@]}"; do
        log "🔍 Teste URL: $url"
        
        # Teste Health Check
        if curl -s --connect-timeout 5 "$url/health" >/dev/null 2>&1; then
            log "✅ URL erreichbar - Sende Shutdown-Befehl..."
            
            # Sende Shutdown-Befehl mit erweiterten Parametern
            local response=$(curl -s --connect-timeout 10 -X POST \
                -H "Content-Type: application/json" \
                -d '{
                    "source":"remote_hotspot_i7",
                    "delay_minutes":1,
                    "timestamp":"'$(date +%s)'",
                    "requester_ip":"'$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')'"
                }' \
                "$url/admin/shutdown" 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                # Parse Response
                local status=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
                
                if [ "$status" = "success" ]; then
                    success "✅ API-Shutdown erfolgreich: $response"
                    return 0
                else
                    warning "⚠️ API-Shutdown Response: $response"
                fi
            else
                warning "Keine Response vom Shutdown-Endpoint auf $url"
            fi
        else
            warning "URL nicht erreichbar: $url"
        fi
    done
    
    error "Alle API-Shutdown-Versuche fehlgeschlagen"
    return 1
}

# HTTP API Bootup (über Cloudflare Tunnel)
bootup_via_api() {
    log "🔋 Versuche API-Bootup über Cloudflare Tunnel..."
    
    # Teste verschiedene mögliche URLs
    local urls=(
        "$M1_PUBLIC_URL"
        "https://graphical-founder-cleveland-vulnerable.trycloudflare.com"
        "https://spas-shopping-tight-sail.trycloudflare.com"
        "https://shock-adapter-silence-fin.trycloudflare.com"
    )
    
    # Versuche aktuelle URL aus Tunnel-Keeper zu holen
    if [ -f /tmp/current_tunnel_url.txt ]; then
        local current_url=$(cat /tmp/current_tunnel_url.txt)
        if [ -n "$current_url" ]; then
            urls=("$current_url" "${urls[@]}")
            log "📡 Verwende aktuelle Tunnel-URL: $current_url"
        fi
    fi
    
    for url in "${urls[@]}"; do
        log "🔍 Teste URL: $url"
        
        # Teste Health Check
        if curl -s --connect-timeout 5 "$url/health" >/dev/null 2>&1; then
            log "✅ URL erreichbar - Sende Bootup-Befehl..."
            
            # Sende Bootup-Befehl
            local response=$(curl -s --connect-timeout 10 -X POST \
                -H "Content-Type: application/json" \
                -d '{
                    "source":"remote_hotspot_i7",
                    "target_ip":"192.168.68.111",
                    "target_mac":"auto",
                    "timestamp":"'$(date +%s)'",
                    "requester_ip":"'$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')'"
                }' \
                "$url/admin/bootup" 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                # Parse Response
                local status=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
                
                if [ "$status" = "success" ]; then
                    success "✅ API-Bootup erfolgreich: $response"
                    return 0
                else
                    warning "⚠️ API-Bootup Response: $response"
                fi
            else
                warning "Keine Response vom Bootup-Endpoint auf $url"
            fi
        else
            warning "URL nicht erreichbar: $url"
        fi
    done
    
    error "Alle API-Bootup-Versuche fehlgeschlagen"
    return 1
}

# Erstelle Shutdown-Endpoint auf M1 (falls SSH verfügbar)
create_shutdown_endpoint() {
    log "🔧 Erstelle Shutdown-Endpoint auf M1..."
    
    if ssh -o ConnectTimeout=5 -o BatchMode=yes amonbaumgartner@$M1_HOST "echo 'SSH OK'" >/dev/null 2>&1; then
        ssh amonbaumgartner@$M1_HOST "
            cd /Users/amonbaumgartner/Gentleman
            cat > m1_shutdown_endpoint.py << 'EOF'
#!/usr/bin/env python3
import json
import subprocess
import sys
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

@app.route('/admin/shutdown', methods=['POST'])
def shutdown_system():
    try:
        data = request.get_json()
        source = data.get('source', 'unknown')
        
        # Log shutdown request
        print(f'🔌 Shutdown-Anfrage von: {source}')
        
        # Stoppe Services
        subprocess.run(['./m1_master_control.sh', 'stop'], capture_output=True)
        subprocess.run(['pkill', '-f', 'python3.*handshake'], capture_output=True)
        subprocess.run(['pkill', '-f', 'cloudflared'], capture_output=True)
        
        # Plane Shutdown in 10 Sekunden
        subprocess.Popen(['sudo', 'shutdown', '-h', '+1'])
        
        return jsonify({
            'status': 'success',
            'message': 'Shutdown in 1 Minute geplant',
            'source': source
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8766, debug=False)
EOF
            chmod +x m1_shutdown_endpoint.py
            
            # Starte Shutdown-Endpoint im Hintergrund
            nohup python3 m1_shutdown_endpoint.py > /tmp/shutdown_endpoint.log 2>&1 &
            echo 'Shutdown-Endpoint gestartet auf Port 8766'
        "
        success "Shutdown-Endpoint auf M1 erstellt"
        return 0
    else
        error "SSH nicht verfügbar für Endpoint-Erstellung"
        return 1
    fi
}

# Network Magic Packet (Alternative)
send_magic_packet() {
    log "📡 Versuche Magic Packet für Remote-Shutdown..."
    
    # Das ist eine vereinfachte Implementierung
    # In der Praxis würde man Wake-on-LAN in Reverse verwenden
    warning "Magic Packet Shutdown nicht implementiert (benötigt spezielle Hardware-Konfiguration)"
    return 1
}

# Hauptfunktion
main() {
    local action="${1:-shutdown}"
    local network_mode=$(detect_network_mode)
    local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    
    echo
    if [ "$action" = "bootup" ]; then
        echo "🔋 GENTLEMAN Remote Bootup"
        echo "=========================="
    else
        echo "🔌 GENTLEMAN Remote Shutdown"
        echo "============================"
    fi
    echo
    log "🌐 Netzwerk-Modus: $network_mode (IP: $current_ip)"
    echo
    
    case "$network_mode" in
        "home")
            if [ "$action" = "bootup" ]; then
                log "🏠 Heimnetz erkannt - Bootup über SSH nicht nötig (bereits im gleichen Netz)"
                warning "M1 Mac sollte bereits erreichbar sein"
                exit 0
            else
                log "🏠 Heimnetz erkannt - Verwende SSH-Shutdown..."
                if shutdown_via_ssh; then
                    success "✅ RX Node Shutdown erfolgreich über SSH"
                    exit 0
                else
                    error "❌ SSH-Shutdown fehlgeschlagen"
                    exit 1
                fi
            fi
            ;;
        "hotspot")
            if [ "$action" = "bootup" ]; then
                log "📱 Hotspot erkannt - Verwende API-Bootup..."
                if bootup_via_api; then
                    success "✅ RX Node Bootup erfolgreich über API"
                    exit 0
                else
                    error "❌ Alle Remote-Bootup-Methoden fehlgeschlagen"
                    echo
                    echo "💡 Mögliche Lösungen:"
                    echo "   1. M1 Mac manuell einschalten"
                    echo "   2. Wake-on-LAN direkt im Heimnetz versuchen"
                    echo "   3. Prüfen ob Wake-on-LAN aktiviert ist"
                    echo
                    exit 1
                fi
            else
                log "📱 Hotspot erkannt - Verwende API-Shutdown..."
                if shutdown_via_api; then
                    success "✅ RX Node Shutdown erfolgreich über API"
                    exit 0
                else
                    warning "API-Shutdown fehlgeschlagen - Versuche alternative Methoden..."
                    if send_magic_packet; then
                        success "✅ RX Node Shutdown erfolgreich über Magic Packet"
                        exit 0
                    else
                        error "❌ Alle Remote-Shutdown-Methoden fehlgeschlagen"
                        echo
                        echo "💡 Mögliche Lösungen:"
                        echo "   1. Zurück ins Heimnetz wechseln für SSH-Zugriff"
                        echo "   2. M1 Mac manuell ausschalten"
                        echo "   3. Cloudflare Tunnel auf M1 neu starten"
                        echo
                        exit 1
                    fi
                fi
            fi
            ;;
        *)
            if [ "$action" = "bootup" ]; then
                error "❌ Unbekanntes Netzwerk - Bootup nicht möglich"
                echo
                echo "💡 Wechsle ins Heimnetz für direkten Wake-on-LAN"
                echo
            else
                error "❌ Unbekanntes Netzwerk - Shutdown nicht möglich"
                echo
                echo "💡 Wechsle ins Heimnetz für direkten SSH-Zugriff"
                echo
            fi
            exit 1
            ;;
    esac
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 
 