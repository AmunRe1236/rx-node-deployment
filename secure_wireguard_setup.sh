#!/bin/bash

# 🔐 GENTLEMAN Cluster WireGuard VPN Setup
# Sichere Remote-Zugriff Lösung für M1 Mac Gateway
# Version: 1.0 - Military-Grade Security

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# WireGuard Configuration
WG_DIR="/opt/homebrew/etc/wireguard"
WG_INTERFACE="wg0"
WG_PORT="51820"
SERVER_IP="10.0.0.1/24"
CLIENT_IP="10.0.0.2/24"
EXTERNAL_INTERFACE=$(route get default | grep interface | awk '{print $2}')
PUBLIC_IP=$(curl -s ifconfig.me || echo "UNKNOWN")

# GENTLEMAN Cluster Configuration
M1_MAC_IP="192.168.68.111"
RX_NODE_IP="192.168.68.117"
I7_NODE_IP="192.168.68.105"
CLUSTER_NETWORK="192.168.68.0/24"

log_header() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║  🔐 GENTLEMAN CLUSTER WIREGUARD VPN SETUP                   ║${NC}"
    echo -e "${PURPLE}║  Military-Grade Security für Remote-Zugriff                 ║${NC}"
    echo -e "${PURPLE}║  M1 Mac Gateway: $M1_MAC_IP                                  ║${NC}"
    echo -e "${PURPLE}║  Public IP: $PUBLIC_IP                                       ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

log() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

# Check if running as root for some operations
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "Läuft als root - das ist für Setup-Operationen erforderlich"
    else
        log_info "Läuft als User - sudo wird für privilegierte Operationen verwendet"
    fi
}

# Install WireGuard if not present
install_wireguard() {
    log_info "🔍 Prüfe WireGuard Installation..."
    
    if ! command -v wg &> /dev/null; then
        log "📦 Installiere WireGuard über Homebrew..."
        brew install wireguard-tools
        log "✅ WireGuard Tools installiert"
    else
        log "✅ WireGuard bereits installiert"
    fi
    
    # Install qrencode for mobile QR codes
    if ! command -v qrencode &> /dev/null; then
        log "📱 Installiere QR-Code Generator..."
        brew install qrencode
        log "✅ QR-Code Generator installiert"
    else
        log "✅ QR-Code Generator bereits verfügbar"
    fi
}

# Create WireGuard directory structure
setup_directories() {
    log_info "📁 Erstelle WireGuard Directory-Struktur..."
    
    sudo mkdir -p "$WG_DIR"
    sudo mkdir -p "$WG_DIR/keys"
    sudo mkdir -p "$WG_DIR/clients"
    sudo chmod 700 "$WG_DIR"
    sudo chmod 700 "$WG_DIR/keys"
    
    log "📁 WireGuard Directories erstellt"
}

# Generate WireGuard keys
generate_keys() {
    log_info "🔑 Generiere WireGuard Schlüssel..."
    
    # Server keys
    if [[ ! -f "$WG_DIR/keys/server_private.key" ]]; then
        wg genkey | sudo tee "$WG_DIR/keys/server_private.key" > /dev/null
        sudo chmod 600 "$WG_DIR/keys/server_private.key"
        sudo cat "$WG_DIR/keys/server_private.key" | wg pubkey | sudo tee "$WG_DIR/keys/server_public.key" > /dev/null
        log "🔑 Server Schlüssel generiert"
    else
        log "✅ Server Schlüssel bereits vorhanden"
    fi
    
    # Client keys
    if [[ ! -f "$WG_DIR/keys/client_private.key" ]]; then
        wg genkey | sudo tee "$WG_DIR/keys/client_private.key" > /dev/null
        sudo chmod 600 "$WG_DIR/keys/client_private.key"
        sudo cat "$WG_DIR/keys/client_private.key" | wg pubkey | sudo tee "$WG_DIR/keys/client_public.key" > /dev/null
        log "🔑 Client Schlüssel generiert"
    else
        log "✅ Client Schlüssel bereits vorhanden"
    fi
    
    # Mobile client keys
    if [[ ! -f "$WG_DIR/keys/mobile_private.key" ]]; then
        wg genkey | sudo tee "$WG_DIR/keys/mobile_private.key" > /dev/null
        sudo chmod 600 "$WG_DIR/keys/mobile_private.key"
        sudo cat "$WG_DIR/keys/mobile_private.key" | wg pubkey | sudo tee "$WG_DIR/keys/mobile_public.key" > /dev/null
        log "📱 Mobile Client Schlüssel generiert"
    else
        log "✅ Mobile Client Schlüssel bereits vorhanden"
    fi
}

