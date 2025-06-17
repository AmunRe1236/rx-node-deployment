#!/bin/bash
# 🎩 Gentleman RX Node - Nebula Setup Script

echo "🎩 Setting up Gentleman RX Node for Nebula Mesh..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (sudo)"
    exit 1
fi

# Create nebula directory
mkdir -p /opt/gentleman/nebula
cd /opt/gentleman/nebula

# Copy configuration files
echo "📋 Installing Nebula configuration..."
cp rx-node/config.yml ./
cp rx-node/ca.crt ./
cp rx-node/rx-node.crt ./
cp rx-node/rx-node.key ./

# Set proper permissions
chmod 600 *.key *.crt
chmod 644 config.yml ca.crt

# Install nebula if not present
if ! command -v nebula &> /dev/null; then
    echo "📦 Installing Nebula..."
    
    # Download nebula binary
    NEBULA_VERSION="1.9.5"
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        ARCH="arm64"
    fi
    
    wget -O nebula.tar.gz "https://github.com/slackhq/nebula/releases/download/v${NEBULA_VERSION}/nebula-linux-${ARCH}.tar.gz"
    tar -xzf nebula.tar.gz
    mv nebula /usr/local/bin/
    mv nebula-cert /usr/local/bin/
    rm nebula.tar.gz
    
    echo "✅ Nebula installed"
fi

# Create systemd service
echo "🔧 Creating systemd service..."
cat > /etc/systemd/system/nebula-gentleman.service << EOF
[Unit]
Description=Gentleman Nebula Mesh Network
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/gentleman/nebula
ExecStart=/usr/local/bin/nebula -config config.yml
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable nebula-gentleman
systemctl start nebula-gentleman

# Check status
echo "🔍 Checking Nebula status..."
sleep 3
systemctl status nebula-gentleman --no-pager

# Test connectivity
echo "🌐 Testing connectivity to lighthouse..."
ping -c 3 192.168.100.1

echo "✅ RX Node setup complete!"
echo "📡 Nebula IP: 192.168.100.10"
echo "🏠 Lighthouse: 192.168.100.1"
echo ""
echo "🔧 Useful commands:"
echo "  systemctl status nebula-gentleman"
echo "  journalctl -u nebula-gentleman -f"
echo "  ip addr show nebula1" 