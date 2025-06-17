#!/bin/bash

# 🔍 GENTLEMAN - Hardware Detection & Auto-Configuration
# ═══════════════════════════════════════════════════════════════

set -e

# 🎨 Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 📁 Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HARDWARE_CONFIG_DIR="$PROJECT_ROOT/config/hardware"
DETECTION_LOG="$PROJECT_ROOT/logs/hardware_detection.log"

# 🏷️ Hardware Detection Results
declare -A HARDWARE_INFO
declare -A NODE_CAPABILITIES
declare -A PERFORMANCE_SCORES

# 📝 Logging
log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$DETECTION_LOG"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$DETECTION_LOG"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $1" >> "$DETECTION_LOG"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$DETECTION_LOG"
}

log_step() {
    echo -e "${BLUE}🔧 $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [STEP] $1" >> "$DETECTION_LOG"
}

# 🎩 Banner
print_banner() {
    echo -e "${PURPLE}"
    echo "🔍 GENTLEMAN - Hardware Detection"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${WHITE}🎯 Automatische Hardware-Erkennung und Node-Optimierung${NC}"
    echo ""
}

# 🖥️ System Detection
detect_system_info() {
    log_step "Erkenne System-Informationen..."
    
    HARDWARE_INFO[os]=$(uname -s)
    HARDWARE_INFO[kernel]=$(uname -r)
    HARDWARE_INFO[arch]=$(uname -m)
    HARDWARE_INFO[hostname]=$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "unknown")
    
    # Betriebssystem Details
    if [[ "${HARDWARE_INFO[os]}" == "Linux" ]]; then
        if command -v lsb_release &> /dev/null; then
            HARDWARE_INFO[distro]=$(lsb_release -si)
            HARDWARE_INFO[distro_version]=$(lsb_release -sr)
        elif [[ -f /etc/os-release ]]; then
            HARDWARE_INFO[distro]=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
            HARDWARE_INFO[distro_version]=$(grep ^VERSION_ID= /etc/os-release | cut -d= -f2 | tr -d '"')
        fi
    elif [[ "${HARDWARE_INFO[os]}" == "Darwin" ]]; then
        HARDWARE_INFO[distro]="macOS"
        HARDWARE_INFO[distro_version]=$(sw_vers -productVersion)
    fi
    
    log_success "System: ${HARDWARE_INFO[os]} ${HARDWARE_INFO[distro]} ${HARDWARE_INFO[distro_version]} (${HARDWARE_INFO[arch]})"
}

# 🧠 CPU Detection
detect_cpu() {
    log_step "Erkenne CPU-Hardware..."
    
    if [[ "${HARDWARE_INFO[os]}" == "Linux" ]]; then
        HARDWARE_INFO[cpu_model]=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        HARDWARE_INFO[cpu_cores]=$(nproc)
        HARDWARE_INFO[cpu_threads]=$(grep -c ^processor /proc/cpuinfo)
        
        # CPU Flags für Optimierungen
        HARDWARE_INFO[cpu_flags]=$(grep flags /proc/cpuinfo | head -1 | cut -d: -f2)
        
        # CPU Frequenz
        if [[ -f /proc/cpuinfo ]]; then
            HARDWARE_INFO[cpu_freq]=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        fi
        
    elif [[ "${HARDWARE_INFO[os]}" == "Darwin" ]]; then
        HARDWARE_INFO[cpu_model]=$(sysctl -n machdep.cpu.brand_string)
        HARDWARE_INFO[cpu_cores]=$(sysctl -n hw.physicalcpu)
        HARDWARE_INFO[cpu_threads]=$(sysctl -n hw.logicalcpu)
        
        # Apple Silicon Detection
        if [[ "${HARDWARE_INFO[arch]}" == "arm64" ]]; then
            HARDWARE_INFO[apple_silicon]=true
            HARDWARE_INFO[cpu_type]="Apple Silicon"
        else
            HARDWARE_INFO[apple_silicon]=false
            HARDWARE_INFO[cpu_type]="Intel"
        fi
    fi
    
    # Performance Score berechnen
    local cpu_score=0
    if [[ ${HARDWARE_INFO[cpu_cores]} -ge 8 ]]; then
        cpu_score=$((cpu_score + 30))
    elif [[ ${HARDWARE_INFO[cpu_cores]} -ge 4 ]]; then
        cpu_score=$((cpu_score + 20))
    else
        cpu_score=$((cpu_score + 10))
    fi
    
    # Apple Silicon Bonus
    if [[ "${HARDWARE_INFO[apple_silicon]}" == "true" ]]; then
        cpu_score=$((cpu_score + 20))
    fi
    
    PERFORMANCE_SCORES[cpu]=$cpu_score
    
    log_success "CPU: ${HARDWARE_INFO[cpu_model]} (${HARDWARE_INFO[cpu_cores]}C/${HARDWARE_INFO[cpu_threads]}T)"
}

