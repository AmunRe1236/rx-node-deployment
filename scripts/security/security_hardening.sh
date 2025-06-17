#!/bin/bash

# 🔒 GENTLEMAN SECURITY HARDENING
# ═══════════════════════════════════════════════════════════════
# KRITISCHE Sicherheitsmaßnahmen vor Produktionsdeployment

set -euo pipefail

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
log_critical() { echo -e "${RED}🚨 KRITISCH: $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  WARNUNG: $1${NC}"; }
log_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_step() { echo -e "${BLUE}🔧 $1${NC}"; }

# 🎩 Security Banner
print_banner() {
    echo -e "${RED}"
    echo "🚨 GENTLEMAN SECURITY HARDENING"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${WHITE}⚠️  KRITISCHE SICHERHEITSLÜCKEN WERDEN BEHOBEN${NC}"
    echo ""
}

# 🔍 Security Audit
security_audit() {
    log_step "Führe Sicherheitsaudit durch..."
    
    local issues=0
    
    # 1. Prüfe .env Datei
    if [[ -f .env ]]; then
        log_info "Prüfe .env Datei..."
        
        # Prüfe auf unsichere Default-Werte
        if grep -q "your.*password\|change.*this\|secret.*key.*here\|gentleman123\|CHANGE_ME" .env 2>/dev/null; then
            log_critical ".env enthält unsichere Default-Werte!"
            grep -n "your.*password\|change.*this\|secret.*key.*here\|gentleman123\|CHANGE_ME" .env || true
            ((issues++))
        fi
        
        # Prüfe auf leere kritische Werte
        if grep -E "^(JWT_SECRET_KEY|ENCRYPTION_KEY|GRAFANA_ADMIN_PASSWORD|MATRIX_ACCESS_TOKEN)=$" .env >/dev/null 2>&1; then
            log_critical ".env enthält leere kritische Werte!"
            ((issues++))
        fi
    else
        log_critical ".env Datei fehlt!"
        ((issues++))
    fi
    
    # 2. Prüfe Dateiberechtigungen
    log_info "Prüfe Dateiberechtigungen..."
    
    # Suche nach world-writable Dateien
    if find . -type f -perm -002 -not -path "./.git/*" | head -5 | grep -q .; then
        log_warning "World-writable Dateien gefunden:"
        find . -type f -perm -002 -not -path "./.git/*" | head -5
        ((issues++))
    fi
    
    # 3. Prüfe auf hardcodierte Secrets
    log_info "Prüfe auf hardcodierte Secrets..."
    
    if grep -r -E "(password|secret|key).*=.*['\"][^{]" --include="*.py" --include="*.yml" --include="*.yaml" . | grep -v ".git" | head -3 | grep -q .; then
        log_warning "Mögliche hardcodierte Secrets gefunden:"
        grep -r -E "(password|secret|key).*=.*['\"][^{]" --include="*.py" --include="*.yml" --include="*.yaml" . | grep -v ".git" | head -3 || true
        ((issues++))
    fi
    
    # 4. Prüfe SSL/TLS Konfiguration
    if [[ ! -d "config/security/ssl" ]]; then
        log_warning "SSL-Zertifikate nicht konfiguriert"
        ((issues++))
    fi
    
    # 5. Prüfe Firewall-Konfiguration
    if [[ ! -f "scripts/security/setup_firewall.sh" ]]; then
        log_warning "Firewall-Setup fehlt"
        ((issues++))
    fi
    
    echo ""
    if (( issues > 0 )); then
        log_critical "$issues Sicherheitsprobleme gefunden!"
        return 1
    else
        log_success "Keine kritischen Sicherheitsprobleme gefunden"
        return 0
    fi
}

