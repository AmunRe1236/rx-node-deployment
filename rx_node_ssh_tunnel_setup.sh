#!/bin/bash

# GENTLEMAN RX Node SSH Tunnel Setup
# Richtet einen SSH-Tunnel über Cloudflare für die RX Node ein

set -euo pipefail

# Konfiguration
RX_NODE_IP="192.168.68.117"
RX_NODE_USER="amo9n11"
SSH_KEY_PATH="$HOME/.ssh/gentleman_key"
SSH_TUNNEL_PORT="2222"

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

# Erstelle SSH Tunnel Server für RX Node
create_ssh_tunnel_server() {
    log_info "🔧 Erstelle SSH Tunnel Server für RX Node..."
    
    cat > /tmp/rx_ssh_tunnel_server.py << 'EOF'
#!/usr/bin/env python3

import socket
import threading
import logging
import sys
import signal
import time
from datetime import datetime

# Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/rx_ssh_tunnel.log'),
        logging.StreamHandler()
    ]
)

class SSHTunnelServer:
    def __init__(self, listen_port=2222, target_host='localhost', target_port=22):
        self.listen_port = listen_port
        self.target_host = target_host
        self.target_port = target_port
        self.server_socket = None
        self.running = False
        self.connections = []
        
    def handle_client(self, client_socket, client_address):
        """Handle einzelne Client-Verbindung"""
        try:
            logging.info(f"🔗 Neue SSH-Verbindung von {client_address}")
            
            # Verbindung zum lokalen SSH Server
            target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            target_socket.connect((self.target_host, self.target_port))
            
            logging.info(f"✅ SSH-Tunnel etabliert: {client_address} -> {self.target_host}:{self.target_port}")
            
            # Bidirektionale Datenweiterleitung
            def forward_data(source, destination, direction):
                try:
                    while True:
                        data = source.recv(4096)
                        if not data:
                            break
                        destination.send(data)
                except Exception as e:
                    logging.debug(f"Datenweiterleitung beendet ({direction}): {e}")
                finally:
                    source.close()
                    destination.close()
            
            # Threads für bidirektionale Weiterleitung
            thread1 = threading.Thread(target=forward_data, args=(client_socket, target_socket, "client->server"))
            thread2 = threading.Thread(target=forward_data, args=(target_socket, client_socket, "server->client"))
            
            thread1.daemon = True
            thread2.daemon = True
            
            thread1.start()
            thread2.start()
            
            # Warte auf Thread-Ende
            thread1.join()
            thread2.join()
            
            logging.info(f"🔌 SSH-Verbindung beendet: {client_address}")
            
        except Exception as e:
            logging.error(f"❌ SSH-Tunnel Fehler für {client_address}: {e}")
        finally:
            try:
                client_socket.close()
                target_socket.close()
            except:
                pass
    
    def start(self):
        """Starte SSH Tunnel Server"""
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.server_socket.bind(('0.0.0.0', self.listen_port))
            self.server_socket.listen(5)
            
            self.running = True
            logging.info(f"🚀 SSH Tunnel Server gestartet auf 0.0.0.0:{self.listen_port}")
            logging.info(f"🎯 Ziel: {self.target_host}:{self.target_port}")
            
            while self.running:
                try:
                    client_socket, client_address = self.server_socket.accept()
                    
                    # Handle Client in separatem Thread
                    client_thread = threading.Thread(
                        target=self.handle_client, 
                        args=(client_socket, client_address)
                    )
                    client_thread.daemon = True
                    client_thread.start()
                    
                    self.connections.append(client_thread)
                    
                except socket.error as e:
                    if self.running:
                        logging.error(f"❌ Socket Fehler: {e}")
                    break
                    
        except Exception as e:
            logging.error(f"❌ SSH Tunnel Server Fehler: {e}")
        finally:
            self.stop()
    
    def stop(self):
        """Stoppe SSH Tunnel Server"""
        self.running = False
        if self.server_socket:
            try:
                self.server_socket.close()
            except:
                pass
        logging.info("🛑 SSH Tunnel Server gestoppt")

def signal_handler(sig, frame):
    logging.info("🛑 SSH Tunnel Server wird beendet...")
    sys.exit(0)

def main():
    # Signal Handler
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Starte SSH Tunnel Server
    tunnel_server = SSHTunnelServer()
    tunnel_server.start()

if __name__ == "__main__":
    main()
EOF

    log_success "SSH Tunnel Server erstellt"
}

