#!/bin/bash

# 🎩 GENTLEMAN Authentication System Starter
# ═══════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}"
echo "🎩 GENTLEMAN Authentication System"
echo "═══════════════════════════════════════════════════════════════"
echo -e "${NC}"

# Check prerequisites
echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

# Check if auth.env exists and is configured
if [ ! -f "auth.env" ]; then
    echo -e "${RED}❌ auth.env not found!${NC}"
    exit 1
fi

# Check for placeholder values
if grep -q "192.168.68.XXX" auth.env; then
    echo -e "${RED}❌ Please update RX_NODE_IP in auth.env with your actual RX Node IP${NC}"
    exit 1
fi

if grep -q "your-current-user" auth.env; then
    echo -e "${RED}❌ Please update RX_NODE_USER in auth.env with your actual RX Node username${NC}"
    exit 1
fi

if grep -q "your_proton_bridge_password" auth.env; then
    echo -e "${YELLOW}⚠️  ProtonMail Bridge password not set in auth.env${NC}"
    echo -e "${YELLOW}   Email authentication will be disabled${NC}"
fi

# Check SSH key
if [ ! -f ~/.ssh/gentleman_rsa ]; then
    echo -e "${YELLOW}⚠️  SSH key not found. Creating one...${NC}"
    mkdir -p ~/.ssh
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/gentleman_rsa -N "" -C "gentleman-homelab-$(date +%Y%m%d)"
    echo -e "${GREEN}✅ SSH key created${NC}"
fi

# Check Docker
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites OK${NC}"

# Start authentication services
echo ""
echo -e "${BLUE}🚀 Starting GENTLEMAN Authentication Services...${NC}"

# Create Docker networks
echo -e "${CYAN}🌐 Creating Docker networks...${NC}"
docker network create gentleman-auth 2>/dev/null || echo "Network already exists"
docker network create gentleman-mesh 2>/dev/null || echo "Network already exists"

# Start authentication stack
echo -e "${CYAN}🔧 Starting authentication services...${NC}"
docker-compose -f docker-compose.auth.yml --env-file auth.env up -d

# Wait for services
echo -e "${YELLOW}⏳ Waiting for services to start...${NC}"
sleep 30

# Check service health
echo -e "${BLUE}📊 Checking service health...${NC}"

services=("keycloak:8085" "openldap:389" "ldap-admin:8086")
for service in "${services[@]}"; do
    name=$(echo $service | cut -d: -f1)
    port=$(echo $service | cut -d: -f2)
    
    if curl -s http://localhost:$port/health >/dev/null 2>&1 || nc -z localhost $port 2>/dev/null; then
        echo -e "${GREEN}✅ $name is running${NC}"
    else
        echo -e "${YELLOW}⏳ $name is starting...${NC}"
    fi
done

echo ""
echo -e "${GREEN}🎉 GENTLEMAN Authentication System Started!${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "${BLUE}🌐 Access URLs:${NC}"
echo "• Keycloak Admin: http://localhost:8085 (admin / GentlemanAuth2024!)"
echo "• LDAP Admin: http://localhost:8086 (cn=admin,dc=gentleman,dc=local / LdapAdmin2024!)"
echo "• Email Auth: http://localhost:8092/auth/login-form"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo "1. Test authentication services locally"
echo "2. Run RX Node setup: ./oneshot-gentleman-auth.sh"
echo "3. Test SSH login: ssh gentleman@your-rx-node-ip"
echo ""
echo -e "${CYAN}💡 Pro Tip: Check logs with: docker-compose -f docker-compose.auth.yml logs -f${NC}" 