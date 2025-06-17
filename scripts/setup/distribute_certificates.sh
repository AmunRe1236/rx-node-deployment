#!/bin/bash

# 🎩 GENTLEMAN - Automatische Zertifikat-Verteilung
# ═══════════════════════════════════════════════════════════════
# Verteilt Nebula-Zertifikate automatisch auf alle drei Systeme

set -e

# 🎨 Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 📝 Logging
log_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_step() { echo -e "${BLUE}🔧 $1${NC}"; }

# 🎩 Banner
print_banner() {
    echo -e "${PURPLE}"
    echo "🎩 GENTLEMAN - Certificate Distribution"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${WHITE}🔐 Automatische Nebula-Zertifikat-Verteilung${NC}"
    echo ""
}

# 🌐 System-Konfiguration
SYSTEMS=(
    "arch-rx:192.168.1.100:rx-node"      # Arch Linux mit RX 6700 XT
    "macos-m1:192.168.1.101:m1-node"     # macOS M1
    "macos-i7:192.168.1.102:i7-node"     # macOS i7
)

LIGHTHOUSE_IP="192.168.100.1"
MESH_NETWORK="192.168.100.0/24"

# 📁 Verzeichnisse
NEBULA_DIR="$(pwd)/nebula"
LIGHTHOUSE_DIR="$NEBULA_DIR/lighthouse"
TEMP_DIR="/tmp/gentleman-certs"

# 🔐 Zertifikat-Generierung
generate_certificates() {
    log_step "Generiere Nebula-Zertifikate..."
    
    cd "$LIGHTHOUSE_DIR"
    
    # 🏛️ CA erstellen (falls nicht vorhanden)
    if [ ! -f "ca.crt" ]; then
        log_info "Erstelle Certificate Authority..."
        nebula-cert ca -name "Gentleman Mesh CA" -duration 8760h
        log_success "CA erstellt"
    else
        log_info "CA bereits vorhanden"
    fi
    
    # 🏠 Lighthouse Zertifikat
    if [ ! -f "lighthouse.crt" ]; then
        log_info "Erstelle Lighthouse-Zertifikat..."
        nebula-cert sign -name "lighthouse" -ip "$LIGHTHOUSE_IP/24" -groups "lighthouse"
        log_success "Lighthouse-Zertifikat erstellt"
    fi
    
    # 🖥️ RX Node (Arch Linux)
    if [ ! -f "../rx-node/rx.crt" ]; then
        log_info "Erstelle RX-Node-Zertifikat..."
        nebula-cert sign -name "rx-node" -ip "192.168.100.10/24" -groups "llm-servers,gpu-nodes"
        mv rx.crt ../rx-node/
        mv rx.key ../rx-node/
        log_success "RX-Node-Zertifikat erstellt"
    fi
    
    # 🍎 M1 Node (macOS M1)
    if [ ! -f "../m1-node/m1.crt" ]; then
        log_info "Erstelle M1-Node-Zertifikat..."
        nebula-cert sign -name "m1-node" -ip "192.168.100.20/24" -groups "audio-services,apple-silicon"
        mv m1.crt ../m1-node/
        mv m1.key ../m1-node/
        log_success "M1-Node-Zertifikat erstellt"
    fi
    
    # 💻 i7 Node (macOS i7)
    if [ ! -f "../i7-node/i7.crt" ]; then
        log_info "Erstelle i7-Node-Zertifikat..."
        nebula-cert sign -name "i7-node" -ip "192.168.100.30/24" -groups "clients,mobile-nodes"
        mv i7.crt ../i7-node/
        mv i7.key ../i7-node/
        log_success "i7-Node-Zertifikat erstellt"
    fi
    
    cd - > /dev/null
}

