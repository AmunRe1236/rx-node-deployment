#!/bin/bash

# 🎩 GENTLEMAN Git Repository Setup
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
echo "🎩 GENTLEMAN Git Repository Setup"
echo "═══════════════════════════════════════════════════════════════"
echo -e "${NC}"

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo -e "${BLUE}📦 Initializing Git repository...${NC}"
    git init
    echo -e "${GREEN}✅ Git repository initialized${NC}"
fi

# Create .gitignore if it doesn't exist
if [ ! -f ".gitignore" ]; then
    echo -e "${BLUE}📝 Creating .gitignore...${NC}"
    cat > .gitignore << 'EOF'
# 🎩 GENTLEMAN .gitignore

# Environment files with secrets
*.env
.env.*
auth.env

# Docker volumes and data
data/
volumes/
logs/

# SSH keys
*.pem
*.key
id_rsa*
gentleman_rsa*

# Temporary files
*.tmp
*.log
.DS_Store
Thumbs.db

# Node modules
node_modules/

# Python
__pycache__/
*.pyc
*.pyo

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
EOF
    echo -e "${GREEN}✅ .gitignore created${NC}"
fi

# Create README if it doesn't exist
if [ ! -f "README.md" ]; then
    echo -e "${BLUE}📖 Creating README.md...${NC}"
    cat > README.md << 'EOF'
# 🎩 GENTLEMAN Homelab

**Elegante systemweite Authentifizierung für dein Homelab**

## 🚀 Quick Start

### M1 Control Node (macOS)
```bash
# 1. Konfiguriere auth.env mit deinen RX Node Details
# 2. Starte Authentication Services
./start-gentleman-auth.sh

# 3. Setup RX Node Integration
./oneshot-gentleman-auth.sh
```

### RX Node (Linux)
```bash
# Wird automatisch vom M1 aus konfiguriert
# Oder manuell: sudo bash scripts/auth/rx-node-pam-setup.sh
```

## 🔑 Features

- **ProtonMail Integration** - Wie Google Account für dein Homelab
- **Magic Links** - Passwordless Login via E-Mail
- **Matrix Chat Commands** - Sichere Remote-Updates
- **Systemweite SSO** - Ein Login für alle Services
- **Zero-Trust Security** - Temporäre SSH-Schlüssel

## 🌐 Services

- **Keycloak** - Identity Provider (Port 8085)
- **OpenLDAP** - Directory Service (Port 389)
- **Matrix** - Chat & Remote Commands (Port 8008)
- **Email Auth** - ProtonMail Integration (Port 8092)

## 🔐 Security

- Temporäre SSH-Schlüssel (auto-delete nach 10min)
- Matrix-Approval für alle Updates
- Fail2Ban Integration
- Audit-Logs für alle Zugriffe

## 📚 Documentation

- `SECURE_REMOTE_UPDATE_README.md` - Remote Update System
- `config/homelab/` - Service Configurations
- `scripts/` - Setup & Management Scripts

---
**🎩 GENTLEMAN - Sicher, elegant, ohne Kompromisse**
EOF
    echo -e "${GREEN}✅ README.md created${NC}"
fi

# Add all files
echo -e "${BLUE}📦 Adding files to git...${NC}"
git add .

# Check if there are changes to commit
if git diff --staged --quiet; then
    echo -e "${YELLOW}⚠️  No changes to commit${NC}"
else
    # Commit changes
    echo -e "${BLUE}💾 Committing changes...${NC}"
    git commit -m "🎩 GENTLEMAN Authentication System - Complete Setup

✅ Features:
- ProtonMail integration (like Google Account)
- Magic Links & Email verification
- Matrix chat commands for remote updates
- Secure temporary SSH keys
- System-wide SSO for all homelab services
- RX Node PAM/LDAP integration

🔐 Security:
- Zero-trust remote updates
- Automatic SSH key cleanup
- Matrix approval workflow
- Fail2Ban integration

🚀 Ready for deployment on RX Node!"

    echo -e "${GREEN}✅ Changes committed${NC}"
fi

# Try to detect RX Node for offline repo
RX_NODE_IP=$(grep "RX_NODE_IP=" auth.env 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "")

if [ "$RX_NODE_IP" != "" ] && [ "$RX_NODE_IP" != "192.168.68.XXX" ]; then
    echo -e "${BLUE}🔍 Testing RX Node connectivity...${NC}"
    
    # Test if RX Node is reachable
    if ping -c 1 -W 3 "$RX_NODE_IP" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ RX Node ($RX_NODE_IP) is reachable${NC}"
        
        # Try to setup offline repo on RX Node
        echo -e "${BLUE}📡 Setting up offline repository on RX Node...${NC}"
        
        RX_NODE_USER=$(grep "RX_NODE_USER=" auth.env 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "")
        
        if [ "$RX_NODE_USER" != "" ] && [ "$RX_NODE_USER" != "your-current-user" ]; then
            # Create bare repository on RX Node
            ssh "$RX_NODE_USER@$RX_NODE_IP" "mkdir -p ~/gentleman-repo.git && cd ~/gentleman-repo.git && git init --bare" 2>/dev/null || {
                echo -e "${YELLOW}⚠️  Could not create offline repo (SSH not ready yet)${NC}"
                echo -e "${YELLOW}   Will use online repo instead${NC}"
            }
            
            # Add offline remote
            git remote add offline "$RX_NODE_USER@$RX_NODE_IP:~/gentleman-repo.git" 2>/dev/null || true
            
            # Try to push to offline repo
            if git push offline main 2>/dev/null; then
                echo -e "${GREEN}✅ Pushed to offline repository on RX Node${NC}"
                echo -e "${CYAN}💡 RX Node can now access: git clone ~/gentleman-repo.git${NC}"
                OFFLINE_SUCCESS=true
            else
                echo -e "${YELLOW}⚠️  Offline push failed${NC}"
                OFFLINE_SUCCESS=false
            fi
        else
            echo -e "${YELLOW}⚠️  RX_NODE_USER not configured${NC}"
            OFFLINE_SUCCESS=false
        fi
    else
        echo -e "${YELLOW}⚠️  RX Node not reachable${NC}"
        OFFLINE_SUCCESS=false
    fi
else
    echo -e "${YELLOW}⚠️  RX_NODE_IP not configured${NC}"
    OFFLINE_SUCCESS=false
fi

# Setup online repository as fallback
if [ "$OFFLINE_SUCCESS" != "true" ]; then
    echo -e "${BLUE}🌐 Setting up online repository...${NC}"
    
    # Add GitHub remote (you'll need to create the repo first)
    echo -e "${YELLOW}📝 To use online repository:${NC}"
    echo "1. Create repository on GitHub: https://github.com/new"
    echo "2. Run: git remote add origin https://github.com/yourusername/gentleman-homelab.git"
    echo "3. Run: git push -u origin main"
    echo ""
    echo -e "${CYAN}💡 Or use the offline repo once RX Node SSH is configured${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Git Repository Setup Complete!${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
if [ "$OFFLINE_SUCCESS" = "true" ]; then
    echo -e "${BLUE}✅ Repository Status:${NC}"
    echo "• Offline repo on RX Node: ✅ Available"
    echo "• RX Node access: git clone ~/gentleman-repo.git"
else
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "1. Configure RX_NODE_IP and RX_NODE_USER in auth.env"
    echo "2. Run ./start-gentleman-auth.sh"
    echo "3. Run ./oneshot-gentleman-auth.sh"
    echo "4. Re-run this script for offline repo"
fi
echo ""
echo -e "${CYAN}🚀 Ready to deploy GENTLEMAN Authentication System!${NC}" 