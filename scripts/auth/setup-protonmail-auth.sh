#!/bin/bash

# 🎩 GENTLEMAN ProtonMail Authentication Setup
# ═══════════════════════════════════════════════════════════════
# ProtonMail als primäre Identität wie Google Account

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
echo "🎩 GENTLEMAN ProtonMail Authentication Setup"
echo "═══════════════════════════════════════════════════════════════"
echo -e "${WHITE}ProtonMail als systemweite Identität wie Google Account${NC}"
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ This script is designed for macOS${NC}"
    exit 1
fi

# Get ProtonMail credentials
echo -e "${BLUE}📧 ProtonMail Konfiguration${NC}"
echo "Bitte geben Sie Ihre ProtonMail-Daten ein:"
echo ""

read -p "ProtonMail E-Mail: " PROTONMAIL_EMAIL
read -p "ProtonMail Bridge Passwort: " -s PROTONMAIL_BRIDGE_PASSWORD
echo ""

# Validate email
if [[ ! "$PROTONMAIL_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo -e "${RED}❌ Ungültige E-Mail-Adresse${NC}"
    exit 1
fi

# Update auth.env with ProtonMail settings
echo -e "${BLUE}🔧 Aktualisiere Konfiguration...${NC}"

# Update GENTLEMAN_ADMIN_EMAIL
sed -i.bak "s/GENTLEMAN_ADMIN_EMAIL=.*/GENTLEMAN_ADMIN_EMAIL=$PROTONMAIL_EMAIL/" auth.env

# Update ProtonMail SMTP settings
sed -i.bak "s/PROTONMAIL_SMTP_USER=.*/PROTONMAIL_SMTP_USER=$PROTONMAIL_EMAIL/" auth.env
sed -i.bak "s/PROTONMAIL_SMTP_PASSWORD=.*/PROTONMAIL_SMTP_PASSWORD=$PROTONMAIL_BRIDGE_PASSWORD/" auth.env

# Add domain to whitelist
DOMAIN=$(echo "$PROTONMAIL_EMAIL" | cut -d'@' -f2)
sed -i.bak "s/EMAIL_DOMAIN_WHITELIST=.*/EMAIL_DOMAIN_WHITELIST=$DOMAIN,protonmail.com,gentlemail.com,gmail.com/" auth.env

rm auth.env.bak

echo -e "${GREEN}✅ Konfiguration aktualisiert${NC}"

# Create ProtonMail Bridge directory
echo -e "${BLUE}📁 Erstelle Verzeichnisse...${NC}"
mkdir -p config/security/protonmail
mkdir -p config/homelab/email-templates/login/html
mkdir -p config/homelab/email-templates/login/text

# Create Keycloak SMTP configuration
echo -e "${BLUE}🔧 Erstelle Keycloak SMTP Konfiguration...${NC}"
cat > config/homelab/keycloak/keycloak.conf << EOF
# 🎩 GENTLEMAN Keycloak Configuration
# ProtonMail SMTP Integration

# Database
db=postgres
db-url=jdbc:postgresql://keycloak-db:5432/keycloak
db-username=keycloak
db-password=\${KEYCLOAK_DB_PASSWORD}

# HTTP
http-enabled=true
hostname=auth.gentleman.local
hostname-strict=false
hostname-strict-https=false
proxy=edge

# SMTP Configuration für ProtonMail
spi-email-template-provider=freemarker
spi-email-template-freemarker-enabled=true

# Logging
log-level=INFO
EOF

# Create email template configuration
cat > config/homelab/keycloak/standalone-ha.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<server xmlns="urn:jboss:domain:19.0">
    <profile>
        <subsystem xmlns="urn:jboss:domain:mail:4.0">
            <mail-session name="default" jndi-name="java:jboss/mail/Default">
                <smtp-server outbound-socket-binding-ref="mail-smtp" 
                           ssl="false" 
                           tls="true"
                           username="${PROTONMAIL_SMTP_USER}"
                           password="${PROTONMAIL_SMTP_PASSWORD}"/>
            </mail-session>
        </subsystem>
    </profile>
    
    <socket-binding-group name="standard-sockets" default-interface="public">
        <outbound-socket-binding name="mail-smtp">
            <remote-destination host="${PROTONMAIL_SMTP_HOST}" port="${PROTONMAIL_SMTP_PORT}"/>
        </outbound-socket-binding>
    </socket-binding-group>
</server>
EOF

# Create text email template
cat > config/homelab/email-templates/login/text/email-verification.ftl << 'EOF'
🎩 GENTLEMAN Homelab - E-Mail Bestätigung

Hallo ${user.firstName!""}!

Willkommen bei GENTLEMAN Homelab. Bitte bestätigen Sie Ihre E-Mail-Adresse:

${link}

Dieser Link ist ${linkExpirationFormatter(linkExpiration)} gültig.

Nach der Bestätigung haben Sie Zugriff auf alle Homelab-Services.

Mit freundlichen Grüßen,
Ihr GENTLEMAN System

🎩 Wo Eleganz auf Funktionalität trifft
EOF

# Start ProtonMail Bridge (if available)
echo -e "${BLUE}🌉 Prüfe ProtonMail Bridge...${NC}"
if command -v protonmail-bridge >/dev/null 2>&1; then
    echo -e "${GREEN}✅ ProtonMail Bridge gefunden${NC}"
    echo -e "${YELLOW}⚠️  Stellen Sie sicher, dass ProtonMail Bridge läuft${NC}"
    echo "   Starten Sie: protonmail-bridge --cli"
else
    echo -e "${YELLOW}⚠️  ProtonMail Bridge nicht gefunden${NC}"
    echo "   Download: https://protonmail.com/bridge"
    echo "   Oder verwenden Sie Docker Container"
fi

# Create ProtonMail integration test script
cat > scripts/auth/test-protonmail.sh << 'EOF'
#!/bin/bash

# 🎩 GENTLEMAN ProtonMail Integration Test

echo "🧪 Teste ProtonMail Integration..."

# Test SMTP Connection
echo "📧 Teste SMTP Verbindung..."
curl -X POST http://localhost:8092/auth/send-verification-code \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$PROTONMAIL_EMAIL\"}"

echo ""
echo "✅ Test abgeschlossen"
echo "Prüfen Sie Ihr ProtonMail Postfach auf Test-E-Mails"
EOF

chmod +x scripts/auth/test-protonmail.sh

# Update oneshot script with ProtonMail settings
echo -e "${BLUE}🔄 Aktualisiere Oneshot Script...${NC}"
if [ -f "oneshot-gentleman-auth.sh" ]; then
    # Add ProtonMail email to the Python setup script
    sed -i.bak "s/amonbaumgartner@gentlemail.com/$PROTONMAIL_EMAIL/g" oneshot-gentleman-auth.sh
    rm oneshot-gentleman-auth.sh.bak
fi

# Create service integration guide
cat > PROTONMAIL_INTEGRATION.md << EOF
# 🎩 GENTLEMAN ProtonMail Integration

## ✅ Konfiguriert

Ihre ProtonMail-Adresse **$PROTONMAIL_EMAIL** ist jetzt als primäre Identität konfiguriert.

## 🚀 Verwendung

### 1. **Magic Link Login (wie Google)**
- Gehen Sie zu: http://auth.gentleman.local:8092/auth/login-form
- Geben Sie Ihre E-Mail ein: $PROTONMAIL_EMAIL
- Klicken Sie "Magic Link senden"
- Prüfen Sie Ihr ProtonMail Postfach
- Klicken Sie den Link in der E-Mail

### 2. **Verification Code Login**
- Gehen Sie zu: http://auth.gentleman.local:8092/auth/login-form
- Geben Sie Ihre E-Mail ein: $PROTONMAIL_EMAIL
- Klicken Sie "Verification Code senden"
- Geben Sie den 6-stelligen Code ein

### 3. **Service Integration**
Alle Homelab-Services verwenden jetzt Ihre ProtonMail als Login:

- **Keycloak**: http://auth.gentleman.local:8085
- **Nextcloud**: OAuth2 mit ProtonMail
- **Grafana**: Generic OAuth mit ProtonMail
- **Jellyfin**: OIDC mit ProtonMail

## 🔧 Management

### Benutzer verwalten
\`\`\`bash
# Keycloak Admin Console
open http://auth.gentleman.local:8085

# E-Mail Auth Service
open http://auth.gentleman.local:8092
\`\`\`

### Test senden
\`\`\`bash
./scripts/auth/test-protonmail.sh
\`\`\`

## 🎯 Vorteile

✅ **Wie Google Account**: Ein Login für alle Services
✅ **Sicher**: Magic Links + Verification Codes
✅ **Privat**: Ihre eigene ProtonMail
✅ **Elegant**: GENTLEMAN Design
✅ **Systemweit**: Funktioniert überall

---
🎩 Wo Eleganz auf Funktionalität trifft
EOF

# Final setup
echo ""
echo -e "${GREEN}🎉 ProtonMail Authentication Setup abgeschlossen!${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "${BLUE}📧 Konfigurierte E-Mail:${NC} $PROTONMAIL_EMAIL"
echo -e "${BLUE}🔗 Login-Formular:${NC} http://auth.gentleman.local:8092/auth/login-form"
echo -e "${BLUE}🔐 Keycloak Admin:${NC} http://auth.gentleman.local:8085"
echo ""
echo -e "${YELLOW}📝 Nächste Schritte:${NC}"
echo "1. Starten Sie das Authentication System:"
echo "   ./oneshot-gentleman-auth.sh"
echo ""
echo "2. Testen Sie die ProtonMail Integration:"
echo "   ./scripts/auth/test-protonmail.sh"
echo ""
echo "3. Öffnen Sie das Login-Formular:"
echo "   open http://auth.gentleman.local:8092/auth/login-form"
echo ""
echo -e "${CYAN}💡 Pro Tip:${NC}"
echo "Ihre ProtonMail funktioniert jetzt wie ein Google Account!"
echo "Ein Login für alle Homelab-Services. 🎩"
echo ""
echo -e "${GREEN}🚀 Ready für systemweite ProtonMail-Authentifizierung!${NC}" 