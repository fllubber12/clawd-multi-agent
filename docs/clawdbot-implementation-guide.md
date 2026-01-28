# Clawdbot Implementation Guide

## Context

We have designed a 7-agent multi-agent system for autonomous overnight coding. The design is complete (see attached .md files), but we need help translating it into working Clawdbot configuration.

**Attached design documents:**
- `agents/README.md` - Team overview, decision framework, quick reference
- `agents/director.md` - Director agent specification (uses Claude Sonnet API)
- `agents/architect.md` - Architect agent specification
- `agents/scout.md` - Scout agent specification
- `agents/builder.md` - Builder agent specification
- `agents/refactorer.md` - Refactorer agent specification
- `agents/inspector.md` - Inspector agent specification
- `agents/scribe.md` - Scribe agent specification
- `pre-flight-checklist.md` - Operational checklist and configuration
- `multi-agent-operations-guide.md` - Execution patterns, scheduling, communication
- `multi-agent-failure-mitigation-guide.md` - Error handling, recovery protocols

---

## What We Need From Clawdbot

### 1. Configuration File Format

**Question:** What configuration format does Clawdbot expect for multi-agent setups?

**What we need:**
- Convert our 7 agent .md specifications into Clawdbot's native format
- Each agent needs: system prompt, model assignment, tools, timeout, priority
- Preserve the detailed behavioral instructions from our .md files

**Our agent specs include:**
```
Agent: Director
Model: claude-sonnet-4-20250514 (via Anthropic API)
Role: Coordinator, decision-maker, can spawn/halt other agents
Tools: file_read, file_write, spawn_agent, halt_agent
Timeout: 300s, Max turns: 50

Agent: Architect  
Model: qwen3:32b (via Ollama local)
Role: System designer, structural decisions
Tools: file_read, file_write
Timeout: 180s, Max turns: 20

[...and 5 more agents with similar specs]
```

---

### 2. Hybrid Model Routing

**Our setup:**
| Agent | Model | Provider |
|-------|-------|----------|
| Director | claude-sonnet-4-20250514 | Anthropic API |
| Architect | qwen3:32b | Ollama (localhost:11434) |
| Scout | qwen3:32b | Ollama (localhost:11434) |
| Builder | qwen3:32b | Ollama (localhost:11434) |
| Refactorer | qwen3:32b | Ollama (localhost:11434) |
| Inspector | qwen3:32b | Ollama (localhost:11434) |
| Scribe | qwen3:32b | Ollama (localhost:11434) |

**What we need:**
- Configure Clawdbot to route Director requests to Anthropic API
- Configure Clawdbot to route all other agent requests to local Ollama
- Environment variables: `ANTHROPIC_API_KEY` for Director, Ollama on default port for workers
- Fallback: If API fails, Director should fall back to local qwen3:32b

**Questions:**
- Does Clawdbot support per-agent model configuration?
- How do we specify different providers (API vs local) for different agents?
- Is there a fallback mechanism we can configure?

---

### 3. Orchestration Logic

**How our system should work:**

```
Director is the entry point
         │
         ▼
Director receives task from human
         │
         ▼
Director decides which agent(s) to invoke
         │
    ┌────┴────┬────────┬────────┬─────────┬──────────┐
    ▼         ▼        ▼        ▼         ▼          ▼
Architect  Scout   Builder  Refactorer Inspector  Scribe
    │         │        │        │         │          │
    └─────────┴────────┴────────┴─────────┴──────────┘
                       │
                       ▼
            Results return to Director
                       │
                       ▼
            Director decides next action
```

**What we need:**
- Director must be able to spawn/invoke other agents
- Director must be able to halt agents (loop detection, emergencies)
- Messages from workers should return to Director
- Scribe should observe all inter-agent communication for logging
- Scout should be queryable by any agent (not just Director)

**Execution phases (from our design):**
1. Planning: Sequential (Director → Architect → Scout)
2. Execution: Limited parallel (Builder + Scout can run concurrently, max 2)
3. Review: Sequential (Refactorer → Inspector → Director)
4. Iteration: Loop if needed, max 3 iterations

**Questions:**
- How does Clawdbot handle agent-to-agent communication?
- Can we implement the spawn_agent/halt_agent tools?
- Is there a built-in orchestration pattern, or do we build it custom?

---

### 4. State Management & Checkpointing

**Our design expects these files (managed by Scribe):**

