# 🎩 GENTLEMAN Git Server

**Lokaler Git-Server mit Gitea für maximale Kontrolle und Sicherheit im Heimnetzwerk**

## 🌟 Features

- **🔒 Vollständig lokal**: Keine externen Abhängigkeiten
- **🌐 Web-Interface**: Moderne Git-Verwaltung mit Gitea
- **🔐 SSL/TLS verschlüsselt**: Sichere Verbindungen
- **💾 Automatische Backups**: Tägliche Sicherungen
- **📊 Monitoring**: Integrierte Überwachung
- **🐳 Docker-basiert**: Einfache Installation und Wartung

## 🚀 Schnellstart

### 1. Git-Server einrichten
```bash
make git-setup
```

### 2. Git-Server starten
```bash
make git-start
```

### 3. Web-Interface öffnen
Öffne in deinem Browser: **https://git.gentleman.local**

## 📋 Verfügbare Befehle

### 🏗️ Setup & Management
```bash
make git-setup      # Erstmalige Einrichtung
make git-start      # Server starten
make git-stop       # Server stoppen
make git-restart    # Server neustarten
make git-status     # Status anzeigen
make git-logs       # Logs anzeigen
make git-update     # Server aktualisieren
make git-clean      # Alles löschen (Vorsicht!)
```

### 💾 Backup & Wartung
```bash
make git-backup     # Manuelles Backup erstellen
make git-shell      # Shell im Container öffnen
```

### 📚 Repository Management
```bash
# Repository erstellen (über Web-Interface)
make git-create-repo REPO_NAME=mein-projekt

# Von lokalem Server klonen
make git-clone-local USER=username REPO_NAME=mein-projekt

# Zu lokalem Server pushen
make git-push-to-local USER=username REPO_NAME=mein-projekt

# Lokalen Server als Origin setzen
make git-set-local-origin USER=username REPO_NAME=mein-projekt
```

## 🌐 Zugriff

### Web-Interface
- **Haupt-URL**: https://git.gentleman.local
- **Direkt-URL**: https://gitea.gentleman.local:3000

### SSH Git Access
```bash
# SSH-Klon
git clone ssh://git@gitea.gentleman.local:2222/username/repository.git

# SSH-Remote hinzufügen
git remote add origin ssh://git@gitea.gentleman.local:2222/username/repository.git
```

### HTTPS Git Access
```bash
# HTTPS-Klon
git clone https://git.gentleman.local/username/repository.git

# HTTPS-Remote hinzufügen
git remote add origin https://git.gentleman.local/username/repository.git
```

## 🔐 Erstmalige Konfiguration

### 1. Admin-Account erstellen
1. Öffne https://git.gentleman.local
2. Folge dem Setup-Assistenten
3. Erstelle deinen Admin-Account
4. **Wichtig**: Ändere das Standard-Passwort!

### 2. Sicherheitseinstellungen
- ✅ 2FA aktivieren
- ✅ SSH-Keys hinzufügen
- ✅ Starke Passwörter verwenden
- ✅ Private Repositories als Standard

### 3. Hosts-Datei konfigurieren
Füge zu `/etc/hosts` hinzu:
```
127.0.0.1 git.gentleman.local
127.0.0.1 gitea.gentleman.local
```

## 🏗️ Architektur

### Services
- **Gitea**: Git-Server mit Web-Interface (Port 3000)
- **PostgreSQL**: Datenbank für Gitea
- **Nginx**: Reverse Proxy mit SSL (Port 80/443)
- **Backup Service**: Automatische tägliche Backups
- **Monitoring**: Prometheus Exporter (Port 9100)

### Netzwerk
- **Git Network**: 172.21.1.0/24
- **Mesh Integration**: 172.20.3.0/24

### Volumes
- `gitea-data`: Repository-Daten
- `gitea-config`: Konfigurationsdateien
- `gitea-db-data`: Datenbankdaten
- `gitea-backups`: Backup-Archive

## 💾 Backup & Wiederherstellung

### Automatische Backups
- **Intervall**: Täglich (24h)
- **Aufbewahrung**: 30 Tage
- **Speicherort**: `gitea-backups` Volume
- **Inhalt**: Datenbank + Repository-Daten

### Manuelles Backup
```bash
make git-backup
```

### Backup-Verzeichnis anzeigen
```bash
docker volume inspect gentleman_gitea-backups
```

### Wiederherstellung
```bash
# 1. Service stoppen
make git-stop

# 2. Backup-Archiv extrahieren
tar -xzf backup_file.tar.gz

# 3. Datenbank wiederherstellen
pg_restore -h localhost -U gitea -d gitea database.dump

# 4. Daten wiederherstellen
# (Details im Backup-Skript)

# 5. Service starten
make git-start
```

## 🔒 Sicherheit

### SSL/TLS
- **Zertifikate**: Selbst-signiert (für lokales Netzwerk)
- **Protokolle**: TLSv1.2, TLSv1.3
- **Cipher Suites**: Moderne, sichere Verschlüsselung

