# 🍎 GENTLEMAN Git Server - M1 Mac Setup

**Optimierte Git-Server-Einrichtung für Apple Silicon M1/M2 Macs**

## 🎯 Warum auf dem M1 Mac?

Der **Git-Server gehört auf den M1 Mac**, weil:

✅ **Zentrale Verwaltung**: M1 Mac als Hauptentwicklungsmaschine  
✅ **Bessere Performance**: Apple Silicon Optimierung  
✅ **Netzwerk-Hub**: Alle Geräte können darauf zugreifen  
✅ **Backup-Integration**: Time Machine erfasst Git-Repositories  
✅ **Entwickler-Workflow**: Direkt am Arbeitsplatz verfügbar  

## 🚀 Schnellstart für M1 Mac

### 1. M1-optimiertes Setup
```bash
make git-setup-m1
```

### 2. Git-Server starten
```bash
make git-start
```

### 3. Zugriff testen
```bash
# Lokal auf M1 Mac
open https://localhost:3000

# Aus dem Netzwerk (z.B. Worker Node)
curl -k https://192.168.100.20:3000
```

## 🏗️ M1 Mac Architektur

### 🌐 Netzwerk-Layout
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Worker Node   │    │    M1 Mac       │    │  Mobile/Other   │
│ 192.168.100.10  │◄──►│ 192.168.100.20  │◄──►│   Devices       │
│                 │    │                 │    │                 │
│ • LLM Server    │    │ • Git Server    │    │ • Git Clients   │
│ • AI Pipeline   │    │ • STT Service   │    │ • Web Access    │
│ • Matrix Client │    │ • TTS Service   │    │                 │
└─────────────────┘    │ • Development   │    └─────────────────┘
                       └─────────────────┘
```

### 🔗 Service-Integration
- **STT/TTS Services**: Laufen bereits auf M1 Mac
- **Git Server**: Neue Ergänzung auf M1 Mac
- **LLM Server**: Läuft auf Worker Node
- **Matrix Updates**: Koordiniert zwischen allen Geräten

## 🍎 M1 Mac Spezifische Features

### 🚀 Performance-Optimierungen
- **ARM64 Docker Images**: Native Apple Silicon Unterstützung
- **Docker BuildKit**: Schnellere Container-Builds
- **Memory Management**: Optimiert für macOS Unified Memory
- **SSD Performance**: Nutzt M1 Mac SSD-Geschwindigkeit

### 🔒 macOS Integration
- **Keychain Integration**: Sichere Passwort-Speicherung
- **Firewall Configuration**: macOS Firewall-Regeln
- **Time Machine Backup**: Automatische Git-Repository-Sicherung
- **Spotlight Integration**: Git-Repositories durchsuchbar

### 🌐 Netzwerk-Konfiguration
```bash
# M1 Mac IP-Adresse
M1_IP="192.168.100.20"

# Zugriff von anderen Geräten
https://192.168.100.20:3000    # Web Interface
ssh://git@192.168.100.20:2222  # SSH Git Access

# Mit Hostname (nach /etc/hosts Eintrag)
https://git.gentleman.local
ssh://git@git.gentleman.local:2222
```

## 📋 Voraussetzungen für M1 Mac

### ✅ Hardware
- **M1/M2 Mac**: Apple Silicon erforderlich
- **8GB+ RAM**: Empfohlen für Git-Server + Development
- **50GB+ freier Speicher**: Für Git-Repositories und Docker
- **Netzwerk**: Ethernet oder stabiles WiFi

### 🛠️ Software
- **macOS 12+**: Monterey oder neuer
- **Docker Desktop**: Neueste Version für Apple Silicon
- **Xcode Command Line Tools**: `xcode-select --install`
- **Homebrew**: Für zusätzliche Tools (optional)

## 🔧 M1 Mac Setup-Prozess

### 1. Automatisches Setup
```bash
# Führt alle Schritte automatisch aus
make git-setup-m1
```

### 2. Manuelle Schritte (falls nötig)

#### Docker Desktop konfigurieren
```bash
# Docker Desktop Einstellungen:
# - Resources → Memory: 4GB+
# - Resources → Disk: 50GB+
# - Features → Use Docker Compose V2: ✅
# - Features → Use containerd: ✅
```

#### Hosts-Datei aktualisieren
```bash
# Auf M1 Mac
sudo echo "127.0.0.1 git.gentleman.local" >> /etc/hosts
sudo echo "127.0.0.1 gitea.gentleman.local" >> /etc/hosts

# Auf anderen Geräten im Netzwerk
sudo echo "192.168.100.20 git.gentleman.local" >> /etc/hosts
sudo echo "192.168.100.20 gitea.gentleman.local" >> /etc/hosts
```

#### Firewall konfigurieren
```bash
# macOS Firewall für Git-Server öffnen
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Docker.app
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock /Applications/Docker.app
```

## 🌐 Netzwerk-Zugriff einrichten

### Von Worker Node (192.168.100.10)
```bash
# Git-Repository klonen
git clone https://192.168.100.20:3000/username/repository.git

# SSH-Zugriff (nach SSH-Key Setup)
git clone ssh://git@192.168.100.20:2222/username/repository.git
```

### Von anderen Geräten
```bash
# Web-Interface öffnen
open https://192.168.100.20:3000

