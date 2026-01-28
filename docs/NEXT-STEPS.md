# Implementation Roadmap - Next Steps

## Phase 1: Hardware Setup (When Parts Arrive)

**Timeline**: ~1-2 hours after delivery

### 1.1 Pre-Installation Verification
```bash
# On Windows PC, check PSU wattage
# Open case, look at PSU label, find wattage number
# REQUIRED: ≥550W for RTX 3060
```

If PSU < 550W:
- **STOP** - need PSU upgrade ($50-70 for 650W unit)
- Recommended: EVGA 650 BQ or Corsair CV650

### 1.2 RAM Installation
1. Power off PC, unplug
2. Open case
3. Remove existing 8GB RAM (likely 1 or 2 sticks)
4. Install new 2x16GB in slots A2 and B2 (consult motherboard manual)
5. Close case, power on
6. Verify in Task Manager → Performance → Memory shows 32GB

### 1.3 GPU Installation
1. Power off PC, unplug
2. Remove RTX 3050:
   - Unscrew bracket
   - Release PCIe latch
   - Disconnect power cable
3. Install RTX 3060:
   - Same PCIe x16 slot
   - Secure bracket
   - Connect 8-pin power cable
4. Close case, power on
5. Install latest NVIDIA drivers from nvidia.com

### 1.4 Ollama Setup (Windows)
```powershell
# Download and install Ollama for Windows
# https://ollama.com/download/windows

# After install, open PowerShell:
ollama --version

# Pull the model (will take 10-20 minutes)
ollama pull qwen3:14b

# Test it works
ollama run qwen3:14b "Say hello and confirm you're working"

# Check it fits in VRAM (should show ~9GB used)
nvidia-smi
```

---

## Phase 2: Clawdbot Configuration

**Timeline**: 2-4 hours

### 2.1 Read Implementation Guide
```
Open: clawdbot-implementation-guide.md
```
This covers:
- Config file format translation
- Hybrid model routing
- Orchestration logic
- State management
- Error handling

### 2.2 Create Clawdbot Config Structure
```
~/.clawdbot/
├── config.yaml           # Main config
├── agents/
│   ├── director.yaml     # Uses Claude API
│   ├── architect.yaml    # Uses Ollama
│   ├── scout.yaml
│   ├── builder.yaml
│   ├── refactorer.yaml
│   ├── inspector.yaml
│   └── scribe.yaml
├── state/
│   └── checkpoints/      # Auto-created during runs
└── logs/
    └── sessions/         # Auto-created during runs
```

### 2.3 Configure API Keys
```bash
# Add to ~/.bashrc or ~/.zshrc (Mac) or Environment Variables (Windows)

# For Director agent (Claude API)
export ANTHROPIC_API_KEY="sk-ant-api03-..."

# Verify it works
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "content-type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"claude-sonnet-4-20250514","max_tokens":50,"messages":[{"role":"user","content":"Say OK"}]}'
```

### 2.4 Configure Ollama Endpoint
```bash
# If running on same machine
export OLLAMA_HOST="http://localhost:11434"

# If running on PC, accessed from Mac
export OLLAMA_HOST="http://<PC_IP>:11434"

# Test connectivity
curl $OLLAMA_HOST/api/tags
```

---

## Phase 3: Pre-Flight Validation

**Timeline**: 35 minutes (per pre-flight-checklist.md)

### 3.1 Infrastructure Check (5 min)
- [ ] Ollama running and responsive
- [ ] qwen3:14b loaded successfully
- [ ] Claude API key valid
- [ ] Sufficient disk space (>10GB free)
- [ ] Network connectivity stable

### 3.2 Single Agent Test (10 min)
- [ ] Director can spawn and communicate
- [ ] Builder can read/write files
- [ ] Inspector can run tests
- [ ] Scribe can create checkpoints

### 3.3 Multi-Agent Coordination Test (15 min)
- [ ] Director → Architect handoff works
- [ ] Parallel Scout + Builder doesn't conflict
- [ ] Checkpoint/recovery cycle works

