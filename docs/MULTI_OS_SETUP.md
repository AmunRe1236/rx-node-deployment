# 🌐 **GENTLEMAN - Multi-OS Setup Guide**
## **Arch Linux + macOS i7 + macOS M1 - Automatische Vernetzung**

---

## 🎯 **System-Übersicht**

```
🎩 GENTLEMAN MESH NETWORK
═══════════════════════════════════════════════════════════════

🖥️ Arch Linux (RX 6700 XT)     🌐 NEBULA MESH VPN     🍎 macOS i7
   ├─ LLM Server               ←→ Lighthouse Node ←→    ├─ Client
   ├─ IP: 192.168.100.10          IP: 192.168.100.1     ├─ IP: 192.168.100.30
   └─ Role: GPU Processing                               └─ Role: Mobile Client
                                        ↕
                               🍎 macOS M1 (Apple Silicon)
                                  ├─ STT Service
                                  ├─ TTS Service  
                                  ├─ IP: 192.168.100.20
                                  └─ Role: Audio Processing
```

---

## 🚀 **Installation pro System**

### 🖥️ **1. Arch Linux (RX 6700 XT) - LLM Server**

```bash
# 🎩 Gentleman herunterladen
git clone https://github.com/user/gentleman.git
cd gentleman

# 🔧 Arch-spezifische Dependencies
sudo pacman -S docker docker-compose make git curl python python-pip

# 🎮 ROCm für RX 6700 XT
sudo pacman -S rocm-opencl-runtime rocm-smi-lib

# 🚀 Installation
./setup.sh

# ⚙️ Konfiguration für Arch + RX 6700 XT
cp env.example .env
nano .env
```

**Arch-spezifische .env Anpassungen:**
```bash
# 🖥️ ARCH LINUX SETTINGS
GENTLEMAN_ENV=production
LLM_GPU_ENABLED=true
ROCM_VERSION=5.7
HSA_OVERRIDE_GFX_VERSION=10.3.0

# 🌐 NEBULA SETTINGS
NEBULA_NODE_TYPE=rx-node
NEBULA_NODE_IP=192.168.100.10
NEBULA_LIGHTHOUSE=192.168.100.1:4242
```

### 🍎 **2. macOS M1 - STT/TTS Services**

```bash
# 🎩 Gentleman herunterladen
git clone https://github.com/user/gentleman.git
cd gentleman

# 🔧 macOS Dependencies (via Homebrew)
brew install docker docker-compose make git curl python@3.11

# 🚀 Installation
./setup.sh

# ⚙️ Konfiguration für M1 Mac
cp env.example .env
nano .env
```

**M1-spezifische .env Anpassungen:**
```bash
# 🍎 M1 MAC SETTINGS
GENTLEMAN_ENV=production
PYTORCH_ENABLE_MPS_FALLBACK=1
PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0

# 🌐 NEBULA SETTINGS
NEBULA_NODE_TYPE=m1-node
NEBULA_NODE_IP=192.168.100.20
NEBULA_LIGHTHOUSE=192.168.100.1:4242

# 🎤 STT/TTS SERVICES
STT_DEVICE=mps  # Apple Silicon GPU
TTS_DEVICE=mps
```

### 💻 **3. macOS i7 - Client**

```bash
# 🎩 Gentleman herunterladen
git clone https://github.com/user/gentleman.git
cd gentleman

# 🔧 macOS Dependencies
brew install docker docker-compose make git curl python@3.11

# 🚀 Installation (Client-Modus)
./setup.sh --client-only

# ⚙️ Konfiguration für i7 MacBook
cp env.example .env
nano .env
```

**i7-spezifische .env Anpassungen:**
```bash
# 💻 i7 MACBOOK SETTINGS
GENTLEMAN_ENV=production
GENTLEMAN_MODE=client

# 🌐 NEBULA SETTINGS
NEBULA_NODE_TYPE=i7-node
NEBULA_NODE_IP=192.168.100.30
NEBULA_LIGHTHOUSE=192.168.100.1:4242

# 📱 CLIENT SETTINGS
WEB_INTERFACE_ENABLED=true
MOBILE_CLIENT_ENABLED=true
```

---

## 🔐 **Automatische Zertifikat-Verteilung**

### 🏠 **Lighthouse Setup (auf einem der Systeme)**

```bash
# 🔐 Zertifikate generieren (nur einmal!)
cd gentleman/nebula/lighthouse

# 🏛️ CA erstellen
nebula-cert ca -name "Gentleman Mesh CA"

# 🖥️ RX Node Zertifikat
nebula-cert sign -name "rx-node" -ip "192.168.100.10/24" -groups "llm-servers"

# 🍎 M1 Node Zertifikat  
nebula-cert sign -name "m1-node" -ip "192.168.100.20/24" -groups "audio-services"

# 💻 i7 Node Zertifikat
nebula-cert sign -name "i7-node" -ip "192.168.100.30/24" -groups "clients"

# 🏠 Lighthouse Zertifikat
nebula-cert sign -name "lighthouse" -ip "192.168.100.1/24" -groups "lighthouse"
```

