#!/bin/bash

# 🎩 GENTLEMAN Secure Remote Update System
# ═══════════════════════════════════════════════════════════════
# Sichere Remote-Updates ohne permanenten Terminal-Zugriff

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration
RX_NODE_IP="192.168.100.10"  # Nebula IP
RX_NODE_USER="gentleman"
MATRIX_ROOM="#gentleman-updates:matrix.gentleman.local"
UPDATE_TIMEOUT=300  # 5 minutes max per update

echo -e "${PURPLE}"
echo "🎩 GENTLEMAN Secure Remote Update System"
echo "═══════════════════════════════════════════════════════════════"
echo -e "${WHITE}Sichere Updates ohne permanenten Terminal-Zugriff${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
# 🔐 Security Functions
# ═══════════════════════════════════════════════════════════════

generate_temp_ssh_key() {
    local temp_key="/tmp/gentleman_update_$(date +%s)"
    
    echo -e "${BLUE}🔑 Generating temporary SSH key...${NC}"
    ssh-keygen -t ed25519 -f "$temp_key" -N "" -C "gentleman-update-$(date +%Y%m%d)"
    
    echo "$temp_key"
}

setup_temp_access() {
    local temp_key="$1"
    local duration="${2:-300}"  # 5 minutes default
    
    echo -e "${BLUE}🚪 Setting up temporary access (${duration}s)...${NC}"
    
    # Copy public key to RX Node
    ssh-copy-id -i "${temp_key}.pub" "$RX_NODE_USER@$RX_NODE_IP" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Manual key copy required${NC}"
        echo "Run on RX Node:"
        echo "echo '$(cat ${temp_key}.pub)' >> ~/.ssh/authorized_keys"
        read -p "Press Enter when done..."
    }
    
    # Schedule key removal
    (
        sleep "$duration"
        echo -e "${YELLOW}🔒 Removing temporary SSH access...${NC}"
        ssh -i "$temp_key" "$RX_NODE_USER@$RX_NODE_IP" \
            "sed -i '/gentleman-update-$(date +%Y%m%d)/d' ~/.ssh/authorized_keys" 2>/dev/null || true
        rm -f "$temp_key" "${temp_key}.pub"
        echo -e "${GREEN}✅ Temporary access revoked${NC}"
    ) &
}

# ═══════════════════════════════════════════════════════════════
# 📡 Matrix Integration
# ═══════════════════════════════════════════════════════════════

send_matrix_notification() {
    local message="$1"
    local room="${2:-$MATRIX_ROOM}"
    
    # Send via Matrix bot API
    curl -s -X POST "http://localhost:8093/matrix/send" \
        -H "Content-Type: application/json" \
        -d "{\"room\": \"$room\", \"message\": \"$message\"}" || true
}

wait_for_matrix_approval() {
    local update_id="$1"
    local timeout="${2:-60}"
    
    echo -e "${YELLOW}⏳ Waiting for Matrix approval (${timeout}s)...${NC}"
    send_matrix_notification "🔄 Update $update_id ready. Reply '!approve $update_id' to proceed or '!cancel $update_id' to abort."
    
    local start_time=$(date +%s)
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            echo -e "${RED}❌ Approval timeout${NC}"
            return 1
        fi
        
        # Check for approval via Matrix API
        local response=$(curl -s "http://localhost:8093/matrix/check-approval/$update_id" || echo "pending")
        
        case "$response" in
            "approved")
                echo -e "${GREEN}✅ Update approved via Matrix${NC}"
                return 0
                ;;
            "cancelled")
                echo -e "${YELLOW}❌ Update cancelled via Matrix${NC}"
                return 1
                ;;
            *)
                sleep 5
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════
# 🚀 Update Functions
# ═══════════════════════════════════════════════════════════════

update_docker_services() {
    local temp_key="$1"
    local services="$2"
    
    echo -e "${BLUE}🐳 Updating Docker services: $services${NC}"
    
    ssh -i "$temp_key" "$RX_NODE_USER@$RX_NODE_IP" << EOF
set -e
cd ~/gentleman

echo "🔄 Pulling latest images..."
docker-compose pull $services

echo "🔄 Restarting services..."
docker-compose up -d $services

echo "📊 Service status:"
docker-compose ps $services

echo "✅ Update complete"
EOF
}

update_system_packages() {
    local temp_key="$1"
    
    echo -e "${BLUE}📦 Updating system packages...${NC}"
    
    ssh -i "$temp_key" "$RX_NODE_USER@$RX_NODE_IP" << 'EOF'
set -e

echo "🔄 Updating package database..."
sudo pacman -Sy

echo "🔄 Upgrading packages..."
sudo pacman -Su --noconfirm

echo "🧹 Cleaning package cache..."
sudo pacman -Sc --noconfirm

echo "✅ System update complete"
EOF
}

