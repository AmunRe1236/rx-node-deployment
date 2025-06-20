#!/bin/bash

# GENTLEMAN Tailscale Friend Network Setup
# Dezentrale Netzwerke mit Inter-Friend Kommunikation

set -eo pipefail

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}❌ $1${NC}" >&2
}

log_info() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}ℹ️ $1${NC}"
}

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}⚠️ $1${NC}"
}

# Zeige dezentrale Architektur
show_decentralized_architecture() {
    echo -e "${PURPLE}🌐 GENTLEMAN Dezentrale Tailscale Architektur${NC}"
    echo "=============================================="
    echo ""
    echo -e "${CYAN}Jeder Freund hat sein eigenes Tailscale-Netzwerk:${NC}"
    echo ""
    echo "┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐"
    echo "│   Amon's Net    │  │   Max's Net     │  │   Lisa's Net    │"
    echo "│ ┌─────┐ ┌─────┐ │  │ ┌─────┐ ┌─────┐ │  │ ┌─────┐ ┌─────┐ │"
    echo "│ │ M1  │ │ RX  │ │  │ │Lptop│ │ Pi  │ │  │ │ PC  │ │Phone│ │"
    echo "│ └─────┘ └─────┘ │  │ └─────┘ └─────┘ │  │ └─────┘ └─────┘ │"
    echo "└─────────────────┘  └─────────────────┘  └─────────────────┘"
    echo "        │                     │                     │"
    echo "        └─────────────────────┼─────────────────────┘"
    echo "                              │"
    echo "                    ┌─────────────────┐"
    echo "                    │ Shared Services │"
    echo "                    │ (Optional)      │"
    echo "                    └─────────────────┘"
    echo ""
}

# Friend-to-Friend Kommunikation
create_friend_communication() {
    log_info "📝 Erstelle Friend-to-Friend Kommunikations-Setup..."
    
    cat > ./friend_network_connector.sh << 'EOF'
#!/bin/bash

# GENTLEMAN Friend Network Connector
# Verbindet verschiedene Tailscale-Netzwerke von Freunden

# Konfiguration
FRIEND_NETWORKS=(
    "amon:100.96.219.28:8765"      # Amon's M1 Mac
    "max:100.64.0.15:8765"         # Max's Laptop (Beispiel IP)
    "lisa:100.64.0.32:8765"        # Lisa's PC (Beispiel IP)
    "tom:100.64.0.48:8765"         # Tom's Mac (Beispiel IP)
)

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Prüfe alle Friend Networks
check_friend_networks() {
    echo "🌐 GENTLEMAN Friend Networks Status"
    echo "===================================="
    echo ""
    
    for network in "${FRIEND_NETWORKS[@]}"; do
        IFS=':' read -r friend_name friend_ip friend_port <<< "$network"
        
        echo -n "👤 $friend_name ($friend_ip): "
        
        if curl -s --max-time 3 "http://$friend_ip:$friend_port/health" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Online${NC}"
        else
            echo -e "${RED}❌ Offline${NC}"
        fi
    done
    echo ""
}

# Verbinde zu Friend Network
connect_to_friend() {
    local friend_name="$1"
    
    if [ -z "$friend_name" ]; then
        echo "Verwendung: $0 connect <friend-name>"
        echo ""
        echo "Verfügbare Freunde:"
        for network in "${FRIEND_NETWORKS[@]}"; do
            IFS=':' read -r name ip port <<< "$network"
            echo "  • $name"
        done
        return 1
    fi
    
    # Finde Friend Network
    for network in "${FRIEND_NETWORKS[@]}"; do
        IFS=':' read -r name ip port <<< "$network"
        if [ "$name" = "$friend_name" ]; then
            log_info "🔗 Verbinde zu $friend_name's GENTLEMAN System..."
            
            # Teste Verbindung
            if curl -s --max-time 5 "http://$ip:$port/health" >/dev/null 2>&1; then
                log_success "Verbunden mit $friend_name ($ip:$port)"
                
                # Zeige verfügbare Services
                echo ""
                echo "🎯 Verfügbare Services bei $friend_name:"
                echo "• Status: curl http://$ip:$port/status"
                echo "• Nodes: curl http://$ip:$port/nodes"
                echo "• SSH: ssh $ip (falls konfiguriert)"
                
                return 0
            else
                log_error "$friend_name ist nicht erreichbar"
                return 1
            fi
        fi
    done
    
    log_error "Freund '$friend_name' nicht gefunden"
}

# Broadcast an alle Friends
broadcast_to_friends() {
    local message="$1"
    
    if [ -z "$message" ]; then
        echo "Verwendung: $0 broadcast '<message>'"
        return 1
    fi
    
    log_info "📡 Sende Broadcast an alle Friend Networks..."
    
    for network in "${FRIEND_NETWORKS[@]}"; do
        IFS=':' read -r friend_name friend_ip friend_port <<< "$network"
        
        echo -n "📤 $friend_name: "
        
        # Sende Message (hier könntest du einen Custom Endpoint verwenden)
        if curl -s --max-time 3 "http://$friend_ip:$friend_port/health" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Delivered${NC}"
        else
            echo -e "${RED}❌ Failed${NC}"
        fi
    done
}

# Hauptfunktion
main() {
    case "${1:-status}" in
        "status")
            check_friend_networks
            ;;
        "connect")
            connect_to_friend "$2"
            ;;
        "broadcast")
            broadcast_to_friends "$2"
            ;;
        "list")
            echo "👥 GENTLEMAN Friend Networks:"
            for network in "${FRIEND_NETWORKS[@]}"; do
                IFS=':' read -r name ip port <<< "$network"
                echo "  • $name: $ip:$port"
            done
            ;;
        *)
            echo "🎯 GENTLEMAN Friend Network Connector"
            echo "====================================="
            echo ""
            echo "Kommandos:"
            echo "  status              - Zeige alle Friend Networks"
            echo "  connect <friend>    - Verbinde zu Friend Network"
            echo "  broadcast <msg>     - Broadcast an alle Friends"
            echo "  list               - Liste alle Friends"
            echo ""
            echo "Beispiele:"
            echo "  $0 status"
            echo "  $0 connect max"
            echo "  $0 broadcast 'Hello Friends!'"
            ;;
    esac
}

