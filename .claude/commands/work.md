# /work - Dispatch Task to Project

Route a task to the appropriate project repository.

## Usage

```
/work <project> <task description>
/work polymarket check the signal generator
/work ygo fix the combo enumeration bug
```

## Instructions

1. Parse the project name from the first argument
2. Look up the project path in `~/clawd/config/repositories.json`
3. Change to the project directory
4. Execute the task

## Project Keys

- `polymarket` - Polymarket CopyTrader
- `ygo` - YGO Combo Pipeline
- `budget` - Budget Pipeline
- `kalshi` - Kalshi Arbitrage
- `clawd` - clawd system

## Routing Logic

```bash
# Get project path
PROJECT_PATH=$(jq -r ".projects.$PROJECT.path" ~/clawd/config/repositories.json | sed "s|~|$HOME|")

# Verify it exists
if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "Project not found: $PROJECT"
    exit 1
fi

# Change to project and work
cd "$PROJECT_PATH"
```

## Before Starting Work

1. Read the project's CLAUDE.md if it exists
2. Check git status for context
3. Activate venv if Python project
