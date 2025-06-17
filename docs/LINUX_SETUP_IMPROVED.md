# 🐧 **GENTLEMAN - Verbessertes Linux Setup**
## **Optimiert basierend auf praktischen Erfahrungen**

---

## 🎯 **Was wurde verbessert?**

### ✅ **Probleme behoben:**
1. **Nebula-Pfade**: Automatische Verwendung von `/etc/nebula/` statt Benutzerverzeichnis
2. **Zertifikat-Berechtigungen**: Korrekte Permissions (600 für Keys, 644 für Certs)
3. **Package Manager**: Intelligente Erkennung und Fallback-Installation
4. **Hardware-Integration**: Automatische Nebula-Konfiguration basierend auf erkannter Hardware
5. **Systemd-Services**: Robuste Service-Konfiguration mit Sicherheitseinstellungen
6. **Firewall**: Automatische iptables/ufw-Konfiguration

### 🚀 **Neue Features:**
- **Automatische Distro-Erkennung** (Arch, Ubuntu, CentOS, etc.)
- **Intelligente Package-Installation** (pacman, apt, yum, dnf, zypper)
- **Hardware-basierte Nebula-Konfiguration**
- **Robuste Fehlerbehandlung**
- **Setup-Troubleshooting-Tools**

---

## 🛠️ **Installation**

### 🎯 **Einfache Installation:**
```bash
# Automatisches Setup mit Hardware-Erkennung
make setup-linux-auto

# Oder manuell:
make setup-linux-improved
```

### 🔧 **Was passiert automatisch:**
1. **System-Erkennung**: Distribution, Package Manager, Architektur
2. **Abhängigkeiten**: Docker, Nebula, Python, Git, etc.
3. **Hardware-Detection**: CPU, GPU, RAM, Storage-Analyse
4. **Nebula-Setup**: Zertifikate, Konfiguration, systemd Service
5. **Firewall**: Automatische Regeln für Nebula VPN
6. **Docker**: Benutzer-Berechtigung und Service-Start

---

## 🌐 **Nebula VPN - Automatische Konfiguration**

### 🎮 **LLM Server (RX Node)**
```yaml
Node IP: 192.168.100.10/24
Gruppen: llm-servers, gpu-nodes
Services: llm-server, monitoring, matrix-updates
Ports: 8000-8010 (API), 9090-9100 (Monitoring)
```

### 🎤 **Audio Server (M1 Node)**
```yaml
Node IP: 192.168.100.20/24
Gruppen: audio-services, apple-silicon
Services: stt-service, tts-service, git-server
Ports: 8001-8003 (STT/TTS)
```

### 📚 **Git Server**
```yaml
Node IP: 192.168.100.40/24
Gruppen: git-servers, storage-nodes
Services: git-server, web-interface
Ports: 3000 (Gitea), 8080 (Web)
```

### 💻 **Client Node**
```yaml
Node IP: 192.168.100.30/24
Gruppen: clients, mobile-nodes
Services: web-interface, monitoring
Ports: 8080 (Web Interface)
```

---

## 📋 **Verfügbare Befehle**

### 🚀 **Setup-Befehle:**
```bash
# Verbessertes Linux-Setup
make setup-linux-improved

# Automatisches Setup mit Hardware-Erkennung
make setup-linux-auto

# Setup-Komponenten testen
make setup-linux-test

# Hardware erneut erkennen
make detect-hardware
```

### 🌐 **Nebula-Befehle:**
```bash
# Nebula-Status anzeigen
make nebula-status

# Nebula-Konnektivität testen
make nebula-test

# Nebula-Service starten/stoppen
make nebula-start
make nebula-stop
make nebula-restart

# Nebula-Logs anzeigen
make nebula-logs
```

### 🔧 **Troubleshooting:**
```bash
# Häufige Probleme beheben
make setup-fix

# Temporäre Dateien aufräumen
make setup-clean

# Komplettes Reset (VORSICHT!)
make setup-reset
```

---

## 🔍 **Unterstützte Linux-Distributionen**

### ✅ **Vollständig getestet:**
- **Arch Linux** (pacman)
- **Ubuntu/Debian** (apt)
- **CentOS/RHEL** (yum)
- **Fedora** (dnf)
- **openSUSE** (zypper)

### 🎯 **Package Manager Erkennung:**
```bash
# Automatische Erkennung und Installation:
pacman -S nebula docker docker-compose python3 git jq bc
apt install nebula docker.io docker-compose python3 git jq bc
yum install docker docker-compose python3 git jq bc
dnf install nebula docker docker-compose python3 git jq bc
zypper install docker docker-compose python3 git jq bc
```

### 📦 **Fallback-Installation:**
Falls Nebula nicht über Package Manager verfügbar:
- Automatischer Download von GitHub Releases
- Architektur-spezifische Binaries (amd64, arm64)
- Installation nach `/usr/local/bin/`

