# Multi-Agent Pipeline Failure Mitigation Guide

## Research-Based Solutions for Overnight Autonomous Operations

This guide addresses four critical failure modes identified in multi-agent LLM systems, synthesized from academic research, production case studies, and framework documentation.

---

## 1. HALLUCINATION PROPAGATION

### The Problem

Research shows that hallucinations in multi-agent systems are fundamentally different from single-LLM hallucinations:

> "Agent hallucinations often span multiple steps and involve multi-state transitions... they may arise during intermediate processes such as perception and reasoning, where they can propagate and accumulate over time." — LLM-based Agents Suffer from Hallucinations (arXiv 2509.18970)

> "Errors in one agent can silently corrupt the state of others, leading to subtle hallucinations rather than obvious failures." — Galileo Multi-Agent Coordination Failure Research

**Key Insight:** The MAST framework (Multi-Agent System Failure Taxonomy) found that "weak or inadequate verification mechanisms were a significant contributor to system failures." A single "rubber stamp" from a weak verifier allows errors to cascade.

### Mitigation Strategies

#### A. Independent Verification Layer

The research is clear: Inspector cannot just review Builder's work — it must verify against independent sources.

```yaml
# Inspector agent configuration
inspector:
  verification_approach: "independent"
  must_verify:
    - code_compiles: "Attempt actual compilation/syntax check"
    - tests_pass: "Run tests, don't trust Builder's claim"
    - requirements_met: "Re-read original requirements, not Builder's interpretation"
  
  # Key: Inspector should NOT see Builder's confidence claims
  context_isolation: true
```

**Implementation for Clawdbot:**
```markdown
## Inspector Verification Protocol

For EACH code artifact, you must:

1. **Compile/Lint Check**: Actually run the code through a linter
   - DO NOT accept "should work" claims
   - Run: `python -m py_compile file.py` or equivalent

2. **Test Execution**: Run existing tests
   - Record actual pass/fail counts
   - Note any tests that were skipped

3. **Requirements Cross-Check**: 
   - Re-read ~/clawd/memory/requirements.md
   - Check each requirement independently
   - Mark: MET / UNMET / PARTIAL

4. **Variance Detection**: 
   - If Builder claims 100% confidence but tests fail, FLAG IMMEDIATELY
   - High variance between claimed and actual = potential hallucination
```

#### B. Circuit Breaker Pattern

From Galileo research: "Implement circuit breaker patterns that can halt processing when consistency checks fail, preventing the propagation of detected inconsistencies."

```yaml
# Circuit breaker configuration
circuit_breaker:
  triggers:
    - condition: "Inspector finds >3 issues in single review"
      action: "halt_and_escalate"
    
    - condition: "Builder output contradicts Architect plan"
      action: "pause_for_review"
    
    - condition: "Same file modified >5 times without tests passing"
      action: "escalate_to_human"
  
  # Automatic rollback on detection
  rollback:
    enabled: true
    checkpoint: "last_passing_tests"
```

#### C. Redundant Processing Pathways

For critical decisions, use parallel verification:

```
Critical Change Detection:
├── Builder creates code
├── Inspector reviews code (perspective 1)
├── Refactorer analyzes code (perspective 2)  
└── If disagreement > threshold → Director mediates

File: ~/clawd/memory/verification-log.md
Track: What was checked, by whom, what was found
```

#### D. Structured Output Formats

> "Adopting structured formats (e.g., JSON) can improve clarity and rigor of expression, which mitigates the risk of miscommunication." — arXiv research

```yaml
# All agent outputs must follow structured format
output_format:
  claims:
    - statement: "string"
      evidence: "string"
      confidence: "HIGH|MEDIUM|LOW"
      verification_method: "string"
  
  # Forces agents to explicitly state how they know something
  no_unsupported_claims: true
```

### Recommended Trust Adjustments for Verification

