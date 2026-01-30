# Clawd Research Hub

> Last updated: January 30, 2026
> Session: Post-orchestration research synthesis

---

## Current State Summary

Clawd is a **hybrid multi-agent autonomous coding system**:
- **Director**: Claude (via `claude -p`, uses Pro subscription)
- **Workers**: 6 local Ollama agents (Architect, Scout, Builder, Refactorer, Inspector, Scribe)
- **Orchestrator**: Custom Python (~560 lines), file-based state, checkpoint/resume

**Status**: Orchestration complete, smoke test passed. Awaiting PC hardware (32GB RAM + RTX 3060 12GB) for worker deployment.

---

## Research Topics

### 🔴 High Priority

#### 1. Model Selection for PC Workers
**Status**: Research complete - ready to test when hardware arrives

**Hardware Constraints**:
- 32GB system RAM
- 12GB VRAM (RTX 3060)
- Need models for code generation, debugging, documentation
- qwen3:32b caused memory pressure on Mac M2 (24GB) - won't fit on 12GB GPU

---

**RTX 3060 12GB Reality Check** (from research):

| Model Size | VRAM (Q4_K_M) | Fits in 12GB? | Speed Est. | Notes |
|------------|---------------|---------------|------------|-------|
| 7B | ~5-6GB | ✅ Yes | 25-37 t/s | Comfortable, room for context |
| 13-14B | ~9-10GB | ⚠️ Tight | 7-15 t/s | Works with moderate context |
| 22B | ~14GB | ❌ No | CPU offload needed | Slow, not recommended |
| 32B+ | ~20GB+ | ❌ No | Heavy CPU offload | Unusable speeds |

**Key insight**: <cite>"12GB limits you to either small models or extreme quantization"</cite>. The sweet spot for RTX 3060 is **7B-14B models at Q4 quantization**.

---

**Recommended Models for Clawd Workers**:

**Tier 1: Safe & Fast (7B class)**
| Model | Ollama Command | Best For | Context |
|-------|----------------|----------|---------|
| `qwen2.5-coder:7b` | `ollama pull qwen2.5-coder:7b` | Builder, Refactorer | 128K |
| `deepseek-r1:7b` | `ollama pull deepseek-r1:7b` | Inspector (reasoning) | 32K |
| `codellama:7b-instruct` | `ollama pull codellama:7b-instruct` | General coding | 16K |

**Tier 2: Quality Stretch (14B class)** - More capable but tighter VRAM
| Model | Ollama Command | Best For | Context |
|-------|----------------|----------|---------|
| `qwen2.5-coder:14b` | `ollama pull qwen2.5-coder:14b` | Complex code tasks | 128K |
| `deepseek-r1:14b` | `ollama pull deepseek-r1:14b` | Reasoning-heavy tasks | 32K |

---

**Model-to-Agent Mapping (Proposed)**:

| Agent | Role | Recommended Model | Rationale |
|-------|------|-------------------|-----------|
| **Builder** | Implement code | `qwen2.5-coder:7b` | Fast generation, good code quality |
| **Refactorer** | Improve code | `qwen2.5-coder:7b` | Same model, consistent style |
| **Inspector** | Verify/debug | `deepseek-r1:7b` | Reasoning-focused, catches errors |
| **Architect** | System design | `deepseek-r1:14b` | Needs more reasoning depth |
| **Scout** | Research | `qwen2.5:7b` (general) | General knowledge, not code-specific |
| **Scribe** | Documentation | `qwen2.5:7b` | Writing-focused, lightweight |

**Alternative strategy**: Use ONE model for all workers to simplify. `qwen2.5-coder:7b` is the best all-rounder for 12GB VRAM.

---

**Benchmark Expectations (RTX 3060)**:
- 7B Q4: ~25-37 tokens/sec (Linux faster than Windows)
- 14B Q4: ~7-15 tokens/sec 
- Context scaling: Each 1K tokens adds ~50-100MB VRAM for KV cache

**Critical**: Context length kills VRAM. At 32K context, even 7B models use significant memory. Keep prompts lean.

---

**Testing Protocol (When PC Arrives)**:
```bash
# 1. Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# 2. Pull candidate models
ollama pull qwen2.5-coder:7b
ollama pull deepseek-r1:7b
ollama pull qwen2.5-coder:14b  # test if it fits

# 3. Check VRAM usage
watch -n 1 nvidia-smi

# 4. Benchmark speed
ollama run qwen2.5-coder:7b "Write a Python function to merge two sorted lists"

# 5. Test with clawd's call-agent.sh
./scripts/call-agent.sh builder "implement merge sort in Python"
```

---

**Kimi K2.5 Option (API-based fallback)**:
- Moonshot AI's coding model
- Available via API - requires subscription
- **Tradeoff**: API costs vs local (free) inference
- **Potential use**: Fallback if local models underperform on specific tasks
- Not primary recommendation due to cost

---

