# GENTLEMAN WireGuard Deployment Guide

## 🎯 Übersicht
Zukunftssichere VPN-Lösung für Freunde-Netzwerk ohne Abhängigkeit von externen Services.

## 🚀 Server Setup (1x für alle)

### 1. VPS mieten
- **Empfehlung**: Hetzner Cloud CPX11 (€3.29/Monat)
- **Mindestanforderungen**: 1 CPU, 1GB RAM, Ubuntu 22.04
- **Standort**: Deutschland (EU-Datenschutz)

### 2. Server einrichten
```bash
# Auf VPS einloggen
ssh root@your-server-ip

# Setup Script ausführen
sudo ./wireguard_server_setup.sh
```

### 3. Clients hinzufügen
```bash
# Für jeden Freund/Gerät
/root/add_client.sh amon-m1
/root/add_client.sh amon-iphone
/root/add_client.sh max-laptop
```

## 👥 Client Setup (für jeden Freund)

### macOS
```bash
# WireGuard installieren
brew install wireguard-tools

# Oder WireGuard App aus App Store
# Config-Datei importieren und verbinden
```

### Linux (Ubuntu/Arch)
```bash
# Setup Script ausführen
./wireguard_client_linux.sh

# Config importieren
sudo cp client.conf /etc/wireguard/
sudo wg-quick up client
```

### iOS/Android
1. WireGuard App installieren
2. QR-Code vom Server scannen
3. Verbindung aktivieren

## 💰 Kosten
- **Server**: €3-5/Monat für unbegrenzte Geräte
- **Pro Person**: €3-6/Jahr (bei 10 Freunden)
- **Einmalig**: Setup-Zeit (1-2 Stunden)

## 🔧 Wartung
- **Updates**: Automatisch via unattended-upgrades
- **Monitoring**: Optional via Grafana/Prometheus
- **Backup**: Config-Dateien regelmäßig sichern

## 🛡️ Sicherheit
- **Verschlüsselung**: ChaCha20Poly1305
- **Authentifizierung**: Ed25519 Keys
- **Perfect Forward Secrecy**: Ja
- **Audit**: Regelmäßig von Sicherheitsexperten geprüft

## 📱 Mobile Optimierung
- **Battery Optimized**: Minimal CPU/Battery Usage
- **Roaming**: Automatische Reconnection
- **Kill Switch**: Verhindert Daten-Leaks

## 🌍 Zukunftssicherheit
- **Open Source**: Keine Vendor Lock-in
- **Standard**: Teil des Linux Kernels
- **Community**: Große, aktive Entwickler-Community
- **Unabhängigkeit**: Keine externen Service-Abhängigkeiten

## 📞 Support für Freunde
- **Setup-Hilfe**: Client Scripts automatisieren Installation
- **Troubleshooting**: Gemeinsame Dokumentation
- **Updates**: Zentral über Server-Admin
