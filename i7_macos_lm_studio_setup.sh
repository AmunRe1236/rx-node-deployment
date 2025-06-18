#!/bin/bash

# 🖥️ GENTLEMAN i7 Node (macOS) LM Studio Setup
# macOS-optimized LM Studio installation for CPU inference
# Target: i7 Node (192.168.68.105) - macOS system

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║  🖥️ GENTLEMAN i7 NODE (macOS) LM STUDIO SETUP               ║
║  CPU Optimized LM Studio Installation for macOS             ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Configuration
LM_STUDIO_PORT="1235"  # Different port from RX node (1234)
INSTALL_DIR="$HOME/i7-lmstudio"
SERVICE_NAME="i7-lmstudio"

echo -e "${BLUE}🚀 Starting i7 Node (macOS) LM Studio Setup...${NC}"
echo -e "${YELLOW}📍 Target: i7 CPU-based inference (macOS)${NC}"
echo -e "${YELLOW}📅 Date: $(date)${NC}"
echo -e "${YELLOW}🔧 Port: $LM_STUDIO_PORT (i7-specific)${NC}"
echo

# Function to log steps
log_step() {
    echo -e "${CYAN}🔹 $1${NC}"
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

# Step 1: System Information (macOS)
log_step "Step 1: macOS System Information"
echo "🖥️  Hostname: $(hostname)"
echo "🌐 IP Address: $(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1)"
echo "💻 OS: $(sw_vers -productName) $(sw_vers -productVersion)"
echo "🧠 CPU: $(sysctl -n machdep.cpu.brand_string)"
echo "🔢 CPU Cores: $(sysctl -n hw.ncpu) cores"
echo "💾 RAM: $(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))GB"
echo "💿 Disk Space: $(df -h / | awk 'NR==2 {print $4}') available"

log_success "macOS System information collected"

# Step 2: CPU Features Check (macOS)
log_step "Step 2: macOS CPU Features Check"
echo "🔍 Checking CPU features for AI optimization:"

# Check macOS CPU features
CPU_FEATURES=""
if sysctl -n machdep.cpu.features | grep -q "AVX2"; then
    echo "  ✅ AVX2 support detected"
    CPU_FEATURES="$CPU_FEATURES avx2"
fi

if sysctl -n machdep.cpu.leaf7_features | grep -q "AVX512"; then
    echo "  ✅ AVX-512 support detected"
    CPU_FEATURES="$CPU_FEATURES avx512"
fi

if sysctl -n machdep.cpu.features | grep -q "FMA"; then
    echo "  ✅ FMA support detected"
    CPU_FEATURES="$CPU_FEATURES fma"
fi

if [ -n "$CPU_FEATURES" ]; then
    log_success "CPU features for AI acceleration: $CPU_FEATURES"
else
    log_warning "Limited CPU AI acceleration features detected"
fi

# Step 3: Check for Homebrew
log_step "Step 3: Homebrew Check"
if command -v brew >/dev/null 2>&1; then
    log_success "Homebrew detected"
    brew update || log_warning "Homebrew update failed"
else
    log_warning "Homebrew not found - manual installation may be needed"
fi

# Step 4: Create Installation Directory
log_step "Step 4: Creating Installation Directory"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
log_success "Installation directory created: $INSTALL_DIR"

# Step 5: Download LM Studio for macOS
log_step "Step 5: Downloading LM Studio for macOS"

# Check if already downloaded
if [ -f "$INSTALL_DIR/LMStudio-0.2.29.dmg" ]; then
    log_success "LM Studio DMG already exists"
else
    # Download LM Studio for macOS
    LM_STUDIO_URL="https://releases.lmstudio.ai/mac/0.2.29/LMStudio-0.2.29.dmg"
    curl -L -o "LMStudio-0.2.29.dmg" "$LM_STUDIO_URL" || {
        log_error "Download failed - continuing with existing setup"
    }
fi

# Step 6: Create LM Studio wrapper script for macOS
log_step "Step 6: Creating macOS LM Studio wrapper script"
cat > "$INSTALL_DIR/start_i7_lmstudio_macos.sh" << 'EOF'
#!/bin/bash

# 🖥️ i7 LM Studio Startup Script (macOS)
# Optimized for Intel CPU inference on macOS

# macOS CPU optimizations
export OMP_NUM_THREADS=$(sysctl -n hw.ncpu)
export VECLIB_MAXIMUM_THREADS=$(sysctl -n hw.ncpu)

# Memory optimizations for macOS
export MALLOC_ARENA_MAX=2

INSTALL_DIR="$HOME/i7-lmstudio"
cd "$INSTALL_DIR"

echo "🖥️ Starting i7 LM Studio with macOS CPU optimizations..."
echo "🧠 Using $(sysctl -n hw.ncpu) CPU threads"
echo "🔧 Port: 1235 (i7-specific)"
echo "📍 Node: i7 CPU Inference (macOS)"
echo "💻 System: $(sw_vers -productName) $(sw_vers -productVersion)"

# Check if LM Studio app exists
if [ -d "/Applications/LM Studio.app" ]; then
    echo "🚀 Starting LM Studio app..."
    open "/Applications/LM Studio.app"
    echo "📱 LM Studio GUI started - configure server on port 1235"
else
    echo "❌ LM Studio app not found in /Applications/"
    echo "📥 Please install LM Studio manually from the DMG file"
    echo "🔗 Or download from: https://lmstudio.ai"
fi

echo ""
echo "🔧 Manual Configuration Steps:"
echo "1. Open LM Studio"
echo "2. Go to Local Server tab"
echo "3. Set port to 1235"
echo "4. Enable 'Serve on Local Network'"
echo "5. Start server"
echo ""
echo "🧪 Test server with:"
echo "curl http://localhost:1235/v1/models"
EOF

chmod +x "$INSTALL_DIR/start_i7_lmstudio_macos.sh"
log_success "macOS LM Studio wrapper script created"

# Step 7: Create test script
log_step "Step 7: Creating i7 LM Studio test script"
cat > "$INSTALL_DIR/test_i7_lmstudio.sh" << 'EOF'
#!/bin/bash

# 🧪 i7 LM Studio Test Script (macOS)

echo "🧪 Testing i7 LM Studio (macOS)..."
echo "📍 Node: $(hostname) ($(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1))"
echo "🔧 Port: 1235"
echo ""

# Test 1: Port availability
echo "🔍 Test 1: Port 1235 availability"
if lsof -i :1235 >/dev/null 2>&1; then
    echo "✅ Port 1235 is in use (LM Studio likely running)"
else
    echo "❌ Port 1235 is free (LM Studio not running)"
fi

# Test 2: API endpoint test
echo ""
echo "🔍 Test 2: LM Studio API test"
if curl -s --connect-timeout 5 http://localhost:1235/v1/models >/dev/null 2>&1; then
    echo "✅ LM Studio API responding"
    echo "📊 Models available:"
    curl -s http://localhost:1235/v1/models | python3 -m json.tool 2>/dev/null || echo "JSON parsing failed"
else
    echo "❌ LM Studio API not responding"
    echo "💡 Start LM Studio with: ./start_i7_lmstudio_macos.sh"
fi

# Test 3: Cross-node connectivity test
echo ""
echo "🔍 Test 3: Cross-node connectivity to RX Node"
RX_NODE_IP="192.168.68.117"
if ping -c 2 "$RX_NODE_IP" >/dev/null 2>&1; then
    echo "✅ RX Node ($RX_NODE_IP) reachable"
    
    # Test RX Node LM Studio
    if curl -s --connect-timeout 5 "http://$RX_NODE_IP:1234/v1/models" >/dev/null 2>&1; then
        echo "✅ RX Node LM Studio API responding on port 1234"
        echo "🔗 Cross-node LM Studio communication possible"
    else
        echo "❌ RX Node LM Studio API not responding"
    fi
else
    echo "❌ RX Node ($RX_NODE_IP) not reachable"
fi

echo ""
echo "🎯 i7 LM Studio Test completed"
EOF

chmod +x "$INSTALL_DIR/test_i7_lmstudio.sh"
log_success "i7 LM Studio test script created"

# Step 8: Create cross-node test script
log_step "Step 8: Creating Cross-Node LM Studio Test"
cat > "$INSTALL_DIR/cross_node_lm_test.sh" << 'EOF'
#!/bin/bash

# 🔗 Cross-Node LM Studio Test Script
# Tests communication between i7 Node (1235) and RX Node (1234)

echo "🔗 Cross-Node LM Studio Communication Test"
echo "=========================================="
echo "i7 Node (CPU): Port 1235"
echo "RX Node (GPU): Port 1234"
echo ""

# Configuration
I7_PORT="1235"
RX_NODE_IP="192.168.68.117"
RX_PORT="1234"
I7_IP=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1)

