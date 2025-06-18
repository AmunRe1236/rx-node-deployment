#!/bin/bash

# 🖥️ GENTLEMAN i7 Node Deployment Script
# Intel CPU optimized deployment for LM Studio
# Target: i7 Node (192.168.68.XXX) - CPU-based AI inference
# Usage: ./i7_node_deployment.sh

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
║  🖥️ GENTLEMAN i7 NODE DEPLOYMENT                             ║
║  Intel CPU Optimized LM Studio Installation                 ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Configuration
I7_NODE_IP="192.168.68.XXX"  # To be configured for actual i7 node
LM_STUDIO_VERSION="0.2.29"
LM_STUDIO_PORT="1235"  # Different port to avoid conflicts with RX node
INSTALL_DIR="$HOME/i7-lmstudio"
SERVICE_NAME="i7-lmstudio"

echo -e "${BLUE}🚀 Starting i7 Node Deployment...${NC}"
echo -e "${YELLOW}📍 Target Node: i7 CPU-based inference${NC}"
echo -e "${YELLOW}📅 Date: $(date)${NC}"
echo -e "${YELLOW}🔧 Port: $LM_STUDIO_PORT (i7-specific)${NC}"
echo

# Function to log steps
log_step() {
    echo -e "${CYAN}🔹 $1${NC}"
}

# Function to log success
log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to log warning
log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to log error
log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Step 1: System Information and Validation
log_step "Step 1: System Information & Validation"
echo "🖥️  Hostname: $(hostname)"
echo "🌐 IP Address: $(hostname -I | awk '{print $1}')"
echo "💻 OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "$(uname -s) $(uname -r)")"
echo "🧠 CPU Info: $(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)"
echo "🧠 CPU Cores: $(nproc) cores"
echo "💾 RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo "💿 Disk Space: $(df -h / | awk 'NR==2 {print $4}') available"

# Verify this is not the RX node
CURRENT_IP=$(hostname -I | awk '{print $1}')
if [ "$CURRENT_IP" = "192.168.68.117" ]; then
    log_error "This appears to be the RX Node (192.168.68.117)!"
    log_error "This script is for i7 nodes only. Use quick_rx_deployment.sh for RX node."
    exit 1
fi

log_success "System validation completed - Confirmed i7 node"

# Step 2: CPU Optimization Check
log_step "Step 2: CPU Optimization Setup"

# Check for Intel CPU
if lscpu | grep -qi "intel"; then
    log_success "Intel CPU detected - optimizations will be applied"
    CPU_VENDOR="intel"
else
    log_warning "Non-Intel CPU detected - generic optimizations will be used"
    CPU_VENDOR="generic"
fi

# Check CPU features for AI workloads
echo "🔍 Checking CPU features for AI optimization:"
CPU_FEATURES=""
if grep -q "avx2" /proc/cpuinfo; then
    echo "  ✅ AVX2 support detected"
    CPU_FEATURES="$CPU_FEATURES avx2"
fi
if grep -q "avx512" /proc/cpuinfo; then
    echo "  ✅ AVX-512 support detected"
    CPU_FEATURES="$CPU_FEATURES avx512"
fi
if grep -q "fma" /proc/cpuinfo; then
    echo "  ✅ FMA support detected"
    CPU_FEATURES="$CPU_FEATURES fma"
fi

if [ -n "$CPU_FEATURES" ]; then
    log_success "CPU features for AI acceleration: $CPU_FEATURES"
else
    log_warning "Limited CPU AI acceleration features detected"
fi

# Step 3: System Updates
log_step "Step 3: System Updates"
sudo apt update && sudo apt upgrade -y
log_success "System updated"

# Step 4: Install Dependencies
log_step "Step 4: Installing Dependencies"
sudo apt install -y \
    curl \
    wget \
    unzip \
    htop \
    neofetch \
    git \
    build-essential \
    cmake \
    python3 \
    python3-pip \
    libomp-dev \
    intel-mkl-full \
    libopenblas-dev \
    liblapack-dev

# Install Intel MKL for CPU optimization (if available)
if [ "$CPU_VENDOR" = "intel" ]; then
    log_step "Installing Intel MKL for CPU optimization"
    wget -qO - https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2023.PUB | sudo apt-key add -
    sudo sh -c 'echo deb https://apt.repos.intel.com/mkl all main > /etc/apt/sources.list.d/intel-mkl.list'
    sudo apt update
    sudo apt install -y intel-mkl-2020.0-088 || log_warning "Intel MKL installation failed - continuing with OpenBLAS"
fi

log_success "Dependencies installed"

# Step 5: Create Installation Directory
log_step "Step 5: Creating Installation Directory"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
log_success "Installation directory created: $INSTALL_DIR"

# Step 6: Download LM Studio
log_step "Step 6: Downloading LM Studio $LM_STUDIO_VERSION"
LM_STUDIO_URL="https://releases.lmstudio.ai/linux/x86/0.2.29/LM_Studio-0.2.29.AppImage"
wget -O "LM_Studio-${LM_STUDIO_VERSION}.AppImage" "$LM_STUDIO_URL"
chmod +x "LM_Studio-${LM_STUDIO_VERSION}.AppImage"
log_success "LM Studio downloaded and made executable"

