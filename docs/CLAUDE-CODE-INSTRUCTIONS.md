# Instructions for Claude Code

## How to Use This Package

You're picking up an ongoing project. Here's how to get oriented:

### 1. Read Order (5-10 minutes)
```
1. README.md                    ← You are here (overview)
2. SESSION-HISTORY.md           ← What happened before
3. HARDWARE-CONFIG.md           ← Current constraints
4. NEXT-STEPS.md                ← What to do next
```

### 2. Reference Materials (as needed)
```
clawdbot-implementation-guide.md   ← For Clawdbot wiring
pre-flight-checklist.md            ← Before any run
agents/*.md                        ← Individual agent specs
```

### 3. Deep Context (if needed)
```
/mnt/transcripts/2026-01-28-*.txt  ← Full conversation transcripts
```

---

## What Zach Will Likely Ask

### "Help me set up the PC after parts arrive"
→ Follow `HARDWARE-CONFIG.md` and `NEXT-STEPS.md` Phase 1
→ Key: Check PSU wattage FIRST

### "Configure Clawdbot with these agents"
→ Use `clawdbot-implementation-guide.md`
→ Agent specs in `agents/*.md`
→ Key: Director uses Claude API, workers use Ollama

### "Run the pre-flight checklist"
→ Follow `pre-flight-checklist.md` exactly
→ 35 minutes total
→ Don't skip smoke tests

### "Start the first overnight run"
→ Use task template in `NEXT-STEPS.md` Phase 4
→ Suggested first task: Fix A Bao A Qu Link Summon bug
→ Ensure all pre-flight passed

### "Review what happened overnight"
→ Morning review checklist in `NEXT-STEPS.md`
→ Check alerts first
→ Verify tests pass before trusting "complete"

---

## Critical Things to Remember

### 1. Hardware Constraints
- Mac: 24GB unified, but only ~5GB free after macOS
- PC (post-upgrade): 12GB dedicated VRAM
- qwen3:14b works, qwen3:32b does NOT

### 2. Model Configuration
```yaml
# Director (Claude Sonnet API)
model: claude-sonnet-4-20250514
# Access via: ANTHROPIC_API_KEY env var

# Workers (Ollama local)
model: qwen3:14b
# Access via: http://localhost:11434
# Params: temp 0.25-0.7, top_p 0.8-0.9
# IMPORTANT: Strip <think>...</think> from history
```

### 3. Execution Rules
- DEFAULT to sequential execution
- Only parallelize if: different files, no dependencies, independent
- Checkpoint every 5 turns
- Max 3 iterations before escalation

### 4. Safety Checks
- Director monitors for prompt injection between agents
- Never summarize errors as successes
- Morning review: check for hardcoded creds, SQL injection, etc.

---

## If You're Missing Context

### Design decisions explained in:
- `team-role-analysis.md` → Why these roles
- `multi-agent-research.md` → Industry patterns
- `SESSION-HISTORY.md` → Decision rationale

### Operational details in:
- `multi-agent-operations-guide.md` → Parameters, protocols
- `multi-agent-failure-mitigation-guide.md` → Error handling
- `pre-flight-checklist.md` → Validation steps

### Full conversation history:
```bash
# View transcript files
ls /mnt/transcripts/2026-01-28-*.txt

# Read specific session
cat /mnt/transcripts/2026-01-28-00-25-44-multi-agent-decision-framework-implementation.txt
```

---

## Quick Command Reference

### Ollama
```bash
ollama pull qwen3:14b          # Download model
ollama run qwen3:14b "test"    # Interactive test
ollama list                     # Show installed models
ollama ps                       # Show running models
nvidia-smi                      # Check GPU VRAM usage (Windows/Linux)
```

### API Test
```bash
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "content-type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"claude-sonnet-4-20250514","max_tokens":50,"messages":[{"role":"user","content":"test"}]}'
```

### Git (for overnight tasks)
```bash
git checkout -b fix/task-name   # New branch for task
git status                      # Check clean state
git diff main                   # Review changes
```

---

## Success Criteria for This Project

The system works when:
1. ✅ PC hardware installed and Ollama running
2. ✅ Clawdbot configured with all 7 agents
3. ✅ Pre-flight checklist passes
4. ✅ First overnight run completes task
5. ✅ Morning review shows working code + passing tests

Take it step by step. Don't rush the hardware setup or skip the pre-flight.
