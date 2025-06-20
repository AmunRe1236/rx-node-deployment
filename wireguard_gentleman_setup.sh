#!/bin/bash

# GENTLEMAN WireGuard Self-Hosted Setup
# Zukunftssichere Alternative zu Tailscale für Freunde-Netzwerk

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

# VPS Provider Empfehlungen
show_vps_options() {
    echo -e "${PURPLE}🌐 VPS Provider für WireGuard Server${NC}"
    echo "======================================="
    echo ""
    echo -e "${CYAN}💰 Günstige Optionen (€3-5/Monat):${NC}"
    echo "• Hetzner Cloud (Deutschland): €3.29/Monat"
    echo "• DigitalOcean (Global): $4/Monat"
    echo "• Vultr (Global): $3.50/Monat"
    echo "• Linode (Global): $5/Monat"
    echo ""
    echo -e "${CYAN}🚀 Ultra-Günstig (€1-2/Monat):${NC}"
    echo "• Contabo VPS S: €4.99/Monat (aber mehr Power)"
    echo "• OVH VPS: €3/Monat"
    echo "• Netcup VPS: €2.99/Monat"
    echo ""
    echo -e "${YELLOW}💡 Empfehlung: Hetzner Cloud (EU-Datenschutz + günstig)${NC}"
}

# WireGuard Server Setup Script (für VPS)
create_server_setup() {
    log_info "📝 Erstelle WireGuard Server Setup Script..."
    
    cat > ./wireguard_server_setup.sh << 'EOF'
#!/bin/bash

# GENTLEMAN WireGuard Server Setup (auf VPS ausführen)
# Unterstützt Ubuntu 20.04/22.04

set -euo pipefail

# Konfiguration
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_NET="10.66.66.0/24"
WG_SERVER_IP="10.66.66.1"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# System Update
update_system() {
    log_info "🔄 Aktualisiere System..."
    apt update && apt upgrade -y
    log_success "System aktualisiert"
}

# WireGuard Installation
install_wireguard() {
    log_info "📦 Installiere WireGuard..."
    apt install -y wireguard wireguard-tools qrencode
    log_success "WireGuard installiert"
}

# Server Keys generieren
generate_server_keys() {
    log_info "🔐 Generiere Server Keys..."
    cd /etc/wireguard
    
    # Server Private Key
    wg genkey | tee server_private.key | wg pubkey > server_public.key
    chmod 600 server_private.key
    
    SERVER_PRIVATE_KEY=$(cat server_private.key)
    SERVER_PUBLIC_KEY=$(cat server_public.key)
    
    log_success "Server Keys generiert"
}

# Server Konfiguration
create_server_config() {
    log_info "⚙️ Erstelle Server Konfiguration..."
    
    cat > /etc/wireguard/$WG_INTERFACE.conf << EOF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = $WG_SERVER_IP/24
ListenPort = $WG_PORT
SaveConfig = true

# NAT und Forwarding
PostUp = iptables -A FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -A FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -D FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Clients werden hier automatisch hinzugefügt
EOF

    log_success "Server Konfiguration erstellt"
}

# IP Forwarding aktivieren
enable_ip_forwarding() {
    log_info "🔄 Aktiviere IP Forwarding..."
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    sysctl -p
    log_success "IP Forwarding aktiviert"
}

# Firewall konfigurieren
configure_firewall() {
    log_info "🔥 Konfiguriere Firewall..."
    
    # UFW installieren falls nicht vorhanden
    apt install -y ufw
    
    # Firewall Rules
    ufw allow ssh
    ufw allow $WG_PORT/udp
    ufw --force enable
    
    log_success "Firewall konfiguriert"
}

# WireGuard Service starten
start_wireguard() {
    log_info "🚀 Starte WireGuard Service..."
    
    systemctl enable wg-quick@$WG_INTERFACE
    systemctl start wg-quick@$WG_INTERFACE
    
    log_success "WireGuard Service gestartet"
}

# Client Management Script erstellen
create_client_manager() {
    log_info "📝 Erstelle Client Management Script..."
    
    cat > /root/add_client.sh << 'SCRIPT'
#!/bin/bash

# GENTLEMAN WireGuard Client Hinzufügen

if [ $# -eq 0 ]; then
    echo "Verwendung: $0 <client-name>"
    echo "Beispiel: $0 amon-m1"
    exit 1
fi

CLIENT_NAME="$1"
WG_INTERFACE="wg0"
WG_NET="10.66.66.0/24"
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public.key)
SERVER_ENDPOINT="$(curl -s ifconfig.me):51820"

# Nächste verfügbare IP finden
LAST_IP=$(grep -oE "10\.66\.66\.[0-9]+" /etc/wireguard/$WG_INTERFACE.conf | sort -V | tail -1 | cut -d. -f4)
if [ -z "$LAST_IP" ]; then
    CLIENT_IP="10.66.66.2"
else
    CLIENT_IP="10.66.66.$((LAST_IP + 1))"
fi

# Client Keys generieren
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)

# Client Config erstellen
cat > /root/${CLIENT_NAME}.conf << EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/24
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_ENDPOINT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# Client zum Server hinzufügen
cat >> /etc/wireguard/$WG_INTERFACE.conf << EOF

# Client: $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_IP/32
EOF

# WireGuard neu laden
wg syncconf $WG_INTERFACE <(wg-quick strip $WG_INTERFACE)

echo "✅ Client '$CLIENT_NAME' hinzugefügt!"
echo "📱 IP: $CLIENT_IP"
echo "📄 Config: /root/${CLIENT_NAME}.conf"
echo ""
echo "🔗 QR Code für Mobile:"
qrencode -t ansiutf8 < /root/${CLIENT_NAME}.conf

echo ""
echo "📋 Config-Datei Inhalt:"
cat /root/${CLIENT_NAME}.conf
SCRIPT

    chmod +x /root/add_client.sh
    log_success "Client Manager erstellt"
}

