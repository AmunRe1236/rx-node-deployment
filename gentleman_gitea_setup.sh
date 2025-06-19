#!/bin/bash

# GENTLEMAN Cluster - Vollständige Gitea Server Setup & Konfiguration
# Automatisiert die komplette Git-Infrastruktur mit lokaler Gitea-Instanz

set -e

echo "🏗️ GENTLEMAN Gitea Server Setup & Konfiguration"
echo "================================================"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Basis-Verzeichnis
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Log-Funktionen
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Gitea Server Konfiguration
GITEA_HOST="192.168.100.1"
GITEA_PORT="3010"
GITEA_SSH_PORT="2223"
GITEA_URL="http://${GITEA_HOST}:${GITEA_PORT}"

# Repository Konfiguration
REPO_NAME="gentleman"
ORG_NAME="gentleman"
ADMIN_USER="gentleman"
ADMIN_EMAIL="admin@gentleman.local"
ADMIN_PASSWORD="gentleman123"

# Prüfe Voraussetzungen
check_prerequisites() {
    log "🔍 Prüfe Voraussetzungen..."
    
    # Docker prüfen
    if ! command -v docker &> /dev/null; then
        error "Docker nicht gefunden! Bitte Docker installieren."
        exit 1
    fi
    
    # Docker Compose prüfen
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose nicht gefunden! Bitte Docker Compose installieren."
        exit 1
    fi
    
    # Git prüfen
    if ! command -v git &> /dev/null; then
        error "Git nicht gefunden! Bitte Git installieren."
        exit 1
    fi
    
    success "✅ Alle Voraussetzungen erfüllt"
}

# Stoppe und entferne alte Container
cleanup_old_containers() {
    log "🧹 Bereinige alte Container..."
    
    # Stoppe alte Container
    docker-compose -f offline-repo/docker-compose.yml down 2>/dev/null || true
    
    # Entferne alte Container
    docker rm -f gentleman-git-server gentleman-git-sync 2>/dev/null || true
    
    # Entferne alte Netzwerke
    docker network rm gentleman-mesh gentleman_offline-repo-mesh 2>/dev/null || true
    
    success "✅ Alte Container bereinigt"
}

# Starte Gitea Server
start_gitea_server() {
    log "🚀 Starte Gitea Server..."
    
    cd offline-repo
    
    # Starte Docker Compose Services
    docker-compose up -d
    
    cd ..
    
    # Warte auf Gitea Server
    log "⏳ Warte auf Gitea Server..."
    sleep 15
    
    # Prüfe Health Check
    local attempts=0
    local max_attempts=12
    
    while [ $attempts -lt $max_attempts ]; do
        if curl -s -f "${GITEA_URL}/api/healthz" > /dev/null 2>&1; then
            success "✅ Gitea Server ist bereit!"
            return 0
        fi
        
        attempts=$((attempts + 1))
        log "⏳ Warte auf Gitea... (${attempts}/${max_attempts})"
        sleep 5
    done
    
    error "❌ Gitea Server konnte nicht gestartet werden"
    return 1
}

# Prüfe Gitea Server Status
check_gitea_status() {
    log "📊 Prüfe Gitea Server Status..."
    
    # Container Status
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "gentleman-git-server"; then
        success "✅ Gitea Container läuft"
    else
        error "❌ Gitea Container läuft nicht"
        return 1
    fi
    
    # Health Check
    if curl -s -f "${GITEA_URL}/api/healthz" > /dev/null 2>&1; then
        success "✅ Gitea API antwortet"
    else
        error "❌ Gitea API antwortet nicht"
        return 1
    fi
    
    # Zeige Container Info
    log "📋 Container Informationen:"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep gentleman
}

# Konfiguriere Git Remote für Gitea
configure_git_remotes() {
    log "🔗 Konfiguriere Git Remotes..."
    
    # Entferne alte Gitea Remote falls vorhanden
    git remote remove gitea 2>/dev/null || true
    
    # Füge Gitea Remote hinzu
    git remote add gitea "${GITEA_URL}/${ORG_NAME}/${REPO_NAME}.git"
    
    # Zeige alle Remotes
    log "📋 Konfigurierte Git Remotes:"
    git remote -v
    
    success "✅ Git Remotes konfiguriert"
}

# Erstelle Gitea API Token (falls benötigt)
create_api_token() {
    log "🔑 Erstelle Gitea API Token..."
    
    # Diese Funktion kann erweitert werden für automatische Token-Erstellung
    # Für jetzt zeigen wir die manuelle Anleitung
    
    log "💡 Manueller Schritt erforderlich:"
    log "   1. Gehe zu: ${GITEA_URL}/user/settings/applications"
    log "   2. Erstelle neuen Token: 'gentleman-cluster-token'"
    log "   3. Speichere Token für automatische API-Calls"
}

