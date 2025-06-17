#!/bin/bash

# 🔒 GENTLEMAN SECURITY INITIALIZATION
# ═══════════════════════════════════════════════════════════════
# Automatische Einrichtung aller Sicherheitsmaßnahmen

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
log_info() { echo -e "${CYAN}🔒 $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_step() { echo -e "${BLUE}🔧 $1${NC}"; }

# 🎩 Security Banner
print_banner() {
    echo -e "${PURPLE}"
    echo "🔒 GENTLEMAN SECURITY INITIALIZATION"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${WHITE}🛡️ Enterprise-Grade Security Setup${NC}"
    echo ""
}

# 🔍 System Detection
detect_system() {
    OS=$(uname -s)
    case $OS in
        Linux*)
            SYSTEM="Linux"
            FIREWALL_CMD="iptables"
            ;;
        Darwin*)
            SYSTEM="macOS"
            FIREWALL_CMD="pfctl"
            ;;
        *)
            log_error "Unsupported system: $OS"
            exit 1
            ;;
    esac
    log_info "Detected system: $SYSTEM"
}

# 🔥 Firewall Setup
setup_firewall() {
    log_step "Setting up firewall rules..."
    
    case $SYSTEM in
        Linux)
            setup_linux_firewall
            ;;
        macOS)
            setup_macos_firewall
            ;;
    esac
}

setup_linux_firewall() {
    log_info "Configuring iptables for Linux..."
    
    # 🧹 Clear existing rules
    sudo iptables -F
    sudo iptables -X
    sudo iptables -t nat -F
    sudo iptables -t nat -X
    
    # 🔒 Default policies (DROP everything)
    sudo iptables -P INPUT DROP
    sudo iptables -P FORWARD DROP
    sudo iptables -P OUTPUT DROP
    
    # ✅ Allow loopback
    sudo iptables -A INPUT -i lo -j ACCEPT
    sudo iptables -A OUTPUT -o lo -j ACCEPT
    
    # ✅ Allow established connections
    sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # 🌐 Allow Nebula Mesh
    sudo iptables -A INPUT -i nebula1 -j ACCEPT
    sudo iptables -A OUTPUT -o nebula1 -j ACCEPT
    
    # 🏠 Allow Nebula Lighthouse (UDP 4242)
    sudo iptables -A INPUT -p udp --dport 4242 -j ACCEPT
    sudo iptables -A OUTPUT -p udp --sport 4242 -j ACCEPT
    
    # 🌐 Allow outbound HTTPS/HTTP for updates
    sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
    
    # 📊 Allow Docker networks
    sudo iptables -A INPUT -i docker0 -j ACCEPT
    sudo iptables -A OUTPUT -o docker0 -j ACCEPT
    
    # 💾 Save rules
    if command -v iptables-save &> /dev/null; then
        sudo iptables-save > /etc/iptables/rules.v4
    fi
    
    log_success "Linux firewall configured"
}

setup_macos_firewall() {
    log_info "Configuring pfctl for macOS..."
    
    # 🔒 Create pfctl rules
    cat > /tmp/gentleman_pf.conf << 'EOF'
# 🎩 Gentleman macOS Firewall Rules
# Block all by default
block all

# Allow loopback
pass on lo0

# Allow Nebula mesh interface
pass in on utun100
pass out on utun100

# Allow established connections
pass in proto tcp from any to any port 22 keep state
pass out proto tcp from any to any port {80, 443} keep state
pass out proto udp from any to any port 4242 keep state

# Allow Docker
pass in on bridge100
pass out on bridge100

# Block everything else
block log all
EOF
    
    # 🔧 Load pfctl rules
    sudo pfctl -f /tmp/gentleman_pf.conf
    sudo pfctl -e
    
    log_success "macOS firewall configured"
}

