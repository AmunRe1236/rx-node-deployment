#!/bin/bash

# 🚀 GENTLEMAN M1 Mobile Setup
# ===========================
# Vollständige Mobile-Konfiguration für M1 Mac
# - Handshake Server mit Auto-Restart
# - Cloudflare Tunnel für öffentlichen Zugriff  
# - SSH-Tunnel für Remote-Verwaltung
# - Robuste Netzwerk-Erkennung

set -e

# Konfiguration
M1_HOST="192.168.68.111"
HANDSHAKE_PORT="8765"
SSH_PORT="22"
CLOUDFLARE_TUNNEL_PORT="8765"
LOG_DIR="/tmp/gentleman_mobile"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging Funktion
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

# Erstelle Log-Verzeichnis
create_log_dir() {
    mkdir -p "$LOG_DIR"
}

# Teste SSH-Verbindung zum M1
test_ssh_connection() {
    log "🔍 Teste SSH-Verbindung zum M1 Mac..."
    if ssh -o ConnectTimeout=5 -o BatchMode=yes amonbaumgartner@$M1_HOST "echo 'SSH OK'" >/dev/null 2>&1; then
        success "SSH-Verbindung zum M1 Mac erfolgreich"
        return 0
    else
        error "SSH-Verbindung zum M1 Mac fehlgeschlagen"
        return 1
    fi
}

# Stoppe alte Services auf M1
stop_old_services() {
    log "🛑 Stoppe alte Services auf M1 Mac..."
    ssh amonbaumgartner@$M1_HOST "
        pkill -f 'python3.*handshake' || true
        pkill -f 'cloudflared' || true
        pkill -f 'm1_handshake_server.py' || true
    " 2>/dev/null || true
    success "Alte Services gestoppt"
}

# Installiere Dependencies auf M1
install_dependencies() {
    log "📦 Installiere Dependencies auf M1 Mac..."
    ssh amonbaumgartner@$M1_HOST "
        cd /Users/amonbaumgartner/Gentleman
        
        # Python Dependencies
        python3 -m pip install --user flask requests flask-cors >/dev/null 2>&1 || true
        
        # Cloudflared prüfen/installieren
        if [ ! -f './cloudflared' ]; then
            echo '📥 Lade cloudflared herunter...'
            curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-arm64 -o cloudflared 2>/dev/null || true
            chmod +x cloudflared 2>/dev/null || true
        fi
        
        echo '✅ Dependencies installiert'
    "
    success "Dependencies auf M1 installiert"
}

# Erstelle robustes Handshake Server Script
create_robust_handshake_server() {
    log "🔧 Erstelle robusten Handshake Server auf M1..."
    ssh amonbaumgartner@$M1_HOST "
        cd /Users/amonbaumgartner/Gentleman
        cat > m1_robust_handshake.sh << 'EOF'
#!/bin/bash

# Robuster M1 Handshake Server mit Auto-Restart
HANDSHAKE_PORT=8765
LOG_FILE=\"/tmp/m1_handshake.log\"
PID_FILE=\"/tmp/m1_handshake.pid\"

start_handshake_server() {
    echo \"\$(date): 🚀 Starte M1 Handshake Server...\" >> \"\$LOG_FILE\"
    cd /Users/amonbaumgartner/Gentleman
    
    # Stoppe alte Instanzen
    pkill -f 'python3.*m1_handshake_server.py' || true
    
    # Starte neuen Server
    nohup python3 m1_handshake_server.py --host 0.0.0.0 --port \$HANDSHAKE_PORT >> \"\$LOG_FILE\" 2>&1 &
    echo \$! > \"\$PID_FILE\"
    
    sleep 3
    if curl -s http://localhost:\$HANDSHAKE_PORT/health >/dev/null 2>&1; then
        echo \"\$(date): ✅ Handshake Server gestartet (PID: \$(cat \$PID_FILE))\" >> \"\$LOG_FILE\"
        return 0
    else
        echo \"\$(date): ❌ Handshake Server Start fehlgeschlagen\" >> \"\$LOG_FILE\"
        return 1
    fi
}

# Kontinuierlicher Health Check
monitor_handshake_server() {
    while true; do
        if ! curl -s http://localhost:\$HANDSHAKE_PORT/health >/dev/null 2>&1; then
            echo \"\$(date): ⚠️ Handshake Server nicht erreichbar - Neustart...\" >> \"\$LOG_FILE\"
            start_handshake_server
        fi
        sleep 30
    done
}

case \"\$1\" in
    start)
        start_handshake_server
        ;;
    monitor)
        start_handshake_server
        monitor_handshake_server
        ;;
    stop)
        pkill -f 'python3.*m1_handshake_server.py' || true
        rm -f \"\$PID_FILE\"
        echo \"\$(date): 🛑 Handshake Server gestoppt\" >> \"\$LOG_FILE\"
        ;;
    status)
        if curl -s http://localhost:\$HANDSHAKE_PORT/health >/dev/null 2>&1; then
            echo \"✅ Handshake Server läuft\"
        else
            echo \"❌ Handshake Server nicht erreichbar\"
        fi
        ;;
    *)
        echo \"Usage: \$0 {start|monitor|stop|status}\"
        exit 1
        ;;
