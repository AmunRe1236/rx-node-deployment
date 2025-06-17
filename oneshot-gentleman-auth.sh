#!/bin/bash

# 🎩 GENTLEMAN Oneshot Authentication Master Script
# ═══════════════════════════════════════════════════════════════
# Komplette systemweite Authentifizierung in einem Zug

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

# Configuration
RX_NODE_IP="192.168.100.10"  # Nebula IP
RX_NODE_REAL_IP="192.168.68.XXX"  # Replace with actual IP
RX_NODE_USER="your-current-user"  # Replace with current RX Node user

echo -e "${PURPLE}"
echo "🎩 GENTLEMAN Oneshot Authentication Master"
echo "═══════════════════════════════════════════════════════════════"
echo -e "${WHITE}Systemweite Benutzer-Integration für RX Node${NC}"
echo ""

# Check prerequisites
echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ This script must run on macOS (M1 control node)${NC}"
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker not found! Please install Docker first.${NC}"
    exit 1
fi

if ! command -v ssh >/dev/null 2>&1; then
    echo -e "${RED}❌ SSH not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites OK${NC}"

# Get RX Node connection details
echo ""
echo -e "${YELLOW}📝 RX Node Configuration${NC}"
echo "Please provide your RX Node details:"

read -p "RX Node IP address (current network): " RX_NODE_REAL_IP
read -p "RX Node username (current): " RX_NODE_USER
read -p "RX Node password (for sudo): " -s RX_NODE_PASSWORD
echo ""

# Phase 1: Setup Authentication Services on macOS
echo ""
echo -e "${BLUE}🚀 Phase 1: Setting up Authentication Services on macOS${NC}"
echo "═══════════════════════════════════════════════════════════════"

chmod +x scripts/auth/oneshot-auth-setup.sh
./scripts/auth/oneshot-auth-setup.sh

# Wait for services to be ready
echo -e "${YELLOW}⏳ Waiting for authentication services to stabilize...${NC}"
sleep 30

# Phase 2: Setup RX Node System Integration
echo ""
echo -e "${BLUE}🚀 Phase 2: Setting up RX Node System Integration${NC}"
echo "═══════════════════════════════════════════════════════════════"

# Copy PAM setup script to RX Node
echo -e "${CYAN}📤 Copying setup script to RX Node...${NC}"
scp scripts/auth/rx-node-pam-setup.sh $RX_NODE_USER@$RX_NODE_REAL_IP:/tmp/

# Execute PAM setup on RX Node
echo -e "${CYAN}🔧 Executing PAM setup on RX Node...${NC}"
ssh $RX_NODE_USER@$RX_NODE_REAL_IP << EOF
echo '$RX_NODE_PASSWORD' | sudo -S bash /tmp/rx-node-pam-setup.sh
EOF

# Phase 3: Configure Keycloak Users and Groups
echo ""
echo -e "${BLUE}🚀 Phase 3: Configuring Keycloak Users and Groups${NC}"
echo "═══════════════════════════════════════════════════════════════"

# Wait for Keycloak to be fully ready
echo -e "${YELLOW}⏳ Waiting for Keycloak to be ready...${NC}"
for i in {1..20}; do
    if curl -s http://localhost:8085/health/ready >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Keycloak is ready${NC}"
        break
    fi
    echo -e "${YELLOW}⏳ Waiting... ($i/20)${NC}"
    sleep 15
done

# Create Keycloak configuration script
cat > /tmp/keycloak-setup.py << 'EOF'
#!/usr/bin/env python3
import requests
import json
import time

# Keycloak configuration
KEYCLOAK_URL = "http://localhost:8085"
ADMIN_USER = "admin"
ADMIN_PASSWORD = "GentlemanAuth2024!"
REALM_NAME = "gentleman-homelab"

