#!/bin/bash
# 🔑 SSH-Schlüssel Setup für Gentleman AI System
# ═══════════════════════════════════════════════════════════════

echo "🔑 SSH-Schlüssel Setup für M1 Mac"
echo "=================================="

# Überprüfe ob der Gentleman SSH-Schlüssel existiert
if [ ! -f ~/.ssh/id_rsa_gentleman ]; then
    echo "❌ Gentleman SSH-Schlüssel nicht gefunden!"
    echo "Generiere neuen Schlüssel..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_gentleman -N "" -C "gentleman-system-$(date +%Y%m%d)"
    chmod 600 ~/.ssh/id_rsa_gentleman
    chmod 644 ~/.ssh/id_rsa_gentleman.pub
    echo "✅ Neuer SSH-Schlüssel generiert"
fi

# Zeige den öffentlichen Schlüssel
echo ""
echo "📋 Öffentlicher Schlüssel für M1 Mac:"
echo "======================================"
cat ~/.ssh/id_rsa_gentleman.pub
echo ""

# Erstelle SSH-Config
echo "🔧 Aktualisiere SSH-Konfiguration..."
cat > ~/.ssh/config << EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa_gentleman
    IdentitiesOnly yes

Host m1-mac
    HostName 192.168.100.1
    User amo9n11
    IdentityFile ~/.ssh/id_rsa_gentleman
    IdentitiesOnly yes
    StrictHostKeyChecking no

Host rx-node
    HostName 192.168.100.10
    User amo9n11
    IdentityFile ~/.ssh/id_rsa_gentleman
    IdentitiesOnly yes
    StrictHostKeyChecking no
EOF

chmod 600 ~/.ssh/config
echo "✅ SSH-Konfiguration aktualisiert"

echo ""
echo "📝 Nächste Schritte:"
echo "==================="
echo "1. Kopiere den obigen öffentlichen Schlüssel"
echo "2. Auf dem M1 Mac ausführen:"
echo "   echo 'ÖFFENTLICHER_SCHLÜSSEL' >> ~/.ssh/authorized_keys"
echo "   chmod 600 ~/.ssh/authorized_keys"
echo "3. Teste die Verbindung mit: ssh m1-mac"
echo "" 