esac
EOF
        chmod +x m1_robust_handshake.sh
    "
    success "Robuster Handshake Server erstellt"
}

# Erstelle Cloudflare Tunnel Manager
create_cloudflare_manager() {
    log "☁️ Erstelle Cloudflare Tunnel Manager auf M1..."
    ssh amonbaumgartner@$M1_HOST "
        cd /Users/amonbaumgartner/Gentleman
        cat > m1_cloudflare_manager.sh << 'EOF'
#!/bin/bash

# Cloudflare Tunnel Manager für M1
TUNNEL_PORT=8765
LOG_FILE=\"/tmp/cloudflare_tunnel.log\"
PID_FILE=\"/tmp/cloudflare_tunnel.pid\"
URL_FILE=\"/tmp/cloudflare_tunnel_url.txt\"

start_tunnel() {
    echo \"\$(date): 🌐 Starte Cloudflare Tunnel...\" >> \"\$LOG_FILE\"
    cd /Users/amonbaumgartner/Gentleman
    
    # Stoppe alte Tunnel
    pkill -f 'cloudflared' || true
    rm -f \"\$URL_FILE\"
    
    # Starte neuen Tunnel
    nohup ./cloudflared tunnel --url http://localhost:\$TUNNEL_PORT >> \"\$LOG_FILE\" 2>&1 &
    echo \$! > \"\$PID_FILE\"
    
    # Warte auf URL
    sleep 15
    grep -o 'https://[a-zA-Z0-9.-]*\\.trycloudflare\\.com' \"\$LOG_FILE\" | tail -1 > \"\$URL_FILE\" 2>/dev/null || true
    
    if [ -s \"\$URL_FILE\" ]; then
        URL=\$(cat \"\$URL_FILE\")
        echo \"\$(date): ✅ Cloudflare Tunnel aktiv: \$URL\" >> \"\$LOG_FILE\"
        echo \"🌐 Öffentliche URL: \$URL\"
        return 0
    else
        echo \"\$(date): ❌ Cloudflare Tunnel Start fehlgeschlagen\" >> \"\$LOG_FILE\"
        return 1
    fi
}

get_tunnel_url() {
    if [ -s \"\$URL_FILE\" ]; then
        cat \"\$URL_FILE\"
    else
        echo \"Keine aktive Tunnel-URL gefunden\"
        return 1
    fi
}

case \"\$1\" in
    start)
        start_tunnel
        ;;
    stop)
        pkill -f 'cloudflared' || true
        rm -f \"\$PID_FILE\" \"\$URL_FILE\"
        echo \"\$(date): 🛑 Cloudflare Tunnel gestoppt\" >> \"\$LOG_FILE\"
        ;;
    status)
        if [ -s \"\$URL_FILE\" ] && pgrep -f 'cloudflared' >/dev/null; then
            echo \"✅ Cloudflare Tunnel läuft: \$(cat \$URL_FILE)\"
        else
            echo \"❌ Cloudflare Tunnel nicht aktiv\"
        fi
        ;;
    url)
        get_tunnel_url
        ;;
    *)
        echo \"Usage: \$0 {start|stop|status|url}\"
        exit 1
        ;;
esac
EOF
        chmod +x m1_cloudflare_manager.sh
    "
    success "Cloudflare Tunnel Manager erstellt"
}

