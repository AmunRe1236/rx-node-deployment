#!/bin/bash

# 🍎 M1 Mac GENTLEMAN Cluster SSH Synchronisation (macOS kompatibel)
# Koordiniert die bestehende M1 Mac SSH-Rotation mit dem gesamten Cluster
# Version: 1.0 macOS

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
M1_SSH_DIR="$HOME/.ssh"
M1_GENTLEMAN_KEY="$M1_SSH_DIR/gentleman_key"
M1_BACKUP_DIR="$M1_SSH_DIR/key_backups"
M1_ROTATION_LOG="$M1_SSH_DIR/key_rotation.log"
CLUSTER_SCRIPT="cluster_ssh_rotation_macos.sh"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# M1 Mac spezifische Konfiguration
M1_IP="192.168.68.111"
M1_HOSTNAME="Mac-mini-von-Amon.local"

# Cluster Nodes (macOS kompatibel)
I7_NODE_ADDRESS="amonbaumgartner@192.168.68.105"
RX_NODE_ADDRESS="amo9n11@192.168.68.117"

# Get node address by name
get_node_address() {
    local node_name="$1"
    case "$node_name" in
        "i7-node") echo "$I7_NODE_ADDRESS" ;;
        "rx-node") echo "$RX_NODE_ADDRESS" ;;
        *) echo "" ;;
    esac
}

# Get all cluster nodes
get_cluster_nodes() {
    echo "i7-node rx-node"
}

log_header() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║  🍎 M1 MAC CLUSTER SSH SYNCHRONISATION (macOS)              ║${NC}"
    echo -e "${PURPLE}║  Hostname: $M1_HOSTNAME                                      ║${NC}"
    echo -e "${PURPLE}║  Timestamp: $(date +'%Y-%m-%d %H:%M:%S')                                    ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

log() {
    local message="[$(date +'%H:%M:%S')] $1"
    echo -e "${GREEN}✅ $message${NC}"
    echo "$message" >> "$M1_ROTATION_LOG"
}

log_info() {
    local message="[$(date +'%H:%M:%S')] $1"
    echo -e "${BLUE}ℹ️  $message${NC}"
    echo "$message" >> "$M1_ROTATION_LOG"
}

log_warning() {
    local message="[$(date +'%H:%M:%S')] $1"
    echo -e "${YELLOW}⚠️  $message${NC}"
    echo "$message" >> "$M1_ROTATION_LOG"
}

log_error() {
    local message="[$(date +'%H:%M:%S')] $1"
    echo -e "${RED}❌ $message${NC}" >&2
    echo "ERROR: $message" >> "$M1_ROTATION_LOG"
}

# Prüfe M1 Mac SSH Setup
check_m1_ssh_setup() {
    log_info "🔍 Prüfe M1 Mac SSH Setup..."
    
    # Check SSH directory
    if [[ ! -d "$M1_SSH_DIR" ]]; then
        log_error "SSH Directory nicht gefunden: $M1_SSH_DIR"
        return 1
    fi
    
    # Check gentleman key
    if [[ ! -f "$M1_GENTLEMAN_KEY" ]]; then
        log_warning "GENTLEMAN Key nicht gefunden: $M1_GENTLEMAN_KEY"
        return 1
    fi
    
    # Check backup directory
    if [[ ! -d "$M1_BACKUP_DIR" ]]; then
        mkdir -p "$M1_BACKUP_DIR"
        log "📁 Backup Directory erstellt: $M1_BACKUP_DIR"
    fi
    
    # Check existing rotation history
    if [[ -f "$M1_SSH_DIR/.last_key_rotation" ]]; then
        local last_rotation=$(cat "$M1_SSH_DIR/.last_key_rotation")
        log_info "📅 Letzte Rotation: $last_rotation"
    else
        log_warning "⚠️  Keine Rotations-Historie gefunden"
    fi
    
    log "✅ M1 Mac SSH Setup geprüft"
    return 0
}

