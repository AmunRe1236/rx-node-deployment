# 🎩 RX Node Connection Guide

## 🌐 **Current Status**

✅ **M1 Lighthouse**: Active on `192.168.100.1:4243` (interface: `utun7`)  
✅ **Nebula Network**: `192.168.100.0/24`  
✅ **Deployment Package**: `rx-node-deployment.tar.gz` ready  
⏳ **RX Node**: Ready to connect to `192.168.100.10`

## 📦 **Deployment Package Contents**

```
rx-node-deployment.tar.gz
├── nebula/rx-node/
│   ├── config.yml          # Nebula configuration
│   ├── ca.crt              # Certificate Authority
│   ├── rx-node.crt         # RX Node certificate
│   └── rx-node.key         # RX Node private key
├── nebula/rx-node-setup.sh  # Automated setup script
├── offline-repo/scripts/node-sync-client.py  # Repository sync client
└── offline-repo/configs/rx-node-sync-config.json  # Sync configuration
```

## 🚀 **RX Node Setup Instructions**

### 1. Transfer Deployment Package
```bash
# From M1 Node
scp rx-node-deployment.tar.gz user@192.168.100.10:~/
```

### 2. Extract and Setup on RX Node
```bash
# On RX Node (192.168.100.10)
tar -xzf rx-node-deployment.tar.gz
sudo ./nebula/rx-node-setup.sh
```

### 3. Verify Connection
```bash
# Check Nebula service
sudo systemctl status nebula-gentleman

# Check network interface
ip addr show nebula1

# Test lighthouse connectivity
ping 192.168.100.1

# Test M1 services
curl http://192.168.100.1:3010/api/healthz
```

## 🔧 **Manual Setup (Alternative)**

### Install Nebula
```bash
sudo apt update
sudo apt install wget

# Download Nebula
wget https://github.com/slackhq/nebula/releases/download/v1.9.5/nebula-linux-amd64.tar.gz
tar -xzf nebula-linux-amd64.tar.gz
sudo mv nebula /usr/local/bin/
sudo mv nebula-cert /usr/local/bin/
```

### Configure Nebula
```bash
sudo mkdir -p /opt/gentleman/nebula
cd /opt/gentleman/nebula

# Copy certificates and config
sudo cp ~/nebula/rx-node/* ./
sudo chmod 600 *.key *.crt
sudo chmod 644 config.yml ca.crt
```

### Start Nebula
```bash
# Test configuration
sudo nebula -config config.yml -test

# Start service
sudo nebula -config config.yml &
```

## 🌐 **Network Configuration**

### Nebula Network Layout
```
M1 Lighthouse:  192.168.100.1  (utun7)
RX Node:        192.168.100.10 (nebula1)
I7 Node:        192.168.100.30 (nebula1)
```

### Physical Network
```
M1 Node:  192.168.68.111  (en0)
RX Node:  192.168.100.10  (eth0) - via Nebula
I7 Node:  192.168.100.30  (eth0) - via Nebula
```

## 🔍 **Troubleshooting**

### Connection Issues
```bash
# Check lighthouse connectivity
ping 192.168.100.1

# Check Nebula logs
sudo journalctl -u nebula-gentleman -f

# Check firewall
sudo ufw status
sudo iptables -L
```

### Service Issues
```bash
# Restart Nebula
sudo systemctl restart nebula-gentleman

# Check configuration
sudo nebula -config /opt/gentleman/nebula/config.yml -test

# Manual start for debugging
sudo nebula -config /opt/gentleman/nebula/config.yml
```

## 📊 **Expected Results**

After successful setup:

1. **Nebula Interface**: `nebula1` with IP `192.168.100.10`
2. **Lighthouse Ping**: `ping 192.168.100.1` should work
3. **Service Status**: `systemctl status nebula-gentleman` shows active
4. **Gitea Access**: `curl http://192.168.100.1:3010` should respond

## 🔄 **Repository Sync Setup**

After Nebula connection is established:

```bash
# Start sync client
python3 node-sync-client.py rx-node-sync-config.json

# Or install as service
sudo cp node-sync-client.py /opt/gentleman/
sudo cp rx-node-sync-config.json /opt/gentleman/
```

## 📞 **Support Commands**

```bash
# Check M1 lighthouse status
ssh user@192.168.68.111 "ifconfig utun7"

# Monitor lighthouse logs
ssh user@192.168.68.111 "tail -f /Users/amonbaumgartner/Gentleman/nebula/m1-node/nebula.log"

# Test from M1 to RX
ssh user@192.168.68.111 "ping 192.168.100.10"
``` 