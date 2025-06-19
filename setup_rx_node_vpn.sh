#!/bin/bash
# 🎮 GENTLEMAN RX Node VPN & GPU Setup Script
# AMD RX 6700 XT GPU-beschleunigter Primary Trainer Setup
# Für Ubuntu/Linux RX Node (192.168.68.117)

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ASCII Header
echo -e "${PURPLE}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║  🎮 GENTLEMAN RX NODE - TOTAL SETUP                          ║
║  AMD RX 6700 XT • WireGuard VPN • LM Studio • ROCm          ║
║  Primary Trainer für GPU-beschleunigte LLM Inferenz         ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Logging Functions
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅ $1${NC}"
}

log_info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] ℹ️  $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"
}

log_step() {
    echo -e "${CYAN}[$(date +'%H:%M:%S')] 🔧 $1${NC}"
}

# Konfiguration
RX_IP="192.168.68.117"
RX_VPN_IP="10.0.0.3/24"
M1_MAC_IP="192.168.68.111"
WIREGUARD_PORT="51820"
LM_STUDIO_PORT="1234"
WORK_DIR="$HOME/gentleman_rx_deployment"

# Schritt 1: System-Validierung
log_step "Schritt 1: RX Node System-Validierung"
echo "🖥️  Hostname: $(hostname)"
echo "🌐 IP Adresse: $(hostname -I | awk '{print $1}')"
echo "💻 OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "$(uname -s) $(uname -r)")"
echo "🧠 CPU: $(lscpu | grep 'Model name' | cut -d':' -f2 | xargs | head -1)"
echo "🔢 CPU Kerne: $(nproc) cores"
echo "💾 RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo "💿 Speicher: $(df -h / | awk 'NR==2 {print $4}') verfügbar"

# Validiere RX Node IP
CURRENT_IP=$(hostname -I | awk '{print $1}')
if [ "$CURRENT_IP" != "$RX_IP" ]; then
    log_warning "IP-Adresse stimmt nicht überein. Erwartet: $RX_IP, Aktuell: $CURRENT_IP"
    log_info "Setze fort mit aktueller IP..."
    RX_IP="$CURRENT_IP"
fi

# Prüfe Root-Rechte
if [[ $EUID -eq 0 ]]; then
    log_error "Bitte führe dieses Script NICHT als root aus!"
    exit 1
fi

log "RX Node System validiert"

# Schritt 2: AMD GPU Erkennung
log_step "Schritt 2: AMD GPU & ROCm Erkennung"
GPU_DETECTED=false
RX6700XT_DETECTED=false

if command -v lspci &> /dev/null; then
    GPU_INFO=$(lspci | grep -i "vga\|3d\|display" | grep -i "amd\|radeon" || true)
    if [[ -n "$GPU_INFO" ]]; then
        echo "🎮 AMD GPU erkannt:"
        echo "$GPU_INFO"
        GPU_DETECTED=true
        
        # Spezielle RX 6700 XT Erkennung
        if echo "$GPU_INFO" | grep -qi "6700"; then
            RX6700XT_DETECTED=true
            log "🎯 AMD RX 6700 XT erkannt - Optimale LLM-Performance!"
        fi
    else
        log_warning "Keine AMD GPU erkannt"
    fi
else
    log_warning "lspci nicht verfügbar - GPU-Erkennung übersprungen"
fi

# Schritt 3: Arbeitsverzeichnis erstellen
log_step "Schritt 3: Arbeitsverzeichnis Setup"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
log "Arbeitsverzeichnis: $WORK_DIR"

# Schritt 4: System-Updates
log_step "Schritt 4: System-Updates"
sudo apt update
sudo apt upgrade -y
log "System aktualisiert"

# Schritt 5: Dependencies installieren
log_step "Schritt 5: Basis-Dependencies Installation"
sudo apt install -y \
    wget \
    curl \
    git \
    build-essential \
    python3 \
    python3-pip \
    htop \
    ufw \
    fuse \
    libfuse2 \
    wireguard \
    wireguard-tools \
    bc \
    jq \
    net-tools