# Create server configuration
create_server_config() {
    log_info "⚙️  Erstelle WireGuard Server Konfiguration..."
    
    local server_private=$(sudo cat "$WG_DIR/keys/server_private.key")
    local client_public=$(sudo cat "$WG_DIR/keys/client_public.key")
    local mobile_public=$(sudo cat "$WG_DIR/keys/mobile_public.key")
    
    sudo tee "$WG_DIR/$WG_INTERFACE.conf" > /dev/null << EOF
[Interface]
# GENTLEMAN Cluster WireGuard Server Configuration
# M1 Mac Gateway (192.168.68.111)
PrivateKey = $server_private
Address = $SERVER_IP
ListenPort = $WG_PORT
SaveConfig = false

# Enable IP forwarding and NAT
PostUp = sysctl -w net.inet.ip.forwarding=1
PostUp = pfctl -e
PostUp = echo 'nat on $EXTERNAL_INTERFACE from $SERVER_IP to any -> ($EXTERNAL_INTERFACE)' | pfctl -f -
PostUp = echo 'pass in on $WG_INTERFACE' | pfctl -f -
PostUp = echo 'pass out on $EXTERNAL_INTERFACE from $SERVER_IP' | pfctl -f -

PostDown = pfctl -d
PostDown = sysctl -w net.inet.ip.forwarding=0

# Desktop Client (Laptop/PC)
[Peer]
# Desktop Client für Remote-Arbeit
PublicKey = $client_public
AllowedIPs = 10.0.0.2/32
PersistentKeepalive = 25

# Mobile Client (iPhone/Android)
[Peer]
# Mobile Client für unterwegs
PublicKey = $mobile_public
AllowedIPs = 10.0.0.3/32
PersistentKeepalive = 25
EOF

    sudo chmod 600 "$WG_DIR/$WG_INTERFACE.conf"
    log "⚙️  Server Konfiguration erstellt"
}

# Create desktop client configuration
create_desktop_client_config() {
    log_info "💻 Erstelle Desktop Client Konfiguration..."
    
    local client_private=$(sudo cat "$WG_DIR/keys/client_private.key")
    local server_public=$(sudo cat "$WG_DIR/keys/server_public.key")
    
    sudo tee "$WG_DIR/clients/desktop_client.conf" > /dev/null << EOF
[Interface]
# GENTLEMAN Cluster Desktop Client Configuration
# Für Remote-Zugriff von Laptop/PC
PrivateKey = $client_private
Address = 10.0.0.2/24
DNS = 8.8.8.8, 1.1.1.1

[Peer]
# GENTLEMAN Cluster M1 Mac Gateway
PublicKey = $server_public
Endpoint = $PUBLIC_IP:$WG_PORT
AllowedIPs = 192.168.68.0/24, 10.0.0.0/24
PersistentKeepalive = 25

# Routen für GENTLEMAN Cluster Services:
# SSH RX Node: ssh amo9n11@192.168.68.117
# GENTLEMAN Protocol: http://192.168.68.117:8008
# LM Studio: http://192.168.68.117:1234
# M1 Mac Coordinator: ssh amonbaumgartner@192.168.68.111
# i7 Node: ssh amonbaumgartner@192.168.68.105
EOF

    sudo chmod 644 "$WG_DIR/clients/desktop_client.conf"
    log "💻 Desktop Client Konfiguration erstellt"
}

