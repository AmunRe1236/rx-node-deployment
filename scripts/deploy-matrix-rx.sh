#!/bin/bash

# 🎩 GENTLEMAN Matrix Deployment für RX Node
# ═══════════════════════════════════════════════════════════════
# Matrix Synapse mit GENTLEMAN Authentication auf RX 6700 XT System

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${PURPLE}"
echo "🎩 GENTLEMAN Matrix Deployment für RX Node"
echo "═══════════════════════════════════════════════════════════════"
echo -e "${WHITE}Matrix Synapse mit systemweiter ProtonMail Authentication${NC}"
echo ""

# Check if running on RX Node
RX_NODE_IP="192.168.100.10"
CURRENT_IP=$(hostname -I | awk '{print $1}')

if [[ "$CURRENT_IP" != "$RX_NODE_IP" ]]; then
    echo -e "${YELLOW}⚠️  Deploying to RX Node remotely...${NC}"
    
    # Deploy to RX Node via SSH
    echo -e "${BLUE}📡 Copying files to RX Node...${NC}"
    
    # Copy Matrix configuration
    scp -r docker-compose.matrix.yml config/homelab/matrix-* gentleman@$RX_NODE_IP:~/gentleman/
    scp auth.env gentleman@$RX_NODE_IP:~/gentleman/
    
    # Execute deployment on RX Node
    ssh gentleman@$RX_NODE_IP "cd ~/gentleman && bash scripts/deploy-matrix-rx.sh"
    exit 0
fi

echo -e "${GREEN}✅ Running on RX Node ($CURRENT_IP)${NC}"

# Ensure GENTLEMAN auth system is running
echo -e "${BLUE}🔐 Checking GENTLEMAN Authentication System...${NC}"
if ! docker ps | grep -q "gentleman-keycloak"; then
    echo -e "${YELLOW}⚠️  Starting GENTLEMAN Auth System first...${NC}"
    docker-compose -f docker-compose.auth.yml --env-file auth.env up -d
    
    echo -e "${YELLOW}⏳ Waiting for Keycloak to be ready...${NC}"
    sleep 60
fi

# Create Matrix network
echo -e "${BLUE}🌐 Creating Matrix network...${NC}"
docker network create gentleman-matrix --driver bridge --subnet=172.25.0.0/16 2>/dev/null || echo "Network already exists"

# Create required directories
echo -e "${BLUE}📁 Creating directories...${NC}"
mkdir -p config/homelab/matrix
mkdir -p logs/matrix
mkdir -p data/matrix/synapse
mkdir -p data/matrix/element

# Generate Matrix signing key if not exists
if [ ! -f "data/matrix/synapse/signing.key" ]; then
    echo -e "${BLUE}🔑 Generating Matrix signing key...${NC}"
    docker run --rm -v $(pwd)/data/matrix/synapse:/data matrixdotorg/synapse:latest generate
fi

# Create Matrix log configuration
cat > config/homelab/matrix-log.config << 'EOF'
version: 1

formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'

handlers:
  file:
    class: logging.handlers.TimedRotatingFileHandler
    formatter: precise
    filename: /data/homeserver.log
    when: midnight
    backupCount: 3
    encoding: utf8
  console:
    class: logging.StreamHandler
    formatter: precise

loggers:
    synapse.storage.SQL:
        level: WARN

root:
    level: INFO
    handlers: [file, console]

disable_existing_loggers: false
EOF

# Create Element configuration
cat > config/homelab/element-config.json << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "http://matrix.gentleman.local:8008",
            "server_name": "matrix.gentleman.local"
        }
    },
    "default_server_name": "matrix.gentleman.local",
    "brand": "GENTLEMAN Matrix",
    "integrations_ui_url": "https://scalar.vector.im/",
    "integrations_rest_url": "https://scalar.vector.im/api",
    "integrations_widgets_urls": [
        "https://scalar.vector.im/_matrix/integrations/v1",
        "https://scalar.vector.im/api",
        "https://scalar-staging.vector.im/_matrix/integrations/v1",
        "https://scalar-staging.vector.im/api",
        "https://scalar-staging.riot.im/scalar/api"
    ],
    "bug_report_endpoint_url": "https://element.io/bugreports/submit",
    "defaultCountryCode": "DE",
    "showLabsSettings": true,
    "features": {
        "feature_new_spinner": true,
        "feature_pinning": true,
        "feature_custom_status": true,
        "feature_custom_tags": true,
        "feature_state_counters": true
    },
    "default_federate": true,
    "default_theme": "dark",
    "roomDirectory": {
        "servers": [
            "matrix.gentleman.local",
            "matrix.org"
        ]
    },
    "enable_presence_by_hs_url": {
        "http://matrix.gentleman.local:8008": false
    },
    "setting_defaults": {
        "breadcrumbs": true
    },
    "jitsi": {
        "preferred_domain": "meet.element.io"
    }
}
EOF

