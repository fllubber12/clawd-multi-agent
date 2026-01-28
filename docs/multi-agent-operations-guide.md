# Multi-Agent Operations Guide
## Resource Allocation, Scheduling, Communication & Emergency Protocols

---

## Executive Summary

Based on deep research into multi-agent LLM orchestration patterns, here's everything you need to configure your 7-agent team for overnight autonomous operation.

### Model Configuration (Hybrid Setup)

| Agent | Model | Provider | Purpose |
|-------|-------|----------|---------|
| **Director** | Claude Sonnet | Anthropic API | Coordination, arbitration, superior judgment |
| **Workers** (6) | qwen3:32b | Ollama (local) | Code generation, research, verification |

This hybrid approach provides differentiated perspective (Director catches blindspots workers share) while keeping token-heavy work local at zero marginal cost.

---

## 1. Resource Allocation: RAM & Model Loading

### The Core Question: Does Each Agent Get Its Own Model Instance?

**For local workers (6 agents): No.** With Ollama running locally, all worker agents share the same qwen3:32b instance.

**For Director: Separate.** Director uses Claude Sonnet via API, independent of local resources.

### How Ollama Memory Works (Worker Agents)

From Ollama's documentation and behavior:

| Setting | Default | Description |
|---------|---------|-------------|
| `OLLAMA_MAX_LOADED_MODELS` | 3 × GPU count (or 3 for CPU) | Maximum models in memory simultaneously |
| `OLLAMA_NUM_PARALLEL` | 4 (or 1 if low memory) | Parallel requests per loaded model |
| `OLLAMA_KEEP_ALIVE` | 5 minutes | How long idle models stay loaded |
| `OLLAMA_MAX_QUEUE` | 512 | Maximum queued requests before 503 errors |

### For qwen3:32b on 24GB M2

```
Model size: ~19GB quantized
Remaining for KV cache: ~5GB
Realistic parallel requests: 2-4 concurrent
```

**Key insight:** Worker agents share ONE local model instance that handles requests sequentially or with limited parallelism. Director runs independently via API.

### Recommendation for Your Setup

**Director (Claude Sonnet API):**
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
# Director configuration in agent definition handles the rest
```

**Workers (Ollama local):**
```bash
# Set these environment variables before starting Ollama
export OLLAMA_NUM_PARALLEL=2        # Conservative for 24GB
export OLLAMA_KEEP_ALIVE=60m        # Keep model loaded during overnight run
export OLLAMA_MAX_QUEUE=100         # Reasonable queue depth
```

**Why `OLLAMA_NUM_PARALLEL=2`?**
- Each parallel request increases KV cache memory
- With 32B model on 24GB, 2 parallel is safe
- More parallel = faster throughput but risk OOM

---

## 2. Execution Model: Sequential vs Parallel vs Hybrid

### Research Findings on Scheduling Patterns

| Pattern | Best For | Latency | Cost | Risk |
|---------|----------|---------|------|------|
| **Fully Sequential** | Dependent tasks | High | Low | Low (predictable) |
| **Fully Parallel** | Independent tasks | Low | High | Medium (coordination) |
| **Hybrid (Recommended)** | Mixed workflows | Medium | Medium | Managed |

### What Research Says

From Google's ADK documentation and M1-Parallel paper:
> "Parallel agents with early termination achieves up to 2.2× speedup while preserving accuracy"

But from the MAST failure analysis:
> "Having multiple agents communicate freely without a clear plan can lead to confusion and make it unclear who's responsible for what"

### Recommended Execution Model for Your Team

```
Phase-Based Hybrid Execution
============================

PHASE 1: Planning (Sequential)
─────────────────────────────
Director → Architect → Scout (research)
                              ↓
                        Planning complete

PHASE 2: Execution (Limited Parallel)
─────────────────────────────────────
┌─────────────┐   ┌─────────────┐
│   Builder   │   │   Scout     │
│ (implement) │   │ (research)  │
└──────┬──────┘   └──────┬──────┘
       │                 │
       └────────┬────────┘
                ↓
          Scribe (checkpoint)

PHASE 3: Review (Sequential)
───────────────────────────
Refactorer → Inspector → Director (verify)