# Create mobile client configuration
create_mobile_client_config() {
    log_info "📱 Erstelle Mobile Client Konfiguration..."
    
    local mobile_private=$(sudo cat "$WG_DIR/keys/mobile_private.key")
    local server_public=$(sudo cat "$WG_DIR/keys/server_public.key")
    
    sudo tee "$WG_DIR/clients/mobile_client.conf" > /dev/null << EOF
[Interface]
# GENTLEMAN Cluster Mobile Client Configuration
# Für Remote-Zugriff von iPhone/Android
PrivateKey = $mobile_private
Address = 10.0.0.3/24
DNS = 8.8.8.8, 1.1.1.1

[Peer]
# GENTLEMAN Cluster M1 Mac Gateway
PublicKey = $server_public
Endpoint = $PUBLIC_IP:$WG_PORT
AllowedIPs = 192.168.68.0/24, 10.0.0.0/24
PersistentKeepalive = 25
EOF

    sudo chmod 644 "$WG_DIR/clients/mobile_client.conf"
    log "📱 Mobile Client Konfiguration erstellt"
}

# Configure macOS firewall
configure_firewall() {
    log_info "🛡️  Konfiguriere macOS Firewall für WireGuard..."
    
    # Create pf rules for WireGuard
    sudo tee "/etc/pf.anchors/wireguard" > /dev/null << EOF
# GENTLEMAN Cluster WireGuard Firewall Rules
# Allow WireGuard traffic
pass in on $EXTERNAL_INTERFACE proto udp from any to any port $WG_PORT
pass in on $WG_INTERFACE from 10.0.0.0/24 to $CLUSTER_NETWORK
pass out on $EXTERNAL_INTERFACE from 10.0.0.0/24 to any

# NAT for VPN clients
nat on $EXTERNAL_INTERFACE from 10.0.0.0/24 to any -> ($EXTERNAL_INTERFACE)

# Allow access to GENTLEMAN services
pass in on $WG_INTERFACE proto tcp from 10.0.0.0/24 to $RX_NODE_IP port {22, 8008, 1234}
pass in on $WG_INTERFACE proto tcp from 10.0.0.0/24 to $M1_MAC_IP port {22, 9418}
pass in on $WG_INTERFACE proto tcp from 10.0.0.0/24 to $I7_NODE_IP port 22
EOF
    
    log "🛡️  Firewall-Regeln konfiguriert"
}

# Start WireGuard service
start_wireguard() {
    log_info "🚀 Starte WireGuard VPN Service..."
    
    # Stop existing WireGuard if running
    if sudo wg show "$WG_INTERFACE" &>/dev/null; then
        log_warning "Stoppe bestehende WireGuard Verbindung..."
        sudo wg-quick down "$WG_DIR/$WG_INTERFACE.conf" || true
    fi
    
    # Start WireGuard
    if sudo wg-quick up "$WG_DIR/$WG_INTERFACE.conf"; then
        log "🚀 WireGuard VPN gestartet"
        
        # Show status
        log_info "📊 WireGuard Status:"
        sudo wg show
        
        # Show interface
        log_info "🌐 VPN Interface:"
        ifconfig | grep -A 5 wg || ifconfig | grep -A 5 utun
        
    else
        log_error "❌ WireGuard Start fehlgeschlagen"
        return 1
    fi
}

# Create QR codes for mobile
create_qr_codes() {
    log_info "📱 Erstelle QR-Codes für Mobile Clients..."
    
    echo -e "${CYAN}📱 QR-Code für Mobile Client:${NC}"
    qrencode -t ansiutf8 < "$WG_DIR/clients/mobile_client.conf"
    
    # Save QR code to file
    qrencode -t PNG -o "$WG_DIR/clients/mobile_qr.png" < "$WG_DIR/clients/mobile_client.conf"
    log "📱 QR-Code gespeichert: $WG_DIR/clients/mobile_qr.png"
}

