# 🎩 GENTLEMAN

**Distributed AI Pipeline with Local Git Server**

> **Note**: This is the **FINAL VERSION** on GitHub. Future development continues on the local Git server.

## 🌟 Overview

GENTLEMAN is a **production-ready distributed AI pipeline** that combines:

- **🎤 Speech-to-Text (STT)** - M1 Mac optimized
- **🧠 Large Language Model (LLM)** - GPU accelerated on Worker Node  
- **🔊 Text-to-Speech (TTS)** - M1 Mac optimized
- **📚 Local Git Server** - Complete independence from external services
- **🔒 Matrix-based Authorization** - Secure update management
- **🌐 Nebula VPN Mesh** - Encrypted network communication

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   Worker Node   │    │    M1 Mac       │
│ 192.168.100.10  │◄──►│ 192.168.100.20  │
│                 │    │                 │
│ • LLM Server    │    │ • Git Server    │
│ • AI Pipeline   │    │ • STT Service   │
│ • Matrix Client │    │ • TTS Service   │
│ • Monitoring    │    │ • Development   │
└─────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### 🐧 **Linux (Empfohlen - Verbessertes Setup)**

```bash
# Clone this repository
git clone https://github.com/YOUR_USERNAME/gentleman.git
cd gentleman

# Automatisches Setup mit Hardware-Erkennung
make setup-linux-auto

# Services starten
make gentleman-up-auto
```

### 🖥️ **Universelles Setup**

#### Prerequisites

- **M1/M2 Mac** with Docker Desktop
- **Worker Node** (Linux/Windows) with Docker
- **Network**: Both devices on same subnet

#### 1. M1 Mac Setup (Git Server + STT/TTS)

```bash
# Clone this repository (last time from GitHub!)
git clone https://github.com/YOUR_USERNAME/gentleman.git
cd gentleman

# Hardware-Erkennung durchführen
make detect-hardware

# Setup M1 Mac Git Server
make git-setup-m1

# Start services
make start-stt
make start-tts
make git-start
```

#### 2. Worker Node Setup (LLM Server)

```bash
# Clone from your new local Git server
git clone https://192.168.100.20:3000/username/gentleman.git
cd gentleman

# Hardware-Erkennung und Setup
make detect-hardware
make setup-linux-improved  # Für Linux-Systeme

# Setup LLM server
make start-llm

# Setup monitoring
make start-monitoring
```

### 3. Test the Pipeline

```bash
# Run comprehensive tests
make test-ai-pipeline-full

# Test individual services
make test-services-health
```

## 📚 Local Git Server

After initial setup, **all development happens on your local Git server**:

- **Web Interface**: https://git.gentleman.local
- **SSH Access**: `ssh://git@git.gentleman.local:2222`
- **Network Access**: `https://192.168.100.20:3000`

### Migration from GitHub

```bash
# Add local Git server as remote
git remote add local https://git.gentleman.local/username/gentleman.git

# Push to local server
git push local main

# Set local as new origin
git remote set-url origin https://git.gentleman.local/username/gentleman.git
```

## 🔒 Security Features

- **🔐 SSL/TLS Encryption** - All communications encrypted
- **🛡️ Matrix Authorization** - Only registered devices can update
- **🌐 Nebula VPN Mesh** - Secure network overlay
- **🔑 SSH Key Authentication** - Secure Git operations
- **📊 Audit Logging** - Complete activity tracking

## 🛠️ Available Commands

### 🚀 Setup & Installation
```bash
# Linux Setup (Empfohlen)
make setup-linux-auto      # Automatisches Setup mit Hardware-Erkennung
make setup-linux-improved  # Verbessertes Linux-Setup
make setup-linux-test      # Setup-Komponenten testen

# Hardware-Erkennung
make detect-hardware        # Hardware analysieren und Node-Rolle bestimmen
make hardware-config        # Hardware-Konfiguration anzeigen

# Troubleshooting
make setup-fix             # Häufige Setup-Probleme beheben
make setup-clean           # Temporäre Dateien aufräumen
make setup-reset           # Komplettes Reset (VORSICHT!)
```

### 🌐 Nebula VPN Management
```bash
make nebula-status         # Nebula-Status anzeigen
make nebula-test           # Nebula-Konnektivität testen
make nebula-start          # Nebula-Service starten
make nebula-stop           # Nebula-Service stoppen
make nebula-restart        # Nebula-Service neustarten
make nebula-logs           # Nebula-Logs anzeigen
```

### Git Server Management
```bash
make git-setup-m1      # M1 Mac optimized setup
make git-start         # Start Git server
make git-stop          # Stop Git server
make git-backup        # Create backup
make git-demo          # Interactive demo
```

