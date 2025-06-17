#!/bin/bash

# 🎩 GENTLEMAN - Demo Test Runner
# ═══════════════════════════════════════════════════════════════
# Demonstriert die komplette AI-Pipeline: STT (M1) → LLM (RX 6700 XT) → TTS (M1)

set -e

# 🎨 Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}🎩 GENTLEMAN AI-PIPELINE DEMO${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Intro
echo -e "${CYAN}🎯 Über diesen Test:${NC}"
echo "   Diese Demo testet die komplette AI-Pipeline:"
echo "   📍 STT Service (M1 Mac):        192.168.100.20:8002"
echo "   📍 LLM Server (RX 6700 XT):     192.168.100.10:8001"
echo "   📍 TTS Service (M1 Mac):        192.168.100.20:8003"
echo ""
echo -e "${YELLOW}⚡ Pipeline-Flow:${NC}"
echo "   1. Audio Input → STT (Whisper auf M1)"
echo "   2. Text → LLM (Llama/Mistral auf RX 6700 XT)"
echo "   3. Response → TTS (Neural Voice auf M1)"
echo ""

# Warte auf User Input
echo -e "${BLUE}🚀 Drücke ENTER um zu starten...${NC}"
read -r

echo ""
echo -e "${PURPLE}──────────────────────────────────────────────────────────────────${NC}"
echo -e "${PURPLE}📋 SCHRITT 1: SERVICE HEALTH CHECKS${NC}"
echo -e "${PURPLE}──────────────────────────────────────────────────────────────────${NC}"

make test-services-health

echo ""
echo -e "${PURPLE}──────────────────────────────────────────────────────────────────${NC}"
echo -e "${PURPLE}🎯 SCHRITT 2: QUICK PIPELINE TEST${NC}"
echo -e "${PURPLE}──────────────────────────────────────────────────────────────────${NC}"

make test-ai-pipeline

echo ""
echo -e "${BLUE}🤔 Vollständiger E2E Test mit mehreren Szenarien? (y/n):${NC}"
read -r run_full_test

if [[ "$run_full_test" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${PURPLE}──────────────────────────────────────────────────────────────────${NC}"
    echo -e "${PURPLE}🚀 SCHRITT 3: VOLLSTÄNDIGER E2E TEST${NC}"
    echo -e "${PURPLE}──────────────────────────────────────────────────────────────────${NC}"
    
    make test-ai-pipeline-full
fi

echo ""
echo -e "${BLUE}🏃‍♂️ Performance Test mit 5 Durchläufen? (y/n):${NC}"
read -r run_perf_test

if [[ "$run_perf_test" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${PURPLE}──────────────────────────────────────────────────────────────────${NC}"
    echo -e "${PURPLE}⚡ SCHRITT 4: PERFORMANCE TEST${NC}"
    echo -e "${PURPLE}──────────────────────────────────────────────────────────────────${NC}"
    
    make test-performance
fi

echo ""
echo -e "${GREEN}✅ DEMO ABGESCHLOSSEN!${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📚 Verfügbare Test-Kommandos:${NC}"
echo "   make test-services-health     - Teste nur Service Health"
echo "   make test-ai-pipeline         - Schneller Pipeline Test"
echo "   make test-ai-pipeline-full    - Vollständiger E2E Test"
echo "   make test-performance         - Performance Benchmarks"
echo "   make test-dev                 - Development Test Suite"
echo ""
echo -e "${CYAN}🔧 Einzelne Services testen:${NC}"
echo "   make test-stt-only           - Nur STT Service"
echo "   make test-llm-only           - Nur LLM Service"
echo "   make test-tts-only           - Nur TTS Service"
echo ""
echo -e "${YELLOW}💡 Tipp:${NC} Für kontinuierliche Tests können Sie einen Cronjob einrichten:"
echo "   */15 * * * * cd /path/to/gentleman && make test-ai-pipeline >/dev/null 2>&1"
echo "" 