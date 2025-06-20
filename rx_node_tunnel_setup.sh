#!/bin/bash

# GENTLEMAN RX Node Tunnel Setup
# Richtet einen Cloudflare Tunnel für die RX Node ein

set -euo pipefail

# Konfiguration
SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# RX Node Konfiguration
RX_NODE_IP="192.168.68.117"
RX_NODE_USER="amo9n11"
SSH_KEY_PATH="$HOME/.ssh/gentleman_key"
TUNNEL_PORT="8765"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging Funktionen
log() {
    echo -e "${LOG_PREFIX} $1"
}

log_success() {
    echo -e "${LOG_PREFIX} ${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${LOG_PREFIX} ${RED}❌ $1${NC}" >&2
}

log_warning() {
    echo -e "${LOG_PREFIX} ${YELLOW}⚠️ $1${NC}"
}

log_info() {
    echo -e "${LOG_PREFIX} ${BLUE}ℹ️ $1${NC}"
}

# Teste SSH-Verbindung zur RX Node
test_rx_node_connection() {
    log_info "🔗 Teste SSH-Verbindung zur RX Node..."
    
    if ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=5 "$RX_NODE_USER@$RX_NODE_IP" "echo 'SSH Test erfolgreich'" >/dev/null 2>&1; then
        log_success "SSH-Verbindung zur RX Node funktioniert"
        return 0
    else
        log_error "SSH-Verbindung zur RX Node fehlgeschlagen"
        log_info "Stelle sicher, dass SSH-Setup abgeschlossen ist: ./setup_rx_node_ssh.sh"
        return 1
    fi
}

# Erstelle RX Node Tunnel Server
create_rx_node_server() {
    log_info "🐍 Erstelle RX Node Tunnel Server..."
    
    # Erstelle Python Server für RX Node
    cat > /tmp/rx_node_tunnel_server.py << 'EOF'
#!/usr/bin/env python3

import http.server
import socketserver
import json
import subprocess
import logging
import os
import signal
import sys
from datetime import datetime
from urllib.parse import urlparse, parse_qs

# Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/rx_node_tunnel.log'),
        logging.StreamHandler()
    ]
)

class RXNodeTunnelHandler(http.server.BaseHTTPRequestHandler):
    
    def do_GET(self):
        parsed_url = urlparse(self.path)
        
        if parsed_url.path == '/health':
            self.handle_health_check()
        elif parsed_url.path == '/status':
            self.handle_status_check()
        elif parsed_url.path == '/info':
            self.handle_info_request()
        else:
            self.send_error(404, "Endpoint not found")
    
    def do_POST(self):
        parsed_url = urlparse(self.path)
        
        if parsed_url.path == '/shutdown':
            self.handle_shutdown_request()
        elif parsed_url.path == '/reboot':
            self.handle_reboot_request()
        else:
            self.send_error(404, "Endpoint not found")
    
    def handle_health_check(self):
        """Health Check Endpoint"""
        try:
            response = {
                "status": "healthy",
                "timestamp": datetime.now().timestamp(),
                "server": "RX Node Tunnel Server",
                "version": "1.0.0",
                "node": "rx-node"
            }
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            self.wfile.write(json.dumps(response, indent=2).encode())
            logging.info(f"🌐 {self.client_address[0]} - Health Check OK")
            
        except Exception as e:
            logging.error(f"❌ Health Check Fehler: {e}")
            self.send_error(500, f"Health Check Error: {e}")
    
    def handle_status_check(self):
        """System Status Check"""
        try:
            # System-Informationen sammeln
            hostname = subprocess.check_output(['hostname'], text=True).strip()
            uptime = subprocess.check_output(['uptime'], text=True).strip()
            
            # Memory Info
            memory_info = subprocess.check_output(['free', '-h'], text=True)
            
            # Disk Info
            disk_info = subprocess.check_output(['df', '-h', '/'], text=True)
            
            response = {
                "status": "online",
                "hostname": hostname,
                "uptime": uptime,
                "memory": memory_info,
                "disk": disk_info,
                "timestamp": datetime.now().timestamp()
            }
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            self.wfile.write(json.dumps(response, indent=2).encode())
            logging.info(f"📊 Status-Anfrage von {self.client_address[0]}")
            
        except Exception as e:
            logging.error(f"❌ Status Check Fehler: {e}")
            self.send_error(500, f"Status Check Error: {e}")
    
    def handle_info_request(self):
        """Detaillierte System-Informationen"""
        try:
            # Netzwerk-Informationen
            ip_info = subprocess.check_output(['ip', 'addr', 'show'], text=True)
            
            # Service-Status
            services = ['sshd', 'NetworkManager']
            service_status = {}
            
            for service in services:
                try:
                    status = subprocess.check_output(['systemctl', 'is-active', service], text=True).strip()
                    service_status[service] = status
                except:
                    service_status[service] = "unknown"
            
            response = {
                "network": ip_info,
                "services": service_status,
                "timestamp": datetime.now().timestamp()
            }
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            self.wfile.write(json.dumps(response, indent=2).encode())
            logging.info(f"📋 Info-Anfrage von {self.client_address[0]}")
            
        except Exception as e:
            logging.error(f"❌ Info Request Fehler: {e}")
            self.send_error(500, f"Info Request Error: {e}")
    
    def handle_shutdown_request(self):
        """Remote Shutdown Request"""
        try:
            # Lese Request Body
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            # Parse JSON
            request_data = json.loads(post_data.decode('utf-8')) if content_length > 0 else {}
            
            source = request_data.get('source', 'unknown')
            delay_minutes = request_data.get('delay_minutes', 1)
            
            logging.info(f"🎯 Shutdown-Anfrage von: {source}")
            logging.info(f"⏰ Shutdown in {delay_minutes} Minuten")
            
            # Führe Shutdown aus
            shutdown_cmd = f"sudo shutdown -h +{delay_minutes}"
            result = subprocess.run(shutdown_cmd.split(), capture_output=True, text=True)
            
            if result.returncode == 0:
                response = {
                    "status": "success",
                    "message": f"Shutdown in {delay_minutes} Minuten eingeleitet",
                    "source": source,
                    "timestamp": datetime.now().timestamp()
                }
                
                self.send_response(200)
                logging.info(f"✅ Shutdown erfolgreich eingeleitet")
            else:
                response = {
                    "status": "error",
                    "message": "Shutdown fehlgeschlagen",
                    "error": result.stderr,
                    "timestamp": datetime.now().timestamp()
                }
                
                self.send_response(500)
                logging.error(f"❌ Shutdown fehlgeschlagen: {result.stderr}")
            
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            self.wfile.write(json.dumps(response, indent=2).encode())
            
        except Exception as e:
            logging.error(f"❌ Shutdown Handler Fehler: {e}")
            self.send_error(500, f"Shutdown Error: {e}")
    
    def handle_reboot_request(self):
        """Remote Reboot Request"""
        try:
            # Lese Request Body
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            # Parse JSON
            request_data = json.loads(post_data.decode('utf-8')) if content_length > 0 else {}
            
            source = request_data.get('source', 'unknown')
            delay_minutes = request_data.get('delay_minutes', 1)
            
            logging.info(f"🔄 Reboot-Anfrage von: {source}")
            
            # Führe Reboot aus
            reboot_cmd = f"sudo reboot"
            result = subprocess.run(reboot_cmd.split(), capture_output=True, text=True)
            
            response = {
                "status": "success",
                "message": "Reboot eingeleitet",
                "source": source,
                "timestamp": datetime.now().timestamp()
            }
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            self.wfile.write(json.dumps(response, indent=2).encode())
            
            logging.info(f"✅ Reboot erfolgreich eingeleitet")
            
        except Exception as e:
            logging.error(f"❌ Reboot Handler Fehler: {e}")
            self.send_error(500, f"Reboot Error: {e}")
    
    def log_message(self, format, *args):
        # Verhindere doppelte Logs
        pass

