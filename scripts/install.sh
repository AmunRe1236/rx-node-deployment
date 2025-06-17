#!/bin/bash

# 🎩 GENTLEMAN - Installation Script
# ═══════════════════════════════════════════════════════════════
# Vollständige Installation des Gentleman Distributed AI Pipeline

set -e

echo "🎩 GENTLEMAN DISTRIBUTED AI PIPELINE - INSTALLATION"
echo "═══════════════════════════════════════════════════════════════"
echo "🚀 Starte vollständige Installation..."
echo ""

# ... existing code ...

# 📧 Proton Mail Service Installation
echo "📧 PROTON MAIL SERVICE INSTALLATION"
echo "═══════════════════════════════════════════════════════════════"
echo "📧 E-Mail: amonbaumgartner@gentlemail.com"

# Erstelle Proton Mail Service Verzeichnisse
mkdir -p services/protonmail-service/{logs,data,config}

# Installiere Proton Mail Dependencies
echo "📦 Installiere Proton Mail Dependencies..."
cd services/protonmail-service
pip install -r requirements.txt
cd ../..

echo "✅ Proton Mail Service installiert"
echo ""

# ... existing code ...

# 🎯 Finale Zusammenfassung
echo "🎩 GENTLEMAN INSTALLATION ABGESCHLOSSEN"
echo "═══════════════════════════════════════════════════════════════"
echo "🤖 LLM Server: http://localhost:8001"
echo "🎤 STT Service: http://localhost:8002"
echo "🔊 TTS Service: http://localhost:8003"
echo "🌐 Mesh Coordinator: http://localhost:8004"
echo "📧 Proton Mail: http://localhost:8127 (amonbaumgartner@gentlemail.com)"
echo "🏠 Home Assistant Integration: Aktiviert"
echo "💾 TrueNAS Integration: Konfiguriert"
echo ""
echo "🚀 Starte alle Services mit: make start-all"
echo "🧪 Teste alle Services mit: make test-all"
echo "📊 Monitoring: http://localhost:3000 (Grafana)"
echo ""
echo "🎩 Wo Eleganz auf Funktionalität trifft!"
echo "═══════════════════════════════════════════════════════════════" 