# Status anzeigen
show_status() {
    log_info "📊 WireGuard Status:"
    echo ""
    
    # Service Status
    systemctl status wg-quick@$WG_INTERFACE --no-pager -l
    echo ""
    
    # WireGuard Status
    wg show
    echo ""
    
    # Server Info
    echo "🌐 Server Public Key: $(cat /etc/wireguard/server_public.key)"
    echo "📍 Server Endpoint: $(curl -s ifconfig.me):$WG_PORT"
    echo "🔧 Server IP: $WG_SERVER_IP"
    echo ""
    echo "➕ Client hinzufügen: /root/add_client.sh <name>"
}

# Hauptfunktion
main() {
    echo "🎯 GENTLEMAN WireGuard Server Setup"
    echo "==================================="
    echo ""
    
    # Root-Check
    if [ "$EUID" -ne 0 ]; then
        log_error "Bitte als root ausführen: sudo $0"
        exit 1
    fi
    
    update_system
    install_wireguard
    generate_server_keys
    create_server_config
    enable_ip_forwarding
    configure_firewall
    start_wireguard
    create_client_manager
    
    echo ""
    log_success "🎉 WireGuard Server Setup abgeschlossen!"
    echo ""
    show_status
    
    echo ""
    echo "🚀 Nächste Schritte:"
    echo "1. Client hinzufügen: /root/add_client.sh <name>"
    echo "2. Config-Datei an Client senden"
    echo "3. Client installiert WireGuard und importiert Config"
}

main "$@"
EOF

    chmod +x ./wireguard_server_setup.sh
    log_success "Server Setup Script erstellt"
}

