#!/bin/bash

# GENTLEMAN Tailscale Setup Deployment Script
# Überträgt und führt Setup Scripts auf M1 Mac und RX Node aus

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

# Konfiguration
M1_HOST="192.168.68.111"
M1_USER="amon"
RX_HOST="192.168.68.117"
RX_USER="amo9n11"

# M1 Mac Setup
deploy_m1_setup() {
    log "🍎 Deploye M1 Mac Tailscale Setup..."
    
    # Prüfe M1 Mac Erreichbarkeit
    if ! ping -c 1 -W 3 "$M1_HOST" &> /dev/null; then
        error "M1 Mac ($M1_HOST) nicht erreichbar"
        return 1
    fi
    
    success "M1 Mac erreichbar"
    
    # Script übertragen
    log "📤 Übertrage Setup Script zum M1 Mac..."
    if scp m1_tailscale_ssh_setup.sh "$M1_USER@$M1_HOST:~/"; then
        success "Script erfolgreich übertragen"
    else
        error "Script Übertragung fehlgeschlagen"
        return 1
    fi
    
    # Script ausführbar machen und ausführen
    log "🚀 Führe M1 Mac Setup aus..."
    ssh "$M1_USER@$M1_HOST" "chmod +x ~/m1_tailscale_ssh_setup.sh && ~/m1_tailscale_ssh_setup.sh"
    
    if [ $? -eq 0 ]; then
        success "M1 Mac Setup abgeschlossen"
    else
        error "M1 Mac Setup fehlgeschlagen"
        return 1
    fi
}

# RX Node Setup
deploy_rx_setup() {
    log "🖥️ Deploye RX Node Tailscale Setup..."
    
    # Prüfe RX Node Erreichbarkeit
    if ! ping -c 1 -W 3 "$RX_HOST" &> /dev/null; then
        error "RX Node ($RX_HOST) nicht erreichbar"
        return 1
    fi
    
    success "RX Node erreichbar"
    
    # Script übertragen
    log "📤 Übertrage Setup Script zur RX Node..."
    if scp rx_node_tailscale_ssh_setup.sh "$RX_USER@$RX_HOST:~/"; then
        success "Script erfolgreich übertragen"
    else
        error "Script Übertragung fehlgeschlagen"
        return 1
    fi
    
    # Script ausführbar machen und ausführen
    log "🚀 Führe RX Node Setup aus..."
    ssh "$RX_USER@$RX_HOST" "chmod +x ~/rx_node_tailscale_ssh_setup.sh && ~/rx_node_tailscale_ssh_setup.sh"
    
    if [ $? -eq 0 ]; then
        success "RX Node Setup abgeschlossen"
    else
        error "RX Node Setup fehlgeschlagen"
        return 1
    fi
}

# Lokales M1 Mac Setup (falls bereits auf M1 Mac)
local_m1_setup() {
    log "🍎 Führe lokales M1 Mac Setup aus..."
    
    if [ -f "m1_tailscale_ssh_setup.sh" ]; then
        chmod +x m1_tailscale_ssh_setup.sh
        ./m1_tailscale_ssh_setup.sh
        
        if [ $? -eq 0 ]; then
            success "Lokales M1 Mac Setup abgeschlossen"
        else
            error "Lokales M1 Mac Setup fehlgeschlagen"
            return 1
        fi
    else
        error "m1_tailscale_ssh_setup.sh nicht gefunden"
        return 1
    fi
}

# Netzwerk Status prüfen
check_network_status() {
    log "🌐 Prüfe Netzwerk Status..."
    
    # Aktuelle IP ermitteln
    CURRENT_IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
    success "Aktuelle IP: $CURRENT_IP"
    
    # Prüfe ob wir im Home Network sind
    if echo "$CURRENT_IP" | grep -q "192.168.68"; then
        success "Im Home Network (192.168.68.x)"
        return 0
    elif echo "$CURRENT_IP" | grep -q "172.20.10"; then
        warning "Im Hotspot Modus (172.20.10.x)"
        return 1
    else
        warning "Unbekanntes Netzwerk: $CURRENT_IP"
        return 1
    fi
}

# SSH Keys prüfen
check_ssh_keys() {
    log "🔑 Prüfe SSH Keys..."
    
    if [ -f "$HOME/.ssh/id_rsa" ]; then
        success "SSH Private Key vorhanden"
    else
        warning "SSH Private Key nicht gefunden"
        log "💡 Generiere SSH Key Pair..."
        ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""
        success "SSH Key Pair generiert"
    fi
    
    if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
        success "SSH Public Key vorhanden"
    else
        error "SSH Public Key nicht gefunden"
        return 1
    fi
}

