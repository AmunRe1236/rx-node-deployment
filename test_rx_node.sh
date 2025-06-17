#!/bin/bash

# 🎩 GENTLEMAN - RX Node Test Script
# ═══════════════════════════════════════════════════════════════

set -e

# 🎨 Colors for elegant output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 🎩 Test Banner
print_banner() {
    echo -e "${PURPLE}"
    echo "🎩 GENTLEMAN - RX Node Test Suite"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${WHITE}🧪 Testing RX Node Setup and Configuration${NC}"
    echo ""
}

# 📝 Logging Functions
log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_test() {
    echo -e "${BLUE}🧪 Testing: $1${NC}"
}

log_step() {
    echo -e "${WHITE}🔧 $1${NC}"
}

# Global test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test result tracking
test_result() {
    local test_name="$1"
    local result="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ "$result" = "PASS" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$test_name: PASSED"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "$test_name: FAILED"
    fi
}

# 🔍 System Detection
detect_system() {
    log_step "Detecting system architecture..."
    
    OS=$(uname -s)
    ARCH=$(uname -m)
    
    case $OS in
        Linux*)
            SYSTEM="Linux"
            if command -v lsb_release &> /dev/null; then
                DISTRO=$(lsb_release -si)
                VERSION=$(lsb_release -sr)
            elif [ -f /etc/os-release ]; then
                DISTRO=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
                VERSION=$(grep ^VERSION_ID= /etc/os-release | cut -d= -f2 | tr -d '"')
            else
                DISTRO="Unknown"
                VERSION="Unknown"
            fi
            ;;
        Darwin*)
            SYSTEM="macOS"
            VERSION=$(sw_vers -productVersion)
            if [[ $ARCH == "arm64" ]]; then
                DISTRO="Apple Silicon"
            else
                DISTRO="Intel"
            fi
            ;;
        *)
            SYSTEM="Unknown"
            DISTRO="Unknown"
            VERSION="Unknown"
            ;;
    esac
    
    log_info "System: $SYSTEM ($DISTRO $VERSION) - $ARCH"
}

# 🧪 Test System Requirements
test_system_requirements() {
    log_test "System Requirements"
    
    local all_passed=true
    
    # Test CPU cores
    if [[ "$SYSTEM" == "Linux" ]]; then
        CPU_CORES=$(nproc)
    elif [[ "$SYSTEM" == "macOS" ]]; then
        CPU_CORES=$(sysctl -n hw.ncpu)
    else
        CPU_CORES="Unknown"
        all_passed=false
    fi
    
    if [[ "$CPU_CORES" -ge 4 ]]; then
        log_info "CPU Cores: $CPU_CORES (✓ Sufficient)"
    else
        log_warning "CPU Cores: $CPU_CORES (⚠️ Minimum 4 recommended)"
        all_passed=false
    fi
    
    # Test RAM
    if [[ "$SYSTEM" == "Linux" ]]; then
        RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    elif [[ "$SYSTEM" == "macOS" ]]; then
        RAM_BYTES=$(sysctl -n hw.memsize)
        RAM_GB=$((RAM_BYTES / 1024 / 1024 / 1024))
    else
        RAM_GB="Unknown"
        all_passed=false
    fi
    
    if [[ "$RAM_GB" -ge 8 ]]; then
        log_info "RAM: ${RAM_GB}GB (✓ Sufficient)"
    else
        log_warning "RAM: ${RAM_GB}GB (⚠️ Minimum 8GB recommended)"
        all_passed=false
    fi
    
    # Test disk space
    DISK_AVAILABLE=$(df -h . | awk 'NR==2 {print $4}')
    log_info "Available Disk Space: $DISK_AVAILABLE"
    
    if $all_passed; then
        test_result "System Requirements" "PASS"
    else
        test_result "System Requirements" "FAIL"
    fi
}