```
~/clawd/memory/
├── current-state.md      # Refreshed each phase - current status
├── requirements.md       # Original task requirements (immutable)
├── decisions-log.md      # Append-only log of all decisions
├── blockers.md           # Current blockers and attempted solutions
├── technical-debt.md     # Noted issues to address later
├── checkpoints/          # JSON snapshots for crash recovery
│   └── checkpoint-{timestamp}.json
└── alerts/               # Escalations and warnings
    └── ESCALATION-{timestamp}.md
```

**Checkpoint format:**
```json
{
  "checkpoint_id": "chk-20240128-031500",
  "timestamp": "2024-01-28T03:15:00Z",
  "phase": "execution",
  "milestone": "core-api-implemented",
  "tasks": {
    "completed": ["task-1", "task-2"],
    "in_progress": ["task-3"],
    "pending": ["task-4", "task-5"]
  },
  "trust_scores": {
    "architect": 7,
    "builder": 6.5,
    "inspector": 8
  },
  "files_modified": ["src/api.py", "tests/test_api.py"],
  "test_status": {
    "passed": 12,
    "failed": 1,
    "skipped": 0
  },
  "context_summary": "Brief summary of current state..."
}
```

**What we need:**
- Directory structure created at startup
- Scribe agent has permissions to write to these locations
- Checkpoint triggers: after milestones, every 15 min if changes, on SIGTERM
- Recovery: On startup, check for latest checkpoint and offer resume

**Questions:**
- Does Clawdbot have built-in state persistence?
- How do we implement checkpoint/recovery hooks?
- Can we hook into startup/shutdown events?

---

### 5. Error Handling & Circuit Breakers

**From our failure mitigation guide, we need these safeguards:**

**Hard limits per agent:**
| Agent | Timeout | Max Turns | Max Consecutive Errors |
|-------|---------|-----------|------------------------|
| Director | 300s | 50 | 3 |
| Architect | 180s | 20 | 3 |
| Scout | 300s | 30 | 3 |
| Builder | 900s | 40 | 3 |
| Refactorer | 600s | 25 | 3 |
| Inspector | 600s | 20 | 3 |
| Scribe | 60s | 10 | 3 |

**Loop detection (Director monitors for):**
- Retry loop: Same action attempted 3+ times → force different approach
- Debate loop: Same arguments repeated → Director decides
- Perfection loop: Endless refinement of working code → declare done
- Stagnation: No file changes for 5+ turns → investigate blocker

**Circuit breaker levels:**
1. Single agent issue → Director reassigns/restarts agent
2. Coordination issue → Emergency meeting → Director mediates
3. System issue → All pause → State dump → Human summary
4. Abort → Graceful shutdown → State preserved → Human notification

**Escalation triggers (alert human):**
- 3+ failed attempts at same milestone
- Agents fundamentally disagree on requirements
- Context window >85% full
- Any agent suggests task is impossible
- Resource limits approaching

**What we need:**
- Timeout enforcement per agent
- Turn counting per agent session
- Loop detection logic (or guidance on implementing it)
- Graceful shutdown handler that saves checkpoint
- Alert mechanism (write to alerts/ directory at minimum)

**Questions:**
- Does Clawdbot have built-in timeout/turn limits?
- Is there a hook system for custom monitoring?
- How do we implement graceful shutdown with state preservation?

---

## Summary: Our Asks

1. **Show us Clawdbot's config format** and help translate our agent specs
2. **Configure hybrid routing**: Director → API, workers → Ollama
3. **Set up orchestration**: Director spawns/coordinates agents, Scribe observes
4. **Implement state management**: checkpoint files, recovery on startup
5. **Add error handling**: timeouts, loop detection, circuit breakers, alerts

---

## Environment We're Working With

- **Hardware**: 24GB M2 Mac
- **Local model**: qwen3:32b via Ollama
- **API**: Anthropic Claude Sonnet for Director
- **Runtime**: Overnight autonomous operation (8+ hours unattended)
- **Goal**: Complete coding tasks while human sleeps

---

## First Steps

Once you understand Clawdbot's capabilities, please help us:

1. Create the config files for all 7 agents
2. Set up the directory structure
3. Create a startup script that:
   - Verifies environment (API key, Ollama running)
   - Creates/loads checkpoint
   - Initializes Director with the task
4. Create a simple test task to validate the setup before overnight run

We have detailed behavioral specifications in the attached .md files - the goal is to preserve that design while making it actually executable in Clawdbot.
