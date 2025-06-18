#!/bin/bash

# 🎮 RX Node GENTLEMAN Cluster SSH Synchronisation
# GPU-powered Primary Trainer Node Koordination und SSH-Rotation
# Version: 1.0

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
RX_SSH_DIR="$HOME/.ssh"
RX_GENTLEMAN_KEY="$RX_SSH_DIR/gentleman_key"
RX_BACKUP_DIR="$RX_SSH_DIR/key_backups"
RX_ROTATION_LOG="$RX_SSH_DIR/key_rotation.log"
CLUSTER_SCRIPT="cluster_ssh_rotation_macos.sh"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# RX Node spezifische Konfiguration
RX_IP="192.168.68.117"
RX_HOSTNAME="rx-node"
RX_ROLE="primary_trainer"
RX_GPU="AMD RX 6700 XT"

# Cluster Nodes (RX Node Perspektive)
I7_NODE_ADDRESS="amonbaumgartner@192.168.68.105"
M1_MAC_ADDRESS="amonbaumgartner@192.168.68.111"

# Get node address by name
get_node_address() {
    local node_name="$1"
    case "$node_name" in
        "i7-node") echo "$I7_NODE_ADDRESS" ;;
        "m1-mac") echo "$M1_MAC_ADDRESS" ;;
        *) echo "" ;;
    esac
}

# Get all cluster nodes (from RX perspective)
get_cluster_nodes() {
    echo "i7-node m1-mac"
}

log_header() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║  🎮 RX NODE CLUSTER SSH SYNCHRONISATION                     ║${NC}"
    echo -e "${PURPLE}║  GPU: $RX_GPU                                   ║${NC}"
    echo -e "${PURPLE}║  Role: Primary Trainer | IP: $RX_IP                         ║${NC}"
    echo -e "${PURPLE}║  Timestamp: $(date +'%Y-%m-%d %H:%M:%S')                                    ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

log() {
    local message="[$(date +'%H:%M:%S')] $1"
    echo -e "${GREEN}✅ $message${NC}"
    echo "$message" >> "$RX_ROTATION_LOG"
}

log_info() {
    local message="[$(date +'%H:%M:%S')] $1"
    echo -e "${BLUE}ℹ️  $message${NC}"
    echo "$message" >> "$RX_ROTATION_LOG"
}

log_warning() {
    local message="[$(date +'%H:%M:%S')] $1"
    echo -e "${YELLOW}⚠️  $message${NC}"
    echo "$message" >> "$RX_ROTATION_LOG"
}

log_error() {
    local message="[$(date +'%H:%M:%S')] $1"
    echo -e "${RED}❌ $message${NC}" >&2
    echo "ERROR: $message" >> "$RX_ROTATION_LOG"
}

# Prüfe RX Node SSH Setup
check_rx_ssh_setup() {
    log_info "🔍 Prüfe RX Node SSH Setup..."
    
    # Check SSH directory
    if [[ ! -d "$RX_SSH_DIR" ]]; then
        mkdir -p "$RX_SSH_DIR"
        chmod 700 "$RX_SSH_DIR"
        log "📁 SSH Directory erstellt: $RX_SSH_DIR"
    fi
    
    # Check gentleman key
    if [[ ! -f "$RX_GENTLEMAN_KEY" ]]; then
        log_warning "GENTLEMAN Key nicht gefunden: $RX_GENTLEMAN_KEY"
        log_info "🔑 Generiere neuen RX Node SSH Key..."
        
        # Generate new key for RX Node
        ssh-keygen -t ed25519 -f "$RX_GENTLEMAN_KEY" -N "" \
            -C "gentleman-rx-node-$(date +%Y%m%d)"
        
        chmod 600 "$RX_GENTLEMAN_KEY"
        chmod 644 "$RX_GENTLEMAN_KEY.pub"
        
        log "🔑 Neuer RX Node SSH Key generiert"
    fi
    
    # Check backup directory
    if [[ ! -d "$RX_BACKUP_DIR" ]]; then
        mkdir -p "$RX_BACKUP_DIR"
        log "📁 Backup Directory erstellt: $RX_BACKUP_DIR"
    fi
    
    # Check existing rotation history
    if [[ -f "$RX_SSH_DIR/.last_key_rotation" ]]; then
        local last_rotation=$(cat "$RX_SSH_DIR/.last_key_rotation")
        log_info "📅 Letzte Rotation: $last_rotation"
    else
        log_warning "⚠️  Keine Rotations-Historie gefunden"
    fi
    
    log "✅ RX Node SSH Setup geprüft"
    return 0
}

