#!/bin/bash

# GENTLEMAN RX Node Tailscale SSH Setup
# Für remote Installation und Konfiguration auf Arch Linux

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
    log "🔍 Sammle RX Node System Informationen..."
    
    echo "=== RX Node System Info ==="
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "IP (Local): $(ip route get 1 | awk '{print $7}' | head -1)"
    echo "GPU: $(lspci | grep VGA | cut -d':' -f3 | xargs)"
    echo "=========================="
}

# System Update
update_system() {
    log "📦 Aktualisiere Arch Linux System..."
    
    # Pacman Update
    sudo pacman -Syu --noconfirm
    
    if [ $? -eq 0 ]; then
        success "System Update abgeschlossen"
    else
        error "System Update fehlgeschlagen"
        return 1
    fi
}

# Tailscale Installation
install_tailscale() {
    log "🔧 Installiere Tailscale auf Arch Linux..."
    
    # Prüfe ob bereits installiert
    if command -v tailscale &> /dev/null; then
        success "Tailscale bereits installiert"
        log "📦 Update Tailscale..."
        sudo pacman -S tailscale --noconfirm
    else
        log "📥 Installiere Tailscale..."
        sudo pacman -S tailscale --noconfirm
        
        if [ $? -eq 0 ]; then
            success "Tailscale installiert"
        else
            error "Tailscale Installation fehlgeschlagen"
            return 1
        fi
    fi
}

# Tailscale Service Setup
setup_tailscale_service() {
    log "⚙️ Konfiguriere Tailscale Service..."
    
    # Service aktivieren
    sudo systemctl enable tailscaled
    
    # Service starten
    if ! systemctl is-active --quiet tailscaled; then
        log "🚀 Starte Tailscale Service..."
        sudo systemctl start tailscaled
        sleep 3
    else
        success "Tailscale Service bereits aktiv"
    fi
    
    # Service Status prüfen
    if systemctl is-active --quiet tailscaled; then
        success "Tailscale Service läuft"
    else
        error "Tailscale Service konnte nicht gestartet werden"
        systemctl status tailscaled
        return 1
    fi
}

# Tailscale Network Join
join_tailscale_network() {
    log "🌐 Verbinde RX Node mit Tailscale Netzwerk..."
    
    # Prüfe aktuellen Status
    if sudo tailscale status &> /dev/null; then
        success "Bereits mit Tailscale verbunden"
        sudo tailscale status
        return 0
    fi
    
    # Network Join mit Subnet Routes
    log "🔗 Starte Tailscale up mit Route Advertisement..."
    echo ""
    echo "=== WICHTIG ==="
    echo "Tailscale wird jetzt eine Login URL anzeigen."
    echo "Öffne diese URL in einem Browser und logge dich ein mit:"
    echo "Account: baumgartneramon@gmail.com"
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
    if ! sudo tailscale status &> /dev/null; then
        error "Tailscale nicht verbunden"
        return 1
    fi
    
    # IP ermitteln
    TAILSCALE_IP=$(sudo tailscale ip -4)
    if [ -z "$TAILSCALE_IP" ]; then
        error "Keine Tailscale IP erhalten"
        return 1
    fi
    
    success "Tailscale IP: $TAILSCALE_IP"
    
    # Status anzeigen
    echo ""
    echo "=== Tailscale Status ==="
    sudo tailscale status
    echo "========================"
    
    return 0
}

# Main Setup Function
main() {
    echo "🎯 GENTLEMAN RX Node Tailscale SSH Setup"
    echo "========================================"
    
    get_system_info
    echo ""
    
    # Setup Steps
    update_system || exit 1
    echo ""
    
    install_tailscale || exit 1
    echo ""
    
    setup_tailscale_service || exit 1
    echo ""
    
    join_tailscale_network || exit 1
    echo ""
    
    verify_tailscale || exit 1
    echo ""
    
    # Final Status
    echo "🎉 RX Node Tailscale Setup abgeschlossen!"
    echo ""
    echo "=== Tailscale Info ==="
    echo "Account: baumgartneramon@gmail.com"
    echo "RX IP: $(sudo tailscale ip -4 2>/dev/null || echo 'N/A')"
    echo "Admin: https://login.tailscale.com/admin/machines"
    echo "======================="
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi


# GENTLEMAN RX Node Tailscale SSH Setup
# Für remote Installation und Konfiguration auf Arch Linux

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
    log "🔍 Sammle RX Node System Informationen..."
    
    echo "=== RX Node System Info ==="
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "IP (Local): $(ip route get 1 | awk '{print $7}' | head -1)"
    echo "GPU: $(lspci | grep VGA | cut -d':' -f3 | xargs)"
    echo "=========================="
}

