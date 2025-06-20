#!/bin/bash

# GENTLEMAN M1 Mac - RX Node SSH Setup & Integration
# Richtet SSH-Zugriff zur RX Node ein und integriert sie ins Cluster

set -euo pipefail

# Konfiguration
SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# GENTLEMAN Netzwerk-Konfiguration
RX_NODE_IP="192.168.68.117"
RX_NODE_USER="amo9n11"
SSH_KEY_NAME="gentleman_key"
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"

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

# Prüfe ob SSH Key existiert
check_ssh_key() {
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        log_error "SSH Key nicht gefunden: $SSH_KEY_PATH"
        log_info "Erstelle SSH Key mit: ssh-keygen -t rsa -b 4096 -f $SSH_KEY_PATH -C 'GENTLEMAN M1 Mac'"
        return 1
    fi
    
    if [[ ! -f "${SSH_KEY_PATH}.pub" ]]; then
        log_error "SSH Public Key nicht gefunden: ${SSH_KEY_PATH}.pub"
        return 1
    fi
    
    log_success "SSH Keys gefunden"
    return 0
}

# Teste Netzwerk-Verbindung zur RX Node
test_network_connection() {
    log_info "🌐 Teste Netzwerk-Verbindung zur RX Node..."
    
    if ping -c 3 -W 2 "$RX_NODE_IP" >/dev/null 2>&1; then
        log_success "RX Node ist über Netzwerk erreichbar ($RX_NODE_IP)"
        return 0
    else
        log_error "RX Node ist nicht erreichbar ($RX_NODE_IP)"
        log_info "Stelle sicher, dass:"
        echo "  • RX Node eingeschaltet ist"
        echo "  • Netzwerk-Setup auf RX Node abgeschlossen ist"
        echo "  • Beide Geräte im gleichen Netzwerk sind"
        return 1
    fi
}

# Kopiere SSH Key zur RX Node
copy_ssh_key() {
    log_info "🔑 Kopiere SSH Key zur RX Node..."
    
    # Teste SSH-Verbindung zuerst mit Passwort
    if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o PasswordAuthentication=yes \
         "$RX_NODE_USER@$RX_NODE_IP" "echo 'SSH Test erfolgreich'" 2>/dev/null; then
        log_error "SSH-Verbindung zur RX Node fehlgeschlagen"
        log_info "Stelle sicher, dass SSH auf der RX Node läuft und der Benutzer '$RX_NODE_USER' existiert"
        return 1
    fi
    
    # Kopiere SSH Key
    if ssh-copy-id -i "${SSH_KEY_PATH}.pub" "$RX_NODE_USER@$RX_NODE_IP"; then
        log_success "SSH Key erfolgreich zur RX Node kopiert"
    else
        log_error "SSH Key konnte nicht kopiert werden"
        return 1
    fi
    
    # Teste Key-basierte Authentifizierung
    if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
       "$RX_NODE_USER@$RX_NODE_IP" "echo 'SSH Key Test erfolgreich'"; then
        log_success "SSH Key-Authentifizierung funktioniert"
        return 0
    else
        log_error "SSH Key-Authentifizierung fehlgeschlagen"
        return 1
    fi
}

# Aktualisiere SSH Config
update_ssh_config() {
    log_info "📝 Aktualisiere SSH Konfiguration..."
    
    local ssh_config="$HOME/.ssh/config"
    
    # Backup der SSH Config
    if [[ -f "$ssh_config" ]]; then
        cp "$ssh_config" "${ssh_config}.backup"
    fi
    
    # Entferne alte RX Node Einträge
    if [[ -f "$ssh_config" ]]; then
        sed -i.bak '/# GENTLEMAN RX Node/,/^$/d' "$ssh_config" 2>/dev/null || true
    fi
    
    # Füge RX Node Konfiguration hinzu
    cat >> "$ssh_config" << EOF

# GENTLEMAN RX Node
Host rx-node
    HostName $RX_NODE_IP
    User $RX_NODE_USER
    IdentityFile $SSH_KEY_PATH
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR

Host $RX_NODE_IP
    User $RX_NODE_USER
    IdentityFile $SSH_KEY_PATH
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
EOF
    
    # Setze korrekte Berechtigungen
    chmod 600 "$ssh_config"
    
    log_success "SSH Konfiguration aktualisiert"
    log_info "Du kannst jetzt 'ssh rx-node' verwenden"
}