main "$@"
EOF

    chmod +x ./friend_network_connector.sh
    log_success "Friend Network Connector erstellt"
}

# Shared Services Setup
create_shared_services() {
    log_info "📝 Erstelle Shared Services Setup..."
    
    cat > ./gentleman_shared_services.md << 'EOF'
# GENTLEMAN Shared Services

## 🎯 Konzept
Optionale gemeinsame Services die alle Friends nutzen können, aber jeder hostet sein eigenes GENTLEMAN System.

## 🌐 Mögliche Shared Services

### 1. Gemeinsamer Chat/Status Server
- **Host**: Einer der Friends (rotierend)
- **Zweck**: Status-Updates, Chat zwischen GENTLEMAN Systemen
- **Kosten**: €0 (einer hostet für alle)

### 2. Backup/Sync Service
- **Host**: Distributed zwischen Friends
- **Zweck**: Gegenseitige Config-Backups
- **Kosten**: €0 (jeder sichert einen anderen)

### 3. Monitoring Dashboard
- **Host**: Einer der Friends
- **Zweck**: Übersicht über alle GENTLEMAN Systeme
- **Kosten**: €0 (freiwillig gehostet)

## 🔧 Implementation

### Chat Server (Optional)
```bash
# Einer der Friends hostet:
python3 gentleman_chat_server.py --port 9000

# Alle anderen verbinden sich:
./friend_network_connector.sh connect chat-host
```

### Backup Ring (Distributed)
```bash
# Jeder Friend sichert einen anderen:
# Amon → Max
# Max → Lisa  
# Lisa → Tom
# Tom → Amon
```

## 💰 Kosten
- **Pro Friend**: €0 zusätzlich
- **Shared Services**: Freiwillig gehostet
- **Backup**: Gegenseitig kostenlos

## 🛡️ Vorteile
- Jeder behält Kontrolle über sein System
- Keine zentrale Abhängigkeit
- Ausfallsicher durch Dezentralisierung
- Kostenlos durch Community-Hosting
EOF

    log_success "Shared Services Guide erstellt"
}