# System Update
update_system() {
    log "📦 Aktualisiere Arch Linux System..."
    
    # Pacman Update
    sudo pacman -Syu --noconfirm
    
    if [ $? -eq 0 ]; then
        success "System Update abgeschlossen"
    else
        error "System Update fehlgeschlagen"
        return 1
    fi
}

# Tailscale Installation
install_tailscale() {
    log "🔧 Installiere Tailscale auf Arch Linux..."
    
    # Prüfe ob bereits installiert
    if command -v tailscale &> /dev/null; then
        success "Tailscale bereits installiert"
        log "📦 Update Tailscale..."
        sudo pacman -S tailscale --noconfirm
    else
        log "📥 Installiere Tailscale..."
        sudo pacman -S tailscale --noconfirm
        
        if [ $? -eq 0 ]; then
            success "Tailscale installiert"
        else
            error "Tailscale Installation fehlgeschlagen"
            return 1
        fi
    fi
}

# Tailscale Service Setup
setup_tailscale_service() {
    log "⚙️ Konfiguriere Tailscale Service..."
    
    # Service aktivieren
    sudo systemctl enable tailscaled
    
    # Service starten
    if ! systemctl is-active --quiet tailscaled; then
        log "🚀 Starte Tailscale Service..."
        sudo systemctl start tailscaled
        sleep 3
    else
        success "Tailscale Service bereits aktiv"
    fi
    
    # Service Status prüfen
    if systemctl is-active --quiet tailscaled; then
        success "Tailscale Service läuft"
    else
        error "Tailscale Service konnte nicht gestartet werden"
        systemctl status tailscaled
        return 1
    fi
}

# Tailscale Network Join
join_tailscale_network() {
    log "🌐 Verbinde RX Node mit Tailscale Netzwerk..."
    
    # Prüfe aktuellen Status
    if sudo tailscale status &> /dev/null; then
        success "Bereits mit Tailscale verbunden"
        sudo tailscale status
        return 0
    fi
    
    # Network Join mit Subnet Routes
    log "🔗 Starte Tailscale up mit Route Advertisement..."
    echo ""
    echo "=== WICHTIG ==="
    echo "Tailscale wird jetzt eine Login URL anzeigen."
    echo "Öffne diese URL in einem Browser und logge dich ein mit:"
    echo "Account: baumgartneramon@gmail.com"
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
    if ! sudo tailscale status &> /dev/null; then
        error "Tailscale nicht verbunden"
        return 1
    fi
    
    # IP ermitteln
    TAILSCALE_IP=$(sudo tailscale ip -4)
    if [ -z "$TAILSCALE_IP" ]; then
        error "Keine Tailscale IP erhalten"
        return 1
    fi
    
    success "Tailscale IP: $TAILSCALE_IP"
    
    # Status anzeigen
    echo ""
    echo "=== Tailscale Status ==="
    sudo tailscale status
    echo "========================"
    
    return 0
}

# Main Setup Function
main() {
    echo "🎯 GENTLEMAN RX Node Tailscale SSH Setup"
    echo "========================================"
    
    get_system_info
    echo ""
    
    # Setup Steps
    update_system || exit 1
    echo ""
    
    install_tailscale || exit 1
    echo ""
    
    setup_tailscale_service || exit 1
    echo ""
    
    join_tailscale_network || exit 1
    echo ""
    
    verify_tailscale || exit 1
    echo ""
    
    # Final Status
    echo "🎉 RX Node Tailscale Setup abgeschlossen!"
    echo ""
    echo "=== Tailscale Info ==="
    echo "Account: baumgartneramon@gmail.com"
    echo "RX IP: $(sudo tailscale ip -4 2>/dev/null || echo 'N/A')"
    echo "Admin: https://login.tailscale.com/admin/machines"
    echo "======================="
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

 