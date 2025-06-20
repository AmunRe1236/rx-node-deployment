# GENTLEMAN Tailscale Setup Guide

## 🎯 Übersicht

Komplette Anleitung zur Einrichtung von Tailscale für das GENTLEMAN System mit M1 Mac und RX Node.

### 📋 Hardware Setup
- **M1 Mac**: 192.168.68.111 (Home) → Tailscale IP wird vergeben
- **RX Node**: 192.168.68.117 (Home) → Tailscale IP wird vergeben  
- **iPhone**: Bereits in Tailscale (100.123.55.36)
- **Account**: baumgartneramon@gmail.com

---

## 🖥️ M1 Mac Tailscale Setup

### 1. Tailscale Status prüfen
```bash
# Aktueller Status
./tailscale_status.sh

# Sollte zeigen:
# M1 Mac: 100.96.219.28
# iPhone: 100.123.55.36
```

### 2. M1 Mac ist bereits konfiguriert ✅
- Tailscale installiert und aktiv
- Account: baumgartneramon@gmail.com
- IP: 100.96.219.28
- Subnet Routes aktiv

---

## 🖥️ RX Node Tailscale Setup

### Schritt 1: SSH Verbindung zur RX Node
```bash
ssh rx-node
# Verbindet zu amo9n11@192.168.68.117
```

### Schritt 2: Tailscale Installation (Arch Linux)
```bash
# System Update
sudo pacman -Syu

# Tailscale installieren
sudo pacman -S tailscale

# Service aktivieren und starten
sudo systemctl enable tailscaled
sudo systemctl start tailscaled

# Service Status prüfen
systemctl status tailscaled
```

### Schritt 3: Tailscale Netzwerk beitreten
```bash
# Mit Route Advertisement für Home Network
sudo tailscale up --advertise-routes=192.168.68.0/24 --accept-routes
```

**⚠️ Wichtig:** Browser öffnet sich automatisch
- Login mit: `baumgartneramon@gmail.com`
- Device autorisieren
- "Machine authorization" bestätigen

### Schritt 4: Konfiguration verifizieren
```bash
# Tailscale Status
tailscale status

# Eigene IP anzeigen
tailscale ip -4

# Ping Test zum M1 Mac
ping 100.96.219.28

# Ping Test zum iPhone
ping 100.123.55.36
```

### Schritt 5: Firewall Konfiguration (Optional)
```bash
# UFW Status prüfen
sudo ufw status

# Tailscale Interface erlauben (falls UFW aktiv)
sudo ufw allow in on tailscale0
```

---

## 🔧 Troubleshooting

### Problem: Tailscale Service startet nicht
```bash
# Logs prüfen
journalctl -u tailscaled -f

# Service neu starten
sudo systemctl restart tailscaled

# Manuelle Diagnose
sudo tailscale status --self=false
```

### Problem: Browser öffnet sich nicht bei `tailscale up`
```bash
# Manuelle Authentifizierung
sudo tailscale up --authkey=AUTHKEY_FROM_ADMIN_CONSOLE

# Oder Login URL anzeigen lassen
sudo tailscale up --force-reauth
```

### Problem: Keine Verbindung zwischen Nodes
```bash
# Auf beiden Nodes prüfen:
tailscale ping 100.x.x.x

# Route Status prüfen
tailscale status --peers

# Netcheck ausführen
tailscale netcheck
```

---

## 📊 Netzwerk-Architektur nach Setup

### Home Network (192.168.68.0/24)
```
Router: 192.168.68.1
├── M1 Mac: 192.168.68.111 ←→ Tailscale: 100.96.219.28
├── RX Node: 192.168.68.117 ←→ Tailscale: 100.x.x.x (wird vergeben)
└── I7 Laptop: 192.168.68.105 (optional)
```

### Tailscale Network (100.x.x.x/20)
```
Tailnet: baumgartneramon@gmail.com
├── M1 Mac: 100.96.219.28 (advertises 192.168.68.0/24)
├── RX Node: 100.x.x.x (accepts routes)
└── iPhone: 100.123.55.36
```

