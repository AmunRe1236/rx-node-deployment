# 🚀 **GENTLEMAN - Quick Start Guide**

> **🎩 Willkommen bei Gentleman!** Diese Anleitung bringt dich in wenigen Minuten zum Laufen.

---

## 📋 **Voraussetzungen**

### 🖥️ **Hardware Requirements**
- **RX PC**: AMD RX 6700 XT (oder kompatible GPU) für LLM-Server
- **M1 Mac**: Apple Silicon für STT/TTS Services
- **i7 MacBook**: Client-Gerät (optional)
- **Netzwerk**: Stabile Internetverbindung für Mesh-VPN

### 💻 **Software Requirements**
- **Docker** & **Docker Compose**
- **Python 3.9+**
- **Git**
- **Make** (für elegante Commands)

---

## ⚡ **One-Click Installation**

```bash
# 🎩 Gentleman herunterladen und installieren
curl -sSL https://raw.githubusercontent.com/user/gentleman/main/setup.sh | bash

# 📁 In Projekt-Verzeichnis wechseln
cd gentleman

# 🔧 Konfiguration anpassen (optional)
cp env.example .env
nano .env  # Anpassungen vornehmen
```

---

## 🚀 **Services Starten**

### 🎯 **Alle Services auf einmal**
```bash
# 🎩 Gentleman komplett starten
make gentleman-up

# 📊 Status prüfen
make gentleman-status

# 📝 Live Logs anzeigen
make gentleman-logs
```

### 🔧 **Einzelne Services**
```bash
# 🖥️ Nur LLM Server (RX PC)
docker-compose up -d llm-server

# 🎤 Nur STT Service (M1 Mac)
docker-compose up -d stt-service

# 🗣️ Nur TTS Service (M1 Mac)
docker-compose up -d tts-service

# 🌐 Nur Mesh Coordinator
docker-compose up -d mesh-coordinator
```

---

## 🌐 **Nebula Mesh Network Setup**

### 🏠 **Lighthouse (Zentraler Knoten)**
```bash
# 🔐 Zertifikate generieren
cd nebula/lighthouse
nebula-cert ca -name "Gentleman Mesh CA"

# 🌐 Lighthouse starten
nebula -config config.yml
```

### 🖥️ **RX Node (LLM Server)**
```bash
# 🔐 Node-Zertifikat erstellen
nebula-cert sign -name "rx-node" -ip "192.168.100.10/24"

# 🌐 Node verbinden
cd ../rx-node
nebula -config config.yml
```

### 🍎 **M1 Node (STT/TTS)**
```bash
# 🔐 Node-Zertifikat erstellen
nebula-cert sign -name "m1-node" -ip "192.168.100.20/24"

# 🌐 Node verbinden
cd ../m1-node
nebula -config config.yml
```

---

## 🧪 **Erste Tests**

### 🔍 **Health Checks**
```bash
# 🏥 Alle Services prüfen
make gentleman-health

# 🖥️ LLM Server testen
curl http://172.20.1.10:8000/health

# 🎤 STT Service testen
curl http://172.20.1.20:8000/health

# 🗣️ TTS Service testen
curl http://172.20.1.30:8000/health
```

### 🎯 **API Tests**
```bash
# 🧠 LLM Generation testen
curl -X POST http://172.20.1.10:8000/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hallo, wie geht es dir?", "max_tokens": 100}'

# 🎤 STT Test (mit Audio-Datei)
curl -X POST http://172.20.1.20:8000/transcribe \
  -F "audio=@test_audio.wav"

# 🗣️ TTS Test
curl -X POST http://172.20.1.30:8000/synthesize \
  -H "Content-Type: application/json" \
  -d '{"text": "Hallo, das ist ein Test!", "voice": "default"}'
```

---

## 🌐 **Web Interface**

### 📱 **Browser öffnen**
```bash
# 🌐 Web Interface starten
make gentleman-web

# 🔗 Im Browser öffnen
open http://localhost:8080
# oder
xdg-open http://localhost:8080
```

### 🎛️ **Dashboard Features**
- **🎤 Voice Input**: Spracheingabe direkt im Browser
- **🧠 AI Chat**: Interaktion mit LLM
- **🗣️ Voice Output**: Sprachausgabe mit Emotionen
- **📊 Monitoring**: Live-Status aller Services
- **⚙️ Settings**: Konfiguration anpassen