# Git-Repository klonen
git clone https://git.gentleman.local/username/repository.git
```

## 🔐 Sicherheit auf M1 Mac

### SSL-Zertifikate
```bash
# Automatisch generiert mit M1 Mac spezifischen Einstellungen
# Enthält alle relevanten Hostnamen und IP-Adressen:
# - git.gentleman.local
# - gitea.gentleman.local
# - 192.168.100.20
# - 127.0.0.1
# - $(hostname).local
```

### Backup-Strategie
```bash
# Time Machine Integration
# Git-Repositories werden automatisch gesichert in:
# ~/Documents/Archives/gentleman/data/git-server/

# Zusätzliche Docker-Volume-Backups
make git-backup
```

### Firewall-Regeln
```bash
# Nur notwendige Ports öffnen:
# - 80/443: HTTP/HTTPS Web-Interface
# - 3000: Gitea Direct Access
# - 2222: SSH Git Access
```

## 🧪 Testing auf M1 Mac

### Lokale Tests
```bash
# Git-Server Demo starten
make git-demo

# Health Check
curl -k https://localhost:3000/api/healthz

# SSH-Verbindung testen
ssh -p 2222 git@localhost
```

### Netzwerk-Tests
```bash
# Von Worker Node testen
ssh worker-node
curl -k https://192.168.100.20:3000/api/healthz

# Repository-Operationen testen
git clone https://192.168.100.20:3000/test/repo.git
```

## 📊 Monitoring auf M1 Mac

### Docker-Container überwachen
```bash
# Container-Status
make git-status

# Resource-Verbrauch
docker stats

# Logs anzeigen
make git-logs
```

### macOS-spezifisches Monitoring
```bash
# CPU/Memory Usage
top -pid $(docker ps -q --filter "name=gitea")

# Disk Usage
du -sh ~/Documents/Archives/gentleman/data/git-server/

# Network Connections
lsof -i :3000 -i :2222 -i :80 -i :443
```

## 🔄 Workflow-Integration

### Development auf M1 Mac
```bash
# Lokales Repository erstellen
cd ~/Projects/mein-projekt
git init
git remote add origin https://localhost:3000/username/mein-projekt.git
git push -u origin main
```

### Deployment von Worker Node
```bash
# Repository auf Worker Node klonen
ssh worker-node
git clone https://192.168.100.20:3000/username/mein-projekt.git
cd mein-projekt
# Deployment-Skripte ausführen
```

### Mobile Development
```bash
# SSH-Tunnel für sicheren Zugriff
ssh -L 3000:localhost:3000 m1-mac-user@192.168.100.20

# Dann lokal zugreifen auf:
https://localhost:3000
```

## 🛠️ Wartung auf M1 Mac

### Regelmäßige Aufgaben
```bash
# Git-Server aktualisieren
make git-update

# Backup erstellen
make git-backup

# Logs rotieren
docker system prune -f

# Docker Desktop neustarten (bei Problemen)
osascript -e 'quit app "Docker Desktop"'
open -a "Docker Desktop"
```

### Performance-Optimierung
```bash
# Docker Desktop Memory erhöhen
# Docker Desktop → Settings → Resources → Memory: 6GB+

# SSD-Speicher freigeben
docker system prune -a -f --volumes

# Git-Repository-Größe optimieren
git gc --aggressive --prune=now
```

## 🚨 Troubleshooting M1 Mac

### Häufige Probleme

#### Port bereits belegt
```bash
# Prüfen welcher Prozess Port 3000 verwendet
lsof -i :3000
# Prozess beenden oder anderen Port verwenden
```

#### Docker Desktop startet nicht
```bash
# Docker Desktop zurücksetzen
rm -rf ~/Library/Group\ Containers/group.com.docker
open -a "Docker Desktop"
```

#### SSL-Zertifikat-Fehler
```bash
# Neue Zertifikate generieren
rm -rf config/security/ssl/gentleman.*
make git-setup-m1
```

#### Netzwerk-Zugriff funktioniert nicht
```bash
# macOS Firewall prüfen
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Docker-Netzwerk neu erstellen
docker network rm gentleman-mesh
make git-setup-m1
```

## 🎯 Nächste Schritte

Nach der M1 Mac Einrichtung:

1. **Admin-Account erstellen**: https://localhost:3000
2. **SSH-Keys konfigurieren**: Für sichere Git-Operationen
3. **Erstes Repository**: GENTLEMAN Projekt migrieren
4. **Worker Node konfigurieren**: Git-Client Setup
5. **Backup testen**: Wiederherstellung einmal durchführen
6. **Team-Zugriff**: Weitere Entwickler einladen

## 📚 M1 Mac Befehle Übersicht

```bash
# Setup & Management
make git-setup-m1     # M1-optimiertes Setup
make git-start        # Server starten
make git-stop         # Server stoppen
make git-status       # Status prüfen
make git-logs         # Logs anzeigen
make git-demo         # Interaktive Demo

# Repository Management
make git-push-to-local USER=username REPO_NAME=projekt
make git-clone-local USER=username REPO_NAME=projekt
make git-set-local-origin USER=username REPO_NAME=projekt

# Wartung
make git-backup       # Backup erstellen
make git-update       # Server aktualisieren
make git-clean        # Alles zurücksetzen
```

---

## 🎉 Fazit

Der **GENTLEMAN Git-Server auf dem M1 Mac** bietet:

✅ **Optimale Performance** durch Apple Silicon  
✅ **Zentrale Verwaltung** aller Git-Repositories  
✅ **Nahtlose Integration** in den Development-Workflow  
✅ **Sichere Netzwerk-Architektur** mit SSL/TLS  
✅ **Automatische Backups** über Time Machine  
✅ **Professionelle Features** wie bei GitHub  

**Dein lokales GitHub auf dem M1 Mac ist bereit! 🍎🎩** 