# SSH Keys zu Nodes kopieren
copy_ssh_keys() {
    log "🔐 Kopiere SSH Keys zu den Nodes..."
    
    # M1 Mac (falls nicht lokal)
    if [ "$CURRENT_IP" != "$M1_HOST" ]; then
        log "📋 Kopiere SSH Key zum M1 Mac..."
        ssh-copy-id "$M1_USER@$M1_HOST" 2>/dev/null || warning "SSH Key zum M1 Mac bereits vorhanden oder Fehler"
    fi
    
    # RX Node
    log "📋 Kopiere SSH Key zur RX Node..."
    ssh-copy-id "$RX_USER@$RX_HOST" 2>/dev/null || warning "SSH Key zur RX Node bereits vorhanden oder Fehler"
}

# Post-Setup Verification
verify_setup() {
    log "🧪 Verifiziere Setup..."
    
    # M1 Mac Tailscale Status (falls erreichbar)
    log "🍎 Prüfe M1 Mac Tailscale Status..."
    if ssh "$M1_USER@$M1_HOST" "command -v tailscale &> /dev/null && tailscale status" 2>/dev/null; then
        success "M1 Mac Tailscale aktiv"
    else
        warning "M1 Mac Tailscale Status nicht verfügbar"
    fi
    
    # RX Node Tailscale Status
    log "🖥️ Prüfe RX Node Tailscale Status..."
    if ssh "$RX_USER@$RX_HOST" "command -v tailscale &> /dev/null && sudo tailscale status" 2>/dev/null; then
        success "RX Node Tailscale aktiv"
    else
        warning "RX Node Tailscale Status nicht verfügbar"
    fi
}

# Hilfe anzeigen
show_help() {
    echo "🎯 GENTLEMAN Tailscale Setup Deployment"
    echo "======================================="
    echo ""
    echo "Verwendung: $0 [OPTION]"
    echo ""
    echo "Optionen:"
    echo "  m1          Nur M1 Mac Setup deployen"
    echo "  rx          Nur RX Node Setup deployen"
    echo "  local       Lokales M1 Mac Setup ausführen"
    echo "  all         Beide Nodes setup (Standard)"
    echo "  verify      Nur Verification ausführen"
    echo "  help        Diese Hilfe anzeigen"
    echo ""
    echo "Beispiele:"
    echo "  $0              # Setup auf beiden Nodes"
    echo "  $0 m1           # Nur M1 Mac Setup"
    echo "  $0 rx           # Nur RX Node Setup"
    echo "  $0 local        # Lokales Setup (wenn bereits auf M1 Mac)"
    echo ""
}

# Main Function
main() {
    case "${1:-all}" in
        "m1")
            echo "🎯 GENTLEMAN M1 Mac Tailscale Deployment"
            echo "========================================"
            check_network_status
            check_ssh_keys
            copy_ssh_keys
            deploy_m1_setup
            ;;
        "rx")
            echo "🎯 GENTLEMAN RX Node Tailscale Deployment"
            echo "========================================="
            check_network_status
            check_ssh_keys
            copy_ssh_keys
            deploy_rx_setup
            ;;
        "local")
            echo "🎯 GENTLEMAN Lokales M1 Mac Setup"
            echo "================================"
            local_m1_setup
            ;;
        "all")
            echo "🎯 GENTLEMAN Tailscale Deployment (Alle Nodes)"
            echo "=============================================="
            check_network_status
            check_ssh_keys
            copy_ssh_keys
            echo ""
            deploy_m1_setup
            echo ""
            deploy_rx_setup
            echo ""
            verify_setup
            ;;
        "verify")
            echo "🎯 GENTLEMAN Setup Verification"
            echo "==============================="
            verify_setup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            error "Unbekannte Option: $1"
            show_help
            exit 1
            ;;
    esac
    
    echo ""
    echo "🎉 Deployment abgeschlossen!"
    echo ""
    echo "=== Nächste Schritte ==="
    echo "1. Tailscale Admin Console: https://login.tailscale.com/admin/machines"
    echo "2. Beide Nodes sollten im Tailscale Netzwerk sichtbar sein"
    echo "3. AMD GPU Setup: Folge GENTLEMAN_AMD_GPU_Setup_Guide.md"
    echo "======================="
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 

