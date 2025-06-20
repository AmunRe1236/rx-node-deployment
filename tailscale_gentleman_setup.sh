#!/bin/bash

# GENTLEMAN Tailscale Setup
# Einfache Mesh-VPN-Lösung ohne Port-Freigabe

set -euo pipefail

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

# Prüfe Tailscale Installation
check_tailscale() {
    if command -v tailscale >/dev/null 2>&1; then
        log_success "Tailscale ist bereits installiert"
        tailscale version
        return 0
    else
        log_info "Tailscale nicht gefunden - Installation erforderlich"
        return 1
    fi
}

# Installiere Tailscale auf macOS
install_tailscale_macos() {
    log_info "🍺 Installiere Tailscale über Homebrew..."
    
    if ! command -v brew >/dev/null 2>&1; then
        log_error "Homebrew nicht gefunden. Bitte installiere Homebrew zuerst:"
        echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        exit 1
    fi
    
    brew install tailscale
    log_success "Tailscale installiert"
}

# Starte Tailscale Service
start_tailscale() {
    log_info "🚀 Starte Tailscale..."
    
    # Starte Tailscale Daemon (falls nicht läuft)
    if ! pgrep -f tailscaled >/dev/null 2>&1; then
        log_info "Starte Tailscale Daemon..."
        sudo tailscaled install-system-daemon
    fi
    
    # Prüfe ob bereits verbunden
    if tailscale status | grep -q "logged in"; then
        log_success "Tailscale ist bereits verbunden"
        tailscale status
        return 0
    fi
    
    # Verbinde mit Tailscale
    log_info "Verbinde mit Tailscale Netzwerk..."
    echo ""
    echo -e "${CYAN}🔗 Öffne den folgenden Link in deinem Browser:${NC}"
    
    # Starte Tailscale mit Subnet-Routing für das Heimnetzwerk
    sudo tailscale up --advertise-routes=192.168.68.0/24 --accept-routes
    
    log_success "Tailscale Setup abgeschlossen!"
}

# Prüfe Tailscale Status
check_status() {
    log_info "📊 Tailscale Status:"
    echo ""
    
    if tailscale status | grep -q "logged in"; then
        echo -e "${GREEN}✅ Verbunden mit Tailscale${NC}"
        echo ""
        tailscale status
        echo ""
        
        # Zeige Tailscale IP
        local tailscale_ip
        tailscale_ip=$(tailscale ip -4)
        echo -e "${CYAN}📍 Deine Tailscale IP: $tailscale_ip${NC}"
        
        # Zeige verfügbare Services
        echo ""
        echo -e "${CYAN}🎯 GENTLEMAN Services über Tailscale:${NC}"
        echo "• M1 Handshake Server: http://$tailscale_ip:8765"
        echo "• SSH zu diesem Mac: ssh $(whoami)@$tailscale_ip"
        
    else
        echo -e "${RED}❌ Nicht mit Tailscale verbunden${NC}"
        return 1
    fi
}

# Setup für andere Nodes (RX Node, I7 Laptop)
setup_other_nodes() {
    log_info "🖥️ Setup für andere GENTLEMAN Nodes:"
    echo ""
    echo -e "${CYAN}RX Node (Arch Linux):${NC}"
    echo "curl -fsSL https://tailscale.com/install.sh | sh"
    echo "sudo tailscale up"
    echo ""
    echo -e "${CYAN}I7 Laptop (Ubuntu):${NC}"
    echo "curl -fsSL https://tailscale.com/install.sh | sh"
    echo "sudo tailscale up"
    echo ""
    echo -e "${CYAN}Mobile Geräte:${NC}"
    echo "• iOS: App Store -> Tailscale"
    echo "• Android: Play Store -> Tailscale"
    echo ""
    log_info "💡 Nach Installation auf allen Geräten sind sie automatisch verbunden!"
}

