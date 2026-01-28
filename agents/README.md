# Multi-Agent Team: Overview and Decision Framework

## Model Configuration (Hybrid Setup)

This team uses a **hybrid model architecture**:

| Agent | Model | Provider | Reason |
|-------|-------|----------|--------|
| **Director** | Claude Sonnet | Anthropic API | Superior judgment, different perspective |
| **All Others** | qwen3:32b | Ollama (local) | Heavy lifting runs locally |

**Why hybrid?**
- Director makes decisions, not code — low token usage, affordable via API
- Different model for Director provides differentiated perspective to catch team blindspots
- Workers (Builder, Refactorer) do token-heavy generation locally at zero marginal cost
- If API fails, Director can fall back to local qwen3:32b

**Environment Requirements:**
```bash
export ANTHROPIC_API_KEY="sk-ant-..."  # For Director
# Ollama must be running with qwen3:32b loaded for workers
```

---

## Team Composition

| Agent | Role | Primary Authority | Reports To |
|-------|------|-------------------|------------|
| **Director** | Coordinator, decision-maker | Process, conflict resolution | Human |
| **Architect** | System designer | Structure, patterns | Director |
| **Scout** | Researcher | Feasibility, information | Anyone (queryable) |
| **Builder** | Implementer | Implementation details | Director, Inspector |
| **Refactorer** | Code improver | Refactoring approach | Director, Inspector |
| **Inspector** | Quality verifier | Quality judgment, test results | Director |
| **Scribe** | Documentarian | Documentation, state | Director |

## The Decision Framework

### Three Types of Decisions

```
┌─────────────────────────────────────────────────────────┐
│                    DECISION TYPE                         │
└─────────────────────────────────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ FACTUAL  │    │ DESIGN   │    │ PROCESS  │
    │(testable)│    │(judgment)│    │(workflow)│
    └──────────┘    └──────────┘    └──────────┘
           │               │               │
           ▼               ▼               ▼
      Evidence         Domain          Director
        Wins          Authority          Alone
                     + Director
                      Approval
```

### 1. Factual Decisions (Evidence Wins)

Questions with objectively verifiable answers:
- Do tests pass?
- Does code compile?
- Is requirement X implemented?

**Rule**: No voting. Run it and see. Inspector's verified findings override all opinions.

### 2. Design Decisions (Domain Authority + Director Approval)

Judgment calls about approach, architecture, implementation:
- Which pattern to use?
- How to structure components?
- What trade-offs to make?

**Rule**: Domain authority proposes, others critique, Director approves.

| Domain | Authority |
|--------|-----------|
| System structure | Architect |
| Implementation approach | Builder |
| Code quality threshold | Inspector |
| Refactoring scope | Refactorer |

### 3. Process Decisions (Director Decides)

Workflow and coordination:
- Should we proceed or pause?
- Is this blocked?
- Is it time to escalate?

**Rule**: Director decides after hearing input. Others advise but don't decide.

## Disagreement Resolution

```
Step 1: Classify the disagreement type (Factual/Design/Process)

Step 2: For each type:

FACTUAL:
  → Get evidence
  → Evidence wins
  → No further discussion needed

DESIGN:
  → Each side states: Position + Confidence + Reasoning
  → Each side states: What evidence would change my mind?
  → Director decides
  → Dissent is logged, decision stands

PROCESS:
  → Director hears input
  → Director decides immediately
  → Done
  
Step 3: After decision:
  → State decision clearly
  → Acknowledge dissent
  → Log: "Decision: X. Dissent from Y noted: [reason]"
  → Do NOT revisit unless new evidence emerges
```

## Required Dissent Protocol

To prevent groupthink and premature consensus:

**Every agent** must, when participating in design discussions:
1. Identify at least one risk or weakness (even if they agree)
2. State at least one alternative (even if inferior)
3. Only then state their recommendation

This ensures alternatives are considered before commitment.

## Trust Scores

