#!/bin/bash

# 🎩 GENTLEMAN - Improved Linux Setup
# ═══════════════════════════════════════════════════════════════
# Verbessertes Setup-Skript für Linux basierend auf Erfahrungen

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
    echo "🎩 GENTLEMAN - Improved Linux Setup"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${WHITE}🐧 Optimiertes Setup für Linux-Systeme${NC}"
    echo ""
}

# 🔍 System Detection
detect_system() {
    log_step "Erkenne Linux-Distribution..."
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO=$ID
        DISTRO_VERSION=$VERSION_ID
    elif [[ -f /etc/arch-release ]]; then
        DISTRO="arch"
        DISTRO_VERSION="rolling"
    elif [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
        DISTRO_VERSION=$(cat /etc/debian_version)
    else
        DISTRO="unknown"
        DISTRO_VERSION="unknown"
    fi
    
    ARCH=$(uname -m)
    KERNEL=$(uname -r)
    
    log_success "System erkannt: $DISTRO $DISTRO_VERSION ($ARCH)"
    log_info "Kernel: $KERNEL"
}

# 📦 Package Manager Detection
detect_package_manager() {
    log_step "Erkenne Package Manager..."
    
    if command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
        PKG_INSTALL="sudo pacman -S --noconfirm"
        PKG_UPDATE="sudo pacman -Syu --noconfirm"
    elif command -v apt >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        PKG_INSTALL="sudo apt install -y"
        PKG_UPDATE="sudo apt update && sudo apt upgrade -y"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        PKG_INSTALL="sudo yum install -y"
        PKG_UPDATE="sudo yum update -y"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        PKG_INSTALL="sudo dnf install -y"
        PKG_UPDATE="sudo dnf update -y"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"
        PKG_INSTALL="sudo zypper install -y"
        PKG_UPDATE="sudo zypper update -y"
    else
        log_error "Kein unterstützter Package Manager gefunden!"
        exit 1
    fi
    
    log_success "Package Manager: $PKG_MANAGER"
}

# 🔧 Install Dependencies
install_dependencies() {
    log_step "Installiere System-Abhängigkeiten..."
    
    # Common packages for all distributions
    COMMON_PACKAGES="curl wget git docker docker-compose python3 python3-pip jq bc"
    
    # Distribution-specific packages
    case $PKG_MANAGER in
        "pacman")
            PACKAGES="$COMMON_PACKAGES nebula base-devel"
            ;;
        "apt")
            PACKAGES="$COMMON_PACKAGES build-essential"
            ;;
        "yum"|"dnf")
            PACKAGES="$COMMON_PACKAGES gcc gcc-c++ make"
            ;;
        "zypper")
            PACKAGES="$COMMON_PACKAGES gcc gcc-c++ make"
            ;;
    esac
    
    log_info "Aktualisiere Package-Listen..."
    eval $PKG_UPDATE
    
    log_info "Installiere Pakete: $PACKAGES"
    eval "$PKG_INSTALL $PACKAGES" || {
        log_warning "Einige Pakete konnten nicht installiert werden, fahre fort..."
    }
    
    log_success "Abhängigkeiten installiert"
}

# 🌐 Improved Nebula Setup
setup_nebula_improved() {
    log_step "Verbesserte Nebula-Installation..."
    
    # Check if Nebula is already installed
    if command -v nebula >/dev/null 2>&1; then
        NEBULA_VERSION=$(nebula -version 2>/dev/null | head -n1 || echo "unknown")
        log_success "Nebula bereits installiert: $NEBULA_VERSION"
        return 0
    fi
    
    # Try package manager installation first
    case $PKG_MANAGER in
        "pacman")
            log_info "Installiere Nebula via pacman..."
            if sudo pacman -S --noconfirm nebula; then
                log_success "Nebula via pacman installiert"
                return 0
            fi
            ;;
        "apt")
            log_info "Prüfe Nebula in apt repositories..."
            if apt-cache search nebula | grep -q "nebula.*vpn\|nebula.*mesh"; then
                if $PKG_INSTALL nebula; then
                    log_success "Nebula via apt installiert"
                    return 0
                fi
            fi
            ;;
    esac
    
    # Manual installation as fallback
    log_info "Installiere Nebula manuell..."
    install_nebula_manual
}