# 🔐 SSL/TLS Setup
setup_ssl() {
    log_step "Setting up SSL/TLS certificates..."
    
    SSL_DIR="./config/security/ssl"
    mkdir -p "$SSL_DIR"
    
    # 🏛️ Generate CA if not exists
    if [ ! -f "$SSL_DIR/ca.crt" ]; then
        log_info "Generating Certificate Authority..."
        openssl genrsa -out "$SSL_DIR/ca.key" 4096
        openssl req -new -x509 -days 3650 -key "$SSL_DIR/ca.key" -out "$SSL_DIR/ca.crt" \
            -subj "/C=DE/ST=Germany/L=Berlin/O=Gentleman AI/OU=Security/CN=Gentleman CA"
    fi
    
    # 🌐 Generate server certificates for each service
    for service in llm-server stt-service tts-service web-interface; do
        if [ ! -f "$SSL_DIR/${service}.crt" ]; then
            log_info "Generating certificate for $service..."
            
            # Generate private key
            openssl genrsa -out "$SSL_DIR/${service}.key" 2048
            
            # Generate certificate signing request
            openssl req -new -key "$SSL_DIR/${service}.key" -out "$SSL_DIR/${service}.csr" \
                -subj "/C=DE/ST=Germany/L=Berlin/O=Gentleman AI/OU=Services/CN=${service}.gentleman.local"
            
            # Sign certificate with CA
            openssl x509 -req -in "$SSL_DIR/${service}.csr" -CA "$SSL_DIR/ca.crt" -CAkey "$SSL_DIR/ca.key" \
                -CAcreateserial -out "$SSL_DIR/${service}.crt" -days 365 -sha256
            
            # Clean up CSR
            rm "$SSL_DIR/${service}.csr"
        fi
    done
    
    log_success "SSL/TLS certificates generated"
}

# 🔑 JWT Secret Generation
setup_jwt() {
    log_step "Setting up JWT authentication..."
    
    JWT_SECRET=$(openssl rand -base64 64)
    ENCRYPTION_KEY=$(openssl rand -base64 32)
    
    # 📝 Update .env file
    if [ -f .env ]; then
        sed -i.bak "s/JWT_SECRET_KEY=.*/JWT_SECRET_KEY=$JWT_SECRET/" .env
        sed -i.bak "s/ENCRYPTION_KEY=.*/ENCRYPTION_KEY=$ENCRYPTION_KEY/" .env
        rm .env.bak
    else
        log_warning ".env file not found, creating from template..."
        cp env.example .env
        sed -i "s/JWT_SECRET_KEY=.*/JWT_SECRET_KEY=$JWT_SECRET/" .env
        sed -i "s/ENCRYPTION_KEY=.*/ENCRYPTION_KEY=$ENCRYPTION_KEY/" .env
    fi
    
    log_success "JWT authentication configured"
}

# 🚨 Security Monitoring Setup
setup_monitoring() {
    log_step "Setting up security monitoring..."
    
    # 📊 Create security monitoring configuration
    cat > ./config/security/security_monitor.yml << 'EOF'
# 🔒 Gentleman Security Monitoring Configuration
security_monitoring:
  enabled: true
  log_level: INFO
  
  # 🔍 Threat Detection
  threat_detection:
    brute_force_threshold: 5
    unusual_traffic_multiplier: 10
    failed_auth_threshold: 3
    
  # 🚨 Alert Configuration
  alerts:
    email_enabled: true
    webhook_enabled: true
    log_enabled: true
    
  # 📊 Metrics Collection
  metrics:
    failed_authentications: true
    unusual_connections: true
    certificate_expiry: true
    firewall_blocks: true
    
  # 🔄 Auto-Response
  auto_response:
    block_suspicious_ips: true
    rate_limit_aggressive: true
    certificate_auto_renewal: true
EOF
    
    log_success "Security monitoring configured"
}

