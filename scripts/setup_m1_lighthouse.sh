#!/bin/bash
# 🎩 GENTLEMAN AI - M1 Mac Lighthouse Setup
# ═══════════════════════════════════════════════════════════════
# Konfiguriert den M1 Mac als Nebula Lighthouse Server

set -e

# 🎨 Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 📝 Logging Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${PURPLE}🔧 $1${NC}"
}

echo "🎩 GENTLEMAN AI - M1 Mac Lighthouse Setup"
echo "════════════════════════════════════════════════════════════"

# 1. Nebula Installation prüfen/installieren
log_step "Prüfe Nebula Installation..."

if ! command -v nebula &> /dev/null; then
    log_info "Installiere Nebula für macOS..."
    
    # Download latest Nebula for macOS
    NEBULA_VERSION="v1.8.2"
    NEBULA_URL="https://github.com/slackhq/nebula/releases/download/${NEBULA_VERSION}/nebula-darwin.tar.gz"
    
    curl -L "$NEBULA_URL" -o nebula-darwin.tar.gz
    tar -xzf nebula-darwin.tar.gz
    sudo mv nebula /usr/local/bin/
    sudo mv nebula-cert /usr/local/bin/
    rm nebula-darwin.tar.gz
    
    log_success "Nebula installiert"
else
    log_success "Nebula bereits installiert: $(nebula -version | head -n1)"
fi

# 2. M1 IP-Adresse ermitteln
log_step "Ermittle M1 IP-Adresse..."
M1_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
if [ -z "$M1_IP" ]; then
    log_error "Konnte IP-Adresse nicht ermitteln"
    exit 1
fi
log_success "M1 IP-Adresse: $M1_IP"

# 3. Nebula Verzeichnisse erstellen
log_step "Erstelle Nebula Verzeichnisse..."
sudo mkdir -p /etc/nebula/lighthouse
sudo mkdir -p /etc/nebula/m1-node
sudo mkdir -p /var/log/nebula

# 4. Certificate Authority erstellen
log_step "Erstelle Certificate Authority..."
cd /etc/nebula/lighthouse

if [ ! -f "ca.crt" ]; then
    log_info "Generiere CA Zertifikat..."
    sudo nebula-cert ca -name "Gentleman Mesh CA" -duration 8760h
    log_success "CA Zertifikat erstellt"
else
    log_info "CA Zertifikat bereits vorhanden"
fi

# 5. Lighthouse Zertifikat erstellen
if [ ! -f "lighthouse.crt" ]; then
    log_info "Generiere Lighthouse Zertifikat..."
    sudo nebula-cert sign -name "lighthouse" -ip "192.168.100.1/24" -groups "lighthouse"
    log_success "Lighthouse Zertifikat erstellt"
else
    log_info "Lighthouse Zertifikat bereits vorhanden"
fi

# 6. M1 Node Zertifikat erstellen
if [ ! -f "../m1-node/m1-node.crt" ]; then
    log_info "Generiere M1 Node Zertifikat..."
    sudo nebula-cert sign -name "m1-node" -ip "192.168.100.20/24" -groups "audio-services,apple-silicon"
    sudo mv m1-node.crt ../m1-node/
    sudo mv m1-node.key ../m1-node/
    sudo cp ca.crt ../m1-node/
    log_success "M1 Node Zertifikat erstellt"
else
    log_info "M1 Node Zertifikat bereits vorhanden"
fi

# 7. RX Node Zertifikat erstellen
if [ ! -f "rx-node.crt" ]; then
    log_info "Generiere RX Node Zertifikat..."
    sudo nebula-cert sign -name "rx-node" -ip "192.168.100.10/24" -groups "llm-servers,gpu-nodes"
    log_success "RX Node Zertifikat erstellt"
else
    log_info "RX Node Zertifikat bereits vorhanden"
fi

# 8. Lighthouse Konfiguration erstellen
log_step "Erstelle Lighthouse Konfiguration..."
sudo tee /etc/nebula/lighthouse/config.yml > /dev/null << EOF
# 🎩 Gentleman M1 Lighthouse Configuration
# ═══════════════════════════════════════════════════════════════
# M1 Mac als Nebula Lighthouse Server

# 🔐 PKI Configuration
pki:
  ca: /etc/nebula/lighthouse/ca.crt
  cert: /etc/nebula/lighthouse/lighthouse.crt
  key: /etc/nebula/lighthouse/lighthouse.key

# 🏠 Static Host Map (Lighthouse ist der Einstiegspunkt)
static_host_map:
  "192.168.100.1": ["$M1_IP:4242"]

