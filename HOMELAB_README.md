# 🎩 GENTLEMAN - Complete Homelab Setup

Ein vollständiges Self-Hosting-Ecosystem für maximale Privatsphäre und Kontrolle über Ihre Daten.

## 🌟 Übersicht

Das GENTLEMAN Homelab ist eine umfassende Self-Hosting-Lösung, die alle wichtigen Services für ein modernes digitales Leben bereitstellt:

### 🏠 **Core Services**
- **🏠 Home Assistant** - Smart Home Zentrale
- **📚 Gitea** - Privater Git-Server für Ihre Repositories
- **☁️ Nextcloud** - Private Cloud-Lösung
- **📧 ProtonMail Bridge** - Sichere E-Mail-Integration
- **🔐 Vaultwarden** - Passwort-Manager (Bitwarden-kompatibel)

### 🛡️ **Security & Infrastructure**
- **🛡️ Pi-hole** - DNS-basierter Ad-Blocker
- **🌐 Traefik** - Reverse Proxy mit automatischen SSL-Zertifikaten
- **📊 TrueNAS Integration** - NAS-Synchronisation und Backup
- **🔄 Watchtower** - Automatische Container-Updates

### 📊 **Monitoring & Media**
- **📊 Prometheus + Grafana** - Umfassendes Monitoring
- **📝 Loki** - Log-Aggregation
- **🎬 Jellyfin** - Media-Server
- **🏥 Healthchecks** - Service-Überwachung

## 🚀 Quick Start

### 1. Basis-Setup ausführen
```bash
# Erst das grundlegende GENTLEMAN-System einrichten
./setup.sh
```

### 2. Homelab-Setup starten
```bash
# Homelab-Erweiterung installieren
chmod +x setup-homelab.sh
./setup-homelab.sh
```

### 3. Konfiguration anpassen
```bash
# Umgebungsvariablen bearbeiten
nano .env.homelab
```

### 4. Hosts-Datei aktualisieren
```bash
# Hosts-Einträge hinzufügen
sudo nano /etc/hosts

# Diese Zeilen hinzufügen:
127.0.0.1 git.gentleman.local
127.0.0.1 cloud.gentleman.local
127.0.0.1 ha.gentleman.local
127.0.0.1 media.gentleman.local
127.0.0.1 vault.gentleman.local
127.0.0.1 dns.gentleman.local
127.0.0.1 proxy.gentleman.local
127.0.0.1 health.gentleman.local
127.0.0.1 bridge.gentleman.local
```

### 5. Homelab starten
```bash
./scripts/homelab/start.sh
```

## 🌐 Service-Zugriff

Nach dem Start sind alle Services über folgende URLs erreichbar:

| Service | URL | Beschreibung |
|---------|-----|--------------|
| **Git Server** | http://git.gentleman.local:3000 | Private Git-Repositories |
| **Nextcloud** | http://cloud.gentleman.local:8080 | Private Cloud-Storage |
| **Home Assistant** | http://ha.gentleman.local:8123 | Smart Home Zentrale |
| **Media Server** | http://media.gentleman.local:8096 | Jellyfin Media-Streaming |
| **Password Manager** | http://vault.gentleman.local:8082 | Vaultwarden (Bitwarden) |
| **DNS Admin** | http://dns.gentleman.local:8081 | Pi-hole Administration |
| **Monitoring** | http://localhost:3001 | Grafana Dashboards |
| **Proxy Dashboard** | http://proxy.gentleman.local:8083 | Traefik Dashboard |
| **Health Monitor** | http://health.gentleman.local:8084 | Service-Überwachung |
| **Homelab Bridge** | http://bridge.gentleman.local:8090 | Service-Integration |

## 🔧 Management-Befehle

```bash
# Homelab starten
./scripts/homelab/start.sh

# Homelab stoppen
./scripts/homelab/stop.sh

# Status anzeigen
./scripts/homelab/status.sh

# Services aktualisieren
./scripts/homelab/update.sh

# Backup erstellen
./scripts/homelab/backup.sh
```

## 📋 Erstmalige Konfiguration

### 🔐 Sicherheit (WICHTIG!)
1. **Passwörter ändern**: Alle Standard-Passwörter in `.env.homelab` ändern
2. **2FA aktivieren**: Für alle Services, die es unterstützen
3. **SSL-Zertifikate**: Traefik generiert automatisch Let's Encrypt-Zertifikate

### 📚 Git Server (Gitea)
1. Öffne http://git.gentleman.local:3000
2. Folge dem Setup-Assistenten
3. Erstelle Admin-Account
4. Generiere API-Token und füge ihn zu `.env.homelab` hinzu

### ☁️ Nextcloud
1. Öffne http://cloud.gentleman.local:8080
2. Verwende Admin-Credentials aus `.env.homelab`
3. Installiere gewünschte Apps
4. Konfiguriere externe Speicher (optional)

### 🏠 Home Assistant
1. Öffne http://ha.gentleman.local:8123
2. Erstelle Admin-Account
3. Generiere Long-Lived Access Token
4. Füge Token zu `.env.homelab` hinzu
5. Konfiguriere Geräte und Automatisierungen

### 📧 ProtonMail Bridge
1. ProtonMail-Credentials in `.env.homelab` eintragen
2. Bridge startet automatisch
3. SMTP: localhost:1025, IMAP: localhost:1143
4. Verwende diese Einstellungen in anderen Services

### 🔐 Vaultwarden (Passwort-Manager)
1. Öffne http://vault.gentleman.local:8082
2. Erstelle ersten Benutzer-Account
3. Installiere Bitwarden-Client-Apps
4. Konfiguriere Server-URL in den Apps