# Erstelle Master Control Script
create_master_control() {
    log "🎛️ Erstelle Master Control Script auf M1..."
    ssh amonbaumgartner@$M1_HOST "
        cd /Users/amonbaumgartner/Gentleman
        cat > m1_master_control.sh << 'EOF'
#!/bin/bash

# GENTLEMAN M1 Master Control
# Zentrales Management für alle M1 Services

LOG_FILE=\"/tmp/m1_master.log\"

log() {
    echo \"\$(date): \$1\" >> \"\$LOG_FILE\"
    echo \"\$1\"
}

start_all_services() {
    log \"🚀 Starte alle M1 Services...\"
    
    # 1. Handshake Server
    ./m1_robust_handshake.sh start
    sleep 5
    
    # 2. Cloudflare Tunnel
    ./m1_cloudflare_manager.sh start
    sleep 10
    
    # 3. Status Check
    log \"📊 Service Status:\"
    ./m1_robust_handshake.sh status
    ./m1_cloudflare_manager.sh status
    
    log \"✅ Alle Services gestartet\"
}

stop_all_services() {
    log \"🛑 Stoppe alle M1 Services...\"
    ./m1_robust_handshake.sh stop
    ./m1_cloudflare_manager.sh stop
    log \"✅ Alle Services gestoppt\"
}

status_all_services() {
    echo \"🤝 GENTLEMAN M1 Services Status\"
    echo \"===============================\"
    echo -n \"Handshake Server: \"
    ./m1_robust_handshake.sh status
    echo -n \"Cloudflare Tunnel: \"
    ./m1_cloudflare_manager.sh status
    
    if [ -f /tmp/cloudflare_tunnel_url.txt ]; then
        echo \"📡 Öffentliche URL: \$(cat /tmp/cloudflare_tunnel_url.txt)\"
    fi
}

case \"\$1\" in
    start)
        start_all_services
        ;;
    stop)
        stop_all_services
        ;;
    restart)
        stop_all_services
        sleep 3
        start_all_services
        ;;
    status)
        status_all_services
        ;;
    *)
        echo \"Usage: \$0 {start|stop|restart|status}\"
        exit 1
        ;;
esac
EOF
        chmod +x m1_master_control.sh
    "
    success "Master Control Script erstellt"
}

# Starte alle Services auf M1
start_m1_services() {
    log "🚀 Starte alle M1 Services..."
    ssh amonbaumgartner@$M1_HOST "
        cd /Users/amonbaumgartner/Gentleman
        ./m1_master_control.sh start
    "
    success "M1 Services gestartet"
}

# Zeige M1 Status und URLs
show_m1_status() {
    log "📊 M1 Status und Informationen:"
    ssh amonbaumgartner@$M1_HOST "
        cd /Users/amonbaumgartner/Gentleman
        ./m1_master_control.sh status
        
        echo
        echo '🌐 Netzwerk-Informationen:'
        echo \"Lokale IP: \$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print \$2}')\"
        echo \"SSH-Zugriff: ssh amonbaumgartner@192.168.68.111\"
        
        if [ -f /tmp/cloudflare_tunnel_url.txt ]; then
            URL=\$(cat /tmp/cloudflare_tunnel_url.txt)
            echo \"📡 Öffentlicher Handshake: \$URL/handshake\"
            echo \"🏥 Öffentlicher Health Check: \$URL/health\"
        fi
    "
}

