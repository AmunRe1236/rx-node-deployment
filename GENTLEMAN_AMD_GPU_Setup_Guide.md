# GENTLEMAN AMD GPU AI Setup Guide

## 🎯 Hardware Übersicht

**RX Node Spezifikationen:**
- **GPU**: AMD Radeon RX 6700 XT (Navi 22, 12GB VRAM)
- **CPU**: AMD Ryzen 5 1600 (6 Cores)
- **RAM**: 16GB DDR4
- **OS**: Arch Linux
- **User**: amo9n11

---

## 🔧 Voraussetzungen

### 1. Tailscale Setup abgeschlossen ✅
- RX Node in Tailscale Netzwerk integriert
- SSH Zugriff über Tailscale IP funktioniert
- Siehe: `GENTLEMAN_Tailscale_Setup_Guide.md`

### 2. SSH Verbindung zur RX Node
```bash
# Via lokales Netzwerk
ssh rx-node  # oder ssh amo9n11@192.168.68.117

# Via Tailscale (nach Setup)
ssh amo9n11@100.x.x.x  # RX Node Tailscale IP
```

---

## 🚀 AMD GPU Setup Schritte

### Schritt 1: System Update
```bash
# Arch Linux System Update
sudo pacman -Syu

# Kernel Headers installieren (falls nötig)
sudo pacman -S linux-headers
```

### Schritt 2: ROCm Installation
```bash
# ROCm Pakete installieren
sudo pacman -S rocm-dev rocm-libs hip-dev

# Alternative falls Probleme auftreten:
# yay -S rocm-opencl-runtime rocm-cmake

# ROCm Version prüfen
/opt/rocm/bin/rocminfo | head -10
```

### Schritt 3: GPU Status verifizieren
```bash
# AMD GPU Info
lspci | grep VGA
# Sollte zeigen: AMD/ATI Navi 22 [Radeon RX 6700/6700 XT]

# ROCm GPU Detection
rocm-smi

# Kernel Module prüfen
lsmod | grep amdgpu
```

### Schritt 4: Python AI Environment
```bash
# Python Dependencies
sudo pacman -S python python-pip python-virtualenv

# AI Virtual Environment erstellen
cd ~
python -m venv ai_env
source ai_env/bin/activate

# Environment aktivieren für zukünftige Sessions
echo "source ~/ai_env/bin/activate" >> ~/.bashrc
```

### Schritt 5: PyTorch mit ROCm
```bash
# Stelle sicher, dass ai_env aktiv ist
source ai_env/bin/activate

# Pip Update
pip install --upgrade pip

# PyTorch für ROCm 5.7 (kompatibel mit RX 6700 XT)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7

# PyTorch Installation testen
python -c "
import torch
print(f'PyTorch Version: {torch.__version__}')
print(f'CUDA Available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'Device Count: {torch.cuda.device_count()}')
    print(f'Device Name: {torch.cuda.get_device_name(0)}')
"
```

### Schritt 6: AI Libraries Installation
```bash
# Basis AI Libraries
pip install transformers
pip install diffusers
pip install accelerate
pip install datasets
pip install tokenizers
pip install safetensors
pip install huggingface-hub

# Zusätzliche Dependencies
pip install pillow numpy scipy scikit-learn matplotlib
pip install requests flask fastapi uvicorn

# Jupyter für Experimente (optional)
pip install jupyter notebook
```

---

## 🤖 AI Server Setup

### AMD AI Server erstellen
```bash
# AI Server Script erstellen
cat > ~/amd_ai_server.py << 'EOF'
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

# AI Libraries (mit Error Handling)
try:
    from transformers import pipeline, AutoTokenizer, AutoModel
    TRANSFORMERS_AVAILABLE = True
    print("✅ Transformers verfügbar")
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

if __name__ == "__main__":
    print("🚀 GENTLEMAN AMD AI Server startet...")
    print("🎯 Hardware: AMD RX 6700 XT")
    
    # Initialize GPU
    gpu_available = initialize_amd_gpu()
    
    print(f"📡 Endpoints verfügbar:")
    print(f"   GET  /health      - Health Check")
    print(f"   GET  /gpu/status  - AMD GPU Status")
    
    # Start Server
    app.run(host='0.0.0.0', port=8765, debug=False, threaded=True)
EOF

chmod +x ~/amd_ai_server.py
```

### Systemd Service erstellen
```bash
# Service File erstellen
sudo tee /etc/systemd/system/gentleman-amd-ai.service > /dev/null << 'EOF'
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
EOF

# Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable gentleman-amd-ai.service
```

---

## 🧪 Testing & Verification

