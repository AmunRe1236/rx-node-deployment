#!/bin/bash

# GENTLEMAN M1 Mac Tailscale SSH Setup
# Für remote Installation und Konfiguration

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
    echo -e "${GREEN}✅${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
}

# System Info
get_system_info() {
    log "🔍 Sammle M1 Mac System Informationen..."
    
    echo "=== M1 Mac System Info ==="
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
    echo "OS: $(sw_vers -productName) $(sw_vers -productVersion)"
    echo "Architecture: $(uname -m)"
    echo "IP (Local): $(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)"
    echo "=========================="
}

# Homebrew Check/Install
setup_homebrew() {
    log "🍺 Prüfe Homebrew Installation..."
    
    if command -v brew &> /dev/null; then
        success "Homebrew bereits installiert"
        log "📦 Update Homebrew..."
        brew update
    else
        warning "Homebrew nicht gefunden - installiere..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Homebrew to PATH hinzufügen
        if [[ $(uname -m) == 'arm64' ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        
        success "Homebrew installiert"
    fi
}

# Tailscale Installation
install_tailscale() {
    log "🔧 Installiere Tailscale..."
    
    if command -v tailscale &> /dev/null; then
        success "Tailscale bereits installiert"
        log "📦 Update Tailscale..."
        brew upgrade tailscale
    else
        log "📥 Installiere Tailscale via Homebrew..."
        brew install tailscale
        success "Tailscale installiert"
    fi
}

# Tailscale Service Setup
setup_tailscale_service() {
    log "⚙️ Konfiguriere Tailscale Service..."
    
    # Tailscale Service starten
    if ! brew services list | grep tailscale | grep started &> /dev/null; then
        log "🚀 Starte Tailscale Service..."
        brew services start tailscale
        sleep 3
    else
        success "Tailscale Service bereits aktiv"
    fi
    
    # Service Status prüfen
    if brew services list | grep tailscale | grep started &> /dev/null; then
        success "Tailscale Service läuft"
    else
        error "Tailscale Service konnte nicht gestartet werden"
        return 1
    fi
}

# Tailscale Network Join
join_tailscale_network() {
    log "🌐 Verbinde mit Tailscale Netzwerk..."
    
    # Prüfe aktuellen Status
    if tailscale status &> /dev/null; then
        success "Bereits mit Tailscale verbunden"
        tailscale status
        return 0
    fi
    
    # Network Join mit Subnet Routes
    log "🔗 Starte Tailscale up mit Subnet Advertisement..."
    echo ""
    echo "=== WICHTIG ==="
    echo "Tailscale wird jetzt einen Browser öffnen für die Authentifizierung."
    echo "Verwende Account: baumgartneramon@gmail.com"
    echo "==============="
    echo ""
    read -p "Drücke Enter um fortzufahren..."
    
    # Tailscale up mit Home Network Advertisement
    sudo tailscale up --advertise-routes=192.168.68.0/24 --accept-routes
    
    if [ $? -eq 0 ]; then
        success "Tailscale Netzwerk beigetreten"
    else
        error "Fehler beim Tailscale Network Join"
        return 1
    fi
}

# Tailscale Verification
verify_tailscale() {
    log "🧪 Verifiziere Tailscale Setup..."
    
    # Status Check
    if ! tailscale status &> /dev/null; then
        error "Tailscale nicht verbunden"
        return 1
    fi
    
    # IP ermitteln
    TAILSCALE_IP=$(tailscale ip -4)
    if [ -z "$TAILSCALE_IP" ]; then
        error "Keine Tailscale IP erhalten"
        return 1
    fi
    
    success "Tailscale IP: $TAILSCALE_IP"
    
    # Status anzeigen
    echo ""
    echo "=== Tailscale Status ==="
    tailscale status
    echo "========================"
    
    return 0
}

# SSH Konfiguration für Tailscale
setup_ssh_config() {
    log "🔑 Konfiguriere SSH für Tailscale..."
    
    # SSH Config erweitern
    SSH_CONFIG="$HOME/.ssh/config"
    
    # Backup erstellen
    if [ -f "$SSH_CONFIG" ]; then
        cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
        log "SSH Config Backup erstellt"
    fi
    
    # Tailscale SSH Config hinzufügen
    if ! grep -q "# GENTLEMAN Tailscale Config" "$SSH_CONFIG" 2>/dev/null; then
        cat >> "$SSH_CONFIG" << 'EOF'

# GENTLEMAN Tailscale Config
Host m1-tailscale
    HostName 100.96.219.28
    User amon
    IdentityFile ~/.ssh/id_rsa
    Port 22
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host rx-node-tailscale
    HostName 100.x.x.x  # Wird nach RX Node Setup aktualisiert
    User amo9n11
    IdentityFile ~/.ssh/id_rsa
    Port 22
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
        success "SSH Tailscale Config hinzugefügt"
    else
        success "SSH Tailscale Config bereits vorhanden"
    fi
}

# Firewall Konfiguration
setup_firewall() {
    log "🔥 Konfiguriere macOS Firewall für Tailscale..."
    
    # Firewall Status prüfen
    FIREWALL_STATUS=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate)
    
    if echo "$FIREWALL_STATUS" | grep -q "enabled"; then
        log "Firewall ist aktiv - konfiguriere Tailscale Ausnahmen..."
        
        # Tailscale zur Firewall hinzufügen
        sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Tailscale.app/Contents/MacOS/Tailscale
        sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock /Applications/Tailscale.app/Contents/MacOS/Tailscale
        
        success "Firewall für Tailscale konfiguriert"
    else
        success "Firewall ist deaktiviert - keine Konfiguration nötig"
    fi
}

# GENTLEMAN Services Integration
integrate_gentleman_services() {
    log "🤝 Integriere GENTLEMAN Services mit Tailscale..."
    
    # Handshake Server Status prüfen
    if pgrep -f "m1_handshake_server.py" > /dev/null; then
        success "M1 Handshake Server läuft bereits"
    else
        warning "M1 Handshake Server nicht aktiv"
        log "💡 Starte Handshake Server für Tailscale Integration..."
        
        # Handshake Server im Hintergrund starten (falls vorhanden)
        if [ -f "./handshake_m1.sh" ]; then
            nohup ./handshake_m1.sh > /dev/null 2>&1 &
            sleep 5
            
            if pgrep -f "m1_handshake_server.py" > /dev/null; then
                success "M1 Handshake Server gestartet"
            else
                warning "Handshake Server konnte nicht gestartet werden"
            fi
        else
            warning "handshake_m1.sh nicht gefunden"
        fi
    fi
}

# Network Tests
test_network_connectivity() {
    log "🌐 Teste Netzwerk Konnektivität..."
    
    # Lokale IP
    LOCAL_IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
    success "Lokale IP: $LOCAL_IP"
    
    # Tailscale IP
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null)
    if [ -n "$TAILSCALE_IP" ]; then
        success "Tailscale IP: $TAILSCALE_IP"
    else
        error "Keine Tailscale IP verfügbar"
    fi
    
    # iPhone Test (falls erreichbar)
    log "📱 Teste Verbindung zum iPhone..."
    if ping -c 1 -W 3000 100.123.55.36 &> /dev/null; then
        success "iPhone über Tailscale erreichbar"
    else
        warning "iPhone nicht erreichbar (eventuell offline)"
    fi
    
    # Internet Test
    log "🌍 Teste Internet Konnektivität..."
    if ping -c 1 -W 3000 8.8.8.8 &> /dev/null; then
        success "Internet Verbindung OK"
    else
        error "Keine Internet Verbindung"
    fi
}

