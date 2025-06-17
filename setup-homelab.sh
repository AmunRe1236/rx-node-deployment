#!/bin/bash

# 🎩 GENTLEMAN - Complete Homelab Setup
# ═══════════════════════════════════════════════════════════════
# Vollständiges Self-Hosting Setup für macOS M1

set -e

# 🎨 Colors for elegant output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 🎩 Banner
print_banner() {
    echo -e "${PURPLE}"
    echo "🎩 GENTLEMAN - Complete Homelab Setup"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${WHITE}🏠 Setting up your complete self-hosted ecosystem${NC}"
    echo ""
}

# 📝 Logging Functions
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
    echo -e "${WHITE}🔧 $1${NC}"
}

# 🔍 System Detection
detect_system() {
    log_step "Detecting system architecture..."
    
    OS=$(uname -s)
    ARCH=$(uname -m)
    
    case $OS in
        Darwin*)
            SYSTEM="macOS"
            VERSION=$(sw_vers -productVersion)
            if [[ $ARCH == "arm64" ]]; then
                DISTRO="Apple Silicon"
            else
                DISTRO="Intel"
            fi
            ;;
        *)
            log_error "This homelab setup is optimized for macOS. For other systems, use the standard setup.sh"
            exit 1
            ;;
    esac
    
    log_info "System: $SYSTEM ($DISTRO $VERSION) - $ARCH"
}

# 📁 Create Directory Structure
create_directories() {
    log_step "Creating homelab directory structure..."
    
    # Main directories
    mkdir -p {config,data,logs,media,backups}
    
    # Service-specific config directories
    mkdir -p config/{homelab,security,monitoring}
    mkdir -p config/homelab/{mosquitto,nextcloud,traefik,truenas,healthchecks}
    mkdir -p config/security/{ssl,acme}
    mkdir -p monitoring/homelab/{dashboards,datasources}
    
    # Data directories
    mkdir -p data/{git,nextcloud,homeassistant,media,backups}
    mkdir -p media/{movies,tv,music,photos}
    
    # Log directories
    mkdir -p logs/{services,monitoring,security}
    
    log_success "Directory structure created!"
}

# 🔐 Generate Security Configuration
generate_security_config() {
    log_step "Generating security configuration..."
    
    # Generate random passwords and keys
    GITEA_DB_PASSWORD=$(openssl rand -hex 16)
    NEXTCLOUD_DB_PASSWORD=$(openssl rand -hex 16)
    NEXTCLOUD_ADMIN_PASSWORD=$(openssl rand -hex 12)
    GRAFANA_ADMIN_PASSWORD=$(openssl rand -hex 12)
    VAULTWARDEN_ADMIN_TOKEN=$(openssl rand -hex 32)
    HEALTHCHECKS_SECRET_KEY=$(openssl rand -hex 32)
    JWT_SECRET_KEY=$(openssl rand -hex 32)
    ENCRYPTION_KEY=$(openssl rand -hex 32)
    
    # Create .env file for homelab
    cat > .env.homelab << EOF
# 🎩 GENTLEMAN Homelab Environment Configuration
# ═══════════════════════════════════════════════════════════════
# WICHTIG: Diese Datei enthält sensible Daten - niemals committen!

# 🌐 Network Configuration
LIGHTHOUSE_IP=192.168.68.111
HOMELAB_DOMAIN=gentleman.local

# 📚 Git Server (Gitea)
GITEA_DB_PASSWORD=${GITEA_DB_PASSWORD}
GITEA_API_TOKEN=  # Nach Setup generieren
GITEA_ADMIN_USER=gentleman
GITEA_ADMIN_EMAIL=admin@gentleman.local

# ☁️ Nextcloud
NEXTCLOUD_DB_PASSWORD=${NEXTCLOUD_DB_PASSWORD}
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=${NEXTCLOUD_ADMIN_PASSWORD}

# 🏠 Home Assistant
HOMEASSISTANT_TOKEN=  # Nach Setup generieren

# 📧 ProtonMail Bridge
PROTONMAIL_USERNAME=  # Ihre ProtonMail E-Mail
PROTONMAIL_PASSWORD=  # Ihr ProtonMail Passwort
PROTONMAIL_2FA_CODE=  # 2FA Code falls aktiviert

# 📊 TrueNAS/FreeNAS Integration
TRUENAS_HOST=truenas.local
TRUENAS_API_KEY=  # TrueNAS API Key
TRUENAS_USERNAME=root

# 📊 Monitoring
GRAFANA_ADMIN_USER=gentleman
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}

