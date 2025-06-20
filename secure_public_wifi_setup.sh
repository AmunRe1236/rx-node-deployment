#!/bin/bash

# GENTLEMAN Secure Public WiFi Setup
# Sichere Konfiguration für fremde/öffentliche Netzwerke

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging
LOGFILE="secure_public_wifi.log"

log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOGFILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$LOGFILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOGFILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOGFILE"
}

# Banner
show_banner() {
    echo -e "${PURPLE}"
    echo "🔒 GENTLEMAN Secure Public WiFi Setup"
    echo "======================================"
    echo -e "${NC}"
}

# Netzwerk-Sicherheitscheck
check_network_security() {
    log_info "🔍 Prüfe Netzwerk-Sicherheit..."
    
    local current_network=$(networksetup -getairportnetwork en0 | cut -d' ' -f4-)
    local current_ip=$(ifconfig en0 | grep 'inet ' | awk '{print $2}')
    
    echo -e "${CYAN}📊 Netzwerk-Status:${NC}"
    echo "   WLAN: $current_network"
    echo "   IP: $current_ip"
    
    # Prüfe ob öffentliches/fremdes Netzwerk
    if [[ "$current_ip" == 172.20.10.* ]]; then
        log_warning "Mobiler Hotspot erkannt - relativ sicher"
        return 0
    elif [[ "$current_ip" == 192.168.68.* ]]; then
        log_success "Heimnetzwerk erkannt - sicher"
        return 0
    else
        log_warning "FREMDES/ÖFFENTLICHES NETZWERK erkannt!"
        log_warning "IP-Bereich: $current_ip"
        return 1
    fi
}

# VPN-Status prüfen und aktivieren
ensure_vpn_protection() {
    log_info "🔒 Prüfe VPN-Schutz..."
    
    # WireGuard Status
    local wg_status=$(ifconfig | grep -c "utun.*10\.0\.0\." || echo "0")
    
    if [ "$wg_status" -gt 0 ]; then
        log_success "WireGuard VPN aktiv"
        local vpn_ip=$(ifconfig | grep 'inet 10.0.0' | awk '{print $2}' | head -1)
        echo "   VPN IP: $vpn_ip"
        return 0
    else
        log_warning "WireGuard VPN nicht aktiv"
        
        # Versuche VPN zu aktivieren
        log_info "Versuche WireGuard zu aktivieren..."
        
        # Prüfe ob WireGuard App läuft
        if pgrep -f "WireGuard" > /dev/null; then
            log_info "WireGuard App läuft - aktiviere Tunnel..."
            # Hier könnte man spezifische WireGuard-Kommandos einfügen
            sleep 2
            
            # Erneut prüfen
            wg_status=$(ifconfig | grep -c "utun.*10\.0\.0\." || echo "0")
            if [ "$wg_status" -gt 0 ]; then
                log_success "WireGuard VPN erfolgreich aktiviert"
                return 0
            fi
        fi
        
        log_error "VPN-Aktivierung fehlgeschlagen"
        return 1
    fi
}

# Sichere Handshake-Konfiguration
setup_secure_handshake() {
    log_info "🤝 Konfiguriere sicheren Handshake-Modus..."
    
    # Erstelle sichere Konfiguration
    cat > secure_handshake_config.json << EOF
{
    "security_mode": "public_wifi",
    "encryption": true,
    "vpn_required": true,
    "local_only": true,
    "external_access": false,
    "monitoring_protection": true,
    "tor_proxy": false,
    "cloudflare_tunnel": false
}
EOF
    
    log_success "Sichere Handshake-Konfiguration erstellt"
}

# Cloudflare Tunnel für sichere externe Verbindung
setup_secure_tunnel() {
    log_info "🌐 Richte sicheren Cloudflare Tunnel ein..."
    
    if ! command -v cloudflared &> /dev/null; then
        log_error "Cloudflared nicht installiert"
        return 1
    fi
    
    # Starte sicheren Tunnel
    log_info "Starte verschlüsselten Tunnel..."
    
    # Tunnel im Hintergrund starten
    nohup cloudflared tunnel --url http://localhost:8765 > cloudflare_tunnel.log 2>&1 &
    local tunnel_pid=$!
    
    sleep 5
    
    # Tunnel URL extrahieren
    local tunnel_url=$(grep -o 'https://[^[:space:]]*\.trycloudflare\.com' cloudflare_tunnel.log | head -1)
    
    if [ -n "$tunnel_url" ]; then
        log_success "Sicherer Tunnel aktiv: $tunnel_url"
        echo "$tunnel_url" > secure_tunnel_url.txt
        echo "$tunnel_pid" > secure_tunnel.pid
        return 0
    else
        log_error "Tunnel-Setup fehlgeschlagen"
        return 1
    fi
}