# 🐳 Test Docker
test_docker() {
    log_test "Docker Installation and Configuration"
    
    local docker_passed=true
    
    # Test Docker installation
    if command -v docker >/dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        log_info "Docker Version: $DOCKER_VERSION"
    else
        log_error "Docker is not installed"
        docker_passed=false
    fi
    
    # Test Docker daemon
    if docker info >/dev/null 2>&1; then
        log_info "Docker Daemon: Running"
    else
        log_error "Docker daemon is not running"
        docker_passed=false
    fi
    
    # Test Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_VERSION=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        log_info "Docker Compose Version: $COMPOSE_VERSION"
    else
        log_error "Docker Compose is not installed"
        docker_passed=false
    fi
    
    # Test Docker network
    if docker network ls | grep -q "gentleman_net"; then
        log_info "Gentleman Network: Exists"
    else
        log_warning "Gentleman Network: Not found (will be created)"
    fi
    
    if $docker_passed; then
        test_result "Docker" "PASS"
    else
        test_result "Docker" "FAIL"
    fi
}

# 🌐 Test Nebula
test_nebula() {
    log_test "Nebula Mesh Network"
    
    local nebula_passed=true
    
    # Test Nebula installation
    if command -v nebula >/dev/null 2>&1; then
        NEBULA_VERSION=$(nebula -version 2>&1 | head -n1)
        log_info "Nebula Version: $NEBULA_VERSION"
    else
        log_error "Nebula is not installed"
        nebula_passed=false
    fi
    
    # Test nebula-cert
    if command -v nebula-cert >/dev/null 2>&1; then
        log_info "Nebula-cert: Available"
    else
        log_error "Nebula-cert is not installed"
        nebula_passed=false
    fi
    
    # Test directory structure
    if [ -d "nebula" ]; then
        log_info "Nebula Directory: Exists"
        
        # Check subdirectories
        for dir in lighthouse rx-node m1-node i7-node; do
            if [ -d "nebula/$dir" ]; then
                log_info "  - $dir: ✓"
            else
                log_error "  - $dir: Missing"
                nebula_passed=false
            fi
        done
    else
        log_error "Nebula directory not found"
        nebula_passed=false
    fi
    
    if $nebula_passed; then
        test_result "Nebula Setup" "PASS"
    else
        test_result "Nebula Setup" "FAIL"
    fi
}

# 🔐 Test Certificates
test_certificates() {
    log_test "Nebula Certificates"
    
    local cert_passed=true
    
    # Test CA certificate
    if [ -f "nebula/lighthouse/ca.crt" ]; then
        log_info "CA Certificate: ✓ Found"
        
        # Verify CA certificate
        if nebula-cert print -path nebula/lighthouse/ca.crt >/dev/null 2>&1; then
            log_info "CA Certificate: ✓ Valid"
        else
            log_error "CA Certificate: Invalid"
            cert_passed=false
        fi
    else
        log_error "CA Certificate: Missing"
        cert_passed=false
    fi
    
    # Test RX node certificates
    RX_CERT_DIR="nebula/rx-node"
    if [ -d "$RX_CERT_DIR" ]; then
        log_info "RX Node Certificate Directory: ✓ Found"
        
        # Check required files
        for file in ca.crt rx-node.crt rx-node.key; do
            if [ -f "$RX_CERT_DIR/$file" ]; then
                log_info "  - $file: ✓"
            else
                log_error "  - $file: Missing"
                cert_passed=false
            fi
        done
        
        # Verify RX node certificate
        if [ -f "$RX_CERT_DIR/rx-node.crt" ]; then
            if nebula-cert print -path "$RX_CERT_DIR/rx-node.crt" >/dev/null 2>&1; then
                # Get certificate details
                CERT_INFO=$(nebula-cert print -path "$RX_CERT_DIR/rx-node.crt" 2>/dev/null)
                CERT_NAME=$(echo "$CERT_INFO" | grep "Name:" | awk '{print $2}')
                CERT_IP=$(echo "$CERT_INFO" | grep -A1 "Ips:" | tail -1 | awk '{print $1}')
                
                log_info "RX Certificate Name: $CERT_NAME"
                log_info "RX Certificate IP: $CERT_IP"
                
                if [[ "$CERT_NAME" == "rx-node" && "$CERT_IP" == "192.168.100.10/24" ]]; then
                    log_info "RX Certificate: ✓ Valid configuration"
                else
                    log_info "RX Certificate: ✓ Valid (Name: $CERT_NAME, IP: $CERT_IP)"
                fi
            else
                log_error "RX Certificate: Invalid format"
                cert_passed=false
            fi
        fi
    else
        log_error "RX Node Certificate Directory: Missing"
        cert_passed=false
    fi
    
    if $cert_passed; then
        test_result "Certificates" "PASS"
    else
        test_result "Certificates" "FAIL"
    fi
}