# 🔐 Vaultwarden (Bitwarden)
VAULTWARDEN_ADMIN_TOKEN=${VAULTWARDEN_ADMIN_TOKEN}

# 🛡️ Pi-hole
PIHOLE_PASSWORD=gentleman_dns_admin

# 🏥 Healthchecks
HEALTHCHECKS_SECRET_KEY=${HEALTHCHECKS_SECRET_KEY}

# 🔄 Watchtower (Auto Updates)
WATCHTOWER_EMAIL_FROM=watchtower@gentleman.local
WATCHTOWER_EMAIL_TO=admin@gentleman.local
WATCHTOWER_EMAIL_SERVER=protonmail-bridge

# 🌐 Traefik (Reverse Proxy)
ACME_EMAIL=admin@gentleman.local

# 🔐 Security
JWT_SECRET_KEY=${JWT_SECRET_KEY}
ENCRYPTION_KEY=${ENCRYPTION_KEY}

# 🐳 Docker
COMPOSE_PROJECT_NAME=gentleman-homelab
EOF

    # Create SSL directory and placeholder files
    mkdir -p config/security/ssl
    touch config/security/acme.json
    chmod 600 config/security/acme.json
    
    log_success "Security configuration generated!"
    log_warning "Please review and update .env.homelab with your specific settings"
}

# 📝 Create Configuration Files
create_config_files() {
    log_step "Creating service configuration files..."
    
    # Mosquitto MQTT Configuration
    cat > config/homelab/mosquitto.conf << 'EOF'
# Mosquitto MQTT Broker Configuration
listener 1883
allow_anonymous true
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
log_type error
log_type warning
log_type notice
log_type information
connection_messages true
log_timestamp true
EOF

    # Nextcloud Custom Configuration
    cat > config/homelab/nextcloud.config.php << 'EOF'
<?php
$CONFIG = array(
  'trusted_domains' => array(
    'cloud.gentleman.local',
    '192.168.68.111',
    'localhost'
  ),
  'overwrite.cli.url' => 'https://cloud.gentleman.local',
  'htaccess.RewriteBase' => '/',
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'apps_paths' => array(
    array(
      'path' => '/var/www/html/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    array(
      'path' => '/var/www/html/custom_apps',
      'url' => '/custom_apps',
      'writable' => true,
    ),
  ),
  'default_phone_region' => 'DE',
  'maintenance' => false,
);
EOF

    # TrueNAS Integration Configuration
    cat > config/homelab/truenas.yml << 'EOF'
# TrueNAS/FreeNAS Integration Configuration
truenas:
  host: truenas.local
  protocol: https
  port: 443
  verify_ssl: false
  
sync:
  enabled: true
  interval: 300  # 5 minutes
  datasets:
    - name: gentleman/models
      local_path: /data/models
      sync_direction: bidirectional
    - name: gentleman/media
      local_path: /media
      sync_direction: pull
    - name: gentleman/backups
      local_path: /backups
      sync_direction: push

backup:
  enabled: true
  schedule: "0 2 * * *"  # Daily at 2 AM
  retention: 30  # days
  compression: gzip
  
monitoring:
  enabled: true
  metrics:
    - disk_usage
    - pool_health
    - dataset_snapshots
    - replication_status
EOF

    # Prometheus Configuration for Homelab
    mkdir -p monitoring/homelab
    cat > monitoring/homelab/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  # Gentleman Core Services
  - job_name: 'gentleman-core'
    static_configs:
      - targets: ['192.168.100.10:8001', '192.168.100.20:8002', '192.168.100.20:8003']
    metrics_path: /metrics
    scrape_interval: 30s

  # Homelab Services
  - job_name: 'homelab-services'
    static_configs:
      - targets: 
        - 'gitea:3000'
        - 'nextcloud:80'
        - 'homeassistant:8123'
        - 'jellyfin:8096'
        - 'vaultwarden:80'
        - 'pihole:80'
    metrics_path: /metrics
    scrape_interval: 30s

  # System Monitoring
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['host.docker.internal:9100']
    scrape_interval: 15s

  # Docker Monitoring
  - job_name: 'docker'
    static_configs:
      - targets: ['host.docker.internal:9323']
    scrape_interval: 15s

  # TrueNAS Monitoring
  - job_name: 'truenas'
    static_configs:
      - targets: ['truenas.local:9100']
    scrape_interval: 60s
    metrics_path: /metrics
EOF

    # Grafana Datasources
    cat > monitoring/homelab/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true
EOF

    # Loki Configuration
    cat > monitoring/homelab/loki.yml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 1h
  max_chunk_age: 1h
  chunk_target_size: 1048576
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
EOF

    log_success "Configuration files created!"
}

