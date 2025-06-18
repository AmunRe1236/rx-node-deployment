#!/bin/bash

# 🧪 RX Node Test Script - GENTLEMAN Dynamic Cluster
# Tests: GPU, ROCm, LM Studio, API, Inference Performance
# Usage: ./test_rx_node.sh

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
║  🧪 GENTLEMAN RX NODE TEST SUITE                             ║
║  Testing GPU Acceleration & LM Studio Performance           ║
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

echo -e "${BLUE}🚀 Starting RX Node Test Suite...${NC}"
echo -e "${YELLOW}📍 Node: $(hostname) ($(hostname -I | awk '{print $1}'))${NC}"
echo -e "${YELLOW}📅 Date: $(date)${NC}"
echo

# Test 1: System Information
echo -e "${CYAN}📋 Test 1: System Information${NC}"
echo "🖥️  Hostname: $(hostname)"
echo "🌐 IP Address: $(hostname -I | awk '{print $1}')"
echo "💻 OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "$(uname -s) $(uname -r)")"
echo "🧠 CPU: $(nproc) cores"
echo "💾 RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo "💿 Disk: $(df -h / | awk 'NR==2 {print $4}') free"
log_test "System Information" "PASS" "Basic system info collected"

# Test 2: AMD GPU Detection
echo -e "${CYAN}🎮 Test 2: AMD GPU Detection${NC}"
if command -v lspci >/dev/null 2>&1; then
    GPU_INFO=$(lspci | grep -i "vga\|3d\|display" | grep -i amd)
    if [ -n "$GPU_INFO" ]; then
        echo "🎯 Detected AMD GPU:"
        echo "$GPU_INFO"
        log_test "AMD GPU Detection" "PASS" "AMD GPU found"
    else
        log_test "AMD GPU Detection" "FAIL" "No AMD GPU detected"
    fi
else
    log_test "AMD GPU Detection" "FAIL" "lspci command not available"
fi

# Test 3: ROCm Installation
echo -e "${CYAN}🔧 Test 3: ROCm Installation${NC}"
ROCM_TESTS=0
ROCM_PASSED=0

# Check ROCm version
if command -v rocm-smi >/dev/null 2>&1; then
    ROCM_VERSION=$(rocm-smi --version 2>/dev/null | head -1 || echo "Unknown")
    echo "📦 ROCm Version: $ROCM_VERSION"
    ROCM_PASSED=$((ROCM_PASSED + 1))
fi
ROCM_TESTS=$((ROCM_TESTS + 1))

# Check GPU status with rocm-smi
if command -v rocm-smi >/dev/null 2>&1; then
    echo "🔍 GPU Status:"
    if rocm-smi 2>/dev/null; then
        ROCM_PASSED=$((ROCM_PASSED + 1))
    fi
fi
ROCM_TESTS=$((ROCM_TESTS + 1))

# Check HIP
if command -v hipconfig >/dev/null 2>&1; then
    HIP_VERSION=$(hipconfig --version 2>/dev/null || echo "Unknown")
    echo "🚀 HIP Version: $HIP_VERSION"
    ROCM_PASSED=$((ROCM_PASSED + 1))
fi
ROCM_TESTS=$((ROCM_TESTS + 1))

if [ $ROCM_PASSED -ge 2 ]; then
    log_test "ROCm Installation" "PASS" "$ROCM_PASSED/$ROCM_TESTS ROCm components working"
else
    log_test "ROCm Installation" "FAIL" "Only $ROCM_PASSED/$ROCM_TESTS ROCm components working"
fi

