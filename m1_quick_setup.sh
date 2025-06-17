#!/bin/bash
# 🎩 GENTLEMAN AI - M1 Mac Quick Setup Script
# ═══════════════════════════════════════════════════════════════

echo "🎩 GENTLEMAN AI - M1 Mac Quick Setup"
echo "════════════════════════════════════════════════════════════"

# 1. IP-Adresse ermitteln
echo "🌐 Ermittle M1 IP-Adresse..."
M1_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
if [ -z "$M1_IP" ]; then
    echo "❌ Fehler: Konnte IP-Adresse nicht ermitteln"
    exit 1
fi
echo "✅ M1 IP-Adresse: $M1_IP"

# 2. Hostname ermitteln
M1_HOSTNAME=$(hostname)
echo "✅ M1 Hostname: $M1_HOSTNAME"

# 3. Discovery JSON erstellen
echo "📋 Erstelle discovery.json für M1 Mac..."
cat > discovery.json << EOF
{
  "service": "gentleman-discovery",
  "node_type": "m1-node",
  "status": "active",
  "hardware": "apple_m1",
  "ip_address": "$M1_IP",
  "hostname": "$M1_HOSTNAME",
  "services": [
    {
      "name": "stt-service",
      "port": 8002,
      "endpoint": "http://$M1_IP:8002",
      "status": "healthy",
      "capabilities": ["speech_to_text", "whisper_m1_optimized"]
    },
    {
      "name": "tts-service",
      "port": 8003,
      "endpoint": "http://$M1_IP:8003",
      "status": "healthy",
      "capabilities": ["text_to_speech", "m1_neural_engine"]
    },
    {
      "name": "mesh-coordinator",
      "port": 8004,
      "endpoint": "http://$M1_IP:8004",
      "status": "healthy",
      "capabilities": ["service_discovery", "mesh_coordination"]
    },
    {
      "name": "web-interface",
      "port": 8080,
      "endpoint": "http://$M1_IP:8080",
      "status": "healthy",
      "capabilities": ["web_ui", "dashboard"]
    }
  ],
  "mesh_info": {
    "coordinator_port": 8004,
    "discovery_enabled": true,
    "cross_node_compatible": true
  },
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S)",
  "node_id": "gentleman-m1-$(echo $M1_IP | tr '.' '-')"
}
EOF

echo "✅ discovery.json erstellt"

# 4. Index.html für M1 erstellen
echo "🌐 Erstelle index.html für M1 Mac..."
cat > index.html << EOF
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🎩 Gentleman AI - M1 Node Discovery</title>
    <style>
        body { font-family: Arial, sans-serif; background: #1a1a1a; color: #fff; margin: 20px; }
        .container { max-width: 800px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 30px; }
        .service { background: #2a2a2a; padding: 15px; margin: 10px 0; border-radius: 8px; }
        .status-healthy { color: #4CAF50; }
        .endpoint { color: #2196F3; text-decoration: none; }
        .endpoint:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎩 Gentleman AI - M1 Node</h1>
            <p><strong>Hardware:</strong> Apple M1/M2</p>
            <p><strong>IP-Adresse:</strong> $M1_IP</p>
            <p><strong>Hostname:</strong> $M1_HOSTNAME</p>
            <p><strong>Status:</strong> <span class="status-healthy">Aktiv</span></p>
        </div>
        
        <h2>🚀 Verfügbare Services</h2>
        
        <div class="service">
            <h3>🎤 STT Service (M1 Optimiert)</h3>
            <p><strong>Port:</strong> 8002</p>
            <p><strong>Status:</strong> <span class="status-healthy">Gesund</span></p>
            <p><strong>Endpoint:</strong> <a href="http://$M1_IP:8002" class="endpoint">http://$M1_IP:8002</a></p>
            <p><strong>Capabilities:</strong> Speech-to-Text, Whisper M1 Optimized</p>
        </div>
        
        <div class="service">
            <h3>🗣️ TTS Service (Neural Engine)</h3>
            <p><strong>Port:</strong> 8003</p>
            <p><strong>Status:</strong> <span class="status-healthy">Gesund</span></p>
            <p><strong>Endpoint:</strong> <a href="http://$M1_IP:8003" class="endpoint">http://$M1_IP:8003</a></p>
            <p><strong>Capabilities:</strong> Text-to-Speech, M1 Neural Engine</p>
        </div>
        
        <div class="service">
            <h3>🌐 Mesh Coordinator</h3>
            <p><strong>Port:</strong> 8004</p>
            <p><strong>Status:</strong> <span class="status-healthy">Gesund</span></p>
            <p><strong>Endpoint:</strong> <a href="http://$M1_IP:8004" class="endpoint">http://$M1_IP:8004</a></p>
            <p><strong>Capabilities:</strong> Service Discovery, Mesh Coordination</p>
        </div>
        
        <div class="service">
            <h3>🌐 Web Interface</h3>
            <p><strong>Port:</strong> 8080</p>
            <p><strong>Status:</strong> <span class="status-healthy">Gesund</span></p>
            <p><strong>Endpoint:</strong> <a href="http://$M1_IP:8080" class="endpoint">http://$M1_IP:8080</a></p>
            <p><strong>Capabilities:</strong> Web UI, Dashboard</p>
        </div>
        
        <h2>🔗 Discovery Endpoints</h2>
        <p><a href="/discovery.json" class="endpoint">JSON Discovery Info</a></p>
        <p><strong>Node ID:</strong> gentleman-m1-$(echo $M1_IP | tr '.' '-')</p>
        <p><strong>Cross-Node Compatible:</strong> ✅ Ja</p>
        <p><strong>RX-Node Partner:</strong> <a href="http://192.168.68.117:8005/" class="endpoint">192.168.68.117</a></p>
        
        <div style="text-align: center; margin-top: 30px; color: #666;">
            <p>🎩 Gentleman AI System - M1 Node Discovery Service</p>
            <p>Optimiert für Apple Silicon Neural Engine</p>
        </div>
    </div>
</body>
</html>
EOF

echo "✅ index.html erstellt"

# 5. Discovery Service starten
echo "🚀 Starte Discovery Service auf Port 8005..."
python3 -m http.server 8005 --bind 0.0.0.0 &
DISCOVERY_PID=$!
echo "✅ Discovery Service gestartet (PID: $DISCOVERY_PID)"

# 6. Test der Discovery
echo "🧪 Teste Discovery Service..."
sleep 2
if curl -s http://localhost:8005/discovery.json > /dev/null; then
    echo "✅ Discovery Service erfolgreich getestet"
else
    echo "❌ Discovery Service Test fehlgeschlagen"
fi

# 7. Zusammenfassung
echo ""
echo "🎉 M1 Mac Setup abgeschlossen!"
echo "════════════════════════════════════════════════════════════"
echo "🌐 Discovery URL: http://$M1_IP:8005/"
echo "📋 JSON API: http://$M1_IP:8005/discovery.json"
echo "🔗 RX-Node: http://192.168.68.117:8005/"
echo ""
echo "📝 Nächste Schritte:"
echo "1. Docker Services starten: docker-compose up -d"
echo "2. Test durchführen: python3 tests/intelligent_test.py"
echo "3. Cross-Node Test von RX-Node: curl http://$M1_IP:8005/discovery.json"
echo ""
 