#!/bin/bash

# 🧪 GENTLEMAN - Hardware Capabilities Test
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
TEST_LOG="$PROJECT_ROOT/logs/hardware_test.log"

# 🏷️ Test Results
declare -A TEST_RESULTS
declare -A PERFORMANCE_METRICS

# 📝 Logging
log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$TEST_LOG"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$TEST_LOG"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $1" >> "$TEST_LOG"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$TEST_LOG"
}

log_step() {
    echo -e "${BLUE}🔧 $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [STEP] $1" >> "$TEST_LOG"
}

# 🎩 Banner
print_banner() {
    echo -e "${PURPLE}"
    echo "🧪 GENTLEMAN - Hardware Capabilities Test"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${WHITE}🎯 Validierung der Hardware-Erkennung und Performance-Tests${NC}"
    echo ""
}

# 📊 Load Hardware Configuration
load_hardware_config() {
    log_step "Lade Hardware-Konfiguration..."
    
    if [[ -f "$HARDWARE_CONFIG_DIR/node_config.env" ]]; then
        source "$HARDWARE_CONFIG_DIR/node_config.env"
        log_success "Hardware-Konfiguration geladen: $GENTLEMAN_NODE_ROLE"
    else
        log_error "Keine Hardware-Konfiguration gefunden!"
        log_info "Führe zuerst 'make detect-hardware' aus."
        exit 1
    fi
}

# 🧠 CPU Performance Test
test_cpu_performance() {
    log_step "Teste CPU-Performance..."
    
    local start_time=$(date +%s.%N)
    
    # CPU Stress Test (Pi Berechnung)
    local pi_digits=$(echo "scale=1000; 4*a(1)" | bc -l 2>/dev/null | wc -c)
    
    local end_time=$(date +%s.%N)
    local cpu_time=$(echo "$end_time - $start_time" | bc)
    
    PERFORMANCE_METRICS[cpu_test_time]=$cpu_time
    
    # CPU Cores Test
    local detected_cores=$(nproc 2>/dev/null || sysctl -n hw.physicalcpu 2>/dev/null || echo "unknown")
    
    if [[ "$detected_cores" == "$CPU_CORES" ]]; then
        TEST_RESULTS[cpu_cores]="PASS"
        log_success "CPU Cores: $CPU_CORES (korrekt erkannt)"
    else
        TEST_RESULTS[cpu_cores]="FAIL"
        log_error "CPU Cores: Erwartet $CPU_CORES, gefunden $detected_cores"
    fi
    
    # Performance Score
    if (( $(echo "$cpu_time < 5.0" | bc -l) )); then
        TEST_RESULTS[cpu_performance]="EXCELLENT"
        log_success "CPU Performance: Excellent (${cpu_time}s)"
    elif (( $(echo "$cpu_time < 10.0" | bc -l) )); then
        TEST_RESULTS[cpu_performance]="GOOD"
        log_success "CPU Performance: Good (${cpu_time}s)"
    else
        TEST_RESULTS[cpu_performance]="SLOW"
        log_warning "CPU Performance: Slow (${cpu_time}s)"
    fi
}