# GENTLEMAN Tailscale Setup Deployment Script
# Überträgt und führt Setup Scripts auf M1 Mac und RX Node aus

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

# Konfiguration
M1_HOST="192.168.68.111"
M1_USER="amon"
RX_HOST="192.168.68.117"
RX_USER="amo9n11"

# M1 Mac Setup
deploy_m1_setup() {
    log "🍎 Deploye M1 Mac Tailscale Setup..."
    
    # Prüfe M1 Mac Erreichbarkeit
    if ! ping -c 1 -W 3 "$M1_HOST" &> /dev/null; then
        error "M1 Mac ($M1_HOST) nicht erreichbar"
        return 1
    fi
    
    success "M1 Mac erreichbar"
    
    # Script übertragen
    log "📤 Übertrage Setup Script zum M1 Mac..."
    if scp m1_tailscale_ssh_setup.sh "$M1_USER@$M1_HOST:~/"; then
        success "Script erfolgreich übertragen"
    else
        error "Script Übertragung fehlgeschlagen"
        return 1
    fi
    
    # Script ausführbar machen und ausführen
    log "🚀 Führe M1 Mac Setup aus..."
    ssh "$M1_USER@$M1_HOST" "chmod +x ~/m1_tailscale_ssh_setup.sh && ~/m1_tailscale_ssh_setup.sh"
    
    if [ $? -eq 0 ]; then
        success "M1 Mac Setup abgeschlossen"
    else
        error "M1 Mac Setup fehlgeschlagen"
        return 1
    fi
}

# RX Node Setup
deploy_rx_setup() {
    log "🖥️ Deploye RX Node Tailscale Setup..."
    
    # Prüfe RX Node Erreichbarkeit
    if ! ping -c 1 -W 3 "$RX_HOST" &> /dev/null; then
        error "RX Node ($RX_HOST) nicht erreichbar"
        return 1
    fi
    
    success "RX Node erreichbar"
    
    # Script übertragen
    log "📤 Übertrage Setup Script zur RX Node..."
    if scp rx_node_tailscale_ssh_setup.sh "$RX_USER@$RX_HOST:~/"; then
        success "Script erfolgreich übertragen"
    else
        error "Script Übertragung fehlgeschlagen"
        return 1
    fi
    
    # Script ausführbar machen und ausführen
    log "🚀 Führe RX Node Setup aus..."
    ssh "$RX_USER@$RX_HOST" "chmod +x ~/rx_node_tailscale_ssh_setup.sh && ~/rx_node_tailscale_ssh_setup.sh"
    
    if [ $? -eq 0 ]; then
        success "RX Node Setup abgeschlossen"
    else
        error "RX Node Setup fehlgeschlagen"
        return 1
    fi
}

# Lokales M1 Mac Setup (falls bereits auf M1 Mac)
local_m1_setup() {
    log "🍎 Führe lokales M1 Mac Setup aus..."
    
    if [ -f "m1_tailscale_ssh_setup.sh" ]; then
        chmod +x m1_tailscale_ssh_setup.sh
        ./m1_tailscale_ssh_setup.sh
        
        if [ $? -eq 0 ]; then
            success "Lokales M1 Mac Setup abgeschlossen"
        else
            error "Lokales M1 Mac Setup fehlgeschlagen"
            return 1
        fi
    else
        error "m1_tailscale_ssh_setup.sh nicht gefunden"
        return 1
    fi
}

# Netzwerk Status prüfen
check_network_status() {
    log "🌐 Prüfe Netzwerk Status..."
    
    # Aktuelle IP ermitteln
    CURRENT_IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
    success "Aktuelle IP: $CURRENT_IP"
    
    # Prüfe ob wir im Home Network sind
    if echo "$CURRENT_IP" | grep -q "192.168.68"; then
        success "Im Home Network (192.168.68.x)"
        return 0
    elif echo "$CURRENT_IP" | grep -q "172.20.10"; then
        warning "Im Hotspot Modus (172.20.10.x)"
        return 1
    else
        warning "Unbekanntes Netzwerk: $CURRENT_IP"
        return 1
    fi
}

# SSH Keys prüfen
check_ssh_keys() {
    log "🔑 Prüfe SSH Keys..."
    
    if [ -f "$HOME/.ssh/id_rsa" ]; then
        success "SSH Private Key vorhanden"
    else
        warning "SSH Private Key nicht gefunden"
        log "💡 Generiere SSH Key Pair..."
        ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""
        success "SSH Key Pair generiert"
    fi
    
    if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
        success "SSH Public Key vorhanden"
    else
        error "SSH Public Key nicht gefunden"
        return 1
    fi
}

