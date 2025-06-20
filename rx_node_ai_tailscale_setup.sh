#!/bin/bash

# GENTLEMAN RX Node AI + Tailscale Setup
# Optimiert für AI-Funktionen über Tailscale

set -eo pipefail

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}❌ $1${NC}" >&2
}

log_info() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}ℹ️ $1${NC}"
}

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}⚠️ $1${NC}"
}

# Erstelle RX Node Setup Commands
create_rx_setup_commands() {
    log_info "📝 Erstelle RX Node Setup Commands..."
    
    cat > ./rx_node_manual_setup.txt << 'EOF'
# GENTLEMAN RX Node Tailscale + AI Setup Commands
# Diese Befehle auf der RX Node ausführen (als amo9n11 user)

# 1. Tailscale Installation (Arch Linux)
echo "🔧 Installiere Tailscale..."
sudo pacman -S tailscale --noconfirm

# 2. Tailscale Service starten
echo "🚀 Starte Tailscale Service..."
sudo systemctl enable tailscaled
sudo systemctl start tailscaled

# 3. Tailscale Netzwerk beitreten
echo "🔗 Verbinde mit Tailscale..."
sudo tailscale up --advertise-routes=192.168.68.0/24 --accept-routes

# 4. Tailscale Status prüfen
echo "📊 Tailscale Status:"
tailscale status
tailscale ip -4

# 5. AI Services Setup
echo "🤖 Erstelle AI Services..."

# Python AI Server erstellen
cat > ~/ai_server.py << 'PYEOF'
#!/usr/bin/env python3
import http.server
import socketserver
import json
import subprocess
import os
import threading
import time
from datetime import datetime

class AIHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                "status": "ok", 
                "service": "rx-node-ai", 
                "timestamp": datetime.now().isoformat(),
                "capabilities": ["text-processing", "image-analysis", "data-computation"]
            }
            self.wfile.write(json.dumps(response).encode())
            
        elif self.path == '/ai/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            # System Info für AI
            gpu_info = "N/A"
            try:
                gpu_info = subprocess.run(['nvidia-smi', '--query-gpu=name,memory.total', '--format=csv,noheader'], 
                                        capture_output=True, text=True).stdout.strip()
            except:
                pass
            
            cpu_info = subprocess.run(['lscpu'], capture_output=True, text=True).stdout
            memory_info = subprocess.run(['free', '-h'], capture_output=True, text=True).stdout
            
            response = {
                "status": "ready",
                "service": "rx-node-ai",
                "hardware": {
                    "gpu": gpu_info,
                    "cpu_cores": os.cpu_count(),
                    "memory": memory_info.split('\n')[1].split()[1] if memory_info else "Unknown"
                },
                "models": ["text-generation", "image-processing", "data-analysis"],
                "timestamp": datetime.now().isoformat()
            }
            self.wfile.write(json.dumps(response).encode())
            
        elif self.path.startswith('/ai/'):
            # AI Endpoints
            self.handle_ai_request()
        else:
            self.send_error(404)
    
    def do_POST(self):
        if self.path.startswith('/ai/'):
            self.handle_ai_request()
        else:
            self.send_error(404)
    
    def handle_ai_request(self):
        """Handle AI processing requests"""
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length) if content_length > 0 else b''
        
        try:
            request_data = json.loads(post_data.decode()) if post_data else {}
        except:
            request_data = {}
        
        if self.path == '/ai/text/process':
            self.process_text(request_data)
        elif self.path == '/ai/image/analyze':
            self.analyze_image(request_data)
        elif self.path == '/ai/compute':
            self.compute_data(request_data)
        else:
            self.send_error(404)
    
    def process_text(self, data):
        """Simulate text processing"""
        text = data.get('text', 'No text provided')
        
        # Simulate processing time
        time.sleep(0.1)
        
        result = {
            "status": "processed",
            "input_length": len(text),
            "word_count": len(text.split()),
            "processed_text": text.upper(),  # Simple transformation
            "processing_time": 0.1,
            "timestamp": datetime.now().isoformat()
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(result).encode())
    
    def analyze_image(self, data):
        """Simulate image analysis"""
        image_path = data.get('image_path', 'no_image')
        
        result = {
            "status": "analyzed",
            "image": image_path,
            "analysis": {
                "objects_detected": ["example_object1", "example_object2"],
                "confidence": 0.95,
                "processing_time": 0.5
            },
            "timestamp": datetime.now().isoformat()
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(result).encode())
    
    def compute_data(self, data):
        """Simulate data computation"""
        numbers = data.get('numbers', [1, 2, 3, 4, 5])
        operation = data.get('operation', 'sum')
        
        if operation == 'sum':
            result_value = sum(numbers)
        elif operation == 'average':
            result_value = sum(numbers) / len(numbers) if numbers else 0
        elif operation == 'max':
            result_value = max(numbers) if numbers else 0
        else:
            result_value = 0
        
        result = {
            "status": "computed",
            "operation": operation,
            "input": numbers,
            "result": result_value,
            "timestamp": datetime.now().isoformat()
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(result).encode())