# 🎮 GPU Detection
detect_gpu() {
    log_step "Erkenne GPU-Hardware..."
    
    HARDWARE_INFO[gpu_count]=0
    HARDWARE_INFO[gpu_vendors]=""
    HARDWARE_INFO[gpu_models]=""
    
    if [[ "${HARDWARE_INFO[os]}" == "Linux" ]]; then
        # NVIDIA GPUs
        if command -v nvidia-smi &> /dev/null; then
            local nvidia_gpus=$(nvidia-smi --list-gpus 2>/dev/null | wc -l)
            if [[ $nvidia_gpus -gt 0 ]]; then
                HARDWARE_INFO[gpu_count]=$((${HARDWARE_INFO[gpu_count]} + nvidia_gpus))
                HARDWARE_INFO[gpu_vendors]+="NVIDIA "
                HARDWARE_INFO[nvidia_gpus]=$nvidia_gpus
                HARDWARE_INFO[nvidia_driver]=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1)
                
                # GPU Models
                local nvidia_models=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | tr '\n' ', ')
                HARDWARE_INFO[gpu_models]+="$nvidia_models"
                
                PERFORMANCE_SCORES[gpu_nvidia]=50
            fi
        fi
        
        # AMD GPUs
        if command -v rocm-smi &> /dev/null; then
            local amd_gpus=$(rocm-smi --showid 2>/dev/null | grep -c "GPU\[" || echo 0)
            if [[ $amd_gpus -gt 0 ]]; then
                HARDWARE_INFO[gpu_count]=$((${HARDWARE_INFO[gpu_count]} + amd_gpus))
                HARDWARE_INFO[gpu_vendors]+="AMD "
                HARDWARE_INFO[amd_gpus]=$amd_gpus
                
                # ROCm Version
                if command -v rocminfo &> /dev/null; then
                    HARDWARE_INFO[rocm_version]=$(rocminfo | grep "HSA Runtime Version" | cut -d: -f2 | xargs)
                fi
                
                # Spezielle RX 6700 XT Erkennung
                local gpu_info=$(lspci | grep -i "VGA\|3D\|Display" | grep -i "AMD\|ATI")
                if echo "$gpu_info" | grep -qi "6700"; then
                    HARDWARE_INFO[rx6700xt]=true
                    PERFORMANCE_SCORES[gpu_amd]=45
                    log_success "🎮 AMD RX 6700 XT erkannt - Optimale LLM-Performance!"
                else
                    PERFORMANCE_SCORES[gpu_amd]=35
                fi
            fi
        fi
        
        # Intel GPUs
        if command -v intel_gpu_top &> /dev/null; then
            HARDWARE_INFO[gpu_vendors]+="Intel "
            PERFORMANCE_SCORES[gpu_intel]=20
        fi
        
    elif [[ "${HARDWARE_INFO[os]}" == "Darwin" ]]; then
        # Apple Silicon GPU (MPS)
        if [[ "${HARDWARE_INFO[apple_silicon]}" == "true" ]]; then
            HARDWARE_INFO[gpu_count]=1
            HARDWARE_INFO[gpu_vendors]="Apple "
            HARDWARE_INFO[gpu_models]="Apple Silicon GPU"
            HARDWARE_INFO[mps_available]=true
            PERFORMANCE_SCORES[gpu_apple]=40
            log_success "🍎 Apple Silicon GPU (MPS) erkannt - Optimale Audio-Performance!"
        else
            # Intel Mac GPU
            local gpu_info=$(system_profiler SPDisplaysDataType | grep "Chipset Model" | cut -d: -f2 | xargs)
            if [[ -n "$gpu_info" ]]; then
                HARDWARE_INFO[gpu_models]="$gpu_info"
                HARDWARE_INFO[gpu_count]=1
                PERFORMANCE_SCORES[gpu_intel]=25
            fi
        fi
    fi
    
    log_success "GPU: ${HARDWARE_INFO[gpu_count]} GPU(s) - ${HARDWARE_INFO[gpu_vendors]}"
}