# 🎮 GPU Capability Test
test_gpu_capabilities() {
    log_step "Teste GPU-Fähigkeiten..."
    
    # NVIDIA GPU Test
    if [[ "$NVIDIA_GPUS" -gt 0 ]]; then
        if command -v nvidia-smi &> /dev/null; then
            local gpu_info=$(nvidia-smi --query-gpu=name,memory.total,utilization.gpu --format=csv,noheader,nounits)
            TEST_RESULTS[nvidia_gpu]="PASS"
            log_success "NVIDIA GPU: $gpu_info"
            
            # GPU Memory Test
            local gpu_memory=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
            PERFORMANCE_METRICS[gpu_memory_mb]=$gpu_memory
            
            if [[ $gpu_memory -gt 8000 ]]; then
                TEST_RESULTS[gpu_memory]="EXCELLENT"
            elif [[ $gpu_memory -gt 4000 ]]; then
                TEST_RESULTS[gpu_memory]="GOOD"
            else
                TEST_RESULTS[gpu_memory]="LIMITED"
            fi
        else
            TEST_RESULTS[nvidia_gpu]="FAIL"
            log_error "NVIDIA GPU erkannt, aber nvidia-smi nicht verfügbar"
        fi
    fi
    
    # AMD GPU Test
    if [[ "$AMD_GPUS" -gt 0 ]]; then
        if command -v rocm-smi &> /dev/null; then
            local gpu_info=$(rocm-smi --showid --showproductname 2>/dev/null || echo "ROCm Info nicht verfügbar")
            TEST_RESULTS[amd_gpu]="PASS"
            log_success "AMD GPU: $gpu_info"
            
            # RX 6700 XT spezifischer Test
            if [[ "$RX6700XT_DETECTED" == "true" ]]; then
                TEST_RESULTS[rx6700xt]="PASS"
                log_success "🎮 AMD RX 6700 XT korrekt erkannt"
            fi
        else
            TEST_RESULTS[amd_gpu]="FAIL"
            log_error "AMD GPU erkannt, aber rocm-smi nicht verfügbar"
        fi
    fi
    
    # Apple Silicon GPU Test
    if [[ "$APPLE_SILICON" == "true" ]]; then
        # MPS Availability Test
        if python3 -c "import torch; print(torch.backends.mps.is_available())" 2>/dev/null | grep -q "True"; then
            TEST_RESULTS[apple_mps]="PASS"
            log_success "🍎 Apple Silicon MPS verfügbar"
            
            # MPS Performance Test
            local mps_test_time=$(python3 -c "
import torch
import time
if torch.backends.mps.is_available():
    device = torch.device('mps')
    x = torch.randn(1000, 1000, device=device)
    start = time.time()
    y = torch.mm(x, x)
    end = time.time()
    print(f'{end - start:.3f}')
else:
    print('0')
" 2>/dev/null || echo "0")
            
            PERFORMANCE_METRICS[mps_test_time]=$mps_test_time
            
            if (( $(echo "$mps_test_time > 0 && $mps_test_time < 1.0" | bc -l) )); then
                TEST_RESULTS[mps_performance]="EXCELLENT"
                log_success "MPS Performance: Excellent (${mps_test_time}s)"
            elif (( $(echo "$mps_test_time > 0" | bc -l) )); then
                TEST_RESULTS[mps_performance]="GOOD"
                log_success "MPS Performance: Good (${mps_test_time}s)"
            else
                TEST_RESULTS[mps_performance]="FAIL"
                log_error "MPS Performance Test fehlgeschlagen"
            fi
        else
            TEST_RESULTS[apple_mps]="FAIL"
            log_error "Apple Silicon erkannt, aber MPS nicht verfügbar"
        fi
    fi
}

# 💾 Memory Test
test_memory_capabilities() {
    log_step "Teste Arbeitsspeicher..."
    
    # Memory Size Verification
    local detected_memory_gb
    if [[ "$(uname -s)" == "Linux" ]]; then
        detected_memory_gb=$(free -g | awk 'NR==2{print $2}')
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        detected_memory_gb=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
    fi
    
    if [[ "$detected_memory_gb" -eq "$MEMORY_GB" ]] || [[ $((detected_memory_gb - MEMORY_GB)) -le 1 ]]; then
        TEST_RESULTS[memory_size]="PASS"
        log_success "Memory: ${MEMORY_GB}GB (korrekt erkannt)"
    else
        TEST_RESULTS[memory_size]="FAIL"
        log_error "Memory: Erwartet ${MEMORY_GB}GB, gefunden ${detected_memory_gb}GB"
    fi
    
    # Memory Performance Test
    local start_time=$(date +%s.%N)
    
    # Memory allocation test
    if command -v python3 &> /dev/null; then
        python3 -c "
import time
start = time.time()
data = [0] * (100 * 1024 * 1024)  # 100MB allocation
end = time.time()
print(f'{end - start:.3f}')
" > /tmp/memory_test.txt 2>/dev/null
        
        local memory_test_time=$(cat /tmp/memory_test.txt 2>/dev/null || echo "0")
        rm -f /tmp/memory_test.txt
        
        PERFORMANCE_METRICS[memory_test_time]=$memory_test_time
        
        if (( $(echo "$memory_test_time < 0.1" | bc -l) )); then
            TEST_RESULTS[memory_performance]="EXCELLENT"
            log_success "Memory Performance: Excellent (${memory_test_time}s)"
        elif (( $(echo "$memory_test_time < 0.5" | bc -l) )); then
            TEST_RESULTS[memory_performance]="GOOD"
            log_success "Memory Performance: Good (${memory_test_time}s)"
        else
            TEST_RESULTS[memory_performance]="SLOW"
            log_warning "Memory Performance: Slow (${memory_test_time}s)"
        fi
    fi
}

# 💿 Storage Test
test_storage_capabilities() {
    log_step "Teste Speicher-Performance..."
    
    # Storage Type Verification
    local detected_storage_type
    if [[ "$(uname -s)" == "Linux" ]]; then
        local root_device=$(df / | awk 'NR==2{print $1}' | sed 's/[0-9]*$//')
        if [[ -f "/sys/block/$(basename $root_device)/queue/rotational" ]]; then
            local rotational=$(cat "/sys/block/$(basename $root_device)/queue/rotational")
            if [[ "$rotational" == "0" ]]; then
                detected_storage_type="SSD"
            else
                detected_storage_type="HDD"
            fi
        fi
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        detected_storage_type="SSD"  # Macs haben meist SSDs
    fi
    
    if [[ "$detected_storage_type" == "$STORAGE_TYPE" ]]; then
        TEST_RESULTS[storage_type]="PASS"
        log_success "Storage Type: $STORAGE_TYPE (korrekt erkannt)"
    else
        TEST_RESULTS[storage_type]="FAIL"
        log_error "Storage Type: Erwartet $STORAGE_TYPE, gefunden $detected_storage_type"
    fi
    
    # Storage Performance Test (Write/Read)
    local test_file="/tmp/gentleman_storage_test"
    local start_time=$(date +%s.%N)
    
    # Write test (10MB)
    dd if=/dev/zero of="$test_file" bs=1M count=10 2>/dev/null
    
    local write_end_time=$(date +%s.%N)
    local write_time=$(echo "$write_end_time - $start_time" | bc)
    
    # Read test
    local read_start_time=$(date +%s.%N)
    dd if="$test_file" of=/dev/null bs=1M 2>/dev/null
    local read_end_time=$(date +%s.%N)
    local read_time=$(echo "$read_end_time - $read_start_time" | bc)
    
    rm -f "$test_file"
    
    PERFORMANCE_METRICS[storage_write_time]=$write_time
    PERFORMANCE_METRICS[storage_read_time]=$read_time
    
    # Performance evaluation
    if (( $(echo "$write_time < 0.5 && $read_time < 0.2" | bc -l) )); then
        TEST_RESULTS[storage_performance]="EXCELLENT"
        log_success "Storage Performance: Excellent (W:${write_time}s, R:${read_time}s)"
    elif (( $(echo "$write_time < 2.0 && $read_time < 1.0" | bc -l) )); then
        TEST_RESULTS[storage_performance]="GOOD"
        log_success "Storage Performance: Good (W:${write_time}s, R:${read_time}s)"
    else
        TEST_RESULTS[storage_performance]="SLOW"
        log_warning "Storage Performance: Slow (W:${write_time}s, R:${read_time}s)"
    fi
}

# 🌐 Network Test
test_network_capabilities() {
    log_step "Teste Netzwerk-Konnektivität..."
    
    # Internet connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        TEST_RESULTS[internet_connectivity]="PASS"
        log_success "Internet-Konnektivität: Verfügbar"
    else
        TEST_RESULTS[internet_connectivity]="FAIL"
        log_error "Internet-Konnektivität: Nicht verfügbar"
    fi
    
    # Local network speed test
    local start_time=$(date +%s.%N)
    curl -s http://speedtest.wdc01.softlayer.com/downloads/test10.zip > /dev/null 2>&1 || true
    local end_time=$(date +%s.%N)
    local network_time=$(echo "$end_time - $start_time" | bc)
    
    PERFORMANCE_METRICS[network_test_time]=$network_time
    
    if (( $(echo "$network_time < 5.0" | bc -l) )); then
        TEST_RESULTS[network_speed]="EXCELLENT"
        log_success "Network Speed: Excellent (${network_time}s)"
    elif (( $(echo "$network_time < 15.0" | bc -l) )); then
        TEST_RESULTS[network_speed]="GOOD"
        log_success "Network Speed: Good (${network_time}s)"
    else
        TEST_RESULTS[network_speed]="SLOW"
        log_warning "Network Speed: Slow (${network_time}s)"
    fi
}

# 🎯 Node Role Validation
validate_node_role() {
    log_step "Validiere Node-Rolle..."
    
    case "$GENTLEMAN_NODE_ROLE" in
        "llm-server")
            if [[ "$GENTLEMAN_GPU_ENABLED" == "true" ]] && ([[ "$NVIDIA_GPUS" -gt 0 ]] || [[ "$AMD_GPUS" -gt 0 ]]); then
                TEST_RESULTS[node_role]="OPTIMAL"
                log_success "Node Role: LLM Server - Optimal (GPU verfügbar)"
            else
                TEST_RESULTS[node_role]="SUBOPTIMAL"
                log_warning "Node Role: LLM Server - Suboptimal (keine GPU)"
            fi
            ;;
        "audio-server")
            if [[ "$APPLE_SILICON" == "true" ]] && [[ "$MPS_AVAILABLE" == "true" ]]; then
                TEST_RESULTS[node_role]="OPTIMAL"
                log_success "Node Role: Audio Server - Optimal (Apple Silicon MPS)"
            else
                TEST_RESULTS[node_role]="SUBOPTIMAL"
                log_warning "Node Role: Audio Server - Suboptimal (kein Apple Silicon)"
            fi
            ;;
        "git-server")
            if [[ "$STORAGE_TYPE" == "SSD" ]] && [[ "$MEMORY_GB" -ge 8 ]]; then
                TEST_RESULTS[node_role]="OPTIMAL"
                log_success "Node Role: Git Server - Optimal (SSD + ausreichend RAM)"
            else
                TEST_RESULTS[node_role]="SUBOPTIMAL"
                log_warning "Node Role: Git Server - Suboptimal (langsamer Storage oder wenig RAM)"
            fi
            ;;
        "client")
            TEST_RESULTS[node_role]="OPTIMAL"
            log_success "Node Role: Client - Optimal (keine speziellen Anforderungen)"
            ;;
        *)
            TEST_RESULTS[node_role]="UNKNOWN"
            log_error "Node Role: Unbekannt ($GENTLEMAN_NODE_ROLE)"
            ;;
    esac
}

