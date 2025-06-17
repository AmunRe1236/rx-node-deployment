#!/bin/bash

# 🎩 GENTLEMAN - One-Click Installation Script
# ═══════════════════════════════════════════════════════════════

set -e

# 🎨 Colors für elegante Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 🎩 Gentleman Banner
print_banner() {
    echo -e "${PURPLE}"
    echo "🎩 GENTLEMAN - Distributed AI Pipeline"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${WHITE}🌟 Wo Eleganz auf Funktionalität trifft${NC}"
    echo ""
}

# 📝 Logging Funktionen
log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
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
    echo -e "${BLUE}🔧 $1${NC}"
}

# 🔍 System Detection
detect_system() {
    log_step "Detecting system architecture..."
    
    OS=$(uname -s)
    ARCH=$(uname -m)
    
    case $OS in
        Linux*)
            SYSTEM="Linux"
            if command -v lsb_release &> /dev/null; then
                DISTRO=$(lsb_release -si)
            elif [ -f /etc/os-release ]; then
                DISTRO=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
            else
                DISTRO="Unknown"
            fi
            ;;
        Darwin*)
            SYSTEM="macOS"
            if [[ $ARCH == "arm64" ]]; then
                DISTRO="Apple Silicon"
            else
                DISTRO="Intel"
            fi
            ;;
        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
    
    log_info "System: $SYSTEM ($DISTRO) - $ARCH"
}

# 🔧 Dependency Check
check_dependencies() {
    log_step "Checking dependencies..."
    
    MISSING_DEPS=()
    
    # Essential tools
    command -v git >/dev/null 2>&1 || MISSING_DEPS+=("git")
    command -v curl >/dev/null 2>&1 || MISSING_DEPS+=("curl")
    command -v python3 >/dev/null 2>&1 || MISSING_DEPS+=("python3")
    command -v pip3 >/dev/null 2>&1 || MISSING_DEPS+=("python3-pip")
    
    # Docker
    if ! command -v docker >/dev/null 2>&1; then
        MISSING_DEPS+=("docker")
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1; then
        MISSING_DEPS+=("docker-compose")
    fi
    
    # Make
    command -v make >/dev/null 2>&1 || MISSING_DEPS+=("make")
    
    if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
        log_warning "Missing dependencies: ${MISSING_DEPS[*]}"
        install_dependencies "${MISSING_DEPS[@]}"
    else
        log_success "All dependencies are installed!"
    fi
}

# 📦 Install Dependencies
install_dependencies() {
    local deps=("$@")
    log_step "Installing missing dependencies..."
    
    case $SYSTEM in
        Linux)
            case $DISTRO in
                ubuntu|debian)
                    sudo apt update
                    sudo apt install -y "${deps[@]}"
                    ;;
                arch|manjaro)
                    sudo pacman -Sy --noconfirm "${deps[@]}"
                    ;;
                fedora|centos|rhel)
                    sudo dnf install -y "${deps[@]}"
                    ;;
                *)
                    log_error "Unsupported Linux distribution: $DISTRO"
                    log_info "Please install manually: ${deps[*]}"
                    exit 1
                    ;;
            esac
            ;;
        macOS)
            if ! command -v brew >/dev/null 2>&1; then
                log_step "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install "${deps[@]}"
            ;;
    esac
    
    log_success "Dependencies installed!"
}

# 🐳 Docker Setup
setup_docker() {
    log_step "Setting up Docker..."
    
    # Start Docker service if not running
    if ! docker info >/dev/null 2>&1; then
        case $SYSTEM in
            Linux)
                sudo systemctl start docker
                sudo systemctl enable docker
                # Add user to docker group
                sudo usermod -aG docker $USER
                log_warning "Please log out and back in for Docker group changes to take effect"
                ;;
            macOS)
                log_info "Please start Docker Desktop manually"
                ;;
        esac
    fi
    
    log_success "Docker setup completed!"
}

