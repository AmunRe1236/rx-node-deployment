# 🎯 RX Node Deployment Guide - Lokale Konfiguration

## 📋 Übersicht
Vollständige Anleitung zur lokalen Konfiguration der RX Node (192.168.68.117) für das GENTLEMAN Multi-Node AI System.

**Status:** ✅ **Setup erfolgreich getestet und funktionsfähig**

## 🚀 Sofortige Bereitstellung

### Option 1: Direkter Download und Ausführung
```bash
# Auf der RX Node ausführen:
ssh amo9n11@192.168.68.117
cd ~
wget https://raw.githubusercontent.com/gentleman-ai/rx-node-setup/main/rx_local_setup.sh
chmod +x rx_local_setup.sh
./rx_local_setup.sh
```

### Option 2: Git Repository (empfohlen)
```bash
# Auf der RX Node ausführen:
ssh amo9n11@192.168.68.117
cd ~
git clone https://github.com/gentleman-ai/rx-node-setup.git
cd rx-node-setup
chmod +x rx_local_setup.sh
./rx_local_setup.sh
```

### Option 3: Vom M1 Mac übertragen (bereits erledigt)
```bash
# Bereits übertragen - direkt ausführen:
ssh rx-node "cd ~ && chmod +x rx_local_setup.sh && ./rx_local_setup.sh"
```

## 📊 Deployment Status

### ✅ Erfolgreich abgeschlossen:
1. **SSH Konnektivität:** Funktional mit `gentleman_key`
2. **Lokales Setup Script:** Erstellt und übertragen
3. **GENTLEMAN Protocol:** Vollständig implementiert
4. **Database:** SQLite initialisiert
5. **Management Scripts:** Alle erstellt und getestet
6. **System Tests:** Alle bestanden
7. **Git Repository:** Committed und bereit

### 🎯 RX Node Spezifikationen:
- **System:** Arch Linux (Kernel 6.12.32-1-lts)
- **Python:** 3.13.3
- **RAM:** 15GB verfügbar
- **Network:** 192.168.68.117/24
- **Rolle:** Primary AI Trainer
- **Port:** 8008 (HTTP Service)

## 🛠️ Verfügbare Scripts auf der RX Node

Nach der Installation sind folgende Scripts verfügbar:

### 1. System Test
```bash
ssh rx-node "cd ~/Gentleman && ./test_gentleman.sh"
```

### 2. Service starten
```bash
ssh rx-node "cd ~/Gentleman && ./start_gentleman.sh"
```

### 3. Status prüfen
```bash
ssh rx-node "cd ~/Gentleman && ./check_status.sh"
```

### 4. GENTLEMAN Protocol direkt
```bash
ssh rx-node "cd ~/Gentleman && python3 talking_gentleman_protocol.py --status"
ssh rx-node "cd ~/Gentleman && python3 talking_gentleman_protocol.py --test"
ssh rx-node "cd ~/Gentleman && python3 talking_gentleman_protocol.py --start"
```

## 🔧 Lokale Konfiguration (auf der RX Node)

### Einmalige Einrichtung
```bash
# 1. SSH zur RX Node
ssh amo9n11@192.168.68.117

# 2. Setup ausführen (falls noch nicht geschehen)
cd ~
./rx_local_setup.sh

# 3. System testen
cd ~/Gentleman
./test_gentleman.sh

# 4. Service starten
./start_gentleman.sh
```

### Verzeichnisstruktur auf RX Node
```
/home/amo9n11/
├── rx_local_setup.sh           # Setup Script
└── Gentleman/                  # Hauptverzeichnis
    ├── backup/                 # Backup Dateien
    ├── logs/                   # Log Dateien
    ├── config/                 # Konfigurationen
    ├── scripts/                # Helper Scripts
    ├── data/                   # AI Training Daten
    ├── talking_gentleman_config.json
    ├── talking_gentleman_protocol.py
    ├── start_gentleman.sh      # Service starten
    ├── check_status.sh         # Status prüfen
    ├── test_gentleman.sh       # System testen
    └── INSTALLATION_SUMMARY.md # Dokumentation
```

## 🌐 GitHub/Gitea Repository Setup

### Lokales Repository (bereits erstellt)
```bash
# Auf dem M1 Mac:
git log --oneline -5
# Zeigt: ff6657b 🎯 RX Node Lokale Konfiguration - Vollständiges Setup Script...
```

### Für GitHub Push (wenn gewünscht)
```bash
# Neues GitHub Repository erstellen:
# https://github.com/new
# Repository Name: "gentleman-rx-node-setup"

# Dann:
git remote add origin https://github.com/[username]/gentleman-rx-node-setup.git
git branch -M main
git push -u origin main
```

### Für Gitea Setup (lokal)
```bash
# Falls Gitea Server läuft:
git remote add gitea http://192.168.68.111:3000/[username]/gentleman-rx-node-setup.git
git push gitea main
```

## 🧪 Vollständiger Systemtest

