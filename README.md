# 🚀 GENTLEMAN Dynamic Cluster Deployment

Automatisches Deployment-System für GENTLEMAN Cluster Nodes mit optimierter AI-Inferenz

## 🎯 Node-spezifische Installation

### 🎮 RX Node (GPU-beschleunigt)
```bash
# 1. Repository klonen
git clone https://github.com/AmunRe1236/rx-node-deployment.git
cd rx-node-deployment

# 2. RX Node Deployment starten
chmod +x quick_rx_deployment.sh
./quick_rx_deployment.sh
```

### 🖥️ i7 Node (CPU-optimiert)
```bash
# 1. Repository klonen (gleiche Quelle)
git clone https://github.com/AmunRe1236/rx-node-deployment.git
cd rx-node-deployment

# 2. i7 Node Deployment starten
chmod +x i7_node_deployment.sh
./i7_node_deployment.sh
```

## 🎮 RX Node - GPU-beschleunigt

### Was wird installiert:
- ✅ **AMD ROCm GPU-Treiber** für GPU-Beschleunigung
- ✅ **LM Studio v0.2.29** mit GPU-Support  
- ✅ **Firewall-Konfiguration** (Port 1234)
- ✅ **Systemd Auto-Start Service**
- ✅ **GPU-Test-Skripte**

### Nach dem Deployment:
1. **LM Studio starten**: `./start_lm_studio.sh`
2. **Modell downloaden** (empfohlen: deepseek-r1-7b)
3. **Server aktivieren** auf Port 1234 mit GPU
4. **➡️ GPU-Lüfter werden hörbar sein! 🎮**

## 🖥️ i7 Node - CPU-optimiert

### Was wird installiert:
- ✅ **Intel MKL** für CPU-Optimierung
- ✅ **OpenBLAS & OpenMP** für Multi-Threading
- ✅ **LM Studio v0.2.29** mit CPU-Optimierungen
- ✅ **Firewall-Konfiguration** (Port 1235)
- ✅ **Systemd Auto-Start Service**
- ✅ **CPU-Performance-Tests**

### Nach dem Deployment:
1. **LM Studio starten**: `cd ~/i7-lmstudio && ./start_i7_lmstudio.sh`
2. **Modell downloaden** (empfohlen: < 7B Parameter, quantisiert)
3. **Server aktivieren** auf Port 1235 mit CPU-Optimierung
4. **➡️ CPU wird bei Inferenz voll ausgelastet! 🧠**

## 📋 Deployment-Optionen:

### RX Node (GPU):
```bash
# Vollständiges GPU-Deployment
./quick_rx_deployment.sh

# Kompaktes GPU-Deployment  
./rx_deployment_direct.sh

# Direkter Befehl (siehe rx_direct_deploy_command.txt)
```

### i7 Node (CPU):
```bash
# Vollständiges CPU-Deployment
./i7_node_deployment.sh
```

## 🧪 Node-spezifische Testsuites:

### 🎮 RX Node Testsuite:
```bash
chmod +x test_rx_node.sh
./test_rx_node.sh
```

**RX Node Test-Bereiche:**
- 🖥️  **System Information** - Hardware & OS Details
- 🎮 **AMD GPU Detection** - GPU Hardware-Erkennung
- 🔧 **ROCm Installation** - GPU-Treiber & Tools
- 🤖 **LM Studio Installation** - Binary & Version Check
- 🌐 **Network Connectivity** - IP & Port Verfügbarkeit (1234)
- 🔗 **LM Studio API Test** - API Endpoint Verfügbarkeit
- ⚡ **GPU Inference Performance** - Echte AI-Inferenz mit Timing
- 📊 **System Resources** - CPU, RAM, GPU-Temperatur

### 🖥️ i7 Node Testsuite:
```bash
chmod +x test_i7_node.sh
./test_i7_node.sh
```

**i7 Node Test-Bereiche:**
- 📋 **System Information** - Hardware & Node-Validierung
- 🧠 **Intel CPU Detection** - CPU Features (AVX2, AVX-512, FMA)
- 🔧 **CPU Optimization Libraries** - Intel MKL, OpenBLAS, OpenMP
- 🤖 **i7 LM Studio Installation** - i7-spezifische Installation
- 🌐 **Network & Port Configuration** - Port 1235 & Konflikt-Check
- 🔗 **i7 LM Studio API Test** - i7-spezifische API Tests
- ⚡ **CPU Inference Performance** - CPU-Inferenz mit Monitoring
- 📊 **System Resources & Temperature** - CPU-Monitoring
- 🔧 **i7 Service Status** - Systemd Service Check

### Test-Ergebnisse:
- ✅ **RX Node Ziele**: <30s GPU-Inferenz, GPU-Beschleunigung aktiv
- ✅ **i7 Node Ziele**: <60s CPU-Inferenz, Intel-Optimierungen aktiv
- 📈 **Detaillierte Logs**: Vollständige Diagnose-Informationen

## 🌐 Server URLs nach Installation:

### 🎮 RX Node (GPU):
- **LM Studio API**: `http://192.168.68.117:1234`
- **Models Endpoint**: `http://192.168.68.117:1234/v1/models`
- **Chat Completions**: `http://192.168.68.117:1234/v1/chat/completions`

### 🖥️ i7 Node (CPU):
- **LM Studio API**: `http://[i7-node-ip]:1235`
- **Models Endpoint**: `http://[i7-node-ip]:1235/v1/models`
- **Chat Completions**: `http://[i7-node-ip]:1235/v1/chat/completions`

## 🧪 Legacy GPU-Test:

RX Node Python-Test (zusätzlich zur Testsuite):
```bash
python3 test_gpu_inference.py
```

## 📊 Performance-Vergleich:

| Node Type | Hardware | Port | Target Response | Modell-Empfehlung |
|-----------|----------|------|-----------------|-------------------|
| 🎮 **RX Node** | AMD GPU + ROCm | 1234 | < 30s | Alle Größen, GPU-optimiert |
| 🖥️ **i7 Node** | Intel CPU + MKL | 1235 | < 60s | < 7B Parameter, quantisiert |

## 🔧 Node-Erkennung:

Die Skripte erkennen automatisch den Node-Typ:
- **RX Node**: IP 192.168.68.117 → GPU-Deployment
- **i7 Node**: Andere IPs → CPU-Deployment
- **Schutz**: Verhindert versehentliche Fehl-Deployments

---

**GENTLEMAN Dynamic Cluster System**  
- 🎮 RX Node (192.168.68.117) - GPU AI Inference Engine  
- 🖥️ i7 Node(s) - CPU AI Inference Engines 