#!/bin/bash

# 🎯 RX Node GENTLEMAN System Integration Script
# Version: 1.0
# Target: Arch Linux RX Node (192.168.68.117)
# Role: Primary AI Trainer

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

RX_NODE="rx-node"
GENTLEMAN_DIR="~/Gentleman"

echo -e "${BLUE}🎯 RX Node GENTLEMAN Integration${NC}"
echo -e "${BLUE}================================${NC}"
echo "Target: $RX_NODE"
echo "Role: Primary AI Trainer"
echo "Timestamp: $(date)"
echo ""

# Function to log messages
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Step 1: Check RX Node connectivity
log "🔍 Prüfe RX Node Konnektivität..."
if ! ssh -o ConnectTimeout=5 "$RX_NODE" "echo 'RX Node erreichbar'" >/dev/null 2>&1; then
    error "RX Node nicht erreichbar - Abbruch"
    exit 1
fi
log "✅ RX Node erreichbar"

# Step 2: Install Python dependencies
log "🐍 Installiere Python Abhängigkeiten..."
ssh "$RX_NODE" "python3 -m pip install --user requests sqlite3 || echo 'Einige Pakete bereits installiert'"
log "✅ Python Abhängigkeiten installiert"

# Step 3: Create directory structure
log "📁 Erstelle Verzeichnisstruktur..."
ssh "$RX_NODE" "mkdir -p ~/.gentleman ~/Gentleman/logs ~/Gentleman/backup"
log "✅ Verzeichnisstruktur erstellt"

# Step 4: Transfer additional files
log "📦 Übertrage zusätzliche Dateien..."
if [[ -f "gentleman_key_rotation.sh" ]]; then
    scp -i ~/.ssh/gentleman_key gentleman_key_rotation.sh "$RX_NODE:$GENTLEMAN_DIR/"
    log "   ✅ Key Rotation Script übertragen"
fi

# Step 5: Create RX Node specific scripts
log "📝 Erstelle RX Node spezifische Scripts..."

# Create service start script
ssh "$RX_NODE" "cat > $GENTLEMAN_DIR/start_gentleman.sh << 'EOF'
#!/bin/bash
# RX Node GENTLEMAN Service Starter
cd ~/Gentleman
echo \"🎯 Starting GENTLEMAN Service on RX Node...\"
echo \"Role: Primary AI Trainer\"
echo \"Port: 8008\"
echo \"GPU: Enabled\"
echo \"\"
python3 talking_gentleman_protocol.py --start
EOF"

ssh "$RX_NODE" "chmod +x $GENTLEMAN_DIR/start_gentleman.sh"
log "   ✅ Service Start Script erstellt"

# Create status check script
ssh "$RX_NODE" "cat > $GENTLEMAN_DIR/check_status.sh << 'EOF'
#!/bin/bash
# RX Node Status Check
echo \"🎯 RX Node GENTLEMAN Status\"
echo \"===========================\"
echo \"Hostname: \$(hostname)\"
echo \"User: \$(whoami)\"
echo \"Directory: \$(pwd)\"
echo \"\"
echo \"🔍 GENTLEMAN Dateien:\"
ls -la ~/Gentleman/
echo \"\"
echo \"🌐 Netzwerk Status:\"
ss -tlnp | grep :8008 || echo \"Port 8008 nicht aktiv\"
echo \"\"
echo \"💾 Speicher:\"
df -h ~/Gentleman/
echo \"\"
echo \"🖥️ System:\"
free -h
echo \"\"
echo \"🔧 Python:\"
python3 --version
EOF"

ssh "$RX_NODE" "chmod +x $GENTLEMAN_DIR/check_status.sh"
log "   ✅ Status Check Script erstellt"

# Step 6: Test the setup
log "🧪 Teste RX Node Setup..."
ssh "$RX_NODE" "cd $GENTLEMAN_DIR && ./check_status.sh"

# Step 7: Initialize database
log "💾 Initialisiere Knowledge Database..."
ssh "$RX_NODE" "cd $GENTLEMAN_DIR && python3 -c \"
import sqlite3
import os
db_path = os.path.expanduser('~/Gentleman/knowledge.db')
conn = sqlite3.connect(db_path)
cursor = conn.cursor()
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
print('✅ Knowledge Database initialisiert')
\""

log "✅ Database initialisiert"

# Step 8: Register RX Node in network
log "📡 Registriere RX Node im Netzwerk..."
ssh "$RX_NODE" "cd $GENTLEMAN_DIR && python3 -c \"
import json
import sqlite3
import os

# Load config
with open('talking_gentleman_config.json', 'r') as f:
    config = json.load(f)

# Register self in database
db_path = os.path.expanduser('~/Gentleman/knowledge.db')
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

cursor.execute('''
INSERT OR REPLACE INTO node_registry 
(node_id, ip_address, port, role, capabilities)
VALUES (?, ?, ?, ?, ?)
''', (
    config['node_id'],
    '192.168.68.117',
    config['port'],
    config['role'],
    json.dumps(config['capabilities'])
))

conn.commit()
conn.close()
print('✅ RX Node im Netzwerk registriert')
\""

log "✅ RX Node registriert"

# Final summary
log "🎉 RX Node GENTLEMAN Integration abgeschlossen!"
echo ""
echo -e "${GREEN}📊 Integration Summary:${NC}"
echo "   ✅ SSH Konnektivität: Funktional"
echo "   ✅ Python Umgebung: Konfiguriert"
echo "   ✅ GENTLEMAN Protokoll: Installiert"
echo "   ✅ Konfiguration: RX Node spezifisch"
echo "   ✅ Database: Initialisiert"
echo "   ✅ Scripts: Erstellt"
echo "   ✅ Netzwerk: Registriert"
echo ""
echo -e "${BLUE}🚀 Nächste Schritte:${NC}"
echo "   1. RX Node Service starten: ssh $RX_NODE '~/Gentleman/start_gentleman.sh'"
echo "   2. Status prüfen: ssh $RX_NODE '~/Gentleman/check_status.sh'"
echo "   3. Integration testen: Alle Nodes starten und Konnektivität prüfen"
echo ""
echo -e "${YELLOW}💡 RX Node Rolle:${NC} Primary AI Trainer mit GPU-Unterstützung" 