# Erweitere RX Tunnel Manager um SSH-Funktionalität
extend_rx_tunnel_manager() {
    log_info "🔧 Erweitere RX Tunnel Manager um SSH-Funktionalität..."
    
    # Backup des aktuellen Managers
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "cp /tmp/rx_tunnel_manager.sh /tmp/rx_tunnel_manager.sh.backup"
    
    # Erstelle erweiterten Tunnel Manager
    cat > /tmp/rx_tunnel_manager_extended.sh << 'EOF'
#!/bin/bash

# RX Node Tunnel Manager (Extended with SSH)
# Verwaltet Cloudflare Tunnel für RX Node inkl. SSH-Tunnel

set -euo pipefail

LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"
TUNNEL_PORT="8765"
SSH_TUNNEL_PORT="2222"
TUNNEL_LOG="/tmp/rx_tunnel.log"
SSH_TUNNEL_LOG="/tmp/rx_ssh_tunnel.log"
SERVER_LOG="/tmp/rx_node_tunnel.log"
TUNNEL_PID_FILE="/tmp/rx_tunnel.pid"
SSH_TUNNEL_PID_FILE="/tmp/rx_ssh_tunnel.pid"
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

# Starte SSH Tunnel Server
start_ssh_tunnel_server() {
    log_info "🔐 Starte SSH Tunnel Server..."
    
    if [ -f "$SSH_TUNNEL_PID_FILE" ]; then
        local pid=$(cat "$SSH_TUNNEL_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "SSH Tunnel Server läuft bereits (PID: $pid)"
            return 0
        fi
    fi
    
    # Starte SSH Tunnel Server im Hintergrund
    nohup python3 /tmp/rx_ssh_tunnel_server.py > "$SSH_TUNNEL_LOG" 2>&1 &
    local ssh_server_pid=$!
    echo "$ssh_server_pid" > "$SSH_TUNNEL_PID_FILE"
    
    # Warte kurz und prüfe ob Server läuft
    sleep 3
    if kill -0 "$ssh_server_pid" 2>/dev/null; then
        log_success "SSH Tunnel Server gestartet (PID: $ssh_server_pid)"
        return 0
    else
        log_error "SSH Tunnel Server konnte nicht gestartet werden"
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
    nohup ~/cloudflared tunnel --url "http://localhost:$TUNNEL_PORT" > "$TUNNEL_LOG" 2>&1 &
    local tunnel_pid=$!
    echo "$tunnel_pid" > "$TUNNEL_PID_FILE"
    
    # Warte auf Tunnel-URL
    log_info "⏳ Warte auf Tunnel-Initialisierung..."
    sleep 10
    
    if kill -0 "$tunnel_pid" 2>/dev/null; then
        # Extrahiere Tunnel-URL
        local tunnel_url=$(grep -o 'https://.*\.trycloudflare\.com' "$TUNNEL_LOG" | head -1 || echo "URL nicht gefunden")
        log_success "Cloudflare Tunnel gestartet (PID: $tunnel_pid)"
        log_success "HTTP Tunnel-URL: $tunnel_url"
        
        # Speichere URL
        echo "$tunnel_url" > /tmp/rx_tunnel_url.txt
        return 0
    else
        log_error "Cloudflare Tunnel konnte nicht gestartet werden"
        return 1
    fi
}

# Starte SSH Cloudflare Tunnel
start_ssh_tunnel() {
    log_info "🔐 Starte SSH Cloudflare Tunnel..."
    
    # Starte separaten Tunnel für SSH
    nohup ~/cloudflared tunnel --url "tcp://localhost:$SSH_TUNNEL_PORT" > /tmp/rx_ssh_cloudflare_tunnel.log 2>&1 &
    local ssh_tunnel_pid=$!
    echo "$ssh_tunnel_pid" > /tmp/rx_ssh_cloudflare_tunnel.pid
    
    # Warte auf SSH Tunnel-URL
    log_info "⏳ Warte auf SSH Tunnel-Initialisierung..."
    sleep 10
    
    if kill -0 "$ssh_tunnel_pid" 2>/dev/null; then
        # Extrahiere SSH Tunnel-URL
        local ssh_tunnel_url=$(grep -o 'https://.*\.trycloudflare\.com' /tmp/rx_ssh_cloudflare_tunnel.log | head -1 || echo "SSH URL nicht gefunden")
        log_success "SSH Cloudflare Tunnel gestartet (PID: $ssh_tunnel_pid)"
        log_success "SSH Tunnel-URL: $ssh_tunnel_url"
        
        # Speichere SSH URL
        echo "$ssh_tunnel_url" > /tmp/rx_ssh_tunnel_url.txt
        return 0
    else
        log_error "SSH Cloudflare Tunnel konnte nicht gestartet werden"
        return 1
    fi
}

# Stoppe Services
stop_services() {
    log_info "🛑 Stoppe RX Node Tunnel Services..."
    
    # Stoppe HTTP Tunnel
    if [ -f "$TUNNEL_PID_FILE" ]; then
        local pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_success "HTTP Tunnel gestoppt"
        fi
        rm -f "$TUNNEL_PID_FILE"
    fi
    
    # Stoppe SSH Cloudflare Tunnel
    if [ -f "/tmp/rx_ssh_cloudflare_tunnel.pid" ]; then
        local pid=$(cat "/tmp/rx_ssh_cloudflare_tunnel.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_success "SSH Cloudflare Tunnel gestoppt"
        fi
        rm -f "/tmp/rx_ssh_cloudflare_tunnel.pid"
    fi
    
    # Stoppe SSH Tunnel Server
    if [ -f "$SSH_TUNNEL_PID_FILE" ]; then
        local pid=$(cat "$SSH_TUNNEL_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_success "SSH Tunnel Server gestoppt"
        fi
        rm -f "$SSH_TUNNEL_PID_FILE"
    fi
    
    # Stoppe HTTP Server
    if [ -f "$SERVER_PID_FILE" ]; then
        local pid=$(cat "$SERVER_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_success "HTTP Server gestoppt"
        fi
        rm -f "$SERVER_PID_FILE"
    fi
}

# Status prüfen
check_status() {
    echo "🎯 RX Node Tunnel Status (Extended)"
    echo "==================================="
    
    # HTTP Server Status
    if [ -f "$SERVER_PID_FILE" ]; then
        local server_pid=$(cat "$SERVER_PID_FILE")
        if kill -0 "$server_pid" 2>/dev/null; then
            echo -e "HTTP Server: ${GREEN}✅ Läuft${NC} (PID: $server_pid)"
        else
            echo -e "HTTP Server: ${RED}❌ Gestoppt${NC}"
        fi
    else
        echo -e "HTTP Server: ${RED}❌ Nicht gestartet${NC}"
    fi
    
    # HTTP Tunnel Status
    if [ -f "$TUNNEL_PID_FILE" ]; then
        local tunnel_pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$tunnel_pid" 2>/dev/null; then
            echo -e "HTTP Tunnel: ${GREEN}✅ Läuft${NC} (PID: $tunnel_pid)"
            
            # HTTP Tunnel URL anzeigen
            if [ -f "/tmp/rx_tunnel_url.txt" ]; then
                local url=$(cat /tmp/rx_tunnel_url.txt)
                echo "HTTP URL: $url"
            fi
        else
            echo -e "HTTP Tunnel: ${RED}❌ Gestoppt${NC}"
        fi
    else
        echo -e "HTTP Tunnel: ${RED}❌ Nicht gestartet${NC}"
    fi
    
    # SSH Tunnel Server Status
    if [ -f "$SSH_TUNNEL_PID_FILE" ]; then
        local ssh_server_pid=$(cat "$SSH_TUNNEL_PID_FILE")
        if kill -0 "$ssh_server_pid" 2>/dev/null; then
            echo -e "SSH Server: ${GREEN}✅ Läuft${NC} (PID: $ssh_server_pid)"
        else
            echo -e "SSH Server: ${RED}❌ Gestoppt${NC}"
        fi
    else
        echo -e "SSH Server: ${RED}❌ Nicht gestartet${NC}"
    fi
    
    # SSH Cloudflare Tunnel Status
    if [ -f "/tmp/rx_ssh_cloudflare_tunnel.pid" ]; then
        local ssh_tunnel_pid=$(cat "/tmp/rx_ssh_cloudflare_tunnel.pid")
        if kill -0 "$ssh_tunnel_pid" 2>/dev/null; then
            echo -e "SSH Tunnel: ${GREEN}✅ Läuft${NC} (PID: $ssh_tunnel_pid)"
            
            # SSH Tunnel URL anzeigen
            if [ -f "/tmp/rx_ssh_tunnel_url.txt" ]; then
                local ssh_url=$(cat /tmp/rx_ssh_tunnel_url.txt)
                echo "SSH URL: $ssh_url"
            fi
        else
            echo -e "SSH Tunnel: ${RED}❌ Gestoppt${NC}"
        fi
    else
        echo -e "SSH Tunnel: ${RED}❌ Nicht gestartet${NC}"
    fi
    
    # System Info
    echo ""
    echo "System: $(hostname)"
    echo "Uptime: $(uptime -p)"
}

# URLs abrufen
get_urls() {
    echo "🌐 RX Node Tunnel URLs"
    echo "======================"
    
    if [ -f "/tmp/rx_tunnel_url.txt" ]; then
        local http_url=$(cat /tmp/rx_tunnel_url.txt)
        echo "HTTP API: $http_url"
    else
        echo "HTTP API: Nicht verfügbar"
    fi
    
    if [ -f "/tmp/rx_ssh_tunnel_url.txt" ]; then
        local ssh_url=$(cat /tmp/rx_ssh_tunnel_url.txt)
        echo "SSH: $ssh_url"
        echo ""
        echo "SSH-Verbindung:"
        echo "cloudflared access tcp --hostname $ssh_url --url localhost:2222"
        echo "ssh -p 2222 amo9n11@localhost"
    else
        echo "SSH: Nicht verfügbar"
    fi
}

# Hauptfunktion
main() {
    case "${1:-}" in
        "start")
            start_server
            start_ssh_tunnel_server
            start_tunnel
            start_ssh_tunnel
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            stop_services
            sleep 2
            start_server
            start_ssh_tunnel_server
            start_tunnel
            start_ssh_tunnel
            ;;
        "status")
            check_status
            ;;
        "urls")
            get_urls
            ;;
        "http-only")
            start_server
            start_tunnel
            ;;
        "ssh-only")
            start_ssh_tunnel_server
            start_ssh_tunnel
            ;;
        *)
            echo "RX Node Tunnel Manager (Extended)"
            echo "================================="
            echo "Verwendung: $0 {start|stop|restart|status|urls|http-only|ssh-only}"
            echo ""
            echo "Kommandos:"
            echo "  start      - Starte alle Services (HTTP + SSH)"
            echo "  stop       - Stoppe alle Services"
            echo "  restart    - Neustart aller Services"
            echo "  status     - Zeige Status"
            echo "  urls       - Zeige Tunnel-URLs"
            echo "  http-only  - Nur HTTP-Tunnel starten"
            echo "  ssh-only   - Nur SSH-Tunnel starten"
            ;;
    esac
}

