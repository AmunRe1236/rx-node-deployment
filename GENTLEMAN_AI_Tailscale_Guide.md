# GENTLEMAN AI über Tailscale Setup

## 🎯 Übersicht
RX Node als AI-Server über Tailscale ohne Port-Forwarding nutzen.

## 🚀 Setup Schritte

### 1. RX Node Setup
```bash
# SSH zur RX Node
ssh rx-node

# Setup Commands ausführen (aus rx_node_manual_setup.txt)
# Jeder Befehl einzeln kopieren und ausführen
```

### 2. Tailscale Verbindung prüfen
```bash
# Auf M1 Mac
./tailscale_status.sh

# Sollte RX Node anzeigen
```

### 3. AI Services testen
```bash
# AI Health Check
./ai_client.sh health

# AI System Status
./ai_client.sh status

# Text Processing
./ai_client.sh text "Verarbeite diesen Text"

# Data Computation
./ai_client.sh compute '[1,2,3,4,5]' sum
```

## 🤖 Verfügbare AI Services

### Text Processing
- **Endpoint**: `/ai/text/process`
- **Method**: POST
- **Input**: `{"text": "your text"}`
- **Output**: Verarbeiteter Text mit Statistiken

### Image Analysis
- **Endpoint**: `/ai/image/analyze`
- **Method**: POST
- **Input**: `{"image_path": "path/to/image"}`
- **Output**: Bildanalyse-Ergebnisse

### Data Computation
- **Endpoint**: `/ai/compute`
- **Method**: POST
- **Input**: `{"numbers": [1,2,3], "operation": "sum"}`
- **Output**: Berechnungsergebnisse

## 🌐 Netzwerk-Architektur

```
M1 Mac (100.96.219.28)
    ↓ Tailscale
RX Node (100.x.x.x) ← AI Server Port 8765
    ↓
GPU/CPU AI Processing
```

## 💡 Vorteile

### Ohne Port-Forwarding:
- ✅ Keine Router-Konfiguration
- ✅ Funktioniert hinter CGNAT
- ✅ Sichere Ende-zu-Ende Verschlüsselung
- ✅ Automatische NAT-Traversal

### AI-Optimiert:
- 🤖 Dedizierte AI-Endpoints
- 📊 Hardware-Status Monitoring
- 🔄 Automatische Service-Wiederherstellung
- 📈 Skalierbare Architektur

## 🔧 Erweiterte Features

### GPU-Beschleunigung (falls vorhanden)
```python
# In ai_server.py erweitern für CUDA/OpenCL
import torch
if torch.cuda.is_available():
    device = torch.device("cuda")
```

### Model Loading
```python
# Verschiedene AI Models laden
models = {
    "text": load_text_model(),
    "image": load_image_model(),
    "audio": load_audio_model()
}
```

### Batch Processing
```python
# Für größere Datenmengen
def process_batch(data_batch):
    results = []
    for item in data_batch:
        results.append(process_item(item))
    return results
```

## 📊 Monitoring

### AI Performance
```bash
# System Resources
./ai_client.sh status

# Service Health
systemctl status gentleman-ai.service
```

### Tailscale Connectivity
```bash
# Network Status
tailscale status

# Ping Test
ping $(tailscale status | grep archlinux | awk '{print $1}')
```

## 🛠️ Troubleshooting

### AI Server nicht erreichbar
1. Tailscale Status prüfen: `tailscale status`
2. Service Status prüfen: `systemctl status gentleman-ai.service`
3. Firewall prüfen: `sudo ufw status`

### Performance Issues
1. GPU Verfügbarkeit: `nvidia-smi`
2. Memory Usage: `free -h`
3. CPU Load: `htop`

## 🚀 Zukunfts-Erweiterungen

- **Multi-Model Support**: Verschiedene AI Models
- **Streaming Responses**: Real-time AI Processing
- **Distributed Computing**: Multi-Node AI Cluster
- **Model Fine-tuning**: Custom Model Training
