#!/bin/bash
# ollama-watchdog.sh - Monitor and restart Ollama during overnight runs
#
# Usage: ./ollama-watchdog.sh &
#        (Run in a separate terminal or as background process)
#
# Environment variables:
#   OLLAMA_URL        - Ollama API URL (default: http://localhost:11434)
#   CHECK_INTERVAL    - Seconds between checks (default: 300 = 5 min)
#   MAX_FAILURES      - Consecutive failures before restart (default: 3)
#   LOG_DIR           - Log directory (default: ~/clawd/memory/logs)
#   ALERTS_DIR        - Alerts directory (default: ~/clawd/memory/alerts)
#   MODEL_TO_LOAD     - Model to reload after restart (default: qwen3:32b)

set -uo pipefail

# ============================================================================
# Configuration
# ============================================================================

OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
CHECK_INTERVAL="${CHECK_INTERVAL:-300}"
MAX_FAILURES="${MAX_FAILURES:-3}"
LOG_DIR="${LOG_DIR:-$HOME/clawd/memory/logs}"
ALERTS_DIR="${ALERTS_DIR:-$HOME/clawd/memory/alerts}"
MODEL_TO_LOAD="${MODEL_TO_LOAD:-qwen3:32b}"

LOG_FILE="$LOG_DIR/watchdog.log"
STATUS_FILE="$LOG_DIR/watchdog-status.json"

# ============================================================================
# Setup
# ============================================================================

mkdir -p "$LOG_DIR"
mkdir -p "$ALERTS_DIR"

failure_count=0
restart_count=0
start_time=$(date +%s)

# ============================================================================
# Functions
# ============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date -Iseconds)"
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    echo "[$timestamp] [$level] $message"
}

update_status() {
    local status="$1"
    local message="${2:-}"
    
    cat > "$STATUS_FILE" << EOF
{
  "status": "$status",
  "timestamp": "$(date -Iseconds)",
  "failure_count": $failure_count,
  "restart_count": $restart_count,
  "uptime_seconds": $(($(date +%s) - start_time)),
  "message": "$message"
}
EOF
}

check_ollama() {
    local response
    local http_code
    
    # Check if Ollama API is responsive
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time 10 \
        "$OLLAMA_URL/api/tags" 2>/dev/null) || true
    
    if [[ "$http_code" == "200" ]]; then
        return 0
    else
        return 1
    fi
}

check_model_loaded() {
    local response
    
    # Check if our model is currently loaded
    response=$(curl -s --max-time 10 "$OLLAMA_URL/api/ps" 2>/dev/null) || true
    
    if echo "$response" | grep -q "$MODEL_TO_LOAD"; then
        return 0
    else
        return 1
    fi
}

check_memory() {
    # Check system memory usage (Linux/macOS compatible)
    local mem_percent
    
    if command -v free &> /dev/null; then
        # Linux
        mem_percent=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
    elif command -v vm_stat &> /dev/null; then
        # macOS
        local pages_free pages_active pages_inactive pages_wired
        pages_free=$(vm_stat | awk '/Pages free/ {print $3}' | tr -d '.')
        pages_active=$(vm_stat | awk '/Pages active/ {print $3}' | tr -d '.')
        pages_inactive=$(vm_stat | awk '/Pages inactive/ {print $3}' | tr -d '.')
        pages_wired=$(vm_stat | awk '/Pages wired down/ {print $4}' | tr -d '.')
        
        local total_pages=$((pages_free + pages_active + pages_inactive + pages_wired))
        local used_pages=$((pages_active + pages_wired))
        
        mem_percent=$((used_pages * 100 / total_pages))
    else
        # Can't determine
        mem_percent=0
    fi
    
    echo "$mem_percent"
}