# Test 4: LM Studio Installation
echo -e "${CYAN}🤖 Test 4: LM Studio Installation${NC}"
LM_STUDIO_PATH=""
POSSIBLE_PATHS=(
    "$HOME/LMStudio/lms"
    "$HOME/lmstudio/lms" 
    "/opt/lmstudio/lms"
    "/usr/local/bin/lms"
    "$(which lms 2>/dev/null)"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path" ] && [ -x "$path" ]; then
        LM_STUDIO_PATH="$path"
        break
    fi
done

if [ -n "$LM_STUDIO_PATH" ]; then
    echo "📍 LM Studio found at: $LM_STUDIO_PATH"
    
    # Try to get version
    if LM_VERSION=$("$LM_STUDIO_PATH" --version 2>/dev/null); then
        echo "📦 Version: $LM_VERSION"
    fi
    
    log_test "LM Studio Installation" "PASS" "LM Studio binary found and executable"
else
    log_test "LM Studio Installation" "FAIL" "LM Studio binary not found"
fi

# Test 5: Network Connectivity
echo -e "${CYAN}🌐 Test 5: Network Connectivity${NC}"
EXPECTED_IP="192.168.68.117"
CURRENT_IP=$(hostname -I | awk '{print $1}')

echo "🎯 Expected IP: $EXPECTED_IP"
echo "📍 Current IP: $CURRENT_IP"

if [ "$CURRENT_IP" = "$EXPECTED_IP" ]; then
    log_test "IP Address" "PASS" "Correct RX Node IP"
else
    log_test "IP Address" "FAIL" "IP mismatch - Expected: $EXPECTED_IP, Got: $CURRENT_IP"
fi

# Test port 1234 availability
if command -v netstat >/dev/null 2>&1; then
    if netstat -tuln | grep -q ":1234"; then
        echo "🔌 Port 1234: In use (LM Studio likely running)"
        log_test "Port 1234 Status" "PASS" "Port is in use"
    else
        echo "🔌 Port 1234: Available"
        log_test "Port 1234 Status" "PASS" "Port is available"
    fi
else
    log_test "Port 1234 Status" "FAIL" "netstat not available"
fi

# Test 6: LM Studio API Test (if running)
echo -e "${CYAN}🔗 Test 6: LM Studio API Test${NC}"
API_URL="http://localhost:1234/v1/models"

if command -v curl >/dev/null 2>&1; then
    echo "🔍 Testing API endpoint: $API_URL"
    
    if API_RESPONSE=$(run_with_timeout 10s curl -s "$API_URL" 2>/dev/null); then
        if echo "$API_RESPONSE" | grep -q "object.*list"; then
            echo "✅ API Response: Valid"
            MODEL_COUNT=$(echo "$API_RESPONSE" | grep -o '"id"' | wc -l)
            echo "📊 Models available: $MODEL_COUNT"
            log_test "LM Studio API" "PASS" "API responding with $MODEL_COUNT models"
        else
            echo "⚠️  API Response: Invalid format"
            log_test "LM Studio API" "FAIL" "API response format invalid"
        fi
    else
        echo "❌ API not responding (LM Studio not running)"
        log_test "LM Studio API" "FAIL" "API not accessible - LM Studio may not be running"
    fi
else
    log_test "LM Studio API" "FAIL" "curl not available for testing"
fi

# Test 7: GPU Inference Test (if API is available)
echo -e "${CYAN}⚡ Test 7: GPU Inference Performance Test${NC}"

if [ "$TESTS_PASSED" -gt 0 ] && command -v curl >/dev/null 2>&1; then
    CHAT_URL="http://localhost:1234/v1/chat/completions"
    
    # Prepare test payload
    TEST_PAYLOAD='{
        "model": "local-model",
        "messages": [
            {"role": "user", "content": "Calculate 2+2 and explain briefly."}
        ],
        "max_tokens": 50,
        "temperature": 0.1
    }'
    
    echo "🧮 Running inference test..."
    echo "📝 Test prompt: 'Calculate 2+2 and explain briefly.'"
    
    START_TIME=$(date +%s.%N)
    
    if INFERENCE_RESPONSE=$(run_with_timeout 45s curl -s -X POST "$CHAT_URL" \
        -H "Content-Type: application/json" \
        -d "$TEST_PAYLOAD" 2>/dev/null); then
        
        END_TIME=$(date +%s.%N)
        DURATION=$(echo "$END_TIME - $START_TIME" | bc -l 2>/dev/null || echo "Unknown")
        
        if echo "$INFERENCE_RESPONSE" | grep -q '"content"'; then
            echo "✅ Inference successful!"
            echo "⏱️  Response time: ${DURATION}s"
            
            # Extract response content
            RESPONSE_CONTENT=$(echo "$INFERENCE_RESPONSE" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
            echo "💬 Response: $RESPONSE_CONTENT"
            
            # Performance evaluation
            if [ -n "$DURATION" ] && [ "$DURATION" != "Unknown" ]; then
                if (( $(echo "$DURATION < 30" | bc -l 2>/dev/null || echo 0) )); then
                    log_test "GPU Inference Performance" "PASS" "Response time: ${DURATION}s (< 30s target)"
                else
                    log_test "GPU Inference Performance" "FAIL" "Response time: ${DURATION}s (> 30s target)"
                fi
            else
                log_test "GPU Inference Performance" "PASS" "Inference successful (timing unavailable)"
            fi
        else
            echo "❌ Inference failed - Invalid response"
            log_test "GPU Inference Performance" "FAIL" "Invalid inference response"
        fi
    else
        echo "❌ Inference test timed out or failed"
        log_test "GPU Inference Performance" "FAIL" "Inference request failed or timed out"
    fi
else
    echo "⏭️  Skipping inference test (LM Studio API not available)"
    log_test "GPU Inference Performance" "SKIP" "API not available for testing"
fi

# Test 8: System Resources During Load
echo -e "${CYAN}📊 Test 8: System Resources${NC}"
echo "💾 Memory Usage:"
free -h
echo
echo "🔥 CPU Load:"
uptime
echo
echo "🌡️  Temperature (if available):"
if command -v sensors >/dev/null 2>&1; then
    sensors 2>/dev/null | grep -E "(temp|Temp)" | head -5 || echo "Temperature sensors not available"
else
    echo "lm-sensors not installed"
fi
log_test "System Resources" "PASS" "Resource monitoring completed"

# Final Results Summary
echo -e "${PURPLE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║  📊 TEST RESULTS SUMMARY                                     ║
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

# Recommendations
echo -e "${BLUE}💡 Recommendations:${NC}"
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! RX Node is fully operational.${NC}"
    echo "🚀 Ready for AI inference workloads"
    echo "🎮 GPU acceleration is working properly"
elif [ $TESTS_PASSED -gt $TESTS_FAILED ]; then
    echo -e "${YELLOW}⚠️  Most tests passed, but some issues detected:${NC}"
    echo "🔧 Check failed tests above and resolve issues"
    echo "🔄 Re-run this test after fixes"
else
    echo -e "${RED}🚨 Multiple critical issues detected:${NC}"
    echo "🛠️  Run deployment script again: ./quick_rx_deployment.sh"
    echo "📞 Contact system administrator if issues persist"
fi

echo
echo -e "${PURPLE}🏁 RX Node Test Complete - $(date)${NC}"

# Exit with appropriate code
if [ $TESTS_FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi 