# 🚀 GENTLEMAN RX Node Deployment

Automatisches Deployment-System für RX Node mit AMD GPU-Beschleunigung

## 🎯 Schnelle Installation

```bash
# 1. Repository klonen
git clone http://192.168.68.111:8080/rx-node-deployment.git
cd rx-node-deployment

# 2. Deployment starten
chmod +x quick_rx_deployment.sh
./quick_rx_deployment.sh
```

## 🎮 Was wird installiert:

- ✅ **AMD ROCm GPU-Treiber** für GPU-Beschleunigung
- ✅ **LM Studio v0.2.29** mit GPU-Support  
- ✅ **Firewall-Konfiguration** (Port 1234)
- ✅ **Systemd Auto-Start Service**
- ✅ **GPU-Test-Skripte**

## 🔊 Nach dem Deployment:

1. **LM Studio starten**: `./start_lm_studio.sh`
2. **Modell downloaden** (empfohlen: deepseek-r1-7b)
3. **Server aktivieren** auf Port 1234 mit GPU
4. **➡️ GPU-Lüfter werden hörbar sein! 🎮**

## 📋 Deployment-Optionen:

### Option 1: Vollständiges Deployment
```bash
./quick_rx_deployment.sh
```

### Option 2: Kompaktes Deployment  
```bash
./rx_deployment_direct.sh
```

### Option 3: Direkter Befehl
```bash
# Siehe rx_direct_deploy_command.txt
```

## 🌐 Server URLs nach Installation:

- **LM Studio API**: `http://192.168.68.117:1234`
- **Models Endpoint**: `http://192.168.68.117:1234/v1/models`
- **Chat Completions**: `http://192.168.68.117:1234/v1/chat/completions`

## 🧪 GPU-Test:

Nach der Installation:
```bash
python3 test_gpu_inference.py
```

Erwartete Ergebnisse:
- ⚡ Antwortzeit: <30 Sekunden
- 🚀 Token-Rate: >15 tokens/sec
- 🔊 **GPU-Lüfter hörbar während Inferenz**

---

**GENTLEMAN Dynamic Cluster System**  
RX Node (192.168.68.117) - AI Inference Engine 