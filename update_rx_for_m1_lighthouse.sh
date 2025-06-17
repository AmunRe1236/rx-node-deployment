#!/bin/bash
# 🎩 GENTLEMAN AI - RX Node Update für M1 Lighthouse

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_step() { echo -e "${PURPLE}🔧 $1${NC}"; }

echo "🎩 GENTLEMAN AI - RX Node Update für M1 Lighthouse"
echo "════════════════════════════════════════════════════════════"

# M1 IP automatisch erkennen
log_step "Erkenne M1 Lighthouse IP..."
M1_LIGHTHOUSE_IP=""

for ip in $(nmap -sn 192.168.68.0/24 2>/dev/null | grep -oP '192\.168\.68\.\d+' | grep -v 192.168.68.117); do
    if curl -s --connect-timeout 1 "http://$ip:8005/discovery.json" | grep -q "apple_m1" 2>/dev/null; then
        M1_LIGHTHOUSE_IP="$ip"
        log_success "M1 Lighthouse gefunden: $M1_LIGHTHOUSE_IP"
        break
    fi
done

if [ -z "$M1_LIGHTHOUSE_IP" ]; then
    read -p "M1 Mac IP-Adresse eingeben: " M1_LIGHTHOUSE_IP
fi

# Prüfe Zertifikate
log_step "Prüfe Nebula Zertifikate..."
NEBULA_DIR="./nebula/rx-node"

if [ ! -f "$NEBULA_DIR/ca.crt" ]; then
    log_warning "Zertifikate fehlen! Bitte vom M1 kopieren:"
    echo "scp user@$M1_LIGHTHOUSE_IP:./rx-node-certs/* $NEBULA_DIR/"
    exit 1
fi

# Backup erstellen
log_step "Erstelle Backup..."
cp "$NEBULA_DIR/config.yml" "$NEBULA_DIR/config.yml.backup.$(date +%Y%m%d_%H%M%S)"

# Neue Konfiguration
log_step "Erstelle neue Konfiguration..."
cat > "$NEBULA_DIR/config.yml" << EOF
# 🎩 Gentleman RX Node - M1 Lighthouse Connection
pki:
  ca: ca.crt
  cert: rx-node.crt
  key: rx-node.key

static_host_map:
  "192.168.100.1": ["$M1_LIGHTHOUSE_IP:4242"]

lighthouse:
  am_lighthouse: false
  interval: 60
  hosts:
    - "192.168.100.1"

listen:
  host: 0.0.0.0
  port: 0

punchy:
  punch: true
  respond: true
  delay: 1s

tun:
  disabled: false
  dev: nebula1
  mtu: 1300

logging:
  level: info
  format: text

firewall:
  conntrack:
    tcp_timeout: 12m
    udp_timeout: 3m
    default_timeout: 10m
    max_connections: 100000

  outbound:
    - port: any
      proto: any
      host: any

  inbound:
    - port: any
      proto: icmp
      host: any
    - port: 22
      proto: tcp
      host: any
    - port: 8000-8010
      proto: tcp
      host: any
      groups:
        - audio-services
        - clients
        - monitoring
    - port: 4242
      proto: udp
      host: any
EOF

# Service neu starten
log_step "Starte Nebula Service neu..."
sudo systemctl restart nebula-rx
sleep 3

# Status prüfen
if systemctl is-active --quiet nebula-rx; then
    log_success "Nebula RX Service läuft"
else
    log_warning "Service nicht aktiv"
    sudo systemctl status nebula-rx
fi

echo ""
log_success "🎉 RX Node Update abgeschlossen!"
echo -e "${CYAN}🏠 M1 Lighthouse: $M1_LIGHTHOUSE_IP:4242${NC}"
echo -e "${CYAN}🖥️  RX Mesh IP: 192.168.100.10${NC}"
echo ""
echo "Status prüfen: sudo journalctl -u nebula-rx -f" 