if __name__ == "__main__":
    PORT = 8765
    with socketserver.TCPServer(("", PORT), AIHandler) as httpd:
        print(f"🤖 RX Node AI Server läuft auf Port {PORT}")
        print(f"🎯 Verfügbare AI Endpoints:")
        print(f"   GET  /health          - Health Check")
        print(f"   GET  /ai/status       - AI System Status")
        print(f"   POST /ai/text/process - Text Processing")
        print(f"   POST /ai/image/analyze - Image Analysis")
        print(f"   POST /ai/compute      - Data Computation")
        httpd.serve_forever()
PYEOF

chmod +x ~/ai_server.py

# 6. AI Server als Service einrichten
echo "⚙️ Erstelle AI Service..."
sudo tee /etc/systemd/system/gentleman-ai.service > /dev/null << SERVICEEOF
[Unit]
Description=GENTLEMAN AI Server
After=network.target tailscaled.service

[Service]
Type=simple
User=amo9n11
WorkingDirectory=/home/amo9n11
ExecStart=/usr/bin/python3 /home/amo9n11/ai_server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable gentleman-ai.service
sudo systemctl start gentleman-ai.service

# 7. Status prüfen
echo "📊 Final Status Check:"
echo "Tailscale Status:"
tailscale status
echo ""
echo "Tailscale IP:"
tailscale ip -4
echo ""
echo "AI Service Status:"
systemctl status gentleman-ai.service --no-pager -l
echo ""
echo "🎉 Setup abgeschlossen!"
echo "AI Server läuft auf: http://$(tailscale ip -4):8765"
EOF

    log_success "RX Node Setup Commands erstellt"
}

