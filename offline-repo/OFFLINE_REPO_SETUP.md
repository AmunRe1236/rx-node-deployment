# 🎩 Gentleman Offline Repository Setup

## 🌐 **System Architecture**

```
GitHub (Origin) ──sync──> M1 Gitea Server ──mesh──> RX/I7 Nodes
                          192.168.100.1:3010
```

## ✅ **Current Status**

- ✅ **Gitea Server**: Running on http://192.168.100.1:3010
- ✅ **SSH Access**: Available on port 2223
- ✅ **Health Check**: Passing
- 🔄 **Git Sync**: Manual setup required

## 🚀 **Quick Start**

### 1. Access Gitea Web Interface
```bash
# From M1 Node
open http://localhost:3010

# From other nodes (via Nebula)
curl http://192.168.100.1:3010
```

### 2. Initial Setup
1. Create admin user: `gentleman`
2. Create organization: `gentleman`
3. Create repository: `gentleman`

### 3. Manual Repository Sync
```bash
# Clone from GitHub
git clone https://github.com/amonbaumgartner/Gentleman.git /tmp/gentleman-sync

# Add Gitea as remote
cd /tmp/gentleman-sync
git remote add gitea http://192.168.100.1:3010/gentleman/gentleman.git

# Push to Gitea
git push gitea master
```

## 🔧 **Node Sync Client Usage**

### RX Node Setup
```bash
# Copy sync client and config
scp scripts/node-sync-client.py configs/rx-node-sync-config.json user@192.168.100.10:~/

# On RX Node
python3 node-sync-client.py rx-node-sync-config.json
```

### I7 Node Setup
```bash
# Copy sync client and config
scp scripts/node-sync-client.py configs/i7-node-sync-config.json user@192.168.100.30:~/

# On I7 Node
python3 node-sync-client.py i7-node-sync-config.json
```

## 🔍 **Testing Sync**

### Test from M1 Node
```bash
# Test Gitea API
curl http://localhost:3010/api/v1/repos/gentleman/gentleman

# Test repository access
git clone http://192.168.100.1:3010/gentleman/gentleman.git /tmp/test-clone
```

### Test from RX/I7 Nodes (via Nebula)
```bash
# Test connectivity
ping 192.168.100.1

# Test Gitea access
curl http://192.168.100.1:3010/api/healthz

# Test repository clone
git clone http://192.168.100.1:3010/gentleman/gentleman.git /opt/gentleman
```

## 📊 **Monitoring**

### Service Status
```bash
# Check containers
docker-compose ps

# Check logs
docker logs gentleman-git-server
docker logs gentleman-git-sync
```

### Sync Status
```bash
# Check sync client logs
tail -f /var/log/gentleman-sync.log

# Check repository status
cd /opt/gentleman && git status
```

## 🔧 **Configuration**

### Sync Intervals
- **Default**: 5 minutes (300 seconds)
- **Fast**: 1 minute (60 seconds)
- **Slow**: 15 minutes (900 seconds)

### Network Ports
- **HTTP**: 3010
- **SSH**: 2223
- **Nebula**: 4243/udp

## 🚨 **Troubleshooting**

### Common Issues
1. **Port conflicts**: Check `lsof -i :3010`
2. **Nebula connectivity**: Check `ping 192.168.100.1`
3. **Git authentication**: Use HTTP for now, SSH later
4. **Sync failures**: Check network connectivity

### Recovery Commands
```bash
# Restart services
docker-compose restart

# Reset repository
rm -rf /opt/gentleman && git clone http://192.168.100.1:3010/gentleman/gentleman.git /opt/gentleman

# Check Nebula status
ifconfig utun7  # M1
ifconfig nebula1  # Linux
``` 