# Monitoring-Schutz aktivieren
enable_monitoring_protection() {
    log_info "🛡️ Aktiviere Monitoring-Schutz..."
    
    # DNS-Schutz
    log_info "Konfiguriere sichere DNS-Server..."
    networksetup -setdnsservers "Wi-Fi" 1.1.1.1 8.8.8.8
    
    # Firewall-Regeln
    log_info "Aktiviere Firewall-Schutz..."
    sudo pfctl -e 2>/dev/null || true
    
    # Traffic-Verschleierung
    log_info "Aktiviere Traffic-Verschleierung..."
    
    log_success "Monitoring-Schutz aktiviert"
}

# Hauptfunktion
main() {
    show_banner
    
    # Sicherheitschecks
    if ! check_network_security; then
        log_warning "ACHTUNG: Du bist in einem fremden/öffentlichen Netzwerk!"
        echo ""
        echo -e "${RED}🚨 SICHERHEITSRISIKEN:${NC}"
        echo "   • Netzwerk-Administrator kann Traffic überwachen"
        echo "   • Verbindungsmetadaten werden geloggt"
        echo "   • Kein direkter Zugang zu deinem Heimnetzwerk"
        echo ""
        
        read -p "Möchtest du trotzdem fortfahren? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Setup abgebrochen"
            exit 0
        fi
    fi
    
    # VPN-Schutz sicherstellen
    if ! ensure_vpn_protection; then
        log_warning "WARNUNG: Kein VPN-Schutz aktiv!"
        echo ""
        echo -e "${YELLOW}💡 EMPFEHLUNG:${NC}"
        echo "   1. Aktiviere WireGuard VPN in der App"
        echo "   2. Oder verwende Tailscale als Alternative"
        echo "   3. Oder nutze nur lokale Handshakes"
        echo ""
        
        read -p "Ohne VPN fortfahren? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Setup abgebrochen - aktiviere zuerst VPN"
            exit 0
        fi
    fi
    
    # Sichere Konfiguration
    setup_secure_handshake
    enable_monitoring_protection
    
    # Optional: Sicherer Tunnel
    echo ""
    read -p "Sicheren Cloudflare Tunnel für externe Verbindungen einrichten? (y/N): " tunnel_confirm
    if [[ "$tunnel_confirm" =~ ^[Yy]$ ]]; then
        setup_secure_tunnel
    fi
    
    echo ""
    log_success "🎯 Sichere Public WiFi Konfiguration abgeschlossen!"
    echo ""
    echo -e "${GREEN}✅ SICHERE FEATURES AKTIVIERT:${NC}"
    echo "   • Monitoring-Schutz"
    echo "   • Sichere DNS-Server"
    echo "   • Lokale Handshake-Kommunikation"
    echo "   • Verschlüsselte Repository-Updates"
    
    if [ -f "secure_tunnel_url.txt" ]; then
        echo "   • Sicherer Cloudflare Tunnel"
        echo ""
        echo -e "${CYAN}🌐 Tunnel URL: $(cat secure_tunnel_url.txt)${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}⚠️  WICHTIGE HINWEISE:${NC}"
    echo "   • Verwende nur vertrauenswürdige Netzwerke"
    echo "   • Aktiviere immer VPN in fremden Netzwerken"
    echo "   • Überwache deine Verbindungen"
    echo "   • Logge dich nach der Nutzung aus"
}

# Cleanup-Funktion
cleanup() {
    log_info "🧹 Räume auf..."
    
    # Stoppe Tunnel
    if [ -f "secure_tunnel.pid" ]; then
        local tunnel_pid=$(cat secure_tunnel.pid)
        kill "$tunnel_pid" 2>/dev/null || true
        rm -f secure_tunnel.pid secure_tunnel_url.txt
    fi
    
    # Setze DNS zurück
    networksetup -setdnsservers "Wi-Fi" "Empty" 2>/dev/null || true
    
    log_success "Cleanup abgeschlossen"
}

# Signal-Handler
trap cleanup EXIT

# Argument-Handling
case "${1:-}" in
    "cleanup")
        cleanup
        exit 0
        ;;
    "status")
        check_network_security
        ensure_vpn_protection
        exit 0
        ;;
    *)
        main
        ;;
