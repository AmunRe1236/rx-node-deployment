#!/bin/bash

# 🎯 GENTLEMAN I7 Node VPN & Git Setup
# Konfiguriert WireGuard Client und lokalen Git Server Zugriff
# Version: 1.0

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
I7_NODE_IP="192.168.68.105"
I7_NODE_USER="amonbaumgartner"
M1_MAC_IP="192.168.68.111"
M1_MAC_USER="amonbaumgartner"
WIREGUARD_KEYS_DIR="/opt/homebrew/etc/wireguard/keys"
CLIENT_CONFIG_NAME="i7_client"

log_header() {
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║  🎯 GENTLEMAN I7 NODE VPN & GIT SETUP                        ║${NC}"
    echo -e "${PURPLE}║  WireGuard Client + Git Server Access                        ║${NC}"
    echo -e "${PURPLE}║  I7 Node: $I7_NODE_IP                                        ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
}

log() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

# Test SSH connection to I7 Node
test_i7_connection() {
    log_info "🔍 Teste SSH-Verbindung zum I7 Node..."
    
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$I7_NODE_USER@$I7_NODE_IP" 'echo "SSH OK"' 2>/dev/null; then
        log "✅ SSH-Verbindung zum I7 Node erfolgreich"
        return 0
    else
        log_error "❌ SSH-Verbindung zum I7 Node fehlgeschlagen"
        log_info "💡 Prüfe SSH-Key Setup oder verwende: ssh-copy-id $I7_NODE_USER@$I7_NODE_IP"
        return 1
    fi
}

# Generate I7 Node specific WireGuard keys
generate_i7_keys() {
    log_info "🔑 Generiere I7 Node WireGuard Schlüssel..."
    
    if [[ ! -f "$WIREGUARD_KEYS_DIR/i7_private.key" ]]; then
        wg genkey | sudo tee "$WIREGUARD_KEYS_DIR/i7_private.key" > /dev/null
        sudo chmod 600 "$WIREGUARD_KEYS_DIR/i7_private.key"
        sudo cat "$WIREGUARD_KEYS_DIR/i7_private.key" | wg pubkey | sudo tee "$WIREGUARD_KEYS_DIR/i7_public.key" > /dev/null
        log "🔑 I7 Node Schlüssel generiert"
    else
        log "✅ I7 Node Schlüssel bereits vorhanden"
    fi
}

# Create I7 specific WireGuard config
create_i7_config() {
    log_info "⚙️  Erstelle I7 Node WireGuard Konfiguration..."
    
    local i7_private=$(sudo cat "$WIREGUARD_KEYS_DIR/i7_private.key")
    local server_public=$(sudo cat "$WIREGUARD_KEYS_DIR/server_public.key")
    
    # Update our template
    cat > "i7_wireguard_client.conf" << EOF
[Interface]
# GENTLEMAN I7 Node WireGuard Client Configuration
# macOS Intel Client für GENTLEMAN Cluster Zugriff
PrivateKey = $i7_private
Address = 10.0.0.4/24
DNS = 8.8.8.8, 1.1.1.1

[Peer]
# GENTLEMAN Cluster M1 Mac Gateway
PublicKey = $server_public
Endpoint = 46.57.127.25:51820
AllowedIPs = 192.168.68.0/24, 10.0.0.0/24
PersistentKeepalive = 25

# GENTLEMAN Cluster Services über VPN verfügbar:
# M1 Mac (Gateway): ssh amonbaumgartner@192.168.68.111
# RX Node: ssh amo9n11@192.168.68.117
# I7 Node (lokal): ssh amonbaumgartner@192.168.68.105
# 
# Git Daemon: git://192.168.68.111:9418/Gentleman
# GENTLEMAN Protocol: http://192.168.68.117:8008
# LM Studio RX: http://192.168.68.117:1234
# LM Studio I7: http://192.168.68.105:1235
EOF
    
    chmod 644 "i7_wireguard_client.conf"
    log "⚙️  I7 Node WireGuard Konfiguration erstellt"
}

# Update server config to include I7 peer
update_server_config() {
    log_info "🔧 Aktualisiere Server-Konfiguration für I7 Node..."
    
    local i7_public=$(sudo cat "$WIREGUARD_KEYS_DIR/i7_public.key")
    local server_config="/opt/homebrew/etc/wireguard/wg0.conf"
    
    # Check if I7 peer already exists
    if sudo grep -q "$i7_public" "$server_config"; then
        log "✅ I7 Node bereits in Server-Konfiguration vorhanden"
    else
        log_info "📝 Füge I7 Node zur Server-Konfiguration hinzu..."
        
        # Add I7 peer to server config
        sudo tee -a "$server_config" > /dev/null << EOF

# I7 MacBook Pro Node
[Peer]
# I7 Intel MacBook für Remote-Development
PublicKey = $i7_public
AllowedIPs = 10.0.0.4/32
PersistentKeepalive = 25
EOF
        
        log "📝 I7 Node zur Server-Konfiguration hinzugefügt"
    fi
}