# Erstelle Tailscale Control Scripts
create_control_scripts() {
    log_info "📝 Erstelle Tailscale Control Scripts..."
    
    # Tailscale Status Script
    cat > ./tailscale_status.sh << 'EOF'
#!/bin/bash

# GENTLEMAN Tailscale Status
echo "🌐 GENTLEMAN Tailscale Network Status"
echo "======================================"
echo ""

if tailscale status | grep -q "logged in"; then
    echo "✅ Tailscale: Verbunden"
    echo ""
    
    # Zeige alle Nodes
    echo "📱 Verfügbare Nodes:"
    tailscale status | grep -E "^\s+[0-9]" | while read line; do
        node_name=$(echo "$line" | awk '{print $1}')
        node_ip=$(echo "$line" | awk '{print $2}')
        echo "  • $node_name: $node_ip"
    done
    
    echo ""
    echo "🎯 GENTLEMAN Services:"
    local_ip=$(tailscale ip -4)
    echo "  • M1 Handshake Server: http://$local_ip:8765"
    echo "  • SSH zu diesem Mac: ssh $(whoami)@$local_ip"
    
else
    echo "❌ Tailscale: Nicht verbunden"
    echo "Führe aus: sudo tailscale up"
fi
EOF

    chmod +x ./tailscale_status.sh
    
    # Tailscale Connect Script
    cat > ./tailscale_connect.sh << 'EOF'
#!/bin/bash

# GENTLEMAN Tailscale Quick Connect
echo "🔗 GENTLEMAN Tailscale Connect"
echo "=============================="
echo ""

if [ $# -eq 0 ]; then
    echo "Verwendung: $0 <node-name>"
    echo ""
    echo "Verfügbare Nodes:"
    tailscale status | grep -E "^\s+[0-9]" | while read line; do
        node_name=$(echo "$line" | awk '{print $1}')
        echo "  • $node_name"
    done
    exit 1
fi

node_name="$1"
node_ip=$(tailscale status | grep "$node_name" | awk '{print $2}')

if [ -n "$node_ip" ]; then
    echo "🔐 Verbinde zu $node_name ($node_ip)..."
    ssh "$node_ip"
else
    echo "❌ Node '$node_name' nicht gefunden"
fi
EOF

    chmod +x ./tailscale_connect.sh
    
    log_success "Control Scripts erstellt"
}

# Erweitere hotspot_node_control.sh für Tailscale
update_hotspot_control() {
    log_info "🔄 Erweitere hotspot_node_control.sh für Tailscale..."
    
    # Backup erstellen
    cp hotspot_node_control.sh hotspot_node_control.sh.backup
    
    # Füge Tailscale-Support hinzu
    cat >> hotspot_node_control.sh << 'EOF'

# Tailscale Support
get_tailscale_ip() {
    local node_name="$1"
    tailscale status | grep "$node_name" | awk '{print $2}' | head -1
}

# Tailscale-basierte Kontrolle
tailscale_control() {
    local node="$1"
    local action="$2"
    
    case "$node" in
        "i7")
            local i7_ip
            i7_ip=$(get_tailscale_ip "i7-laptop")
            if [ -n "$i7_ip" ]; then
                log_info "🌐 Verwende Tailscale für I7: $i7_ip"
                case "$action" in
                    "status")
                        curl -s --max-time 5 "http://$i7_ip:8765/health" >/dev/null 2>&1 && echo "✅ I7 erreichbar" || echo "❌ I7 nicht erreichbar"
                        ;;
                    "ssh")
                        ssh "$i7_ip"
                        ;;
                esac
            else
                log_error "I7 nicht im Tailscale Netzwerk gefunden"
            fi
            ;;
        "rx")
            local rx_ip
            rx_ip=$(get_tailscale_ip "archlinux")
            if [ -n "$rx_ip" ]; then
                log_info "🌐 Verwende Tailscale für RX Node: $rx_ip"
                case "$action" in
                    "status")
                        curl -s --max-time 5 "http://$rx_ip:8765/health" >/dev/null 2>&1 && echo "✅ RX Node erreichbar" || echo "❌ RX Node nicht erreichbar"
                        ;;
                    "ssh")
                        ssh "amo9n11@$rx_ip"
                        ;;
                esac
            else
                log_error "RX Node nicht im Tailscale Netzwerk gefunden"
            fi
            ;;
    esac
}
EOF

    log_success "hotspot_node_control.sh erweitert"
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN Tailscale Setup${NC}"
    echo "============================="
    echo ""
    
    log_info "Tailscale löst deine Port-Probleme ohne Router-Konfiguration!"
    echo ""
    
    # Prüfe Installation
    if ! check_tailscale; then
        install_tailscale_macos
    fi
    
    # Starte Tailscale
    start_tailscale
    
    # Prüfe Status
    sleep 2
    check_status
    
    # Erstelle Scripts
    create_control_scripts
    
    # Erweitere bestehende Scripts
    update_hotspot_control
    
    # Setup-Anweisungen für andere Nodes
    setup_other_nodes
    
    echo ""
    log_success "🎉 Tailscale Setup abgeschlossen!"
    echo ""
    echo -e "${CYAN}Nächste Schritte:${NC}"
    echo "1. Installiere Tailscale auf RX Node und I7 Laptop"
    echo "2. Verwende: ./tailscale_status.sh für Network-Status"
    echo "3. Verwende: ./tailscale_connect.sh <node> für SSH"
    echo "4. Alle Geräte sind automatisch verbunden - keine Ports nötig!"
    echo ""
    echo -e "${YELLOW}💡 Vorteile:${NC}"
    echo "• Keine Router-Konfiguration nötig"
    echo "• Funktioniert hinter CGNAT"
    echo "• Automatisches NAT-Traversal"
    echo "• Ende-zu-Ende verschlüsselt"
    echo "• Kostenlos für bis zu 20 Geräte"
}

