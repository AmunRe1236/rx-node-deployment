#!/bin/bash

# 🔄 GENTLEMAN Cluster-weite SSH Key Rotation & Synchronisation (macOS kompatibel)
# Version: 2.0 macOS
# Erweitert die bestehende M1 Mac Rotation auf das gesamte Cluster
# Author: GENTLEMAN AI System

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
GENTLEMAN_KEY_PATH="$HOME/.ssh/gentleman_key"
BACKUP_DIR="$HOME/.ssh/key_backups"
ROTATION_LOG="$HOME/.ssh/key_rotation.log"
CLUSTER_CONFIG="cluster_rotation_config.json"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Cluster Nodes (macOS kompatibel - ohne assoziative Arrays)
I7_NODE_ADDRESS="amonbaumgartner@192.168.68.105"
RX_NODE_ADDRESS="amo9n11@192.168.68.117"
M1_MAC_ADDRESS="amonbaumgartner@192.168.68.111"

# Current node detection
CURRENT_IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
case "$CURRENT_IP" in
    "192.168.68.105") CURRENT_NODE="i7-node" ;;
    "192.168.68.117") CURRENT_NODE="rx-node" ;;
    "192.168.68.111") CURRENT_NODE="m1-mac" ;;
    *) CURRENT_NODE="unknown" ;;
esac

# Fallback node detection if IP method fails
if [[ "$CURRENT_NODE" == "unknown" ]]; then
    HOSTNAME_CHECK=$(hostname 2>/dev/null || echo "unknown")
    if [[ "$HOSTNAME_CHECK" == *"MacBook-Pro-von-Amon"* ]]; then
        CURRENT_NODE="i7-node"
    elif [[ "$HOSTNAME_CHECK" == *"Mac-mini"* ]]; then
        CURRENT_NODE="m1-mac"
    elif [[ "$HOSTNAME_CHECK" == *"rx"* ]]; then
        CURRENT_NODE="rx-node"
    else
        CURRENT_NODE="i7-node"  # Default fallback
    fi
fi

# Functions
log_header() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║  🔄 GENTLEMAN CLUSTER SSH KEY ROTATION & SYNC (macOS)        ║${NC}"
    echo -e "${PURPLE}║  Node: ${CURRENT_NODE} | Timestamp: $(date +'%Y-%m-%d %H:%M:%S')             ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

log() {
    local message="[$(date +'%H:%M:%S')] $1"
    echo -e "${GREEN}✅ $message${NC}"
    echo "$message" >> "$ROTATION_LOG"
}

log_info() {
    local message="[$(date +'%H:%M:%S')] $1"
    echo -e "${BLUE}ℹ️  $message${NC}"
    echo "$message" >> "$ROTATION_LOG"
}

log_warning() {
    local message="[$(date +'%H:%M:%S')] $1"
    echo -e "${YELLOW}⚠️  $message${NC}"
    echo "$message" >> "$ROTATION_LOG"
}

log_error() {
    local message="[$(date +'%H:%M:%S')] $1"
    echo -e "${RED}❌ $message${NC}" >&2
    echo "ERROR: $message" >> "$ROTATION_LOG"
}

# Get node address by name
get_node_address() {
    local node_name="$1"
    case "$node_name" in
        "i7-node") echo "$I7_NODE_ADDRESS" ;;
        "rx-node") echo "$RX_NODE_ADDRESS" ;;
        "m1-mac") echo "$M1_MAC_ADDRESS" ;;
        *) echo "" ;;
    esac
}

# Get all node names
get_all_nodes() {
    echo "i7-node rx-node m1-mac"
}

