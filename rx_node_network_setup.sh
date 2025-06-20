#!/bin/bash

# GENTLEMAN RX Node Network & SSH Setup Script
# Konfiguriert die RX Node für das GENTLEMAN Cluster

set -euo pipefail

# Konfiguration
SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# GENTLEMAN Netzwerk-Konfiguration
M1_MAC_IP="192.168.68.111"
I7_LAPTOP_IP="192.168.68.105"
RX_NODE_IP="192.168.68.117"
NETWORK_SUBNET="192.168.68.0/24"
GATEWAY_IP="192.168.68.1"
DNS_SERVERS="8.8.8.8,8.8.4.4"

# SSH Konfiguration
SSH_USER="amo9n11"
SSH_KEY_NAME="gentleman_key"
SSH_PORT="22"

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

# Prüfe Root-Rechte
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Dieses Skript muss als root ausgeführt werden"
        echo "Verwende: sudo $0"
        exit 1
    fi
}

# Prüfe Arch Linux
check_arch_linux() {
    if ! command -v pacman > /dev/null 2>&1; then
        log_error "Dieses Skript ist für Arch Linux konzipiert"
        exit 1
    fi
    log_success "Arch Linux erkannt"
}

# Aktualisiere System
update_system() {
    log_info "🔄 Aktualisiere System-Pakete..."
    
    pacman -Syu --noconfirm
    
    # Installiere benötigte Pakete
    local packages=(
        "openssh"
        "networkmanager"
        "ethtool"
        "net-tools"
        "iproute2"
        "bind-tools"
        "curl"
        "wget"
        "git"
        "python"
        "python-pip"
        "jq"
        "htop"
        "vim"
        "nano"
    )
    
    log_info "📦 Installiere benötigte Pakete..."
    pacman -S --needed --noconfirm "${packages[@]}"
    
    log_success "System aktualisiert und Pakete installiert"
}

# Konfiguriere Netzwerk
setup_network() {
    log_info "🌐 Konfiguriere Netzwerk..."
    
    # Aktiviere und starte NetworkManager
    systemctl enable NetworkManager
    systemctl start NetworkManager
    
    # Finde primäres Netzwerk-Interface
    local interface
    interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    if [[ -z "$interface" ]]; then
        log_error "Kein Netzwerk-Interface gefunden"
        return 1
    fi
    
    log_info "📡 Verwende Interface: $interface"
    
    # Erstelle NetworkManager-Konfiguration
    cat > "/etc/NetworkManager/system-connections/GENTLEMAN-Network.nmconnection" << EOF
[connection]
id=GENTLEMAN-Network
uuid=$(uuidgen)
type=ethernet
interface-name=$interface
autoconnect=true

[ethernet]

[ipv4]
method=manual
addresses=$RX_NODE_IP/24
gateway=$GATEWAY_IP
dns=$DNS_SERVERS

[ipv6]
method=auto

[proxy]
EOF
    
    # Setze Berechtigungen
    chmod 600 "/etc/NetworkManager/system-connections/GENTLEMAN-Network.nmconnection"
    
    # Lade Konfiguration neu
    nmcli connection reload
    
    # Aktiviere Verbindung
    nmcli connection up "GENTLEMAN-Network" || true
    
    log_success "Netzwerk konfiguriert: $RX_NODE_IP"
}

# Konfiguriere SSH Server
setup_ssh_server() {
    log_info "🔐 Konfiguriere SSH Server..."
    
    # Backup der Original-Konfiguration
    if [[ -f /etc/ssh/sshd_config ]]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    fi
    
    # Erstelle sichere SSH-Konfiguration
    cat > /etc/ssh/sshd_config << 'EOF'
# GENTLEMAN SSH Server Configuration

# Basic Settings
Port 22
Protocol 2
AddressFamily any
ListenAddress 0.0.0.0

# Host Keys
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Security Settings
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
UsePAM yes

# Connection Settings
X11Forwarding no
AllowTcpForwarding yes
GatewayPorts no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 10

# Logging
SyslogFacility AUTH
LogLevel INFO

# SFTP Subsystem
Subsystem sftp /usr/lib/ssh/sftp-server

# Allow specific users
AllowUsers amo9n11

# Banner
Banner /etc/ssh/banner
EOF
    
    # Erstelle SSH Banner
    cat > /etc/ssh/banner << 'EOF'
=====================================
    GENTLEMAN RX Node
    Authorized Access Only
=====================================
EOF
    
    # Generiere Host Keys falls nicht vorhanden
    ssh-keygen -A
    
    # Aktiviere und starte SSH
    systemctl enable sshd
    systemctl restart sshd
    
    log_success "SSH Server konfiguriert und gestartet"
}