echo "📍 i7 Node: $I7_IP:$I7_PORT"
echo "📍 RX Node: $RX_NODE_IP:$RX_PORT"
echo ""

# Test 1: i7 Node LM Studio Status
echo "🖥️ Test 1: i7 Node LM Studio Status"
if curl -s --connect-timeout 5 "http://localhost:$I7_PORT/v1/models" >/dev/null 2>&1; then
    echo "✅ i7 LM Studio (CPU) responding on port $I7_PORT"
    I7_MODELS=$(curl -s "http://localhost:$I7_PORT/v1/models" | python3 -c "import sys,json; data=json.load(sys.stdin); print(len(data.get('data', [])))" 2>/dev/null || echo "0")
    echo "📊 i7 Models loaded: $I7_MODELS"
else
    echo "❌ i7 LM Studio (CPU) not responding"
fi

echo ""

# Test 2: RX Node LM Studio Status
echo "🎮 Test 2: RX Node LM Studio Status"
if curl -s --connect-timeout 5 "http://$RX_NODE_IP:$RX_PORT/v1/models" >/dev/null 2>&1; then
    echo "✅ RX LM Studio (GPU) responding on port $RX_PORT"
    RX_MODELS=$(curl -s "http://$RX_NODE_IP:$RX_PORT/v1/models" | python3 -c "import sys,json; data=json.load(sys.stdin); print(len(data.get('data', [])))" 2>/dev/null || echo "0")
    echo "📊 RX Models loaded: $RX_MODELS"
