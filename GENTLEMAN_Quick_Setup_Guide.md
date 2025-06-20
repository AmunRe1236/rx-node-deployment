# 🕸️ GENTLEMAN Mesh Network - Quick Setup Guide

Komplette Anleitung für das Setup des GENTLEMAN Mesh-Netzwerks mit allen drei Nodes.

## 📋 Übersicht

Das GENTLEMAN System besteht aus drei Hauptkomponenten:
- **M1 Mac** (Central Hub) - Koordination und Handshake Server
- **RX Node** (Arch Linux) - AI/Computing Node mit AMD GPU
- **I7 Laptop** (Cross-Platform) - Secondary Node und Mobile Access

## 🚀 Quick Start

### 1. M1 Mac Setup (Central Hub)

```bash
# Klone Repository
git clone https://github.com/AmunRe1236/rx-node-deployment.git Gentleman
cd Gentleman

# Führe M1 Setup aus
chmod +x m1_gentleman_setup.sh
./m1_gentleman_setup.sh
```

**Was passiert:**
- ✅ Homebrew und Python Dependencies Installation
- ✅ Tailscale Setup und Konfiguration
- ✅ SSH-Schlüssel Generierung
- ✅ Handshake Server Setup
- ✅ Wake-on-LAN Konfiguration

**Nach dem Setup:**
```bash
./start_gentleman_m1.sh          # M1 starten
./tailscale_mesh_summary.sh      # System-Übersicht
```

### 2. RX Node Setup (Arch Linux)

```bash
# Auf der RX Node ausführen
git clone https://github.com/AmunRe1236/rx-node-deployment.git Gentleman
cd Gentleman

# Führe RX Setup aus
chmod +x rx_node_gentleman_setup.sh
./rx_node_gentleman_setup.sh
```

**Was passiert:**
- ✅ Arch Linux System Update
- ✅ Docker und Development Tools
- ✅ Tailscale Installation und Setup
- ✅ SSH Server Konfiguration
- ✅ Wake-on-LAN Aktivierung
- ✅ AMD GPU Support (optional)

**Nach dem Setup:**
```bash
./start_gentleman_rx.sh          # RX Node starten
```

### 3. I7 Laptop Setup (Cross-Platform)

```bash
# Auf dem I7 Laptop ausführen
git clone https://github.com/AmunRe1236/rx-node-deployment.git Gentleman
cd Gentleman

# Führe I7 Setup aus
chmod +x i7_gentleman_setup.sh
./i7_gentleman_setup.sh
```

**Was passiert:**
- ✅ OS-spezifische Package Installation
- ✅ Python Dependencies
- ✅ Tailscale Setup
- ✅ SSH Konfiguration für alle Nodes
- ✅ Development Tools (optional)

**Nach dem Setup:**
```bash
./start_gentleman_i7.sh          # I7 Laptop starten
```

## 🔗 Tailscale Setup

Für alle Nodes benötigst du einen Tailscale Account:

1. **Account erstellen:** https://login.tailscale.com/start
2. **Auth-Keys generieren:** https://login.tailscale.com/admin/settings/keys
3. **Während Setup:** Keys in die jeweiligen Setup-Scripts eingeben

## 📊 System Verifikation

Nach dem Setup aller Nodes:

```bash
# Auf dem M1 Mac
./mesh_node_control.sh all status    # Status aller Nodes
./verify_complete_mesh.sh            # Vollständige Mesh-Verifikation
./tailscale_mesh_summary.sh          # Detaillierte Übersicht
```

## 🎮 Verfügbare Commands

### M1 Mac (Central Hub)
```bash
./start_gentleman_m1.sh             # System starten
./handshake_m1.sh                   # Handshake Server
./mesh_node_control.sh              # Node-Verwaltung
./m1_rx_node_control.sh             # RX Node Control
./tailscale_mesh_summary.sh         # System-Übersicht
```

### RX Node (AI/Computing)
```bash
./start_gentleman_rx.sh             # System starten
./rx_node_tailscale_setup.sh        # Tailscale Re-Setup
./amd_ai_client.sh                  # AMD GPU AI Client
```

