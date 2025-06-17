# 🔐 GENTLEMAN Authentication System

## Übersicht

Das GENTLEMAN Authentication System bietet eine moderne, zentralisierte Lösung für Benutzer- und Passwort-Verwaltung in Ihrem Homelab. Als moderne Alternative zu noMAD verwendet es **Keycloak** als Identity Provider mit LDAP-Backup für maximale Kompatibilität.

## 🎯 Warum Keycloak statt noMAD?

### ✅ **Vorteile von Keycloak:**
- **Modern & Aktiv entwickelt**: Regelmäßige Updates und Security-Patches
- **OpenID Connect & OAuth 2.0**: Moderne Authentifizierungsstandards
- **Multi-Protocol Support**: SAML, LDAP, Kerberos, Social Login
- **Web-basierte Administration**: Keine Client-Software erforderlich
- **Docker-native**: Perfekt für Container-Umgebungen
- **ARM64 Support**: Läuft nativ auf Apple Silicon
- **Enterprise-grade**: Von Red Hat entwickelt und unterstützt

### ❌ **Probleme mit noMAD:**
- Entwicklung eingestellt (deprecated)
- Nur macOS-spezifisch
- Begrenzte Integration mit modernen Services
- Keine Container-Unterstützung

## 🏗️ Architektur

```
┌─────────────────────────────────────────────────────────────┐
│                    🎩 GENTLEMAN Auth System                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────┐ │
│  │  Keycloak   │◄──►│  Auth Sync   │◄──►│   OpenLDAP      │ │
│  │ (Primary)   │    │   Service    │    │  (Backup)       │ │
│  └─────────────┘    └──────────────┘    └─────────────────┘ │
│         │                   │                      │        │
│         ▼                   ▼                      ▼        │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Homelab Services                           │ │
│  │  • Gitea      • Nextcloud    • Grafana                 │ │
│  │  • Jellyfin   • Home Assistant • Vaultwarden           │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Installation

### 1. **Automatische Installation**
```bash
# Auth-System einrichten
./scripts/auth/setup-auth.sh
```

### 2. **Manuelle Installation**
```bash
# Docker-Netzwerk erstellen
docker network create gentleman-auth --driver bridge --subnet=172.24.0.0/16

# Services starten
docker-compose -f docker-compose.auth.yml --env-file .env.auth up -d
```

## 🔧 Konfiguration

### **Hosts-Datei aktualisieren**
```bash
sudo nano /etc/hosts

# Folgende Zeilen hinzufügen:
127.0.0.1 auth.gentleman.local
127.0.0.1 ldap.gentleman.local
```

### **Keycloak Initial Setup**
1. **Keycloak Admin Console öffnen**: http://auth.gentleman.local:8085
2. **Anmelden**: admin / GentlemanAuth2024!
3. **Realm erstellen**: "gentleman-homelab"
4. **Benutzer anlegen**
5. **Service-Clients konfigurieren**

### **Service Integration**

#### **Gitea (Git Server)**
```yaml
# In Gitea Admin Panel
Authentication Sources → Add Authentication Source
Type: OAuth2
Name: Keycloak
Provider: OpenID Connect
Client ID: gitea-client
Client Secret: [aus Keycloak kopieren]
OpenID Connect Auto Discovery URL: http://auth.gentleman.local:8085/realms/gentleman-homelab/.well-known/openid_configuration
```

#### **Nextcloud**
```bash
# OIDC App installieren
docker exec -it gentleman-nextcloud occ app:install user_oidc

# Konfiguration
Provider Name: Keycloak
Identifier: keycloak
Client ID: nextcloud-client
Client Secret: [aus Keycloak kopieren]
Discovery URL: http://auth.gentleman.local:8085/realms/gentleman-homelab/.well-known/openid_configuration
```

#### **Grafana**
```yaml
# In grafana.ini oder Environment Variables
[auth.generic_oauth]
enabled = true
name = Keycloak
allow_sign_up = true
client_id = grafana-client
client_secret = [aus Keycloak kopieren]
scopes = openid profile email
auth_url = http://auth.gentleman.local:8085/realms/gentleman-homelab/protocol/openid-connect/auth
token_url = http://auth.gentleman.local:8085/realms/gentleman-homelab/protocol/openid-connect/token
api_url = http://auth.gentleman.local:8085/realms/gentleman-homelab/protocol/openid-connect/userinfo
```

## 👥 Benutzer- und Gruppenverwaltung

### **Standard-Gruppen**
- **homelab-admins**: Vollzugriff auf alle Services
- **homelab-users**: Standard-Zugriff
- **media-users**: Nur Media-Services (Jellyfin)

### **Benutzer anlegen**
1. Keycloak Admin Console → Users → Add User
2. Benutzerdaten eingeben
3. Credentials → Set Password
4. Groups → Join Group

### **Service-spezifische Rollen**
```yaml
Gitea:
  - admin: Repository-Administration
  - user: Standard Git-Zugriff
  - readonly: Nur Lese-Zugriff