# 🌐 Nebula Setup
setup_nebula() {
    log_step "Setting up Nebula mesh network..."
    
    # Check if Nebula is already installed via package manager
    if command -v nebula >/dev/null 2>&1; then
        log_info "Nebula already installed via package manager"
        NEBULA_VERSION=$(nebula -version 2>/dev/null | head -n1 || echo "unknown")
        log_info "Nebula version: $NEBULA_VERSION"
    else
        # Try to install via package manager first
        case $SYSTEM in
            Linux)
                if command -v pacman >/dev/null 2>&1; then
                    log_info "Installing Nebula via pacman..."
                    sudo pacman -S --noconfirm nebula || {
                        log_warning "Package manager installation failed, downloading manually..."
                        download_nebula_manual
                    }
                elif command -v apt >/dev/null 2>&1; then
                    log_info "Installing Nebula via apt..."
                    sudo apt update && sudo apt install -y nebula || {
                        log_warning "Package manager installation failed, downloading manually..."
                        download_nebula_manual
                    }
                elif command -v yum >/dev/null 2>&1; then
                    log_info "Installing Nebula via yum..."
                    sudo yum install -y nebula || {
                        log_warning "Package manager installation failed, downloading manually..."
                        download_nebula_manual
                    }
                else
                    log_info "No supported package manager found, downloading manually..."
                    download_nebula_manual
                fi
                ;;
            macOS)
                if command -v brew >/dev/null 2>&1; then
                    log_info "Installing Nebula via Homebrew..."
                    brew install nebula || {
                        log_warning "Homebrew installation failed, downloading manually..."
                        download_nebula_manual
                    }
                else
                    log_info "Homebrew not found, downloading manually..."
                    download_nebula_manual
                fi
                ;;
            *)
                download_nebula_manual
                ;;
        esac
    fi
    
    # Setup Nebula configuration based on detected hardware
    setup_nebula_config
    
    log_success "Nebula setup completed!"
}

download_nebula_manual() {
    NEBULA_VERSION="v1.9.5"
        case $SYSTEM in
            Linux)
                case $ARCH in
                    x86_64)
                        NEBULA_ARCH="amd64"
                        ;;
                    aarch64|arm64)
                        NEBULA_ARCH="arm64"
                        ;;
                    *)
                        log_error "Unsupported architecture for Nebula: $ARCH"
                        exit 1
                        ;;
                esac
                NEBULA_URL="https://github.com/slackhq/nebula/releases/download/${NEBULA_VERSION}/nebula-linux-${NEBULA_ARCH}.tar.gz"
                ;;
            macOS)
                case $ARCH in
                    x86_64)
                        NEBULA_ARCH="amd64"
                        ;;
                    arm64)
                        NEBULA_ARCH="arm64"
                        ;;
                esac
                NEBULA_URL="https://github.com/slackhq/nebula/releases/download/${NEBULA_VERSION}/nebula-darwin-${NEBULA_ARCH}.tar.gz"
                ;;
        esac
        
        log_info "Downloading Nebula ${NEBULA_VERSION}..."
        curl -L "$NEBULA_URL" | tar -xz
        sudo mv nebula /usr/local/bin/
        sudo mv nebula-cert /usr/local/bin/
        rm -f nebula-*.tar.gz
}

setup_nebula_config() {
    log_step "Setting up Nebula configuration..."
    
    # Create system-wide Nebula directory
    sudo mkdir -p /etc/nebula
    
    # Load hardware configuration if available
    if [[ -f "config/hardware/node_config.env" ]]; then
        source config/hardware/node_config.env
        NODE_ROLE=${GENTLEMAN_NODE_ROLE:-"client"}
        NODE_ID=${GENTLEMAN_NODE_ID:-"$(hostname)"}
        log_info "Detected node role: $NODE_ROLE"
    else
        NODE_ROLE="client"
        NODE_ID="$(hostname)"
        log_warning "No hardware configuration found, using defaults"
    fi
    
    # Setup node-specific configuration
    case $NODE_ROLE in
        "llm-server")
            setup_nebula_llm_server
            ;;
        "audio-server")
            setup_nebula_audio_server
            ;;
        "git-server")
            setup_nebula_git_server
            ;;
        *)
            setup_nebula_client
            ;;
    esac
}

setup_nebula_llm_server() {
    log_info "Configuring Nebula for LLM Server (RX Node)..."
    
    NODE_DIR="/etc/nebula/rx-node"
    sudo mkdir -p "$NODE_DIR"
    
    # Generate certificates if they don't exist
    if [[ ! -f "$NODE_DIR/rx-node.crt" ]]; then
        generate_node_certificates "rx-node" "192.168.100.10/24" "llm-servers,gpu-nodes"
    fi
    
    # Create optimized configuration
    create_nebula_config_llm_server "$NODE_DIR"
    
    # Setup systemd service
    setup_nebula_systemd_service "rx-node" "$NODE_DIR"
}

setup_nebula_audio_server() {
    log_info "Configuring Nebula for Audio Server (M1 Node)..."
    
    NODE_DIR="/etc/nebula/m1-node"
    sudo mkdir -p "$NODE_DIR"
    
    if [[ ! -f "$NODE_DIR/m1-node.crt" ]]; then
        generate_node_certificates "m1-node" "192.168.100.20/24" "audio-services,apple-silicon"
    fi
    
    create_nebula_config_audio_server "$NODE_DIR"
    setup_nebula_systemd_service "m1-node" "$NODE_DIR"
}