else
    echo "❌ RX LM Studio (GPU) not responding"
fi

echo ""

# Test 3: Performance Comparison Test
echo "⚡ Test 3: Performance Comparison (if both available)"
if curl -s --connect-timeout 5 "http://localhost:$I7_PORT/v1/models" >/dev/null 2>&1 && \
   curl -s --connect-timeout 5 "http://$RX_NODE_IP:$RX_PORT/v1/models" >/dev/null 2>&1; then
    
    echo "🧪 Running performance comparison test..."
    
    # Simple test prompt
    TEST_PROMPT="Hello, how are you?"
    
    echo "📝 Test prompt: '$TEST_PROMPT'"
    echo ""
    
    # Test i7 (CPU) performance
    echo "🖥️ Testing i7 Node (CPU) performance..."
    I7_START=$(date +%s.%N)
    I7_RESPONSE=$(curl -s --connect-timeout 30 -X POST "http://localhost:$I7_PORT/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"local\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEST_PROMPT\"}],\"max_tokens\":50}" 2>/dev/null || echo "ERROR")
    I7_END=$(date +%s.%N)
    I7_TIME=$(echo "$I7_END - $I7_START" | bc 2>/dev/null || echo "N/A")
    
    if [ "$I7_RESPONSE" != "ERROR" ]; then
        echo "✅ i7 Response time: ${I7_TIME}s"
    else
        echo "❌ i7 Test failed"
    fi
    
    echo ""
    
    # Test RX (GPU) performance
    echo "🎮 Testing RX Node (GPU) performance..."
    RX_START=$(date +%s.%N)
    RX_RESPONSE=$(curl -s --connect-timeout 30 -X POST "http://$RX_NODE_IP:$RX_PORT/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"local\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEST_PROMPT\"}],\"max_tokens\":50}" 2>/dev/null || echo "ERROR")
    RX_END=$(date +%s.%N)
    RX_TIME=$(echo "$RX_END - $RX_START" | bc 2>/dev/null || echo "N/A")
    
    if [ "$RX_RESPONSE" != "ERROR" ]; then
        echo "✅ RX Response time: ${RX_TIME}s"
    else
        echo "❌ RX Test failed"
    fi
    
    echo ""
    echo "📊 Performance Summary:"
    echo "   🖥️ i7 (CPU): ${I7_TIME}s"
    echo "   🎮 RX (GPU): ${RX_TIME}s"
    
else
    echo "⚠️ Both nodes must be running for performance comparison"
fi

echo ""
echo "🎯 Cross-Node Test completed"
echo ""
echo "💡 Usage:"
echo "   Start i7: ./start_i7_lmstudio_macos.sh"
echo "   Test i7:  ./test_i7_lmstudio.sh"
echo "   Cross-test: ./cross_node_lm_test.sh"
EOF

chmod +x "$INSTALL_DIR/cross_node_lm_test.sh"
log_success "Cross-node LM Studio test script created"

# Final summary
echo ""
log_success "i7 Node (macOS) LM Studio Setup completed!"
echo ""
echo -e "${GREEN}📊 Setup Summary:${NC}"
echo "   📁 Installation Directory: $INSTALL_DIR"
echo "   🔧 Port: $LM_STUDIO_PORT (i7-specific)"
echo "   🖥️ Platform: macOS optimized"
echo "   🧪 Test Scripts: Available"
echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "   1. Install LM Studio manually: open LMStudio-0.2.29.dmg"
echo "   2. Start LM Studio: ./start_i7_lmstudio_macos.sh"
echo "   3. Test i7 LM Studio: ./test_i7_lmstudio.sh"
echo "   4. Cross-node test: ./cross_node_lm_test.sh"
echo ""
echo -e "${YELLOW}💡 Manual Configuration:${NC}"
echo "   - Open LM Studio GUI"
echo "   - Configure Local Server on port 1235"
echo "   - Enable 'Serve on Local Network'"
echo "   - Load a model and start server"
echo ""
echo -e "${CYAN}🔗 Cross-Node Testing:${NC}"
echo "   - i7 Node (CPU): http://localhost:1235"
echo "   - RX Node (GPU): http://192.168.68.117:1234"
echo "   - Performance comparison available" 