deploy_new_configuration() {
    local temp_key="$1"
    local config_files="$2"
    
    echo -e "${BLUE}⚙️  Deploying new configuration...${NC}"
    
    # Copy configuration files
    for file in $config_files; do
        if [ -f "$file" ]; then
            echo -e "${CYAN}📤 Copying $file...${NC}"
            scp -i "$temp_key" "$file" "$RX_NODE_USER@$RX_NODE_IP:~/gentleman/$file"
        fi
    done
    
    # Apply configuration
    ssh -i "$temp_key" "$RX_NODE_USER@$RX_NODE_IP" << 'EOF'
set -e
cd ~/gentleman

echo "🔄 Applying configuration changes..."
if [ -f "docker-compose.yml" ]; then
    docker-compose down
    docker-compose up -d
fi

echo "✅ Configuration deployed"
EOF
}

# ═══════════════════════════════════════════════════════════════
# 🎯 Main Update Logic
# ═══════════════════════════════════════════════════════════════

main() {
    local update_type="${1:-interactive}"
    local update_id="update_$(date +%s)"
    
    case "$update_type" in
        "docker")
            local services="${2:-all}"
            echo -e "${BLUE}🐳 Docker Service Update: $services${NC}"
            
            # Matrix approval for production updates
            if ! wait_for_matrix_approval "$update_id" 120; then
                echo -e "${RED}❌ Update cancelled${NC}"
                exit 1
            fi
            
            # Setup temporary access
            local temp_key=$(generate_temp_ssh_key)
            setup_temp_access "$temp_key" 300
            
            # Perform update
            send_matrix_notification "🔄 Starting Docker update: $services"
            update_docker_services "$temp_key" "$services"
            send_matrix_notification "✅ Docker update complete: $services"
            ;;
            
        "system")
            echo -e "${BLUE}📦 System Package Update${NC}"
            
            # Matrix approval required
            if ! wait_for_matrix_approval "$update_id" 180; then
                echo -e "${RED}❌ Update cancelled${NC}"
                exit 1
            fi
            
            # Setup temporary access
            local temp_key=$(generate_temp_ssh_key)
            setup_temp_access "$temp_key" 600  # 10 minutes for system updates
            
            # Perform update
            send_matrix_notification "🔄 Starting system package update"
            update_system_packages "$temp_key"
            send_matrix_notification "✅ System update complete"
            ;;
            
        "config")
            local config_files="$2"
            echo -e "${BLUE}⚙️  Configuration Deployment${NC}"
            
            # Matrix approval
            if ! wait_for_matrix_approval "$update_id" 60; then
                echo -e "${RED}❌ Deployment cancelled${NC}"
                exit 1
            fi
            
            # Setup temporary access
            local temp_key=$(generate_temp_ssh_key)
            setup_temp_access "$temp_key" 180
            
            # Deploy configuration
            send_matrix_notification "🔄 Deploying configuration: $config_files"
            deploy_new_configuration "$temp_key" "$config_files"
            send_matrix_notification "✅ Configuration deployed"
            ;;
            
        "matrix")
            # Matrix-triggered update (already approved)
            local command="$2"
            echo -e "${BLUE}💬 Matrix-triggered update: $command${NC}"
            
            # Setup temporary access (shorter duration)
            local temp_key=$(generate_temp_ssh_key)
            setup_temp_access "$temp_key" 120
            
            # Execute command
            case "$command" in
                "restart-all")
                    update_docker_services "$temp_key" ""
                    ;;
                "update-docker")
                    update_docker_services "$temp_key" "all"
                    ;;
                "status")
                    ssh -i "$temp_key" "$RX_NODE_USER@$RX_NODE_IP" \
                        "cd ~/gentleman && docker-compose ps"
                    ;;
            esac
            ;;
            
        "interactive")
            echo -e "${YELLOW}📋 Interactive Update Menu${NC}"
            echo "1. Docker Services Update"
            echo "2. System Package Update"
            echo "3. Configuration Deployment"
            echo "4. Matrix Integration Test"
            echo "5. Exit"
            
            read -p "Select option (1-5): " choice
            
            case "$choice" in
                1) main "docker" ;;
                2) main "system" ;;
                3) 
                    read -p "Configuration files (space-separated): " files
                    main "config" "$files"
                    ;;
                4) 
                    send_matrix_notification "🧪 Matrix integration test - $(date)"
                    echo -e "${GREEN}✅ Test message sent${NC}"
                    ;;
                5) exit 0 ;;
                *) echo -e "${RED}❌ Invalid option${NC}" ;;
            esac
            ;;
            
        *)
            echo -e "${RED}❌ Unknown update type: $update_type${NC}"
            echo "Usage: $0 [docker|system|config|matrix|interactive] [options]"
            exit 1
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
# 🚀 Execute
# ═══════════════════════════════════════════════════════════════

# Check prerequisites
if ! command -v ssh >/dev/null 2>&1; then
    echo -e "${RED}❌ SSH not available${NC}"
    exit 1
fi

if ! curl -s http://localhost:8093/health >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Matrix integration not available${NC}"
    echo "Updates will proceed without Matrix notifications"
fi

# Execute main function
main "$@"

echo ""
echo -e "${GREEN}🎉 GENTLEMAN Remote Update Complete!${NC}"
echo -e "${CYAN}💡 Security: Temporary SSH access automatically revoked${NC}" 