# Status Scripts erstellen
create_status_scripts() {
    log "📊 Erstelle Tailscale Status Scripts..."
    
    # Tailscale Status Script
    cat > tailscale_m1_status.sh << 'EOF'
#!/bin/bash

# GENTLEMAN M1 Tailscale Status

echo "=== M1 Mac Tailscale Status ==="
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "Datum: $(date)"
echo ""

if command -v tailscale &> /dev/null; then
    echo "✅ Tailscale installiert"
    
    if tailscale status &> /dev/null; then
        echo "✅ Tailscale verbunden"
        echo "IP: $(tailscale ip -4)"
        echo ""
        echo "=== Tailscale Netzwerk ==="
        tailscale status
    else
        echo "❌ Tailscale nicht verbunden"
    fi
else
    echo "❌ Tailscale nicht installiert"
fi

echo ""
echo "=== Netzwerk Info ==="
echo "Lokale IP: $(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)"

echo ""
echo "=== GENTLEMAN Services ==="
if pgrep -f "m1_handshake_server.py" > /dev/null; then
    echo "✅ M1 Handshake Server: Running (PID: $(pgrep -f 'm1_handshake_server.py'))"
else
    echo "❌ M1 Handshake Server: Stopped"
fi

echo "================================"
EOF
    
    chmod +x tailscale_m1_status.sh
    success "tailscale_m1_status.sh erstellt"
    
    # Quick Connect Script
    cat > tailscale_m1_connect.sh << 'EOF'
#!/bin/bash

# GENTLEMAN M1 Tailscale Quick Connect

echo "🔗 GENTLEMAN M1 Tailscale Verbindung..."

if ! tailscale status &> /dev/null; then
    echo "🚀 Starte Tailscale Verbindung..."
    sudo tailscale up --advertise-routes=192.168.68.0/24 --accept-routes
else
    echo "✅ Bereits verbunden"
    tailscale status
fi
EOF
    
    chmod +x tailscale_m1_connect.sh
    success "tailscale_m1_connect.sh erstellt"
}