# 🌐 Lighthouse Configuration
lighthouse:
  am_lighthouse: true
  serve_dns: false
  interval: 60
  hosts: []

# 🔊 Listen Configuration
listen:
  host: 0.0.0.0
  port: 4242

# 🥊 Punchy (NAT Traversal)
punchy:
  punch: true
  respond: true
  delay: 1s
  respond_delay: 5s

# 🌐 TUN Interface (macOS)
tun:
  disabled: false
  dev: utun100
  drop_local_broadcast: false
  drop_multicast: false
  tx_queue: 500
  mtu: 1300
  routes: []
  unsafe_routes: []

# 📝 Logging
logging:
  level: info
  format: text
  disable_timestamp: false
  timestamp_format: "2006-01-02T15:04:05Z07:00"

# 🔥 Firewall Configuration
firewall:
  # Connection Tracking
  conntrack:
    tcp_timeout: 12m
    udp_timeout: 3m
    default_timeout: 10m
    max_connections: 100000

  # Outbound Rules (Allow all outbound)
  outbound:
    - port: any
      proto: any
      host: any

  # Inbound Rules (Lighthouse accepts all mesh traffic)
  inbound:
    # Allow ICMP (ping)
    - port: any
      proto: icmp
      host: any

    # Allow SSH (secure access)
    - port: 22
      proto: tcp
      host: any

    # Allow all mesh communication
    - port: any
      proto: any
      host: any
      groups:
        - llm-servers
        - audio-services
        - clients
        - monitoring
        - gpu-nodes
        - apple-silicon

    # Allow Nebula mesh protocol
    - port: 4242
      proto: udp
      host: any

# 🎯 M1 Lighthouse Specific Settings
# Role: Lighthouse Server + Audio Services
# Hardware: Apple M1/M2 Mac
# Services: lighthouse, stt-service, tts-service, mesh-coordinator
# IP: 192.168.100.1/24 (Lighthouse) + 192.168.100.20/24 (Services)
# Groups: lighthouse, audio-services, apple-silicon
EOF

# 9. LaunchDaemon erstellen
log_step "Erstelle LaunchDaemon..."
sudo tee /Library/LaunchDaemons/com.gentleman.nebula.lighthouse.plist > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.gentleman.nebula.lighthouse</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/nebula</string>
        <string>-config</string>
        <string>/etc/nebula/lighthouse/config.yml</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/nebula/lighthouse.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/nebula/lighthouse.error.log</string>
    <key>UserName</key>
    <string>root</string>
</dict>
</plist>
EOF

# 10. Berechtigungen setzen
log_step "Setze Berechtigungen..."
sudo chmod 600 /etc/nebula/lighthouse/*.key
sudo chmod 644 /etc/nebula/lighthouse/*.crt
sudo chmod 644 /etc/nebula/lighthouse/config.yml
sudo chown -R root:wheel /etc/nebula

# 11. Service starten
log_step "Starte Lighthouse Service..."
sudo launchctl load /Library/LaunchDaemons/com.gentleman.nebula.lighthouse.plist

# 12. Zertifikate für RX Node bereitstellen
log_step "Bereite Zertifikate für RX Node vor..."
mkdir -p ./rx-node-certs
sudo cp /etc/nebula/lighthouse/ca.crt ./rx-node-certs/
sudo cp /etc/nebula/lighthouse/rx-node.crt ./rx-node-certs/
sudo cp /etc/nebula/lighthouse/rx-node.key ./rx-node-certs/
sudo chown $(whoami):staff ./rx-node-certs/*

echo ""
log_success "🎉 M1 Mac Lighthouse Setup abgeschlossen!"
echo "════════════════════════════════════════════════════════════"
echo -e "${CYAN}🏠 Lighthouse IP: 192.168.100.1${NC}"
echo -e "${CYAN}🍎 M1 Node IP: 192.168.100.20${NC}"
echo -e "${CYAN}🌐 Public IP: $M1_IP${NC}"
echo -e "${CYAN}🔌 Port: 4242/udp${NC}"
echo ""
echo -e "${YELLOW}📋 Nächste Schritte für RX Node:${NC}"
echo "1. Zertifikate kopieren:"
echo "   scp ./rx-node-certs/* user@192.168.68.117:/home/amo9n11/Documents/Archives/gentleman/nebula/rx-node/"
echo ""
echo "2. RX Node Konfiguration aktualisieren"
echo "3. RX Node Nebula Service neu starten" 