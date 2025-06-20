#!/bin/bash

# 🎯 GENTLEMAN RX Node Remote Control
# ===================================
# Steuerung der RX Node über M1 Mac Gateway vom Hotspot aus

set -e

# Konfiguration
M1_HOST="192.168.68.111"
M1_USER="amonbaumgartner"
RX_HOST="192.168.68.117"
RX_USER="amo9n11"
RX_MAC="30:9c:23:5f:44:a8"  # Ethernet Interface enp33s0
LOG_FILE="/tmp/rx_node_control.log"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktion
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] $1" | tee -a "$LOG_FILE"
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

# RX Node Status überprüfen
check_rx_status() {
    local method="$1"
    
    if [[ "$method" == "direct" ]]; then
        # Direkter Zugriff (Heimnetz)
        if ping -c 1 -W 1000 $RX_HOST >/dev/null 2>&1; then
            echo "online"
        else
            echo "offline"
        fi
    else
        # Über M1 Mac Gateway (Hotspot)
        if ssh -o ConnectTimeout=5 $M1_USER@$M1_HOST "ping -c 1 -W 1000 $RX_HOST >/dev/null 2>&1"; then
            echo "online"
        else
            echo "offline"
        fi
    fi
}

# RX Node Shutdown (über M1 Gateway)
rx_shutdown() {
    local network_mode=$(detect_network_mode)
    
    log_message "🛑 Starte RX Node Shutdown..."
    log_message "🌐 Netzwerk-Modus: $network_mode"
    
    if [[ "$network_mode" == "home" ]]; then
        log_message "🏠 Heimnetz - Direkter SSH-Zugriff"
        
        # Direkte SSH-Verbindung zur RX Node
        if ssh -o ConnectTimeout=10 $RX_USER@$RX_HOST "echo 'RX Node Shutdown gestartet...' && sudo systemctl poweroff"; then
            log_message "✅ RX Node Shutdown-Befehl erfolgreich gesendet"
        else
            log_message "❌ Direkter SSH-Shutdown fehlgeschlagen"
            return 1
        fi
        
    else
        log_message "📱 Hotspot - Über M1 Mac Gateway"
        
        # SSH über M1 Mac Gateway zur RX Node
        local shutdown_cmd="ssh -o ConnectTimeout=10 $RX_USER@$RX_HOST 'echo \"RX Node Shutdown über M1 Gateway...\" && sudo systemctl poweroff'"
        
        if ssh -o ConnectTimeout=15 $M1_USER@$M1_HOST "$shutdown_cmd"; then
            log_message "✅ RX Node Shutdown über M1 Gateway erfolgreich"
        else
            log_message "❌ Gateway-SSH-Shutdown fehlgeschlagen"
            return 1
        fi
    fi
    
    # Status überwachen
    log_message "🔄 Überwache Shutdown-Prozess..."
    for i in {1..30}; do
        sleep 2
        local status=$(check_rx_status "$([[ "$network_mode" == "home" ]] && echo "direct" || echo "gateway")")
        
        if [[ "$status" == "offline" ]]; then
            log_message "🎉 RX Node erfolgreich heruntergefahren (nach $((i*2)) Sekunden)"
            return 0
        fi
        
        echo -n "."
    done
    
    echo ""
    log_message "⏰ Timeout - RX Node Status unbekannt"
    return 1
}