# Main Setup Function
main() {
    echo "🎯 GENTLEMAN M1 Mac Tailscale SSH Setup"
    echo "======================================="
    
    get_system_info
    echo ""
    
    # Setup Steps
    setup_homebrew || exit 1
    echo ""
    
    install_tailscale || exit 1
    echo ""
    
    setup_tailscale_service || exit 1
    echo ""
    
    join_tailscale_network || exit 1
    echo ""
    
    verify_tailscale || exit 1
    echo ""
    
    setup_ssh_config
    echo ""
    
    setup_firewall
    echo ""
    
    integrate_gentleman_services
    echo ""
    
    test_network_connectivity
    echo ""
    
    create_status_scripts
    echo ""
    
    # Final Status
    echo "🎉 M1 Mac Tailscale Setup abgeschlossen!"
    echo ""
    echo "=== Nächste Schritte ==="
    echo "1. RX Node Setup: Folge GENTLEMAN_Tailscale_Setup_Guide.md"
    echo "2. Status prüfen: ./tailscale_m1_status.sh"
    echo "3. Reconnect: ./tailscale_m1_connect.sh"
    echo ""
    echo "=== Tailscale Info ==="
    echo "Account: baumgartneramon@gmail.com"
    echo "M1 IP: $(tailscale ip -4 2>/dev/null || echo 'N/A')"
    echo "Admin: https://login.tailscale.com/admin/machines"
    echo "======================="
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 

# GENTLEMAN M1 Mac Tailscale SSH Setup
# Für remote Installation und Konfiguration

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
    echo -e "${GREEN}✅${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
}

# System Info
get_system_info() {
    log "🔍 Sammle M1 Mac System Informationen..."
    
    echo "=== M1 Mac System Info ==="
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
    echo "OS: $(sw_vers -productName) $(sw_vers -productVersion)"
    echo "Architecture: $(uname -m)"
    echo "IP (Local): $(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)"
    echo "=========================="
}