**Decision**: Start with `qwen2.5-coder:7b` for all workers. It's the safest choice that will definitely work. Upgrade to 14B models later if quality is insufficient and you can tolerate slower speeds.

---

**Ollama Context Window Management** (Critical for Performance):

**Default is too small**: Ollama defaults to 2048-4096 tokens, but agentic tasks need more.

**Setting context length**:
```bash
# Temporary (in chat)
/set parameter num_ctx 16384

# Save as custom model variant
/save qwen-coder-16k:7b

# Permanent via Modelfile
cat > Modelfile << EOF
FROM qwen2.5-coder:7b
PARAMETER num_ctx 16384
EOF
ollama create qwen-coder-16k -f Modelfile

# Or set globally via environment
export OLLAMA_CONTEXT_LENGTH=16384
```

**VRAM vs Context tradeoff (RTX 3060 12GB)**:

| Context | KV Cache VRAM | Model VRAM | Total | Fits? |
|---------|---------------|------------|-------|-------|
| 4K | ~0.3GB | 5GB | ~5.3GB | ✅ Comfortable |
| 8K | ~0.6GB | 5GB | ~5.6GB | ✅ Good |
| 16K | ~1.2GB | 5GB | ~6.2GB | ✅ Recommended |
| 32K | ~2.4GB | 5GB | ~7.4GB | ⚠️ Tight |
| 64K | ~4.8GB | 5GB | ~9.8GB | ⚠️ Very tight |

**Recommendation for clawd**: Use 16K context. Balances capability with VRAM headroom.

**Monitor with**:
```bash
# Check actual context being used
ollama ps  # Shows CONTEXT column

# Monitor VRAM in real-time
watch -n 1 nvidia-smi
```

**Flash Attention** (free performance boost):
```bash
export OLLAMA_FLASH_ATTENTION=1
```
Reduces VRAM usage and increases speed with zero quality loss.

---

#### 2. Compound Engineering Pattern
**Status**: Research complete - ready to implement

**Source**: Kieran Klaassen / Every Inc. (EveryInc/compound-engineering-plugin - 5K+ stars)

---

**Core Philosophy**:
> "Each unit of engineering work should make subsequent units easier—not harder."

Traditional development accumulates technical debt. Compound engineering inverts this by creating a learning loop where each bug, failed test, or insight gets documented and used by future work.

---

**The Four-Phase Loop**:

```
Plan (40%) → Work (20%) → Review (20%) → Compound (20%)
     ↑                                          │
     └──────────────────────────────────────────┘
```

| Phase | Time | Purpose |
|-------|------|---------|
| **Plan** | 40% | Research approaches, create detailed implementation plans |
| **Work** | 20% | Execute plan systematically with validation |
| **Review** | 20% | Evaluate output, identify issues and learnings |
| **Compound** | 20% | Feed results back to make next loop better |

**Key insight**: 80% is planning and review, only 20% is execution. When AI writes all code, the bottleneck shifts to knowing *what* to build and catching problems early.

---

**What to Compound (Learning Extraction)**:

**1. Patterns** - New patterns discovered or created:
```markdown
## Pattern: [Name]
When to use: [context]
Implementation: [example code]
See: [file reference]
```

**2. Decisions** - Why certain approaches were chosen:
```markdown
## Decision: [Choice Made]
Context: [situation]
Options considered: [alternatives]
Rationale: [why this choice]
Consequences: [trade-offs]
```

**3. Failures** - Turn every bug into a lesson:
```markdown
## Lesson: [What Went Wrong]
Symptom: [what was observed]
Root cause: [actual problem]
Fix: [solution]
Prevention: [how to avoid in future]
```

---

**Where to Codify Learnings**:

1. **CLAUDE.md / AGENTS.md** - Project-wide guidance that applies everywhere
2. **Subdirectory .md files** - Specific guidance for subsystems
3. **Agent prompt files** - Lessons specific to an agent's role
4. **Test cases** - Turn bugs into regression tests

---

**Adaptation for Clawd**:

The compound-engineering-plugin is designed for Claude Code (single agent). Clawd needs a multi-agent version:

**Clawd's Compound Loop**:
```
┌─────────────────────────────────────────────────────────────┐
│ PHASE 1: Compound Review (Nightly, before task execution)   │
├─────────────────────────────────────────────────────────────┤
│ 1. Scribe agent reviews memory/logs/ from last 24 hours     │
│ 2. Extracts patterns, decisions, failures using templates   │
│ 3. Updates relevant agent .md files:                        │
│    - builder.md gets coding patterns                        │
│    - inspector.md gets verification lessons                 │
│    - CLAUDE.md gets project-wide insights                   │
│ 4. Commits updates to repo                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ PHASE 2: Task Execution (Uses updated knowledge)            │
├─────────────────────────────────────────────────────────────┤
│ 1. Director loads freshly updated agent prompts             │
│ 2. Picks highest priority task from memory/tasks/           │
│ 3. Orchestrator runs task loop (spawn workers, checkpoint)  │
│ 4. On completion, logs are ready for next compound cycle    │
└─────────────────────────────────────────────────────────────┘
```

