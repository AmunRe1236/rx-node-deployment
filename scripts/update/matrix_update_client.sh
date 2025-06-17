#!/bin/bash

# 🎩 GENTLEMAN - Matrix Update Client
# ═══════════════════════════════════════════════════════════════
# Client-Skript für Matrix-basierte Pipeline-Updates

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
    echo "🎩 GENTLEMAN - Matrix Update Client"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${WHITE}🔐 Matrix-autorisierte Pipeline-Updates${NC}"
    echo ""
}

# 🔧 Konfiguration
MATRIX_SERVICE_URL="http://localhost:8005"
CONFIG_FILE=".env"
MATRIX_CONFIG="config/integrations/matrix-authorization.yml"

# 📋 Hilfsfunktionen
usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  system_update     - Vollständiges System-Update"
    echo "  security_patch    - Security-Patches anwenden"
    echo "  software_update   - Software-Dependencies updaten"
    echo "  config_update     - Konfiguration aktualisieren"
    echo "  service_restart   - Services neu starten"
    echo "  rollback          - Rollback zum vorherigen Stand"
    echo "  status            - Update-Status anzeigen"
    echo "  register          - Gerät in Matrix registrieren"
    echo ""
    echo "Options:"
    echo "  --device-id       - Geräte-ID (default: auto-detect)"
    echo "  --user-id         - Matrix User ID"
    echo "  --force           - Force Update ohne Bestätigung"
    echo "  --dry-run         - Zeige was gemacht würde"
    echo ""
}

# 🔍 System Detection
detect_device() {
    log_step "Erkenne Gerät..."
    
    HOSTNAME=$(hostname)
    OS=$(uname -s)
    ARCH=$(uname -m)
    
    # Gerät basierend auf Hostname/System erkennen
    case $HOSTNAME in
        *arch*|*rx*)
            DEVICE_ID="rx-node"
            DEVICE_TYPE="llm-server"
            ;;
        *m1*|*apple*|*silicon*)
            DEVICE_ID="m1-node"
            DEVICE_TYPE="audio-services"
            ;;
        *i7*|*intel*)
            DEVICE_ID="i7-node"
            DEVICE_TYPE="client"
            ;;
        *)
            DEVICE_ID=$(hostname -s)
            DEVICE_TYPE="unknown"
            ;;
    esac
    
    log_info "Gerät: $DEVICE_ID ($DEVICE_TYPE) - $OS $ARCH"
}

# 🔐 Matrix Authorization prüfen
check_authorization() {
    local command=$1
    local user_id=$2
    
    log_step "Prüfe Matrix-Autorisierung..."
    
    # API Call an Matrix Update Service
    auth_response=$(curl -s -X POST \
        "$MATRIX_SERVICE_URL/authorize" \
        -H "Content-Type: application/json" \
        -d "{
            \"command\": \"$command\",
            \"device\": \"$DEVICE_ID\",
            \"user_id\": \"$user_id\"
        }")
    
    # Parse Response
    authorized=$(echo "$auth_response" | jq -r '.authorized')
    reason=$(echo "$auth_response" | jq -r '.reason')
    
    if [ "$authorized" != "true" ]; then
        log_error "Nicht autorisiert: $reason"
        return 1
    fi
    
    log_success "Autorisierung erfolgreich: $reason"
    return 0
}

# 🔄 Update ausführen
execute_update() {
    local command=$1
    local parameters=$2
    
    log_step "Führe Update aus: $command"
    
    case $command in
        "system_update")
            run_system_update
            ;;
        "security_patch")
            run_security_patch
            ;;
        "software_update")
            run_software_update
            ;;
        "config_update")
            run_config_update "$parameters"
            ;;
        "service_restart")
            run_service_restart "$parameters"
            ;;
        "rollback")
            run_rollback "$parameters"
            ;;
        *)
            log_error "Unbekannter Befehl: $command"
            return 1
            ;;
    esac
}

# 🖥️ System Update
run_system_update() {
    log_step "System Update wird ausgeführt..."
    
    # Backup erstellen
    if [ ! "$DRY_RUN" = "true" ]; then
        log_info "Erstelle System-Backup..."
        ./scripts/backup/create_backup.sh
    fi
    
    # Gentleman Pipeline updaten
    log_info "Aktualisiere Gentleman Pipeline..."
    if [ ! "$DRY_RUN" = "true" ]; then
        git pull origin main
        ./setup.sh --update
    else
        echo "DRY RUN: git pull && ./setup.sh --update"
    fi
    
    log_success "System Update abgeschlossen"
}

