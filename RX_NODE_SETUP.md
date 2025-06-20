# 🎯 GENTLEMAN RX Node Setup Guide

## Übersicht

Dieses Setup integriert die RX Node vollständig ins GENTLEMAN Cluster und ermöglicht es dem M1 Mac, als zentraler Knotenpunkt zu fungieren, der die RX Node fernsteuern kann.

## 📋 Voraussetzungen

- **RX Node**: Arch Linux System
- **M1 Mac**: macOS mit GENTLEMAN System
- **Netzwerk**: Beide Geräte im gleichen Heimnetzwerk (192.168.68.x)

## 🚀 Setup-Prozess

### Schritt 1: RX Node Netzwerk & SSH Setup

**Auf der RX Node ausführen:**

```bash
# Skript zur RX Node kopieren (per USB, scp, etc.)
sudo ./rx_node_network_setup.sh
```

**Was das Skript macht:**
- ✅ System-Pakete aktualisieren
- ✅ Netzwerk konfigurieren (statische IP: 192.168.68.117)
- ✅ SSH Server sicher einrichten
- ✅ Benutzer 'amo9n11' konfigurieren
- ✅ Wake-on-LAN aktivieren
- ✅ Firewall konfigurieren
- ✅ GENTLEMAN Konfigurationsdateien erstellen

### Schritt 2: SSH-Integration vom M1 Mac

**Auf dem M1 Mac ausführen:**

```bash
# SSH Keys zur RX Node kopieren und Integration
./setup_rx_node_ssh.sh
```

**Was das Skript macht:**
- ✅ SSH Keys zur RX Node kopieren
- ✅ SSH-Konfiguration aktualisieren
- ✅ Verbindungstests durchführen
- ✅ M1 Handshake Server für RX Node konfigurieren
- ✅ Remote Control testen

## 🎛️ Verfügbare Steuerungsmöglichkeiten

### M1 Mac als zentraler Knotenpunkt

```bash
# RX Node über M1 Mac API steuern
./m1_rx_node_control.sh status      # Status prüfen
./m1_rx_node_control.sh shutdown    # Herunterfahren
./m1_rx_node_control.sh shutdown 5  # In 5 Minuten herunterfahren
./m1_rx_node_control.sh wakeup      # Aufwecken (Wake-on-LAN)
```

### Direkte SSH-Steuerung

```bash
# Kurzer SSH-Zugriff
ssh rx-node

# Direkte Befehle
ssh rx-node "sudo shutdown -h now"
ssh rx-node "systemctl status sshd"
ssh rx-node "gentleman-status"
```

### Alternative Steuerung

```bash
# Ursprüngliches RX Node Control Skript
./rx_node_control.sh status
./rx_node_control.sh shutdown
./rx_node_control.sh wakeup
```

## 🌐 Netzwerk-Konfiguration

| Node | IP-Adresse | Rolle |
|------|------------|-------|
| M1 Mac | 192.168.68.111 | Master/Gateway |
| I7 Laptop | 192.168.68.105 | Client |
| RX Node | 192.168.68.117 | Receiver |

## 🔧 M1 Handshake Server API

Der M1 Handshake Server wurde erweitert mit neuen RX Node Endpoints:

```bash
# RX Node Status prüfen
curl http://localhost:8765/admin/rx-node/status

# RX Node herunterfahren
curl -X POST http://localhost:8765/admin/rx-node/shutdown \
     -H "Content-Type: application/json" \
     -d '{"source": "API Test", "delay_minutes": 1}'

# RX Node aufwecken
curl -X POST http://localhost:8765/admin/rx-node/wakeup \
     -H "Content-Type: application/json" \
     -d '{"source": "API Test"}'
```

## 🔍 Status und Überwachung

### RX Node Status prüfen

```bash
# Auf der RX Node
gentleman-status

# Vom M1 Mac aus
ssh rx-node "gentleman-status"
./m1_rx_node_control.sh status
```

### M1 Handshake Server Status

```bash
# Health Check
curl http://localhost:8765/health

# Cluster Status
curl http://localhost:8765/status
```

## 🛠️ Troubleshooting

### SSH-Probleme

```bash
# SSH-Verbindung testen
ssh -vvv rx-node

# SSH Keys neu kopieren
ssh-copy-id -i ~/.ssh/gentleman_key.pub amo9n11@192.168.68.117
```

### Netzwerk-Probleme

```bash
# Ping-Test
ping 192.168.68.117

# Netzwerk-Status auf RX Node
ssh rx-node "ip addr show"
ssh rx-node "systemctl status NetworkManager"
```

### M1 Handshake Server Probleme

```bash
# Server neu starten
./handshake_m1.sh

# Logs prüfen
tail -f /tmp/m1_handshake_server.log
```

## 🎯 Architektur

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   I7 Laptop     │    │     M1 Mac      │    │    RX Node      │
│ 192.168.68.105  │    │ 192.168.68.111  │    │ 192.168.68.117  │
│                 │    │                 │    │                 │
│ • Hotspot Mode  │◄──►│ • Master Node   │◄──►│ • Receiver      │
│ • Auto-Handshake│    │ • API Gateway   │    │ • SSH Server    │
│ • Remote Control│    │ • Tunnel Manager│    │ • Wake-on-LAN   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Cloudflare     │
                    │    Tunnel       │
                    │ (Hotspot Mode)  │
                    └─────────────────┘
```

## 💡 Erweiterte Funktionen

### Wake-on-LAN

Die RX Node unterstützt Wake-on-LAN und kann vom M1 Mac aus aufgeweckt werden:

```bash
# Direkt mit wakeonlan
wakeonlan 30:9c:23:5f:44:a8

# Über M1 Control Script
./m1_rx_node_control.sh wakeup

# Über API
curl -X POST http://localhost:8765/admin/rx-node/wakeup \
     -H "Content-Type: application/json" \
     -d '{"source": "Manual Test"}'
```

### Automatische Integration

Das System erkennt automatisch:
- Netzwerk-Modi (Home vs. Hotspot)
- Verfügbare Steuerungsmethoden (SSH vs. API)
- Node-Status und Erreichbarkeit

## ✅ Erfolgskriterien

Nach erfolgreichem Setup sollten folgende Funktionen verfügbar sein:

- [x] SSH-Zugriff: `ssh rx-node`
- [x] RX Node Status: `./m1_rx_node_control.sh status`
- [x] Remote Shutdown: `./m1_rx_node_control.sh shutdown`
- [x] Wake-on-LAN: `./m1_rx_node_control.sh wakeup`
- [x] M1 API Endpoints für RX Node
- [x] Automatische Netzwerk-Erkennung
- [x] Sichere SSH-Konfiguration
- [x] Firewall-Schutz

Das GENTLEMAN System ist jetzt vollständig integriert mit dem M1 Mac als zentralem Knotenpunkt! 🎉 

## ✅ Erfolgskriterien

Nach erfolgreichem Setup sollten folgende Funktionen verfügbar sein:

- [x] SSH-Zugriff: `ssh rx-node`
- [x] RX Node Status: `./m1_rx_node_control.sh status`
- [x] Remote Shutdown: `./m1_rx_node_control.sh shutdown`
- [x] Wake-on-LAN: `./m1_rx_node_control.sh wakeup`
- [x] M1 API Endpoints für RX Node
- [x] Automatische Netzwerk-Erkennung
- [x] Sichere SSH-Konfiguration
- [x] Firewall-Schutz

Das GENTLEMAN System ist jetzt vollständig integriert mit dem M1 Mac als zentralem Knotenpunkt! 🎉 
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