# Initialize cluster rotation system
init_cluster_rotation() {
    log_info "🔧 Initialisiere Cluster SSH Rotation System..."
    
    # Create directories
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$(dirname "$ROTATION_LOG")"
    
    # Create cluster config if not exists
    if [[ ! -f "$CLUSTER_CONFIG" ]]; then
        cat > "$CLUSTER_CONFIG" << EOF
{
  "cluster_rotation": {
    "version": "2.0-macos",
    "last_rotation": "never",
    "rotation_interval_days": 30,
    "auto_sync": true,
    "backup_count": 10
  },
  "nodes": {
    "i7-node": {
      "ip": "192.168.68.105",
      "user": "amonbaumgartner",
      "role": "client",
      "status": "unknown",
      "last_sync": "never"
    },
    "rx-node": {
      "ip": "192.168.68.117", 
      "user": "amo9n11",
      "role": "primary_trainer",
      "status": "unknown",
      "last_sync": "never"
    },
    "m1-mac": {
      "ip": "192.168.68.111",
      "user": "amonbaumgartner", 
      "role": "coordinator",
      "status": "local",
      "last_sync": "$(date)"
    }
  }
}
EOF
        log "📝 Cluster Rotation Config erstellt: $CLUSTER_CONFIG"
    fi
    
    log "✅ Cluster Rotation System initialisiert"
}

# Test node connectivity
test_node_connectivity() {
    local node_name="$1"
    local node_address=$(get_node_address "$node_name")
    
    if [[ "$node_name" == "$CURRENT_NODE" ]]; then
        echo "local"
        return 0
    fi
    
    if [[ -z "$node_address" ]]; then
        echo "unknown"
        return 1
    fi
    
    if ssh -o ConnectTimeout=5 -o BatchMode=yes -i "$GENTLEMAN_KEY_PATH" "$node_address" "echo 'connected'" &>/dev/null; then
        echo "online"
        return 0
    else
        echo "offline"
        return 1
    fi
}

# Discover cluster status
discover_cluster() {
    log_info "🔍 Scanne Cluster Status..."
    
    local online_nodes=0
    local total_nodes=3
    
    for node_name in $(get_all_nodes); do
        local status=$(test_node_connectivity "$node_name")
        
        case "$status" in
            "local")
                log_info "   🏠 $node_name: LOKAL (aktueller Node)"
                ((online_nodes++))
                ;;
            "online")
                log "   🌐 $node_name: ONLINE"
                ((online_nodes++))
                ;;
            "offline")
                log_warning "   ❌ $node_name: OFFLINE"
                ;;
        esac
        
        # Export status for other functions (macOS kompatibel)
        export "NODE_$(echo $node_name | tr '-' '_')_STATUS=$status"
    done
    
    log_info "📊 Cluster Status: $online_nodes/$total_nodes Nodes erreichbar"
}

# Generate new cluster-wide SSH key
generate_cluster_key() {
    log_info "🔑 Generiere neuen Cluster SSH Key..."
    
    # Backup existing key
    if [[ -f "$GENTLEMAN_KEY_PATH" ]]; then
        cp "$GENTLEMAN_KEY_PATH" "$BACKUP_DIR/gentleman_key_$TIMESTAMP"
        cp "$GENTLEMAN_KEY_PATH.pub" "$BACKUP_DIR/gentleman_key_$TIMESTAMP.pub"
        log "💾 Alter Key gesichert: $BACKUP_DIR/gentleman_key_$TIMESTAMP"
    fi
    
    # Generate new ED25519 key
    ssh-keygen -t ed25519 -f "$GENTLEMAN_KEY_PATH" -N "" \
        -C "gentleman-cluster-$CURRENT_NODE-$TIMESTAMP"
    
    chmod 600 "$GENTLEMAN_KEY_PATH"
    chmod 644 "$GENTLEMAN_KEY_PATH.pub"
    
    local fingerprint=$(ssh-keygen -lf "$GENTLEMAN_KEY_PATH.pub")
    log "🔑 Neuer Cluster Key generiert"
    log_info "   Fingerprint: $fingerprint"
    log_info "   Comment: gentleman-cluster-$CURRENT_NODE-$TIMESTAMP"
}

