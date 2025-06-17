#!/bin/bash
# Key Rotation Monitoring Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔍 Gentleman AI System - Key Rotation Status"
echo "==========================================="

# Prüfe letzten Rotation-Status
if [ -f "rotation_status.json" ]; then
    echo "📊 Letzter Rotation-Status:"
    cat rotation_status.json | python3 -m json.tool
    echo ""
fi

# Prüfe ob Rotation benötigt wird
echo "🔄 Prüfe ob Rotation benötigt wird..."
if python3 key_rotation_system.py --check; then
    echo "✅ Keine Rotation benötigt"
else
    echo "⚠️  Key-Rotation benötigt!"
fi

# Zeige Systemd-Timer Status
echo ""
echo "⏱️  Systemd-Timer Status:"
systemctl status gentleman-key-rotation.timer --no-pager -l

# Zeige Cron-Job Status
echo ""
echo "⏰ Cron-Job Status:"
crontab -l | grep key_rotation || echo "Kein Cron-Job gefunden"

# Zeige letzte Log-Einträge
echo ""
echo "📝 Letzte Log-Einträge:"
if [ -f "logs/key_rotation.log" ]; then
    tail -10 logs/key_rotation.log
else
    echo "Keine Log-Datei gefunden"
fi

# Zeige SSH-Key Status
echo ""
echo "🔐 SSH-Key Status:"
ls -la ~/.ssh/id_rsa_*_rotated* 2>/dev/null || echo "Keine rotierten SSH-Keys gefunden"

# Zeige API-Key Status
echo ""
echo "🔑 API-Key Status:"
if [ -f "api_keys.json" ]; then
    echo "API-Keys vorhanden ($(stat -c %y api_keys.json))"
else
    echo "Keine API-Keys gefunden"
fi 