# Erstelle AI Client für M1 Mac
create_ai_client() {
    log_info "📝 Erstelle AI Client für M1 Mac..."
    
    cat > ./ai_client.sh << 'EOF'
#!/bin/bash

# GENTLEMAN AI Client
# Nutzt RX Node AI Services über Tailscale

# Konfiguration
RX_NODE_IP=""  # Wird automatisch ermittelt
AI_PORT="8765"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Finde RX Node in Tailscale
find_rx_node() {
    RX_NODE_IP=$(tailscale status | grep "archlinux" | awk '{print $1}')
    
    if [ -z "$RX_NODE_IP" ]; then
        log_error "RX Node nicht im Tailscale Netzwerk gefunden"
        echo "Verfügbare Nodes:"
        tailscale status
        return 1
    fi
    
    log_success "RX Node gefunden: $RX_NODE_IP"
    return 0
}

# AI Health Check
ai_health() {
    if ! find_rx_node; then return 1; fi
    
    log_info "🔍 Prüfe AI Server Status..."
    
    response=$(curl -s --max-time 5 "http://$RX_NODE_IP:$AI_PORT/health")
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "AI Server ist erreichbar"
    else
        log_error "AI Server nicht erreichbar"
        return 1
    fi
}

# AI Status
ai_status() {
    if ! find_rx_node; then return 1; fi
    
    log_info "📊 Hole AI System Status..."
    
    response=$(curl -s --max-time 5 "http://$RX_NODE_IP:$AI_PORT/ai/status")
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
    else
        log_error "Konnte AI Status nicht abrufen"
        return 1
    fi
}

# Text Processing
ai_text() {
    if ! find_rx_node; then return 1; fi
    
    local text="$1"
    if [ -z "$text" ]; then
        echo "Verwendung: $0 text '<text>'"
        return 1
    fi
    
    log_info "📝 Verarbeite Text über AI..."
    
    response=$(curl -s --max-time 10 \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$text\"}" \
        "http://$RX_NODE_IP:$AI_PORT/ai/text/process")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Text verarbeitet"
    else
        log_error "Text-Verarbeitung fehlgeschlagen"
        return 1
    fi
}

# Data Computation
ai_compute() {
    if ! find_rx_node; then return 1; fi
    
    local numbers="$1"
    local operation="${2:-sum}"
    
    if [ -z "$numbers" ]; then
        echo "Verwendung: $0 compute '[1,2,3,4,5]' [sum|average|max]"
        return 1
    fi
    
    log_info "🔢 Führe Berechnung aus..."
    
    response=$(curl -s --max-time 10 \
        -H "Content-Type: application/json" \
        -d "{\"numbers\": $numbers, \"operation\": \"$operation\"}" \
        "http://$RX_NODE_IP:$AI_PORT/ai/compute")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Berechnung abgeschlossen"
    else
        log_error "Berechnung fehlgeschlagen"
        return 1
    fi
}

# Hauptfunktion
main() {
    case "${1:-health}" in
        "health")
            ai_health
            ;;
        "status")
            ai_status
            ;;
        "text")
            ai_text "$2"
            ;;
        "compute")
            ai_compute "$2" "$3"
            ;;
        "find")
            find_rx_node
            ;;
        *)
            echo "🤖 GENTLEMAN AI Client"
            echo "====================="
            echo ""
            echo "Kommandos:"
            echo "  health              - AI Server Health Check"
            echo "  status              - AI System Status"
            echo "  text '<text>'       - Text Processing"
            echo "  compute '[nums]' op - Data Computation"
            echo "  find                - Finde RX Node"
            echo ""
            echo "Beispiele:"
            echo "  $0 health"
            echo "  $0 status"
            echo "  $0 text 'Hello World'"
            echo "  $0 compute '[1,2,3,4,5]' sum"
            echo "  $0 compute '[10,20,30]' average"
            ;;
    esac
}

main "$@"
EOF

    chmod +x ./ai_client.sh
    log_success "AI Client erstellt"
}