| Event | Trust Impact |
|-------|-------------|
| Inspector catches real bug | Inspector +1 |
| Inspector misses bug found by tests | Inspector -2 |
| Inspector flags non-issue | Inspector -1 |
| Builder code passes all checks | Builder +0.5 |
| Builder code fails basic lint | Builder -1 |
| Verified hallucination propagated | All involved agents -2 |

---

## 2. CONTEXT WINDOW BLOAT

### The Problem

Research from JetBrains (Dec 2025) on coding agents found:

> "As the context grows, language models often struggle to make good use of all the information they're given."

> "Keeping a window of the latest 10 turns gave us the best balance between performance and efficiency."

From OpenAI Cookbook on context summarization:
> "Compounding errors: If a bad fact enters the summary, it can poison future behavior ('context poisoning')."

**Key Insight:** With 7 agents each generating output, context explodes fast. An overnight run could easily exceed any model's effective context window multiple times.

### Mitigation Strategies

#### A. Hierarchical State Management

Instead of appending full history, maintain structured state files:

```
~/clawd/memory/
├── current-state.md      # What's happening NOW (refreshed each phase)
├── decisions-log.md      # Key decisions only (append-only, summarized)
├── blockers.md           # Active blockers (cleared when resolved)
├── completed-phases.md   # Summaries of completed work
└── artifacts/
    ├── phase-1-summary.md
    ├── phase-2-summary.md
    └── ...
```

#### B. Scribe's Summarization Protocol

The Scribe agent becomes critical for preventing context bloat:

```markdown
## Scribe Summarization Rules

### What to KEEP (verbatim):
- Current phase objectives
- Active blockers and their status
- Last 3 agent outputs
- Uncommitted code changes
- Failed test outputs (most recent only)

### What to SUMMARIZE:
- Completed phases → 3-5 bullet points each
- Resolved blockers → "Resolved: X by Y"
- Passing tests → "All N tests passing"
- Agent discussions → "Decision: X. Rationale: Y"

### What to DISCARD:
- Intermediate reasoning that led to discarded approaches
- Full file contents that haven't changed
- Repeated status checks
- Verbose tool outputs after success

### Summarization Frequency:
- After each milestone completion
- When context approaches 70% of limit
- Every 30 minutes of elapsed time (whichever comes first)
```

#### C. Observation Masking (from JetBrains research)

Keep the last N turns in full, mask observations from older turns:

```yaml
context_management:
  strategy: "hybrid"
  
  # Recent turns: full fidelity
  recent_turns_full: 10
  
  # Older turns: mask verbose observations
  observation_masking:
    enabled: true
    keep:
      - agent_decisions
      - action_taken
      - outcome_summary
    mask:
      - full_file_contents
      - test_output_details
      - tool_call_responses
```

#### D. Anchored Summarization (from Factory.ai)

Don't re-summarize everything each time — maintain incremental summaries:

```markdown
## Anchored Summary Protocol

Each summary is anchored to a specific milestone:

Anchor: milestone-3 (Authentication Complete)
Summary: "Auth system implemented with JWT tokens. Tests passing.
         Files: auth.py, middleware.py, tests/test_auth.py"
         
Anchor: milestone-4 (Database Integration)  
Summary: "PostgreSQL connected. User model created. 
         Migration applied. 12/12 tests passing."

On context overflow:
1. Keep current milestone content in full
2. Keep previous milestone summaries (anchored)
3. Compress anything older into single paragraph
```

### Context Budget Calculator

For qwen3:32b with ~32K context window:

| Component | Token Budget |
|-----------|-------------|
| System prompts (7 agents) | ~3,500 |
| Current phase state | ~4,000 |
| Recent turns (10) | ~8,000 |
| Summarized history | ~4,000 |
| Working space for response | ~8,000 |
| **Safety buffer** | ~4,500 |
| **Total** | ~32,000 |

**Rule:** Trigger summarization when working context exceeds 24,000 tokens (~75%).

