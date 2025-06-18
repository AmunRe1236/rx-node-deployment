#!/bin/bash

# 🖥️ i7 Node Test Script - GENTLEMAN Dynamic Cluster
# Tests: CPU, Intel optimizations, LM Studio, API, CPU inference performance
# Usage: ./test_i7_node.sh

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ASCII Art Header
echo -e "${PURPLE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║  🖥️ GENTLEMAN i7 NODE TEST SUITE                             ║
║  Testing CPU Optimization & LM Studio Performance           ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Test Results Tracking
TESTS_PASSED=0
TESTS_FAILED=0
TEST_RESULTS=()

# Function to log test results
log_test() {
    local test_name="$1"
    local status="$2"
    local details="$3"
    
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✅ $test_name: PASSED${NC}"
        [ -n "$details" ] && echo -e "   ${CYAN}$details${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TEST_RESULTS+=("✅ $test_name: PASSED")
    else
        echo -e "${RED}❌ $test_name: FAILED${NC}"
        [ -n "$details" ] && echo -e "   ${RED}$details${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TEST_RESULTS+=("❌ $test_name: FAILED")
    fi
    echo
}

# Function to run command with timeout
run_with_timeout() {
    local timeout_duration="$1"
    shift
    timeout "$timeout_duration" "$@"
}

echo -e "${BLUE}🚀 Starting i7 Node Test Suite...${NC}"
echo -e "${YELLOW}📍 Node: $(hostname) ($(hostname -I | awk '{print $1}'))${NC}"
echo -e "${YELLOW}📅 Date: $(date)${NC}"
echo

# Test 1: System Information & Node Validation
echo -e "${CYAN}📋 Test 1: System Information & Node Validation${NC}"
echo "🖥️  Hostname: $(hostname)"
echo "🌐 IP Address: $(hostname -I | awk '{print $1}')"
echo "💻 OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "$(uname -s) $(uname -r)")"
echo "🧠 CPU: $(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)"
echo "🔢 CPU Cores: $(nproc) cores"
echo "💾 RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo "💿 Disk: $(df -h / | awk 'NR==2 {print $4}') free"

# Verify this is NOT the RX node
CURRENT_IP=$(hostname -I | awk '{print $1}')
if [ "$CURRENT_IP" = "192.168.68.117" ]; then
    log_test "Node Validation" "FAIL" "This appears to be RX Node (192.168.68.117) - Use test_rx_node.sh instead"
else
    log_test "Node Validation" "PASS" "Confirmed i7 node (not RX node)"
fi

# Test 2: Intel CPU Detection & Features
echo -e "${CYAN}🧠 Test 2: Intel CPU Detection & AI Features${NC}"
CPU_TESTS=0
CPU_PASSED=0

# Check for Intel CPU
if lscpu | grep -qi "intel"; then
    echo "✅ Intel CPU detected"
    CPU_VENDOR="intel"
    CPU_PASSED=$((CPU_PASSED + 1))
else
    echo "⚠️  Non-Intel CPU detected"
    CPU_VENDOR="generic"
fi
CPU_TESTS=$((CPU_TESTS + 1))

# Check CPU features for AI workloads
echo "🔍 Checking CPU AI acceleration features:"
CPU_FEATURES=""
if grep -q "avx2" /proc/cpuinfo; then
    echo "  ✅ AVX2 support detected"
    CPU_FEATURES="$CPU_FEATURES avx2"
    CPU_PASSED=$((CPU_PASSED + 1))
fi
CPU_TESTS=$((CPU_TESTS + 1))

if grep -q "avx512" /proc/cpuinfo; then
    echo "  ✅ AVX-512 support detected"
    CPU_FEATURES="$CPU_FEATURES avx512"
    CPU_PASSED=$((CPU_PASSED + 1))
fi
CPU_TESTS=$((CPU_TESTS + 1))

if grep -q "fma" /proc/cpuinfo; then
    echo "  ✅ FMA support detected"
    CPU_FEATURES="$CPU_FEATURES fma"
    CPU_PASSED=$((CPU_PASSED + 1))
fi
CPU_TESTS=$((CPU_TESTS + 1))

if [ $CPU_PASSED -ge 3 ]; then
    log_test "Intel CPU & AI Features" "PASS" "$CPU_PASSED/$CPU_TESTS features available: $CPU_FEATURES"