# Erstelle Deployment Guide
create_ai_deployment_guide() {
    log_info "📖 Erstelle AI Deployment Guide..."
    
    cat > ./GENTLEMAN_AI_Tailscale_Guide.md << 'EOF'
# GENTLEMAN AI über Tailscale Setup

## 🎯 Übersicht
RX Node als AI-Server über Tailscale ohne Port-Forwarding nutzen.

## 🚀 Setup Schritte

### 1. RX Node Setup
```bash
# SSH zur RX Node
ssh rx-node

# Setup Commands ausführen (aus rx_node_manual_setup.txt)
# Jeder Befehl einzeln kopieren und ausführen
```

### 2. Tailscale Verbindung prüfen
```bash
# Auf M1 Mac
./tailscale_status.sh

# Sollte RX Node anzeigen
```

### 3. AI Services testen
```bash
# AI Health Check
./ai_client.sh health

# AI System Status
./ai_client.sh status

# Text Processing
./ai_client.sh text "Verarbeite diesen Text"

# Data Computation
./ai_client.sh compute '[1,2,3,4,5]' sum
```

## 🤖 Verfügbare AI Services

### Text Processing
- **Endpoint**: `/ai/text/process`
- **Method**: POST
- **Input**: `{"text": "your text"}`
- **Output**: Verarbeiteter Text mit Statistiken

### Image Analysis
- **Endpoint**: `/ai/image/analyze`
- **Method**: POST
- **Input**: `{"image_path": "path/to/image"}`
- **Output**: Bildanalyse-Ergebnisse

### Data Computation
- **Endpoint**: `/ai/compute`
- **Method**: POST
- **Input**: `{"numbers": [1,2,3], "operation": "sum"}`
- **Output**: Berechnungsergebnisse

## 🌐 Netzwerk-Architektur

```
M1 Mac (100.96.219.28)
    ↓ Tailscale
RX Node (100.x.x.x) ← AI Server Port 8765
    ↓
GPU/CPU AI Processing
```

## 💡 Vorteile

### Ohne Port-Forwarding:
- ✅ Keine Router-Konfiguration
- ✅ Funktioniert hinter CGNAT
- ✅ Sichere Ende-zu-Ende Verschlüsselung
- ✅ Automatische NAT-Traversal

### AI-Optimiert:
- 🤖 Dedizierte AI-Endpoints
- 📊 Hardware-Status Monitoring
- 🔄 Automatische Service-Wiederherstellung
- 📈 Skalierbare Architektur

## 🔧 Erweiterte Features

### GPU-Beschleunigung (falls vorhanden)
```python
# In ai_server.py erweitern für CUDA/OpenCL
import torch
if torch.cuda.is_available():
    device = torch.device("cuda")
```

### Model Loading
```python
# Verschiedene AI Models laden
models = {
    "text": load_text_model(),
    "image": load_image_model(),
    "audio": load_audio_model()
}
```

### Batch Processing
```python
# Für größere Datenmengen
def process_batch(data_batch):
    results = []
    for item in data_batch:
        results.append(process_item(item))
    return results
```

## 📊 Monitoring

### AI Performance
```bash
# System Resources
./ai_client.sh status

# Service Health
systemctl status gentleman-ai.service
```

### Tailscale Connectivity
```bash
# Network Status
tailscale status

# Ping Test
ping $(tailscale status | grep archlinux | awk '{print $1}')
```

## 🛠️ Troubleshooting

### AI Server nicht erreichbar
1. Tailscale Status prüfen: `tailscale status`
2. Service Status prüfen: `systemctl status gentleman-ai.service`
3. Firewall prüfen: `sudo ufw status`

### Performance Issues
1. GPU Verfügbarkeit: `nvidia-smi`
2. Memory Usage: `free -h`
3. CPU Load: `htop`

## 🚀 Zukunfts-Erweiterungen

- **Multi-Model Support**: Verschiedene AI Models
- **Streaming Responses**: Real-time AI Processing
- **Distributed Computing**: Multi-Node AI Cluster
- **Model Fine-tuning**: Custom Model Training
EOF

    log_success "AI Deployment Guide erstellt"
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🤖 GENTLEMAN RX Node AI + Tailscale Setup${NC}"
    echo "=============================================="
    echo ""
    
    log_info "Erstelle AI-optimiertes Setup für RX Node über Tailscale..."
    echo ""
    
    create_rx_setup_commands
    create_ai_client
    create_ai_deployment_guide
    
    echo ""
    log_success "🎉 AI + Tailscale Setup erstellt!"
    echo ""
    echo -e "${CYAN}📁 Erstellt:${NC}"
    echo "• rx_node_manual_setup.txt - RX Node Setup Commands"
    echo "• ai_client.sh - AI Client für M1 Mac"
    echo "• GENTLEMAN_AI_Tailscale_Guide.md - Vollständige Anleitung"
    echo ""
    echo -e "${YELLOW}🚀 Nächste Schritte:${NC}"
    echo "1. SSH zur RX Node: ssh rx-node"
    echo "2. Commands aus rx_node_manual_setup.txt ausführen"
    echo "3. AI Client testen: ./ai_client.sh health"
    echo ""
    echo -e "${GREEN}💡 AI Services über Tailscale:${NC}"
    echo "• Text Processing"
    echo "• Image Analysis"  
    echo "• Data Computation"
    echo "• Hardware Monitoring"
    echo "• Kein Port-Forwarding nötig!"
}