# Erstelle GENTLEMAN Benutzer
setup_user() {
    log_info "👤 Konfiguriere Benutzer '$SSH_USER'..."
    
    # Erstelle Benutzer falls nicht vorhanden
    if ! id "$SSH_USER" &>/dev/null; then
        useradd -m -s /bin/bash -G wheel "$SSH_USER"
        log_info "Benutzer '$SSH_USER' erstellt"
    else
        log_info "Benutzer '$SSH_USER' existiert bereits"
    fi
    
    # Erstelle SSH-Verzeichnis
    local ssh_dir="/home/$SSH_USER/.ssh"
    mkdir -p "$ssh_dir"
    
    # Setze Berechtigungen
    chown "$SSH_USER:$SSH_USER" "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Erstelle authorized_keys falls nicht vorhanden
    touch "$ssh_dir/authorized_keys"
    chown "$SSH_USER:$SSH_USER" "$ssh_dir/authorized_keys"
    chmod 600 "$ssh_dir/authorized_keys"
    
    log_success "Benutzer '$SSH_USER' konfiguriert"
}

# Konfiguriere Wake-on-LAN
setup_wake_on_lan() {
    log_info "🔋 Konfiguriere Wake-on-LAN..."
    
    # Finde primäres Netzwerk-Interface
    local interface
    interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    if [[ -z "$interface" ]]; then
        log_warning "Kein Netzwerk-Interface für Wake-on-LAN gefunden"
        return 1
    fi
    
    # Aktiviere Wake-on-LAN
    ethtool -s "$interface" wol g 2>/dev/null || log_warning "Wake-on-LAN konnte nicht aktiviert werden"
    
    # Erstelle systemd Service für Wake-on-LAN
    cat > /etc/systemd/system/wake-on-lan.service << EOF
[Unit]
Description=Enable Wake-on-LAN for $interface
Requires=network.target
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/ethtool -s $interface wol g
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
    
    # Aktiviere Service
    systemctl enable wake-on-lan.service
    systemctl start wake-on-lan.service
    
    # Zeige aktuelle WoL-Einstellungen
    local wol_status
    wol_status=$(ethtool "$interface" | grep "Wake-on" || echo "Wake-on: Unbekannt")
    log_info "Wake-on-LAN Status: $wol_status"
    
    log_success "Wake-on-LAN konfiguriert"
}

# Konfiguriere Firewall
setup_firewall() {
    log_info "🔥 Konfiguriere Firewall..."
    
    # Installiere ufw falls nicht vorhanden
    pacman -S --needed --noconfirm ufw
    
    # Aktiviere ufw
    systemctl enable ufw
    
    # Setze Standard-Regeln
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Erlaube SSH
    ufw allow ssh
    
    # Erlaube Verbindungen von GENTLEMAN Nodes
    ufw allow from "$M1_MAC_IP"
    ufw allow from "$I7_LAPTOP_IP"
    
    # Erlaube lokales Netzwerk
    ufw allow from "$NETWORK_SUBNET"
    
    # Aktiviere Firewall
    ufw --force enable
    
    log_success "Firewall konfiguriert"
}