install_nebula_manual() {
    NEBULA_VERSION="v1.9.5"
    
    case $ARCH in
        x86_64)
            NEBULA_ARCH="amd64"
            ;;
        aarch64|arm64)
            NEBULA_ARCH="arm64"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    NEBULA_URL="https://github.com/slackhq/nebula/releases/download/${NEBULA_VERSION}/nebula-linux-${NEBULA_ARCH}.tar.gz"
    
    log_info "Downloading Nebula ${NEBULA_VERSION} for ${NEBULA_ARCH}..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download and extract
    curl -L "$NEBULA_URL" | tar -xz
    
    # Install binaries
    sudo mv nebula /usr/local/bin/
    sudo mv nebula-cert /usr/local/bin/
    sudo chmod +x /usr/local/bin/nebula*
    
    # Cleanup
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
    
    # Verify installation
    if command -v nebula >/dev/null 2>&1; then
        NEBULA_VERSION=$(nebula -version 2>/dev/null | head -n1 || echo "installed")
        log_success "Nebula manuell installiert: $NEBULA_VERSION"
    else
        log_error "Nebula-Installation fehlgeschlagen"
        exit 1
    fi
}

# 🔧 Hardware Detection Integration
run_hardware_detection() {
    log_step "Führe Hardware-Erkennung durch..."
    
    if [[ -f "scripts/setup/hardware_detection.sh" ]]; then
        chmod +x scripts/setup/hardware_detection.sh
        ./scripts/setup/hardware_detection.sh
        
        if [[ -f "config/hardware/node_config.env" ]]; then
            source config/hardware/node_config.env
            log_success "Hardware erkannt: $GENTLEMAN_NODE_ROLE"
            export DETECTED_NODE_ROLE="$GENTLEMAN_NODE_ROLE"
            export DETECTED_NODE_ID="$GENTLEMAN_NODE_ID"
        else
            log_warning "Hardware-Konfiguration nicht gefunden"
            export DETECTED_NODE_ROLE="client"
            export DETECTED_NODE_ID="$(hostname)"
        fi
    else
        log_warning "Hardware-Detection-Skript nicht gefunden"
        export DETECTED_NODE_ROLE="client"
        export DETECTED_NODE_ID="$(hostname)"
    fi
}

# 🌐 Automatic Nebula Configuration
setup_nebula_auto_config() {
    log_step "Automatische Nebula-Konfiguration..."
    
    # Create system-wide Nebula directory
    sudo mkdir -p /etc/nebula
    
    # Determine node configuration based on detected hardware
    case $DETECTED_NODE_ROLE in
        "llm-server")
            setup_nebula_llm_node
            ;;
        "audio-server")
            setup_nebula_audio_node
            ;;
        "git-server")
            setup_nebula_git_node
            ;;
        *)
            setup_nebula_client_node
            ;;
    esac
}

setup_nebula_llm_node() {
    log_info "Konfiguriere Nebula für LLM Server..."
    
    NODE_NAME="rx-node"
    NODE_IP="192.168.100.10"
    NODE_GROUPS="llm-servers,gpu-nodes"
    NODE_DIR="/etc/nebula/$NODE_NAME"
    
    sudo mkdir -p "$NODE_DIR"
    
    # Generate certificates
    generate_node_certificates "$NODE_NAME" "$NODE_IP/24" "$NODE_GROUPS" "$NODE_DIR"
    
    # Create configuration
    create_nebula_config_llm "$NODE_DIR"
    
    # Setup systemd service
    create_systemd_service "$NODE_NAME" "$NODE_DIR"
    
    log_success "LLM Server Nebula-Konfiguration erstellt"
}