### Netzwerk-Sicherheit
- **Firewall**: Nur notwendige Ports geöffnet
- **VPN Integration**: Nebula Mesh Network
- **Isolation**: Separate Docker-Netzwerke

### Authentifizierung
- **Lokale Accounts**: Keine externe Abhängigkeiten
- **SSH-Keys**: Empfohlen für Git-Operationen
- **2FA**: Unterstützt (TOTP)

## 🔧 Konfiguration

### Umgebungsvariablen
Konfiguration in `.env.git-server`:
```bash
# Datenbank
GITEA_DB_PASSWORD=secure_password

# Gitea Sicherheit
GITEA_SECRET_KEY=generated_secret
GITEA_INTERNAL_TOKEN=generated_token

# Netzwerk
GITEA_DOMAIN=gitea.gentleman.local
GITEA_ROOT_URL=https://gitea.gentleman.local:3000

# Backup
BACKUP_RETENTION=30
BACKUP_INTERVAL=86400
```

### Gitea-Konfiguration
Erweiterte Konfiguration über Web-Interface oder `app.ini`:
- Repository-Einstellungen
- Benutzer-Registrierung (deaktiviert)
- Webhook-Konfiguration
- E-Mail-Einstellungen

## 🐛 Troubleshooting

### Service startet nicht
```bash
# Logs prüfen
make git-logs

# Status prüfen
make git-status

# Container neu starten
make git-restart
```

### SSL-Zertifikat-Fehler
```bash
# Neue Zertifikate generieren
rm -rf config/security/ssl/gentleman.*
make git-setup
```

### Datenbank-Probleme
```bash
# Datenbank-Container prüfen
docker-compose -f docker-compose.git-server.yml logs gitea-db

# Datenbank-Shell öffnen
docker-compose -f docker-compose.git-server.yml exec gitea-db psql -U gitea -d gitea
```

### Port-Konflikte
Ports ändern in `docker-compose.git-server.yml`:
- Web: 3000 → 3001
- SSH: 2222 → 2223
- HTTP: 80 → 8080
- HTTPS: 443 → 8443

## 📊 Monitoring

### Health Checks
```bash
# Service-Status
curl -f https://git.gentleman.local/nginx-health

# Gitea API
curl -f https://gitea.gentleman.local:3000/api/healthz

# Datenbank
docker-compose -f docker-compose.git-server.yml exec gitea-db pg_isready
```

### Metriken
- **Prometheus Exporter**: Port 9100
- **Grafana Integration**: Möglich
- **Log-Aggregation**: Docker Logs

## 🔄 Updates

### Gitea aktualisieren
```bash
make git-update
```

### Manuelle Updates
```bash
# Images aktualisieren
docker-compose -f docker-compose.git-server.yml pull

# Services neu starten
docker-compose -f docker-compose.git-server.yml up -d
```

## 🌐 Integration

### Mit GENTLEMAN System
- **Nebula VPN**: Automatische Integration
- **Matrix Authorization**: Geplant
- **Monitoring**: Prometheus/Grafana
- **Backup**: Zentrale Backup-Strategie

### Mit externen Tools
- **IDE Integration**: VS Code, IntelliJ
- **CI/CD**: Gitea Actions, Jenkins
- **Webhooks**: Automatisierung möglich

## 📝 Best Practices

### Repository-Management
- ✅ Private Repositories als Standard
- ✅ Branching-Strategien definieren
- ✅ Commit-Message-Konventionen
- ✅ Code-Review-Prozesse

### Sicherheit
- ✅ Regelmäßige Backups prüfen
- ✅ SSL-Zertifikate erneuern
- ✅ Benutzer-Zugriffsrechte überprüfen
- ✅ Logs überwachen

### Performance
- ✅ Repository-Größe überwachen
- ✅ Datenbank-Performance prüfen
- ✅ Backup-Zeiten optimieren
- ✅ Netzwerk-Latenz minimieren

## 🆘 Support

### Logs sammeln
```bash
# Alle Service-Logs
make git-logs > git-server-logs.txt

# System-Informationen
docker system info > system-info.txt
docker-compose -f docker-compose.git-server.yml config > config-dump.yml
```

### Häufige Probleme
1. **Browser-Zertifikat-Warnung**: Normal bei selbst-signierten Zertifikaten
2. **SSH-Verbindung fehlschlägt**: SSH-Key korrekt konfiguriert?
3. **Langsame Performance**: Festplattenspeicher prüfen
4. **Backup-Fehler**: Berechtigungen und Speicherplatz prüfen

---

## 🎯 Nächste Schritte

Nach der Einrichtung:

1. **Repository erstellen**: Erstes Projekt anlegen
2. **SSH-Keys konfigurieren**: Für sichere Git-Operationen
3. **Backup testen**: Wiederherstellung einmal durchführen
4. **Monitoring einrichten**: Grafana-Dashboard konfigurieren
5. **Team einladen**: Weitere Benutzer hinzufügen

**Viel Spaß mit deinem lokalen Git-Server! 🎩** 