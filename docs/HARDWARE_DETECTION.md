# 🔍 **GENTLEMAN - Hardware Detection System**
## **Automatische Hardware-Erkennung und Node-Optimierung**

---

## 🎯 **Überblick**

Das GENTLEMAN Hardware Detection System erkennt automatisch die verfügbare Hardware und konfiguriert jeden Node optimal für seine spezifische Rolle im verteilten AI-System.

### ✨ **Features**

- **🔍 Automatische Erkennung**: CPU, GPU, RAM, Storage, Netzwerk
- **🎯 Intelligente Rollenzuweisung**: Basierend auf Hardware-Capabilities
- **⚡ Performance-Optimierung**: Hardware-spezifische Konfiguration
- **📊 Detaillierte Reports**: JSON-basierte Hardware-Berichte
- **🧪 Capability-Tests**: Validierung der erkannten Hardware

---

## 🚀 **Schnellstart**

### 🔍 **Hardware Detection ausführen**

```bash
# Vollständige Hardware-Erkennung
make detect-hardware

# Hardware-Konfiguration anzeigen
make hardware-config

# Hardware-Report anzeigen
make hardware-report

# Hardware-Tests durchführen
make hardware-test
```

### 🎯 **Automatisches Setup**

```bash
# Setup basierend auf erkannter Hardware
make setup-smart

# Services automatisch starten
make gentleman-up-auto
```

---

## 🔧 **Hardware-Erkennung im Detail**

### 🖥️ **System-Erkennung**

```bash
# Erkannte Informationen:
- Betriebssystem (Linux, macOS, Windows)
- Distribution (Arch, Ubuntu, macOS Version)
- Architektur (x86_64, arm64)
- Kernel-Version
- Hostname
```

**Beispiel-Output**:
```
✅ System: Linux arch  (x86_64)
```

### 🧠 **CPU-Erkennung**

```bash
# Erkannte CPU-Details:
- CPU-Modell und Hersteller
- Anzahl physische Kerne
- Anzahl logische Threads
- CPU-Flags und Features
- Apple Silicon Detection
```

**Beispiel-Output**:
```
✅ CPU: AMD Ryzen 5 1600 Six-Core Processor (12C/12T)
```

**Performance-Scoring**:
- **8+ Kerne**: 30 Punkte
- **4-7 Kerne**: 20 Punkte
- **<4 Kerne**: 10 Punkte
- **Apple Silicon Bonus**: +20 Punkte

### 🎮 **GPU-Erkennung**

#### **NVIDIA GPUs**
```bash
# Automatische Erkennung via nvidia-smi:
- GPU-Modell und Speicher
- CUDA-Treiber-Version
- GPU-Auslastung
- Multi-GPU Support
```

#### **AMD GPUs**
```bash
# Automatische Erkennung via rocm-smi:
- GPU-Modell (spezielle RX 6700 XT Erkennung)
- ROCm-Version
- GPU-Speicher und Status
- RDNA2-Architektur Support
```

**Beispiel-Output**:
```
🎮 AMD RX 6700 XT erkannt - Optimale LLM-Performance!
✅ GPU: 1 GPU(s) - AMD
```

#### **Apple Silicon GPUs**
```bash
# MPS (Metal Performance Shaders) Erkennung:
- Apple Silicon GPU verfügbar
- MPS Backend Support
- Unified Memory Architecture
```

**Performance-Scoring**:
- **NVIDIA GPU**: 50 Punkte
- **AMD RX 6700 XT**: 45 Punkte
- **Apple Silicon**: 40 Punkte
- **Andere AMD**: 35 Punkte

### 💾 **Memory-Erkennung**

```bash
# Arbeitsspeicher-Details:
- Gesamter verfügbarer RAM
- Verfügbarer RAM
- Memory-Performance-Tests
```

**Performance-Scoring**:
- **32GB+**: 30 Punkte
- **16-31GB**: 25 Punkte
- **8-15GB**: 20 Punkte
- **<8GB**: 10 Punkte

### 💿 **Storage-Erkennung**

```bash
# Speicher-Details:
- Storage-Typ (SSD vs HDD)
- Verfügbarer Speicherplatz
- Read/Write Performance
```