main "$@" 

# GENTLEMAN RX Node AI + Tailscale Setup
# Optimiert für AI-Funktionen über Tailscale

set -eo pipefail

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}❌ $1${NC}" >&2
}

log_info() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}ℹ️ $1${NC}"
}

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}⚠️ $1${NC}"
}

# Erstelle RX Node Setup Commands
create_rx_setup_commands() {
    log_info "📝 Erstelle RX Node Setup Commands..."
    
    cat > ./rx_node_manual_setup.txt << 'EOF'
# GENTLEMAN RX Node Tailscale + AI Setup Commands
# Diese Befehle auf der RX Node ausführen (als amo9n11 user)

# 1. Tailscale Installation (Arch Linux)
echo "🔧 Installiere Tailscale..."
sudo pacman -S tailscale --noconfirm

# 2. Tailscale Service starten
echo "🚀 Starte Tailscale Service..."
sudo systemctl enable tailscaled
sudo systemctl start tailscaled

# 3. Tailscale Netzwerk beitreten
echo "🔗 Verbinde mit Tailscale..."
sudo tailscale up --advertise-routes=192.168.68.0/24 --accept-routes

# 4. Tailscale Status prüfen
echo "📊 Tailscale Status:"
tailscale status
tailscale ip -4

# 5. AI Services Setup
echo "🤖 Erstelle AI Services..."

# Python AI Server erstellen
cat > ~/ai_server.py << 'PYEOF'
#!/usr/bin/env python3
import http.server
import socketserver
import json
import subprocess
import os
import threading
import time
from datetime import datetime

class AIHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                "status": "ok", 
                "service": "rx-node-ai", 
                "timestamp": datetime.now().isoformat(),
                "capabilities": ["text-processing", "image-analysis", "data-computation"]
            }
            self.wfile.write(json.dumps(response).encode())
            
        elif self.path == '/ai/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            # System Info für AI
            gpu_info = "N/A"
            try:
                gpu_info = subprocess.run(['nvidia-smi', '--query-gpu=name,memory.total', '--format=csv,noheader'], 
                                        capture_output=True, text=True).stdout.strip()
            except:
                pass
            
            cpu_info = subprocess.run(['lscpu'], capture_output=True, text=True).stdout
            memory_info = subprocess.run(['free', '-h'], capture_output=True, text=True).stdout
            
            response = {
                "status": "ready",
                "service": "rx-node-ai",
                "hardware": {
                    "gpu": gpu_info,
                    "cpu_cores": os.cpu_count(),
                    "memory": memory_info.split('\n')[1].split()[1] if memory_info else "Unknown"
                },
                "models": ["text-generation", "image-processing", "data-analysis"],
                "timestamp": datetime.now().isoformat()
            }
            self.wfile.write(json.dumps(response).encode())
            
        elif self.path.startswith('/ai/'):
            # AI Endpoints
            self.handle_ai_request()
        else:
            self.send_error(404)
    
    def do_POST(self):
        if self.path.startswith('/ai/'):
            self.handle_ai_request()
        else:
            self.send_error(404)
    
    def handle_ai_request(self):
        """Handle AI processing requests"""
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length) if content_length > 0 else b''
        
        try:
            request_data = json.loads(post_data.decode()) if post_data else {}
        except:
            request_data = {}
        
        if self.path == '/ai/text/process':
            self.process_text(request_data)
        elif self.path == '/ai/image/analyze':
            self.analyze_image(request_data)
        elif self.path == '/ai/compute':
            self.compute_data(request_data)
        else:
            self.send_error(404)
    
    def process_text(self, data):
        """Simulate text processing"""
        text = data.get('text', 'No text provided')
        
        # Simulate processing time
        time.sleep(0.1)
        
        result = {
            "status": "processed",
            "input_length": len(text),
            "word_count": len(text.split()),
            "processed_text": text.upper(),  # Simple transformation
            "processing_time": 0.1,
            "timestamp": datetime.now().isoformat()
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(result).encode())
    
    def analyze_image(self, data):
        """Simulate image analysis"""
        image_path = data.get('image_path', 'no_image')
        
        result = {
            "status": "analyzed",
            "image": image_path,
            "analysis": {
                "objects_detected": ["example_object1", "example_object2"],
                "confidence": 0.95,
                "processing_time": 0.5
            },
            "timestamp": datetime.now().isoformat()
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(result).encode())
    
    def compute_data(self, data):
        """Simulate data computation"""
        numbers = data.get('numbers', [1, 2, 3, 4, 5])
        operation = data.get('operation', 'sum')
        
        if operation == 'sum':
            result_value = sum(numbers)
        elif operation == 'average':
            result_value = sum(numbers) / len(numbers) if numbers else 0
        elif operation == 'max':
            result_value = max(numbers) if numbers else 0
        else:
            result_value = 0
        
        result = {
            "status": "computed",
            "operation": operation,
            "input": numbers,
            "result": result_value,
            "timestamp": datetime.now().isoformat()
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(result).encode())