### 1. Manual Testing
```bash
# AI Environment aktivieren
source ~/ai_env/bin/activate

# AI Server manuell starten (für Tests)
python ~/amd_ai_server.py

# In anderem Terminal:
curl http://localhost:8765/health
curl http://localhost:8765/gpu/status
```

### 2. Service Testing
```bash
# Service starten
sudo systemctl start gentleman-amd-ai.service

# Service Status prüfen
systemctl status gentleman-amd-ai.service

# Logs anzeigen
journalctl -u gentleman-amd-ai.service -f
```

### 3. Remote Testing (vom M1 Mac)
```bash
# RX Node Tailscale IP ermitteln
tailscale status | grep archlinux

# Health Check
curl http://100.x.x.x:8765/health

# GPU Status
curl http://100.x.x.x:8765/gpu/status
```

---

## 🔧 Troubleshooting

### Problem: ROCm nicht gefunden
```bash
# ROCm Installation prüfen
ls /opt/rocm/

# Environment Variables setzen
export PATH=/opt/rocm/bin:$PATH
export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH

# In ~/.bashrc hinzufügen für permanente Lösung
echo 'export PATH=/opt/rocm/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
```

### Problem: PyTorch erkennt GPU nicht
```bash
# ROCm Version prüfen
rocminfo | grep "Agent 2"

# PyTorch ROCm Kompatibilität testen
python -c "
import torch
print('ROCm verfügbar:', torch.cuda.is_available())
print('Geräte:', torch.cuda.device_count())
if torch.cuda.is_available():
    print('GPU Name:', torch.cuda.get_device_name(0))
"
```

### Problem: Service startet nicht
```bash
# Service Logs detailliert
journalctl -u gentleman-amd-ai.service --no-pager -l

# Manuelle Ausführung für Debugging
sudo -u amo9n11 /home/amo9n11/ai_env/bin/python /home/amo9n11/amd_ai_server.py

# Permissions prüfen
ls -la /home/amo9n11/amd_ai_server.py
ls -la /home/amo9n11/ai_env/
```

---

## 📊 Performance Monitoring

### GPU Monitoring Commands
```bash
# ROCm System Management Interface
rocm-smi

# Kontinuierliches Monitoring
watch -n 1 rocm-smi

# GPU Memory Usage
rocm-smi --showmeminfo

# GPU Temperature
rocm-smi --showtemp
```

### System Resources
```bash
# CPU Usage
htop

# Memory Usage
free -h

# Disk Usage
df -h

# Network Status
ss -tulpn | grep 8765
```

---

## 🚀 Erweiterte AI Features

### 1. Text Generation Models
```python
# Kleine Models für RX 6700 XT (12GB)
models = [
    "microsoft/DialoGPT-small",      # 117MB
    "gpt2",                          # 548MB
    "facebook/bart-large-cnn",       # 1.63GB
    "google/flan-t5-base",           # 990MB
]
```

### 2. Image Generation
```python
# Stable Diffusion für RX 6700 XT
from diffusers import StableDiffusionPipeline

pipe = StableDiffusionPipeline.from_pretrained(
    "runwayml/stable-diffusion-v1-5",
    torch_dtype=torch.float16
).to("cuda")
```

### 3. Model Optimization
```python
# Memory Optimization für 12GB VRAM
torch.backends.cuda.matmul.allow_tf32 = True
torch.backends.cudnn.allow_tf32 = True

# Model Quantization
model = model.half()  # FP16 für mehr Speed
```

---

## ✅ Setup Verification Checklist

### Hardware
- [ ] AMD RX 6700 XT erkannt (`lspci | grep VGA`)
- [ ] ROCm installiert (`rocm-smi` funktioniert)
- [ ] GPU Memory verfügbar (12GB)

### Software
- [ ] Python AI Environment aktiv
- [ ] PyTorch mit ROCm installiert
- [ ] PyTorch erkennt GPU (`torch.cuda.is_available()`)
- [ ] AI Libraries installiert

### Services
- [ ] AI Server startet manuell
- [ ] Systemd Service konfiguriert
- [ ] Service startet automatisch
- [ ] Health Check über Tailscale erreichbar

### Network
- [ ] AI Server auf Port 8765 erreichbar
- [ ] Tailscale Verbindung funktioniert
- [ ] Remote Access vom M1 Mac
- [ ] Firewall konfiguriert

**🎉 AMD GPU AI Setup abgeschlossen wenn alle Checkboxen ✅**

---

## 📚 Nützliche Ressourcen