---

**Implementation Plan for Clawd**:

**Step 1: Create compound review script**
```bash
# scripts/compound-review.sh
#!/bin/bash
cd ~/clawd

# Run Scribe to extract learnings from recent logs
claude -p "You are the Scribe agent. Review all files in memory/logs/ 
from the last 24 hours. For each session:
1. Extract PATTERNS (reusable approaches that worked)
2. Extract DECISIONS (choices made and rationale)  
3. Extract FAILURES (bugs and their fixes)

Update the appropriate agent .md files with these learnings.
Use the templates in docs/compound-templates.md.
Commit changes with message 'compound: learnings from [date]'"
```

**Step 2: Create compound templates**
```markdown
# docs/compound-templates.md

## Pattern Template
### Pattern: [Descriptive Name]
**Context**: When this applies
**Implementation**: How to do it
**Example**: Code or command
**Learned from**: [task/date]

## Decision Template  
### Decision: [What was decided]
**Context**: The situation
**Options**: What we considered
**Choice**: What we picked and why
**Trade-offs**: What we gave up

## Failure Template
### Lesson: [Brief description]
**Symptom**: What we observed
**Root cause**: Actual problem
**Fix**: How we solved it
**Prevention**: How to avoid next time
```

**Step 3: Schedule with launchd (Mac)**
```xml
<!-- ~/Library/LaunchAgents/com.clawd.compound-review.plist -->
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.clawd.compound-review</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/zach/clawd/scripts/compound-review.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>22</integer>
    <key>Minute</key>
    <integer>30</integer>
  </dict>
</dict>
</plist>
```

**Step 4: Add caffeinate wrapper**
```bash
# Wrap overnight runs to prevent Mac sleep
caffeinate -i -t 32400 ./scripts/compound-review.sh
```

---

**Key Differences from Original Plugin**:

| Compound Plugin (Claude Code) | Clawd Adaptation |
|------------------------------|------------------|
| `/workflows:compound` command | Scribe agent extracts learnings |
| Single agent reviews own work | Multi-agent: Scribe reviews all workers' logs |
| Interactive (user triggers) | Automated (nightly cron/launchd) |
| Updates AGENTS.md | Updates agent-specific .md files |
| docs/solutions/ directory | memory/learnings/ directory |

---

**Success Metrics**:

After implementing compound loop, track:
- Do agent prompts grow with useful patterns?
- Do repeated errors decrease over time?
- Does task completion rate improve?
- Are Director decisions getting more informed?

---

#### 3. Skills Architecture & Separation of Concerns
**Status**: Research complete - ready to implement

**Sources**: 
- Anthropic official docs (docs.claude.com, platform.claude.com)
- HumanLayer "Writing a good CLAUDE.md"
- Will Larson's implementation at Imprint
- Claude Code Skills deep dive (leehanchung.github.io)
- Chris Wiles' claude-code-showcase repo

---

**Core Principle: Progressive Disclosure**

> "The most important concept for building Skills is Progressive Disclosure - showing just enough information to help agents decide what to do next, then revealing more details as they need them."

**Three-tier loading**:
1. **Startup**: Only name + description from frontmatter (minimal tokens)
2. **Invocation**: Full SKILL.md content loaded (~500 lines max)
3. **As needed**: Additional bundled files (reference.md, etc.)

This is critical for local models with limited context windows.

---

**CLAUDE.md Best Practices**

**What goes in CLAUDE.md** (always loaded):
- Project structure / tech stack overview
- How to build/test/run the project
- Universal coding conventions
- Pointers to detailed docs (NOT the docs themselves)

**What does NOT go in CLAUDE.md**:
- Task-specific instructions (use Skills instead)
- Detailed schemas (put in separate files)
- Code snippets (they go stale; use file:line references)
- Long examples (put in Skills)

**Key insight from HumanLayer**:
> "Frontier thinking LLMs can follow ~150-200 instructions with reasonable consistency. Smaller models exhibit exponential decay in instruction-following as instructions increase."

For clawd's local 7B models, this means: **keep prompts lean**.

---

**Separation Pattern**

| Layer | Purpose | When Loaded | Token Cost |
|-------|---------|-------------|------------|
| **CLAUDE.md** | Universal context | Always | Every turn |
| **Skill (SKILL.md)** | Task-specific instructions | On invocation | When relevant |
| **Bundled files** | Reference material | On demand | Only if needed |

**Example structure**:
```
.claude/
├── CLAUDE.md              # Universal: tech stack, build commands
├── skills/
│   ├── building/
│   │   └── SKILL.md       # How to implement features
│   ├── reviewing/
│   │   └── SKILL.md       # Code review checklist
│   └── debugging/
│       ├── SKILL.md       # Debug workflow
│       └── common-errors.md  # Reference (loaded on demand)
└── agents/
    └── code-reviewer.md   # Specialized persona
```

---

**SKILL.md Format**

