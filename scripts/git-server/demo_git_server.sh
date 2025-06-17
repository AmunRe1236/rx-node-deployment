#!/bin/bash

# 🎩 GENTLEMAN Git Server Demo Script
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# 📋 Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEMO_REPO_NAME="gentleman-demo"
DEMO_USER="admin"

# 🎨 Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 📝 Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# 🏥 Health check function
check_git_server() {
    log "Checking Git server health..."
    
    local checks_passed=0
    local total_checks=4
    
    # Check if containers are running
    if docker-compose -f "${PROJECT_ROOT}/docker-compose.git-server.yml" ps | grep -q "Up"; then
        success "✅ Docker containers are running"
        ((checks_passed++))
    else
        error "❌ Docker containers are not running"
    fi
    
    # Check Gitea web interface
    if curl -f -s -k "https://gitea.gentleman.local:3000/api/healthz" >/dev/null 2>&1; then
        success "✅ Gitea web interface is accessible"
        ((checks_passed++))
    else
        warning "⚠️ Gitea web interface not accessible (may need initial setup)"
    fi
    
    # Check Nginx proxy
    if curl -f -s -k "https://git.gentleman.local/nginx-health" >/dev/null 2>&1; then
        success "✅ Nginx proxy is working"
        ((checks_passed++))
    else
        warning "⚠️ Nginx proxy not accessible"
    fi
    
    # Check database
    if docker-compose -f "${PROJECT_ROOT}/docker-compose.git-server.yml" exec -T gitea-db pg_isready -U gitea >/dev/null 2>&1; then
        success "✅ PostgreSQL database is ready"
        ((checks_passed++))
    else
        error "❌ PostgreSQL database is not ready"
    fi
    
    echo ""
    if [ $checks_passed -eq $total_checks ]; then
        success "🎉 All health checks passed! ($checks_passed/$total_checks)"
        return 0
    else
        warning "⚠️ Some health checks failed ($checks_passed/$total_checks)"
        return 1
    fi
}

# 📊 Show server information
show_server_info() {
    echo ""
    echo -e "${PURPLE}🎩 GENTLEMAN Git Server Information${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Container status
    echo -e "${CYAN}📦 Container Status:${NC}"
    docker-compose -f "${PROJECT_ROOT}/docker-compose.git-server.yml" ps
    echo ""
    
    # Network information
    echo -e "${CYAN}🌐 Network Information:${NC}"
    echo -e "   Web Interface: ${GREEN}https://git.gentleman.local${NC}"
    echo -e "   Direct Gitea:  ${GREEN}https://gitea.gentleman.local:3000${NC}"
    echo -e "   SSH Access:    ${GREEN}ssh://git@gitea.gentleman.local:2222${NC}"
    echo ""
    
    # Volume information
    echo -e "${CYAN}💾 Storage Volumes:${NC}"
    docker volume ls | grep gitea || echo "   No Gitea volumes found"
    echo ""
    
    # Resource usage
    echo -e "${CYAN}📊 Resource Usage:${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" $(docker-compose -f "${PROJECT_ROOT}/docker-compose.git-server.yml" ps -q) 2>/dev/null || echo "   Unable to get resource stats"
    echo ""
}

# 🧪 Test Git operations
test_git_operations() {
    log "Testing Git operations..."
    
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Initialize test repository
    log "Creating test repository..."
    git init
    git config user.name "GENTLEMAN Demo"
    git config user.email "demo@gentleman.local"
    
    # Create test files
    echo "# GENTLEMAN Git Server Demo" > README.md
    echo "This is a demo repository for testing the local Git server." >> README.md
    echo "" >> README.md
    echo "Created on: $(date)" >> README.md
    
    echo "console.log('Hello from GENTLEMAN Git Server!');" > demo.js
    
    cat > .gitignore << EOF
node_modules/
*.log
.env
.DS_Store
EOF
    
    # Commit files
    git add .
    git commit -m "Initial commit: Add demo files"
    
    success "Test repository created in: $temp_dir"
    
    # Show repository info
    echo ""
    echo -e "${CYAN}📁 Test Repository Contents:${NC}"
    ls -la
    echo ""
    echo -e "${CYAN}📝 Git Log:${NC}"
    git log --oneline
    echo ""
    
    info "To push to your Git server, run:"
    echo -e "   ${GREEN}cd $temp_dir${NC}"
    echo -e "   ${GREEN}git remote add origin https://git.gentleman.local/$DEMO_USER/$DEMO_REPO_NAME.git${NC}"
    echo -e "   ${GREEN}git push -u origin main${NC}"
    echo ""
    
    # Cleanup option
    read -p "Delete test repository? (y/N): " cleanup
    if [[ "$cleanup" =~ ^[Yy]$ ]]; then
        rm -rf "$temp_dir"
        success "Test repository cleaned up"
    else
        info "Test repository kept at: $temp_dir"
    fi
}

