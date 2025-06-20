# 📱 GENTLEMAN M1 Mobile Access Setup Guide

## 🎯 Ziel
Den GENTLEMAN M1 Mac über mobile Daten von überall erreichbar machen.

---

## 📊 Aktueller Status

### ✅ Was funktioniert:
- **M1 Mac lokale IP**: 192.168.68.105 
- **Öffentliche IP**: 46.57.127.25
- **Router Gateway**: 192.168.68.1
- **Services laufen lokal**:
  - Handshake Server: Port 8765 ✅
  - Git Daemon: Port 9418 ✅  
  - Gitea Docker: Port 3010 ✅

### ❌ Was fehlt:
- Externe Erreichbarkeit (Port-Forwarding oder Tunnel)

---

## 🚀 Option 1: ngrok Tunnel (Schnelltest)

### Setup:
```bash
# 1. Registriere dich kostenlos
open https://ngrok.com/signup

# 2. Hole Authtoken aus Dashboard und konfiguriere
ngrok config add-authtoken [DEIN_AUTHTOKEN]

# 3. Starte Tunnel für Handshake Service
ngrok http 8765
```

### Nach dem Start:
- ngrok zeigt öffentliche URL an (z.B. `https://abc123.ngrok.io`)
- Diese URL ist von überall erreichbar
- Teste mit: `curl https://abc123.ngrok.io/health`

### Für alle Services:
```bash
# Terminal 1: Handshake
ngrok http 8765

# Terminal 2: Git Daemon  
ngrok tcp 9418

# Terminal 3: Gitea
ngrok http 3010
```

---

## 🔧 Option 2: Router Port-Forwarding (Dauerhaft)

### Router Zugang:
```bash
# Öffne Router Admin Panel
open http://192.168.68.1
```

### Port-Forwarding Konfiguration:
| Service | Extern | Intern | Protokoll |
|---------|--------|--------|-----------|
| Handshake | 8765 | 192.168.68.105:8765 | TCP |
| Git Daemon | 9418 | 192.168.68.105:9418 | TCP |
| Gitea | 3010 | 192.168.68.105:3010 | TCP |

### Nach Konfiguration:
- **Handshake**: `http://46.57.127.25:8765/health`
- **Gitea**: `http://46.57.127.25:3010`
- **Git Clone**: `git://46.57.127.25:9418/Gentleman`

---

## 🛡️ Option 3: Tailscale VPN (Empfohlen)

### Installation:
```bash
# Installiere Tailscale
brew install tailscale

# Starte Tailscale
sudo tailscale up

# Hole Tailscale IP
tailscale ip -4
```

### Vorteile:
- ✅ Ende-zu-Ende verschlüsselt
- ✅ Keine Port-Öffnung erforderlich
- ✅ Automatische Peer-to-Peer Verbindung
- ✅ Geräte-übergreifend verfügbar

### Zugriff:
- Nach Setup erhältst du eine Tailscale IP (z.B. 100.x.x.x)
- Services sind unter dieser IP erreichbar
- Nur deine Geräte haben Zugriff

---

## 🧪 Sofortiger Test

### Aktueller Test-Status:
```bash
# Führe Mobile Access Test aus
./mobile_access_test.sh
```

### RX Node Verbindung:
Ich sehe in den Logs, dass die RX Node (192.168.68.117) bereits versucht, sich zu verbinden:
```
Exception occurred during processing of request from ('192.168.68.117', 46164)
```

Das bedeutet:
- ✅ RX Node findet den M1 Mac im lokalen Netz
- ✅ Handshake Server läuft und akzeptiert Verbindungen
- ⚠️ Verbindung wird unterbrochen (Socket not connected)

---

## 🔄 Schneller Start

### 1. Für sofortigen Test (ngrok):
```bash
# Registriere dich auf ngrok.com
# Hole Authtoken und führe aus:
ngrok config add-authtoken [TOKEN]
ngrok http 8765

# Teste dann mit der angezeigten URL
```

### 2. Für permanente Lösung (Router):
```bash
# Öffne Router Admin Panel
open http://192.168.68.1

# Konfiguriere Port-Forwarding wie oben beschrieben
```

### 3. Für sichere Lösung (Tailscale):
```bash
brew install tailscale
sudo tailscale up
# Folge den Anweisungen zur Geräte-Authentifizierung
```

---

## 📲 Mobile Client URLs

### Nach erfolgreichem Setup:

#### Mit ngrok:
- **Handshake**: `https://[RANDOM].ngrok.io/health`
- **Gitea**: `https://[RANDOM2].ngrok.io`

#### Mit Port-Forwarding:
- **Handshake**: `http://46.57.127.25:8765/health`
- **Gitea**: `http://46.57.127.25:3010`
- **Git Clone**: `git://46.57.127.25:9418/Gentleman`

#### Mit Tailscale:
- **Handshake**: `http://[TAILSCALE-IP]:8765/health`
- **Gitea**: `http://[TAILSCALE-IP]:3010`
- **Git Clone**: `git://[TAILSCALE-IP]:9418/Gentleman`

---

## 🔒 Sicherheitshinweise

1. **ngrok**: Temporär, für Tests geeignet
2. **Port-Forwarding**: Öffnet Ports ins Internet - Firewall empfohlen
3. **Tailscale**: Sicherste Option, keine Port-Öffnung erforderlich

---

## 🚨 Troubleshooting

### Handshake Server Probleme:
```bash
# Starte Handshake Server neu
pkill -f "talking_gentleman_protocol.py"
python3 talking_gentleman_protocol.py --start &
```

### Git Daemon Probleme:
```bash
# Starte Git Daemon neu
pkill -f "git daemon"
git daemon --verbose --export-all --base-path=/Users/amonbaumgartner --reuseaddr --port=9418 &
```

### Teste lokale Services:
```bash
# Alle Services testen
./mobile_access_test.sh
``` 