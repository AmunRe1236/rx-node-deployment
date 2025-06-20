#!/bin/bash

# GENTLEMAN Cloudflare Zero Trust Setup
# ToS-konforme Alternative zu Quick Tunnels für interne Services

set -euo pipefail

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}❌ $1${NC}" >&2
}

log_info() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}ℹ️ $1${NC}"
}

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}⚠️ $1${NC}"
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN Cloudflare Zero Trust Setup${NC}"
    echo "========================================="
    echo ""
    
    log_warning "🚨 Cloudflare Quick Tunnels sind NICHT für interne Services geeignet!"
    echo ""
    echo -e "${RED}Cloudflare ToS Violation:${NC}"
    echo "• Exposing internal corporate intranet sites"
    echo "• Any site with proprietary or sensitive data"
    echo "• Even if it's just a test"
    echo ""
    echo -e "${GREEN}✅ Empfohlene Alternativen:${NC}"
    echo ""
    echo -e "${CYAN}1. Cloudflare Zero Trust (Kostenlos)${NC}"
    echo "   • Bis zu 50 Nutzer kostenlos"
    echo "   • ToS-konform für interne Services"
    echo "   • Professionelle Authentifizierung"
    echo "   • Setup: https://one.dash.cloudflare.com/"
    echo ""
    echo -e "${CYAN}2. WireGuard VPN (Selbst gehostet)${NC}"
    echo "   • Vollständige Kontrolle"
    echo "   • Keine externen Abhängigkeiten"
    echo "   • Moderne Verschlüsselung"
    echo "   • Setup-Anleitung verfügbar"
    echo ""
    echo -e "${CYAN}3. Tailscale (Kostenlos für persönliche Nutzung)${NC}"
    echo "   • Einfache Einrichtung"
    echo "   • Mesh-Netzwerk"
    echo "   • Zero-Config"
    echo "   • Bis zu 20 Geräte kostenlos"
    echo ""
    
    read -p "Welche Alternative möchtest du einrichten? (1/2/3): " choice
    
    case "$choice" in
        "1")
            setup_cloudflare_zero_trust
            ;;
        "2")
            setup_wireguard_vpn
            ;;
        "3")
            setup_tailscale
            ;;
        *)
            log_error "Ungültige Auswahl"
            exit 1
            ;;
    esac
}

# Cloudflare Zero Trust Setup
setup_cloudflare_zero_trust() {
    log_info "🛡️ Cloudflare Zero Trust Setup"
    echo ""
    echo "Schritte für Cloudflare Zero Trust:"
    echo ""
    echo "1. Gehe zu: https://one.dash.cloudflare.com/"
    echo "2. Erstelle ein Cloudflare Zero Trust Team"
    echo "3. Wähle den kostenlosen Plan (bis zu 50 Nutzer)"
    echo "4. Installiere cloudflared:"
    echo ""
    echo -e "${CYAN}macOS Installation:${NC}"
    echo "brew install cloudflared"
    echo ""
    echo -e "${CYAN}Ubuntu/Debian Installation:${NC}"
    echo "curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb"
    echo "sudo dpkg -i cloudflared.deb"
    echo ""
    echo "5. Authentifiziere cloudflared:"
    echo "cloudflared tunnel login"
    echo ""
    echo "6. Erstelle einen Tunnel:"
    echo "cloudflared tunnel create gentleman-tunnel"
    echo ""
    echo "7. Konfiguriere den Tunnel (config.yml):"
    echo ""
    cat << 'EOF'
tunnel: <TUNNEL-ID>
credentials-file: /path/to/credentials.json

ingress:
  - hostname: m1-api.yourteam.cloudflareaccess.com
    service: http://localhost:8765
  - hostname: rx-node.yourteam.cloudflareaccess.com  
    service: http://192.168.68.117:8765
  - service: http_status:404
EOF
    echo ""
    echo "8. Starte den Tunnel:"
    echo "cloudflared tunnel run gentleman-tunnel"
    echo ""
    echo "9. Konfiguriere Access Policies im Dashboard"
    echo "   • Nur autorisierte Benutzer"
    echo "   • E-Mail-Authentifizierung"
    echo "   • Multi-Faktor-Authentifizierung"
    echo ""
    log_success "Cloudflare Zero Trust ist ToS-konform für interne Services!"
}

