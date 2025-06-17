#!/bin/bash

# 🎩 GENTLEMAN - RX Node Nebula Setup
# ═══════════════════════════════════════════════════════════════
# Automatisches Setup der Nebula VPN-Konfiguration für RX Node

set -e

# 🎨 Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 📝 Logging
log_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_step() { echo -e "${BLUE}🔧 $1${NC}"; }

# 🎩 Banner
print_banner() {
    echo -e "${PURPLE}"
    echo "🎩 GENTLEMAN - RX Node Nebula Setup"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${WHITE}🌐 Konfiguriere Nebula VPN für LLM Server${NC}"
    echo ""
}

# 📁 Verzeichnisse
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
NEBULA_DIR="$PROJECT_ROOT/nebula/rx-node"
SERVICE_FILE="$NEBULA_DIR/nebula-rx.service"

# 🔍 Voraussetzungen prüfen
check_prerequisites() {
    log_step "Prüfe Voraussetzungen..."
    
    # Nebula installiert?
    if ! command -v nebula &> /dev/null; then
        log_error "Nebula ist nicht installiert!"
        log_info "Installiere mit: sudo pacman -S nebula"
        exit 1
    fi
    
    # Root-Rechte für systemd?
    if [[ $EUID -ne 0 ]] && [[ "$1" != "--no-service" ]]; then
        log_warning "Root-Rechte erforderlich für systemd Service"
        log_info "Führe aus: sudo $0"
        log_info "Oder verwende: $0 --no-service"
        exit 1
    fi
    
    # Zertifikate vorhanden?
    if [[ ! -f "$NEBULA_DIR/ca.crt" ]] || [[ ! -f "$NEBULA_DIR/rx-node.crt" ]]; then
        log_error "Nebula-Zertifikate nicht gefunden!"
        log_info "Führe zuerst aus: make detect-hardware"
        exit 1
    fi
    
    log_success "Voraussetzungen erfüllt"
}

# 🔧 Konfiguration validieren
validate_config() {
    log_step "Validiere Nebula-Konfiguration..."
    
    cd "$NEBULA_DIR"
    
    # Konfiguration testen
    if nebula -config config.yml -test; then
        log_success "Nebula-Konfiguration ist gültig"
    else
        log_error "Nebula-Konfiguration ist ungültig!"
        exit 1
    fi
    
    # Zertifikat-Info anzeigen
    log_info "Zertifikat-Informationen:"
    nebula-cert print -path rx-node.crt | grep -E "(Name|Groups|Ips|Not After)"
}

# 🔥 Firewall konfigurieren
setup_firewall() {
    log_step "Konfiguriere Firewall für Nebula..."
    
    # iptables Regeln für Nebula
    if command -v iptables &> /dev/null; then
        # Nebula Interface erlauben
        iptables -A INPUT -i nebula1 -j ACCEPT 2>/dev/null || true
        iptables -A OUTPUT -o nebula1 -j ACCEPT 2>/dev/null || true
        
        # Nebula UDP Port erlauben
        iptables -A INPUT -p udp --dport 4242 -j ACCEPT 2>/dev/null || true
        iptables -A OUTPUT -p udp --sport 4242 -j ACCEPT 2>/dev/null || true
        
        log_success "iptables Regeln hinzugefügt"
    fi
    
    # ufw Regeln (falls installiert)
    if command -v ufw &> /dev/null; then
        ufw allow 4242/udp comment "Nebula VPN" 2>/dev/null || true
        log_success "ufw Regeln hinzugefügt"
    fi
}

# 🔧 Systemd Service installieren
install_service() {
    log_step "Installiere systemd Service..."
    
    # Service-Datei kopieren
    cp "$SERVICE_FILE" /etc/systemd/system/
    
    # systemd neu laden
    systemctl daemon-reload
    
    # Service aktivieren
    systemctl enable nebula-rx.service
    
    log_success "systemd Service installiert und aktiviert"
}