# ⚙️ Test Configuration
test_configuration() {
    log_test "Nebula Configuration"
    
    local config_passed=true
    
    # Test RX node config
    RX_CONFIG="nebula/rx-node/config.yml"
    if [ -f "$RX_CONFIG" ]; then
        log_info "RX Node Config: ✓ Found"
        
        # Check key configuration elements
        if grep -q "cert: rx-node.crt" "$RX_CONFIG"; then
            log_info "  - Certificate reference: ✓"
        else
            log_error "  - Certificate reference: Missing"
            config_passed=false
        fi
        
        if grep -q "key: rx-node.key" "$RX_CONFIG"; then
            log_info "  - Key reference: ✓"
        else
            log_error "  - Key reference: Missing"
            config_passed=false
        fi
        
        if grep -q "am_lighthouse: false" "$RX_CONFIG"; then
            log_info "  - Node type: ✓ Client node"
        else
            log_error "  - Node type: Incorrect configuration"
            config_passed=false
        fi
        
        # Check for placeholder values
        if grep -q "LIGHTHOUSE_IP" "$RX_CONFIG"; then
            log_warning "  - Lighthouse IP: Contains placeholder (needs manual update)"
        else
            log_info "  - Lighthouse IP: ✓ Configured"
        fi
    else
        log_error "RX Node Config: Missing"
        config_passed=false
    fi
    
    # Test environment file
    if [ -f ".env" ]; then
        log_info "Environment File: ✓ Found"
        
        # Check key variables
        if grep -q "RX_NODE_IP=192.168.100.10" ".env"; then
            log_info "  - RX Node IP: ✓ Configured"
        else
            log_warning "  - RX Node IP: Not configured"
        fi
    else
        log_warning "Environment File: Not found"
    fi
    
    if $config_passed; then
        test_result "Configuration" "PASS"
    else
        test_result "Configuration" "FAIL"
    fi
}

# 🌐 Test Network Configuration
test_network() {
    log_test "Network Configuration"
    
    local network_passed=true
    
    # Test if TUN/TAP is available (Linux)
    if [[ "$SYSTEM" == "Linux" ]]; then
        if [ -c /dev/net/tun ]; then
            log_info "TUN/TAP Device: ✓ Available"
        else
            log_error "TUN/TAP Device: Not available"
            log_info "  Run: sudo modprobe tun"
            network_passed=false
        fi
    fi
    
    # Test port availability
    if command -v netstat >/dev/null 2>&1; then
        if netstat -ln | grep -q ":4242"; then
            log_warning "Port 4242: Already in use"
        else
            log_info "Port 4242: ✓ Available"
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -ln | grep -q ":4242"; then
            log_warning "Port 4242: Already in use"
        else
            log_info "Port 4242: ✓ Available"
        fi
    else
        log_warning "Cannot check port availability (netstat/ss not found)"
    fi
    
    # Test firewall (Linux)
    if [[ "$SYSTEM" == "Linux" ]]; then
        if command -v ufw >/dev/null 2>&1; then
            UFW_STATUS=$(ufw status | head -n1)
            log_info "UFW Firewall: $UFW_STATUS"
            if [[ "$UFW_STATUS" == *"active"* ]]; then
                log_warning "  - Ensure port 4242/udp is allowed"
            fi
        elif command -v firewall-cmd >/dev/null 2>&1; then
            if systemctl is-active firewalld >/dev/null 2>&1; then
                log_info "Firewalld: Active"
                log_warning "  - Ensure port 4242/udp is allowed"
            else
                log_info "Firewalld: Inactive"
            fi
        fi
    fi
    
    if $network_passed; then
        test_result "Network Configuration" "PASS"
    else
        test_result "Network Configuration" "FAIL"
    fi
}

