#!/bin/bash

# 🎩 GENTLEMAN - Initialization Script
# ═══════════════════════════════════════════════════════════════
# Initialisierung und Start aller Gentleman Services

set -e

echo "🎩 GENTLEMAN DISTRIBUTED AI PIPELINE - INITIALIZATION"
echo "═══════════════════════════════════════════════════════════════"
echo "🚀 Starte System-Initialisierung..."
echo ""

# ... existing code ...

# 📧 Proton Mail Service Initialisierung
echo "📧 PROTON MAIL SERVICE INITIALIZATION"
echo "═══════════════════════════════════════════════════════════════"
echo "📧 E-Mail: amonbaumgartner@gentlemail.com"

# Prüfe Proton Mail Service Konfiguration
if [ ! -f "config/integrations/protonmail.yaml" ]; then
    echo "⚠️ Proton Mail Konfiguration nicht gefunden"
    echo "📝 Erstelle Standard-Konfiguration..."
    mkdir -p config/integrations
    cp config/integrations/protonmail.yaml.example config/integrations/protonmail.yaml 2>/dev/null || true
fi

# Starte Proton Mail Service
echo "🚀 Starte Proton Mail Service..."
cd services/protonmail-service
python app.py &
PROTONMAIL_PID=$!
cd ../..

# Warte auf Service Start
echo "⏳ Warte auf Proton Mail Service..."
sleep 5

# Teste Proton Mail Service
if curl -s http://localhost:8127/health > /dev/null; then
    echo "✅ Proton Mail Service erfolgreich gestartet"
    echo "📧 Verfügbar auf: http://localhost:8127"
else
    echo "❌ Proton Mail Service Start fehlgeschlagen"
    kill $PROTONMAIL_PID 2>/dev/null || true
    exit 1
fi

echo ""

# ... existing code ...

# 🎯 System Status Check
echo "🎯 SYSTEM STATUS CHECK"
echo "═══════════════════════════════════════════════════════════════"

# Service Health Checks
services=(
    "LLM Server:http://localhost:8001/health"
    "STT Service:http://localhost:8002/health"
    "TTS Service:http://localhost:8003/health"
    "Mesh Coordinator:http://localhost:8004/health"
    "Proton Mail:http://localhost:8127/health"
)

for service in "${services[@]}"; do
    name=$(echo $service | cut -d: -f1)
    url=$(echo $service | cut -d: -f2-)
    
    if curl -s "$url" > /dev/null; then
        echo "✅ $name: Online"
    else
        echo "❌ $name: Offline"
    fi
done

echo ""

# 🎩 Finale System-Übersicht
echo "🎩 GENTLEMAN SYSTEM BEREIT"
echo "═══════════════════════════════════════════════════════════════"
echo "🤖 LLM Server: http://localhost:8001"
echo "🎤 STT Service: http://localhost:8002"
echo "🔊 TTS Service: http://localhost:8003"
echo "🌐 Mesh Coordinator: http://localhost:8004"
echo "📧 Proton Mail: http://localhost:8127"
echo ""
echo "📧 E-Mail-Adresse: amonbaumgartner@gentlemail.com"
echo "🏠 Home Assistant: Integriert"
echo "💾 TrueNAS: Konfiguriert"
echo "🔐 Nebula Mesh: Aktiv"
echo ""
echo "🎭 Voice Pipeline: Voice → STT → LLM → TTS → Voice"
echo "📱 Smart Home: Voice Commands, E-Mail Notifications"
echo "📊 Monitoring: Prometheus + Grafana"
echo ""
echo "🎩 Wo Eleganz auf Funktionalität trifft!"
echo "═══════════════════════════════════════════════════════════════"

# Speichere PIDs für Cleanup
echo "LLM_PID=$LLM_PID" > .gentleman_pids
echo "STT_PID=$STT_PID" >> .gentleman_pids
echo "TTS_PID=$TTS_PID" >> .gentleman_pids
echo "MESH_PID=$MESH_PID" >> .gentleman_pids
echo "PROTONMAIL_PID=$PROTONMAIL_PID" >> .gentleman_pids

echo "🎯 System erfolgreich initialisiert!"
echo "🛑 Stoppe alle Services mit: ./scripts/stop.sh" 