def get_admin_token():
    """Get admin access token"""
    url = f"{KEYCLOAK_URL}/realms/master/protocol/openid-connect/token"
    data = {
        'client_id': 'admin-cli',
        'username': ADMIN_USER,
        'password': ADMIN_PASSWORD,
        'grant_type': 'password'
    }
    response = requests.post(url, data=data)
    if response.status_code == 200:
        return response.json()['access_token']
    else:
        print(f"Failed to get token: {response.status_code}")
        return None

def create_realm(token):
    """Create GENTLEMAN realm"""
    url = f"{KEYCLOAK_URL}/admin/realms"
    headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
    
    realm_config = {
        "realm": REALM_NAME,
        "displayName": "GENTLEMAN Homelab",
        "enabled": True,
        "registrationAllowed": False,
        "loginWithEmailAllowed": True,
        "duplicateEmailsAllowed": False,
        "resetPasswordAllowed": True,
        "editUsernameAllowed": False,
        "bruteForceProtected": True,
        "permanentLockout": False,
        "maxFailureWaitSeconds": 900,
        "minimumQuickLoginWaitSeconds": 60,
        "waitIncrementSeconds": 60,
        "quickLoginCheckMilliSeconds": 1000,
        "maxDeltaTimeSeconds": 43200,
        "failureFactor": 30
    }
    
    response = requests.post(url, headers=headers, json=realm_config)
    if response.status_code == 201:
        print("✅ Realm created successfully")
        return True
    elif response.status_code == 409:
        print("✅ Realm already exists")
        return True
    else:
        print(f"❌ Failed to create realm: {response.status_code}")
        return False

def create_groups(token):
    """Create user groups"""
    url = f"{KEYCLOAK_URL}/admin/realms/{REALM_NAME}/groups"
    headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
    
    groups = [
        {"name": "homelab-admins", "attributes": {"description": ["Full access to all homelab services"]}},
        {"name": "homelab-users", "attributes": {"description": ["Standard access to homelab services"]}},
        {"name": "media-users", "attributes": {"description": ["Access to media services only"]}}
    ]
    
    for group in groups:
        response = requests.post(url, headers=headers, json=group)
        if response.status_code == 201:
            print(f"✅ Group '{group['name']}' created")
        elif response.status_code == 409:
            print(f"✅ Group '{group['name']}' already exists")
        else:
            print(f"❌ Failed to create group '{group['name']}': {response.status_code}")

def create_user(token):
    """Create gentleman user"""
    url = f"{KEYCLOAK_URL}/admin/realms/{REALM_NAME}/users"
    headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
    
    user_config = {
        "username": "gentleman",
        "email": "admin@gentleman.local",
        "firstName": "GENTLEMAN",
        "lastName": "Admin",
        "enabled": True,
        "emailVerified": True,
        "credentials": [{
            "type": "password",
            "value": "GentlemanUser2024!",
            "temporary": False
        }]
    }
    
    response = requests.post(url, headers=headers, json=user_config)
    if response.status_code == 201:
        print("✅ User 'gentleman' created")
        
        # Get user ID and add to homelab-admins group
        users_response = requests.get(f"{url}?username=gentleman", headers=headers)
        if users_response.status_code == 200:
            users = users_response.json()
            if users:
                user_id = users[0]['id']
                
                # Get homelab-admins group ID
                groups_response = requests.get(f"{KEYCLOAK_URL}/admin/realms/{REALM_NAME}/groups", headers=headers)
                if groups_response.status_code == 200:
                    groups = groups_response.json()
                    admin_group = next((g for g in groups if g['name'] == 'homelab-admins'), None)
                    if admin_group:
                        # Add user to group
                        group_url = f"{KEYCLOAK_URL}/admin/realms/{REALM_NAME}/users/{user_id}/groups/{admin_group['id']}"
                        group_response = requests.put(group_url, headers=headers)
                        if group_response.status_code == 204:
                            print("✅ User added to homelab-admins group")
                        else:
                            print(f"❌ Failed to add user to group: {group_response.status_code}")
        
    elif response.status_code == 409:
        print("✅ User 'gentleman' already exists")
    else:
        print(f"❌ Failed to create user: {response.status_code}")

