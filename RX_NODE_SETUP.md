# 🎮 RX NODE - LLM POWERHOUSE SETUP
═══════════════════════════════════════════════════════════════

## 🎯 **Architektur-Übersicht**

### 🎮 **RX Node (AMD RX 6700 XT)** - LLM-Spezialist
```
┌─────────────────────────────────────────────────────────────┐
│                    🎮 RX NODE (192.168.100.10)             │
├─────────────────────────────────────────────────────────────┤
│  🧠 LLM-Server (8001)     - Hauptaufgabe: Große Modelle    │
│  🌐 Web-Interface (8080)  - Request Handler                │
│  🔗 Mesh-Coordinator (8004) - Nebula-Verbindung           │
│  📝 Log-Aggregator (8005) - Zentrale Logs                 │
│  📊 Prometheus (9090)     - Monitoring                     │
└─────────────────────────────────────────────────────────────┘
                              │
                         Nebula Mesh
                              │
┌─────────────────────────────────────────────────────────────┐
│                    🍎 M1 MAC (192.168.100.1)               │
├─────────────────────────────────────────────────────────────┤
│  🎤 STT-Service (8002)    - Whisper Speech-to-Text         │
│  🗣️ TTS-Service (8003)    - Text-to-Speech                 │
│  📡 Discovery Service     - Service Discovery              │
│  🏠 Nebula Lighthouse     - Mesh-Koordination              │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 **RX Node Services**

### 🧠 **LLM-Server (Port 8001)**
- **Zweck**: Hauptaufgabe - Verarbeitung großer Sprachmodelle
- **Hardware**: Optimiert für AMD RX 6700 XT
- **Modelle**: DialoGPT-large (erweiterbar)
- **API**: REST-API für Text-Generation

### 🌐 **Web-Interface (Port 8080)**
- **Zweck**: Request Handler und Benutzeroberfläche
- **Funktionen**: 
  - Empfängt Anfragen
  - Koordiniert mit M1 Audio-Services
  - Zeigt Systemstatus
- **Endpoints**: 
  - M1 STT: `http://192.168.100.1:8002`
  - M1 TTS: `http://192.168.100.1:8003`

### 🔗 **Mesh-Coordinator (Port 8004)**
- **Zweck**: Nebula-Mesh-Verbindung zum M1
- **Port**: 4243/UDP (RX Node)
- **Verbindung**: 192.168.100.1:4242 (M1 Lighthouse)

## 🔧 **Installation & Start**

### 1. **System vorbereiten**
```bash
cd /home/amo9n11/Documents/Archives/gentleman
```

### 2. **Services starten**
```bash
# Alle RX Node Services starten
docker-compose up -d

# Status überprüfen
docker-compose ps
```

### 3. **Discovery Service starten**
```bash
# Discovery Service auf Port 8007
python3 discovery_service.py &
```

## 📊 **Service-Status überprüfen**

### **Health Checks**
```bash
# LLM-Server
curl http://localhost:8001/health

# Web-Interface
curl http://localhost:8080/health

# Log-Aggregator
curl http://localhost:8005/health

# Prometheus
curl http://localhost:9090/-/healthy

# Discovery Service
curl http://localhost:8007/health
```

### **Docker Status**
```bash
docker-compose ps --format table
```

## 🌐 **Nebula Mesh Verbindung**

### **RX Node Konfiguration**
- **IP**: 192.168.100.10
- **Port**: 4243/UDP
- **Lighthouse**: 192.168.100.1:4242
- **Interface**: nebula1

### **Verbindung testen**
```bash
# Nebula Status
sudo nebula-cert print -path nebula/rx.crt

# Ping M1 über Mesh
ping 192.168.100.1

# Mesh Interface prüfen
ip addr show nebula1
```

## 🔄 **Workflow: Audio-Request-Verarbeitung**

```
1. 🎤 Audio → M1 STT Service (192.168.100.1:8002)
2. 📝 Text → RX Node LLM Server (192.168.100.10:8001)
3. 🧠 Processing → AMD RX 6700 XT
4. 📤 Response → M1 TTS Service (192.168.100.1:8003)
5. 🔊 Audio Output
```

## 📈 **Monitoring & Logs**

### **Prometheus Metriken**
- URL: http://localhost:9090
- RX Node Metriken: GPU, CPU, Memory
- Service Health Status

### **Log-Aggregation**
- URL: http://localhost:8005
- Zentrale Sammlung aller Service-Logs
- System-Statistiken

### **Discovery Service**
- URL: http://localhost:8007
- Service-Discovery für M1
- Mesh-Status-Informationen

## 🛠️ **Troubleshooting**

### **LLM-Server lädt nicht**
```bash
# Logs überprüfen
docker logs gentleman-llm --tail 50

# GPU-Status prüfen
rocm-smi
```

### **Nebula-Verbindung fehlgeschlagen**
```bash
# Nebula-Logs
docker logs gentleman-mesh --tail 20

# Firewall prüfen
sudo ufw status
```

### **Services nicht erreichbar**
```bash
# Port-Status
netstat -tulpn | grep -E "(8001|8080|8004|8005|9090)"

# Docker-Netzwerk
docker network ls
docker network inspect gentleman_gentleman-mesh
```

## 🎯 **Optimierungen**

### **GPU-Performance**
- ROCm 5.7 optimiert
- FP16 Precision aktiviert
- Memory-efficient Attention

### **Netzwerk-Performance**
- Docker Bridge Network
- Nebula Mesh für sichere Kommunikation
- Load Balancing zwischen Services

### **Monitoring**
- Prometheus Metriken
- Health Checks alle 30s
- Automatische Service-Recovery

---

## 📋 **Aktuelle Service-Ports**

| Service | Port | Zweck |
|---------|------|-------|
| LLM-Server | 8001 | Hauptaufgabe: Text-Generation |
| Web-Interface | 8080 | Request Handler |
| Mesh-Coordinator | 8004 | Nebula-Verbindung |
| Log-Aggregator | 8005 | Zentrale Logs |
| Discovery Service | 8007 | Service-Discovery |
| Prometheus | 9090 | Monitoring |
| Alertmanager | 9093 | Benachrichtigungen |
| Nebula | 4243/UDP | Mesh-Netzwerk |

**Status**: ✅ RX Node als LLM-Powerhouse konfiguriert und bereit für M1-Verbindung! 