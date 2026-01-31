# /status - Check All Projects

Check the status of all monitored projects.

## Instructions

1. Read the repository config: `~/clawd/config/repositories.json`
2. For each project, check:
   - Git status (uncommitted changes, branch)
   - Recent commits (last 3)
   - Sentry errors (if webhook logs exist)
3. Summarize in a table format

## Output Format

| Project | Branch | Status | Last Commit | Sentry |
|---------|--------|--------|-------------|--------|
| polymarket | main | clean | 2h ago: fix signal... | 0 new |
| ygo | main | 2 modified | 1d ago: add... | 1 new |
...

## Commands to Run

```bash
# Get project paths
cat ~/clawd/config/repositories.json | jq -r '.projects | to_entries[] | "\(.key):\(.value.path)"'

# For each project:
cd <path> && git status --short && git log --oneline -3

# Check Sentry logs
ls -t ~/clawd/logs/sentry-webhooks/*.json 2>/dev/null | head -5
```
