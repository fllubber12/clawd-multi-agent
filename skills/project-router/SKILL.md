# Skill: Project Router

Route tasks, errors, and queries to the correct project repository.

## Configuration

All project metadata lives in `~/clawd/config/repositories.json`.

## Project Reference

| Key | Name | Path |
|-----|------|------|
| `polymarket` | Polymarket CopyTrader | ~/Projects/Polymarket_CopyTrader |
| `ygo` | YGO Combo Pipeline | ~/Desktop/testing |
| `budget` | Budget Pipeline | ~/Desktop/budget |
| `kalshi` | Kalshi Arbitrage | ~/Projects/Kalshi_Arbitrage |
| `clawd` | clawd | ~/clawd |

## Routing Logic

### By Keyword Detection

| Keywords | Route To |
|----------|----------|
| polymarket, copy trading, trader, signal, fade | `polymarket` |
| ygo, yugioh, combo, enumeration, deck, card | `ygo` |
| budget, transaction, credit karma, spending | `budget` |
| kalshi, arbitrage, cross-exchange, spread | `kalshi` |
| clawd, agent, orchestrator, taskforce | `clawd` |

### By Sentry Project Slug

Map Sentry `project_slug` to local project:
```python
SENTRY_TO_PROJECT = {
    "polymarket-copytrader": "polymarket",
    "polymarket": "polymarket",
    "ygo-combo-pipeline": "ygo",
    "ygo": "ygo",
    "budget-pipeline": "budget",
    "budget": "budget",
    "kalshi-arbitrage": "kalshi",
    "kalshi": "kalshi",
    "clawd": "clawd",
}
```

### By File Path

If error includes a file path, extract project from it:
```python
def project_from_path(filepath):
    if "Polymarket_CopyTrader" in filepath:
        return "polymarket"
    if "Desktop/testing" in filepath:
        return "ygo"
    if "Desktop/budget" in filepath:
        return "budget"
    if "Kalshi_Arbitrage" in filepath:
        return "kalshi"
    if "clawd" in filepath:
        return "clawd"
    return None
```

## Dispatching to Claude Code

### Interactive Session
```bash
# Navigate to project and start Claude Code
cd $(cat ~/clawd/config/repositories.json | jq -r ".projects.${PROJECT}.path" | sed "s|~|$HOME|")
claude
```

### Non-Interactive (with prompt)
```bash
PROJECT_PATH=$(cat ~/clawd/config/repositories.json | jq -r ".projects.${PROJECT}.path" | sed "s|~|$HOME|")
cd "$PROJECT_PATH"
claude --print "Your task: $TASK_DESCRIPTION"
```

### With Worktree (isolated fix)
```bash
# Create worktree for isolated changes
~/clawd/scripts/worktree-create.sh $PROJECT $BRANCH_NAME

# Work in worktree
cd ~/clawd/workspace/$PROJECT-$BRANCH_NAME
claude --print "Fix: $ERROR_DESCRIPTION"

# Cleanup after
~/clawd/scripts/worktree-cleanup.sh $PROJECT-$BRANCH_NAME
```

## Workflow Examples

### Example 1: Sentry Error
```
Input: Sentry alert from project "kalshi-arbitrage"
Route: kalshi
Action: ~/clawd/scripts/worktree-create.sh kalshi sentry-fix-123
```

### Example 2: User Task
```
Input: "Check the polymarket bot signal generator"
Route: polymarket
Action: cd ~/Projects/Polymarket_CopyTrader && claude
```

### Example 3: Multi-Project Status
```
Input: "What's the status of all projects?"
Route: brain
Action: Read ~/Brain/overview.md
```

## Helper Functions

### Get Project Path
```bash
get_project_path() {
    local project=$1
    jq -r ".projects.${project}.path" ~/clawd/config/repositories.json | sed "s|~|$HOME|"
}
```

### Get Test Command
```bash
get_test_command() {
    local project=$1
    jq -r ".projects.${project}.test_command" ~/clawd/config/repositories.json
}
```

### Run Tests for Project
```bash
run_project_tests() {
    local project=$1
    local path=$(get_project_path $project)
    local test_cmd=$(get_test_command $project)

    cd "$path"
    source .venv/bin/activate
    eval $test_cmd
}
```

## Error Handling

If project cannot be determined:
1. Check `~/clawd/config/repositories.json` for new mappings
2. Ask user: "Which project does this relate to?"
3. Log ambiguous routing to `~/clawd/logs/routing-unknown.log`

## Adding New Projects

1. Add entry to `~/clawd/config/repositories.json`
2. Update keyword mappings above
3. Add Sentry project mapping if applicable
4. Update `~/Brain/projects/` with project file