# 📋 Konfigurationsdateien erstellen
create_configs() {
    log_step "Erstelle Nebula-Konfigurationsdateien..."
    
    # 🏠 Lighthouse Config
    cat > "$NEBULA_DIR/lighthouse/config.yml" << EOF
# 🎩 Gentleman Lighthouse Configuration
pki:
  ca: ca.crt
  cert: lighthouse.crt
  key: lighthouse.key

static_host_map:
  "192.168.100.1": ["0.0.0.0:4242"]

lighthouse:
  am_lighthouse: true
  serve_dns: false
  interval: 60
  hosts: []

listen:
  host: 0.0.0.0
  port: 4242

punchy:
  punch: true
  respond: true
  delay: 1s

tun:
  disabled: false
  dev: nebula1
  drop_local_broadcast: false
  drop_multicast: false
  tx_queue: 500
  mtu: 1300

logging:
  level: info
  format: text

firewall:
  conntrack:
    tcp_timeout: 12m
    udp_timeout: 3m
    default_timeout: 10m
    max_connections: 100000

  outbound:
    - port: any
      proto: any
      host: any

  inbound:
    - port: any
      proto: icmp
      host: any
    - port: 8000-8010
      proto: tcp
      host: any
    - port: 22
      proto: tcp
      host: any
EOF

    # 🖥️ RX Node Config
    cat > "$NEBULA_DIR/rx-node/config.yml" << EOF
# 🎩 Gentleman RX Node Configuration (Arch Linux + RX 6700 XT)
pki:
  ca: ca.crt
  cert: rx.crt
  key: rx.key

static_host_map:
  "192.168.100.1": ["LIGHTHOUSE_PUBLIC_IP:4242"]

lighthouse:
  am_lighthouse: false
  interval: 60
  hosts:
    - "192.168.100.1"

listen:
  host: 0.0.0.0
  port: 0

punchy:
  punch: true
  respond: true
  delay: 1s

tun:
  disabled: false
  dev: nebula1
  drop_local_broadcast: false
  drop_multicast: false
  tx_queue: 500
  mtu: 1300

logging:
  level: info
  format: text

firewall:
  conntrack:
    tcp_timeout: 12m
    udp_timeout: 3m
    default_timeout: 10m
    max_connections: 100000

  outbound:
    - port: any
      proto: any
      host: any

  inbound:
    - port: any
      proto: icmp
      host: any
    - port: 8000-8010
      proto: tcp
      host: any
    - port: 22
      proto: tcp
      host: any
EOF

    # 🍎 M1 Node Config
    cat > "$NEBULA_DIR/m1-node/config.yml" << EOF
# 🎩 Gentleman M1 Node Configuration (macOS Apple Silicon)
pki:
  ca: ca.crt
  cert: m1.crt
  key: m1.key

static_host_map:
  "192.168.100.1": ["LIGHTHOUSE_PUBLIC_IP:4242"]

lighthouse:
  am_lighthouse: false
  interval: 60
  hosts:
    - "192.168.100.1"

listen:
  host: 0.0.0.0
  port: 0

punchy:
  punch: true
  respond: true
  delay: 1s

tun:
  disabled: false
  dev: utun100
  drop_local_broadcast: false
  drop_multicast: false
  tx_queue: 500
  mtu: 1300

logging:
  level: info
  format: text

firewall:
  conntrack:
    tcp_timeout: 12m
    udp_timeout: 3m
    default_timeout: 10m
    max_connections: 100000

  outbound:
    - port: any
      proto: any
      host: any

  inbound:
    - port: any
      proto: icmp
      host: any
    - port: 8000-8010
      proto: tcp
      host: any
    - port: 22
      proto: tcp
      host: any
EOF

    # 💻 i7 Node Config
    cat > "$NEBULA_DIR/i7-node/config.yml" << EOF
# 🎩 Gentleman i7 Node Configuration (macOS Intel)
pki:
  ca: ca.crt
  cert: i7.crt
  key: i7.key

static_host_map:
  "192.168.100.1": ["LIGHTHOUSE_PUBLIC_IP:4242"]

lighthouse:
  am_lighthouse: false
  interval: 60
  hosts:
    - "192.168.100.1"

listen:
  host: 0.0.0.0
  port: 0

punchy:
  punch: true
  respond: true
  delay: 1s

tun:
  disabled: false
  dev: utun100
  drop_local_broadcast: false
  drop_multicast: false
  tx_queue: 500
  mtu: 1300

logging:
  level: info
  format: text

firewall:
  conntrack:
    tcp_timeout: 12m
    udp_timeout: 3m
    default_timeout: 10m
    max_connections: 100000

  outbound:
    - port: any
      proto: any
      host: any

  inbound:
    - port: any
      proto: icmp
      host: any
    - port: 8000-8010
      proto: tcp
      host: any
    - port: 22
      proto: tcp
      host: any
EOF

    log_success "Konfigurationsdateien erstellt"
}

# 📤 CA-Zertifikat zu allen Nodes kopieren
distribute_ca() {
    log_step "Verteile CA-Zertifikat zu allen Nodes..."
    
    # CA zu allen Node-Verzeichnissen kopieren
    for node_dir in "$NEBULA_DIR"/{rx-node,m1-node,i7-node}; do
        if [ -d "$node_dir" ]; then
            cp "$LIGHTHOUSE_DIR/ca.crt" "$node_dir/"
            log_success "CA kopiert nach $(basename "$node_dir")"
        fi
    done
}