main "$@"
EOF

    log_success "Erweiterter RX Tunnel Manager erstellt"
}

# Deploye SSH-Tunnel-Komponenten zur RX Node
deploy_ssh_components() {
    log_info "📤 Deploye SSH-Tunnel-Komponenten zur RX Node..."
    
    # Kopiere SSH Tunnel Server
    if scp -i "$SSH_KEY_PATH" /tmp/rx_ssh_tunnel_server.py "$RX_NODE_USER@$RX_NODE_IP:/tmp/"; then
        log_success "SSH Tunnel Server kopiert"
    else
        log_error "SSH Tunnel Server Kopierung fehlgeschlagen"
        return 1
    fi
    
    # Kopiere erweiterten Tunnel Manager
    if scp -i "$SSH_KEY_PATH" /tmp/rx_tunnel_manager_extended.sh "$RX_NODE_USER@$RX_NODE_IP:/tmp/"; then
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "chmod +x /tmp/rx_tunnel_manager_extended.sh"
        log_success "Erweiterter Tunnel Manager kopiert"
    else
        log_error "Erweiterter Tunnel Manager Kopierung fehlgeschlagen"
        return 1
    fi
    
    # Mache SSH Tunnel Server ausführbar
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "chmod +x /tmp/rx_ssh_tunnel_server.py"
}

# Teste SSH-Tunnel
test_ssh_tunnel() {
    log_info "🧪 Teste SSH-Tunnel Setup..."
    
    # Starte erweiterten Tunnel Manager
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh start"
    
    # Warte kurz
    sleep 10
    
    # Prüfe Status
    log_info "📊 Prüfe Tunnel-Status..."
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh status"
    
    echo ""
    log_info "📋 Tunnel-URLs:"
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh urls"
}

