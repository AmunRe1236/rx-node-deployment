#!/bin/bash

# 🎨 EXCALIDRAW REAL-TIME SYNC SETUP
# ==================================
# Setup für 1Hz Excalidraw Synchronisation zwischen allen Nodes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M1_HOST="192.168.68.111"
SYNC_PORT="3001"
WEB_PORT="3002"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_info() {
    log "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    log "${GREEN}✅ $1${NC}"
}

log_error() {
    log "${RED}❌ $1${NC}"
}

# 1. Python Dependencies installieren
install_dependencies() {
    log_info "📦 Installiere Python Dependencies..."
    
    # Lokale Installation
    pip3 install websockets asyncio sqlite3 || log_error "Lokale Installation fehlgeschlagen"
    
    # M1 Mac Installation
    ssh amonbaumgartner@$M1_HOST "pip3 install websockets asyncio || echo 'M1 Installation teilweise fehlgeschlagen'"
    
    log_success "Dependencies installiert"
}

# 2. Excalidraw Sync Server auf M1 starten
start_m1_sync_server() {
    log_info "🖥️ Starte Excalidraw Sync Server auf M1 Mac..."
    
    # Übertrage Server-Script
    scp excalidraw_realtime_sync.py amonbaumgartner@$M1_HOST:/Users/amonbaumgartner/Gentleman/
    
    # Stoppe alte Instanzen
    ssh amonbaumgartner@$M1_HOST "pkill -f excalidraw_realtime_sync.py || echo 'Keine alten Instanzen'"
    
    # Starte Server als Daemon
    ssh amonbaumgartner@$M1_HOST "cd /Users/amonbaumgartner/Gentleman && nohup python3 excalidraw_realtime_sync.py > excalidraw_sync.log 2>&1 &"
    
    # Warte und teste
    sleep 3
    if ssh amonbaumgartner@$M1_HOST "pgrep -f excalidraw_realtime_sync.py > /dev/null"; then
        log_success "Excalidraw Sync Server auf M1 gestartet"
        return 0
    else
        log_error "Server-Start fehlgeschlagen"
        return 1
    fi
}