# Hauptfunktion
main() {
    echo
    echo "🚀 GENTLEMAN M1 Mobile Setup"
    echo "============================"
    echo
    
    create_log_dir
    
    if ! test_ssh_connection; then
        error "SSH-Verbindung fehlgeschlagen. Stelle sicher, dass der M1 Mac erreichbar ist."
        exit 1
    fi
    
    stop_old_services
    install_dependencies
    create_robust_handshake_server
    create_cloudflare_manager
    create_master_control
    start_m1_services
    
    echo
    success "🎉 M1 Mobile Setup abgeschlossen!"
    echo
    
    # Warte kurz und zeige Status
    sleep 5
    show_m1_status
    
    echo
    echo "📱 Mobile Nutzung:"
    echo "- Handshake über öffentliche URL verfügbar"
    echo "- SSH-Zugriff über Heimnetz: ssh amonbaumgartner@192.168.68.111"
    echo "- Lokaler Zugriff: http://192.168.68.111:8765"
    echo
    echo "🔧 Management-Befehle auf M1:"
    echo "- ./m1_master_control.sh {start|stop|restart|status}"
    echo "- ./m1_robust_handshake.sh {start|stop|status}"
    echo "- ./m1_cloudflare_manager.sh {start|stop|status|url}"
    echo
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 

# 🚀 GENTLEMAN M1 Mobile Setup
# ===========================
# Vollständige Mobile-Konfiguration für M1 Mac
# - Handshake Server mit Auto-Restart
# - Cloudflare Tunnel für öffentlichen Zugriff  
# - SSH-Tunnel für Remote-Verwaltung
# - Robuste Netzwerk-Erkennung

set -e

# Konfiguration
M1_HOST="192.168.68.111"
HANDSHAKE_PORT="8765"
SSH_PORT="22"
CLOUDFLARE_TUNNEL_PORT="8765"
LOG_DIR="/tmp/gentleman_mobile"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging Funktion
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

# Erstelle Log-Verzeichnis
create_log_dir() {
    mkdir -p "$LOG_DIR"
}

# Teste SSH-Verbindung zum M1
test_ssh_connection() {
    log "🔍 Teste SSH-Verbindung zum M1 Mac..."
    if ssh -o ConnectTimeout=5 -o BatchMode=yes amonbaumgartner@$M1_HOST "echo 'SSH OK'" >/dev/null 2>&1; then
        success "SSH-Verbindung zum M1 Mac erfolgreich"
        return 0
    else
        error "SSH-Verbindung zum M1 Mac fehlgeschlagen"
        return 1
    fi
}

# Stoppe alte Services auf M1
stop_old_services() {
    log "🛑 Stoppe alte Services auf M1 Mac..."
    ssh amonbaumgartner@$M1_HOST "
        pkill -f 'python3.*handshake' || true
        pkill -f 'cloudflared' || true
        pkill -f 'm1_handshake_server.py' || true
    " 2>/dev/null || true
    success "Alte Services gestoppt"
}

# Installiere Dependencies auf M1
install_dependencies() {
    log "📦 Installiere Dependencies auf M1 Mac..."
    ssh amonbaumgartner@$M1_HOST "
        cd /Users/amonbaumgartner/Gentleman
        
        # Python Dependencies
        python3 -m pip install --user flask requests flask-cors >/dev/null 2>&1 || true
        
        # Cloudflared prüfen/installieren
        if [ ! -f './cloudflared' ]; then
            echo '📥 Lade cloudflared herunter...'
            curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-arm64 -o cloudflared 2>/dev/null || true
            chmod +x cloudflared 2>/dev/null || true
        fi
        
        echo '✅ Dependencies installiert'
    "
    success "Dependencies auf M1 installiert"
}

# Erstelle robustes Handshake Server Script
create_robust_handshake_server() {
    log "🔧 Erstelle robusten Handshake Server auf M1..."
    ssh amonbaumgartner@$M1_HOST "
        cd /Users/amonbaumgartner/Gentleman
        cat > m1_robust_handshake.sh << 'EOF'
#!/bin/bash

# Robuster M1 Handshake Server mit Auto-Restart
HANDSHAKE_PORT=8765
LOG_FILE=\"/tmp/m1_handshake.log\"
PID_FILE=\"/tmp/m1_handshake.pid\"

start_handshake_server() {
    echo \"\$(date): 🚀 Starte M1 Handshake Server...\" >> \"\$LOG_FILE\"
    cd /Users/amonbaumgartner/Gentleman
    
    # Stoppe alte Instanzen
    pkill -f 'python3.*m1_handshake_server.py' || true
    
    # Starte neuen Server
    nohup python3 m1_handshake_server.py --host 0.0.0.0 --port \$HANDSHAKE_PORT >> \"\$LOG_FILE\" 2>&1 &
    echo \$! > \"\$PID_FILE\"
    
    sleep 3
    if curl -s http://localhost:\$HANDSHAKE_PORT/health >/dev/null 2>&1; then
        echo \"\$(date): ✅ Handshake Server gestartet (PID: \$(cat \$PID_FILE))\" >> \"\$LOG_FILE\"
        return 0
    else
        echo \"\$(date): ❌ Handshake Server Start fehlgeschlagen\" >> \"\$LOG_FILE\"
        return 1
    fi
}

# Kontinuierlicher Health Check
monitor_handshake_server() {
    while true; do
        if ! curl -s http://localhost:\$HANDSHAKE_PORT/health >/dev/null 2>&1; then
            echo \"\$(date): ⚠️ Handshake Server nicht erreichbar - Neustart...\" >> \"\$LOG_FILE\"
            start_handshake_server
        fi
        sleep 30
    done
}

case \"\$1\" in
    start)
        start_handshake_server
        ;;
    monitor)
        start_handshake_server
        monitor_handshake_server
        ;;
    stop)
        pkill -f 'python3.*m1_handshake_server.py' || true
        rm -f \"\$PID_FILE\"
        echo \"\$(date): 🛑 Handshake Server gestoppt\" >> \"\$LOG_FILE\"
        ;;
    status)
        if curl -s http://localhost:\$HANDSHAKE_PORT/health >/dev/null 2>&1; then
            echo \"✅ Handshake Server läuft\"
        else
            echo \"❌ Handshake Server nicht erreichbar\"
        fi
        ;;
    *)
        echo \"Usage: \$0 {start|monitor|stop|status}\"
        exit 1
        ;;
