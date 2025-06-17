#!/bin/bash

# 🎩 GENTLEMAN Git Server Setup Script
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# 📋 Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GIT_SERVER_ENV="${PROJECT_ROOT}/.env.git-server"

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

# 🔐 Generate secure secrets
generate_secrets() {
    log "Generating secure secrets for Git server..."
    
    # Generate database password
    GITEA_DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    # Generate Gitea secret key
    GITEA_SECRET_KEY=$(openssl rand -hex 32)
    
    # Generate Gitea internal token
    GITEA_INTERNAL_TOKEN=$(openssl rand -hex 32)
    
    success "Secure secrets generated"
}

# 📝 Create environment file
create_env_file() {
    log "Creating Git server environment file..."
    
    cat > "${GIT_SERVER_ENV}" << EOF
# 🎩 GENTLEMAN Git Server Environment Configuration
# ═══════════════════════════════════════════════════════════════
# Generated on: $(date -Iseconds)

# 🗄️ Database Configuration
GITEA_DB_PASSWORD=${GITEA_DB_PASSWORD}

# 🔐 Gitea Security Configuration
GITEA_SECRET_KEY=${GITEA_SECRET_KEY}
GITEA_INTERNAL_TOKEN=${GITEA_INTERNAL_TOKEN}

# 🌐 Network Configuration
GITEA_DOMAIN=gitea.gentleman.local
GITEA_ROOT_URL=https://gitea.gentleman.local:3000

# 📊 Backup Configuration
BACKUP_RETENTION=30
BACKUP_INTERVAL=86400

# 🔒 SSL Configuration
SSL_CERT_PATH=./config/security/ssl/gentleman.crt
SSL_KEY_PATH=./config/security/ssl/gentleman.key
EOF
    
    chmod 600 "${GIT_SERVER_ENV}"
    success "Environment file created: ${GIT_SERVER_ENV}"
}

# 🏗️ Setup directories
setup_directories() {
    log "Setting up Git server directories..."
    
    mkdir -p "${PROJECT_ROOT}/config/git-server"
    mkdir -p "${PROJECT_ROOT}/scripts/git-server"
    mkdir -p "${PROJECT_ROOT}/data/git-server/backups"
    
    # Set proper permissions
    chmod 755 "${PROJECT_ROOT}/config/git-server"
    chmod 755 "${PROJECT_ROOT}/scripts/git-server"
    chmod 755 "${PROJECT_ROOT}/data/git-server"
    chmod 700 "${PROJECT_ROOT}/data/git-server/backups"
    
    success "Directories created and secured"
}

# 🔒 Setup SSL certificates
setup_ssl() {
    log "Setting up SSL certificates for Git server..."
    
    SSL_DIR="${PROJECT_ROOT}/config/security/ssl"
    
    if [[ ! -f "${SSL_DIR}/gentleman.crt" ]] || [[ ! -f "${SSL_DIR}/gentleman.key" ]]; then
        warning "SSL certificates not found, generating self-signed certificates..."
        
        mkdir -p "${SSL_DIR}"
        
        # Generate self-signed certificate
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "${SSL_DIR}/gentleman.key" \
            -out "${SSL_DIR}/gentleman.crt" \
            -subj "/C=DE/ST=Germany/L=Local/O=Gentleman/OU=Git Server/CN=git.gentleman.local" \
            -addext "subjectAltName=DNS:git.gentleman.local,DNS:gitea.gentleman.local,DNS:localhost,IP:127.0.0.1"
        
        chmod 600 "${SSL_DIR}/gentleman.key"
        chmod 644 "${SSL_DIR}/gentleman.crt"
        
        success "Self-signed SSL certificates generated"
    else
        success "SSL certificates already exist"
    fi
}

# 🌐 Setup hosts file entries
setup_hosts() {
    log "Setting up hosts file entries..."
    
    HOSTS_ENTRIES=(
        "127.0.0.1 git.gentleman.local"
        "127.0.0.1 gitea.gentleman.local"
    )
    
    for entry in "${HOSTS_ENTRIES[@]}"; do
        if ! grep -q "$entry" /etc/hosts 2>/dev/null; then
            warning "Adding hosts entry: $entry"
            echo "# Add this to your /etc/hosts file:"
            echo "$entry"
        else
            success "Hosts entry already exists: $entry"
        fi
    done
}

