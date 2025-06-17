#!/bin/bash

# 🎩 GENTLEMAN Manual Git Setup
# ═══════════════════════════════════════════════════════════════

echo "🎩 GENTLEMAN Git Setup - Manual Version"
echo "═══════════════════════════════════════════════════════════════"

# Initialize git repository
echo "📦 Initializing Git repository..."
git init

# Add all files
echo "📦 Adding files to git..."
git add .

# Create initial commit
echo "💾 Creating initial commit..."
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

echo ""
echo "✅ Git repository created successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Configure auth.env with your RX Node details"
echo "2. Run: ./start-gentleman-auth.sh"
echo "3. Run: ./oneshot-gentleman-auth.sh"
echo ""
echo "🌐 For online repository:"
echo "1. Create repo on GitHub: https://github.com/new"
echo "2. git remote add origin https://github.com/username/gentleman-homelab.git"
echo "3. git push -u origin main"
echo ""
echo "🎩 GENTLEMAN setup complete!" 