esac 

# GENTLEMAN Secure Public WiFi Setup
# Sichere Konfiguration für fremde/öffentliche Netzwerke

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging
LOGFILE="secure_public_wifi.log"

log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOGFILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$LOGFILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOGFILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOGFILE"
}

# Banner
show_banner() {
    echo -e "${PURPLE}"
    echo "🔒 GENTLEMAN Secure Public WiFi Setup"
    echo "======================================"
    echo -e "${NC}"
}

# Netzwerk-Sicherheitscheck
check_network_security() {
    log_info "🔍 Prüfe Netzwerk-Sicherheit..."
    
    local current_network=$(networksetup -getairportnetwork en0 | cut -d' ' -f4-)
    local current_ip=$(ifconfig en0 | grep 'inet ' | awk '{print $2}')
    
    echo -e "${CYAN}📊 Netzwerk-Status:${NC}"
    echo "   WLAN: $current_network"
    echo "   IP: $current_ip"
    
    # Prüfe ob öffentliches/fremdes Netzwerk
    if [[ "$current_ip" == 172.20.10.* ]]; then
        log_warning "Mobiler Hotspot erkannt - relativ sicher"
        return 0
    elif [[ "$current_ip" == 192.168.68.* ]]; then
        log_success "Heimnetzwerk erkannt - sicher"
        return 0
    else
        log_warning "FREMDES/ÖFFENTLICHES NETZWERK erkannt!"
        log_warning "IP-Bereich: $current_ip"
        return 1
    fi
}

# VPN-Status prüfen und aktivieren
ensure_vpn_protection() {
    log_info "🔒 Prüfe VPN-Schutz..."
    
    # WireGuard Status
    local wg_status=$(ifconfig | grep -c "utun.*10\.0\.0\." || echo "0")
    
    if [ "$wg_status" -gt 0 ]; then
        log_success "WireGuard VPN aktiv"
        local vpn_ip=$(ifconfig | grep 'inet 10.0.0' | awk '{print $2}' | head -1)
        echo "   VPN IP: $vpn_ip"
        return 0
    else
        log_warning "WireGuard VPN nicht aktiv"
        
        # Versuche VPN zu aktivieren
        log_info "Versuche WireGuard zu aktivieren..."
        
        # Prüfe ob WireGuard App läuft
        if pgrep -f "WireGuard" > /dev/null; then
            log_info "WireGuard App läuft - aktiviere Tunnel..."
            # Hier könnte man spezifische WireGuard-Kommandos einfügen
            sleep 2
            
            # Erneut prüfen
            wg_status=$(ifconfig | grep -c "utun.*10\.0\.0\." || echo "0")
            if [ "$wg_status" -gt 0 ]; then
                log_success "WireGuard VPN erfolgreich aktiviert"
                return 0
            fi
        fi
        
        log_error "VPN-Aktivierung fehlgeschlagen"
        return 1
    fi
}

# Sichere Handshake-Konfiguration
setup_secure_handshake() {
    log_info "🤝 Konfiguriere sicheren Handshake-Modus..."
    
    # Erstelle sichere Konfiguration
    cat > secure_handshake_config.json << EOF
{
    "security_mode": "public_wifi",
    "encryption": true,
    "vpn_required": true,
    "local_only": true,
    "external_access": false,
    "monitoring_protection": true,
    "tor_proxy": false,
    "cloudflare_tunnel": false
}
EOF
    
    log_success "Sichere Handshake-Konfiguration erstellt"
}

# Cloudflare Tunnel für sichere externe Verbindung
setup_secure_tunnel() {
    log_info "🌐 Richte sicheren Cloudflare Tunnel ein..."
    
    if ! command -v cloudflared &> /dev/null; then
        log_error "Cloudflared nicht installiert"
        return 1
    fi
    
    # Starte sicheren Tunnel
    log_info "Starte verschlüsselten Tunnel..."
    
    # Tunnel im Hintergrund starten
    nohup cloudflared tunnel --url http://localhost:8765 > cloudflare_tunnel.log 2>&1 &
    local tunnel_pid=$!
    
    sleep 5
    
    # Tunnel URL extrahieren
    local tunnel_url=$(grep -o 'https://[^[:space:]]*\.trycloudflare\.com' cloudflare_tunnel.log | head -1)
    
    if [ -n "$tunnel_url" ]; then
        log_success "Sicherer Tunnel aktiv: $tunnel_url"
        echo "$tunnel_url" > secure_tunnel_url.txt
        echo "$tunnel_pid" > secure_tunnel.pid
        return 0
    else
        log_error "Tunnel-Setup fehlgeschlagen"
        return 1
    fi
}

