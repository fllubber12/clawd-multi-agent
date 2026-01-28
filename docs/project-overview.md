# Multi-Agent Autonomous Coding Pipeline - Handoff Package

## Quick Context for Claude Code

You're continuing work on **Zach's multi-agent autonomous coding system** designed to run overnight while he sleeps. This package contains everything you need to implement and configure the system.

**Current Status**: Design phase COMPLETE. Implementation phase READY TO BEGIN.

---

## Project Goal

Build a 7-agent autonomous coding pipeline that can:
1. Take a defined task (e.g., debug the ygo-combo-pipeline)
2. Work autonomously overnight (8+ hours)
3. Produce working, tested code by morning
4. Recover gracefully from failures
5. Know when to stop and ask for human help

---

## Architecture Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                         DIRECTOR                                │
│                    (Claude Sonnet API)                          │
│              Decision-maker, Orchestrator                       │
└─────────────────────────┬───────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│   ARCHITECT   │ │    SCOUT      │ │    SCRIBE     │
│   (qwen3:14b) │ │  (qwen3:14b)  │ │  (qwen3:14b)  │
│   Structure   │ │   Research    │ │ Documentation │
└───────────────┘ └───────────────┘ └───────────────┘
        │
        ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│    BUILDER    │ │  REFACTORER   │ │   INSPECTOR   │
│   (qwen3:14b) │ │  (qwen3:14b)  │ │  (qwen3:14b)  │
│Implementation │ │   Cleanup     │ │    Testing    │
└───────────────┘ └───────────────┘ └───────────────┘
```

### Hybrid Model Configuration

| Agent | Model | Why |
|-------|-------|-----|
| **Director** | Claude Sonnet (API) | Superior judgment, different perspective catches blindspots |
| **Workers (6)** | qwen3:14b (Ollama local) | Heavy token generation, zero marginal cost |

---

## Hardware Configuration

### CURRENT: Mac (24GB M2)
- Can run qwen3:14b (not 32b - memory constraints)
- macOS uses ~19GB baseline, leaving ~5GB free
- **Limitation**: Must close heavy apps before runs

### PLANNED: PC Upgrade (In Progress)
Zach is purchasing:
- **ASUS RTX 3060 12GB** ($349.99)
- **Corsair Vengeance 32GB DDR4** ($259.99)

Once installed, the PC becomes primary:
- qwen3:14b runs in 12GB VRAM (fast, dedicated)
- Mac monitors via Telegram
- PC does all compute

**Pre-installation check needed**: Verify PSU ≥550W

---

## Files You Have

### Guides (read these first)
| File | Purpose |
|------|---------|
| `clawdbot-implementation-guide.md` | **START HERE** - How to wire this into Clawdbot |
| `multi-agent-operations-guide.md` | Operational parameters, resource allocation |
| `multi-agent-failure-mitigation-guide.md` | What can go wrong and how to handle it |
| `pre-flight-checklist.md` | Validation before overnight runs |

### Agent Definitions
| File | Role |
|------|------|
| `agents/README.md` | Overview + hybrid model config table |
| `agents/director.md` | Orchestrator (Claude Sonnet API) |
| `agents/architect.md` | System design |
| `agents/scout.md` | Research & information gathering |
| `agents/builder.md` | Code implementation |
| `agents/refactorer.md` | Code cleanup |
| `agents/inspector.md` | Testing & verification |
| `agents/scribe.md` | Documentation & state management |

### Research (background context)
| File | Contents |
|------|----------|
| `multi-agent-research.md` | Initial research on patterns |
| `team-role-analysis.md` | Role design rationale |
| `ollama-clawdbot-diagnostics.md` | Troubleshooting notes |

---

## Immediate Next Steps

### 1. Hardware Setup (When PC parts arrive)
```bash
# On PC:
# 1. Install RTX 3060 (check PSU first!)
# 2. Install 32GB RAM (replace existing)
# 3. Install Windows Ollama: https://ollama.com/download/windows
# 4. Pull model:
ollama pull qwen3:14b
ollama run qwen3:14b "Hello, confirm you're working"
```

### 2. Configure Clawdbot
See `clawdbot-implementation-guide.md` for detailed instructions:
- Config file format translation
- Hybrid model routing (Director → API, workers → Ollama)
- Orchestration logic
- State management
- Error handling

### 3. Run Pre-Flight Checklist
Before any overnight run, execute full `pre-flight-checklist.md`:
- Infrastructure validation (35 min)
- Smoke tests
- API key verification

### 4. Define First Task
Use the task template from pre-flight checklist. Suggested first task:

```markdown
## Task: Fix A Bao A Qu Link Summon Failure

**Objective**: Debug why step 17 fails in ygo-combo-pipeline

**Success Criteria**:
- [ ] Identify root cause of Link Summon failure
- [ ] Implement fix
- [ ] All 237 existing tests still pass
- [ ] New test covers the fixed scenario

**Scope Boundaries**:
- DO: Fix this specific bug
- DO NOT: Refactor unrelated code
- DO NOT: Add new features

**Abort Conditions**:
- If requires changes to ygopro-core itself
- If > 3 files need modification
```

---

## Key Configuration Values

### Environment Variables
```bash
# For Director (Claude API)
export ANTHROPIC_API_KEY="sk-ant-..."

# For Workers (Ollama)
export OLLAMA_HOST="http://localhost:11434"  # or PC IP if remote
export OLLAMA_NUM_PARALLEL=2
export OLLAMA_KEEP_ALIVE=60m
export OLLAMA_MAX_QUEUE=100
```

### Model Parameters (qwen3:14b)
```yaml
temperature: 0.25-0.7
top_p: 0.8-0.9
top_k: 20-40
repetition_penalty: 1.05
# Strip <think>...</think> blocks from history to prevent context bloat
```

### Timeouts & Limits
```yaml
agent_timeout: 300s (5 min per turn)
max_turns_per_agent: 50
checkpoint_interval: 5 turns
max_iterations_before_escalation: 3
```

---

## Critical Reminders

1. **Prompt Injection Risk**: Agents can accidentally inject meta-instructions. Director must monitor for this.

2. **Ollama Stability**: May need watchdog script for restarts after ~30min.

3. **Sequential Default**: Don't parallelize agents unless tasks are truly independent.

4. **Context Poisoning**: Never summarize errors as successes. Keep code snippets verbatim.

5. **Morning Review**: Always check alerts, verify tests pass, review for security issues.

---

## Transcript History

Full conversation history preserved in:
```
/mnt/transcripts/2026-01-28-00-00-22-multi-agent-team-role-research.txt
/mnt/transcripts/2026-01-28-00-03-59-multi-agent-orchestration-operations.txt
/mnt/transcripts/2026-01-28-00-25-44-multi-agent-decision-framework-implementation.txt
/mnt/transcripts/2026-01-28-17-25-25-multi-agent-pipeline-final-research-and-setup.txt
```

---

## Questions? Missing Context?

If you need clarification on any design decision, the rationale is in the transcripts or guide files. Key decisions documented:

- Why 7 agents? → `team-role-analysis.md`
- Why hybrid models? → Research showed different models catch each other's blindspots
- Why qwen3:14b not 32b? → Mac memory constraints (19GB baseline usage)
- Why sequential over parallel? → Anthropic research shows parallel agents contradict each other
