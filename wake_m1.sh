#!/bin/bash

# 🔋 Schnelles M1 Mac Wake-on-LAN
# ===============================

# Konfiguration
M1_HOST="192.168.68.111"
M1_MAC="14:98:77:6d:3b:71"

echo "🔋 Wecke M1 Mac auf..."

# Netzwerk-Modus ermitteln
current_ip=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')

if [[ "$current_ip" =~ ^192\.168\.68\. ]]; then
    echo "🏠 Heimnetz - Verwende lokales Wake-on-LAN"
    
    # Lokales Wake-on-LAN
    if command -v wakeonlan >/dev/null 2>&1; then
        wakeonlan -i 192.168.68.255 $M1_MAC
        echo "✅ Magic Packet gesendet via wakeonlan"
    else
        echo "⚠️  wakeonlan nicht installiert - Verwende Python"
    fi
    
    # Python Fallback
    python3 -c "
import socket
mac_bytes = bytes.fromhex('$M1_MAC'.replace(':', ''))
magic_packet = b'\xff' * 6 + mac_bytes * 16
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
sock.sendto(magic_packet, ('192.168.68.255', 9))
sock.close()
print('✅ Python Magic Packet gesendet')
"

elif [[ "$current_ip" =~ ^172\.20\.10\. ]]; then
    echo "📱 Hotspot - Verwende Internet Wake-on-LAN"
    
    # Internet Wake-on-LAN über verschiedene Routen
    python3 -c "
import socket
import time

mac_bytes = bytes.fromhex('$M1_MAC'.replace(':', ''))
magic_packet = b'\xff' * 6 + mac_bytes * 16

# Verschiedene Ziele probieren
targets = [
    ('192.168.68.255', 9),
    ('192.168.68.1', 9),
    ('192.168.68.111', 9),
    ('255.255.255.255', 9),
    ('192.168.68.255', 7),
    ('192.168.68.1', 7)
]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

for target_ip, port in targets:
    try:
        sock.sendto(magic_packet, (target_ip, port))
        time.sleep(0.1)
    except:
        pass

sock.close()
print('✅ Internet Magic Packets gesendet')
"
else
    echo "❓ Unbekanntes Netzwerk - Versuche alle Methoden"
fi

echo "🔄 Warte 10 Sekunden und prüfe Status..."
sleep 10

if ping -c 1 -W 1000 $M1_HOST >/dev/null 2>&1; then
    echo "🎉 M1 Mac ist online!"
else
    echo "⏰ M1 Mac antwortet noch nicht - benötigt möglicherweise mehr Zeit"
    echo "💡 Versuche nochmal in 30-60 Sekunden"
fi 

# 🔋 Schnelles M1 Mac Wake-on-LAN
# ===============================

# Konfiguration
M1_HOST="192.168.68.111"
M1_MAC="14:98:77:6d:3b:71"

echo "🔋 Wecke M1 Mac auf..."

# Netzwerk-Modus ermitteln
current_ip=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | head -1 | awk '{print $2}')

if [[ "$current_ip" =~ ^192\.168\.68\. ]]; then
    echo "🏠 Heimnetz - Verwende lokales Wake-on-LAN"
    
    # Lokales Wake-on-LAN
    if command -v wakeonlan >/dev/null 2>&1; then
        wakeonlan -i 192.168.68.255 $M1_MAC
        echo "✅ Magic Packet gesendet via wakeonlan"
    else
        echo "⚠️  wakeonlan nicht installiert - Verwende Python"
    fi
    
    # Python Fallback
    python3 -c "
import socket
mac_bytes = bytes.fromhex('$M1_MAC'.replace(':', ''))
magic_packet = b'\xff' * 6 + mac_bytes * 16
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
sock.sendto(magic_packet, ('192.168.68.255', 9))
sock.close()
print('✅ Python Magic Packet gesendet')
"

elif [[ "$current_ip" =~ ^172\.20\.10\. ]]; then
    echo "📱 Hotspot - Verwende Internet Wake-on-LAN"
    
    # Internet Wake-on-LAN über verschiedene Routen
    python3 -c "
import socket
import time

mac_bytes = bytes.fromhex('$M1_MAC'.replace(':', ''))
magic_packet = b'\xff' * 6 + mac_bytes * 16

# Verschiedene Ziele probieren
targets = [
    ('192.168.68.255', 9),
    ('192.168.68.1', 9),
    ('192.168.68.111', 9),
    ('255.255.255.255', 9),
    ('192.168.68.255', 7),
    ('192.168.68.1', 7)
]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

for target_ip, port in targets:
    try:
        sock.sendto(magic_packet, (target_ip, port))
        time.sleep(0.1)
    except:
        pass

sock.close()
print('✅ Internet Magic Packets gesendet')
"
else
    echo "❓ Unbekanntes Netzwerk - Versuche alle Methoden"
fi

echo "🔄 Warte 10 Sekunden und prüfe Status..."
sleep 10

if ping -c 1 -W 1000 $M1_HOST >/dev/null 2>&1; then
    echo "🎉 M1 Mac ist online!"
else
    echo "⏰ M1 Mac antwortet noch nicht - benötigt möglicherweise mehr Zeit"
    echo "💡 Versuche nochmal in 30-60 Sekunden"
fi 
 