# Client Setup Scripts erstellen
create_client_scripts() {
    log_info "📝 Erstelle Client Setup Scripts..."
    
    # macOS Client Setup
    cat > ./wireguard_client_macos.sh << 'EOF'
#!/bin/bash

# GENTLEMAN WireGuard Client Setup (macOS)

echo "🎯 GENTLEMAN WireGuard Client Setup (macOS)"
echo "==========================================="
echo ""

# WireGuard installieren
if ! command -v wg >/dev/null 2>&1; then
    echo "📦 Installiere WireGuard..."
    if command -v brew >/dev/null 2>&1; then
        brew install wireguard-tools
    else
        echo "❌ Homebrew nicht gefunden. Bitte installiere WireGuard manuell:"
        echo "   https://www.wireguard.com/install/"
        exit 1
    fi
fi

echo "✅ WireGuard installiert"
echo ""
echo "📋 Nächste Schritte:"
echo "1. Config-Datei vom Server-Admin erhalten"
echo "2. WireGuard App aus App Store installieren"
echo "3. Config-Datei in WireGuard App importieren"
echo "4. Verbindung aktivieren"
echo ""
echo "💡 Oder via Terminal:"
echo "   sudo wg-quick up /path/to/config.conf"
EOF

    # Linux Client Setup
    cat > ./wireguard_client_linux.sh << 'EOF'
#!/bin/bash

# GENTLEMAN WireGuard Client Setup (Linux)

echo "🎯 GENTLEMAN WireGuard Client Setup (Linux)"
echo "==========================================="
echo ""

# WireGuard installieren
echo "📦 Installiere WireGuard..."
if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y wireguard wireguard-tools
elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S wireguard-tools
elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y wireguard-tools
else
    echo "❌ Paketmanager nicht erkannt. Bitte WireGuard manuell installieren."
    exit 1
fi

echo "✅ WireGuard installiert"
echo ""
echo "📋 Verwendung:"
echo "1. Config-Datei nach /etc/wireguard/ kopieren"
echo "2. sudo wg-quick up <config-name>"
echo "3. sudo systemctl enable wg-quick@<config-name> (für Autostart)"
echo ""
echo "Beispiel:"
echo "  sudo cp client.conf /etc/wireguard/"
echo "  sudo wg-quick up client"
EOF

    chmod +x ./wireguard_client_*.sh
    log_success "Client Setup Scripts erstellt"
}

# Kosten-Kalkulator
show_cost_analysis() {
    echo -e "${PURPLE}💰 Kosten-Analyse: WireGuard vs Tailscale${NC}"
    echo "=========================================="
    echo ""
    echo -e "${GREEN}WireGuard (Self-Hosted):${NC}"
    echo "• VPS: €3-5/Monat für unbegrenzte Geräte"
    echo "• Einmalig: Setup-Zeit (1-2 Stunden)"
    echo "• Jährlich: €36-60 für alle Freunde zusammen"
    echo ""
    echo -e "${YELLOW}Tailscale (Hosted):${NC}"
    echo "• Kostenlos: Bis 20 Geräte (aktuell)"
    echo "• Risiko: Preisänderungen möglich"
    echo "• Pro Nutzer: $5/Monat bei Überschreitung"
    echo ""
    echo -e "${BLUE}Für 10 Freunde mit je 2 Geräten (20 Geräte):${NC}"
    echo "• WireGuard: €60/Jahr (€6 pro Person)"
    echo "• Tailscale: €0 (aktuell) oder €600/Jahr bei Pricing-Änderung"
    echo ""
    echo -e "${CYAN}💡 Empfehlung: WireGuard für Zukunftssicherheit${NC}"
}