# 🐳 Docker setup
setup_docker() {
    log "Setting up Docker environment..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Create Docker network if it doesn't exist
    if ! docker network ls | grep -q "gentleman-mesh"; then
        log "Creating gentleman-mesh network..."
        docker network create gentleman-mesh --driver bridge --subnet=172.20.0.0/16
        success "Docker network created"
    else
        success "Docker network already exists"
    fi
    
    success "Docker environment ready"
}

# 🚀 Start Git server
start_git_server() {
    log "Starting Git server..."
    
    cd "${PROJECT_ROOT}"
    
    # Load environment variables
    if [[ -f "${GIT_SERVER_ENV}" ]]; then
        set -a
        source "${GIT_SERVER_ENV}"
        set +a
    fi
    
    # Start services
    docker-compose -f docker-compose.git-server.yml up -d
    
    success "Git server started"
    
    # Wait for services to be ready
    log "Waiting for services to be ready..."
    sleep 10
    
    # Check service health
    check_services
}

# 🏥 Check service health
check_services() {
    log "Checking service health..."
    
    local services=("gitea" "gitea-db" "gitea-nginx")
    local all_healthy=true
    
    for service in "${services[@]}"; do
        if docker-compose -f docker-compose.git-server.yml ps "$service" | grep -q "Up"; then
            success "Service $service is running"
        else
            error "Service $service is not running"
            all_healthy=false
        fi
    done
    
    if $all_healthy; then
        success "All services are healthy"
        show_access_info
    else
        error "Some services are not healthy. Check logs with: docker-compose -f docker-compose.git-server.yml logs"
    fi
}

# 📋 Show access information
show_access_info() {
    echo ""
    echo -e "${PURPLE}🎩 GENTLEMAN Git Server Setup Complete!${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}📍 Access URLs:${NC}"
    echo -e "   🌐 Web Interface: ${GREEN}https://git.gentleman.local${NC}"
    echo -e "   🌐 Direct Gitea:  ${GREEN}https://gitea.gentleman.local:3000${NC}"
    echo -e "   🔗 SSH Git:       ${GREEN}ssh://git@gitea.gentleman.local:2222${NC}"
    echo ""
    echo -e "${CYAN}🔐 First Time Setup:${NC}"
    echo -e "   1. Open ${GREEN}https://git.gentleman.local${NC} in your browser"
    echo -e "   2. Complete the initial Gitea setup"
    echo -e "   3. Create your admin account"
    echo -e "   4. Create your first repository"
    echo ""
    echo -e "${CYAN}📊 Management Commands:${NC}"
    echo -e "   🚀 Start:    ${GREEN}make git-start${NC}"
    echo -e "   🛑 Stop:     ${GREEN}make git-stop${NC}"
    echo -e "   📊 Status:   ${GREEN}make git-status${NC}"
    echo -e "   📋 Logs:     ${GREEN}make git-logs${NC}"
    echo -e "   💾 Backup:   ${GREEN}make git-backup${NC}"
    echo ""
    echo -e "${CYAN}🔒 Security Notes:${NC}"
    echo -e "   • SSL certificates are self-signed (accept in browser)"
    echo -e "   • Database password: ${YELLOW}[Generated securely]${NC}"
    echo -e "   • Change default admin password after first login"
    echo -e "   • Enable 2FA for admin account"
    echo ""
}

# 🧹 Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    # Add cleanup logic if needed
}

# 🚀 Main execution
main() {
    echo -e "${PURPLE}🎩 GENTLEMAN Git Server Setup${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check prerequisites
    log "Checking prerequisites..."
    
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1; then
        error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    if ! command -v openssl >/dev/null 2>&1; then
        error "OpenSSL is not installed. Please install OpenSSL first."
        exit 1
    fi
    
    success "Prerequisites check passed"
    
    # Setup process
    generate_secrets
    create_env_file
    setup_directories
    setup_ssl
    setup_hosts
    setup_docker
    start_git_server
    
    success "🎩 GENTLEMAN Git Server setup completed successfully!"
}

# Trap cleanup on exit
trap cleanup EXIT

# Execute main function
main "$@" 