# 💾 Memory Detection
detect_memory() {
    log_step "Erkenne Arbeitsspeicher..."
    
    if [[ "${HARDWARE_INFO[os]}" == "Linux" ]]; then
        HARDWARE_INFO[memory_total]=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        HARDWARE_INFO[memory_available]=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        HARDWARE_INFO[memory_gb]=$((${HARDWARE_INFO[memory_total]} / 1024 / 1024))
        
    elif [[ "${HARDWARE_INFO[os]}" == "Darwin" ]]; then
        HARDWARE_INFO[memory_total]=$(sysctl -n hw.memsize)
        HARDWARE_INFO[memory_gb]=$((${HARDWARE_INFO[memory_total]} / 1024 / 1024 / 1024))
    fi
    
    # Memory Performance Score
    local memory_score=0
    if [[ ${HARDWARE_INFO[memory_gb]} -ge 32 ]]; then
        memory_score=30
    elif [[ ${HARDWARE_INFO[memory_gb]} -ge 16 ]]; then
        memory_score=25
    elif [[ ${HARDWARE_INFO[memory_gb]} -ge 8 ]]; then
        memory_score=20
    else
        memory_score=10
    fi
    
    PERFORMANCE_SCORES[memory]=$memory_score
    
    log_success "RAM: ${HARDWARE_INFO[memory_gb]}GB"
}

# 💿 Storage Detection
detect_storage() {
    log_step "Erkenne Speicher-Hardware..."
    
    if [[ "${HARDWARE_INFO[os]}" == "Linux" ]]; then
        # Disk Space
        HARDWARE_INFO[disk_total]=$(df -h / | awk 'NR==2{print $2}')
        HARDWARE_INFO[disk_available]=$(df -h / | awk 'NR==2{print $4}')
        
        # SSD Detection
        local root_device=$(df / | awk 'NR==2{print $1}' | sed 's/[0-9]*$//')
        if [[ -f "/sys/block/$(basename $root_device)/queue/rotational" ]]; then
            local rotational=$(cat "/sys/block/$(basename $root_device)/queue/rotational")
            if [[ "$rotational" == "0" ]]; then
                HARDWARE_INFO[storage_type]="SSD"
                PERFORMANCE_SCORES[storage]=20
            else
                HARDWARE_INFO[storage_type]="HDD"
                PERFORMANCE_SCORES[storage]=10
            fi
        fi
        
    elif [[ "${HARDWARE_INFO[os]}" == "Darwin" ]]; then
        HARDWARE_INFO[disk_total]=$(df -h / | awk 'NR==2{print $2}')
        HARDWARE_INFO[disk_available]=$(df -h / | awk 'NR==2{print $4}')
        HARDWARE_INFO[storage_type]="SSD"  # Macs haben meist SSDs
        PERFORMANCE_SCORES[storage]=25
    fi
    
    log_success "Storage: ${HARDWARE_INFO[disk_total]} (${HARDWARE_INFO[storage_type]})"
}

# 🌐 Network Detection
detect_network() {
    log_step "Erkenne Netzwerk-Hardware..."
    
    # IP Addresses
    if command -v ip &> /dev/null; then
        HARDWARE_INFO[ip_addresses]=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+' 2>/dev/null || echo "unknown")
    elif command -v ifconfig &> /dev/null; then
        HARDWARE_INFO[ip_addresses]=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
    fi
    
    # Network Interfaces
    if [[ "${HARDWARE_INFO[os]}" == "Linux" ]]; then
        HARDWARE_INFO[network_interfaces]=$(ls /sys/class/net/ | grep -v lo | tr '\n' ' ')
    elif [[ "${HARDWARE_INFO[os]}" == "Darwin" ]]; then
        HARDWARE_INFO[network_interfaces]=$(networksetup -listallhardwareports | grep "Device:" | cut -d: -f2 | xargs | tr '\n' ' ')
    fi
    
    log_success "Network: ${HARDWARE_INFO[ip_addresses]} (${HARDWARE_INFO[network_interfaces]})"
}