# Teste SSH-Verbindung
test_ssh_connection() {
    log_info "🔗 Teste SSH-Verbindung..."
    
    # Teste mit Alias
    if ssh rx-node "hostname && uptime" 2>/dev/null; then
        log_success "SSH-Verbindung über Alias 'rx-node' erfolgreich"
    else
        log_warning "SSH-Verbindung über Alias fehlgeschlagen"
    fi
    
    # Teste direkte IP-Verbindung
    if ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "echo 'Direkte SSH-Verbindung erfolgreich'"; then
        log_success "Direkte SSH-Verbindung erfolgreich"
        return 0
    else
        log_error "Direkte SSH-Verbindung fehlgeschlagen"
        return 1
    fi
}

# Hole RX Node Informationen
get_rx_node_info() {
    log_info "📊 Sammle RX Node Informationen..."
    
    local info_script='
echo "=== RX Node System Information ==="
echo "Hostname: $(hostname)"
echo "IP: $(ip route get 1 | awk "{print \$7}" | head -1)"
echo "MAC: $(ip link show | grep -A1 "state UP" | grep "link/ether" | awk "{print \$2}" | head -1)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d \")"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo "Memory: $(free -h | grep Mem | awk "{print \$3 \"/\" \$2}")"
echo "Disk: $(df -h / | tail -1 | awk "{print \$3 \"/\" \$2 \" (\" \$5 \" used)\"}")"
echo ""
echo "=== Network Information ==="
ip addr show | grep -E "inet |link/ether"
echo ""
echo "=== Services ==="
systemctl is-active sshd NetworkManager ufw 2>/dev/null || echo "Service status check failed"
'
    
    if ssh rx-node "$info_script" 2>/dev/null; then
        log_success "RX Node Informationen erfolgreich abgerufen"
    else
        log_warning "Konnte RX Node Informationen nicht abrufen"
    fi
}

# Aktualisiere M1 Handshake Server für RX Node
update_handshake_server_config() {
    log_info "🔧 Aktualisiere M1 Handshake Server Konfiguration..."
    
    # Prüfe ob M1 Handshake Server läuft
    if ! curl -s --max-time 3 http://localhost:8765/health >/dev/null 2>&1; then
        log_warning "M1 Handshake Server läuft nicht"
        log_info "Starte den Server mit: ./handshake_m1.sh"
        return 1
    fi
    
    # Teste RX Node Endpoints
    if curl -s --max-time 5 http://localhost:8765/admin/rx-node/status >/dev/null 2>&1; then
        log_success "RX Node Endpoints sind verfügbar"
    else
        log_warning "RX Node Endpoints nicht verfügbar - Server-Neustart erforderlich"
    fi
    
    return 0
}

# Teste RX Node Remote Control
test_rx_node_control() {
    log_info "🎯 Teste RX Node Remote Control..."
    
    # Teste das neue M1 RX Node Control Skript
    if [[ -f "./m1_rx_node_control.sh" ]]; then
        log_info "Teste RX Node Status über M1 API..."
        if ./m1_rx_node_control.sh status; then
            log_success "RX Node Remote Control funktioniert"
        else
            log_warning "RX Node Remote Control hat Probleme"
        fi
    else
        log_warning "M1 RX Node Control Skript nicht gefunden"
    fi
}

