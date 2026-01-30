#!/bin/bash
# pc-first-boot-setup.sh
# Run this on your new PC after hardware is installed
#
# Usage: chmod +x pc-first-boot-setup.sh && ./pc-first-boot-setup.sh

set -euo pipefail

echo "=============================================="
echo "Clawd PC Setup - First Boot"
echo "=============================================="

# ============================================================================
# 1. System Checks
# ============================================================================

echo ""
echo "[1/8] Checking system..."

# Check for NVIDIA GPU
if command -v nvidia-smi &> /dev/null; then
    echo "✓ NVIDIA driver detected"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
else
    echo "✗ nvidia-smi not found - install NVIDIA drivers first"
    echo "  Ubuntu: sudo apt install nvidia-driver-535"
    exit 1
fi

# Check RAM
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
echo "✓ RAM: ${TOTAL_RAM}GB"

if [[ $TOTAL_RAM -lt 24 ]]; then
    echo "⚠ Warning: Less than 24GB RAM detected"
fi

# ============================================================================
# 2. Install Ollama
# ============================================================================

echo ""
echo "[2/8] Installing Ollama..."

if command -v ollama &> /dev/null; then
    echo "✓ Ollama already installed"
    ollama --version
else
    curl -fsSL https://ollama.com/install.sh | sh
    echo "✓ Ollama installed"
fi

# ============================================================================
# 3. Pull Base Model
# ============================================================================

echo ""
echo "[3/8] Pulling qwen2.5-coder:7b..."
echo "  (This may take 5-10 minutes on first run)"

ollama pull qwen2.5-coder:7b

echo "✓ Model downloaded"

# ============================================================================
# 4. Create 16K Context Variant
# ============================================================================

echo ""
echo "[4/8] Creating 16K context variant..."

MODELFILE_DIR="$HOME/clawd"
mkdir -p "$MODELFILE_DIR"

cat > "$MODELFILE_DIR/Modelfile.qwen-coder-16k" << 'EOF'
FROM qwen2.5-coder:7b
PARAMETER num_ctx 16384
PARAMETER temperature 0.3
PARAMETER stop "<|endoftext|>"
PARAMETER stop "<|im_end|>"
EOF

ollama create qwen-coder-16k -f "$MODELFILE_DIR/Modelfile.qwen-coder-16k"

echo "✓ qwen-coder-16k created"

# ============================================================================
# 5. Set Environment Variables
# ============================================================================

echo ""
echo "[5/8] Setting up environment..."

# Add to bashrc if not already present
BASHRC="$HOME/.bashrc"
if ! grep -q "OLLAMA_FLASH_ATTENTION" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'EOF'

# Clawd / Ollama environment
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_CONTEXT_LENGTH=16384
export OLLAMA_KEEP_ALIVE=24h
export CLAWD_MODEL="qwen-coder-16k"
export CLAWD_HOME="$HOME/clawd"
export PATH="$HOME/.bun/bin:$PATH"
EOF
    echo "✓ Environment variables added to ~/.bashrc"
else
    echo "✓ Environment variables already in ~/.bashrc"
fi

# Source for current session
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_CONTEXT_LENGTH=16384

# ============================================================================
# 6. Test Model
# ============================================================================

echo ""
echo "[6/8] Testing model..."

TEST_RESPONSE=$(ollama run qwen-coder-16k "Say 'Hello, clawd is ready' and nothing else" 2>&1)
echo "  Model response: $TEST_RESPONSE"

if [[ "$TEST_RESPONSE" == *"ready"* ]] || [[ "$TEST_RESPONSE" == *"Hello"* ]]; then
    echo "✓ Model responding correctly"
else
    echo "⚠ Model response unexpected, but may still work"
fi

# ============================================================================
# 7. Check VRAM Usage
# ============================================================================

echo ""
echo "[7/8] Checking VRAM usage..."

sleep 2  # Let model load fully
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader

VRAM_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1)
echo "✓ VRAM used: ${VRAM_USED}MB"

if [[ $VRAM_USED -gt 10000 ]]; then
    echo "⚠ Warning: Using more than 10GB VRAM - may be tight for 16K context"
fi

# ============================================================================
# 8. Install Bun and qmd (optional)
# ============================================================================

echo ""
echo "[8/8] Installing Bun and qmd (for memory search)..."

if command -v bun &> /dev/null; then
    echo "✓ Bun already installed"
else
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
    echo "✓ Bun installed"
fi

# Install qmd
if command -v qmd &> /dev/null; then
    echo "✓ qmd already installed"
else
    bun install -g https://github.com/tobi/qmd
    echo "✓ qmd installed"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "=============================================="
echo "Setup Complete!"
echo "=============================================="
echo ""
echo "Installed:"
echo "  • Ollama with qwen-coder-16k (16K context)"
echo "  • Flash Attention enabled"
echo "  • Bun + qmd for memory search"
echo ""
echo "Next steps:"
echo "  1. Source environment: source ~/.bashrc"
echo "  2. Clone clawd repo: git clone https://github.com/flubber12/clawd-multi-agent ~/clawd"
echo "  3. Update call-agent.sh model to 'qwen-coder-16k'"
echo "  4. Set up qmd: qmd collection add ~/clawd/memory --name clawd-memory"
echo "  5. Test: ./scripts/call-agent.sh builder 'print hello world in python'"
echo ""
echo "Run 'clawd-test' to verify model is working"