```yaml
---
name: building-features
description: Implements new features following project conventions. 
  Use when asked to build, create, or implement functionality.
---

# Building Features

## Workflow
1. Read the task specification
2. Check existing patterns in src/
3. Implement following conventions
4. Run tests before committing

## Conventions
- Use TypeScript strict mode
- Error handling: always use Result types
- Tests: colocate with source files

## Reference
For detailed patterns, see ./patterns.md
```

**Critical fields**:
- `name`: Lowercase, hyphens only. Becomes `/skill-name` command
- `description`: Write in third person. Include WHAT it does AND WHEN to use it

---

**Application to Clawd**

**Current state** (agents/*.md files likely contain):
- What the agent does (technical capability)
- When Director should spawn it (orchestration logic)
- How the agent approaches tasks (workflow)
- Tool usage patterns (usage intelligence)
- Common mistakes and fixes (learnings)

**Better separation**:

| File | Contains | Loaded |
|------|----------|--------|
| `CLAUDE.md` | Project overview, memory structure, task format | Always |
| `agents/builder.md` | Builder's persona + core capabilities | When Builder spawned |
| `skills/implementing/SKILL.md` | Implementation workflow, patterns | When doing implementation |
| `skills/debugging/SKILL.md` | Debug workflow, common errors | When debugging |
| `memory/learnings/*.md` | Compound learnings by topic | On demand |

---

**Refactoring Plan for Clawd**

**Step 1: Audit current agent files**
```bash
# Check line counts
wc -l agents/*.md

# Look for mixed concerns
grep -l "when to use\|workflow\|pattern\|convention" agents/*.md
```

**Step 2: Extract Skills from agents**

For each agent file, identify:
- **Keep in agent.md**: Persona, core role, capabilities, tools
- **Move to skill**: Workflows, patterns, best practices
- **Move to memory/learnings**: Historical lessons, gotchas

**Step 3: Create clawd-specific Skills**

| Skill | Purpose | Trigger |
|-------|---------|---------|
| `implementing` | Building new code | "implement", "create", "build" |
| `debugging` | Finding and fixing bugs | "debug", "fix", "error" |
| `refactoring` | Improving existing code | "refactor", "clean up", "improve" |
| `testing` | Writing and running tests | "test", "verify", "check" |
| `documenting` | Writing docs | "document", "explain", "readme" |

**Step 4: Slim down CLAUDE.md**

Current CLAUDE.md might be overloaded. Should contain only:
```markdown
# Clawd Multi-Agent System

## Project Structure
- agents/ - Agent definitions
- memory/ - Tasks, checkpoints, logs, learnings
- scripts/ - Orchestration and utilities

## Commands
- ./scripts/orchestrator.py - Main loop
- ./scripts/call-agent.sh - Invoke a worker

## Conventions
- Tasks in memory/tasks/*.md
- Checkpoints in memory/checkpoints/
- Logs in memory/logs/

## Skills (read when relevant)
- skills/implementing/ - How to build features
- skills/debugging/ - How to fix bugs
[...]
```

---

**Token Efficiency for Local Models**

For `qwen2.5-coder:7b` with limited context, every token matters.

**Before** (everything in agent prompt):
```
Agent prompt: ~2000 tokens
+ CLAUDE.md: ~1000 tokens
+ Task description: ~500 tokens
+ File contents: ~2000 tokens
= 5500 tokens before any output
```

**After** (with Skills):
```
Agent prompt: ~500 tokens (lean)
+ CLAUDE.md: ~300 tokens (pointers only)
+ Relevant skill: ~400 tokens (loaded on demand)
+ Task description: ~500 tokens
+ File contents: ~2000 tokens
= 3700 tokens (32% reduction)
```

This reduction matters significantly for 7B models.

---

**Progressive Disclosure in Practice**

**Example: Builder needs to implement a feature**

1. Builder starts with lean prompt (persona + capabilities)
2. Orchestrator passes task: "Implement merge sort in Python"
3. Builder invokes `implementing` skill → loads workflow
4. Skill references `memory/learnings/python-patterns.md` → loaded only if needed
5. Builder follows workflow, produces code

Without progressive disclosure, ALL of this would be in context from the start.

---

### 🟡 Medium Priority

#### 4. Memory Architecture (Passive vs Active)
**Status**: Basic structure exists, needs optimization strategy

**Source**: Supermemory article + first article on agent memory

**The problem**: Tool-based memory is unreliable (model might not call it)

**Clawd's current memory**:
- **Passive** (always loaded): CLAUDE.md, agent .md files
- **Active** (requires tool call): memory/ folder, checkpoints

**Hybrid approach**:
```
┌─────────────────────────────────────────────────────┐
│ PASSIVE (always in context)                         │
│ ├── CLAUDE.md (project overview)                    │
│ ├── Current task definition                         │
│ └── Recent checkpoint summary (auto-injected)       │
├─────────────────────────────────────────────────────┤
│ WARM (searchable, loaded on relevance)              │
│ ├── Agent Skill files                               │
│ ├── Recent session logs (via qmd search)            │
│ └── Related task history                            │
├─────────────────────────────────────────────────────┤
│ COLD (archived, rarely accessed)                    │
│ ├── Old checkpoints (>30 days)                      │
│ └── Completed task archives                         │
└─────────────────────────────────────────────────────┘
```

**Key insight from research**: 
> "Memory needs to be fed into the model on every run" (passive)
> But passive memory is expensive (tokens)
> Solution: Consolidate important learnings from active → passive via Scribe

**Action items**:
- [ ] Implement auto-injection of recent checkpoint summary at task start
- [ ] Set up qmd for memory/ folder search (see below)
- [ ] Define consolidation criteria (what moves from active to passive)
- [ ] Add memory decay (archive checkpoints >30 days)

---

#### 5. qmd for Memory Retrieval
**Status**: Research complete - ready to install

**Sources**: 
- tobi/qmd (original CLI tool)
- ehc-io/qmd (MCP server version)
- levineam/qmd-skill (Claude Code skill)

---

**What qmd Is**:

A local markdown search engine combining:
- **BM25** (keyword search via SQLite FTS5) - fast, instant
- **Vector embeddings** (semantic search) - slower, smarter
- **LLM re-ranking** (hybrid query mode) - highest quality

All running locally via node-llama-cpp with GGUF models.

---

**Two Versions**:

| Version | Installation | Best For |
|---------|--------------|----------|
| `tobi/qmd` | `bun install -g https://github.com/tobi/qmd` | CLI usage, cron jobs |
| `ehc-io/qmd` | Docker + MCP | Claude Code integration |

For clawd, the CLI version (`tobi/qmd`) is simpler and sufficient.

---

**Search Modes**:

| Mode | Command | Speed | Use Case |
|------|---------|-------|----------|
| `search` | `qmd search "query"` | Instant | Default - keyword matching |
| `vsearch` | `qmd vsearch "query"` | ~30-60s first run | Semantic similarity |
| `query` | `qmd query "query"` | Slow | Hybrid + reranking (best quality) |

**Recommendation from qmd-skill**:
> "Prefer `qmd search` (BM25). It's typically instant and should be the default. Use `qmd vsearch` only when keyword search fails."

---

**Setup for Clawd**:

```bash
# Install (requires Bun)
curl -fsSL https://bun.sh/install | bash
bun install -g https://github.com/tobi/qmd

# Create collection for clawd memory
qmd collection add ~/clawd/memory --name clawd-memory --mask "**/*.md"

# Add context (helps search quality)
qmd context add qmd://clawd-memory "Clawd multi-agent system: tasks, checkpoints, logs, learnings"

# Generate embeddings (one-time, can take a while)
qmd embed

# Test search
qmd search "A Bao A Qu" -c clawd-memory
```

---

**Cron for Index Updates**:

```bash
# Add to crontab
crontab -e

# Hourly BM25 index update (fast)
0 * * * * export PATH="$HOME/.bun/bin:$PATH" && qmd update

# Optional: nightly embedding refresh (slow)
0 5 * * * export PATH="$HOME/.bun/bin:$PATH" && qmd embed
```

---

**Integration with Director**:

Director can use qmd before making decisions:

```bash
# In call-agent.sh or orchestrator, before spawning Director:
SEARCH_RESULTS=$(qmd search "$TASK_KEYWORDS" -c clawd-memory 2>/dev/null | head -20)

# Pass to Director as context
claude -p "Task: $TASK

Relevant history from memory:
$SEARCH_RESULTS

Make your decision..."
```

---

**Models Used (auto-downloaded)**:

| Model | Purpose | Size |
|-------|---------|------|
| embeddinggemma-300M | Vector embeddings | ~300MB |
| qwen3-reranker-0.6B | Re-ranking | ~600MB |
| qmd-query-expansion-1.7B | Query expansion | ~1.7GB |

Cache location: `~/.cache/qmd/models/`

---

**Key Differences from Code Search**:

qmd is for **markdown knowledge bases**, not code:
- Chunking is content-based (~800 tokens/chunk)
- Handles "messy" markdown well
- Not a replacement for grep/ripgrep for code

For code search in clawd, workers should use standard tools (grep, ripgrep, ast-grep).

---

**Action Items**:
- [ ] Install Bun and qmd on Mac
- [ ] Create clawd-memory collection
- [ ] Add cron for hourly updates
- [ ] Test search quality with existing memory/
- [ ] Integrate search results into Director context

---

#### 6. Prompt Injection Defenses
**Status**: Understood threat model, mitigations identified

**Sources**: Security article ("10 ways to hack"), Moltbot exposure article

**Threat vectors for clawd**:
1. Malicious content in task files (memory/*.md)
2. Injections in external content workers might read (web, docs)
3. Supply chain (if using external Skills)

**Mitigations**:

| Defense | Implementation |
|---------|----------------|
| Director as security boundary | Claude (Opus 4.5) has 99% prompt injection resistance per Anthropic. Director validates/sanitizes before passing to workers. |
| Workers never read external content directly | All external input goes through Director first |
| No exposed gateway | Clawd runs locally, no network attack surface |
| File permissions | `chmod 700 ~/clawd/memory` |
| Allowlist for task sources | Only execute tasks from known paths |

**Key principle**: Workers receive instructions from Director only, never raw external content.

**Action items**:
- [ ] Add input sanitization to orchestrator before worker dispatch
- [ ] Implement task file validation (check for suspicious patterns)
- [ ] Document threat model in clawd repo

---

#### 7. Overnight Run Infrastructure & Observability
**Status**: Research complete - implementation ready

**Sources**:
- n8n AI agent deployment guide
- OpenTelemetry AI agent observability standards
- Datadog/Langfuse agent monitoring patterns
- Azure AI Foundry observability best practices

---

**Core Components**:

```
┌─────────────────────────────────────────────────────────────┐
│ OVERNIGHT RUN INFRASTRUCTURE                                 │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  10:30 PM: Compound Review                                   │
│  ├── Extract learnings from day's logs                       │
│  ├── Update agent prompts                                    │
│  └── Commit changes                                          │
│                                                              │
│  11:00 PM: Task Execution                                    │
│  ├── Load updated prompts (now smarter!)                     │
│  ├── Pick task from memory/tasks/pending.md                  │
│  ├── Run orchestrator loop                                   │
│  │   ├── Director decision                                   │
│  │   ├── Worker execution                                    │
│  │   ├── Checkpoint after each turn                          │
│  │   └── Repeat until complete/halt/escalate                 │
│  └── Log to memory/logs/                                     │
│                                                              │
│  Continuous: Monitoring                                      │
│  ├── Ollama watchdog (restart if crashed)                    │
│  ├── Alert on escalation/halt                                │
│  └── Morning summary notification                            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

**Observability Best Practices for Agents**:

From research, AI agents need more than traditional monitoring:

| Traditional | Agent-Specific |
|-------------|----------------|
| Uptime | Decision quality |
| Latency | Reasoning paths |
| Error rate | Tool selection accuracy |
| Resource usage | Context adherence |

**Key metrics to track for clawd**:
1. **Task completion rate** - Did it finish the task?
2. **Escalation rate** - How often does it need human help?
3. **Turn count** - How many Director decisions per task?
4. **Worker failure rate** - Which workers are unreliable?
5. **Token usage** - Are prompts staying lean?

---

**Logging Structure**:

```
memory/logs/
├── overnight-2026-01-30.log      # Main orchestrator log
├── compound-review.log           # Compound extraction log
├── sessions/
│   └── session-TIMESTAMP.json    # Structured session data
└── metrics/
    └── daily-summary-2026-01-30.md  # Aggregated metrics
```

**Session JSON format** (for replay/analysis):
```json
{
  "session_id": "uuid",
  "task": "A Bao A Qu debug",
  "start_time": "2026-01-30T23:00:00Z",
  "end_time": "2026-01-31T02:30:00Z",
  "status": "complete|escalate|halt",
  "turns": [
    {
      "turn": 1,
      "director_decision": {...},
      "worker": "builder",
      "worker_output": "...",
      "duration_ms": 45000
    }
  ],
  "metrics": {
    "total_turns": 12,
    "workers_used": ["builder", "inspector"],
    "escalations": 0,
    "errors": 1
  }
}
```

---

**Notification System**:

```bash
# scripts/notify.sh
#!/bin/bash
# Send notification on important events

MESSAGE="$1"
SEVERITY="${2:-info}"  # info, warn, error

# Option 1: macOS notification
osascript -e "display notification \"$MESSAGE\" with title \"Clawd $SEVERITY\" sound name \"Ping\""

# Option 2: Discord webhook (if configured)
if [[ -n "$DISCORD_WEBHOOK" ]]; then
  curl -H "Content-Type: application/json" \
       -d "{\"content\": \"**[$SEVERITY]** $MESSAGE\"}" \
       "$DISCORD_WEBHOOK"
fi

# Option 3: Pushover (for phone notifications)
if [[ -n "$PUSHOVER_TOKEN" ]]; then
  curl -s \
    --form-string "token=$PUSHOVER_TOKEN" \
    --form-string "user=$PUSHOVER_USER" \
    --form-string "message=$MESSAGE" \
    --form-string "title=Clawd $SEVERITY" \
    https://api.pushover.net/1/messages.json
fi
```

**Trigger points**:
- Task started
- Task completed successfully
- Escalation triggered (needs human)
- Halt triggered (consecutive failures)
- Morning summary (after overnight run)

---

**Rate Limit Handling**:

`claude -p` uses Pro subscription, which has rate limits.

**Mitigations**:
1. **Add delays**: Sleep between Director calls
   ```python
   # In orchestrator.py
   time.sleep(10)  # 10 seconds between turns
   ```

2. **Batch worker tasks**: Group related operations

3. **Exponential backoff**: On rate limit errors
   ```python
   def call_director_with_backoff(prompt, max_retries=5):
       for attempt in range(max_retries):
           try:
               return call_director(prompt)
           except RateLimitError:
               wait = 2 ** attempt * 60  # 1, 2, 4, 8, 16 minutes
               log(f"Rate limited, waiting {wait}s")
               time.sleep(wait)
       raise Exception("Rate limit exceeded after max retries")
   ```

4. **Fallback to local model**: Use Ollama for non-critical decisions
   ```python
   if rate_limited and not critical_decision:
       return call_local_model(prompt)
   ```

---

**Failure Recovery**:

| Failure | Recovery |
|---------|----------|
| Ollama crash | Watchdog restarts, orchestrator continues from checkpoint |
| Mac sleep | caffeinate prevents sleep; if happened, resume from checkpoint |
| Rate limit | Exponential backoff, then halt with alert |
| Worker infinite loop | Timeout after 5 minutes, kill and retry once |
| Orchestrator crash | launchd restart, resume from checkpoint |

---

**Morning Summary Script**:

```bash
# scripts/morning-summary.sh
#!/bin/bash
# Generate and send morning summary of overnight run

LOGFILE="$HOME/clawd/memory/logs/overnight-$(date +%Y-%m-%d).log"

if [[ -f "$LOGFILE" ]]; then
  # Extract key metrics
  COMPLETED=$(grep -c "Task complete" "$LOGFILE" || echo 0)
  ESCALATED=$(grep -c "ESCALATE" "$LOGFILE" || echo 0)
  ERRORS=$(grep -c "ERROR" "$LOGFILE" || echo 0)
  
  SUMMARY="Overnight Run Summary:
- Tasks completed: $COMPLETED
- Escalations: $ESCALATED  
- Errors: $ERRORS

Check full log: $LOGFILE"

  ./scripts/notify.sh "$SUMMARY" "info"
else
  ./scripts/notify.sh "No overnight log found - run may not have started" "warn"
fi
```

---

**Action Items**:
- [x] Create launchd plists ✅ (in artifacts)
- [ ] Add structured session logging to orchestrator
- [ ] Create notify.sh with Discord/Pushover support
- [ ] Add morning-summary.sh
- [ ] Add rate limit handling to orchestrator
- [ ] Test full overnight run cycle

---

### 🟢 Low Priority / Nice-to-Have

#### 8. Agent Sandboxing
**Status**: Future consideration

Workers currently run with full user permissions. If containerizing later:
- Use non-root user in container
- Don't mount host filesystem
- Don't expose Docker socket
- Whitelist specific commands

Not urgent since clawd runs locally on trusted hardware.

---

#### 9. Tailscale for Remote Monitoring
**Status**: Optional enhancement

If want to check clawd status from phone while it runs overnight:
```bash
# On clawd machine
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Access orchestrator logs remotely via Tailscale IP
```

Not needed for core functionality.

---

#### 10. PRD-to-Tasks Pipeline
**Status**: Pattern identified, low priority

From Ryan Carson's setup - formalized task definition:
```
report.md → PRD → prd.json (tasks) → execution loop
```

Current clawd uses free-form task .md files. Could formalize later if needed.

---

## Key Insights from Research

### Architecture Principles

1. **Hybrid models catch blindspots** - Claude for decisions, local models for execution
2. **Sequential over parallel** - Agents conflict less when run one at a time
3. **File-based state** - Survives crashes, human-inspectable, git-friendly
4. **Separation of concerns** - Technical prompts vs workflow Skills
5. **Memory consolidation** - Important learnings migrate from active to passive

### Security Principles

1. **Director as security boundary** - Opus 4.5's injection resistance protects the system
2. **Workers are sandboxed by design** - Only receive sanitized instructions
3. **No exposed network surface** - Local-only architecture
4. **Principle of least privilege** - Workers don't need all capabilities

### Operational Principles

1. **Compound learning** - Every session improves the next via Scribe consolidation
2. **Graceful degradation** - Checkpoints enable resume after any failure
3. **Observable state** - All decisions logged, all state in files
4. **Token efficiency** - Lean prompts, tiered memory, search over bulk loading

---

## Sources & References

| Article | Author | Key Takeaway |
|---------|--------|--------------|
| "How to build an agent that never forgets" | @rohit4verse | Three-layer memory hierarchy, memory decay |
| "10 ways to hack a vibecoder's clawdbot" | (security) | Prompt injection vectors, need for sandboxing |
| "How to fix your Clawdbot in 1 day" | @0thernet | Zo Computer pitch, Agent Client Protocol mention |
| "How to make your agent learn and ship while you sleep" | @ryancarson | Compound Engineering, two-phase nightly loop |
| "Most of what you're seeing is overhyped" | @eyad_khrais | Realistic assessment, Opus 4.5 injection resistance |
| "qmd-skill" | levineam | Local markdown search, 95% token reduction claim |
| "Your Moltbot is probably exposed" | (security) | Hardening checklist, Tailscale setup |
| "We gave Moltbot supermemory" | @DhravyaShah | Passive vs active memory problem |
| "Separation of Responsibilities: MCP vs Skills" | @dani_avila7 | Technical contracts vs usage intelligence |
| "How to Connect Kimi K2.5 to ClawdBot" | @KimiProduct | Kimi K2.5 as API-based model option for Moltbot |
| "Compound Engineering: How Every Codes With Agents" | Every Inc. | 80% plan/review, 20% work - the full methodology |
| "compound-engineering-plugin" | @kieranklaassen | Plan→Work→Review→Compound loop, learning templates |
| "Learning from Every's Compound Engineering" | Will Larson | Compound step creates the compounding mechanism |
| "Writing a good CLAUDE.md" | HumanLayer | Keep CLAUDE.md minimal, use pointers not copies |
| "Skill authoring best practices" | Anthropic Docs | 500 lines max, progressive disclosure, description matters |
| "Equipping agents for the real world with Agent Skills" | Anthropic Eng | Skills as onboarding guides, three-tier loading |
| "Claude Agent Skills: A First Principles Deep Dive" | Lee Han Chung | Skills are prompt injection, not code execution |
| "claude-code-showcase" | Chris Wiles | Practical skills structure, hooks, agent patterns |
| "Context length - Ollama Docs" | Ollama | Default 4096 too small for agents, set to 64K+ |
| "Ollama VRAM Requirements 2026" | LocalLLM.in | Q4_K_M sweet spot, Flash Attention free boost |
| "Speed Up Local LLMs by Tuning Context" | Windows Forum | Context vs VRAM tradeoff, 100% GPU critical |
| "tobi/qmd" | Tobi | BM25 + vector + reranking, all local |
| "15 best practices for AI agents" | n8n Blog | Escalation tracking, human-in-loop triggers |
| "AI Agent Monitoring" | UptimeRobot | System health + agent behavior = full visibility |
| "AI Agent Observability" | OpenTelemetry | Standardized metrics, traces, logs for agents |
| "Monitor AI agents" | Datadog | Non-linear execution graphs, decision tracing |

---

## Next Actions (Prioritized)

### When PC arrives:
1. [x] ~~Research model selection~~ ✅ COMPLETE
2. [x] ~~Research Ollama context management~~ ✅ COMPLETE
3. [ ] Set up Ollama on PC
4. [ ] Create custom model with 16K context: `qwen-coder-16k:7b`
5. [ ] Pull recommended models: `qwen2.5-coder:7b`, `deepseek-r1:7b`
6. [ ] Enable Flash Attention: `export OLLAMA_FLASH_ATTENTION=1`
7. [ ] Test VRAM usage with `nvidia-smi` 
8. [ ] Benchmark speed on sample coding tasks
9. [ ] Run first real task (A Bao A Qu Link Summon debug)

### Before first overnight run:
10. [x] ~~Research Compound Engineering pattern~~ ✅ COMPLETE
11. [x] ~~Research Skills architecture~~ ✅ COMPLETE
12. [x] ~~Research qmd for memory search~~ ✅ COMPLETE
13. [x] ~~Research overnight observability~~ ✅ COMPLETE
14. [x] ~~Create compound-review.sh~~ ✅ COMPLETE (in artifacts)
15. [x] ~~Create compound templates~~ ✅ COMPLETE (in artifacts)
16. [x] ~~Create launchd plists~~ ✅ COMPLETE (in artifacts)
17. [ ] Audit and refactor agent .md files (separate Skills from prompts)
18. [ ] Add basic input sanitization to orchestrator
19. [ ] Add structured session logging to orchestrator
20. [ ] Create notify.sh for escalation alerts

### Quality of life:
21. [ ] Install Bun and qmd, index memory/ folder
22. [ ] Add cron for qmd index updates
23. [ ] Create morning-summary.sh
24. [ ] Document threat model in repo

---

## Quick Reference

### Commands
```bash
# Run task interactively
claude -p "Execute task in memory/first-task.md" --dangerously-skip-permissions

# Run task autonomously (needs API key)
python3 scripts/orchestrator.py memory/first-task.md

# Resume from checkpoint
python3 scripts/orchestrator.py --resume

# Test worker
./scripts/call-agent.sh builder "implement function X"

# Check Ollama status
ollama list
ollama ps
```

### File Locations
```
~/clawd/
├── CLAUDE.md              # Project context (passive memory)
├── agents/*.md            # Agent Skills + prompts
├── scripts/orchestrator.py # Core loop
├── memory/
│   ├── tasks/             # Task definitions
│   ├── checkpoints/       # State snapshots
│   └── logs/              # Session logs
└── docs/                  # Architecture docs
```

### Hardware
| Machine | Specs | Role |
|---------|-------|------|
| Mac M2 | 24GB RAM | Director (claude -p), development |
| PC | 32GB RAM, RTX 3060 12GB | Ollama workers |

---

*This document is the single source of truth for clawd research. Update after each session.*