---

## 3. DEADLOCK AND LOOP PREVENTION

### The Problem

From production failure analysis:

> "Multi-turn AI agents, despite explicit stop conditions, frequently fall into infinite loops due to a phenomenon we call Loop Drift." — FixBrokenAIApps

> "Agents may cycle endlessly ('chain-of-thought loops'). Dedicated Supervisory Agents halt or redirect agents upon detection of unproductive iteration." — EmergentMind Multi-Agent Framework

**Common Loop Patterns:**
1. **Retry Loop**: Agent keeps retrying same failed operation
2. **Debate Loop**: Two agents endlessly disagree
3. **Perfection Loop**: Agent keeps "improving" already-good code
4. **Context Re-anchoring**: Agent re-processes old information

### Mitigation Strategies

#### A. Hard Guardrails (External Enforcement)

```yaml
# Clawdbot configuration
agents:
  defaults:
    # Maximum LLM calls per task
    maxTurns: 25
    
    # Maximum time per task
    timeoutSeconds: 600
    
    # Consecutive identical outputs
    maxRepetitiveOutputs: 3
    
    # Consecutive tool errors
    maxConsecutiveToolErrors: 3
    
    # Action on limit reached
    limitAction: "escalate_to_director"
```

#### B. Loop Detection Patterns

```markdown
## Director Loop Detection Protocol

Monitor for these patterns:

### Pattern 1: Retry Loop
- Same tool called 3+ times with same parameters
- Action: Inject "Try a different approach" instruction

### Pattern 2: Oscillation
- Agent A says X, Agent B says Y, Agent A says X again
- Action: Force decision after 2 rounds, use voting

### Pattern 3: Stagnation  
- No file changes for 5+ turns despite "working on it"
- Action: Request concrete next action or admit blocked

### Pattern 4: Scope Creep Loop
- Continuous "improvements" to passing code
- Action: If tests pass, STOP refactoring

Detection triggers Director intervention immediately.
```

#### C. Progress Checkpoints

```yaml
progress_tracking:
  checkpoints:
    - name: "meaningful_progress"
      definition: "New test passing OR new file created OR blocker resolved"
      required_every: 10  # turns
      on_failure: "pause_and_assess"
    
    - name: "phase_completion"
      max_duration_minutes: 60
      on_timeout: "summarize_state_and_escalate"
```

#### D. Semantic Completion Checks

Don't rely on agent saying "DONE" — verify programmatically:

```python
# Pseudo-code for completion verification
def verify_task_complete(task, state):
    if task.type == "implement_feature":
        return (
            file_exists(task.target_file) and
            tests_exist(task.feature_name) and
            tests_pass(task.feature_name)
        )
    elif task.type == "fix_bug":
        return (
            original_test_now_passes() and
            no_new_test_failures()
        )
    # Never trust just the agent's claim
```

#### E. Oracle/Supervisor Pattern

From multi-agent framework research: "Introduction of an oracle agent to critique outputs prevents infinite loops and supports robust delegation."

```markdown
## Director as Oracle

Director has HALT capability over all agents.

Director monitors:
- Turn counts per agent
- Time elapsed per phase
- Repetition in outputs
- Contradiction between agents

Director can:
- Force agent to stop current task
- Reassign task to different agent  
- Declare task blocked and move on
- Trigger emergency checkpoint
```

### Timeout Configuration by Role

| Agent | Turn Limit | Time Limit | Rationale |
|-------|-----------|------------|-----------|
| Director | 50 | 300s | Needs flexibility for coordination |
| Architect | 20 | 180s | Planning should be bounded |
| Scout | 30 | 300s | Research can take time |
| Builder | 40 | 900s | Implementation is complex |
| Refactorer | 25 | 600s | Should be focused |
| Inspector | 20 | 600s | Review is bounded |
| Scribe | 10 | 60s | Just documenting |

---

