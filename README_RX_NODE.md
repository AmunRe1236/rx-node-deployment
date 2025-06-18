# 🎯 GENTLEMAN RX Node Setup

## Übersicht
Dieses Repository enthält alle nötigen Dateien zur lokalen Konfiguration der RX Node (192.168.68.117) für das GENTLEMAN Multi-Node AI System.

## 🚀 Schnellstart

### 1. Repository herunterladen
```bash
# Auf der RX Node ausführen:
cd ~
git clone https://github.com/gentleman-ai/rx-node-setup.git
# oder
wget https://raw.githubusercontent.com/gentleman-ai/rx-node-setup/main/rx_local_setup.sh
```

### 2. Setup ausführen
```bash
chmod +x rx_local_setup.sh
./rx_local_setup.sh
```

### 3. System testen
```bash
cd ~/Gentleman
./test_gentleman.sh
```

### 4. Service starten
```bash
cd ~/Gentleman
./start_gentleman.sh
```

## 📋 System Anforderungen

### Hardware
- **CPU:** Mindestens 4 Cores (empfohlen: 8+)
- **RAM:** Mindestens 8GB (empfohlen: 16GB+)
- **GPU:** Optional, aber empfohlen für AI Training
- **Storage:** Mindestens 10GB freier Speicher

### Software
- **OS:** Linux (getestet auf Arch Linux)
- **Python:** 3.8+ (empfohlen: 3.11+)
- **Network:** Zugang zu 192.168.68.0/24 Netzwerk

## 🏗️ Architektur

### RX Node Rolle: Primary AI Trainer
```
┌─────────────────────────────────────────┐
│           RX Node (192.168.68.117)      │
│  ┌─────────────────────────────────────┐ │
│  │     GENTLEMAN Protocol              │ │
│  │  ┌─────────────┐ ┌─────────────────┐ │ │
│  │  │   HTTP      │ │   SQLite        │ │ │
│  │  │   Server    │ │   Database      │ │ │
│  │  │   Port 8008 │ │   Knowledge     │ │ │
│  │  └─────────────┘ └─────────────────┘ │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │          AI Training Pipeline       │ │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ │ │
│  │  │   GPU   │ │ Cluster │ │  Model  │ │ │
│  │  │Training │ │  Mgmt   │ │Serving  │ │ │
│  │  └─────────┘ └─────────┘ └─────────┘ │ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## 📦 Installierte Komponenten

### Kern-Dateien
- `talking_gentleman_protocol.py` - Haupt-Service
- `talking_gentleman_config.json` - Konfiguration
- `knowledge.db` - SQLite Datenbank

### Management Scripts
- `start_gentleman.sh` - Service starten
- `check_status.sh` - Status prüfen
- `test_gentleman.sh` - System testen

### Verzeichnisstruktur
```
~/Gentleman/
├── backup/                     # Backup Dateien
├── logs/                       # Log Dateien
├── config/                     # Zusätzliche Configs
├── scripts/                    # Helper Scripts
├── data/                       # AI Training Daten
├── talking_gentleman_config.json
├── talking_gentleman_protocol.py
├── start_gentleman.sh
├── check_status.sh
├── test_gentleman.sh
└── INSTALLATION_SUMMARY.md
```

## ⚙️ Konfiguration

### RX Node Spezifische Einstellungen
```json
{
  "node_id": "rx-local-trainer",
  "role": "primary_trainer",
  "port": 8008,
  "capabilities": [
    "knowledge_training",
    "gpu_inference",
    "cluster_management",
    "distributed_training",
    "model_serving"
  ],
  "hardware": {
    "gpu_available": true,
    "memory_gb": 16,
    "cpu_cores": 8,
    "specialized_role": "ai_trainer"
  }
}
```

### Netzwerk Konfiguration
- **Port:** 8008 (HTTP Service)
- **Discovery Port:** 8009 (Node Discovery)
- **Known Nodes:**
  - M1 Mac: 192.168.68.111
  - RX Node: 192.168.68.117 (selbst)
  - i7 Node: 192.168.68.105

## 🧪 Testing

### Automatische Tests
```bash
cd ~/Gentleman
./test_gentleman.sh
```

### Manuelle Tests
```bash
# Status Check
python3 talking_gentleman_protocol.py --status

# Database Test
python3 talking_gentleman_protocol.py --test

# Network Test
curl http://localhost:8008/status
curl http://localhost:8008/health
```

## 🔧 Troubleshooting

### Häufige Probleme

#### Port 8008 bereits in Verwendung
```bash
# Prozess finden und beenden
sudo lsof -i :8008
sudo kill -9 <PID>
```

#### Python Dependencies fehlen
```bash
# Arch Linux
sudo pacman -S python-requests python-sqlite

# Ubuntu/Debian
sudo apt install python3-requests python3-sqlite

# Mit pip (falls erlaubt)
python3 -m pip install --user --break-system-packages requests
```

#### Database Probleme
```bash
# Database neu erstellen
cd ~/Gentleman
rm -f knowledge.db
python3 talking_gentleman_protocol.py --test
```

### Log Dateien
```bash
# Service Logs
tail -f ~/Gentleman/logs/gentleman.log

# System Logs
journalctl -f | grep gentleman
```

## 🔐 Sicherheit

### SSH Zugang
- Verwende `gentleman_key` für SSH Authentifizierung
- SSH Config automatisch aktualisiert

### API Sicherheit
- API Key Authentifizierung aktiviert
- Verschlüsselte Kommunikation zwischen Nodes

### Firewall
```bash
# Port 8008 öffnen (falls nötig)
sudo ufw allow 8008/tcp
sudo iptables -A INPUT -p tcp --dport 8008 -j ACCEPT
```

## 🚀 Production Deployment

### Service Installation (systemd)
```bash
# Service File erstellen
sudo tee /etc/systemd/system/gentleman.service << EOF
[Unit]
Description=GENTLEMAN Protocol RX Node
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$HOME/Gentleman
ExecStart=/usr/bin/python3 talking_gentleman_protocol.py --start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable gentleman
sudo systemctl start gentleman
```

### Monitoring
```bash
# Service Status
sudo systemctl status gentleman

# Logs
sudo journalctl -u gentleman -f
```

## 📊 Performance

### Empfohlene Hardware
- **CPU:** AMD Ryzen 7+ oder Intel i7+
- **GPU:** NVIDIA RTX 3060+ für AI Training
- **RAM:** 32GB für große Modelle
- **Storage:** SSD für bessere I/O Performance

### Optimierungen
```bash
# GPU Memory Management
export CUDA_VISIBLE_DEVICES=0
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

# Python Optimierungen
export PYTHONOPTIMIZE=1
export PYTHONUNBUFFERED=1
```

## 🤝 Support

### Kontakt
- **GitHub Issues:** https://github.com/gentleman-ai/rx-node-setup/issues
- **Documentation:** https://docs.gentleman-ai.com
- **Community:** https://discord.gg/gentleman-ai

### Logs für Support
```bash
# System Info sammeln
cd ~/Gentleman
./check_status.sh > system_info.txt
cat INSTALLATION_SUMMARY.md >> system_info.txt
```

## 📝 Changelog

### Version 1.0 (2025-06-18)
- ✅ Initiale RX Node Setup Implementation
- ✅ SQLite Database Integration
- ✅ HTTP Service mit Status Endpoints
- ✅ Management Scripts
- ✅ Automatische Tests
- ✅ Systemd Service Support

## 📄 Lizenz

MIT License - siehe LICENSE Datei für Details.

---

**🎯 RX Node - Primary AI Trainer für das GENTLEMAN Multi-Node System** 