setup_nebula_audio_node() {
    log_info "Konfiguriere Nebula für Audio Server..."
    
    NODE_NAME="m1-node"
    NODE_IP="192.168.100.20"
    NODE_GROUPS="audio-services,apple-silicon"
    NODE_DIR="/etc/nebula/$NODE_NAME"
    
    sudo mkdir -p "$NODE_DIR"
    generate_node_certificates "$NODE_NAME" "$NODE_IP/24" "$NODE_GROUPS" "$NODE_DIR"
    create_nebula_config_audio "$NODE_DIR"
    create_systemd_service "$NODE_NAME" "$NODE_DIR"
    
    log_success "Audio Server Nebula-Konfiguration erstellt"
}

setup_nebula_git_node() {
    log_info "Konfiguriere Nebula für Git Server..."
    
    NODE_NAME="git-node"
    NODE_IP="192.168.100.40"
    NODE_GROUPS="git-servers,storage-nodes"
    NODE_DIR="/etc/nebula/$NODE_NAME"
    
    sudo mkdir -p "$NODE_DIR"
    generate_node_certificates "$NODE_NAME" "$NODE_IP/24" "$NODE_GROUPS" "$NODE_DIR"
    create_nebula_config_git "$NODE_DIR"
    create_systemd_service "$NODE_NAME" "$NODE_DIR"
    
    log_success "Git Server Nebula-Konfiguration erstellt"
}

setup_nebula_client_node() {
    log_info "Konfiguriere Nebula für Client..."
    
    NODE_NAME="client-node"
    NODE_IP="192.168.100.30"
    NODE_GROUPS="clients,mobile-nodes"
    NODE_DIR="/etc/nebula/$NODE_NAME"
    
    sudo mkdir -p "$NODE_DIR"
    generate_node_certificates "$NODE_NAME" "$NODE_IP/24" "$NODE_GROUPS" "$NODE_DIR"
    create_nebula_config_client "$NODE_DIR"
    create_systemd_service "$NODE_NAME" "$NODE_DIR"
    
    log_success "Client Nebula-Konfiguration erstellt"
}

generate_node_certificates() {
    local node_name="$1"
    local node_ip="$2"
    local node_groups="$3"
    local node_dir="$4"
    
    log_info "Generiere Zertifikate für $node_name..."
    
    # Ensure lighthouse CA exists
    mkdir -p nebula/lighthouse
    
    if [[ ! -f "nebula/lighthouse/ca.crt" ]]; then
        log_info "Erstelle Certificate Authority..."
        cd nebula/lighthouse
        nebula-cert ca -name "Gentleman Mesh CA"
        cd ../..
    fi
    
    # Generate node certificate if it doesn't exist
    if [[ ! -f "$node_dir/${node_name}.crt" ]]; then
        cd nebula/lighthouse
        nebula-cert sign -name "$node_name" -ip "$node_ip" -groups "$node_groups"
        
        # Move certificates to system directory with proper permissions
        sudo mv "${node_name}.crt" "$node_dir/"
        sudo mv "${node_name}.key" "$node_dir/"
        sudo cp ca.crt "$node_dir/"
        
        # Set secure permissions
        sudo chmod 600 "$node_dir/"*.key
        sudo chmod 644 "$node_dir/"*.crt
        sudo chown root:root "$node_dir/"*
        
        cd ../..
        log_success "Zertifikate für $node_name erstellt"
    else
        log_info "Zertifikate für $node_name bereits vorhanden"
    fi
}

