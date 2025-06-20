# GENTLEMAN System Setup Documentation

## 🎯 Übersicht

Vollständige Dokumentation für das GENTLEMAN System mit M1 Mac, RX Node und Tailscale-basierter AI-Infrastruktur.

### 📋 System Komponenten
- **M1 Mac**: Zentrale Steuerung, Handshake Server
- **RX Node**: AMD GPU AI Server (RX 6700 XT)
- **iPhone**: Mobile Kontrolle
- **Tailscale**: Netzwerk-Backbone

---

## 📚 Dokumentations-Struktur

### 1. 🌐 Netzwerk Setup
**Datei**: `GENTLEMAN_Tailscale_Setup_Guide.md`

**Inhalt**:
- Tailscale Installation auf M1 Mac ✅ (bereits aktiv)
- Tailscale Installation auf RX Node
- SSH Konfiguration über Tailscale
- Netzwerk-Architektur und Routing
- Troubleshooting und Verification

**Status**: M1 Mac fertig, RX Node Setup dokumentiert

### 2. 🤖 AMD GPU AI Setup  
**Datei**: `GENTLEMAN_AMD_GPU_Setup_Guide.md`

**Inhalt**:
- ROCm Installation für AMD RX 6700 XT
- PyTorch mit ROCm Support
- AI Server Implementation
- Performance Monitoring
- Erweiterte AI Features

**Status**: Vollständig dokumentiert, bereit für Implementation

### 3. 🔧 System Integration
**Datei**: Dieses README

**Inhalt**:
- Setup-Reihenfolge
- Abhängigkeiten zwischen Komponenten
- Gesamtsystem-Tests
- Wartung und Updates

---

## 🚀 Setup-Reihenfolge

### Phase 1: Netzwerk Foundation ✅
1. **M1 Mac Tailscale** - Bereits konfiguriert
   - IP: 100.96.219.28
   - Account: baumgartneramon@gmail.com
   - Subnet Routes aktiv

2. **iPhone Integration** - Bereits konfiguriert ✅
   - IP: 100.123.55.36
   - Tailscale App aktiv

### Phase 2: RX Node Integration (Aktuell)
3. **RX Node Tailscale Setup**
   ```bash
   # SSH zur RX Node
   ssh rx-node
   
   # Folge: GENTLEMAN_Tailscale_Setup_Guide.md
   # Abschnitt: "RX Node Tailscale Setup"
   ```

4. **Netzwerk Verification**
   ```bash
   # Vom M1 Mac
   ./tailscale_status.sh
   ping 100.x.x.x  # RX Node Tailscale IP
   ```

### Phase 3: AI Infrastructure
5. **AMD GPU Setup**
   ```bash
   # SSH zur RX Node
   ssh amo9n11@100.x.x.x  # Via Tailscale
   
   # Folge: GENTLEMAN_AMD_GPU_Setup_Guide.md
   # Vollständiges ROCm + PyTorch Setup
   ```

6. **AI Services Deployment**
   ```bash
   # AI Server als Service
   sudo systemctl start gentleman-amd-ai.service
   
   # Remote Test vom M1 Mac
   curl http://100.x.x.x:8765/health
   ```

---

## 🔧 Aktuelle Hardware-Konfiguration

### M1 Mac (Zentrale)
- **IP Home**: 192.168.68.111
- **IP Tailscale**: 100.96.219.28
- **Services**: Handshake Server (Port 8765)
- **Status**: ✅ Aktiv und konfiguriert

### RX Node (AI Server)
- **IP Home**: 192.168.68.117
- **IP Tailscale**: 100.x.x.x (wird vergeben)
- **GPU**: AMD RX 6700 XT (12GB VRAM)
- **CPU**: AMD Ryzen 5 1600
- **RAM**: 16GB DDR4
- **OS**: Arch Linux
- **User**: amo9n11
- **Status**: 🔄 Tailscale Setup ausstehend

### iPhone (Mobile)
- **IP Tailscale**: 100.123.55.36
- **Status**: ✅ Aktiv in Tailscale

---

## 🌐 Netzwerk-Architektur

