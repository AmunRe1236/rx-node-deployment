#!/bin/bash

# 🔌🔋 GENTLEMAN Remote Power Control
# ===================================
# Kombiniertes Script für Remote-Shutdown und Remote-Bootup
# Unterstützt sowohl SSH (Heimnetz) als auch API (Hotspot)

# Verwende das bestehende remote_shutdown.sh als Basis
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_SHUTDOWN_SCRIPT="$SCRIPT_DIR/remote_shutdown.sh"

# Prüfe ob remote_shutdown.sh existiert
if [ ! -f "$REMOTE_SHUTDOWN_SCRIPT" ]; then
    echo "❌ remote_shutdown.sh nicht gefunden in $SCRIPT_DIR"
    exit 1
fi

# Hauptfunktion
main() {
    local action="${1:-help}"
    
    case "$action" in
        "shutdown")
            echo "🔌 Starte Remote-Shutdown..."
            "$REMOTE_SHUTDOWN_SCRIPT" shutdown
            ;;
        "bootup"|"wakeup"|"start")
            echo "🔋 Starte Remote-Bootup..."
            bootup_system
            ;;
        "status")
            echo "📊 System-Status wird geprüft..."
            
            # Netzwerk-Modus erkennen
            local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
            local network_mode="unknown"
            
            if [[ "$current_ip" =~ ^192\.168\.68\. ]]; then
                network_mode="home"
            elif [[ "$current_ip" =~ ^172\.20\.10\. ]]; then
                network_mode="hotspot"
            fi
            
            echo
            echo "🌐 GENTLEMAN Power Control Status"
            echo "================================="
            echo "📍 Aktuelles Netzwerk: $network_mode (IP: $current_ip)"
            echo
            
            # M1 Mac Status prüfen
            if [ "$network_mode" = "home" ]; then
                echo "🔍 Prüfe M1 Mac Status (SSH)..."
                if ping -c 1 -W 2 192.168.68.111 >/dev/null 2>&1; then
                    echo "✅ M1 Mac: Online (192.168.68.111)"
                    
                    if ssh -o ConnectTimeout=3 -o BatchMode=yes amonbaumgartner@192.168.68.111 "echo 'SSH OK'" >/dev/null 2>&1; then
                        echo "✅ SSH-Zugriff: Verfügbar"
                    else
                        echo "⚠️ SSH-Zugriff: Nicht verfügbar"
                    fi
                else
                    echo "❌ M1 Mac: Offline oder nicht erreichbar"
                fi
            else
                echo "🔍 Prüfe M1 Mac Status (API)..."
                
                # Versuche Tunnel-URL zu finden
                local tunnel_url=""
                if [ -f /tmp/current_tunnel_url.txt ]; then
                    tunnel_url=$(cat /tmp/current_tunnel_url.txt)
                fi
                
                if [ -n "$tunnel_url" ]; then
                    echo "🌐 Tunnel-URL: $tunnel_url"
                    
                    if curl -s --connect-timeout 5 "$tunnel_url/health" >/dev/null 2>&1; then
                        echo "✅ M1 Mac: Online (über Tunnel)"
                        echo "✅ API-Zugriff: Verfügbar"
                    else
                        echo "❌ M1 Mac: Nicht über Tunnel erreichbar"
                    fi
                else
                    echo "❌ Keine Tunnel-URL verfügbar"
                fi
            fi
            
            echo
            echo "💡 Verfügbare Aktionen:"
            if [ "$network_mode" = "home" ]; then
                echo "   ./remote_power_control.sh shutdown  - M1 Mac ausschalten (SSH)"
                echo "   ./remote_power_control.sh bootup    - M1 Mac einschalten (Wake-on-LAN)"
            else
                echo "   ./remote_power_control.sh shutdown  - M1 Mac ausschalten (API)"
                echo "   ./remote_power_control.sh bootup    - M1 Mac einschalten (API)"
            fi
            echo
            ;;
        "help"|*)
            echo
            echo "🔌🔋 GENTLEMAN Remote Power Control"
            echo "===================================="
            echo
            echo "Usage: $0 {shutdown|bootup|status|help}"
            echo
            echo "Commands:"
            echo "  shutdown  - Schalte M1 Mac remote aus"
            echo "  bootup    - Schalte M1 Mac remote ein (Wake-on-LAN)"
            echo "  status    - Zeige System-Status"
            echo "  help      - Zeige diese Hilfe"
            echo
            echo "Funktionsweise:"
            echo "  📡 Heimnetz  (192.168.68.x): SSH + Wake-on-LAN"
            echo "  📱 Hotspot   (172.20.10.x):  API über Cloudflare Tunnel"
            echo "  ❓ Unbekannt: Keine Remote-Kontrolle möglich"
            echo
            echo "Beispiele:"
            echo "  $0 shutdown    # M1 Mac ausschalten"
            echo "  $0 bootup      # M1 Mac einschalten"
            echo "  $0 status      # Status prüfen"
            echo
            ;;
    esac
}

