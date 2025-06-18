#!/bin/bash
# Start GENTLEMAN Protocol in offline mode

echo "🎩 Starte GENTLEMAN Protocol (Offline-Modus)"
echo "==========================================="

# Check if config exists
if [ ! -f "talking_gentleman_config.json" ]; then
    echo "❌ GENTLEMAN Config nicht gefunden!"
    exit 1
fi

# Start in background
echo "🚀 Starte GENTLEMAN Protocol..."
python3 talking_gentleman_protocol.py --start &
GENTLEMAN_PID=$!

echo "✅ GENTLEMAN Protocol gestartet (PID: $GENTLEMAN_PID)"
echo "📍 Port: 8008"
echo "🔍 Status: http://localhost:8008/status"

# Wait and check
sleep 3
if curl -s --connect-timeout 3 http://localhost:8008/status >/dev/null 2>&1; then
    echo "✅ GENTLEMAN Protocol erfolgreich gestartet!"
else
    echo "❌ GENTLEMAN Protocol Start fehlgeschlagen"
fi