# 3. Web Interface erstellen
create_web_interface() {
    log_info "🌐 Erstelle Excalidraw Web Interface..."
    
    cat > excalidraw_web.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>🎨 Excalidraw Real-Time Sync</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
            margin: 0; padding: 20px; background: #f8f9fa;
        }
        .header { 
            background: white; padding: 20px; border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px;
        }
        .status { 
            display: flex; gap: 20px; align-items: center; flex-wrap: wrap;
        }
        .status-item { 
            background: #f1f3f4; padding: 8px 12px; border-radius: 6px; 
            font-size: 14px; min-width: 100px;
        }
        .connected { background: #e8f5e8; color: #2d5a2d; }
        .disconnected { background: #ffeaa7; color: #d63031; }
        .controls { 
            background: white; padding: 20px; border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px;
        }
        .controls input, .controls button { 
            padding: 10px; margin: 5px; border: 1px solid #ddd; 
            border-radius: 4px; font-size: 14px;
        }
        .controls button { 
            background: #0984e3; color: white; border: none; cursor: pointer;
        }
        .controls button:hover { background: #0770c0; }
        #canvas { 
            background: white; border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            min-height: 600px; padding: 20px;
        }
        .log { 
            background: #2d3436; color: #ddd; padding: 15px; 
            border-radius: 8px; font-family: monospace; font-size: 12px;
            max-height: 200px; overflow-y: auto; margin-top: 20px;
        }
        .performance { 
            display: flex; gap: 10px; font-size: 12px; color: #636e72;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🎨 Excalidraw Real-Time Sync</h1>
        <div class="status">
            <div class="status-item" id="connectionStatus">
                <strong>Status:</strong> <span id="status" class="disconnected">Verbinde...</span>
            </div>
            <div class="status-item">
                <strong>Room:</strong> <span id="room">default</span>
            </div>
            <div class="status-item">
                <strong>Clients:</strong> <span id="clients">0</span>
            </div>
            <div class="status-item">
                <strong>Ping:</strong> <span id="ping">--</span>ms
            </div>
        </div>
        <div class="performance">
            <span>Sync Rate: 1Hz</span>
            <span>•</span>
            <span>Protocol: WebSocket</span>
            <span>•</span>
            <span>Server: M1 Mac (192.168.68.111:3001)</span>
        </div>
    </div>
    
    <div class="controls">
        <label>Room ID: <input type="text" id="roomInput" value="default" placeholder="Room Name"></label>
        <button onclick="joinRoom()">🚪 Room beitreten</button>
        <button onclick="clearCanvas()">🗑️ Canvas leeren</button>
        <button onclick="exportData()">💾 Exportieren</button>
        <button onclick="toggleLog()">📋 Log anzeigen</button>
    </div>
    
    <div id="canvas">
        <div style="text-align: center; padding: 50px; color: #636e72;">
            <h2>🎨 Excalidraw Canvas</h2>
            <p>Hier wird das echte Excalidraw Canvas eingebettet</p>
            <p>WebSocket Status: <span id="wsStatus">Verbinde...</span></p>
            <div style="margin-top: 20px;">
                <div>📡 Real-Time Synchronisation aktiv</div>
                <div>⚡ Updates alle 1 Sekunde</div>
                <div>👥 Multi-User Support</div>
            </div>
        </div>
    </div>
    
    <div id="logContainer" class="log" style="display: none;">
        <div id="logContent"></div>
    </div>
    
    <script>
        let ws = null;
        let currentRoom = 'default';
        let pingStartTime = 0;
        let logVisible = false;
        
        function log(message) {
            const timestamp = new Date().toLocaleTimeString();
            const logContent = document.getElementById('logContent');
            logContent.innerHTML += `[${timestamp}] ${message}\n`;
            logContent.scrollTop = logContent.scrollHeight;
        }
        
        function connect() {
            const wsUrl = `ws://${window.location.hostname}:3001`;
            log(`Verbinde zu ${wsUrl}...`);
            ws = new WebSocket(wsUrl);
            
            ws.onopen = function() {
                document.getElementById('status').textContent = 'Verbunden';
                document.getElementById('status').className = 'connected';
                document.getElementById('wsStatus').textContent = 'Verbunden ✅';
                document.getElementById('connectionStatus').className = 'status-item connected';
                log('✅ WebSocket Verbindung hergestellt');
                joinRoom();
                startPing();
            };
            
            ws.onmessage = function(event) {
                const data = JSON.parse(event.data);
                
                if (data.type === 'heartbeat') {
                    document.getElementById('clients').textContent = data.total_clients;
                    log(`💓 Heartbeat: ${data.total_clients} Clients, ${data.active_rooms} Rooms`);
                } else if (data.type === 'pong') {
                    const ping = Date.now() - pingStartTime;
                    document.getElementById('ping').textContent = ping;
                } else if (data.type === 'drawing_sync') {
                    log(`🎨 Zeichnung synchronisiert (${data.checksum.substring(0,8)}...)`);
                } else if (data.type === 'user_joined') {
                    log(`👋 Benutzer ist Room '${data.room_id}' beigetreten`);
                } else {
                    log(`📨 ${data.type}: ${JSON.stringify(data).substring(0,100)}...`);
                }
            };
            
            ws.onclose = function() {
                document.getElementById('status').textContent = 'Getrennt';
                document.getElementById('status').className = 'disconnected';
                document.getElementById('wsStatus').textContent = 'Getrennt ❌';
                document.getElementById('connectionStatus').className = 'status-item disconnected';
                log('❌ Verbindung getrennt, versuche Reconnect...');
                setTimeout(connect, 2000);
            };
            
            ws.onerror = function(error) {
                log(`🚨 WebSocket Fehler: ${error}`);
            };
        }
        
        function joinRoom() {
            const roomId = document.getElementById('roomInput').value || 'default';
            currentRoom = roomId;
            document.getElementById('room').textContent = roomId;
            
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({
                    type: 'join_room',
                    room_id: roomId
                }));
                log(`🚪 Room '${roomId}' beigetreten`);
            }
        }
        
        function clearCanvas() {
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({
                    type: 'drawing_update',
                    room_id: currentRoom,
                    data: { elements: [], appState: {} }
                }));
                log('🗑️ Canvas geleert');
            }
        }
        
        function exportData() {
            log('💾 Export-Funktion würde hier implementiert werden');
        }
        
        function toggleLog() {
            logVisible = !logVisible;
            document.getElementById('logContainer').style.display = logVisible ? 'block' : 'none';
        }
        
        function startPing() {
            setInterval(() => {
                if (ws && ws.readyState === WebSocket.OPEN) {
                    pingStartTime = Date.now();
                    ws.send(JSON.stringify({ type: 'ping' }));
                }
            }, 5000); // Ping alle 5 Sekunden
        }
        
        // Auto-connect beim Laden
        connect();
        
        // Simuliere Zeichnungs-Updates (für Demo)
        setInterval(() => {
            if (ws && ws.readyState === WebSocket.OPEN && Math.random() > 0.95) {
                ws.send(JSON.stringify({
                    type: 'drawing_update',
                    room_id: currentRoom,
                    data: {
                        elements: [{ id: Date.now(), type: 'rectangle', x: Math.random() * 100, y: Math.random() * 100 }],
                        appState: { viewBackgroundColor: '#ffffff' }
                    }
                }));
            }
        }, 1000); // 1Hz Demo-Updates
    </script>