# Copy WireGuard config to I7 Node
copy_config_to_i7() {
    log_info "📤 Kopiere WireGuard Konfiguration zum I7 Node..."
    
    # Copy WireGuard config
    if scp -o ConnectTimeout=10 "i7_wireguard_client.conf" "$I7_NODE_USER@$I7_NODE_IP:~/"; then
        log "📤 WireGuard Konfiguration kopiert"
    else
        log_error "❌ Kopieren der WireGuard Konfiguration fehlgeschlagen"
        return 1
    fi
    
    # Install WireGuard on I7 Node (if macOS)
    log_info "🍺 Installiere WireGuard auf I7 Node..."
    ssh "$I7_NODE_USER@$I7_NODE_IP" 'brew list wireguard-tools &>/dev/null || brew install wireguard-tools'
    
    # Setup WireGuard directory on I7
    ssh "$I7_NODE_USER@$I7_NODE_IP" 'sudo mkdir -p /opt/homebrew/etc/wireguard && sudo chown $(whoami):staff /opt/homebrew/etc/wireguard'
    
    # Copy config to proper location
    ssh "$I7_NODE_USER@$I7_NODE_IP" 'cp ~/i7_wireguard_client.conf /opt/homebrew/etc/wireguard/'
    
    log "✅ WireGuard auf I7 Node eingerichtet"
}

# Test Git daemon connection
test_git_daemon() {
    log_info "🔍 Teste Git Daemon Verbindung..."
    
    # Test local git daemon
    if nc -z localhost 9418; then
        log "✅ Lokaler Git Daemon erreichbar (Port 9418)"
    else
        log_warning "⚠️  Lokaler Git Daemon nicht erreichbar - starte ihn..."
        start_git_daemon
    fi
    
    # Test from I7 node
    log_info "🧪 Teste Git Daemon Zugriff vom I7 Node..."
    if ssh "$I7_NODE_USER@$I7_NODE_IP" "nc -z $M1_MAC_IP 9418"; then
        log "✅ Git Daemon vom I7 Node erreichbar"
        return 0
    else
        log_warning "⚠️  Git Daemon vom I7 Node nicht erreichbar"
        return 1
    fi
}

# Start or restart git daemon
start_git_daemon() {
    log_info "🚀 Starte Git Daemon Service..."
    
    # Stop existing daemon
    pkill -f "git daemon" 2>/dev/null || echo "Kein laufender Daemon gefunden"
    
    # Create export file
    touch git-daemon-export-ok
    
    # Start daemon
    git daemon \
        --verbose \
        --export-all \
        --base-path=$(pwd) \
        --reuseaddr \
        --enable=receive-pack \
        --port=9418 &
    
    local daemon_pid=$!
    log "🚀 Git Daemon gestartet (PID: $daemon_pid)"
    
    # Wait and test
    sleep 2
    if nc -z localhost 9418; then
        log "✅ Git Daemon erfolgreich gestartet"
        return 0
    else
        log_error "❌ Git Daemon Start fehlgeschlagen"
        return 1
    fi
}

# Setup Git access on I7 Node
setup_i7_git_access() {
    log_info "📚 Konfiguriere Git-Zugriff auf I7 Node..."
    
    # Create Git access script on I7
    ssh "$I7_NODE_USER@$I7_NODE_IP" 'cat > ~/setup_gentleman_git.sh' << 'EOF'
#!/bin/bash

echo "🎩 GENTLEMAN Git Setup auf I7 Node"
echo "=================================="

# Clone repository from M1 Git daemon
if [[ ! -d ~/Gentleman ]]; then
    echo "📥 Clone GENTLEMAN Repository..."
    git clone git://192.168.68.111:9418/Gentleman ~/Gentleman
    echo "✅ Repository geklont"
else
    echo "📁 Repository bereits vorhanden - aktualisiere..."
    cd ~/Gentleman
    git pull origin master
    echo "✅ Repository aktualisiert"
fi

# Setup remote for future pushes
cd ~/Gentleman
git remote set-url origin git://192.168.68.111:9418/Gentleman
git remote -v

echo "🎉 Git Setup abgeschlossen!"
echo "💡 Verwende: cd ~/Gentleman && git pull"
EOF
    
    # Make script executable
    ssh "$I7_NODE_USER@$I7_NODE_IP" 'chmod +x ~/setup_gentleman_git.sh'
    
    log "📚 Git-Setup Script auf I7 Node erstellt"
}