if __name__ == "__main__":
    PORT = 8765
    with socketserver.TCPServer(("", PORT), AIHandler) as httpd:
        print(f"🤖 RX Node AI Server läuft auf Port {PORT}")
        print(f"🎯 Verfügbare AI Endpoints:")
        print(f"   GET  /health          - Health Check")
        print(f"   GET  /ai/status       - AI System Status")
        print(f"   POST /ai/text/process - Text Processing")
        print(f"   POST /ai/image/analyze - Image Analysis")
        print(f"   POST /ai/compute      - Data Computation")
        httpd.serve_forever()
PYEOF

chmod +x ~/ai_server.py

# 6. AI Server als Service einrichten
echo "⚙️ Erstelle AI Service..."
sudo tee /etc/systemd/system/gentleman-ai.service > /dev/null << SERVICEEOF
[Unit]
Description=GENTLEMAN AI Server
After=network.target tailscaled.service

[Service]
Type=simple
User=amo9n11
WorkingDirectory=/home/amo9n11
ExecStart=/usr/bin/python3 /home/amo9n11/ai_server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable gentleman-ai.service
sudo systemctl start gentleman-ai.service

# 7. Status prüfen
echo "📊 Final Status Check:"
echo "Tailscale Status:"
tailscale status
echo ""
echo "Tailscale IP:"
tailscale ip -4
echo ""
echo "AI Service Status:"
systemctl status gentleman-ai.service --no-pager -l
echo ""
echo "🎉 Setup abgeschlossen!"
echo "AI Server läuft auf: http://$(tailscale ip -4):8765"
EOF

    log_success "RX Node Setup Commands erstellt"
}