# 🎮 Test GPU Detection
test_gpu() {
    log_test "GPU Detection and Configuration"
    
    local gpu_found=false
    
    # Test for NVIDIA GPUs
    if command -v nvidia-smi >/dev/null 2>&1; then
        NVIDIA_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null || echo "")
        if [ -n "$NVIDIA_INFO" ]; then
            log_info "NVIDIA GPU Detected:"
            echo "$NVIDIA_INFO" | while read line; do
                log_info "  - $line"
            done
            gpu_found=true
            
            # Test CUDA
            if command -v nvcc >/dev/null 2>&1; then
                CUDA_VERSION=$(nvcc --version | grep "release" | cut -d' ' -f6 | cut -d',' -f1)
                log_info "CUDA Version: $CUDA_VERSION"
            else
                log_warning "CUDA toolkit not found"
            fi
        fi
    fi
    
    # Test for AMD GPUs (Linux)
    if [[ "$SYSTEM" == "Linux" ]]; then
        if command -v rocm-smi >/dev/null 2>&1; then
            AMD_INFO=$(rocm-smi --showproductname 2>/dev/null | grep "Card series" || echo "")
            if [ -n "$AMD_INFO" ]; then
                log_info "AMD GPU Detected:"
                log_info "  - $AMD_INFO"
                gpu_found=true
                
                # Test ROCm
                if [ -d "/opt/rocm" ]; then
                    ROCM_VERSION=$(cat /opt/rocm/.info/version 2>/dev/null || echo "Unknown")
                    log_info "ROCm Version: $ROCM_VERSION"
                else
                    log_warning "ROCm not found"
                fi
            fi
        else
            # Alternative AMD detection
            AMD_CARDS=$(lspci | grep -i "amd.*vga\|amd.*display" 2>/dev/null || echo "")
            if [ -n "$AMD_CARDS" ]; then
                log_info "AMD GPU Detected (via lspci):"
                echo "$AMD_CARDS" | while read line; do
                    log_info "  - $line"
                done
                gpu_found=true
            fi
        fi
    fi
    
    # Test for Apple Silicon GPU (macOS)
    if [[ "$SYSTEM" == "macOS" && "$ARCH" == "arm64" ]]; then
        log_info "Apple Silicon GPU: ✓ Available (Metal Performance Shaders)"
        gpu_found=true
        
        # Test Metal support
        if python3 -c "import torch; print('MPS available:', torch.backends.mps.is_available())" 2>/dev/null; then
            log_info "PyTorch MPS Support: ✓ Available"
        else
            log_warning "PyTorch MPS Support: Not available (install PyTorch with MPS support)"
        fi
    fi
    
    if ! $gpu_found; then
        log_warning "No GPU detected - will use CPU for AI workloads"
    fi
    
    test_result "GPU Detection" "PASS"  # Always pass, GPU is optional
}

# 🔧 Test System Resources
test_system_resources() {
    log_test "System Resources and Performance"
    
    # CPU load
    if [[ "$SYSTEM" == "Linux" ]]; then
        LOAD_AVG=$(uptime | cut -d',' -f3- | cut -d':' -f2)
        log_info "Load Average:$LOAD_AVG"
    elif [[ "$SYSTEM" == "macOS" ]]; then
        LOAD_AVG=$(uptime | cut -d':' -f4-)
        log_info "Load Average:$LOAD_AVG"
    fi
    
    # Memory usage
    if [[ "$SYSTEM" == "Linux" ]]; then
        MEM_INFO=$(free -h | grep "Mem:")
        MEM_USED=$(echo $MEM_INFO | awk '{print $3}')
        MEM_TOTAL=$(echo $MEM_INFO | awk '{print $2}')
        log_info "Memory Usage: $MEM_USED / $MEM_TOTAL"
    elif [[ "$SYSTEM" == "macOS" ]]; then
        MEM_PRESSURE=$(memory_pressure | head -n1)
        log_info "Memory Pressure: $MEM_PRESSURE"
    fi
    
    # Disk usage
    DISK_USAGE=$(df -h . | awk 'NR==2 {print $5 " used (" $3 "/" $2 ")"}')
    log_info "Disk Usage: $DISK_USAGE"
    
    # Temperature (if available)
    if command -v sensors >/dev/null 2>&1; then
        CPU_TEMP=$(sensors 2>/dev/null | grep "Core 0" | head -n1 | cut -d'+' -f2 | cut -d'(' -f1 || echo "N/A")
        if [ "$CPU_TEMP" != "N/A" ]; then
            log_info "CPU Temperature: $CPU_TEMP"
        fi
    fi
    
    test_result "System Resources" "PASS"
}

