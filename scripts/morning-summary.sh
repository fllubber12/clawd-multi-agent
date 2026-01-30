#!/bin/bash
#
# morning-summary.sh - Generate and send morning summary of overnight run
#
# Usage:
#   ./scripts/morning-summary.sh              # Summarize last night
#   ./scripts/morning-summary.sh 2026-01-30   # Summarize specific date
#
# Typically scheduled via launchd to run at 8:00 AM
#

set -euo pipefail

CLAWD_HOME="${CLAWD_HOME:-$HOME/clawd}"
SCRIPTS_DIR="$CLAWD_HOME/scripts"
LOGS_DIR="$CLAWD_HOME/memory/logs"
CHECKPOINTS_DIR="$CLAWD_HOME/memory/checkpoints"
LEARNINGS_DIR="$CLAWD_HOME/memory/learnings"

# Date to summarize (default: today, which covers last night's run)
TARGET_DATE="${1:-$(date +%Y-%m-%d)}"

# Find relevant log files
ORCHESTRATOR_LOG="$LOGS_DIR/orchestrator-${TARGET_DATE//-/}.log"
EVENTS_LOG="$LOGS_DIR/events-${TARGET_DATE//-/}.jsonl"
COMPOUND_LOG="$LEARNINGS_DIR/compound-$TARGET_DATE.md"

echo "=== Clawd Morning Summary for $TARGET_DATE ==="
echo ""

# Check if overnight run happened
if [[ ! -f "$ORCHESTRATOR_LOG" ]] && [[ ! -f "$EVENTS_LOG" ]]; then
    "$SCRIPTS_DIR/notify.sh" "No overnight run detected for $TARGET_DATE" "warn"
    echo "No orchestrator logs found for $TARGET_DATE"
    echo "The overnight run may not have started."
    exit 0
fi

# Initialize counters
TASKS_COMPLETED=0
TASKS_ESCALATED=0
TASKS_HALTED=0
ERRORS=0
TURNS=0

# Parse orchestrator log if exists
if [[ -f "$ORCHESTRATOR_LOG" ]]; then
    TASKS_COMPLETED=$(grep -c "Task completed\|status: complete" "$ORCHESTRATOR_LOG" 2>/dev/null || echo 0)
    TASKS_ESCALATED=$(grep -c "ESCALATE\|status: escalated" "$ORCHESTRATOR_LOG" 2>/dev/null || echo 0)
    TASKS_HALTED=$(grep -c "HALT\|status: halted" "$ORCHESTRATOR_LOG" 2>/dev/null || echo 0)
    ERRORS=$(grep -c "\[ERROR\]" "$ORCHESTRATOR_LOG" 2>/dev/null || echo 0)
    TURNS=$(grep -c "Calling Director\|Director decision" "$ORCHESTRATOR_LOG" 2>/dev/null || echo 0)
fi

# Parse events log if exists (JSONL format)
if [[ -f "$EVENTS_LOG" ]]; then
    # Count events by type
    WORKER_CALLS=$(grep -c '"type":"worker_call"' "$EVENTS_LOG" 2>/dev/null || echo 0)
    CHECKPOINTS=$(grep -c '"type":"checkpoint"' "$EVENTS_LOG" 2>/dev/null || echo 0)
fi

# Check for new compound learnings
LEARNINGS_ADDED=0
if [[ -f "$COMPOUND_LOG" ]]; then
    LEARNINGS_ADDED=$(grep -c "^### " "$COMPOUND_LOG" 2>/dev/null || echo 0)
fi

# Count checkpoints created
CHECKPOINTS_TODAY=$(find "$CHECKPOINTS_DIR" -name "*$TARGET_DATE*" -type f 2>/dev/null | wc -l | tr -d ' ')

# Build summary
SUMMARY="Overnight Run Summary ($TARGET_DATE):

Tasks:
- Completed: $TASKS_COMPLETED
- Escalated: $TASKS_ESCALATED
- Halted: $TASKS_HALTED

Activity:
- Director turns: $TURNS
- Worker calls: ${WORKER_CALLS:-N/A}
- Checkpoints: $CHECKPOINTS_TODAY
- Errors: $ERRORS

Compound Learning:
- Learnings extracted: $LEARNINGS_ADDED"

echo "$SUMMARY"
echo ""

# Determine overall status and severity
if [[ $TASKS_ESCALATED -gt 0 ]]; then
    STATUS="needs attention"
    SEVERITY="warn"
elif [[ $ERRORS -gt 3 ]]; then
    STATUS="had issues"
    SEVERITY="warn"
elif [[ $TASKS_COMPLETED -gt 0 ]]; then
    STATUS="successful"
    SEVERITY="info"
else
    STATUS="no tasks run"
    SEVERITY="info"
fi

# Send notification
SHORT_SUMMARY="Overnight: $TASKS_COMPLETED completed, $TASKS_ESCALATED escalated, $ERRORS errors"
"$SCRIPTS_DIR/notify.sh" "$SHORT_SUMMARY" "$SEVERITY"

# Show any escalations that need attention
if [[ $TASKS_ESCALATED -gt 0 ]]; then
    echo "=== Escalations Requiring Attention ==="
    grep -A 5 "ESCALATE\|escalate" "$ORCHESTRATOR_LOG" 2>/dev/null | head -30 || true
    echo ""
fi

# Show errors if any
if [[ $ERRORS -gt 0 ]]; then
    echo "=== Errors (last 10) ==="
    grep "\[ERROR\]" "$ORCHESTRATOR_LOG" 2>/dev/null | tail -10 || true
    echo ""
fi

# Point to full logs
echo "=== Full Logs ==="
echo "Orchestrator: $ORCHESTRATOR_LOG"
echo "Events: $EVENTS_LOG"
echo "Compound: $COMPOUND_LOG"
echo ""

# Save summary to file
SUMMARY_FILE="$LOGS_DIR/summary-$TARGET_DATE.md"
cat > "$SUMMARY_FILE" << EOF
# Morning Summary - $TARGET_DATE

## Status: $STATUS

$SUMMARY

---

*Generated: $(date -Iseconds)*
EOF

echo "Summary saved to: $SUMMARY_FILE"