# Erstelle GENTLEMAN Konfigurationsdateien
create_gentleman_config() {
    log_info "📋 Erstelle GENTLEMAN Konfiguration..."
    
    # Erstelle GENTLEMAN Verzeichnis
    local gentleman_dir="/opt/gentleman"
    mkdir -p "$gentleman_dir"
    
    # Erstelle Konfigurationsdatei
    cat > "$gentleman_dir/config.json" << EOF
{
    "node_type": "rx_node",
    "node_id": "rx-node-$(hostname)",
    "cluster": {
        "m1_mac": {
            "ip": "$M1_MAC_IP",
            "role": "master"
        },
        "i7_laptop": {
            "ip": "$I7_LAPTOP_IP", 
            "role": "client"
        },
        "rx_node": {
            "ip": "$RX_NODE_IP",
            "role": "receiver"
        }
    },
    "ssh": {
        "user": "$SSH_USER",
        "port": $SSH_PORT,
        "key_name": "$SSH_KEY_NAME"
    },
    "network": {
        "subnet": "$NETWORK_SUBNET",
        "gateway": "$GATEWAY_IP"
    }
}
EOF
    
    # Erstelle Status-Skript
    cat > "$gentleman_dir/status.sh" << 'EOF'
#!/bin/bash

echo "🎯 GENTLEMAN RX Node Status"
echo "=========================="
echo "Hostname: $(hostname)"
echo "IP: $(ip route get 1 | awk '{print $7}' | head -1)"
echo "MAC: $(ip link show | grep -A1 "state UP" | grep "link/ether" | awk '{print $2}' | head -1)"
echo "Uptime: $(uptime -p)"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"
echo ""
echo "Services:"
echo "SSH: $(systemctl is-active sshd)"
echo "NetworkManager: $(systemctl is-active NetworkManager)"
echo "Firewall: $(systemctl is-active ufw)"
EOF
    
    chmod +x "$gentleman_dir/status.sh"
    
    # Erstelle Symlink für einfachen Zugriff
    ln -sf "$gentleman_dir/status.sh" "/usr/local/bin/gentleman-status"
    
    log_success "GENTLEMAN Konfiguration erstellt"
}

# Zeige SSH Key Setup Anweisungen
show_ssh_key_instructions() {
    log_info "🔑 SSH Key Setup Anweisungen:"
    
    echo ""
    echo -e "${CYAN}Auf dem M1 Mac (192.168.68.111) ausführen:${NC}"
    echo -e "${YELLOW}# SSH Key zur RX Node kopieren${NC}"
    echo "ssh-copy-id -i ~/.ssh/${SSH_KEY_NAME}.pub ${SSH_USER}@${RX_NODE_IP}"
    echo ""
    echo -e "${YELLOW}# SSH-Verbindung testen${NC}"
    echo "ssh -i ~/.ssh/${SSH_KEY_NAME} ${SSH_USER}@${RX_NODE_IP}"
    echo ""
    echo -e "${CYAN}Auf dem I7 Laptop (192.168.68.105) ausführen:${NC}"
    echo -e "${YELLOW}# SSH Key zur RX Node kopieren${NC}"
    echo "ssh-copy-id -i ~/.ssh/${SSH_KEY_NAME}.pub ${SSH_USER}@${RX_NODE_IP}"
    echo ""
    echo -e "${YELLOW}# SSH-Verbindung testen${NC}"
    echo "ssh -i ~/.ssh/${SSH_KEY_NAME} ${SSH_USER}@${RX_NODE_IP}"
    echo ""
}