# Zeige Zusammenfassung
show_summary() {
    echo ""
    echo -e "${PURPLE}🎯 GENTLEMAN RX Node Integration - Zusammenfassung${NC}"
    echo "=================================================="
    echo ""
    
    echo -e "${CYAN}SSH-Zugriff:${NC}"
    echo "• Kurz: ssh rx-node"
    echo "• Lang: ssh $RX_NODE_USER@$RX_NODE_IP"
    echo "• Key: $SSH_KEY_PATH"
    echo ""
    
    echo -e "${CYAN}Remote Control:${NC}"
    echo "• Status: ./m1_rx_node_control.sh status"
    echo "• Herunterfahren: ./m1_rx_node_control.sh shutdown [delay]"
    echo "• Aufwecken: ./m1_rx_node_control.sh wakeup"
    echo ""
    
    echo -e "${CYAN}Alternative Steuerung:${NC}"
    echo "• Über ursprüngliches Skript: ./rx_node_control.sh status"
    echo "• Direkter SSH-Zugriff: ssh rx-node 'sudo shutdown -h now'"
    echo ""
    
    echo -e "${CYAN}M1 Mac als Knotenpunkt:${NC}"
    echo "• M1 Handshake Server steuert RX Node über SSH"
    echo "• API-Endpoints für RX Node verfügbar"
    echo "• Wake-on-LAN für RX Node konfiguriert"
    echo ""
    
    echo -e "${YELLOW}💡 Nächste Schritte:${NC}"
    echo "1. Teste alle Remote-Control-Funktionen"
    echo "2. Integriere RX Node in automatische Überwachung"
    echo "3. Konfiguriere Backup- und Sync-Mechanismen"
    echo ""
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN M1 Mac - RX Node SSH Setup${NC}"
    echo "========================================"
    echo ""
    
    log_info "Starte RX Node SSH Setup und Integration..."
    
    # Prüfungen und Setup
    if ! check_ssh_key; then
        exit 1
    fi
    
    if ! test_network_connection; then
        exit 1
    fi
    
    if ! copy_ssh_key; then
        exit 1
    fi
    
    update_ssh_config
    
    if ! test_ssh_connection; then
        log_error "SSH-Setup fehlgeschlagen"
        exit 1
    fi
    
    get_rx_node_info
    update_handshake_server_config
    test_rx_node_control
    
    echo ""
    log_success "🎉 RX Node SSH Setup und Integration abgeschlossen!"
    
    show_summary
}

# Prüfe Dependencies
if ! command -v ssh > /dev/null 2>&1; then
    log_error "SSH ist nicht installiert"
    exit 1
fi

if ! command -v ssh-copy-id > /dev/null 2>&1; then
    log_error "ssh-copy-id ist nicht installiert"
    exit 1
fi

# Führe Hauptfunktion aus
main "$@" 

# GENTLEMAN M1 Mac - RX Node SSH Setup & Integration
# Richtet SSH-Zugriff zur RX Node ein und integriert sie ins Cluster

set -euo pipefail

# Konfiguration
SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# GENTLEMAN Netzwerk-Konfiguration
RX_NODE_IP="192.168.68.117"
RX_NODE_USER="amo9n11"
SSH_KEY_NAME="gentleman_key"
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"

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

# Prüfe ob SSH Key existiert
check_ssh_key() {
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        log_error "SSH Key nicht gefunden: $SSH_KEY_PATH"
        log_info "Erstelle SSH Key mit: ssh-keygen -t rsa -b 4096 -f $SSH_KEY_PATH -C 'GENTLEMAN M1 Mac'"
        return 1
    fi
    
    if [[ ! -f "${SSH_KEY_PATH}.pub" ]]; then
        log_error "SSH Public Key nicht gefunden: ${SSH_KEY_PATH}.pub"
        return 1
    fi
    
    log_success "SSH Keys gefunden"
    return 0
}

# Teste Netzwerk-Verbindung zur RX Node
test_network_connection() {
    log_info "🌐 Teste Netzwerk-Verbindung zur RX Node..."
    
    if ping -c 3 -W 2 "$RX_NODE_IP" >/dev/null 2>&1; then
        log_success "RX Node ist über Netzwerk erreichbar ($RX_NODE_IP)"
        return 0
    else
        log_error "RX Node ist nicht erreichbar ($RX_NODE_IP)"
        log_info "Stelle sicher, dass:"
        echo "  • RX Node eingeschaltet ist"
        echo "  • Netzwerk-Setup auf RX Node abgeschlossen ist"
        echo "  • Beide Geräte im gleichen Netzwerk sind"
        return 1
    fi
}