def signal_handler(sig, frame):
    logging.info("🛑 RX Node Tunnel Server wird beendet...")
    sys.exit(0)

def main():
    PORT = 8765
    
    # Signal Handler
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        with socketserver.TCPServer(("0.0.0.0", PORT), RXNodeTunnelHandler) as httpd:
            logging.info(f"🚀 RX Node Tunnel Server gestartet auf 0.0.0.0:{PORT}")
            logging.info(f"📡 Endpoints verfügbar:")
            logging.info(f"   GET  /health    - Health Check")
            logging.info(f"   GET  /status    - System Status")
            logging.info(f"   GET  /info      - Detaillierte Informationen")
            logging.info(f"   POST /shutdown  - Remote Shutdown")
            logging.info(f"   POST /reboot    - Remote Reboot")
            
            httpd.serve_forever()
            
    except Exception as e:
        logging.error(f"❌ Server Fehler: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

    log_success "RX Node Tunnel Server erstellt"
}

# Kopiere Server zur RX Node
deploy_server_to_rx_node() {
    log_info "📤 Kopiere Server zur RX Node..."
    
    # Kopiere Python Server
    if scp -i "$SSH_KEY_PATH" /tmp/rx_node_tunnel_server.py "$RX_NODE_USER@$RX_NODE_IP:/tmp/"; then
        log_success "Server erfolgreich zur RX Node kopiert"
    else
        log_error "Server-Kopierung fehlgeschlagen"
        return 1
    fi
    
    # Mache Server ausführbar
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "chmod +x /tmp/rx_node_tunnel_server.py"
    
    log_success "Server auf RX Node bereit"
}

# Installiere Cloudflared auf RX Node
install_cloudflared_on_rx_node() {
    log_info "☁️ Installiere Cloudflared auf RX Node..."
    
    # Installationskommandos
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" << 'EOF'
# Prüfe ob cloudflared bereits installiert ist
if command -v cloudflared > /dev/null 2>&1; then
    echo "Cloudflared bereits installiert"
    cloudflared --version
    exit 0
fi

# Installiere cloudflared
echo "Installiere cloudflared..."
cd /tmp

# Download für Linux AMD64
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64

# Mache ausführbar
chmod +x cloudflared-linux-amd64

# Verschiebe zu /usr/local/bin
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

# Teste Installation
cloudflared --version
echo "Cloudflared erfolgreich installiert"
EOF

    if [ $? -eq 0 ]; then
        log_success "Cloudflared auf RX Node installiert"
    else
        log_error "Cloudflared Installation fehlgeschlagen"
        return 1
    fi
}

# Erstelle Tunnel-Manager für RX Node
create_rx_tunnel_manager() {
    log_info "🔧 Erstelle Tunnel-Manager für RX Node..."
    
    # Erstelle Tunnel-Manager Script
    cat > /tmp/rx_tunnel_manager.sh << 'EOF'
#!/bin/bash

# RX Node Tunnel Manager
# Verwaltet Cloudflare Tunnel für RX Node

set -euo pipefail

LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"
TUNNEL_PORT="8765"
TUNNEL_LOG="/tmp/rx_tunnel.log"
SERVER_LOG="/tmp/rx_node_tunnel.log"
TUNNEL_PID_FILE="/tmp/rx_tunnel.pid"
SERVER_PID_FILE="/tmp/rx_server.pid"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${LOG_PREFIX} $1"
}

log_success() {
    echo -e "${LOG_PREFIX} ${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${LOG_PREFIX} ${RED}❌ $1${NC}" >&2
}

log_info() {
    echo -e "${LOG_PREFIX} ${BLUE}ℹ️ $1${NC}"
}

# Starte RX Node Server
start_server() {
    log_info "🐍 Starte RX Node Tunnel Server..."
    
    if [ -f "$SERVER_PID_FILE" ]; then
        local pid=$(cat "$SERVER_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Server läuft bereits (PID: $pid)"
            return 0
        fi
    fi
    
    # Starte Server im Hintergrund
    nohup python3 /tmp/rx_node_tunnel_server.py > "$SERVER_LOG" 2>&1 &
    local server_pid=$!
    echo "$server_pid" > "$SERVER_PID_FILE"
    
    # Warte kurz und prüfe ob Server läuft
    sleep 3
    if kill -0 "$server_pid" 2>/dev/null; then
        log_success "RX Node Server gestartet (PID: $server_pid)"
        return 0
    else
        log_error "RX Node Server konnte nicht gestartet werden"
        return 1
    fi
}

# Starte Cloudflare Tunnel
start_tunnel() {
    log_info "☁️ Starte Cloudflare Tunnel..."
    
    if [ -f "$TUNNEL_PID_FILE" ]; then
        local pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Tunnel läuft bereits (PID: $pid)"
            return 0
        fi
    fi
    
    # Starte Tunnel im Hintergrund
    nohup cloudflared tunnel --url "http://localhost:$TUNNEL_PORT" > "$TUNNEL_LOG" 2>&1 &
    local tunnel_pid=$!
    echo "$tunnel_pid" > "$TUNNEL_PID_FILE"
    
    # Warte auf Tunnel-URL
    log_info "⏳ Warte auf Tunnel-Initialisierung..."
    sleep 10
    
    if kill -0 "$tunnel_pid" 2>/dev/null; then
        # Extrahiere Tunnel-URL
        local tunnel_url=$(grep -o 'https://.*\.trycloudflare\.com' "$TUNNEL_LOG" | head -1 || echo "URL nicht gefunden")
        log_success "Cloudflare Tunnel gestartet (PID: $tunnel_pid)"
        log_success "Tunnel-URL: $tunnel_url"
        
        # Speichere URL
        echo "$tunnel_url" > /tmp/rx_tunnel_url.txt
        return 0
    else
        log_error "Cloudflare Tunnel konnte nicht gestartet werden"
        return 1
    fi
}

# Stoppe Services
stop_services() {
    log_info "🛑 Stoppe RX Node Tunnel Services..."
    
    # Stoppe Tunnel
    if [ -f "$TUNNEL_PID_FILE" ]; then
        local pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_success "Tunnel gestoppt"
        fi
        rm -f "$TUNNEL_PID_FILE"
    fi
    
    # Stoppe Server
    if [ -f "$SERVER_PID_FILE" ]; then
        local pid=$(cat "$SERVER_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_success "Server gestoppt"
        fi
        rm -f "$SERVER_PID_FILE"
    fi
}

# Status prüfen
check_status() {
    echo "🎯 RX Node Tunnel Status"
    echo "========================"
    
    # Server Status
    if [ -f "$SERVER_PID_FILE" ]; then
        local server_pid=$(cat "$SERVER_PID_FILE")
        if kill -0 "$server_pid" 2>/dev/null; then
            echo -e "Server: ${GREEN}✅ Läuft${NC} (PID: $server_pid)"
        else
            echo -e "Server: ${RED}❌ Gestoppt${NC}"
        fi
    else
        echo -e "Server: ${RED}❌ Nicht gestartet${NC}"
    fi
    
    # Tunnel Status
    if [ -f "$TUNNEL_PID_FILE" ]; then
        local tunnel_pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$tunnel_pid" 2>/dev/null; then
            echo -e "Tunnel: ${GREEN}✅ Läuft${NC} (PID: $tunnel_pid)"
            
            # Tunnel URL anzeigen
            if [ -f "/tmp/rx_tunnel_url.txt" ]; then
                local url=$(cat /tmp/rx_tunnel_url.txt)
                echo "URL: $url"
            fi
        else
            echo -e "Tunnel: ${RED}❌ Gestoppt${NC}"
        fi
    else
        echo -e "Tunnel: ${RED}❌ Nicht gestartet${NC}"
    fi
    
    # System Info
    echo ""
    echo "System: $(hostname)"
    echo "Uptime: $(uptime -p)"
}

# Zeige Logs
show_logs() {
    local service="$1"
    
    case "$service" in
        "server")
            if [ -f "$SERVER_LOG" ]; then
                tail -f "$SERVER_LOG"
            else
                log_error "Server-Log nicht gefunden"
            fi
            ;;
        "tunnel")
            if [ -f "$TUNNEL_LOG" ]; then
                tail -f "$TUNNEL_LOG"
            else
                log_error "Tunnel-Log nicht gefunden"
            fi
            ;;
        *)
            echo "Verfügbare Logs: server, tunnel"
            ;;
    esac
}

