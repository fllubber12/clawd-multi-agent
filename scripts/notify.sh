#!/bin/bash
#
# notify.sh - Send notifications for clawd events
#
# Usage:
#   ./scripts/notify.sh "Task completed successfully" info
#   ./scripts/notify.sh "Escalation needed" error
#
# Environment variables:
#   DISCORD_WEBHOOK  - Discord webhook URL (optional)
#   PUSHOVER_TOKEN   - Pushover API token (optional)
#   PUSHOVER_USER    - Pushover user key (optional)
#

set -euo pipefail

MESSAGE="${1:-No message provided}"
SEVERITY="${2:-info}"  # info, warn, error

# Timestamp for logging
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Log to file
LOG_FILE="${CLAWD_HOME:-$HOME/clawd}/memory/logs/notifications.log"
mkdir -p "$(dirname "$LOG_FILE")"
echo "[$TIMESTAMP] [$SEVERITY] $MESSAGE" >> "$LOG_FILE"

# macOS notification (always works locally)
if [[ "$(uname)" == "Darwin" ]]; then
    # Choose sound based on severity
    case "$SEVERITY" in
        error)
            SOUND="Basso"
            ;;
        warn)
            SOUND="Ping"
            ;;
        *)
            SOUND="Pop"
            ;;
    esac

    osascript -e "display notification \"$MESSAGE\" with title \"Clawd [$SEVERITY]\" sound name \"$SOUND\"" 2>/dev/null || true
fi

# Discord webhook (if configured)
if [[ -n "${DISCORD_WEBHOOK:-}" ]]; then
    # Color based on severity
    case "$SEVERITY" in
        error)
            COLOR=15158332  # Red
            ;;
        warn)
            COLOR=16776960  # Yellow
            ;;
        *)
            COLOR=3066993   # Green
            ;;
    esac

    curl -s -H "Content-Type: application/json" \
         -d "{\"embeds\": [{\"title\": \"Clawd [$SEVERITY]\", \"description\": \"$MESSAGE\", \"color\": $COLOR, \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}]}" \
         "$DISCORD_WEBHOOK" > /dev/null 2>&1 || true
fi

# Pushover (for phone notifications, if configured)
if [[ -n "${PUSHOVER_TOKEN:-}" ]] && [[ -n "${PUSHOVER_USER:-}" ]]; then
    # Priority based on severity
    case "$SEVERITY" in
        error)
            PRIORITY=1
            ;;
        warn)
            PRIORITY=0
            ;;
        *)
            PRIORITY=-1
            ;;
    esac

    curl -s \
        --form-string "token=$PUSHOVER_TOKEN" \
        --form-string "user=$PUSHOVER_USER" \
        --form-string "message=$MESSAGE" \
        --form-string "title=Clawd [$SEVERITY]" \
        --form-string "priority=$PRIORITY" \
        https://api.pushover.net/1/messages.json > /dev/null 2>&1 || true
fi

# Terminal output
case "$SEVERITY" in
    error)
        echo -e "\033[0;31m[ERROR]\033[0m $MESSAGE"
        ;;
    warn)
        echo -e "\033[1;33m[WARN]\033[0m $MESSAGE"
        ;;
    *)
        echo -e "\033[0;32m[INFO]\033[0m $MESSAGE"
        ;;
esac