# Zeige Netzwerk-Informationen
show_network_info() {
    log_info "🌐 Netzwerk-Informationen:"
    
    echo ""
    echo -e "${CYAN}RX Node Netzwerk-Konfiguration:${NC}"
    echo "IP-Adresse: $RX_NODE_IP"
    echo "Subnetz: $NETWORK_SUBNET"
    echo "Gateway: $GATEWAY_IP"
    echo "DNS: $DNS_SERVERS"
    echo ""
    
    # Zeige aktuelle Netzwerk-Informationen
    local current_ip
    current_ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1 || echo "Unbekannt")
    
    local current_mac
    current_mac=$(ip link show | grep -A1 "state UP" | grep "link/ether" | awk '{print $2}' | head -1 || echo "Unbekannt")
    
    echo -e "${BLUE}Aktuelle Konfiguration:${NC}"
    echo "Aktuelle IP: $current_ip"
    echo "MAC-Adresse: $current_mac"
    echo ""
    
    # Teste Verbindungen zu anderen GENTLEMAN Nodes
    echo -e "${BLUE}Verbindungstests:${NC}"
    
    if ping -c 1 -W 2 "$M1_MAC_IP" >/dev/null 2>&1; then
        echo -e "M1 Mac ($M1_MAC_IP): ${GREEN}✅ Erreichbar${NC}"
    else
        echo -e "M1 Mac ($M1_MAC_IP): ${RED}❌ Nicht erreichbar${NC}"
    fi
    
    if ping -c 1 -W 2 "$I7_LAPTOP_IP" >/dev/null 2>&1; then
        echo -e "I7 Laptop ($I7_LAPTOP_IP): ${GREEN}✅ Erreichbar${NC}"
    else
        echo -e "I7 Laptop ($I7_LAPTOP_IP): ${RED}❌ Nicht erreichbar${NC}"
    fi
    
    if ping -c 1 -W 2 "$GATEWAY_IP" >/dev/null 2>&1; then
        echo -e "Gateway ($GATEWAY_IP): ${GREEN}✅ Erreichbar${NC}"
    else
        echo -e "Gateway ($GATEWAY_IP): ${RED}❌ Nicht erreichbar${NC}"
    fi
    
    echo ""
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN RX Node Setup${NC}"
    echo "=========================="
    echo ""
    
    log_info "Starte GENTLEMAN RX Node Netzwerk & SSH Setup..."
    
    # Prüfungen
    check_root
    check_arch_linux
    
    # Setup-Schritte
    update_system
    setup_network
    setup_user
    setup_ssh_server
    setup_wake_on_lan
    setup_firewall
    create_gentleman_config
    
    echo ""
    log_success "🎉 GENTLEMAN RX Node Setup abgeschlossen!"
    echo ""
    
    # Zeige Informationen
    show_network_info
    show_ssh_key_instructions
    
    echo -e "${YELLOW}💡 Nächste Schritte:${NC}"
    echo "1. SSH Keys von M1 Mac und I7 Laptop kopieren"
    echo "2. SSH-Verbindungen testen"
    echo "3. RX Node in GENTLEMAN Cluster integrieren"
    echo "4. Status prüfen: gentleman-status"
    echo ""
    
    log_info "Neustart empfohlen um alle Änderungen zu aktivieren"
}

# Führe Hauptfunktion aus
main "$@" 

# GENTLEMAN RX Node Network & SSH Setup Script
# Konfiguriert die RX Node für das GENTLEMAN Cluster

set -euo pipefail

# Konfiguration
SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# GENTLEMAN Netzwerk-Konfiguration
M1_MAC_IP="192.168.68.111"
I7_LAPTOP_IP="192.168.68.105"
RX_NODE_IP="192.168.68.117"
NETWORK_SUBNET="192.168.68.0/24"
GATEWAY_IP="192.168.68.1"
DNS_SERVERS="8.8.8.8,8.8.4.4"

# SSH Konfiguration
SSH_USER="amo9n11"
SSH_KEY_NAME="gentleman_key"
SSH_PORT="22"

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

# Prüfe Root-Rechte
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Dieses Skript muss als root ausgeführt werden"
        echo "Verwende: sudo $0"
        exit 1
    fi
}

# Prüfe Arch Linux
check_arch_linux() {
    if ! command -v pacman > /dev/null 2>&1; then
        log_error "Dieses Skript ist für Arch Linux konzipiert"
        exit 1
    fi
    log_success "Arch Linux erkannt"
}

# Aktualisiere System
update_system() {
    log_info "🔄 Aktualisiere System-Pakete..."
    
    pacman -Syu --noconfirm
    
    # Installiere benötigte Pakete
    local packages=(
        "openssh"
        "networkmanager"
        "ethtool"
        "net-tools"
        "iproute2"
        "bind-tools"
        "curl"
        "wget"
        "git"
        "python"
        "python-pip"
        "jq"
        "htop"
        "vim"
        "nano"
    )
    
    log_info "📦 Installiere benötigte Pakete..."
    pacman -S --needed --noconfirm "${packages[@]}"
    
    log_success "System aktualisiert und Pakete installiert"
}