setup_nebula_git_server() {
    log_info "Configuring Nebula for Git Server..."
    
    NODE_DIR="/etc/nebula/git-node"
    sudo mkdir -p "$NODE_DIR"
    
    if [[ ! -f "$NODE_DIR/git-node.crt" ]]; then
        generate_node_certificates "git-node" "192.168.100.40/24" "git-servers,storage-nodes"
    fi
    
    create_nebula_config_git_server "$NODE_DIR"
    setup_nebula_systemd_service "git-node" "$NODE_DIR"
}

setup_nebula_client() {
    log_info "Configuring Nebula for Client Node..."
    
    NODE_DIR="/etc/nebula/client-node"
    sudo mkdir -p "$NODE_DIR"
    
    if [[ ! -f "$NODE_DIR/client-node.crt" ]]; then
        generate_node_certificates "client-node" "192.168.100.30/24" "clients,mobile-nodes"
    fi
    
    create_nebula_config_client "$NODE_DIR"
    setup_nebula_systemd_service "client-node" "$NODE_DIR"
}

generate_node_certificates() {
    local node_name="$1"
    local node_ip="$2"
    local node_groups="$3"
    
    log_info "Generating certificates for $node_name..."
    
    # Ensure lighthouse CA exists
    if [[ ! -f "nebula/lighthouse/ca.crt" ]]; then
        mkdir -p nebula/lighthouse
        cd nebula/lighthouse
        nebula-cert ca -name "Gentleman Mesh CA"
        cd ../..
    fi
    
    # Generate node certificate
    cd nebula/lighthouse
    nebula-cert sign -name "$node_name" -ip "$node_ip" -groups "$node_groups"
    
    # Move certificates to system directory
    sudo mv "${node_name}.crt" "/etc/nebula/${node_name}/"
    sudo mv "${node_name}.key" "/etc/nebula/${node_name}/"
    sudo cp ca.crt "/etc/nebula/${node_name}/"
    
    # Set secure permissions
    sudo chmod 600 "/etc/nebula/${node_name}/"*.key
    sudo chmod 644 "/etc/nebula/${node_name}/"*.crt
    
    cd ../..
}

create_nebula_config_llm_server() {
    local node_dir="$1"
    
    sudo tee "$node_dir/config.yml" > /dev/null << 'EOF'
# 🎩 Gentleman LLM Server Node Configuration
pki:
  ca: /etc/nebula/rx-node/ca.crt
  cert: /etc/nebula/rx-node/rx-node.crt
  key: /etc/nebula/rx-node/rx-node.key

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
    - port: 8000-8010
      proto: tcp
      host: any
      groups:
        - audio-services
        - clients
        - monitoring
    - port: 9090-9100
      proto: tcp
      host: any
      groups:
        - monitoring
    - port: 4242
      proto: udp
      host: any
EOF
}

