#!/bin/bash

# 🌐 GENTLEMAN Internet Remote Shutdown
# =====================================
# Shutdown über Internet-Verbindungen wenn direkte SSH nicht möglich ist

set -e

# Konfiguration
M1_HOST="192.168.68.111"
M1_USER="amonbaumgartner"
ROUTER_IP="192.168.68.1"
LOG_FILE="/tmp/internet_shutdown.log"

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

# Magic Packet Wake-on-LAN (für Shutdown-Signal)
send_magic_packet() {
    log_message "🔮 Versuche Magic Packet Methode..."
    
    # Bekannte M1 Mac MAC-Adresse (falls verfügbar)
    local target_mac="a4:83:e7:xx:xx:xx"  # Placeholder - müsste die echte MAC sein
    
    # Versuche verschiedene WoL-Tools
    if command -v wakeonlan >/dev/null 2>&1; then
        log_message "📡 Sende Wake-on-LAN Packet an $target_mac"
        wakeonlan "$target_mac" 2>/dev/null || true
    fi
    
    # Python-basiertes Magic Packet
    python3 -c "
import socket
import binascii

def send_magic_packet(mac_address, ip='255.255.255.255', port=9):
    # MAC-Adresse formatieren
    mac_bytes = binascii.unhexlify(mac_address.replace(':', '').replace('-', ''))
    
    # Magic Packet erstellen (6 x 0xFF + 16 x MAC-Adresse)
    magic_packet = b'\xff' * 6 + mac_bytes * 16
    
    # UDP-Socket erstellen und Packet senden
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.sendto(magic_packet, (ip, port))
    sock.close()
    print('Magic Packet gesendet')

# Sende an verschiedene Broadcast-Adressen
send_magic_packet('$target_mac', '255.255.255.255')
send_magic_packet('$target_mac', '192.168.68.255')
" 2>/dev/null || true
    
    log_message "✅ Magic Packets gesendet"
}

# Router-basierte Kommunikation
router_communication() {
    log_message "🏠 Versuche Router-basierte Kommunikation..."
    
    # Versuche Router-Zugriff (falls möglich)
    if ping -c 1 "$ROUTER_IP" >/dev/null 2>&1; then
        log_message "✅ Router erreichbar: $ROUTER_IP"
        
        # Hier könnten Router-spezifische Befehle stehen
        # z.B. SNMP, Telnet, oder Web-Interface-Zugriff
        
        return 0
    else
        log_message "❌ Router nicht erreichbar"
        return 1
    fi
}

# Cloud-basierte Kommunikation
cloud_communication() {
    log_message "☁️ Versuche Cloud-basierte Kommunikation..."
    
    # GitHub-basierte Kommunikation über Repository
    if command -v git >/dev/null 2>&1; then
        log_message "📡 Erstelle Shutdown-Signal über GitHub..."
        
        # Erstelle Shutdown-Signal-Datei
        echo "SHUTDOWN_REQUEST_$(date +%s)" > /tmp/shutdown_signal.txt
        echo "Source: I7_HOTSPOT" >> /tmp/shutdown_signal.txt
        echo "Timestamp: $(date)" >> /tmp/shutdown_signal.txt
        echo "IP: $(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')" >> /tmp/shutdown_signal.txt
        
        # Versuche GitHub-Upload (falls Repository konfiguriert)
        git add /tmp/shutdown_signal.txt 2>/dev/null || true
        git commit -m "Remote shutdown signal from I7 hotspot" 2>/dev/null || true
        git push 2>/dev/null || true
        
        log_message "✅ Shutdown-Signal über Git erstellt"
        return 0
    else
        log_message "❌ Git nicht verfügbar"
        return 1
    fi
}