main "$@" 

# GENTLEMAN Tailscale Setup
# Einfache Mesh-VPN-Lösung ohne Port-Freigabe

set -euo pipefail

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

# Prüfe Tailscale Installation
check_tailscale() {
    if command -v tailscale >/dev/null 2>&1; then
        log_success "Tailscale ist bereits installiert"
        tailscale version
        return 0
    else
        log_info "Tailscale nicht gefunden - Installation erforderlich"
        return 1
    fi
}

# Installiere Tailscale auf macOS
install_tailscale_macos() {
    log_info "🍺 Installiere Tailscale über Homebrew..."
    
    if ! command -v brew >/dev/null 2>&1; then
        log_error "Homebrew nicht gefunden. Bitte installiere Homebrew zuerst:"
        echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        exit 1
    fi
    
    brew install tailscale
    log_success "Tailscale installiert"
}

# Starte Tailscale Service
start_tailscale() {
    log_info "🚀 Starte Tailscale..."
    
    # Starte Tailscale Daemon (falls nicht läuft)
    if ! pgrep -f tailscaled >/dev/null 2>&1; then
        log_info "Starte Tailscale Daemon..."
        sudo tailscaled install-system-daemon
    fi
    
    # Prüfe ob bereits verbunden
    if tailscale status | grep -q "logged in"; then
        log_success "Tailscale ist bereits verbunden"
        tailscale status
        return 0
    fi
    
    # Verbinde mit Tailscale
    log_info "Verbinde mit Tailscale Netzwerk..."
    echo ""
    echo -e "${CYAN}🔗 Öffne den folgenden Link in deinem Browser:${NC}"
    
    # Starte Tailscale mit Subnet-Routing für das Heimnetzwerk
    sudo tailscale up --advertise-routes=192.168.68.0/24 --accept-routes
    
    log_success "Tailscale Setup abgeschlossen!"
}