create_nebula_config_audio_server() {
    local node_dir="$1"
    
    sudo tee "$node_dir/config.yml" > /dev/null << 'EOF'
# 🎩 Gentleman Audio Server Node Configuration
pki:
  ca: /etc/nebula/m1-node/ca.crt
  cert: /etc/nebula/m1-node/m1-node.crt
  key: /etc/nebula/m1-node/m1-node.key

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

create_nebula_config_git_server() {
    local node_dir="$1"
    
    sudo tee "$node_dir/config.yml" > /dev/null << 'EOF'
# 🎩 Gentleman Git Server Node Configuration
pki:
  ca: /etc/nebula/git-node/ca.crt
  cert: /etc/nebula/git-node/git-node.crt
  key: /etc/nebula/git-node/git-node.key

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
    
    sudo tee "$node_dir/config.yml" > /dev/null << 'EOF'
# 🎩 Gentleman Client Node Configuration
pki:
  ca: /etc/nebula/client-node/ca.crt
  cert: /etc/nebula/client-node/client-node.crt
  key: /etc/nebula/client-node/client-node.key

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

setup_nebula_systemd_service() {
    local node_name="$1"
    local node_dir="$2"
    
    log_info "Setting up systemd service for $node_name..."
    
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

    # Enable and start service
    sudo systemctl daemon-reload
    sudo systemctl enable "nebula-${node_name}.service"
    
    log_info "Systemd service nebula-${node_name} configured and enabled"
}

# 🔐 Generate Certificates
generate_certificates() {
    log_step "Generating Nebula certificates..."
    
    cd nebula/lighthouse
    
    if [ ! -f ca.crt ]; then
        log_info "Generating CA certificate..."
        nebula-cert ca -name "Gentleman Mesh CA"
    fi
    
    # Generate node certificates with correct IP mapping
    declare -A node_ips=(
        ["lighthouse"]="192.168.100.1"
        ["rx"]="192.168.100.10"
        ["m1"]="192.168.100.20"
        ["i7"]="192.168.100.30"
    )
    
    declare -A node_groups=(
        ["lighthouse"]="lighthouse"
        ["rx"]="llm-servers,gpu-nodes"
        ["m1"]="audio-services,apple-silicon"
        ["i7"]="clients,mobile-nodes"
    )
    
    for node in lighthouse rx m1 i7; do
        if [ ! -f "../${node}-node/${node}.crt" ]; then
            log_info "Generating certificate for ${node} node..."
            nebula-cert sign -name "${node}" -ip "${node_ips[$node]}/24" -groups "${node_groups[$node]}"
            mkdir -p "../${node}-node"
            mv "${node}.crt" "../${node}-node/"
            mv "${node}.key" "../${node}-node/"
            cp ca.crt "../${node}-node/"
        fi
    done
    
    cd ../..
    log_success "Certificates generated!"
}

# 🐍 Python Environment
setup_python_env() {
    log_step "Setting up Python environment..."
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install requirements
    if [ -f requirements.txt ]; then
        pip install -r requirements.txt
    fi
    
    log_success "Python environment ready!"
}

# 🔧 Configuration
setup_configuration() {
    log_step "Setting up configuration..."
    
    # Copy example configuration
    if [ -f .env.example ] && [ ! -f .env ]; then
        cp .env.example .env
        log_info "Created .env file from template"
        
        # Security warning for default passwords
        log_warning "IMPORTANT: Please change default passwords in .env file!"
        log_warning "Especially: GRAFANA_ADMIN_PASSWORD, JWT_SECRET_KEY, ENCRYPTION_KEY"
    fi
    
    # Set up config directories
    mkdir -p config/{environments,security,monitoring}
    
    # Generate default configurations
    cat > config/environments/development.yml << EOF
# 🎩 Gentleman Development Configuration
gentleman:
  debug: true
  log_level: DEBUG
  
services:
  llm-server:
    host: "172.20.1.10"
    port: 8000
    gpu_enabled: true
    
  stt-service:
    host: "172.20.1.20"
    port: 8000
    model: "large-v3"
    language: "de"
    
  tts-service:
    host: "172.20.1.30"
    port: 8000
    voice_model: "coqui-tts"
    emotion_enabled: true

mesh:
  lighthouse: "192.168.100.1"
  port: 4242
EOF
    
    log_success "Configuration setup completed!"
}

# 🧪 Test Installation
test_installation() {
    log_step "Testing installation..."
    
    # Test Docker
    if docker --version >/dev/null 2>&1; then
        log_success "Docker: OK"
    else
        log_error "Docker: FAILED"
        return 1
    fi
    
    # Test Docker Compose
    if docker-compose --version >/dev/null 2>&1; then
        log_success "Docker Compose: OK"
    else
        log_error "Docker Compose: FAILED"
        return 1
    fi
    
    # Test Nebula
    if nebula -version >/dev/null 2>&1; then
        log_success "Nebula: OK"
    else
        log_error "Nebula: FAILED"
        return 1
    fi
    
    # Test Python environment
    if source venv/bin/activate && python -c "import fastapi, torch" 2>/dev/null; then
        log_success "Python Environment: OK"
    else
        log_warning "Python Environment: Some packages may be missing"
    fi
    
    log_success "Installation test completed!"
}

# 🔍 Hardware Detection
run_hardware_detection() {
    log_step "Running hardware detection..."
    
    if [[ -f "$PROJECT_ROOT/scripts/setup/hardware_detection.sh" ]]; then
        chmod +x "$PROJECT_ROOT/scripts/setup/hardware_detection.sh"
        "$PROJECT_ROOT/scripts/setup/hardware_detection.sh"
        
        # Load hardware configuration if available
        if [[ -f "$PROJECT_ROOT/config/hardware/node_config.env" ]]; then
            log_info "Loading hardware-based configuration..."
            set -a
            source "$PROJECT_ROOT/config/hardware/node_config.env"
            set +a
            
            log_success "Hardware configuration loaded: $GENTLEMAN_NODE_ROLE"
        fi
    else
        log_warning "Hardware detection script not found, using manual configuration"
    fi
}

# 🎯 Smart Setup based on Hardware
smart_setup() {
    log_step "Performing smart setup based on detected hardware..."
    
    # Load hardware config if available
    if [[ -f "$PROJECT_ROOT/config/hardware/node_config.env" ]]; then
        source "$PROJECT_ROOT/config/hardware/node_config.env"
        
        case "$GENTLEMAN_NODE_ROLE" in
            "llm-server")
                log_info "🎮 Configuring as LLM Server (GPU-optimized)"
                setup_llm_server_optimizations
                ;;
            "audio-server")
                log_info "🎤 Configuring as Audio Server (M1 Mac optimized)"
                setup_audio_server_optimizations
                ;;
            "git-server")
                log_info "📚 Configuring as Git Server (Development Hub)"
                setup_git_server_optimizations
                ;;
            "client")
                log_info "💻 Configuring as Client (Web Interface)"
                setup_client_optimizations
                ;;
            *)
                log_warning "Unknown node role, using default configuration"
                ;;
        esac
    else
        log_warning "No hardware configuration found, using default setup"
    fi
}