PHASE 4: Iteration (if needed)
─────────────────────────────
Loop back to Phase 2 or 3
```

### Clawdbot Configuration

Based on the Clawdbot documentation from your transcript:

```json
{
  "agents": {
    "defaults": {
      "subagents": {
        "maxConcurrent": 2,
        "archiveAfterMinutes": 120,
        "runTimeoutSeconds": 600
      }
    }
  }
}
```

**Why `maxConcurrent: 2`?**
- Matches `OLLAMA_NUM_PARALLEL=2`
- Prevents queue buildup
- Allows Builder + Scout to work simultaneously
- Director always needs bandwidth to intervene

---

## 3. Meeting & Synchronization Patterns

### Research on Debate Rounds and Convergence

From MIT's multi-agent debate research:
> "Performance improves as the number of rounds of underlying debate increases... However, additional debate rounds above four led to similar final results"

From NeurIPS evaluation:
> "Simple majority voting tends to account for much of the empirical gain historically attributed to debate"

### Key Finding: 1-2 Rounds is Usually Sufficient

The research consensus:
- **Round 0:** Initial proposals (independent work)
- **Round 1:** Review and critique (most gains happen here)
- **Round 2+:** Diminishing returns unless high-stakes decision

### Meeting Types for Your Team

#### 1. Scheduled Checkpoints (Regular Meetings)

```markdown
## Checkpoint Protocol

FREQUENCY: After each major milestone (not time-based)

TRIGGER CONDITIONS:
- Builder completes a component
- Scout finishes research phase
- Inspector finds significant issues
- Phase transition

ATTENDEES: All agents (via shared state)

AGENDA:
1. Scribe reads current state summary
2. Each agent reports status (one sentence)
3. Director identifies blockers or conflicts
4. Decision: Continue / Revise / Escalate
5. Scribe writes checkpoint

DURATION: 1 model call per agent (fast)
```

#### 2. Review Sessions (Debate Pattern)

```markdown
## Review Protocol

TRIGGER: Before committing significant changes

STRUCTURE:
Round 1 - Present:
  - Builder presents implementation
  - (Optional) Scout presents research findings

Round 2 - Critique:
  - Inspector reviews for bugs
  - Refactorer reviews for quality
  - Architect reviews for alignment with big picture

Round 3 - Decide:
  - Director weighs input (trust-weighted)
  - Decision: Approve / Request changes / Escalate

MAX ROUNDS: 3 (force decision after 3)
```

#### 3. Emergency Meetings

```markdown
## Emergency Protocol

TRIGGER CONDITIONS:
- Agent detects critical error
- Agent stuck > 10 minutes
- Conflicting outputs detected
- Resource exhaustion warning
- Trust score drops below threshold (3/10)

PROCESS:
1. Triggering agent writes to ~/clawd/memory/emergency.md
2. Director is immediately notified
3. All other agents pause current work
4. Director assesses and decides:
   - Resolve internally
   - Request human intervention
   - Abort current phase

ESCALATION TO HUMAN:
- Emergency unresolved after 2 attempts
- Decision involves irreversible action
- Multiple agents in conflict (no consensus)
- Cost/time budget exceeded
```

### Implementation: Shared State for Meetings

```markdown
# ~/clawd/memory/team-state.md

## Current Phase: 2 - Execution
## Last Checkpoint: 2026-01-28 03:45:00

### Agent Status
| Agent | Status | Current Task | Trust |
|-------|--------|--------------|-------|
| Director | Active | Monitoring | N/A |
| Architect | Idle | - | 8/10 |
| Scout | Working | Researching API patterns | 7/10 |
| Builder | Working | Implementing auth module | 9/10 |
| Refactorer | Idle | - | 8/10 |
| Inspector | Idle | - | 9/10 |
| Scribe | Active | Maintaining state | N/A |

### Pending Decisions
- [ ] Choice between REST vs GraphQL (awaiting Scout research)

### Blockers
- None currently

### Next Checkpoint Trigger
- Builder completes auth module
```

---

## 4. Emergency Escalation System

### Circuit Breaker Pattern

From Galileo's research on multi-agent failures:
> "Implement circuit breaker patterns that can halt processing when consistency checks fail, preventing the propagation of detected inconsistencies"

### Escalation Levels

```
LEVEL 0: Normal Operation
─────────────────────────
All agents working within parameters
No intervention needed

LEVEL 1: Agent-Level Issue
──────────────────────────
Single agent stuck or confused
→ Director reassigns or restarts agent
→ Continue operation

LEVEL 2: Coordination Issue  
───────────────────────────
Agents producing conflicting outputs
→ Emergency meeting triggered
→ Director mediates
→ May require phase restart

LEVEL 3: System Issue
─────────────────────
Resource exhaustion, repeated failures
→ All agents pause
→ Scribe writes full state dump
→ Director writes human-readable summary
→ Wait for human intervention

LEVEL 4: Abort
──────────────
Unrecoverable error or human command
→ Graceful shutdown
→ State preserved for analysis
```

### Emergency Detection Rules

```markdown
## Automatic Triggers

1. STUCK DETECTION
   - Agent makes no progress for 3 consecutive calls
   - Same error repeated 3 times
   → Trigger: Level 1