# Hauptfunktion
main() {
    case "${1:-}" in
        "start")
            start_server
            start_tunnel
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            stop_services
            sleep 2
            start_server
            start_tunnel
            ;;
        "status")
            check_status
            ;;
        "logs")
            show_logs "${2:-}"
            ;;
        "url")
            if [ -f "/tmp/rx_tunnel_url.txt" ]; then
                cat /tmp/rx_tunnel_url.txt
            else
                echo "Tunnel-URL nicht verfügbar"
            fi
            ;;
        *)
            echo "RX Node Tunnel Manager"
            echo "====================="
            echo "Verwendung: $0 {start|stop|restart|status|logs|url}"
            echo ""
            echo "Kommandos:"
            echo "  start    - Starte Server und Tunnel"
            echo "  stop     - Stoppe alle Services"
            echo "  restart  - Neustart aller Services"
            echo "  status   - Zeige Status"
            echo "  logs     - Zeige Logs (server|tunnel)"
            echo "  url      - Zeige Tunnel-URL"
            ;;
    esac
}

main "$@"
EOF

    # Kopiere Tunnel-Manager zur RX Node
    if scp -i "$SSH_KEY_PATH" /tmp/rx_tunnel_manager.sh "$RX_NODE_USER@$RX_NODE_IP:/tmp/"; then
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "chmod +x /tmp/rx_tunnel_manager.sh"
        log_success "Tunnel-Manager zur RX Node kopiert"
    else
        log_error "Tunnel-Manager Kopierung fehlgeschlagen"
        return 1
    fi
}

# Starte RX Node Tunnel
start_rx_tunnel() {
    log_info "🚀 Starte RX Node Tunnel..."
    
    # Starte Tunnel auf RX Node
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh start"
    
    # Warte kurz
    sleep 5
    
    # Hole Tunnel-URL
    local tunnel_url
    tunnel_url=$(ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh url" 2>/dev/null || echo "")
    
    if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
        log_success "RX Node Tunnel gestartet!"
        log_success "Tunnel-URL: $tunnel_url"
        
        # Speichere URL lokal
        echo "$tunnel_url" > /tmp/rx_node_tunnel_url.txt
        
        return 0
    else
        log_warning "Tunnel gestartet, aber URL noch nicht verfügbar"
        log_info "Prüfe Status mit: ssh rx-node '/tmp/rx_tunnel_manager.sh status'"
        return 1
    fi
}

# Teste RX Node Tunnel
test_rx_tunnel() {
    log_info "🧪 Teste RX Node Tunnel..."
    
    # Hole Tunnel-URL
    local tunnel_url
    if [ -f "/tmp/rx_node_tunnel_url.txt" ]; then
        tunnel_url=$(cat /tmp/rx_node_tunnel_url.txt)
    else
        tunnel_url=$(ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh url" 2>/dev/null || echo "")
    fi
    
    if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
        log_info "Teste Health-Check über Tunnel..."
        
        # Teste Health-Check
        if curl -s --max-time 10 "$tunnel_url/health" | jq . >/dev/null 2>&1; then
            log_success "RX Node Tunnel funktioniert!"
            log_success "Health-Check: $tunnel_url/health"
            log_success "Status: $tunnel_url/status"
            return 0
        else
            log_warning "Tunnel erreichbar, aber Health-Check fehlgeschlagen"
            return 1
        fi
    else
        log_error "Tunnel-URL nicht verfügbar"
        return 1
    fi
}

# Erstelle lokales RX Node Tunnel Control Script
create_local_control_script() {
    log_info "📝 Erstelle lokales RX Node Tunnel Control Script..."
    
    cat > ./rx_node_tunnel_control.sh << 'EOF'
#!/bin/bash

# GENTLEMAN RX Node Tunnel Control
# Steuert die RX Node über ihren eigenen Tunnel

set -euo pipefail

# Konfiguration
RX_NODE_IP="192.168.68.117"
RX_NODE_USER="amo9n11"
SSH_KEY_PATH="$HOME/.ssh/gentleman_key"
TUNNEL_URL_FILE="/tmp/rx_node_tunnel_url.txt"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

# Hole Tunnel-URL
get_tunnel_url() {
    local tunnel_url=""
    
    # Versuche lokale Datei
    if [ -f "$TUNNEL_URL_FILE" ]; then
        tunnel_url=$(cat "$TUNNEL_URL_FILE" 2>/dev/null || echo "")
    fi
    
    # Versuche SSH zur RX Node
    if [[ -z "$tunnel_url" || "$tunnel_url" == "Tunnel-URL nicht verfügbar" ]]; then
        tunnel_url=$(ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh url" 2>/dev/null || echo "")
    fi
    
    echo "$tunnel_url"
}

# Prüfe Netzwerk-Modus
detect_network_mode() {
    local current_ip
    current_ip=$(ifconfig | grep -E "(192\.168\.68\.|172\.20\.10\.)" | head -1 | awk '{print $2}' || echo "")
    
    if [[ "$current_ip" =~ ^192\.168\.68\. ]]; then
        echo "home"
    elif [[ "$current_ip" =~ ^172\.20\.10\. ]]; then
        echo "hotspot"
    else
        echo "unknown"
    fi
}

# RX Node Status
rx_status() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🎯 RX Node Status (Netzwerk: $network_mode)"
    
    if [ "$network_mode" == "home" ]; then
        # Heimnetzwerk - SSH verwenden
        log_info "📡 Verwende SSH-Verbindung..."
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh status"
    else
        # Hotspot - Tunnel verwenden
        local tunnel_url
        tunnel_url=$(get_tunnel_url)
        
        if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
            log_info "☁️ Verwende Tunnel: $tunnel_url"
            
            # Status über Tunnel
            local response
            response=$(curl -s --max-time 10 "$tunnel_url/status" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                echo "🎯 RX Node Status (über Tunnel)"
                echo "==============================="
                echo "$response" | jq -r '.hostname // "N/A"' | sed 's/^/Hostname: /'
                echo "$response" | jq -r '.uptime // "N/A"' | sed 's/^/Uptime: /'
                log_success "RX Node online über Tunnel"
            else
                log_error "Status-Abfrage über Tunnel fehlgeschlagen"
            fi
        else
            log_error "Tunnel-URL nicht verfügbar"
        fi
    fi
}

# RX Node Shutdown
rx_shutdown() {
    local delay_minutes="${1:-1}"
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🎯 RX Node Shutdown (Netzwerk: $network_mode, Delay: ${delay_minutes}m)"
    
    if [ "$network_mode" == "home" ]; then
        # Heimnetzwerk - SSH verwenden
        log_info "📡 Verwende SSH-Verbindung..."
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "sudo shutdown -h +$delay_minutes"
        log_success "Shutdown-Befehl über SSH gesendet"
    else
        # Hotspot - Tunnel verwenden
        local tunnel_url
        tunnel_url=$(get_tunnel_url)
        
        if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
            log_info "☁️ Verwende Tunnel: $tunnel_url"
            
            # Shutdown über Tunnel
            local response
            response=$(curl -s --max-time 10 -X POST "$tunnel_url/shutdown" \
                -H "Content-Type: application/json" \
                -d "{\"source\": \"Tunnel Control\", \"delay_minutes\": $delay_minutes}" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                local status
                status=$(echo "$response" | jq -r '.status // "unknown"')
                
                if [ "$status" == "success" ]; then
                    log_success "RX Node Shutdown über Tunnel eingeleitet"
                else
                    log_error "Shutdown über Tunnel fehlgeschlagen"
                fi
            else
                log_error "Shutdown-Anfrage über Tunnel fehlgeschlagen"
            fi
        else
            log_error "Tunnel-URL nicht verfügbar"
        fi
    fi
}

# RX Node Tunnel Management
rx_tunnel() {
    local action="$1"
    
    case "$action" in
        "start")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh start"
            ;;
        "stop")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh stop"
            ;;
        "restart")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh restart"
            ;;
        "url")
            local tunnel_url
            tunnel_url=$(get_tunnel_url)
            if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
                echo "$tunnel_url"
            else
                echo "Tunnel-URL nicht verfügbar"
            fi
            ;;
        *)
            echo "Tunnel-Aktionen: start|stop|restart|url"
            ;;
    esac
}

