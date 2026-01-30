# clawd-env.sh - Environment setup for clawd multi-agent system
# Add this to your ~/.bashrc or ~/.zshrc, or source it before running clawd
#
# Usage: source ~/clawd/clawd-env.sh

# ============================================================================
# Ollama Configuration
# ============================================================================

# Enable Flash Attention (reduces VRAM, increases speed, zero quality loss)
export OLLAMA_FLASH_ATTENTION=1

# Default context length for models (can be overridden per-model)
export OLLAMA_CONTEXT_LENGTH=16384

# Keep models loaded in VRAM (prevents reload between calls)
export OLLAMA_KEEP_ALIVE=24h

# Number of parallel requests (1 = sequential, safer for memory)
export OLLAMA_NUM_PARALLEL=1

# ============================================================================
# Clawd Configuration  
# ============================================================================

# Default model for workers (use the 16K context variant)
export CLAWD_MODEL="qwen-coder-16k"

# Clawd home directory
export CLAWD_HOME="$HOME/clawd"

# Log directory
export CLAWD_LOGS="$CLAWD_HOME/memory/logs"

# Alerts directory (for escalations)
export CLAWD_ALERTS="$CLAWD_HOME/memory/alerts"

# ============================================================================
# Paths
# ============================================================================

# Add Bun to path (for qmd)
export PATH="$HOME/.bun/bin:$PATH"

# ============================================================================
# Aliases (optional convenience)
# ============================================================================

# Quick model test
alias clawd-test='ollama run $CLAWD_MODEL "Say hello and confirm you are ready"'

# Check what's loaded in Ollama
alias clawd-status='ollama ps'

# Watch VRAM usage
alias clawd-vram='watch -n 1 nvidia-smi'

# Quick qmd search
alias clawd-search='qmd search -c clawd-memory'

# ============================================================================
# Startup Check
# ============================================================================

echo "Clawd environment loaded:"
echo "  CLAWD_MODEL: $CLAWD_MODEL"
echo "  OLLAMA_FLASH_ATTENTION: $OLLAMA_FLASH_ATTENTION"
echo "  OLLAMA_CONTEXT_LENGTH: $OLLAMA_CONTEXT_LENGTH"
