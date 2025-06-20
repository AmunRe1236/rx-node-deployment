#!/bin/bash

# GENTLEMAN WireGuard Client Setup (Linux)

echo "🎯 GENTLEMAN WireGuard Client Setup (Linux)"
echo "==========================================="
echo ""

# WireGuard installieren
echo "📦 Installiere WireGuard..."
if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y wireguard wireguard-tools
elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S wireguard-tools
elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y wireguard-tools
else
    echo "❌ Paketmanager nicht erkannt. Bitte WireGuard manuell installieren."
    exit 1
fi

echo "✅ WireGuard installiert"
echo ""
echo "📋 Verwendung:"
echo "1. Config-Datei nach /etc/wireguard/ kopieren"
echo "2. sudo wg-quick up <config-name>"
echo "3. sudo systemctl enable wg-quick@<config-name> (für Autostart)"
echo ""
echo "Beispiel:"
echo "  sudo cp client.conf /etc/wireguard/"
echo "  sudo wg-quick up client"