---

## 🚀 Nach dem Setup verfügbar

### 1. Direkte Node-zu-Node Kommunikation
```bash
# Vom M1 Mac zur RX Node
ssh amo9n11@100.x.x.x  # RX Node Tailscale IP

# Von RX Node zum M1 Mac  
ssh amon@100.96.219.28
```

### 2. Services über Tailscale
```bash
# M1 Handshake Server von RX Node erreichbar
curl http://100.96.219.28:8765/health

# RX Node Services vom M1 Mac erreichbar
curl http://100.x.x.x:8765/health
```

### 3. Hotspot-Modus funktioniert
- M1 Mac im Hotspot: 172.20.10.x
- RX Node weiterhin erreichbar über Tailscale IP
- Keine Port-Forwarding nötig

---

## 🔐 Sicherheit & Best Practices

### Tailscale ACLs (Access Control Lists)
```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["group:gentleman"],
      "dst": ["*:*"]
    }
  ],
  "groups": {
    "group:gentleman": ["baumgartneramon@gmail.com"]
  }
}
```

### SSH Konfiguration über Tailscale
```bash
# ~/.ssh/config auf M1 Mac erweitern
Host rx-node-tailscale
    HostName 100.x.x.x  # RX Node Tailscale IP
    User amo9n11
    IdentityFile ~/.ssh/id_rsa
    Port 22
```

### Automatische Verbindung
```bash
# Tailscale Auto-Start konfigurieren
sudo systemctl enable tailscaled

# Exit Node konfigurieren (optional)
sudo tailscale up --exit-node=100.96.219.28
```

---

## 📱 Mobile Zugriff

### iPhone bereits konfiguriert ✅
- Tailscale App installiert
- Account: baumgartneramon@gmail.com  
- IP: 100.123.55.36

### Zugriff von iPhone
```
# SSH zu M1 Mac
ssh://amon@100.96.219.28

# SSH zu RX Node  
ssh://amo9n11@100.x.x.x

# Web Services
http://100.96.219.28:8765  # M1 Handshake Server
http://100.x.x.x:8765      # RX Node Services
```

---

## 🎯 Nächste Schritte nach Tailscale Setup

### 1. AI Services Setup (RX Node)
- AMD GPU ROCm Installation
- PyTorch mit ROCm Support
- AI Server über Tailscale erreichbar

### 2. Remote Control Enhancement
- Wake-on-LAN über Tailscale
- Remote Shutdown Commands
- Service Monitoring

### 3. Friend Network Integration
- Zusätzliche Tailscale Accounts für Freunde
- Inter-Network Communication
- Shared Services Discovery

---

## 📚 Referenzen

### Tailscale Commands Cheat Sheet
```bash
# Status und Info
tailscale status
tailscale ip -4
tailscale netcheck

# Verbindung
tailscale up
tailscale down
tailscale logout

# Debugging
tailscale ping <ip>
tailscale debug derp
```