# WireGuard VPN Setup
setup_wireguard_vpn() {
    log_info "🔐 WireGuard VPN Setup"
    echo ""
    echo "WireGuard bietet vollständige Kontrolle über dein VPN:"
    echo ""
    echo -e "${CYAN}Vorteile:${NC}"
    echo "• Keine externen Abhängigkeiten"
    echo "• Modernste Verschlüsselung"
    echo "• Hohe Performance"
    echo "• Vollständige Privatsphäre"
    echo ""
    echo -e "${CYAN}Setup-Optionen:${NC}"
    echo ""
    echo "1. Selbst gehostet auf eigenem Server"
    echo "2. AWS Lightsail ($5-7/Monat)"
    echo "3. DigitalOcean Droplet ($4-6/Monat)"
    echo "4. Raspberry Pi zu Hause"
    echo ""
    echo -e "${CYAN}Installation (Ubuntu):${NC}"
    echo "sudo apt update && sudo apt install wireguard"
    echo ""
    echo -e "${CYAN}Automatisches Setup mit wg-easy:${NC}"
    echo "docker run -d \\"
    echo "  --name=wg-easy \\"
    echo "  -e WG_HOST=your-domain.com \\"
    echo "  -e PASSWORD=secure-password \\"
    echo "  -v ~/.wg-easy:/etc/wireguard \\"
    echo "  -p 51820:51820/udp \\"
    echo "  -p 51821:51821/tcp \\"
    echo "  --cap-add=NET_ADMIN \\"
    echo "  --cap-add=SYS_MODULE \\"
    echo "  --sysctl=\"net.ipv4.ip_forward=1\" \\"
    echo "  --restart unless-stopped \\"
    echo "  ghcr.io/wg-easy/wg-easy"
    echo ""
    log_success "WireGuard ist die sicherste selbst gehostete Option!"
}

# Tailscale Setup  
setup_tailscale() {
    log_info "🌐 Tailscale Setup"
    echo ""
    echo "Tailscale bietet einfaches Mesh-Networking:"
    echo ""
    echo -e "${CYAN}Vorteile:${NC}"
    echo "• Zero-Config Setup"
    echo "• Bis zu 20 Geräte kostenlos"
    echo "• Automatisches NAT-Traversal"
    echo "• Basiert auf WireGuard"
    echo ""
    echo -e "${CYAN}Installation:${NC}"
    echo ""
    echo "macOS:"
    echo "brew install tailscale"
    echo ""
    echo "Ubuntu/Debian:"
    echo "curl -fsSL https://tailscale.com/install.sh | sh"
    echo ""
    echo "Windows/iOS/Android:"
    echo "Download von https://tailscale.com/download"
    echo ""
    echo -e "${CYAN}Setup:${NC}"
    echo "1. sudo tailscale up"
    echo "2. Folge dem Link zur Authentifizierung"
    echo "3. Wiederhole auf allen Geräten"
    echo ""
    echo -e "${CYAN}Subnet Routing (für Netzwerk-Zugriff):${NC}"
    echo "sudo tailscale up --advertise-routes=192.168.68.0/24"
    echo ""
    log_success "Tailscale ist die einfachste Mesh-VPN-Lösung!"
}

main "$@" 

# GENTLEMAN Cloudflare Zero Trust Setup
# ToS-konforme Alternative zu Quick Tunnels für interne Services

set -euo pipefail

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}❌ $1${NC}" >&2
}

log_info() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}ℹ️ $1${NC}"
}

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}⚠️ $1${NC}"
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN Cloudflare Zero Trust Setup${NC}"
    echo "========================================="
    echo ""
    
    log_warning "🚨 Cloudflare Quick Tunnels sind NICHT für interne Services geeignet!"
    echo ""
    echo -e "${RED}Cloudflare ToS Violation:${NC}"
    echo "• Exposing internal corporate intranet sites"
    echo "• Any site with proprietary or sensitive data"
    echo "• Even if it's just a test"
    echo ""
    echo -e "${GREEN}✅ Empfohlene Alternativen:${NC}"
    echo ""
    echo -e "${CYAN}1. Cloudflare Zero Trust (Kostenlos)${NC}"
    echo "   • Bis zu 50 Nutzer kostenlos"
    echo "   • ToS-konform für interne Services"
    echo "   • Professionelle Authentifizierung"
    echo "   • Setup: https://one.dash.cloudflare.com/"
    echo ""
    echo -e "${CYAN}2. WireGuard VPN (Selbst gehostet)${NC}"
    echo "   • Vollständige Kontrolle"
    echo "   • Keine externen Abhängigkeiten"
    echo "   • Moderne Verschlüsselung"
    echo "   • Setup-Anleitung verfügbar"
    echo ""
    echo -e "${CYAN}3. Tailscale (Kostenlos für persönliche Nutzung)${NC}"
    echo "   • Einfache Einrichtung"
    echo "   • Mesh-Netzwerk"
    echo "   • Zero-Config"
    echo "   • Bis zu 20 Geräte kostenlos"
    echo ""
    
    read -p "Welche Alternative möchtest du einrichten? (1/2/3): " choice
    
    case "$choice" in
        "1")
            setup_cloudflare_zero_trust
            ;;
        "2")
            setup_wireguard_vpn
            ;;
        "3")
            setup_tailscale
            ;;
        *)
            log_error "Ungültige Auswahl"
            exit 1
            ;;
    esac
}

