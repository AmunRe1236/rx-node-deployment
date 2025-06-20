#!/bin/bash

# 🔌 GENTLEMAN Hotspot Remote Shutdown
# ====================================
# Robustes Remote-Shutdown auch über Hotspot-Verbindungen
# Funktioniert sowohl mit SSH als auch API

set -e

# Konfiguration
M1_HOST="192.168.68.111"
M1_USER="amonbaumgartner"
LOG_FILE="/tmp/hotspot_shutdown.log"

# Logging-Funktion
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Netzwerk-Modus ermitteln
detect_network_mode() {
    local current_ip=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')
    
    if [[ "$current_ip" =~ ^192\.168\.68\. ]]; then
        echo "home"
    elif [[ "$current_ip" =~ ^172\.20\.10\. ]]; then
        echo "hotspot"
    else
        echo "unknown"
    fi
}

# SSH-Verbindung testen
test_ssh_connection() {
    ssh -o ConnectTimeout=5 -o BatchMode=yes "$M1_USER@$M1_HOST" "echo 'SSH OK'" >/dev/null 2>&1
    return $?
}

# SSH-basiertes Shutdown (funktioniert oft auch über Hotspot)
ssh_shutdown() {
    log_message "🔌 Versuche SSH-Shutdown..."
    
    if ! test_ssh_connection; then
        log_message "❌ SSH-Verbindung fehlgeschlagen"
        return 1
    fi
    
    log_message "📡 SSH-Verbindung erfolgreich - Führe Shutdown durch..."
    
    # AppleScript-basierter Shutdown (funktioniert ohne sudo)
    local shutdown_script="
        echo '🛑 Stoppe GENTLEMAN Services...'
        pkill -f 'python3.*handshake' 2>/dev/null || true
        pkill -f 'cloudflared' 2>/dev/null || true
        pkill -f 'gentleman' 2>/dev/null || true
        
        echo '🔌 Fahre System herunter...'
        osascript -e 'tell app \"System Events\" to shut down'
    "
    
    if ssh -o ConnectTimeout=10 "$M1_USER@$M1_HOST" "$shutdown_script"; then
        log_message "✅ SSH-Shutdown-Befehl gesendet"
        return 0
    else
        log_message "❌ SSH-Shutdown fehlgeschlagen"
        return 1
    fi
}

# M1 Handshake Server starten (für API-Shutdown)
start_m1_handshake_server() {
    log_message "🚀 Starte M1 Handshake Server für API-Shutdown..."
    
    if ! test_ssh_connection; then
        log_message "❌ SSH-Verbindung für Server-Start fehlgeschlagen"
        return 1
    fi
    
    # Starte Handshake Server im Hintergrund
    ssh "$M1_USER@$M1_HOST" "
        cd /Users/amonbaumgartner/Gentleman
        nohup python3 m1_handshake_server.py > /tmp/handshake_server.log 2>&1 &
        sleep 2
        echo 'Handshake Server gestartet'
    " 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        log_message "✅ M1 Handshake Server gestartet"
        return 0
    else
        log_message "❌ M1 Handshake Server Start fehlgeschlagen"
        return 1
    fi
}

# API-basiertes Shutdown über Tunnel
api_shutdown() {
    log_message "📱 Versuche API-Shutdown über Cloudflare Tunnel..."
    
    # Hole aktuelle Tunnel-URL
    local tunnel_url
    if [[ -f "./m1_tunnel_keeper.sh" ]]; then
        tunnel_url=$(./m1_tunnel_keeper.sh url 2>/dev/null | head -1)
    fi
    
    # Fallback URLs
    local fallback_urls=(
        "https://super-ken-tunes-martin.trycloudflare.com"
        "https://spy-specifies-exhibition-convenient.trycloudflare.com"
        "https://fundamentals-remain-specifies-licenses.trycloudflare.com"
    )
    
    local urls_to_try=()
    [[ -n "$tunnel_url" ]] && urls_to_try+=("$tunnel_url")
    urls_to_try+=("${fallback_urls[@]}")
    
    for url in "${urls_to_try[@]}"; do
        log_message "🔍 Teste URL: $url"
        
        # Teste URL-Erreichbarkeit
        if curl -s --max-time 5 "$url/health" >/dev/null 2>&1; then
            log_message "✅ URL erreichbar - Sende Shutdown-Befehl..."
            
            # Sende Shutdown-Request
            local response=$(curl -X POST "$url/admin/shutdown" \
                -H "Content-Type: application/json" \
                -d '{"delay_minutes": 1, "source": "HOTSPOT_SHUTDOWN", "reason": "Remote shutdown from hotspot"}' \
                --max-time 15 2>/dev/null)
            
            if [[ $? -eq 0 ]] && echo "$response" | grep -q '"status".*"success"'; then
                log_message "✅ API-Shutdown erfolgreich"
                return 0
            else
                log_message "⚠️ API-Shutdown Response: $response"
            fi
        else
            log_message "⚠️ URL nicht erreichbar: $url"
        fi
    done
    
    log_message "❌ Alle API-Shutdown-Versuche fehlgeschlagen"
    return 1
}

