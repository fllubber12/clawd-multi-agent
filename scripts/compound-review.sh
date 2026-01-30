#!/bin/bash
#
# compound-review.sh - Extract learnings from recent sessions
#
# Part of the Compound Engineering pattern:
# Plan → Work → Review → Compound → (repeat)
#
# This script runs the "Compound" phase, extracting patterns,
# decisions, and lessons from recent work to make future work easier.
#
# Usage:
#   ./scripts/compound-review.sh              # Review last 24 hours
#   ./scripts/compound-review.sh --days 7     # Review last 7 days
#   ./scripts/compound-review.sh --dry-run    # Preview without committing
#

set -euo pipefail

# Configuration
CLAWD_HOME="${CLAWD_HOME:-$HOME/clawd}"
LOGS_DIR="$CLAWD_HOME/memory/logs"
LEARNINGS_DIR="$CLAWD_HOME/memory/learnings"
TEMPLATES_FILE="$CLAWD_HOME/docs/compound-templates.md"
DAYS_BACK=1
DRY_RUN=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Extract learnings from recent session logs using Claude (Scribe agent).

Options:
  --days N        Review logs from last N days (default: 1)
  --dry-run       Preview extraction without committing changes
  --verbose       Show detailed output
  --help          Show this help message

Examples:
  $(basename "$0")                  # Review last 24 hours
  $(basename "$0") --days 7         # Review last week
  $(basename "$0") --dry-run        # Preview without committing

Environment:
  CLAWD_HOME      Base directory for clawd (default: ~/clawd)
  SCRIBE_MODEL    Ollama model for Scribe (default: qwen2.5:7b)

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --days)
            DAYS_BACK="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! -d "$CLAWD_HOME" ]]; then
    log_error "CLAWD_HOME not found: $CLAWD_HOME"
    exit 1
fi

if [[ ! -d "$LOGS_DIR" ]]; then
    log_warn "Logs directory not found, creating: $LOGS_DIR"
    mkdir -p "$LOGS_DIR"
fi

if [[ ! -d "$LEARNINGS_DIR" ]]; then
    log_warn "Learnings directory not found, creating: $LEARNINGS_DIR"
    mkdir -p "$LEARNINGS_DIR"
fi

# Find recent log files
log_info "Searching for logs from the last $DAYS_BACK day(s)..."

if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
    RECENT_LOGS=$(find "$LOGS_DIR" -name "*.md" -mtime -"$DAYS_BACK" -type f 2>/dev/null || true)
else
    # Linux
    RECENT_LOGS=$(find "$LOGS_DIR" -name "*.md" -mtime -"$DAYS_BACK" -type f 2>/dev/null || true)
fi

if [[ -z "$RECENT_LOGS" ]]; then
    log_warn "No log files found from the last $DAYS_BACK day(s)"
    log_info "Nothing to compound. Exiting."
    exit 0
fi

LOG_COUNT=$(echo "$RECENT_LOGS" | wc -l | tr -d ' ')
log_info "Found $LOG_COUNT log file(s) to review"

if $VERBOSE; then
    echo "$RECENT_LOGS" | while read -r f; do
        echo "  - $(basename "$f")"
    done
fi

# Prepare the compound review prompt
COMPOUND_PROMPT=$(cat << 'PROMPT_END'
You are Scribe, the documentation agent for clawd. Your task is to extract learnings from recent session logs.

## Your Mission

Review the provided log files and extract:
1. **Patterns** - Reusable approaches that worked well
2. **Decisions** - Choices made and their rationale  
3. **Failures/Lessons** - Bugs encountered and how they were fixed
4. **Gotchas** - Non-obvious behaviors or requirements discovered

## Templates

Use these formats:

### Pattern
```markdown
### Pattern: [Name]
**Context**: [When this applies]
**Implementation**: [Code/approach]
**Learned from**: [Source] - [Date]
```

### Decision
```markdown
### Decision: [What was decided]
**Context**: [Situation]
**Options**: [What was considered]
**Choice**: [What was picked and why]
```

### Lesson
```markdown
### Lesson: [What went wrong]
**Symptom**: [What was observed]
**Root cause**: [Actual problem]
**Fix**: [Solution]
**Prevention**: [How to avoid]
```

### Gotcha
```markdown
### Gotcha: [One-liner]
[2-3 sentence explanation]
**Applies to**: [Context]
```

## Output Instructions

1. Read all the log content provided
2. Extract learnings using the templates above
3. Group learnings by destination file:
   - Agent-specific → mention which agent file
   - Project-wide → CLAUDE.md
   - Domain-specific → memory/learnings/[topic].md
4. Output in a format that can be appended to the appropriate files

Be selective - only extract genuinely reusable learnings, not one-off fixes.

---

## Log Files to Review

PROMPT_END
)