# Erstelle lokales SSH-Tunnel Control Script
create_ssh_tunnel_control() {
    log_info "📝 Erstelle lokales SSH-Tunnel Control Script..."
    
    cat > ./rx_ssh_tunnel_control.sh << 'EOF'
#!/bin/bash

# GENTLEMAN RX Node SSH Tunnel Control
# Ermöglicht SSH-Zugriff auf RX Node über Cloudflare Tunnel

set -euo pipefail

# Konfiguration
RX_NODE_IP="192.168.68.117"
RX_NODE_USER="amo9n11"
SSH_KEY_PATH="$HOME/.ssh/gentleman_key"
SSH_TUNNEL_URL_FILE="/tmp/rx_ssh_tunnel_url.txt"

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

# Hole SSH-Tunnel-URL
get_ssh_tunnel_url() {
    local ssh_url=""
    
    # Versuche von RX Node zu holen
    ssh_url=$(ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "cat /tmp/rx_ssh_tunnel_url.txt 2>/dev/null || echo ''" 2>/dev/null || echo "")
    
    echo "$ssh_url"
}

# SSH-Verbindung über Tunnel
ssh_via_tunnel() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🔐 SSH-Verbindung zur RX Node (Netzwerk: $network_mode)"
    
    if [ "$network_mode" == "home" ]; then
        log_info "📡 Im Heimnetzwerk - verwende direkte SSH-Verbindung"
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP"
    else
        log_info "☁️ Im Hotspot - verwende SSH-Tunnel"
        
        local ssh_tunnel_url
        ssh_tunnel_url=$(get_ssh_tunnel_url)
        
        if [[ -n "$ssh_tunnel_url" && "$ssh_tunnel_url" != "SSH URL nicht gefunden" ]]; then
            log_info "🌐 SSH-Tunnel-URL: $ssh_tunnel_url"
            log_info "🔗 Etabliere Tunnel-Verbindung..."
            
            # Starte lokalen Tunnel-Proxy
            cloudflared access tcp --hostname "$ssh_tunnel_url" --url localhost:2222 &
            local proxy_pid=$!
            
            # Warte kurz für Proxy-Initialisierung
            sleep 3
            
            log_info "🔐 Verbinde via SSH über Tunnel..."
            ssh -i "$SSH_KEY_PATH" -p 2222 "$RX_NODE_USER@localhost"
            
            # Stoppe Proxy nach SSH-Session
            kill $proxy_pid 2>/dev/null || true
            
        else
            log_error "SSH-Tunnel-URL nicht verfügbar"
            log_info "💡 Starte SSH-Tunnel auf RX Node:"
            log_info "   ssh rx-node '/tmp/rx_tunnel_manager_extended.sh start'"
        fi
    fi
}

# SSH-Tunnel-Status
ssh_tunnel_status() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    echo -e "${PURPLE}🎯 GENTLEMAN SSH-Tunnel Status${NC}"
    echo "==============================="
    echo ""
    echo -e "${BLUE}Netzwerk-Modus: $network_mode${NC}"
    echo ""
    
    if [ "$network_mode" == "home" ]; then
        log_info "📡 Im Heimnetzwerk - SSH-Tunnel nicht erforderlich"
        log_info "📋 Prüfe RX Node SSH-Tunnel-Services..."
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh status"
    else
        log_info "☁️ Im Hotspot - SSH-Tunnel erforderlich"
        
        local ssh_tunnel_url
        ssh_tunnel_url=$(get_ssh_tunnel_url)
        
        if [[ -n "$ssh_tunnel_url" && "$ssh_tunnel_url" != "SSH URL nicht gefunden" ]]; then
            echo "✅ SSH-Tunnel verfügbar: $ssh_tunnel_url"
            echo ""
            echo "🔗 Verbindung herstellen:"
            echo "  $0 connect"
        else
            echo "❌ SSH-Tunnel nicht verfügbar"
        fi
    fi
}

# SSH-Tunnel verwalten
manage_ssh_tunnel() {
    local action="$1"
    
    case "$action" in
        "start")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh start"
            ;;
        "stop")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh stop"
            ;;
        "restart")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh restart"
            ;;
        "urls")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh urls"
            ;;
        *)
            echo "SSH-Tunnel Aktionen: start|stop|restart|urls"
            ;;
    esac
}

# Hauptfunktion
main() {
    case "${1:-}" in
        "connect"|"ssh")
            ssh_via_tunnel
            ;;
        "status")
            ssh_tunnel_status
            ;;
        "tunnel")
            manage_ssh_tunnel "${2:-status}"
            ;;
        *)
            echo -e "${PURPLE}🎯 GENTLEMAN RX Node SSH-Tunnel Control${NC}"
            echo "========================================"
            echo ""
            echo "Kommandos:"
            echo "  connect                   - SSH-Verbindung zur RX Node"
            echo "  ssh                       - Alias für connect"
            echo "  status                    - SSH-Tunnel Status"
            echo "  tunnel {start|stop|restart|urls} - Tunnel verwalten"
            echo ""
            echo "Beispiele:"
            echo "  $0 connect                - SSH zur RX Node"
            echo "  $0 status                 - Tunnel-Status prüfen"
            echo "  $0 tunnel start           - SSH-Tunnel starten"
            ;;
    esac
}

main "$@"
EOF

    chmod +x ./rx_ssh_tunnel_control.sh
    log_success "SSH-Tunnel Control Script erstellt"
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN RX Node SSH Tunnel Setup${NC}"
    echo "======================================"
    echo ""
    
    log_info "Richte SSH-Tunnel für RX Node ein..."
    
    # Setup-Schritte
    create_ssh_tunnel_server
    extend_rx_tunnel_manager
    deploy_ssh_components
    test_ssh_tunnel
    create_ssh_tunnel_control
    
    echo ""
    log_success "🎉 SSH-Tunnel Setup abgeschlossen!"
    echo ""
    echo -e "${CYAN}Verfügbare Kommandos:${NC}"
    echo "• SSH-Verbindung: ./rx_ssh_tunnel_control.sh connect"
    echo "• Tunnel-Status: ./rx_ssh_tunnel_control.sh status"
    echo "• Tunnel verwalten: ./rx_ssh_tunnel_control.sh tunnel start"
    echo ""
    echo -e "${YELLOW}💡 Verwendung:${NC}"
    echo "1. Im Heimnetzwerk: Normale SSH-Verbindung"
    echo "2. Im Hotspot: Automatische Tunnel-Weiterleitung"
    echo "3. Beide Modi werden automatisch erkannt"
}

main "$@"

