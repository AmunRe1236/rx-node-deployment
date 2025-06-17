#!/bin/bash

# 🎩 GENTLEMAN Oneshot Authentication Setup
# ═══════════════════════════════════════════════════════════════
# Schnelle systemweite Benutzer-Integration für RX Node

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

echo -e "${PURPLE}🎩 GENTLEMAN Oneshot Auth Setup${NC}"
echo "═══════════════════════════════════════════════════════════════"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ This script is designed for macOS (controlling RX Node remotely)${NC}"
    exit 1
fi

# 1. Create Docker networks
echo -e "${BLUE}🌐 Creating Docker networks...${NC}"
docker network create gentleman-auth --driver bridge --subnet=172.24.0.0/16 2>/dev/null || echo "Network already exists"
docker network create gentleman-homelab --driver bridge --subnet=172.25.0.0/16 2>/dev/null || echo "Network already exists"

# 2. Create directories
echo -e "${BLUE}📁 Creating directories...${NC}"
mkdir -p config/homelab/keycloak
mkdir -p config/security/certs
mkdir -p logs/auth

# 3. Generate LDAP certificates quickly
echo -e "${BLUE}🔐 Generating LDAP certificates...${NC}"
if [ ! -f "config/security/certs/ldap.crt" ]; then
    # Quick certificate generation
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout config/security/certs/ldap.key \
        -out config/security/certs/ldap.crt \
        -subj "/C=DE/ST=Berlin/L=Berlin/O=GENTLEMAN/OU=Homelab/CN=ldap.gentleman.local"
    
    # CA certificate (self-signed)
    cp config/security/certs/ldap.crt config/security/certs/ca.crt
    
    # DH parameters (quick generation)
    openssl dhparam -out config/security/certs/dhparam.pem 1024
    
    chmod 600 config/security/certs/*.key
    chmod 644 config/security/certs/*.crt config/security/certs/*.pem
    
    echo -e "${GREEN}✅ Certificates generated${NC}"
fi

# 4. Start authentication services
echo -e "${BLUE}🚀 Starting authentication services...${NC}"
docker-compose -f docker-compose.auth.yml --env-file auth.env up -d

# 5. Wait for services
echo -e "${YELLOW}⏳ Waiting for services to start (60 seconds)...${NC}"
sleep 60

# 6. Check service status
echo -e "${BLUE}📊 Checking service status...${NC}"
docker-compose -f docker-compose.auth.yml --env-file auth.env ps

# 7. Setup Keycloak realm and users
echo -e "${BLUE}🔧 Setting up Keycloak realm...${NC}"
sleep 30  # Additional wait for Keycloak to be fully ready

# Test Keycloak availability
KEYCLOAK_READY=false
for i in {1..10}; do
    if curl -s http://localhost:8085/health/ready >/dev/null 2>&1; then
        KEYCLOAK_READY=true
        break
    fi
    echo -e "${YELLOW}⏳ Waiting for Keycloak... ($i/10)${NC}"
    sleep 10
done

if [ "$KEYCLOAK_READY" = true ]; then
    echo -e "${GREEN}✅ Keycloak is ready${NC}"
    
    # Trigger auth-sync setup
    echo -e "${BLUE}🔄 Setting up realm and clients...${NC}"
    curl -s http://localhost:8091/setup || echo "Auth-sync setup triggered"
    
else
    echo -e "${YELLOW}⚠️  Keycloak may not be fully ready yet${NC}"
fi

# 8. Create RX Node SSH integration script
echo -e "${BLUE}🖥️  Creating RX Node integration...${NC}"
cat > scripts/auth/rx-node-integration.sh << 'EOF'
#!/bin/bash

# 🎩 GENTLEMAN RX Node SSH Integration
# ═══════════════════════════════════════════════════════════════

RX_NODE_IP="192.168.100.10"
RX_NODE_USER="gentleman"
SSH_KEY="$HOME/.ssh/gentleman_rsa"

echo "🖥️  Setting up systemwide authentication on RX Node..."

# Generate SSH key if not exists
if [ ! -f "$SSH_KEY" ]; then
    echo "🔑 Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY" -N "" -C "gentleman@homelab"
fi

# Create user setup script for RX Node
cat > /tmp/rx-node-setup.sh << 'RXEOF'
#!/bin/bash

# Create gentleman user
sudo useradd -m -s /bin/bash gentleman 2>/dev/null || echo "User exists"

# Add to sudo group
sudo usermod -aG sudo gentleman

# Setup SSH directory
sudo mkdir -p /home/gentleman/.ssh
sudo chmod 700 /home/gentleman/.ssh

# Install SSH key (will be copied separately)
sudo chown -R gentleman:gentleman /home/gentleman/.ssh

# Install LDAP/PAM integration packages
if command -v apt-get >/dev/null; then
    sudo apt-get update
    sudo apt-get install -y libpam-ldap libnss-ldap ldap-utils
elif command -v pacman >/dev/null; then
    sudo pacman -S --noconfirm openldap nss-pam-ldapd
fi

# Configure LDAP authentication
sudo tee /etc/ldap/ldap.conf << LDAPEOF
BASE dc=gentleman,dc=local
URI ldap://auth.gentleman.local:389
BINDDN cn=readonly,dc=gentleman,dc=local
BINDPW LdapRead2024!
LDAPEOF

echo "✅ RX Node user setup complete"
RXEOF

echo "📋 RX Node integration script created"
echo "🔧 To apply on RX Node, run:"
echo "   scp /tmp/rx-node-setup.sh $RX_NODE_USER@$RX_NODE_IP:/tmp/"
echo "   ssh $RX_NODE_USER@$RX_NODE_IP 'bash /tmp/rx-node-setup.sh'"

EOF

chmod +x scripts/auth/rx-node-integration.sh

# 9. Display results
echo ""
echo -e "${GREEN}🎉 GENTLEMAN Oneshot Auth Setup Complete!${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "${BLUE}🔐 Access URLs:${NC}"
echo "• Keycloak Admin: http://localhost:8085"
echo "• LDAP Admin:     http://localhost:8086"
echo "• Auth Sync API:  http://localhost:8091"
echo ""
echo -e "${BLUE}🔑 Default Credentials:${NC}"
echo "• Keycloak Admin: admin / GentlemanAuth2024!"
echo "• LDAP Admin:     cn=admin,dc=gentleman,dc=local / LdapAdmin2024!"
echo ""
echo -e "${YELLOW}📝 Next Steps für RX Node Integration:${NC}"
echo "1. Add hosts entries to /etc/hosts:"
echo "   echo '127.0.0.1 auth.gentleman.local' | sudo tee -a /etc/hosts"
echo "   echo '127.0.0.1 ldap.gentleman.local' | sudo tee -a /etc/hosts"
echo ""
echo "2. Setup RX Node user:"
echo "   ./scripts/auth/rx-node-integration.sh"
echo ""
echo "3. Create user in Keycloak:"
echo "   - Open http://localhost:8085"
echo "   - Login as admin"
echo "   - Create user 'gentleman' in realm 'gentleman-homelab'"
echo "   - Add to group 'homelab-admins'"
echo ""
echo -e "${BLUE}🛠️  Management Commands:${NC}"
echo "• Status: docker-compose -f docker-compose.auth.yml --env-file auth.env ps"
echo "• Logs:   docker-compose -f docker-compose.auth.yml --env-file auth.env logs -f"
echo "• Stop:   docker-compose -f docker-compose.auth.yml --env-file auth.env down"
echo ""
echo -e "${GREEN}🚀 Ready for systemwide authentication!${NC}" 