# Deployment Guide
create_deployment_guide() {
    log_info "📖 Erstelle Deployment Guide..."
    
    cat > ./GENTLEMAN_WireGuard_Deployment.md << 'EOF'
# GENTLEMAN WireGuard Deployment Guide

## 🎯 Übersicht
Zukunftssichere VPN-Lösung für Freunde-Netzwerk ohne Abhängigkeit von externen Services.

## 🚀 Server Setup (1x für alle)

### 1. VPS mieten
- **Empfehlung**: Hetzner Cloud CPX11 (€3.29/Monat)
- **Mindestanforderungen**: 1 CPU, 1GB RAM, Ubuntu 22.04
- **Standort**: Deutschland (EU-Datenschutz)

### 2. Server einrichten
```bash
# Auf VPS einloggen
ssh root@your-server-ip

# Setup Script herunterladen und ausführen
curl -O https://raw.githubusercontent.com/your-repo/wireguard_server_setup.sh
chmod +x wireguard_server_setup.sh
sudo ./wireguard_server_setup.sh
```

### 3. Clients hinzufügen
```bash
# Für jeden Freund/Gerät
/root/add_client.sh amon-m1
/root/add_client.sh amon-iphone
/root/add_client.sh max-laptop
```

## 👥 Client Setup (für jeden Freund)

### macOS
```bash
# WireGuard installieren
brew install wireguard-tools

# Oder WireGuard App aus App Store
# Config-Datei importieren und verbinden
```

### Linux (Ubuntu/Arch)
```bash
# Setup Script ausführen
./wireguard_client_linux.sh

# Config importieren
sudo cp client.conf /etc/wireguard/
sudo wg-quick up client
```

### iOS/Android
1. WireGuard App installieren
2. QR-Code vom Server scannen
3. Verbindung aktivieren

## 💰 Kosten
- **Server**: €3-5/Monat für unbegrenzte Geräte
- **Pro Person**: €3-6/Jahr (bei 10 Freunden)
- **Einmalig**: Setup-Zeit (1-2 Stunden)

## 🔧 Wartung
- **Updates**: Automatisch via unattended-upgrades
- **Monitoring**: Optional via Grafana/Prometheus
- **Backup**: Config-Dateien regelmäßig sichern

## 🛡️ Sicherheit
- **Verschlüsselung**: ChaCha20Poly1305
- **Authentifizierung**: Ed25519 Keys
- **Perfect Forward Secrecy**: Ja
- **Audit**: Regelmäßig von Sicherheitsexperten geprüft

## 📱 Mobile Optimierung
- **Battery Optimized**: Minimal CPU/Battery Usage
- **Roaming**: Automatische Reconnection
- **Kill Switch**: Verhindert Daten-Leaks

## 🌍 Zukunftssicherheit
- **Open Source**: Keine Vendor Lock-in
- **Standard**: Teil des Linux Kernels
- **Community**: Große, aktive Entwickler-Community
- **Unabhängigkeit**: Keine externen Service-Abhängigkeiten
EOF

    log_success "Deployment Guide erstellt"
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN WireGuard Setup${NC}"
    echo "=============================="
    echo ""
    
    log_warning "Tailscale Pricing-Risiko erkannt - erstelle zukunftssichere Alternative!"
    echo ""
    
    show_vps_options
    echo ""
    
    show_cost_analysis
    echo ""
    
    create_server_setup
    create_client_scripts
    create_deployment_guide
    
    echo ""
    log_success "🎉 WireGuard Setup-Paket erstellt!"
    echo ""
    echo -e "${CYAN}📁 Erstellt:${NC}"
    echo "• wireguard_server_setup.sh - Server Setup"
    echo "• wireguard_client_macos.sh - macOS Client"
    echo "• wireguard_client_linux.sh - Linux Client"
    echo "• GENTLEMAN_WireGuard_Deployment.md - Vollständige Anleitung"
    echo ""
    echo -e "${YELLOW}🚀 Nächste Schritte:${NC}"
    echo "1. VPS bei Hetzner/DigitalOcean mieten"
    echo "2. wireguard_server_setup.sh auf VPS ausführen"
    echo "3. Clients für Freunde hinzufügen"
    echo "4. Config-Dateien verteilen"
    echo ""
    echo -e "${GREEN}💡 Vorteile:${NC}"
    echo "• €3-6/Jahr pro Person (bei 10 Freunden)"
    echo "• Unbegrenzte Geräte"
    echo "• Keine Vendor Lock-in"
    echo "• Zukunftssicher"
    echo "• EU-Datenschutz"
}