restart_ollama() {
    log "WARN" "Attempting to restart Ollama..."
    
    # Kill existing Ollama process
    pkill -f "ollama serve" 2>/dev/null || true
    sleep 3
    
    # Start Ollama
    if command -v ollama &> /dev/null; then
        ollama serve &> "$LOG_DIR/ollama-serve.log" &
        sleep 10
        
        # Verify it started
        if check_ollama; then
            log "INFO" "Ollama restarted successfully"
            
            # Warm up the model
            log "INFO" "Loading model $MODEL_TO_LOAD..."
            ollama run "$MODEL_TO_LOAD" "Warmup. Reply with: ready" > /dev/null 2>&1 || true
            
            ((restart_count++))
            return 0
        else
            log "ERROR" "Ollama failed to restart"
            return 1
        fi
    else
        log "ERROR" "ollama command not found"
        return 1
    fi
}

create_alert() {
    local title="$1"
    local severity="$2"
    local description="$3"
    
    local alert_file="$ALERTS_DIR/OLLAMA-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$alert_file" << EOF
# ESCALATION: $title

**Timestamp**: $(date -Iseconds)
**Severity**: $severity
**Agent**: Watchdog

## Issue

$description

## Status

- Failure count: $failure_count
- Restart count: $restart_count
- Uptime: $(($(date +%s) - start_time)) seconds

## Human Action Needed

Check Ollama logs at: $LOG_DIR/ollama-serve.log
Check watchdog logs at: $LOG_FILE

EOF
    
    log "ALERT" "Created alert: $alert_file"
}

cleanup() {
    log "INFO" "Watchdog shutting down"
    update_status "stopped" "Watchdog process terminated"
    exit 0
}

# ============================================================================
# Main
# ============================================================================

# Set up signal handlers
trap cleanup SIGINT SIGTERM

log "INFO" "=========================================="
log "INFO" "Ollama Watchdog Starting"
log "INFO" "URL: $OLLAMA_URL"
log "INFO" "Check interval: ${CHECK_INTERVAL}s"
log "INFO" "Max failures before restart: $MAX_FAILURES"
log "INFO" "Model: $MODEL_TO_LOAD"
log "INFO" "=========================================="

update_status "starting" "Watchdog initializing"

# Initial check
if check_ollama; then
    log "INFO" "Initial health check passed"
    update_status "healthy" "Ollama is responsive"
else
    log "WARN" "Initial health check failed, attempting restart"
    restart_ollama
fi

# Main monitoring loop
while true; do
    sleep "$CHECK_INTERVAL"
    
    # Check Ollama health
    if check_ollama; then
        if [[ $failure_count -gt 0 ]]; then
            log "INFO" "Ollama recovered after $failure_count failures"
        fi
        failure_count=0
        
        # Check if model is loaded
        if ! check_model_loaded; then
            log "WARN" "Model $MODEL_TO_LOAD not loaded, loading..."
            ollama run "$MODEL_TO_LOAD" "Warmup" > /dev/null 2>&1 || true
        fi
        
        # Check memory pressure
        mem_percent=$(check_memory)
        if [[ $mem_percent -gt 85 ]]; then
            log "WARN" "High memory usage: ${mem_percent}%"
            update_status "warning" "High memory usage: ${mem_percent}%"
            
            if [[ $mem_percent -gt 95 ]]; then
                create_alert "Critical Memory Pressure" "HIGH" "System memory at ${mem_percent}%. Ollama may become unstable."
            fi
        else
            update_status "healthy" "Memory: ${mem_percent}%"
        fi
        
    else
        ((failure_count++))
        log "WARN" "Health check failed ($failure_count/$MAX_FAILURES)"
        update_status "degraded" "Health check failures: $failure_count"
        
        if [[ $failure_count -ge $MAX_FAILURES ]]; then
            log "ERROR" "Max failures reached, attempting restart"
            create_alert "Ollama Unresponsive" "HIGH" "Ollama failed to respond after $MAX_FAILURES consecutive checks. Attempting automatic restart."
            
            if restart_ollama; then
                failure_count=0
                update_status "recovered" "Ollama restarted successfully"
            else
                log "ERROR" "Restart failed!"
                create_alert "Ollama Restart Failed" "CRITICAL" "Failed to restart Ollama. Manual intervention required."
                update_status "critical" "Restart failed, manual intervention needed"
                
                # Don't exit - keep trying
                sleep 60
            fi
        fi
    fi
done