# 🔐 Generate Secure Secrets
generate_secrets() {
    log_step "Generiere sichere Secrets..."
    
    # Erstelle .env falls nicht vorhanden
    if [[ ! -f .env ]]; then
        if [[ -f env.example ]]; then
            cp env.example .env
            log_info ".env von env.example erstellt"
        else
            log_critical "Weder .env noch env.example gefunden!"
            return 1
        fi
    fi
    
    # Backup der aktuellen .env
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
    
    # Generiere sichere Werte
    JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
    ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d '\n')
    GRAFANA_PASSWORD=$(openssl rand -base64 16 | tr -d '\n')
    API_KEY=$(openssl rand -hex 32)
    
    # Ersetze unsichere Werte
    sed -i.bak \
        -e "s|JWT_SECRET_KEY=.*|JWT_SECRET_KEY=${JWT_SECRET}|" \
        -e "s|ENCRYPTION_KEY=.*|ENCRYPTION_KEY=${ENCRYPTION_KEY}|" \
        -e "s|GRAFANA_ADMIN_PASSWORD=.*|GRAFANA_ADMIN_PASSWORD=${GRAFANA_PASSWORD}|" \
        -e "s|API_KEY=.*|API_KEY=${API_KEY}|" \
        -e "s|your.*password.*here|GENERATED_SECURE_PASSWORD|g" \
        -e "s|change.*this|GENERATED_SECURE_VALUE|g" \
        -e "s|CHANGE_ME.*|GENERATED_SECURE_VALUE|g" \
        .env
    
    rm .env.bak
    
    log_success "Sichere Secrets generiert und in .env gespeichert"
    log_warning "WICHTIG: Notiere dir das neue Grafana-Passwort: ${GRAFANA_PASSWORD}"
}