**Performance-Scoring**:
- **SSD (macOS)**: 25 Punkte
- **SSD (Linux)**: 20 Punkte
- **HDD**: 10 Punkte

---

## 🎯 **Automatische Rollenzuweisung**

### 🎮 **LLM Server**
**Optimale Hardware**:
- NVIDIA GPU oder AMD RX 6700 XT
- 16GB+ RAM
- Multi-Core CPU

**Services**:
- `llm-server`
- `monitoring`
- `matrix-updates`

**Beispiel-Konfiguration**:
```bash
GENTLEMAN_NODE_ROLE=llm-server
GENTLEMAN_GPU_ENABLED=true
RX6700XT_DETECTED=true
ROCM_VERSION=5.7
HSA_OVERRIDE_GFX_VERSION=10.3.0
```

### 🎤 **Audio Server**
**Optimale Hardware**:
- Apple Silicon (M1/M2/M3)
- MPS Support
- 8GB+ RAM

**Services**:
- `stt-service`
- `tts-service`
- `git-server`

**Beispiel-Konfiguration**:
```bash
GENTLEMAN_NODE_ROLE=audio-server
APPLE_SILICON=true
MPS_AVAILABLE=true
STT_DEVICE=mps
TTS_DEVICE=mps
```

### 📚 **Git Server**
**Optimale Hardware**:
- SSD Storage
- 8GB+ RAM
- Stabile Netzwerk-Verbindung

**Services**:
- `git-server`
- `web-interface`

### 💻 **Client**
**Fallback-Rolle**:
- Jede Hardware
- Minimale Anforderungen

**Services**:
- `web-interface`
- `monitoring`

---

## 📊 **Hardware-Reports**

### 📋 **JSON Hardware Report**

```json
{
  "detection_timestamp": "2025-06-15T13:10:57+02:00",
  "hostname": "archlinux",
  "system": {
    "os": "Linux",
    "distro": "arch",
    "architecture": "x86_64"
  },
  "cpu": {
    "model": "AMD Ryzen 5 1600 Six-Core Processor",
    "cores": 12,
    "threads": 12,
    "performance_score": 50
  },
  "gpu": {
    "count": 1,
    "vendors": "AMD",
    "rx6700xt": true,
    "rocm_version": "5.7"
  },
  "memory": {
    "total_gb": 15,
    "performance_score": 20
  },
  "node_capabilities": {
    "node_id": "llm-server-archlinux",
    "primary_role": "llm-server",
    "services": "llm-server,monitoring,matrix-updates",
    "total_score": 115,
    "gpu_acceleration": true
  }
}
```

### 📈 **Performance-Metriken**

```json
{
  "performance_metrics": {
    "cpu_test_time": "2.345",
    "gpu_memory_mb": "12288",
    "memory_test_time": "0.153",
    "storage_write_time": "0.234",
    "storage_read_time": "0.123",
    "network_test_time": "1.456"
  }
}
```

---

## 🧪 **Hardware-Tests**

### 🔍 **Capability-Tests**

```bash
# Vollständige Hardware-Tests
make hardware-test

# Spezifische Tests:
- CPU Performance (Pi-Berechnung)
- GPU Memory und Compute
- RAM Allocation Speed
- Storage Read/Write Speed
- Network Connectivity
- Node Role Validation
```

### 📊 **Test-Ergebnisse**

```bash
📊 Test-Zusammenfassung:
  Gesamt Tests: 11
  Erfolgreich: 7
  Fehlgeschlagen: 0
  Optimal: 1

⚡ Performance-Metriken:
  CPU Test: 2.345s
  MPS Test: 0.456s
  Storage Write: 0.234s

💡 Empfehlungen:
  ✅ Node Role: LLM Server - Optimal (GPU verfügbar)
  ⚠️  Storage-Performance ist langsam - erwäge SSD-Upgrade
```

---

## ⚙️ **Konfiguration und Anpassung**

### 🎯 **Manuelle Rollenzuweisung**

```bash
# Hardware-Detection überschreiben
export GENTLEMAN_NODE_ROLE=audio-server
export GENTLEMAN_GPU_ENABLED=false

# Spezifische GPU-Konfiguration
export RX6700XT_DETECTED=true
export ROCM_VERSION=5.7
export HSA_OVERRIDE_GFX_VERSION=10.3.0
```

