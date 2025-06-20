#!/bin/bash

# 🔋 GENTLEMAN Hotspot Wake-on-LAN
# ================================
# Robustes Wake-on-LAN über Hotspot-Verbindungen
# Verwendet mehrere Methoden für maximale Erfolgsrate

set -e

# Konfiguration
M1_HOST="192.168.68.111"
M1_MAC="14:98:77:6d:3b:71"  # M1 Mac MAC-Adresse (korrekt ermittelt)
ROUTER_IP="192.168.68.1"
BROADCAST_IP="192.168.68.255"
LOG_FILE="/tmp/hotspot_wol.log"

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

# MAC-Adresse automatisch ermitteln
get_m1_mac_address() {
    # Versuche verschiedene Methoden
    local mac_addr=""
    
    # Methode 1: ARP-Tabelle
    mac_addr=$(arp -n $M1_HOST 2>/dev/null | grep -o -E '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
    
    if [[ -n "$mac_addr" ]]; then
        echo "$mac_addr"
        return 0
    fi
    
    # Methode 2: Fallback auf gespeicherte MAC
    echo "$M1_MAC"
}

# Wake-on-LAN Magic Packet senden
send_wol_packet() {
    local mac_address="$1"
    local target_ip="$2"
    local method="$3"
    
    log_message "🔮 Sende Magic Packet ($method) an $mac_address -> $target_ip"
    
    # Methode 1: wakeonlan Tool (wenn installiert)
    if command -v wakeonlan >/dev/null 2>&1; then
        wakeonlan -i "$target_ip" "$mac_address" 2>/dev/null && \
        log_message "✅ Magic Packet gesendet via wakeonlan" || \
        log_message "⚠️  wakeonlan fehlgeschlagen"
    fi
    
    # Methode 2: Python-basiertes Magic Packet
    python3 -c "
import socket
import struct

def send_magic_packet(mac_address, target_ip):
    # MAC-Adresse in Bytes konvertieren
    mac_bytes = bytes.fromhex(mac_address.replace(':', ''))
    
    # Magic Packet erstellen (6x 0xFF + 16x MAC-Adresse)
    magic_packet = b'\xff' * 6 + mac_bytes * 16
    
    # Socket erstellen und senden
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    
    try:
        # An verschiedene Ports senden
        for port in [7, 9, 40000]:
            sock.sendto(magic_packet, (target_ip, port))
        print('✅ Python Magic Packet gesendet')
        return True
    except Exception as e:
        print(f'❌ Python Magic Packet Fehler: {e}')
        return False
    finally:
        sock.close()

send_magic_packet('$mac_address', '$target_ip')
" && log_message "✅ Python Magic Packet erfolgreich" || log_message "⚠️  Python Magic Packet fehlgeschlagen"
}

# Internet-basiertes Wake-on-LAN
internet_wol() {
    local mac_address=$(get_m1_mac_address)
    
    log_message "🌐 Internet Wake-on-LAN für MAC: $mac_address"
    
    # Strategie 1: Broadcast an verschiedene Netzwerke
    log_message "📡 Strategie 1: Broadcast-Methode"
    
    # Bekannte Netzwerk-Broadcasts
    local broadcast_targets=(
        "192.168.68.255"   # Heimnetz Broadcast
        "192.168.1.255"    # Häufiges Heimnetz
        "192.168.0.255"    # Alternatives Heimnetz
        "255.255.255.255"  # Global Broadcast
    )
    
    for target in "${broadcast_targets[@]}"; do
        send_wol_packet "$mac_address" "$target" "Broadcast-$target"
    done
    
    # Strategie 2: Direkte Router-Adresse
    log_message "📡 Strategie 2: Router-Methode"
    send_wol_packet "$mac_address" "$ROUTER_IP" "Router"
    
    # Strategie 3: Spezifische M1 IP
    log_message "📡 Strategie 3: Direkte IP-Methode"
    send_wol_packet "$mac_address" "$M1_HOST" "Direct-IP"
    
    # Strategie 4: UDP-Flooding (mehr Ports)
    log_message "📡 Strategie 4: Multi-Port-Methode"
    python3 -c "
import socket
import time

mac_address = '$mac_address'
mac_bytes = bytes.fromhex(mac_address.replace(':', ''))
magic_packet = b'\xff' * 6 + mac_bytes * 16

# Verschiedene Ziele und Ports
targets = [
    ('192.168.68.255', [7, 9, 40000, 2304, 32767]),
    ('192.168.68.1', [7, 9, 40000, 2304, 32767]),
    ('192.168.68.111', [7, 9, 40000, 2304, 32767])
]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

try:
    for target_ip, ports in targets:
        for port in ports:
            try:
                sock.sendto(magic_packet, (target_ip, port))
                time.sleep(0.1)
            except:
                pass
    print('✅ Multi-Port Magic Packets gesendet')
except Exception as e:
    print(f'❌ Multi-Port Fehler: {e}')
finally:
    sock.close()
"
}

# Hauptfunktion
main() {
    echo -e "${BLUE}🔋 GENTLEMAN Hotspot Wake-on-LAN${NC}"
    echo -e "${BLUE}===================================${NC}"
    
    local network_mode=$(detect_network_mode)
    local current_ip=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')
    
    log_message "🌐 Netzwerk-Modus: $network_mode (IP: $current_ip)"
    
    if [[ "$network_mode" == "home" ]]; then
        log_message "🏠 Heimnetz erkannt - Verwende lokales Wake-on-LAN"
        local mac_address=$(get_m1_mac_address)
        send_wol_packet "$mac_address" "$BROADCAST_IP" "Local-Broadcast"
        
    elif [[ "$network_mode" == "hotspot" ]]; then
        log_message "📱 Hotspot erkannt - Verwende Internet Wake-on-LAN"
        internet_wol
        
    else
        log_message "❓ Unbekanntes Netzwerk - Versuche alle Methoden"
        internet_wol
    fi
    
    log_message "🔄 Wake-on-LAN Pakete gesendet - Warte auf M1 Mac Bootup..."
    
    # Warte und prüfe Status
    for i in {1..30}; do
        echo -n "."
        sleep 2
        
        # Prüfe alle 10 Sekunden
        if [[ $((i % 5)) -eq 0 ]]; then
            if ping -c 1 -W 1000 $M1_HOST >/dev/null 2>&1; then
                log_message "🎉 M1 Mac ist online! (nach $((i*2)) Sekunden)"
                return 0
            fi
        fi
    done
    
    echo ""
    log_message "⏰ Timeout erreicht - M1 Mac antwortet nicht"
    log_message "💡 Mögliche Gründe:"
    log_message "   - Wake-on-LAN ist nicht aktiviert"
    log_message "   - M1 Mac ist nicht im Heimnetz"
    log_message "   - Router blockiert Wake-on-LAN Pakete"
    log_message "   - M1 Mac benötigt mehr Zeit zum Booten"
    
    return 1
}

# Script ausführen
main "$@" 

# 🔋 GENTLEMAN Hotspot Wake-on-LAN
# ================================
# Robustes Wake-on-LAN über Hotspot-Verbindungen
# Verwendet mehrere Methoden für maximale Erfolgsrate

set -e

# Konfiguration
M1_HOST="192.168.68.111"
M1_MAC="14:98:77:6d:3b:71"  # M1 Mac MAC-Adresse (korrekt ermittelt)
ROUTER_IP="192.168.68.1"
BROADCAST_IP="192.168.68.255"
LOG_FILE="/tmp/hotspot_wol.log"

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

# MAC-Adresse automatisch ermitteln
get_m1_mac_address() {
    # Versuche verschiedene Methoden
    local mac_addr=""
    
    # Methode 1: ARP-Tabelle
    mac_addr=$(arp -n $M1_HOST 2>/dev/null | grep -o -E '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
    
    if [[ -n "$mac_addr" ]]; then
        echo "$mac_addr"
        return 0
    fi
    
    # Methode 2: Fallback auf gespeicherte MAC
    echo "$M1_MAC"
}

# Wake-on-LAN Magic Packet senden
send_wol_packet() {
    local mac_address="$1"
    local target_ip="$2"
    local method="$3"
    
    log_message "🔮 Sende Magic Packet ($method) an $mac_address -> $target_ip"
    
    # Methode 1: wakeonlan Tool (wenn installiert)
    if command -v wakeonlan >/dev/null 2>&1; then
        wakeonlan -i "$target_ip" "$mac_address" 2>/dev/null && \
        log_message "✅ Magic Packet gesendet via wakeonlan" || \
        log_message "⚠️  wakeonlan fehlgeschlagen"
    fi
    
    # Methode 2: Python-basiertes Magic Packet
    python3 -c "
import socket
import struct

def send_magic_packet(mac_address, target_ip):
    # MAC-Adresse in Bytes konvertieren
    mac_bytes = bytes.fromhex(mac_address.replace(':', ''))
    
    # Magic Packet erstellen (6x 0xFF + 16x MAC-Adresse)
    magic_packet = b'\xff' * 6 + mac_bytes * 16
    
    # Socket erstellen und senden
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    
    try:
        # An verschiedene Ports senden
        for port in [7, 9, 40000]:
            sock.sendto(magic_packet, (target_ip, port))
        print('✅ Python Magic Packet gesendet')
        return True
    except Exception as e:
        print(f'❌ Python Magic Packet Fehler: {e}')
        return False
    finally:
        sock.close()

send_magic_packet('$mac_address', '$target_ip')
" && log_message "✅ Python Magic Packet erfolgreich" || log_message "⚠️  Python Magic Packet fehlgeschlagen"
}

# Internet-basiertes Wake-on-LAN
internet_wol() {
    local mac_address=$(get_m1_mac_address)
    
    log_message "🌐 Internet Wake-on-LAN für MAC: $mac_address"
    
    # Strategie 1: Broadcast an verschiedene Netzwerke
    log_message "📡 Strategie 1: Broadcast-Methode"
    
    # Bekannte Netzwerk-Broadcasts
    local broadcast_targets=(
        "192.168.68.255"   # Heimnetz Broadcast
        "192.168.1.255"    # Häufiges Heimnetz
        "192.168.0.255"    # Alternatives Heimnetz
        "255.255.255.255"  # Global Broadcast
    )
    
    for target in "${broadcast_targets[@]}"; do
        send_wol_packet "$mac_address" "$target" "Broadcast-$target"
    done
    
    # Strategie 2: Direkte Router-Adresse
    log_message "📡 Strategie 2: Router-Methode"
    send_wol_packet "$mac_address" "$ROUTER_IP" "Router"
    
    # Strategie 3: Spezifische M1 IP
    log_message "📡 Strategie 3: Direkte IP-Methode"
    send_wol_packet "$mac_address" "$M1_HOST" "Direct-IP"
    
    # Strategie 4: UDP-Flooding (mehr Ports)
    log_message "📡 Strategie 4: Multi-Port-Methode"
    python3 -c "
import socket
import time

mac_address = '$mac_address'
mac_bytes = bytes.fromhex(mac_address.replace(':', ''))
magic_packet = b'\xff' * 6 + mac_bytes * 16

# Verschiedene Ziele und Ports
targets = [
    ('192.168.68.255', [7, 9, 40000, 2304, 32767]),
    ('192.168.68.1', [7, 9, 40000, 2304, 32767]),
    ('192.168.68.111', [7, 9, 40000, 2304, 32767])
]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

try:
    for target_ip, ports in targets:
        for port in ports:
            try:
                sock.sendto(magic_packet, (target_ip, port))
                time.sleep(0.1)
            except:
                pass
    print('✅ Multi-Port Magic Packets gesendet')
except Exception as e:
    print(f'❌ Multi-Port Fehler: {e}')
finally:
    sock.close()
"
}

# Hauptfunktion
main() {
    echo -e "${BLUE}🔋 GENTLEMAN Hotspot Wake-on-LAN${NC}"
    echo -e "${BLUE}===================================${NC}"
    
    local network_mode=$(detect_network_mode)
    local current_ip=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')
    
    log_message "🌐 Netzwerk-Modus: $network_mode (IP: $current_ip)"
    
    if [[ "$network_mode" == "home" ]]; then
        log_message "🏠 Heimnetz erkannt - Verwende lokales Wake-on-LAN"
        local mac_address=$(get_m1_mac_address)
        send_wol_packet "$mac_address" "$BROADCAST_IP" "Local-Broadcast"
        
    elif [[ "$network_mode" == "hotspot" ]]; then
        log_message "📱 Hotspot erkannt - Verwende Internet Wake-on-LAN"
        internet_wol
        
    else
        log_message "❓ Unbekanntes Netzwerk - Versuche alle Methoden"
        internet_wol
    fi
    
    log_message "🔄 Wake-on-LAN Pakete gesendet - Warte auf M1 Mac Bootup..."
    
    # Warte und prüfe Status
    for i in {1..30}; do
        echo -n "."
        sleep 2
        
        # Prüfe alle 10 Sekunden
        if [[ $((i % 5)) -eq 0 ]]; then
            if ping -c 1 -W 1000 $M1_HOST >/dev/null 2>&1; then
                log_message "🎉 M1 Mac ist online! (nach $((i*2)) Sekunden)"
                return 0
            fi
        fi
    done
    
    echo ""
    log_message "⏰ Timeout erreicht - M1 Mac antwortet nicht"
    log_message "💡 Mögliche Gründe:"
    log_message "   - Wake-on-LAN ist nicht aktiviert"
    log_message "   - M1 Mac ist nicht im Heimnetz"
    log_message "   - Router blockiert Wake-on-LAN Pakete"
    log_message "   - M1 Mac benötigt mehr Zeit zum Booten"
    
    return 1
}

# Script ausführen
main "$@" 
 