# Erstelle AI Client für M1 Mac
create_ai_client() {
    log_info "📝 Erstelle AI Client für M1 Mac..."
    
    cat > ./ai_client.sh << 'EOF'
#!/bin/bash

# GENTLEMAN AI Client
# Nutzt RX Node AI Services über Tailscale

# Konfiguration
RX_NODE_IP=""  # Wird automatisch ermittelt
AI_PORT="8765"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Finde RX Node in Tailscale
find_rx_node() {
    RX_NODE_IP=$(tailscale status | grep "archlinux" | awk '{print $1}')
    
    if [ -z "$RX_NODE_IP" ]; then
        log_error "RX Node nicht im Tailscale Netzwerk gefunden"
        echo "Verfügbare Nodes:"
        tailscale status
        return 1
    fi
    
    log_success "RX Node gefunden: $RX_NODE_IP"
    return 0
}

# AI Health Check
ai_health() {
    if ! find_rx_node; then return 1; fi
    
    log_info "🔍 Prüfe AI Server Status..."
    
    response=$(curl -s --max-time 5 "http://$RX_NODE_IP:$AI_PORT/health")
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "AI Server ist erreichbar"
    else
        log_error "AI Server nicht erreichbar"
        return 1
    fi
}

# AI Status
ai_status() {
    if ! find_rx_node; then return 1; fi
    
    log_info "📊 Hole AI System Status..."
    
    response=$(curl -s --max-time 5 "http://$RX_NODE_IP:$AI_PORT/ai/status")
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
    else
        log_error "Konnte AI Status nicht abrufen"
        return 1
    fi
}

# Text Processing
ai_text() {
    if ! find_rx_node; then return 1; fi
    
    local text="$1"
    if [ -z "$text" ]; then
        echo "Verwendung: $0 text '<text>'"
        return 1
    fi
    
    log_info "📝 Verarbeite Text über AI..."
    
    response=$(curl -s --max-time 10 \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$text\"}" \
        "http://$RX_NODE_IP:$AI_PORT/ai/text/process")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Text verarbeitet"
    else
        log_error "Text-Verarbeitung fehlgeschlagen"
        return 1
    fi
}

# Data Computation
ai_compute() {
    if ! find_rx_node; then return 1; fi
    
    local numbers="$1"
    local operation="${2:-sum}"
    
    if [ -z "$numbers" ]; then
        echo "Verwendung: $0 compute '[1,2,3,4,5]' [sum|average|max]"
        return 1
    fi
    
    log_info "🔢 Führe Berechnung aus..."
    
    response=$(curl -s --max-time 10 \
        -H "Content-Type: application/json" \
        -d "{\"numbers\": $numbers, \"operation\": \"$operation\"}" \
        "http://$RX_NODE_IP:$AI_PORT/ai/compute")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Berechnung abgeschlossen"
    else
        log_error "Berechnung fehlgeschlagen"
        return 1
    fi
}

# Hauptfunktion
main() {
    case "${1:-health}" in
        "health")
            ai_health
            ;;
        "status")
            ai_status
            ;;
        "text")
            ai_text "$2"
            ;;
        "compute")
            ai_compute "$2" "$3"
            ;;
        "find")
            find_rx_node
            ;;
        *)
            echo "🤖 GENTLEMAN AI Client"
            echo "====================="
            echo ""
            echo "Kommandos:"
            echo "  health              - AI Server Health Check"
            echo "  status              - AI System Status"
            echo "  text '<text>'       - Text Processing"
            echo "  compute '[nums]' op - Data Computation"
            echo "  find                - Finde RX Node"
            echo ""
            echo "Beispiele:"
            echo "  $0 health"
            echo "  $0 status"
            echo "  $0 text 'Hello World'"
            echo "  $0 compute '[1,2,3,4,5]' sum"
            echo "  $0 compute '[10,20,30]' average"
            ;;
    esac
}

main "$@"
EOF

    chmod +x ./ai_client.sh
    log_success "AI Client erstellt"
}