# 🌐 Setup Hosts File
setup_hosts() {
    log_step "Setting up local DNS entries..."
    
    HOSTS_ENTRIES=(
        "127.0.0.1 git.gentleman.local"
        "127.0.0.1 cloud.gentleman.local"
        "127.0.0.1 ha.gentleman.local"
        "127.0.0.1 media.gentleman.local"
        "127.0.0.1 vault.gentleman.local"
        "127.0.0.1 dns.gentleman.local"
        "127.0.0.1 proxy.gentleman.local"
        "127.0.0.1 health.gentleman.local"
        "127.0.0.1 bridge.gentleman.local"
    )
    
    log_info "Add these entries to your /etc/hosts file:"
    for entry in "${HOSTS_ENTRIES[@]}"; do
        echo "  $entry"
    done
    
    log_warning "Run: sudo nano /etc/hosts and add the entries above"
}

# 🐳 Setup Docker Networks
setup_docker_networks() {
    log_step "Setting up Docker networks..."
    
    # Create networks if they don't exist
    docker network create gentleman-mesh --driver bridge --subnet=172.20.0.0/16 2>/dev/null || true
    docker network create gentleman-homelab --driver bridge --subnet=172.22.0.0/16 2>/dev/null || true
    docker network create gentleman-homeassistant --driver bridge --subnet=172.23.0.0/16 2>/dev/null || true
    
    log_success "Docker networks created!"
}