# Hauptfunktion
main() {
    case "${1:-}" in
        "status")
            rx_status
            ;;
        "shutdown")
            rx_shutdown "${2:-1}"
            ;;
        "tunnel")
            rx_tunnel "${2:-status}"
            ;;
        *)
            echo -e "${PURPLE}🎯 GENTLEMAN RX Node Tunnel Control${NC}"
            echo "===================================="
            echo ""
            echo "Kommandos:"
            echo "  status                    - RX Node Status prüfen"
            echo "  shutdown [delay_minutes]  - RX Node herunterfahren"
            echo "  tunnel {start|stop|restart|url} - Tunnel verwalten"
            echo ""
            echo "Beispiele:"
            echo "  $0 status"
            echo "  $0 shutdown 5"
            echo "  $0 tunnel url"
            ;;
    esac
}

main "$@"
EOF

    chmod +x ./rx_node_tunnel_control.sh
    log_success "Lokales RX Node Tunnel Control Script erstellt"
}

# Zeige Zusammenfassung
show_summary() {
    echo ""
    echo -e "${PURPLE}🎯 GENTLEMAN RX Node Tunnel Setup - Zusammenfassung${NC}"
    echo "=================================================="
    echo ""
    
    echo -e "${CYAN}RX Node Tunnel System:${NC}"
    echo "• Eigener Cloudflare Tunnel für RX Node"
    echo "• Python-basierter Tunnel Server (Port 8765)"
    echo "• Automatisches Tunnel-Management"
    echo "• Lokale und Remote-Steuerung"
    echo ""
    
    echo -e "${CYAN}Verfügbare Kommandos:${NC}"
    echo "• Lokale Steuerung: ./rx_node_tunnel_control.sh status"
    echo "• SSH zur RX Node: ssh rx-node '/tmp/rx_tunnel_manager.sh status'"
    echo "• Tunnel-URL: ./rx_node_tunnel_control.sh tunnel url"
    echo ""
    
    echo -e "${CYAN}API-Endpoints (über Tunnel):${NC}"
    if [ -f "/tmp/rx_node_tunnel_url.txt" ]; then
        local tunnel_url
        tunnel_url=$(cat /tmp/rx_node_tunnel_url.txt)
        echo "• Health Check: $tunnel_url/health"
        echo "• System Status: $tunnel_url/status"
        echo "• Shutdown: POST $tunnel_url/shutdown"
        echo "• Reboot: POST $tunnel_url/reboot"
    else
        echo "• Tunnel-URL wird nach dem Start verfügbar sein"
    fi
    echo ""
    
    echo -e "${YELLOW}💡 Nächste Schritte:${NC}"
    echo "1. Teste RX Node Tunnel: ./rx_node_tunnel_control.sh status"
    echo "2. Wechsle zum Hotspot und teste Remote-Zugriff"
    echo "3. Teste Shutdown über Tunnel: ./rx_node_tunnel_control.sh shutdown 1"
    echo ""
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN RX Node Tunnel Setup${NC}"
    echo "=================================="
    echo ""
    
    log_info "Starte RX Node Tunnel Setup..."
    
    # Setup-Schritte
    if ! test_rx_node_connection; then
        exit 1
    fi
    
    create_rx_node_server
    deploy_server_to_rx_node
    install_cloudflared_on_rx_node
    create_rx_tunnel_manager
    start_rx_tunnel
    
    # Warte kurz für Tunnel-Initialisierung
    sleep 5
    
    if test_rx_tunnel; then
        create_local_control_script
        
        echo ""
        log_success "🎉 RX Node Tunnel Setup erfolgreich abgeschlossen!"
        
        show_summary
    else
        log_warning "Setup abgeschlossen, aber Tunnel-Test fehlgeschlagen"
        log_info "Prüfe manuell: ssh rx-node '/tmp/rx_tunnel_manager.sh status'"
    fi
}

# Führe Hauptfunktion aus
main "$@"