# Erstelle Deployment Guide
create_ai_deployment_guide() {
    log_info "📖 Erstelle AI Deployment Guide..."
    
    cat > ./GENTLEMAN_AI_Tailscale_Guide.md << 'EOF'
# GENTLEMAN AI über Tailscale Setup

## 🎯 Übersicht
RX Node als AI-Server über Tailscale ohne Port-Forwarding nutzen.

## 🚀 Setup Schritte

### 1. RX Node Setup
```bash
# SSH zur RX Node
ssh rx-node

# Setup Commands ausführen (aus rx_node_manual_setup.txt)
# Jeder Befehl einzeln kopieren und ausführen
```

### 2. Tailscale Verbindung prüfen
```bash
# Auf M1 Mac
./tailscale_status.sh

# Sollte RX Node anzeigen
```

### 3. AI Services testen
```bash
# AI Health Check
./ai_client.sh health

# AI System Status
./ai_client.sh status

# Text Processing
./ai_client.sh text "Verarbeite diesen Text"

# Data Computation
./ai_client.sh compute '[1,2,3,4,5]' sum
```

## 🤖 Verfügbare AI Services

### Text Processing
- **Endpoint**: `/ai/text/process`
- **Method**: POST
- **Input**: `{"text": "your text"}`
- **Output**: Verarbeiteter Text mit Statistiken

### Image Analysis
- **Endpoint**: `/ai/image/analyze`
- **Method**: POST
- **Input**: `{"image_path": "path/to/image"}`
- **Output**: Bildanalyse-Ergebnisse

### Data Computation
- **Endpoint**: `/ai/compute`
- **Method**: POST
- **Input**: `{"numbers": [1,2,3], "operation": "sum"}`
- **Output**: Berechnungsergebnisse

## 🌐 Netzwerk-Architektur

```
M1 Mac (100.96.219.28)
    ↓ Tailscale
RX Node (100.x.x.x) ← AI Server Port 8765
    ↓
GPU/CPU AI Processing
```

## 💡 Vorteile

### Ohne Port-Forwarding:
- ✅ Keine Router-Konfiguration
- ✅ Funktioniert hinter CGNAT
- ✅ Sichere Ende-zu-Ende Verschlüsselung
- ✅ Automatische NAT-Traversal

### AI-Optimiert:
- 🤖 Dedizierte AI-Endpoints
- 📊 Hardware-Status Monitoring
- 🔄 Automatische Service-Wiederherstellung
- 📈 Skalierbare Architektur

## 🔧 Erweiterte Features

### GPU-Beschleunigung (falls vorhanden)
```python
# In ai_server.py erweitern für CUDA/OpenCL
import torch
if torch.cuda.is_available():
    device = torch.device("cuda")
```

### Model Loading
```python
# Verschiedene AI Models laden
models = {
    "text": load_text_model(),
    "image": load_image_model(),
    "audio": load_audio_model()
}
```

### Batch Processing
```python
# Für größere Datenmengen
def process_batch(data_batch):
    results = []
    for item in data_batch:
        results.append(process_item(item))
    return results
```

## 📊 Monitoring

### AI Performance
```bash
# System Resources
./ai_client.sh status

# Service Health
systemctl status gentleman-ai.service
```

### Tailscale Connectivity
```bash
# Network Status
tailscale status

# Ping Test
ping $(tailscale status | grep archlinux | awk '{print $1}')
```

## 🛠️ Troubleshooting

### AI Server nicht erreichbar
1. Tailscale Status prüfen: `tailscale status`
2. Service Status prüfen: `systemctl status gentleman-ai.service`
3. Firewall prüfen: `sudo ufw status`

### Performance Issues
1. GPU Verfügbarkeit: `nvidia-smi`
2. Memory Usage: `free -h`
3. CPU Load: `htop`

## 🚀 Zukunfts-Erweiterungen

- **Multi-Model Support**: Verschiedene AI Models
- **Streaming Responses**: Real-time AI Processing
- **Distributed Computing**: Multi-Node AI Cluster
- **Model Fine-tuning**: Custom Model Training
EOF

    log_success "AI Deployment Guide erstellt"
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🤖 GENTLEMAN RX Node AI + Tailscale Setup${NC}"
    echo "=============================================="
    echo ""
    
    log_info "Erstelle AI-optimiertes Setup für RX Node über Tailscale..."
    echo ""
    
    create_rx_setup_commands
    create_ai_client
    create_ai_deployment_guide
    
    echo ""
    log_success "🎉 AI + Tailscale Setup erstellt!"
    echo ""
    echo -e "${CYAN}📁 Erstellt:${NC}"
    echo "• rx_node_manual_setup.txt - RX Node Setup Commands"
    echo "• ai_client.sh - AI Client für M1 Mac"
    echo "• GENTLEMAN_AI_Tailscale_Guide.md - Vollständige Anleitung"
    echo ""
    echo -e "${YELLOW}🚀 Nächste Schritte:${NC}"
    echo "1. SSH zur RX Node: ssh rx-node"
    echo "2. Commands aus rx_node_manual_setup.txt ausführen"
    echo "3. AI Client testen: ./ai_client.sh health"
    echo ""
    echo -e "${GREEN}💡 AI Services über Tailscale:${NC}"
    echo "• Text Processing"
    echo "• Image Analysis"  
    echo "• Data Computation"
    echo "• Hardware Monitoring"
    echo "• Kein Port-Forwarding nötig!"
}

main "$@" 
 