# Kopiere SSH Key zur RX Node
copy_ssh_key() {
    log_info "🔑 Kopiere SSH Key zur RX Node..."
    
    # Teste SSH-Verbindung zuerst mit Passwort
    if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o PasswordAuthentication=yes \
         "$RX_NODE_USER@$RX_NODE_IP" "echo 'SSH Test erfolgreich'" 2>/dev/null; then
        log_error "SSH-Verbindung zur RX Node fehlgeschlagen"
        log_info "Stelle sicher, dass SSH auf der RX Node läuft und der Benutzer '$RX_NODE_USER' existiert"
        return 1
    fi
    
    # Kopiere SSH Key
    if ssh-copy-id -i "${SSH_KEY_PATH}.pub" "$RX_NODE_USER@$RX_NODE_IP"; then
        log_success "SSH Key erfolgreich zur RX Node kopiert"
    else
        log_error "SSH Key konnte nicht kopiert werden"
        return 1
    fi
    
    # Teste Key-basierte Authentifizierung
    if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
       "$RX_NODE_USER@$RX_NODE_IP" "echo 'SSH Key Test erfolgreich'"; then
        log_success "SSH Key-Authentifizierung funktioniert"
        return 0
    else
        log_error "SSH Key-Authentifizierung fehlgeschlagen"
        return 1
    fi
}

# Aktualisiere SSH Config
update_ssh_config() {
    log_info "📝 Aktualisiere SSH Konfiguration..."
    
    local ssh_config="$HOME/.ssh/config"
    
    # Backup der SSH Config
    if [[ -f "$ssh_config" ]]; then
        cp "$ssh_config" "${ssh_config}.backup"
    fi
    
    # Entferne alte RX Node Einträge
    if [[ -f "$ssh_config" ]]; then
        sed -i.bak '/# GENTLEMAN RX Node/,/^$/d' "$ssh_config" 2>/dev/null || true
    fi
    
    # Füge RX Node Konfiguration hinzu
    cat >> "$ssh_config" << EOF

# GENTLEMAN RX Node
Host rx-node
    HostName $RX_NODE_IP
    User $RX_NODE_USER
    IdentityFile $SSH_KEY_PATH
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR

Host $RX_NODE_IP
    User $RX_NODE_USER
    IdentityFile $SSH_KEY_PATH
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
EOF
    
    # Setze korrekte Berechtigungen
    chmod 600 "$ssh_config"
    
    log_success "SSH Konfiguration aktualisiert"
    log_info "Du kannst jetzt 'ssh rx-node' verwenden"
}

# Teste SSH-Verbindung
test_ssh_connection() {
    log_info "🔗 Teste SSH-Verbindung..."
    
    # Teste mit Alias
    if ssh rx-node "hostname && uptime" 2>/dev/null; then
        log_success "SSH-Verbindung über Alias 'rx-node' erfolgreich"
    else
        log_warning "SSH-Verbindung über Alias fehlgeschlagen"
    fi
    
    # Teste direkte IP-Verbindung
    if ssh -i "$SSH_KEY_PATH" "$RX_NODE_USER@$RX_NODE_IP" "echo 'Direkte SSH-Verbindung erfolgreich'"; then
        log_success "Direkte SSH-Verbindung erfolgreich"
        return 0
    else
        log_error "Direkte SSH-Verbindung fehlgeschlagen"
        return 1
    fi
}

# Hole RX Node Informationen
get_rx_node_info() {
    log_info "📊 Sammle RX Node Informationen..."
    
    local info_script='
echo "=== RX Node System Information ==="
echo "Hostname: $(hostname)"
echo "IP: $(ip route get 1 | awk "{print \$7}" | head -1)"
echo "MAC: $(ip link show | grep -A1 "state UP" | grep "link/ether" | awk "{print \$2}" | head -1)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d \")"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo "Memory: $(free -h | grep Mem | awk "{print \$3 \"/\" \$2}")"
echo "Disk: $(df -h / | tail -1 | awk "{print \$3 \"/\" \$2 \" (\" \$5 \" used)\"}")"
echo ""
echo "=== Network Information ==="
ip addr show | grep -E "inet |link/ether"
echo ""
echo "=== Services ==="
systemctl is-active sshd NetworkManager ufw 2>/dev/null || echo "Service status check failed"
'
    
    if ssh rx-node "$info_script" 2>/dev/null; then
        log_success "RX Node Informationen erfolgreich abgerufen"
    else
        log_warning "Konnte RX Node Informationen nicht abrufen"
    fi
}

