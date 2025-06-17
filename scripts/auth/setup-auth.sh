#!/bin/bash

# 🎩 GENTLEMAN Authentication System Setup
# ═══════════════════════════════════════════════════════════════

set -e

echo "🎩 GENTLEMAN Authentication System Setup"
echo "═══════════════════════════════════════════════════════════════"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ This script is designed for macOS${NC}"
    exit 1
fi

# Create auth environment file if it doesn't exist
AUTH_ENV_FILE=".env.auth"
if [ ! -f "$AUTH_ENV_FILE" ]; then
    echo -e "${BLUE}📝 Creating authentication environment file...${NC}"
    
    cat > "$AUTH_ENV_FILE" << 'EOF'
# 🎩 GENTLEMAN Authentication System Environment Variables
# ═══════════════════════════════════════════════════════════════

# Keycloak Configuration
KEYCLOAK_ADMIN_PASSWORD=GentlemanAuth2024!
KEYCLOAK_DB_PASSWORD=KeycloakDB2024!

# LDAP Configuration  
LDAP_ADMIN_PASSWORD=LdapAdmin2024!
LDAP_CONFIG_PASSWORD=LdapConfig2024!
LDAP_READONLY_PASSWORD=LdapRead2024!

# GENTLEMAN Admin User
GENTLEMAN_ADMIN_USER=gentleman
GENTLEMAN_ADMIN_EMAIL=admin@gentleman.local

# Service URLs
KEYCLOAK_URL=http://auth.gentleman.local:8085
LDAP_ADMIN_URL=http://ldap.gentleman.local:8086
EOF
    
    echo -e "${GREEN}✅ Created $AUTH_ENV_FILE${NC}"
else
    echo -e "${GREEN}✅ $AUTH_ENV_FILE already exists${NC}"
fi

# Create Docker networks
echo -e "${BLUE}🌐 Creating Docker networks...${NC}"
docker network create gentleman-auth --driver bridge --subnet=172.24.0.0/16 2>/dev/null || echo "Network gentleman-auth already exists"

# Create directories
echo -e "${BLUE}📁 Creating directories...${NC}"
mkdir -p config/homelab/keycloak
mkdir -p config/security/certs
mkdir -p logs/auth

# Generate certificates for LDAP if they don't exist
if [ ! -f "config/security/certs/ldap.crt" ]; then
    echo -e "${BLUE}🔐 Generating LDAP certificates...${NC}"
    
    # Create CA key and certificate
    openssl genrsa -out config/security/certs/ca.key 4096
    openssl req -new -x509 -days 365 -key config/security/certs/ca.key -out config/security/certs/ca.crt -subj "/C=DE/ST=Berlin/L=Berlin/O=GENTLEMAN/OU=Homelab/CN=GENTLEMAN-CA"
    
    # Create LDAP key and certificate
    openssl genrsa -out config/security/certs/ldap.key 4096
    openssl req -new -key config/security/certs/ldap.key -out config/security/certs/ldap.csr -subj "/C=DE/ST=Berlin/L=Berlin/O=GENTLEMAN/OU=Homelab/CN=ldap.gentleman.local"
    openssl x509 -req -in config/security/certs/ldap.csr -CA config/security/certs/ca.crt -CAkey config/security/certs/ca.key -CAcreateserial -out config/security/certs/ldap.crt -days 365
    
    # Generate DH parameters
    openssl dhparam -out config/security/certs/dhparam.pem 2048
    
    # Set permissions
    chmod 600 config/security/certs/*.key
    chmod 644 config/security/certs/*.crt config/security/certs/*.pem
    
    echo -e "${GREEN}✅ LDAP certificates generated${NC}"
fi

# Start authentication services
echo -e "${BLUE}🚀 Starting authentication services...${NC}"
docker-compose -f docker-compose.auth.yml --env-file .env.auth up -d

# Wait for services to start
echo -e "${YELLOW}⏳ Waiting for services to start...${NC}"
sleep 30

# Check service status
echo -e "${BLUE}📊 Checking service status...${NC}"
docker-compose -f docker-compose.auth.yml ps

# Display access information
echo ""
echo -e "${GREEN}🎉 GENTLEMAN Authentication System Setup Complete!${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "${BLUE}🔐 Access URLs:${NC}"
echo "• Keycloak Admin: http://auth.gentleman.local:8085"
echo "• LDAP Admin:     http://ldap.gentleman.local:8086"
echo "• Auth Sync API:  http://localhost:8091"
echo ""
echo -e "${BLUE}🔑 Default Credentials:${NC}"
echo "• Keycloak Admin: admin / GentlemanAuth2024!"
echo "• LDAP Admin:     cn=admin,dc=gentleman,dc=local / LdapAdmin2024!"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. Add hosts entries to /etc/hosts:"
echo "   127.0.0.1 auth.gentleman.local"
echo "   127.0.0.1 ldap.gentleman.local"
echo ""
echo "2. Access Keycloak and complete initial setup"
echo "3. Configure service integrations"
echo "4. Create users and groups"
echo ""
echo -e "${BLUE}🛠️ Management Commands:${NC}"
echo "• Start:  docker-compose -f docker-compose.auth.yml --env-file .env.auth up -d"
echo "• Stop:   docker-compose -f docker-compose.auth.yml --env-file .env.auth down"
echo "• Logs:   docker-compose -f docker-compose.auth.yml --env-file .env.auth logs -f"
echo "" 