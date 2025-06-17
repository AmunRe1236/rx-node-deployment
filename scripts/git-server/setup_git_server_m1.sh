#!/bin/bash

# 🎩 GENTLEMAN Git Server Setup für M1 Mac
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# 📋 Configuration für M1 Mac
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GIT_SERVER_ENV="${PROJECT_ROOT}/.env.git-server"
M1_IP="192.168.100.20"  # M1 Mac IP im Netzwerk

# 🎨 Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 📝 Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# 🍎 M1 Mac spezifische Checks
check_m1_prerequisites() {
    log "Checking M1 Mac prerequisites..."
    
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        error "This script is designed for M1 Mac (macOS). Current OS: $(uname)"
        exit 1
    fi
    
    # Check if running on Apple Silicon
    if [[ "$(uname -m)" != "arm64" ]]; then
        warning "Not running on Apple Silicon (arm64). Current architecture: $(uname -m)"
        warning "This may still work but is optimized for M1/M2 Macs"
    fi
    
    # Check Docker Desktop for Mac
    if ! docker info >/dev/null 2>&1; then
        error "Docker Desktop for Mac is not running. Please start Docker Desktop first."
        exit 1
    fi
    
    # Check available resources
    local memory_gb=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
    if [[ $memory_gb -lt 8 ]]; then
        warning "Less than 8GB RAM detected (${memory_gb}GB). Git server may run slowly."
    else
        success "Sufficient RAM detected: ${memory_gb}GB"
    fi
    
    success "M1 Mac prerequisites check passed"
}

# 🔐 Generate secure secrets für M1
generate_m1_secrets() {
    log "Generating secure secrets for M1 Git server..."
    
    # Use macOS native tools where possible
    GITEA_DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    GITEA_SECRET_KEY=$(openssl rand -hex 32)
    GITEA_INTERNAL_TOKEN=$(openssl rand -hex 32)
    
    success "Secure secrets generated using macOS tools"
}

# 📝 Create M1-optimized environment file
create_m1_env_file() {
    log "Creating M1 Mac Git server environment file..."
    
    cat > "${GIT_SERVER_ENV}" << EOF
# 🎩 GENTLEMAN Git Server Environment Configuration (M1 Mac)
# ═══════════════════════════════════════════════════════════════
# Generated on: $(date -Iseconds)
# Host: M1 Mac ($(hostname))
# IP: ${M1_IP}

# 🗄️ Database Configuration
GITEA_DB_PASSWORD=${GITEA_DB_PASSWORD}

# 🔐 Gitea Security Configuration
GITEA_SECRET_KEY=${GITEA_SECRET_KEY}
GITEA_INTERNAL_TOKEN=${GITEA_INTERNAL_TOKEN}

# 🌐 Network Configuration (M1 Mac)
GITEA_DOMAIN=git.gentleman.local
GITEA_ROOT_URL=https://git.gentleman.local:3000
GITEA_SSH_DOMAIN=${M1_IP}
GITEA_SSH_PORT=2222

# 📊 Backup Configuration
BACKUP_RETENTION=30
BACKUP_INTERVAL=86400

# 🔒 SSL Configuration
SSL_CERT_PATH=./config/security/ssl/gentleman.crt
SSL_KEY_PATH=./config/security/ssl/gentleman.key

# 🍎 M1 Mac Optimizations
DOCKER_PLATFORM=linux/arm64
COMPOSE_DOCKER_CLI_BUILD=1
DOCKER_BUILDKIT=1
EOF
    
    chmod 600 "${GIT_SERVER_ENV}"
    success "M1 Mac environment file created: ${GIT_SERVER_ENV}"
}

# 🏗️ Setup M1-optimized directories
setup_m1_directories() {
    log "Setting up M1 Mac Git server directories..."
    
    # Create directories with macOS-friendly permissions
    mkdir -p "${PROJECT_ROOT}/config/git-server"
    mkdir -p "${PROJECT_ROOT}/scripts/git-server"
    mkdir -p "${PROJECT_ROOT}/data/git-server/backups"
    mkdir -p "${PROJECT_ROOT}/data/git-server/repositories"
    mkdir -p "${PROJECT_ROOT}/logs/git-server"
    
    # Set macOS-appropriate permissions
    chmod 755 "${PROJECT_ROOT}/config/git-server"
    chmod 755 "${PROJECT_ROOT}/scripts/git-server"
    chmod 755 "${PROJECT_ROOT}/data/git-server"
    chmod 700 "${PROJECT_ROOT}/data/git-server/backups"
    chmod 755 "${PROJECT_ROOT}/data/git-server/repositories"
    chmod 755 "${PROJECT_ROOT}/logs/git-server"
    
    success "M1 Mac directories created and secured"
}