# RX Node Wake-on-LAN (über M1 Gateway)
rx_wakeup() {
    local network_mode=$(detect_network_mode)
    
    log_message "🔋 Starte RX Node Wake-on-LAN..."
    log_message "🌐 Netzwerk-Modus: $network_mode"
    log_message "🔮 RX Node MAC: $RX_MAC"
    
    if [[ "$network_mode" == "home" ]]; then
        log_message "🏠 Heimnetz - Lokales Wake-on-LAN"
        
        # Lokales Wake-on-LAN
        if command -v wakeonlan >/dev/null 2>&1; then
            wakeonlan -i 192.168.68.255 $RX_MAC
            log_message "✅ Magic Packet gesendet via wakeonlan"
        fi
        
        # Python Fallback
        python3 -c "
import socket
mac_bytes = bytes.fromhex('$RX_MAC'.replace(':', ''))
magic_packet = b'\xff' * 6 + mac_bytes * 16
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
sock.sendto(magic_packet, ('192.168.68.255', 9))
sock.close()
print('✅ Python Magic Packet gesendet')
"
        
    else
        log_message "📱 Hotspot - Wake-on-LAN über M1 Gateway"
        
        # Wake-on-LAN über M1 Mac Gateway
        local wol_cmd="
        # Python Magic Packet über M1 Gateway
        python3 -c \"
import socket
mac_bytes = bytes.fromhex('$RX_MAC'.replace(':', ''))
magic_packet = b'\xff' * 6 + mac_bytes * 16
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
sock.sendto(magic_packet, ('192.168.68.255', 9))
sock.sendto(magic_packet, ('$RX_HOST', 9))
sock.close()
print('✅ Magic Packet über M1 Gateway gesendet')
\"
        "
        
        if ssh -o ConnectTimeout=10 $M1_USER@$M1_HOST "$wol_cmd"; then
            log_message "✅ Wake-on-LAN über M1 Gateway erfolgreich"
        else
            log_message "❌ Gateway Wake-on-LAN fehlgeschlagen"
            return 1
        fi
    fi
    
    # Status überwachen
    log_message "🔄 Warte auf RX Node Bootup..."
    for i in {1..60}; do
        sleep 2
        local status=$(check_rx_status "$([[ "$network_mode" == "home" ]] && echo "direct" || echo "gateway")")
        
        if [[ "$status" == "online" ]]; then
            log_message "🎉 RX Node ist online! (nach $((i*2)) Sekunden)"
            return 0
        fi
        
        # Fortschrittsanzeige
        if [[ $((i % 5)) -eq 0 ]]; then
            echo -n " [$((i*2))s]"
        else
            echo -n "."
        fi
    done
    
    echo ""
    log_message "⏰ Timeout - RX Node antwortet nicht"
    log_message "💡 Mögliche Gründe:"
    log_message "   - Wake-on-LAN ist nicht aktiviert"
    log_message "   - RX Node benötigt mehr Zeit zum Booten"
    log_message "   - Netzwerkprobleme"
    return 1
}

# RX Node Status anzeigen
rx_status() {
    local network_mode=$(detect_network_mode)
    local current_ip=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')
    
    echo -e "${BLUE}🎯 GENTLEMAN RX Node Status${NC}"
    echo -e "${BLUE}============================${NC}"
    echo ""
    
    log_message "🌐 Netzwerk-Modus: $network_mode (IP: $current_ip)"
    log_message "🎯 RX Node: $RX_HOST"
    log_message "🔮 MAC-Adresse: $RX_MAC"
    
    local status=$(check_rx_status "$([[ "$network_mode" == "home" ]] && echo "direct" || echo "gateway")")
    
    if [[ "$status" == "online" ]]; then
        log_message "✅ RX Node Status: ONLINE"
        
        # Zusätzliche Informationen wenn online
        if [[ "$network_mode" == "home" ]]; then
            ssh -o ConnectTimeout=5 $RX_USER@$RX_HOST "echo '📊 System Info:' && uptime && echo '💾 Speicher:' && free -h | head -2" 2>/dev/null || true
        else
            ssh -o ConnectTimeout=10 $M1_USER@$M1_HOST "ssh -o ConnectTimeout=5 $RX_USER@$RX_HOST 'echo \"📊 System Info:\" && uptime && echo \"💾 Speicher:\" && free -h | head -2'" 2>/dev/null || true
        fi
    else
        log_message "❌ RX Node Status: OFFLINE"
    fi
}

# Hilfe anzeigen
show_help() {
    echo -e "${BLUE}🎯 GENTLEMAN RX Node Remote Control${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo ""
    echo "Verwendung: $0 {shutdown|wakeup|status|help}"
    echo ""
    echo "Befehle:"
    echo "  shutdown  - RX Node herunterfahren"
    echo "  wakeup    - RX Node aufwecken (Wake-on-LAN)"
    echo "  status    - RX Node Status anzeigen"
    echo "  help      - Diese Hilfe anzeigen"
    echo ""
    echo "Funktioniert sowohl im Heimnetz als auch über Hotspot (via M1 Gateway)"
}

# Hauptfunktion
main() {
    case "$1" in
        "shutdown"|"poweroff"|"halt")
            rx_shutdown
            ;;
        "wakeup"|"wake"|"start"|"bootup")
            rx_wakeup
            ;;
        "status"|"check")
            rx_status
            ;;
        "help"|"-h"|"--help"|"")
            show_help
            ;;
        *)
            echo "❌ Unbekannter Befehl: $1"
            show_help
            exit 1
            ;;
    esac
}