# 🎯 Node Role Determination
determine_node_role() {
    log_step "Bestimme optimale Node-Rolle..."
    
    local total_score=0
    local best_role="client"
    
    # Berechne Gesamt-Performance-Score
    for score in "${PERFORMANCE_SCORES[@]}"; do
        total_score=$((total_score + score))
    done
    
    # LLM Server Score (GPU-fokussiert)
    local llm_score=0
    if [[ "${HARDWARE_INFO[nvidia_gpus]}" -gt 0 ]]; then
        llm_score=$((llm_score + 50))
    fi
    if [[ "${HARDWARE_INFO[rx6700xt]}" == "true" ]]; then
        llm_score=$((llm_score + 45))
    fi
    llm_score=$((llm_score + ${PERFORMANCE_SCORES[cpu]} + ${PERFORMANCE_SCORES[memory]}))
    
    # Audio Server Score (Apple Silicon fokussiert)
    local audio_score=0
    if [[ "${HARDWARE_INFO[apple_silicon]}" == "true" ]]; then
        audio_score=$((audio_score + 60))
    fi
    audio_score=$((audio_score + ${PERFORMANCE_SCORES[cpu]} + ${PERFORMANCE_SCORES[memory]}))
    
    # Git Server Score (Storage + CPU fokussiert)
    local git_score=0
    git_score=$((git_score + ${PERFORMANCE_SCORES[storage]} + ${PERFORMANCE_SCORES[cpu]} + ${PERFORMANCE_SCORES[memory]}))
    if [[ "${HARDWARE_INFO[apple_silicon]}" == "true" ]]; then
        git_score=$((git_score + 30))  # M1 Mac als Development Hub
    fi
    
    # Client Score (Basis für alle)
    local client_score=$((${PERFORMANCE_SCORES[cpu]} + ${PERFORMANCE_SCORES[memory]}))
    
    # Beste Rolle bestimmen
    if [[ $llm_score -gt $audio_score && $llm_score -gt $git_score && $llm_score -gt $client_score ]]; then
        best_role="llm-server"
        NODE_CAPABILITIES[primary_role]="llm-server"
        NODE_CAPABILITIES[gpu_acceleration]=true
        NODE_CAPABILITIES[services]="llm-server,monitoring,matrix-updates"
    elif [[ $audio_score -gt $git_score && $audio_score -gt $client_score ]]; then
        best_role="audio-server"
        NODE_CAPABILITIES[primary_role]="audio-server"
        NODE_CAPABILITIES[audio_processing]=true
        NODE_CAPABILITIES[services]="stt-service,tts-service,git-server"
    elif [[ $git_score -gt $client_score ]]; then
        best_role="git-server"
        NODE_CAPABILITIES[primary_role]="git-server"
        NODE_CAPABILITIES[development_hub]=true
        NODE_CAPABILITIES[services]="git-server,web-interface"
    else
        best_role="client"
        NODE_CAPABILITIES[primary_role]="client"
        NODE_CAPABILITIES[services]="web-interface,monitoring"
    fi
    
    # Node ID generieren
    local hostname_short=$(hostname -s 2>/dev/null || cat /etc/hostname 2>/dev/null | cut -d. -f1 || echo "node")
    local node_id="${best_role}-${hostname_short}"
    NODE_CAPABILITIES[node_id]="$node_id"
    NODE_CAPABILITIES[total_score]=$total_score
    
    log_success "Optimale Rolle: $best_role (Score: $total_score)"
    log_info "Node ID: $node_id"
    log_info "Services: ${NODE_CAPABILITIES[services]}"
}