# Konfiguriere Netzwerk
setup_network() {
    log_info "🌐 Konfiguriere Netzwerk..."
    
    # Aktiviere und starte NetworkManager
    systemctl enable NetworkManager
    systemctl start NetworkManager
    
    # Finde primäres Netzwerk-Interface
    local interface
    interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    if [[ -z "$interface" ]]; then
        log_error "Kein Netzwerk-Interface gefunden"
        return 1
    fi
    
    log_info "📡 Verwende Interface: $interface"
    
    # Erstelle NetworkManager-Konfiguration
    cat > "/etc/NetworkManager/system-connections/GENTLEMAN-Network.nmconnection" << EOF
[connection]
id=GENTLEMAN-Network
uuid=$(uuidgen)
type=ethernet
interface-name=$interface
autoconnect=true

[ethernet]

[ipv4]
method=manual
addresses=$RX_NODE_IP/24
gateway=$GATEWAY_IP
dns=$DNS_SERVERS

[ipv6]
method=auto

[proxy]
EOF
    
    # Setze Berechtigungen
    chmod 600 "/etc/NetworkManager/system-connections/GENTLEMAN-Network.nmconnection"
    
    # Lade Konfiguration neu
    nmcli connection reload
    
    # Aktiviere Verbindung
    nmcli connection up "GENTLEMAN-Network" || true
    
    log_success "Netzwerk konfiguriert: $RX_NODE_IP"
}

# Konfiguriere SSH Server
setup_ssh_server() {
    log_info "🔐 Konfiguriere SSH Server..."
    
    # Backup der Original-Konfiguration
    if [[ -f /etc/ssh/sshd_config ]]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    fi
    
    # Erstelle sichere SSH-Konfiguration
    cat > /etc/ssh/sshd_config << 'EOF'
# GENTLEMAN SSH Server Configuration

# Basic Settings
Port 22
Protocol 2
AddressFamily any
ListenAddress 0.0.0.0

# Host Keys
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Security Settings
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
UsePAM yes

# Connection Settings
X11Forwarding no
AllowTcpForwarding yes
GatewayPorts no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 10

# Logging
SyslogFacility AUTH
LogLevel INFO

# SFTP Subsystem
Subsystem sftp /usr/lib/ssh/sftp-server

# Allow specific users
AllowUsers amo9n11

# Banner
Banner /etc/ssh/banner
EOF
    
    # Erstelle SSH Banner
    cat > /etc/ssh/banner << 'EOF'
=====================================
    GENTLEMAN RX Node
    Authorized Access Only
=====================================
EOF
    
    # Generiere Host Keys falls nicht vorhanden
    ssh-keygen -A
    
    # Aktiviere und starte SSH
    systemctl enable sshd
    systemctl restart sshd
    
    log_success "SSH Server konfiguriert und gestartet"
}

# Erstelle GENTLEMAN Benutzer
setup_user() {
    log_info "👤 Konfiguriere Benutzer '$SSH_USER'..."
    
    # Erstelle Benutzer falls nicht vorhanden
    if ! id "$SSH_USER" &>/dev/null; then
        useradd -m -s /bin/bash -G wheel "$SSH_USER"
        log_info "Benutzer '$SSH_USER' erstellt"
    else
        log_info "Benutzer '$SSH_USER' existiert bereits"
    fi
    
    # Erstelle SSH-Verzeichnis
    local ssh_dir="/home/$SSH_USER/.ssh"
    mkdir -p "$ssh_dir"
    
    # Setze Berechtigungen
    chown "$SSH_USER:$SSH_USER" "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Erstelle authorized_keys falls nicht vorhanden
    touch "$ssh_dir/authorized_keys"
    chown "$SSH_USER:$SSH_USER" "$ssh_dir/authorized_keys"
    chmod 600 "$ssh_dir/authorized_keys"
    
    log_success "Benutzer '$SSH_USER' konfiguriert"
}