# Script ausführen
main "$@" 

# 🎯 GENTLEMAN RX Node Remote Control
# ===================================
# Steuerung der RX Node über M1 Mac Gateway vom Hotspot aus

set -e

# Konfiguration
M1_HOST="192.168.68.111"
M1_USER="amonbaumgartner"
RX_HOST="192.168.68.117"
RX_USER="amo9n11"
RX_MAC="30:9c:23:5f:44:a8"  # Ethernet Interface enp33s0
LOG_FILE="/tmp/rx_node_control.log"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktion
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] $1" | tee -a "$LOG_FILE"
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

# RX Node Status überprüfen
check_rx_status() {
    local method="$1"
    
    if [[ "$method" == "direct" ]]; then
        # Direkter Zugriff (Heimnetz)
        if ping -c 1 -W 1000 $RX_HOST >/dev/null 2>&1; then
            echo "online"
        else
            echo "offline"
        fi
    else
        # Über M1 Mac Gateway (Hotspot)
        if ssh -o ConnectTimeout=5 $M1_USER@$M1_HOST "ping -c 1 -W 1000 $RX_HOST >/dev/null 2>&1"; then
            echo "online"
        else
            echo "offline"
        fi
    fi
}

# RX Node Shutdown (über M1 Gateway)
rx_shutdown() {
    local network_mode=$(detect_network_mode)
    
    log_message "🛑 Starte RX Node Shutdown..."
    log_message "🌐 Netzwerk-Modus: $network_mode"
    
    if [[ "$network_mode" == "home" ]]; then
        log_message "🏠 Heimnetz - Direkter SSH-Zugriff"
        
        # Direkte SSH-Verbindung zur RX Node
        if ssh -o ConnectTimeout=10 $RX_USER@$RX_HOST "echo 'RX Node Shutdown gestartet...' && sudo systemctl poweroff"; then
            log_message "✅ RX Node Shutdown-Befehl erfolgreich gesendet"
        else
            log_message "❌ Direkter SSH-Shutdown fehlgeschlagen"
            return 1
        fi
        
    else
        log_message "📱 Hotspot - Über M1 Mac Gateway"
        
        # SSH über M1 Mac Gateway zur RX Node
        local shutdown_cmd="ssh -o ConnectTimeout=10 $RX_USER@$RX_HOST 'echo \"RX Node Shutdown über M1 Gateway...\" && sudo systemctl poweroff'"
        
        if ssh -o ConnectTimeout=15 $M1_USER@$M1_HOST "$shutdown_cmd"; then
            log_message "✅ RX Node Shutdown über M1 Gateway erfolgreich"
        else
            log_message "❌ Gateway-SSH-Shutdown fehlgeschlagen"
            return 1
        fi
    fi
    
    # Status überwachen
    log_message "🔄 Überwache Shutdown-Prozess..."
    for i in {1..30}; do
        sleep 2
        local status=$(check_rx_status "$([[ "$network_mode" == "home" ]] && echo "direct" || echo "gateway")")
        
        if [[ "$status" == "offline" ]]; then
            log_message "🎉 RX Node erfolgreich heruntergefahren (nach $((i*2)) Sekunden)"
            return 0
        fi
        
        echo -n "."
    done
    
    echo ""
    log_message "⏰ Timeout - RX Node Status unbekannt"
    return 1
}