# 🔧 Interactive setup helper
interactive_setup() {
    echo ""
    echo -e "${PURPLE}🎩 GENTLEMAN Git Server Interactive Setup${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}This will guide you through the Git server setup process.${NC}"
    echo ""
    
    # Check if already running
    if docker-compose -f "${PROJECT_ROOT}/docker-compose.git-server.yml" ps | grep -q "Up"; then
        warning "Git server appears to be already running."
        read -p "Continue anyway? (y/N): " continue_setup
        if [[ ! "$continue_setup" =~ ^[Yy]$ ]]; then
            info "Setup cancelled."
            return 0
        fi
    fi
    
    # Step 1: Setup
    echo -e "${CYAN}Step 1: Setting up Git server...${NC}"
    read -p "Run git server setup? (Y/n): " run_setup
    if [[ ! "$run_setup" =~ ^[Nn]$ ]]; then
        cd "$PROJECT_ROOT"
        make git-setup
    fi
    
    # Step 2: Health check
    echo ""
    echo -e "${CYAN}Step 2: Checking server health...${NC}"
    if check_git_server; then
        success "Server is healthy!"
    else
        warning "Server health check failed. Check logs with: make git-logs"
    fi
    
    # Step 3: Show information
    echo ""
    echo -e "${CYAN}Step 3: Server information${NC}"
    show_server_info
    
    # Step 4: Test Git operations
    echo ""
    echo -e "${CYAN}Step 4: Test Git operations${NC}"
    read -p "Create test repository? (Y/n): " create_test
    if [[ ! "$create_test" =~ ^[Nn]$ ]]; then
        test_git_operations
    fi
    
    # Step 5: Next steps
    echo ""
    echo -e "${CYAN}🎯 Next Steps:${NC}"
    echo -e "   1. Open ${GREEN}https://git.gentleman.local${NC} in your browser"
    echo -e "   2. Complete the Gitea initial setup"
    echo -e "   3. Create your admin account"
    echo -e "   4. Create your first repository"
    echo -e "   5. Add SSH keys for secure access"
    echo ""
    echo -e "${CYAN}📚 Useful Commands:${NC}"
    echo -e "   ${GREEN}make git-status${NC}  - Check server status"
    echo -e "   ${GREEN}make git-logs${NC}    - View server logs"
    echo -e "   ${GREEN}make git-backup${NC}  - Create backup"
    echo -e "   ${GREEN}make git-stop${NC}    - Stop server"
    echo ""
}

# 🚀 Main menu
show_menu() {
    echo ""
    echo -e "${PURPLE}🎩 GENTLEMAN Git Server Demo${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Choose an option:${NC}"
    echo -e "   ${GREEN}1${NC}) Interactive Setup"
    echo -e "   ${GREEN}2${NC}) Health Check"
    echo -e "   ${GREEN}3${NC}) Server Information"
    echo -e "   ${GREEN}4${NC}) Test Git Operations"
    echo -e "   ${GREEN}5${NC}) View Logs"
    echo -e "   ${GREEN}6${NC}) Create Backup"
    echo -e "   ${GREEN}0${NC}) Exit"
    echo ""
    read -p "Enter your choice (0-6): " choice
    
    case $choice in
        1)
            interactive_setup
            ;;
        2)
            check_git_server
            ;;
        3)
            show_server_info
            ;;
        4)
            test_git_operations
            ;;
        5)
            echo -e "${CYAN}📋 Viewing Git server logs (Ctrl+C to exit):${NC}"
            cd "$PROJECT_ROOT"
            make git-logs
            ;;
        6)
            echo -e "${CYAN}💾 Creating backup...${NC}"
            cd "$PROJECT_ROOT"
            make git-backup
            ;;
        0)
            success "Goodbye! 🎩"
            exit 0
            ;;
        *)
            error "Invalid choice. Please try again."
            show_menu
            ;;
    esac
}

# 🚀 Main execution
main() {
    cd "$PROJECT_ROOT"
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check if docker-compose file exists
    if [[ ! -f "docker-compose.git-server.yml" ]]; then
        error "Git server configuration not found. Run 'make git-setup' first."
        exit 1
    fi
    
    # Show menu or run specific command
    if [[ $# -eq 0 ]]; then
        while true; do
            show_menu
            echo ""
            read -p "Press Enter to continue or Ctrl+C to exit..."
        done
    else
        case "$1" in
            "health")
                check_git_server
                ;;
            "info")
                show_server_info
                ;;
            "test")
                test_git_operations
                ;;
            "setup")
                interactive_setup
                ;;
            *)
                echo "Usage: $0 [health|info|test|setup]"
                exit 1
                ;;
        esac
    fi
}

# Execute main function
main "$@" 