# 🎮 LLM Server Optimizations
setup_llm_server_optimizations() {
    log_step "Setting up LLM Server optimizations..."
    
    # GPU-specific optimizations
    if [[ "$RX6700XT_DETECTED" == "true" ]]; then
        log_info "🎮 Applying AMD RX 6700 XT optimizations..."
        export ROCM_VERSION=5.7
        export HSA_OVERRIDE_GFX_VERSION=10.3.0
        export HIP_VISIBLE_DEVICES=0
        export PYTORCH_HIP_ALLOC_CONF=max_split_size_mb:128
    elif [[ "$NVIDIA_GPUS" -gt 0 ]]; then
        log_info "🟢 Applying NVIDIA GPU optimizations..."
        export CUDA_VISIBLE_DEVICES=0
        export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128
    fi
    
    # CPU optimizations
    export OMP_NUM_THREADS="$CPU_CORES"
    export MKL_NUM_THREADS="$CPU_CORES"
    
    log_success "LLM Server optimizations applied"
}

# 🎤 Audio Server Optimizations
setup_audio_server_optimizations() {
    log_step "Setting up Audio Server optimizations..."
    
    if [[ "$APPLE_SILICON" == "true" ]]; then
        log_info "🍎 Applying Apple Silicon optimizations..."
        export PYTORCH_ENABLE_MPS_FALLBACK=1
        export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
        export STT_DEVICE=mps
        export TTS_DEVICE=mps
    fi
    
    log_success "Audio Server optimizations applied"
}

# 📚 Git Server Optimizations
setup_git_server_optimizations() {
    log_step "Setting up Git Server optimizations..."
    
    # Storage optimizations
    if [[ "$STORAGE_TYPE" == "SSD" ]]; then
        log_info "💿 Applying SSD optimizations..."
        export GIT_PACK_THREADS="$CPU_CORES"
    fi
    
    log_success "Git Server optimizations applied"
}

# 💻 Client Optimizations
setup_client_optimizations() {
    log_step "Setting up Client optimizations..."
    
    # Web interface optimizations
    export FLASK_WORKERS=$((CPU_CORES / 2))
    
    log_success "Client optimizations applied"
}

# 🚀 Main Installation Function
main() {
    print_banner
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-hardware-detection)
                SKIP_HARDWARE_DETECTION=true
                shift
                ;;
            --client-only)
                CLIENT_ONLY=true
                shift
                ;;
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # System detection
    detect_system
    
    # Hardware detection (unless skipped)
    if [[ "$SKIP_HARDWARE_DETECTION" != "true" ]]; then
        run_hardware_detection
    fi
    
    # Dependencies
    check_dependencies
    
    # Docker setup
    setup_docker
    
    # Nebula setup
    setup_nebula
    
    # Smart setup based on hardware
    smart_setup
    
    # Generate certificates
    generate_certificates
    
    # Create environment file
    setup_configuration
    
    # Python environment
    setup_python_env
    
    # Test installation
    test_installation
    
    log_success "🎩 GENTLEMAN installation completed!"
    
    # Show next steps
    echo ""
    log_info "🚀 Next steps:"
    echo "  1. Start services: make gentleman-up-auto"
    echo "  2. Check status: docker-compose ps"
    echo "  3. View logs: docker-compose logs -f"
    echo "  4. Access web interface: http://localhost:8080"
    echo ""
}

# 🎯 Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 