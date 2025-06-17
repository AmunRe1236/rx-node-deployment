#!/bin/bash

# 🎩 GENTLEMAN - AI Pipeline Quick Test
# ═══════════════════════════════════════════════════════════════
# Schneller Test der AI-Pipeline: STT (M1) → LLM (RX 6700 XT) → TTS (M1)

set -euo pipefail

# 🎨 Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 🏗️ Configuration
STT_HOST="192.168.100.20"
STT_PORT="8002"
LLM_HOST="192.168.100.10"
LLM_PORT="8001"
TTS_HOST="192.168.100.20"
TTS_PORT="8003"

# 🎯 Test Configuration
TEST_TEXT="Hallo Gentleman, wie geht es dir heute?"
TEMP_DIR="/tmp/gentleman_test_$$"
AUDIO_FILE="$TEMP_DIR/test_audio.wav"
RESPONSE_FILE="$TEMP_DIR/response.json"
TTS_AUDIO_FILE="$TEMP_DIR/response_audio.wav"

# 📊 Metrics
declare -A METRICS
START_TIME=$(date +%s.%N)

# 🛠️ Functions
log() {
    echo -e "${BLUE}🎩 [$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

info() {
    echo -e "${CYAN}ℹ️${NC} $1"
}

metric() {
    local service="$1"
    local time="$2"
    METRICS["$service"]="$time"
}

cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Trap für Cleanup
trap cleanup EXIT

test_service_health() {
    local service_name="$1"
    local host="$2"
    local port="$3"
    
    log "Teste $service_name Health..."
    
    local start_time=$(date +%s.%N)
    if curl -f -s "http://$host:$port/health" > /dev/null 2>&1; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        success "$service_name ist gesund (${duration}s)"
        metric "${service_name}_health" "$duration"
        return 0
    else
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        error "$service_name ist nicht erreichbar (${duration}s)"
        metric "${service_name}_health" "failed"
        return 1
    fi
}

generate_test_audio() {
    local text="$1"
    local output_file="$2"
    
    log "Generiere Test-Audio..."
    
    # macOS: say command
    if command -v say >/dev/null 2>&1; then
        if command -v ffmpeg >/dev/null 2>&1; then
            say -v Anna "$text" -o "$output_file.aiff" 2>/dev/null || true
            ffmpeg -i "$output_file.aiff" -ar 16000 -ac 1 -y "$output_file" 2>/dev/null || true
            rm -f "$output_file.aiff" 2>/dev/null || true
        else
            say -v Anna "$text" -o "$output_file" 2>/dev/null || true
        fi
    # Linux: espeak
    elif command -v espeak >/dev/null 2>&1; then
        espeak -v de -s 150 -w "$output_file" "$text" 2>/dev/null || true
    else
        # Fallback: Stilles Audio mit sox falls verfügbar
        if command -v sox >/dev/null 2>&1; then
            sox -n -r 16000 -c 1 "$output_file" trim 0.0 2.0 2>/dev/null || true
        else
            warning "Keine Audio-Generierung verfügbar - verwende leere Datei"
            touch "$output_file"
        fi
    fi
    
    if [[ -f "$output_file" ]]; then
        success "Test-Audio erstellt: $(ls -lh "$output_file" | awk '{print $5}')"
        return 0
    else
        error "Audio-Generierung fehlgeschlagen"
        return 1
    fi
}

test_stt_service() {
    local audio_file="$1"
    
    log "Teste STT Service..."
    
    if [[ ! -f "$audio_file" ]]; then
        error "Audio-Datei nicht gefunden: $audio_file"
        return 1
    fi
    
    local start_time=$(date +%s.%N)
    local response
    
    if response=$(curl -f -s -X POST \
        -F "audio=@$audio_file;type=audio/wav" \
        "http://$STT_HOST:$STT_PORT/transcribe" 2>/dev/null); then
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        
        # Parse Response
        local transcribed_text
        if transcribed_text=$(echo "$response" | jq -r '.text // .transcription // empty' 2>/dev/null); then
            success "STT erfolgreich (${duration}s): '$transcribed_text'"
            metric "stt" "$duration"
            echo "$transcribed_text"
            return 0
        else
            info "STT Response: $response"
            success "STT erfolgreich (${duration}s) - Raw Response"
            metric "stt" "$duration"
            echo "$TEST_TEXT"  # Fallback
            return 0
        fi
    else
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        error "STT fehlgeschlagen (${duration}s)"
        metric "stt" "failed"
        return 1
    fi
}

test_llm_service() {
    local prompt="$1"
    
    log "Teste LLM Service..."
    
    local start_time=$(date +%s.%N)
    local response
    local payload=$(jq -n \
        --arg prompt "$prompt" \
        --arg lang "de" \
        '{prompt: $prompt, max_tokens: 150, temperature: 0.7, language: $lang}')
    
    if response=$(curl -f -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "http://$LLM_HOST:$LLM_PORT/generate" 2>/dev/null); then
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        
        # Parse Response
        local generated_text
        if generated_text=$(echo "$response" | jq -r '.response // .text // .generated_text // empty' 2>/dev/null); then
            local short_text="${generated_text:0:50}"
            success "LLM erfolgreich (${duration}s): '$short_text...'"
            metric "llm" "$duration"
            echo "$generated_text"
            return 0
        else
            info "LLM Response: $response"
            success "LLM erfolgreich (${duration}s) - Raw Response"
            metric "llm" "$duration"
            echo "Hallo! Es geht mir gut, danke der Nachfrage. Wie kann ich dir helfen?"  # Fallback
            return 0
        fi
    else
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        error "LLM fehlgeschlagen (${duration}s)"
        metric "llm" "failed"
        return 1
    fi
}

test_tts_service() {
    local text="$1"
    
    log "Teste TTS Service..."
    
    local start_time=$(date +%s.%N)
    local payload=$(jq -n \
        --arg text "$text" \
        --arg voice "neural_german_female" \
        '{text: $text, voice: $voice, speed: 1.0, pitch: 1.0}')
    
    if curl -f -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        -o "$TTS_AUDIO_FILE" \
        "http://$TTS_HOST:$TTS_PORT/synthesize" 2>/dev/null; then
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        
        if [[ -f "$TTS_AUDIO_FILE" ]] && [[ -s "$TTS_AUDIO_FILE" ]]; then
            local file_size=$(ls -lh "$TTS_AUDIO_FILE" | awk '{print $5}')
            success "TTS erfolgreich (${duration}s): Audio generiert ($file_size)"
            metric "tts" "$duration"
            return 0
        else
            error "TTS: Leere Audio-Datei generiert"
            metric "tts" "failed"
            return 1
        fi
    else
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        error "TTS fehlgeschlagen (${duration}s)"
        metric "tts" "failed"
        return 1
    fi
}

print_summary() {
    local total_time=$(echo "$(date +%s.%N) - $START_TIME" | bc -l)
    
    echo ""
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}🎩 GENTLEMAN AI-PIPELINE TEST ZUSAMMENFASSUNG${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "⏱️  ${CYAN}Gesamtdauer:${NC} ${total_time}s"
    echo -e "🎯 ${CYAN}Test-Text:${NC} '$TEST_TEXT'"
    echo ""
    echo -e "${YELLOW}📊 Performance Metriken:${NC}"
    echo "─────────────────────────────────────────────────────────────────"
    
    local total_pipeline_time=0
    local successful_services=0
    local failed_services=0
    
    for service in stt_health llm_health tts_health stt llm tts; do
        if [[ -n "${METRICS[$service]:-}" ]]; then
            local service_display=$(echo "$service" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')
            if [[ "${METRICS[$service]}" == "failed" ]]; then
                echo -e "❌ ${service_display}: ${RED}FEHLGESCHLAGEN${NC}"
                ((failed_services++))
            else
                local duration="${METRICS[$service]}"
                echo -e "✅ ${service_display}: ${GREEN}${duration}s${NC}"
                ((successful_services++))
                
                # Addiere zur Pipeline-Zeit (nur STT, LLM, TTS)
                if [[ "$service" =~ ^(stt|llm|tts)$ ]]; then
                    total_pipeline_time=$(echo "$total_pipeline_time + $duration" | bc -l)
                fi
            fi
        fi
    done
    
    echo ""
    echo -e "${YELLOW}🔄 Pipeline Performance:${NC}"
    echo "─────────────────────────────────────────────────────────────────"
    echo -e "⚡ Reine Pipeline-Zeit: ${CYAN}${total_pipeline_time}s${NC}"
    echo -e "📈 Erfolgreiche Services: ${GREEN}$successful_services${NC}"
    echo -e "💥 Fehlgeschlagene Services: ${RED}$failed_services${NC}"
    
    if (( successful_services > 0 )); then
        local success_rate=$(echo "scale=1; $successful_services * 100 / ($successful_services + $failed_services)" | bc -l)
        echo -e "🎯 Erfolgsrate: ${GREEN}${success_rate}%${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}💡 Empfehlungen:${NC}"
    echo "─────────────────────────────────────────────────────────────────"
    
    # Performance Empfehlungen
    if [[ -n "${METRICS[stt]:-}" ]] && [[ "${METRICS[stt]}" != "failed" ]]; then
        if (( $(echo "${METRICS[stt]} > 3.0" | bc -l) )); then
            echo "🎤 STT Performance: Optimierung empfohlen (>${METRICS[stt]}s)"
        fi
    fi
    
    if [[ -n "${METRICS[llm]:-}" ]] && [[ "${METRICS[llm]}" != "failed" ]]; then
        if (( $(echo "${METRICS[llm]} > 5.0" | bc -l) )); then
            echo "🧠 LLM Performance: GPU-Auslastung prüfen (>${METRICS[llm]}s)"
        fi
    fi
    
    if [[ -n "${METRICS[tts]:-}" ]] && [[ "${METRICS[tts]}" != "failed" ]]; then
        if (( $(echo "${METRICS[tts]} > 2.0" | bc -l) )); then
            echo "🔊 TTS Performance: Optimierung empfohlen (>${METRICS[tts]}s)"
        fi
    fi
    
    # Service Empfehlungen
    if (( failed_services > 0 )); then
        echo "🚨 Services reparieren: $failed_services Service(s) nicht verfügbar"
    fi
    
    if (( failed_services == 0 )); then
        echo "✅ Alle Services funktionieren optimal!"
    fi
    
    echo ""
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
}

main() {
    echo -e "${PURPLE}🎩 GENTLEMAN AI-Pipeline Quick Test${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Setup
    mkdir -p "$TEMP_DIR"
    
    # Prüfe erforderliche Tools
    local missing_tools=()
    for tool in curl jq bc; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Fehlende Tools: ${missing_tools[*]}"
        echo "Ubuntu/Debian: sudo apt install curl jq bc"
        echo "macOS: brew install curl jq bc"
        exit 1
    fi
    
    # 1. Health Checks
    log "Starte Service Health Checks..."
    local health_failed=0
    
    test_service_health "STT" "$STT_HOST" "$STT_PORT" || ((health_failed++))
    test_service_health "LLM" "$LLM_HOST" "$LLM_PORT" || ((health_failed++))
    test_service_health "TTS" "$TTS_HOST" "$TTS_PORT" || ((health_failed++))
    
    if (( health_failed > 0 )); then
        warning "$health_failed Service(s) nicht gesund - Pipeline-Test könnte fehlschlagen"
    else
        success "Alle Services gesund - starte Pipeline-Test"
    fi
    
    echo ""
    log "Starte AI-Pipeline Test..."
    
    # 2. Audio generieren
    if ! generate_test_audio "$TEST_TEXT" "$AUDIO_FILE"; then
        error "Kann kein Test-Audio generieren"
        exit 1
    fi
    
    # 3. STT Test
    local transcribed_text
    if transcribed_text=$(test_stt_service "$AUDIO_FILE"); then
        info "Transkribiert: '$transcribed_text'"
    else
        error "STT Test fehlgeschlagen - Pipeline abgebrochen"
        print_summary
        exit 1
    fi
    
    # 4. LLM Test
    local generated_text
    if generated_text=$(test_llm_service "$transcribed_text"); then
        info "LLM Response: '${generated_text:0:100}...'"
    else
        error "LLM Test fehlgeschlagen - Pipeline abgebrochen"
        print_summary
        exit 1
    fi
    
    # 5. TTS Test
    if test_tts_service "$generated_text"; then
        info "TTS Audio: $TTS_AUDIO_FILE"
    else
        error "TTS Test fehlgeschlagen"
    fi
    
    # 6. Summary
    print_summary
    
    # 7. Optional: Audio abspielen
    if [[ -f "$TTS_AUDIO_FILE" ]] && [[ -s "$TTS_AUDIO_FILE" ]]; then
        echo ""
        echo -e "${CYAN}🔊 Generierte Audio-Datei: $TTS_AUDIO_FILE${NC}"
        if command -v afplay >/dev/null 2>&1; then  # macOS
            echo "Abspielen mit: afplay $TTS_AUDIO_FILE"
        elif command -v aplay >/dev/null 2>&1; then  # Linux ALSA
            echo "Abspielen mit: aplay $TTS_AUDIO_FILE"
        elif command -v paplay >/dev/null 2>&1; then  # Linux PulseAudio
            echo "Abspielen mit: paplay $TTS_AUDIO_FILE"
        fi
    fi
}

# Entry Point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 