# GENTLEMAN RX Node SSH Tunnel Setup
# Richtet einen SSH-Tunnel über Cloudflare für die RX Node ein

set -euo pipefail

# Konfiguration
RX_NODE_IP="192.168.68.117"
RX_NODE_USER="amo9n11"
SSH_KEY_PATH="$HOME/.ssh/gentleman_key"
SSH_TUNNEL_PORT="2222"

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

# Erstelle SSH Tunnel Server für RX Node
create_ssh_tunnel_server() {
    log_info "🔧 Erstelle SSH Tunnel Server für RX Node..."
    
    cat > /tmp/rx_ssh_tunnel_server.py << 'EOF'
#!/usr/bin/env python3

import socket
import threading
import logging
import sys
import signal
import time
from datetime import datetime

# Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/rx_ssh_tunnel.log'),
        logging.StreamHandler()
    ]
)

class SSHTunnelServer:
    def __init__(self, listen_port=2222, target_host='localhost', target_port=22):
        self.listen_port = listen_port
        self.target_host = target_host
        self.target_port = target_port
        self.server_socket = None
        self.running = False
        self.connections = []
        
    def handle_client(self, client_socket, client_address):
        """Handle einzelne Client-Verbindung"""
        try:
            logging.info(f"🔗 Neue SSH-Verbindung von {client_address}")
            
            # Verbindung zum lokalen SSH Server
            target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            target_socket.connect((self.target_host, self.target_port))
            
            logging.info(f"✅ SSH-Tunnel etabliert: {client_address} -> {self.target_host}:{self.target_port}")
            
            # Bidirektionale Datenweiterleitung
            def forward_data(source, destination, direction):
                try:
                    while True:
                        data = source.recv(4096)
                        if not data:
                            break
                        destination.send(data)
                except Exception as e:
                    logging.debug(f"Datenweiterleitung beendet ({direction}): {e}")
                finally:
                    source.close()
                    destination.close()
            
            # Threads für bidirektionale Weiterleitung
            thread1 = threading.Thread(target=forward_data, args=(client_socket, target_socket, "client->server"))
            thread2 = threading.Thread(target=forward_data, args=(target_socket, client_socket, "server->client"))
            
            thread1.daemon = True
            thread2.daemon = True
            
            thread1.start()
            thread2.start()
            
            # Warte auf Thread-Ende
            thread1.join()
            thread2.join()
            
            logging.info(f"🔌 SSH-Verbindung beendet: {client_address}")
            
        except Exception as e:
            logging.error(f"❌ SSH-Tunnel Fehler für {client_address}: {e}")
        finally:
            try:
                client_socket.close()
                target_socket.close()
            except:
                pass
    
    def start(self):
        """Starte SSH Tunnel Server"""
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.server_socket.bind(('0.0.0.0', self.listen_port))
            self.server_socket.listen(5)
            
            self.running = True
            logging.info(f"🚀 SSH Tunnel Server gestartet auf 0.0.0.0:{self.listen_port}")
            logging.info(f"🎯 Ziel: {self.target_host}:{self.target_port}")
            
            while self.running:
                try:
                    client_socket, client_address = self.server_socket.accept()
                    
                    # Handle Client in separatem Thread
                    client_thread = threading.Thread(
                        target=self.handle_client, 
                        args=(client_socket, client_address)
                    )
                    client_thread.daemon = True
                    client_thread.start()
                    
                    self.connections.append(client_thread)
                    
                except socket.error as e:
                    if self.running:
                        logging.error(f"❌ Socket Fehler: {e}")
                    break
                    
        except Exception as e:
            logging.error(f"❌ SSH Tunnel Server Fehler: {e}")
        finally:
            self.stop()
    
    def stop(self):
        """Stoppe SSH Tunnel Server"""
        self.running = False
        if self.server_socket:
            try:
                self.server_socket.close()
            except:
                pass
        logging.info("🛑 SSH Tunnel Server gestoppt")

def signal_handler(sig, frame):
    logging.info("🛑 SSH Tunnel Server wird beendet...")
    sys.exit(0)

def main():
    # Signal Handler
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Starte SSH Tunnel Server
    tunnel_server = SSHTunnelServer()
    tunnel_server.start()

if __name__ == "__main__":
    main()
EOF

    log_success "SSH Tunnel Server erstellt"
}