# Homebrew Check/Install
setup_homebrew() {
    log "🍺 Prüfe Homebrew Installation..."
    
    if command -v brew &> /dev/null; then
        success "Homebrew bereits installiert"
        log "📦 Update Homebrew..."
        brew update
    else
        warning "Homebrew nicht gefunden - installiere..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Homebrew to PATH hinzufügen
        if [[ $(uname -m) == 'arm64' ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        
        success "Homebrew installiert"
    fi
}

# Tailscale Installation
install_tailscale() {
    log "🔧 Installiere Tailscale..."
    
    if command -v tailscale &> /dev/null; then
        success "Tailscale bereits installiert"
        log "📦 Update Tailscale..."
        brew upgrade tailscale
    else
        log "📥 Installiere Tailscale via Homebrew..."
        brew install tailscale
        success "Tailscale installiert"
    fi
}

# Tailscale Service Setup
setup_tailscale_service() {
    log "⚙️ Konfiguriere Tailscale Service..."
    
    # Tailscale Service starten
    if ! brew services list | grep tailscale | grep started &> /dev/null; then
        log "🚀 Starte Tailscale Service..."
        brew services start tailscale
        sleep 3
    else
        success "Tailscale Service bereits aktiv"
    fi
    
    # Service Status prüfen
    if brew services list | grep tailscale | grep started &> /dev/null; then
        success "Tailscale Service läuft"
    else
        error "Tailscale Service konnte nicht gestartet werden"
        return 1
    fi
}

# Tailscale Network Join
join_tailscale_network() {
    log "🌐 Verbinde mit Tailscale Netzwerk..."
    
    # Prüfe aktuellen Status
    if tailscale status &> /dev/null; then
        success "Bereits mit Tailscale verbunden"
        tailscale status
        return 0
    fi
    
    # Network Join mit Subnet Routes
    log "🔗 Starte Tailscale up mit Subnet Advertisement..."
    echo ""
    echo "=== WICHTIG ==="
    echo "Tailscale wird jetzt einen Browser öffnen für die Authentifizierung."
    echo "Verwende Account: baumgartneramon@gmail.com"
    echo "==============="
    echo ""
    read -p "Drücke Enter um fortzufahren..."
    
    # Tailscale up mit Home Network Advertisement
    sudo tailscale up --advertise-routes=192.168.68.0/24 --accept-routes
    
    if [ $? -eq 0 ]; then
        success "Tailscale Netzwerk beigetreten"
    else
        error "Fehler beim Tailscale Network Join"
        return 1
    fi
}

# Tailscale Verification
verify_tailscale() {
    log "🧪 Verifiziere Tailscale Setup..."
    
    # Status Check
    if ! tailscale status &> /dev/null; then
        error "Tailscale nicht verbunden"
        return 1
    fi
    
    # IP ermitteln
    TAILSCALE_IP=$(tailscale ip -4)
    if [ -z "$TAILSCALE_IP" ]; then
        error "Keine Tailscale IP erhalten"
        return 1
    fi
    
    success "Tailscale IP: $TAILSCALE_IP"
    
    # Status anzeigen
    echo ""
    echo "=== Tailscale Status ==="
    tailscale status
    echo "========================"
    
    return 0
}

# SSH Konfiguration für Tailscale
setup_ssh_config() {
    log "🔑 Konfiguriere SSH für Tailscale..."
    
    # SSH Config erweitern
    SSH_CONFIG="$HOME/.ssh/config"
    
    # Backup erstellen
    if [ -f "$SSH_CONFIG" ]; then
        cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
        log "SSH Config Backup erstellt"
    fi
    
    # Tailscale SSH Config hinzufügen
    if ! grep -q "# GENTLEMAN Tailscale Config" "$SSH_CONFIG" 2>/dev/null; then
        cat >> "$SSH_CONFIG" << 'EOF'

# GENTLEMAN Tailscale Config
Host m1-tailscale
    HostName 100.96.219.28
    User amon
    IdentityFile ~/.ssh/id_rsa
    Port 22
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host rx-node-tailscale
    HostName 100.x.x.x  # Wird nach RX Node Setup aktualisiert
    User amo9n11
    IdentityFile ~/.ssh/id_rsa
    Port 22
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
        success "SSH Tailscale Config hinzugefügt"
    else
        success "SSH Tailscale Config bereits vorhanden"
    fi
}

# Firewall Konfiguration
setup_firewall() {
    log "🔥 Konfiguriere macOS Firewall für Tailscale..."
    
    # Firewall Status prüfen
    FIREWALL_STATUS=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate)
    
    if echo "$FIREWALL_STATUS" | grep -q "enabled"; then
        log "Firewall ist aktiv - konfiguriere Tailscale Ausnahmen..."
        
        # Tailscale zur Firewall hinzufügen
        sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Tailscale.app/Contents/MacOS/Tailscale
        sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock /Applications/Tailscale.app/Contents/MacOS/Tailscale
        
        success "Firewall für Tailscale konfiguriert"
    else
        success "Firewall ist deaktiviert - keine Konfiguration nötig"
    fi
}

# GENTLEMAN Services Integration
integrate_gentleman_services() {
    log "🤝 Integriere GENTLEMAN Services mit Tailscale..."
    
    # Handshake Server Status prüfen
    if pgrep -f "m1_handshake_server.py" > /dev/null; then
        success "M1 Handshake Server läuft bereits"
    else
        warning "M1 Handshake Server nicht aktiv"
        log "💡 Starte Handshake Server für Tailscale Integration..."
        
        # Handshake Server im Hintergrund starten (falls vorhanden)
        if [ -f "./handshake_m1.sh" ]; then
            nohup ./handshake_m1.sh > /dev/null 2>&1 &
            sleep 5
            
            if pgrep -f "m1_handshake_server.py" > /dev/null; then
                success "M1 Handshake Server gestartet"
            else
                warning "Handshake Server konnte nicht gestartet werden"
            fi
        else
            warning "handshake_m1.sh nicht gefunden"
        fi
    fi
}

# Network Tests
test_network_connectivity() {
    log "🌐 Teste Netzwerk Konnektivität..."
    
    # Lokale IP
    LOCAL_IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
    success "Lokale IP: $LOCAL_IP"
    
    # Tailscale IP
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null)
    if [ -n "$TAILSCALE_IP" ]; then
        success "Tailscale IP: $TAILSCALE_IP"
    else
        error "Keine Tailscale IP verfügbar"
    fi
    
    # iPhone Test (falls erreichbar)
    log "📱 Teste Verbindung zum iPhone..."
    if ping -c 1 -W 3000 100.123.55.36 &> /dev/null; then
        success "iPhone über Tailscale erreichbar"
    else
        warning "iPhone nicht erreichbar (eventuell offline)"
    fi
    
    # Internet Test
    log "🌍 Teste Internet Konnektivität..."
    if ping -c 1 -W 3000 8.8.8.8 &> /dev/null; then
        success "Internet Verbindung OK"
    else
        error "Keine Internet Verbindung"
    fi
}

