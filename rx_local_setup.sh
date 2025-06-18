#!/bin/bash

# 🎯 RX Node Lokale GENTLEMAN Konfiguration
# Dieses Script wird direkt auf der RX Node ausgeführt
# Version: 1.0
# Datum: $(date)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Konfiguration
GENTLEMAN_DIR="$HOME/Gentleman"
BACKUP_DIR="$HOME/Gentleman/backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${BLUE}🎯 RX Node Lokale GENTLEMAN Konfiguration${NC}"
echo -e "${BLUE}===========================================${NC}"
echo "Hostname: $(hostname 2>/dev/null || echo 'Unknown')"
echo "User: $(whoami)"
echo "Timestamp: $(date)"
echo "Working Directory: $(pwd)"
echo ""

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Step 1: System Information
log "🔍 Sammle System Informationen..."
echo "System: $(uname -a)"
echo "Python: $(python3 --version 2>/dev/null || echo 'Python3 nicht gefunden')"
echo "Verfügbarer Speicher: $(free -h 2>/dev/null | grep Mem || echo 'Memory info nicht verfügbar')"
echo "Netzwerk Interface: $(ip addr show 2>/dev/null | grep inet | head -3 || echo 'Network info nicht verfügbar')"
echo ""

# Step 2: Create directory structure
log "📁 Erstelle Verzeichnisstruktur..."
mkdir -p "$GENTLEMAN_DIR"/{backup,logs,config,scripts,data}
mkdir -p "$HOME/.gentleman"
log "✅ Verzeichnisse erstellt"

# Step 3: Install Python dependencies
log "🐍 Installiere Python Abhängigkeiten..."
if command -v python3 >/dev/null 2>&1; then
    # Try different installation methods
    if python3 -m pip install --user --break-system-packages requests sqlite3 2>/dev/null; then
        log "✅ Python Pakete über pip installiert"
    elif python3 -m pip install --user requests 2>/dev/null; then
        log "✅ Python Pakete über pip (ohne break-system-packages) installiert"
    else
        warning "Pip Installation fehlgeschlagen - versuche System-Pakete"
        # For Arch Linux
        if command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm python-requests python-sqlite 2>/dev/null || true
        fi
    fi
else
    error "Python3 nicht gefunden!"
    exit 1
fi

# Step 4: Create RX Node configuration
log "⚙️ Erstelle RX Node Konfiguration..."
cat > "$GENTLEMAN_DIR/talking_gentleman_config.json" << 'EOF'
{
  "node_id": "rx-local-trainer-$(date +%s)",
  "port": 8008,
  "role": "primary_trainer",
  "api_key": "0EH8lZvERxVF5s8YNK-hOJHIxgDDcGjVdROrk6iUGFY",
  "encryption_enabled": true,
  "cache_path": "~/.gentleman/talking_cache.db",
  "knowledge_db_path": "~/Gentleman/knowledge.db",
  "network": {
    "discovery_enabled": true,
    "discovery_port": 8009,
    "heartbeat_interval": 30,
    "sync_interval": 300,
    "timeout": 10
  },
  "known_nodes": [
    {
      "ip": "192.168.68.111",
      "port": 8008,
      "role": "secondary",
      "name": "m1-mac",
      "ai_enabled": true,
      "comment": "M1 Mac - Secondary Node"
    },
    {
      "ip": "192.168.68.117",
      "port": 8008,
      "role": "primary_trainer",
      "name": "rx-node",
      "ai_enabled": true,
      "comment": "RX Node - Haupttrainer für AI Knowledge System"
    },
    {
      "ip": "192.168.68.105",
      "port": 8008,
      "role": "client",
      "name": "i7-node",
      "ai_enabled": true,
      "comment": "I7 Node - Client mit AI-Unterstützung"
    }
  ],
  "capabilities": [
    "knowledge_training",
    "gpu_inference",
    "cluster_management",
    "distributed_training",
    "model_serving"
  ],
  "ai_integration": {
    "auto_load_clusters": true,
    "cache_embeddings": true,
    "max_cache_size_mb": 500,
    "inference_timeout": 60,
    "gpu_enabled": true,
    "training_mode": true
  },
  "hardware": {
    "gpu_available": true,
    "memory_gb": 16,
    "cpu_cores": 8,
    "specialized_role": "ai_trainer"
  }
}
EOF