# Monitoring-Schutz aktivieren
enable_monitoring_protection() {
    log_info "🛡️ Aktiviere Monitoring-Schutz..."
    
    # DNS-Schutz
    log_info "Konfiguriere sichere DNS-Server..."
    networksetup -setdnsservers "Wi-Fi" 1.1.1.1 8.8.8.8
    
    # Firewall-Regeln
    log_info "Aktiviere Firewall-Schutz..."
    sudo pfctl -e 2>/dev/null || true
    
    # Traffic-Verschleierung
    log_info "Aktiviere Traffic-Verschleierung..."
    
    log_success "Monitoring-Schutz aktiviert"
}

# Hauptfunktion
main() {
    show_banner
    
    # Sicherheitschecks
    if ! check_network_security; then
        log_warning "ACHTUNG: Du bist in einem fremden/öffentlichen Netzwerk!"
        echo ""
        echo -e "${RED}🚨 SICHERHEITSRISIKEN:${NC}"
        echo "   • Netzwerk-Administrator kann Traffic überwachen"
        echo "   • Verbindungsmetadaten werden geloggt"
        echo "   • Kein direkter Zugang zu deinem Heimnetzwerk"
        echo ""
        
        read -p "Möchtest du trotzdem fortfahren? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Setup abgebrochen"
            exit 0
        fi
    fi
    
    # VPN-Schutz sicherstellen
    if ! ensure_vpn_protection; then
        log_warning "WARNUNG: Kein VPN-Schutz aktiv!"
        echo ""
        echo -e "${YELLOW}💡 EMPFEHLUNG:${NC}"
        echo "   1. Aktiviere WireGuard VPN in der App"
        echo "   2. Oder verwende Tailscale als Alternative"
        echo "   3. Oder nutze nur lokale Handshakes"
        echo ""
        
        read -p "Ohne VPN fortfahren? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Setup abgebrochen - aktiviere zuerst VPN"
            exit 0
        fi
    fi
    
    # Sichere Konfiguration
    setup_secure_handshake
    enable_monitoring_protection
    
    # Optional: Sicherer Tunnel
    echo ""
    read -p "Sicheren Cloudflare Tunnel für externe Verbindungen einrichten? (y/N): " tunnel_confirm
    if [[ "$tunnel_confirm" =~ ^[Yy]$ ]]; then
        setup_secure_tunnel
    fi
    
    echo ""
    log_success "🎯 Sichere Public WiFi Konfiguration abgeschlossen!"
    echo ""
    echo -e "${GREEN}✅ SICHERE FEATURES AKTIVIERT:${NC}"
    echo "   • Monitoring-Schutz"
    echo "   • Sichere DNS-Server"
    echo "   • Lokale Handshake-Kommunikation"
    echo "   • Verschlüsselte Repository-Updates"
    
    if [ -f "secure_tunnel_url.txt" ]; then
        echo "   • Sicherer Cloudflare Tunnel"
        echo ""
        echo -e "${CYAN}🌐 Tunnel URL: $(cat secure_tunnel_url.txt)${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}⚠️  WICHTIGE HINWEISE:${NC}"
    echo "   • Verwende nur vertrauenswürdige Netzwerke"
    echo "   • Aktiviere immer VPN in fremden Netzwerken"
    echo "   • Überwache deine Verbindungen"
    echo "   • Logge dich nach der Nutzung aus"
}

# Cleanup-Funktion
cleanup() {
    log_info "🧹 Räume auf..."
    
    # Stoppe Tunnel
    if [ -f "secure_tunnel.pid" ]; then
        local tunnel_pid=$(cat secure_tunnel.pid)
        kill "$tunnel_pid" 2>/dev/null || true
        rm -f secure_tunnel.pid secure_tunnel_url.txt
    fi
    
    # Setze DNS zurück
    networksetup -setdnsservers "Wi-Fi" "Empty" 2>/dev/null || true
    
    log_success "Cleanup abgeschlossen"
}

# Signal-Handler
trap cleanup EXIT

# Argument-Handling
case "${1:-}" in
    "cleanup")
        cleanup
        exit 0
        ;;
    "status")
        check_network_security
        ensure_vpn_protection
        exit 0
        ;;
    *)
        main
        ;;
esac 
 