### 📁 **Konfigurationsdateien**

```bash
# Hardware-Konfiguration
config/hardware/node_config.env

# Hardware-Reports
config/hardware/hardware_report_*.json
config/hardware/current_hardware.json

# Test-Reports
config/hardware/hardware_test_report_*.json
config/hardware/current_test_report.json
```

### 🔧 **Environment-Variablen**

```bash
# Node-Identität
GENTLEMAN_NODE_ID=llm-server-archlinux
GENTLEMAN_NODE_ROLE=llm-server
GENTLEMAN_HOSTNAME=archlinux

# Hardware-Flags
GENTLEMAN_GPU_ENABLED=true
APPLE_SILICON=false
RX6700XT_DETECTED=true
MPS_AVAILABLE=false

# Performance-Tuning
CPU_CORES=12
MEMORY_GB=15
DOCKER_MEMORY_LIMIT=7GB
PERFORMANCE_SCORE=115
```

---

## 🔧 **Troubleshooting**

### ❌ **Häufige Probleme**

#### **Hardware nicht erkannt**
```bash
# Problem: GPU nicht erkannt
# Lösung: Treiber installieren
sudo pacman -S rocm-opencl-runtime  # AMD
sudo pacman -S nvidia nvidia-utils  # NVIDIA

# Hardware-Detection erneut ausführen
make detect-hardware
```

#### **Falsche Rollenzuweisung**
```bash
# Problem: Node-Rolle ist suboptimal
# Lösung: Manuelle Konfiguration
export GENTLEMAN_NODE_ROLE=llm-server
make setup-auto
```

#### **Performance-Tests fehlgeschlagen**
```bash
# Problem: bc command not found
# Lösung: bc installieren
sudo pacman -S bc  # Arch Linux
sudo apt install bc  # Ubuntu

# Tests erneut ausführen
make hardware-test
```

### 🔍 **Debug-Informationen**

```bash
# Detaillierte Logs
tail -f logs/hardware_detection.log
tail -f logs/hardware_test.log

# Hardware-Status prüfen
lscpu                    # CPU Info
lspci | grep VGA         # GPU Info
free -h                  # Memory Info
df -h                    # Storage Info
ip addr show             # Network Info
```

### 🛠️ **Manuelle Hardware-Checks**

```bash
# NVIDIA GPU Check
nvidia-smi

# AMD GPU Check
rocm-smi

# Apple Silicon Check (macOS)
python3 -c "import torch; print(torch.backends.mps.is_available())"

# CPU Performance Check
nproc
cat /proc/cpuinfo | grep "model name" | head -1
```

---

## 🎯 **Best Practices**

### ✅ **Empfohlener Workflow**

1. **Hardware Detection ausführen**:
   ```bash
   make detect-hardware
   ```

2. **Konfiguration validieren**:
   ```bash
   make hardware-config
   make hardware-test
   ```

3. **Automatisches Setup**:
   ```bash
   make setup-smart
   ```

4. **Services starten**:
   ```bash
   make gentleman-up-auto
   ```

5. **Performance validieren**:
   ```bash
   make test-ai-pipeline
   ```

### 🔄 **Regelmäßige Updates**

```bash
# Hardware-Detection nach System-Updates
sudo pacman -Syu  # System Update
make detect-hardware  # Hardware neu erkennen
make hardware-test    # Tests durchführen
```

### 📊 **Monitoring**

```bash
# Hardware-Status überwachen
make hardware-report  # Aktueller Status
make hardware-test    # Performance-Tests

# Automatische Reports
crontab -e
# 0 6 * * * cd /path/to/gentleman && make hardware-test
```

---

## 🎉 **Fazit**

Das GENTLEMAN Hardware Detection System bietet:

✅ **Vollautomatische Erkennung** aller relevanten Hardware-Komponenten  
✅ **Intelligente Rollenzuweisung** basierend auf Hardware-Capabilities  
✅ **Performance-Optimierung** für jede Hardware-Konfiguration  
✅ **Umfassende Tests** zur Validierung der Hardware-Performance  
✅ **Detaillierte Reports** für Monitoring und Debugging  

**🎩 Deine Hardware wird automatisch erkannt und optimal konfiguriert!** 