</body>
</html>
EOF

    log_success "Web Interface erstellt"
}

# 4. Lokalen Client erstellen
create_local_client() {
    log_info "💻 Erstelle lokalen Excalidraw Client..."
    
    cat > excalidraw_client.py << 'EOF'
#!/usr/bin/env python3
"""
Excalidraw Client für Real-Time Sync
"""

import asyncio
import websockets
import json
import time

class ExcalidrawClient:
    def __init__(self, server_url="ws://192.168.68.111:3001"):
        self.server_url = server_url
        self.room_id = "default"
        self.user_id = f"user_{int(time.time())}"
        
    async def connect(self):
        print(f"🔗 Verbinde zu {self.server_url}...")
        
        async with websockets.connect(self.server_url) as websocket:
            # Join Room
            await websocket.send(json.dumps({
                "type": "join_room",
                "room_id": self.room_id
            }))
            
            print(f"✅ Verbunden mit Room '{self.room_id}'")
            
            # Empfange Nachrichten
            async for message in websocket:
                data = json.loads(message)
                print(f"📨 {data['type']}: {str(data)[:100]}...")
                
                if data['type'] == 'heartbeat':
                    print(f"💓 {data['total_clients']} Clients aktiv")

if __name__ == "__main__":
    client = ExcalidrawClient()
    asyncio.run(client.connect())
EOF

    chmod +x excalidraw_client.py
    log_success "Lokaler Client erstellt"
}

# 5. Test der Synchronisation
test_sync() {
    log_info "🧪 Teste Excalidraw Synchronisation..."
    
    # Teste WebSocket Verbindung
    if command -v wscat > /dev/null; then
        echo '{"type":"ping"}' | wscat -c ws://$M1_HOST:$SYNC_PORT -x || log_error "WebSocket Test fehlgeschlagen"
    else
        log_info "wscat nicht verfügbar, überspringe WebSocket Test"
    fi
    
    # Teste HTTP Interface
    if curl -s http://$M1_HOST:$WEB_PORT > /dev/null; then
        log_success "Web Interface erreichbar"
    else
        log_error "Web Interface nicht erreichbar"
    fi
    
    # Teste Server Status
    if ssh amonbaumgartner@$M1_HOST "pgrep -f excalidraw_realtime_sync.py > /dev/null"; then
        log_success "Sync Server läuft auf M1"
    else
        log_error "Sync Server nicht aktiv"
    fi
}

# 6. Monitoring Setup
setup_monitoring() {
    log_info "📊 Richte Monitoring ein..."
    
    cat > monitor_excalidraw.sh << 'EOF'
#!/bin/bash

# Excalidraw Sync Monitoring
echo "🎨 EXCALIDRAW SYNC MONITORING"
echo "============================="

M1_HOST="192.168.68.111"

echo "📊 Server Status:"
if ssh amonbaumgartner@$M1_HOST "pgrep -f excalidraw_realtime_sync.py > /dev/null"; then
    echo "  ✅ Sync Server: AKTIV"
    PID=$(ssh amonbaumgartner@$M1_HOST "pgrep -f excalidraw_realtime_sync.py")
    echo "  📋 PID: $PID"
else
    echo "  ❌ Sync Server: INAKTIV"
fi

echo ""
echo "🌐 Endpoints:"
echo "  • WebSocket: ws://$M1_HOST:3001"
echo "  • Web Interface: http://$M1_HOST:3002"
echo "  • Health Check: curl http://$M1_HOST:3001/health"

echo ""
echo "📈 Performance:"
echo "  • Sync Rate: 1Hz (1 Update/Sekunde)"
echo "  • Max Clients/Room: 50"
echo "  • Database: SQLite"

echo ""
echo "📋 Logs:"
ssh amonbaumgartner@$M1_HOST "tail -5 /Users/amonbaumgartner/Gentleman/excalidraw_sync.log 2>/dev/null || echo 'Keine Logs verfügbar'"
EOF

    chmod +x monitor_excalidraw.sh
    log_success "Monitoring Setup abgeschlossen"
}

