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

# Root-Check
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Bitte als root ausführen: sudo $0"
        exit 1
    fi
}

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
    
    cat > /etc/wireguard/$WG_INTERFACE.conf << CONF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = $WG_SERVER_IP/24
ListenPort = $WG_PORT
SaveConfig = true

# NAT und Forwarding
PostUp = iptables -A FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -A FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -D FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Clients werden hier automatisch hinzugefügt
CONF

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
cat > /root/${CLIENT_NAME}.conf << CLIENTCONF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/24
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_ENDPOINT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CLIENTCONF

# Client zum Server hinzufügen
cat >> /etc/wireguard/$WG_INTERFACE.conf << SERVERCONF

# Client: $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_IP/32
SERVERCONF

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
    
    check_root
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