### Home Network (192.168.68.0/24)
```
Router (192.168.68.1)
├── M1 Mac: 192.168.68.111 ←→ Tailscale: 100.96.219.28
├── RX Node: 192.168.68.117 ←→ Tailscale: 100.x.x.x
└── I7 Laptop: 192.168.68.105 (optional)
```

### Tailscale Overlay (100.x.x.x/20)
```
Tailnet: baumgartneramon@gmail.com
├── M1 Mac: 100.96.219.28 (Route Advertiser)
├── RX Node: 100.x.x.x (AI Server)
└── iPhone: 100.123.55.36 (Mobile Client)
```

### Service Ports
- **8765**: Handshake Server (M1) + AI Server (RX)
- **22**: SSH (beide Nodes)
- **Tailscale**: Automatische Port-Verwaltung

---

## 🧪 Testing & Verification

### Netzwerk Tests
```bash
# Tailscale Status
./tailscale_status.sh

# Ping Tests
ping 100.96.219.28  # M1 Mac
ping 100.x.x.x      # RX Node
ping 100.123.55.36  # iPhone

# SSH Tests
ssh amon@100.96.219.28      # M1 Mac
ssh amo9n11@100.x.x.x       # RX Node
```

### Service Tests
```bash
# M1 Handshake Server
curl http://100.96.219.28:8765/health

# RX AI Server (nach Setup)
curl http://100.x.x.x:8765/health
curl http://100.x.x.x:8765/gpu/status
```

### Hotspot Tests
```bash
# M1 Mac ins Hotspot wechseln
# RX Node sollte weiterhin erreichbar sein über Tailscale
ping 100.x.x.x
ssh amo9n11@100.x.x.x
```

---

## 🔧 Maintenance & Updates

### Tailscale Updates
```bash
# M1 Mac
brew upgrade tailscale

# RX Node (Arch Linux)
sudo pacman -S tailscale
```

### AI Environment Updates
```bash
# RX Node
source ~/ai_env/bin/activate
pip install --upgrade torch transformers
```

### System Updates
```bash
# M1 Mac
brew update && brew upgrade

# RX Node
sudo pacman -Syu
```

---

## 🚨 Troubleshooting Quick Reference

### Tailscale Issues
```bash
# Service Restart
sudo systemctl restart tailscaled

# Re-authentication
sudo tailscale up --force-reauth

# Network Diagnostics
tailscale netcheck
```

### SSH Issues
```bash
# SSH Key Problems
ssh-add ~/.ssh/id_rsa

# Connection Test
ssh -v amo9n11@100.x.x.x
```

### AI Server Issues
```bash
# Service Status
systemctl status gentleman-amd-ai.service

# Manual Start for Debugging
source ~/ai_env/bin/activate
python ~/amd_ai_server.py
```

---

## 📊 System Status Dashboard

### Quick Status Check
```bash
# Alle Services prüfen
./system_status_check.sh  # (zu erstellen)

# Erwartet:
# ✅ M1 Tailscale: Online
# ✅ RX Tailscale: Online  
# ✅ M1 Handshake: Running
# ✅ RX AI Server: Running
# ✅ Network: All nodes reachable
```

---

## 🎯 Nächste Entwicklungsschritte

### Phase 4: Advanced Features
- [ ] Wake-on-LAN über Tailscale
- [ ] Distributed AI Model Loading
- [ ] Mobile App für AI Control
- [ ] Friend Network Integration

### Phase 5: Optimization
- [ ] GPU Memory Optimization
- [ ] Model Caching Strategies
- [ ] Performance Monitoring Dashboard
- [ ] Automated Health Checks

---

## 📞 Support & Resources

### Dokumentation
- `GENTLEMAN_Tailscale_Setup_Guide.md` - Netzwerk Setup
- `GENTLEMAN_AMD_GPU_Setup_Guide.md` - AI Infrastructure
- Dieses README - System Overview