# 📊 Generate Test Report
generate_test_report() {
    log_step "Generiere Test-Report..."
    
    local report_file="$HARDWARE_CONFIG_DIR/hardware_test_report_$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$report_file" << EOF
{
  "test_timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "node_role": "$GENTLEMAN_NODE_ROLE",
  "test_results": {
    "cpu_cores": "${TEST_RESULTS[cpu_cores]:-UNKNOWN}",
    "cpu_performance": "${TEST_RESULTS[cpu_performance]:-UNKNOWN}",
    "nvidia_gpu": "${TEST_RESULTS[nvidia_gpu]:-N/A}",
    "amd_gpu": "${TEST_RESULTS[amd_gpu]:-N/A}",
    "rx6700xt": "${TEST_RESULTS[rx6700xt]:-N/A}",
    "apple_mps": "${TEST_RESULTS[apple_mps]:-N/A}",
    "mps_performance": "${TEST_RESULTS[mps_performance]:-N/A}",
    "memory_size": "${TEST_RESULTS[memory_size]:-UNKNOWN}",
    "memory_performance": "${TEST_RESULTS[memory_performance]:-UNKNOWN}",
    "storage_type": "${TEST_RESULTS[storage_type]:-UNKNOWN}",
    "storage_performance": "${TEST_RESULTS[storage_performance]:-UNKNOWN}",
    "internet_connectivity": "${TEST_RESULTS[internet_connectivity]:-UNKNOWN}",
    "network_speed": "${TEST_RESULTS[network_speed]:-UNKNOWN}",
    "node_role": "${TEST_RESULTS[node_role]:-UNKNOWN}"
  },
  "performance_metrics": {
    "cpu_test_time": "${PERFORMANCE_METRICS[cpu_test_time]:-0}",
    "gpu_memory_mb": "${PERFORMANCE_METRICS[gpu_memory_mb]:-0}",
    "mps_test_time": "${PERFORMANCE_METRICS[mps_test_time]:-0}",
    "memory_test_time": "${PERFORMANCE_METRICS[memory_test_time]:-0}",
    "storage_write_time": "${PERFORMANCE_METRICS[storage_write_time]:-0}",
    "storage_read_time": "${PERFORMANCE_METRICS[storage_read_time]:-0}",
    "network_test_time": "${PERFORMANCE_METRICS[network_test_time]:-0}"
  }
}
EOF
    
    log_success "Test-Report erstellt: $report_file"
    
    # Symlink für aktuellen Report
    ln -sf "$report_file" "$HARDWARE_CONFIG_DIR/current_test_report.json"
}

