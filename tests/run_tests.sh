#!/bin/bash

# 🎩 GENTLEMAN - Test Runner Script
# ═══════════════════════════════════════════════════════════════

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Funktionen
print_header() {
    echo -e "${PURPLE}🎩 GENTLEMAN SYSTEM TESTS${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
}

print_step() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

# Hauptfunktion
main() {
    print_header
    
    # Überprüfe ob Python verfügbar ist
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 ist nicht installiert!"
        exit 1
    fi
    
    # Überprüfe ob requests installiert ist
    if ! python3 -c "import requests" &> /dev/null; then
        print_warning "requests Modul nicht gefunden. Installiere..."
        pip3 install requests
    fi
    
    # Überprüfe ob Docker läuft
    if ! docker info &> /dev/null; then
        print_error "Docker ist nicht verfügbar!"
        exit 1
    fi
    
    # Überprüfe ob Services laufen
    print_step "🐳 Überprüfe Docker Services..."
    if ! docker-compose ps | grep -q "Up"; then
        print_error "Gentleman Services laufen nicht!"
        echo "Starte Services mit: docker-compose up -d"
        exit 1
    fi
    
    print_success "Docker Services laufen"
    
    # Warte kurz für Service-Startup
    print_step "⏳ Warte auf Service-Initialisierung..."
    sleep 5
    
    # Bestimme Test-Typ
    case "${1:-local}" in
        "local")
            print_step "🖥️ Führe lokalen Test aus..."
            python3 tests/m1_client_test.py localhost
            ;;
        "distributed")
            if [ -z "$2" ]; then
                print_error "Für distributed Test ist RX-Node IP erforderlich!"
                echo "Verwendung: $0 distributed <RX_NODE_IP>"
                exit 1
            fi
            print_step "🌐 Führe verteilten Test aus (RX-Node: $2)..."
            python3 tests/m1_client_test.py "$2"
            ;;
        "full")
            print_step "🔬 Führe vollständigen Test aus..."
            if [ -f "tests/distributed_system_test.py" ]; then
                python3 tests/distributed_system_test.py
            else
                print_warning "Vollständiger Test nicht verfügbar, führe einfachen Test aus..."
                python3 tests/m1_client_test.py localhost
            fi
            ;;
        *)
            echo "Verwendung: $0 [local|distributed <IP>|full]"
            echo ""
            echo "Optionen:"
            echo "  local                 - Lokaler Test (Standard)"
            echo "  distributed <IP>      - Test gegen entfernte RX-Node"
            echo "  full                  - Vollständiger Systemtest"
            echo ""
            echo "Beispiele:"
            echo "  $0                    # Lokaler Test"
            echo "  $0 local              # Lokaler Test"
            echo "  $0 distributed 192.168.1.100  # Test gegen RX-Node"
            echo "  $0 full               # Vollständiger Test"
            exit 1
            ;;
    esac
    
    # Ergebnis
    if [ $? -eq 0 ]; then
        print_success "Alle Tests erfolgreich!"
        echo ""
        echo -e "${GREEN}🎉 Das Gentleman AI System funktioniert korrekt!${NC}"
    else
        print_error "Tests fehlgeschlagen!"
        echo ""
        echo -e "${RED}❌ Das System benötigt weitere Überprüfung.${NC}"
        exit 1
    fi
}

# Script ausführen
main "$@" 