# Analysiere RX Node System
analyze_rx_system() {
    log_info "🎮 Analysiere RX Node System..."
    
    echo -e "${CYAN}📋 RX Node System Information:${NC}"
    
    # System Info
    if command -v lscpu &>/dev/null; then
        local cpu_info=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
        echo -e "   💻 CPU: $cpu_info"
    fi
    
    # Memory Info
    if [[ -f /proc/meminfo ]]; then
        local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        local mem_gb=$((mem_total / 1024 / 1024))
        echo -e "   🧠 RAM: ${mem_gb}GB"
    fi
    
    # GPU Info
    if command -v lspci &>/dev/null; then
        local gpu_info=$(lspci | grep -i vga | head -1 | cut -d: -f3 | xargs)
        echo -e "   🎮 GPU: $gpu_info"
    fi
    
    # Disk Info
    if command -v df &>/dev/null; then
        local disk_info=$(df -h / | tail -1 | awk '{print $2 " total, " $4 " free"}')
        echo -e "   💾 Disk: $disk_info"
    fi
    
    # Network Info
    local network_info=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || echo "Unknown")
    echo -e "   🌐 IP: $network_info"
    
    # SSH Keys
    local key_count=$(ls -1 "$RX_SSH_DIR"/*key* 2>/dev/null | wc -l)
    echo -e "   🔑 SSH Keys: $key_count"
    
    log_info "📊 RX Node System analysiert"
}

# Teste Cluster Konnektivität vom RX Node aus
test_cluster_connectivity() {
    log_info "🌐 Teste Cluster Konnektivität vom RX Node..."
    
    local online_count=0
    local total_count=2
    
    for node_name in $(get_cluster_nodes); do
        local node_address=$(get_node_address "$node_name")
        
        log_info "   📡 Teste Verbindung zu $node_name ($node_address)..."
        
        if ssh -o ConnectTimeout=5 -o BatchMode=yes -i "$RX_GENTLEMAN_KEY" "$node_address" \
           "echo 'RX Node connection test successful on $(hostname)'" &>/dev/null; then
            log "   ✅ $node_name: ONLINE"
            ((online_count++))
        else
            log_warning "   ❌ $node_name: OFFLINE oder nicht erreichbar"
        fi
    done
    
    log_info "📊 Cluster Konnektivität: $online_count/$total_count Nodes erreichbar"
    
    if [[ $online_count -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# RX Node GPU Status prüfen
check_gpu_status() {
    log_info "🎮 Prüfe GPU Status..."
    
    # Check for AMD GPU tools
    if command -v rocm-smi &>/dev/null; then
        echo -e "${CYAN}📊 AMD GPU Status (rocm-smi):${NC}"
        rocm-smi --showtemp --showpower --showuse 2>/dev/null || echo "   ⚠️  ROCm SMI nicht verfügbar"
    elif command -v radeontop &>/dev/null; then
        echo -e "${CYAN}📊 AMD GPU Status (radeontop):${NC}"
        timeout 3 radeontop -d - -l 1 2>/dev/null || echo "   ⚠️  Radeontop nicht verfügbar"
    else
        log_warning "Keine AMD GPU Monitoring Tools gefunden"
    fi
    
    # Check GPU memory
    if [[ -d /sys/class/drm/card0/device ]]; then
        echo -e "   🎮 GPU Device: $(cat /sys/class/drm/card0/device/vendor 2>/dev/null):$(cat /sys/class/drm/card0/device/device 2>/dev/null)"
    fi
    
    log "✅ GPU Status geprüft"
}

# Generiere RX Node spezifischen SSH Key
generate_rx_cluster_key() {
    log_info "🔑 Generiere neuen RX Node Cluster SSH Key..."
    
    # Backup existing key
    if [[ -f "$RX_GENTLEMAN_KEY" ]]; then
        cp "$RX_GENTLEMAN_KEY" "$RX_BACKUP_DIR/gentleman_key_$TIMESTAMP"
        cp "$RX_GENTLEMAN_KEY.pub" "$RX_BACKUP_DIR/gentleman_key_$TIMESTAMP.pub"
        log "💾 Alter Key gesichert: $RX_BACKUP_DIR/gentleman_key_$TIMESTAMP"
    fi
    
    # Generate new ED25519 key with RX Node identifier
    ssh-keygen -t ed25519 -f "$RX_GENTLEMAN_KEY" -N "" \
        -C "gentleman-rx-cluster-$RX_HOSTNAME-$TIMESTAMP"
    
    chmod 600 "$RX_GENTLEMAN_KEY"
    chmod 644 "$RX_GENTLEMAN_KEY.pub"
    
    local fingerprint=$(ssh-keygen -lf "$RX_GENTLEMAN_KEY.pub")
    log "🔑 Neuer RX Cluster Key generiert"
    log_info "   Fingerprint: $fingerprint"
    log_info "   Comment: gentleman-rx-cluster-$RX_HOSTNAME-$TIMESTAMP"
}

# Verteile RX Node Key an Cluster
distribute_rx_key_to_cluster() {
    log_info "📤 Verteile RX Node Key an Cluster..."
    
    local success_count=0
    local total_count=2
    
    for node_name in $(get_cluster_nodes); do
        local node_address=$(get_node_address "$node_name")
        
        log_info "   📡 Übertrage RX Key zu $node_name ($node_address)..."
        
        # Test connection first
        if ssh -o ConnectTimeout=5 -o BatchMode=yes -i "$RX_GENTLEMAN_KEY" "$node_address" \
           "echo 'connection test'" &>/dev/null; then
            
            # Add RX public key to node's authorized_keys
            if cat "$RX_GENTLEMAN_KEY.pub" | \
               ssh -i "$RX_GENTLEMAN_KEY" "$node_address" \
               "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"; then
                
                log "   ✅ RX Key erfolgreich zu $node_name übertragen"
                ((success_count++))
            else
                log_error "   ❌ RX Key-Übertragung zu $node_name fehlgeschlagen"
            fi
        else
            log_warning "   ⚠️  $node_name nicht erreichbar"
        fi
    done
    
    log_info "📊 RX Key Verteilung: $success_count/$total_count Nodes aktualisiert"
    
    if [[ $success_count -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Sammle Cluster Keys auf RX Node
collect_cluster_keys() {
    log_info "📥 Sammle Cluster Keys auf RX Node..."
    
    local collected_keys=0
    
    for node_name in $(get_cluster_nodes); do
        local node_address=$(get_node_address "$node_name")
        
        log_info "   📡 Hole Public Key von $node_name..."
        
        if ssh -o ConnectTimeout=5 -i "$RX_GENTLEMAN_KEY" "$node_address" \
           "cat ~/.ssh/gentleman_key.pub 2>/dev/null || cat ~/.ssh/id_*.pub 2>/dev/null | head -1" > "/tmp/${node_name}_key.pub" 2>/dev/null; then
            
            if [[ -s "/tmp/${node_name}_key.pub" ]]; then
                # Add to RX Node authorized_keys
                cat "/tmp/${node_name}_key.pub" >> "$RX_SSH_DIR/authorized_keys"
                log "   ✅ Key von $node_name gesammelt"
                ((collected_keys++))
            else
                log_warning "   ⚠️  Kein Key von $node_name erhalten"
            fi
            
            rm -f "/tmp/${node_name}_key.pub"
        else
            log_warning "   ❌ Kann nicht zu $node_name verbinden"
        fi
    done
    
    # Clean up duplicates in authorized_keys
    if [[ -f "$RX_SSH_DIR/authorized_keys" ]]; then
        sort -u "$RX_SSH_DIR/authorized_keys" -o "$RX_SSH_DIR/authorized_keys"
        chmod 600 "$RX_SSH_DIR/authorized_keys"
        log "🧹 Authorized_keys bereinigt und sortiert"
    fi
    
    log_info "📊 Cluster Keys gesammelt: $collected_keys Keys"
    return 0
}

# Synchronisiere GENTLEMAN Protocol
sync_gentleman_protocol() {
    log_info "🎩 Synchronisiere GENTLEMAN Protocol..."
    
    # Check if GENTLEMAN Protocol is running
    if pgrep -f "talking_gentleman_protocol.py" >/dev/null; then
        log "🎩 GENTLEMAN Protocol läuft bereits"
        
        # Test HTTP endpoint
        if curl -s --connect-timeout 3 http://localhost:8008/status >/dev/null 2>&1; then
            log "✅ GENTLEMAN HTTP API erreichbar (Port 8008)"
        else
            log_warning "⚠️  GENTLEMAN HTTP API nicht erreichbar"
        fi
    else
        log_warning "⚠️  GENTLEMAN Protocol nicht aktiv"
        
        # Try to start if script exists
        if [[ -f "talking_gentleman_protocol.py" ]]; then
            log_info "🚀 Starte GENTLEMAN Protocol..."
            python3 talking_gentleman_protocol.py --start &
            sleep 3
            
            if pgrep -f "talking_gentleman_protocol.py" >/dev/null; then
                log "✅ GENTLEMAN Protocol gestartet"
            else
                log_error "❌ GENTLEMAN Protocol Start fehlgeschlagen"
            fi
        fi
    fi
}

# Erstelle RX Node Cluster Status Report
create_rx_status_report() {
    log_info "📋 Erstelle RX Node Cluster Status Report..."
    
    local report_file="rx_cluster_status_$TIMESTAMP.md"
    
    cat > "$report_file" << EOF
# 🎮 RX Node GENTLEMAN Cluster Status Report

**Datum**: $(date)  
**RX Node**: $RX_HOSTNAME ($RX_IP)  
**GPU**: $RX_GPU  
**Rolle**: Primary Trainer  
**Report ID**: $TIMESTAMP

---

## 🔑 SSH Key Status

### RX Node GENTLEMAN Key:
- **Pfad**: $RX_GENTLEMAN_KEY
- **Fingerprint**: $(ssh-keygen -lf "$RX_GENTLEMAN_KEY.pub" 2>/dev/null || echo "Nicht verfügbar")
- **Erstellt**: $(stat -c "%y" "$RX_GENTLEMAN_KEY" 2>/dev/null || echo "Unbekannt")

### Backup Status:
- **Backup Directory**: $RX_BACKUP_DIR
- **Anzahl Backups**: $(ls -1 "$RX_BACKUP_DIR"/gentleman_key_* 2>/dev/null | wc -l)

---

## 🎮 GPU & System Status

### Hardware:
- **GPU**: $RX_GPU
- **CPU**: $(lscpu | grep "Model name" | cut -d: -f2 | xargs 2>/dev/null || echo "Unbekannt")
- **RAM**: $(free -h | grep Mem | awk '{print $2}' 2>/dev/null || echo "Unbekannt")
- **Disk**: $(df -h / | tail -1 | awk '{print $4 " free"}' 2>/dev/null || echo "Unbekannt")

### GENTLEMAN Protocol:
- **Status**: $(pgrep -f "talking_gentleman_protocol.py" >/dev/null && echo "✅ Aktiv" || echo "❌ Inaktiv")
- **HTTP API**: $(curl -s --connect-timeout 3 http://localhost:8008/status >/dev/null 2>&1 && echo "✅ Port 8008" || echo "❌ Nicht erreichbar")

---

## 🌐 Cluster Konnektivität

$(for node_name in $(get_cluster_nodes); do
    node_address=$(get_node_address "$node_name")
    if ssh -o ConnectTimeout=3 -o BatchMode=yes -i "$RX_GENTLEMAN_KEY" "$node_address" "echo 'online'" &>/dev/null; then
        echo "- **$node_name** ($node_address): ✅ ONLINE"
    else
        echo "- **$node_name** ($node_address): ❌ OFFLINE"
    fi
done)

---

## 📅 Rotation History

### Letzte Rotationen:
$(if [[ -f "$RX_SSH_DIR/.last_key_rotation" ]]; then
    echo "- **System Rotation**: $(cat "$RX_SSH_DIR/.last_key_rotation")"
else
    echo "- **System Rotation**: Keine Historie"
fi)

$(if [[ -f "$RX_SSH_DIR/.last_cluster_sync" ]]; then
    echo "- **Cluster Sync**: $(cat "$RX_SSH_DIR/.last_cluster_sync")"
else
    echo "- **Cluster Sync**: Nie durchgeführt"
fi)

---

## 📊 Empfehlungen

$(if [[ $(ls -1 "$RX_BACKUP_DIR"/gentleman_key_* 2>/dev/null | wc -l) -gt 15 ]]; then
    echo "- ⚠️  Backup-Bereinigung empfohlen (>15 Backups)"
fi)

$(if ! ssh -o ConnectTimeout=3 -o BatchMode=yes -i "$RX_GENTLEMAN_KEY" "amonbaumgartner@192.168.68.105" "echo test" &>/dev/null; then
    echo "- ⚠️  i7 Node nicht erreichbar - SSH Key prüfen"
fi)

$(if ! ssh -o ConnectTimeout=3 -o BatchMode=yes -i "$RX_GENTLEMAN_KEY" "amonbaumgartner@192.168.68.111" "echo test" &>/dev/null; then
    echo "- ⚠️  M1 Mac nicht erreichbar - SSH Key prüfen"
fi)

$(if ! pgrep -f "talking_gentleman_protocol.py" >/dev/null; then
    echo "- ⚠️  GENTLEMAN Protocol nicht aktiv - Service starten"
fi)

---

**Report erstellt von**: RX Node Cluster Sync Script v1.0
EOF
    
    log "📄 Status Report erstellt: $report_file"
}

# Main functions
run_rx_cluster_sync() {
    log_header
    
    log "🚀 Starte RX Node Cluster Synchronisation..."
    
    # Step 1: Check RX setup
    if ! check_rx_ssh_setup; then
        log_error "RX Node SSH Setup unvollständig"
        exit 1
    fi
    
    # Step 2: Analyze RX system
    analyze_rx_system
    
    # Step 3: Check GPU status
    check_gpu_status
    
    # Step 4: Test cluster connectivity
    if test_cluster_connectivity; then
        log "✅ Cluster erreichbar - führe Synchronisation durch"
        
        # Step 5: Generate RX cluster key
        generate_rx_cluster_key
        
        # Step 6: Distribute RX key
        if distribute_rx_key_to_cluster; then
            log "✅ RX Key-Verteilung erfolgreich"
        else
            log_warning "⚠️  RX Key-Verteilung teilweise fehlgeschlagen"
        fi
        
        # Step 7: Collect cluster keys
        collect_cluster_keys
        
    else
        log_warning "⚠️  Cluster nicht erreichbar - lokale Rotation nur"
        generate_rx_cluster_key
    fi
    
    # Step 8: Sync GENTLEMAN Protocol
    sync_gentleman_protocol
    
    # Step 9: Update timestamps
    echo "$TIMESTAMP" > "$RX_SSH_DIR/.last_cluster_sync"
    echo "$TIMESTAMP" > "$RX_SSH_DIR/.last_key_rotation"
    
    # Step 10: Create status report
    create_rx_status_report
    
    log "🎉 RX Node Cluster Synchronisation abgeschlossen!"
    log_info "📊 Sync ID: $TIMESTAMP"
    log_info "📝 Log: $RX_ROTATION_LOG"
}

# Command line interface
case "${1:-sync}" in
    "sync"|"run")
        run_rx_cluster_sync
        ;;
    "status")
        check_rx_ssh_setup
        analyze_rx_system
        check_gpu_status
        test_cluster_connectivity
        ;;
    "test")
        test_cluster_connectivity
        ;;
    "gpu")
        check_gpu_status
        ;;
    "keys")
        generate_rx_cluster_key
        ;;
    "collect")
        collect_cluster_keys
        ;;
    "distribute")
        distribute_rx_key_to_cluster
        ;;
    "gentleman")
        sync_gentleman_protocol
        ;;
    "report")
        create_rx_status_report
        ;;
    "help"|"-h"|"--help")
        echo "🎮 RX Node GENTLEMAN Cluster SSH Synchronisation"
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  sync, run    - Vollständige RX Node Cluster-Synchronisation"
        echo "  status       - Zeige RX Node System und Cluster Status"
        echo "  test         - Teste nur Cluster-Konnektivität"
        echo "  gpu          - Zeige GPU Status"
        echo "  keys         - Generiere neuen SSH Key"
        echo "  collect      - Sammle Cluster Keys auf RX Node"
        echo "  distribute   - Verteile RX Key an Cluster"
        echo "  gentleman    - Synchronisiere GENTLEMAN Protocol"
        echo "  report       - Erstelle Status Report"
        echo "  help         - Zeige diese Hilfe"
        ;;
    *)
        log_error "Unbekannter Befehl: $1"
        echo "Verwende '$0 help' für Hilfe"
        exit 1
        ;;
esac 