Nextcloud:
  - admin: Nextcloud-Administration
  - user: Standard Cloud-Zugriff

Grafana:
  - admin: Dashboard-Administration
  - editor: Dashboard bearbeiten
  - viewer: Nur anzeigen
```

## 🔄 macOS Integration

### **Option 1: Jamf Connect (Empfohlen)**
```bash
# Jamf Connect für moderne macOS-Integration
# Unterstützt OIDC und moderne Auth-Flows
# Kommerzielle Lösung mit Support
```

### **Option 2: NoMAD Login AD**
```bash
# Open-Source Alternative
# Begrenzte Funktionalität
# Community-Support
```

### **Option 3: Native macOS (Manuell)**
```bash
# Kerberos-Konfiguration
sudo nano /etc/krb5.conf

[libdefaults]
    default_realm = GENTLEMAN.LOCAL
    
[realms]
    GENTLEMAN.LOCAL = {
        kdc = auth.gentleman.local
        admin_server = auth.gentleman.local
    }
```

## 🛠️ Management & Wartung

### **Service-Status prüfen**
```bash
# Alle Auth-Services
docker-compose -f docker-compose.auth.yml ps

# Logs anzeigen
docker-compose -f docker-compose.auth.yml logs -f

# Einzelner Service
docker logs gentleman-keycloak -f
```

### **Backup & Restore**
```bash
# Keycloak Backup
docker exec gentleman-keycloak /opt/keycloak/bin/kc.sh export --realm gentleman-homelab --file /tmp/realm-backup.json

# LDAP Backup
docker exec gentleman-openldap slapcat -n 0 > ldap-config-backup.ldif
docker exec gentleman-openldap slapcat -n 1 > ldap-data-backup.ldif
```

### **Updates**
```bash
# Services aktualisieren
docker-compose -f docker-compose.auth.yml pull
docker-compose -f docker-compose.auth.yml up -d
```

## 🔍 Troubleshooting

### **Häufige Probleme**

#### **Keycloak startet nicht**
```bash
# Logs prüfen
docker logs gentleman-keycloak

# Häufige Ursachen:
# - Datenbank nicht erreichbar
# - Falsche Umgebungsvariablen
# - Port bereits belegt
```

#### **Service-Integration funktioniert nicht**
```bash
# Client-Konfiguration prüfen
# - Redirect URIs korrekt?
# - Client Secret aktuell?
# - Discovery URL erreichbar?

# Test mit curl
curl http://auth.gentleman.local:8085/realms/gentleman-homelab/.well-known/openid_configuration
```

#### **LDAP-Verbindung fehlschlägt**
```bash
# LDAP-Server testen
ldapsearch -x -H ldap://localhost:389 -D "cn=admin,dc=gentleman,dc=local" -W -b "dc=gentleman,dc=local"

# Zertifikate prüfen
openssl x509 -in config/security/certs/ldap.crt -text -noout
```

## 📊 Monitoring & Metriken

### **Keycloak Metriken**
- Login-Erfolg/Fehler-Rate
- Aktive Sessions
- Token-Ausstellung
- Realm-Statistiken

### **Integration in Grafana**
```yaml
# Prometheus Scrape Config
- job_name: 'keycloak'
  static_configs:
    - targets: ['keycloak:8080']
  metrics_path: '/metrics'
```

## 🔐 Sicherheit

### **Best Practices**
- **Starke Passwörter**: Mindestens 12 Zeichen
- **2FA aktivieren**: Für Admin-Accounts
- **Session-Timeouts**: Kurze Timeouts für sensible Services
- **Audit-Logging**: Alle Auth-Events protokollieren
- **Regelmäßige Updates**: Security-Patches zeitnah einspielen

### **Netzwerk-Sicherheit**
```yaml
# Firewall-Regeln
- Port 8085: Nur lokales Netzwerk
- Port 389/636: Nur Auth-Services
- Port 8091: Nur localhost
```

## 🎯 Nächste Schritte

1. **✅ Auth-System installieren**
2. **🔧 Services konfigurieren**
3. **👥 Benutzer anlegen**
4. **🔄 macOS-Integration einrichten**
5. **📊 Monitoring aktivieren**
6. **🔐 Security-Audit durchführen**

---

## 🆘 Support

Bei Problemen:
1. **Logs prüfen**: `docker-compose -f docker-compose.auth.yml logs`
2. **Service-Status**: `docker-compose -f docker-compose.auth.yml ps`
3. **Auth Sync API**: http://localhost:8091/health
4. **Keycloak Admin**: http://auth.gentleman.local:8085

**Das GENTLEMAN Authentication System bietet Ihnen eine moderne, sichere und skalierbare Lösung für die zentrale Benutzer- und Passwort-Verwaltung in Ihrem Homelab! 🎩** 