# Prüfe Tailscale Status
check_status() {
    log_info "📊 Tailscale Status:"
    echo ""
    
    if tailscale status | grep -q "logged in"; then
        echo -e "${GREEN}✅ Verbunden mit Tailscale${NC}"
        echo ""
        tailscale status
        echo ""
        
        # Zeige Tailscale IP
        local tailscale_ip
        tailscale_ip=$(tailscale ip -4)
        echo -e "${CYAN}📍 Deine Tailscale IP: $tailscale_ip${NC}"
        
        # Zeige verfügbare Services
        echo ""
        echo -e "${CYAN}🎯 GENTLEMAN Services über Tailscale:${NC}"
        echo "• M1 Handshake Server: http://$tailscale_ip:8765"
        echo "• SSH zu diesem Mac: ssh $(whoami)@$tailscale_ip"
        
    else
        echo -e "${RED}❌ Nicht mit Tailscale verbunden${NC}"
        return 1
    fi
}

# Setup für andere Nodes (RX Node, I7 Laptop)
setup_other_nodes() {
    log_info "🖥️ Setup für andere GENTLEMAN Nodes:"
    echo ""
    echo -e "${CYAN}RX Node (Arch Linux):${NC}"
    echo "curl -fsSL https://tailscale.com/install.sh | sh"
    echo "sudo tailscale up"
    echo ""
    echo -e "${CYAN}I7 Laptop (Ubuntu):${NC}"
    echo "curl -fsSL https://tailscale.com/install.sh | sh"
    echo "sudo tailscale up"
    echo ""
    echo -e "${CYAN}Mobile Geräte:${NC}"
    echo "• iOS: App Store -> Tailscale"
    echo "• Android: Play Store -> Tailscale"
    echo ""
    log_info "💡 Nach Installation auf allen Geräten sind sie automatisch verbunden!"
}