main "$@" 

# GENTLEMAN WireGuard Self-Hosted Setup
# Zukunftssichere Alternative zu Tailscale für Freunde-Netzwerk

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

# VPS Provider Empfehlungen
show_vps_options() {
    echo -e "${PURPLE}🌐 VPS Provider für WireGuard Server${NC}"
    echo "======================================="
    echo ""
    echo -e "${CYAN}💰 Günstige Optionen (€3-5/Monat):${NC}"
    echo "• Hetzner Cloud (Deutschland): €3.29/Monat"
    echo "• DigitalOcean (Global): $4/Monat"
    echo "• Vultr (Global): $3.50/Monat"
    echo "• Linode (Global): $5/Monat"
    echo ""
    echo -e "${CYAN}🚀 Ultra-Günstig (€1-2/Monat):${NC}"
    echo "• Contabo VPS S: €4.99/Monat (aber mehr Power)"
    echo "• OVH VPS: €3/Monat"
    echo "• Netcup VPS: €2.99/Monat"
    echo ""
    echo -e "${YELLOW}💡 Empfehlung: Hetzner Cloud (EU-Datenschutz + günstig)${NC}"
}

# WireGuard Server Setup Script (für VPS)
create_server_setup() {
    log_info "📝 Erstelle WireGuard Server Setup Script..."
    
    cat > ./wireguard_server_setup.sh << 'EOF'
#!/bin/bash

# GENTLEMAN WireGuard Server Setup (auf VPS ausführen)
# Unterstützt Ubuntu 20.04/22.04

set -euo pipefail

# Konfiguration
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_NET="10.66.66.0/24"
WG_SERVER_IP="10.66.66.1"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# System Update
update_system() {
    log_info "🔄 Aktualisiere System..."
    apt update && apt upgrade -y
    log_success "System aktualisiert"
}

# WireGuard Installation
install_wireguard() {
    log_info "📦 Installiere WireGuard..."
    apt install -y wireguard wireguard-tools qrencode
    log_success "WireGuard installiert"
}

# Server Keys generieren
generate_server_keys() {
    log_info "🔐 Generiere Server Keys..."
    cd /etc/wireguard
    
    # Server Private Key
    wg genkey | tee server_private.key | wg pubkey > server_public.key
    chmod 600 server_private.key
    
    SERVER_PRIVATE_KEY=$(cat server_private.key)
    SERVER_PUBLIC_KEY=$(cat server_public.key)
    
    log_success "Server Keys generiert"
}

# Server Konfiguration
create_server_config() {
    log_info "⚙️ Erstelle Server Konfiguration..."
    
    cat > /etc/wireguard/$WG_INTERFACE.conf << EOF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = $WG_SERVER_IP/24
ListenPort = $WG_PORT
SaveConfig = true

# NAT und Forwarding
PostUp = iptables -A FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -A FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -D FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Clients werden hier automatisch hinzugefügt
EOF

    log_success "Server Konfiguration erstellt"
}

# IP Forwarding aktivieren
enable_ip_forwarding() {
    log_info "🔄 Aktiviere IP Forwarding..."
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    sysctl -p
    log_success "IP Forwarding aktiviert"
}

# Firewall konfigurieren
configure_firewall() {
    log_info "🔥 Konfiguriere Firewall..."
    
    # UFW installieren falls nicht vorhanden
    apt install -y ufw
    
    # Firewall Rules
    ufw allow ssh
    ufw allow $WG_PORT/udp
    ufw --force enable
    
    log_success "Firewall konfiguriert"
}

# WireGuard Service starten
start_wireguard() {
    log_info "🚀 Starte WireGuard Service..."
    
    systemctl enable wg-quick@$WG_INTERFACE
    systemctl start wg-quick@$WG_INTERFACE
    
    log_success "WireGuard Service gestartet"
}

# Client Management Script erstellen
create_client_manager() {
    log_info "📝 Erstelle Client Management Script..."
    
    cat > /root/add_client.sh << 'SCRIPT'
#!/bin/bash

# GENTLEMAN WireGuard Client Hinzufügen

if [ $# -eq 0 ]; then
    echo "Verwendung: $0 <client-name>"
    echo "Beispiel: $0 amon-m1"
    exit 1
fi

CLIENT_NAME="$1"
WG_INTERFACE="wg0"
WG_NET="10.66.66.0/24"
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public.key)
SERVER_ENDPOINT="$(curl -s ifconfig.me):51820"

# Nächste verfügbare IP finden
LAST_IP=$(grep -oE "10\.66\.66\.[0-9]+" /etc/wireguard/$WG_INTERFACE.conf | sort -V | tail -1 | cut -d. -f4)
if [ -z "$LAST_IP" ]; then
    CLIENT_IP="10.66.66.2"
else
    CLIENT_IP="10.66.66.$((LAST_IP + 1))"
fi

# Client Keys generieren
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)

# Client Config erstellen
cat > /root/${CLIENT_NAME}.conf << EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/24
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_ENDPOINT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# Client zum Server hinzufügen
cat >> /etc/wireguard/$WG_INTERFACE.conf << EOF

# Client: $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_IP/32
EOF

# WireGuard neu laden
wg syncconf $WG_INTERFACE <(wg-quick strip $WG_INTERFACE)

echo "✅ Client '$CLIENT_NAME' hinzugefügt!"
echo "📱 IP: $CLIENT_IP"
echo "📄 Config: /root/${CLIENT_NAME}.conf"
echo ""
echo "🔗 QR Code für Mobile:"
qrencode -t ansiutf8 < /root/${CLIENT_NAME}.conf

echo ""
echo "📋 Config-Datei Inhalt:"
cat /root/${CLIENT_NAME}.conf
SCRIPT

    chmod +x /root/add_client.sh
    log_success "Client Manager erstellt"
}

