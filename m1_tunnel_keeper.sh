#!/bin/bash

# 🌐 GENTLEMAN M1 Tunnel Keeper
# =============================
# Hält Cloudflare Tunnel stabil und überwacht die Verbindung
# Automatisches Recovery bei Verbindungsabbrüchen

set -e

# Konfiguration
TUNNEL_PORT="8765"
TUNNEL_LOG="/tmp/cloudflare_tunnel.log"
KEEPER_LOG="/tmp/tunnel_keeper.log"
KEEPER_PID="/tmp/tunnel_keeper.pid"
HEALTH_CHECK_INTERVAL=30
MAX_RESTART_ATTEMPTS=5
RESTART_DELAY=10

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging Funktionen
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$msg" >> "$KEEPER_LOG"
}

success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "$KEEPER_LOG"
}

error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1"
    echo -e "${RED}$msg${NC}"
    echo "$msg" >> "$KEEPER_LOG"
}

warning() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "$KEEPER_LOG"
}

# Prüfe ob Tunnel läuft
is_tunnel_running() {
    if pgrep -f "cloudflared tunnel" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Prüfe Tunnel-Gesundheit
check_tunnel_health() {
    local public_url="$1"
    
    if [ -z "$public_url" ]; then
        return 1
    fi
    
    # Teste Health-Endpoint
    if curl -s --connect-timeout 10 --max-time 15 "$public_url/health" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Extrahiere Public URL aus Tunnel-Logs
extract_public_url() {
    if [ -f "$TUNNEL_LOG" ]; then
        # Suche nach der neuesten URL
        local url=$(tail -50 "$TUNNEL_LOG" | grep -E "https://[a-z0-9-]+\.trycloudflare\.com" | tail -1 | sed -E 's/.*\|(.*)\|.*/\1/' | tr -d ' ')
        
        if [[ "$url" =~ ^https://.*\.trycloudflare\.com$ ]]; then
            echo "$url"
            return 0
        fi
    fi
    
    return 1
}

# Starte Cloudflare Tunnel
start_tunnel() {
    log "🚀 Starte Cloudflare Tunnel..."
    
    # Stoppe alte Tunnel-Instanzen
    pkill -f "cloudflared tunnel" 2>/dev/null || true
    sleep 2
    
    # Starte neuen Tunnel im Hintergrund
    nohup cloudflared tunnel --url "http://localhost:$TUNNEL_PORT" > "$TUNNEL_LOG" 2>&1 &
    local tunnel_pid=$!
    
    # Warte auf Tunnel-Start
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        sleep 2
        attempts=$((attempts + 1))
        
        if is_tunnel_running; then
            # Warte auf Public URL
            sleep 5
            local public_url=$(extract_public_url)
            
            if [ -n "$public_url" ]; then
                success "Tunnel gestartet: $public_url"
                echo "$public_url" > /tmp/current_tunnel_url.txt
                return 0
            fi
        fi
        
        log "Warte auf Tunnel-Start... ($attempts/$max_attempts)"
    done
    
    error "Tunnel-Start fehlgeschlagen"
    return 1
}

# Tunnel-Monitor (Hauptschleife)
monitor_tunnel() {
    local restart_count=0
    local last_restart=0
    
    log "🔄 Starte Tunnel-Monitor..."
    
    while true; do
        # Prüfe ob Tunnel-Prozess läuft
        if ! is_tunnel_running; then
            warning "Tunnel-Prozess nicht gefunden"
            
            # Restart-Limit prüfen
            local current_time=$(date +%s)
            if [ $((current_time - last_restart)) -lt 300 ]; then
                restart_count=$((restart_count + 1))
            else
                restart_count=1
            fi
            
            if [ $restart_count -gt $MAX_RESTART_ATTEMPTS ]; then
                error "Maximale Restart-Versuche erreicht ($MAX_RESTART_ATTEMPTS)"
                error "Tunnel-Monitor wird beendet"
                exit 1
            fi
            
            warning "Restart-Versuch $restart_count/$MAX_RESTART_ATTEMPTS"
            
            # Tunnel neu starten
            if start_tunnel; then
                success "Tunnel erfolgreich neu gestartet"
                last_restart=$current_time
                restart_count=0
            else
                error "Tunnel-Neustart fehlgeschlagen"
                sleep $RESTART_DELAY
                continue
            fi
        else
            # Tunnel läuft - prüfe Gesundheit
            local public_url=$(extract_public_url)
            
            if [ -n "$public_url" ]; then
                if check_tunnel_health "$public_url"; then
                    # Alles OK - nur alle 5 Minuten loggen
                    if [ $(($(date +%s) % 300)) -eq 0 ]; then
                        log "✅ Tunnel gesund: $public_url"
                    fi
                    restart_count=0
                else
                    warning "Tunnel-Health-Check fehlgeschlagen: $public_url"
                    
                    # Gib dem Tunnel eine Chance sich zu erholen
                    sleep 30
                    
                    if ! check_tunnel_health "$public_url"; then
                        warning "Tunnel-Neustart wegen Health-Check-Fehlern"
                        pkill -f "cloudflared tunnel" 2>/dev/null || true
                        sleep 5
                        continue
                    fi
                fi
            else
                warning "Keine Public URL gefunden"
            fi
        fi
        
        # Warte bis zum nächsten Check
        sleep $HEALTH_CHECK_INTERVAL
    done
}

# Stoppe Tunnel-Keeper
stop_keeper() {
    log "🛑 Stoppe Tunnel-Keeper..."
    
    # Stoppe Tunnel
    pkill -f "cloudflared tunnel" 2>/dev/null || true
    
    # Entferne PID-Datei
    rm -f "$KEEPER_PID"
    
    # Entferne URL-Datei
    rm -f /tmp/current_tunnel_url.txt
    
    success "Tunnel-Keeper gestoppt"
}

# Status anzeigen
show_status() {
    echo
    echo "🌐 GENTLEMAN Tunnel-Keeper Status"
    echo "================================="
    echo
    
    # Keeper-Status
    if [ -f "$KEEPER_PID" ] && kill -0 "$(cat "$KEEPER_PID")" 2>/dev/null; then
        echo "✅ Tunnel-Keeper: Läuft (PID: $(cat "$KEEPER_PID"))"
    else
        echo "❌ Tunnel-Keeper: Gestoppt"
    fi
    
    # Tunnel-Status
    if is_tunnel_running; then
        echo "✅ Cloudflare Tunnel: Läuft"
        
        local public_url=$(extract_public_url)
        if [ -n "$public_url" ]; then
            echo "🌐 Public URL: $public_url"
            
            if check_tunnel_health "$public_url"; then
                echo "💚 Health Check: OK"
            else
                echo "💔 Health Check: Fehler"
            fi
        else
            echo "⚠️  Public URL: Nicht verfügbar"
        fi
    else
        echo "❌ Cloudflare Tunnel: Gestoppt"
    fi
    
    echo
    
    # Log-Statistiken
    if [ -f "$KEEPER_LOG" ]; then
        local log_lines=$(wc -l < "$KEEPER_LOG")
        local errors=$(grep -c "❌" "$KEEPER_LOG" 2>/dev/null || echo "0")
        local warnings=$(grep -c "⚠️" "$KEEPER_LOG" 2>/dev/null || echo "0")
        
        echo "📊 Log-Statistiken:"
        echo "   Gesamt-Einträge: $log_lines"
        echo "   Fehler: $errors"
        echo "   Warnungen: $warnings"
        echo
    fi
}

# Hauptfunktion
main() {
    case "${1:-start}" in
        "start")
            if [ -f "$KEEPER_PID" ] && kill -0 "$(cat "$KEEPER_PID")" 2>/dev/null; then
                warning "Tunnel-Keeper läuft bereits (PID: $(cat "$KEEPER_PID"))"
                exit 1
            fi
            
            echo
            echo "🌐 GENTLEMAN Tunnel-Keeper"
            echo "=========================="
            echo
            
            # Starte im Hintergrund
            (
                echo $$ > "$KEEPER_PID"
                monitor_tunnel
            ) &
            
            success "Tunnel-Keeper gestartet (PID: $!)"
            ;;
        "stop")
            if [ -f "$KEEPER_PID" ] && kill -0 "$(cat "$KEEPER_PID")" 2>/dev/null; then
                kill "$(cat "$KEEPER_PID")"
                stop_keeper
            else
                warning "Tunnel-Keeper läuft nicht"
            fi
            ;;
        "restart")
            $0 stop
            sleep 2
            $0 start
            ;;
        "status")
            show_status
            ;;
        "logs")
            if [ -f "$KEEPER_LOG" ]; then
                tail -50 "$KEEPER_LOG"
            else
                warning "Keine Logs verfügbar"
            fi
            ;;
        "url")
            if [ -f /tmp/current_tunnel_url.txt ]; then
                cat /tmp/current_tunnel_url.txt
            else
                echo "Keine aktuelle URL verfügbar"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 {start|stop|restart|status|logs|url}"
            echo
            echo "Commands:"
            echo "  start   - Starte Tunnel-Keeper"
            echo "  stop    - Stoppe Tunnel-Keeper"
            echo "  restart - Neustart Tunnel-Keeper"
            echo "  status  - Zeige Status"
            echo "  logs    - Zeige Logs"
            echo "  url     - Zeige aktuelle Public URL"
            echo
            exit 1
            ;;
    esac
}

