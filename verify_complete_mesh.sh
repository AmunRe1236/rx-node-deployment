#!/bin/bash

# GENTLEMAN Complete Mesh Verification
# Überprüft das vollständige Tailscale Mesh-Netzwerk

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktion
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "${BLUE}🕸️ GENTLEMAN Complete Mesh Verification${NC}"
log "${BLUE}=======================================${NC}"

# Überprüfe lokalen Tailscale-Status
log "${YELLOW}📊 Lokaler Tailscale-Status:${NC}"
if command -v tailscale >/dev/null 2>&1; then
    tailscale status
    echo ""
else
    log "${RED}❌ Tailscale nicht installiert${NC}"
    exit 1
fi

# Definiere erwartete Nodes
declare -A EXPECTED_NODES=(
    ["M1 Mac"]="100.96.219.28"
    ["iPhone"]="100.123.55.36"
    ["RX Node"]=""
    ["I7 Laptop"]=""
)

# Hole aktuelle Tailscale-Nodes
log "${BLUE}🔍 Erkenne Tailscale-Nodes...${NC}"

# M1 Mac (bereits bekannt)
log "${GREEN}✅ M1 Mac: ${EXPECTED_NODES["M1 Mac"]}${NC}"

# iPhone (bereits bekannt)
log "${GREEN}✅ iPhone: ${EXPECTED_NODES["iPhone"]}${NC}"

# RX Node (falls vorhanden)
RX_IP=$(ssh rx-node "tailscale ip -4" 2>/dev/null || echo "")
if [ -n "$RX_IP" ]; then
    EXPECTED_NODES["RX Node"]="$RX_IP"
    log "${GREEN}✅ RX Node: $RX_IP${NC}"
else
    log "${YELLOW}⚠️ RX Node: Nicht im Tailscale-Netz${NC}"
fi

# I7 Laptop (aktueller Rechner, falls es nicht der M1 ist)
CURRENT_IP=$(tailscale ip -4 2>/dev/null || echo "")
if [ "$CURRENT_IP" != "${EXPECTED_NODES["M1 Mac"]}" ] && [ -n "$CURRENT_IP" ]; then
    EXPECTED_NODES["I7 Laptop"]="$CURRENT_IP"
    log "${GREEN}✅ I7 Laptop: $CURRENT_IP${NC}"
else
    log "${YELLOW}⚠️ I7 Laptop: Nicht erkannt oder ist M1 Mac${NC}"
fi

echo ""

# Teste alle Verbindungen
log "${BLUE}🔍 Teste Mesh-Verbindungen...${NC}"
echo ""

TOTAL_TESTS=0
SUCCESSFUL_TESTS=0

for NODE1_NAME in "${!EXPECTED_NODES[@]}"; do
    NODE1_IP="${EXPECTED_NODES[$NODE1_NAME]}"
    
    if [ -z "$NODE1_IP" ]; then
        continue
    fi
    
    for NODE2_NAME in "${!EXPECTED_NODES[@]}"; do
        NODE2_IP="${EXPECTED_NODES[$NODE2_NAME]}"
        
        if [ -z "$NODE2_IP" ] || [ "$NODE1_NAME" = "$NODE2_NAME" ]; then
            continue
        fi
        
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        
        # Teste Ping (nur vom aktuellen Gerät aus)
        if [ "$NODE1_IP" = "$CURRENT_IP" ] || [ "$NODE1_NAME" = "M1 Mac" ]; then
            if ping -c 1 -W 3 "$NODE2_IP" >/dev/null 2>&1; then
                log "${GREEN}✅ $NODE1_NAME → $NODE2_NAME ($NODE2_IP)${NC}"
                SUCCESSFUL_TESTS=$((SUCCESSFUL_TESTS + 1))
            else
                log "${RED}❌ $NODE1_NAME → $NODE2_NAME ($NODE2_IP)${NC}"
            fi
        fi
    done
done

echo ""

# Berechne Mesh-Coverage
TOTAL_POSSIBLE_CONNECTIONS=0
ACTIVE_NODES=0

for NODE_NAME in "${!EXPECTED_NODES[@]}"; do
    if [ -n "${EXPECTED_NODES[$NODE_NAME]}" ]; then
        ACTIVE_NODES=$((ACTIVE_NODES + 1))
    fi
done

if [ $ACTIVE_NODES -gt 1 ]; then
    TOTAL_POSSIBLE_CONNECTIONS=$((ACTIVE_NODES * (ACTIVE_NODES - 1)))
fi

if [ $TOTAL_POSSIBLE_CONNECTIONS -gt 0 ]; then
    MESH_COVERAGE=$(echo "scale=0; $SUCCESSFUL_TESTS * 100 / $TOTAL_POSSIBLE_CONNECTIONS" | bc 2>/dev/null || echo "0")
else
    MESH_COVERAGE=0
fi

# Zeige Ergebnisse
log "${BLUE}📊 Mesh-Netzwerk Statistiken:${NC}"
echo ""
log "${BLUE}Aktive Nodes: $ACTIVE_NODES/4${NC}"
log "${BLUE}Erfolgreiche Verbindungen: $SUCCESSFUL_TESTS/$TOTAL_POSSIBLE_CONNECTIONS${NC}"
log "${BLUE}Mesh-Coverage: $MESH_COVERAGE%${NC}"

echo ""

if [ $MESH_COVERAGE -ge 80 ]; then
    log "${GREEN}🎉 VOLLSTÄNDIGES MESH-NETZWERK AKTIV!${NC}"
elif [ $MESH_COVERAGE -ge 50 ]; then
    log "${YELLOW}🟡 TEILWEISES MESH-NETZWERK AKTIV${NC}"
else
    log "${RED}🔴 UNVOLLSTÄNDIGES MESH-NETZWERK${NC}"
fi

# Zeige fehlende Integrationen
echo ""
log "${BLUE}📋 Status der Node-Integrationen:${NC}"

for NODE_NAME in "${!EXPECTED_NODES[@]}"; do
    NODE_IP="${EXPECTED_NODES[$NODE_NAME]}"
    if [ -n "$NODE_IP" ]; then
        log "${GREEN}✅ $NODE_NAME: Integriert ($NODE_IP)${NC}"
    else
        log "${RED}❌ $NODE_NAME: Nicht integriert${NC}"
        
        case $NODE_NAME in
            "RX Node")
                log "${YELLOW}   → Führe aus: ./rx_node_tailscale_manual_setup.sh${NC}"
                ;;
            "I7 Laptop")
                log "${YELLOW}   → Führe aus: ./i7_tailscale_setup.sh${NC}"
                ;;
        esac
    fi
done

echo ""

# Zeige verfügbare Scripts
log "${BLUE}🛠️ Verfügbare Setup-Scripts:${NC}"
echo "   ./rx_node_tailscale_manual_setup.sh - RX Node Integration"
echo "   ./i7_tailscale_setup.sh - I7 Laptop Integration"
echo "   ./verify_rx_tailscale.sh - RX Node Verification"
echo "   ./verify_complete_mesh.sh - Vollständige Mesh-Überprüfung"

echo ""
log "${BLUE}📱 Überprüfe auch deine Tailscale-App für alle Geräte!${NC}" 