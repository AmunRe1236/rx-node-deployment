# 🎩 Gentleman Nebula Mesh Network Deployment

## 🌐 Network Architecture

```
M1 Node (Lighthouse)     RX Node (Client)        I7 Node (Client)
192.168.100.1           192.168.100.10          192.168.100.30
192.168.68.111:4243     192.168.100.10:4243     192.168.100.30:4243
```

## 🔐 Certificate Authority

- **CA Created**: `ca.crt` / `ca.key`
- **M1 Lighthouse**: `m1-lighthouse.crt` / `m1-lighthouse.key`
- **RX Node**: `rx-node.crt` / `rx-node.key`
- **I7 Node**: `i7-node.crt` / `i7-node.key`

## 🚀 Deployment Steps

### M1 Node (Lighthouse) - COMPLETED ✅
```bash
cd nebula/m1-node
sudo nebula -config config.yml > nebula.log 2>&1 &
```

### RX Node Setup
```bash
# Copy files to RX Node
scp rx-node-certs.tar.gz setup-rx-node.sh user@192.168.100.10:~/

# On RX Node
./setup-rx-node.sh
```

### I7 Node Setup
```bash
# Copy files to I7 Node
scp i7-node-certs.tar.gz setup-i7-node.sh user@192.168.100.30:~/

# On I7 Node
./setup-i7-node.sh
```

## 🔍 Testing Connectivity

```bash
# From any node, test mesh connectivity
ping 192.168.100.1   # M1 Lighthouse
ping 192.168.100.10  # RX Node
ping 192.168.100.30  # I7 Node

# Test service discovery
curl http://192.168.100.10:8005/discovery.json
curl http://192.168.100.30:8005/discovery.json
```

## 📊 Status Check

```bash
# Check Nebula process
ps aux | grep nebula

# Check interface
ifconfig utun7  # macOS
ifconfig nebula1  # Linux

# Check logs
tail -f nebula.log
```

## 🔧 Troubleshooting

- **Port conflicts**: Nebula uses 4243/udp
- **Firewall**: Allow UDP 4243 and TCP 8000-8010
- **Interface**: macOS uses utun*, Linux uses nebula1
- **Certificates**: Must be in same directory as config.yml 