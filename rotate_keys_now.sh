#!/bin/bash
# Manuelle Key-Rotation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starte manuelle Key-Rotation..."
echo "================================="

# Prüfe ob Python-Script vorhanden ist
if [ ! -f "key_rotation_system.py" ]; then
    echo "❌ key_rotation_system.py nicht gefunden!"
    exit 1
fi

# Führe Key-Rotation durch
echo "🔄 Führe Key-Rotation durch..."
python3 key_rotation_system.py

ROTATION_EXIT_CODE=$?

echo ""
echo "📊 Rotation abgeschlossen. Status:"

if [ $ROTATION_EXIT_CODE -eq 0 ]; then
    echo "✅ Key-Rotation erfolgreich!"
else
    echo "❌ Key-Rotation fehlgeschlagen (Exit Code: $ROTATION_EXIT_CODE)"
fi

echo ""
echo "📋 Aktueller Status:"
if [ -f "key_rotation_monitor.sh" ]; then
    ./key_rotation_monitor.sh
else
    echo "Monitor-Script nicht gefunden"
fi

exit $ROTATION_EXIT_CODE 