# Erweitere RX Tunnel Manager um SSH-Funktionalität
extend_rx_tunnel_manager() {
    log_info "🔧 Erweitere RX Tunnel Manager um SSH-Funktionalität..."
    
    # Backup des aktuellen Managers
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "cp /tmp/rx_tunnel_manager.sh /tmp/rx_tunnel_manager.sh.backup"
    
    # Erstelle erweiterten Tunnel Manager
    cat > /tmp/rx_tunnel_manager_extended.sh << 'EOF'
#!/bin/bash

# RX Node Tunnel Manager (Extended with SSH)
# Verwaltet Cloudflare Tunnel für RX Node inkl. SSH-Tunnel

set -euo pipefail

LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"
TUNNEL_PORT="8765"
SSH_TUNNEL_PORT="2222"
TUNNEL_LOG="/tmp/rx_tunnel.log"
SSH_TUNNEL_LOG="/tmp/rx_ssh_tunnel.log"
SERVER_LOG="/tmp/rx_node_tunnel.log"
TUNNEL_PID_FILE="/tmp/rx_tunnel.pid"
SSH_TUNNEL_PID_FILE="/tmp/rx_ssh_tunnel.pid"
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

# Starte SSH Tunnel Server
start_ssh_tunnel_server() {
    log_info "🔐 Starte SSH Tunnel Server..."
    
    if [ -f "$SSH_TUNNEL_PID_FILE" ]; then
        local pid=$(cat "$SSH_TUNNEL_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "SSH Tunnel Server läuft bereits (PID: $pid)"
            return 0
        fi
    fi
    
    # Starte SSH Tunnel Server im Hintergrund
    nohup python3 /tmp/rx_ssh_tunnel_server.py > "$SSH_TUNNEL_LOG" 2>&1 &
    local ssh_server_pid=$!
    echo "$ssh_server_pid" > "$SSH_TUNNEL_PID_FILE"
    
    # Warte kurz und prüfe ob Server läuft
    sleep 3
    if kill -0 "$ssh_server_pid" 2>/dev/null; then
        log_success "SSH Tunnel Server gestartet (PID: $ssh_server_pid)"
        return 0
    else
        log_error "SSH Tunnel Server konnte nicht gestartet werden"
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
    nohup ~/cloudflared tunnel --url "http://localhost:$TUNNEL_PORT" > "$TUNNEL_LOG" 2>&1 &
    local tunnel_pid=$!
    echo "$tunnel_pid" > "$TUNNEL_PID_FILE"
    
    # Warte auf Tunnel-URL
    log_info "⏳ Warte auf Tunnel-Initialisierung..."
    sleep 10
    
    if kill -0 "$tunnel_pid" 2>/dev/null; then
        # Extrahiere Tunnel-URL
        local tunnel_url=$(grep -o 'https://.*\.trycloudflare\.com' "$TUNNEL_LOG" | head -1 || echo "URL nicht gefunden")
        log_success "Cloudflare Tunnel gestartet (PID: $tunnel_pid)"
        log_success "HTTP Tunnel-URL: $tunnel_url"
        
        # Speichere URL
        echo "$tunnel_url" > /tmp/rx_tunnel_url.txt
        return 0
    else
        log_error "Cloudflare Tunnel konnte nicht gestartet werden"
        return 1
    fi
}

# Starte SSH Cloudflare Tunnel
start_ssh_tunnel() {
    log_info "🔐 Starte SSH Cloudflare Tunnel..."
    
    # Starte separaten Tunnel für SSH
    nohup ~/cloudflared tunnel --url "tcp://localhost:$SSH_TUNNEL_PORT" > /tmp/rx_ssh_cloudflare_tunnel.log 2>&1 &
    local ssh_tunnel_pid=$!
    echo "$ssh_tunnel_pid" > /tmp/rx_ssh_cloudflare_tunnel.pid
    
    # Warte auf SSH Tunnel-URL
    log_info "⏳ Warte auf SSH Tunnel-Initialisierung..."
    sleep 10
    
    if kill -0 "$ssh_tunnel_pid" 2>/dev/null; then
        # Extrahiere SSH Tunnel-URL
        local ssh_tunnel_url=$(grep -o 'https://.*\.trycloudflare\.com' /tmp/rx_ssh_cloudflare_tunnel.log | head -1 || echo "SSH URL nicht gefunden")
        log_success "SSH Cloudflare Tunnel gestartet (PID: $ssh_tunnel_pid)"
        log_success "SSH Tunnel-URL: $ssh_tunnel_url"
        
        # Speichere SSH URL
        echo "$ssh_tunnel_url" > /tmp/rx_ssh_tunnel_url.txt
        return 0
    else
        log_error "SSH Cloudflare Tunnel konnte nicht gestartet werden"
        return 1
    fi
}

# Stoppe Services
stop_services() {
    log_info "🛑 Stoppe RX Node Tunnel Services..."
    
    # Stoppe HTTP Tunnel
    if [ -f "$TUNNEL_PID_FILE" ]; then
        local pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_success "HTTP Tunnel gestoppt"
        fi
        rm -f "$TUNNEL_PID_FILE"
    fi
    
    # Stoppe SSH Cloudflare Tunnel
    if [ -f "/tmp/rx_ssh_cloudflare_tunnel.pid" ]; then
        local pid=$(cat "/tmp/rx_ssh_cloudflare_tunnel.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_success "SSH Cloudflare Tunnel gestoppt"
        fi
        rm -f "/tmp/rx_ssh_cloudflare_tunnel.pid"
    fi
    
    # Stoppe SSH Tunnel Server
    if [ -f "$SSH_TUNNEL_PID_FILE" ]; then
        local pid=$(cat "$SSH_TUNNEL_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_success "SSH Tunnel Server gestoppt"
        fi
        rm -f "$SSH_TUNNEL_PID_FILE"
    fi
    
    # Stoppe HTTP Server
    if [ -f "$SERVER_PID_FILE" ]; then
        local pid=$(cat "$SERVER_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log_success "HTTP Server gestoppt"
        fi
        rm -f "$SERVER_PID_FILE"
    fi
}

# Status prüfen
check_status() {
    echo "🎯 RX Node Tunnel Status (Extended)"
    echo "==================================="
    
    # HTTP Server Status
    if [ -f "$SERVER_PID_FILE" ]; then
        local server_pid=$(cat "$SERVER_PID_FILE")
        if kill -0 "$server_pid" 2>/dev/null; then
            echo -e "HTTP Server: ${GREEN}✅ Läuft${NC} (PID: $server_pid)"
        else
            echo -e "HTTP Server: ${RED}❌ Gestoppt${NC}"
        fi
    else
        echo -e "HTTP Server: ${RED}❌ Nicht gestartet${NC}"
    fi
    
    # HTTP Tunnel Status
    if [ -f "$TUNNEL_PID_FILE" ]; then
        local tunnel_pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$tunnel_pid" 2>/dev/null; then
            echo -e "HTTP Tunnel: ${GREEN}✅ Läuft${NC} (PID: $tunnel_pid)"
            
            # HTTP Tunnel URL anzeigen
            if [ -f "/tmp/rx_tunnel_url.txt" ]; then
                local url=$(cat /tmp/rx_tunnel_url.txt)
                echo "HTTP URL: $url"
            fi
        else
            echo -e "HTTP Tunnel: ${RED}❌ Gestoppt${NC}"
        fi
    else
        echo -e "HTTP Tunnel: ${RED}❌ Nicht gestartet${NC}"
    fi
    
    # SSH Tunnel Server Status
    if [ -f "$SSH_TUNNEL_PID_FILE" ]; then
        local ssh_server_pid=$(cat "$SSH_TUNNEL_PID_FILE")
        if kill -0 "$ssh_server_pid" 2>/dev/null; then
            echo -e "SSH Server: ${GREEN}✅ Läuft${NC} (PID: $ssh_server_pid)"
        else
            echo -e "SSH Server: ${RED}❌ Gestoppt${NC}"
        fi
    else
        echo -e "SSH Server: ${RED}❌ Nicht gestartet${NC}"
    fi
    
    # SSH Cloudflare Tunnel Status
    if [ -f "/tmp/rx_ssh_cloudflare_tunnel.pid" ]; then
        local ssh_tunnel_pid=$(cat "/tmp/rx_ssh_cloudflare_tunnel.pid")
        if kill -0 "$ssh_tunnel_pid" 2>/dev/null; then
            echo -e "SSH Tunnel: ${GREEN}✅ Läuft${NC} (PID: $ssh_tunnel_pid)"
            
            # SSH Tunnel URL anzeigen
            if [ -f "/tmp/rx_ssh_tunnel_url.txt" ]; then
                local ssh_url=$(cat /tmp/rx_ssh_tunnel_url.txt)
                echo "SSH URL: $ssh_url"
            fi
        else
            echo -e "SSH Tunnel: ${RED}❌ Gestoppt${NC}"
        fi
    else
        echo -e "SSH Tunnel: ${RED}❌ Nicht gestartet${NC}"
    fi
    
    # System Info
    echo ""
    echo "System: $(hostname)"
    echo "Uptime: $(uptime -p)"
}

# URLs abrufen
get_urls() {
    echo "🌐 RX Node Tunnel URLs"
    echo "======================"
    
    if [ -f "/tmp/rx_tunnel_url.txt" ]; then
        local http_url=$(cat /tmp/rx_tunnel_url.txt)
        echo "HTTP API: $http_url"
    else
        echo "HTTP API: Nicht verfügbar"
    fi
    
    if [ -f "/tmp/rx_ssh_tunnel_url.txt" ]; then
        local ssh_url=$(cat /tmp/rx_ssh_tunnel_url.txt)
        echo "SSH: $ssh_url"
        echo ""
        echo "SSH-Verbindung:"
        echo "cloudflared access tcp --hostname $ssh_url --url localhost:2222"
        echo "ssh -p 2222 amo9n11@localhost"
    else
        echo "SSH: Nicht verfügbar"
    fi
}

# Hauptfunktion
main() {
    case "${1:-}" in
        "start")
            start_server
            start_ssh_tunnel_server
            start_tunnel
            start_ssh_tunnel
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            stop_services
            sleep 2
            start_server
            start_ssh_tunnel_server
            start_tunnel
            start_ssh_tunnel
            ;;
        "status")
            check_status
            ;;
        "urls")
            get_urls
            ;;
        "http-only")
            start_server
            start_tunnel
            ;;
        "ssh-only")
            start_ssh_tunnel_server
            start_ssh_tunnel
            ;;
        *)
            echo "RX Node Tunnel Manager (Extended)"
            echo "================================="
            echo "Verwendung: $0 {start|stop|restart|status|urls|http-only|ssh-only}"
            echo ""
            echo "Kommandos:"
            echo "  start      - Starte alle Services (HTTP + SSH)"
            echo "  stop       - Stoppe alle Services"
            echo "  restart    - Neustart aller Services"
            echo "  status     - Zeige Status"
            echo "  urls       - Zeige Tunnel-URLs"
            echo "  http-only  - Nur HTTP-Tunnel starten"
            echo "  ssh-only   - Nur SSH-Tunnel starten"
            ;;
    esac
}