# 📋 Display Test Summary
display_test_summary() {
    echo ""
    echo -e "${GREEN}🧪 Hardware Capabilities Test Abgeschlossen!${NC}"
    echo ""
    echo -e "${WHITE}📊 Test-Zusammenfassung:${NC}"
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local optimal_tests=0
    
    for result in "${TEST_RESULTS[@]}"; do
        total_tests=$((total_tests + 1))
        case "$result" in
            "PASS"|"OPTIMAL"|"EXCELLENT"|"GOOD")
                passed_tests=$((passed_tests + 1))
                ;;
            "FAIL"|"UNKNOWN")
                failed_tests=$((failed_tests + 1))
                ;;
        esac
        
        if [[ "$result" == "OPTIMAL" || "$result" == "EXCELLENT" ]]; then
            optimal_tests=$((optimal_tests + 1))
        fi
    done
    
    echo -e "${CYAN}  Gesamt Tests:${NC} $total_tests"
    echo -e "${GREEN}  Erfolgreich:${NC} $passed_tests"
    echo -e "${RED}  Fehlgeschlagen:${NC} $failed_tests"
    echo -e "${YELLOW}  Optimal:${NC} $optimal_tests"
    echo ""
    
    # Performance Summary
    echo -e "${WHITE}⚡ Performance-Metriken:${NC}"
    if [[ -n "${PERFORMANCE_METRICS[cpu_test_time]}" ]]; then
        echo -e "${CYAN}  CPU Test:${NC} ${PERFORMANCE_METRICS[cpu_test_time]}s"
    fi
    if [[ -n "${PERFORMANCE_METRICS[mps_test_time]}" ]]; then
        echo -e "${CYAN}  MPS Test:${NC} ${PERFORMANCE_METRICS[mps_test_time]}s"
    fi
    if [[ -n "${PERFORMANCE_METRICS[storage_write_time]}" ]]; then
        echo -e "${CYAN}  Storage Write:${NC} ${PERFORMANCE_METRICS[storage_write_time]}s"
    fi
    echo ""
    
    # Recommendations
    echo -e "${WHITE}💡 Empfehlungen:${NC}"
    
    if [[ "${TEST_RESULTS[node_role]}" == "SUBOPTIMAL" ]]; then
        echo -e "${YELLOW}  ⚠️  Node-Rolle ist suboptimal für diese Hardware${NC}"
        echo -e "${CYAN}     Führe 'make detect-hardware' erneut aus${NC}"
    fi
    
    if [[ "${TEST_RESULTS[gpu_memory]}" == "LIMITED" ]]; then
        echo -e "${YELLOW}  ⚠️  GPU-Speicher ist begrenzt - reduziere Batch-Größen${NC}"
    fi
    
    if [[ "${TEST_RESULTS[storage_performance]}" == "SLOW" ]]; then
        echo -e "${YELLOW}  ⚠️  Storage-Performance ist langsam - erwäge SSD-Upgrade${NC}"
    fi
    
    echo ""
    echo -e "${WHITE}📋 Nächste Schritte:${NC}"
    echo -e "${CYAN}  1.${NC} make gentleman-up-auto   # Services basierend auf Hardware starten"
    echo -e "${CYAN}  2.${NC} make test-ai-pipeline    # AI-Pipeline testen"
    echo -e "${CYAN}  3.${NC} make hardware-report     # Detaillierten Report anzeigen"
    echo ""
}

# 🚀 Main Function
main() {
    print_banner
    
    # Create directories
    mkdir -p "$HARDWARE_CONFIG_DIR"
    mkdir -p "$(dirname "$TEST_LOG")"
    
    # Load configuration
    load_hardware_config
    
    # Run tests
    test_cpu_performance
    test_gpu_capabilities
    test_memory_capabilities
    test_storage_capabilities
    test_network_capabilities
    validate_node_role
    
    # Generate report
    generate_test_report
    
    # Display summary
    display_test_summary
    
    log_success "Hardware Capabilities Test abgeschlossen!"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 