log "Basis-Dependencies installiert"

# Schritt 6: AMD ROCm Installation
if [[ $GPU_DETECTED == true ]]; then
    log_step "Schritt 6: AMD ROCm Installation für GPU-Beschleunigung"
    
    # ROCm Repository hinzufügen
    log_info "Füge ROCm Repository hinzu..."
    wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -
    echo 'deb [arch=amd64] https://repo.radeon.com/rocm/apt/debian/ ubuntu main' | \
        sudo tee /etc/apt/sources.list.d/rocm.list
    
    sudo apt update
    
    # ROCm installieren
    log_info "Installiere ROCm..."
    sudo apt install -y rocm-dev rocm-libs rocm-utils rocm-smi
    
    # Benutzer zu render/video Gruppen hinzufügen
    sudo usermod -a -G render,video $USER
    
    # ROCm Umgebungsvariablen setzen
    if [[ $RX6700XT_DETECTED == true ]]; then
        echo 'export HSA_OVERRIDE_GFX_VERSION=10.3.0' >> ~/.bashrc
        echo 'export ROCM_PATH=/opt/rocm' >> ~/.bashrc
        echo 'export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
    fi
    
    log "ROCm installiert - Neustart möglicherweise erforderlich"
    
    # ROCm Test
    if command -v rocm-smi &> /dev/null; then
        log_info "Teste ROCm Installation..."
        rocm-smi || log_warning "ROCm Test fehlgeschlagen - möglicherweise Neustart erforderlich"
    fi
else
    log_warning "Schritt 6: ROCm Installation übersprungen (keine AMD GPU)"
fi

# Schritt 7: WireGuard VPN Setup
log_step "Schritt 7: WireGuard VPN Client Setup"

# WireGuard Keys generieren
if [[ ! -f "rx_wireguard_private.key" ]]; then
    log_info "Generiere WireGuard Keys..."
    wg genkey > rx_wireguard_private.key
    wg pubkey < rx_wireguard_private.key > rx_wireguard_public.key
    chmod 600 rx_wireguard_private.key
    log "WireGuard Keys generiert"
else
    log "WireGuard Keys bereits vorhanden"
fi

RX_PRIVATE_KEY=$(cat rx_wireguard_private.key)
RX_PUBLIC_KEY=$(cat rx_wireguard_public.key)

log_info "RX Node Public Key: $RX_PUBLIC_KEY"

# WireGuard Konfiguration erstellen
log_info "Erstelle WireGuard Konfiguration..."
cat > rx_wg0.conf << EOF
[Interface]
# GENTLEMAN RX Node WireGuard Client Configuration
# Ubuntu Linux Client für GPU-beschleunigte LLM Inferenz
PrivateKey = $RX_PRIVATE_KEY
Address = $RX_VPN_IP
DNS = 8.8.8.8, 1.1.1.1

[Peer]
# GENTLEMAN Cluster M1 Mac Gateway
PublicKey = 4+UBqx/VdhKLCZnQqgsgWEUAoi8co+FHT4fsl8Mp81k=
Endpoint = $M1_MAC_IP:$WIREGUARD_PORT
AllowedIPs = 192.168.68.0/24, 10.0.0.0/24
PersistentKeepalive = 25

# GENTLEMAN Cluster Services über VPN verfügbar:
# M1 Mac (Gateway): ssh amonbaumgartner@192.168.68.111
# RX Node (lokal): ssh amo9n11@192.168.68.117
# I7 Node: ssh amonbaumgartner@192.168.68.105
# 
# Git Daemon: git://192.168.68.111:9418/Gentleman
# GENTLEMAN Protocol: http://192.168.68.117:8008
# LM Studio RX: http://192.168.68.117:1234
# LM Studio I7: http://192.168.68.105:1235
EOF

# WireGuard Konfiguration installieren
sudo mkdir -p /etc/wireguard
sudo mv rx_wg0.conf /etc/wireguard/wg0.conf
sudo chmod 600 /etc/wireguard/wg0.conf