# 📦 Create Service Scripts
create_service_scripts() {
    log_step "Creating service management scripts..."
    
    # Create scripts directory
    mkdir -p scripts/homelab
    
    # Start Homelab Script
    cat > scripts/homelab/start.sh << 'EOF'
#!/bin/bash
echo "🎩 Starting GENTLEMAN Homelab..."

# Load environment
set -a
source .env.homelab
set +a

# Start core services first
echo "Starting core infrastructure..."
docker-compose -f docker-compose.homelab.yml up -d \
    gitea-db gitea \
    nextcloud-db nextcloud \
    mosquitto \
    prometheus grafana loki \
    traefik

# Wait for core services
sleep 30

# Start application services
echo "Starting application services..."
docker-compose -f docker-compose.homelab.yml up -d \
    homeassistant \
    protonmail-bridge \
    pihole \
    vaultwarden \
    jellyfin \
    truenas-sync \
    homelab-bridge

# Start monitoring and maintenance
echo "Starting monitoring services..."
docker-compose -f docker-compose.homelab.yml up -d \
    watchtower \
    healthchecks

echo "✅ GENTLEMAN Homelab started!"
echo ""
echo "🌐 Access your services:"
echo "  Git Server:      http://git.gentleman.local:3000"
echo "  Nextcloud:       http://cloud.gentleman.local:8080"
echo "  Home Assistant:  http://ha.gentleman.local:8123"
echo "  Media Server:    http://media.gentleman.local:8096"
echo "  Password Manager: http://vault.gentleman.local:8082"
echo "  DNS Admin:       http://dns.gentleman.local:8081"
echo "  Monitoring:      http://localhost:3001"
echo "  Proxy Dashboard: http://proxy.gentleman.local:8083"
echo ""
EOF

    # Stop Homelab Script
    cat > scripts/homelab/stop.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping GENTLEMAN Homelab..."

docker-compose -f docker-compose.homelab.yml down

echo "✅ GENTLEMAN Homelab stopped!"
EOF

    # Status Script
    cat > scripts/homelab/status.sh << 'EOF'
#!/bin/bash
echo "🎩 GENTLEMAN Homelab Status"
echo "═══════════════════════════════════════════════════════════════"

docker-compose -f docker-compose.homelab.yml ps

echo ""
echo "🌐 Service URLs:"
echo "  Git Server:      http://git.gentleman.local:3000"
echo "  Nextcloud:       http://cloud.gentleman.local:8080"
echo "  Home Assistant:  http://ha.gentleman.local:8123"
echo "  Media Server:    http://media.gentleman.local:8096"
echo "  Password Manager: http://vault.gentleman.local:8082"
echo "  DNS Admin:       http://dns.gentleman.local:8081"
echo "  Monitoring:      http://localhost:3001"
echo "  Proxy Dashboard: http://proxy.gentleman.local:8083"
echo "  Health Monitor:  http://health.gentleman.local:8084"
echo "  Homelab Bridge:  http://bridge.gentleman.local:8090"
EOF

    # Update Script
    cat > scripts/homelab/update.sh << 'EOF'
#!/bin/bash
echo "🔄 Updating GENTLEMAN Homelab..."

# Pull latest images
docker-compose -f docker-compose.homelab.yml pull

# Restart services with new images
docker-compose -f docker-compose.homelab.yml up -d

echo "✅ GENTLEMAN Homelab updated!"
EOF

    # Backup Script
    cat > scripts/homelab/backup.sh << 'EOF'
#!/bin/bash
echo "💾 Backing up GENTLEMAN Homelab..."

BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup configurations
cp -r config "$BACKUP_DIR/"
cp .env.homelab "$BACKUP_DIR/"
cp docker-compose.homelab.yml "$BACKUP_DIR/"

# Backup Docker volumes
docker run --rm -v gentleman-homelab_gitea-data:/data -v "$PWD/$BACKUP_DIR":/backup alpine tar czf /backup/gitea-data.tar.gz -C /data .
docker run --rm -v gentleman-homelab_nextcloud-data:/data -v "$PWD/$BACKUP_DIR":/backup alpine tar czf /backup/nextcloud-data.tar.gz -C /data .
docker run --rm -v gentleman-homelab_homeassistant-config:/data -v "$PWD/$BACKUP_DIR":/backup alpine tar czf /backup/homeassistant-config.tar.gz -C /data .
docker run --rm -v gentleman-homelab_vaultwarden-data:/data -v "$PWD/$BACKUP_DIR":/backup alpine tar czf /backup/vaultwarden-data.tar.gz -C /data .

echo "✅ Backup completed: $BACKUP_DIR"
EOF

    # Make scripts executable
    chmod +x scripts/homelab/*.sh
    
    log_success "Service scripts created!"
}

# 🚀 Main Setup Function
main() {
    print_banner
    
    # System detection
    detect_system
    
    # Check if basic setup was run
    if [ ! -f "nebula/rx-node/config.yml" ]; then
        log_error "Please run ./setup.sh first to set up the basic GENTLEMAN system"
        exit 1
    fi
    
    log_step "Setting up complete GENTLEMAN Homelab..."
    echo "═══════════════════════════════════════════════════════════════"
    
    # Setup steps
    create_directories
    generate_security_config
    create_config_files
    setup_hosts
    setup_docker_networks
    create_service_scripts
    
    echo ""
    log_success "🎉 GENTLEMAN Homelab setup completed!"
    echo ""
    log_step "Next Steps:"
    echo "═══════════════════════════════════════════════════════════════"
    echo "1. Review and update .env.homelab with your settings"
    echo "2. Add hosts entries to /etc/hosts (shown above)"
    echo "3. Configure ProtonMail credentials in .env.homelab"
    echo "4. Set up TrueNAS API key if you have TrueNAS"
    echo "5. Start the homelab: ./scripts/homelab/start.sh"
    echo ""
    log_info "📚 Available commands:"
    echo "  Start:   ./scripts/homelab/start.sh"
    echo "  Stop:    ./scripts/homelab/stop.sh"
    echo "  Status:  ./scripts/homelab/status.sh"
    echo "  Update:  ./scripts/homelab/update.sh"
    echo "  Backup:  ./scripts/homelab/backup.sh"
    echo ""
    log_warning "🔐 Security: Change all default passwords in .env.homelab!"
    echo ""
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 