### Useful Links
- [Tailscale Admin Console](https://login.tailscale.com/admin/machines)
- [Tailscale Documentation](https://tailscale.com/kb/)
- [ACL Configuration](https://tailscale.com/kb/1018/acls/)

---

## ✅ Setup Verification Checklist

### M1 Mac
- [ ] Tailscale installiert und aktiv
- [ ] IP: 100.96.219.28 erreichbar
- [ ] Subnet Routes advertised
- [ ] SSH zu RX Node funktioniert

### RX Node  
- [ ] Tailscale installiert und aktiv
- [ ] Tailscale IP erhalten
- [ ] Ping zu M1 Mac funktioniert
- [ ] SSH vom M1 Mac funktioniert
- [ ] Routes accepted

### Network Tests
- [ ] M1 ↔ RX Node Ping
- [ ] M1 ↔ iPhone Ping  
- [ ] RX ↔ iPhone Ping
- [ ] Services über Tailscale erreichbar
- [ ] Hotspot-Modus getestet

**🎉 Setup abgeschlossen wenn alle Checkboxen ✅** 

## 🎯 Übersicht

Komplette Anleitung zur Einrichtung von Tailscale für das GENTLEMAN System mit M1 Mac und RX Node.

### 📋 Hardware Setup
- **M1 Mac**: 192.168.68.111 (Home) → Tailscale IP wird vergeben
- **RX Node**: 192.168.68.117 (Home) → Tailscale IP wird vergeben  
- **iPhone**: Bereits in Tailscale (100.123.55.36)
- **Account**: baumgartneramon@gmail.com

---

## 🖥️ M1 Mac Tailscale Setup

### 1. Tailscale Status prüfen
```bash
# Aktueller Status
./tailscale_status.sh

# Sollte zeigen:
# M1 Mac: 100.96.219.28
# iPhone: 100.123.55.36
```

### 2. M1 Mac ist bereits konfiguriert ✅
- Tailscale installiert und aktiv
- Account: baumgartneramon@gmail.com
- IP: 100.96.219.28
- Subnet Routes aktiv

---

## 🖥️ RX Node Tailscale Setup

### Schritt 1: SSH Verbindung zur RX Node
```bash
ssh rx-node
# Verbindet zu amo9n11@192.168.68.117
```

### Schritt 2: Tailscale Installation (Arch Linux)
```bash
# System Update
sudo pacman -Syu

# Tailscale installieren
sudo pacman -S tailscale

# Service aktivieren und starten
sudo systemctl enable tailscaled
sudo systemctl start tailscaled

# Service Status prüfen
systemctl status tailscaled
```

### Schritt 3: Tailscale Netzwerk beitreten
```bash
# Mit Route Advertisement für Home Network
sudo tailscale up --advertise-routes=192.168.68.0/24 --accept-routes
```

**⚠️ Wichtig:** Browser öffnet sich automatisch
- Login mit: `baumgartneramon@gmail.com`
- Device autorisieren
- "Machine authorization" bestätigen

### Schritt 4: Konfiguration verifizieren
```bash
# Tailscale Status
tailscale status

# Eigene IP anzeigen
tailscale ip -4

# Ping Test zum M1 Mac
ping 100.96.219.28

# Ping Test zum iPhone
ping 100.123.55.36
```

### Schritt 5: Firewall Konfiguration (Optional)
```bash
# UFW Status prüfen
sudo ufw status

# Tailscale Interface erlauben (falls UFW aktiv)
sudo ufw allow in on tailscale0
```

---

## 🔧 Troubleshooting

### Problem: Tailscale Service startet nicht
```bash
# Logs prüfen
journalctl -u tailscaled -f

# Service neu starten
sudo systemctl restart tailscaled

# Manuelle Diagnose
sudo tailscale status --self=false
```

### Problem: Browser öffnet sich nicht bei `tailscale up`
```bash
# Manuelle Authentifizierung
sudo tailscale up --authkey=AUTHKEY_FROM_ADMIN_CONSOLE

# Oder Login URL anzeigen lassen
sudo tailscale up --force-reauth
```

### Problem: Keine Verbindung zwischen Nodes
```bash
# Auf beiden Nodes prüfen:
tailscale ping 100.x.x.x

# Route Status prüfen
tailscale status --peers

# Netcheck ausführen
tailscale netcheck
```

---

## 📊 Netzwerk-Architektur nach Setup

### Home Network (192.168.68.0/24)
```
Router: 192.168.68.1
├── M1 Mac: 192.168.68.111 ←→ Tailscale: 100.96.219.28
├── RX Node: 192.168.68.117 ←→ Tailscale: 100.x.x.x (wird vergeben)
└── I7 Laptop: 192.168.68.105 (optional)
```

### Tailscale Network (100.x.x.x/20)
```
Tailnet: baumgartneramon@gmail.com
├── M1 Mac: 100.96.219.28 (advertises 192.168.68.0/24)
├── RX Node: 100.x.x.x (accepts routes)
└── iPhone: 100.123.55.36
```

---

## 🚀 Nach dem Setup verfügbar

### 1. Direkte Node-zu-Node Kommunikation
```bash
# Vom M1 Mac zur RX Node
ssh amo9n11@100.x.x.x  # RX Node Tailscale IP

# Von RX Node zum M1 Mac  
ssh amon@100.96.219.28
```

### 2. Services über Tailscale
```bash
# M1 Handshake Server von RX Node erreichbar
curl http://100.96.219.28:8765/health

# RX Node Services vom M1 Mac erreichbar
curl http://100.x.x.x:8765/health
```

### 3. Hotspot-Modus funktioniert
- M1 Mac im Hotspot: 172.20.10.x
- RX Node weiterhin erreichbar über Tailscale IP
- Keine Port-Forwarding nötig

---

## 🔐 Sicherheit & Best Practices

### Tailscale ACLs (Access Control Lists)
```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["group:gentleman"],
      "dst": ["*:*"]
    }
  ],
  "groups": {
    "group:gentleman": ["baumgartneramon@gmail.com"]
  }
}
```

### SSH Konfiguration über Tailscale
```bash
# ~/.ssh/config auf M1 Mac erweitern
Host rx-node-tailscale
    HostName 100.x.x.x  # RX Node Tailscale IP
    User amo9n11
    IdentityFile ~/.ssh/id_rsa
    Port 22
```

### Automatische Verbindung
```bash
# Tailscale Auto-Start konfigurieren
sudo systemctl enable tailscaled

# Exit Node konfigurieren (optional)
sudo tailscale up --exit-node=100.96.219.28
```

---

## 📱 Mobile Zugriff

### iPhone bereits konfiguriert ✅
- Tailscale App installiert
- Account: baumgartneramon@gmail.com  
- IP: 100.123.55.36

### Zugriff von iPhone
```
# SSH zu M1 Mac
ssh://amon@100.96.219.28

# SSH zu RX Node  
ssh://amo9n11@100.x.x.x

# Web Services
http://100.96.219.28:8765  # M1 Handshake Server
http://100.x.x.x:8765      # RX Node Services
```

---

## 🎯 Nächste Schritte nach Tailscale Setup

### 1. AI Services Setup (RX Node)
- AMD GPU ROCm Installation
- PyTorch mit ROCm Support
- AI Server über Tailscale erreichbar

### 2. Remote Control Enhancement
- Wake-on-LAN über Tailscale
- Remote Shutdown Commands
- Service Monitoring

### 3. Friend Network Integration
- Zusätzliche Tailscale Accounts für Freunde
- Inter-Network Communication
- Shared Services Discovery

---

## 📚 Referenzen

### Tailscale Commands Cheat Sheet
```bash
# Status und Info
tailscale status
tailscale ip -4
tailscale netcheck

# Verbindung
tailscale up
tailscale down
tailscale logout

# Debugging
tailscale ping <ip>
tailscale debug derp
```

### Useful Links
- [Tailscale Admin Console](https://login.tailscale.com/admin/machines)
- [Tailscale Documentation](https://tailscale.com/kb/)
- [ACL Configuration](https://tailscale.com/kb/1018/acls/)

---

## ✅ Setup Verification Checklist

### M1 Mac
- [ ] Tailscale installiert und aktiv
- [ ] IP: 100.96.219.28 erreichbar
- [ ] Subnet Routes advertised
- [ ] SSH zu RX Node funktioniert

### RX Node  
- [ ] Tailscale installiert und aktiv
- [ ] Tailscale IP erhalten
- [ ] Ping zu M1 Mac funktioniert
- [ ] SSH vom M1 Mac funktioniert
- [ ] Routes accepted

### Network Tests
- [ ] M1 ↔ RX Node Ping
- [ ] M1 ↔ iPhone Ping  
- [ ] RX ↔ iPhone Ping
- [ ] Services über Tailscale erreichbar
- [ ] Hotspot-Modus getestet

**🎉 Setup abgeschlossen wenn alle Checkboxen ✅** 
 