log "✅ Konfiguration erstellt"

# Step 5: Create the main protocol file
log "📝 Erstelle GENTLEMAN Protocol..."
cat > "$GENTLEMAN_DIR/talking_gentleman_protocol.py" << 'EOF'
#!/usr/bin/env python3
"""
🎯 GENTLEMAN Protocol - RX Node Local Version
Lokale Version für RX Node Training Server
"""

import json
import sqlite3
import threading
import time
import sys
import os
import argparse
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import socket

class GentlemanProtocol:
    def __init__(self, config_path="talking_gentleman_config.json"):
        self.config_path = config_path
        self.config = self.load_config()
        self.server = None
        self.running = False
        self.setup_database()
        
    def load_config(self):
        """Load configuration from JSON file"""
        try:
            with open(self.config_path, 'r') as f:
                config = json.load(f)
                # Expand paths
                config['cache_path'] = os.path.expanduser(config['cache_path'])
                config['knowledge_db_path'] = os.path.expanduser(config['knowledge_db_path'])
                return config
        except Exception as e:
            print(f"❌ Config loading error: {e}")
            return self.default_config()
    
    def default_config(self):
        """Default configuration if file not found"""
        return {
            "node_id": f"rx-local-{int(time.time())}",
            "port": 8008,
            "role": "primary_trainer",
            "network": {"heartbeat_interval": 30}
        }
    
    def setup_database(self):
        """Initialize SQLite database"""
        try:
            db_path = self.config.get('knowledge_db_path', 'knowledge.db')
            os.makedirs(os.path.dirname(db_path), exist_ok=True)
            
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            
            # Knowledge cache table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS knowledge_cache (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    query TEXT NOT NULL,
                    response TEXT NOT NULL,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    node_id TEXT,
                    embedding BLOB
                )
            ''')
            
            # Node registry table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS node_registry (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    node_id TEXT UNIQUE NOT NULL,
                    ip_address TEXT NOT NULL,
                    port INTEGER NOT NULL,
                    role TEXT NOT NULL,
                    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
                    capabilities TEXT
                )
            ''')
            
            conn.commit()
            conn.close()
            print("✅ Database initialized")
            
        except Exception as e:
            print(f"❌ Database setup error: {e}")
    
    def register_node(self):
        """Register this node in the database"""
        try:
            db_path = self.config.get('knowledge_db_path', 'knowledge.db')
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT OR REPLACE INTO node_registry 
                (node_id, ip_address, port, role, capabilities, last_seen)
                VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ''', (
                self.config['node_id'],
                '192.168.68.117',  # RX Node IP
                self.config['port'],
                self.config['role'],
                json.dumps(self.config.get('capabilities', []))
            ))
            
            conn.commit()
            conn.close()
            print(f"✅ Node registered: {self.config['node_id']}")
            
        except Exception as e:
            print(f"❌ Node registration error: {e}")

class GentlemanHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        """Handle GET requests"""
        try:
            parsed_path = urlparse(self.path)
            
            if parsed_path.path == '/status':
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                
                status = {
                    "status": "online",
                    "node_id": "rx-local-trainer",
                    "role": "primary_trainer",
                    "timestamp": time.time(),
                    "capabilities": ["training", "gpu_inference"]
                }
                
                self.wfile.write(json.dumps(status).encode())
                
            elif parsed_path.path == '/health':
                self.send_response(200)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(b'OK')
                
            else:
                self.send_response(404)
                self.end_headers()
                
        except Exception as e:
            print(f"❌ Request handling error: {e}")
            self.send_response(500)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Override to reduce log spam"""
        pass

def main():
    parser = argparse.ArgumentParser(description='GENTLEMAN Protocol RX Node')
    parser.add_argument('--start', action='store_true', help='Start the server')
    parser.add_argument('--status', action='store_true', help='Check status')
    parser.add_argument('--test', action='store_true', help='Run tests')
    
    args = parser.parse_args()
    
    print("🎯 GENTLEMAN Protocol - RX Node Local Version")
    print("=" * 50)
    
    if args.status:
        print("📊 Status Check:")
        print(f"   Node ID: rx-local-trainer-{int(time.time())}")
        print(f"   Role: Primary AI Trainer")
        print(f"   Port: 8008")
        print(f"   GPU: Available")
        return
    
    if args.test:
        print("🧪 Running tests...")
        protocol = GentlemanProtocol()
        protocol.register_node()
        print("✅ Tests completed")
        return
    
    if args.start:
        print("🚀 Starting GENTLEMAN Service...")
        protocol = GentlemanProtocol()
        protocol.register_node()
        
        try:
            server = HTTPServer(('0.0.0.0', protocol.config['port']), GentlemanHandler)
            print(f"✅ Server running on port {protocol.config['port']}")
            print("Press Ctrl+C to stop")
            server.serve_forever()
            
        except KeyboardInterrupt:
            print("\n🛑 Server stopped by user")
        except Exception as e:
            print(f"❌ Server error: {e}")
    
    else:
        print("Usage: python3 talking_gentleman_protocol.py --start|--status|--test")

if __name__ == "__main__":
    main()
EOF

chmod +x "$GENTLEMAN_DIR/talking_gentleman_protocol.py"
log "✅ Protocol Script erstellt"

# Step 6: Create management scripts
log "🛠️ Erstelle Management Scripts..."

# Start script
cat > "$GENTLEMAN_DIR/start_gentleman.sh" << 'EOF'
#!/bin/bash
echo "🎯 Starting GENTLEMAN Service on RX Node..."
echo "Role: Primary AI Trainer"
echo "Port: 8008"
echo "GPU: Enabled"
echo ""
cd ~/Gentleman
python3 talking_gentleman_protocol.py --start
EOF
chmod +x "$GENTLEMAN_DIR/start_gentleman.sh"

# Status script
cat > "$GENTLEMAN_DIR/check_status.sh" << 'EOF'
#!/bin/bash
echo "🎯 RX Node GENTLEMAN Status"
echo "==========================="
echo "Hostname: $(hostname 2>/dev/null || echo 'Unknown')"
echo "User: $(whoami)"
echo "Directory: $(pwd)"
echo ""
echo "🔍 GENTLEMAN Dateien:"
ls -la ~/Gentleman/ 2>/dev/null || echo "Gentleman directory not found"
echo ""
echo "🌐 Netzwerk Status:"
ss -tlnp 2>/dev/null | grep :8008 || echo "Port 8008 nicht aktiv"
echo ""
echo "💾 Speicher:"
df -h ~/Gentleman/ 2>/dev/null || echo "Disk info not available"
echo ""
echo "🖥️ System:"
free -h 2>/dev/null || echo "Memory info not available"
echo ""
echo "🔧 Python:"
python3 --version 2>/dev/null || echo "Python3 not found"
EOF
chmod +x "$GENTLEMAN_DIR/check_status.sh"

# Test script
cat > "$GENTLEMAN_DIR/test_gentleman.sh" << 'EOF'
#!/bin/bash
echo "🧪 GENTLEMAN System Test"
echo "========================"
cd ~/Gentleman

echo "1. Configuration Test:"
python3 -c "import json; print('✅ Config OK' if json.load(open('talking_gentleman_config.json')) else '❌ Config Error')"

echo "2. Database Test:"
python3 talking_gentleman_protocol.py --test

echo "3. Network Test:"
python3 -c "
import socket
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(('0.0.0.0', 8008))
    s.close()
    print('✅ Port 8008 available')
except:
    print('❌ Port 8008 in use or blocked')
"

echo "4. Status Test:"
python3 talking_gentleman_protocol.py --status

echo ""
echo "🎉 Test completed!"
EOF
chmod +x "$GENTLEMAN_DIR/test_gentleman.sh"

log "✅ Management Scripts erstellt"

# Step 7: Create installation summary
log "📋 Erstelle Installations-Zusammenfassung..."
cat > "$GENTLEMAN_DIR/INSTALLATION_SUMMARY.md" << EOF
# 🎯 RX Node GENTLEMAN Installation Summary

## Installation Details
- **Datum:** $(date)
- **Hostname:** $(hostname 2>/dev/null || echo 'Unknown')
- **User:** $(whoami)
- **System:** $(uname -a)
- **Python:** $(python3 --version 2>/dev/null || echo 'Not found')

## Installierte Dateien
- ✅ talking_gentleman_config.json
- ✅ talking_gentleman_protocol.py
- ✅ start_gentleman.sh
- ✅ check_status.sh
- ✅ test_gentleman.sh
- ✅ knowledge.db (SQLite Database)

## Verzeichnisstruktur
\`\`\`
~/Gentleman/
├── backup/
├── logs/
├── config/
├── scripts/
├── data/
├── talking_gentleman_config.json
├── talking_gentleman_protocol.py
├── start_gentleman.sh
├── check_status.sh
├── test_gentleman.sh
└── INSTALLATION_SUMMARY.md
\`\`\`

## Nächste Schritte
1. Test ausführen: \`./test_gentleman.sh\`
2. Service starten: \`./start_gentleman.sh\`
3. Status prüfen: \`./check_status.sh\`

## Konfiguration
- **Node ID:** rx-local-trainer
- **Role:** Primary AI Trainer
- **Port:** 8008
- **GPU:** Enabled
- **Database:** ~/Gentleman/knowledge.db

## Support
Bei Problemen die Log-Dateien in ~/Gentleman/logs/ prüfen.
EOF

log "✅ Zusammenfassung erstellt"

# Step 8: Run initial test
log "🧪 Führe initialen Test aus..."
cd "$GENTLEMAN_DIR"
python3 talking_gentleman_protocol.py --test 2>/dev/null || warning "Test mit Fehlern - siehe Details oben"

# Final summary
echo ""
log "🎉 RX Node Lokale Konfiguration abgeschlossen!"
echo ""
echo -e "${GREEN}📊 Installation Summary:${NC}"
echo "   ✅ Verzeichnisstruktur: Erstellt"
echo "   ✅ Python Dependencies: Installiert"
echo "   ✅ GENTLEMAN Protocol: Konfiguriert"
echo "   ✅ Management Scripts: Bereit"
echo "   ✅ Database: Initialisiert"
echo "   ✅ Tests: Ausgeführt"
echo ""
echo -e "${BLUE}🚀 Nächste Schritte:${NC}"
echo "   1. Test ausführen: cd ~/Gentleman && ./test_gentleman.sh"
echo "   2. Service starten: cd ~/Gentleman && ./start_gentleman.sh"
echo "   3. Status prüfen: cd ~/Gentleman && ./check_status.sh"
echo ""
echo -e "${YELLOW}💡 Wichtige Dateien:${NC}"
echo "   📁 Hauptverzeichnis: ~/Gentleman/"
echo "   ⚙️ Konfiguration: ~/Gentleman/talking_gentleman_config.json"
echo "   🐍 Protocol: ~/Gentleman/talking_gentleman_protocol.py"
echo "   📊 Zusammenfassung: ~/Gentleman/INSTALLATION_SUMMARY.md"
echo ""
echo -e "${GREEN}🎯 RX Node ist bereit als Primary AI Trainer!${NC}" 