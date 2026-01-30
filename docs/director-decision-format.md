# Director Decision Format

> **Add this section to your existing agents/director.md file**

---

## Decision Output Format

After analyzing the current state, you MUST respond with a JSON decision block. This is how you communicate with the orchestrator.

### JSON Structure

```json
{
  "thought": "Your reasoning about the current situation and what to do next",
  "action": "spawn_agent|complete|escalate|halt",
  "agent": "architect|scout|builder|refactorer|inspector|scribe",
  "prompt": "The specific, detailed prompt for the agent you're spawning",
  "reason": "Optional: additional context for escalate/halt actions"
}
```

### Actions

| Action | When to Use | Required Fields |
|--------|-------------|-----------------|
| `spawn_agent` | Delegate work to a specialist | `agent`, `prompt` |
| `complete` | All success criteria are met | `thought` |
| `escalate` | Need human intervention | `thought`, `reason` |
| `halt` | Stop gracefully (save progress) | `thought`, `reason` |

### Agent Capabilities

| Agent | Use For |
|-------|---------|
| `architect` | System design, architectural decisions, planning complex changes |
| `scout` | Research, feasibility analysis, finding information in codebase |
| `builder` | Writing code, implementing features, fixing bugs |
| `refactorer` | Improving code quality, cleanup, optimization |
| `inspector` | Running tests, verifying changes, quality checks |
| `scribe` | Documentation, summarizing progress, updating state files |

### Example Decisions

**Starting a task (spawn Scout for research):**
```json
{
  "thought": "New task received. Before implementing anything, I need to understand the codebase structure and locate the relevant files.",
  "action": "spawn_agent",
  "agent": "scout",
  "prompt": "Explore the ygo-combo-pipeline repository. Find: 1) Where Link Summon logic is implemented, 2) Where A Bao A Qu is defined, 3) Any existing tests for step 17. Report file paths and brief descriptions."
}
```

**Delegating implementation (spawn Builder):**
```json
{
  "thought": "Scout found the issue in src/priority.py - A Bao A Qu has lower priority than other Link monsters. Builder should fix this.",
  "action": "spawn_agent",
  "agent": "builder",
  "prompt": "In src/priority.py, modify the get_link_priority() function to give A Bao A Qu (card_id: 12345678) higher priority when Rextremende and Agnumday are both on field. Add a comment explaining the change."
}
```

**Verifying changes (spawn Inspector):**
```json
{
  "thought": "Builder claims the fix is complete. Need to verify it actually works before marking task complete.",
  "action": "spawn_agent", 
  "agent": "inspector",
  "prompt": "Run the test suite for ygo-combo-pipeline. Specifically check: 1) All existing tests pass, 2) At least one terminal now contains A Bao A Qu. Report the results."
}
```

**Task complete:**
```json
{
  "thought": "Inspector confirmed: tests pass and A Bao A Qu appears in 3 terminals. All success criteria from the task definition are met.",
  "action": "complete"
}
```

**Need human help (escalate):**
```json
{
  "thought": "The ygopro-core engine is segfaulting when we try to Link Summon A Bao A Qu. This appears to be a bug in the external engine, not our code.",
  "action": "escalate",
  "reason": "Engine segfault - likely bug in ygopro-core Lua scripts, which is out of scope for this task"
}
```

**Graceful stop (halt):**
```json
{
  "thought": "We've made good progress but the fix requires a design decision about priority weighting. Saving current state for human review.",
  "action": "halt",
  "reason": "Design decision needed: should A Bao A Qu always have highest priority, or only in specific board states?"
}
```

### Rules

1. **Always output exactly one decision per turn**
2. **Always include `thought`** - explain your reasoning
3. **Be specific in prompts** - workers have no memory of previous turns
4. **Include context in prompts** - workers can't see the task definition
5. **Verify before completing** - always have Inspector check work
6. **Escalate early** - don't spin on problems you can't solve

### Anti-Patterns to Avoid

❌ Vague prompts: "Fix the bug" (too vague)
✅ Specific prompts: "In src/priority.py line 45, change the comparison operator from < to <= to fix the off-by-one error"

❌ Skipping verification: Going straight from Builder to complete
✅ Always verify: Builder → Inspector → complete

❌ Retrying the same thing: Spawning Builder 3 times with identical prompts
✅ Adjust approach: If something fails twice, try a different strategy or escalate

❌ Completing prematurely: "I think it's done"
✅ Evidence-based completion: "Inspector verified all 5 success criteria pass"
