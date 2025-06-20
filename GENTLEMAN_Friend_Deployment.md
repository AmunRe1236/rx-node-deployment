# GENTLEMAN Friend Deployment Guide

## 🎯 Für neue Friends: Dein eigenes GENTLEMAN System

### 1. Tailscale Setup
```bash
# macOS
brew install tailscale
sudo tailscale up

# Linux
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### 2. GENTLEMAN System Setup
```bash
# Clone das GENTLEMAN Repository
git clone https://github.com/your-repo/gentleman.git
cd gentleman

# Setup für dein System
./handshake_m1.sh        # Oder entsprechendes Script für dein OS
```

### 3. Friend Network Registration
```bash
# Teile deine Tailscale IP mit anderen Friends
tailscale ip -4

# Beispiel: 100.64.0.25
# Andere Friends fügen dich hinzu in friend_network_connector.sh
```

### 4. Teste Friend Connections
```bash
# Status aller Friend Networks
./friend_network_connector.sh status

# Verbinde zu einem Friend
./friend_network_connector.sh connect amon
```

## 👥 Friend Network Management

### Neuen Friend hinzufügen
```bash
# In friend_network_connector.sh:
FRIEND_NETWORKS+=(
    "new_friend:100.64.0.99:8765"
)
```

### Friend Network Status
```bash
./friend_network_connector.sh status
```

## 💰 Kosten pro Friend
- **Tailscale**: €0 (bis 20 Geräte)
- **GENTLEMAN Setup**: €0 (Open Source)
- **Shared Services**: €0 (Community gehostet)
- **Total**: €0

## 🔧 Optional: Shared Services
- Chat zwischen GENTLEMAN Systemen
- Gegenseitige Backups
- Community Monitoring
- Alle freiwillig und kostenlos