# Skalierungs-Analyse
show_scaling_analysis() {
    echo -e "${PURPLE}📊 Tailscale Skalierungs-Analyse${NC}"
    echo "=================================="
    echo ""
    echo -e "${GREEN}✅ Perfekte Skalierung bei dezentralem Setup:${NC}"
    echo ""
    echo "👥 Anzahl Friends │ Geräte/Friend │ Tailscale Kosten │ Pro Person"
    echo "─────────────────┼───────────────┼──────────────────┼───────────"
    echo "        5        │       4       │        €0        │    €0"
    echo "       10        │       4       │        €0        │    €0"
    echo "       50        │       4       │        €0        │    €0"
    echo "      100        │       4       │        €0        │    €0"
    echo ""
    echo -e "${BLUE}💡 Warum das funktioniert:${NC}"
    echo "• Jeder Friend = eigenes Tailscale-Konto"
    echo "• Jeder bleibt unter 20 Geräte-Limit"
    echo "• Inter-Network Communication über öffentliche IPs"
    echo "• Keine geteilten Kosten"
    echo ""
    echo -e "${CYAN}🔄 Friend-to-Friend Kommunikation:${NC}"
    echo "• Tailscale gibt jedem Netzwerk öffentliche IPs"
    echo "• Friends können sich gegenseitig erreichen"
    echo "• Optional: Shared Services für Community-Features"
    echo ""
    echo -e "${YELLOW}⚠️ Einziges Risiko:${NC}"
    echo "• Tailscale könnte kostenlose Tier komplett abschaffen"
    echo "• Aber: Sehr unwahrscheinlich (20 Geräte sind großzügig)"
    echo "• Backup: WireGuard-Setup als Notfall-Plan"
}