# GENTLEMAN RX Node Tunnel Setup
# Richtet einen Cloudflare Tunnel für die RX Node ein

set -euo pipefail

# Konfiguration
SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# RX Node Konfiguration
RX_NODE_IP="192.168.68.117"
RX_NODE_USER="amo9n11"
SSH_KEY_PATH="$HOME/.ssh/gentleman_key"
TUNNEL_PORT="8765"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging Funktionen
log() {
    echo -e "${LOG_PREFIX} $1"
}

log_success() {
    echo -e "${LOG_PREFIX} ${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${LOG_PREFIX} ${RED}❌ $1${NC}" >&2
}

log_warning() {
    echo -e "${LOG_PREFIX} ${YELLOW}⚠️ $1${NC}"
}

log_info() {
    echo -e "${LOG_PREFIX} ${BLUE}ℹ️ $1${NC}"
}

# Teste SSH-Verbindung zur RX Node
test_rx_node_connection() {
    log_info "🔗 Teste SSH-Verbindung zur RX Node..."
    
    if ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=5 "$RX_NODE_USER@$RX_NODE_IP" "echo 'SSH Test erfolgreich'" >/dev/null 2>&1; then
        log_success "SSH-Verbindung zur RX Node funktioniert"
        return 0
    else
        log_error "SSH-Verbindung zur RX Node fehlgeschlagen"
        log_info "Stelle sicher, dass SSH-Setup abgeschlossen ist: ./setup_rx_node_ssh.sh"
        return 1
    fi
}

# Erstelle RX Node Tunnel Server
create_rx_node_server() {
    log_info "🐍 Erstelle RX Node Tunnel Server..."
    
    # Erstelle Python Server für RX Node
    cat > /tmp/rx_node_tunnel_server.py << 'EOF'
#!/usr/bin/env python3

import http.server
import socketserver
import json
import subprocess
import logging
import os
import signal
import sys
from datetime import datetime
from urllib.parse import urlparse, parse_qs

# Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/rx_node_tunnel.log'),
        logging.StreamHandler()
    ]
)

class RXNodeTunnelHandler(http.server.BaseHTTPRequestHandler):
    
    def do_GET(self):
        parsed_url = urlparse(self.path)
        
        if parsed_url.path == '/health':
            self.handle_health_check()
        elif parsed_url.path == '/status':
            self.handle_status_check()
        elif parsed_url.path == '/info':
            self.handle_info_request()
        else:
            self.send_error(404, "Endpoint not found")
    
    def do_POST(self):
        parsed_url = urlparse(self.path)
        
        if parsed_url.path == '/shutdown':
            self.handle_shutdown_request()
        elif parsed_url.path == '/reboot':
            self.handle_reboot_request()
        else:
            self.send_error(404, "Endpoint not found")
    
    def handle_health_check(self):
        """Health Check Endpoint"""
        try:
            response = {
                "status": "healthy",
                "timestamp": datetime.now().timestamp(),
                "server": "RX Node Tunnel Server",
                "version": "1.0.0",
                "node": "rx-node"
            }
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            self.wfile.write(json.dumps(response, indent=2).encode())
            logging.info(f"🌐 {self.client_address[0]} - Health Check OK")
            
        except Exception as e:
            logging.error(f"❌ Health Check Fehler: {e}")
            self.send_error(500, f"Health Check Error: {e}")
    
    def handle_status_check(self):
        """System Status Check"""
        try:
            # System-Informationen sammeln
            hostname = subprocess.check_output(['hostname'], text=True).strip()
            uptime = subprocess.check_output(['uptime'], text=True).strip()
            
            # Memory Info
            memory_info = subprocess.check_output(['free', '-h'], text=True)
            
            # Disk Info
            disk_info = subprocess.check_output(['df', '-h', '/'], text=True)
            
            response = {
                "status": "online",
                "hostname": hostname,
                "uptime": uptime,
                "memory": memory_info,
                "disk": disk_info,
                "timestamp": datetime.now().timestamp()
            }
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            self.wfile.write(json.dumps(response, indent=2).encode())
            logging.info(f"📊 Status-Anfrage von {self.client_address[0]}")
            
        except Exception as e:
            logging.error(f"❌ Status Check Fehler: {e}")
            self.send_error(500, f"Status Check Error: {e}")
    
    def handle_info_request(self):
        """Detaillierte System-Informationen"""
        try:
            # Netzwerk-Informationen
            ip_info = subprocess.check_output(['ip', 'addr', 'show'], text=True)
            
            # Service-Status
            services = ['sshd', 'NetworkManager']
            service_status = {}
            
            for service in services:
                try:
                    status = subprocess.check_output(['systemctl', 'is-active', service], text=True).strip()
                    service_status[service] = status
                except:
                    service_status[service] = "unknown"
            
            response = {
                "network": ip_info,
                "services": service_status,
                "timestamp": datetime.now().timestamp()
            }
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            self.wfile.write(json.dumps(response, indent=2).encode())
            logging.info(f"📋 Info-Anfrage von {self.client_address[0]}")
            
        except Exception as e:
            logging.error(f"❌ Info Request Fehler: {e}")
            self.send_error(500, f"Info Request Error: {e}")
    
    def handle_shutdown_request(self):
        """Remote Shutdown Request"""
        try:
            # Lese Request Body
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            # Parse JSON
            request_data = json.loads(post_data.decode('utf-8')) if content_length > 0 else {}
            
            source = request_data.get('source', 'unknown')
            delay_minutes = request_data.get('delay_minutes', 1)
            
            logging.info(f"🎯 Shutdown-Anfrage von: {source}")
            logging.info(f"⏰ Shutdown in {delay_minutes} Minuten")
            
            # Führe Shutdown aus
            shutdown_cmd = f"sudo shutdown -h +{delay_minutes}"
            result = subprocess.run(shutdown_cmd.split(), capture_output=True, text=True)
            
            if result.returncode == 0:
                response = {
                    "status": "success",
                    "message": f"Shutdown in {delay_minutes} Minuten eingeleitet",
                    "source": source,
                    "timestamp": datetime.now().timestamp()
                }
                
                self.send_response(200)
                logging.info(f"✅ Shutdown erfolgreich eingeleitet")
            else:
                response = {
                    "status": "error",
                    "message": "Shutdown fehlgeschlagen",
                    "error": result.stderr,
                    "timestamp": datetime.now().timestamp()
                }
                
                self.send_response(500)
                logging.error(f"❌ Shutdown fehlgeschlagen: {result.stderr}")
            
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            self.wfile.write(json.dumps(response, indent=2).encode())
            
        except Exception as e:
            logging.error(f"❌ Shutdown Handler Fehler: {e}")
            self.send_error(500, f"Shutdown Error: {e}")
    
    def handle_reboot_request(self):
        """Remote Reboot Request"""
        try:
            # Lese Request Body
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            # Parse JSON
            request_data = json.loads(post_data.decode('utf-8')) if content_length > 0 else {}
            
            source = request_data.get('source', 'unknown')
            delay_minutes = request_data.get('delay_minutes', 1)
            
            logging.info(f"🔄 Reboot-Anfrage von: {source}")
            
            # Führe Reboot aus
            reboot_cmd = f"sudo reboot"
            result = subprocess.run(reboot_cmd.split(), capture_output=True, text=True)
            
            response = {
                "status": "success",
                "message": "Reboot eingeleitet",
                "source": source,
                "timestamp": datetime.now().timestamp()
            }
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            self.wfile.write(json.dumps(response, indent=2).encode())
            
            logging.info(f"✅ Reboot erfolgreich eingeleitet")
            
        except Exception as e:
            logging.error(f"❌ Reboot Handler Fehler: {e}")
            self.send_error(500, f"Reboot Error: {e}")
    
    def log_message(self, format, *args):
        # Verhindere doppelte Logs
        pass