### 3.4 Recovery Test (5 min)
- [ ] Simulate crash mid-task
- [ ] Verify Scribe checkpoint loads
- [ ] Verify Director resumes correctly

---

## Phase 4: First Overnight Run

**Timeline**: Define task, run overnight, review in morning

### 4.1 Task Definition
Create task file following template:

```markdown
## Task: [Clear, specific objective]

**Objective**: [One sentence]

**Success Criteria**:
- [ ] Criterion 1 (measurable)
- [ ] Criterion 2 (measurable)
- [ ] All existing tests pass

**Scope Boundaries**:
- DO: [specific allowed actions]
- DO NOT: [explicit exclusions]

**Abort Conditions**:
- [When to stop and escalate]

**Starting Point**:
- Repository: [path]
- Branch: [name]
- Entry file: [path]
```

### 4.2 Suggested First Task
```markdown
## Task: Fix A Bao A Qu Link Summon Failure

**Objective**: Debug why step 17 fails in ygo-combo-pipeline

**Success Criteria**:
- [ ] Root cause identified and documented
- [ ] Fix implemented
- [ ] All 237 existing tests pass
- [ ] New test case covers the bug

**Scope Boundaries**:
- DO: Investigate and fix the specific Link Summon failure
- DO: Add diagnostic logging if helpful
- DO NOT: Refactor unrelated code
- DO NOT: Change ygopro-core bindings
- DO NOT: Modify test infrastructure

**Abort Conditions**:
- If bug is in ygopro-core itself (not our code)
- If fix requires >5 files modified
- If 3+ different approaches all fail

**Starting Point**:
- Repository: ~/projects/ygo-combo-pipeline
- Branch: main (create fix/link-summon-step17)
- Entry file: src/engine/link_summon.py
```

### 4.3 Launch Sequence
```bash
# 1. Ensure clean state
cd ~/projects/ygo-combo-pipeline
git status  # Should be clean
git checkout -b fix/link-summon-step17

# 2. Start Ollama watchdog (optional but recommended)
# See pre-flight-checklist.md for script

# 3. Launch Clawdbot with task
clawdbot run --task ./tasks/fix-link-summon.md --agents ./agents/

# 4. Monitor briefly, then sleep
# Check Telegram for alerts
```

### 4.4 Morning Review Checklist
```markdown
## Morning Review - [DATE]

### Quick Checks
- [ ] Any IMMEDIATE alerts?
- [ ] Clawdbot still running or completed?
- [ ] Test suite status?

### If Completed Successfully
- [ ] Review changes: `git diff main`
- [ ] Run tests manually: `pytest`
- [ ] Check for security issues (hardcoded creds, etc.)
- [ ] Review Scribe's summary

### If Failed/Stopped
- [ ] Check alerts/escalation files
- [ ] Review last checkpoint
- [ ] Identify failure point
- [ ] Decide: resume, restart, or manual fix

### Final
- [ ] Merge or discard branch
- [ ] Note lessons learned
- [ ] Update trust scores if needed
```

---

## Phase 5: Iteration & Improvement

After first successful run:

1. **Tune parameters** based on observed behavior
2. **Adjust agent prompts** if any showed weaknesses
3. **Add more tasks** to the queue
4. **Consider scaling** (longer runs, harder tasks)

---

## Troubleshooting Quick Reference

| Problem | Solution |
|---------|----------|
| Ollama unresponsive | `ollama stop && ollama serve` |
| Model won't load | Check VRAM: `nvidia-smi` |
| API key rejected | Verify with curl test above |
| Agent looping | Check Director's halt logic |
| Context overflow | Reduce checkpoint verbosity |
| Tests fail on "complete" code | Increase Inspector rigor |

---

## Contact Points

- **Clawdbot issues**: Check Clawdbot documentation
- **Ollama issues**: https://github.com/ollama/ollama/issues
- **Model behavior**: Try adjusting temperature/top_p
- **Architecture questions**: Reference the transcripts in /mnt/transcripts/