# Step 7: Install FUSE for AppImage support
log_step "Step 7: Installing FUSE for AppImage support"
sudo apt install -y fuse libfuse2
log_success "FUSE installed"

# Step 8: Create LM Studio wrapper script
log_step "Step 8: Creating LM Studio wrapper script"
cat > "$INSTALL_DIR/start_i7_lmstudio.sh" << 'EOF'
#!/bin/bash

# 🖥️ i7 LM Studio Startup Script
# Optimized for Intel CPU inference

export OMP_NUM_THREADS=$(nproc)
export MKL_NUM_THREADS=$(nproc)
export OPENBLAS_NUM_THREADS=$(nproc)
export VECLIB_MAXIMUM_THREADS=$(nproc)

# Intel MKL optimizations (if available)
export MKL_ENABLE_INSTRUCTIONS=AVX2
export MKL_THREADING_LAYER=GNU

# CPU-specific optimizations
export MALLOC_ARENA_MAX=2
export MALLOC_MMAP_THRESHOLD_=131072
export MALLOC_TRIM_THRESHOLD_=131072
export MALLOC_TOP_PAD_=131072

INSTALL_DIR="$HOME/i7-lmstudio"
cd "$INSTALL_DIR"

echo "🖥️ Starting i7 LM Studio with CPU optimizations..."
echo "🧠 Using $(nproc) CPU threads"
echo "🔧 Port: 1235 (i7-specific)"
echo "📍 Node: i7 CPU Inference"

# Start LM Studio with CPU optimizations
./LM_Studio-0.2.29.AppImage --server --port 1235 --host 0.0.0.0 --cpu-threads $(nproc)
EOF

chmod +x "$INSTALL_DIR/start_i7_lmstudio.sh"
log_success "i7 LM Studio wrapper script created"

# Step 9: Create systemd service for i7 node
log_step "Step 9: Creating systemd service for i7 node"
sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" > /dev/null << EOF
[Unit]
Description=i7 LM Studio Server - CPU Optimized AI Inference
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/start_i7_lmstudio.sh
Restart=always
RestartSec=10
Environment=HOME=$HOME
Environment=OMP_NUM_THREADS=$(nproc)
Environment=MKL_NUM_THREADS=$(nproc)

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
log_success "i7 systemd service created and enabled"

# Step 10: Firewall Configuration
log_step "Step 10: Configuring Firewall for i7 node"
sudo ufw allow "$LM_STUDIO_PORT"/tcp comment "i7 LM Studio API"
sudo ufw reload
log_success "Firewall configured for port $LM_STUDIO_PORT"

# Step 11: Create CPU Performance Test Script
log_step "Step 11: Creating CPU Performance Test Script"
cat > "$INSTALL_DIR/test_i7_cpu_inference.py" << 'EOF'
#!/usr/bin/env python3

import requests
import time
import json
import psutil
import threading
from datetime import datetime

def monitor_cpu():
    """Monitor CPU usage during inference"""
    cpu_usage = []
    def collect_cpu():
        while getattr(collect_cpu, 'running', True):
            cpu_usage.append(psutil.cpu_percent(interval=1))
    
    thread = threading.Thread(target=collect_cpu)
    thread.start()
    return thread, cpu_usage

def test_i7_inference():
    """Test i7 CPU inference performance"""
    print("🖥️ i7 CPU Inference Performance Test")
    print("=" * 50)
    
    api_url = "http://localhost:1235/v1/chat/completions"
    
    # Test payload
    payload = {
        "model": "local-model",
        "messages": [
            {"role": "user", "content": "Explain quantum computing in 100 words."}
        ],
        "max_tokens": 150,
        "temperature": 0.1
    }
    
    print(f"🔍 Testing endpoint: {api_url}")
    print(f"📝 Test prompt: '{payload['messages'][0]['content']}'")
    print()
    
    # Start CPU monitoring
    monitor_thread, cpu_usage = monitor_cpu()
    
    # Perform inference test
    start_time = time.time()
    try:
        response = requests.post(api_url, json=payload, timeout=120)
        end_time = time.time()
        
        # Stop CPU monitoring
        monitor_cpu.running = False
        monitor_thread.join()
        
        duration = end_time - start_time
        
        if response.status_code == 200:
            result = response.json()
            content = result['choices'][0]['message']['content']
            
            print("✅ Inference Successful!")
            print(f"⏱️  Response Time: {duration:.2f} seconds")
            print(f"🧠 Average CPU Usage: {sum(cpu_usage)/len(cpu_usage):.1f}%")
            print(f"🔥 Peak CPU Usage: {max(cpu_usage):.1f}%")
            print(f"📊 CPU Cores Used: {psutil.cpu_count()}")
            print()
            print("💬 Response:")
            print(content)
            
            # Performance evaluation
            if duration < 60:
                print(f"\n🎯 Performance: GOOD (< 60s target for CPU)")
            elif duration < 120:
                print(f"\n⚠️  Performance: ACCEPTABLE (< 120s)")
            else:
                print(f"\n❌ Performance: SLOW (> 120s)")
                
        else:
            print(f"❌ API Error: {response.status_code}")
            print(response.text)
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection Error: {e}")
        print("💡 Make sure i7 LM Studio is running on port 1235")