def signal_handler(sig, frame):
    logging.info("🛑 RX Node Tunnel Server wird beendet...")
    sys.exit(0)

def main():
    PORT = 8765
    
    # Signal Handler
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        with socketserver.TCPServer(("0.0.0.0", PORT), RXNodeTunnelHandler) as httpd:
            logging.info(f"🚀 RX Node Tunnel Server gestartet auf 0.0.0.0:{PORT}")
            logging.info(f"📡 Endpoints verfügbar:")
            logging.info(f"   GET  /health    - Health Check")
            logging.info(f"   GET  /status    - System Status")
            logging.info(f"   GET  /info      - Detaillierte Informationen")
            logging.info(f"   POST /shutdown  - Remote Shutdown")
            logging.info(f"   POST /reboot    - Remote Reboot")
            
            httpd.serve_forever()
            
    except Exception as e:
        logging.error(f"❌ Server Fehler: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

    log_success "RX Node Tunnel Server erstellt"
}

# Kopiere Server zur RX Node
deploy_server_to_rx_node() {
    log_info "📤 Kopiere Server zur RX Node..."
    
    # Kopiere Python Server
    if scp -i "$SSH_KEY_PATH" /tmp/rx_node_tunnel_server.py "$RX_NODE_USER@$RX_NODE_IP:/tmp/"; then
        log_success "Server erfolgreich zur RX Node kopiert"
    else
        log_error "Server-Kopierung fehlgeschlagen"
        return 1
    fi
    
    # Mache Server ausführbar
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "chmod +x /tmp/rx_node_tunnel_server.py"
    
    log_success "Server auf RX Node bereit"
}

# Installiere Cloudflared auf RX Node
install_cloudflared_on_rx_node() {
    log_info "☁️ Installiere Cloudflared auf RX Node..."
    
    # Installationskommandos
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" << 'EOF'
# Prüfe ob cloudflared bereits installiert ist
if command -v cloudflared > /dev/null 2>&1; then
    echo "Cloudflared bereits installiert"
    cloudflared --version
    exit 0
fi

# Installiere cloudflared
echo "Installiere cloudflared..."
cd /tmp

# Download für Linux AMD64
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64

# Mache ausführbar
chmod +x cloudflared-linux-amd64

# Verschiebe zu /usr/local/bin
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

# Teste Installation
cloudflared --version
echo "Cloudflared erfolgreich installiert"
EOF

    if [ $? -eq 0 ]; then
        log_success "Cloudflared auf RX Node installiert"
    else
        log_error "Cloudflared Installation fehlgeschlagen"
        return 1
    fi
}

# Erstelle Tunnel-Manager für RX Node
create_rx_tunnel_manager() {
    log_info "🔧 Erstelle Tunnel-Manager für RX Node..."
    
    # Erstelle Tunnel-Manager Script
    cat > /tmp/rx_tunnel_manager.sh << 'EOF'
#!/bin/bash

# RX Node Tunnel Manager
# Verwaltet Cloudflare Tunnel für RX Node

set -euo pipefail

LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"
TUNNEL_PORT="8765"
TUNNEL_LOG="/tmp/rx_tunnel.log"
SERVER_LOG="/tmp/rx_node_tunnel.log"
TUNNEL_PID_FILE="/tmp/rx_tunnel.pid"
SERVER_PID_FILE="/tmp/rx_server.pid"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${LOG_PREFIX} $1"
}

log_success() {
    echo -e "${LOG_PREFIX} ${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${LOG_PREFIX} ${RED}❌ $1${NC}" >&2
}

log_info() {
    echo -e "${LOG_PREFIX} ${BLUE}ℹ️ $1${NC}"
}

# Starte RX Node Server
start_server() {
    log_info "🐍 Starte RX Node Tunnel Server..."
    
    if [ -f "$SERVER_PID_FILE" ]; then
        local pid=$(cat "$SERVER_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Server läuft bereits (PID: $pid)"
            return 0
        fi
    fi
    
    # Starte Server im Hintergrund
    nohup python3 /tmp/rx_node_tunnel_server.py > "$SERVER_LOG" 2>&1 &
    local server_pid=$!
    echo "$server_pid" > "$SERVER_PID_FILE"
    
    # Warte kurz und prüfe ob Server läuft
    sleep 3
    if kill -0 "$server_pid" 2>/dev/null; then
        log_success "RX Node Server gestartet (PID: $server_pid)"
        return 0
    else
        log_error "RX Node Server konnte nicht gestartet werden"
        return 1
    fi
}

# Starte Cloudflare Tunnel
start_tunnel() {
    log_info "☁️ Starte Cloudflare Tunnel..."
    
    if [ -f "$TUNNEL_PID_FILE" ]; then
        local pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Tunnel läuft bereits (PID: $pid)"
            return 0
        fi
    fi
    
    # Starte Tunnel im Hintergrund
    nohup cloudflared tunnel --url "http://localhost:$TUNNEL_PORT" > "$TUNNEL_LOG" 2>&1 &
    local tunnel_pid=$!
    echo "$tunnel_pid" > "$TUNNEL_PID_FILE"
    
    # Warte auf Tunnel-URL
    log_info "⏳ Warte auf Tunnel-Initialisierung..."
    sleep 10
    
    if kill -0 "$tunnel_pid" 2>/dev/null; then
        # Extrahiere Tunnel-URL
        local tunnel_url=$(grep -o 'https://.*\.trycloudflare\.com' "$TUNNEL_LOG" | head -1 || echo "URL nicht gefunden")
        log_success "Cloudflare Tunnel gestartet (PID: $tunnel_pid)"
        log_success "Tunnel-URL: $tunnel_url"
        
        # Speichere URL
        echo "$tunnel_url" > /tmp/rx_tunnel_url.txt
        return 0
    else
        log_error "Cloudflare Tunnel konnte nicht gestartet werden"
        return 1
    fi
}

# Stoppe Services
stop_services() {
    log_info "🛑 Stoppe RX Node Tunnel Services..."
    
    # Stoppe Tunnel
    if [ -f "$TUNNEL_PID_FILE" ]; then
        local pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_success "Tunnel gestoppt"
        fi
        rm -f "$TUNNEL_PID_FILE"
    fi
    
    # Stoppe Server
    if [ -f "$SERVER_PID_FILE" ]; then
        local pid=$(cat "$SERVER_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_success "Server gestoppt"
        fi
        rm -f "$SERVER_PID_FILE"
    fi
}

# Status prüfen
check_status() {
    echo "🎯 RX Node Tunnel Status"
    echo "========================"
    
    # Server Status
    if [ -f "$SERVER_PID_FILE" ]; then
        local server_pid=$(cat "$SERVER_PID_FILE")
        if kill -0 "$server_pid" 2>/dev/null; then
            echo -e "Server: ${GREEN}✅ Läuft${NC} (PID: $server_pid)"
        else
            echo -e "Server: ${RED}❌ Gestoppt${NC}"
        fi
    else
        echo -e "Server: ${RED}❌ Nicht gestartet${NC}"
    fi
    
    # Tunnel Status
    if [ -f "$TUNNEL_PID_FILE" ]; then
        local tunnel_pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$tunnel_pid" 2>/dev/null; then
            echo -e "Tunnel: ${GREEN}✅ Läuft${NC} (PID: $tunnel_pid)"
            
            # Tunnel URL anzeigen
            if [ -f "/tmp/rx_tunnel_url.txt" ]; then
                local url=$(cat /tmp/rx_tunnel_url.txt)
                echo "URL: $url"
            fi
        else
            echo -e "Tunnel: ${RED}❌ Gestoppt${NC}"
        fi
    else
        echo -e "Tunnel: ${RED}❌ Nicht gestartet${NC}"
    fi
    
    # System Info
    echo ""
    echo "System: $(hostname)"
    echo "Uptime: $(uptime -p)"
}

# Zeige Logs
show_logs() {
    local service="$1"
    
    case "$service" in
        "server")
            if [ -f "$SERVER_LOG" ]; then
                tail -f "$SERVER_LOG"
            else
                log_error "Server-Log nicht gefunden"
            fi
            ;;
        "tunnel")
            if [ -f "$TUNNEL_LOG" ]; then
                tail -f "$TUNNEL_LOG"
            else
                log_error "Tunnel-Log nicht gefunden"
            fi
            ;;
        *)
            echo "Verfügbare Logs: server, tunnel"
            ;;
    esac
}

