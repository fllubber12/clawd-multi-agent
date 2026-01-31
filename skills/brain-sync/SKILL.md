# Skill: Brain Sync

Keep the Brain repo (`~/Brain`) updated with session progress and project state.

## Purpose

The Brain is Zach's central knowledge hub. It should always reflect:
- Current project status
- Recent decisions and their rationale
- What's working, what's blocked
- Next steps for each project

## When to Update Brain

### Automatic Triggers
- End of significant work session
- Major milestone completed
- Important decision made
- Project status changed (blocked → unblocked, etc.)
- New feature or fix deployed

### Manual Triggers
- User says "update brain"
- User says "sync brain"
- User says "record this in brain"

## What to Update

### 1. overview.md (always check)
Location: `~/Brain/overview.md`

Update when:
- Project status changes (health, last touched)
- Focus shifts to different project
- Weekly goals completed or changed
- Timeline events pass

Fields to update:
```markdown
Last updated: [today's date]

| Project | Status | Health | Last Touched | Next Action |
```

### 2. Project Files
Location: `~/Brain/projects/[project].md`

Update when:
- Significant work done on project
- New features added
- Bugs fixed
- Architecture changed
- Blockers discovered or resolved

Sections to update:
- Current Status (phase, health, last touched)
- What's Working / What's Not
- Next Steps
- Context for Work Sessions

### 3. Decisions Log
Location: `~/Brain/decisions/log.md`

Update when:
- Architectural decision made
- Tool/library choice made
- Approach changed
- Trade-off evaluated

Format:
```markdown
## [Date] - [Decision Title]

**Context**: Why this decision was needed
**Options Considered**: What alternatives existed
**Decision**: What was chosen
**Rationale**: Why this option
**Consequences**: What this enables/prevents
```

### 4. Infrastructure Docs
Location: `~/Brain/infrastructure/`

Update when:
- New service deployed
- Configuration changed
- New integration added

## Sync Workflow

```bash
# 1. Read current state
cat ~/Brain/overview.md

# 2. Identify what changed this session
# - What project(s) were worked on?
# - What was accomplished?
# - Any decisions made?
# - Any status changes?

# 3. Update relevant files
# - overview.md (always)
# - projects/[relevant].md
# - decisions/log.md (if decisions made)

# 4. Commit changes
cd ~/Brain
git add -A
git commit -m "docs: Update [project] status - [summary]"
git push
```

## Example Updates

### After Completing a Feature
```markdown
# In overview.md
| Budget Pipeline | Functional | 🟢 | Jan 31 | Phase 1 complete |

# In projects/budget-pipeline.md
## Current Status
- **Phase**: Phase 1 Complete
- **Last Touched**: Jan 31, 2026
- **Health**: 🟢 Good

## What's Working
- ETL pipeline processing 187 transactions
- Category overrides applied correctly
- Sentry monitoring active
```

### After Making a Decision
```markdown
# In decisions/log.md
## Jan 31, 2026 - Use ngrok for Sentry webhooks

**Context**: Need external URL for Sentry to send webhooks to local handler
**Options**: ngrok, Tailscale Funnel, VPS, Cloudflare Tunnel
**Decision**: ngrok with free static domain
**Rationale**: Already had account, free tier includes 1 static domain
**Consequences**: URL persists across restarts, launchd service handles auto-start
```

### After Hitting a Blocker
```markdown
# In overview.md
| Yu-Gi-Oh Engine | Blocked on clawd | 🟡 | Jan 31 | A Bao A Qu bug |

# In projects/yugioh-engine.md
## Current Status
- **Health**: 🟡 Needs Attention (blocked)

## Blockers
- A Bao A Qu Link Summon never occurs at depth 25
- Waiting for clawd taskforce to debug
```

## Commit Message Format

```
docs: Update [project] - [brief summary]

Examples:
- docs: Update polymarket status - trader roster fixed
- docs: Add kalshi-arbitrage to Brain
- docs: Update overview - Sentry pipeline complete
- docs: Record webhook architecture decision
```

## Reminders

- **Don't over-update**: Only update when meaningful changes occur
- **Keep it current**: Stale Brain is worse than no Brain
- **Preserve rationale**: Always explain WHY, not just WHAT
- **Commit often**: Small, frequent updates > big batches