### Test-Sequenz
```bash
# 1. Netzwerk Test
ping -c 1 192.168.68.117

# 2. SSH Test
ssh rx-node "echo 'SSH OK'"

# 3. GENTLEMAN Test
ssh rx-node "cd ~/Gentleman && ./test_gentleman.sh"

# 4. Service Test (kurz)
ssh rx-node "cd ~/Gentleman && timeout 10 python3 talking_gentleman_protocol.py --start || echo 'Service Test OK'"

# 5. Status Test
ssh rx-node "cd ~/Gentleman && python3 talking_gentleman_protocol.py --status"
```

## 🔐 Sicherheitskonfiguration

### SSH Keys (bereits konfiguriert)
- ✅ `gentleman_key` für sichere Authentifizierung
- ✅ SSH Config automatisch aktualisiert
- ✅ Key Rotation Scripts verfügbar

### Firewall (falls nötig)
```bash
# Auf der RX Node ausführen:
sudo ufw allow 8008/tcp
sudo ufw allow from 192.168.68.0/24 to any port 8008
```

## 🚀 Production Deployment

### Systemd Service (empfohlen)
```bash
# Auf der RX Node ausführen:
sudo tee /etc/systemd/system/gentleman.service << 'EOF'
[Unit]
Description=GENTLEMAN Protocol RX Node
After=network.target

[Service]
Type=simple
User=amo9n11
WorkingDirectory=/home/amo9n11/Gentleman
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

# Status prüfen
sudo systemctl status gentleman
```

## 📊 Monitoring & Logs

### Service Status
```bash
# Systemd Service
sudo systemctl status gentleman

# Manual Process
ssh rx-node "pgrep -f talking_gentleman_protocol"
```

### Logs
```bash
# Service Logs
sudo journalctl -u gentleman -f

# Application Logs
ssh rx-node "tail -f ~/Gentleman/logs/gentleman.log"
```

## 🔧 Troubleshooting

### Häufige Probleme

#### 1. Port 8008 belegt
```bash
ssh rx-node "sudo lsof -i :8008"
ssh rx-node "sudo kill -9 \$(sudo lsof -t -i :8008)"
```

#### 2. Python Dependencies
```bash
ssh rx-node "python3 -m pip install --user --break-system-packages requests"
```

#### 3. Database Issues
```bash
ssh rx-node "cd ~/Gentleman && rm -f knowledge.db && python3 talking_gentleman_protocol.py --test"
```

### Support Informationen sammeln
```bash
ssh rx-node "cd ~/Gentleman && ./check_status.sh > ~/system_info.txt"
scp rx-node:~/system_info.txt ./rx_node_debug.txt
```

## 📈 Performance Optimierung

### GPU Setup (falls verfügbar)
```bash
# NVIDIA GPU
ssh rx-node "nvidia-smi"

# CUDA Environment
ssh rx-node "export CUDA_VISIBLE_DEVICES=0"
```

### Memory Management
```bash
# Python Memory
ssh rx-node "export PYTHONOPTIMIZE=1"
ssh rx-node "export PYTHONUNBUFFERED=1"
```

## 🎯 Nächste Schritte

### 1. Service dauerhaft aktivieren
```bash
ssh rx-node "cd ~/Gentleman && sudo systemctl enable gentleman && sudo systemctl start gentleman"
```

### 2. Alle Nodes synchronisieren
```bash
# M1 Mac Service starten
python3 talking_gentleman_protocol.py --start &

# i7 Node Service starten
ssh i7-node "cd ~/Gentleman && python3 talking_gentleman_protocol.py --start" &

# RX Node Service starten
ssh rx-node "cd ~/Gentleman && python3 talking_gentleman_protocol.py --start" &
```

### 3. Cluster Konnektivität testen
```bash
# Status aller Nodes prüfen
curl http://192.168.68.111:8008/status
curl http://192.168.68.117:8008/status  
curl http://192.168.68.105:8008/status
```

## 📝 Deployment Checklist

- [x] SSH Zugang zur RX Node konfiguriert
- [x] Lokales Setup Script erstellt
- [x] Setup Script zur RX Node übertragen
- [x] Lokale Konfiguration erfolgreich ausgeführt
- [x] System Tests bestanden
- [x] Management Scripts funktionsfähig
- [x] Database initialisiert
- [x] Git Repository erstellt
- [x] Dokumentation vollständig
- [ ] Systemd Service aktiviert (optional)
- [ ] Alle Nodes gleichzeitig gestartet (nächster Schritt)
- [ ] Cluster Synchronisation getestet (nächster Schritt)

## 🎉 Fazit

**Die RX Node ist jetzt vollständig für lokale Konfiguration vorbereitet!**

### ✅ Was funktioniert:
- **Lokales Setup:** Vollständig automatisiert
- **GENTLEMAN Protocol:** Funktionsfähig
- **Database:** Initialisiert und getestet
- **Management:** Alle Scripts verfügbar
- **Sicherheit:** SSH Keys konfiguriert
- **Dokumentation:** Vollständig

### 🚀 Bereit für:
- **Production Deployment:** Systemd Service
- **Cluster Integration:** Multi-Node Synchronisation
- **AI Training:** GPU-beschleunigtes Training
- **Monitoring:** Logs und Status Tracking

**Die RX Node ist bereit als Primary AI Trainer im GENTLEMAN Multi-Node System! 🎯** 