# Hauptfunktion
main() {
    echo "🎨 EXCALIDRAW REAL-TIME SYNC SETUP"
    echo "=================================="
    echo ""
    echo "📋 Features:"
    echo "  • 1Hz Real-Time Synchronisation"
    echo "  • Multi-User Support (50 Clients/Room)"
    echo "  • WebSocket + SQLite Backend"
    echo "  • Web Interface für Browser-Zugriff"
    echo "  • VPN-kompatibel für RX Node"
    echo ""
    
    read -p "🚀 Setup starten? (y/n): " confirm
    if [[ $confirm != "y" ]]; then
        echo "Setup abgebrochen"
        exit 0
    fi
    
    install_dependencies
    start_m1_sync_server
    create_web_interface
    create_local_client
    setup_monitoring
    
    echo ""
    log_success "🎉 Excalidraw Real-Time Sync Setup abgeschlossen!"
    echo ""
    echo "📋 Nächste Schritte:"
    echo "  1. Web Interface öffnen: http://$M1_HOST:3002"
    echo "  2. Client testen: python3 excalidraw_client.py"
    echo "  3. Monitoring: ./monitor_excalidraw.sh"
    echo "  4. RX Node: Über VPN ws://10.0.0.1:3001 verbinden"
    echo ""
    echo "🎨 Viel Spaß mit Real-Time Excalidraw!"
    
    # Teste Setup
    test_sync
}

# Script ausführen
main "$@" 

# 🎨 EXCALIDRAW REAL-TIME SYNC SETUP
# ==================================
# Setup für 1Hz Excalidraw Synchronisation zwischen allen Nodes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M1_HOST="192.168.68.111"
SYNC_PORT="3001"
WEB_PORT="3002"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_info() {
    log "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    log "${GREEN}✅ $1${NC}"
}

log_error() {
    log "${RED}❌ $1${NC}"
}

# 1. Python Dependencies installieren
install_dependencies() {
    log_info "📦 Installiere Python Dependencies..."
    
    # Lokale Installation
    pip3 install websockets asyncio sqlite3 || log_error "Lokale Installation fehlgeschlagen"
    
    # M1 Mac Installation
    ssh amonbaumgartner@$M1_HOST "pip3 install websockets asyncio || echo 'M1 Installation teilweise fehlgeschlagen'"
    
    log_success "Dependencies installiert"
}

# 2. Excalidraw Sync Server auf M1 starten
start_m1_sync_server() {
    log_info "🖥️ Starte Excalidraw Sync Server auf M1 Mac..."
    
    # Übertrage Server-Script
    scp excalidraw_realtime_sync.py amonbaumgartner@$M1_HOST:/Users/amonbaumgartner/Gentleman/
    
    # Stoppe alte Instanzen
    ssh amonbaumgartner@$M1_HOST "pkill -f excalidraw_realtime_sync.py || echo 'Keine alten Instanzen'"
    
    # Starte Server als Daemon
    ssh amonbaumgartner@$M1_HOST "cd /Users/amonbaumgartner/Gentleman && nohup python3 excalidraw_realtime_sync.py > excalidraw_sync.log 2>&1 &"
    
    # Warte und teste
    sleep 3
    if ssh amonbaumgartner@$M1_HOST "pgrep -f excalidraw_realtime_sync.py > /dev/null"; then
        log_success "Excalidraw Sync Server auf M1 gestartet"
        return 0
    else
        log_error "Server-Start fehlgeschlagen"
        return 1
    fi
}