# Collect log content
LOG_CONTENT=""
while IFS= read -r log_file; do
    if [[ -n "$log_file" && -f "$log_file" ]]; then
        LOG_CONTENT+="
### File: $(basename "$log_file")
$(cat "$log_file")

---
"
    fi
done <<< "$RECENT_LOGS"

FULL_PROMPT="$COMPOUND_PROMPT

$LOG_CONTENT"

# Create temporary file for the prompt
TEMP_PROMPT=$(mktemp)
echo "$FULL_PROMPT" > "$TEMP_PROMPT"

log_info "Running compound review with Scribe..."

if $DRY_RUN; then
    log_warn "DRY RUN - would process the following:"
    echo "---"
    echo "Prompt length: $(wc -c < "$TEMP_PROMPT") characters"
    echo "Log files: $LOG_COUNT"
    echo "---"
    
    if $VERBOSE; then
        echo "Full prompt preview (first 2000 chars):"
        head -c 2000 "$TEMP_PROMPT"
        echo "..."
    fi
    
    rm "$TEMP_PROMPT"
    exit 0
fi

# Run the compound review via Claude
# Using claude -p for Pro subscription, or fallback to Ollama Scribe
OUTPUT_FILE="$LEARNINGS_DIR/compound-$(date +%Y-%m-%d).md"

if command -v claude &> /dev/null; then
    log_info "Using Claude (claude -p) for compound review..."
    
    # Claude Code headless mode
    RESULT=$(claude -p "$(cat "$TEMP_PROMPT")" 2>&1) || {
        log_error "Claude command failed"
        rm "$TEMP_PROMPT"
        exit 1
    }
else
    log_info "Claude not found, using Ollama Scribe..."
    
    SCRIBE_MODEL="${SCRIBE_MODEL:-qwen2.5:7b}"
    
    if ! command -v ollama &> /dev/null; then
        log_error "Neither claude nor ollama found. Cannot run compound review."
        rm "$TEMP_PROMPT"
        exit 1
    fi
    
    RESULT=$(ollama run "$SCRIBE_MODEL" "$(cat "$TEMP_PROMPT")" 2>&1) || {
        log_error "Ollama command failed"
        rm "$TEMP_PROMPT"
        exit 1
    }
fi

rm "$TEMP_PROMPT"

# Save the output
cat << EOF > "$OUTPUT_FILE"
# Compound Review - $(date +%Y-%m-%d)

> Auto-generated by compound-review.sh
> Reviewed $LOG_COUNT log file(s) from the last $DAYS_BACK day(s)

---

$RESULT

---

*Generated: $(date -Iseconds)*
EOF

log_success "Learnings extracted to: $OUTPUT_FILE"

# Git commit if not dry run and in a git repo
if [[ -d "$CLAWD_HOME/.git" ]]; then
    log_info "Committing learnings to git..."
    
    cd "$CLAWD_HOME"
    git add "$OUTPUT_FILE"
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        log_info "No changes to commit"
    else
        git commit -m "compound: learnings from $(date +%Y-%m-%d)

Reviewed $LOG_COUNT log file(s) from the last $DAYS_BACK day(s).

🤖 Generated with compound-review.sh
Co-Authored-By: Claude <noreply@anthropic.com>"
        
        log_success "Committed to git"
    fi
else
    log_warn "Not a git repository, skipping commit"
fi

log_success "Compound review complete!"

# Summary
echo ""
echo "=== Summary ==="
echo "Logs reviewed: $LOG_COUNT"
echo "Output file: $OUTPUT_FILE"
echo "Date range: last $DAYS_BACK day(s)"
if [[ -d "$CLAWD_HOME/.git" ]]; then
    echo "Git status: committed"
fi
echo ""

# Hint for next steps
log_info "Next: Review $OUTPUT_FILE and distribute learnings to appropriate agent files"