### External Resources
- [Tailscale Documentation](https://tailscale.com/kb/)
- [ROCm Documentation](https://rocmdocs.amd.com/)
- [PyTorch ROCm Guide](https://pytorch.org/get-started/locally/)

### Contact
- System Owner: Amon Baumgartner
- Tailscale Account: baumgartneramon@gmail.com

---

**🎉 Happy Computing mit GENTLEMAN!** 

## 🎯 Übersicht

Vollständige Dokumentation für das GENTLEMAN System mit M1 Mac, RX Node und Tailscale-basierter AI-Infrastruktur.

### 📋 System Komponenten
- **M1 Mac**: Zentrale Steuerung, Handshake Server
- **RX Node**: AMD GPU AI Server (RX 6700 XT)
- **iPhone**: Mobile Kontrolle
- **Tailscale**: Netzwerk-Backbone

---

## 📚 Dokumentations-Struktur

### 1. 🌐 Netzwerk Setup
**Datei**: `GENTLEMAN_Tailscale_Setup_Guide.md`

**Inhalt**:
- Tailscale Installation auf M1 Mac ✅ (bereits aktiv)
- Tailscale Installation auf RX Node
- SSH Konfiguration über Tailscale
- Netzwerk-Architektur und Routing
- Troubleshooting und Verification

**Status**: M1 Mac fertig, RX Node Setup dokumentiert

### 2. 🤖 AMD GPU AI Setup  
**Datei**: `GENTLEMAN_AMD_GPU_Setup_Guide.md`

**Inhalt**:
- ROCm Installation für AMD RX 6700 XT
- PyTorch mit ROCm Support
- AI Server Implementation
- Performance Monitoring
- Erweiterte AI Features

**Status**: Vollständig dokumentiert, bereit für Implementation

### 3. 🔧 System Integration
**Datei**: Dieses README

**Inhalt**:
- Setup-Reihenfolge
- Abhängigkeiten zwischen Komponenten
- Gesamtsystem-Tests
- Wartung und Updates

---

## 🚀 Setup-Reihenfolge

### Phase 1: Netzwerk Foundation ✅
1. **M1 Mac Tailscale** - Bereits konfiguriert
   - IP: 100.96.219.28
   - Account: baumgartneramon@gmail.com
   - Subnet Routes aktiv

2. **iPhone Integration** - Bereits konfiguriert ✅
   - IP: 100.123.55.36
   - Tailscale App aktiv

### Phase 2: RX Node Integration (Aktuell)
3. **RX Node Tailscale Setup**
   ```bash
   # SSH zur RX Node
   ssh rx-node
   
   # Folge: GENTLEMAN_Tailscale_Setup_Guide.md
   # Abschnitt: "RX Node Tailscale Setup"
   ```

4. **Netzwerk Verification**
   ```bash
   # Vom M1 Mac
   ./tailscale_status.sh
   ping 100.x.x.x  # RX Node Tailscale IP
   ```

### Phase 3: AI Infrastructure
5. **AMD GPU Setup**
   ```bash
   # SSH zur RX Node
   ssh amo9n11@100.x.x.x  # Via Tailscale
   
   # Folge: GENTLEMAN_AMD_GPU_Setup_Guide.md
   # Vollständiges ROCm + PyTorch Setup
   ```

6. **AI Services Deployment**
   ```bash
   # AI Server als Service
   sudo systemctl start gentleman-amd-ai.service
   
   # Remote Test vom M1 Mac
   curl http://100.x.x.x:8765/health
   ```

---

## 🔧 Aktuelle Hardware-Konfiguration

### M1 Mac (Zentrale)
- **IP Home**: 192.168.68.111
- **IP Tailscale**: 100.96.219.28
- **Services**: Handshake Server (Port 8765)
- **Status**: ✅ Aktiv und konfiguriert

### RX Node (AI Server)
- **IP Home**: 192.168.68.117
- **IP Tailscale**: 100.x.x.x (wird vergeben)
- **GPU**: AMD RX 6700 XT (12GB VRAM)
- **CPU**: AMD Ryzen 5 1600
- **RAM**: 16GB DDR4
- **OS**: Arch Linux
- **User**: amo9n11
- **Status**: 🔄 Tailscale Setup ausstehend

### iPhone (Mobile)
- **IP Tailscale**: 100.123.55.36
- **Status**: ✅ Aktiv in Tailscale

---

## 🌐 Netzwerk-Architektur

### Home Network (192.168.68.0/24)
```
Router (192.168.68.1)
├── M1 Mac: 192.168.68.111 ←→ Tailscale: 100.96.219.28
├── RX Node: 192.168.68.117 ←→ Tailscale: 100.x.x.x
└── I7 Laptop: 192.168.68.105 (optional)
```

### Tailscale Overlay (100.x.x.x/20)
```
Tailnet: baumgartneramon@gmail.com
├── M1 Mac: 100.96.219.28 (Route Advertiser)
├── RX Node: 100.x.x.x (AI Server)
└── iPhone: 100.123.55.36 (Mobile Client)
```

### Service Ports
- **8765**: Handshake Server (M1) + AI Server (RX)
- **22**: SSH (beide Nodes)
- **Tailscale**: Automatische Port-Verwaltung

---

## 🧪 Testing & Verification

### Netzwerk Tests
```bash
# Tailscale Status
./tailscale_status.sh

# Ping Tests
ping 100.96.219.28  # M1 Mac
ping 100.x.x.x      # RX Node
ping 100.123.55.36  # iPhone

# SSH Tests
ssh amon@100.96.219.28      # M1 Mac
ssh amo9n11@100.x.x.x       # RX Node
```

### Service Tests
```bash
# M1 Handshake Server
curl http://100.96.219.28:8765/health

# RX AI Server (nach Setup)
curl http://100.x.x.x:8765/health
curl http://100.x.x.x:8765/gpu/status
```

### Hotspot Tests
```bash
# M1 Mac ins Hotspot wechseln
# RX Node sollte weiterhin erreichbar sein über Tailscale
ping 100.x.x.x
ssh amo9n11@100.x.x.x
```

---

## 🔧 Maintenance & Updates

### Tailscale Updates
```bash
# M1 Mac
brew upgrade tailscale

# RX Node (Arch Linux)
sudo pacman -S tailscale
```

### AI Environment Updates
```bash
# RX Node
source ~/ai_env/bin/activate
pip install --upgrade torch transformers
```

### System Updates
```bash
# M1 Mac
brew update && brew upgrade

# RX Node
sudo pacman -Syu
```

---

## 🚨 Troubleshooting Quick Reference

### Tailscale Issues
```bash
# Service Restart
sudo systemctl restart tailscaled

# Re-authentication
sudo tailscale up --force-reauth

# Network Diagnostics
tailscale netcheck
```

### SSH Issues
```bash
# SSH Key Problems
ssh-add ~/.ssh/id_rsa

# Connection Test
ssh -v amo9n11@100.x.x.x
```

### AI Server Issues
```bash
# Service Status
systemctl status gentleman-amd-ai.service

# Manual Start for Debugging
source ~/ai_env/bin/activate
python ~/amd_ai_server.py
```

---

## 📊 System Status Dashboard

### Quick Status Check
```bash
# Alle Services prüfen
./system_status_check.sh  # (zu erstellen)

# Erwartet:
# ✅ M1 Tailscale: Online
# ✅ RX Tailscale: Online  
# ✅ M1 Handshake: Running
# ✅ RX AI Server: Running
# ✅ Network: All nodes reachable
```

---

## 🎯 Nächste Entwicklungsschritte

### Phase 4: Advanced Features
- [ ] Wake-on-LAN über Tailscale
- [ ] Distributed AI Model Loading
- [ ] Mobile App für AI Control
- [ ] Friend Network Integration

### Phase 5: Optimization
- [ ] GPU Memory Optimization
- [ ] Model Caching Strategies
- [ ] Performance Monitoring Dashboard
- [ ] Automated Health Checks

---

## 📞 Support & Resources

### Dokumentation
- `GENTLEMAN_Tailscale_Setup_Guide.md` - Netzwerk Setup
- `GENTLEMAN_AMD_GPU_Setup_Guide.md` - AI Infrastructure
- Dieses README - System Overview

### External Resources
- [Tailscale Documentation](https://tailscale.com/kb/)
- [ROCm Documentation](https://rocmdocs.amd.com/)
- [PyTorch ROCm Guide](https://pytorch.org/get-started/locally/)

### Contact
- System Owner: Amon Baumgartner
- Tailscale Account: baumgartneramon@gmail.com

---

**🎉 Happy Computing mit GENTLEMAN!** 
 