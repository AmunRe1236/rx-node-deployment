#!/bin/bash

# 🎩 GENTLEMAN - Keycloak Startup Fix
# Behebt das --optimized Flag Problem beim ersten Start

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 GENTLEMAN Keycloak Startup Fix${NC}"
echo "=================================================="

# Check if Keycloak container exists and is running
if docker ps | grep -q "gentleman-keycloak"; then
    echo -e "${YELLOW}⏹️  Stopping existing Keycloak container...${NC}"
    docker stop gentleman-keycloak || true
    docker rm gentleman-keycloak || true
fi

# Check if Keycloak has been built before
KEYCLOAK_DATA_DIR="./config/homelab/keycloak"
KEYCLOAK_BUILT_FLAG="$KEYCLOAK_DATA_DIR/.keycloak_built"

if [ ! -f "$KEYCLOAK_BUILT_FLAG" ]; then
    echo -e "${BLUE}🏗️  First time setup - Building Keycloak...${NC}"
    
    # Ensure config directory exists
    mkdir -p "$KEYCLOAK_DATA_DIR"
    
    # Start with development mode first
    echo -e "${YELLOW}📦 Starting Keycloak in development mode...${NC}"
    docker-compose -f docker-compose.auth.yml up -d keycloak-db
    
    # Wait for database
    echo -e "${YELLOW}⏳ Waiting for database to be ready...${NC}"
    sleep 10
    
    # Start Keycloak in dev mode
    docker-compose -f docker-compose.auth.yml up -d keycloak
    
    # Wait for Keycloak to be ready
    echo -e "${YELLOW}⏳ Waiting for Keycloak to initialize...${NC}"
    for i in {1..30}; do
        if curl -f http://localhost:8085/health/ready >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Keycloak is ready!${NC}"
            break
        fi
        echo -e "${YELLOW}⏳ Waiting... ($i/30)${NC}"
        sleep 10
    done
    
    # Mark as built
    touch "$KEYCLOAK_BUILT_FLAG"
    echo -e "${GREEN}✅ Keycloak successfully initialized${NC}"
    
else
    echo -e "${GREEN}✅ Keycloak already built, starting normally...${NC}"
    docker-compose -f docker-compose.auth.yml up -d keycloak
fi

echo ""
echo -e "${GREEN}🎉 Keycloak Fix Complete!${NC}"
echo ""
echo "Access URLs:"
echo "• Keycloak Admin: http://localhost:8085"
echo "• Username: admin"
echo "• Password: GentlemanAuth2024!"
echo ""
echo -e "${BLUE}💡 Tip:${NC} Nach dem ersten erfolgreichen Start kannst du"
echo "   das command in docker-compose.auth.yml auf 'start --optimized' ändern"
echo "   für bessere Performance." 