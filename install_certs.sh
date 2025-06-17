#!/bin/bash

echo "🔑 Installing Nebula Certificates for RX Node..."

# Create CA certificate
sudo tee /etc/nebula/ca.crt << 'EOF'
-----BEGIN NEBULA CERTIFICATE-----
CkMKEUdlbnRsZW1hbi1NZXNoLUNBKJDIvMIGMJCvwdEGOiDVHuYLyNBeG2rIOtT4
MqR4ydzYTZtr+gLpvodPrW5aNUABEkA23wPP2l5u/310ghltpQNnFAgVkzAca3K6
p36pM44dXqUu8KJEKnlyWmwELDnY6FnY+u0vcmgJ0sRUobcZnY4G
-----END NEBULA CERTIFICATE-----
EOF

# Create RX Node certificate
sudo tee /etc/nebula/rx.crt << 'EOF'
-----BEGIN NEBULA CERTIFICATE-----
CooBCgdyeC1ub2RlEgqKyKGFDID+//8PIg5hdWRpby1zZXJ2aWNlcyIHY2xpZW50
cyIKbW9uaXRvcmluZyilyLzCBjCPr8HRBjog49fkISWRNJ+LAW2VlWMDuP2Xy7KF
5PfjUuYwk9GWH01KIMG0U5CkD/taln4YtZe185kUAEgdGnjGFXCNQW1n9YAOEkAZ
AIeG9TQGlnfkvc/AYHMHy0hZ0nYBOXAOu8481fjvjLrToCWAEEj37WpsUOa0zwvN
Qmix8IR+sHwCz5EmThIE
-----END NEBULA CERTIFICATE-----
EOF

# Create RX Node private key
sudo tee /etc/nebula/rx.key << 'EOF'
-----BEGIN NEBULA X25519 PRIVATE KEY-----
cIiJeL+Ebi8A2xs796ShWgK98GAjSaSQeaikz83k6j0=
-----END NEBULA X25519 PRIVATE KEY-----
EOF

# Set correct permissions
sudo chmod 600 /etc/nebula/rx.key
sudo chmod 644 /etc/nebula/ca.crt
sudo chmod 644 /etc/nebula/rx.crt
sudo chown root:root /etc/nebula/*

echo "✅ Certificates installed successfully!"
echo "📋 Certificate files:"
ls -la /etc/nebula/

echo "🚀 Ready to start Nebula!" 