# SSH-basiertes Shutdown (funktioniert in beiden Modi)
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

# Bootup-Funktion (erweitert)
bootup_system() {
    log_message "🔋 Starte Remote-Bootup..."
    
    local network_mode=$(detect_network_mode)
    
    if [[ "$network_mode" == "home" ]]; then
        log_message "�� Heimnetz erkannt - Verwende lokales Wake-on-LAN"
        ssh_bootup
        
    elif [[ "$network_mode" == "hotspot" ]]; then
        log_message "📱 Hotspot erkannt - Verwende Hotspot Wake-on-LAN"
        
        # Neue robuste Hotspot Wake-on-LAN Methode
        if [[ -f "./hotspot_wol.sh" ]]; then
            log_message "🔋 Verwende spezielles Hotspot Wake-on-LAN..."
            ./hotspot_wol.sh
        else
            log_message "⚠️  Hotspot WoL Script nicht gefunden - Verwende Fallback"
            api_bootup
        fi
        
    else
        log_message "❓ Unbekanntes Netzwerk - Versuche alle Methoden"
        api_bootup
    fi
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 

# 🔌🔋 GENTLEMAN Remote Power Control
# ===================================
# Kombiniertes Script für Remote-Shutdown und Remote-Bootup
# Unterstützt sowohl SSH (Heimnetz) als auch API (Hotspot)

# Verwende das bestehende remote_shutdown.sh als Basis
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_SHUTDOWN_SCRIPT="$SCRIPT_DIR/remote_shutdown.sh"

# Prüfe ob remote_shutdown.sh existiert
if [ ! -f "$REMOTE_SHUTDOWN_SCRIPT" ]; then
    echo "❌ remote_shutdown.sh nicht gefunden in $SCRIPT_DIR"
    exit 1
fi

# Hauptfunktion
main() {
    local action="${1:-help}"
    
    case "$action" in
        "shutdown")
            echo "🔌 Starte Remote-Shutdown..."
            "$REMOTE_SHUTDOWN_SCRIPT" shutdown
            ;;
        "bootup"|"wakeup"|"start")
            echo "🔋 Starte Remote-Bootup..."
            bootup_system
            ;;
        "status")
            echo "📊 System-Status wird geprüft..."
            
            # Netzwerk-Modus erkennen
            local current_ip=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
            local network_mode="unknown"
            
            if [[ "$current_ip" =~ ^192\.168\.68\. ]]; then
                network_mode="home"
            elif [[ "$current_ip" =~ ^172\.20\.10\. ]]; then
                network_mode="hotspot"
            fi
            
            echo
            echo "🌐 GENTLEMAN Power Control Status"
            echo "================================="
            echo "📍 Aktuelles Netzwerk: $network_mode (IP: $current_ip)"
            echo
            
            # M1 Mac Status prüfen
            if [ "$network_mode" = "home" ]; then
                echo "🔍 Prüfe M1 Mac Status (SSH)..."
                if ping -c 1 -W 2 192.168.68.111 >/dev/null 2>&1; then
                    echo "✅ M1 Mac: Online (192.168.68.111)"
                    
                    if ssh -o ConnectTimeout=3 -o BatchMode=yes amonbaumgartner@192.168.68.111 "echo 'SSH OK'" >/dev/null 2>&1; then
                        echo "✅ SSH-Zugriff: Verfügbar"
                    else
                        echo "⚠️ SSH-Zugriff: Nicht verfügbar"
                    fi
                else
                    echo "❌ M1 Mac: Offline oder nicht erreichbar"
                fi
            else
                echo "🔍 Prüfe M1 Mac Status (API)..."
                
                # Versuche Tunnel-URL zu finden
                local tunnel_url=""
                if [ -f /tmp/current_tunnel_url.txt ]; then
                    tunnel_url=$(cat /tmp/current_tunnel_url.txt)
                fi
                
                if [ -n "$tunnel_url" ]; then
                    echo "🌐 Tunnel-URL: $tunnel_url"
                    
                    if curl -s --connect-timeout 5 "$tunnel_url/health" >/dev/null 2>&1; then
                        echo "✅ M1 Mac: Online (über Tunnel)"
                        echo "✅ API-Zugriff: Verfügbar"
                    else
                        echo "❌ M1 Mac: Nicht über Tunnel erreichbar"
                    fi
                else
                    echo "❌ Keine Tunnel-URL verfügbar"
                fi
            fi
            
            echo
            echo "💡 Verfügbare Aktionen:"
            if [ "$network_mode" = "home" ]; then
                echo "   ./remote_power_control.sh shutdown  - M1 Mac ausschalten (SSH)"
                echo "   ./remote_power_control.sh bootup    - M1 Mac einschalten (Wake-on-LAN)"
            else
                echo "   ./remote_power_control.sh shutdown  - M1 Mac ausschalten (API)"
                echo "   ./remote_power_control.sh bootup    - M1 Mac einschalten (API)"
            fi
            echo
            ;;
        "help"|*)
            echo
            echo "🔌🔋 GENTLEMAN Remote Power Control"
            echo "===================================="
            echo
            echo "Usage: $0 {shutdown|bootup|status|help}"
            echo
            echo "Commands:"
            echo "  shutdown  - Schalte M1 Mac remote aus"
            echo "  bootup    - Schalte M1 Mac remote ein (Wake-on-LAN)"
            echo "  status    - Zeige System-Status"
            echo "  help      - Zeige diese Hilfe"
            echo
            echo "Funktionsweise:"
            echo "  📡 Heimnetz  (192.168.68.x): SSH + Wake-on-LAN"
            echo "  📱 Hotspot   (172.20.10.x):  API über Cloudflare Tunnel"
            echo "  ❓ Unbekannt: Keine Remote-Kontrolle möglich"
            echo
            echo "Beispiele:"
            echo "  $0 shutdown    # M1 Mac ausschalten"
            echo "  $0 bootup      # M1 Mac einschalten"
            echo "  $0 status      # Status prüfen"
            echo
            ;;
    esac
}

# SSH-basiertes Shutdown (funktioniert in beiden Modi)
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

# Bootup-Funktion (erweitert)
bootup_system() {
    log_message "🔋 Starte Remote-Bootup..."
    
    local network_mode=$(detect_network_mode)
    
    if [[ "$network_mode" == "home" ]]; then
        log_message "�� Heimnetz erkannt - Verwende lokales Wake-on-LAN"
        ssh_bootup
        
    elif [[ "$network_mode" == "hotspot" ]]; then
        log_message "📱 Hotspot erkannt - Verwende Hotspot Wake-on-LAN"
        
        # Neue robuste Hotspot Wake-on-LAN Methode
        if [[ -f "./hotspot_wol.sh" ]]; then
            log_message "🔋 Verwende spezielles Hotspot Wake-on-LAN..."
            ./hotspot_wol.sh
        else
            log_message "⚠️  Hotspot WoL Script nicht gefunden - Verwende Fallback"
            api_bootup
        fi
        
    else
        log_message "❓ Unbekanntes Netzwerk - Versuche alle Methoden"
        api_bootup
    fi
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 
 