# Konfiguriere Wake-on-LAN
setup_wake_on_lan() {
    log_info "🔋 Konfiguriere Wake-on-LAN..."
    
    # Finde primäres Netzwerk-Interface
    local interface
    interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    if [[ -z "$interface" ]]; then
        log_warning "Kein Netzwerk-Interface für Wake-on-LAN gefunden"
        return 1
    fi
    
    # Aktiviere Wake-on-LAN
    ethtool -s "$interface" wol g 2>/dev/null || log_warning "Wake-on-LAN konnte nicht aktiviert werden"
    
    # Erstelle systemd Service für Wake-on-LAN
    cat > /etc/systemd/system/wake-on-lan.service << EOF
[Unit]
Description=Enable Wake-on-LAN for $interface
Requires=network.target
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/ethtool -s $interface wol g
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
    
    # Aktiviere Service
    systemctl enable wake-on-lan.service
    systemctl start wake-on-lan.service
    
    # Zeige aktuelle WoL-Einstellungen
    local wol_status
    wol_status=$(ethtool "$interface" | grep "Wake-on" || echo "Wake-on: Unbekannt")
    log_info "Wake-on-LAN Status: $wol_status"
    
    log_success "Wake-on-LAN konfiguriert"
}

# Konfiguriere Firewall
setup_firewall() {
    log_info "🔥 Konfiguriere Firewall..."
    
    # Installiere ufw falls nicht vorhanden
    pacman -S --needed --noconfirm ufw
    
    # Aktiviere ufw
    systemctl enable ufw
    
    # Setze Standard-Regeln
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Erlaube SSH
    ufw allow ssh
    
    # Erlaube Verbindungen von GENTLEMAN Nodes
    ufw allow from "$M1_MAC_IP"
    ufw allow from "$I7_LAPTOP_IP"
    
    # Erlaube lokales Netzwerk
    ufw allow from "$NETWORK_SUBNET"
    
    # Aktiviere Firewall
    ufw --force enable
    
    log_success "Firewall konfiguriert"
}

# Erstelle GENTLEMAN Konfigurationsdateien
create_gentleman_config() {
    log_info "📋 Erstelle GENTLEMAN Konfiguration..."
    
    # Erstelle GENTLEMAN Verzeichnis
    local gentleman_dir="/opt/gentleman"
    mkdir -p "$gentleman_dir"
    
    # Erstelle Konfigurationsdatei
    cat > "$gentleman_dir/config.json" << EOF
{
    "node_type": "rx_node",
    "node_id": "rx-node-$(hostname)",
    "cluster": {
        "m1_mac": {
            "ip": "$M1_MAC_IP",
            "role": "master"
        },
        "i7_laptop": {
            "ip": "$I7_LAPTOP_IP", 
            "role": "client"
        },
        "rx_node": {
            "ip": "$RX_NODE_IP",
            "role": "receiver"
        }
    },
    "ssh": {
        "user": "$SSH_USER",
        "port": $SSH_PORT,
        "key_name": "$SSH_KEY_NAME"
    },
    "network": {
        "subnet": "$NETWORK_SUBNET",
        "gateway": "$GATEWAY_IP"
    }
}
EOF
    
    # Erstelle Status-Skript
    cat > "$gentleman_dir/status.sh" << 'EOF'
#!/bin/bash

echo "🎯 GENTLEMAN RX Node Status"
echo "=========================="
echo "Hostname: $(hostname)"
echo "IP: $(ip route get 1 | awk '{print $7}' | head -1)"
echo "MAC: $(ip link show | grep -A1 "state UP" | grep "link/ether" | awk '{print $2}' | head -1)"
echo "Uptime: $(uptime -p)"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"
echo ""
echo "Services:"
echo "SSH: $(systemctl is-active sshd)"
echo "NetworkManager: $(systemctl is-active NetworkManager)"
echo "Firewall: $(systemctl is-active ufw)"
EOF
    
    chmod +x "$gentleman_dir/status.sh"
    
    # Erstelle Symlink für einfachen Zugriff
    ln -sf "$gentleman_dir/status.sh" "/usr/local/bin/gentleman-status"
    
    log_success "GENTLEMAN Konfiguration erstellt"
}