# 🔒 Setup SSL/TLS
setup_ssl() {
    log_step "Richte SSL/TLS ein..."
    
    SSL_DIR="config/security/ssl"
    mkdir -p "$SSL_DIR"
    
    # Generiere CA falls nicht vorhanden
    if [[ ! -f "$SSL_DIR/ca.crt" ]]; then
        log_info "Generiere Certificate Authority..."
        
        # CA Private Key
        openssl genrsa -out "$SSL_DIR/ca.key" 4096
        
        # CA Certificate
        openssl req -new -x509 -days 3650 -key "$SSL_DIR/ca.key" -out "$SSL_DIR/ca.crt" \
            -subj "/C=DE/ST=Germany/L=Berlin/O=Gentleman AI/OU=Security/CN=Gentleman CA" \
            -config <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
[req_distinguished_name]
[v3_ca]
basicConstraints = CA:TRUE
keyUsage = keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF
)
        
        log_success "Certificate Authority erstellt"
    fi
    
    # Generiere Service-Zertifikate
    for service in llm-server stt-service tts-service web-interface matrix-update; do
        if [[ ! -f "$SSL_DIR/${service}.crt" ]]; then
            log_info "Generiere Zertifikat für $service..."
            
            # Private Key
            openssl genrsa -out "$SSL_DIR/${service}.key" 2048
            
            # Certificate Signing Request
            openssl req -new -key "$SSL_DIR/${service}.key" -out "$SSL_DIR/${service}.csr" \
                -subj "/C=DE/ST=Germany/L=Berlin/O=Gentleman AI/OU=Services/CN=${service}.gentleman.local"
            
            # Sign Certificate
            openssl x509 -req -in "$SSL_DIR/${service}.csr" \
                -CA "$SSL_DIR/ca.crt" -CAkey "$SSL_DIR/ca.key" \
                -CAcreateserial -out "$SSL_DIR/${service}.crt" \
                -days 365 -sha256 \
                -extensions v3_req -extfile <(cat <<EOF
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${service}.gentleman.local
DNS.2 = ${service}
DNS.3 = localhost
IP.1 = 127.0.0.1
IP.2 = 192.168.100.10
IP.3 = 192.168.100.20
IP.4 = 192.168.100.30
EOF
)
            
            # Cleanup
            rm "$SSL_DIR/${service}.csr"
        fi
    done
    
    # Sichere Berechtigungen
    chmod 600 "$SSL_DIR"/*.key
    chmod 644 "$SSL_DIR"/*.crt
    
    log_success "SSL/TLS Zertifikate erstellt"
}

# 🔥 Setup Firewall
setup_firewall() {
    log_step "Richte Firewall ein..."
    
    # Erstelle Firewall-Setup-Skript
    cat > scripts/security/setup_firewall.sh << 'EOF'
#!/bin/bash

# 🔥 GENTLEMAN FIREWALL SETUP
set -e

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux iptables
    echo "🔥 Konfiguriere Linux Firewall (iptables)..."
    
    # Flush existing rules
    sudo iptables -F
    sudo iptables -X
    sudo iptables -t nat -F
    sudo iptables -t nat -X
    
    # Default policies
    sudo iptables -P INPUT DROP
    sudo iptables -P FORWARD DROP
    sudo iptables -P OUTPUT ACCEPT
    
    # Allow loopback
    sudo iptables -A INPUT -i lo -j ACCEPT
    
    # Allow established connections
    sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Allow Nebula VPN
    sudo iptables -A INPUT -i nebula1 -j ACCEPT
    sudo iptables -A INPUT -p udp --dport 4242 -j ACCEPT
    
    # Allow SSH (nur von lokalen Netzwerken)
    sudo iptables -A INPUT -p tcp --dport 22 -s 192.168.0.0/16 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 22 -s 10.0.0.0/8 -j ACCEPT
    
    # Block everything else
    sudo iptables -A INPUT -j DROP
    
    # Save rules
    if command -v iptables-save >/dev/null; then
        sudo iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS pfctl
    echo "🔥 Konfiguriere macOS Firewall (pfctl)..."
    
    # Create pfctl rules
    sudo tee /etc/pf.anchors/gentleman << 'PFEOF'
# Gentleman AI Firewall Rules
scrub-anchor "com.apple/*"
nat-anchor "com.apple/*"
rdr-anchor "com.apple/*"
dummynet-anchor "com.apple/*"
anchor "com.apple/*"
load anchor "com.apple" from "/etc/pf.anchors/com.apple"

# Allow loopback
pass on lo0

# Allow Nebula VPN
pass in on utun100
pass out on utun100

# Allow established connections
pass in proto tcp from any to any port {80, 443, 8001, 8002, 8003, 8004, 8005} keep state
pass out proto tcp from any to any port {80, 443} keep state
pass out proto udp from any to any port {53, 4242} keep state

# Block everything else
block log all
PFEOF
    
    # Load rules
    sudo pfctl -f /etc/pf.anchors/gentleman
    sudo pfctl -e
fi

echo "✅ Firewall konfiguriert"
EOF
    
    chmod +x scripts/security/setup_firewall.sh
    log_success "Firewall-Setup erstellt"
}

# 🔐 Secure File Permissions
secure_permissions() {
    log_step "Sichere Dateiberechtigungen..."
    
    # Sichere .env
    if [[ -f .env ]]; then
        chmod 600 .env
        log_info ".env Berechtigungen gesichert (600)"
    fi
    
    # Sichere SSL-Verzeichnis
    if [[ -d config/security ]]; then
        chmod -R 700 config/security
        log_info "Security-Verzeichnis gesichert (700)"
    fi
    
    # Sichere Skripte
    find scripts -name "*.sh" -exec chmod 750 {} \;
    log_info "Skript-Berechtigungen gesichert (750)"
    
    # Entferne world-writable Berechtigungen
    find . -type f -perm -002 -not -path "./.git/*" -exec chmod o-w {} \; 2>/dev/null || true
    
    log_success "Dateiberechtigungen gesichert"
}

# 🚨 Security Monitoring Setup
setup_monitoring() {
    log_step "Richte Security Monitoring ein..."
    
    # Erstelle Security Monitor Konfiguration
    mkdir -p config/security
    cat > config/security/security_monitor.yml << 'EOF'
# 🔒 Gentleman Security Monitoring
security_monitoring:
  enabled: true
  log_level: INFO
  
  # Threat Detection
  threat_detection:
    brute_force_threshold: 5
    unusual_traffic_multiplier: 10
    failed_auth_threshold: 3
    
  # Alert Configuration
  alerts:
    email_enabled: false  # Konfiguriere nach Bedarf
    webhook_enabled: true
    log_enabled: true
    
  # Auto-Response
  auto_response:
    block_suspicious_ips: true
    rate_limit_aggressive: true
EOF
    
    # Erstelle Security Log Rotation
    cat > scripts/security/rotate_logs.sh << 'EOF'
#!/bin/bash
# 📝 Security Log Rotation
find logs/ -name "security_*.log" -mtime +30 -delete 2>/dev/null || true
find logs/ -name "audit_*.log" -mtime +90 -delete 2>/dev/null || true
EOF
    
    chmod +x scripts/security/rotate_logs.sh
    
    log_success "Security Monitoring konfiguriert"
}

# 📋 Generate Security Report
generate_security_report() {
    log_step "Generiere Sicherheitsbericht..."
    
    local report_file="logs/security_report_$(date +%Y%m%d_%H%M%S).txt"
    mkdir -p logs
    
    {
        echo "🔒 GENTLEMAN SECURITY REPORT"
        echo "═══════════════════════════════════════════════════════════════"
        echo "Generated: $(date)"
        echo ""
        
        echo "📋 SECURITY CHECKLIST:"
        echo "─────────────────────────────────────────────────────────────────"
        
        # .env Check
        if [[ -f .env ]] && ! grep -q "your.*password\|change.*this\|CHANGE_ME" .env; then
            echo "✅ .env: Sichere Konfiguration"
        else
            echo "❌ .env: Unsichere Default-Werte gefunden"
        fi
        
        # SSL Check
        if [[ -f config/security/ssl/ca.crt ]]; then
            echo "✅ SSL: Zertifikate vorhanden"
        else
            echo "❌ SSL: Zertifikate fehlen"
        fi
        
        # Firewall Check
        if [[ -f scripts/security/setup_firewall.sh ]]; then
            echo "✅ Firewall: Setup verfügbar"
        else
            echo "❌ Firewall: Setup fehlt"
        fi
        
        # Permissions Check
        if [[ -f .env ]] && [[ "$(stat -c %a .env 2>/dev/null || stat -f %A .env 2>/dev/null)" == "600" ]]; then
            echo "✅ Permissions: .env gesichert"
        else
            echo "❌ Permissions: .env nicht gesichert"
        fi
        
        echo ""
        echo "🔐 NEXT STEPS:"
        echo "─────────────────────────────────────────────────────────────────"
        echo "1. Führe './scripts/security/setup_firewall.sh' aus"
        echo "2. Teste alle Services mit 'make test-services-health'"
        echo "3. Aktiviere Matrix-Autorisierung"
        echo "4. Konfiguriere Monitoring-Alerts"
        echo ""
        
    } > "$report_file"
    
    log_success "Sicherheitsbericht erstellt: $report_file"
    cat "$report_file"
}

# 🚀 Main Function
main() {
    print_banner
    
    log_info "Starte Sicherheitshärtung für GENTLEMAN AI..."
    echo ""
    
    # 1. Security Audit
    if ! security_audit; then
        log_critical "Sicherheitsaudit fehlgeschlagen!"
        echo ""
        log_info "Behebe die Probleme automatisch? (y/n)"
        read -r fix_issues
        
        if [[ "$fix_issues" =~ ^[Yy]$ ]]; then
            log_step "Behebe Sicherheitsprobleme automatisch..."
        else
            log_critical "Sicherheitsprobleme müssen vor Deployment behoben werden!"
            exit 1
        fi
    fi
    
    # 2. Generate Secure Secrets
    generate_secrets
    
    # 3. Setup SSL/TLS
    setup_ssl
    
    # 4. Setup Firewall
    setup_firewall
    
    # 5. Secure Permissions
    secure_permissions
    
    # 6. Setup Monitoring
    setup_monitoring
    
    # 7. Generate Report
    generate_security_report
    
    echo ""
    log_success "🔒 SICHERHEITSHÄRTUNG ABGESCHLOSSEN!"
    echo ""
    log_warning "WICHTIGE NÄCHSTE SCHRITTE:"
    echo "1. Führe './scripts/security/setup_firewall.sh' aus"
    echo "2. Teste mit 'make test-services-health'"
    echo "3. Sichere deine .env Datei an einem sicheren Ort"
    echo "4. Aktiviere Matrix-Autorisierung für Updates"
    echo ""
}

# Entry Point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi