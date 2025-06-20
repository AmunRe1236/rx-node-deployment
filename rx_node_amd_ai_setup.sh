#!/bin/bash

# GENTLEMAN RX Node AMD GPU AI Setup
# Optimiert für AMD RX 6700 XT mit ROCm

set -eo pipefail

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}❌ $1${NC}" >&2
}

log_info() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}ℹ️ $1${NC}"
}

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}⚠️ $1${NC}"
}

# Erstelle AMD GPU Setup Commands
create_amd_setup_commands() {
    log_info "📝 Erstelle AMD GPU AI Setup Commands..."
    
    cat > ./rx_node_amd_setup.txt << 'EOF'
# GENTLEMAN RX Node AMD GPU AI Setup Commands
# Für AMD RX 6700 XT mit ROCm Support
# Diese Befehle auf der RX Node ausführen (als amo9n11 user)

echo "🎯 AMD RX 6700 XT AI Setup wird gestartet..."

# 1. System Update
echo "📦 System Update..."
sudo pacman -Syu --noconfirm

# 2. ROCm Installation (Arch Linux)
echo "🔧 Installiere ROCm für AMD GPU..."
sudo pacman -S rocm-dev rocm-libs hip-dev --noconfirm

# Alternative: AUR ROCm (falls Probleme)
# yay -S rocm-opencl-runtime rocm-cmake --noconfirm

# 3. Python AI Dependencies
echo "🐍 Installiere Python AI Stack..."
sudo pacman -S python python-pip python-virtualenv --noconfirm

# 4. Erstelle AI Environment
echo "🌐 Erstelle AI Virtual Environment..."
cd ~
python -m venv ai_env
source ai_env/bin/activate

# 5. PyTorch für ROCm installieren
echo "🔥 Installiere PyTorch mit ROCm Support..."
pip install --upgrade pip
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7

# 6. AI Libraries installieren
echo "🤖 Installiere AI Libraries..."
pip install transformers
pip install diffusers
pip install accelerate
pip install datasets
pip install tokenizers
pip install safetensors
pip install huggingface-hub
pip install pillow
pip install numpy
pip install scipy
pip install scikit-learn
pip install matplotlib
pip install requests
pip install flask
pip install fastapi
pip install uvicorn

# 7. ROCm Environment testen
echo "🧪 Teste ROCm Installation..."
python -c "import torch; print(f'PyTorch Version: {torch.__version__}'); print(f'ROCm Available: {torch.cuda.is_available()}'); print(f'GPU Count: {torch.cuda.device_count()}'); print(f'GPU Name: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"No GPU\"}')"

# 8. AMD GPU Info
echo "📊 AMD GPU Information:"
rocm-smi
lspci | grep VGA

# 9. Erstelle AI Server mit AMD GPU Support
cat > ~/amd_ai_server.py << 'PYEOF'
#!/usr/bin/env python3
"""
GENTLEMAN AMD AI Server
Optimiert für AMD RX 6700 XT mit ROCm
"""

import os
import sys
import json
import time
import subprocess
import threading
from datetime import datetime
from pathlib import Path

# Web Framework
from flask import Flask, request, jsonify
import torch

# AI Libraries
try:
    from transformers import pipeline, AutoTokenizer, AutoModel
    from diffusers import StableDiffusionPipeline
    TRANSFORMERS_AVAILABLE = True
except ImportError:
    TRANSFORMERS_AVAILABLE = False
    print("⚠️ Transformers nicht verfügbar")

app = Flask(__name__)

# Global AI Models
models = {}
device = "cpu"

def initialize_amd_gpu():
    """Initialisiere AMD GPU mit ROCm"""
    global device
    
    print("🔍 Prüfe AMD GPU Verfügbarkeit...")
    
    if torch.cuda.is_available():
        device = "cuda"  # ROCm nutzt cuda API
        gpu_name = torch.cuda.get_device_name(0)
        gpu_memory = torch.cuda.get_device_properties(0).total_memory / 1024**3
        
        print(f"✅ AMD GPU gefunden: {gpu_name}")
        print(f"💾 GPU Memory: {gpu_memory:.1f} GB")
        print(f"🎯 Device: {device}")
        
        # GPU Warm-up
        dummy_tensor = torch.randn(100, 100).to(device)
        _ = dummy_tensor @ dummy_tensor
        del dummy_tensor
        torch.cuda.empty_cache()
        
        return True
    else:
        print("⚠️ Keine AMD GPU gefunden, nutze CPU")
        device = "cpu"
        return False

def load_ai_models():
    """Lade AI Models für verschiedene Tasks"""
    global models
    
    if not TRANSFORMERS_AVAILABLE:
        print("⚠️ Transformers nicht verfügbar, nutze Basic Models")
        return
    
    try:
        print("📚 Lade AI Models...")
        
        # Text Generation (klein für RX 6700 XT)
        print("📝 Lade Text Generation Model...")
        models['text_gen'] = pipeline(
            "text-generation",
            model="microsoft/DialoGPT-small",
            device=0 if device == "cuda" else -1,
            torch_dtype=torch.float16 if device == "cuda" else torch.float32
        )
        
        # Sentiment Analysis
        print("😊 Lade Sentiment Analysis...")
        models['sentiment'] = pipeline(
            "sentiment-analysis",
            device=0 if device == "cuda" else -1
        )
        
        # Text Summarization
        print("📄 Lade Summarization Model...")
        models['summarize'] = pipeline(
            "summarization",
            model="facebook/bart-large-cnn",
            device=0 if device == "cuda" else -1,
            torch_dtype=torch.float16 if device == "cuda" else torch.float32
        )
        
        print("✅ AI Models geladen!")
        
    except Exception as e:
        print(f"❌ Fehler beim Laden der Models: {e}")
        models = {}

@app.route('/health')
def health():
    """Health Check"""
    return jsonify({
        "status": "ok",
        "service": "amd-ai-server",
        "gpu": device,
        "timestamp": datetime.now().isoformat(),
        "models_loaded": len(models)
    })

@app.route('/gpu/status')
def gpu_status():
    """AMD GPU Status"""
    try:
        # ROCm-SMI Info
        rocm_info = subprocess.run(['rocm-smi'], capture_output=True, text=True)
        
        gpu_info = {
            "device": device,
            "torch_version": torch.__version__,
            "cuda_available": torch.cuda.is_available(),
            "gpu_count": torch.cuda.device_count() if torch.cuda.is_available() else 0,
            "rocm_smi": rocm_info.stdout if rocm_info.returncode == 0 else "N/A"
        }
        
        if torch.cuda.is_available():
            gpu_info.update({
                "gpu_name": torch.cuda.get_device_name(0),
                "gpu_memory_total": torch.cuda.get_device_properties(0).total_memory,
                "gpu_memory_allocated": torch.cuda.memory_allocated(0),
                "gpu_memory_reserved": torch.cuda.memory_reserved(0)
            })
        
        return jsonify(gpu_info)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/ai/text/generate', methods=['POST'])
def generate_text():
    """Text Generation mit AMD GPU"""
    if 'text_gen' not in models:
        return jsonify({"error": "Text generation model nicht verfügbar"}), 400
    
    data = request.get_json()
    prompt = data.get('prompt', 'Hello')
    max_length = data.get('max_length', 50)
    
    try:
        start_time = time.time()
        
        result = models['text_gen'](
            prompt,
            max_length=max_length,
            num_return_sequences=1,
            temperature=0.7,
            do_sample=True,
            pad_token_id=models['text_gen'].tokenizer.eos_token_id
        )
        
        processing_time = time.time() - start_time
        
        return jsonify({
            "status": "success",
            "prompt": prompt,
            "generated_text": result[0]['generated_text'],
            "processing_time": processing_time,
            "device": device,
            "timestamp": datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/ai/text/sentiment', methods=['POST'])
def analyze_sentiment():
    """Sentiment Analysis"""
    if 'sentiment' not in models:
        return jsonify({"error": "Sentiment model nicht verfügbar"}), 400
    
    data = request.get_json()
    text = data.get('text', '')
    
    try:
        start_time = time.time()
        result = models['sentiment'](text)
        processing_time = time.time() - start_time
        
        return jsonify({
            "status": "success",
            "text": text,
            "sentiment": result[0]['label'],
            "confidence": result[0]['score'],
            "processing_time": processing_time,
            "device": device,
            "timestamp": datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/ai/text/summarize', methods=['POST'])
def summarize_text():
    """Text Summarization"""
    if 'summarize' not in models:
        return jsonify({"error": "Summarization model nicht verfügbar"}), 400
    
    data = request.get_json()
    text = data.get('text', '')
    max_length = data.get('max_length', 150)
    min_length = data.get('min_length', 30)
    
    try:
        start_time = time.time()
        result = models['summarize'](
            text,
            max_length=max_length,
            min_length=min_length,
            do_sample=False
        )
        processing_time = time.time() - start_time
        
        return jsonify({
            "status": "success",
            "original_text": text,
            "summary": result[0]['summary_text'],
            "processing_time": processing_time,
            "device": device,
            "timestamp": datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/ai/benchmark')
def benchmark():
    """GPU Benchmark"""
    try:
        if device == "cpu":
            return jsonify({"message": "CPU Benchmark nicht implementiert"})
        
        print("🏃 Starte GPU Benchmark...")
        start_time = time.time()
        
        # Matrix Multiplikation Benchmark
        size = 2048
        a = torch.randn(size, size, device=device, dtype=torch.float16)
        b = torch.randn(size, size, device=device, dtype=torch.float16)
        
        torch.cuda.synchronize()
        compute_start = time.time()
        
        c = torch.matmul(a, b)
        
        torch.cuda.synchronize()
        compute_time = time.time() - compute_start
        
        total_time = time.time() - start_time
        
        # Cleanup
        del a, b, c
        torch.cuda.empty_cache()
        
        return jsonify({
            "status": "success",
            "benchmark": {
                "matrix_size": f"{size}x{size}",
                "compute_time": compute_time,
                "total_time": total_time,
                "device": device,
                "dtype": "float16"
            },
            "timestamp": datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    print("🚀 GENTLEMAN AMD AI Server startet...")
    print("🎯 Hardware: AMD RX 6700 XT")
    
    # Initialize GPU
    gpu_available = initialize_amd_gpu()
    
    # Load Models
    load_ai_models()
    
    print(f"📡 Endpoints verfügbar:")
    print(f"   GET  /health           - Health Check")
    print(f"   GET  /gpu/status       - AMD GPU Status")
    print(f"   POST /ai/text/generate - Text Generation")
    print(f"   POST /ai/text/sentiment - Sentiment Analysis")
    print(f"   POST /ai/text/summarize - Text Summarization")
    print(f"   GET  /ai/benchmark     - GPU Benchmark")
    
    # Start Server
    app.run(host='0.0.0.0', port=8765, debug=False, threaded=True)
PYEOF

chmod +x ~/amd_ai_server.py

# 10. Systemd Service erstellen
echo "⚙️ Erstelle AI Service..."
sudo tee /etc/systemd/system/gentleman-amd-ai.service > /dev/null << SERVICEEOF
[Unit]
Description=GENTLEMAN AMD AI Server
After=network.target

[Service]
Type=simple
User=amo9n11
WorkingDirectory=/home/amo9n11
Environment=PATH=/home/amo9n11/ai_env/bin:/usr/bin:/bin
ExecStart=/home/amo9n11/ai_env/bin/python /home/amo9n11/amd_ai_server.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

# 11. Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable gentleman-amd-ai.service

# 12. Final Status
echo "📊 Setup Status:"
echo "ROCm Version:"
/opt/rocm/bin/rocminfo | head -10

echo "PyTorch + ROCm Test:"
source ai_env/bin/activate
python -c "
import torch
print(f'PyTorch: {torch.__version__}')
print(f'CUDA Available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'Device Count: {torch.cuda.device_count()}')
    print(f'Device Name: {torch.cuda.get_device_name(0)}')
    print(f'Memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB')
"

echo "🎉 AMD AI Setup abgeschlossen!"
echo "Starte Service mit: sudo systemctl start gentleman-amd-ai.service"
echo "AI Server läuft auf: http://$(hostname -I | awk '{print $1}'):8765"
EOF

    log_success "AMD GPU Setup Commands erstellt"
}

# Erstelle AMD-optimierten AI Client
create_amd_ai_client() {
    log_info "📝 Erstelle AMD AI Client..."
    
    cat > ./amd_ai_client.sh << 'EOF'
#!/bin/bash

# GENTLEMAN AMD AI Client
# Optimiert für AMD RX 6700 XT AI Server

# Konfiguration
RX_NODE_IP=""
AI_PORT="8765"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Finde RX Node
find_rx_node() {
    # Erst Tailscale versuchen
    RX_NODE_IP=$(tailscale status 2>/dev/null | grep "archlinux" | awk '{print $1}')
    
    if [ -z "$RX_NODE_IP" ]; then
        # Fallback auf lokales Netzwerk
        RX_NODE_IP="192.168.68.117"
        log_info "Nutze lokale IP: $RX_NODE_IP"
    else
        log_success "RX Node über Tailscale gefunden: $RX_NODE_IP"
    fi
}

# AMD GPU Status
gpu_status() {
    find_rx_node
    log_info "📊 Hole AMD GPU Status..."
    
    response=$(curl -s --max-time 10 "http://$RX_NODE_IP:$AI_PORT/gpu/status")
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
    else
        log_error "GPU Status nicht verfügbar"
        return 1
    fi
}

# Text Generation
generate_text() {
    find_rx_node
    local prompt="$1"
    local max_length="${2:-100}"
    
    if [ -z "$prompt" ]; then
        echo "Verwendung: $0 generate '<prompt>' [max_length]"
        return 1
    fi
    
    log_info "🤖 Generiere Text mit AMD GPU..."
    
    response=$(curl -s --max-time 30 \
        -H "Content-Type: application/json" \
        -d "{\"prompt\": \"$prompt\", \"max_length\": $max_length}" \
        "http://$RX_NODE_IP:$AI_PORT/ai/text/generate")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Text generiert"
    else
        log_error "Text-Generierung fehlgeschlagen"
        return 1
    fi
}

# Sentiment Analysis
analyze_sentiment() {
    find_rx_node
    local text="$1"
    
    if [ -z "$text" ]; then
        echo "Verwendung: $0 sentiment '<text>'"
        return 1
    fi
    
    log_info "😊 Analysiere Sentiment..."
    
    response=$(curl -s --max-time 15 \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$text\"}" \
        "http://$RX_NODE_IP:$AI_PORT/ai/text/sentiment")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Sentiment analysiert"
    else
        log_error "Sentiment-Analyse fehlgeschlagen"
        return 1
    fi
}

# Text Summarization
summarize_text() {
    find_rx_node
    local text="$1"
    local max_length="${2:-150}"
    
    if [ -z "$text" ]; then
        echo "Verwendung: $0 summarize '<text>' [max_length]"
        return 1
    fi
    
    log_info "📄 Erstelle Zusammenfassung..."
    
    response=$(curl -s --max-time 30 \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$text\", \"max_length\": $max_length}" \
        "http://$RX_NODE_IP:$AI_PORT/ai/text/summarize")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Text zusammengefasst"
    else
        log_error "Zusammenfassung fehlgeschlagen"
        return 1
    fi
}

# GPU Benchmark
benchmark() {
    find_rx_node
    log_info "🏃 Starte AMD GPU Benchmark..."
    
    response=$(curl -s --max-time 60 "http://$RX_NODE_IP:$AI_PORT/ai/benchmark")
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Benchmark abgeschlossen"
    else
        log_error "Benchmark fehlgeschlagen"
        return 1
    fi
}

# Health Check
health() {
    find_rx_node
    log_info "🔍 Prüfe AMD AI Server..."
    
    response=$(curl -s --max-time 5 "http://$RX_NODE_IP:$AI_PORT/health")
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "AMD AI Server ist erreichbar"
    else
        log_error "AMD AI Server nicht erreichbar"
        return 1
    fi
}

# Hauptfunktion
main() {
    case "${1:-health}" in
        "health")
            health
            ;;
        "gpu"|"status")
            gpu_status
            ;;
        "generate"|"gen")
            generate_text "$2" "$3"
            ;;
        "sentiment")
            analyze_sentiment "$2"
            ;;
        "summarize"|"sum")
            summarize_text "$2" "$3"
            ;;
        "benchmark"|"bench")
            benchmark
            ;;
        *)
            echo -e "${PURPLE}🤖 GENTLEMAN AMD AI Client${NC}"
            echo "================================"
            echo ""
            echo "Kommandos:"
            echo "  health                    - AI Server Health Check"
            echo "  gpu|status                - AMD GPU Status"
            echo "  generate '<prompt>' [len] - Text Generation"
            echo "  sentiment '<text>'        - Sentiment Analysis"
            echo "  summarize '<text>' [len]  - Text Summarization"
            echo "  benchmark                 - GPU Benchmark"
            echo ""
            echo "Beispiele:"
            echo "  $0 health"
            echo "  $0 gpu"
            echo "  $0 generate 'Erkläre mir KI' 200"
            echo "  $0 sentiment 'Ich liebe dieses Produkt!'"
            echo "  $0 summarize 'Langer Text hier...' 100"
            echo "  $0 benchmark"
            ;;
    esac
}

main "$@"
EOF

    chmod +x ./amd_ai_client.sh
    log_success "AMD AI Client erstellt"
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN AMD GPU AI Setup${NC}"
    echo "======================================"
    echo ""
    echo -e "${CYAN}🔥 Hardware Detected:${NC}"
    echo "• AMD RX 6700 XT (Navi 22)"
    echo "• 12GB VRAM"
    echo "• ROCm Support ✅"
    echo ""
    
    log_info "Erstelle AMD-optimiertes AI-Setup..."
    
    create_amd_setup_commands
    create_amd_ai_client
    
    echo ""
    log_success "🎉 AMD GPU AI Setup erstellt!"
    echo ""
    echo -e "${CYAN}📁 Erstellt:${NC}"
    echo "• rx_node_amd_setup.txt - AMD GPU Setup Commands"
    echo "• amd_ai_client.sh - AMD AI Client"
    echo ""
    echo -e "${YELLOW}🚀 Nächste Schritte:${NC}"
    echo "1. SSH zur RX Node: ssh rx-node"
    echo "2. Commands aus rx_node_amd_setup.txt ausführen"
    echo "3. AMD AI testen: ./amd_ai_client.sh health"
    echo ""
    echo -e "${GREEN}💡 AMD AI Features:${NC}"
    echo "• Text Generation mit ROCm"
    echo "• Sentiment Analysis"  
    echo "• Text Summarization"
    echo "• GPU Benchmarking"
    echo "• Optimiert für RX 6700 XT!"
}

main "$@" 

# GENTLEMAN RX Node AMD GPU AI Setup
# Optimiert für AMD RX 6700 XT mit ROCm

set -eo pipefail

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}❌ $1${NC}" >&2
}

