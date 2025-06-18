#!/bin/bash
# Helper script to distribute SSH keys when nodes come online

echo "🔑 SSH Key Distribution Helper"
echo "============================="

if [ ! -f "$HOME/.ssh/gentleman_key.pub" ]; then
    echo "❌ SSH Public Key nicht gefunden!"
    exit 1
fi

echo "📋 Aktueller Public Key:"
echo "----------------------------------------"
cat "$HOME/.ssh/gentleman_key.pub"
echo "----------------------------------------"
echo ""

echo "📝 Anweisungen für manuelle Verteilung:"
echo "1. Kopiere den obigen Public Key"
echo "2. Auf Ziel-Node: mkdir -p ~/.ssh"
echo "3. Auf Ziel-Node: echo 'COPIED_KEY' >> ~/.ssh/authorized_keys"
echo "4. Auf Ziel-Node: chmod 600 ~/.ssh/authorized_keys"
echo ""

echo "🎯 Ziel-Nodes:"
echo "- RX Node: amo9n11@192.168.68.117"
echo "- M1 Mac: amonbaumgartner@192.168.68.111"
echo "- i7 Node: amonbaumgartner@192.168.68.105"