# 🔒 Security Patch
run_security_patch() {
    log_step "Security Patches werden angewendet..."
    
    if [ ! "$DRY_RUN" = "true" ]; then
        # Nebula Update
        log_info "Aktualisiere Nebula auf v1.9.5..."
        ./scripts/security/update_nebula.sh
        
        # SSL Certificates prüfen
        log_info "Prüfe SSL-Zertifikate..."
        ./scripts/security/check_certificates.sh
        
        # Firewall Rules updaten
        log_info "Aktualisiere Firewall-Regeln..."
        ./scripts/security/update_firewall.sh
    else
        echo "DRY RUN: Security patches würden angewendet"
    fi
    
    log_success "Security Patches angewendet"
}

# 📦 Software Update
run_software_update() {
    log_step "Software Dependencies werden aktualisiert..."
    
    if [ ! "$DRY_RUN" = "true" ]; then
        # Python Dependencies
        log_info "Aktualisiere Python-Packages..."
        pip install -r requirements.txt --upgrade
        
        # Docker Images
        log_info "Aktualisiere Docker Images..."
        docker-compose pull
        
        # System Packages
        case $(uname -s) in
            Linux)
                if command -v apt &> /dev/null; then
                    sudo apt update && sudo apt upgrade -y
                elif command -v pacman &> /dev/null; then
                    sudo pacman -Syu --noconfirm
                fi
                ;;
            Darwin)
                if command -v brew &> /dev/null; then
                    brew update && brew upgrade
                fi
                ;;
        esac
    else
        echo "DRY RUN: Software dependencies würden aktualisiert"
    fi
    
    log_success "Software Update abgeschlossen"
}

# ⚙️ Config Update
run_config_update() {
    local config_file=$1
    
    log_step "Konfiguration wird aktualisiert..."
    
    if [ ! "$DRY_RUN" = "true" ]; then
        # Backup der aktuellen Config
        cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
        
        # Config von Git pullen
        git pull origin main --quiet
        
        # Merge mit lokalen Änderungen
        if [ -f "$config_file" ]; then
            log_info "Lade Konfiguration von: $config_file"
            source "$config_file"
        fi
        
        # Services neu starten wenn nötig
        log_info "Services werden neu gestartet..."
        docker-compose restart
    else
        echo "DRY RUN: Konfiguration würde aktualisiert"
    fi
    
    log_success "Konfiguration aktualisiert"
}

# 🔄 Service Restart
run_service_restart() {
    local services=$1
    
    log_step "Services werden neu gestartet..."
    
    if [ ! "$DRY_RUN" = "true" ]; then
        if [ -z "$services" ]; then
            log_info "Starte alle Services neu..."
            docker-compose restart
        else
            log_info "Starte spezifische Services neu: $services"
            for service in $services; do
                docker-compose restart "$service"
            done
        fi
    else
        echo "DRY RUN: Services würden neu gestartet: ${services:-alle}"
    fi
    
    log_success "Service Restart abgeschlossen"
}

# ↩️ Rollback
run_rollback() {
    local version=$1
    
    log_step "Rollback wird ausgeführt..."
    
    if [ ! "$DRY_RUN" = "true" ]; then
        if [ -z "$version" ]; then
            # Zum letzten Backup zurückkehren
            log_info "Rollback zum letzten Backup..."
            ./scripts/backup/restore_backup.sh --latest
        else
            log_info "Rollback zu Version: $version"
            git checkout "$version"
            ./setup.sh --restore
        fi
        
        # Services neu starten
        docker-compose down
        docker-compose up -d
    else
        echo "DRY RUN: Rollback würde ausgeführt zu: ${version:-latest backup}"
    fi
    
    log_success "Rollback abgeschlossen"
}

