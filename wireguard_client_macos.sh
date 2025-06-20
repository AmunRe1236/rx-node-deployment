#!/bin/bash

# GENTLEMAN WireGuard Client Setup (macOS)

echo "🎯 GENTLEMAN WireGuard Client Setup (macOS)"
echo "==========================================="
echo ""

# WireGuard installieren
if ! command -v wg >/dev/null 2>&1; then
    echo "📦 Installiere WireGuard..."
    if command -v brew >/dev/null 2>&1; then
        brew install wireguard-tools
    else
        echo "❌ Homebrew nicht gefunden. Bitte installiere WireGuard manuell:"
        echo "   https://www.wireguard.com/install/"
        exit 1
    fi
fi

echo "✅ WireGuard installiert"
echo ""
echo "📋 Nächste Schritte:"
echo "1. Config-Datei vom Server-Admin erhalten"
echo "2. WireGuard App aus App Store installieren"
echo "3. Config-Datei in WireGuard App importieren"
echo "4. Verbindung aktivieren"
echo ""
echo "💡 Oder via Terminal:"
echo "   sudo wg-quick up /path/to/config.conf"