# Status Scripts erstellen
create_status_scripts() {
    log "📊 Erstelle Tailscale Status Scripts..."
    
    # Tailscale Status Script
    cat > tailscale_m1_status.sh << 'EOF'
#!/bin/bash

# GENTLEMAN M1 Tailscale Status

echo "=== M1 Mac Tailscale Status ==="
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "Datum: $(date)"
echo ""

if command -v tailscale &> /dev/null; then
    echo "✅ Tailscale installiert"
    
    if tailscale status &> /dev/null; then
        echo "✅ Tailscale verbunden"
        echo "IP: $(tailscale ip -4)"
        echo ""
        echo "=== Tailscale Netzwerk ==="
        tailscale status
    else
        echo "❌ Tailscale nicht verbunden"
    fi
else
    echo "❌ Tailscale nicht installiert"
fi

echo ""
echo "=== Netzwerk Info ==="
echo "Lokale IP: $(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)"

echo ""
echo "=== GENTLEMAN Services ==="
if pgrep -f "m1_handshake_server.py" > /dev/null; then
    echo "✅ M1 Handshake Server: Running (PID: $(pgrep -f 'm1_handshake_server.py'))"
else
    echo "❌ M1 Handshake Server: Stopped"
fi

echo "================================"
EOF
    
    chmod +x tailscale_m1_status.sh
    success "tailscale_m1_status.sh erstellt"
    
    # Quick Connect Script
    cat > tailscale_m1_connect.sh << 'EOF'
#!/bin/bash

# GENTLEMAN M1 Tailscale Quick Connect

echo "🔗 GENTLEMAN M1 Tailscale Verbindung..."

if ! tailscale status &> /dev/null; then
    echo "🚀 Starte Tailscale Verbindung..."
    sudo tailscale up --advertise-routes=192.168.68.0/24 --accept-routes
else
    echo "✅ Bereits verbunden"
    tailscale status
fi
EOF
    
    chmod +x tailscale_m1_connect.sh
    success "tailscale_m1_connect.sh erstellt"
}

# Main Setup Function
main() {
    echo "🎯 GENTLEMAN M1 Mac Tailscale SSH Setup"
    echo "======================================="
    
    get_system_info
    echo ""
    
    # Setup Steps
    setup_homebrew || exit 1
    echo ""
    
    install_tailscale || exit 1
    echo ""
    
    setup_tailscale_service || exit 1
    echo ""
    
    join_tailscale_network || exit 1
    echo ""
    
    verify_tailscale || exit 1
    echo ""
    
    setup_ssh_config
    echo ""
    
    setup_firewall
    echo ""
    
    integrate_gentleman_services
    echo ""
    
    test_network_connectivity
    echo ""
    
    create_status_scripts
    echo ""
    
    # Final Status
    echo "🎉 M1 Mac Tailscale Setup abgeschlossen!"
    echo ""
    echo "=== Nächste Schritte ==="
    echo "1. RX Node Setup: Folge GENTLEMAN_Tailscale_Setup_Guide.md"
    echo "2. Status prüfen: ./tailscale_m1_status.sh"
    echo "3. Reconnect: ./tailscale_m1_connect.sh"
    echo ""
    echo "=== Tailscale Info ==="
    echo "Account: baumgartneramon@gmail.com"
    echo "M1 IP: $(tailscale ip -4 2>/dev/null || echo 'N/A')"
    echo "Admin: https://login.tailscale.com/admin/machines"
    echo "======================="
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 
 