# 📊 Status anzeigen
show_status() {
    log_step "Status wird abgerufen..."
    
    # Matrix Service Status
    matrix_status=$(curl -s "$MATRIX_SERVICE_URL/status" || echo '{"error": "Service nicht erreichbar"}')
    
    echo -e "${WHITE}🎩 GENTLEMAN UPDATE STATUS${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${CYAN}Gerät:${NC} $DEVICE_ID ($DEVICE_TYPE)"
    echo -e "${CYAN}Matrix Service:${NC} $MATRIX_SERVICE_URL"
    echo ""
    
    echo -e "${WHITE}📊 Aktive Updates:${NC}"
    echo "$matrix_status" | jq -r '.active_updates // empty'
    echo ""
    
    echo -e "${WHITE}🔐 Autorisierte Benutzer:${NC}"
    echo "$matrix_status" | jq -r '.authorized_users[]? // "Keine"'
    echo ""
    
    echo -e "${WHITE}📝 Letzte Events:${NC}"
    echo "$matrix_status" | jq -r '.recent_events[]? | "\(.timestamp): \(.type) - \(.user_id)"'
}

# 🆔 Gerät registrieren
register_device() {
    local user_id=$1
    
    log_step "Registriere Gerät in Matrix..."
    
    if [ -z "$user_id" ]; then
        read -p "Matrix User ID eingeben (@username:server.com): " user_id
    fi
    
    # Registrierungsanfrage senden
    registration_data="{
        \"device_id\": \"$DEVICE_ID\",
        \"device_type\": \"$DEVICE_TYPE\",
        \"user_id\": \"$user_id\",
        \"hostname\": \"$(hostname)\",
        \"os\": \"$(uname -s)\",
        \"arch\": \"$(uname -m)\",
        \"nebula_cert\": \"$(cat ./nebula/${DEVICE_ID}-node/${DEVICE_ID}.crt | base64 -w 0)\"
    }"
    
    response=$(curl -s -X POST \
        "$MATRIX_SERVICE_URL/register" \
        -H "Content-Type: application/json" \
        -d "$registration_data")
    
    if echo "$response" | jq -e '.success' > /dev/null; then
        log_success "Gerät erfolgreich registriert!"
        log_info "Warte auf Admin-Genehmigung..."
    else
        log_error "Registrierung fehlgeschlagen: $(echo "$response" | jq -r '.error')"
    fi
}

# 🚀 Hauptfunktion
main() {
    print_banner
    
    # Parameter parsen
    COMMAND=""
    USER_ID=""
    FORCE=false
    DRY_RUN=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --device-id)
                DEVICE_ID="$2"
                shift 2
                ;;
            --user-id)
                USER_ID="$2"
                shift 2
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                if [ -z "$COMMAND" ]; then
                    COMMAND="$1"
                else
                    PARAMETERS="$PARAMETERS $1"
                fi
                shift
                ;;
        esac
    done
    
    # Gerät erkennen falls nicht gesetzt
    if [ -z "$DEVICE_ID" ]; then
        detect_device
    fi
    
    # User ID aus Umgebung laden falls nicht gesetzt
    if [ -z "$USER_ID" ] && [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        USER_ID="${MATRIX_USER_ID:-}"
    fi
    
    # Befehl ausführen
    case $COMMAND in
        "status")
            show_status
            ;;
        "register")
            register_device "$USER_ID"
            ;;
        "system_update"|"security_patch"|"software_update"|"config_update"|"service_restart"|"rollback")
            # Matrix Authorization prüfen
            if [ -z "$USER_ID" ]; then
                log_error "Matrix User ID erforderlich. Verwende --user-id oder setze MATRIX_USER_ID in .env"
                exit 1
            fi
            
            if check_authorization "$COMMAND" "$USER_ID"; then
                if [ "$FORCE" = "true" ] || [ "$DRY_RUN" = "true" ]; then
                    execute_update "$COMMAND" "$PARAMETERS"
                else
                    read -p "Update '$COMMAND' auf $DEVICE_ID ausführen? (y/N): " confirm
                    if [[ $confirm =~ ^[Yy]$ ]]; then
                        execute_update "$COMMAND" "$PARAMETERS"
                    else
                        log_info "Update abgebrochen"
                    fi
                fi
            else
                exit 1
            fi
            ;;
        "")
            usage
            exit 1
            ;;
        *)
            log_error "Unbekannter Befehl: $COMMAND"
            usage
            exit 1
            ;;
    esac
}

# Script ausführen falls direkt aufgerufen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 