#!/bin/bash
# call-agent.sh - Call a local Ollama agent with robust error handling
#
# Usage: ./call-agent.sh <agent_name> "<prompt>"
#        ./call-agent.sh builder "Implement the factorial function"
#
# Environment variables:
#   OLLAMA_URL      - Ollama API URL (default: http://localhost:11434)
#   OLLAMA_MODEL    - Model to use (default: qwen3:32b)
#   TIMEOUT         - Request timeout in seconds (default: 300)
#   MAX_RETRIES     - Maximum retry attempts (default: 3)
#   LOG_DIR         - Log directory (default: ~/clawd/memory/logs)
#   THINKING_MODE   - Enable thinking mode: true/false (default: true)

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
OLLAMA_MODEL="${OLLAMA_MODEL:-qwen3:32b}"
TIMEOUT="${TIMEOUT:-300}"
MAX_RETRIES="${MAX_RETRIES:-3}"
LOG_DIR="${LOG_DIR:-$HOME/clawd/memory/logs}"
THINKING_MODE="${THINKING_MODE:-true}"
ALERTS_DIR="${ALERTS_DIR:-$HOME/clawd/memory/alerts}"

# Retry configuration
INITIAL_BACKOFF=5
MAX_BACKOFF=60

# ============================================================================
# Setup
# ============================================================================

# Ensure directories exist
mkdir -p "$LOG_DIR"
mkdir -p "$ALERTS_DIR"

# Generate session ID for this call
SESSION_ID="$(date +%Y%m%d-%H%M%S)-$$"
LOG_FILE="$LOG_DIR/agent-calls.log"

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
    
    # Also print to stderr for visibility
    if [[ "$level" == "ERROR" ]] || [[ "$level" == "WARN" ]]; then
        echo "[$level] $message" >&2
    fi
}

log_json() {
    local agent="$1"
    local status="$2"
    local latency_ms="$3"
    local error="${4:-}"
    
    local timestamp
    timestamp="$(date -Iseconds)"
    
    # Append to JSONL log
    echo "{\"timestamp\":\"$timestamp\",\"session\":\"$SESSION_ID\",\"agent\":\"$agent\",\"status\":\"$status\",\"latency_ms\":$latency_ms,\"error\":\"$error\"}" >> "$LOG_DIR/calls.jsonl"
}

check_ollama_health() {
    local response
    local http_code
    
    # Try to get tags (lightweight health check)
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time 10 \
        "$OLLAMA_URL/api/tags" 2>/dev/null) || true
    
    if [[ "$response" == "200" ]]; then
        return 0
    else
        return 1
    fi
}

create_alert() {
    local title="$1"
    local severity="$2"
    local description="$3"
    
    local timestamp
    timestamp="$(date -Iseconds)"
    local alert_file="$ALERTS_DIR/AGENT-CALL-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$alert_file" << EOF
# ESCALATION: $title

**Timestamp**: $timestamp
**Severity**: $severity
**Agent**: call-agent.sh

## Issue

$description

## Context

- Session ID: $SESSION_ID
- Ollama URL: $OLLAMA_URL
- Model: $OLLAMA_MODEL

## Attempted Solutions

Script exhausted retry attempts ($MAX_RETRIES).

## Human Action Needed

Check Ollama status and logs.

EOF
    
    log "ALERT" "Created alert file: $alert_file"
}

