#!/bin/bash
# call-agent.sh - Call a worker agent via Ollama API
# Usage: ./call-agent.sh <agent_name> "<task_prompt>" [max_tokens]
#
# Example: ./call-agent.sh builder "Write a factorial function in Python"

AGENT_NAME="$1"
TASK_PROMPT="$2"
MAX_TOKENS="${3:-1500}"

if [ -z "$AGENT_NAME" ] || [ -z "$TASK_PROMPT" ]; then
    echo "Usage: $0 <agent_name> \"<task_prompt>\" [max_tokens]"
    echo "Agents: architect, scout, builder, refactorer, inspector, scribe"
    exit 1
fi

AGENT_FILE="$HOME/clawd/agents/${AGENT_NAME}.md"

if [ ! -f "$AGENT_FILE" ]; then
    echo "Error: Agent file not found: $AGENT_FILE"
    exit 1
fi

# Capitalize agent name (macOS compatible)
AGENT_NAME_CAP=$(echo "$AGENT_NAME" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')

# Extract condensed identity from agent file (first ~50 lines for system context)
SYSTEM_CONTEXT=$(head -100 "$AGENT_FILE" | grep -v '^#' | grep -v '^$' | head -30)

# Construct the full prompt (using heredoc for safety)
# /nothink at START forces non-thinking mode in qwen3
FULL_PROMPT="/nothink
[SYSTEM: You are the ${AGENT_NAME_CAP} agent]

${SYSTEM_CONTEXT}

---

TASK: ${TASK_PROMPT}

IMPORTANT: Output ONLY your deliverable. No explanations, no thinking, no preamble. Just the result."

# Call Ollama API
response=$(curl -s http://localhost:11434/api/generate -d @- << EOJSON
{
  "model": "qwen3:14b",
  "prompt": $(printf '%s' "$FULL_PROMPT" | jq -Rs .),
  "stream": false,
  "options": {
    "temperature": 0.5,
    "top_p": 0.85,
    "num_predict": $MAX_TOKENS
  }
}
EOJSON
)

# Extract response - qwen3 thinking mode puts content in 'thinking' field
# Concatenate both: thinking (reasoning) + response (final answer)
THINKING=$(echo "$response" | jq -r '.thinking // ""')
RESP=$(echo "$response" | jq -r '.response // ""')

# If response is empty but thinking exists, extract code/output from thinking
if [ -z "$RESP" ] || [ "$RESP" = "null" ]; then
    # Try to extract code blocks from thinking
    if echo "$THINKING" | grep -q '```'; then
        echo "$THINKING" | sed -n '/```/,/```/p'
    else
        echo "$THINKING"
    fi
else
    echo "$RESP"
fi