log "WireGuard Client konfiguriert"

# Schritt 8: LM Studio Download & Setup
log_step "Schritt 8: LM Studio Download & GPU-Setup"

LM_STUDIO_VERSION="0.2.29"
LM_STUDIO_FILE="LM_Studio-${LM_STUDIO_VERSION}.AppImage"
LM_STUDIO_URL="https://releases.lmstudio.ai/linux/x86/${LM_STUDIO_VERSION}/${LM_STUDIO_FILE}"

if [[ ! -f "$LM_STUDIO_FILE" ]]; then
    log_info "Downloade LM Studio..."
    wget "$LM_STUDIO_URL" -O "$LM_STUDIO_FILE"
    chmod +x "$LM_STUDIO_FILE"
else
    log "LM Studio bereits heruntergeladen"
fi

# LM Studio GPU Launcher erstellen
log_info "Erstelle LM Studio GPU Launcher..."
cat > start_rx_lmstudio_gpu.sh << 'EOF'
#!/bin/bash
# 🎮 RX Node LM Studio GPU Launcher
# Optimiert für AMD RX 6700 XT mit ROCm

export DISPLAY=:0
export ROCM_PATH=/opt/rocm
export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH
export HSA_OVERRIDE_GFX_VERSION=10.3.0
export HIP_VISIBLE_DEVICES=0
export PYTORCH_HIP_ALLOC_CONF=max_split_size_mb:128

cd ~/gentleman_rx_deployment

echo "🎮 Starte LM Studio mit AMD RX 6700 XT GPU-Beschleunigung..."
echo "📍 Arbeitsverzeichnis: $(pwd)"
echo "🔥 ROCm Pfad: $ROCM_PATH"
echo "🎯 GPU Device: $HIP_VISIBLE_DEVICES"
echo ""
echo "🚀 LM Studio GUI wird gestartet..."
echo "💡 Wichtig: Aktiviere GPU Acceleration in LM Studio Settings!"
echo ""

./LM_Studio-0.2.29.AppImage --no-sandbox
EOF

chmod +x start_rx_lmstudio_gpu.sh

# LM Studio Server Launcher erstellen
cat > start_rx_lmstudio_server.sh << 'EOF'
#!/bin/bash
# 🌐 RX Node LM Studio Server Launcher
# GPU-beschleunigter LLM Server auf Port 1234

export ROCM_PATH=/opt/rocm
export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH
export HSA_OVERRIDE_GFX_VERSION=10.3.0
export HIP_VISIBLE_DEVICES=0

cd ~/gentleman_rx_deployment

echo "🌐 Starte LM Studio Server (Port 1234) mit GPU-Beschleunigung..."
echo "🎮 AMD RX 6700 XT GPU wird verwendet"
echo "📡 Server verfügbar unter: http://192.168.68.117:1234"
echo ""
echo "💡 HINWEIS: Modell muss zuerst in LM Studio GUI geladen werden!"
echo "🔄 Verwende: ./start_rx_lmstudio_gpu.sh für GUI"
echo ""

# Prüfe ob LM Studio läuft
if pgrep -f "LM_Studio" > /dev/null; then
    echo "✅ LM Studio Prozess erkannt"
else
    echo "⚠️  LM Studio GUI nicht erkannt - starte zuerst GUI mit geladenem Modell"
    echo "🚀 GUI starten: ./start_rx_lmstudio_gpu.sh"
fi

echo ""
echo "🎯 Server wird in LM Studio über 'Local Server' Tab gestartet"
echo "🔧 Einstellungen: Port 1234, GPU Acceleration ON, alle GPU Layers"
EOF

chmod +x start_rx_lmstudio_server.sh

log "LM Studio GPU-Launcher erstellt"

# Schritt 9: Firewall Konfiguration
log_step "Schritt 9: Firewall Konfiguration"
sudo ufw allow $LM_STUDIO_PORT/tcp comment "LM Studio Server"
sudo ufw allow 51820/udp comment "WireGuard VPN"
sudo ufw allow 8008/tcp comment "GENTLEMAN Protocol"
sudo ufw --force enable