### AI Pipeline
```bash
make start-all         # Start all services
make test-ai-pipeline  # Quick pipeline test
make test-performance  # Performance benchmarks
make stop-all          # Stop all services
```

### Security & Updates
```bash
make security-harden   # Apply security hardening
make matrix-register   # Register device for updates
make update-system     # System updates via Matrix
```

## 📊 Monitoring

- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards  
- **Health Checks**: Automated service monitoring
- **Performance Metrics**: Real-time pipeline performance

Access: `http://192.168.100.10:3000` (Grafana)

## 🧪 Testing

Comprehensive test suite included:

- **End-to-End Pipeline Tests** - Full STT→LLM→TTS flow
- **Performance Benchmarks** - Latency and throughput metrics
- **Health Checks** - Service availability monitoring
- **Security Audits** - Automated security scanning

## 📁 Project Structure

```
gentleman/
├── 🎤 services/stt-service/     # Speech-to-Text (M1 Mac)
├── 🧠 services/llm-service/     # Language Model (Worker Node)
├── 🔊 services/tts-service/     # Text-to-Speech (M1 Mac)
├── 📚 config/git-server/        # Local Git server config
├── 🔒 scripts/security/         # Security hardening
├── 🧪 tests/                    # Comprehensive test suite
├── 📊 monitoring/               # Prometheus & Grafana
├── 🌐 nebula/                   # VPN mesh configuration
└── 🐳 docker-compose*.yml      # Service orchestration
```

## 🔧 Configuration

### Environment Variables

Copy `env.example` to `.env` and configure:

```bash
# Network Configuration
M1_MAC_IP=192.168.100.20
WORKER_NODE_IP=192.168.100.10

# Security
MATRIX_HOMESERVER=https://matrix.org
MATRIX_ACCESS_TOKEN=your_token_here

# Services
STT_MODEL=openai/whisper-large-v3
LLM_MODEL=microsoft/DialoGPT-large
TTS_MODEL=microsoft/speecht5_tts
```

## 🎯 Performance Goals

- **STT Latency**: < 3 seconds
- **LLM Response**: < 5 seconds  
- **TTS Generation**: < 2 seconds
- **Total Pipeline**: < 10 seconds

## 🔄 Backup & Recovery

- **Automated Backups**: Daily Git server backups
- **Time Machine Integration**: M1 Mac automatic backups
- **Configuration Backup**: All settings preserved
- **Disaster Recovery**: Complete system restoration

## 🌐 Network Requirements

- **Bandwidth**: 100 Mbps+ recommended
- **Latency**: < 10ms between nodes
- **Ports**: 8001-8005, 3000, 2222, 80, 443
- **VPN**: Nebula mesh overlay

## 📖 Documentation

- **[Git Server Setup](GIT_SERVER_M1_SETUP.md)** - M1 Mac Git server guide
- **[Security Checklist](SECURITY_CHECKLIST.md)** - Security hardening guide
- **[Testing Guide](tests/README.md)** - Comprehensive testing documentation

## 🚨 Important Notes

### ⚠️ This is the FINAL GitHub Version

- **No more GitHub updates** after this commit
- **All future development** happens on local Git server
- **Complete independence** from external Git hosting
- **Your data stays local** and under your control

### 🔄 Migration Path

1. **Setup local Git server** on M1 Mac
2. **Clone this repository** to local server
3. **Update all remotes** to point to local server
4. **Archive this GitHub repository**
5. **Continue development locally**

## 🎉 Features

✅ **Production Ready** - Fully tested and documented  
✅ **Distributed Architecture** - Optimized for M1 Mac + Worker Node  
✅ **Complete Independence** - No external dependencies  
✅ **Enterprise Security** - Matrix auth, SSL/TLS, VPN mesh  
✅ **Comprehensive Monitoring** - Prometheus, Grafana, health checks  
✅ **Automated Testing** - E2E tests, performance benchmarks  
✅ **Professional Documentation** - Setup guides, troubleshooting  
✅ **Backup & Recovery** - Multiple backup strategies  

## 📞 Support

Since this moves to a local Git server, support is self-managed:

- **Documentation**: Comprehensive guides included
- **Testing**: Automated test suite for validation
- **Monitoring**: Built-in health checks and metrics
- **Troubleshooting**: Detailed error handling and logs

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 🎯 Next Steps After GitHub

1. **Setup M1 Mac Git Server**: `make git-setup-m1`
2. **Migrate repositories**: Push to local Git server
3. **Update team access**: Configure local Git accounts
4. **Archive GitHub repo**: Set to read-only
5. **Enjoy independence**: Your AI pipeline, your rules! 🎩

**Welcome to the future of independent AI development!** 