#!/bin/bash

# 🖥️ GENTLEMAN i7 Node Test Suite (macOS)
# macOS-specific testing for i7 CPU inference
# Usage: ./test_i7_macos.sh

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ASCII Header
echo -e "${PURPLE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║  🖥️ GENTLEMAN i7 NODE TEST SUITE (macOS)                     ║
║  Testing CPU Optimization & LM Studio Performance           ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Functions
log_test() {
    echo -e "${CYAN}📋 Test $1: $2${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

log_failure() {
    echo -e "${RED}❌ $1${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

log_info() {
    echo -e "${BLUE}🔍 $1${NC}"
}

echo -e "${BLUE}🚀 Starting i7 Node (macOS) Test Suite...${NC}"
echo -e "${YELLOW}📍 Node: $(hostname)${NC}"
echo -e "${YELLOW}📅 Date: $(date)${NC}"
echo

# Test 1: System Information
log_test "1" "macOS System Information & Node Validation"
echo "🖥️  Hostname: $(hostname)"
echo "🌐 IP Address: $(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)"
echo "💻 OS: $(sw_vers -productName) $(sw_vers -productVersion)"
echo "🧠 CPU: $(sysctl -n machdep.cpu.brand_string)"
echo "🔢 CPU Cores: $(sysctl -n hw.ncpu) cores"
echo "💾 RAM: $(echo "$(sysctl -n hw.memsize) / 1024 / 1024 / 1024" | bc)GB"
echo "💿 Disk: $(df -h / | awk 'NR==2 {print $4}') free"

# Verify this is i7 node (IP check)
CURRENT_IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
if [ "$CURRENT_IP" = "192.168.68.105" ]; then
    log_success "Node Validation: PASSED - Confirmed i7 node (192.168.68.105)"
else
    log_failure "Node Validation: WARNING - Expected 192.168.68.105, got $CURRENT_IP"
fi

# Test 2: Intel CPU Features
log_test "2" "Intel CPU Detection & AI Features"
CPU_BRAND=$(sysctl -n machdep.cpu.brand_string)
if echo "$CPU_BRAND" | grep -qi "intel"; then
    echo "✅ Intel CPU detected: $CPU_BRAND"
    
    # Check CPU features
    FEATURES_COUNT=0
    echo "🔍 Checking CPU AI acceleration features:"
    
    if sysctl -n machdep.cpu.features | grep -qi "AVX2"; then
        echo "  ✅ AVX2 support detected"
        FEATURES_COUNT=$((FEATURES_COUNT + 1))
    fi
    
    if sysctl -n machdep.cpu.leaf7_features | grep -qi "AVX512"; then
        echo "  ✅ AVX-512 support detected"
        FEATURES_COUNT=$((FEATURES_COUNT + 1))
    fi
    
    if sysctl -n machdep.cpu.features | grep -qi "FMA"; then
        echo "  ✅ FMA support detected"
        FEATURES_COUNT=$((FEATURES_COUNT + 1))
    fi
    
    if [ $FEATURES_COUNT -ge 2 ]; then
        log_success "Intel CPU & AI Features: PASSED - $FEATURES_COUNT/3 AI features available"
    else
        log_failure "Intel CPU & AI Features: FAILED - Only $FEATURES_COUNT/3 AI features available"
    fi
else
    log_failure "Intel CPU Detection: FAILED - Non-Intel CPU detected"
fi

# Test 3: macOS Optimization Libraries
log_test "3" "macOS CPU Optimization Libraries"
LIBS_COUNT=0

# Check for Accelerate framework (macOS native)
if [ -d "/System/Library/Frameworks/Accelerate.framework" ]; then
    echo "📦 Accelerate Framework: Available (macOS native BLAS/LAPACK)"
    LIBS_COUNT=$((LIBS_COUNT + 1))
fi

# Check for OpenMP via Homebrew
if brew list | grep -q "libomp"; then
    echo "📦 OpenMP: Available via Homebrew"
    LIBS_COUNT=$((LIBS_COUNT + 1))
fi

# Check for Intel MKL
if [ -d "/opt/intel/mkl" ] || brew list | grep -q "intel-mkl"; then
    echo "📦 Intel MKL: Available"
    LIBS_COUNT=$((LIBS_COUNT + 1))
fi

if [ $LIBS_COUNT -ge 1 ]; then
    log_success "CPU Optimization Libraries: PASSED - $LIBS_COUNT optimization libraries available"
else
    log_failure "CPU Optimization Libraries: FAILED - No optimization libraries found"
fi

# Test 4: LM Studio Installation Check
log_test "4" "i7 LM Studio Installation"
LMSTUDIO_DIR="$HOME/i7-lmstudio"
if [ -d "$LMSTUDIO_DIR" ]; then
    echo "📁 Installation directory: $LMSTUDIO_DIR exists"
    
    if [ -f "$LMSTUDIO_DIR/start_i7_lmstudio_macos.sh" ]; then
        echo "🚀 Startup script: Available"
        log_success "i7 LM Studio Installation: PASSED - Setup files found"
    else
        log_failure "i7 LM Studio Installation: FAILED - Startup script missing"
    fi
else
    log_failure "i7 LM Studio Installation: FAILED - Installation directory not found"
fi

# Test 5: Network & Port Configuration
log_test "5" "Network Connectivity & Port Configuration"
CURRENT_IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
echo "📍 Current IP: $CURRENT_IP"
echo "🔧 Expected i7 Port: 1235"

# Check if port 1235 is available
if ! lsof -i :1235 > /dev/null 2>&1; then
    echo "🔌 Port 1235: Available"
    log_success "i7 Port Configuration: PASSED - Port 1235 is available"
else
    echo "🔌 Port 1235: In use"
    log_failure "i7 Port Configuration: FAILED - Port 1235 is already in use"
fi

# Check for port conflicts with RX node
if ! lsof -i :1234 > /dev/null 2>&1; then
    log_success "Port Conflict Check: PASSED - No conflict with RX node port 1234"
else
    echo "⚠️  Port 1234 is in use (expected if RX node is running)"
fi

# Test 6: GENTLEMAN Protocol
log_test "6" "GENTLEMAN Protocol Integration"
if [ -f "talking_gentleman_protocol.py" ]; then
    echo "🎩 GENTLEMAN Protocol: Available"
    
    # Test protocol status
    if python3 talking_gentleman_protocol.py --status > /dev/null 2>&1; then
        log_success "GENTLEMAN Protocol: PASSED - Protocol responds"
    else
        log_failure "GENTLEMAN Protocol: FAILED - Protocol not responding"
    fi
else
    log_failure "GENTLEMAN Protocol: FAILED - Protocol file not found"
fi

# Test 7: Cross-Node Connectivity
log_test "7" "Cross-Node Connectivity Test"
echo "🔗 Testing connectivity to other nodes:"

# Test RX Node
if curl -s --connect-timeout 5 http://192.168.68.117:8008/status > /dev/null 2>&1; then
    echo "✅ RX Node (192.168.68.117): Online"
    RX_ONLINE=true
else
    echo "❌ RX Node (192.168.68.117): Offline"
    RX_ONLINE=false
fi

# Test M1 Mac
if curl -s --connect-timeout 5 http://192.168.68.111:8007/status > /dev/null 2>&1; then
    echo "✅ M1 Mac (192.168.68.111): Online"
    M1_ONLINE=true
else
    echo "❌ M1 Mac (192.168.68.111): Offline"
    M1_ONLINE=false
fi

if [ "$RX_ONLINE" = true ] || [ "$M1_ONLINE" = true ]; then
    log_success "Cross-Node Connectivity: PASSED - At least one node reachable"
else
    log_failure "Cross-Node Connectivity: FAILED - No other nodes reachable"
fi

# Test 8: Performance Baseline
log_test "8" "System Performance Baseline"
echo "⚡ Running system performance tests..."

# CPU benchmark
echo "🧮 CPU Test: Calculating pi to 1000 digits"
START_TIME=$(date +%s.%N)
echo "scale=1000; 4*a(1)" | bc -l > /dev/null 2>&1
END_TIME=$(date +%s.%N)
CPU_TIME=$(echo "$END_TIME - $START_TIME" | bc)
echo "⏱️  CPU calculation time: ${CPU_TIME}s"

# Memory test
echo "💾 Memory Test: Available memory"
AVAILABLE_MEM=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
AVAILABLE_MB=$((AVAILABLE_MEM * 4096 / 1024 / 1024))
echo "💾 Available memory: ${AVAILABLE_MB}MB"

if (( $(echo "$CPU_TIME < 5.0" | bc -l) )); then
    log_success "System Performance: PASSED - Good CPU performance"
else
    log_failure "System Performance: FAILED - Slow CPU performance"
fi

# Final Summary
echo
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                    📊 TEST SUMMARY                           ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${BLUE}📋 Total Tests: $TOTAL_TESTS${NC}"
echo -e "${GREEN}✅ Passed: $PASSED_TESTS${NC}"
echo -e "${RED}❌ Failed: $FAILED_TESTS${NC}"

# Calculate success rate
if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc)
    echo -e "${YELLOW}📊 Success Rate: ${SUCCESS_RATE}%${NC}"
    
    if (( $(echo "$SUCCESS_RATE >= 80" | bc -l) )); then
        echo -e "${GREEN}🎉 i7 Node Test Suite: OVERALL PASS${NC}"
        exit 0
    else
        echo -e "${RED}💥 i7 Node Test Suite: OVERALL FAIL${NC}"
        exit 1
    fi
else
    echo -e "${RED}💥 No tests were executed${NC}"
    exit 1
fi 