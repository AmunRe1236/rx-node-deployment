#!/bin/bash
# 🚀 GENTLEMAN RX Node Quick Deployment (Kompakt)
echo "🚀 RX Node GPU Deployment gestartet..."

# System Update
sudo apt update && sudo apt upgrade -y

# Dependencies
sudo apt install -y wget curl git build-essential python3 python3-pip ufw fuse libfuse2

# AMD ROCm Installation
if lspci | grep -i "amd\|radeon"; then
    echo "🎮 AMD GPU erkannt - installiere ROCm..."
    wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -
    echo 'deb [arch=amd64] https://repo.radeon.com/rocm/apt/debian/ ubuntu main' | sudo tee /etc/apt/sources.list.d/rocm.list
    sudo apt update
    sudo apt install -y rocm-dev rocm-libs rocm-utils
    sudo usermod -a -G render,video $USER
fi

# LM Studio Download
mkdir -p ~/lm_studio_deployment && cd ~/lm_studio_deployment
wget "https://releases.lmstudio.ai/linux/x86/0.2.29/LM_Studio-0.2.29.AppImage"
chmod +x LM_Studio-0.2.29.AppImage

# Firewall
sudo ufw allow 1234/tcp && sudo ufw --force enable

# Launcher Script
cat > start_lm_studio.sh << 'EOF'
#!/bin/bash
export DISPLAY=:0
export ROCm_PATH=/opt/rocm
export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH
cd ~/lm_studio_deployment
echo "🤖 Starting LM Studio..."
./LM_Studio-0.2.29.AppImage --no-sandbox
EOF
chmod +x start_lm_studio.sh

echo "✅ Deployment abgeschlossen!"
echo "🚀 LM Studio starten: ./start_lm_studio.sh"
echo "🌐 Server URL: http://$(hostname -I | awk '{print $1}'):1234"
echo "🔊 GPU-Lüfter werden bei Inferenz hörbar sein!" 