# Erstelle Tailscale Control Scripts
create_control_scripts() {
    log_info "📝 Erstelle Tailscale Control Scripts..."
    
    # Tailscale Status Script
    cat > ./tailscale_status.sh << 'EOF'
#!/bin/bash

# GENTLEMAN Tailscale Status
echo "🌐 GENTLEMAN Tailscale Network Status"
echo "======================================"
echo ""

if tailscale status | grep -q "logged in"; then
    echo "✅ Tailscale: Verbunden"
    echo ""
    
    # Zeige alle Nodes
    echo "📱 Verfügbare Nodes:"
    tailscale status | grep -E "^\s+[0-9]" | while read line; do
        node_name=$(echo "$line" | awk '{print $1}')
        node_ip=$(echo "$line" | awk '{print $2}')
        echo "  • $node_name: $node_ip"
    done
    
    echo ""
    echo "🎯 GENTLEMAN Services:"
    local_ip=$(tailscale ip -4)
    echo "  • M1 Handshake Server: http://$local_ip:8765"
    echo "  • SSH zu diesem Mac: ssh $(whoami)@$local_ip"
    
else
    echo "❌ Tailscale: Nicht verbunden"
    echo "Führe aus: sudo tailscale up"
fi
EOF

    chmod +x ./tailscale_status.sh
    
    # Tailscale Connect Script
    cat > ./tailscale_connect.sh << 'EOF'
#!/bin/bash

# GENTLEMAN Tailscale Quick Connect
echo "🔗 GENTLEMAN Tailscale Connect"
echo "=============================="
echo ""

if [ $# -eq 0 ]; then
    echo "Verwendung: $0 <node-name>"
    echo ""
    echo "Verfügbare Nodes:"
    tailscale status | grep -E "^\s+[0-9]" | while read line; do
        node_name=$(echo "$line" | awk '{print $1}')
        echo "  • $node_name"
    done
    exit 1
fi

node_name="$1"
node_ip=$(tailscale status | grep "$node_name" | awk '{print $2}')

if [ -n "$node_ip" ]; then
    echo "🔐 Verbinde zu $node_name ($node_ip)..."
    ssh "$node_ip"
else
    echo "❌ Node '$node_name' nicht gefunden"
fi
EOF

    chmod +x ./tailscale_connect.sh
    
    log_success "Control Scripts erstellt"
}

# Erweitere hotspot_node_control.sh für Tailscale
update_hotspot_control() {
    log_info "🔄 Erweitere hotspot_node_control.sh für Tailscale..."
    
    # Backup erstellen
    cp hotspot_node_control.sh hotspot_node_control.sh.backup
    
    # Füge Tailscale-Support hinzu
    cat >> hotspot_node_control.sh << 'EOF'

# Tailscale Support
get_tailscale_ip() {
    local node_name="$1"
    tailscale status | grep "$node_name" | awk '{print $2}' | head -1
}

# Tailscale-basierte Kontrolle
tailscale_control() {
    local node="$1"
    local action="$2"
    
    case "$node" in
        "i7")
            local i7_ip
            i7_ip=$(get_tailscale_ip "i7-laptop")
            if [ -n "$i7_ip" ]; then
                log_info "🌐 Verwende Tailscale für I7: $i7_ip"
                case "$action" in
                    "status")
                        curl -s --max-time 5 "http://$i7_ip:8765/health" >/dev/null 2>&1 && echo "✅ I7 erreichbar" || echo "❌ I7 nicht erreichbar"
                        ;;
                    "ssh")
                        ssh "$i7_ip"
                        ;;
                esac
            else
                log_error "I7 nicht im Tailscale Netzwerk gefunden"
            fi
            ;;
        "rx")
            local rx_ip
            rx_ip=$(get_tailscale_ip "archlinux")
            if [ -n "$rx_ip" ]; then
                log_info "🌐 Verwende Tailscale für RX Node: $rx_ip"
                case "$action" in
                    "status")
                        curl -s --max-time 5 "http://$rx_ip:8765/health" >/dev/null 2>&1 && echo "✅ RX Node erreichbar" || echo "❌ RX Node nicht erreichbar"
                        ;;
                    "ssh")
                        ssh "amo9n11@$rx_ip"
                        ;;
                esac
            else
                log_error "RX Node nicht im Tailscale Netzwerk gefunden"
            fi
            ;;
    esac
}
EOF

    log_success "hotspot_node_control.sh erweitert"
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN Tailscale Setup${NC}"
    echo "============================="
    echo ""
    
    log_info "Tailscale löst deine Port-Probleme ohne Router-Konfiguration!"
    echo ""
    
    # Prüfe Installation
    if ! check_tailscale; then
        install_tailscale_macos
    fi
    
    # Starte Tailscale
    start_tailscale
    
    # Prüfe Status
    sleep 2
    check_status
    
    # Erstelle Scripts
    create_control_scripts
    
    # Erweitere bestehende Scripts
    update_hotspot_control
    
    # Setup-Anweisungen für andere Nodes
    setup_other_nodes
    
    echo ""
    log_success "🎉 Tailscale Setup abgeschlossen!"
    echo ""
    echo -e "${CYAN}Nächste Schritte:${NC}"
    echo "1. Installiere Tailscale auf RX Node und I7 Laptop"
    echo "2. Verwende: ./tailscale_status.sh für Network-Status"
    echo "3. Verwende: ./tailscale_connect.sh <node> für SSH"
    echo "4. Alle Geräte sind automatisch verbunden - keine Ports nötig!"
    echo ""
    echo -e "${YELLOW}💡 Vorteile:${NC}"
    echo "• Keine Router-Konfiguration nötig"
    echo "• Funktioniert hinter CGNAT"
    echo "• Automatisches NAT-Traversal"
    echo "• Ende-zu-Ende verschlüsselt"
    echo "• Kostenlos für bis zu 20 Geräte"
}

main "$@" 
 