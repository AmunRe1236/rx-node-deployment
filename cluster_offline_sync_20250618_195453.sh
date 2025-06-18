#!/bin/bash
# Offline SSH Key Sync for GENTLEMAN Cluster
# Generated: Wed Jun 18 19:55:44 CEST 2025
# Rotation ID: 20250618_195453

echo "🔄 GENTLEMAN Cluster Offline Key Sync"
echo "===================================="

# New public key to add:
NEW_PUBLIC_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKkCYEbfDIcYEoD48dO3mkoKEqDCMfiRXZT+L8RSDkC9 gentleman-cluster-m1-mac-20250618_195453'

# Add to authorized_keys
mkdir -p ~/.ssh
echo "$NEW_PUBLIC_KEY" >> ~/.ssh/authorized_keys
sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

echo "✅ New cluster key added to authorized_keys"
echo "🔑 Key fingerprint: 256 SHA256:JT5YWOq2KipQxqRovawF42/U0Qe5lpmv7vtl80DLzA4 gentleman-cluster-m1-mac-20250618_195453 (ED25519)"
echo "📅 Rotation timestamp: 20250618_195453"
