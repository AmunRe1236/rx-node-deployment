# 🔧 SSH Setup und Wake-on-LAN Konfiguration für M1 Mac

## Problem: SSH-Verbindung verweigert
```
ssh: connect to host 192.168.68.111 port 22: Connection refused
```

## ✅ Lösung 1: SSH aktivieren auf M1 Mac

### Schritt 1: Systemeinstellungen öffnen
1. **Apple-Menü** → **Systemeinstellungen**
2. **Allgemein** → **Freigabe** (oder direkt **Freigabe** suchen)

### Schritt 2: Remote Login aktivieren
1. **Remote Login** aktivieren (Häkchen setzen)
2. **Zugriff erlauben für**: 
   - Entweder **Alle Benutzer**
   - Oder spezifisch **amonbaumgartner** hinzufügen

### Schritt 3: Firewall prüfen
1. **Systemeinstellungen** → **Netzwerk** → **Firewall**
2. Falls aktiviert: **Firewall-Optionen** → **Remote Login** erlauben

## ✅ Lösung 2: Wake-on-LAN manuell prüfen (auf M1 Mac)

### Terminal auf M1 Mac öffnen und folgende Befehle ausführen:

```bash
# 1. Power Management Einstellungen anzeigen
pmset -g

# 2. Wake-on-LAN Status prüfen
pmset -g | grep -i wake

# 3. MAC-Adresse ermitteln
ifconfig en0 | grep ether

# 4. Netzwerk Interface Details
ifconfig en0 | grep -E '(ether|inet)'

# 5. Wake-on-LAN aktivieren (falls deaktiviert)
sudo pmset -a womp 1

# 6. Alle Power Management Einstellungen
sudo pmset -g custom
```

## ✅ Lösung 3: Wake-on-LAN über Systemeinstellungen

### Schritt 1: Energiesparmodus
1. **Systemeinstellungen** → **Batterie** (oder **Energie sparen**)
2. **Erweitert** oder **Weitere Optionen**

### Schritt 2: Wake-on-LAN aktivieren
1. **"Wake für Netzwerkzugriff"** aktivieren
2. **"Wake für Ethernet-Netzwerkadministrator"** aktivieren

## 🔍 Erwartete Ergebnisse

### pmset -g Ausgabe sollte enthalten:
```
womp                1 (Wake on Magic Packet)
```

### MAC-Adresse Format:
```
ether xx:xx:xx:xx:xx:xx
```

## 🚀 Nach der Konfiguration testen

### Von I7 Laptop aus:
```bash
# SSH-Test
ssh amonbaumgartner@192.168.68.111 "pmset -g | grep womp"

# Wake-on-LAN Test
./wake_m1.sh
```

## 📝 Wichtige Hinweise

1. **SSH bleibt nach Neustart aktiviert** (einmalige Konfiguration)
2. **Wake-on-LAN funktioniert nur bei Ethernet-Verbindung** (nicht WLAN)
3. **M1 Mac muss im gleichen Netzwerk sein** für lokales Wake-on-LAN
4. **Router muss Wake-on-LAN Pakete weiterleiten** für Internet-Wake-on-LAN

## 🔧 Fehlerbehebung

### SSH funktioniert nicht:
- Firewall prüfen
- Benutzername korrekt?
- Port 22 offen?

### Wake-on-LAN funktioniert nicht:
- Ethernet-Kabel verwenden (nicht WLAN)
- MAC-Adresse korrekt?
- `womp` aktiviert?
- Router-Konfiguration prüfen 

## Problem: SSH-Verbindung verweigert
```
ssh: connect to host 192.168.68.111 port 22: Connection refused
```

## ✅ Lösung 1: SSH aktivieren auf M1 Mac

### Schritt 1: Systemeinstellungen öffnen
1. **Apple-Menü** → **Systemeinstellungen**
2. **Allgemein** → **Freigabe** (oder direkt **Freigabe** suchen)

### Schritt 2: Remote Login aktivieren
1. **Remote Login** aktivieren (Häkchen setzen)
2. **Zugriff erlauben für**: 
   - Entweder **Alle Benutzer**
   - Oder spezifisch **amonbaumgartner** hinzufügen

### Schritt 3: Firewall prüfen
1. **Systemeinstellungen** → **Netzwerk** → **Firewall**
2. Falls aktiviert: **Firewall-Optionen** → **Remote Login** erlauben

## ✅ Lösung 2: Wake-on-LAN manuell prüfen (auf M1 Mac)

### Terminal auf M1 Mac öffnen und folgende Befehle ausführen:

```bash
# 1. Power Management Einstellungen anzeigen
pmset -g

# 2. Wake-on-LAN Status prüfen
pmset -g | grep -i wake

# 3. MAC-Adresse ermitteln
ifconfig en0 | grep ether

# 4. Netzwerk Interface Details
ifconfig en0 | grep -E '(ether|inet)'

# 5. Wake-on-LAN aktivieren (falls deaktiviert)
sudo pmset -a womp 1

# 6. Alle Power Management Einstellungen
sudo pmset -g custom
```

## ✅ Lösung 3: Wake-on-LAN über Systemeinstellungen

### Schritt 1: Energiesparmodus
1. **Systemeinstellungen** → **Batterie** (oder **Energie sparen**)
2. **Erweitert** oder **Weitere Optionen**

### Schritt 2: Wake-on-LAN aktivieren
1. **"Wake für Netzwerkzugriff"** aktivieren
2. **"Wake für Ethernet-Netzwerkadministrator"** aktivieren

## 🔍 Erwartete Ergebnisse

### pmset -g Ausgabe sollte enthalten:
```
womp                1 (Wake on Magic Packet)
```

### MAC-Adresse Format:
```
ether xx:xx:xx:xx:xx:xx
```

## 🚀 Nach der Konfiguration testen

### Von I7 Laptop aus:
```bash
# SSH-Test
ssh amonbaumgartner@192.168.68.111 "pmset -g | grep womp"

# Wake-on-LAN Test
./wake_m1.sh
```

## 📝 Wichtige Hinweise

1. **SSH bleibt nach Neustart aktiviert** (einmalige Konfiguration)
2. **Wake-on-LAN funktioniert nur bei Ethernet-Verbindung** (nicht WLAN)
3. **M1 Mac muss im gleichen Netzwerk sein** für lokales Wake-on-LAN
4. **Router muss Wake-on-LAN Pakete weiterleiten** für Internet-Wake-on-LAN

## 🔧 Fehlerbehebung

### SSH funktioniert nicht:
- Firewall prüfen
- Benutzername korrekt?
- Port 22 offen?

### Wake-on-LAN funktioniert nicht:
- Ethernet-Kabel verwenden (nicht WLAN)
- MAC-Adresse korrekt?
- `womp` aktiviert?
- Router-Konfiguration prüfen 
 