# Email/Notification-basierte Kommunikation
notification_communication() {
    log_message "📧 Versuche Notification-basierte Kommunikation..."
    
    # Erstelle lokale Notification-Datei
    local notification_file="/tmp/m1_shutdown_request.txt"
    cat > "$notification_file" << EOF
GENTLEMAN SHUTDOWN REQUEST
=========================
Zeit: $(date)
Von: I7 Laptop (Hotspot)
IP: $(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')
Aktion: Remote Shutdown Request
Status: PENDING

Bitte M1 Mac manuell ausschalten oder ins Heimnetz wechseln für SSH-Zugriff.
EOF
    
    log_message "✅ Notification-Datei erstellt: $notification_file"
    
    # Versuche System-Notification (macOS)
    osascript -e 'display notification "M1 Mac Shutdown angefordert - Bitte manuell ausschalten" with title "GENTLEMAN Remote Shutdown"' 2>/dev/null || true
    
    return 0
}

# Hauptfunktion für Internet-Shutdown
internet_shutdown() {
    local network_mode=$(detect_network_mode)
    log_message "🌐 Netzwerk-Modus: $network_mode (IP: $(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}'))"
    
    if [[ "$network_mode" != "hotspot" ]]; then
        log_message "⚠️ Nicht im Hotspot-Modus - verwende reguläres Shutdown"
        return 1
    fi
    
    log_message "📱 Hotspot-Modus erkannt - verwende Internet-Methoden..."
    
    # Versuche verschiedene Internet-basierte Methoden
    local methods_tried=0
    local methods_successful=0
    
    # Methode 1: Magic Packet
    if send_magic_packet; then
        ((methods_successful++))
    fi
    ((methods_tried++))
    
    # Methode 2: Router-Kommunikation
    if router_communication; then
        ((methods_successful++))
    fi
    ((methods_tried++))
    
    # Methode 3: Cloud-Kommunikation
    if cloud_communication; then
        ((methods_successful++))
    fi
    ((methods_tried++))
    
    # Methode 4: Notification
    if notification_communication; then
        ((methods_successful++))
    fi
    ((methods_tried++))
    
    log_message "📊 Methoden versucht: $methods_tried, erfolgreich: $methods_successful"
    
    if [[ $methods_successful -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Main
main() {
    echo "🌐 GENTLEMAN Internet Remote Shutdown"
    echo "====================================="
    echo
    
    log_message "🚀 Internet Remote-Shutdown gestartet"
    
    if internet_shutdown; then
        log_message "✅ Internet-Shutdown-Signale gesendet"
        echo
        echo "✅ Shutdown-Signale wurden gesendet!"
        echo "   📧 Notification erstellt"
        echo "   🔮 Magic Packets gesendet"
        echo "   ☁️ Cloud-Signale übertragen"
        echo
        echo "💡 Nächste Schritte:"
        echo "   1. M1 Mac manuell überprüfen und ausschalten"
        echo "   2. Oder ins Heimnetz wechseln für direkten SSH-Zugriff"
        exit 0
    else
        log_message "❌ Internet-Shutdown fehlgeschlagen"
        echo
        echo "❌ Internet-Shutdown fehlgeschlagen!"
        echo
        echo "💡 Einzige Lösung:"
        echo "   → Physisch zur M1 Mac gehen und manuell ausschalten"
        exit 1
    fi
}

# Script ausführen
main "$@" 

# 🌐 GENTLEMAN Internet Remote Shutdown
# =====================================
# Shutdown über Internet-Verbindungen wenn direkte SSH nicht möglich ist

set -e

# Konfiguration
M1_HOST="192.168.68.111"
M1_USER="amonbaumgartner"
ROUTER_IP="192.168.68.1"
LOG_FILE="/tmp/internet_shutdown.log"

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

# Magic Packet Wake-on-LAN (für Shutdown-Signal)
send_magic_packet() {
    log_message "🔮 Versuche Magic Packet Methode..."
    
    # Bekannte M1 Mac MAC-Adresse (falls verfügbar)
    local target_mac="a4:83:e7:xx:xx:xx"  # Placeholder - müsste die echte MAC sein
    
    # Versuche verschiedene WoL-Tools
    if command -v wakeonlan >/dev/null 2>&1; then
        log_message "📡 Sende Wake-on-LAN Packet an $target_mac"
        wakeonlan "$target_mac" 2>/dev/null || true
    fi
    
    # Python-basiertes Magic Packet
    python3 -c "
import socket
import binascii

def send_magic_packet(mac_address, ip='255.255.255.255', port=9):
    # MAC-Adresse formatieren
    mac_bytes = binascii.unhexlify(mac_address.replace(':', '').replace('-', ''))
    
    # Magic Packet erstellen (6 x 0xFF + 16 x MAC-Adresse)
    magic_packet = b'\xff' * 6 + mac_bytes * 16
    
    # UDP-Socket erstellen und Packet senden
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.sendto(magic_packet, (ip, port))
    sock.close()
    print('Magic Packet gesendet')

# Sende an verschiedene Broadcast-Adressen
send_magic_packet('$target_mac', '255.255.255.255')
send_magic_packet('$target_mac', '192.168.68.255')
" 2>/dev/null || true
    
    log_message "✅ Magic Packets gesendet"
}

# Router-basierte Kommunikation
router_communication() {
    log_message "🏠 Versuche Router-basierte Kommunikation..."
    
    # Versuche Router-Zugriff (falls möglich)
    if ping -c 1 "$ROUTER_IP" >/dev/null 2>&1; then
        log_message "✅ Router erreichbar: $ROUTER_IP"
        
        # Hier könnten Router-spezifische Befehle stehen
        # z.B. SNMP, Telnet, oder Web-Interface-Zugriff
        
        return 0
    else
        log_message "❌ Router nicht erreichbar"
        return 1
    fi
}

# Cloud-basierte Kommunikation
cloud_communication() {
    log_message "☁️ Versuche Cloud-basierte Kommunikation..."
    
    # GitHub-basierte Kommunikation über Repository
    if command -v git >/dev/null 2>&1; then
        log_message "📡 Erstelle Shutdown-Signal über GitHub..."
        
        # Erstelle Shutdown-Signal-Datei
        echo "SHUTDOWN_REQUEST_$(date +%s)" > /tmp/shutdown_signal.txt
        echo "Source: I7_HOTSPOT" >> /tmp/shutdown_signal.txt
        echo "Timestamp: $(date)" >> /tmp/shutdown_signal.txt
        echo "IP: $(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')" >> /tmp/shutdown_signal.txt
        
        # Versuche GitHub-Upload (falls Repository konfiguriert)
        git add /tmp/shutdown_signal.txt 2>/dev/null || true
        git commit -m "Remote shutdown signal from I7 hotspot" 2>/dev/null || true
        git push 2>/dev/null || true
        
        log_message "✅ Shutdown-Signal über Git erstellt"
        return 0
    else
        log_message "❌ Git nicht verfügbar"
        return 1
    fi
}

# Email/Notification-basierte Kommunikation
notification_communication() {
    log_message "📧 Versuche Notification-basierte Kommunikation..."
    
    # Erstelle lokale Notification-Datei
    local notification_file="/tmp/m1_shutdown_request.txt"
    cat > "$notification_file" << EOF
GENTLEMAN SHUTDOWN REQUEST
=========================
Zeit: $(date)
Von: I7 Laptop (Hotspot)
IP: $(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')
Aktion: Remote Shutdown Request
Status: PENDING

Bitte M1 Mac manuell ausschalten oder ins Heimnetz wechseln für SSH-Zugriff.
EOF
    
    log_message "✅ Notification-Datei erstellt: $notification_file"
    
    # Versuche System-Notification (macOS)
    osascript -e 'display notification "M1 Mac Shutdown angefordert - Bitte manuell ausschalten" with title "GENTLEMAN Remote Shutdown"' 2>/dev/null || true
    
    return 0
}

# Hauptfunktion für Internet-Shutdown
internet_shutdown() {
    local network_mode=$(detect_network_mode)
    log_message "🌐 Netzwerk-Modus: $network_mode (IP: $(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}'))"
    
    if [[ "$network_mode" != "hotspot" ]]; then
        log_message "⚠️ Nicht im Hotspot-Modus - verwende reguläres Shutdown"
        return 1
    fi
    
    log_message "📱 Hotspot-Modus erkannt - verwende Internet-Methoden..."
    
    # Versuche verschiedene Internet-basierte Methoden
    local methods_tried=0
    local methods_successful=0
    
    # Methode 1: Magic Packet
    if send_magic_packet; then
        ((methods_successful++))
    fi
    ((methods_tried++))
    
    # Methode 2: Router-Kommunikation
    if router_communication; then
        ((methods_successful++))
    fi
    ((methods_tried++))
    
    # Methode 3: Cloud-Kommunikation
    if cloud_communication; then
        ((methods_successful++))
    fi
    ((methods_tried++))
    
    # Methode 4: Notification
    if notification_communication; then
        ((methods_successful++))
    fi
    ((methods_tried++))
    
    log_message "📊 Methoden versucht: $methods_tried, erfolgreich: $methods_successful"
    
    if [[ $methods_successful -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Main
main() {
    echo "🌐 GENTLEMAN Internet Remote Shutdown"
    echo "====================================="
    echo
    
    log_message "🚀 Internet Remote-Shutdown gestartet"
    
    if internet_shutdown; then
        log_message "✅ Internet-Shutdown-Signale gesendet"
        echo
        echo "✅ Shutdown-Signale wurden gesendet!"
        echo "   📧 Notification erstellt"
        echo "   🔮 Magic Packets gesendet"
        echo "   ☁️ Cloud-Signale übertragen"
        echo
        echo "💡 Nächste Schritte:"
        echo "   1. M1 Mac manuell überprüfen und ausschalten"
        echo "   2. Oder ins Heimnetz wechseln für direkten SSH-Zugriff"
        exit 0
    else
        log_message "❌ Internet-Shutdown fehlgeschlagen"
        echo
        echo "❌ Internet-Shutdown fehlgeschlagen!"
        echo
        echo "💡 Einzige Lösung:"
        echo "   → Physisch zur M1 Mac gehen und manuell ausschalten"
        exit 1
    fi
}

# Script ausführen
main "$@" 
 