# 📊 Hardware Report
generate_hardware_report() {
    log_step "Generiere Hardware-Report..."
    
    mkdir -p "$HARDWARE_CONFIG_DIR"
    local report_file="$HARDWARE_CONFIG_DIR/hardware_report_$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$report_file" << EOF
{
  "detection_timestamp": "$(date -Iseconds)",
  "hostname": "${HARDWARE_INFO[hostname]}",
  "system": {
    "os": "${HARDWARE_INFO[os]}",
    "distro": "${HARDWARE_INFO[distro]}",
    "distro_version": "${HARDWARE_INFO[distro_version]}",
    "kernel": "${HARDWARE_INFO[kernel]}",
    "architecture": "${HARDWARE_INFO[arch]}"
  },
  "cpu": {
    "model": "${HARDWARE_INFO[cpu_model]}",
    "cores": ${HARDWARE_INFO[cpu_cores]},
    "threads": ${HARDWARE_INFO[cpu_threads]},
    "apple_silicon": ${HARDWARE_INFO[apple_silicon]:-false},
    "performance_score": ${PERFORMANCE_SCORES[cpu]}
  },
  "gpu": {
    "count": ${HARDWARE_INFO[gpu_count]},
    "vendors": "${HARDWARE_INFO[gpu_vendors]}",
    "models": "${HARDWARE_INFO[gpu_models]}",
    "nvidia_gpus": ${HARDWARE_INFO[nvidia_gpus]:-0},
    "amd_gpus": ${HARDWARE_INFO[amd_gpus]:-0},
    "rx6700xt": ${HARDWARE_INFO[rx6700xt]:-false},
    "mps_available": ${HARDWARE_INFO[mps_available]:-false},
    "nvidia_driver": "${HARDWARE_INFO[nvidia_driver]:-}",
    "rocm_version": "${HARDWARE_INFO[rocm_version]:-}"
  },
  "memory": {
    "total_gb": ${HARDWARE_INFO[memory_gb]},
    "performance_score": ${PERFORMANCE_SCORES[memory]}
  },
  "storage": {
    "total": "${HARDWARE_INFO[disk_total]}",
    "available": "${HARDWARE_INFO[disk_available]}",
    "type": "${HARDWARE_INFO[storage_type]}",
    "performance_score": ${PERFORMANCE_SCORES[storage]}
  },
  "network": {
    "ip_addresses": "${HARDWARE_INFO[ip_addresses]}",
    "interfaces": "${HARDWARE_INFO[network_interfaces]}"
  },
  "node_capabilities": {
    "node_id": "${NODE_CAPABILITIES[node_id]}",
    "primary_role": "${NODE_CAPABILITIES[primary_role]}",
    "services": "${NODE_CAPABILITIES[services]}",
    "total_score": ${NODE_CAPABILITIES[total_score]},
    "gpu_acceleration": ${NODE_CAPABILITIES[gpu_acceleration]:-false},
    "audio_processing": ${NODE_CAPABILITIES[audio_processing]:-false},
    "development_hub": ${NODE_CAPABILITIES[development_hub]:-false}
  }
}
EOF
    
    log_success "Hardware-Report erstellt: $report_file"
    
    # Symlink für aktuellen Report
    ln -sf "$report_file" "$HARDWARE_CONFIG_DIR/current_hardware.json"
}

# ⚙️ Generate Node Configuration
generate_node_config() {
    log_step "Generiere Node-Konfiguration..."
    
    local config_file="$HARDWARE_CONFIG_DIR/node_config.env"
    
    cat > "$config_file" << EOF
# 🎩 GENTLEMAN - Auto-Generated Node Configuration
# ═══════════════════════════════════════════════════════════════
# Generated: $(date -Iseconds)
# Hardware Detection: Automatic
# Node ID: ${NODE_CAPABILITIES[node_id]}

# 🏷️ NODE IDENTITY
GENTLEMAN_NODE_ID=${NODE_CAPABILITIES[node_id]}
GENTLEMAN_NODE_ROLE=${NODE_CAPABILITIES[primary_role]}
GENTLEMAN_HOSTNAME=${HARDWARE_INFO[hostname]}

# 🖥️ SYSTEM CONFIGURATION
GENTLEMAN_OS=${HARDWARE_INFO[os]}
GENTLEMAN_ARCH=${HARDWARE_INFO[arch]}
GENTLEMAN_DISTRO=${HARDWARE_INFO[distro]}

# 🧠 CPU CONFIGURATION
CPU_CORES=${HARDWARE_INFO[cpu_cores]}
CPU_THREADS=${HARDWARE_INFO[cpu_threads]}
OMP_NUM_THREADS=${HARDWARE_INFO[cpu_cores]}
MKL_NUM_THREADS=${HARDWARE_INFO[cpu_cores]}

# 🎮 GPU CONFIGURATION
GENTLEMAN_GPU_ENABLED=${NODE_CAPABILITIES[gpu_acceleration]:-false}
NVIDIA_GPUS=${HARDWARE_INFO[nvidia_gpus]:-0}
AMD_GPUS=${HARDWARE_INFO[amd_gpus]:-0}
APPLE_SILICON=${HARDWARE_INFO[apple_silicon]:-false}
MPS_AVAILABLE=${HARDWARE_INFO[mps_available]:-false}
RX6700XT_DETECTED=${HARDWARE_INFO[rx6700xt]:-false}

# 🎤 AUDIO CONFIGURATION
AUDIO_PROCESSING_ENABLED=${NODE_CAPABILITIES[audio_processing]:-false}
STT_DEVICE=$([ "${HARDWARE_INFO[apple_silicon]}" == "true" ] && echo "mps" || echo "cpu")
TTS_DEVICE=$([ "${HARDWARE_INFO[apple_silicon]}" == "true" ] && echo "mps" || echo "cpu")

# 💾 MEMORY CONFIGURATION
MEMORY_GB=${HARDWARE_INFO[memory_gb]}
DOCKER_MEMORY_LIMIT=$((${HARDWARE_INFO[memory_gb]} / 2))GB

# 🌐 NETWORK CONFIGURATION
NODE_IP=${HARDWARE_INFO[ip_addresses]}
NEBULA_NODE_TYPE=${NODE_CAPABILITIES[node_id]}
NEBULA_NODE_IP=192.168.100.10
NEBULA_LIGHTHOUSE=192.168.100.1

# 🚀 SERVICES CONFIGURATION
GENTLEMAN_SERVICES=${NODE_CAPABILITIES[services]}
DEVELOPMENT_HUB=${NODE_CAPABILITIES[development_hub]:-false}

# 📊 PERFORMANCE TUNING
PERFORMANCE_SCORE=${NODE_CAPABILITIES[total_score]}
STORAGE_TYPE=${HARDWARE_INFO[storage_type]}
EOF

    log_success "Node-Konfiguration erstellt: $config_file"
}