if __name__ == "__main__":
    test_i7_inference()
EOF

chmod +x "$INSTALL_DIR/test_i7_cpu_inference.py"
log_success "i7 CPU performance test script created"

# Step 12: Create system info script
log_step "Step 12: Creating system info script"
cat > "$INSTALL_DIR/i7_system_info.sh" << 'EOF'
#!/bin/bash

echo "🖥️ i7 Node System Information"
echo "=" * 40
echo "📍 Hostname: $(hostname)"
echo "🌐 IP Address: $(hostname -I | awk '{print $1}')"
echo "💻 OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "$(uname -s) $(uname -r)")"
echo "🧠 CPU: $(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)"
echo "🔢 CPU Cores: $(nproc)"
echo "💾 RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo "💿 Disk: $(df -h / | awk 'NR==2 {print $4}') free"
echo "🌡️  Temperature:"
if command -v sensors >/dev/null 2>&1; then
    sensors | grep -E "(Core|Package)" | head -5
else
    echo "   lm-sensors not installed"
fi
echo "🔧 LM Studio Port: 1235"
echo "📊 Service Status:"
systemctl is-active i7-lmstudio || echo "   Service not running"
EOF

chmod +x "$INSTALL_DIR/i7_system_info.sh"
log_success "i7 system info script created"

# Step 13: Create quick start guide
log_step "Step 13: Creating quick start guide"
cat > "$INSTALL_DIR/README_i7.md" << 'EOF'
# 🖥️ i7 Node - CPU Optimized LM Studio

## Quick Start

### 1. Start LM Studio Server
```bash
cd ~/i7-lmstudio
./start_i7_lmstudio.sh
```

### 2. Check System Status
```bash
./i7_system_info.sh
```

### 3. Test CPU Inference Performance
```bash
python3 test_i7_cpu_inference.py
```

### 4. Access API
- **Base URL**: `http://localhost:1235`
- **Models**: `http://localhost:1235/v1/models`
- **Chat**: `http://localhost:1235/v1/chat/completions`

## Service Management

### Start/Stop Service
```bash
sudo systemctl start i7-lmstudio
sudo systemctl stop i7-lmstudio
sudo systemctl status i7-lmstudio
```

### View Logs
```bash
sudo journalctl -u i7-lmstudio -f
```

## Performance Notes

- **Target Response Time**: < 60 seconds (CPU inference)
- **Optimizations**: Intel MKL, OpenMP, CPU threading
- **Port**: 1235 (different from RX node port 1234)
- **CPU Usage**: Will utilize all available cores during inference

## Recommended Models for CPU

- **Small Models** (< 7B parameters): Best performance
- **Quantized Models**: Q4_K_M, Q5_K_M formats
- **Efficient Architectures**: Phi, TinyLlama, CodeLlama-7B

EOF

log_success "i7 quick start guide created"

# Final Summary
echo
echo -e "${PURPLE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║  🎉 i7 NODE DEPLOYMENT COMPLETE!                             ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}✅ Installation Summary:${NC}"
echo "🖥️  Node Type: i7 CPU-optimized"
echo "📍 Installation Directory: $INSTALL_DIR"
echo "🔧 Service Port: $LM_STUDIO_PORT (i7-specific)"
echo "🚀 Service Name: $SERVICE_NAME"
echo "🎯 Optimization: Intel CPU + MKL"

echo
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "1. Start LM Studio: cd $INSTALL_DIR && ./start_i7_lmstudio.sh"
echo "2. Download a CPU-optimized model (recommended: 7B or smaller)"
echo "3. Test performance: python3 $INSTALL_DIR/test_i7_cpu_inference.py"
echo "4. Check system info: $INSTALL_DIR/i7_system_info.sh"

echo
echo -e "${CYAN}📋 Service Management:${NC}"
echo "• Start service: sudo systemctl start $SERVICE_NAME"
echo "• Stop service: sudo systemctl stop $SERVICE_NAME"
echo "• View logs: sudo journalctl -u $SERVICE_NAME -f"

echo
echo -e "${YELLOW}⚠️  Important Notes:${NC}"
echo "• This is CPU-based inference (slower than GPU)"
echo "• Use smaller models (< 7B) for better performance"
echo "• Port $LM_STUDIO_PORT is different from RX node (1234)"
echo "• CPU will run at high utilization during inference"

echo
echo -e "${PURPLE}🏁 i7 Node Deployment Complete - $(date)${NC}"
log_success "i7 node is ready for CPU-based AI inference!" 