## 4. STATE CHECKPOINTING AND CRASH RECOVERY

### The Problem

From Temporal's AI agent research:

> "If your agent fails, you're back to step one. You restart the process from the beginning, repeating LLM calls that take time and cost money. Even worse, your restarted agent takes a different path."

> "Are you sure you've saved all relevant state in those checkpoints so the agent can reliably continue?"

**Key Insight:** Overnight runs WILL encounter failures (network, Ollama restart, power, etc.). Without proper checkpointing, hours of work are lost.

### Mitigation Strategies

#### A. File-Based State Persistence

Since Clawdbot uses file-based memory, leverage it for durability:

```
~/clawd/memory/
├── checkpoints/
│   ├── checkpoint-001.json    # After milestone 1
│   ├── checkpoint-002.json    # After milestone 2
│   └── latest.json            # Symlink to most recent
├── recovery/
│   ├── in-progress-task.json  # What was being worked on
│   └── agent-states.json      # Each agent's last known state
```

#### B. Checkpoint Structure

```json
{
  "checkpoint_id": "cp-20260128-0342",
  "timestamp": "2026-01-28T03:42:15Z",
  "milestone": "authentication-complete",
  
  "phase": {
    "current": 2,
    "name": "execution",
    "progress_pct": 65
  },
  
  "completed_tasks": [
    {"task": "setup-project", "agent": "Builder", "status": "success"},
    {"task": "implement-auth", "agent": "Builder", "status": "success"}
  ],
  
  "in_progress_task": {
    "task": "implement-database",
    "agent": "Builder",
    "started_at": "2026-01-28T03:40:00Z",
    "last_action": "Created models.py"
  },
  
  "pending_tasks": [
    "implement-api-endpoints",
    "write-tests",
    "documentation"
  ],
  
  "agent_trust_scores": {
    "Director": 8,
    "Architect": 7,
    "Scout": 7,
    "Builder": 8,
    "Refactorer": 7,
    "Inspector": 7,
    "Scribe": 7
  },
  
  "files_modified": [
    "src/auth.py",
    "src/models.py",
    "tests/test_auth.py"
  ],
  
  "test_status": {
    "total": 15,
    "passing": 12,
    "failing": 3,
    "skipped": 0
  },
  
  "context_summary": "Auth complete with JWT. Database models defined. 3 endpoint tests failing due to missing routes."
}
```

#### C. Checkpoint Frequency

```yaml
checkpoint_policy:
  # Always checkpoint after these events
  trigger_on:
    - milestone_complete
    - phase_transition
    - test_suite_pass
    - emergency_escalation
  
  # Time-based fallback
  periodic:
    interval_minutes: 15
    min_changes: 1  # Only if something changed
  
  # Retain policy
  retention:
    keep_last: 10
    keep_milestone: true  # Never delete milestone checkpoints
```

#### D. Recovery Protocol

```markdown
## Startup Recovery Protocol

On Clawdbot startup, Director checks:

1. **Check for existing state**
   ```
   if exists(~/clawd/memory/checkpoints/latest.json):
       load_checkpoint()
       assess_resumability()
   ```

2. **Assess what can be resumed**
   - Are modified files still present?
   - Do test results match checkpoint?
   - Is in-progress task still valid?

3. **Recovery options**
   - FULL_RESUME: Continue exactly where stopped
   - PARTIAL_RESUME: Rollback in-progress task, continue from last milestone
   - FRESH_START: Checkpoint corrupted, start over

4. **Notify and proceed**
   - Log: "Resuming from checkpoint cp-XXXX (milestone: Y)"
   - Don't repeat completed work
   - Re-validate assumptions before continuing
```

#### E. Graceful Shutdown Handling

```yaml
# Handle SIGTERM/SIGINT gracefully
shutdown_protocol:
  on_signal:
    - save_immediate_checkpoint
    - mark_in_progress_task_interrupted
    - flush_all_logs
    - write_recovery_instructions
  
  timeout_seconds: 30  # Max time for graceful shutdown
```

