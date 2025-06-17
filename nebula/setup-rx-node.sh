#!/bin/bash
# 🎩 Gentleman RX Node - Nebula Setup Script

echo "🚀 Setting up Nebula on RX Node..."

# Extract certificates
tar -xzf rx-node-certs.tar.gz

# Install nebula if not present
if ! command -v nebula &> /dev/null; then
    echo "Installing Nebula..."
    wget https://github.com/slackhq/nebula/releases/download/v1.9.5/nebula-linux-amd64.tar.gz
    tar -xzf nebula-linux-amd64.tar.gz
    sudo mv nebula /usr/local/bin/
    sudo mv nebula-cert /usr/local/bin/
fi

# Start Nebula
cd rx-node
sudo nebula -config config.yml > nebula.log 2>&1 &

echo "✅ Nebula RX Node started!"
echo "Check logs: tail -f rx-node/nebula.log"
echo "Test connectivity: ping 192.168.100.1" 