---

## 📊 **Monitoring & Observability**

### 📈 **Prometheus Metrics**
```bash
# 📊 Prometheus öffnen
open http://localhost:9090
```

### 📊 **Grafana Dashboards**
```bash
# 📊 Grafana öffnen
open http://localhost:3000

# 🔑 Login
# Username: gentleman
# Password: gentleman123
```

### 📝 **Log Aggregation**
```bash
# 📝 Logs in Echtzeit
make gentleman-logs

# 🔍 Spezifische Service Logs
docker-compose logs -f llm-server
docker-compose logs -f stt-service
docker-compose logs -f tts-service
```

---

## 🎯 **Typische Workflows**

### 🗣️ **Voice-to-Voice Pipeline**
1. **🎤 Audio aufnehmen** → STT Service (M1 Mac)
2. **📝 Text verarbeiten** → LLM Server (RX PC)
3. **🗣️ Antwort generieren** → TTS Service (M1 Mac)
4. **🔊 Audio ausgeben** → Client

### 💬 **Chat Interface**
1. **📱 Web Interface öffnen**
2. **💬 Text eingeben oder Sprache aufnehmen**
3. **🧠 AI-Antwort erhalten**
4. **🗣️ Antwort anhören**

### 📊 **System Monitoring**
1. **📈 Grafana Dashboard öffnen**
2. **📊 Metriken überwachen**
3. **🚨 Alerts konfigurieren**
4. **🔧 Performance optimieren**

---

## 🔧 **Troubleshooting**

### ❌ **Häufige Probleme**

#### 🐳 **Docker Issues**
```bash
# 🔄 Docker neu starten
sudo systemctl restart docker

# 🧹 Docker aufräumen
make gentleman-cleanup
```

#### 🌐 **Nebula Connection Issues**
```bash
# 🔍 Nebula Status prüfen
nebula -config nebula/rx-node/config.yml -test

# 🔄 Nebula neu starten
sudo systemctl restart nebula
```

#### 🖥️ **GPU Issues (RX 6700 XT)**
```bash
# 🔍 ROCm Status prüfen
rocm-smi

# 🔧 GPU Treiber neu laden
sudo modprobe -r amdgpu && sudo modprobe amdgpu
```

#### 🍎 **M1 Mac Issues**
```bash
# 🔍 MPS Status prüfen
python -c "import torch; print(torch.backends.mps.is_available())"

# 🔧 Rosetta für x86 Kompatibilität
arch -x86_64 /bin/bash
```

### 📞 **Support**
- **📚 Dokumentation**: `./docs/`
- **🐛 Issues**: GitHub Issues
- **💬 Community**: Discord Server
- **📧 Email**: support@gentleman-ai.com

---

## 🎯 **Nächste Schritte**

### 📖 **Weitere Dokumentation**
- **🏗️ [Architecture Guide](ARCHITECTURE.md)** - System-Architektur verstehen
- **🔧 [Configuration Guide](CONFIGURATION.md)** - Erweiterte Konfiguration
- **🌐 [Nebula Setup](NEBULA_SETUP.md)** - Mesh-VPN im Detail
- **🐳 [Docker Guide](DOCKER_GUIDE.md)** - Container-Deployment
- **📊 [Performance Guide](PERFORMANCE.md)** - Optimierung & Tuning

### 🚀 **Advanced Features**
- **🎭 Emotion Analysis** - Emotionale Sprachsynthese
- **🌍 Multi-Language** - Mehrsprachige Unterstützung
- **📱 Mobile Apps** - Native iOS/Android Clients
- **🔌 API Integration** - Eigene Anwendungen entwickeln
- **☁️ Cloud Deployment** - Skalierung in die Cloud

---

> **🎩 Herzlichen Glückwunsch!** Du hast Gentleman erfolgreich eingerichtet.  
> **🌟 Viel Spaß mit deiner eleganten, verteilten KI-Pipeline!**

---

**📅 Letzte Aktualisierung**: $(date)  
**📋 Version**: 1.0.0  
**🔄 Status**: Production Ready 