# 3. Web Interface erstellen
create_web_interface() {
    log_info "🌐 Erstelle Excalidraw Web Interface..."
    
    cat > excalidraw_web.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>🎨 Excalidraw Real-Time Sync</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
            margin: 0; padding: 20px; background: #f8f9fa;
        }
        .header { 
            background: white; padding: 20px; border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px;
        }
        .status { 
            display: flex; gap: 20px; align-items: center; flex-wrap: wrap;
        }
        .status-item { 
            background: #f1f3f4; padding: 8px 12px; border-radius: 6px; 
            font-size: 14px; min-width: 100px;
        }
        .connected { background: #e8f5e8; color: #2d5a2d; }
        .disconnected { background: #ffeaa7; color: #d63031; }
        .controls { 
            background: white; padding: 20px; border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px;
        }
        .controls input, .controls button { 
            padding: 10px; margin: 5px; border: 1px solid #ddd; 
            border-radius: 4px; font-size: 14px;
        }
        .controls button { 
            background: #0984e3; color: white; border: none; cursor: pointer;
        }
        .controls button:hover { background: #0770c0; }
        #canvas { 
            background: white; border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            min-height: 600px; padding: 20px;
        }
        .log { 
            background: #2d3436; color: #ddd; padding: 15px; 
            border-radius: 8px; font-family: monospace; font-size: 12px;
            max-height: 200px; overflow-y: auto; margin-top: 20px;
        }
        .performance { 
            display: flex; gap: 10px; font-size: 12px; color: #636e72;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🎨 Excalidraw Real-Time Sync</h1>
        <div class="status">
            <div class="status-item" id="connectionStatus">
                <strong>Status:</strong> <span id="status" class="disconnected">Verbinde...</span>
            </div>
            <div class="status-item">
                <strong>Room:</strong> <span id="room">default</span>
            </div>
            <div class="status-item">
                <strong>Clients:</strong> <span id="clients">0</span>
            </div>
            <div class="status-item">
                <strong>Ping:</strong> <span id="ping">--</span>ms
            </div>
        </div>
        <div class="performance">
            <span>Sync Rate: 1Hz</span>
            <span>•</span>
            <span>Protocol: WebSocket</span>
            <span>•</span>
            <span>Server: M1 Mac (192.168.68.111:3001)</span>
        </div>
    </div>
    
    <div class="controls">
        <label>Room ID: <input type="text" id="roomInput" value="default" placeholder="Room Name"></label>
        <button onclick="joinRoom()">🚪 Room beitreten</button>
        <button onclick="clearCanvas()">🗑️ Canvas leeren</button>
        <button onclick="exportData()">💾 Exportieren</button>
        <button onclick="toggleLog()">📋 Log anzeigen</button>
    </div>
    
    <div id="canvas">
        <div style="text-align: center; padding: 50px; color: #636e72;">
            <h2>🎨 Excalidraw Canvas</h2>
            <p>Hier wird das echte Excalidraw Canvas eingebettet</p>
            <p>WebSocket Status: <span id="wsStatus">Verbinde...</span></p>
            <div style="margin-top: 20px;">
                <div>📡 Real-Time Synchronisation aktiv</div>
                <div>⚡ Updates alle 1 Sekunde</div>
                <div>👥 Multi-User Support</div>
            </div>
        </div>
    </div>
    
    <div id="logContainer" class="log" style="display: none;">
        <div id="logContent"></div>
    </div>
    
    <script>
        let ws = null;
        let currentRoom = 'default';
        let pingStartTime = 0;
        let logVisible = false;
        
        function log(message) {
            const timestamp = new Date().toLocaleTimeString();
            const logContent = document.getElementById('logContent');
            logContent.innerHTML += `[${timestamp}] ${message}\n`;
            logContent.scrollTop = logContent.scrollHeight;
        }
        
        function connect() {
            const wsUrl = `ws://${window.location.hostname}:3001`;
            log(`Verbinde zu ${wsUrl}...`);
            ws = new WebSocket(wsUrl);
            
            ws.onopen = function() {
                document.getElementById('status').textContent = 'Verbunden';
                document.getElementById('status').className = 'connected';
                document.getElementById('wsStatus').textContent = 'Verbunden ✅';
                document.getElementById('connectionStatus').className = 'status-item connected';
                log('✅ WebSocket Verbindung hergestellt');
                joinRoom();
                startPing();
            };
            
            ws.onmessage = function(event) {
                const data = JSON.parse(event.data);
                
                if (data.type === 'heartbeat') {
                    document.getElementById('clients').textContent = data.total_clients;
                    log(`💓 Heartbeat: ${data.total_clients} Clients, ${data.active_rooms} Rooms`);
                } else if (data.type === 'pong') {
                    const ping = Date.now() - pingStartTime;
                    document.getElementById('ping').textContent = ping;
                } else if (data.type === 'drawing_sync') {
                    log(`🎨 Zeichnung synchronisiert (${data.checksum.substring(0,8)}...)`);
                } else if (data.type === 'user_joined') {
                    log(`👋 Benutzer ist Room '${data.room_id}' beigetreten`);
                } else {
                    log(`📨 ${data.type}: ${JSON.stringify(data).substring(0,100)}...`);
                }
            };
            
            ws.onclose = function() {
                document.getElementById('status').textContent = 'Getrennt';
                document.getElementById('status').className = 'disconnected';
                document.getElementById('wsStatus').textContent = 'Getrennt ❌';
                document.getElementById('connectionStatus').className = 'status-item disconnected';
                log('❌ Verbindung getrennt, versuche Reconnect...');
                setTimeout(connect, 2000);
            };
            
            ws.onerror = function(error) {
                log(`🚨 WebSocket Fehler: ${error}`);
            };
        }
        
        function joinRoom() {
            const roomId = document.getElementById('roomInput').value || 'default';
            currentRoom = roomId;
            document.getElementById('room').textContent = roomId;
            
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({
                    type: 'join_room',
                    room_id: roomId
                }));
                log(`🚪 Room '${roomId}' beigetreten`);
            }
        }
        
        function clearCanvas() {
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({
                    type: 'drawing_update',
                    room_id: currentRoom,
                    data: { elements: [], appState: {} }
                }));
                log('🗑️ Canvas geleert');
            }
        }
        
        function exportData() {
            log('💾 Export-Funktion würde hier implementiert werden');
        }
        
        function toggleLog() {
            logVisible = !logVisible;
            document.getElementById('logContainer').style.display = logVisible ? 'block' : 'none';
        }
        
        function startPing() {
            setInterval(() => {
                if (ws && ws.readyState === WebSocket.OPEN) {
                    pingStartTime = Date.now();
                    ws.send(JSON.stringify({ type: 'ping' }));
                }
            }, 5000); // Ping alle 5 Sekunden
        }
        
        // Auto-connect beim Laden
        connect();
        
        // Simuliere Zeichnungs-Updates (für Demo)
        setInterval(() => {
            if (ws && ws.readyState === WebSocket.OPEN && Math.random() > 0.95) {
                ws.send(JSON.stringify({
                    type: 'drawing_update',
                    room_id: currentRoom,
                    data: {
                        elements: [{ id: Date.now(), type: 'rectangle', x: Math.random() * 100, y: Math.random() * 100 }],
                        appState: { viewBackgroundColor: '#ffffff' }
                    }
                }));
            }
        }, 1000); // 1Hz Demo-Updates
    </script>