create_nebula_config_llm() {
    local node_dir="$1"
    
    sudo tee "$node_dir/config.yml" > /dev/null << EOF
# 🎩 Gentleman LLM Server Node Configuration
# Automatically generated by improved setup script

pki:
  ca: $node_dir/ca.crt
  cert: $node_dir/rx-node.crt
  key: $node_dir/rx-node.key

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
  respond_delay: 5s

tun:
  disabled: false
  dev: nebula1
  drop_local_broadcast: false
  drop_multicast: false
  tx_queue: 500
  mtu: 1300
  routes: []
  unsafe_routes: []

logging:
  level: info
  format: text
  disable_timestamp: false

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
    # Allow ICMP (ping)
    - port: any
      proto: icmp
      host: any
    
    # Allow SSH
    - port: 22
      proto: tcp
      host: any
    
    # Allow LLM Server API
    - port: 8000-8010
      proto: tcp
      host: any
      groups:
        - audio-services
        - clients
        - monitoring
    
    # Allow monitoring
    - port: 9090-9100
      proto: tcp
      host: any
      groups:
        - monitoring
    
    # Allow Matrix communication
    - port: 8448
      proto: tcp
      host: any
      groups:
        - matrix-nodes
    
    # Allow Nebula mesh
    - port: 4242
      proto: udp
      host: any
EOF
}

create_nebula_config_audio() {
    local node_dir="$1"
    
    sudo tee "$node_dir/config.yml" > /dev/null << EOF
# 🎩 Gentleman Audio Server Node Configuration

pki:
  ca: $node_dir/ca.crt
  cert: $node_dir/m1-node.crt
  key: $node_dir/m1-node.key

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
    - port: 22
      proto: tcp
      host: any
    - port: 8001-8003
      proto: tcp
      host: any
      groups:
        - llm-servers
        - clients
        - monitoring
    - port: 4242
      proto: udp
      host: any
EOF
}

create_nebula_config_git() {
    local node_dir="$1"
    
    sudo tee "$node_dir/config.yml" > /dev/null << EOF
# 🎩 Gentleman Git Server Node Configuration

pki:
  ca: $node_dir/ca.crt
  cert: $node_dir/git-node.crt
  key: $node_dir/git-node.key

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
    - port: 22
      proto: tcp
      host: any
    - port: 3000
      proto: tcp
      host: any
      groups:
        - clients
        - monitoring
    - port: 8080
      proto: tcp
      host: any
      groups:
        - clients
    - port: 4242
      proto: udp
      host: any
EOF
}

create_nebula_config_client() {
    local node_dir="$1"
    
    sudo tee "$node_dir/config.yml" > /dev/null << EOF
# 🎩 Gentleman Client Node Configuration

pki:
  ca: $node_dir/ca.crt
  cert: $node_dir/client-node.crt
  key: $node_dir/client-node.key

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
    - port: 22
      proto: tcp
      host: any
    - port: 8080
      proto: tcp
      host: any
    - port: 4242
      proto: udp
      host: any
EOF
}

create_systemd_service() {
    local node_name="$1"
    local node_dir="$2"
    
    log_info "Erstelle systemd Service für $node_name..."
    
    sudo tee "/etc/systemd/system/nebula-${node_name}.service" > /dev/null << EOF
[Unit]
Description=Nebula VPN - ${node_name}
Documentation=https://github.com/slackhq/nebula
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/bin/nebula -config ${node_dir}/config.yml
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=mixed
Restart=always
RestartSec=5
TimeoutStopSec=30

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${node_dir}
CapabilityBoundingSet=CAP_NET_ADMIN
AmbientCapabilities=CAP_NET_ADMIN

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nebula-${node_name}

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable "nebula-${node_name}.service"
    
    log_success "Systemd Service nebula-${node_name} erstellt und aktiviert"
}

# 🔥 Setup Firewall
setup_firewall() {
    log_step "Konfiguriere Firewall..."
    
    # Configure iptables for Nebula
    if command -v iptables >/dev/null 2>&1; then
        # Allow Nebula interface
        sudo iptables -A INPUT -i nebula1 -j ACCEPT 2>/dev/null || true
        sudo iptables -A OUTPUT -o nebula1 -j ACCEPT 2>/dev/null || true
        
        # Allow Nebula UDP port
        sudo iptables -A INPUT -p udp --dport 4242 -j ACCEPT 2>/dev/null || true
        sudo iptables -A OUTPUT -p udp --sport 4242 -j ACCEPT 2>/dev/null || true
        
        log_success "iptables Regeln für Nebula hinzugefügt"
    fi
    
    # Configure ufw if available
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow 4242/udp comment "Nebula VPN" 2>/dev/null || true
        log_success "ufw Regeln für Nebula hinzugefügt"
    fi
}

