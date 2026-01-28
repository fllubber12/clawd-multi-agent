# Session History & Key Decisions

## Conversation Timeline

### Session 1: Ollama + Clawdbot Setup
**Transcript**: `2026-01-27-23-49-44-ollama-clawdbot-setup-troubleshooting.txt`

- Initial setup of Ollama on Mac
- Troubleshooting tool-calling issues
- Model selection for Apple Silicon

### Session 2: Multi-Agent Research (Initial)
**Transcript**: `2026-01-27-23-55-47-multi-agent-orchestration-research.txt`

- Research on multi-agent patterns
- Initial architecture ideas
- Failure mode analysis

### Session 3: Team Design Research
**Transcript**: `2026-01-27-23-58-48-multi-agent-team-design-research.txt`

- Team composition theory
- Role specialization patterns
- Initial role proposals: Strategist, Refactorer, Organizer, Researcher, Nitpicker, Leader
- Framework comparisons (CrewAI, Google ADK, IBM)

### Session 4: Team Role Deep Dive
**Transcript**: `2026-01-28-00-00-22-multi-agent-team-role-research.txt`

**Key Decisions**:
- Optimal team size: 7 agents
- Trust scoring system (1-10 scale)
- Role definitions finalized

**7 Agent Roles Established**:
1. Director - Orchestrator (highest authority)
2. Architect - System design
3. Scout - Research & information
4. Builder - Code implementation
5. Refactorer - Code cleanup
6. Inspector - Testing & verification
7. Scribe - Documentation & state

### Session 5: Operations Guide
**Transcript**: `2026-01-28-00-03-59-multi-agent-orchestration-operations.txt`

**Key Decisions**:
- Resource allocation strategy
- Execution patterns (sequential default, limited parallel)
- Meeting protocols
- Emergency escalation procedures
- Communication standards

### Session 6: Decision Framework & Implementation
**Transcript**: `2026-01-28-00-25-44-multi-agent-decision-framework-implementation.txt`

**Key Decisions**:
- Decision authority framework:
  - Factual decisions: Evidence wins
  - Design decisions: Domain authority + Director approval
  - Process decisions: Director's call
- Failure mitigation strategies
- All 7 agent definition files created

### Session 7: Final Research & Hardware Issues
**Transcript**: `2026-01-28-17-25-25-multi-agent-pipeline-final-research-and-setup.txt`

**Key Discoveries (9 Critical Factors)**:
1. Inter-agent prompt injection risk
2. Qwen3 configuration parameters
3. Ollama long-running stability issues
4. Smoke test protocol (35 min pre-flight)
5. Observability & logging spec
6. Sub-agent parallelism risks
7. Task scope definition importance
8. Context poisoning warning
9. Morning review protocol

**Key Decisions**:
- Hybrid model architecture: Director = Claude Sonnet, Workers = qwen3
- Downgrade from qwen3:32b to qwen3:14b (memory constraints)

### Session 8: PC Upgrade Decision (Current)
**This Conversation**

**Key Decisions**:
- PC upgrade chosen over Mac Mini M4
- Parts ordered: RTX 3060 12GB + 32GB DDR4
- Total cost: $609.98
- PC will become primary compute, Mac for monitoring

---

## Key Design Decisions & Rationale

### Why 7 Agents?
- Research shows 3-7 is optimal range
- Smaller teams lack coverage
- Larger teams have coordination overhead
- 7 provides: planning, execution, review, documentation without gaps

### Why Hybrid Models (Claude + Ollama)?
- Different models catch each other's blindspots
- Director needs superior judgment (Claude Sonnet)
- Workers need high throughput at low cost (local Ollama)
- Anthropic's own systems use "Opus as lead, Sonnet as subagents"

### Why qwen3:14b Not 32b?
- Mac has 24GB unified memory
- macOS uses ~19GB at baseline
- Only ~5GB free even with apps closed
- qwen3:32b needs ~20GB → crashes
- qwen3:14b needs ~9GB → fits comfortably

### Why Sequential Over Parallel?
- Anthropic research: "parallel sub-agents often contradict each other"
- Sequential ensures consistency
- Only parallelize when: different files, no dependencies, independent verification

### Why PC Upgrade Over Mac Mini?
- Mac Mini M4 16GB is DOWNGRADE from current 24GB Mac
- PC upgrade provides DEDICATED 12GB VRAM
- RTX 3060 faster for inference than unified memory
- Future upgradeable (can add better GPU later)
- Keep Mac for daily use + monitoring

---

## Files Created Across Sessions

### Guides
| File | Created In | Purpose |
|------|-----------|---------|
| `multi-agent-research.md` | Session 2 | Initial research findings |
| `team-role-analysis.md` | Session 4 | Role design rationale |
| `multi-agent-operations-guide.md` | Session 5 | Operational parameters |
| `multi-agent-failure-mitigation-guide.md` | Session 6 | Failure handling |
| `pre-flight-checklist.md` | Session 7 | Validation procedures |
| `clawdbot-implementation-guide.md` | Session 7 | Wiring into Clawdbot |

### Agent Definitions
| File | Created In | Model |
|------|-----------|-------|
| `agents/README.md` | Session 6 | N/A (overview) |
| `agents/director.md` | Session 6 | Claude Sonnet API |
| `agents/architect.md` | Session 6 | qwen3:14b |
| `agents/scout.md` | Session 6 | qwen3:14b |
| `agents/builder.md` | Session 6 | qwen3:14b |
| `agents/refactorer.md` | Session 6 | qwen3:14b |
| `agents/inspector.md` | Session 6 | qwen3:14b |
| `agents/scribe.md` | Session 6 | qwen3:14b |

---

## Open Questions / Future Considerations

1. **Telegram Integration**: How exactly will Mac monitor PC via Telegram?
   - Clawdbot may have built-in support
   - May need simple bot bridge

2. **Cost Monitoring**: Claude API for Director has costs
   - Director makes decisions, not code (low tokens)
   - Should still monitor usage

3. **Scaling**: After first success, consider:
   - Longer runs
   - Harder tasks
   - Multiple parallel pipelines?

4. **Ollama Watchdog**: May need auto-restart script
   - GitHub issues report hangs after ~30min
   - Script in pre-flight-checklist.md

---

## Project Context

### Target Application
**ygo-combo-pipeline**: Yu-Gi-Oh! combo enumeration engine
- Uses ygopro-core via CFFI bindings
- 237 unit tests currently
- Known bug: A Bao A Qu Link Summon fails at step 17
- This is the intended first overnight task

### Zach's Background
- PhD candidate in biochemistry/biotechnology
- Strong technical expertise in synthetic biology + computation
- Methodical, prefers "over-engineered" solutions
- Building this system to work while he sleeps