main "$@"
EOF

    log_success "Erweiterter RX Tunnel Manager erstellt"
}

# Deploye SSH-Tunnel-Komponenten zur RX Node
deploy_ssh_components() {
    log_info "📤 Deploye SSH-Tunnel-Komponenten zur RX Node..."
    
    # Kopiere SSH Tunnel Server
    if scp -i "$SSH_KEY_PATH" /tmp/rx_ssh_tunnel_server.py "$RX_NODE_USER@$RX_NODE_IP:/tmp/"; then
        log_success "SSH Tunnel Server kopiert"
    else
        log_error "SSH Tunnel Server Kopierung fehlgeschlagen"
        return 1
    fi
    
    # Kopiere erweiterten Tunnel Manager
    if scp -i "$SSH_KEY_PATH" /tmp/rx_tunnel_manager_extended.sh "$RX_NODE_USER@$RX_NODE_IP:/tmp/"; then
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "chmod +x /tmp/rx_tunnel_manager_extended.sh"
        log_success "Erweiterter Tunnel Manager kopiert"
    else
        log_error "Erweiterter Tunnel Manager Kopierung fehlgeschlagen"
        return 1
    fi
    
    # Mache SSH Tunnel Server ausführbar
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "chmod +x /tmp/rx_ssh_tunnel_server.py"
}

# Teste SSH-Tunnel
test_ssh_tunnel() {
    log_info "🧪 Teste SSH-Tunnel Setup..."
    
    # Starte erweiterten Tunnel Manager
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh start"
    
    # Warte kurz
    sleep 10
    
    # Prüfe Status
    log_info "📊 Prüfe Tunnel-Status..."
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh status"
    
    echo ""
    log_info "📋 Tunnel-URLs:"
    ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh urls"
}