# Execute setup on I7 Node
execute_i7_setup() {
    log_info "🚀 Führe Setup auf I7 Node aus..."
    
    # Execute Git setup
    ssh "$I7_NODE_USER@$I7_NODE_IP" '~/setup_gentleman_git.sh'
    
    log "✅ Setup auf I7 Node abgeschlossen"
}

# Test complete setup
test_complete_setup() {
    log_info "🧪 Teste vollständiges Setup..."
    
    # Test Git access
    if ssh "$I7_NODE_USER@$I7_NODE_IP" 'cd ~/Gentleman && git log --oneline -1'; then
        log "✅ Git-Zugriff funktioniert"
    else
        log_warning "⚠️  Git-Zugriff Problem"
    fi
    
    # Test WireGuard config
    if ssh "$I7_NODE_USER@$I7_NODE_IP" 'test -f /opt/homebrew/etc/wireguard/i7_wireguard_client.conf'; then
        log "✅ WireGuard Konfiguration vorhanden"
        
        # Provide VPN start instructions
        echo ""
        log_info "📋 I7 Node VPN Start Anweisungen:"
        echo -e "${CYAN}   Auf I7 Node ausführen:${NC}"
        echo -e "${CYAN}   sudo wg-quick up i7_wireguard_client${NC}"
        echo -e "${CYAN}   sudo wg show${NC}"
        echo ""
    else
        log_warning "⚠️  WireGuard Konfiguration fehlt"
    fi
}

# Restart WireGuard server with new config
restart_wireguard_server() {
    log_info "🔄 Neustart WireGuard Server mit I7 Node Konfiguration..."
    
    # Stop current WireGuard
    sudo wg-quick down wg0 2>/dev/null || echo "WireGuard war nicht aktiv"
    
    # Start with updated config
    if sudo wg-quick up wg0; then
        log "✅ WireGuard Server mit I7 Support neugestartet"
        
        # Show status
        log_info "📊 WireGuard Status:"
        sudo wg show
    else
        log_error "❌ WireGuard Neustart fehlgeschlagen"
        return 1
    fi
}

# Main function
main() {
    log_header
    
    log "🚀 Starte I7 Node VPN & Git Setup..."
    
    # Step 1: Test I7 connection
    if ! test_i7_connection; then
        log_error "Setup abgebrochen - I7 Node nicht erreichbar"
        exit 1
    fi
    
    # Step 2: Generate I7 keys
    generate_i7_keys
    
    # Step 3: Create I7 config
    create_i7_config
    
    # Step 4: Update server config
    update_server_config
    
    # Step 5: Copy config to I7
    copy_config_to_i7
    
    # Step 6: Restart WireGuard server
    restart_wireguard_server
    
    # Step 7: Setup Git daemon
    start_git_daemon
    
    # Step 8: Setup Git access on I7
    setup_i7_git_access
    
    # Step 9: Execute setup on I7
    execute_i7_setup
    
    # Step 10: Test complete setup
    test_complete_setup
    
    echo ""
    echo -e "${GREEN}🎉 I7 Node VPN & Git Setup abgeschlossen!${NC}"
    echo ""
    echo -e "${CYAN}📋 Nächste Schritte auf I7 Node:${NC}"
    echo -e "1. 🔐 VPN starten: ${YELLOW}sudo wg-quick up i7_wireguard_client${NC}"
    echo -e "2. 🔍 VPN testen: ${YELLOW}sudo wg show${NC}"
    echo -e "3. 📡 Ping Test: ${YELLOW}ping 192.168.68.111${NC}"
    echo -e "4. 📚 Git verwenden: ${YELLOW}cd ~/Gentleman && git pull${NC}"
    echo ""
    echo -e "${PURPLE}🎯 I7 Node ist jetzt vollständig in das GENTLEMAN Cluster integriert!${NC}"
}

# Command line interface
case "${1:-main}" in
    "main"|"setup")
        main
        ;;
    "test-ssh")
        test_i7_connection
        ;;
    "test-git")
        test_git_daemon
        ;;
    "restart-daemon")
        start_git_daemon
        ;;
    "help"|"-h"|"--help")
        echo "🎯 GENTLEMAN I7 Node VPN & Git Setup"
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  setup        - Vollständiges I7 Setup (Standard)"
        echo "  test-ssh     - Teste SSH-Verbindung zu I7"
        echo "  test-git     - Teste Git Daemon Verbindung"
        echo "  restart-daemon - Starte Git Daemon neu"
        echo "  help         - Zeige diese Hilfe"
        ;;
    *)
        log_error "Unbekannter Befehl: $1"
        echo "Verwende '$0 help' für Hilfe"
        exit 1
        ;;
esac 