# Status anzeigen
show_status() {
    log_info "📊 WireGuard Status:"
    echo ""
    
    # Service Status
    systemctl status wg-quick@$WG_INTERFACE --no-pager -l
    echo ""
    
    # WireGuard Status
    wg show
    echo ""
    
    # Server Info
    echo "🌐 Server Public Key: $(cat /etc/wireguard/server_public.key)"
    echo "📍 Server Endpoint: $(curl -s ifconfig.me):$WG_PORT"
    echo "🔧 Server IP: $WG_SERVER_IP"
    echo ""
    echo "➕ Client hinzufügen: /root/add_client.sh <name>"
}

# Hauptfunktion
main() {
    echo "🎯 GENTLEMAN WireGuard Server Setup"
    echo "==================================="
    echo ""
    
    # Root-Check
    if [ "$EUID" -ne 0 ]; then
        log_error "Bitte als root ausführen: sudo $0"
        exit 1
    fi
    
    update_system
    install_wireguard
    generate_server_keys
    create_server_config
    enable_ip_forwarding
    configure_firewall
    start_wireguard
    create_client_manager
    
    echo ""
    log_success "🎉 WireGuard Server Setup abgeschlossen!"
    echo ""
    show_status
    
    echo ""
    echo "🚀 Nächste Schritte:"
    echo "1. Client hinzufügen: /root/add_client.sh <name>"
    echo "2. Config-Datei an Client senden"
    echo "3. Client installiert WireGuard und importiert Config"
}

main "$@"
EOF

    chmod +x ./wireguard_server_setup.sh
    log_success "Server Setup Script erstellt"
}