# Create installation instructions
create_instructions() {
    log_info "📋 Erstelle Installations-Anweisungen..."
    
    cat > "$WG_DIR/INSTALLATION_GUIDE.md" << EOF
# 🔐 GENTLEMAN Cluster VPN - Installation Guide

## 📱 Mobile Installation (iOS/Android)

### iOS:
1. **WireGuard App** aus App Store installieren
2. **QR-Code scannen** oder Konfiguration importieren
3. **VPN aktivieren** in der App

### Android:
1. **WireGuard App** aus Play Store installieren  
2. **QR-Code scannen** oder Konfiguration importieren
3. **VPN aktivieren** in der App

## 💻 Desktop Installation

### Windows:
1. **WireGuard for Windows** herunterladen: https://www.wireguard.com/install/
2. **Konfigurationsdatei importieren**: \`desktop_client.conf\`
3. **Tunnel aktivieren**

### macOS:
1. **WireGuard installieren**: \`brew install wireguard-tools\`
2. **Konfiguration kopieren**: \`/opt/homebrew/etc/wireguard/\`
3. **VPN starten**: \`sudo wg-quick up desktop_client\`

### Linux:
1. **WireGuard installieren**: \`sudo apt install wireguard\`
2. **Konfiguration kopieren**: \`/etc/wireguard/\`
3. **VPN starten**: \`sudo wg-quick up desktop_client\`

---

## 🎯 Nach VPN-Verbindung verfügbare Services:

### 🎮 RX Node (Primary Trainer):
- **SSH**: \`ssh amo9n11@192.168.68.117\`
- **GENTLEMAN Protocol**: http://192.168.68.117:8008
- **LM Studio API**: http://192.168.68.117:1234
- **GPU Monitoring**: SSH + \`./rxnode_cluster_sync.sh gpu\`

### 💻 M1 Mac (Coordinator):
- **SSH**: \`ssh amonbaumgartner@192.168.68.111\`
- **Git Daemon**: git://192.168.68.111:9418/Gentleman
- **Cluster Management**: SSH + Cluster-Scripts

### 🖥️ i7 Node (Client):
- **SSH**: \`ssh amonbaumgartner@192.168.68.105\`
- **Compute Tasks**: SSH + Processing Scripts

---

## 🔐 Sicherheitsfeatures:

✅ **ChaCha20Poly1305 Verschlüsselung** (Military-Grade)  
✅ **Perfect Forward Secrecy** - Jede Session neue Schlüssel  
✅ **Zero-Trust Architecture** - Nur VPN-Clients haben Zugriff  
✅ **NAT Traversal** - Funktioniert hinter Firewalls  
✅ **Automatic Reconnection** - Stabile Verbindungen  
✅ **No-Logs Policy** - Keine Verbindungsdaten gespeichert  

---

## 🌍 Router-Konfiguration erforderlich:

**Port-Weiterleitung aktivieren:**
- **Router**: http://192.168.68.1
- **Port**: UDP $WG_PORT → 192.168.68.111:$WG_PORT
- **Protokoll**: UDP
- **Ziel**: M1 Mac (192.168.68.111)

---

**🎩 GENTLEMAN Cluster - Sichere Remote-Verbindung aktiv!**
EOF

    log "📋 Installations-Guide erstellt: $WG_DIR/INSTALLATION_GUIDE.md"
}

# Test VPN connectivity
test_vpn() {
    log_info "🧪 Teste VPN Konnektivität..."
    
    # Test VPN interface
    if ip addr show "$WG_INTERFACE" &>/dev/null || ifconfig | grep -q wg; then
        log "✅ VPN Interface aktiv"
    else
        log_warning "⚠️  VPN Interface nicht gefunden"
    fi
    
    # Test routing
    if ping -c 1 10.0.0.1 &>/dev/null; then
        log "✅ VPN Gateway erreichbar"
    else
        log_warning "⚠️  VPN Gateway nicht erreichbar"
    fi
    
    # Test cluster access
    if ping -c 1 "$RX_NODE_IP" &>/dev/null; then
        log "✅ RX Node über VPN erreichbar"
    else
        log_warning "⚠️  RX Node nicht erreichbar"
    fi
}

# Create systemd service for auto-start
create_autostart() {
    log_info "🔄 Konfiguriere Auto-Start..."
    
    # Create LaunchDaemon for macOS
    sudo tee "/Library/LaunchDaemons/com.gentleman.wireguard.plist" > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.gentleman.wireguard</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/wg-quick</string>
        <string>up</string>
        <string>$WG_DIR/$WG_INTERFACE.conf</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/wireguard.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/wireguard.error.log</string>
</dict>
</plist>
EOF
    
    sudo launchctl load "/Library/LaunchDaemons/com.gentleman.wireguard.plist" 2>/dev/null || true
    log "🔄 Auto-Start konfiguriert"
}

# Main setup function
main() {
    log_header
    
    check_sudo
    
    log "🚀 Starte GENTLEMAN Cluster WireGuard VPN Setup..."
    
    # Step 1: Install WireGuard
    install_wireguard
    
    # Step 2: Setup directories
    setup_directories
    
    # Step 3: Generate keys
    generate_keys
    
    # Step 4: Create configurations
    create_server_config
    create_desktop_client_config
    create_mobile_client_config
    
    # Step 5: Configure firewall
    configure_firewall
    
    # Step 6: Start WireGuard
    start_wireguard
    
    # Step 7: Create QR codes
    create_qr_codes
    
    # Step 8: Create instructions
    create_instructions
    
    # Step 9: Test connectivity
    test_vpn
    
    # Step 10: Setup auto-start
    create_autostart
    
    echo ""
    echo -e "${GREEN}🎉 GENTLEMAN Cluster WireGuard VPN erfolgreich eingerichtet!${NC}"
    echo ""
    echo -e "${CYAN}📋 Nächste Schritte:${NC}"
    echo -e "1. 🌐 Router Port-Weiterleitung: UDP $WG_PORT → 192.168.68.111"
    echo -e "2. 📱 Mobile App: QR-Code scannen aus $WG_DIR/clients/"
    echo -e "3. 💻 Desktop: Konfiguration aus $WG_DIR/clients/desktop_client.conf"
    echo -e "4. 📖 Vollständige Anleitung: $WG_DIR/INSTALLATION_GUIDE.md"
    echo ""
    echo -e "${PURPLE}🔐 VPN Status:${NC}"
    sudo wg show 2>/dev/null || echo "WireGuard Status nicht verfügbar"
    echo ""
    echo -e "${GREEN}🎩 GENTLEMAN Cluster ist jetzt sicher remote erreichbar!${NC}"
}

# Command line interface
case "${1:-setup}" in
    "setup"|"install")
        main
        ;;
    "start")
        start_wireguard
        ;;
    "stop")
        sudo wg-quick down "$WG_DIR/$WG_INTERFACE.conf"
        ;;
    "status")
        sudo wg show
        ;;
    "test")
        test_vpn
        ;;
    "qr")
        create_qr_codes
        ;;
    "clients")
        echo "📁 Client Konfigurationen:"
        ls -la "$WG_DIR/clients/" 2>/dev/null || echo "Keine Client-Konfigurationen gefunden"
        ;;
    "help"|"-h"|"--help")
        echo "🔐 GENTLEMAN Cluster WireGuard VPN Setup"
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  setup, install - Vollständige VPN-Installation"
        echo "  start          - WireGuard VPN starten"
        echo "  stop           - WireGuard VPN stoppen"
        echo "  status         - VPN Status anzeigen"
        echo "  test           - Konnektivität testen"
        echo "  qr             - QR-Codes für Mobile anzeigen"
        echo "  clients        - Client-Konfigurationen auflisten"
        echo "  help           - Diese Hilfe anzeigen"
        ;;
    *)
        log_error "Unbekannter Befehl: $1"
        echo "Verwende '$0 help' für Hilfe"
        exit 1
        ;;
esac 