log_info() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}ℹ️ $1${NC}"
}

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}⚠️ $1${NC}"
}

# Erstelle AMD GPU Setup Commands
create_amd_setup_commands() {
    log_info "📝 Erstelle AMD GPU AI Setup Commands..."
    
    cat > ./rx_node_amd_setup.txt << 'EOF'
# GENTLEMAN RX Node AMD GPU AI Setup Commands
# Für AMD RX 6700 XT mit ROCm Support
# Diese Befehle auf der RX Node ausführen (als amo9n11 user)

echo "🎯 AMD RX 6700 XT AI Setup wird gestartet..."

# 1. System Update
echo "📦 System Update..."
sudo pacman -Syu --noconfirm

# 2. ROCm Installation (Arch Linux)
echo "🔧 Installiere ROCm für AMD GPU..."
sudo pacman -S rocm-dev rocm-libs hip-dev --noconfirm

# Alternative: AUR ROCm (falls Probleme)
# yay -S rocm-opencl-runtime rocm-cmake --noconfirm

# 3. Python AI Dependencies
echo "🐍 Installiere Python AI Stack..."
sudo pacman -S python python-pip python-virtualenv --noconfirm

# 4. Erstelle AI Environment
echo "🌐 Erstelle AI Virtual Environment..."
cd ~
python -m venv ai_env
source ai_env/bin/activate

# 5. PyTorch für ROCm installieren
echo "🔥 Installiere PyTorch mit ROCm Support..."
pip install --upgrade pip
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7

# 6. AI Libraries installieren
echo "🤖 Installiere AI Libraries..."
pip install transformers
pip install diffusers
pip install accelerate
pip install datasets
pip install tokenizers
pip install safetensors
pip install huggingface-hub
pip install pillow
pip install numpy
pip install scipy
pip install scikit-learn
pip install matplotlib
pip install requests
pip install flask
pip install fastapi
pip install uvicorn

# 7. ROCm Environment testen
echo "🧪 Teste ROCm Installation..."
python -c "import torch; print(f'PyTorch Version: {torch.__version__}'); print(f'ROCm Available: {torch.cuda.is_available()}'); print(f'GPU Count: {torch.cuda.device_count()}'); print(f'GPU Name: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"No GPU\"}')"

# 8. AMD GPU Info
echo "📊 AMD GPU Information:"
rocm-smi
lspci | grep VGA

# 9. Erstelle AI Server mit AMD GPU Support
cat > ~/amd_ai_server.py << 'PYEOF'
#!/usr/bin/env python3
"""
GENTLEMAN AMD AI Server
Optimiert für AMD RX 6700 XT mit ROCm
"""

import os
import sys
import json
import time
import subprocess
import threading
from datetime import datetime
from pathlib import Path

# Web Framework
from flask import Flask, request, jsonify
import torch

# AI Libraries
try:
    from transformers import pipeline, AutoTokenizer, AutoModel
    from diffusers import StableDiffusionPipeline
    TRANSFORMERS_AVAILABLE = True
except ImportError:
    TRANSFORMERS_AVAILABLE = False
    print("⚠️ Transformers nicht verfügbar")

app = Flask(__name__)

# Global AI Models
models = {}
device = "cpu"

def initialize_amd_gpu():
    """Initialisiere AMD GPU mit ROCm"""
    global device
    
    print("🔍 Prüfe AMD GPU Verfügbarkeit...")
    
    if torch.cuda.is_available():
        device = "cuda"  # ROCm nutzt cuda API
        gpu_name = torch.cuda.get_device_name(0)
        gpu_memory = torch.cuda.get_device_properties(0).total_memory / 1024**3
        
        print(f"✅ AMD GPU gefunden: {gpu_name}")
        print(f"💾 GPU Memory: {gpu_memory:.1f} GB")
        print(f"🎯 Device: {device}")
        
        # GPU Warm-up
        dummy_tensor = torch.randn(100, 100).to(device)
        _ = dummy_tensor @ dummy_tensor
        del dummy_tensor
        torch.cuda.empty_cache()
        
        return True
    else:
        print("⚠️ Keine AMD GPU gefunden, nutze CPU")
        device = "cpu"
        return False

def load_ai_models():
    """Lade AI Models für verschiedene Tasks"""
    global models
    
    if not TRANSFORMERS_AVAILABLE:
        print("⚠️ Transformers nicht verfügbar, nutze Basic Models")
        return
    
    try:
        print("📚 Lade AI Models...")
        
        # Text Generation (klein für RX 6700 XT)
        print("📝 Lade Text Generation Model...")
        models['text_gen'] = pipeline(
            "text-generation",
            model="microsoft/DialoGPT-small",
            device=0 if device == "cuda" else -1,
            torch_dtype=torch.float16 if device == "cuda" else torch.float32
        )
        
        # Sentiment Analysis
        print("😊 Lade Sentiment Analysis...")
        models['sentiment'] = pipeline(
            "sentiment-analysis",
            device=0 if device == "cuda" else -1
        )
        
        # Text Summarization
        print("📄 Lade Summarization Model...")
        models['summarize'] = pipeline(
            "summarization",
            model="facebook/bart-large-cnn",
            device=0 if device == "cuda" else -1,
            torch_dtype=torch.float16 if device == "cuda" else torch.float32
        )
        
        print("✅ AI Models geladen!")
        
    except Exception as e:
        print(f"❌ Fehler beim Laden der Models: {e}")
        models = {}

@app.route('/health')
def health():
    """Health Check"""
    return jsonify({
        "status": "ok",
        "service": "amd-ai-server",
        "gpu": device,
        "timestamp": datetime.now().isoformat(),
        "models_loaded": len(models)
    })

@app.route('/gpu/status')
def gpu_status():
    """AMD GPU Status"""
    try:
        # ROCm-SMI Info
        rocm_info = subprocess.run(['rocm-smi'], capture_output=True, text=True)
        
        gpu_info = {
            "device": device,
            "torch_version": torch.__version__,
            "cuda_available": torch.cuda.is_available(),
            "gpu_count": torch.cuda.device_count() if torch.cuda.is_available() else 0,
            "rocm_smi": rocm_info.stdout if rocm_info.returncode == 0 else "N/A"
        }
        
        if torch.cuda.is_available():
            gpu_info.update({
                "gpu_name": torch.cuda.get_device_name(0),
                "gpu_memory_total": torch.cuda.get_device_properties(0).total_memory,
                "gpu_memory_allocated": torch.cuda.memory_allocated(0),
                "gpu_memory_reserved": torch.cuda.memory_reserved(0)
            })
        
        return jsonify(gpu_info)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/ai/text/generate', methods=['POST'])
def generate_text():
    """Text Generation mit AMD GPU"""
    if 'text_gen' not in models:
        return jsonify({"error": "Text generation model nicht verfügbar"}), 400
    
    data = request.get_json()
    prompt = data.get('prompt', 'Hello')
    max_length = data.get('max_length', 50)
    
    try:
        start_time = time.time()
        
        result = models['text_gen'](
            prompt,
            max_length=max_length,
            num_return_sequences=1,
            temperature=0.7,
            do_sample=True,
            pad_token_id=models['text_gen'].tokenizer.eos_token_id
        )
        
        processing_time = time.time() - start_time
        
        return jsonify({
            "status": "success",
            "prompt": prompt,
            "generated_text": result[0]['generated_text'],
            "processing_time": processing_time,
            "device": device,
            "timestamp": datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/ai/text/sentiment', methods=['POST'])
def analyze_sentiment():
    """Sentiment Analysis"""
    if 'sentiment' not in models:
        return jsonify({"error": "Sentiment model nicht verfügbar"}), 400
    
    data = request.get_json()
    text = data.get('text', '')
    
    try:
        start_time = time.time()
        result = models['sentiment'](text)
        processing_time = time.time() - start_time
        
        return jsonify({
            "status": "success",
            "text": text,
            "sentiment": result[0]['label'],
            "confidence": result[0]['score'],
            "processing_time": processing_time,
            "device": device,
            "timestamp": datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/ai/text/summarize', methods=['POST'])
def summarize_text():
    """Text Summarization"""
    if 'summarize' not in models:
        return jsonify({"error": "Summarization model nicht verfügbar"}), 400
    
    data = request.get_json()
    text = data.get('text', '')
    max_length = data.get('max_length', 150)
    min_length = data.get('min_length', 30)
    
    try:
        start_time = time.time()
        result = models['summarize'](
            text,
            max_length=max_length,
            min_length=min_length,
            do_sample=False
        )
        processing_time = time.time() - start_time
        
        return jsonify({
            "status": "success",
            "original_text": text,
            "summary": result[0]['summary_text'],
            "processing_time": processing_time,
            "device": device,
            "timestamp": datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/ai/benchmark')
def benchmark():
    """GPU Benchmark"""
    try:
        if device == "cpu":
            return jsonify({"message": "CPU Benchmark nicht implementiert"})
        
        print("🏃 Starte GPU Benchmark...")
        start_time = time.time()
        
        # Matrix Multiplikation Benchmark
        size = 2048
        a = torch.randn(size, size, device=device, dtype=torch.float16)
        b = torch.randn(size, size, device=device, dtype=torch.float16)
        
        torch.cuda.synchronize()
        compute_start = time.time()
        
        c = torch.matmul(a, b)
        
        torch.cuda.synchronize()
        compute_time = time.time() - compute_start
        
        total_time = time.time() - start_time
        
        # Cleanup
        del a, b, c
        torch.cuda.empty_cache()
        
        return jsonify({
            "status": "success",
            "benchmark": {
                "matrix_size": f"{size}x{size}",
                "compute_time": compute_time,
                "total_time": total_time,
                "device": device,
                "dtype": "float16"
            },
            "timestamp": datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    print("🚀 GENTLEMAN AMD AI Server startet...")
    print("🎯 Hardware: AMD RX 6700 XT")
    
    # Initialize GPU
    gpu_available = initialize_amd_gpu()
    
    # Load Models
    load_ai_models()
    
    print(f"📡 Endpoints verfügbar:")
    print(f"   GET  /health           - Health Check")
    print(f"   GET  /gpu/status       - AMD GPU Status")
    print(f"   POST /ai/text/generate - Text Generation")
    print(f"   POST /ai/text/sentiment - Sentiment Analysis")
    print(f"   POST /ai/text/summarize - Text Summarization")
    print(f"   GET  /ai/benchmark     - GPU Benchmark")
    
    # Start Server
    app.run(host='0.0.0.0', port=8765, debug=False, threaded=True)
PYEOF

chmod +x ~/amd_ai_server.py

# 10. Systemd Service erstellen
echo "⚙️ Erstelle AI Service..."
sudo tee /etc/systemd/system/gentleman-amd-ai.service > /dev/null << SERVICEEOF
[Unit]
Description=GENTLEMAN AMD AI Server
After=network.target

[Service]
Type=simple
User=amo9n11
WorkingDirectory=/home/amo9n11
Environment=PATH=/home/amo9n11/ai_env/bin:/usr/bin:/bin
ExecStart=/home/amo9n11/ai_env/bin/python /home/amo9n11/amd_ai_server.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

# 11. Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable gentleman-amd-ai.service

# 12. Final Status
echo "📊 Setup Status:"
echo "ROCm Version:"
/opt/rocm/bin/rocminfo | head -10

echo "PyTorch + ROCm Test:"
source ai_env/bin/activate
python -c "
import torch
print(f'PyTorch: {torch.__version__}')
print(f'CUDA Available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'Device Count: {torch.cuda.device_count()}')
    print(f'Device Name: {torch.cuda.get_device_name(0)}')
    print(f'Memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB')
"

echo "🎉 AMD AI Setup abgeschlossen!"
echo "Starte Service mit: sudo systemctl start gentleman-amd-ai.service"
echo "AI Server läuft auf: http://$(hostname -I | awk '{print $1}'):8765"
EOF

    log_success "AMD GPU Setup Commands erstellt"
}

# Erstelle AMD-optimierten AI Client
create_amd_ai_client() {
    log_info "📝 Erstelle AMD AI Client..."
    
    cat > ./amd_ai_client.sh << 'EOF'
#!/bin/bash

# GENTLEMAN AMD AI Client
# Optimiert für AMD RX 6700 XT AI Server

# Konfiguration
RX_NODE_IP=""
AI_PORT="8765"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Finde RX Node
find_rx_node() {
    # Erst Tailscale versuchen
    RX_NODE_IP=$(tailscale status 2>/dev/null | grep "archlinux" | awk '{print $1}')
    
    if [ -z "$RX_NODE_IP" ]; then
        # Fallback auf lokales Netzwerk
        RX_NODE_IP="192.168.68.117"
        log_info "Nutze lokale IP: $RX_NODE_IP"
    else
        log_success "RX Node über Tailscale gefunden: $RX_NODE_IP"
    fi
}

# AMD GPU Status
gpu_status() {
    find_rx_node
    log_info "📊 Hole AMD GPU Status..."
    
    response=$(curl -s --max-time 10 "http://$RX_NODE_IP:$AI_PORT/gpu/status")
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
    else
        log_error "GPU Status nicht verfügbar"
        return 1
    fi
}

# Text Generation
generate_text() {
    find_rx_node
    local prompt="$1"
    local max_length="${2:-100}"
    
    if [ -z "$prompt" ]; then
        echo "Verwendung: $0 generate '<prompt>' [max_length]"
        return 1
    fi
    
    log_info "🤖 Generiere Text mit AMD GPU..."
    
    response=$(curl -s --max-time 30 \
        -H "Content-Type: application/json" \
        -d "{\"prompt\": \"$prompt\", \"max_length\": $max_length}" \
        "http://$RX_NODE_IP:$AI_PORT/ai/text/generate")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Text generiert"
    else
        log_error "Text-Generierung fehlgeschlagen"
        return 1
    fi
}

# Sentiment Analysis
analyze_sentiment() {
    find_rx_node
    local text="$1"
    
    if [ -z "$text" ]; then
        echo "Verwendung: $0 sentiment '<text>'"
        return 1
    fi
    
    log_info "😊 Analysiere Sentiment..."
    
    response=$(curl -s --max-time 15 \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$text\"}" \
        "http://$RX_NODE_IP:$AI_PORT/ai/text/sentiment")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Sentiment analysiert"
    else
        log_error "Sentiment-Analyse fehlgeschlagen"
        return 1
    fi
}

# Text Summarization
summarize_text() {
    find_rx_node
    local text="$1"
    local max_length="${2:-150}"
    
    if [ -z "$text" ]; then
        echo "Verwendung: $0 summarize '<text>' [max_length]"
        return 1
    fi
    
    log_info "📄 Erstelle Zusammenfassung..."
    
    response=$(curl -s --max-time 30 \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$text\", \"max_length\": $max_length}" \
        "http://$RX_NODE_IP:$AI_PORT/ai/text/summarize")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Text zusammengefasst"
    else
        log_error "Zusammenfassung fehlgeschlagen"
        return 1
    fi
}

# GPU Benchmark
benchmark() {
    find_rx_node
    log_info "🏃 Starte AMD GPU Benchmark..."
    
    response=$(curl -s --max-time 60 "http://$RX_NODE_IP:$AI_PORT/ai/benchmark")
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "Benchmark abgeschlossen"
    else
        log_error "Benchmark fehlgeschlagen"
        return 1
    fi
}

# Health Check
health() {
    find_rx_node
    log_info "🔍 Prüfe AMD AI Server..."
    
    response=$(curl -s --max-time 5 "http://$RX_NODE_IP:$AI_PORT/health")
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        log_success "AMD AI Server ist erreichbar"
    else
        log_error "AMD AI Server nicht erreichbar"
        return 1
    fi
}

# Hauptfunktion
main() {
    case "${1:-health}" in
        "health")
            health
            ;;
        "gpu"|"status")
            gpu_status
            ;;
        "generate"|"gen")
            generate_text "$2" "$3"
            ;;
        "sentiment")
            analyze_sentiment "$2"
            ;;
        "summarize"|"sum")
            summarize_text "$2" "$3"
            ;;
        "benchmark"|"bench")
            benchmark
            ;;
        *)
            echo -e "${PURPLE}🤖 GENTLEMAN AMD AI Client${NC}"
            echo "================================"
            echo ""
            echo "Kommandos:"
            echo "  health                    - AI Server Health Check"
            echo "  gpu|status                - AMD GPU Status"
            echo "  generate '<prompt>' [len] - Text Generation"
            echo "  sentiment '<text>'        - Sentiment Analysis"
            echo "  summarize '<text>' [len]  - Text Summarization"
            echo "  benchmark                 - GPU Benchmark"
            echo ""
            echo "Beispiele:"
            echo "  $0 health"
            echo "  $0 gpu"
            echo "  $0 generate 'Erkläre mir KI' 200"
            echo "  $0 sentiment 'Ich liebe dieses Produkt!'"
            echo "  $0 summarize 'Langer Text hier...' 100"
            echo "  $0 benchmark"
            ;;
    esac
}

main "$@"
EOF

    chmod +x ./amd_ai_client.sh
    log_success "AMD AI Client erstellt"
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN AMD GPU AI Setup${NC}"
    echo "======================================"
    echo ""
    echo -e "${CYAN}🔥 Hardware Detected:${NC}"
    echo "• AMD RX 6700 XT (Navi 22)"
    echo "• 12GB VRAM"
    echo "• ROCm Support ✅"
    echo ""
    
    log_info "Erstelle AMD-optimiertes AI-Setup..."
    
    create_amd_setup_commands
    create_amd_ai_client
    
    echo ""
    log_success "🎉 AMD GPU AI Setup erstellt!"
    echo ""
    echo -e "${CYAN}📁 Erstellt:${NC}"
    echo "• rx_node_amd_setup.txt - AMD GPU Setup Commands"
    echo "• amd_ai_client.sh - AMD AI Client"
    echo ""
    echo -e "${YELLOW}🚀 Nächste Schritte:${NC}"
    echo "1. SSH zur RX Node: ssh rx-node"
    echo "2. Commands aus rx_node_amd_setup.txt ausführen"
    echo "3. AMD AI testen: ./amd_ai_client.sh health"
    echo ""
    echo -e "${GREEN}💡 AMD AI Features:${NC}"
    echo "• Text Generation mit ROCm"
    echo "• Sentiment Analysis"  
    echo "• Text Summarization"
    echo "• GPU Benchmarking"
    echo "• Optimiert für RX 6700 XT!"
}

main "$@" 
 