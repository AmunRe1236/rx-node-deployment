#!/bin/bash
# Gentleman AI System - Key Rotation Setup Script

set -e

echo "🔐 Gentleman AI System - Key Rotation Setup"
echo "=========================================="

# Erstelle notwendige Verzeichnisse
mkdir -p logs
mkdir -p backups/ssh_keys
mkdir -p backups/api_keys
mkdir -p backups/nebula_certs

# Setze Berechtigungen
chmod 700 backups
chmod 700 backups/ssh_keys
chmod 700 backups/api_keys
chmod 700 backups/nebula_certs

# Mache Python-Script ausführbar
chmod +x key_rotation_system.py

# Erstelle Systemd-Service für automatische Rotation
cat > /tmp/gentleman-key-rotation.service << 'EOF'
[Unit]
Description=Gentleman AI System Key Rotation
After=network.target

[Service]
Type=oneshot
User=amo9n11
WorkingDirectory=/home/amo9n11/Documents/Archives/gentleman
ExecStart=/usr/bin/python3 /home/amo9n11/Documents/Archives/gentleman/key_rotation_system.py
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Erstelle Systemd-Timer für wöchentliche Rotation
cat > /tmp/gentleman-key-rotation.timer << 'EOF'
[Unit]
Description=Run Gentleman Key Rotation weekly
Requires=gentleman-key-rotation.service

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Installiere Systemd-Files (benötigt sudo)
echo "📦 Installiere Systemd-Service und Timer..."
sudo cp /tmp/gentleman-key-rotation.service /etc/systemd/system/
sudo cp /tmp/gentleman-key-rotation.timer /etc/systemd/system/

# Aktiviere und starte Timer
sudo systemctl daemon-reload
sudo systemctl enable gentleman-key-rotation.timer
sudo systemctl start gentleman-key-rotation.timer

# Erstelle Cron-Job als Backup (falls Systemd nicht verfügbar)
echo "⏰ Erstelle Cron-Job für Key-Rotation..."
(crontab -l 2>/dev/null; echo "0 2 * * 0 cd /home/amo9n11/Documents/Archives/gentleman && python3 key_rotation_system.py") | crontab -

# Erstelle Monitoring-Script
cat > key_rotation_monitor.sh << 'EOF'
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

# Zeige letzte Log-Einträge
echo ""
echo "📝 Letzte Log-Einträge:"
if [ -f "logs/key_rotation.log" ]; then
    tail -10 logs/key_rotation.log
else
    echo "Keine Log-Datei gefunden"
fi
EOF

chmod +x key_rotation_monitor.sh

# Erstelle manuelles Rotation-Script
cat > rotate_keys_now.sh << 'EOF'
#!/bin/bash
# Manuelle Key-Rotation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starte manuelle Key-Rotation..."
echo "================================="

python3 key_rotation_system.py

echo ""
echo "📊 Rotation abgeschlossen. Status:"
./key_rotation_monitor.sh
EOF

chmod +x rotate_keys_now.sh

# Erstelle Konfigurationsdatei falls nicht vorhanden
if [ ! -f "key_rotation_config.json" ]; then
    echo "⚙️  Erstelle Standard-Konfiguration..."
    python3 -c "
import json
config = {
    'ssh_keys': {
        'rotation_interval_days': 30,
        'key_type': 'rsa',
        'key_size': 4096,
        'backup_count': 5
    },
    'nebula_certs': {
        'rotation_interval_days': 90,
        'ca_name': 'Gentleman-Mesh-CA',
        'backup_count': 3
    },
    'api_keys': {
        'rotation_interval_days': 7,
        'key_length': 64,
        'backup_count': 10
    },
    'nodes': {
        'rx_node': {
            'ip': '192.168.100.10',
            'ssh_user': 'amo9n11'
        },
        'm1_mac': {
            'ip': '192.168.100.1',
            'ssh_user': 'amo9n11'
        }
    }
}
with open('key_rotation_config.json', 'w') as f:
    json.dump(config, f, indent=2)
print('✅ Konfiguration erstellt: key_rotation_config.json')
"
fi

echo ""
echo "✅ Key-Rotation-System erfolgreich eingerichtet!"
echo ""
echo "📋 Verfügbare Befehle:"
echo "  ./key_rotation_monitor.sh    - Status anzeigen"
echo "  ./rotate_keys_now.sh         - Manuelle Rotation"
echo "  python3 key_rotation_system.py --check - Prüfe ob Rotation benötigt"
echo ""
echo "⏰ Automatische Rotation:"
echo "  Systemd-Timer: Wöchentlich (Sonntag 2:00 Uhr)"
echo "  Cron-Job: Backup-Mechanismus"
echo ""
echo "📁 Wichtige Dateien:"
echo "  key_rotation_config.json - Konfiguration"
echo "  rotation_status.json     - Rotation-Status"
echo "  logs/key_rotation.log    - Log-Datei"
echo ""
echo "🔐 Das Key-Rotation-System ist jetzt aktiv!" 