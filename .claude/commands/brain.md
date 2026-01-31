# /brain - Quick Brain Overview

Get a quick overview from the Brain repository.

## Instructions

1. Read `~/Brain/overview.md` for high-level status
2. Check `~/Brain/projects/` for project-specific files
3. Summarize what's active and what needs attention

## Key Files

- `~/Brain/overview.md` - Main overview
- `~/Brain/projects/*.md` - Per-project status
- `~/Brain/decisions/` - Important decisions log

## Output Format

Provide a concise summary:
- Active projects and their current status
- Recent changes or decisions
- Any flagged issues or blockers
- Upcoming tasks or deadlines

## Commands

```bash
# Main overview
cat ~/Brain/overview.md

# List project files
ls ~/Brain/projects/

# Recent changes
ls -lt ~/Brain/projects/ | head -5
```