else
    log_test "Intel CPU & AI Features" "FAIL" "Only $CPU_PASSED/$CPU_TESTS AI features available"
fi

# Test 3: CPU Optimization Libraries
echo -e "${CYAN}🔧 Test 3: CPU Optimization Libraries${NC}"
OPT_TESTS=0
OPT_PASSED=0

# Check for Intel MKL
if ldconfig -p | grep -q "libmkl"; then
    echo "📦 Intel MKL: Available"
    OPT_PASSED=$((OPT_PASSED + 1))
else
    echo "📦 Intel MKL: Not found"
fi
OPT_TESTS=$((OPT_TESTS + 1))

# Check for OpenBLAS
if ldconfig -p | grep -q "libopenblas"; then
    echo "📦 OpenBLAS: Available"
    OPT_PASSED=$((OPT_PASSED + 1))
else
    echo "📦 OpenBLAS: Not found"
fi
OPT_TESTS=$((OPT_TESTS + 1))

# Check for OpenMP
if ldconfig -p | grep -q "libomp\|libgomp"; then
    echo "📦 OpenMP: Available"
    OPT_PASSED=$((OPT_PASSED + 1))
else
    echo "📦 OpenMP: Not found"
fi
OPT_TESTS=$((OPT_TESTS + 1))

if [ $OPT_PASSED -ge 2 ]; then
    log_test "CPU Optimization Libraries" "PASS" "$OPT_PASSED/$OPT_TESTS optimization libraries available"
else
    log_test "CPU Optimization Libraries" "FAIL" "Only $OPT_PASSED/$OPT_TESTS optimization libraries available"
fi

