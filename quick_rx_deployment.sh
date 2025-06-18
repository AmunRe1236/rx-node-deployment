#!/bin/bash
# 🚀 GENTLEMAN RX Node Quick Deployment Script
# Automatische Installation von LM Studio mit AMD GPU-Beschleunigung
# Für RX Node (192.168.68.117)

set -e  # Exit on error

echo "🚀 GENTLEMAN RX Node Quick Deployment"
echo "====================================="
echo "🎯 Target: RX Node mit AMD GPU"
echo "📅 $(date)"
echo ""

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging Function
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️  $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"
}

# System Info
log "🔍 System Information"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Architecture: $(uname -m)"
echo ""

# GPU Detection
log "🎮 GPU Detection"
if command -v lspci &> /dev/null; then
    GPU_INFO=$(lspci | grep -i "vga\|3d\|display" || true)
    if [[ $GPU_INFO == *"AMD"* ]] || [[ $GPU_INFO == *"Radeon"* ]]; then
        log "✅ AMD GPU detected:"
        echo "$GPU_INFO"
        AMD_GPU=true
    elif [[ $GPU_INFO == *"NVIDIA"* ]]; then
        log "✅ NVIDIA GPU detected:"
        echo "$GPU_INFO"
        NVIDIA_GPU=true
    else
        warn "⚠️  No dedicated GPU detected or unknown GPU"
        echo "$GPU_INFO"
    fi
else
    warn "lspci not available - cannot detect GPU"
fi
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "❌ Bitte führe dieses Script NICHT als root aus!"
    exit 1
fi

# Create working directory
WORK_DIR="$HOME/gentleman_deployment"
log "📁 Creating work directory: $WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# System Update
log "🔄 System Update"
sudo apt update
sudo apt upgrade -y

# Install dependencies
log "📦 Installing dependencies"
sudo apt install -y \
    wget \
    curl \
    git \
    build-essential \
    python3 \
    python3-pip \
    htop \
    nvtop \
    ufw \
    fuse \
    libfuse2

# AMD ROCm Installation (if AMD GPU detected)
if [[ $AMD_GPU == true ]]; then
    log "🎮 Installing AMD ROCm for GPU acceleration"
    
    # Add ROCm repository
    wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -
    echo 'deb [arch=amd64] https://repo.radeon.com/rocm/apt/debian/ ubuntu main' | sudo tee /etc/apt/sources.list.d/rocm.list
    
    sudo apt update
    
    # Install ROCm
    sudo apt install -y rocm-dev rocm-libs rocm-utils
    
    # Add user to render group
    sudo usermod -a -G render,video $USER
    
    log "✅ ROCm installed. You may need to reboot for full GPU access."
    
    # Test ROCm installation
    if command -v rocm-smi &> /dev/null; then
        log "🧪 Testing ROCm installation"
        rocm-smi || warn "ROCm test failed - may need reboot"
    fi
fi

# Download LM Studio
log "🤖 Downloading LM Studio"
LM_STUDIO_VERSION="0.2.29"
LM_STUDIO_URL="https://releases.lmstudio.ai/linux/x86/${LM_STUDIO_VERSION}/LM_Studio-${LM_STUDIO_VERSION}.AppImage"

if [[ ! -f "LM_Studio-${LM_STUDIO_VERSION}.AppImage" ]]; then
    wget "$LM_STUDIO_URL" -O "LM_Studio-${LM_STUDIO_VERSION}.AppImage"
    chmod +x "LM_Studio-${LM_STUDIO_VERSION}.AppImage"
else
    log "✅ LM Studio already downloaded"
fi

# Create LM Studio launcher script
log "📝 Creating LM Studio launcher"
cat > lm_studio_launcher.sh << 'EOF'
#!/bin/bash
# LM Studio Launcher with GPU acceleration

export DISPLAY=:0
export ROCm_PATH=/opt/rocm
export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH

cd ~/gentleman_deployment

echo "🤖 Starting LM Studio with GPU acceleration..."
echo "📍 Working directory: $(pwd)"
echo "🎮 ROCm path: $ROCm_PATH"

# Start LM Studio
./LM_Studio-0.2.29.AppImage --no-sandbox
EOF

chmod +x lm_studio_launcher.sh

# Create server startup script
log "📝 Creating server startup script"
cat > start_lm_studio_server.sh << 'EOF'
#!/bin/bash
# LM Studio Server Startup Script

export DISPLAY=:0
export ROCm_PATH=/opt/rocm
export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH

cd ~/gentleman_deployment

echo "🌐 Starting LM Studio Server Mode..."
echo "📍 Port: 1234"
echo "🎮 GPU Acceleration: Enabled"

# Start LM Studio in server mode (headless)
./LM_Studio-0.2.29.AppImage --server --port 1234 --no-sandbox &

LM_PID=$!
echo "🚀 LM Studio Server started with PID: $LM_PID"
echo "🌐 Server URL: http://$(hostname -I | awk '{print $1}'):1234"

# Wait for server to start
sleep 10

# Test server
if curl -s http://localhost:1234/v1/models > /dev/null; then
    echo "✅ LM Studio Server is responding"
else
    echo "❌ LM Studio Server not responding"
fi

# Keep script running
wait $LM_PID
EOF

chmod +x start_lm_studio_server.sh

# Configure firewall
log "🔥 Configuring firewall"
sudo ufw allow 1234/tcp
sudo ufw --force enable

# Create systemd service for LM Studio
log "⚙️  Creating systemd service"
sudo tee /etc/systemd/system/lm-studio.service << EOF
[Unit]
Description=LM Studio Server
After=network.target

