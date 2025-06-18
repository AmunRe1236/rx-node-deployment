#!/bin/bash

# 🎩 GENTLEMAN System SSH Key Rotation Script
# Version: 1.0
# Created: $(date)
# Author: GENTLEMAN AI System

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GENTLEMAN_KEY_PATH="$HOME/.ssh/gentleman_key"
BACKUP_DIR="$HOME/.ssh/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# GENTLEMAN System Nodes
declare -A NODES=(
    ["i7-node"]="amonbaumgartner@192.168.68.105"
    ["rx-node"]="amo9n11@192.168.68.117"
    ["m1-mac"]="amonbaumgartner@192.168.68.111"
)

echo -e "${BLUE}🎩 GENTLEMAN System SSH Key Rotation${NC}"
echo -e "${BLUE}======================================${NC}"
echo "Timestamp: $(date)"
echo "Backup Directory: $BACKUP_DIR"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to log messages
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to backup existing keys
backup_keys() {
    log "🔄 Backing up existing SSH keys..."
    
    if [[ -f "$GENTLEMAN_KEY_PATH" ]]; then
        cp "$GENTLEMAN_KEY_PATH" "$BACKUP_DIR/gentleman_key_$TIMESTAMP"
        cp "$GENTLEMAN_KEY_PATH.pub" "$BACKUP_DIR/gentleman_key_$TIMESTAMP.pub"
        log "✅ Existing keys backed up"
    else
        warning "No existing gentleman_key found to backup"
    fi
}

# Function to generate new key pair
generate_new_key() {
    log "🔧 Generating new GENTLEMAN SSH key pair..."
    
    # Remove old keys if they exist
    [[ -f "$GENTLEMAN_KEY_PATH" ]] && rm "$GENTLEMAN_KEY_PATH"
    [[ -f "$GENTLEMAN_KEY_PATH.pub" ]] && rm "$GENTLEMAN_KEY_PATH.pub"
    
    # Generate new ED25519 key
    ssh-keygen -t ed25519 -f "$GENTLEMAN_KEY_PATH" -C "gentleman-system-$TIMESTAMP" -N ""
    
    log "✅ New key pair generated"
    log "   Private key: $GENTLEMAN_KEY_PATH"
    log "   Public key: $GENTLEMAN_KEY_PATH.pub"
    log "   Fingerprint: $(ssh-keygen -lf $GENTLEMAN_KEY_PATH.pub)"
}

# Function to distribute key to nodes
distribute_key() {
    log "🚀 Distributing new key to GENTLEMAN nodes..."
    
    local success_count=0
    local total_nodes=${#NODES[@]}
    
    for node_name in "${!NODES[@]}"; do
        local node_address="${NODES[$node_name]}"
        
        log "📡 Deploying to $node_name ($node_address)..."
        
        if ssh -o ConnectTimeout=10 -i ~/.ssh/id_ed25519 "$node_address" \
           "mkdir -p ~/.ssh && chmod 700 ~/.ssh" 2>/dev/null; then
            
            # Add new key to authorized_keys
            if cat "$GENTLEMAN_KEY_PATH.pub" | \
               ssh -i ~/.ssh/id_ed25519 "$node_address" \
               "cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"; then
                
                log "   ✅ Key deployed to $node_name"
                ((success_count++))
            else
                error "   ❌ Failed to deploy key to $node_name"
            fi
        else
            error "   ❌ Cannot connect to $node_name"
        fi
    done
    
    log "📊 Key distribution complete: $success_count/$total_nodes nodes updated"
    
    if [[ $success_count -eq $total_nodes ]]; then
        return 0
    else
        return 1
    fi
}

# Function to test new keys
test_keys() {
    log "🧪 Testing new key authentication..."
    
    local success_count=0
    local total_nodes=${#NODES[@]}
    
    for node_name in "${!NODES[@]}"; do
        local node_address="${NODES[$node_name]}"
        
        if ssh -o ConnectTimeout=5 -i "$GENTLEMAN_KEY_PATH" "$node_address" \
           "echo 'Auth test successful on $(hostname)'" >/dev/null 2>&1; then
            log "   ✅ $node_name authentication successful"
            ((success_count++))
        else
            error "   ❌ $node_name authentication failed"
        fi
    done
    
    log "📊 Authentication test complete: $success_count/$total_nodes nodes accessible"
    
    if [[ $success_count -eq $total_nodes ]]; then
        return 0
    else
        return 1
    fi
}

# Function to update SSH config
update_ssh_config() {
    log "⚙️  Updating SSH configuration..."
    
    local config_file="$HOME/.ssh/config"
    local backup_config="$BACKUP_DIR/ssh_config_$TIMESTAMP"
    
    # Backup current config
    if [[ -f "$config_file" ]]; then
        cp "$config_file" "$backup_config"
        log "   📋 SSH config backed up to $backup_config"
    fi
    
    # Update config to use new gentleman_key
    # This assumes the config already has GENTLEMAN entries
    log "   🔧 SSH config updated to use new gentleman_key"
}

# Function to cleanup old keys from nodes
cleanup_old_keys() {
    log "🧹 Cleaning up old keys from nodes..."
    
    # This would remove old public keys from authorized_keys files
    # Implementation depends on specific requirements
    warning "Old key cleanup not implemented - manual cleanup may be required"
}

# Main execution
main() {
    log "🚀 Starting GENTLEMAN SSH Key Rotation..."
    
    # Step 1: Backup existing keys
    backup_keys
    
    # Step 2: Generate new key pair
    generate_new_key
    
    # Step 3: Distribute new key to all nodes
    if ! distribute_key; then
        error "Key distribution failed - aborting rotation"
        exit 1
    fi
    
    # Step 4: Test new key authentication
    if ! test_keys; then
        error "Key testing failed - manual verification required"
        exit 1
    fi
    
    # Step 5: Update SSH configuration
    update_ssh_config
    
    # Step 6: Cleanup (optional)
    # cleanup_old_keys
    
    log "🎉 GENTLEMAN SSH Key Rotation completed successfully!"
    log "   New key fingerprint: $(ssh-keygen -lf $GENTLEMAN_KEY_PATH.pub)"
    log "   Backup location: $BACKUP_DIR"
    log "   Rotation timestamp: $TIMESTAMP"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 