# 🐳 Docker Setup
setup_docker() {
    log_step "Konfiguriere Docker..."
    
    # Add user to docker group
    sudo usermod -aG docker $USER || true
    
    # Enable and start Docker
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Test Docker
    if sudo docker run --rm hello-world >/dev/null 2>&1; then
        log_success "Docker funktioniert korrekt"
    else
        log_warning "Docker-Test fehlgeschlagen"
    fi
}

# 🧪 Test Installation
test_installation() {
    log_step "Teste Installation..."
    
    # Test Nebula
    if command -v nebula >/dev/null 2>&1; then
        NEBULA_VERSION=$(nebula -version 2>/dev/null | head -n1 || echo "unknown")
        log_success "Nebula: $NEBULA_VERSION"
    else
        log_error "Nebula: Nicht gefunden"
    fi
    
    # Test Docker
    if command -v docker >/dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version 2>/dev/null || echo "unknown")
        log_success "Docker: $DOCKER_VERSION"
    else
        log_error "Docker: Nicht gefunden"
    fi
    
    # Test Nebula configuration
    if [[ -f "/etc/nebula/${DETECTED_NODE_ROLE%-server}-node/config.yml" ]] || [[ -f "/etc/nebula/rx-node/config.yml" ]]; then
        log_success "Nebula-Konfiguration: Vorhanden"
    else
        log_warning "Nebula-Konfiguration: Nicht gefunden"
    fi
}

# 📊 Show Summary
show_summary() {
    echo ""
    log_success "🎩 Verbessertes Linux-Setup abgeschlossen!"
    echo ""
    echo -e "${WHITE}📊 System-Zusammenfassung:${NC}"
    echo -e "${CYAN}  Distribution:${NC} $DISTRO $DISTRO_VERSION"
    echo -e "${CYAN}  Package Manager:${NC} $PKG_MANAGER"
    echo -e "${CYAN}  Node-Rolle:${NC} $DETECTED_NODE_ROLE"
    echo -e "${CYAN}  Node-ID:${NC} $DETECTED_NODE_ID"
    echo ""
    echo -e "${WHITE}🌐 Nebula-Konfiguration:${NC}"
    if [[ "$DETECTED_NODE_ROLE" == "llm-server" ]]; then
        echo -e "${GREEN}  IP-Adresse:${NC} 192.168.100.10/24"
        echo -e "${GREEN}  Service:${NC} nebula-rx-node"
    else
        echo -e "${GREEN}  IP-Adresse:${NC} 192.168.100.30/24"
        echo -e "${GREEN}  Service:${NC} nebula-client-node"
    fi
    echo ""
    echo -e "${WHITE}📋 Nützliche Befehle:${NC}"
    echo -e "${CYAN}  Nebula starten:${NC} sudo systemctl start nebula-*"
    echo -e "${CYAN}  Nebula Status:${NC} make nebula-status"
    echo -e "${CYAN}  Hardware-Info:${NC} make hardware-config"
    echo -e "${CYAN}  Services starten:${NC} make gentleman-up-auto"
    echo ""
}

# 🎯 Main Function
main() {
    print_banner
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "Bitte nicht als root ausführen!"
        log_info "Verwende: ./scripts/setup/setup_linux_improved.sh"
        exit 1
    fi
    
    # Setup steps
    detect_system
    detect_package_manager
    install_dependencies
    setup_nebula_improved
    run_hardware_detection
    setup_nebula_auto_config
    setup_firewall
    setup_docker
    test_installation
    show_summary
    
    log_success "🎩 Setup erfolgreich abgeschlossen!"
    log_info "Starte Services mit: make gentleman-up-auto"
}

# 🎯 Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 