## 🔗 Service-Integration

### 🤖 AI-Integration
- **LLM-Server**: Alle Services können den GENTLEMAN LLM-Server nutzen
- **STT/TTS**: Spracherkennung und -synthese für Home Assistant
- **Automatisierung**: KI-gestützte Entscheidungen in Home Assistant

### 📊 TrueNAS/FreeNAS Integration
```yaml
# config/homelab/truenas.yml
truenas:
  host: truenas.local
  api_key: "your-api-key"
  
sync:
  datasets:
    - gentleman/models    # AI-Modelle
    - gentleman/media     # Media-Dateien
    - gentleman/backups   # Backups
```

### 📧 E-Mail-Integration
- **ProtonMail Bridge** stellt SMTP/IMAP bereit
- **Watchtower** sendet Update-Benachrichtigungen
- **Healthchecks** sendet Alarm-E-Mails
- **Home Assistant** kann E-Mails versenden

## 📊 Monitoring & Logs

### Grafana Dashboards
- **System-Übersicht**: CPU, RAM, Disk, Netzwerk
- **Service-Health**: Status aller Container
- **AI-Performance**: LLM/STT/TTS Metriken
- **Smart Home**: Home Assistant Daten
- **Security**: Fehlgeschlagene Logins, Anomalien

### Log-Aggregation
- **Loki** sammelt alle Container-Logs
- **Grafana** visualisiert Log-Daten
- **Alerting** bei kritischen Ereignissen

## 🔄 Backup-Strategie

### Automatische Backups
- **Täglich**: Alle Konfigurationen und Datenbanken
- **Wöchentlich**: Vollständige Volume-Backups
- **TrueNAS-Sync**: Kontinuierliche Synchronisation wichtiger Daten

### Backup-Inhalte
- Konfigurationsdateien
- Datenbank-Dumps
- Docker-Volumes
- SSL-Zertifikate
- Umgebungsvariablen

## 🛠️ Troubleshooting

### Häufige Probleme

**Services starten nicht:**
```bash
# Logs prüfen
docker-compose -f docker-compose.homelab.yml logs [service-name]

# Container-Status prüfen
docker ps -a
```

**Netzwerk-Probleme:**
```bash
# Docker-Netzwerke prüfen
docker network ls

# Netzwerke neu erstellen
docker network prune
./setup-homelab.sh
```

**Speicherplatz-Probleme:**
```bash
# Docker aufräumen
docker system prune -a

# Alte Volumes entfernen
docker volume prune
```

### Service-spezifische Probleme

**Gitea-Datenbank-Verbindung:**
```bash
# Datenbank-Container prüfen
docker logs gentleman-gitea-db

# Verbindung testen
docker exec -it gentleman-gitea-db psql -U gitea -d gitea
```

**Home Assistant-Geräte:**
```bash
# USB-Geräte prüfen
ls -la /dev/ttyUSB*

# Container-Berechtigungen prüfen
docker exec -it gentleman-homeassistant ls -la /dev/
```

## 🔒 Sicherheits-Best-Practices

### Netzwerk-Sicherheit
- **Firewall**: Nur notwendige Ports öffnen
- **VPN**: Zugriff über Nebula Mesh Network
- **SSL**: Alle Services über HTTPS
- **Isolation**: Services in separaten Docker-Netzwerken

### Authentifizierung
- **Starke Passwörter**: Mindestens 16 Zeichen
- **2FA**: Überall wo möglich aktivieren
- **API-Keys**: Regelmäßig rotieren
- **Session-Management**: Kurze Timeouts

### Daten-Schutz
- **Verschlüsselung**: Daten at-rest und in-transit
- **Backups**: Verschlüsselt und getestet
- **Zugriffskontrolle**: Principle of least privilege
- **Audit-Logs**: Alle Zugriffe protokollieren

## 🚀 Erweiterte Features

### Custom Services hinzufügen
```yaml
# docker-compose.homelab.yml erweitern
my-custom-service:
  image: my-app:latest
  container_name: gentleman-my-app
  networks:
    - homelab
  ports:
    - "8090:8080"
```

### Externe Integration
- **Matrix-Server**: Für sichere Kommunikation
- **LDAP/Active Directory**: Zentrale Benutzerverwaltung
- **Backup-Provider**: S3-kompatible Speicher
- **Monitoring-Alerts**: Slack, Discord, Teams

### Performance-Optimierung
- **SSD-Storage**: Für Datenbanken und häufig genutzte Daten
- **RAM-Disk**: Für temporäre Dateien
- **Load-Balancing**: Für hochverfügbare Services
- **Caching**: Redis/Memcached für bessere Performance

## 📞 Support & Community

### Dokumentation
- **Service-Docs**: Jeder Service hat eigene Dokumentation
- **API-Referenz**: Für Entwickler und Automatisierung
- **Video-Tutorials**: Schritt-für-Schritt-Anleitungen

### Community
- **GitHub Issues**: Bug-Reports und Feature-Requests
- **Discord**: Community-Chat und Support
- **Wiki**: Erweiterte Konfigurationsbeispiele

---

## 🎯 Nächste Schritte

1. **Setup abschließen**: Alle Services konfigurieren
2. **Daten migrieren**: Bestehende Daten importieren
3. **Automatisierung**: Home Assistant-Regeln erstellen
4. **Monitoring**: Dashboards anpassen
5. **Backup testen**: Wiederherstellung üben
6. **Sicherheit härten**: Alle Empfehlungen umsetzen

**Viel Spaß mit Ihrem privaten Homelab! 🎩** 