# 📋 Display Hardware Summary
display_summary() {
    echo ""
    echo -e "${GREEN}🎩 Hardware Detection Abgeschlossen!${NC}"
    echo ""
    echo -e "${WHITE}📊 Hardware-Zusammenfassung:${NC}"
    echo -e "${CYAN}  System:${NC} ${HARDWARE_INFO[os]} ${HARDWARE_INFO[distro]} (${HARDWARE_INFO[arch]})"
    echo -e "${CYAN}  CPU:${NC} ${HARDWARE_INFO[cpu_model]} (${HARDWARE_INFO[cpu_cores]}C/${HARDWARE_INFO[cpu_threads]}T)"
    echo -e "${CYAN}  GPU:${NC} ${HARDWARE_INFO[gpu_count]} GPU(s) - ${HARDWARE_INFO[gpu_vendors]}"
    echo -e "${CYAN}  RAM:${NC} ${HARDWARE_INFO[memory_gb]}GB"
    echo -e "${CYAN}  Storage:${NC} ${HARDWARE_INFO[disk_total]} (${HARDWARE_INFO[storage_type]})"
    echo ""
    echo -e "${WHITE}🎯 Optimale Node-Konfiguration:${NC}"
    echo -e "${GREEN}  Node ID:${NC} ${NODE_CAPABILITIES[node_id]}"
    echo -e "${GREEN}  Rolle:${NC} ${NODE_CAPABILITIES[primary_role]}"
    echo -e "${GREEN}  Services:${NC} ${NODE_CAPABILITIES[services]}"
    echo -e "${GREEN}  Performance Score:${NC} ${NODE_CAPABILITIES[total_score]}/150"
    echo ""
    
    # Spezielle Empfehlungen
    if [[ "${HARDWARE_INFO[rx6700xt]}" == "true" ]]; then
        echo -e "${YELLOW}🎮 AMD RX 6700 XT erkannt - Perfekt für LLM Server!${NC}"
    fi
    
    if [[ "${HARDWARE_INFO[apple_silicon]}" == "true" ]]; then
        echo -e "${YELLOW}🍎 Apple Silicon erkannt - Optimal für Audio Services!${NC}"
    fi
    
    echo ""
    echo -e "${WHITE}📋 Nächste Schritte:${NC}"
    echo -e "${CYAN}  1.${NC} make setup-auto          # Automatisches Setup basierend auf Hardware"
    echo -e "${CYAN}  2.${NC} make gentleman-up-auto   # Services starten"
    echo -e "${CYAN}  3.${NC} make test-services-health # Hardware-Tests durchführen"
    echo ""
}

# 🚀 Main Function
main() {
    print_banner
    
    # Create directories
    mkdir -p "$HARDWARE_CONFIG_DIR"
    mkdir -p "$(dirname "$DETECTION_LOG")"
    
    # Hardware Detection
    detect_system_info
    detect_cpu
    detect_gpu
    detect_memory
    detect_storage
    detect_network
    
    # Node Configuration
    determine_node_role
    generate_hardware_report
    generate_node_config
    
    # Summary
    display_summary
    
    log_success "Hardware Detection abgeschlossen!"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 