### I7 Laptop (Secondary)
```bash
./start_gentleman_i7.sh             # System starten
./i7_auto_handshake_setup.sh        # Auto-Handshake Client
```

### Universal Commands (auf allen Nodes)
```bash
./mesh_node_control.sh all status   # Status aller Nodes
./mesh_node_control.sh all shutdown # Alle Nodes herunterfahren
./mesh_node_control.sh all wakeup   # Alle Nodes aufwecken
```

## 🌐 Netzwerk-Modi

Das System erkennt automatisch verschiedene Netzwerk-Modi:

### Heimnetzwerk (192.168.68.x)
- Direkte SSH-Verbindungen
- Wake-on-LAN funktional
- Lokale Handshake Server Verbindung

### Hotspot-Modus (172.20.10.x)
- Tailscale Mesh-Routing
- Remote Wake-on-LAN über M1 Mac
- Tunnel-basierte Verbindungen

### Andere Netzwerke
- Vollständig über Tailscale
- Mesh-Network Routing
- Sichere Ende-zu-Ende Verbindungen

## 🔐 SSH-Konfiguration

Nach dem Setup sind folgende SSH-Verbindungen verfügbar:

```bash
# Von M1 Mac
ssh rx-node                         # RX Node (Heimnetz)
ssh amo9n11@100.xxx.xxx.xxx         # RX Node (Tailscale)

# Von I7 Laptop
ssh m1-mac                          # M1 Mac (Tailscale)
ssh rx-node                         # RX Node (Heimnetz)
ssh rx-node-tailscale               # RX Node (Tailscale)

# Von RX Node
ssh amonbaumgartner@100.xxx.xxx.xxx # M1 Mac (Tailscale)
```

## 🛠️ Troubleshooting

### Tailscale Probleme
```bash
# Status überprüfen
tailscale status

# Neu verbinden
sudo tailscale down
sudo tailscale up --authkey="NEUER_KEY"

# IP anzeigen
tailscale ip -4
```

### SSH Probleme
```bash
# SSH-Schlüssel neu generieren
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519

# SSH-Agent
ssh-add ~/.ssh/id_ed25519

# Verbindung testen
ssh -v HOSTNAME
```

### Handshake Server Probleme
```bash
# Server Status (M1 Mac)
pgrep -f "m1_handshake_server.py"

# Server neu starten
pkill -f "m1_handshake_server.py"
python3 m1_handshake_server.py &

# Health Check
curl http://localhost:8765/health
```

## 📱 Monitoring

### System-Übersicht
```bash
./tailscale_mesh_summary.sh
```

### Node Status
```bash
./mesh_node_control.sh all status
```

### Netzwerk-Tests
```bash
./verify_complete_mesh.sh
```

## 🔄 Updates

Repository auf allen Nodes aktualisieren:

```bash
cd Gentleman
git pull origin master
chmod +x *.sh
```

## 🆘 Support

Bei Problemen:

1. **Logs überprüfen:** `./tailscale_mesh_summary.sh`
2. **Netzwerk testen:** `./verify_complete_mesh.sh`
3. **Services neu starten:** `./start_gentleman_[NODE].sh`
4. **GitHub Issues:** https://github.com/AmunRe1236/rx-node-deployment/issues

## 🎯 Erweiterte Features

### AI/GPU Computing (RX Node)
```bash
./amd_ai_client.sh                  # AMD GPU AI Services
./rx_node_amd_ai_setup.sh          # AMD AI Setup
```

### Friend Network (Skalierung)
```bash
./tailscale_friend_network_setup.sh # Friend Network Setup
./friend_network_connector.sh       # Friend Connections
```

### Sicherheit
```bash
./security_audit.sh                 # Security Audit
./secure_ssh_setup.sh              # SSH Hardening
```

---

**🌟 Das GENTLEMAN Mesh Network ist jetzt einsatzbereit!**

Alle Nodes sind über Tailscale verbunden und können sich gegenseitig erreichen, unabhängig vom Netzwerk-Standort. 