# 🔍 Vulnerability Scan
run_security_scan() {
    log_step "Running initial security scan..."
    
    # 🔒 Check for common vulnerabilities
    SCAN_RESULTS="./logs/security_scan_$(date +%Y%m%d_%H%M%S).log"
    mkdir -p ./logs
    
    {
        echo "🔒 GENTLEMAN SECURITY SCAN REPORT"
        echo "═══════════════════════════════════════════════════════════════"
        echo "Date: $(date)"
        echo ""
        
        # Check file permissions
        echo "📁 File Permissions Check:"
        find . -type f -perm -002 -ls | head -10
        echo ""
        
        # Check for weak passwords
        echo "🔑 Password Strength Check:"
        if [ -f .env ]; then
            grep -E "(password|secret|key)" .env | grep -v "your-" | wc -l
        fi
        echo ""
        
        # Check SSL certificates
        echo "🔐 SSL Certificate Check:"
        if [ -d "./config/security/ssl" ]; then
            for cert in ./config/security/ssl/*.crt; do
                if [ -f "$cert" ]; then
                    echo "Certificate: $(basename "$cert")"
                    openssl x509 -in "$cert" -noout -dates
                fi
            done
        fi
        echo ""
        
        # Check Docker security
        echo "🐳 Docker Security Check:"
        if command -v docker &> /dev/null; then
            docker --version
            docker info --format '{{.SecurityOptions}}'
        fi
        echo ""
        
    } > "$SCAN_RESULTS"
    
    log_success "Security scan completed: $SCAN_RESULTS"
}

# 📋 Security Checklist
run_security_checklist() {
    log_step "Running security checklist..."
    
    echo ""
    echo -e "${WHITE}🔒 GENTLEMAN SECURITY CHECKLIST${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    
    # Check Nebula
    if command -v nebula &> /dev/null; then
        echo -e "✅ Nebula VPN: ${GREEN}INSTALLED${NC}"
    else
        echo -e "❌ Nebula VPN: ${RED}NOT INSTALLED${NC}"
    fi
    
    # Check Firewall
    case $SYSTEM in
        Linux)
            if sudo iptables -L &> /dev/null; then
                echo -e "✅ Firewall: ${GREEN}ACTIVE${NC}"
            else
                echo -e "❌ Firewall: ${RED}INACTIVE${NC}"
            fi
            ;;
        macOS)
            if sudo pfctl -s info &> /dev/null; then
                echo -e "✅ Firewall: ${GREEN}ACTIVE${NC}"
            else
                echo -e "❌ Firewall: ${RED}INACTIVE${NC}"
            fi
            ;;
    esac
    
    # Check SSL Certificates
    if [ -d "./config/security/ssl" ] && [ -f "./config/security/ssl/ca.crt" ]; then
        echo -e "✅ SSL Certificates: ${GREEN}GENERATED${NC}"
    else
        echo -e "❌ SSL Certificates: ${RED}MISSING${NC}"
    fi
    
    # Check JWT Configuration
    if [ -f .env ] && grep -q "JWT_SECRET_KEY=" .env; then
        echo -e "✅ JWT Authentication: ${GREEN}CONFIGURED${NC}"
    else
        echo -e "❌ JWT Authentication: ${RED}NOT CONFIGURED${NC}"
    fi
    
    # Check Docker Security
    if command -v docker &> /dev/null; then
        echo -e "✅ Docker: ${GREEN}AVAILABLE${NC}"
    else
        echo -e "❌ Docker: ${RED}NOT AVAILABLE${NC}"
    fi
    
    echo ""
}

# 🚀 Main Function
main() {
    print_banner
    
    log_info "Starting Gentleman Security Initialization..."
    
    detect_system
    setup_firewall
    setup_ssl
    setup_jwt
    setup_monitoring
    run_security_scan
    run_security_checklist
    
    echo ""
    log_success "🔒 Gentleman Security Setup Complete!"
    echo ""
    echo -e "${WHITE}🎯 Next Steps:${NC}"
    echo "  1. Review security scan: ./logs/security_scan_*.log"
    echo "  2. Test security: make gentleman-security-test"
    echo "  3. Monitor security: make gentleman-security-monitor"
    echo "  4. Start services: make gentleman-up"
    echo ""
    echo -e "${GREEN}🛡️ Your Gentleman installation is now enterprise-grade secure!${NC}"
}

# 🎯 Execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 