esac
EOF
        chmod +x m1_robust_handshake.sh
    "
    success "Robuster Handshake Server erstellt"
}

# Erstelle Cloudflare Tunnel Manager
create_cloudflare_manager() {
    log "☁️ Erstelle Cloudflare Tunnel Manager auf M1..."
    ssh amonbaumgartner@$M1_HOST "
        cd /Users/amonbaumgartner/Gentleman
        cat > m1_cloudflare_manager.sh << 'EOF'
#!/bin/bash

# Cloudflare Tunnel Manager für M1
TUNNEL_PORT=8765
LOG_FILE=\"/tmp/cloudflare_tunnel.log\"
PID_FILE=\"/tmp/cloudflare_tunnel.pid\"
URL_FILE=\"/tmp/cloudflare_tunnel_url.txt\"

start_tunnel() {
    echo \"\$(date): 🌐 Starte Cloudflare Tunnel...\" >> \"\$LOG_FILE\"
    cd /Users/amonbaumgartner/Gentleman
    
    # Stoppe alte Tunnel
    pkill -f 'cloudflared' || true
    rm -f \"\$URL_FILE\"
    
    # Starte neuen Tunnel
    nohup ./cloudflared tunnel --url http://localhost:\$TUNNEL_PORT >> \"\$LOG_FILE\" 2>&1 &
    echo \$! > \"\$PID_FILE\"
    
    # Warte auf URL
    sleep 15
    grep -o 'https://[a-zA-Z0-9.-]*\\.trycloudflare\\.com' \"\$LOG_FILE\" | tail -1 > \"\$URL_FILE\" 2>/dev/null || true
    
    if [ -s \"\$URL_FILE\" ]; then
        URL=\$(cat \"\$URL_FILE\")
        echo \"\$(date): ✅ Cloudflare Tunnel aktiv: \$URL\" >> \"\$LOG_FILE\"
        echo \"🌐 Öffentliche URL: \$URL\"
        return 0
    else
        echo \"\$(date): ❌ Cloudflare Tunnel Start fehlgeschlagen\" >> \"\$LOG_FILE\"
        return 1
    fi
}

get_tunnel_url() {
    if [ -s \"\$URL_FILE\" ]; then
        cat \"\$URL_FILE\"
    else
        echo \"Keine aktive Tunnel-URL gefunden\"
        return 1
    fi
}

case \"\$1\" in
    start)
        start_tunnel
        ;;
    stop)
        pkill -f 'cloudflared' || true
        rm -f \"\$PID_FILE\" \"\$URL_FILE\"
        echo \"\$(date): 🛑 Cloudflare Tunnel gestoppt\" >> \"\$LOG_FILE\"
        ;;
    status)
        if [ -s \"\$URL_FILE\" ] && pgrep -f 'cloudflared' >/dev/null; then
            echo \"✅ Cloudflare Tunnel läuft: \$(cat \$URL_FILE)\"
        else
            echo \"❌ Cloudflare Tunnel nicht aktiv\"
        fi
        ;;
    url)
        get_tunnel_url
        ;;
    *)
        echo \"Usage: \$0 {start|stop|status|url}\"
        exit 1
        ;;
esac
EOF
        chmod +x m1_cloudflare_manager.sh
    "
    success "Cloudflare Tunnel Manager erstellt"
}

