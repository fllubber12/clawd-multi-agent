# Hardware Configuration

## Current Setup

### Mac (Primary - Current)
| Component | Spec |
|-----------|------|
| Model | Mac (M2 chip) |
| RAM | 24GB Unified Memory |
| Available for LLMs | ~5GB (after macOS overhead) |
| Max Model | qwen3:14b (~9GB) ⚠️ |

**Constraints**:
- macOS uses ~19GB baseline
- Must close heavy apps (Slack, Safari) before runs
- Cannot run qwen3:32b reliably

### PC (Secondary - Pre-Upgrade)
| Component | Spec |
|-----------|------|
| CPU | Intel i5-12400F |
| RAM | 8GB DDR4 |
| GPU | RTX 3050 (8GB VRAM) |
| Max Model | qwen3:8b only |

**Status**: Insufficient for meaningful LLM work

---

## Planned Upgrade

### Parts Ordered
| Part | Price | Status |
|------|-------|--------|
| ASUS Dual RTX 3060 V2 OC 12GB | $349.99 | In cart |
| Corsair Vengeance 32GB DDR4 3200 | $259.99 | In cart |
| **Total** | **$609.98** | |

**Delivery**: GPU arrives Jan 29, RAM arrives Jan 30

### Post-Upgrade PC Specs
| Component | Spec |
|-----------|------|
| CPU | Intel i5-12400F (unchanged) |
| RAM | 32GB DDR4-3200 |
| GPU | RTX 3060 12GB VRAM |
| Max Model | qwen3:14b in VRAM ✅ |

**Benefits**:
- Dedicated 12GB VRAM for LLM inference
- Much faster than Mac's unified memory approach
- 32GB system RAM for other tasks
- Can run Ollama overnight without memory pressure

---

## Pre-Installation Checklist

### Before Installing GPU
- [ ] **Check PSU wattage** (need ≥550W)
  - Open case
  - Find label on PSU
  - Look for wattage number
- [ ] **If PSU < 550W**: Buy upgrade first (~$50-70)

### Installation Order
1. Install RAM first (safer, no power concerns)
2. Verify RAM works (boot, check Task Manager)
3. Install GPU second
4. Install NVIDIA drivers
5. Install Ollama for Windows
6. Pull qwen3:14b
7. Test inference

---

## Final Architecture (Post-Upgrade)

```
┌─────────────────────────────────────────────────────────────────┐
│                           YOUR MAC                              │
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │  Telegram   │    │   Claude    │    │  Monitor/   │         │
│  │   Client    │    │    .ai      │    │   Alerts    │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                                      ▲                │
│         │              Network                 │                │
│         └──────────────────────────────────────┘                │
│                            │                                    │
└────────────────────────────┼────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                           YOUR PC                               │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                      Clawdbot                            │   │
│  │                                                          │   │
│  │  Director ──────► Claude API (cloud)                     │   │
│  │      │                                                   │   │
│  │      ▼                                                   │   │
│  │  Workers ───────► Ollama (local)                         │   │
│  │  (6 agents)         │                                    │   │
│  │                     ▼                                    │   │
│  │               qwen3:14b                                  │   │
│  │               (in 12GB VRAM)                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Hardware:                                                      │
│  • i5-12400F (CPU)                                             │
│  • 32GB DDR4 (System RAM)                                      │
│  • RTX 3060 12GB (GPU/VRAM)                                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Environment Variables (Post-Setup)

### On PC (where Clawdbot runs)
```bash
# Claude API for Director
export ANTHROPIC_API_KEY="sk-ant-api03-..."

# Ollama configuration
export OLLAMA_HOST="http://localhost:11434"
export OLLAMA_NUM_PARALLEL=2
export OLLAMA_KEEP_ALIVE=60m
export OLLAMA_MAX_QUEUE=100
```

### Verify Setup Commands
```bash
# Check GPU is recognized
nvidia-smi

# Check Ollama is running
curl http://localhost:11434/api/tags

# Check model fits in VRAM
ollama run qwen3:14b "test"
nvidia-smi  # Should show ~9GB VRAM used

# Check Claude API
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "content-type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"claude-sonnet-4-20250514","max_tokens":50,"messages":[{"role":"user","content":"OK"}]}'
```

---

## Fallback Options

### If GPU Installation Fails
- Continue using Mac with qwen3:14b
- Close apps before runs
- Accept slower inference

### If PC PSU is Insufficient
- Budget option: Use Mac as primary
- Proper fix: Buy 650W PSU ($50-70)
- Recommended: Corsair CV650, EVGA 650 BQ

### If qwen3:14b Has Issues
- Try qwen3:8b (smaller but faster)
- Adjust parameters (lower context, temperature)
- Fall back to all-Claude-API (costs money but works)