# Analysiere bestehende SSH Keys auf M1 Mac
analyze_m1_keys() {
    log_info "🔑 Analysiere bestehende SSH Keys auf M1 Mac..."
    
    local key_count=0
    local gentleman_keys=0
    
    echo -e "${CYAN}📋 SSH Keys auf M1 Mac:${NC}"
    for key_file in "$M1_SSH_DIR"/*; do
        if [[ -f "$key_file" && ("$key_file" == *.pub || "$key_file" == *key) ]]; then
            ((key_count++))
            local basename=$(basename "$key_file")
            
            if [[ "$basename" == *gentleman* ]]; then
                ((gentleman_keys++))
                echo -e "   🎩 $basename (GENTLEMAN)"
                
                # Show fingerprint if it's a public key
                if [[ "$key_file" == *.pub ]] && [[ -f "$key_file" ]]; then
                    local fingerprint=$(ssh-keygen -lf "$key_file" 2>/dev/null || echo "Fingerprint nicht verfügbar")
                    echo -e "      Fingerprint: $fingerprint"
                fi
            else
                echo -e "   🔑 $basename"
            fi
        fi
    done
    
    log_info "📊 Gefunden: $key_count Keys total, $gentleman_keys GENTLEMAN Keys"
}

# Teste Cluster Konnektivität von M1 Mac aus
test_cluster_connectivity() {
    log_info "🌐 Teste Cluster Konnektivität von M1 Mac..."
    
    local online_count=0
    local total_count=2
    
    for node_name in $(get_cluster_nodes); do
        local node_address=$(get_node_address "$node_name")
        
        log_info "   📡 Teste Verbindung zu $node_name ($node_address)..."
        
        if ssh -o ConnectTimeout=5 -o BatchMode=yes -i "$M1_GENTLEMAN_KEY" "$node_address" \
           "echo 'M1 Mac connection test successful on $(hostname)'" &>/dev/null; then
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

# Synchronisiere M1 Mac Rotation mit Cluster
sync_m1_with_cluster() {
    log_info "🔄 Synchronisiere M1 Mac mit Cluster..."
    
    # Check if cluster rotation script exists
    if [[ ! -f "$CLUSTER_SCRIPT" ]]; then
        log_error "Cluster Rotation Script nicht gefunden: $CLUSTER_SCRIPT"
        return 1
    fi
    
    # Backup current M1 key before sync
    if [[ -f "$M1_GENTLEMAN_KEY" ]]; then
        cp "$M1_GENTLEMAN_KEY" "$M1_BACKUP_DIR/gentleman_key_pre_cluster_sync_$TIMESTAMP"
        cp "$M1_GENTLEMAN_KEY.pub" "$M1_BACKUP_DIR/gentleman_key_pre_cluster_sync_$TIMESTAMP.pub"
        log "💾 M1 Key vor Cluster-Sync gesichert"
    fi
    
    # Run cluster rotation from M1 Mac
    log_info "🚀 Starte Cluster-Rotation von M1 Mac..."
    if bash "$CLUSTER_SCRIPT" run; then
        log "✅ Cluster-Rotation erfolgreich ausgeführt"
    else
        log_error "❌ Cluster-Rotation fehlgeschlagen"
        return 1
    fi
    
    # Update M1 Mac specific rotation timestamp
    echo "$TIMESTAMP" > "$M1_SSH_DIR/.last_cluster_sync"
    log "📅 M1 Mac Cluster-Sync Zeitstempel aktualisiert"
    
    return 0
}

# Verteile M1 Mac Key an Cluster
distribute_m1_key_to_cluster() {
    log_info "📤 Verteile M1 Mac Key an Cluster..."
    
    local success_count=0
    local total_count=2
    
    for node_name in $(get_cluster_nodes); do
        local node_address=$(get_node_address "$node_name")
        
        log_info "   📡 Übertrage M1 Key zu $node_name ($node_address)..."
        
        # Test connection first
        if ssh -o ConnectTimeout=5 -o BatchMode=yes -i "$M1_GENTLEMAN_KEY" "$node_address" \
           "echo 'connection test'" &>/dev/null; then
            
            # Add M1 public key to node's authorized_keys
            if cat "$M1_GENTLEMAN_KEY.pub" | \
               ssh -i "$M1_GENTLEMAN_KEY" "$node_address" \
               "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"; then
                
                log "   ✅ M1 Key erfolgreich zu $node_name übertragen"
                ((success_count++))
            else
                log_error "   ❌ M1 Key-Übertragung zu $node_name fehlgeschlagen"
            fi
        else
            log_warning "   ⚠️  $node_name nicht erreichbar"
        fi
    done
    
    log_info "📊 M1 Key Verteilung: $success_count/$total_count Nodes aktualisiert"
    
    if [[ $success_count -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Sammle Cluster Keys auf M1 Mac
collect_cluster_keys() {
    log_info "📥 Sammle Cluster Keys auf M1 Mac..."
    
    local collected_keys=0
    
    for node_name in $(get_cluster_nodes); do
        local node_address=$(get_node_address "$node_name")
        
        log_info "   📡 Hole Public Key von $node_name..."
        
        if ssh -o ConnectTimeout=5 -i "$M1_GENTLEMAN_KEY" "$node_address" \
           "cat ~/.ssh/gentleman_key.pub 2>/dev/null || cat ~/.ssh/id_*.pub 2>/dev/null | head -1" > "/tmp/${node_name}_key.pub" 2>/dev/null; then
            
            if [[ -s "/tmp/${node_name}_key.pub" ]]; then
                # Add to M1 Mac authorized_keys
                cat "/tmp/${node_name}_key.pub" >> "$M1_SSH_DIR/authorized_keys"
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
    if [[ -f "$M1_SSH_DIR/authorized_keys" ]]; then
        sort -u "$M1_SSH_DIR/authorized_keys" -o "$M1_SSH_DIR/authorized_keys"
        chmod 600 "$M1_SSH_DIR/authorized_keys"
        log "🧹 Authorized_keys bereinigt und sortiert"
    fi
    
    log_info "📊 Cluster Keys gesammelt: $collected_keys Keys"
    return 0
}

# Erstelle M1 Mac Cluster Status Report
create_m1_status_report() {
    log_info "📋 Erstelle M1 Mac Cluster Status Report..."
    
    local report_file="m1_cluster_status_$TIMESTAMP.md"
    
    cat > "$report_file" << EOF
# 🍎 M1 Mac GENTLEMAN Cluster Status Report

**Datum**: $(date)  
**M1 Mac**: $M1_HOSTNAME ($M1_IP)  
**Report ID**: $TIMESTAMP

---

## 🔑 SSH Key Status

### M1 Mac GENTLEMAN Key:
- **Pfad**: $M1_GENTLEMAN_KEY
- **Fingerprint**: $(ssh-keygen -lf "$M1_GENTLEMAN_KEY.pub" 2>/dev/null || echo "Nicht verfügbar")
- **Erstellt**: $(stat -f "%Sm" "$M1_GENTLEMAN_KEY" 2>/dev/null || echo "Unbekannt")

### Backup Status:
- **Backup Directory**: $M1_BACKUP_DIR
- **Anzahl Backups**: $(ls -1 "$M1_BACKUP_DIR"/gentleman_key_* 2>/dev/null | wc -l | tr -d ' ')

---

## 🌐 Cluster Konnektivität

$(for node_name in $(get_cluster_nodes); do
    node_address=$(get_node_address "$node_name")
    if ssh -o ConnectTimeout=3 -o BatchMode=yes -i "$M1_GENTLEMAN_KEY" "$node_address" "echo 'online'" &>/dev/null; then
        echo "- **$node_name** ($node_address): ✅ ONLINE"
    else
        echo "- **$node_name** ($node_address): ❌ OFFLINE"
    fi
done)

---

## 📅 Rotation History

### Letzte Rotationen:
$(if [[ -f "$M1_SSH_DIR/.last_key_rotation" ]]; then
    echo "- **System Rotation**: $(cat "$M1_SSH_DIR/.last_key_rotation")"
else
    echo "- **System Rotation**: Keine Historie"
fi)

$(if [[ -f "$M1_SSH_DIR/.last_cluster_sync" ]]; then
    echo "- **Cluster Sync**: $(cat "$M1_SSH_DIR/.last_cluster_sync")"
else
    echo "- **Cluster Sync**: Nie durchgeführt"
fi)

---

## 📊 Empfehlungen

$(if [[ $(ls -1 "$M1_BACKUP_DIR"/gentleman_key_* 2>/dev/null | wc -l | tr -d ' ') -gt 15 ]]; then
    echo "- ⚠️  Backup-Bereinigung empfohlen (>15 Backups)"
fi)

$(if ! ssh -o ConnectTimeout=3 -o BatchMode=yes -i "$M1_GENTLEMAN_KEY" "amonbaumgartner@192.168.68.105" "echo test" &>/dev/null; then
    echo "- ⚠️  i7 Node nicht erreichbar - SSH Tunnel prüfen"
fi)

$(if ! ssh -o ConnectTimeout=3 -o BatchMode=yes -i "$M1_GENTLEMAN_KEY" "amo9n11@192.168.68.117" "echo test" &>/dev/null; then
    echo "- ⚠️  RX Node nicht erreichbar - Netzwerk prüfen"
fi)

---

**Report erstellt von**: M1 Mac Cluster Sync Script v1.0 macOS
EOF
    
    log "📄 Status Report erstellt: $report_file"
}

# Main functions
run_m1_cluster_sync() {
    log_header
    
    log "🚀 Starte M1 Mac Cluster Synchronisation..."
    
    # Step 1: Check M1 setup
    if ! check_m1_ssh_setup; then
        log_error "M1 Mac SSH Setup unvollständig"
        exit 1
    fi
    
    # Step 2: Analyze existing keys
    analyze_m1_keys
    
    # Step 3: Test cluster connectivity
    if test_cluster_connectivity; then
        log "✅ Cluster erreichbar - führe Synchronisation durch"
        
        # Step 4: Sync with cluster
        if sync_m1_with_cluster; then
            log "✅ Cluster-Synchronisation erfolgreich"
        else
            log_warning "⚠️  Cluster-Synchronisation teilweise fehlgeschlagen"
        fi
        
        # Step 5: Distribute M1 key
        if distribute_m1_key_to_cluster; then
            log "✅ M1 Key-Verteilung erfolgreich"
        else
            log_warning "⚠️  M1 Key-Verteilung teilweise fehlgeschlagen"
        fi
        
        # Step 6: Collect cluster keys
        collect_cluster_keys
        
    else
        log_warning "⚠️  Cluster nicht erreichbar - lokale Rotation nur"
    fi
    
    # Step 7: Create status report
    create_m1_status_report
    
    log "🎉 M1 Mac Cluster Synchronisation abgeschlossen!"
    log_info "📊 Sync ID: $TIMESTAMP"
    log_info "📝 Log: $M1_ROTATION_LOG"
}

# Command line interface
case "${1:-sync}" in
    "sync"|"run")
        run_m1_cluster_sync
        ;;
    "status")
        check_m1_ssh_setup
        analyze_m1_keys
        test_cluster_connectivity
        ;;
    "test")
        test_cluster_connectivity
        ;;
    "collect")
        collect_cluster_keys
        ;;
    "distribute")
        distribute_m1_key_to_cluster
        ;;
    "report")
        create_m1_status_report
        ;;
    "help"|"-h"|"--help")
        echo "🍎 M1 Mac GENTLEMAN Cluster SSH Synchronisation (macOS kompatibel)"
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  sync, run    - Vollständige M1 Mac Cluster-Synchronisation"
        echo "  status       - Zeige M1 Mac und Cluster Status"
        echo "  test         - Teste nur Cluster-Konnektivität"
        echo "  collect      - Sammle Cluster Keys auf M1 Mac"
        echo "  distribute   - Verteile M1 Key an Cluster"
        echo "  report       - Erstelle Status Report"
        echo "  help         - Zeige diese Hilfe"
        ;;
    *)
        log_error "Unbekannter Befehl: $1"
        echo "Verwende '$0 help' für Hilfe"
        exit 1
        ;;
esac 