# Erstelle Master Control Script
create_master_control() {
    log "🎛️ Erstelle Master Control Script auf M1..."
    ssh amonbaumgartner@$M1_HOST "
        cd /Users/amonbaumgartner/Gentleman
        cat > m1_master_control.sh << 'EOF'
#!/bin/bash

# GENTLEMAN M1 Master Control
# Zentrales Management für alle M1 Services

LOG_FILE=\"/tmp/m1_master.log\"

log() {
    echo \"\$(date): \$1\" >> \"\$LOG_FILE\"
    echo \"\$1\"
}

start_all_services() {
    log \"🚀 Starte alle M1 Services...\"
    
    # 1. Handshake Server
    ./m1_robust_handshake.sh start
    sleep 5
    
    # 2. Cloudflare Tunnel
    ./m1_cloudflare_manager.sh start
    sleep 10
    
    # 3. Status Check
    log \"📊 Service Status:\"
    ./m1_robust_handshake.sh status
    ./m1_cloudflare_manager.sh status
    
    log \"✅ Alle Services gestartet\"
}

stop_all_services() {
    log \"🛑 Stoppe alle M1 Services...\"
    ./m1_robust_handshake.sh stop
    ./m1_cloudflare_manager.sh stop
    log \"✅ Alle Services gestoppt\"
}

status_all_services() {
    echo \"🤝 GENTLEMAN M1 Services Status\"
    echo \"===============================\"
    echo -n \"Handshake Server: \"
    ./m1_robust_handshake.sh status
    echo -n \"Cloudflare Tunnel: \"
    ./m1_cloudflare_manager.sh status
    
    if [ -f /tmp/cloudflare_tunnel_url.txt ]; then
        echo \"📡 Öffentliche URL: \$(cat /tmp/cloudflare_tunnel_url.txt)\"
    fi
}

case \"\$1\" in
    start)
        start_all_services
        ;;
    stop)
        stop_all_services
        ;;
    restart)
        stop_all_services
        sleep 3
        start_all_services
        ;;
    status)
        status_all_services
        ;;
    *)
        echo \"Usage: \$0 {start|stop|restart|status}\"
        exit 1
        ;;
esac
EOF
        chmod +x m1_master_control.sh
    "
    success "Master Control Script erstellt"
}

# Starte alle Services auf M1
start_m1_services() {
    log "🚀 Starte alle M1 Services..."
    ssh amonbaumgartner@$M1_HOST "
        cd /Users/amonbaumgartner/Gentleman
        ./m1_master_control.sh start
    "
    success "M1 Services gestartet"
}

# Zeige M1 Status und URLs
show_m1_status() {
    log "📊 M1 Status und Informationen:"
    ssh amonbaumgartner@$M1_HOST "
        cd /Users/amonbaumgartner/Gentleman
        ./m1_master_control.sh status
        
        echo
        echo '🌐 Netzwerk-Informationen:'
        echo \"Lokale IP: \$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print \$2}')\"
        echo \"SSH-Zugriff: ssh amonbaumgartner@192.168.68.111\"
        
        if [ -f /tmp/cloudflare_tunnel_url.txt ]; then
            URL=\$(cat /tmp/cloudflare_tunnel_url.txt)
            echo \"📡 Öffentlicher Handshake: \$URL/handshake\"
            echo \"🏥 Öffentlicher Health Check: \$URL/health\"
        fi
    "
}

# Hauptfunktion
main() {
    echo
    echo "🚀 GENTLEMAN M1 Mobile Setup"
    echo "============================"
    echo
    
    create_log_dir
    
    if ! test_ssh_connection; then
        error "SSH-Verbindung fehlgeschlagen. Stelle sicher, dass der M1 Mac erreichbar ist."
        exit 1
    fi
    
    stop_old_services
    install_dependencies
    create_robust_handshake_server
    create_cloudflare_manager
    create_master_control
    start_m1_services
    
    echo
    success "🎉 M1 Mobile Setup abgeschlossen!"
    echo
    
    # Warte kurz und zeige Status
    sleep 5
    show_m1_status
    
    echo
    echo "📱 Mobile Nutzung:"
    echo "- Handshake über öffentliche URL verfügbar"
    echo "- SSH-Zugriff über Heimnetz: ssh amonbaumgartner@192.168.68.111"
    echo "- Lokaler Zugriff: http://192.168.68.111:8765"
    echo
    echo "🔧 Management-Befehle auf M1:"
    echo "- ./m1_master_control.sh {start|stop|restart|status}"
    echo "- ./m1_robust_handshake.sh {start|stop|status}"
    echo "- ./m1_cloudflare_manager.sh {start|stop|status|url}"
    echo
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 
 