#### F. Idempotent Operations

For safe replay after recovery:

```markdown
## Idempotent Operation Guidelines

All agent operations should be idempotent:

✅ GOOD (Idempotent):
- "Create file X with content Y" (overwrites if exists)
- "Ensure test X passes" (checks first)
- "Set config value to X" (not "increment by 1")

❌ BAD (Not Idempotent):
- "Append to file X" (duplicates on replay)
- "Increment counter" (wrong value on replay)  
- "Send notification" (duplicate messages)

For non-idempotent operations:
- Check if already done before executing
- Log completion to prevent replay
- Use unique operation IDs
```

---

## INTEGRATED MONITORING SETUP

### Real-Time Monitoring Commands

```bash
# Terminal 1: Ollama health
watch -n 5 'curl -s http://localhost:11434/api/tags | jq ".models[0].name"'

# Terminal 2: Agent activity
tail -f ~/clawd/logs/agent-activity.log | grep -E "(ERROR|WARN|milestone|checkpoint)"

# Terminal 3: State changes
watch -n 30 'cat ~/clawd/memory/current-state.md | head -20'

# Terminal 4: Loop detection
watch -n 10 'cat ~/clawd/memory/checkpoints/latest.json | jq ".in_progress_task"'

# Terminal 5: Emergency alerts
watch -n 5 'ls -la ~/clawd/alerts/ 2>/dev/null | tail -5'
```

### Alert Thresholds

| Metric | Warning | Critical |
|--------|---------|----------|
| Agent turns without progress | 10 | 20 |
| Time on single task | 10 min | 30 min |
| Context usage | 70% | 85% |
| Consecutive errors | 2 | 5 |
| Ollama response time | 30s | 60s |
| Memory usage | 80% | 90% |

---

## IMPLEMENTATION CHECKLIST

### Pre-Flight Additions

- [ ] Create checkpoint directory structure
- [ ] Initialize recovery state files  
- [ ] Set up monitoring terminals
- [ ] Configure agent timeout values
- [ ] Test checkpoint save/restore
- [ ] Verify idempotent operations
- [ ] Set up alert file watcher

### Agent Prompt Additions

- [ ] Add loop detection instructions to Director
- [ ] Add summarization protocol to Scribe
- [ ] Add independent verification protocol to Inspector
- [ ] Add circuit breaker triggers to all agents
- [ ] Add "claim + evidence" output format requirement

### Runtime Validation

- [ ] Checkpoint saved after first milestone
- [ ] Context summarization triggering correctly
- [ ] Loop detection catching test patterns
- [ ] Recovery tested (kill and restart)

---

## RESEARCH SOURCES

### Hallucination Propagation
- "LLM-based Agents Suffer from Hallucinations: A Survey" (arXiv 2509.18970)
- Galileo Multi-Agent Coordination Failure Mitigation
- GUARDIAN: Safeguarding LLM Multi-Agent Collaborations (arXiv 2505.19234)
- "Why Do Multi-Agent LLM Systems Fail?" MAST Framework (arXiv 2503.13657)

### Context Window Management
- JetBrains Research: Efficient Context Management for LLM-Powered Agents
- Factory.ai: Compressing Context
- OpenAI Cookbook: Context Engineering with Sessions
- Mem0: LLM Chat History Summarization Guide

### Loop/Deadlock Prevention
- Invariant Loop Detection Documentation
- "Why AI Agents Get Stuck in Loops" - FixBrokenAIApps
- Clawdbot Issue #806: Tool Call Loop Detection
- Multi-Agent LLM Framework - EmergentMind

### State Checkpointing
- LangChain: Durable Execution Documentation
- Temporal: Building Dynamic AI Agents
- DBOS: Durable Execution for Crashproof AI Agents
- Microsoft Agent Framework: Checkpointing and Resuming