# Hauptfunktion
main() {
    case "${1:-}" in
        "start")
            start_server
            start_tunnel
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            stop_services
            sleep 2
            start_server
            start_tunnel
            ;;
        "status")
            check_status
            ;;
        "logs")
            show_logs "${2:-}"
            ;;
        "url")
            if [ -f "/tmp/rx_tunnel_url.txt" ]; then
                cat /tmp/rx_tunnel_url.txt
            else
                echo "Tunnel-URL nicht verfügbar"
            fi
            ;;
        *)
            echo "RX Node Tunnel Manager"
            echo "====================="
            echo "Verwendung: $0 {start|stop|restart|status|logs|url}"
            echo ""
            echo "Kommandos:"
            echo "  start    - Starte Server und Tunnel"
            echo "  stop     - Stoppe alle Services"
            echo "  restart  - Neustart aller Services"
            echo "  status   - Zeige Status"
            echo "  logs     - Zeige Logs (server|tunnel)"
            echo "  url      - Zeige Tunnel-URL"
            ;;
    esac
}

main "$@"
EOF

    # Kopiere Tunnel-Manager zur RX Node
    if scp -i "$SSH_KEY_PATH" /tmp/rx_tunnel_manager.sh "$RX_NODE_USER@$RX_NODE_IP:/tmp/"; then
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "chmod +x /tmp/rx_tunnel_manager.sh"
        log_success "Tunnel-Manager zur RX Node kopiert"
    else
        log_error "Tunnel-Manager Kopierung fehlgeschlagen"
        return 1
    fi
}

# Starte RX Node Tunnel
start_rx_tunnel() {
    log_info "🚀 Starte RX Node Tunnel..."
    
    # Starte Tunnel auf RX Node
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh start"
    
    # Warte kurz
    sleep 5
    
    # Hole Tunnel-URL
    local tunnel_url
    tunnel_url=$(ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh url" 2>/dev/null || echo "")
    
    if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
        log_success "RX Node Tunnel gestartet!"
        log_success "Tunnel-URL: $tunnel_url"
        
        # Speichere URL lokal
        echo "$tunnel_url" > /tmp/rx_node_tunnel_url.txt
        
        return 0
    else
        log_warning "Tunnel gestartet, aber URL noch nicht verfügbar"
        log_info "Prüfe Status mit: ssh rx-node '/tmp/rx_tunnel_manager.sh status'"
        return 1
    fi
}

# Teste RX Node Tunnel
test_rx_tunnel() {
    log_info "🧪 Teste RX Node Tunnel..."
    
    # Hole Tunnel-URL
    local tunnel_url
    if [ -f "/tmp/rx_node_tunnel_url.txt" ]; then
        tunnel_url=$(cat /tmp/rx_node_tunnel_url.txt)
    else
        tunnel_url=$(ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh url" 2>/dev/null || echo "")
    fi
    
    if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
        log_info "Teste Health-Check über Tunnel..."
        
        # Teste Health-Check
        if curl -s --max-time 10 "$tunnel_url/health" | jq . >/dev/null 2>&1; then
            log_success "RX Node Tunnel funktioniert!"
            log_success "Health-Check: $tunnel_url/health"
            log_success "Status: $tunnel_url/status"
            return 0
        else
            log_warning "Tunnel erreichbar, aber Health-Check fehlgeschlagen"
            return 1
        fi
    else
        log_error "Tunnel-URL nicht verfügbar"
        return 1
    fi
}

# Erstelle lokales RX Node Tunnel Control Script
create_local_control_script() {
    log_info "📝 Erstelle lokales RX Node Tunnel Control Script..."
    
    cat > ./rx_node_tunnel_control.sh << 'EOF'
#!/bin/bash

# GENTLEMAN RX Node Tunnel Control
# Steuert die RX Node über ihren eigenen Tunnel

set -euo pipefail

# Konfiguration
RX_NODE_IP="192.168.68.117"
RX_NODE_USER="amo9n11"
SSH_KEY_PATH="$HOME/.ssh/gentleman_key"
TUNNEL_URL_FILE="/tmp/rx_node_tunnel_url.txt"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

# Hole Tunnel-URL
get_tunnel_url() {
    local tunnel_url=""
    
    # Versuche lokale Datei
    if [ -f "$TUNNEL_URL_FILE" ]; then
        tunnel_url=$(cat "$TUNNEL_URL_FILE" 2>/dev/null || echo "")
    fi
    
    # Versuche SSH zur RX Node
    if [[ -z "$tunnel_url" || "$tunnel_url" == "Tunnel-URL nicht verfügbar" ]]; then
        tunnel_url=$(ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh url" 2>/dev/null || echo "")
    fi
    
    echo "$tunnel_url"
}

# Prüfe Netzwerk-Modus
detect_network_mode() {
    local current_ip
    current_ip=$(ifconfig | grep -E "(192\.168\.68\.|172\.20\.10\.)" | head -1 | awk '{print $2}' || echo "")
    
    if [[ "$current_ip" =~ ^192\.168\.68\. ]]; then
        echo "home"
    elif [[ "$current_ip" =~ ^172\.20\.10\. ]]; then
        echo "hotspot"
    else
        echo "unknown"
    fi
}

# RX Node Status
rx_status() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🎯 RX Node Status (Netzwerk: $network_mode)"
    
    if [ "$network_mode" == "home" ]; then
        # Heimnetzwerk - SSH verwenden
        log_info "📡 Verwende SSH-Verbindung..."
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh status"
    else
        # Hotspot - Tunnel verwenden
        local tunnel_url
        tunnel_url=$(get_tunnel_url)
        
        if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
            log_info "☁️ Verwende Tunnel: $tunnel_url"
            
            # Status über Tunnel
            local response
            response=$(curl -s --max-time 10 "$tunnel_url/status" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                echo "🎯 RX Node Status (über Tunnel)"
                echo "==============================="
                echo "$response" | jq -r '.hostname // "N/A"' | sed 's/^/Hostname: /'
                echo "$response" | jq -r '.uptime // "N/A"' | sed 's/^/Uptime: /'
                log_success "RX Node online über Tunnel"
            else
                log_error "Status-Abfrage über Tunnel fehlgeschlagen"
            fi
        else
            log_error "Tunnel-URL nicht verfügbar"
        fi
    fi
}

# RX Node Shutdown
rx_shutdown() {
    local delay_minutes="${1:-1}"
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🎯 RX Node Shutdown (Netzwerk: $network_mode, Delay: ${delay_minutes}m)"
    
    if [ "$network_mode" == "home" ]; then
        # Heimnetzwerk - SSH verwenden
        log_info "📡 Verwende SSH-Verbindung..."
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "sudo shutdown -h +$delay_minutes"
        log_success "Shutdown-Befehl über SSH gesendet"
    else
        # Hotspot - Tunnel verwenden
        local tunnel_url
        tunnel_url=$(get_tunnel_url)
        
        if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
            log_info "☁️ Verwende Tunnel: $tunnel_url"
            
            # Shutdown über Tunnel
            local response
            response=$(curl -s --max-time 10 -X POST "$tunnel_url/shutdown" \
                -H "Content-Type: application/json" \
                -d "{\"source\": \"Tunnel Control\", \"delay_minutes\": $delay_minutes}" | jq . 2>/dev/null || echo "")
            
            if [ -n "$response" ]; then
                local status
                status=$(echo "$response" | jq -r '.status // "unknown"')
                
                if [ "$status" == "success" ]; then
                    log_success "RX Node Shutdown über Tunnel eingeleitet"
                else
                    log_error "Shutdown über Tunnel fehlgeschlagen"
                fi
            else
                log_error "Shutdown-Anfrage über Tunnel fehlgeschlagen"
            fi
        else
            log_error "Tunnel-URL nicht verfügbar"
        fi
    fi
}

# RX Node Tunnel Management
rx_tunnel() {
    local action="$1"
    
    case "$action" in
        "start")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh start"
            ;;
        "stop")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh stop"
            ;;
        "restart")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager.sh restart"
            ;;
        "url")
            local tunnel_url
            tunnel_url=$(get_tunnel_url)
            if [[ -n "$tunnel_url" && "$tunnel_url" != "Tunnel-URL nicht verfügbar" ]]; then
                echo "$tunnel_url"
            else
                echo "Tunnel-URL nicht verfügbar"
            fi
            ;;
        *)
            echo "Tunnel-Aktionen: start|stop|restart|url"
            ;;
    esac
}