# Client Setup Scripts erstellen
create_client_scripts() {
    log_info "📝 Erstelle Client Setup Scripts..."
    
    # macOS Client Setup
    cat > ./wireguard_client_macos.sh << 'EOF'
#!/bin/bash

# GENTLEMAN WireGuard Client Setup (macOS)

echo "🎯 GENTLEMAN WireGuard Client Setup (macOS)"
echo "==========================================="
echo ""

# WireGuard installieren
if ! command -v wg >/dev/null 2>&1; then
    echo "📦 Installiere WireGuard..."
    if command -v brew >/dev/null 2>&1; then
        brew install wireguard-tools
    else
        echo "❌ Homebrew nicht gefunden. Bitte installiere WireGuard manuell:"
        echo "   https://www.wireguard.com/install/"
        exit 1
    fi
fi

echo "✅ WireGuard installiert"
echo ""
echo "📋 Nächste Schritte:"
echo "1. Config-Datei vom Server-Admin erhalten"
echo "2. WireGuard App aus App Store installieren"
echo "3. Config-Datei in WireGuard App importieren"
echo "4. Verbindung aktivieren"
echo ""
echo "💡 Oder via Terminal:"
echo "   sudo wg-quick up /path/to/config.conf"
EOF

    # Linux Client Setup
    cat > ./wireguard_client_linux.sh << 'EOF'
#!/bin/bash

# GENTLEMAN WireGuard Client Setup (Linux)

echo "🎯 GENTLEMAN WireGuard Client Setup (Linux)"
echo "==========================================="
echo ""

# WireGuard installieren
echo "📦 Installiere WireGuard..."
if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y wireguard wireguard-tools
elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S wireguard-tools
elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y wireguard-tools
else
    echo "❌ Paketmanager nicht erkannt. Bitte WireGuard manuell installieren."
    exit 1
fi

echo "✅ WireGuard installiert"
echo ""
echo "📋 Verwendung:"
echo "1. Config-Datei nach /etc/wireguard/ kopieren"
echo "2. sudo wg-quick up <config-name>"
echo "3. sudo systemctl enable wg-quick@<config-name> (für Autostart)"
echo ""
echo "Beispiel:"
echo "  sudo cp client.conf /etc/wireguard/"
echo "  sudo wg-quick up client"
EOF

    chmod +x ./wireguard_client_*.sh
    log_success "Client Setup Scripts erstellt"
}

# Kosten-Kalkulator
show_cost_analysis() {
    echo -e "${PURPLE}💰 Kosten-Analyse: WireGuard vs Tailscale${NC}"
    echo "=========================================="
    echo ""
    echo -e "${GREEN}WireGuard (Self-Hosted):${NC}"
    echo "• VPS: €3-5/Monat für unbegrenzte Geräte"
    echo "• Einmalig: Setup-Zeit (1-2 Stunden)"
    echo "• Jährlich: €36-60 für alle Freunde zusammen"
    echo ""
    echo -e "${YELLOW}Tailscale (Hosted):${NC}"
    echo "• Kostenlos: Bis 20 Geräte (aktuell)"
    echo "• Risiko: Preisänderungen möglich"
    echo "• Pro Nutzer: $5/Monat bei Überschreitung"
    echo ""
    echo -e "${BLUE}Für 10 Freunde mit je 2 Geräten (20 Geräte):${NC}"
    echo "• WireGuard: €60/Jahr (€6 pro Person)"
    echo "• Tailscale: €0 (aktuell) oder €600/Jahr bei Pricing-Änderung"
    echo ""
    echo -e "${CYAN}💡 Empfehlung: WireGuard für Zukunftssicherheit${NC}"
}