</body>
</html>
EOF

    log_success "Web Interface erstellt"
}

# 4. Lokalen Client erstellen
create_local_client() {
    log_info "💻 Erstelle lokalen Excalidraw Client..."
    
    cat > excalidraw_client.py << 'EOF'
#!/usr/bin/env python3
"""
Excalidraw Client für Real-Time Sync
"""

import asyncio
import websockets
import json
import time

class ExcalidrawClient:
    def __init__(self, server_url="ws://192.168.68.111:3001"):
        self.server_url = server_url
        self.room_id = "default"
        self.user_id = f"user_{int(time.time())}"
        
    async def connect(self):
        print(f"🔗 Verbinde zu {self.server_url}...")
        
        async with websockets.connect(self.server_url) as websocket:
            # Join Room
            await websocket.send(json.dumps({
                "type": "join_room",
                "room_id": self.room_id
            }))
            
            print(f"✅ Verbunden mit Room '{self.room_id}'")
            
            # Empfange Nachrichten
            async for message in websocket:
                data = json.loads(message)
                print(f"📨 {data['type']}: {str(data)[:100]}...")
                
                if data['type'] == 'heartbeat':
                    print(f"💓 {data['total_clients']} Clients aktiv")

if __name__ == "__main__":
    client = ExcalidrawClient()
    asyncio.run(client.connect())
EOF

    chmod +x excalidraw_client.py
    log_success "Lokaler Client erstellt"
}