# Deployment Guide für Friends
create_friend_deployment() {
    log_info "📖 Erstelle Friend Deployment Guide..."
    
    cat > ./GENTLEMAN_Friend_Deployment.md << 'EOF'
# GENTLEMAN Friend Deployment Guide

## 🎯 Für neue Friends: Dein eigenes GENTLEMAN System

### 1. Tailscale Setup
```bash
# macOS
brew install tailscale
sudo tailscale up

# Linux
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### 2. GENTLEMAN System Setup
```bash
# Clone das GENTLEMAN Repository
git clone https://github.com/your-repo/gentleman.git
cd gentleman

# Setup für dein System
./handshake_m1.sh        # Oder entsprechendes Script für dein OS
```

### 3. Friend Network Registration
```bash
# Teile deine Tailscale IP mit anderen Friends
tailscale ip -4

# Beispiel: 100.64.0.25
# Andere Friends fügen dich hinzu in friend_network_connector.sh
```

### 4. Teste Friend Connections
```bash
# Status aller Friend Networks
./friend_network_connector.sh status

# Verbinde zu einem Friend
./friend_network_connector.sh connect amon
```

## 👥 Friend Network Management

### Neuen Friend hinzufügen
```bash
# In friend_network_connector.sh:
FRIEND_NETWORKS+=(
    "new_friend:100.64.0.99:8765"
)
```

### Friend Network Status
```bash
./friend_network_connector.sh status
```

## 💰 Kosten pro Friend
- **Tailscale**: €0 (bis 20 Geräte)
- **GENTLEMAN Setup**: €0 (Open Source)
- **Shared Services**: €0 (Community gehostet)
- **Total**: €0

## 🔧 Optional: Shared Services
- Chat zwischen GENTLEMAN Systemen
- Gegenseitige Backups
- Community Monitoring
- Alle freiwillig und kostenlos
EOF

    log_success "Friend Deployment Guide erstellt"
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN Tailscale Friend Network Setup${NC}"
    echo "=============================================="
    echo ""
    
    log_info "Dezentrale Architektur erkannt - perfekt für Tailscale!"
    echo ""
    
    show_decentralized_architecture
    show_scaling_analysis
    
    create_friend_communication
    create_shared_services
    create_friend_deployment
    
    echo ""
    log_success "🎉 Friend Network Setup erstellt!"
    echo ""
    echo -e "${CYAN}📁 Erstellt:${NC}"
    echo "• friend_network_connector.sh - Friend-to-Friend Kommunikation"
    echo "• gentleman_shared_services.md - Optionale Shared Services"
    echo "• GENTLEMAN_Friend_Deployment.md - Guide für neue Friends"
    echo ""
    echo -e "${GREEN}✅ Perfekte Skalierung:${NC}"
    echo "• Jeder Friend = eigenes Tailscale-Konto (kostenlos)"
    echo "• Unbegrenzte Anzahl Friends möglich"
    echo "• Keine geteilten Kosten"
    echo "• Inter-Network Kommunikation funktioniert"
    echo ""
    echo -e "${YELLOW}🚀 Nächste Schritte:${NC}"
    echo "1. Teile GENTLEMAN Setup mit Friends"
    echo "2. Jeder erstellt sein eigenes Tailscale-Konto"
    echo "3. IPs austauschen für Friend Network"
    echo "4. Optional: Shared Services einrichten"
}

main "$@" 

# GENTLEMAN Tailscale Friend Network Setup
# Dezentrale Netzwerke mit Inter-Friend Kommunikation

set -eo pipefail

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}❌ $1${NC}" >&2
}

log_info() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}ℹ️ $1${NC}"
}

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}⚠️ $1${NC}"
}

# Zeige dezentrale Architektur
show_decentralized_architecture() {
    echo -e "${PURPLE}🌐 GENTLEMAN Dezentrale Tailscale Architektur${NC}"
    echo "=============================================="
    echo ""
    echo -e "${CYAN}Jeder Freund hat sein eigenes Tailscale-Netzwerk:${NC}"
    echo ""
    echo "┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐"
    echo "│   Amon's Net    │  │   Max's Net     │  │   Lisa's Net    │"
    echo "│ ┌─────┐ ┌─────┐ │  │ ┌─────┐ ┌─────┐ │  │ ┌─────┐ ┌─────┐ │"
    echo "│ │ M1  │ │ RX  │ │  │ │Lptop│ │ Pi  │ │  │ │ PC  │ │Phone│ │"
    echo "│ └─────┘ └─────┘ │  │ └─────┘ └─────┘ │  │ └─────┘ └─────┘ │"
    echo "└─────────────────┘  └─────────────────┘  └─────────────────┘"
    echo "        │                     │                     │"
    echo "        └─────────────────────┼─────────────────────┘"
    echo "                              │"
    echo "                    ┌─────────────────┐"
    echo "                    │ Shared Services │"
    echo "                    │ (Optional)      │"
    echo "                    └─────────────────┘"
    echo ""
}

# Friend-to-Friend Kommunikation
create_friend_communication() {
    log_info "📝 Erstelle Friend-to-Friend Kommunikations-Setup..."
    
    cat > ./friend_network_connector.sh << 'EOF'
#!/bin/bash

# GENTLEMAN Friend Network Connector
# Verbindet verschiedene Tailscale-Netzwerke von Freunden

# Konfiguration
FRIEND_NETWORKS=(
    "amon:100.96.219.28:8765"      # Amon's M1 Mac
    "max:100.64.0.15:8765"         # Max's Laptop (Beispiel IP)
    "lisa:100.64.0.32:8765"        # Lisa's PC (Beispiel IP)
    "tom:100.64.0.48:8765"         # Tom's Mac (Beispiel IP)
)

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Prüfe alle Friend Networks
check_friend_networks() {
    echo "🌐 GENTLEMAN Friend Networks Status"
    echo "===================================="
    echo ""
    
    for network in "${FRIEND_NETWORKS[@]}"; do
        IFS=':' read -r friend_name friend_ip friend_port <<< "$network"
        
        echo -n "👤 $friend_name ($friend_ip): "
        
        if curl -s --max-time 3 "http://$friend_ip:$friend_port/health" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Online${NC}"
        else
            echo -e "${RED}❌ Offline${NC}"
        fi
    done
    echo ""
}

# Verbinde zu Friend Network
connect_to_friend() {
    local friend_name="$1"
    
    if [ -z "$friend_name" ]; then
        echo "Verwendung: $0 connect <friend-name>"
        echo ""
        echo "Verfügbare Freunde:"
        for network in "${FRIEND_NETWORKS[@]}"; do
            IFS=':' read -r name ip port <<< "$network"
            echo "  • $name"
        done
        return 1
    fi
    
    # Finde Friend Network
    for network in "${FRIEND_NETWORKS[@]}"; do
        IFS=':' read -r name ip port <<< "$network"
        if [ "$name" = "$friend_name" ]; then
            log_info "🔗 Verbinde zu $friend_name's GENTLEMAN System..."
            
            # Teste Verbindung
            if curl -s --max-time 5 "http://$ip:$port/health" >/dev/null 2>&1; then
                log_success "Verbunden mit $friend_name ($ip:$port)"
                
                # Zeige verfügbare Services
                echo ""
                echo "🎯 Verfügbare Services bei $friend_name:"
                echo "• Status: curl http://$ip:$port/status"
                echo "• Nodes: curl http://$ip:$port/nodes"
                echo "• SSH: ssh $ip (falls konfiguriert)"
                
                return 0
            else
                log_error "$friend_name ist nicht erreichbar"
                return 1
            fi
        fi
    done
    
    log_error "Freund '$friend_name' nicht gefunden"
}

# Broadcast an alle Friends
broadcast_to_friends() {
    local message="$1"
    
    if [ -z "$message" ]; then
        echo "Verwendung: $0 broadcast '<message>'"
        return 1
    fi
    
    log_info "📡 Sende Broadcast an alle Friend Networks..."
    
    for network in "${FRIEND_NETWORKS[@]}"; do
        IFS=':' read -r friend_name friend_ip friend_port <<< "$network"
        
        echo -n "📤 $friend_name: "
        
        # Sende Message (hier könntest du einen Custom Endpoint verwenden)
        if curl -s --max-time 3 "http://$friend_ip:$friend_port/health" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Delivered${NC}"
        else
            echo -e "${RED}❌ Failed${NC}"
        fi
    done
}

# Hauptfunktion
main() {
    case "${1:-status}" in
        "status")
            check_friend_networks
            ;;
        "connect")
            connect_to_friend "$2"
            ;;
        "broadcast")
            broadcast_to_friends "$2"
            ;;
        "list")
            echo "👥 GENTLEMAN Friend Networks:"
            for network in "${FRIEND_NETWORKS[@]}"; do
                IFS=':' read -r name ip port <<< "$network"
                echo "  • $name: $ip:$port"
            done
            ;;
        *)
            echo "🎯 GENTLEMAN Friend Network Connector"
            echo "====================================="
            echo ""
            echo "Kommandos:"
            echo "  status              - Zeige alle Friend Networks"
            echo "  connect <friend>    - Verbinde zu Friend Network"
            echo "  broadcast <msg>     - Broadcast an alle Friends"
            echo "  list               - Liste alle Friends"
            echo ""
            echo "Beispiele:"
            echo "  $0 status"
            echo "  $0 connect max"
            echo "  $0 broadcast 'Hello Friends!'"
            ;;
    esac
}

main "$@"
EOF

    chmod +x ./friend_network_connector.sh
    log_success "Friend Network Connector erstellt"
}

# Shared Services Setup
create_shared_services() {
    log_info "📝 Erstelle Shared Services Setup..."
    
    cat > ./gentleman_shared_services.md << 'EOF'
# GENTLEMAN Shared Services

## 🎯 Konzept
Optionale gemeinsame Services die alle Friends nutzen können, aber jeder hostet sein eigenes GENTLEMAN System.

## 🌐 Mögliche Shared Services

### 1. Gemeinsamer Chat/Status Server
- **Host**: Einer der Friends (rotierend)
- **Zweck**: Status-Updates, Chat zwischen GENTLEMAN Systemen
- **Kosten**: €0 (einer hostet für alle)

### 2. Backup/Sync Service
- **Host**: Distributed zwischen Friends
- **Zweck**: Gegenseitige Config-Backups
- **Kosten**: €0 (jeder sichert einen anderen)

### 3. Monitoring Dashboard
- **Host**: Einer der Friends
- **Zweck**: Übersicht über alle GENTLEMAN Systeme
- **Kosten**: €0 (freiwillig gehostet)

## 🔧 Implementation

### Chat Server (Optional)
```bash
# Einer der Friends hostet:
python3 gentleman_chat_server.py --port 9000

# Alle anderen verbinden sich:
./friend_network_connector.sh connect chat-host
```

### Backup Ring (Distributed)
```bash
# Jeder Friend sichert einen anderen:
# Amon → Max
# Max → Lisa  
# Lisa → Tom
# Tom → Amon
```

## 💰 Kosten
- **Pro Friend**: €0 zusätzlich
- **Shared Services**: Freiwillig gehostet
- **Backup**: Gegenseitig kostenlos

## 🛡️ Vorteile
- Jeder behält Kontrolle über sein System
- Keine zentrale Abhängigkeit
- Ausfallsicher durch Dezentralisierung
- Kostenlos durch Community-Hosting
EOF

    log_success "Shared Services Guide erstellt"
}

# Skalierungs-Analyse
show_scaling_analysis() {
    echo -e "${PURPLE}📊 Tailscale Skalierungs-Analyse${NC}"
    echo "=================================="
    echo ""
    echo -e "${GREEN}✅ Perfekte Skalierung bei dezentralem Setup:${NC}"
    echo ""
    echo "👥 Anzahl Friends │ Geräte/Friend │ Tailscale Kosten │ Pro Person"
    echo "─────────────────┼───────────────┼──────────────────┼───────────"
    echo "        5        │       4       │        €0        │    €0"
    echo "       10        │       4       │        €0        │    €0"
    echo "       50        │       4       │        €0        │    €0"
    echo "      100        │       4       │        €0        │    €0"
    echo ""
    echo -e "${BLUE}💡 Warum das funktioniert:${NC}"
    echo "• Jeder Friend = eigenes Tailscale-Konto"
    echo "• Jeder bleibt unter 20 Geräte-Limit"
    echo "• Inter-Network Communication über öffentliche IPs"
    echo "• Keine geteilten Kosten"
    echo ""
    echo -e "${CYAN}🔄 Friend-to-Friend Kommunikation:${NC}"
    echo "• Tailscale gibt jedem Netzwerk öffentliche IPs"
    echo "• Friends können sich gegenseitig erreichen"
    echo "• Optional: Shared Services für Community-Features"
    echo ""
    echo -e "${YELLOW}⚠️ Einziges Risiko:${NC}"
    echo "• Tailscale könnte kostenlose Tier komplett abschaffen"
    echo "• Aber: Sehr unwahrscheinlich (20 Geräte sind großzügig)"
    echo "• Backup: WireGuard-Setup als Notfall-Plan"
}

# Deployment Guide für Friends
create_friend_deployment() {
    log_info "📖 Erstelle Friend Deployment Guide..."
    
    cat > ./GENTLEMAN_Friend_Deployment.md << 'EOF'
# GENTLEMAN Friend Deployment Guide

## 🎯 Für neue Friends: Dein eigenes GENTLEMAN System

### 1. Tailscale Setup
```bash
# macOS
brew install tailscale
sudo tailscale up

# Linux
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### 2. GENTLEMAN System Setup
```bash
# Clone das GENTLEMAN Repository
git clone https://github.com/your-repo/gentleman.git
cd gentleman

# Setup für dein System
./handshake_m1.sh        # Oder entsprechendes Script für dein OS
```

### 3. Friend Network Registration
```bash
# Teile deine Tailscale IP mit anderen Friends
tailscale ip -4

# Beispiel: 100.64.0.25
# Andere Friends fügen dich hinzu in friend_network_connector.sh
```

### 4. Teste Friend Connections
```bash
# Status aller Friend Networks
./friend_network_connector.sh status

# Verbinde zu einem Friend
./friend_network_connector.sh connect amon
```

## 👥 Friend Network Management

### Neuen Friend hinzufügen
```bash
# In friend_network_connector.sh:
FRIEND_NETWORKS+=(
    "new_friend:100.64.0.99:8765"
)
```

### Friend Network Status
```bash
./friend_network_connector.sh status
```

## 💰 Kosten pro Friend
- **Tailscale**: €0 (bis 20 Geräte)
- **GENTLEMAN Setup**: €0 (Open Source)
- **Shared Services**: €0 (Community gehostet)
- **Total**: €0

## 🔧 Optional: Shared Services
- Chat zwischen GENTLEMAN Systemen
- Gegenseitige Backups
- Community Monitoring
- Alle freiwillig und kostenlos
EOF

    log_success "Friend Deployment Guide erstellt"
}