# Hauptfunktion
main() {
    case "${1:-}" in
        "status")
            rx_status
            ;;
        "shutdown")
            rx_shutdown "${2:-1}"
            ;;
        "tunnel")
            rx_tunnel "${2:-status}"
            ;;
        *)
            echo -e "${PURPLE}🎯 GENTLEMAN RX Node Tunnel Control${NC}"
            echo "===================================="
            echo ""
            echo "Kommandos:"
            echo "  status                    - RX Node Status prüfen"
            echo "  shutdown [delay_minutes]  - RX Node herunterfahren"
            echo "  tunnel {start|stop|restart|url} - Tunnel verwalten"
            echo ""
            echo "Beispiele:"
            echo "  $0 status"
            echo "  $0 shutdown 5"
            echo "  $0 tunnel url"
            ;;
    esac
}

main "$@"
EOF

    chmod +x ./rx_node_tunnel_control.sh
    log_success "Lokales RX Node Tunnel Control Script erstellt"
}

# Zeige Zusammenfassung
show_summary() {
    echo ""
    echo -e "${PURPLE}🎯 GENTLEMAN RX Node Tunnel Setup - Zusammenfassung${NC}"
    echo "=================================================="
    echo ""
    
    echo -e "${CYAN}RX Node Tunnel System:${NC}"
    echo "• Eigener Cloudflare Tunnel für RX Node"
    echo "• Python-basierter Tunnel Server (Port 8765)"
    echo "• Automatisches Tunnel-Management"
    echo "• Lokale und Remote-Steuerung"
    echo ""
    
    echo -e "${CYAN}Verfügbare Kommandos:${NC}"
    echo "• Lokale Steuerung: ./rx_node_tunnel_control.sh status"
    echo "• SSH zur RX Node: ssh rx-node '/tmp/rx_tunnel_manager.sh status'"
    echo "• Tunnel-URL: ./rx_node_tunnel_control.sh tunnel url"
    echo ""
    
    echo -e "${CYAN}API-Endpoints (über Tunnel):${NC}"
    if [ -f "/tmp/rx_node_tunnel_url.txt" ]; then
        local tunnel_url
        tunnel_url=$(cat /tmp/rx_node_tunnel_url.txt)
        echo "• Health Check: $tunnel_url/health"
        echo "• System Status: $tunnel_url/status"
        echo "• Shutdown: POST $tunnel_url/shutdown"
        echo "• Reboot: POST $tunnel_url/reboot"
    else
        echo "• Tunnel-URL wird nach dem Start verfügbar sein"
    fi
    echo ""
    
    echo -e "${YELLOW}💡 Nächste Schritte:${NC}"
    echo "1. Teste RX Node Tunnel: ./rx_node_tunnel_control.sh status"
    echo "2. Wechsle zum Hotspot und teste Remote-Zugriff"
    echo "3. Teste Shutdown über Tunnel: ./rx_node_tunnel_control.sh shutdown 1"
    echo ""
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN RX Node Tunnel Setup${NC}"
    echo "=================================="
    echo ""
    
    log_info "Starte RX Node Tunnel Setup..."
    
    # Setup-Schritte
    if ! test_rx_node_connection; then
        exit 1
    fi
    
    create_rx_node_server
    deploy_server_to_rx_node
    install_cloudflared_on_rx_node
    create_rx_tunnel_manager
    start_rx_tunnel
    
    # Warte kurz für Tunnel-Initialisierung
    sleep 5
    
    if test_rx_tunnel; then
        create_local_control_script
        
        echo ""
        log_success "🎉 RX Node Tunnel Setup erfolgreich abgeschlossen!"
        
        show_summary
    else
        log_warning "Setup abgeschlossen, aber Tunnel-Test fehlgeschlagen"
        log_info "Prüfe manuell: ssh rx-node '/tmp/rx_tunnel_manager.sh status'"
    fi
}

# Führe Hauptfunktion aus
main "$@"