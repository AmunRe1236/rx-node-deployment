#!/bin/bash

# 🎩 GENTLEMAN - Stop Script
# ═══════════════════════════════════════════════════════════════
# Stoppe alle Gentleman Services

echo "🎩 GENTLEMAN DISTRIBUTED AI PIPELINE - SHUTDOWN"
echo "═══════════════════════════════════════════════════════════════"
echo "🛑 Stoppe alle Services..."
echo ""

# Lade PIDs falls verfügbar
if [ -f ".gentleman_pids" ]; then
    source .gentleman_pids
fi

# 🛑 Stoppe Services
services=(
    "LLM Server:$LLM_PID"
    "STT Service:$STT_PID"
    "TTS Service:$TTS_PID"
    "Mesh Coordinator:$MESH_PID"
    "Proton Mail:$PROTONMAIL_PID"
)

for service in "${services[@]}"; do
    name=$(echo $service | cut -d: -f1)
    pid=$(echo $service | cut -d: -f2)
    
    if [ ! -z "$pid" ] && kill -0 $pid 2>/dev/null; then
        echo "🛑 Stoppe $name (PID: $pid)..."
        kill $pid 2>/dev/null || true
        sleep 2
        if kill -0 $pid 2>/dev/null; then
            echo "⚠️ Force kill $name..."
            kill -9 $pid 2>/dev/null || true
        fi
        echo "✅ $name gestoppt"
    else
        echo "ℹ️ $name bereits gestoppt"
    fi
done

# 🧹 Cleanup zusätzlicher Prozesse
echo ""
echo "🧹 CLEANUP"
echo "═══════════════════════════════════════════════════════════════"

# Stoppe alle Python Services
pkill -f "python.*app.py" 2>/dev/null || true
pkill -f "uvicorn" 2>/dev/null || true

# Stoppe Docker Container falls vorhanden
if command -v docker &> /dev/null; then
    echo "🐳 Stoppe Docker Container..."
    docker-compose down 2>/dev/null || true
    docker-compose -f docker-compose.extended.yml down 2>/dev/null || true
fi

# Cleanup PID Datei
rm -f .gentleman_pids

echo "✅ Cleanup abgeschlossen"
echo ""

echo "🎩 GENTLEMAN SYSTEM GESTOPPT"
echo "═══════════════════════════════════════════════════════════════"
echo "📧 Proton Mail Service: Gestoppt"
echo "🤖 LLM Server: Gestoppt"
echo "🎤 STT Service: Gestoppt"
echo "🔊 TTS Service: Gestoppt"
echo "🌐 Mesh Coordinator: Gestoppt"
echo ""
echo "🚀 Starte System neu mit: ./scripts/init.sh"
echo "🎩 Auf Wiedersehen!"
echo "═══════════════════════════════════════════════════════════════" 