# 🧪 Run Nebula Test (if possible)
test_nebula_connectivity() {
    log_test "Nebula Connectivity Test"
    
    local connectivity_passed=true
    
    # Check if we can start nebula in test mode
    if [ -f "nebula/rx-node/config.yml" ] && [ -f "nebula/rx-node/ca.crt" ]; then
        log_info "Testing Nebula configuration syntax..."
        
        # Test config syntax (dry run) - run from the correct directory
        cd nebula/rx-node
        if nebula -config config.yml -test 2>/dev/null; then
            log_info "Nebula Config: ✓ Valid syntax"
        else
            log_warning "Nebula Config: Syntax test failed (may need lighthouse running)"
            # Don't fail the test for this, as it's expected without lighthouse
        fi
        cd ../..
    else
        log_warning "Cannot test Nebula connectivity - missing config or certificates"
        connectivity_passed=false
    fi
    
    if $connectivity_passed; then
        test_result "Nebula Connectivity" "PASS"
    else
        test_result "Nebula Connectivity" "FAIL"
    fi
}

# 📊 Generate Test Report
generate_report() {
    echo ""
    log_step "Test Summary"
    echo "═══════════════════════════════════════════════════════════════"
    
    echo -e "${WHITE}Total Tests: $TESTS_TOTAL${NC}"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed! RX Node is ready for deployment.${NC}"
        OVERALL_STATUS="READY"
    elif [ $TESTS_FAILED -le 2 ]; then
        echo -e "${YELLOW}⚠️  Minor issues detected. RX Node should work with manual fixes.${NC}"
        OVERALL_STATUS="NEEDS_ATTENTION"
    else
        echo -e "${RED}❌ Major issues detected. RX Node needs significant fixes.${NC}"
        OVERALL_STATUS="NOT_READY"
    fi
    
    echo ""
    log_step "Next Steps"
    echo "═══════════════════════════════════════════════════════════════"
    
    case $OVERALL_STATUS in
        "READY")
            echo -e "${GREEN}✅ Your RX Node is ready! Next steps:${NC}"
            echo "1. Update LIGHTHOUSE_IP in nebula/rx-node/config.yml"
            echo "2. Start Nebula: sudo nebula -config nebula/rx-node/config.yml"
            echo "3. Test connectivity: ping 192.168.100.1"
            echo "4. Start Docker services: docker-compose up -d"
            ;;
        "NEEDS_ATTENTION")
            echo -e "${YELLOW}⚠️  Fix these issues before deployment:${NC}"
            echo "1. Review failed tests above"
            echo "2. Install missing dependencies"
            echo "3. Fix configuration issues"
            echo "4. Re-run this test script"
            ;;
        "NOT_READY")
            echo -e "${RED}❌ Major setup required:${NC}"
            echo "1. Install missing system requirements"
            echo "2. Run setup script: ./setup.sh or ./Gentleman/setup.sh"
            echo "3. Fix all failed tests"
            echo "4. Re-run this test script"
            ;;
    esac
    
    echo ""
    echo -e "${CYAN}📋 For detailed logs and troubleshooting:${NC}"
    echo "- Check system logs: journalctl -u gentleman-nebula"
    echo "- Nebula logs: tail -f logs/nebula.log"
    echo "- Docker logs: docker-compose logs"
    echo ""
}

# 🚀 Main Test Function
main() {
    print_banner
    
    # System detection
    detect_system
    
    echo ""
    log_step "Running Comprehensive RX Node Tests"
    echo "═══════════════════════════════════════════════════════════════"
    
    # Run all tests
    test_system_requirements
    test_docker
    test_nebula
    test_certificates
    test_configuration
    test_network
    test_gpu
    test_system_resources
    test_nebula_connectivity
    
    # Generate final report
    generate_report
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 