### 📤 **Zertifikat-Verteilung**

```bash
# 🚀 Automatische Verteilung via Script
./scripts/setup/distribute_certificates.sh

# 📋 Oder manuell:
# Kopiere ca.crt zu allen Nodes
# Kopiere jeweilige .crt und .key zu entsprechenden Nodes
```

---

## 🌐 **Automatische Service Discovery**

### 🔍 **Wie erkennen sich die Services?**

1. **🏠 Lighthouse Node** (läuft auf einem der drei Systeme)
   - Zentrale Koordination
   - Service Registry
   - Automatische IP-Zuweisung

2. **📡 Service Announcement**
   ```bash
   # Jeder Service meldet sich automatisch an:
   # - Service-Typ (LLM, STT, TTS, Client)
   # - Verfügbare Endpoints
   # - Gesundheitsstatus
   # - Capabilities
   ```

3. **🔄 Health Monitoring**
   ```bash
   # Kontinuierliche Überwachung:
   # - Ping zwischen allen Nodes
   # - Service-Verfügbarkeit
   # - Performance-Metriken
   # - Automatisches Failover
   ```

### 🎯 **Service Discovery Beispiel**

```bash
# 🖥️ Arch Linux startet LLM Server
make gentleman-up-llm

# 🍎 M1 Mac startet STT/TTS
make gentleman-up-audio

# 💻 i7 MacBook startet Client
make gentleman-up-client

# 🌐 Automatische Erkennung erfolgt!
# Alle Services sehen sich gegenseitig
```

---

## 🚀 **Startup-Reihenfolge**

### 📋 **Empfohlene Reihenfolge:**

1. **🏠 Lighthouse starten** (auf beliebigem System)
   ```bash
   make gentleman-lighthouse
   ```

2. **🖥️ LLM Server starten** (Arch Linux)
   ```bash
   make gentleman-up-llm
   ```

3. **🍎 Audio Services starten** (M1 Mac)
   ```bash
   make gentleman-up-audio
   ```

4. **💻 Client starten** (i7 MacBook)
   ```bash
   make gentleman-up-client
   ```

### ⚡ **Oder alle gleichzeitig:**
```bash
# 🎩 Auf allen drei Systemen parallel:
make gentleman-up
```

---

## 🔧 **Automatische Konfiguration**

### 📡 **Service Discovery Config**

Jeder Node hat eine `service-discovery.yml`:

```yaml
# 🎩 Gentleman Service Discovery
discovery:
  lighthouse: "192.168.100.1:4242"
  announce_interval: 30s
  health_check_interval: 10s
  
services:
  llm-server:
    host: "192.168.100.10"
    port: 8000
    capabilities: ["text-generation", "gpu-acceleration"]
    
  stt-service:
    host: "192.168.100.20"
    port: 8001
    capabilities: ["speech-to-text", "german", "realtime"]
    
  tts-service:
    host: "192.168.100.20"
    port: 8002
    capabilities: ["text-to-speech", "emotion", "german"]
    
  web-client:
    host: "192.168.100.30"
    port: 8080
    capabilities: ["web-interface", "mobile-client"]
```

### 🔄 **Automatisches Load Balancing**

```bash
# 🎯 Intelligente Lastverteilung:
# - GPU-intensive Tasks → Arch Linux (RX 6700 XT)
# - Audio Processing → M1 Mac (Neural Engine)
# - User Interface → i7 MacBook (Mobility)
```

---

## 🧪 **Testing der Vernetzung**

### 🔍 **Connectivity Tests**

```bash
# 🌐 Nebula Mesh testen
make gentleman-test-mesh

# 🏥 Service Health Checks
make gentleman-health-all

# 📊 Performance Tests
make gentleman-benchmark-network
```

### 📋 **Erwartete Ausgabe:**
```bash
🎩 GENTLEMAN MESH STATUS
═══════════════════════════════════════════════════════════════
✅ Lighthouse: 192.168.100.1 (HEALTHY)
✅ RX Node:    192.168.100.10 (LLM Server READY)
✅ M1 Node:    192.168.100.20 (STT/TTS READY)  
✅ i7 Node:    192.168.100.30 (Client READY)

🌐 Network Latency:
   RX ↔ M1: 2ms
   RX ↔ i7: 3ms  
   M1 ↔ i7: 2ms

🚀 All services discovered and connected!
```

---

## 🎯 **Fazit**

### ✅ **Automatische Erkennung - JA!**
- **Keine manuelle Registrierung** erforderlich
- **Zero-Config** Service Discovery
- **Automatisches** Load Balancing
- **Self-Healing** Network

### 🎩 **Gentleman macht es elegant:**
1. **Ein Setup-Script** für alle drei Systeme
2. **Automatische Zertifikat-Verteilung**
3. **Intelligente Service-Erkennung**
4. **Nahtlose Kommunikation** zwischen allen Nodes

**🌟 Einfach `make gentleman-up` auf allen drei Systemen und alles funktioniert!**

---

**📅 Erstellt**: $(date)  
**🔄 Version**: 1.0.0  
**📋 Status**: Production Ready 