[Service]
Type=forking
User=$USER
WorkingDirectory=$WORK_DIR
Environment=DISPLAY=:0
Environment=ROCm_PATH=/opt/rocm
Environment=LD_LIBRARY_PATH=/opt/rocm/lib
ExecStart=$WORK_DIR/start_lm_studio_server.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable lm-studio

# Download recommended models
log "📥 Preparing model download instructions"
cat > download_models.md << 'EOF'
# 🤖 Empfohlene AI-Modelle für RX Node

## Schnelle Installation:
1. Starte LM Studio: `./lm_studio_launcher.sh`
2. Gehe zu "Discover" Tab
3. Suche und downloade eines dieser Modelle:

## Empfohlene Modelle (nach Performance):

### 🔥 Für AMD GPU (Beste Performance):
- **deepseek-r1-7b-gguf** (7GB) - Reasoning-optimiert
- **llama-3.2-3b-instruct-gguf** (2GB) - Schnell und effizient
- **qwen2.5-7b-instruct-gguf** (4GB) - Ausgewogen

### ⚡ Für schnelle Tests:
- **phi-3-mini-4k-instruct-gguf** (2GB) - Sehr schnell
- **gemma-2-2b-it-gguf** (1.5GB) - Minimal

## Nach dem Download:
1. Gehe zu "Local Server" Tab
2. Wähle das Modell aus
3. Aktiviere "GPU Acceleration" 
4. Setze Port auf 1234
5. Klicke "Start Server"

## GPU-Optimierung:
- Wähle höchste GPU Layers (meist alle)
- Aktiviere "Use GPU" in Settings
- Überwache GPU-Temperatur mit: `watch -n 1 rocm-smi`
EOF

# Create test script
log "🧪 Creating test script"
cat > test_gpu_inference.py << 'EOF'
#!/usr/bin/env python3
"""
🧪 GPU Inference Test für RX Node
"""

import requests
import json
import time
import sys

def test_lm_studio():
    base_url = "http://localhost:1234"
    
    print("🧪 Testing LM Studio GPU Inference")
    print("=" * 50)
    
    # Test 1: Models endpoint
    try:
        response = requests.get(f"{base_url}/v1/models", timeout=5)
        if response.status_code == 200:
            models = response.json()
            print(f"✅ Available models: {len(models.get('data', []))}")
            for model in models.get('data', []):
                print(f"   - {model.get('id', 'Unknown')}")
        else:
            print(f"❌ Models endpoint failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return False
    
    # Test 2: GPU Inference
    test_prompt = "Explain quantum computing in simple terms. Make this response detailed to test GPU performance."
    
    inference_data = {
        "model": "auto",
        "messages": [
            {"role": "system", "content": "You are a helpful AI assistant running on AMD GPU."},
            {"role": "user", "content": test_prompt}
        ],
        "temperature": 0.7,
        "max_tokens": 1024
    }
    
    print("\n🔥 Starting GPU inference test...")
    print("   (Listen for GPU fan noise!)")
    
    start_time = time.time()
    
    try:
        response = requests.post(
            f"{base_url}/v1/chat/completions",
            json=inference_data,
            timeout=120
        )
        
        end_time = time.time()
        response_time = end_time - start_time
        
        if response.status_code == 200:
            result = response.json()
            
            print(f"✅ GPU Inference successful!")
            print(f"   Response Time: {response_time:.2f}s")
            
            if 'choices' in result:
                content = result['choices'][0]['message']['content']
                print(f"   Response Length: {len(content)} characters")
                print(f"   Preview: {content[:150]}...")
                
                # Performance analysis
                if response_time < 30:
                    print("🚀 Fast response - GPU likely active!")
                else:
                    print("⚠️  Slow response - check GPU settings")
            
            if 'usage' in result:
                usage = result['usage']
                tokens_per_second = usage.get('completion_tokens', 0) / response_time
                print(f"   Tokens/second: {tokens_per_second:.1f}")
                
                if tokens_per_second > 15:
                    print("🎮 High token rate - GPU acceleration confirmed!")
                else:
                    print("💭 Low token rate - may be CPU-only")
            
            return True
        else:
            print(f"❌ Inference failed: {response.status_code}")
            print(f"   Error: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Inference error: {e}")
        return False

if __name__ == "__main__":
    if test_lm_studio():
        print("\n🎉 GPU test completed successfully!")
        print("🔊 If you heard GPU fans, acceleration is working!")
    else:
        print("\n❌ GPU test failed")
        sys.exit(1)
EOF

chmod +x test_gpu_inference.py

# Final instructions
log "🎯 Deployment completed!"
echo ""
echo "📋 NEXT STEPS:"
echo "=============="
echo ""
echo "1. 🤖 Start LM Studio GUI:"
echo "   ./lm_studio_launcher.sh"
echo ""
echo "2. 📥 Download a model (see download_models.md)"
echo ""
echo "3. 🌐 Start server mode:"
echo "   ./start_lm_studio_server.sh"
echo ""
echo "4. 🧪 Test GPU inference:"
echo "   python3 test_gpu_inference.py"
echo ""
echo "5. 🔊 Listen for GPU fan noise during inference!"
echo ""

if [[ $AMD_GPU == true ]]; then
    warn "⚠️  IMPORTANT: Reboot may be required for full ROCm GPU access:"
    echo "   sudo reboot"
    echo ""
fi

echo "📁 All files created in: $WORK_DIR"
echo "🌐 Expected server URL: http://$(hostname -I | awk '{print $1}'):1234"
echo ""
echo "🎮 To monitor GPU usage:"
echo "   watch -n 1 rocm-smi"
echo ""

log "✅ RX Node deployment complete!" 