# Hybrid-Shutdown: SSH zuerst, dann API falls nötig
hybrid_shutdown() {
    local network_mode=$(detect_network_mode)
    log_message "🌐 Netzwerk-Modus: $network_mode (IP: $(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}'))"
    
    # SSH immer zuerst versuchen (funktioniert oft auch im Hotspot)
    if ssh_shutdown; then
        log_message "✅ SSH-Shutdown erfolgreich"
        return 0
    fi
    
    # Falls SSH fehlschlägt und wir im Hotspot sind
    if [[ "$network_mode" == "hotspot" ]]; then
        log_message "🔄 SSH fehlgeschlagen - Versuche API-Shutdown..."
        
        # Versuche M1 Handshake Server zu starten
        if start_m1_handshake_server; then
            sleep 5  # Warte bis Server läuft
            
            # Versuche API-Shutdown
            if api_shutdown; then
                return 0
            fi
        fi
    fi
    
    log_message "❌ Alle Shutdown-Methoden fehlgeschlagen"
    return 1
}

# Main
main() {
    echo "🔌 GENTLEMAN Hotspot Remote Shutdown"
    echo "===================================="
    echo
    
    log_message "🚀 Hotspot Remote-Shutdown gestartet"
    
    if hybrid_shutdown; then
        log_message "✅ ✅ RX Node Shutdown erfolgreich"
        echo
        echo "✅ RX Node wurde erfolgreich heruntergefahren!"
        echo "   Die M1 Mac sollte in ca. 1-2 Minuten ausgeschaltet sein."
        exit 0
    else
        log_message "❌ ❌ RX Node Shutdown fehlgeschlagen"
        echo
        echo "❌ RX Node Shutdown fehlgeschlagen!"
        echo
        echo "💡 Mögliche Lösungen:"
        echo "   1. Netzwerkverbindung prüfen"
        echo "   2. M1 Mac manuell ausschalten"
        echo "   3. Ins Heimnetz wechseln und SSH versuchen"
        echo
        exit 1
    fi
}

# Script ausführen
main "$@" 

# 🔌 GENTLEMAN Hotspot Remote Shutdown
# ====================================
# Robustes Remote-Shutdown auch über Hotspot-Verbindungen
# Funktioniert sowohl mit SSH als auch API

set -e

# Konfiguration
M1_HOST="192.168.68.111"
M1_USER="amonbaumgartner"
LOG_FILE="/tmp/hotspot_shutdown.log"

# Logging-Funktion
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Netzwerk-Modus ermitteln
detect_network_mode() {
    local current_ip=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')
    
    if [[ "$current_ip" =~ ^192\.168\.68\. ]]; then
        echo "home"
    elif [[ "$current_ip" =~ ^172\.20\.10\. ]]; then
        echo "hotspot"
    else
        echo "unknown"
    fi
}

# SSH-Verbindung testen
test_ssh_connection() {
    ssh -o ConnectTimeout=5 -o BatchMode=yes "$M1_USER@$M1_HOST" "echo 'SSH OK'" >/dev/null 2>&1
    return $?
}

# SSH-basiertes Shutdown (funktioniert oft auch über Hotspot)
ssh_shutdown() {
    log_message "🔌 Versuche SSH-Shutdown..."
    
    if ! test_ssh_connection; then
        log_message "❌ SSH-Verbindung fehlgeschlagen"
        return 1
    fi
    
    log_message "📡 SSH-Verbindung erfolgreich - Führe Shutdown durch..."
    
    # AppleScript-basierter Shutdown (funktioniert ohne sudo)
    local shutdown_script="
        echo '🛑 Stoppe GENTLEMAN Services...'
        pkill -f 'python3.*handshake' 2>/dev/null || true
        pkill -f 'cloudflared' 2>/dev/null || true
        pkill -f 'gentleman' 2>/dev/null || true
        
        echo '🔌 Fahre System herunter...'
        osascript -e 'tell app \"System Events\" to shut down'
    "
    
    if ssh -o ConnectTimeout=10 "$M1_USER@$M1_HOST" "$shutdown_script"; then
        log_message "✅ SSH-Shutdown-Befehl gesendet"
        return 0
    else
        log_message "❌ SSH-Shutdown fehlgeschlagen"
        return 1
    fi
}