# SSH Keys zu Nodes kopieren
copy_ssh_keys() {
    log "🔐 Kopiere SSH Keys zu den Nodes..."
    
    # M1 Mac (falls nicht lokal)
    if [ "$CURRENT_IP" != "$M1_HOST" ]; then
        log "📋 Kopiere SSH Key zum M1 Mac..."
        ssh-copy-id "$M1_USER@$M1_HOST" 2>/dev/null || warning "SSH Key zum M1 Mac bereits vorhanden oder Fehler"
    fi
    
    # RX Node
    log "📋 Kopiere SSH Key zur RX Node..."
    ssh-copy-id "$RX_USER@$RX_HOST" 2>/dev/null || warning "SSH Key zur RX Node bereits vorhanden oder Fehler"
}

# Post-Setup Verification
verify_setup() {
    log "🧪 Verifiziere Setup..."
    
    # M1 Mac Tailscale Status (falls erreichbar)
    log "🍎 Prüfe M1 Mac Tailscale Status..."
    if ssh "$M1_USER@$M1_HOST" "command -v tailscale &> /dev/null && tailscale status" 2>/dev/null; then
        success "M1 Mac Tailscale aktiv"
    else
        warning "M1 Mac Tailscale Status nicht verfügbar"
    fi
    
    # RX Node Tailscale Status
    log "🖥️ Prüfe RX Node Tailscale Status..."
    if ssh "$RX_USER@$RX_HOST" "command -v tailscale &> /dev/null && sudo tailscale status" 2>/dev/null; then
        success "RX Node Tailscale aktiv"
    else
        warning "RX Node Tailscale Status nicht verfügbar"
    fi
}

# Hilfe anzeigen
show_help() {
    echo "🎯 GENTLEMAN Tailscale Setup Deployment"
    echo "======================================="
    echo ""
    echo "Verwendung: $0 [OPTION]"
    echo ""
    echo "Optionen:"
    echo "  m1          Nur M1 Mac Setup deployen"
    echo "  rx          Nur RX Node Setup deployen"
    echo "  local       Lokales M1 Mac Setup ausführen"
    echo "  all         Beide Nodes setup (Standard)"
    echo "  verify      Nur Verification ausführen"
    echo "  help        Diese Hilfe anzeigen"
    echo ""
    echo "Beispiele:"
    echo "  $0              # Setup auf beiden Nodes"
    echo "  $0 m1           # Nur M1 Mac Setup"
    echo "  $0 rx           # Nur RX Node Setup"
    echo "  $0 local        # Lokales Setup (wenn bereits auf M1 Mac)"
    echo ""
}

# Main Function
main() {
    case "${1:-all}" in
        "m1")
            echo "🎯 GENTLEMAN M1 Mac Tailscale Deployment"
            echo "========================================"
            check_network_status
            check_ssh_keys
            copy_ssh_keys
            deploy_m1_setup
            ;;
        "rx")
            echo "🎯 GENTLEMAN RX Node Tailscale Deployment"
            echo "========================================="
            check_network_status
            check_ssh_keys
            copy_ssh_keys
            deploy_rx_setup
            ;;
        "local")
            echo "🎯 GENTLEMAN Lokales M1 Mac Setup"
            echo "================================"
            local_m1_setup
            ;;
        "all")
            echo "🎯 GENTLEMAN Tailscale Deployment (Alle Nodes)"
            echo "=============================================="
            check_network_status
            check_ssh_keys
            copy_ssh_keys
            echo ""
            deploy_m1_setup
            echo ""
            deploy_rx_setup
            echo ""
            verify_setup
            ;;
        "verify")
            echo "🎯 GENTLEMAN Setup Verification"
            echo "==============================="
            verify_setup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            error "Unbekannte Option: $1"
            show_help
            exit 1
            ;;
    esac
    
    echo ""
    echo "🎉 Deployment abgeschlossen!"
    echo ""
    echo "=== Nächste Schritte ==="
    echo "1. Tailscale Admin Console: https://login.tailscale.com/admin/machines"
    echo "2. Beide Nodes sollten im Tailscale Netzwerk sichtbar sein"
    echo "3. AMD GPU Setup: Folge GENTLEMAN_AMD_GPU_Setup_Guide.md"
    echo "======================="
}

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 
 