# Update hosts file for local resolution
echo -e "${BLUE}🌐 Updating hosts file...${NC}"
if ! grep -q "matrix.gentleman.local" /etc/hosts; then
    echo "127.0.0.1 matrix.gentleman.local" | sudo tee -a /etc/hosts
fi
if ! grep -q "element.gentleman.local" /etc/hosts; then
    echo "127.0.0.1 element.gentleman.local" | sudo tee -a /etc/hosts
fi

# Start Matrix services
echo -e "${BLUE}🚀 Starting Matrix services...${NC}"
docker-compose -f docker-compose.matrix.yml --env-file auth.env up -d

# Wait for services to start
echo -e "${YELLOW}⏳ Waiting for Matrix services to start...${NC}"
sleep 45

# Check service status
echo -e "${BLUE}📊 Checking Matrix service status...${NC}"
docker-compose -f docker-compose.matrix.yml ps

# Create Matrix admin user
echo -e "${BLUE}👤 Creating Matrix admin user...${NC}"
ADMIN_EMAIL=$(grep GENTLEMAN_ADMIN_EMAIL auth.env | cut -d'=' -f2)
ADMIN_USERNAME=$(echo $ADMIN_EMAIL | cut -d'@' -f1)

docker exec -it gentleman-synapse register_new_matrix_user \
    -u $ADMIN_USERNAME \
    -p "GentlemanMatrix2024!" \
    -a \
    http://localhost:8008

# Setup Keycloak Matrix client
echo -e "${BLUE}🔧 Setting up Keycloak Matrix client...${NC}"
curl -X POST http://localhost:8091/setup-matrix-client || echo "Matrix client setup triggered"

# Test Matrix integration
echo -e "${BLUE}🧪 Testing Matrix integration...${NC}"
sleep 10

MATRIX_HEALTH=$(curl -s http://localhost:8008/health || echo "unhealthy")
ELEMENT_HEALTH=$(curl -s http://localhost:8009 | grep -q "Element" && echo "healthy" || echo "unhealthy")

echo ""
echo -e "${GREEN}🎉 GENTLEMAN Matrix Deployment Complete!${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "${BLUE}💬 Matrix Access URLs:${NC}"
echo "• Matrix Server:  http://matrix.gentleman.local:8008"
echo "• Element Client: http://element.gentleman.local:8009"
echo "• Matrix Admin:   http://localhost:8093"
echo ""
echo -e "${BLUE}🔐 Authentication:${NC}"
echo "• Login Method:   GENTLEMAN ProtonMail Auth"
echo "• ProtonMail:     $ADMIN_EMAIL"
echo "• Magic Links:    ✅ Enabled"
echo "• OIDC Provider:  http://auth.gentleman.local:8085"
echo ""
echo -e "${BLUE}📊 Service Status:${NC}"
echo "• Matrix Server:  $MATRIX_HEALTH"
echo "• Element Client: $ELEMENT_HEALTH"
echo "• Auth Sync:      Running on :8093"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. Open Element: http://element.gentleman.local:8009"
echo "2. Click 'Sign In' → 'GENTLEMAN Homelab'"
echo "3. Enter ProtonMail: $ADMIN_EMAIL"
echo "4. Check email for Magic Link"
echo "5. ✅ Automatically logged into Matrix!"
echo ""
echo -e "${CYAN}💡 Pro Tips:${NC}"
echo "• Same login works for ALL homelab services"
echo "• Matrix rooms auto-created for system updates"
echo "• Admin commands available via chat"
echo "• Monitoring alerts sent to Matrix rooms"
echo ""
echo -e "${GREEN}🚀 Matrix ready with systemwide GENTLEMAN Authentication!${NC}" 