# M1 Handshake Server starten (für API-Shutdown)
start_m1_handshake_server() {
    log_message "🚀 Starte M1 Handshake Server für API-Shutdown..."
    
    if ! test_ssh_connection; then
        log_message "❌ SSH-Verbindung für Server-Start fehlgeschlagen"
        return 1
    fi
    
    # Starte Handshake Server im Hintergrund
    ssh "$M1_USER@$M1_HOST" "
        cd /Users/amonbaumgartner/Gentleman
        nohup python3 m1_handshake_server.py > /tmp/handshake_server.log 2>&1 &
        sleep 2
        echo 'Handshake Server gestartet'
    " 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        log_message "✅ M1 Handshake Server gestartet"
        return 0
    else
        log_message "❌ M1 Handshake Server Start fehlgeschlagen"
        return 1
    fi
}

# API-basiertes Shutdown über Tunnel
api_shutdown() {
    log_message "📱 Versuche API-Shutdown über Cloudflare Tunnel..."
    
    # Hole aktuelle Tunnel-URL
    local tunnel_url
    if [[ -f "./m1_tunnel_keeper.sh" ]]; then
        tunnel_url=$(./m1_tunnel_keeper.sh url 2>/dev/null | head -1)
    fi
    
    # Fallback URLs
    local fallback_urls=(
        "https://super-ken-tunes-martin.trycloudflare.com"
        "https://spy-specifies-exhibition-convenient.trycloudflare.com"
        "https://fundamentals-remain-specifies-licenses.trycloudflare.com"
    )
    
    local urls_to_try=()
    [[ -n "$tunnel_url" ]] && urls_to_try+=("$tunnel_url")
    urls_to_try+=("${fallback_urls[@]}")
    
    for url in "${urls_to_try[@]}"; do
        log_message "🔍 Teste URL: $url"
        
        # Teste URL-Erreichbarkeit
        if curl -s --max-time 5 "$url/health" >/dev/null 2>&1; then
            log_message "✅ URL erreichbar - Sende Shutdown-Befehl..."
            
            # Sende Shutdown-Request
            local response=$(curl -X POST "$url/admin/shutdown" \
                -H "Content-Type: application/json" \
                -d '{"delay_minutes": 1, "source": "HOTSPOT_SHUTDOWN", "reason": "Remote shutdown from hotspot"}' \
                --max-time 15 2>/dev/null)
            
            if [[ $? -eq 0 ]] && echo "$response" | grep -q '"status".*"success"'; then
                log_message "✅ API-Shutdown erfolgreich"
                return 0
            else
                log_message "⚠️ API-Shutdown Response: $response"
            fi
        else
            log_message "⚠️ URL nicht erreichbar: $url"
        fi
    done
    
    log_message "❌ Alle API-Shutdown-Versuche fehlgeschlagen"
    return 1
}

# Hybrid-Shutdown: SSH zuerst, dann API falls nötig
hybrid_shutdown() {
    local network_mode=$(detect_network_mode)
    log_message "🌐 Netzwerk-Modus: $network_mode (IP: $(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}'))"
    
    # SSH immer zuerst versuchen (funktioniert oft auch im Hotspot)
    if ssh_shutdown; then
        log_message "✅ SSH-Shutdown erfolgreich"
        return 0
    fi
    
    # Falls SSH fehlschlägt und wir im Hotspot sind
    if [[ "$network_mode" == "hotspot" ]]; then
        log_message "🔄 SSH fehlgeschlagen - Versuche API-Shutdown..."
        
        # Versuche M1 Handshake Server zu starten
        if start_m1_handshake_server; then
            sleep 5  # Warte bis Server läuft
            
            # Versuche API-Shutdown
            if api_shutdown; then
                return 0
            fi
        fi
    fi
    
    log_message "❌ Alle Shutdown-Methoden fehlgeschlagen"
    return 1
}

# Main
main() {
    echo "🔌 GENTLEMAN Hotspot Remote Shutdown"
    echo "===================================="
    echo
    
    log_message "🚀 Hotspot Remote-Shutdown gestartet"
    
    if hybrid_shutdown; then
        log_message "✅ ✅ RX Node Shutdown erfolgreich"
        echo
        echo "✅ RX Node wurde erfolgreich heruntergefahren!"
        echo "   Die M1 Mac sollte in ca. 1-2 Minuten ausgeschaltet sein."
        exit 0
    else
        log_message "❌ ❌ RX Node Shutdown fehlgeschlagen"
        echo
        echo "❌ RX Node Shutdown fehlgeschlagen!"
        echo
        echo "💡 Mögliche Lösungen:"
        echo "   1. Netzwerkverbindung prüfen"
        echo "   2. M1 Mac manuell ausschalten"
        echo "   3. Ins Heimnetz wechseln und SSH versuchen"
        echo
        exit 1
    fi
}

# Script ausführen
main "$@" 
 