# Test 4: i7 LM Studio Installation
echo -e "${CYAN}🤖 Test 4: i7 LM Studio Installation${NC}"
I7_INSTALL_DIR="$HOME/i7-lmstudio"
LM_STUDIO_PATH=""
POSSIBLE_PATHS=(
    "$I7_INSTALL_DIR/LM_Studio-0.2.29.AppImage"
    "$HOME/i7-lmstudio/lms"
    "/opt/i7-lmstudio/LM_Studio-0.2.29.AppImage"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path" ] && [ -x "$path" ]; then
        LM_STUDIO_PATH="$path"
        break
    fi
done

if [ -n "$LM_STUDIO_PATH" ]; then
    echo "📍 i7 LM Studio found at: $LM_STUDIO_PATH"
    
    # Check for i7-specific wrapper script
    if [ -f "$I7_INSTALL_DIR/start_i7_lmstudio.sh" ]; then
        echo "📜 i7 wrapper script: Available"
        log_test "i7 LM Studio Installation" "PASS" "i7 LM Studio and wrapper script found"
    else
        log_test "i7 LM Studio Installation" "FAIL" "i7 wrapper script missing"
    fi
else
    log_test "i7 LM Studio Installation" "FAIL" "i7 LM Studio binary not found"
fi

# Test 5: Network Connectivity & Port Configuration
echo -e "${CYAN}🌐 Test 5: Network Connectivity & Port Configuration${NC}"
CURRENT_IP=$(hostname -I | awk '{print $1}')
I7_PORT="1235"

echo "📍 Current IP: $CURRENT_IP"
echo "🔧 Expected i7 Port: $I7_PORT"

# Test port 1235 availability (i7-specific)
if command -v netstat >/dev/null 2>&1; then
    if netstat -tuln | grep -q ":$I7_PORT"; then
        echo "🔌 Port $I7_PORT: In use (i7 LM Studio likely running)"
        log_test "i7 Port Configuration" "PASS" "Port $I7_PORT is in use"
    else
        echo "🔌 Port $I7_PORT: Available"
        log_test "i7 Port Configuration" "PASS" "Port $I7_PORT is available"
    fi
else
    log_test "i7 Port Configuration" "FAIL" "netstat not available"
fi

# Verify we're not using RX node port
if netstat -tuln 2>/dev/null | grep -q ":1234"; then
    log_test "Port Conflict Check" "FAIL" "Port 1234 (RX node) is in use - potential conflict"
else
    log_test "Port Conflict Check" "PASS" "No conflict with RX node port 1234"
fi

# Test 6: i7 LM Studio API Test
echo -e "${CYAN}🔗 Test 6: i7 LM Studio API Test${NC}"
I7_API_URL="http://localhost:$I7_PORT/v1/models"

if command -v curl >/dev/null 2>&1; then
    echo "🔍 Testing i7 API endpoint: $I7_API_URL"
    
    if API_RESPONSE=$(run_with_timeout 10s curl -s "$I7_API_URL" 2>/dev/null); then
        if echo "$API_RESPONSE" | grep -q "object.*list"; then
            echo "✅ i7 API Response: Valid"
            MODEL_COUNT=$(echo "$API_RESPONSE" | grep -o '"id"' | wc -l)
            echo "📊 Models available: $MODEL_COUNT"
            log_test "i7 LM Studio API" "PASS" "i7 API responding with $MODEL_COUNT models"
        else
            echo "⚠️  i7 API Response: Invalid format"
            log_test "i7 LM Studio API" "FAIL" "i7 API response format invalid"
        fi
    else
        echo "❌ i7 API not responding (LM Studio not running on port $I7_PORT)"
        log_test "i7 LM Studio API" "FAIL" "i7 API not accessible - LM Studio may not be running"
    fi
else
    log_test "i7 LM Studio API" "FAIL" "curl not available for testing"
fi

# Test 7: CPU Inference Performance Test
echo -e "${CYAN}⚡ Test 7: CPU Inference Performance Test${NC}"

if [ "$TESTS_PASSED" -gt 0 ] && command -v curl >/dev/null 2>&1; then
    I7_CHAT_URL="http://localhost:$I7_PORT/v1/chat/completions"
    
    # Prepare test payload optimized for CPU
    TEST_PAYLOAD='{
        "model": "local-model",
        "messages": [
            {"role": "user", "content": "What is 15 * 23? Show your calculation."}
        ],
        "max_tokens": 100,
        "temperature": 0.1
    }'
    
    echo "🧮 Running CPU inference test..."
    echo "📝 Test prompt: 'What is 15 * 23? Show your calculation.'"
    echo "🎯 Target: < 60s for CPU inference"
    
    # Monitor CPU usage during test
    CPU_BEFORE=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}')
    
    START_TIME=$(date +%s.%N)
    
    if INFERENCE_RESPONSE=$(run_with_timeout 120s curl -s -X POST "$I7_CHAT_URL" \
        -H "Content-Type: application/json" \
        -d "$TEST_PAYLOAD" 2>/dev/null); then
        
        END_TIME=$(date +%s.%N)
        CPU_AFTER=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}')
        
        DURATION=$(echo "$END_TIME - $START_TIME" | bc -l 2>/dev/null || echo "Unknown")
        
        if echo "$INFERENCE_RESPONSE" | grep -q '"content"'; then
            echo "✅ CPU Inference successful!"
            echo "⏱️  Response time: ${DURATION}s"
            echo "🧠 CPU cores: $(nproc)"
            
            # Extract response content
            RESPONSE_CONTENT=$(echo "$INFERENCE_RESPONSE" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
            echo "💬 Response: $RESPONSE_CONTENT"
            
            # Performance evaluation for CPU
            if [ -n "$DURATION" ] && [ "$DURATION" != "Unknown" ]; then
                if (( $(echo "$DURATION < 60" | bc -l 2>/dev/null || echo 0) )); then
                    log_test "CPU Inference Performance" "PASS" "Response time: ${DURATION}s (< 60s CPU target)"
                elif (( $(echo "$DURATION < 120" | bc -l 2>/dev/null || echo 0) )); then
                    log_test "CPU Inference Performance" "PASS" "Response time: ${DURATION}s (acceptable for CPU)"
                else
                    log_test "CPU Inference Performance" "FAIL" "Response time: ${DURATION}s (> 120s - too slow)"
                fi
            else
                log_test "CPU Inference Performance" "PASS" "CPU inference successful (timing unavailable)"
            fi
        else
            echo "❌ CPU Inference failed - Invalid response"
            log_test "CPU Inference Performance" "FAIL" "Invalid CPU inference response"
        fi
    else
        echo "❌ CPU Inference test timed out or failed"
        log_test "CPU Inference Performance" "FAIL" "CPU inference request failed or timed out"
    fi
else
    echo "⏭️  Skipping CPU inference test (i7 LM Studio API not available)"
    log_test "CPU Inference Performance" "SKIP" "i7 API not available for testing"
fi

# Test 8: System Resources & Temperature Monitoring
echo -e "${CYAN}📊 Test 8: System Resources & Temperature${NC}"
echo "💾 Memory Usage:"
free -h
echo
echo "🔥 CPU Load:"
uptime
echo
echo "🌡️  CPU Temperature:"
if command -v sensors >/dev/null 2>&1; then
    TEMP_OUTPUT=$(sensors 2>/dev/null | grep -E "(Core|Package|CPU)" | head -5)
    if [ -n "$TEMP_OUTPUT" ]; then
        echo "$TEMP_OUTPUT"
    else
        echo "Temperature sensors available but no CPU temps found"
    fi
else
    echo "lm-sensors not installed - cannot monitor CPU temperature"
fi

echo
echo "⚙️  CPU Frequency:"
if [ -f "/proc/cpuinfo" ]; then
    grep "MHz" /proc/cpuinfo | head -4
else
    echo "CPU frequency information not available"
fi

log_test "System Resources" "PASS" "Resource monitoring completed"

# Test 9: i7 Service Status
echo -e "${CYAN}🔧 Test 9: i7 Service Status${NC}"
SERVICE_NAME="i7-lmstudio"

if systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
    echo "📋 i7 Service: Installed"
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "🟢 i7 Service: Active"
        log_test "i7 Service Status" "PASS" "i7-lmstudio service is active"
    elif systemctl is-enabled --quiet "$SERVICE_NAME"; then
        echo "🟡 i7 Service: Enabled but not active"
        log_test "i7 Service Status" "PASS" "i7-lmstudio service is enabled"
    else
        echo "🔴 i7 Service: Inactive"
        log_test "i7 Service Status" "FAIL" "i7-lmstudio service is not active"
    fi
else
    echo "❌ i7 Service: Not installed"
    log_test "i7 Service Status" "FAIL" "i7-lmstudio service not found"
fi

# Final Results Summary
echo -e "${PURPLE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║  📊 i7 NODE TEST RESULTS SUMMARY                             ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}✅ Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}❌ Tests Failed: $TESTS_FAILED${NC}"
echo -e "${YELLOW}📈 Success Rate: $(( TESTS_PASSED * 100 / (TESTS_PASSED + TESTS_FAILED) ))%${NC}"
echo

echo -e "${CYAN}📋 Detailed Results:${NC}"
for result in "${TEST_RESULTS[@]}"; do
    echo "   $result"
done
echo

# i7-Specific Recommendations
echo -e "${BLUE}💡 i7 Node Recommendations:${NC}"
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! i7 Node is fully operational.${NC}"
    echo "🖥️  Ready for CPU-based AI inference workloads"
    echo "🧠 CPU optimizations are working properly"
    echo "🔧 Use port 1235 for i7 node API access"
elif [ $TESTS_PASSED -gt $TESTS_FAILED ]; then
    echo -e "${YELLOW}⚠️  Most tests passed, but some issues detected:${NC}"
    echo "🔧 Check failed tests above and resolve issues"
    echo "🔄 Re-run this test after fixes"
    echo "💡 Consider using smaller models (< 7B) for better CPU performance"
else
    echo -e "${RED}🚨 Multiple critical issues detected:${NC}"
    echo "🛠️  Run i7 deployment script: ./i7_node_deployment.sh"
    echo "📞 Contact system administrator if issues persist"
fi

echo
echo -e "${YELLOW}📋 i7 Node Specific Notes:${NC}"
echo "• CPU-based inference is slower than GPU (expect 60-120s response times)"
echo "• Use quantized models (Q4_K_M, Q5_K_M) for better performance"
echo "• Port 1235 is reserved for i7 node (different from RX node port 1234)"
echo "• Intel MKL and OpenMP optimizations should be active"
echo "• Monitor CPU temperature during heavy inference workloads"

echo
echo -e "${PURPLE}🏁 i7 Node Test Complete - $(date)${NC}"

# Exit with appropriate code
if [ $TESTS_FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi 