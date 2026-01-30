# Clawd Handoff Summary

**Date**: January 30, 2026
**Session**: Full system prep + Clawdbot security hardening

---

## What Clawd Is

A two-layer AI system:
- **Layer 1**: Personal AI assistant via Clawdbot (Telegram @zachs_molty_bot)
- **Layer 2**: 7-agent autonomous coding taskforce for overnight runs

**Architecture**: Director (Claude API) orchestrates 6 local workers (Ollama on PC).

---

## Current State: Ready for PC

All Mac-side prep is complete. Waiting for PC hardware (RTX 3060 12GB + 32GB RAM).

### What's Built

| Component | Status | Location |
|-----------|--------|----------|
| Orchestrator | ✅ Complete | `scripts/orchestrator.py` |
| Agent prompts (lean) | ✅ Complete | `agents/*.md` |
| Skills (6 total) | ✅ Complete | `skills/*/SKILL.md` |
| Compound review | ✅ Complete | `scripts/compound-review.sh` |
| Notifications | ✅ Complete | `scripts/notify.sh` |
| Morning summary | ✅ Complete | `scripts/morning-summary.sh` |
| PC setup script | ✅ Complete | `setup/pc-first-boot-setup.sh` |
| qmd (memory search) | ✅ Installed | `clawd-memory` collection indexed |
| qmd skill wrapper | ✅ Complete | `skills/qmd/SKILL.md` |
| launchd plists | ✅ Ready | `launchd/*.plist` |
| Clawdbot security | ✅ Complete | `setup/clawdbot-secure-*` |
| Docker sandbox | ✅ Built | `clawdbot-sandbox:bookworm-slim` |

### Key Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Worker model | `qwen-coder-16k` (7B) | Fits RTX 3060 12GB, 25-37 t/s |
| Context length | 16K tokens | Balance of capability vs VRAM |
| Thinking mode | Disabled | 7B models don't benefit |
| Orchestration | DIY Python | Frameworks don't fit hybrid model setup |

### Model Change

**Old**: qwen3:32b (won't fit 12GB VRAM)
**New**: qwen2.5-coder:7b with 16K context variant (`qwen-coder-16k`)

---

## Clawdbot (Layer 1) Status

Personal AI assistant running on Mac via Telegram.

| Setting | Value |
|---------|-------|
| Bot | @zachs_molty_bot |
| Model | `anthropic/claude-haiku-4.5` (was Gemini Free) |
| Sandbox | `mode: all` (everything in Docker) |
| Elevated tools | Disabled |
| Telegram | Allowlist only (user 8392043810) |
| Groups | Denied |

**Security hardened:**
- Built `clawdbot-sandbox:bookworm-slim` Docker image
- Sandbox isolates all exec in containers
- No host escape possible (elevated disabled)

**Restart command:** `clawdbot gateway restart`

---

## Files to Know

```
~/clawd/
├── CLAUDE.md                    # Project overview, conventions
├── docs/clawd-research-hub.md   # Full research synthesis (models, patterns, qmd)
├── scripts/
│   ├── orchestrator.py          # Core loop (Director → Workers)
│   ├── call-agent.sh            # Worker invocation
│   ├── compound-review.sh       # Nightly learning extraction
│   ├── notify.sh                # Notifications
│   └── morning-summary.sh       # Overnight run summary
├── setup/
│   ├── pc-first-boot-setup.sh   # Run this on PC first
│   ├── clawd-env.sh             # Environment to source
│   ├── Modelfile.qwen-coder-16k # 16K context model definition
│   ├── clawdbot-secure-config.json      # Hardened clawdbot config
│   └── clawdbot-secure-setup-instructions.md
├── agents/
│   ├── director.md              # Full prompt with decision format
│   └── *.md                     # Lean worker prompts
├── skills/                      # Progressive disclosure workflows
│   ├── qmd/SKILL.md             # Memory search skill
│   ├── debugging/SKILL.md
│   ├── documenting/SKILL.md
│   ├── implementing/SKILL.md
│   ├── refactoring/SKILL.md
│   └── testing/SKILL.md
└── memory/
    ├── smoke-test-task.md       # Trivial first test
    └── first-task.md            # A Bao A Qu debug task
```

---

## When PC Arrives

```bash
# 1. Clone repo
git clone https://github.com/fllubber12/clawd-multi-agent ~/clawd

# 2. Run setup (installs Ollama, creates model, sets env)
chmod +x ~/clawd/setup/pc-first-boot-setup.sh
~/clawd/setup/pc-first-boot-setup.sh

# 3. Source environment
source ~/clawd/setup/clawd-env.sh

# 4. Test worker
./scripts/call-agent.sh builder "print hello world in python"

# 5. Run smoke test (set ANTHROPIC_API_KEY first)
export ANTHROPIC_API_KEY="sk-ant-..."
python3 scripts/orchestrator.py memory/smoke-test-task.md

# 6. If smoke test passes, run real task
python3 scripts/orchestrator.py memory/first-task.md
```

---

## Environment Variables

```bash
# Required
export ANTHROPIC_API_KEY="sk-ant-..."  # For Director

# Set by clawd-env.sh
export CLAWD_MODEL="qwen-coder-16k"
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_CONTEXT_LENGTH=16384
export OLLAMA_KEEP_ALIVE=24h
export CLAWD_HOME="$HOME/clawd"
```

---

## What's NOT Done (Future Work)

| Item | Priority | Notes |
|------|----------|-------|
| Full overnight run test | High | Need PC first |
| Rate limit handling | Medium | Add exponential backoff to orchestrator |
| Director API fallback | Low | Falls back to local model if API fails |
| Threat model doc | Low | Document security boundaries |
| launchd installation | Low | Copy plists to ~/Library/LaunchAgents |

---

## Recent Git History

```
ef92ecf feat(skills): add qmd markdown search skill for clawd-memory collection
5313308 Add clawdbot security config and setup instructions
851aa5a docs: Add handoff summary for PC hardware arrival
ba24f5c Add PC setup scripts, update call-agent.sh for qwen-coder-16k
98cf81c Add notifications, session logging, and input sanitization
7fdf5a0 docs: Update research hub with Ollama context, qmd, observability
```

---

## Quick Commands

```bash
# Test notification
./scripts/notify.sh "Test message" info

# Search memory
~/.bun/bin/qmd search "A Bao A Qu" -c clawd-memory

# Dry run compound review
./scripts/compound-review.sh --dry-run --verbose

# Run orchestrator
python3 scripts/orchestrator.py memory/smoke-test-task.md

# Resume from checkpoint
python3 scripts/orchestrator.py --resume
```

---

## Contacts / Resources

- **Repo**: https://github.com/fllubber12/clawd-multi-agent
- **Research**: `docs/clawd-research-hub.md` (comprehensive)
- **Pre-flight checklist**: `docs/pre-flight-checklist.md`

---

*Handoff updated: 2026-01-30 (added Clawdbot security, qmd skill)*