# Aktualisiere M1 Handshake Server für RX Node
update_handshake_server_config() {
    log_info "🔧 Aktualisiere M1 Handshake Server Konfiguration..."
    
    # Prüfe ob M1 Handshake Server läuft
    if ! curl -s --max-time 3 http://localhost:8765/health >/dev/null 2>&1; then
        log_warning "M1 Handshake Server läuft nicht"
        log_info "Starte den Server mit: ./handshake_m1.sh"
        return 1
    fi
    
    # Teste RX Node Endpoints
    if curl -s --max-time 5 http://localhost:8765/admin/rx-node/status >/dev/null 2>&1; then
        log_success "RX Node Endpoints sind verfügbar"
    else
        log_warning "RX Node Endpoints nicht verfügbar - Server-Neustart erforderlich"
    fi
    
    return 0
}

# Teste RX Node Remote Control
test_rx_node_control() {
    log_info "🎯 Teste RX Node Remote Control..."
    
    # Teste das neue M1 RX Node Control Skript
    if [[ -f "./m1_rx_node_control.sh" ]]; then
        log_info "Teste RX Node Status über M1 API..."
        if ./m1_rx_node_control.sh status; then
            log_success "RX Node Remote Control funktioniert"
        else
            log_warning "RX Node Remote Control hat Probleme"
        fi
    else
        log_warning "M1 RX Node Control Skript nicht gefunden"
    fi
}

# Zeige Zusammenfassung
show_summary() {
    echo ""
    echo -e "${PURPLE}🎯 GENTLEMAN RX Node Integration - Zusammenfassung${NC}"
    echo "=================================================="
    echo ""
    
    echo -e "${CYAN}SSH-Zugriff:${NC}"
    echo "• Kurz: ssh rx-node"
    echo "• Lang: ssh $RX_NODE_USER@$RX_NODE_IP"
    echo "• Key: $SSH_KEY_PATH"
    echo ""
    
    echo -e "${CYAN}Remote Control:${NC}"
    echo "• Status: ./m1_rx_node_control.sh status"
    echo "• Herunterfahren: ./m1_rx_node_control.sh shutdown [delay]"
    echo "• Aufwecken: ./m1_rx_node_control.sh wakeup"
    echo ""
    
    echo -e "${CYAN}Alternative Steuerung:${NC}"
    echo "• Über ursprüngliches Skript: ./rx_node_control.sh status"
    echo "• Direkter SSH-Zugriff: ssh rx-node 'sudo shutdown -h now'"
    echo ""
    
    echo -e "${CYAN}M1 Mac als Knotenpunkt:${NC}"
    echo "• M1 Handshake Server steuert RX Node über SSH"
    echo "• API-Endpoints für RX Node verfügbar"
    echo "• Wake-on-LAN für RX Node konfiguriert"
    echo ""
    
    echo -e "${YELLOW}💡 Nächste Schritte:${NC}"
    echo "1. Teste alle Remote-Control-Funktionen"
    echo "2. Integriere RX Node in automatische Überwachung"
    echo "3. Konfiguriere Backup- und Sync-Mechanismen"
    echo ""
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN M1 Mac - RX Node SSH Setup${NC}"
    echo "========================================"
    echo ""
    
    log_info "Starte RX Node SSH Setup und Integration..."
    
    # Prüfungen und Setup
    if ! check_ssh_key; then
        exit 1
    fi
    
    if ! test_network_connection; then
        exit 1
    fi
    
    if ! copy_ssh_key; then
        exit 1
    fi
    
    update_ssh_config
    
    if ! test_ssh_connection; then
        log_error "SSH-Setup fehlgeschlagen"
        exit 1
    fi
    
    get_rx_node_info
    update_handshake_server_config
    test_rx_node_control
    
    echo ""
    log_success "🎉 RX Node SSH Setup und Integration abgeschlossen!"
    
    show_summary
}

# Prüfe Dependencies
if ! command -v ssh > /dev/null 2>&1; then
    log_error "SSH ist nicht installiert"
    exit 1
fi

if ! command -v ssh-copy-id > /dev/null 2>&1; then
    log_error "ssh-copy-id ist nicht installiert"
    exit 1
fi

# Führe Hauptfunktion aus
main "$@" 
 