# Cleanup bei Script-Ende
trap stop_keeper EXIT INT TERM

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 

# 🌐 GENTLEMAN M1 Tunnel Keeper
# =============================
# Hält Cloudflare Tunnel stabil und überwacht die Verbindung
# Automatisches Recovery bei Verbindungsabbrüchen

set -e

# Konfiguration
TUNNEL_PORT="8765"
TUNNEL_LOG="/tmp/cloudflare_tunnel.log"
KEEPER_LOG="/tmp/tunnel_keeper.log"
KEEPER_PID="/tmp/tunnel_keeper.pid"
HEALTH_CHECK_INTERVAL=30
MAX_RESTART_ATTEMPTS=5
RESTART_DELAY=10

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging Funktionen
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$msg" >> "$KEEPER_LOG"
}

success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "$KEEPER_LOG"
}

error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1"
    echo -e "${RED}$msg${NC}"
    echo "$msg" >> "$KEEPER_LOG"
}

warning() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "$KEEPER_LOG"
}

# Prüfe ob Tunnel läuft
is_tunnel_running() {
    if pgrep -f "cloudflared tunnel" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Prüfe Tunnel-Gesundheit
check_tunnel_health() {
    local public_url="$1"
    
    if [ -z "$public_url" ]; then
        return 1
    fi
    
    # Teste Health-Endpoint
    if curl -s --connect-timeout 10 --max-time 15 "$public_url/health" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Extrahiere Public URL aus Tunnel-Logs
extract_public_url() {
    if [ -f "$TUNNEL_LOG" ]; then
        # Suche nach der neuesten URL
        local url=$(tail -50 "$TUNNEL_LOG" | grep -E "https://[a-z0-9-]+\.trycloudflare\.com" | tail -1 | sed -E 's/.*\|(.*)\|.*/\1/' | tr -d ' ')
        
        if [[ "$url" =~ ^https://.*\.trycloudflare\.com$ ]]; then
            echo "$url"
            return 0
        fi
    fi
    
    return 1
}

# Starte Cloudflare Tunnel
start_tunnel() {
    log "🚀 Starte Cloudflare Tunnel..."
    
    # Stoppe alte Tunnel-Instanzen
    pkill -f "cloudflared tunnel" 2>/dev/null || true
    sleep 2
    
    # Starte neuen Tunnel im Hintergrund
    nohup cloudflared tunnel --url "http://localhost:$TUNNEL_PORT" > "$TUNNEL_LOG" 2>&1 &
    local tunnel_pid=$!
    
    # Warte auf Tunnel-Start
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        sleep 2
        attempts=$((attempts + 1))
        
        if is_tunnel_running; then
            # Warte auf Public URL
            sleep 5
            local public_url=$(extract_public_url)
            
            if [ -n "$public_url" ]; then
                success "Tunnel gestartet: $public_url"
                echo "$public_url" > /tmp/current_tunnel_url.txt
                return 0
            fi
        fi
        
        log "Warte auf Tunnel-Start... ($attempts/$max_attempts)"
    done
    
    error "Tunnel-Start fehlgeschlagen"
    return 1
}

# Tunnel-Monitor (Hauptschleife)
monitor_tunnel() {
    local restart_count=0
    local last_restart=0
    
    log "🔄 Starte Tunnel-Monitor..."
    
    while true; do
        # Prüfe ob Tunnel-Prozess läuft
        if ! is_tunnel_running; then
            warning "Tunnel-Prozess nicht gefunden"
            
            # Restart-Limit prüfen
            local current_time=$(date +%s)
            if [ $((current_time - last_restart)) -lt 300 ]; then
                restart_count=$((restart_count + 1))
            else
                restart_count=1
            fi
            
            if [ $restart_count -gt $MAX_RESTART_ATTEMPTS ]; then
                error "Maximale Restart-Versuche erreicht ($MAX_RESTART_ATTEMPTS)"
                error "Tunnel-Monitor wird beendet"
                exit 1
            fi
            
            warning "Restart-Versuch $restart_count/$MAX_RESTART_ATTEMPTS"
            
            # Tunnel neu starten
            if start_tunnel; then
                success "Tunnel erfolgreich neu gestartet"
                last_restart=$current_time
                restart_count=0
            else
                error "Tunnel-Neustart fehlgeschlagen"
                sleep $RESTART_DELAY
                continue
            fi
        else
            # Tunnel läuft - prüfe Gesundheit
            local public_url=$(extract_public_url)
            
            if [ -n "$public_url" ]; then
                if check_tunnel_health "$public_url"; then
                    # Alles OK - nur alle 5 Minuten loggen
                    if [ $(($(date +%s) % 300)) -eq 0 ]; then
                        log "✅ Tunnel gesund: $public_url"
                    fi
                    restart_count=0
                else
                    warning "Tunnel-Health-Check fehlgeschlagen: $public_url"
                    
                    # Gib dem Tunnel eine Chance sich zu erholen
                    sleep 30
                    
                    if ! check_tunnel_health "$public_url"; then
                        warning "Tunnel-Neustart wegen Health-Check-Fehlern"
                        pkill -f "cloudflared tunnel" 2>/dev/null || true
                        sleep 5
                        continue
                    fi
                fi
            else
                warning "Keine Public URL gefunden"
            fi
        fi
        
        # Warte bis zum nächsten Check
        sleep $HEALTH_CHECK_INTERVAL
    done
}

# Stoppe Tunnel-Keeper
stop_keeper() {
    log "🛑 Stoppe Tunnel-Keeper..."
    
    # Stoppe Tunnel
    pkill -f "cloudflared tunnel" 2>/dev/null || true
    
    # Entferne PID-Datei
    rm -f "$KEEPER_PID"
    
    # Entferne URL-Datei
    rm -f /tmp/current_tunnel_url.txt
    
    success "Tunnel-Keeper gestoppt"
}

# Status anzeigen
show_status() {
    echo
    echo "🌐 GENTLEMAN Tunnel-Keeper Status"
    echo "================================="
    echo
    
    # Keeper-Status
    if [ -f "$KEEPER_PID" ] && kill -0 "$(cat "$KEEPER_PID")" 2>/dev/null; then
        echo "✅ Tunnel-Keeper: Läuft (PID: $(cat "$KEEPER_PID"))"
    else
        echo "❌ Tunnel-Keeper: Gestoppt"
    fi
    
    # Tunnel-Status
    if is_tunnel_running; then
        echo "✅ Cloudflare Tunnel: Läuft"
        
        local public_url=$(extract_public_url)
        if [ -n "$public_url" ]; then
            echo "🌐 Public URL: $public_url"
            
            if check_tunnel_health "$public_url"; then
                echo "💚 Health Check: OK"
            else
                echo "💔 Health Check: Fehler"
            fi
        else
            echo "⚠️  Public URL: Nicht verfügbar"
        fi
    else
        echo "❌ Cloudflare Tunnel: Gestoppt"
    fi
    
    echo
    
    # Log-Statistiken
    if [ -f "$KEEPER_LOG" ]; then
        local log_lines=$(wc -l < "$KEEPER_LOG")
        local errors=$(grep -c "❌" "$KEEPER_LOG" 2>/dev/null || echo "0")
        local warnings=$(grep -c "⚠️" "$KEEPER_LOG" 2>/dev/null || echo "0")
        
        echo "📊 Log-Statistiken:"
        echo "   Gesamt-Einträge: $log_lines"
        echo "   Fehler: $errors"
        echo "   Warnungen: $warnings"
        echo
    fi
}

# Hauptfunktion
main() {
    case "${1:-start}" in
        "start")
            if [ -f "$KEEPER_PID" ] && kill -0 "$(cat "$KEEPER_PID")" 2>/dev/null; then
                warning "Tunnel-Keeper läuft bereits (PID: $(cat "$KEEPER_PID"))"
                exit 1
            fi
            
            echo
            echo "🌐 GENTLEMAN Tunnel-Keeper"
            echo "=========================="
            echo
            
            # Starte im Hintergrund
            (
                echo $$ > "$KEEPER_PID"
                monitor_tunnel
            ) &
            
            success "Tunnel-Keeper gestartet (PID: $!)"
            ;;
        "stop")
            if [ -f "$KEEPER_PID" ] && kill -0 "$(cat "$KEEPER_PID")" 2>/dev/null; then
                kill "$(cat "$KEEPER_PID")"
                stop_keeper
            else
                warning "Tunnel-Keeper läuft nicht"
            fi
            ;;
        "restart")
            $0 stop
            sleep 2
            $0 start
            ;;
        "status")
            show_status
            ;;
        "logs")
            if [ -f "$KEEPER_LOG" ]; then
                tail -50 "$KEEPER_LOG"
            else
                warning "Keine Logs verfügbar"
            fi
            ;;
        "url")
            if [ -f /tmp/current_tunnel_url.txt ]; then
                cat /tmp/current_tunnel_url.txt
            else
                echo "Keine aktuelle URL verfügbar"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 {start|stop|restart|status|logs|url}"
            echo
            echo "Commands:"
            echo "  start   - Starte Tunnel-Keeper"
            echo "  stop    - Stoppe Tunnel-Keeper"
            echo "  restart - Neustart Tunnel-Keeper"
            echo "  status  - Zeige Status"
            echo "  logs    - Zeige Logs"
            echo "  url     - Zeige aktuelle Public URL"
            echo
            exit 1
            ;;
    esac
}

# Cleanup bei Script-Ende
trap stop_keeper EXIT INT TERM

# Script ausführen
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 
 