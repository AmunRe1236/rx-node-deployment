#!/bin/bash
# 🚀 GENTLEMAN RX Node Quick Deploy
# Kompakte Version für schnelle RX Node Einrichtung
# AMD RX 6700 XT + Ubuntu + LM Studio + WireGuard

echo "🎮 RX Node GPU Deployment gestartet..."

# System Update
echo "📦 System Updates..."
sudo apt update && sudo apt upgrade -y

# Dependencies
echo "🔧 Dependencies Installation..."
sudo apt install -y wget curl git build-essential python3 python3-pip ufw fuse libfuse2 wireguard wireguard-tools

# AMD ROCm Installation
echo "🎮 Prüfe AMD GPU..."
if lspci | grep -i "amd\|radeon"; then
    echo "🎯 AMD GPU erkannt - installiere ROCm..."
    wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -
    echo 'deb [arch=amd64] https://repo.radeon.com/rocm/apt/debian/ ubuntu main' | sudo tee /etc/apt/sources.list.d/rocm.list
    sudo apt update
    sudo apt install -y rocm-dev rocm-libs rocm-utils rocm-smi
    sudo usermod -a -G render,video $USER
    
    # RX 6700 XT Optimierung
    if lspci | grep -i "6700"; then
        echo 'export HSA_OVERRIDE_GFX_VERSION=10.3.0' >> ~/.bashrc
        echo 'export ROCM_PATH=/opt/rocm' >> ~/.bashrc
        echo 'export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
        echo "🎯 RX 6700 XT Optimierungen aktiviert"
    fi
else
    echo "⚠️ Keine AMD GPU gefunden"
fi

# LM Studio Download
echo "🤖 LM Studio Download..."
mkdir -p ~/rx_deployment && cd ~/rx_deployment
wget "https://releases.lmstudio.ai/linux/x86/0.2.29/LM_Studio-0.2.29.AppImage"
chmod +x LM_Studio-0.2.29.AppImage

# WireGuard Setup
echo "🔐 WireGuard Setup..."
wg genkey > rx_private.key
wg pubkey < rx_private.key > rx_public.key
chmod 600 rx_private.key

RX_PRIVATE=$(cat rx_private.key)
RX_PUBLIC=$(cat rx_public.key)

# WireGuard Config
cat > rx_wg0.conf << EOF
[Interface]
PrivateKey = $RX_PRIVATE
Address = 10.0.0.3/24
DNS = 8.8.8.8

[Peer]
PublicKey = 4+UBqx/VdhKLCZnQqgsgWEUAoi8co+FHT4fsl8Mp81k=
Endpoint = 192.168.68.111:51820
AllowedIPs = 192.168.68.0/24, 10.0.0.0/24
PersistentKeepalive = 25
EOF

sudo mkdir -p /etc/wireguard
sudo mv rx_wg0.conf /etc/wireguard/wg0.conf
sudo chmod 600 /etc/wireguard/wg0.conf

# Firewall
echo "🔥 Firewall Setup..."
sudo ufw allow 1234/tcp
sudo ufw allow 51820/udp
sudo ufw --force enable

# Launcher Scripts
echo "🚀 Launcher Scripts..."

# GPU Launcher
cat > start_rx_gpu.sh << 'EOF'
#!/bin/bash
export DISPLAY=:0
export ROCM_PATH=/opt/rocm
export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH
export HSA_OVERRIDE_GFX_VERSION=10.3.0
cd ~/rx_deployment
echo "🎮 Starte LM Studio mit AMD GPU..."
./LM_Studio-0.2.29.AppImage --no-sandbox
EOF
chmod +x start_rx_gpu.sh

# VPN Starter
cat > start_vpn.sh << 'EOF'
#!/bin/bash
echo "🔐 Starte VPN..."
sudo wg-quick up wg0
echo "✅ VPN aktiv: 10.0.0.3"
ping -c 2 10.0.0.1 || echo "⚠️ M1 Mac nicht erreichbar"
EOF
chmod +x start_vpn.sh

# GPU Test
cat > test_gpu.sh << 'EOF'
#!/bin/bash
echo "🧪 GPU Test..."
rocm-smi || echo "ROCm nicht verfügbar"
curl -s http://localhost:1234/v1/models | head || echo "LM Studio Server nicht aktiv"
EOF
chmod +x test_gpu.sh

echo ""
echo "✅ RX Node Deployment abgeschlossen!"
echo ""
echo "📋 NÄCHSTE SCHRITTE:"
echo "1. 🔐 VPN starten: ./start_vpn.sh"
echo "2. 🎮 LM Studio starten: ./start_rx_gpu.sh"
echo "3. 📥 Modell downloaden (qwen2.5-7b empfohlen)"
echo "4. 🌐 Server aktivieren: Port 1234, GPU ON"
echo "5. 🧪 Test: ./test_gpu.sh"
echo ""
echo "🎯 RX Public Key für M1 Mac Server:"
echo "$RX_PUBLIC"
echo ""
echo "🌐 Server URL: http://$(hostname -I | awk '{print $1}'):1234"
echo "🔊 GPU-Lüfter werden bei Inferenz hörbar!"

# Reboot Hinweis
if lspci | grep -i "amd"; then
    echo ""
    echo "⚠️ WICHTIG: Neustart für ROCm empfohlen:"
    echo "sudo reboot"
fi 