log "Firewall konfiguriert"

# Schritt 10: GPU Tests und Monitoring Tools
log_step "Schritt 10: GPU Test & Monitoring Setup"

# GPU Test Script erstellen
cat > test_rx_gpu.py << 'EOF'
#!/usr/bin/env python3
"""
🧪 RX Node GPU Test Script
Tests für AMD RX 6700 XT GPU-Funktionalität
"""

import subprocess
import sys
import time

def test_rocm():
    """Test ROCm Installation"""
    print("🔧 Teste ROCm Installation...")
    try:
        result = subprocess.run(['rocm-smi'], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print("✅ ROCm funktional")
            print(result.stdout)
            return True
        else:
            print("❌ ROCm Test fehlgeschlagen")
            return False
    except Exception as e:
        print(f"❌ ROCm Test Fehler: {e}")
        return False

def test_gpu_load():
    """Einfacher GPU Load Test"""
    print("🎮 Teste GPU Load...")
    try:
        # Starte rocm-smi im Hintergrund für Monitoring
        print("📊 GPU Status (5 Sekunden):")
        subprocess.run(['rocm-smi', '--showtemp', '--showpower', '--showuse'], timeout=5)
        return True
    except Exception as e:
        print(f"❌ GPU Load Test Fehler: {e}")
        return False

def test_lm_studio_api():
    """Test LM Studio API Verbindung"""
    print("🌐 Teste LM Studio API...")
    try:
        import requests
        response = requests.get('http://localhost:1234/v1/models', timeout=5)
        if response.status_code == 200:
            print("✅ LM Studio API erreichbar")
            models = response.json()
            print(f"📊 Verfügbare Modelle: {len(models.get('data', []))}")
            return True
        else:
            print("❌ LM Studio API nicht erreichbar")
            return False
    except Exception as e:
        print(f"❌ LM Studio API Test Fehler: {e}")
        print("💡 Starte LM Studio Server: ./start_rx_lmstudio_server.sh")
        return False

if __name__ == "__main__":
    print("🧪 RX Node GPU Test Suite")
    print("=" * 50)
    
    tests_passed = 0
    total_tests = 3
    
    if test_rocm():
        tests_passed += 1
    
    if test_gpu_load():
        tests_passed += 1
        
    if test_lm_studio_api():
        tests_passed += 1
    
    print("\n📊 Test Ergebnisse:")
    print(f"✅ Tests bestanden: {tests_passed}/{total_tests}")
    
    if tests_passed == total_tests:
        print("🎉 Alle Tests erfolgreich! RX Node GPU-System funktional.")
    else:
        print("⚠️  Einige Tests fehlgeschlagen. Siehe Ausgabe oben.")
        sys.exit(1)
EOF

chmod +x test_rx_gpu.py

# GPU Monitoring Script
cat > monitor_rx_gpu.sh << 'EOF'
#!/bin/bash
# 📊 RX Node GPU Monitoring

echo "📊 AMD RX 6700 XT GPU Monitoring"
echo "================================"
echo "🔄 Drücke Ctrl+C zum Beenden"
echo ""

watch -n 2 'echo "🎮 GPU Status:" && rocm-smi --showtemp --showpower --showuse && echo "" && echo "🌡️ Thermals:" && sensors 2>/dev/null | grep -A5 "amdgpu" || echo "Sensors nicht verfügbar"'
EOF

chmod +x monitor_rx_gpu.sh

log "GPU Test & Monitoring Tools erstellt"

# Schritt 11: Finale Einrichtung
log_step "Schritt 11: Finale Einrichtung"

# Erstelle WireGuard Auto-Start
cat > start_rx_vpn.sh << 'EOF'
#!/bin/bash
# 🔐 RX Node VPN Starter

echo "🔐 Starte RX Node VPN Verbindung..."
sudo wg-quick up wg0
echo "✅ VPN aktiv"
echo "🌐 VPN IP: 10.0.0.3"
echo "📡 Teste Verbindung..."
ping -c 3 10.0.0.1 || echo "⚠️ M1 Mac nicht erreichbar"
EOF

chmod +x start_rx_vpn.sh

# VPN Status Script
cat > check_rx_vpn.sh << 'EOF'
#!/bin/bash
# 📊 RX Node VPN Status

echo "📊 RX Node VPN Status"
echo "===================="

if sudo wg show | grep -q "interface: wg0"; then
    echo "✅ VPN Status: AKTIV"
    sudo wg show
    echo ""
    echo "🌐 Teste Cluster Konnektivität:"
    echo "   M1 Mac (10.0.0.1):"
    ping -c 2 10.0.0.1 2>/dev/null && echo "     ✅ Erreichbar" || echo "     ❌ Nicht erreichbar"
    echo "   I7 Node (10.0.0.4):"
    ping -c 2 10.0.0.4 2>/dev/null && echo "     ✅ Erreichbar" || echo "     ❌ Nicht erreichbar"
else
    echo "❌ VPN Status: NICHT AKTIV"
    echo "🚀 Starten mit: ./start_rx_vpn.sh"
fi
EOF

chmod +x check_rx_vpn.sh

log "VPN Management Scripts erstellt"

# Success Message
echo ""
echo -e "${GREEN}🎉 RX NODE SETUP ABGESCHLOSSEN!${NC}"
echo ""
echo -e "${YELLOW}📋 NÄCHSTE SCHRITTE:${NC}"
echo "===================="
echo ""
echo -e "${CYAN}1. 🔐 VPN starten:${NC}"
echo "   ./start_rx_vpn.sh"
echo ""
echo -e "${CYAN}2. 🎮 LM Studio GUI starten:${NC}"
echo "   ./start_rx_lmstudio_gpu.sh"
echo ""
echo -e "${CYAN}3. 📥 Modell downloaden (Empfehlung):${NC}"
echo "   - llama-3.2-3b-instruct-gguf (schnell)"
echo "   - qwen2.5-7b-instruct-gguf (ausgewogen)"
echo ""
echo -e "${CYAN}4. 🌐 Server aktivieren:${NC}"
echo "   Local Server Tab → Port 1234 → GPU ON → Alle GPU Layers"
echo ""
echo -e "${CYAN}5. 🧪 Tests ausführen:${NC}"
echo "   python3 test_rx_gpu.py"
echo ""
echo -e "${CYAN}6. 📊 GPU überwachen:${NC}"
echo "   ./monitor_rx_gpu.sh"
echo ""

if [[ $GPU_DETECTED == true ]]; then
    if [[ $RX6700XT_DETECTED == true ]]; then
        echo -e "${GREEN}🎮 AMD RX 6700 XT erkannt - Perfekt für LLM Training!${NC}"
    else
        echo -e "${YELLOW}🎮 AMD GPU erkannt - GPU-Beschleunigung verfügbar${NC}"
    fi
    echo -e "${YELLOW}⚠️  Neustart empfohlen für vollständige ROCm-Funktionalität${NC}"
    echo ""
fi

echo -e "${BLUE}📁 Alle Dateien erstellt in: $WORK_DIR${NC}"
echo -e "${BLUE}🌐 LM Studio Server URL: http://$RX_IP:$LM_STUDIO_PORT${NC}"
echo -e "${BLUE}🔐 VPN IP nach Aktivierung: 10.0.0.3${NC}"
echo ""
echo -e "${PURPLE}🔊 GPU-Lüfter werden bei Inferenz hörbar sein!${NC}"
echo ""

# Public Key für Server-Konfiguration anzeigen
echo -e "${CYAN}📋 WICHTIG: RX Node Public Key für M1 Mac Server:${NC}"
echo -e "${YELLOW}$RX_PUBLIC_KEY${NC}"
echo ""
echo "Füge diesen Key zur M1 Mac WireGuard Server-Konfiguration hinzu!"

log "✅ RX Node Setup komplett abgeschlossen!" 