2. CONFLICT DETECTION
   - Two agents produce contradictory outputs
   - Trust-weighted disagreement > threshold
   → Trigger: Level 2

3. RESOURCE DETECTION
   - Memory usage > 90%
   - Queue depth > 50 requests
   - Response latency > 5 minutes
   → Trigger: Level 3

4. QUALITY DETECTION
   - Inspector finds > 5 critical bugs in single review
   - Architect flags fundamental design flaw
   → Trigger: Level 2

5. RUNAWAY DETECTION
   - Same task attempted > 5 times
   - Phase duration > 2× expected
   → Trigger: Level 2, then Level 3
```

### Human Notification

For overnight runs, you need a way to know if things go wrong:

```markdown
## Human Alert Methods

Option 1: File-based (Simple)
- Write to ~/clawd/alerts/ALERT-{timestamp}.md
- You check in the morning

Option 2: Log Monitoring
- `clawdbot logs --follow | grep -i "EMERGENCY\|ESCALATE\|ABORT"`
- Run in separate terminal with notification

Option 3: Webhook (if available)
- Configure Clawdbot to POST to a webhook on Level 3+
- Webhook triggers phone notification
```

---

## 5. Communication Protocols

### Research Finding: Structured > Free-Form

From the MCP research:
> "Predefined interaction protocols specify the expected sequences and patterns of messages for particular coordination tasks"

From MAST failure analysis:
> "Without a clear error-correction protocol, additional agents can even confuse the main coder"

### Message Format Standard

All inter-agent communication should follow this structure:

```markdown
## Agent Message Format

FROM: [Agent Name]
TO: [Agent Name or "ALL"]
TYPE: [STATUS | REQUEST | RESPONSE | DECISION | ALERT]
PRIORITY: [LOW | NORMAL | HIGH | EMERGENCY]
TIMESTAMP: [ISO 8601]

### Content
[Actual message content]

### Context
[Relevant background if needed]

### Expected Response
[What you need back, if anything]
```

### Example Communications

```markdown
## Example 1: Status Update

FROM: Builder
TO: ALL
TYPE: STATUS
PRIORITY: NORMAL
TIMESTAMP: 2026-01-28T03:45:00Z

### Content
Completed auth module implementation. Ready for review.

### Context
Used JWT approach as recommended by Scout's research.

### Expected Response
Inspector and Refactorer to begin review phase.
```

```markdown
## Example 2: Emergency Alert

FROM: Inspector
TO: Director
TYPE: ALERT
PRIORITY: EMERGENCY
TIMESTAMP: 2026-01-28T04:12:00Z

### Content
Critical security vulnerability detected in auth module.
Password hashing uses MD5 instead of bcrypt.

### Context
This was not caught in initial implementation.
Trust adjustment recommended for Builder (-2).

### Expected Response
Immediate decision on whether to:
1. Fix and continue
2. Rollback and redesign
3. Escalate to human
```

### Communication Topology

```
                Director
               /   |   \
              /    |    \
         Architect |   Scribe
             \     |     /
              \    |    /
               Scout   
                 |
    ┌────────────┼────────────┐
    |            |            |
 Builder    Refactorer    Inspector
    |            |            |
    └────────────┴────────────┘
         (peer communication
          for review cycles)
```

**Rules:**
- All agents can report to Director
- Director broadcasts decisions to all
- Scribe listens to everything (passive)
- Builder/Refactorer/Inspector communicate during review phases
- Scout can be queried by anyone
- Architect advises but doesn't direct

---

## 6. Convergence & Stopping Criteria

### When to Stop a Debate/Review Cycle

From the research:
> "Empirically, we find that language models are able to converge on a single shared answer after multiple rounds of debate"

> "Limit debate depth to one pass unless stability demands more"

### Convergence Detection

```markdown
## Convergence Rules

1. UNANIMOUS AGREEMENT
   - All participating agents agree
   - → Stop immediately

2. SUPERMAJORITY
   - 5/7 agents agree (or trust-weighted equivalent)
   - → Stop, note dissent

3. MAX ROUNDS REACHED
   - 3 rounds of debate without convergence
   - → Director decides, note controversy

4. STABILITY DETECTED
   - No agent changed position in last round
   - → Stop, take current majority

5. DIMINISHING RETURNS
   - Changes between rounds < threshold
   - → Stop, current state is final
```

### Implementation

```python
# Pseudocode for convergence check

def check_convergence(round_history):
    current = round_history[-1]
    
    # Unanimous?
    if all_agree(current):
        return True, "unanimous"
    
    # Supermajority?
    if trust_weighted_majority(current) > 0.7:
        return True, "supermajority"
    
    # Max rounds?
    if len(round_history) >= 3:
        return True, "max_rounds"
    
    # Stable? (no changes from last round)
    if len(round_history) > 1:
        if current == round_history[-2]:
            return True, "stable"
    
    return False, "continue"