# 5. Test der Synchronisation
test_sync() {
    log_info "🧪 Teste Excalidraw Synchronisation..."
    
    # Teste WebSocket Verbindung
    if command -v wscat > /dev/null; then
        echo '{"type":"ping"}' | wscat -c ws://$M1_HOST:$SYNC_PORT -x || log_error "WebSocket Test fehlgeschlagen"
    else
        log_info "wscat nicht verfügbar, überspringe WebSocket Test"
    fi
    
    # Teste HTTP Interface
    if curl -s http://$M1_HOST:$WEB_PORT > /dev/null; then
        log_success "Web Interface erreichbar"
    else
        log_error "Web Interface nicht erreichbar"
    fi
    
    # Teste Server Status
    if ssh amonbaumgartner@$M1_HOST "pgrep -f excalidraw_realtime_sync.py > /dev/null"; then
        log_success "Sync Server läuft auf M1"
    else
        log_error "Sync Server nicht aktiv"
    fi
}

# 6. Monitoring Setup
setup_monitoring() {
    log_info "📊 Richte Monitoring ein..."
    
    cat > monitor_excalidraw.sh << 'EOF'
#!/bin/bash

# Excalidraw Sync Monitoring
echo "🎨 EXCALIDRAW SYNC MONITORING"
echo "============================="

M1_HOST="192.168.68.111"

echo "📊 Server Status:"
if ssh amonbaumgartner@$M1_HOST "pgrep -f excalidraw_realtime_sync.py > /dev/null"; then
    echo "  ✅ Sync Server: AKTIV"
    PID=$(ssh amonbaumgartner@$M1_HOST "pgrep -f excalidraw_realtime_sync.py")
    echo "  📋 PID: $PID"
else
    echo "  ❌ Sync Server: INAKTIV"
fi

echo ""
echo "🌐 Endpoints:"
echo "  • WebSocket: ws://$M1_HOST:3001"
echo "  • Web Interface: http://$M1_HOST:3002"
echo "  • Health Check: curl http://$M1_HOST:3001/health"

echo ""
echo "📈 Performance:"
echo "  • Sync Rate: 1Hz (1 Update/Sekunde)"
echo "  • Max Clients/Room: 50"
echo "  • Database: SQLite"

echo ""
echo "📋 Logs:"
ssh amonbaumgartner@$M1_HOST "tail -5 /Users/amonbaumgartner/Gentleman/excalidraw_sync.log 2>/dev/null || echo 'Keine Logs verfügbar'"
EOF

    chmod +x monitor_excalidraw.sh
    log_success "Monitoring Setup abgeschlossen"
}

# Hauptfunktion
main() {
    echo "🎨 EXCALIDRAW REAL-TIME SYNC SETUP"
    echo "=================================="
    echo ""
    echo "📋 Features:"
    echo "  • 1Hz Real-Time Synchronisation"
    echo "  • Multi-User Support (50 Clients/Room)"
    echo "  • WebSocket + SQLite Backend"
    echo "  • Web Interface für Browser-Zugriff"
    echo "  • VPN-kompatibel für RX Node"
    echo ""
    
    read -p "🚀 Setup starten? (y/n): " confirm
    if [[ $confirm != "y" ]]; then
        echo "Setup abgebrochen"
        exit 0
    fi
    
    install_dependencies
    start_m1_sync_server
    create_web_interface
    create_local_client
    setup_monitoring
    
    echo ""
    log_success "🎉 Excalidraw Real-Time Sync Setup abgeschlossen!"
    echo ""
    echo "📋 Nächste Schritte:"
    echo "  1. Web Interface öffnen: http://$M1_HOST:3002"
    echo "  2. Client testen: python3 excalidraw_client.py"
    echo "  3. Monitoring: ./monitor_excalidraw.sh"
    echo "  4. RX Node: Über VPN ws://10.0.0.1:3001 verbinden"
    echo ""
    echo "🎨 Viel Spaß mit Real-Time Excalidraw!"
    
    # Teste Setup
    test_sync
}

# Script ausführen
main "$@" 
 