# Deployment Guide
create_deployment_guide() {
    log_info "📖 Erstelle Deployment Guide..."
    
    cat > ./GENTLEMAN_WireGuard_Deployment.md << 'EOF'
# GENTLEMAN WireGuard Deployment Guide

## 🎯 Übersicht
Zukunftssichere VPN-Lösung für Freunde-Netzwerk ohne Abhängigkeit von externen Services.

## 🚀 Server Setup (1x für alle)

### 1. VPS mieten
- **Empfehlung**: Hetzner Cloud CPX11 (€3.29/Monat)
- **Mindestanforderungen**: 1 CPU, 1GB RAM, Ubuntu 22.04
- **Standort**: Deutschland (EU-Datenschutz)

### 2. Server einrichten
```bash
# Auf VPS einloggen
ssh root@your-server-ip

# Setup Script herunterladen und ausführen
curl -O https://raw.githubusercontent.com/your-repo/wireguard_server_setup.sh
chmod +x wireguard_server_setup.sh
sudo ./wireguard_server_setup.sh
```

### 3. Clients hinzufügen
```bash
# Für jeden Freund/Gerät
/root/add_client.sh amon-m1
/root/add_client.sh amon-iphone
/root/add_client.sh max-laptop
```

## 👥 Client Setup (für jeden Freund)

### macOS
```bash
# WireGuard installieren
brew install wireguard-tools

# Oder WireGuard App aus App Store
# Config-Datei importieren und verbinden
```

### Linux (Ubuntu/Arch)
```bash
# Setup Script ausführen
./wireguard_client_linux.sh

# Config importieren
sudo cp client.conf /etc/wireguard/
sudo wg-quick up client
```

### iOS/Android
1. WireGuard App installieren
2. QR-Code vom Server scannen
3. Verbindung aktivieren

## 💰 Kosten
- **Server**: €3-5/Monat für unbegrenzte Geräte
- **Pro Person**: €3-6/Jahr (bei 10 Freunden)
- **Einmalig**: Setup-Zeit (1-2 Stunden)

## 🔧 Wartung
- **Updates**: Automatisch via unattended-upgrades
- **Monitoring**: Optional via Grafana/Prometheus
- **Backup**: Config-Dateien regelmäßig sichern

## 🛡️ Sicherheit
- **Verschlüsselung**: ChaCha20Poly1305
- **Authentifizierung**: Ed25519 Keys
- **Perfect Forward Secrecy**: Ja
- **Audit**: Regelmäßig von Sicherheitsexperten geprüft

## 📱 Mobile Optimierung
- **Battery Optimized**: Minimal CPU/Battery Usage
- **Roaming**: Automatische Reconnection
- **Kill Switch**: Verhindert Daten-Leaks

## 🌍 Zukunftssicherheit
- **Open Source**: Keine Vendor Lock-in
- **Standard**: Teil des Linux Kernels
- **Community**: Große, aktive Entwickler-Community
- **Unabhängigkeit**: Keine externen Service-Abhängigkeiten
EOF

    log_success "Deployment Guide erstellt"
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN WireGuard Setup${NC}"
    echo "=============================="
    echo ""
    
    log_warning "Tailscale Pricing-Risiko erkannt - erstelle zukunftssichere Alternative!"
    echo ""
    
    show_vps_options
    echo ""
    
    show_cost_analysis
    echo ""
    
    create_server_setup
    create_client_scripts
    create_deployment_guide
    
    echo ""
    log_success "🎉 WireGuard Setup-Paket erstellt!"
    echo ""
    echo -e "${CYAN}📁 Erstellt:${NC}"
    echo "• wireguard_server_setup.sh - Server Setup"
    echo "• wireguard_client_macos.sh - macOS Client"
    echo "• wireguard_client_linux.sh - Linux Client"
    echo "• GENTLEMAN_WireGuard_Deployment.md - Vollständige Anleitung"
    echo ""
    echo -e "${YELLOW}🚀 Nächste Schritte:${NC}"
    echo "1. VPS bei Hetzner/DigitalOcean mieten"
    echo "2. wireguard_server_setup.sh auf VPS ausführen"
    echo "3. Clients für Freunde hinzufügen"
    echo "4. Config-Dateien verteilen"
    echo ""
    echo -e "${GREEN}💡 Vorteile:${NC}"
    echo "• €3-6/Jahr pro Person (bei 10 Freunden)"
    echo "• Unbegrenzte Geräte"
    echo "• Keine Vendor Lock-in"
    echo "• Zukunftssicher"
    echo "• EU-Datenschutz"
}

main "$@" 
 