# Zeige SSH Key Setup Anweisungen
show_ssh_key_instructions() {
    log_info "🔑 SSH Key Setup Anweisungen:"
    
    echo ""
    echo -e "${CYAN}Auf dem M1 Mac (192.168.68.111) ausführen:${NC}"
    echo -e "${YELLOW}# SSH Key zur RX Node kopieren${NC}"
    echo "ssh-copy-id -i ~/.ssh/${SSH_KEY_NAME}.pub ${SSH_USER}@${RX_NODE_IP}"
    echo ""
    echo -e "${YELLOW}# SSH-Verbindung testen${NC}"
    echo "ssh -i ~/.ssh/${SSH_KEY_NAME} ${SSH_USER}@${RX_NODE_IP}"
    echo ""
    echo -e "${CYAN}Auf dem I7 Laptop (192.168.68.105) ausführen:${NC}"
    echo -e "${YELLOW}# SSH Key zur RX Node kopieren${NC}"
    echo "ssh-copy-id -i ~/.ssh/${SSH_KEY_NAME}.pub ${SSH_USER}@${RX_NODE_IP}"
    echo ""
    echo -e "${YELLOW}# SSH-Verbindung testen${NC}"
    echo "ssh -i ~/.ssh/${SSH_KEY_NAME} ${SSH_USER}@${RX_NODE_IP}"
    echo ""
}

# Zeige Netzwerk-Informationen
show_network_info() {
    log_info "🌐 Netzwerk-Informationen:"
    
    echo ""
    echo -e "${CYAN}RX Node Netzwerk-Konfiguration:${NC}"
    echo "IP-Adresse: $RX_NODE_IP"
    echo "Subnetz: $NETWORK_SUBNET"
    echo "Gateway: $GATEWAY_IP"
    echo "DNS: $DNS_SERVERS"
    echo ""
    
    # Zeige aktuelle Netzwerk-Informationen
    local current_ip
    current_ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1 || echo "Unbekannt")
    
    local current_mac
    current_mac=$(ip link show | grep -A1 "state UP" | grep "link/ether" | awk '{print $2}' | head -1 || echo "Unbekannt")
    
    echo -e "${BLUE}Aktuelle Konfiguration:${NC}"
    echo "Aktuelle IP: $current_ip"
    echo "MAC-Adresse: $current_mac"
    echo ""
    
    # Teste Verbindungen zu anderen GENTLEMAN Nodes
    echo -e "${BLUE}Verbindungstests:${NC}"
    
    if ping -c 1 -W 2 "$M1_MAC_IP" >/dev/null 2>&1; then
        echo -e "M1 Mac ($M1_MAC_IP): ${GREEN}✅ Erreichbar${NC}"
    else
        echo -e "M1 Mac ($M1_MAC_IP): ${RED}❌ Nicht erreichbar${NC}"
    fi
    
    if ping -c 1 -W 2 "$I7_LAPTOP_IP" >/dev/null 2>&1; then
        echo -e "I7 Laptop ($I7_LAPTOP_IP): ${GREEN}✅ Erreichbar${NC}"
    else
        echo -e "I7 Laptop ($I7_LAPTOP_IP): ${RED}❌ Nicht erreichbar${NC}"
    fi
    
    if ping -c 1 -W 2 "$GATEWAY_IP" >/dev/null 2>&1; then
        echo -e "Gateway ($GATEWAY_IP): ${GREEN}✅ Erreichbar${NC}"
    else
        echo -e "Gateway ($GATEWAY_IP): ${RED}❌ Nicht erreichbar${NC}"
    fi
    
    echo ""
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN RX Node Setup${NC}"
    echo "=========================="
    echo ""
    
    log_info "Starte GENTLEMAN RX Node Netzwerk & SSH Setup..."
    
    # Prüfungen
    check_root
    check_arch_linux
    
    # Setup-Schritte
    update_system
    setup_network
    setup_user
    setup_ssh_server
    setup_wake_on_lan
    setup_firewall
    create_gentleman_config
    
    echo ""
    log_success "🎉 GENTLEMAN RX Node Setup abgeschlossen!"
    echo ""
    
    # Zeige Informationen
    show_network_info
    show_ssh_key_instructions
    
    echo -e "${YELLOW}💡 Nächste Schritte:${NC}"
    echo "1. SSH Keys von M1 Mac und I7 Laptop kopieren"
    echo "2. SSH-Verbindungen testen"
    echo "3. RX Node in GENTLEMAN Cluster integrieren"
    echo "4. Status prüfen: gentleman-status"
    echo ""
    
    log_info "Neustart empfohlen um alle Änderungen zu aktivieren"
}

# Führe Hauptfunktion aus
main "$@" 
 