# Erstelle lokales SSH-Tunnel Control Script
create_ssh_tunnel_control() {
    log_info "📝 Erstelle lokales SSH-Tunnel Control Script..."
    
    cat > ./rx_ssh_tunnel_control.sh << 'EOF'
#!/bin/bash

# GENTLEMAN RX Node SSH Tunnel Control
# Ermöglicht SSH-Zugriff auf RX Node über Cloudflare Tunnel

set -euo pipefail

# Konfiguration
RX_NODE_IP="192.168.68.117"
RX_NODE_USER="amo9n11"
SSH_KEY_PATH="$HOME/.ssh/gentleman_key"
SSH_TUNNEL_URL_FILE="/tmp/rx_ssh_tunnel_url.txt"

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

# Hole SSH-Tunnel-URL
get_ssh_tunnel_url() {
    local ssh_url=""
    
    # Versuche von RX Node zu holen
    ssh_url=$(ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "cat /tmp/rx_ssh_tunnel_url.txt 2>/dev/null || echo ''" 2>/dev/null || echo "")
    
    echo "$ssh_url"
}

# SSH-Verbindung über Tunnel
ssh_via_tunnel() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    log_info "🔐 SSH-Verbindung zur RX Node (Netzwerk: $network_mode)"
    
    if [ "$network_mode" == "home" ]; then
        log_info "📡 Im Heimnetzwerk - verwende direkte SSH-Verbindung"
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP"
    else
        log_info "☁️ Im Hotspot - verwende SSH-Tunnel"
        
        local ssh_tunnel_url
        ssh_tunnel_url=$(get_ssh_tunnel_url)
        
        if [[ -n "$ssh_tunnel_url" && "$ssh_tunnel_url" != "SSH URL nicht gefunden" ]]; then
            log_info "🌐 SSH-Tunnel-URL: $ssh_tunnel_url"
            log_info "🔗 Etabliere Tunnel-Verbindung..."
            
            # Starte lokalen Tunnel-Proxy
            cloudflared access tcp --hostname "$ssh_tunnel_url" --url localhost:2222 &
            local proxy_pid=$!
            
            # Warte kurz für Proxy-Initialisierung
            sleep 3
            
            log_info "🔐 Verbinde via SSH über Tunnel..."
            ssh -i "$SSH_KEY_PATH" -p 2222 "$RX_NODE_USER@localhost"
            
            # Stoppe Proxy nach SSH-Session
            kill $proxy_pid 2>/dev/null || true
            
        else
            log_error "SSH-Tunnel-URL nicht verfügbar"
            log_info "💡 Starte SSH-Tunnel auf RX Node:"
            log_info "   ssh rx-node '/tmp/rx_tunnel_manager_extended.sh start'"
        fi
    fi
}

# SSH-Tunnel-Status
ssh_tunnel_status() {
    local network_mode
    network_mode=$(detect_network_mode)
    
    echo -e "${PURPLE}🎯 GENTLEMAN SSH-Tunnel Status${NC}"
    echo "==============================="
    echo ""
    echo -e "${BLUE}Netzwerk-Modus: $network_mode${NC}"
    echo ""
    
    if [ "$network_mode" == "home" ]; then
        log_info "📡 Im Heimnetzwerk - SSH-Tunnel nicht erforderlich"
        log_info "📋 Prüfe RX Node SSH-Tunnel-Services..."
        ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh status"
    else
        log_info "☁️ Im Hotspot - SSH-Tunnel erforderlich"
        
        local ssh_tunnel_url
        ssh_tunnel_url=$(get_ssh_tunnel_url)
        
        if [[ -n "$ssh_tunnel_url" && "$ssh_tunnel_url" != "SSH URL nicht gefunden" ]]; then
            echo "✅ SSH-Tunnel verfügbar: $ssh_tunnel_url"
            echo ""
            echo "🔗 Verbindung herstellen:"
            echo "  $0 connect"
        else
            echo "❌ SSH-Tunnel nicht verfügbar"
        fi
    fi
}

# SSH-Tunnel verwalten
manage_ssh_tunnel() {
    local action="$1"
    
    case "$action" in
        "start")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh start"
            ;;
        "stop")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh stop"
            ;;
        "restart")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh restart"
            ;;
        "urls")
            ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "/tmp/rx_tunnel_manager_extended.sh urls"
            ;;
        *)
            echo "SSH-Tunnel Aktionen: start|stop|restart|urls"
            ;;
    esac
}

# Hauptfunktion
main() {
    case "${1:-}" in
        "connect"|"ssh")
            ssh_via_tunnel
            ;;
        "status")
            ssh_tunnel_status
            ;;
        "tunnel")
            manage_ssh_tunnel "${2:-status}"
            ;;
        *)
            echo -e "${PURPLE}🎯 GENTLEMAN RX Node SSH-Tunnel Control${NC}"
            echo "========================================"
            echo ""
            echo "Kommandos:"
            echo "  connect                   - SSH-Verbindung zur RX Node"
            echo "  ssh                       - Alias für connect"
            echo "  status                    - SSH-Tunnel Status"
            echo "  tunnel {start|stop|restart|urls} - Tunnel verwalten"
            echo ""
            echo "Beispiele:"
            echo "  $0 connect                - SSH zur RX Node"
            echo "  $0 status                 - Tunnel-Status prüfen"
            echo "  $0 tunnel start           - SSH-Tunnel starten"
            ;;
    esac
}

main "$@"
EOF

    chmod +x ./rx_ssh_tunnel_control.sh
    log_success "SSH-Tunnel Control Script erstellt"
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN RX Node SSH Tunnel Setup${NC}"
    echo "======================================"
    echo ""
    
    log_info "Richte SSH-Tunnel für RX Node ein..."
    
    # Setup-Schritte
    create_ssh_tunnel_server
    extend_rx_tunnel_manager
    deploy_ssh_components
    test_ssh_tunnel
    create_ssh_tunnel_control
    
    echo ""
    log_success "🎉 SSH-Tunnel Setup abgeschlossen!"
    echo ""
    echo -e "${CYAN}Verfügbare Kommandos:${NC}"
    echo "• SSH-Verbindung: ./rx_ssh_tunnel_control.sh connect"
    echo "• Tunnel-Status: ./rx_ssh_tunnel_control.sh status"
    echo "• Tunnel verwalten: ./rx_ssh_tunnel_control.sh tunnel start"
    echo ""
    echo -e "${YELLOW}💡 Verwendung:${NC}"
    echo "1. Im Heimnetzwerk: Normale SSH-Verbindung"
    echo "2. Im Hotspot: Automatische Tunnel-Weiterleitung"
    echo "3. Beide Modi werden automatisch erkannt"
}

main "$@"