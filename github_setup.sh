#!/bin/bash
# 🐙 GitHub Setup für Gentleman AI System
# ═══════════════════════════════════════════════════════════════

echo "🐙 GitHub Setup für Gentleman AI System"
echo "========================================"
echo ""

# Überprüfe Git-Konfiguration
echo "📋 Aktuelle Git-Konfiguration:"
echo "Benutzer: $(git config user.name)"
echo "E-Mail: $(git config user.email)"
echo "Repository: $(git remote get-url origin)"
echo ""

# Zeige Commit-Status
echo "📊 Lokale Commits bereit für Push:"
git log --oneline origin/main..HEAD 2>/dev/null || echo "Keine Remote-Referenz gefunden"
echo ""

# Zeige Anweisungen für GitHub Personal Access Token
echo "🔑 GitHub Personal Access Token Setup:"
echo "======================================"
echo "1. Gehe zu: https://github.com/settings/tokens"
echo "2. Klicke auf 'Generate new token (classic)'"
echo "3. Wähle folgende Scopes:"
echo "   ✓ repo (Full control of private repositories)"
echo "   ✓ workflow (Update GitHub Action workflows)"
echo "4. Kopiere das generierte Token"
echo ""

# Git Credential Helper konfigurieren
echo "🔧 Git Credential Helper konfigurieren:"
echo "======================================="
echo "git config --global credential.helper store"
echo "git config --global user.name \"Dein GitHub Username\""
echo "git config --global user.email \"deine@email.com\""
echo ""

# Push-Befehl
echo "🚀 Push-Befehl:"
echo "==============="
echo "git push origin main"
echo ""
echo "Beim ersten Push wirst du nach Username und Token gefragt:"
echo "Username: Dein GitHub Username"
echo "Password: Das Personal Access Token (nicht dein GitHub Passwort!)"
echo ""

# Zeige aktuelle Dateien die gepusht werden
echo "📁 Dateien die gepusht werden:"
echo "=============================="
git diff --name-status origin/main..HEAD 2>/dev/null || echo "Alle Änderungen sind neu" 