# Distribute key to online nodes
distribute_cluster_key() {
    log_info "📤 Verteile neuen Key an Online-Nodes..."
    
    local success_count=0
    local attempt_count=0
    
    for node_name in $(get_all_nodes); do
        [[ "$node_name" == "$CURRENT_NODE" ]] && continue
        
        local node_address=$(get_node_address "$node_name")
        local status_var="NODE_$(echo $node_name | tr '-' '_')_STATUS"
        local node_status="${!status_var:-unknown}"
        
        ((attempt_count++))
        
        if [[ "$node_status" == "online" ]]; then
            log_info "   📡 Übertrage Key zu $node_name ($node_address)..."
            
            # Use existing key for initial connection
            if ssh -o ConnectTimeout=10 -i "$GENTLEMAN_KEY_PATH" "$node_address" \
               "mkdir -p ~/.ssh && chmod 700 ~/.ssh" 2>/dev/null; then
                
                # Add new key to authorized_keys
                if cat "$GENTLEMAN_KEY_PATH.pub" | \
                   ssh -i "$GENTLEMAN_KEY_PATH" "$node_address" \
                   "cat >> ~/.ssh/authorized_keys && sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"; then
                    
                    log "   ✅ Key erfolgreich zu $node_name übertragen"
                    ((success_count++))
                else
                    log_error "   ❌ Key-Übertragung zu $node_name fehlgeschlagen"
                fi
            else
                log_error "   ❌ SSH-Verbindung zu $node_name fehlgeschlagen"
            fi
        else
            log_warning "   ⏭️  $node_name übersprungen (Status: $node_status)"
        fi
    done
    
    log_info "📊 Key-Verteilung: $success_count/$attempt_count Online-Nodes aktualisiert"
    return $([[ $success_count -gt 0 ]] && echo 0 || echo 1)
}

# Test new key authentication across cluster
test_cluster_authentication() {
    log_info "🧪 Teste Cluster-weite Authentifizierung..."
    
    local success_count=0
    local test_count=0
    
    for node_name in $(get_all_nodes); do
        [[ "$node_name" == "$CURRENT_NODE" ]] && continue
        
        local node_address=$(get_node_address "$node_name")
        local status_var="NODE_$(echo $node_name | tr '-' '_')_STATUS"
        local node_status="${!status_var:-unknown}"
        
        if [[ "$node_status" == "online" ]]; then
            ((test_count++))
            
            if ssh -o ConnectTimeout=5 -o BatchMode=yes -i "$GENTLEMAN_KEY_PATH" "$node_address" \
               "echo 'Auth test successful on $(hostname) at $(date)'" &>/dev/null; then
                log "   ✅ $node_name Authentifizierung erfolgreich"
                ((success_count++))
            else
                log_error "   ❌ $node_name Authentifizierung fehlgeschlagen"
            fi
        fi
    done
    
    log_info "📊 Authentifizierung: $success_count/$test_count Online-Nodes erfolgreich"
    return $([[ $success_count -eq $test_count ]] && echo 0 || echo 1)
}

# Synchronize rotation across cluster
sync_rotation_to_cluster() {
    log_info "🔄 Synchronisiere Rotation mit Cluster..."
    
    # Copy rotation scripts to online nodes
    for node_name in $(get_all_nodes); do
        [[ "$node_name" == "$CURRENT_NODE" ]] && continue
        
        local node_address=$(get_node_address "$node_name")
        local status_var="NODE_$(echo $node_name | tr '-' '_')_STATUS"
        local node_status="${!status_var:-unknown}"
        
        if [[ "$node_status" == "online" ]]; then
            log_info "   📋 Synchronisiere Rotation-Scripts zu $node_name..."
            
            # Copy this script and config
            if scp -o ConnectTimeout=10 -i "$GENTLEMAN_KEY_PATH" \
               "$0" "$CLUSTER_CONFIG" "$node_address:~/" &>/dev/null; then
                
                # Make executable and run sync
                ssh -i "$GENTLEMAN_KEY_PATH" "$node_address" \
                    "chmod +x ~/$(basename "$0") && echo '$TIMESTAMP' > ~/.ssh/.last_key_rotation" &>/dev/null
                
                log "   ✅ $node_name synchronisiert"
            else
                log_warning "   ⚠️  $node_name Synchronisation fehlgeschlagen"
            fi
        fi
    done
}

# Update cluster configuration
update_cluster_config() {
    log_info "📝 Aktualisiere Cluster-Konfiguration..."
    
    # Update last rotation timestamp (simple sed replacement)
    if [[ -f "$CLUSTER_CONFIG" ]]; then
        sed -i.bak "s/\"last_rotation\": \"[^\"]*\"/\"last_rotation\": \"$TIMESTAMP\"/" "$CLUSTER_CONFIG"
    fi
    
    echo "$TIMESTAMP" > ~/.ssh/.last_key_rotation
    log "📅 Rotation-Zeitstempel aktualisiert: $TIMESTAMP"
}