# RX Node Wake-on-LAN (über M1 Gateway)
rx_wakeup() {
    local network_mode=$(detect_network_mode)
    
    log_message "🔋 Starte RX Node Wake-on-LAN..."
    log_message "🌐 Netzwerk-Modus: $network_mode"
    log_message "🔮 RX Node MAC: $RX_MAC"
    
    if [[ "$network_mode" == "home" ]]; then
        log_message "🏠 Heimnetz - Lokales Wake-on-LAN"
        
        # Lokales Wake-on-LAN
        if command -v wakeonlan >/dev/null 2>&1; then
            wakeonlan -i 192.168.68.255 $RX_MAC
            log_message "✅ Magic Packet gesendet via wakeonlan"
        fi
        
        # Python Fallback
        python3 -c "
import socket
mac_bytes = bytes.fromhex('$RX_MAC'.replace(':', ''))
magic_packet = b'\xff' * 6 + mac_bytes * 16
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
sock.sendto(magic_packet, ('192.168.68.255', 9))
sock.close()
print('✅ Python Magic Packet gesendet')
"
        
    else
        log_message "📱 Hotspot - Wake-on-LAN über M1 Gateway"
        
        # Wake-on-LAN über M1 Mac Gateway
        local wol_cmd="
        # Python Magic Packet über M1 Gateway
        python3 -c \"
import socket
mac_bytes = bytes.fromhex('$RX_MAC'.replace(':', ''))
magic_packet = b'\xff' * 6 + mac_bytes * 16
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
sock.sendto(magic_packet, ('192.168.68.255', 9))
sock.sendto(magic_packet, ('$RX_HOST', 9))
sock.close()
print('✅ Magic Packet über M1 Gateway gesendet')
\"
        "
        
        if ssh -o ConnectTimeout=10 $M1_USER@$M1_HOST "$wol_cmd"; then
            log_message "✅ Wake-on-LAN über M1 Gateway erfolgreich"
        else
            log_message "❌ Gateway Wake-on-LAN fehlgeschlagen"
            return 1
        fi
    fi
    
    # Status überwachen
    log_message "🔄 Warte auf RX Node Bootup..."
    for i in {1..60}; do
        sleep 2
        local status=$(check_rx_status "$([[ "$network_mode" == "home" ]] && echo "direct" || echo "gateway")")
        
        if [[ "$status" == "online" ]]; then
            log_message "🎉 RX Node ist online! (nach $((i*2)) Sekunden)"
            return 0
        fi
        
        # Fortschrittsanzeige
        if [[ $((i % 5)) -eq 0 ]]; then
            echo -n " [$((i*2))s]"
        else
            echo -n "."
        fi
    done
    
    echo ""
    log_message "⏰ Timeout - RX Node antwortet nicht"
    log_message "💡 Mögliche Gründe:"
    log_message "   - Wake-on-LAN ist nicht aktiviert"
    log_message "   - RX Node benötigt mehr Zeit zum Booten"
    log_message "   - Netzwerkprobleme"
    return 1
}

# RX Node Status anzeigen
rx_status() {
    local network_mode=$(detect_network_mode)
    local current_ip=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')
    
    echo -e "${BLUE}🎯 GENTLEMAN RX Node Status${NC}"
    echo -e "${BLUE}============================${NC}"
    echo ""
    
    log_message "🌐 Netzwerk-Modus: $network_mode (IP: $current_ip)"
    log_message "🎯 RX Node: $RX_HOST"
    log_message "🔮 MAC-Adresse: $RX_MAC"
    
    local status=$(check_rx_status "$([[ "$network_mode" == "home" ]] && echo "direct" || echo "gateway")")
    
    if [[ "$status" == "online" ]]; then
        log_message "✅ RX Node Status: ONLINE"
        
        # Zusätzliche Informationen wenn online
        if [[ "$network_mode" == "home" ]]; then
            ssh -o ConnectTimeout=5 $RX_USER@$RX_HOST "echo '📊 System Info:' && uptime && echo '💾 Speicher:' && free -h | head -2" 2>/dev/null || true
        else
            ssh -o ConnectTimeout=10 $M1_USER@$M1_HOST "ssh -o ConnectTimeout=5 $RX_USER@$RX_HOST 'echo \"📊 System Info:\" && uptime && echo \"💾 Speicher:\" && free -h | head -2'" 2>/dev/null || true
        fi
    else
        log_message "❌ RX Node Status: OFFLINE"
    fi
}

# Hilfe anzeigen
show_help() {
    echo -e "${BLUE}🎯 GENTLEMAN RX Node Remote Control${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo ""
    echo "Verwendung: $0 {shutdown|wakeup|status|help}"
    echo ""
    echo "Befehle:"
    echo "  shutdown  - RX Node herunterfahren"
    echo "  wakeup    - RX Node aufwecken (Wake-on-LAN)"
    echo "  status    - RX Node Status anzeigen"
    echo "  help      - Diese Hilfe anzeigen"
    echo ""
    echo "Funktioniert sowohl im Heimnetz als auch über Hotspot (via M1 Gateway)"
}

# Hauptfunktion
main() {
    case "$1" in
        "shutdown"|"poweroff"|"halt")
            rx_shutdown
            ;;
        "wakeup"|"wake"|"start"|"bootup")
            rx_wakeup
            ;;
        "status"|"check")
            rx_status
            ;;
        "help"|"-h"|"--help"|"")
            show_help
            ;;
        *)
            echo "❌ Unbekannter Befehl: $1"
            show_help
            exit 1
            ;;
    esac
}

# Script ausführen
main "$@" 
 