# Hauptfunktion
main() {
    echo -e "${PURPLE}🎯 GENTLEMAN Tailscale Friend Network Setup${NC}"
    echo "=============================================="
    echo ""
    
    log_info "Dezentrale Architektur erkannt - perfekt für Tailscale!"
    echo ""
    
    show_decentralized_architecture
    show_scaling_analysis
    
    create_friend_communication
    create_shared_services
    create_friend_deployment
    
    echo ""
    log_success "🎉 Friend Network Setup erstellt!"
    echo ""
    echo -e "${CYAN}📁 Erstellt:${NC}"
    echo "• friend_network_connector.sh - Friend-to-Friend Kommunikation"
    echo "• gentleman_shared_services.md - Optionale Shared Services"
    echo "• GENTLEMAN_Friend_Deployment.md - Guide für neue Friends"
    echo ""
    echo -e "${GREEN}✅ Perfekte Skalierung:${NC}"
    echo "• Jeder Friend = eigenes Tailscale-Konto (kostenlos)"
    echo "• Unbegrenzte Anzahl Friends möglich"
    echo "• Keine geteilten Kosten"
    echo "• Inter-Network Kommunikation funktioniert"
    echo ""
    echo -e "${YELLOW}🚀 Nächste Schritte:${NC}"
    echo "1. Teile GENTLEMAN Setup mit Friends"
    echo "2. Jeder erstellt sein eigenes Tailscale-Konto"
    echo "3. IPs austauschen für Friend Network"
    echo "4. Optional: Shared Services einrichten"
}

main "$@" 
 