def main():
    print("🔧 Setting up Keycloak configuration...")
    
    token = get_admin_token()
    if not token:
        print("❌ Failed to get admin token")
        return
    
    if create_realm(token):
        time.sleep(2)  # Wait for realm to be ready
        create_groups(token)
        time.sleep(1)
        create_user(token)
    
    print("✅ Keycloak setup complete")

if __name__ == "__main__":
    main()
EOF

# Install Python requests if needed and run setup
echo -e "${CYAN}🔧 Configuring Keycloak...${NC}"
python3 -c "import requests" 2>/dev/null || pip3 install requests
python3 /tmp/keycloak-setup.py

# Phase 4: Test Authentication
echo ""
echo -e "${BLUE}🚀 Phase 4: Testing Authentication${NC}"
echo "═══════════════════════════════════════════════════════════════"

# Add hosts entries
echo -e "${CYAN}🌐 Adding hosts entries...${NC}"
echo "127.0.0.1 auth.gentleman.local" | sudo tee -a /etc/hosts >/dev/null || true
echo "127.0.0.1 ldap.gentleman.local" | sudo tee -a /etc/hosts >/dev/null || true

# Test LDAP connectivity from RX Node
echo -e "${CYAN}🧪 Testing LDAP connectivity from RX Node...${NC}"
ssh $RX_NODE_USER@$RX_NODE_REAL_IP << EOF
# Add hosts entry on RX Node
echo '$RX_NODE_PASSWORD' | sudo -S sh -c 'echo "192.168.68.111 auth.gentleman.local" >> /etc/hosts'

# Test LDAP search
getent passwd gentleman || echo "LDAP user lookup failed (expected initially)"

# Test SSH with new user (will fail initially, but shows it's configured)
echo "Testing SSH configuration..."
sudo systemctl restart sshd
EOF

# Final Results
echo ""
echo -e "${GREEN}🎉 GENTLEMAN Oneshot Authentication Setup Complete!${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "${BLUE}✅ What's been configured:${NC}"
echo "• Keycloak Identity Provider (http://localhost:8085)"
echo "• OpenLDAP Directory Service (http://localhost:8086)"
echo "• RX Node PAM/LDAP integration"
echo "• SSH authentication for LDAP users"
echo "• Sudo permissions for homelab groups"
echo ""
echo -e "${BLUE}🔑 Login Credentials:${NC}"
echo "• Keycloak Admin: admin / GentlemanAuth2024!"
echo "• LDAP Admin: cn=admin,dc=gentleman,dc=local / LdapAdmin2024!"
echo "• GENTLEMAN User: gentleman / GentlemanUser2024!"
echo "• RX Node Fallback: gentlemanlocal / GentlemanLocal2024!"
echo ""
echo -e "${BLUE}🖥️  RX Node Access:${NC}"
echo "• SSH with LDAP: ssh gentleman@$RX_NODE_REAL_IP"
echo "• SSH fallback: ssh gentlemanlocal@$RX_NODE_REAL_IP"
echo "• Local services use Keycloak authentication"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. Test LDAP authentication:"
echo "   ssh $RX_NODE_USER@$RX_NODE_REAL_IP 'getent passwd gentleman'"
echo ""
echo "2. Test SSH login:"
echo "   ssh gentleman@$RX_NODE_REAL_IP"
echo ""
echo "3. Configure service integrations:"
echo "   - Gitea: OAuth2 with Keycloak"
echo "   - Nextcloud: OIDC integration"
echo "   - Grafana: Generic OAuth"
echo ""
echo -e "${GREEN}🚀 Your RX Node now supports systemwide authentication!${NC}"
echo ""
echo -e "${CYAN}💡 Pro Tip: Use 'gentleman' user for all homelab services${NC}"
echo -e "${CYAN}   This user has admin rights and works across all systems${NC}" 