```

---

## 7. Complete Configuration Recommendations

### Environment Variables

```bash
# Ollama settings
export OLLAMA_NUM_PARALLEL=2
export OLLAMA_KEEP_ALIVE=60m
export OLLAMA_MAX_QUEUE=100

# Optional: If you have issues
export OLLAMA_DEBUG=1
```

### Clawdbot Configuration

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama/qwen3:32b"
      },
      "subagents": {
        "maxConcurrent": 2,
        "archiveAfterMinutes": 120,
        "runTimeoutSeconds": 900
      }
    }
  },
  "tools": {
    "subagents": {
      "tools": {
        "deny": ["gateway", "cron"]
      }
    }
  }
}
```

### Agent-Specific Settings

| Agent | Timeout | Tools Needed | Priority |
|-------|---------|--------------|----------|
| Director | 120s | All coordination tools | Highest |
| Architect | 180s | File read, analysis | High |
| Scout | 300s | Web search, file read | Normal |
| Builder | 900s | All file/code tools | Normal |
| Refactorer | 600s | File read/write | Normal |
| Inspector | 600s | File read, test runner | Normal |
| Scribe | 60s | File write only | Low |

---

## 8. Operational Checklist

### Pre-Flight (Before Overnight Run)

```markdown
## Pre-Flight Checklist

□ Ollama running with correct environment variables
□ Model loaded: `ollama list` shows qwen3:32b
□ Clawdbot gateway running: `clawdbot status`
□ Memory directory exists: `mkdir -p ~/clawd/memory`
□ Initial state file created
□ All agent definitions loaded
□ Test simple command works
□ Sufficient disk space (> 10GB free)
□ Clear any old logs/state from previous runs
□ Set terminal to not sleep/lock
```

### Monitoring During Run

```bash
# In separate terminal windows:

# Window 1: Ollama logs
ollama logs -f

# Window 2: Clawdbot logs  
clawdbot logs --follow

# Window 3: Memory state
watch -n 30 cat ~/clawd/memory/team-state.md

# Window 4: Emergency alerts
watch -n 10 'ls ~/clawd/alerts/ 2>/dev/null | tail -5'
```

### Post-Run Review

```markdown
## Morning Review Checklist

□ Check ~/clawd/alerts/ for any emergencies
□ Read ~/clawd/memory/pipeline-state.md for final status
□ Review Director's decision log
□ Check trust scores - any significant changes?
□ Verify outputs in expected location
□ Review logs for any anomalies
□ Note lessons learned for next run
```

---

## 9. Summary: Key Operational Parameters

| Parameter | Recommended Value | Rationale |
|-----------|-------------------|-----------|
| **Max Concurrent Agents** | 2 | Matches Ollama parallel limit |
| **Debate Rounds** | 1-3 max | Diminishing returns after |
| **Checkpoint Frequency** | Per milestone | Not time-based |
| **Agent Timeout** | 60s-900s by role | Longer for Builder |
| **Emergency Threshold** | 3 failures | Then escalate |
| **Trust Score Range** | 1-10 | Start at 7 |
| **Model Keep-Alive** | 60 minutes | Stay loaded overnight |

---

## 10. What You Might Be Missing

Based on research, here are additional factors to consider:

### 1. **Hallucination Propagation**
> "If a weak tester or reviewer allows incorrect code to pass, later stages in the workflow may amplify the mistake"

**Mitigation:** Inspector should be independent verification, not just rubber stamp.

### 2. **Context Window Limits**
> "Even with long context models, their ability to truly understand long, complex inputs is mixed"

**Mitigation:** Scribe summarizes state rather than appending full history.

### 3. **Token Cost Accumulation**
With 7 agents and multiple rounds, token usage grows fast. Free local models help, but:

**Mitigation:** 
- Set max context per agent call
- Summarize rather than pass full transcripts
- Archive completed phases

### 4. **Deadlock Prevention**
> "Without a clear error-correction protocol, agents can get stuck waiting for each other"

**Mitigation:** 
- Timeouts on all operations
- Director can force-proceed decisions
- No circular dependencies in workflow

### 5. **State Corruption Recovery**
> "If gateway restarts, pending announce work is lost"

**Mitigation:**
- Scribe checkpoints every major milestone
- State in files, not just in memory
- Can resume from last checkpoint

### 6. **Model Consistency**
All agents use same model, so personality differences come purely from prompts.

**Mitigation:** Strong, distinctive prompts for each agent role.