call_ollama() {
    local agent="$1"
    local prompt="$2"
    
    # Load agent system prompt if available
    local system_prompt=""
    local agent_file="$HOME/clawd/agents/${agent}.md"
    
    if [[ -f "$agent_file" ]]; then
        system_prompt=$(cat "$agent_file")
        log "INFO" "Loaded system prompt from $agent_file"
    else
        log "WARN" "No agent file found at $agent_file, using prompt only"
    fi
    
    # Build request body
    local request_body
    if [[ -n "$system_prompt" ]]; then
        request_body=$(jq -n \
            --arg model "$OLLAMA_MODEL" \
            --arg system "$system_prompt" \
            --arg prompt "$prompt" \
            --argjson think "$THINKING_MODE" \
            '{
                model: $model,
                system: $system,
                prompt: $prompt,
                stream: false,
                options: {
                    num_ctx: 32768
                },
                think: $think
            }')
    else
        request_body=$(jq -n \
            --arg model "$OLLAMA_MODEL" \
            --arg prompt "$prompt" \
            --argjson think "$THINKING_MODE" \
            '{
                model: $model,
                prompt: $prompt,
                stream: false,
                options: {
                    num_ctx: 32768
                },
                think: $think
            }')
    fi
    
    # Make the request
    local start_time
    start_time=$(date +%s%3N)
    
    local response
    local http_code
    local curl_exit
    
    # Use a temp file for the response body
    local temp_response
    temp_response=$(mktemp)
    
    http_code=$(curl -s -o "$temp_response" -w "%{http_code}" \
        --max-time "$TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$request_body" \
        "$OLLAMA_URL/api/generate" 2>/dev/null) && curl_exit=0 || curl_exit=$?
    
    local end_time
    end_time=$(date +%s%3N)
    local latency_ms=$((end_time - start_time))
    
    # Check curl exit code
    if [[ $curl_exit -ne 0 ]]; then
        rm -f "$temp_response"
        log "ERROR" "Curl failed with exit code $curl_exit"
        log_json "$agent" "curl_error" "$latency_ms" "exit_code_$curl_exit"
        return 1
    fi
    
    # Check HTTP status
    if [[ "$http_code" != "200" ]]; then
        local error_body
        error_body=$(cat "$temp_response" 2>/dev/null || echo "no body")
        rm -f "$temp_response"
        log "ERROR" "HTTP $http_code: $error_body"
        log_json "$agent" "http_error" "$latency_ms" "http_$http_code"
        return 1
    fi
    
    # Parse response
    response=$(cat "$temp_response")
    rm -f "$temp_response"
    
    # Extract the response text (strip thinking blocks for cleaner output)
    local output
    output=$(echo "$response" | jq -r '.response // empty')
    
    if [[ -z "$output" ]]; then
        log "ERROR" "Empty response from Ollama"
        log_json "$agent" "empty_response" "$latency_ms" "empty"
        return 1
    fi
    
    # Success!
    log_json "$agent" "success" "$latency_ms" ""
    log "INFO" "Call to $agent completed in ${latency_ms}ms"
    
    # Output the response
    echo "$output"
    return 0
}

# ============================================================================
# Main
# ============================================================================

main() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <agent_name> \"<prompt>\"" >&2
        echo "" >&2
        echo "Agents: director, architect, scout, builder, refactorer, inspector, scribe" >&2
        echo "" >&2
        echo "Environment variables:" >&2
        echo "  OLLAMA_URL      - API URL (default: http://localhost:11434)" >&2
        echo "  OLLAMA_MODEL    - Model (default: qwen3:32b)" >&2
        echo "  TIMEOUT         - Timeout in seconds (default: 300)" >&2
        echo "  MAX_RETRIES     - Retry attempts (default: 3)" >&2
        echo "  THINKING_MODE   - Enable thinking: true/false (default: true)" >&2
        exit 1
    fi
    
    local agent="$1"
    local prompt="$2"
    
    log "INFO" "Starting call to agent '$agent' (session: $SESSION_ID)"
    log "INFO" "Prompt: ${prompt:0:100}..."  # Log first 100 chars
    
    # Health check
    if ! check_ollama_health; then
        log "ERROR" "Ollama health check failed at $OLLAMA_URL"
        echo "ERROR: Ollama is not responding at $OLLAMA_URL" >&2
        
        # Create a state file for Director awareness
        echo "{\"status\":\"ollama_down\",\"timestamp\":\"$(date -Iseconds)\",\"url\":\"$OLLAMA_URL\"}" > "$LOG_DIR/ollama-status.json"
        exit 1
    fi
    
    # Retry loop with exponential backoff
    local attempt=1
    local backoff=$INITIAL_BACKOFF
    
    while [[ $attempt -le $MAX_RETRIES ]]; do
        log "INFO" "Attempt $attempt of $MAX_RETRIES"
        
        if call_ollama "$agent" "$prompt"; then
            # Success - clear any error state
            rm -f "$LOG_DIR/ollama-status.json"
            exit 0
        fi
        
        if [[ $attempt -lt $MAX_RETRIES ]]; then
            log "WARN" "Attempt $attempt failed, retrying in ${backoff}s..."
            sleep "$backoff"
            
            # Exponential backoff with cap
            backoff=$((backoff * 2))
            if [[ $backoff -gt $MAX_BACKOFF ]]; then
                backoff=$MAX_BACKOFF
            fi
        fi
        
        ((attempt++))
    done
    
    # All retries exhausted
    log "ERROR" "All $MAX_RETRIES attempts failed for agent '$agent'"
    
    # Create alert
    create_alert "Agent Call Failed" "HIGH" "Failed to call agent '$agent' after $MAX_RETRIES attempts. Last prompt: ${prompt:0:200}..."
    
    # Create state file
    echo "{\"status\":\"call_failed\",\"agent\":\"$agent\",\"timestamp\":\"$(date -Iseconds)\",\"attempts\":$MAX_RETRIES}" > "$LOG_DIR/last-failure.json"
    
    exit 1
}

main "$@"