# Test Gitea Konnektivität
test_gitea_connectivity() {
    log "🧪 Teste Gitea Konnektivität..."
    
    # Web Interface Test
    if curl -s -f "${GITEA_URL}" > /dev/null 2>&1; then
        success "✅ Gitea Web Interface erreichbar"
    else
        warning "⚠️ Gitea Web Interface nicht erreichbar"
    fi
    
    # API Test
    if curl -s -f "${GITEA_URL}/api/v1/version" > /dev/null 2>&1; then
        success "✅ Gitea API erreichbar"
        
        # Zeige Gitea Version
        local version=$(curl -s "${GITEA_URL}/api/v1/version" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        log "📋 Gitea Version: ${version}"
    else
        warning "⚠️ Gitea API nicht erreichbar"
    fi
    
    # SSH Test (falls SSH Key konfiguriert)
    local ssh_test_result=$(ssh -p ${GITEA_SSH_PORT} -o ConnectTimeout=5 -o StrictHostKeyChecking=no git@${GITEA_HOST} 2>&1 || true)
    if echo "${ssh_test_result}" | grep -q "successfully authenticated"; then
        success "✅ Gitea SSH erreichbar"
    else
        log "ℹ️ Gitea SSH: SSH Key Setup erforderlich"
    fi
}

# Öffne Gitea Web Interface
open_gitea_interface() {
    log "🌐 Öffne Gitea Web Interface..."
    
    # Für macOS
    if command -v open &> /dev/null; then
        open "${GITEA_URL}"
        success "✅ Gitea Web Interface geöffnet"
        log "🔗 URL: ${GITEA_URL}"
    else
        log "🔗 Bitte öffne manuell: ${GITEA_URL}"
    fi
    
    log ""
    log "📋 Gitea Setup Informationen:"
    log "   🌐 Web Interface: ${GITEA_URL}"
    log "   🔐 SSH Clone URL: ssh://git@${GITEA_HOST}:${GITEA_SSH_PORT}/${ORG_NAME}/${REPO_NAME}.git"
    log "   📡 HTTP Clone URL: ${GITEA_URL}/${ORG_NAME}/${REPO_NAME}.git"
    log "   👤 Admin User: ${ADMIN_USER}"
    log "   📧 Admin Email: ${ADMIN_EMAIL}"
}

# Sync to Gitea (falls Repository existiert)
sync_to_gitea() {
    log "🔄 Versuche Sync zu Gitea..."
    
    # Teste ob Remote erreichbar ist
    if git ls-remote gitea &> /dev/null; then
        log "📤 Pushe zu Gitea..."
        git push gitea master 2>/dev/null || git push gitea main 2>/dev/null || {
            warning "⚠️ Push zu Gitea fehlgeschlagen - Repository muss erst in Gitea erstellt werden"
        }
    else
        log "ℹ️ Gitea Repository noch nicht verfügbar - erstelle erst Repository in Web Interface"
    fi
}

# Hauptfunktion
main() {
    log "🚀 Starte vollständige Gitea Setup..."
    
    # Option für verschiedene Modi
    case "${1:-full}" in
        "setup")
            check_prerequisites
            cleanup_old_containers
            start_gitea_server
            check_gitea_status
            configure_git_remotes
            test_gitea_connectivity
            open_gitea_interface
            ;;
        "start")
            start_gitea_server
            check_gitea_status
            ;;
        "status")
            check_gitea_status
            test_gitea_connectivity
            ;;
        "sync")
            sync_to_gitea
            ;;
        "stop")
            log "🛑 Stoppe Gitea Server..."
            cd offline-repo && docker-compose down
            success "✅ Gitea Server gestoppt"
            ;;
        "restart")
            log "🔄 Starte Gitea Server neu..."
            cd offline-repo && docker-compose restart
            check_gitea_status
            ;;
        *)
            # Full Setup (Standard)
            check_prerequisites
            cleanup_old_containers
            start_gitea_server
            check_gitea_status
            configure_git_remotes
            test_gitea_connectivity
            create_api_token
            open_gitea_interface
            sync_to_gitea
            ;;
    esac
    
    echo ""
    success "🎉 Gitea Setup abgeschlossen!"
    log ""
    log "🎯 Nächste Schritte:"
    log "   1. Erstelle Admin Account in Web Interface"
    log "   2. Erstelle Organisation '${ORG_NAME}'"
    log "   3. Erstelle Repository '${REPO_NAME}'"
    log "   4. Führe aus: ./gentleman_gitea_setup.sh sync"
    log ""
    log "🔧 Verfügbare Befehle:"
    log "   ./gentleman_gitea_setup.sh setup    - Vollständiges Setup"
    log "   ./gentleman_gitea_setup.sh start    - Starte Server"
    log "   ./gentleman_gitea_setup.sh status   - Zeige Status"
    log "   ./gentleman_gitea_setup.sh sync     - Sync zu Gitea"
    log "   ./gentleman_gitea_setup.sh stop     - Stoppe Server"
    log "   ./gentleman_gitea_setup.sh restart  - Neustart"
}

# Führe Hauptfunktion aus
main "$@" 