# Cloudflare Zero Trust Setup
setup_cloudflare_zero_trust() {
    log_info "🛡️ Cloudflare Zero Trust Setup"
    echo ""
    echo "Schritte für Cloudflare Zero Trust:"
    echo ""
    echo "1. Gehe zu: https://one.dash.cloudflare.com/"
    echo "2. Erstelle ein Cloudflare Zero Trust Team"
    echo "3. Wähle den kostenlosen Plan (bis zu 50 Nutzer)"
    echo "4. Installiere cloudflared:"
    echo ""
    echo -e "${CYAN}macOS Installation:${NC}"
    echo "brew install cloudflared"
    echo ""
    echo -e "${CYAN}Ubuntu/Debian Installation:${NC}"
    echo "curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb"
    echo "sudo dpkg -i cloudflared.deb"
    echo ""
    echo "5. Authentifiziere cloudflared:"
    echo "cloudflared tunnel login"
    echo ""
    echo "6. Erstelle einen Tunnel:"
    echo "cloudflared tunnel create gentleman-tunnel"
    echo ""
    echo "7. Konfiguriere den Tunnel (config.yml):"
    echo ""
    cat << 'EOF'
tunnel: <TUNNEL-ID>
credentials-file: /path/to/credentials.json

ingress:
  - hostname: m1-api.yourteam.cloudflareaccess.com
    service: http://localhost:8765
  - hostname: rx-node.yourteam.cloudflareaccess.com  
    service: http://192.168.68.117:8765
  - service: http_status:404
EOF
    echo ""
    echo "8. Starte den Tunnel:"
    echo "cloudflared tunnel run gentleman-tunnel"
    echo ""
    echo "9. Konfiguriere Access Policies im Dashboard"
    echo "   • Nur autorisierte Benutzer"
    echo "   • E-Mail-Authentifizierung"
    echo "   • Multi-Faktor-Authentifizierung"
    echo ""
    log_success "Cloudflare Zero Trust ist ToS-konform für interne Services!"
}

# WireGuard VPN Setup
setup_wireguard_vpn() {
    log_info "🔐 WireGuard VPN Setup"
    echo ""
    echo "WireGuard bietet vollständige Kontrolle über dein VPN:"
    echo ""
    echo -e "${CYAN}Vorteile:${NC}"
    echo "• Keine externen Abhängigkeiten"
    echo "• Modernste Verschlüsselung"
    echo "• Hohe Performance"
    echo "• Vollständige Privatsphäre"
    echo ""
    echo -e "${CYAN}Setup-Optionen:${NC}"
    echo ""
    echo "1. Selbst gehostet auf eigenem Server"
    echo "2. AWS Lightsail ($5-7/Monat)"
    echo "3. DigitalOcean Droplet ($4-6/Monat)"
    echo "4. Raspberry Pi zu Hause"
    echo ""
    echo -e "${CYAN}Installation (Ubuntu):${NC}"
    echo "sudo apt update && sudo apt install wireguard"
    echo ""
    echo -e "${CYAN}Automatisches Setup mit wg-easy:${NC}"
    echo "docker run -d \\"
    echo "  --name=wg-easy \\"
    echo "  -e WG_HOST=your-domain.com \\"
    echo "  -e PASSWORD=secure-password \\"
    echo "  -v ~/.wg-easy:/etc/wireguard \\"
    echo "  -p 51820:51820/udp \\"
    echo "  -p 51821:51821/tcp \\"
    echo "  --cap-add=NET_ADMIN \\"
    echo "  --cap-add=SYS_MODULE \\"
    echo "  --sysctl=\"net.ipv4.ip_forward=1\" \\"
    echo "  --restart unless-stopped \\"
    echo "  ghcr.io/wg-easy/wg-easy"
    echo ""
    log_success "WireGuard ist die sicherste selbst gehostete Option!"
}

# Tailscale Setup  
setup_tailscale() {
    log_info "🌐 Tailscale Setup"
    echo ""
    echo "Tailscale bietet einfaches Mesh-Networking:"
    echo ""
    echo -e "${CYAN}Vorteile:${NC}"
    echo "• Zero-Config Setup"
    echo "• Bis zu 20 Geräte kostenlos"
    echo "• Automatisches NAT-Traversal"
    echo "• Basiert auf WireGuard"
    echo ""
    echo -e "${CYAN}Installation:${NC}"
    echo ""
    echo "macOS:"
    echo "brew install tailscale"
    echo ""
    echo "Ubuntu/Debian:"
    echo "curl -fsSL https://tailscale.com/install.sh | sh"
    echo ""
    echo "Windows/iOS/Android:"
    echo "Download von https://tailscale.com/download"
    echo ""
    echo -e "${CYAN}Setup:${NC}"
    echo "1. sudo tailscale up"
    echo "2. Folge dem Link zur Authentifizierung"
    echo "3. Wiederhole auf allen Geräten"
    echo ""
    echo -e "${CYAN}Subnet Routing (für Netzwerk-Zugriff):${NC}"
    echo "sudo tailscale up --advertise-routes=192.168.68.0/24"
    echo ""
    log_success "Tailscale ist die einfachste Mesh-VPN-Lösung!"
}

main "$@" 
 