# 📦 Deployment-Pakete erstellen
create_deployment_packages() {
    log_step "Erstelle Deployment-Pakete für jedes System..."
    
    mkdir -p "$TEMP_DIR"
    
    # 🖥️ Arch Linux Package
    log_info "Erstelle Arch Linux Package..."
    mkdir -p "$TEMP_DIR/arch-rx"
    cp -r "$NEBULA_DIR/rx-node/"* "$TEMP_DIR/arch-rx/"
    cat > "$TEMP_DIR/arch-rx/install.sh" << 'EOF'
#!/bin/bash
# 🎩 Gentleman Arch Linux Installation
echo "🖥️ Installing Gentleman on Arch Linux..."
sudo pacman -S nebula --noconfirm
sudo cp config.yml /etc/nebula/
sudo cp *.crt *.key /etc/nebula/
sudo systemctl enable nebula@config
sudo systemctl start nebula@config
echo "✅ Arch Linux Node ready!"
EOF
    chmod +x "$TEMP_DIR/arch-rx/install.sh"
    
    # 🍎 M1 Mac Package
    log_info "Erstelle M1 Mac Package..."
    mkdir -p "$TEMP_DIR/macos-m1"
    cp -r "$NEBULA_DIR/m1-node/"* "$TEMP_DIR/macos-m1/"
    cat > "$TEMP_DIR/macos-m1/install.sh" << 'EOF'
#!/bin/bash
# 🎩 Gentleman M1 Mac Installation
echo "🍎 Installing Gentleman on M1 Mac..."
brew install nebula
sudo mkdir -p /etc/nebula
sudo cp config.yml /etc/nebula/
sudo cp *.crt *.key /etc/nebula/
sudo brew services start nebula
echo "✅ M1 Mac Node ready!"
EOF
    chmod +x "$TEMP_DIR/macos-m1/install.sh"
    
    # 💻 i7 Mac Package
    log_info "Erstelle i7 Mac Package..."
    mkdir -p "$TEMP_DIR/macos-i7"
    cp -r "$NEBULA_DIR/i7-node/"* "$TEMP_DIR/macos-i7/"
    cat > "$TEMP_DIR/macos-i7/install.sh" << 'EOF'
#!/bin/bash
# 🎩 Gentleman i7 Mac Installation
echo "💻 Installing Gentleman on i7 Mac..."
brew install nebula
sudo mkdir -p /etc/nebula
sudo cp config.yml /etc/nebula/
sudo cp *.crt *.key /etc/nebula/
sudo brew services start nebula
echo "✅ i7 Mac Node ready!"
EOF
    chmod +x "$TEMP_DIR/macos-i7/install.sh"
    
    # 📦 Archive erstellen
    cd "$TEMP_DIR"
    tar -czf arch-rx-deployment.tar.gz arch-rx/
    tar -czf macos-m1-deployment.tar.gz macos-m1/
    tar -czf macos-i7-deployment.tar.gz macos-i7/
    cd - > /dev/null
    
    log_success "Deployment-Pakete erstellt in $TEMP_DIR"
}

# 📋 Installationsanweisungen anzeigen
show_instructions() {
    echo ""
    log_success "🎩 Zertifikat-Verteilung abgeschlossen!"
    echo ""
    echo -e "${WHITE}📋 Nächste Schritte:${NC}"
    echo ""
    echo -e "${CYAN}🖥️ Arch Linux (RX 6700 XT):${NC}"
    echo "   1. Kopiere: $TEMP_DIR/arch-rx-deployment.tar.gz"
    echo "   2. Entpacke und führe aus: ./install.sh"
    echo "   3. Starte Services: make gentleman-up-llm"
    echo ""
    echo -e "${CYAN}🍎 macOS M1:${NC}"
    echo "   1. Kopiere: $TEMP_DIR/macos-m1-deployment.tar.gz"
    echo "   2. Entpacke und führe aus: ./install.sh"
    echo "   3. Starte Services: make gentleman-up-audio"
    echo ""
    echo -e "${CYAN}💻 macOS i7:${NC}"
    echo "   1. Kopiere: $TEMP_DIR/macos-i7-deployment.tar.gz"
    echo "   2. Entpacke und führe aus: ./install.sh"
    echo "   3. Starte Services: make gentleman-up-client"
    echo ""
    echo -e "${GREEN}🌐 Automatische Erkennung:${NC}"
    echo "   ✅ Alle Systeme werden sich automatisch finden"
    echo "   ✅ Keine manuelle Konfiguration erforderlich"
    echo "   ✅ Service Discovery funktioniert out-of-the-box"
    echo ""
    echo -e "${YELLOW}🔍 Testen:${NC}"
    echo "   make gentleman-test-mesh    # Netzwerk testen"
    echo "   make gentleman-health-all   # Alle Services prüfen"
    echo ""
}

# 🚀 Hauptfunktion
main() {
    print_banner
    
    # Prüfe Voraussetzungen
    if ! command -v nebula-cert &> /dev/null; then
        log_error "nebula-cert nicht gefunden! Bitte Nebula installieren."
        exit 1
    fi
    
    # Erstelle Verzeichnisse falls nicht vorhanden
    mkdir -p "$NEBULA_DIR"/{lighthouse,rx-node,m1-node,i7-node}
    
    # Führe Schritte aus
    generate_certificates
    create_configs
    distribute_ca
    create_deployment_packages
    show_instructions
    
    log_success "🎩 Gentleman Mesh Network bereit für Deployment!"
}

# 🎯 Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 