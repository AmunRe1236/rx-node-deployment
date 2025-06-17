#!/bin/bash

# 🔒 GENTLEMAN PRE-COMMIT SECURITY CHECK
# ═══════════════════════════════════════════════════════════════
# Verhindert Commits mit Sicherheitslücken

set -e

# 🎨 Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔒 GENTLEMAN SECURITY PRE-COMMIT CHECK${NC}"
echo "═══════════════════════════════════════════════════════════════"

# 🚨 Critical Security Checks
SECURITY_ISSUES=0

# 1. Check for hardcoded secrets (exclude security scripts)
echo "🔍 Prüfe auf hardcodierte Secrets..."
if git diff --cached --name-only | grep -v "scripts/security/" | xargs grep -l "password.*=.*['\"][^{$]" 2>/dev/null; then
    echo -e "${RED}❌ KRITISCH: Hardcodierte Passwörter gefunden!${NC}"
    git diff --cached --name-only | grep -v "scripts/security/" | xargs grep -n "password.*=.*['\"][^{$]" 2>/dev/null || true
    ((SECURITY_ISSUES++))
fi

# 2. Check for API keys
echo "🔑 Prüfe auf API-Schlüssel..."
if git diff --cached --name-only | xargs grep -E "(api_key|secret_key|access_token).*=.*['\"][a-zA-Z0-9]{20,}" 2>/dev/null; then
    echo -e "${RED}❌ KRITISCH: API-Schlüssel gefunden!${NC}"
    ((SECURITY_ISSUES++))
fi

# 3. Check for .env files
echo "📝 Prüfe auf .env Dateien..."
if git diff --cached --name-only | grep -E "\.env$|\.env\." 2>/dev/null; then
    echo -e "${RED}❌ KRITISCH: .env Datei wird committed!${NC}"
    echo "Entferne .env Dateien aus dem Commit:"
    git diff --cached --name-only | grep -E "\.env$|\.env\."
    ((SECURITY_ISSUES++))
fi

# 4. Check for private keys (exclude security scripts)
echo "🔐 Prüfe auf private Schlüssel..."
if git diff --cached --name-only | grep -v "scripts/security/" | xargs grep -l "BEGIN.*PRIVATE KEY" 2>/dev/null; then
    echo -e "${RED}❌ KRITISCH: Private Schlüssel gefunden!${NC}"
    ((SECURITY_ISSUES++))
fi

# 5. Check for default passwords (exclude security scripts)
echo "🔓 Prüfe auf Default-Passwörter..."
if git diff --cached --name-only | grep -v "scripts/security/" | xargs grep -E "(password|secret).*=.*(admin|password|123|default|change.*this)" 2>/dev/null; then
    echo -e "${RED}❌ KRITISCH: Default-Passwörter gefunden!${NC}"
    ((SECURITY_ISSUES++))
fi

# 6. Check file permissions
echo "📋 Prüfe Dateiberechtigungen..."
for file in $(git diff --cached --name-only); do
    if [[ -f "$file" ]] && [[ "$(stat -c %a "$file" 2>/dev/null || stat -f %A "$file" 2>/dev/null)" =~ .*[0-9][0-9][2367] ]]; then
        echo -e "${YELLOW}⚠️  WARNUNG: $file ist world-writable${NC}"
    fi
done

# 7. Check for debug flags
echo "🐛 Prüfe auf Debug-Flags..."
if git diff --cached --name-only | xargs grep -E "(DEBUG|debug).*=.*(True|true|1)" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  WARNUNG: Debug-Flags aktiviert${NC}"
fi

# 🎯 Result
echo ""
if (( SECURITY_ISSUES > 0 )); then
    echo -e "${RED}🚨 $SECURITY_ISSUES KRITISCHE SICHERHEITSPROBLEME GEFUNDEN!${NC}"
    echo ""
    echo "COMMIT ABGEBROCHEN!"
    echo ""
    echo "Behebe die Probleme und versuche es erneut:"
    echo "1. Entferne hardcodierte Secrets"
    echo "2. Verwende Umgebungsvariablen"
    echo "3. Prüfe .gitignore Konfiguration"
    echo "4. Führe './scripts/security/security_hardening.sh' aus"
    echo ""
    exit 1
else
    echo -e "${GREEN}✅ Keine kritischen Sicherheitsprobleme gefunden${NC}"
    echo -e "${GREEN}✅ Commit kann fortgesetzt werden${NC}"
    exit 0
fi 