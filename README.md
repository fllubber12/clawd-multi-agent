# Clawd Multi-Agent Pipeline

A 7-agent autonomous coding system using Claude Code as Director and Ollama (qwen3:14b) for worker agents.

## Architecture

```
Director (Claude Opus via Claude Code)
    ↓ HTTP API calls
Worker Agents (qwen3:14b via Ollama)
    - Architect: System design
    - Scout: Research & feasibility
    - Builder: Implementation
    - Refactorer: Code quality
    - Inspector: Testing & verification
    - Scribe: State management
```

## Quick Start

1. **Start Ollama**
   ```bash
   ollama serve
   ```

2. **Verify model**
   ```bash
   ollama list  # Should show qwen3:14b
   ```

3. **Test an agent**
   ```bash
   ./call-agent.sh builder "Write a hello world function"
   ```

## Directory Structure

```
~/clawd/
├── agents/       # Agent system prompts
├── docs/         # Documentation & guides
├── memory/       # State files & checkpoints
├── workspace/    # Working directory for tasks
└── call-agent.sh # Helper to call Ollama agents
```

## Documentation

- [Claude Code Instructions](docs/CLAUDE-CODE-INSTRUCTIONS.md) - How to use this repo
- [Next Steps](docs/NEXT-STEPS.md) - Implementation roadmap
- [Operations Guide](docs/multi-agent-operations-guide.md) - Operational parameters
- [Failure Mitigation](docs/multi-agent-failure-mitigation-guide.md) - Error handling
- [Pre-Flight Checklist](docs/pre-flight-checklist.md) - Validation before runs

## Status

- [x] Agent definitions complete
- [x] Ollama integration working
- [x] Director-as-Orchestrator pattern implemented
- [ ] Full overnight run tested
- [ ] PC hardware upgrade (arriving Jan 29-30)

## Hardware

- Current: Mac M2 24GB (qwen3:14b)
- Planned: PC with RTX 3060 12GB + 32GB RAM
