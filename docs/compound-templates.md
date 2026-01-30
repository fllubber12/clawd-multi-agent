# Compound Engineering Templates

> Use these templates when extracting learnings from session logs.
> Scribe uses these during the nightly compound review phase.

---

## Pattern Template

Use when you discover a reusable approach that worked well.

```markdown
### Pattern: [Descriptive Name]

**Context**: [When this pattern applies - what situation triggers it]

**Problem**: [What problem does this solve]

**Implementation**:
```[language]
[Code or command example]
```

**Why it works**: [Brief explanation]

**Learned from**: [Task name or checkpoint ID] - [Date]

**Related patterns**: [Links to related patterns if any]
```

### Example:

```markdown
### Pattern: CFFI Engine Integration

**Context**: When simulating Yu-Gi-Oh card interactions that require 100% accuracy

**Problem**: Python reimplementations of card effects drift from official rulings

**Implementation**:
```python
from cffi import FFI
ffi = FFI()
# Load the official EDOPro Lua scripts via CFFI
engine = ffi.dlopen("./ocgcore.so")
```

**Why it works**: Uses the same Lua scripts as the actual game client, guaranteeing identical behavior

**Learned from**: ygo-combo-pipeline refactor - 2026-01-15

**Related patterns**: None yet
```

---

## Decision Template

Use when recording why a particular approach was chosen over alternatives.

```markdown
### Decision: [What was decided]

**Date**: [When decided]

**Context**: [The situation that required a decision]

**Options considered**:
1. **[Option A]**: [Brief description]
   - Pros: [advantages]
   - Cons: [disadvantages]
2. **[Option B]**: [Brief description]
   - Pros: [advantages]
   - Cons: [disadvantages]
3. **[Option C]**: [Brief description] (if applicable)

**Choice**: [Which option was selected]

**Rationale**: [Why this choice was made]

**Trade-offs accepted**: [What we gave up by not choosing alternatives]

**Revisit if**: [Conditions that would make us reconsider]
```

### Example:

```markdown
### Decision: DIY Orchestrator Over Frameworks

**Date**: 2026-01-30

**Context**: Needed orchestration for hybrid Claude + Ollama multi-agent system

**Options considered**:
1. **LangGraph**: 
   - Pros: Production-ready, good state management
   - Cons: Assumes same-provider agents, heavy dependencies
2. **AutoGen**: 
   - Pros: Multi-agent focused, conversation patterns
   - Cons: Designed for same-process agents
3. **DIY Python orchestrator**: 
   - Pros: Full control, fits hybrid architecture, simple
   - Cons: More code to maintain

**Choice**: DIY Python orchestrator

**Rationale**: Frameworks assume agents run in same process/provider. Clawd mixes Claude API + local Ollama, which breaks framework assumptions.

**Trade-offs accepted**: Must maintain our own code instead of using battle-tested framework

**Revisit if**: A framework emerges that natively supports hybrid local/API architectures
```

---

## Failure Template

Use when turning a bug, error, or failed approach into a lesson.

```markdown
### Lesson: [Brief description of what went wrong]

**Date**: [When encountered]

**Symptom**: [What was observed - error message, behavior, etc.]

**Investigation**: [What we checked, what we found]

**Root cause**: [The actual underlying problem]

**Fix**: [How it was resolved]
```[language]
[Code fix if applicable]
```

**Prevention**: [How to avoid this in the future]

**Detection**: [How to catch this earlier next time]
```

### Example:

```markdown
### Lesson: qwen3:32b Memory Pressure on M2 Mac

**Date**: 2026-01-29

**Symptom**: Mac became unresponsive during Ollama inference, required force restart

**Investigation**: 
- Checked Activity Monitor: memory pressure critical
- ollama ps showed model consuming ~22GB
- M2 Mac has 24GB total, leaving <2GB for system

**Root cause**: qwen3:32b at Q4 quantization requires ~20GB+ VRAM/RAM. On unified memory Mac, this starves the system.

**Fix**: 
- Removed qwen3:32b from Mac
- Will run larger models on PC (32GB RAM + 12GB VRAM) instead

**Prevention**: 
- Always check model memory requirements before pulling
- Rule of thumb: model should use <70% of available memory
- For 24GB Mac: stick to 14B or smaller models

**Detection**: 
- Run `ollama run --verbose` to see memory usage before committing
- Add memory check to call-agent.sh
```

---

## Gotcha Template

Use for quick notes about non-obvious behaviors or requirements.

```markdown
### Gotcha: [One-line description]

[2-3 sentence explanation of the gotcha and how to handle it]

**Applies to**: [Agent, tool, or context where this matters]
```

### Example:

```markdown
### Gotcha: Ollama requires explicit model pull before use

Unlike Docker which auto-pulls images, Ollama will fail silently or with cryptic errors if the model isn't already downloaded. Always run `ollama pull <model>` before first use in scripts.

**Applies to**: Builder, Refactorer, Inspector (all Ollama workers)
```

---

## Usage Guidelines

### When to Create Each Type

| Situation | Template |
|-----------|----------|
| Found a reusable approach | Pattern |
| Chose between alternatives | Decision |
| Fixed a bug or error | Failure/Lesson |
| Discovered non-obvious behavior | Gotcha |

### Where Learnings Go

| Learning Type | Destination |
|---------------|-------------|
| Agent-specific (e.g., "Builder should always...") | `agents/builder.md` |
| Project-wide (e.g., "All tasks must...") | `CLAUDE.md` |
| Domain-specific (e.g., "Yu-Gi-Oh combos...") | `memory/learnings/ygo-patterns.md` |
| Tool-specific (e.g., "Ollama quirks...") | `memory/learnings/ollama-gotchas.md` |

### Quality Checklist

Before adding a learning, verify:
- [ ] Is this actually reusable? (Not just a one-off fix)
- [ ] Is the context clear enough for future reference?
- [ ] Does it conflict with existing learnings? (If so, update the old one)
- [ ] Is it in the right location?

---

## Scribe's Compound Review Prompt

When running compound review, Scribe should:

1. Read all files in `memory/logs/` from the last 24 hours
2. For each session log, extract:
   - Patterns that worked
   - Decisions that were made
   - Errors and how they were fixed
   - Non-obvious gotchas discovered
3. Format using templates above
4. Place in appropriate destination files
5. Commit with message: `compound: learnings from YYYY-MM-DD`

---

*Last updated: January 30, 2026*