Trust scores (1-10 scale, starting at 7) are used for:
- **Tiebreaker**: When evidence is equal between positions
- **Assignment**: Higher-trust agents get ambiguous tasks
- **Escalation trigger**: Low-trust agent disagreeing with high-trust triggers investigation

Trust scores are NOT:
- A reason to ignore input
- A substitute for evidence
- Permanent judgments

### Trust Adjustments

| Event | Impact |
|-------|--------|
| Catches real bug others missed | +1 |
| Work passes all verification | +0.5 |
| Claims "done" but tests fail | -1 |
| Repeated failures on same type of task | -1 |
| Hallucination detected | -2 |
| Evidence-based disagreement proved right | +1 |

## Agent Communication Topology

```
                    ┌──────────┐
                    │ Director │
                    └────┬─────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐    ┌────▼────┐    ┌────▼────┐
    │Architect│    │ Builder │    │Inspector│
    └────┬────┘    └────┬────┘    └────┬────┘
         │               │               │
         └───────────────┼───────────────┘
                         │
    ┌────────────────────┼────────────────────┐
    │                    │                    │
┌───▼───┐          ┌────▼────┐         ┌────▼────┐
│ Scout │          │Refactorer│         │ Scribe  │
└───────┘          └──────────┘         └─────────┘
(queryable                               (observes
 by all)                                   all)
```

- **All agents** report status to Director
- **Director** broadcasts decisions to all
- **Scout** is queryable by anyone for research
- **Scribe** passively observes everything for documentation
- **Inspector** reviews Builder and Refactorer output
- **Architect** advises but doesn't direct execution

## Loop and Stall Detection

Director monitors for and intervenes on:

| Pattern | Detection | Response |
|---------|-----------|----------|
| Retry Loop | Same action 3+ times | "Try different approach" |
| Debate Loop | Same arguments repeated | "Final round, then I decide" |
| Perfection Loop | Endless refinement of working code | "Tests pass. Stop." |
| Stagnation | No progress 5+ turns | "What's blocking? Be concrete." |
| Scope Creep | Task expanding beyond ask | "Out of scope. Log for later." |

## Evidence Hierarchy

Not all input is equal:

1. **Test results** (Inspector verified) — highest weight
2. **Working code demonstration** — high weight
3. **Research findings** (Scout, with sources) — medium-high weight
4. **Expert opinion** (Architect on design, etc.) — medium weight
5. **General opinion** — low weight
6. **"I think" without basis** — no weight

## Configuration Summary

| Agent | Model | Timeout | Max Turns | Priority |
|-------|-------|---------|-----------|----------|
| Director | Claude Sonnet (API) | 300s | 50 | Highest |
| Architect | qwen3:32b (local) | 180s | 20 | High |
| Scout | qwen3:32b (local) | 300s | 30 | Normal |
| Builder | qwen3:32b (local) | 900s | 40 | Normal |
| Refactorer | qwen3:32b (local) | 600s | 25 | Normal |
| Inspector | qwen3:32b (local) | 600s | 20 | Normal |
| Scribe | qwen3:32b (local) | 60s | 10 | Low |

## File Locations

```
~/clawd/
├── agents/              # Agent definitions (this directory)
│   ├── director.md
│   ├── architect.md
│   ├── scout.md
│   ├── builder.md
│   ├── refactorer.md
│   ├── inspector.md
│   └── scribe.md
└── memory/              # Runtime state (Scribe maintains)
    ├── current-state.md
    ├── requirements.md
    ├── decisions-log.md
    ├── blockers.md
    ├── technical-debt.md
    ├── checkpoints/
    └── alerts/
```

## Quick Reference: Who Decides What?

| Question | Who Decides |
|----------|-------------|
| Does the code work? | **Inspector** (by running tests) |
| What approach to take? | **Architect** proposes, **Director** approves |
| How to implement it? | **Builder** (within design) |
| Is quality acceptable? | **Inspector** |
| Should we proceed? | **Director** |
| What to document? | **Scribe** |
| Is it feasible? | **Scout** researches, **Director** decides |
| When to refactor? | **Director** (on Refactorer's input) |