# 🔒 Setup SSL certificates für M1
setup_m1_ssl() {
    log "Setting up SSL certificates for M1 Mac Git server..."
    
    SSL_DIR="${PROJECT_ROOT}/config/security/ssl"
    
    if [[ ! -f "${SSL_DIR}/gentleman.crt" ]] || [[ ! -f "${SSL_DIR}/gentleman.key" ]]; then
        warning "SSL certificates not found, generating M1-optimized certificates..."
        
        mkdir -p "${SSL_DIR}"
        
        # Generate certificate with M1 Mac specific settings
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "${SSL_DIR}/gentleman.key" \
            -out "${SSL_DIR}/gentleman.crt" \
            -subj "/C=DE/ST=Germany/L=Local/O=Gentleman/OU=Git Server M1/CN=git.gentleman.local" \
            -addext "subjectAltName=DNS:git.gentleman.local,DNS:gitea.gentleman.local,DNS:$(hostname).local,IP:${M1_IP},IP:127.0.0.1"
        
        chmod 600 "${SSL_DIR}/gentleman.key"
        chmod 644 "${SSL_DIR}/gentleman.crt"
        
        success "M1 Mac SSL certificates generated with local network support"
    else
        success "SSL certificates already exist"
    fi
}

# 🌐 Setup M1 network configuration
setup_m1_network() {
    log "Setting up M1 Mac network configuration..."
    
    # Check if we can bind to the required ports
    local ports_to_check=(80 443 3000 2222)
    local port_conflicts=()
    
    for port in "${ports_to_check[@]}"; do
        if lsof -i :$port >/dev/null 2>&1; then
            port_conflicts+=($port)
        fi
    done
    
    if [[ ${#port_conflicts[@]} -gt 0 ]]; then
        warning "Port conflicts detected: ${port_conflicts[*]}"
        warning "You may need to stop other services or modify port mappings"
    else
        success "All required ports are available"
    fi
    
    # Add hosts entries for local development
    info "Adding hosts entries for M1 Mac..."
    echo "# Add these entries to /etc/hosts on all devices in your network:"
    echo "${M1_IP} git.gentleman.local"
    echo "${M1_IP} gitea.gentleman.local"
    echo "127.0.0.1 git.gentleman.local"
    echo "127.0.0.1 gitea.gentleman.local"
}

# 🐳 Setup Docker für M1
setup_m1_docker() {
    log "Setting up Docker environment for M1 Mac..."
    
    # Check Docker Desktop settings
    local docker_info=$(docker info 2>/dev/null)
    
    if echo "$docker_info" | grep -q "Architecture: aarch64"; then
        success "Docker is running with ARM64 architecture"
    else
        warning "Docker may not be optimized for Apple Silicon"
    fi
    
    # Create Docker network if it doesn't exist
    if ! docker network ls | grep -q "gentleman-mesh"; then
        log "Creating gentleman-mesh network for M1..."
        docker network create gentleman-mesh --driver bridge --subnet=172.20.0.0/16
        success "Docker network created"
    else
        success "Docker network already exists"
    fi
    
    # Set Docker BuildKit for better M1 performance
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    
    success "M1 Mac Docker environment ready"
}

# 🚀 Start Git server on M1
start_m1_git_server() {
    log "Starting Git server on M1 Mac..."
    
    cd "${PROJECT_ROOT}"
    
    # Load environment variables
    if [[ -f "${GIT_SERVER_ENV}" ]]; then
        set -a
        source "${GIT_SERVER_ENV}"
        set +a
    fi
    
    # Use M1-optimized Docker Compose
    DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 \
    docker-compose -f docker-compose.git-server.yml up -d
    
    success "Git server started on M1 Mac"
    
    # Wait for services to be ready
    log "Waiting for services to be ready..."
    sleep 15
    
    # Check service health
    check_m1_services
}

# 🏥 Check M1 service health
check_m1_services() {
    log "Checking M1 Git server health..."
    
    local services=("gitea" "gitea-db" "gitea-nginx")
    local all_healthy=true
    
    for service in "${services[@]}"; do
        if docker-compose -f docker-compose.git-server.yml ps "$service" | grep -q "Up"; then
            success "Service $service is running on M1"
        else
            error "Service $service is not running on M1"
            all_healthy=false
        fi
    done
    
    # Test network connectivity
    if curl -f -s -k "https://localhost:3000/api/healthz" >/dev/null 2>&1; then
        success "Gitea is accessible on M1 Mac"
    else
        warning "Gitea may still be starting up..."
    fi
    
    if $all_healthy; then
        success "All services are healthy on M1 Mac"
        show_m1_access_info
    else
        error "Some services are not healthy. Check logs with: make git-logs"
    fi
}

# 📋 Show M1 access information
show_m1_access_info() {
    echo ""
    echo -e "${PURPLE}🎩 GENTLEMAN Git Server auf M1 Mac bereit!${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}📍 Zugriff von M1 Mac (lokal):${NC}"
    echo -e "   🌐 Web Interface: ${GREEN}https://localhost:3000${NC}"
    echo -e "   🌐 Nginx Proxy:   ${GREEN}https://localhost${NC}"
    echo -e "   🔗 SSH Git:       ${GREEN}ssh://git@localhost:2222${NC}"
    echo ""
    echo -e "${CYAN}📍 Zugriff aus dem Netzwerk:${NC}"
    echo -e "   🌐 Web Interface: ${GREEN}https://${M1_IP}:3000${NC}"
    echo -e "   🌐 Nginx Proxy:   ${GREEN}https://${M1_IP}${NC}"
    echo -e "   🔗 SSH Git:       ${GREEN}ssh://git@${M1_IP}:2222${NC}"
    echo ""
    echo -e "${CYAN}📍 Mit Hostnamen (nach /etc/hosts Eintrag):${NC}"
    echo -e "   🌐 Web Interface: ${GREEN}https://git.gentleman.local${NC}"
    echo -e "   🔗 SSH Git:       ${GREEN}ssh://git@git.gentleman.local:2222${NC}"
    echo ""
    echo -e "${CYAN}🔐 Erstmalige Einrichtung:${NC}"
    echo -e "   1. Öffne ${GREEN}https://git.gentleman.local${NC} im Browser"
    echo -e "   2. Akzeptiere das SSL-Zertifikat"
    echo -e "   3. Folge dem Gitea Setup-Assistenten"
    echo -e "   4. Erstelle deinen Admin-Account"
    echo ""
    echo -e "${CYAN}🍎 M1 Mac spezifische Hinweise:${NC}"
    echo -e "   • Docker Desktop sollte mindestens 4GB RAM zugewiesen haben"
    echo -e "   • Firewall-Einstellungen prüfen für Netzwerkzugriff"
    echo -e "   • Time Machine Backups schließen Git-Daten ein"
    echo ""
    echo -e "${CYAN}🌐 Netzwerk-Integration:${NC}"
    echo -e "   • Worker Node kann auf ${GREEN}https://${M1_IP}:3000${NC} zugreifen"
    echo -e "   • Andere Geräte im Netzwerk können Git-Server nutzen"
    echo -e "   • Nebula VPN Integration verfügbar"
    echo ""
}

# 🚀 Main execution für M1
main() {
    echo -e "${PURPLE}🎩 GENTLEMAN Git Server Setup für M1 Mac${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # M1 Mac specific checks
    check_m1_prerequisites
    
    # Setup process optimized for M1
    generate_m1_secrets
    create_m1_env_file
    setup_m1_directories
    setup_m1_ssl
    setup_m1_network
    setup_m1_docker
    start_m1_git_server
    
    success "🎩 GENTLEMAN Git Server auf M1 Mac erfolgreich eingerichtet!"
}

# Execute main function
main "$@" 