# 🚀 Nebula starten
start_nebula() {
    log_step "Starte Nebula VPN..."
    
    if [[ "$1" == "--no-service" ]]; then
        # Manueller Start für Tests
        log_info "Starte Nebula manuell (Strg+C zum Beenden)..."
        cd "$NEBULA_DIR"
        nebula -config config.yml
    else
        # Service starten
        systemctl start nebula-rx.service
        
        # Status prüfen
        sleep 2
        if systemctl is-active --quiet nebula-rx.service; then
            log_success "Nebula Service läuft"
            
            # Interface prüfen
            if ip addr show nebula1 &>/dev/null; then
                NEBULA_IP=$(ip addr show nebula1 | grep -oP 'inet \K[\d.]+')
                log_success "Nebula Interface: nebula1 ($NEBULA_IP)"
            fi
        else
            log_error "Nebula Service konnte nicht gestartet werden"
            log_info "Prüfe Logs: journalctl -u nebula-rx.service -f"
            exit 1
        fi
    fi
}

# 🧪 Konnektivität testen
test_connectivity() {
    log_step "Teste Nebula-Konnektivität..."
    
    # Warte auf Interface
    for i in {1..10}; do
        if ip addr show nebula1 &>/dev/null; then
            break
        fi
        sleep 1
    done
    
    if ! ip addr show nebula1 &>/dev/null; then
        log_warning "Nebula Interface nicht verfügbar"
        return 1
    fi
    
    # Lighthouse ping
    if ping -c 1 -W 5 192.168.100.1 &>/dev/null; then
        log_success "Lighthouse erreichbar (192.168.100.1)"
    else
        log_warning "Lighthouse nicht erreichbar"
    fi
    
    # Andere Nodes testen (falls verfügbar)
    for node_ip in 192.168.100.20 192.168.100.30; do
        if ping -c 1 -W 2 "$node_ip" &>/dev/null; then
            log_success "Node $node_ip erreichbar"
        else
            log_info "Node $node_ip nicht verfügbar"
        fi
    done
}

# 📊 Status anzeigen
show_status() {
    echo ""
    log_success "🎩 RX Node Nebula Setup abgeschlossen!"
    echo ""
    echo -e "${WHITE}📊 Nebula Status:${NC}"
    
    if systemctl is-active --quiet nebula-rx.service 2>/dev/null; then
        echo -e "${GREEN}  Service:${NC} Aktiv"
    else
        echo -e "${YELLOW}  Service:${NC} Inaktiv"
    fi
    
    if ip addr show nebula1 &>/dev/null; then
        NEBULA_IP=$(ip addr show nebula1 | grep -oP 'inet \K[\d.]+' || echo "Unbekannt")
        echo -e "${GREEN}  Interface:${NC} nebula1 ($NEBULA_IP)"
    else
        echo -e "${YELLOW}  Interface:${NC} Nicht verfügbar"
    fi
    
    echo ""
    echo -e "${WHITE}🎯 RX Node Konfiguration:${NC}"
    echo -e "${CYAN}  Node ID:${NC} rx-node"
    echo -e "${CYAN}  IP-Adresse:${NC} 192.168.100.10/24"
    echo -e "${CYAN}  Rolle:${NC} LLM Server"
    echo -e "${CYAN}  Gruppen:${NC} llm-servers, gpu-nodes"
    echo ""
    echo -e "${WHITE}📋 Nützliche Befehle:${NC}"
    echo -e "${CYAN}  Status:${NC} systemctl status nebula-rx"
    echo -e "${CYAN}  Logs:${NC} journalctl -u nebula-rx -f"
    echo -e "${CYAN}  Stoppen:${NC} sudo systemctl stop nebula-rx"
    echo -e "${CYAN}  Neustarten:${NC} sudo systemctl restart nebula-rx"
    echo ""
}

# 🎯 Hauptfunktion
main() {
    print_banner
    
    # Parameter verarbeiten
    NO_SERVICE=false
    if [[ "$1" == "--no-service" ]]; then
        NO_SERVICE=true
        log_info "Service-Installation übersprungen"
    fi
    
    # Setup-Schritte
    check_prerequisites "$1"
    validate_config
    
    if [[ "$NO_SERVICE" == false ]]; then
        setup_firewall
        install_service
        start_nebula
        test_connectivity
    else
        log_info "Manuelle Konfiguration - Service nicht installiert"
        start_nebula --no-service
    fi
    
    show_status
}

# 🎯 Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 