# Cleanup old backups
cleanup_old_backups() {
    log_info "🧹 Bereinige alte Key-Backups..."
    
    local backup_count=$(ls -1 "$BACKUP_DIR"/gentleman_key_* 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ $backup_count -gt 10 ]]; then
        local to_delete=$((backup_count - 10))
        ls -1t "$BACKUP_DIR"/gentleman_key_* | tail -n "$to_delete" | xargs rm -f
        log "🗑️  $to_delete alte Backups entfernt"
    else
        log_info "📦 $backup_count Backups behalten (unter Limit)"
    fi
}

# Generate offline instructions for disconnected nodes
generate_offline_instructions() {
    log_info "📋 Erstelle Offline-Anweisungen für getrennte Nodes..."
    
    local offline_script="cluster_offline_sync_$TIMESTAMP.sh"
    
    cat > "$offline_script" << EOF
#!/bin/bash
# Offline SSH Key Sync for GENTLEMAN Cluster
# Generated: $(date)
# Rotation ID: $TIMESTAMP

echo "🔄 GENTLEMAN Cluster Offline Key Sync"
echo "===================================="

# New public key to add:
NEW_PUBLIC_KEY='$(cat "$GENTLEMAN_KEY_PATH.pub")'

# Add to authorized_keys
mkdir -p ~/.ssh
echo "\$NEW_PUBLIC_KEY" >> ~/.ssh/authorized_keys
sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

echo "✅ New cluster key added to authorized_keys"
echo "🔑 Key fingerprint: $(ssh-keygen -lf "$GENTLEMAN_KEY_PATH.pub")"
echo "📅 Rotation timestamp: $TIMESTAMP"
EOF
    
    chmod +x "$offline_script"
    log "📄 Offline Sync Script erstellt: $offline_script"
}

# Main rotation function
run_cluster_rotation() {
    log_header
    
    log "🚀 Starte Cluster-weite SSH Key Rotation..."
    
    # Step 1: Initialize system
    init_cluster_rotation
    
    # Step 2: Discover cluster
    discover_cluster
    
    # Step 3: Generate new cluster key
    generate_cluster_key
    
    # Step 4: Distribute to online nodes
    if distribute_cluster_key; then
        log "✅ Key-Verteilung erfolgreich"
    else
        log_warning "⚠️  Einige Key-Verteilungen fehlgeschlagen"
    fi
    
    # Step 5: Test authentication
    if test_cluster_authentication; then
        log "✅ Cluster-Authentifizierung erfolgreich"
    else
        log_warning "⚠️  Einige Authentifizierungen fehlgeschlagen"
    fi
    
    # Step 6: Synchronize rotation
    sync_rotation_to_cluster
    
    # Step 7: Update configuration
    update_cluster_config
    
    # Step 8: Cleanup
    cleanup_old_backups
    
    # Step 9: Generate offline instructions
    generate_offline_instructions
    
    log "🎉 Cluster SSH Key Rotation abgeschlossen!"
    log_info "📊 Rotation ID: $TIMESTAMP"
    log_info "📝 Log: $ROTATION_LOG"
    log_info "💾 Backups: $BACKUP_DIR"
}

# Command line interface
case "${1:-run}" in
    "run"|"rotate")
        run_cluster_rotation
        ;;
    "status")
        discover_cluster
        ;;
    "test")
        test_cluster_authentication
        ;;
    "sync")
        sync_rotation_to_cluster
        ;;
    "cleanup")
        cleanup_old_backups
        ;;
    "help"|"-h"|"--help")
        echo "🔄 GENTLEMAN Cluster SSH Key Rotation (macOS kompatibel)"
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  run, rotate  - Führe vollständige Cluster-Rotation durch"
        echo "  status       - Zeige Cluster-Status"
        echo "  test         - Teste Cluster-Authentifizierung"
        echo "  sync         - Synchronisiere mit Cluster"
        echo "  cleanup      - Bereinige alte Backups"
        echo "  help         - Zeige diese Hilfe"
        ;;
    *)
        log_error "Unbekannter Befehl: $1"
        echo "Verwende '$0 help' für Hilfe"
        exit 1
        ;;
esac 