- [ROCm Documentation](https://rocmdocs.amd.com/)
- [PyTorch ROCm Support](https://pytorch.org/get-started/locally/)
- [Hugging Face Transformers](https://huggingface.co/docs/transformers/)
- [AMD GPU Optimization Guide](https://github.com/RadeonOpenCompute/ROCm) 

## 🎯 Hardware Übersicht

**RX Node Spezifikationen:**
- **GPU**: AMD Radeon RX 6700 XT (Navi 22, 12GB VRAM)
- **CPU**: AMD Ryzen 5 1600 (6 Cores)
- **RAM**: 16GB DDR4
- **OS**: Arch Linux
- **User**: amo9n11

---

## 🔧 Voraussetzungen

### 1. Tailscale Setup abgeschlossen ✅
- RX Node in Tailscale Netzwerk integriert
- SSH Zugriff über Tailscale IP funktioniert
- Siehe: `GENTLEMAN_Tailscale_Setup_Guide.md`

### 2. SSH Verbindung zur RX Node
```bash
# Via lokales Netzwerk
ssh rx-node  # oder ssh amo9n11@192.168.68.117

# Via Tailscale (nach Setup)
ssh amo9n11@100.x.x.x  # RX Node Tailscale IP
```

---

## 🚀 AMD GPU Setup Schritte

### Schritt 1: System Update
```bash
# Arch Linux System Update
sudo pacman -Syu

# Kernel Headers installieren (falls nötig)
sudo pacman -S linux-headers
```

### Schritt 2: ROCm Installation
```bash
# ROCm Pakete installieren
sudo pacman -S rocm-dev rocm-libs hip-dev

# Alternative falls Probleme auftreten:
# yay -S rocm-opencl-runtime rocm-cmake

# ROCm Version prüfen
/opt/rocm/bin/rocminfo | head -10
```

### Schritt 3: GPU Status verifizieren
```bash
# AMD GPU Info
lspci | grep VGA
# Sollte zeigen: AMD/ATI Navi 22 [Radeon RX 6700/6700 XT]

# ROCm GPU Detection
rocm-smi

# Kernel Module prüfen
lsmod | grep amdgpu
```

### Schritt 4: Python AI Environment
```bash
# Python Dependencies
sudo pacman -S python python-pip python-virtualenv

# AI Virtual Environment erstellen
cd ~
python -m venv ai_env
source ai_env/bin/activate

# Environment aktivieren für zukünftige Sessions
echo "source ~/ai_env/bin/activate" >> ~/.bashrc
```

### Schritt 5: PyTorch mit ROCm
```bash
# Stelle sicher, dass ai_env aktiv ist
source ai_env/bin/activate

# Pip Update
pip install --upgrade pip

# PyTorch für ROCm 5.7 (kompatibel mit RX 6700 XT)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7

# PyTorch Installation testen
python -c "
import torch
print(f'PyTorch Version: {torch.__version__}')
print(f'CUDA Available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'Device Count: {torch.cuda.device_count()}')
    print(f'Device Name: {torch.cuda.get_device_name(0)}')
"
```

### Schritt 6: AI Libraries Installation
```bash
# Basis AI Libraries
pip install transformers
pip install diffusers
pip install accelerate
pip install datasets
pip install tokenizers
pip install safetensors
pip install huggingface-hub

# Zusätzliche Dependencies
pip install pillow numpy scipy scikit-learn matplotlib
pip install requests flask fastapi uvicorn

# Jupyter für Experimente (optional)
pip install jupyter notebook
```

---

## 🤖 AI Server Setup

### AMD AI Server erstellen
```bash
# AI Server Script erstellen
cat > ~/amd_ai_server.py << 'EOF'
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

# AI Libraries (mit Error Handling)
try:
    from transformers import pipeline, AutoTokenizer, AutoModel
    TRANSFORMERS_AVAILABLE = True
    print("✅ Transformers verfügbar")
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

if __name__ == "__main__":
    print("🚀 GENTLEMAN AMD AI Server startet...")
    print("🎯 Hardware: AMD RX 6700 XT")
    
    # Initialize GPU
    gpu_available = initialize_amd_gpu()
    
    print(f"📡 Endpoints verfügbar:")
    print(f"   GET  /health      - Health Check")
    print(f"   GET  /gpu/status  - AMD GPU Status")
    
    # Start Server
    app.run(host='0.0.0.0', port=8765, debug=False, threaded=True)
EOF

chmod +x ~/amd_ai_server.py
```

### Systemd Service erstellen
```bash
# Service File erstellen
sudo tee /etc/systemd/system/gentleman-amd-ai.service > /dev/null << 'EOF'
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
EOF

# Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable gentleman-amd-ai.service
```

---

## 🧪 Testing & Verification

### 1. Manual Testing
```bash
# AI Environment aktivieren
source ~/ai_env/bin/activate

# AI Server manuell starten (für Tests)
python ~/amd_ai_server.py

# In anderem Terminal:
curl http://localhost:8765/health
curl http://localhost:8765/gpu/status
```

### 2. Service Testing
```bash
# Service starten
sudo systemctl start gentleman-amd-ai.service

# Service Status prüfen
systemctl status gentleman-amd-ai.service

# Logs anzeigen
journalctl -u gentleman-amd-ai.service -f
```

### 3. Remote Testing (vom M1 Mac)
```bash
# RX Node Tailscale IP ermitteln
tailscale status | grep archlinux

# Health Check
curl http://100.x.x.x:8765/health

# GPU Status
curl http://100.x.x.x:8765/gpu/status
```

---

## 🔧 Troubleshooting

### Problem: ROCm nicht gefunden
```bash
# ROCm Installation prüfen
ls /opt/rocm/

# Environment Variables setzen
export PATH=/opt/rocm/bin:$PATH
export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH

# In ~/.bashrc hinzufügen für permanente Lösung
echo 'export PATH=/opt/rocm/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
```

### Problem: PyTorch erkennt GPU nicht
```bash
# ROCm Version prüfen
rocminfo | grep "Agent 2"

# PyTorch ROCm Kompatibilität testen
python -c "
import torch
print('ROCm verfügbar:', torch.cuda.is_available())
print('Geräte:', torch.cuda.device_count())
if torch.cuda.is_available():
    print('GPU Name:', torch.cuda.get_device_name(0))
"
```

### Problem: Service startet nicht
```bash
# Service Logs detailliert
journalctl -u gentleman-amd-ai.service --no-pager -l

# Manuelle Ausführung für Debugging
sudo -u amo9n11 /home/amo9n11/ai_env/bin/python /home/amo9n11/amd_ai_server.py

# Permissions prüfen
ls -la /home/amo9n11/amd_ai_server.py
ls -la /home/amo9n11/ai_env/
```

---

## 📊 Performance Monitoring

### GPU Monitoring Commands
```bash
# ROCm System Management Interface
rocm-smi

# Kontinuierliches Monitoring
watch -n 1 rocm-smi

# GPU Memory Usage
rocm-smi --showmeminfo

# GPU Temperature
rocm-smi --showtemp
```

### System Resources
```bash
# CPU Usage
htop

# Memory Usage
free -h

# Disk Usage
df -h

# Network Status
ss -tulpn | grep 8765
```

---

## 🚀 Erweiterte AI Features

### 1. Text Generation Models
```python
# Kleine Models für RX 6700 XT (12GB)
models = [
    "microsoft/DialoGPT-small",      # 117MB
    "gpt2",                          # 548MB
    "facebook/bart-large-cnn",       # 1.63GB
    "google/flan-t5-base",           # 990MB
]
```

### 2. Image Generation
```python
# Stable Diffusion für RX 6700 XT
from diffusers import StableDiffusionPipeline

pipe = StableDiffusionPipeline.from_pretrained(
    "runwayml/stable-diffusion-v1-5",
    torch_dtype=torch.float16
).to("cuda")
```

### 3. Model Optimization
```python
# Memory Optimization für 12GB VRAM
torch.backends.cuda.matmul.allow_tf32 = True
torch.backends.cudnn.allow_tf32 = True

# Model Quantization
model = model.half()  # FP16 für mehr Speed
```

---

## ✅ Setup Verification Checklist

### Hardware
- [ ] AMD RX 6700 XT erkannt (`lspci | grep VGA`)
- [ ] ROCm installiert (`rocm-smi` funktioniert)
- [ ] GPU Memory verfügbar (12GB)

### Software
- [ ] Python AI Environment aktiv
- [ ] PyTorch mit ROCm installiert
- [ ] PyTorch erkennt GPU (`torch.cuda.is_available()`)
- [ ] AI Libraries installiert

### Services
- [ ] AI Server startet manuell
- [ ] Systemd Service konfiguriert
- [ ] Service startet automatisch
- [ ] Health Check über Tailscale erreichbar

### Network
- [ ] AI Server auf Port 8765 erreichbar
- [ ] Tailscale Verbindung funktioniert
- [ ] Remote Access vom M1 Mac
- [ ] Firewall konfiguriert

**🎉 AMD GPU AI Setup abgeschlossen wenn alle Checkboxen ✅**

---

## 📚 Nützliche Ressourcen

- [ROCm Documentation](https://rocmdocs.amd.com/)
- [PyTorch ROCm Support](https://pytorch.org/get-started/locally/)
- [Hugging Face Transformers](https://huggingface.co/docs/transformers/)
- [AMD GPU Optimization Guide](https://github.com/RadeonOpenCompute/ROCm) 
 