---

## 🔒 **Sicherheitsverbesserungen**

### 🔐 **Zertifikat-Management:**
```bash
# Sichere Pfade:
/etc/nebula/rx-node/ca.crt      (644, root:root)
/etc/nebula/rx-node/rx-node.crt (644, root:root)
/etc/nebula/rx-node/rx-node.key (600, root:root)
```

### 🛡️ **Systemd-Sicherheit:**
```ini
# Sicherheitseinstellungen:
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
CapabilityBoundingSet=CAP_NET_ADMIN
AmbientCapabilities=CAP_NET_ADMIN
```

### 🔥 **Firewall-Automatisierung:**
```bash
# Automatische iptables-Regeln:
iptables -A INPUT -i nebula1 -j ACCEPT
iptables -A INPUT -p udp --dport 4242 -j ACCEPT

# ufw-Regeln (falls verfügbar):
ufw allow 4242/udp comment "Nebula VPN"
```

---

## 🧪 **Testing & Validation**

### 📊 **Automatische Tests:**
```bash
make setup-linux-test
```

**Überprüft:**
- ✅ Docker Installation und Funktionalität
- ✅ Nebula Installation und Version
- ✅ Nebula Service Status
- ✅ Hardware-Konfiguration
- ✅ Zertifikat-Gültigkeit
- ✅ Netzwerk-Interface (nebula1)

### 🔍 **Manuelle Validierung:**
```bash
# Nebula-Konfiguration testen:
sudo nebula -config /etc/nebula/rx-node/config.yml -test

# Service-Status prüfen:
systemctl status nebula-rx-node

# Interface prüfen:
ip addr show nebula1

# Logs anzeigen:
journalctl -u nebula-rx-node -f
```

---

## 🚨 **Troubleshooting**

### ❌ **Häufige Probleme:**

**1. "Permission denied" bei Docker:**
```bash
# Lösung:
make setup-fix
# oder manuell:
sudo usermod -aG docker $USER
newgrp docker
```

**2. "Nebula config invalid":**
```bash
# Diagnose:
sudo nebula -config /etc/nebula/rx-node/config.yml -test

# Lösung:
make setup-linux-improved  # Konfiguration neu erstellen
```

**3. "TUN interface creation failed":**
```bash
# Lösung:
sudo modprobe tun
echo 'tun' | sudo tee -a /etc/modules-load.d/tun.conf
```

**4. "Service won't start":**
```bash
# Diagnose:
journalctl -u nebula-rx-node -n 20

# Häufige Lösungen:
sudo systemctl daemon-reload
sudo systemctl restart nebula-rx-node
```

### 🔧 **Reset bei Problemen:**
```bash
# Sanftes Reset:
make setup-clean

# Komplettes Reset (VORSICHT!):
make setup-reset
make setup-linux-improved
```

---

## 📈 **Performance-Optimierungen**

### 🎯 **Hardware-spezifische Konfiguration:**
- **AMD RX 6700 XT**: ROCm-Optimierungen, LLM Server-Rolle
- **Apple Silicon**: MPS-Optimierungen, Audio Server-Rolle
- **Intel CPUs**: Client-Optimierungen
- **SSD Storage**: Erweiterte Cache-Einstellungen

### 🌐 **Netzwerk-Optimierungen:**
```yaml
# Nebula-Tuning:
mtu: 1300                    # Optimiert für VPN
tx_queue: 500               # Erhöhte Queue-Größe
punchy: true                # Aggressive NAT-Traversal
respond_delay: 5s           # Optimierte Response-Zeit
```

### 🔥 **Firewall-Performance:**
```yaml
# Optimierte Connection-Tracking:
tcp_timeout: 12m
udp_timeout: 3m
max_connections: 100000
```

---

## 🎯 **Fazit**

### ✅ **Verbesserungen erreicht:**
1. **🚀 Zuverlässige Installation** auf allen Linux-Distributionen
2. **🔒 Sichere Konfiguration** mit korrekten Berechtigungen
3. **🌐 Automatische Nebula-Einrichtung** basierend auf Hardware
4. **🛠️ Robuste Fehlerbehandlung** und Troubleshooting
5. **📊 Umfassende Tests** und Validierung

### 🎩 **Nächstes Mal:**
```bash
# Ein Befehl für komplettes Setup:
make setup-linux-auto

# Automatisch konfiguriert:
✅ Hardware-Erkennung
✅ Nebula VPN mit korrekten Zertifikaten
✅ Systemd Services
✅ Firewall-Regeln
✅ Docker-Berechtigung
✅ Performance-Optimierungen
```

**🎩 Das verbesserte Linux-Setup macht die Installation zum Kinderspiel!** 🚀 