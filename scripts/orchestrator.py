#!/usr/bin/env python3
"""
Clawd Orchestrator - Coordinates Director (Claude API) and Workers (Ollama)

Usage:
    python scripts/orchestrator.py [task_file]
    python scripts/orchestrator.py memory/smoke-test-task.md
    python scripts/orchestrator.py --resume  # Resume from latest checkpoint

Environment:
    ANTHROPIC_API_KEY - Required for Director
    OLLAMA_URL - Worker endpoint (default: http://localhost:11434)
    CLAWD_HOME - Clawd directory (default: ~/clawd)
"""

import json
import subprocess
import os
import sys
import re
import time
from datetime import datetime
from pathlib import Path
from typing import Optional
import urllib.request
import urllib.error

# =============================================================================
# Configuration
# =============================================================================

ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY")
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
CLAWD_HOME = Path(os.environ.get("CLAWD_HOME", Path.home() / "clawd"))

# Orchestration limits
MAX_TURNS = 50
MAX_CONSECUTIVE_FAILURES = 3
WORKER_TIMEOUT = 600  # 10 minutes
DIRECTOR_TIMEOUT = 120  # 2 minutes

# Paths
AGENTS_DIR = CLAWD_HOME / "agents"
MEMORY_DIR = CLAWD_HOME / "memory"
CHECKPOINT_DIR = MEMORY_DIR / "checkpoints"
ALERTS_DIR = MEMORY_DIR / "alerts"
LOGS_DIR = MEMORY_DIR / "logs"
SCRIPTS_DIR = CLAWD_HOME / "scripts"

# =============================================================================
# Logging
# =============================================================================

def log(level: str, message: str):
    """Log to stdout and file"""
    timestamp = datetime.now().isoformat()
    line = f"[{timestamp}] [{level}] {message}"
    print(line)
    
    # Append to log file
    LOGS_DIR.mkdir(parents=True, exist_ok=True)
    log_file = LOGS_DIR / f"orchestrator-{datetime.now().strftime('%Y%m%d')}.log"
    with open(log_file, "a") as f:
        f.write(line + "\n")

def log_json(event: dict):
    """Log structured event to JSONL"""
    event["timestamp"] = datetime.now().isoformat()
    LOGS_DIR.mkdir(parents=True, exist_ok=True)
    jsonl_file = LOGS_DIR / f"events-{datetime.now().strftime('%Y%m%d')}.jsonl"
    with open(jsonl_file, "a") as f:
        f.write(json.dumps(event) + "\n")

# =============================================================================
# Claude API (Director)
# =============================================================================

def call_claude_api(system_prompt: str, user_message: str) -> str:
    """Call Claude API directly (no SDK dependency)"""
    if not ANTHROPIC_API_KEY:
        raise ValueError("ANTHROPIC_API_KEY not set")
    
    url = "https://api.anthropic.com/v1/messages"
    headers = {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json"
    }
    
    payload = {
        "model": "claude-sonnet-4-20250514",
        "max_tokens": 4096,
        "system": system_prompt,
        "messages": [
            {"role": "user", "content": user_message}
        ]
    }
    
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    
    try:
        with urllib.request.urlopen(req, timeout=DIRECTOR_TIMEOUT) as response:
            result = json.loads(response.read().decode("utf-8"))
            # Extract text from response
            for block in result.get("content", []):
                if block.get("type") == "text":
                    return block.get("text", "")
            return ""
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8") if e.fp else str(e)
        log("ERROR", f"Claude API error: {e.code} - {error_body}")
        raise
    except urllib.error.URLError as e:
        log("ERROR", f"Claude API connection error: {e.reason}")
        raise

def load_director_prompt() -> str:
    """Load Director system prompt from file"""
    director_file = AGENTS_DIR / "director.md"
    if director_file.exists():
        return director_file.read_text()
    else:
        log("WARN", f"Director prompt not found at {director_file}, using default")
        return "You are the Director agent coordinating a multi-agent coding system."

def call_director(state: dict) -> dict:
    """Call Director and get structured decision"""
    system_prompt = load_director_prompt()
    
    # Build the user message with current state
    user_message = format_state_for_director(state)
    
    log("INFO", f"Calling Director (turn {state['turn']})")
    log_json({"event": "director_call", "turn": state["turn"]})
    
    start_time = time.time()
    try:
        response = call_claude_api(system_prompt, user_message)
        latency = time.time() - start_time
        log("INFO", f"Director responded in {latency:.1f}s")
        log_json({"event": "director_response", "latency_ms": int(latency * 1000)})
        
        # Parse the decision from response
        decision = parse_director_decision(response)
        return decision
        
    except Exception as e:
        log("ERROR", f"Director call failed: {e}")
        log_json({"event": "director_error", "error": str(e)})
        
        # Return a halt decision on error
        return {
            "thought": f"Director call failed: {e}",
            "action": "halt",
            "reason": "director_error"
        }

def format_state_for_director(state: dict) -> str:
    """Format current state as a message for Director"""
    lines = [
        "# Current Task State",
        "",
        f"## Task",
        state.get("task", "No task loaded"),
        "",
        f"## Phase: {state.get('phase', 'unknown')}",
        f"## Turn: {state.get('turn', 0)} / {MAX_TURNS}",
        "",
    ]
    
    # Recent history (last 5 agent interactions)
    history = state.get("history", [])
    if history:
        lines.append("## Recent Agent Interactions")
        for entry in history[-5:]:
            lines.append(f"\n### {entry.get('agent', 'unknown')} (Turn {entry.get('turn', '?')})")
            lines.append(f"**Prompt**: {entry.get('prompt', 'N/A')[:200]}...")
            result = entry.get("result", "N/A")
            if len(result) > 500:
                result = result[:500] + "... [truncated]"
            lines.append(f"**Result**: {result}")
        lines.append("")
    
    # Files modified
    files = state.get("files_modified", [])
    if files:
        lines.append("## Files Modified")
        for f in files[-10:]:
            lines.append(f"- {f}")
        lines.append("")
    
    # Any blockers
    blockers = state.get("blockers", [])
    if blockers:
        lines.append("## Active Blockers")
        for b in blockers:
            lines.append(f"- {b}")
        lines.append("")
    
    lines.append("## Your Decision")
    lines.append("Analyze the current state and provide your next decision as a JSON block.")
    lines.append("Available agents: architect, scout, builder, refactorer, inspector, scribe")
    
    return "\n".join(lines)

def parse_director_decision(response: str) -> dict:
    """Parse Director's JSON decision from response"""
    # Try to find JSON block in response
    # Look for ```json ... ``` or { ... }
    
    # Method 1: Look for code block
    json_match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', response, re.DOTALL)
    if json_match:
        try:
            return json.loads(json_match.group(1))
        except json.JSONDecodeError:
            pass
    
    # Method 2: Look for raw JSON object
    json_match = re.search(r'\{[^{}]*"action"[^{}]*\}', response, re.DOTALL)
    if json_match:
        try:
            return json.loads(json_match.group(0))
        except json.JSONDecodeError:
            pass
    
    # Method 3: Try to parse entire response as JSON
    try:
        return json.loads(response)
    except json.JSONDecodeError:
        pass
    
    # Fallback: couldn't parse, return halt
    log("WARN", f"Could not parse Director decision, halting. Response: {response[:200]}")
    return {
        "thought": "Could not parse Director response",
        "action": "halt",
        "reason": "parse_error",
        "raw_response": response[:500]
    }

# =============================================================================
# Worker Calls (Ollama via call-agent.sh)
# =============================================================================

def call_worker(agent_name: str, prompt: str) -> dict:
    """Call a worker agent via call-agent.sh"""
    log("INFO", f"Calling worker: {agent_name}")
    log_json({"event": "worker_call", "agent": agent_name, "prompt_length": len(prompt)})
    
    script_path = SCRIPTS_DIR / "call-agent.sh"
    if not script_path.exists():
        return {
            "success": False,
            "error": f"call-agent.sh not found at {script_path}",
            "output": ""
        }
    
    start_time = time.time()
    try:
        result = subprocess.run(
            [str(script_path), agent_name, prompt],
            capture_output=True,
            text=True,
            timeout=WORKER_TIMEOUT,
            env={**os.environ, "OLLAMA_URL": OLLAMA_URL}
        )
        
        latency = time.time() - start_time
        log("INFO", f"Worker {agent_name} responded in {latency:.1f}s")
        log_json({
            "event": "worker_response",
            "agent": agent_name,
            "latency_ms": int(latency * 1000),
            "exit_code": result.returncode
        })
        
        if result.returncode == 0:
            return {
                "success": True,
                "output": result.stdout,
                "error": None
            }
        else:
            return {
                "success": False,
                "output": result.stdout,
                "error": result.stderr or f"Exit code {result.returncode}"
            }
            
    except subprocess.TimeoutExpired:
        log("ERROR", f"Worker {agent_name} timed out after {WORKER_TIMEOUT}s")
        return {
            "success": False,
            "error": f"Timeout after {WORKER_TIMEOUT}s",
            "output": ""
        }
    except Exception as e:
        log("ERROR", f"Worker {agent_name} failed: {e}")
        return {
            "success": False,
            "error": str(e),
            "output": ""
        }

# =============================================================================
# State Management
# =============================================================================

def init_state(task: str) -> dict:
    """Initialize fresh state for a task"""
    return {
        "task_id": f"task-{datetime.now().strftime('%Y%m%d-%H%M%S')}",
        "task": task,
        "phase": "planning",
        "turn": 0,
        "history": [],
        "decisions": [],
        "files_modified": [],
        "blockers": [],
        "consecutive_failures": 0,
        "started_at": datetime.now().isoformat(),
        "status": "running"
    }

def save_checkpoint(state: dict):
    """Save state to checkpoint file"""
    CHECKPOINT_DIR.mkdir(parents=True, exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    checkpoint_file = CHECKPOINT_DIR / f"chk-{state['task_id']}-{timestamp}.json"
    
    with open(checkpoint_file, "w") as f:
        json.dump(state, f, indent=2, default=str)
    
    # Also update current-state.json
    current_state_file = MEMORY_DIR / "current-state.json"
    with open(current_state_file, "w") as f:
        json.dump(state, f, indent=2, default=str)
    
    log("INFO", f"Checkpoint saved: {checkpoint_file.name}")
    log_json({"event": "checkpoint", "file": str(checkpoint_file)})

def load_latest_checkpoint() -> Optional[dict]:
    """Load most recent checkpoint"""
    if not CHECKPOINT_DIR.exists():
        return None
    
    checkpoints = sorted(CHECKPOINT_DIR.glob("chk-*.json"))
    if not checkpoints:
        return None
    
    latest = checkpoints[-1]
    log("INFO", f"Loading checkpoint: {latest.name}")
    
    with open(latest) as f:
        return json.load(f)

# =============================================================================
# Alerts & Escalation
# =============================================================================

def create_alert(title: str, severity: str, description: str, state: dict):
    """Create an escalation alert"""
    ALERTS_DIR.mkdir(parents=True, exist_ok=True)
    
    timestamp = datetime.now()
    alert_file = ALERTS_DIR / f"ALERT-{timestamp.strftime('%Y%m%d-%H%M%S')}.md"
    
    content = f"""# ESCALATION: {title}

**Timestamp**: {timestamp.isoformat()}
**Severity**: {severity}
**Task ID**: {state.get('task_id', 'unknown')}
**Turn**: {state.get('turn', 'unknown')}

## Issue

{description}

## Recent History

"""
    
    for entry in state.get("history", [])[-3:]:
        content += f"- {entry.get('agent', '?')}: {entry.get('prompt', 'N/A')[:100]}...\n"
    
    content += """
## State at Alert

See checkpoint for full state.

## Human Action Needed

Review the situation and decide how to proceed.
"""
    
    with open(alert_file, "w") as f:
        f.write(content)
    
    log("ALERT", f"Created alert: {alert_file.name}")
    log_json({"event": "alert", "title": title, "severity": severity})

# =============================================================================
# Main Orchestration Loop
# =============================================================================

def run_orchestrator(task_file: str = None, resume: bool = False):
    """Main orchestration loop"""
    
    # Initialize or resume state
    if resume:
        state = load_latest_checkpoint()
        if state is None:
            log("ERROR", "No checkpoint found to resume from")
            return None
        log("INFO", f"Resuming task {state['task_id']} from turn {state['turn']}")
    else:
        if task_file is None:
            log("ERROR", "No task file specified")
            return None
        
        task_path = Path(task_file)
        if not task_path.exists():
            # Try relative to CLAWD_HOME
            task_path = CLAWD_HOME / task_file
        
        if not task_path.exists():
            log("ERROR", f"Task file not found: {task_file}")
            return None
        
        task = task_path.read_text()
        state = init_state(task)
        log("INFO", f"Starting new task: {state['task_id']}")
    
    # Save initial checkpoint
    save_checkpoint(state)
    
    # Main loop
    while state["turn"] < MAX_TURNS and state["status"] == "running":
        state["turn"] += 1
        
        # Check for too many consecutive failures
        if state["consecutive_failures"] >= MAX_CONSECUTIVE_FAILURES:
            log("ERROR", f"Too many consecutive failures ({MAX_CONSECUTIVE_FAILURES})")
            create_alert(
                "Consecutive Failures",
                "HIGH",
                f"Agent failed {MAX_CONSECUTIVE_FAILURES} times in a row",
                state
            )
            state["status"] = "halted"
            break
        
        # Get Director decision
        decision = call_director(state)
        state["decisions"].append({
            "turn": state["turn"],
            "decision": decision,
            "timestamp": datetime.now().isoformat()
        })
        
        log("INFO", f"Director decision: {decision.get('action', 'unknown')}")
        
        # Execute decision
        action = decision.get("action", "halt")
        
        if action == "spawn_agent":
            agent = decision.get("agent")
            prompt = decision.get("prompt", "")
            
            if not agent:
                log("WARN", "spawn_agent without agent name")
                state["consecutive_failures"] += 1
                continue
            
            result = call_worker(agent, prompt)
            
            # Record in history
            state["history"].append({
                "turn": state["turn"],
                "agent": agent,
                "prompt": prompt,
                "result": result.get("output", ""),
                "success": result.get("success", False),
                "error": result.get("error"),
                "timestamp": datetime.now().isoformat()
            })
            
            if result.get("success"):
                state["consecutive_failures"] = 0
            else:
                state["consecutive_failures"] += 1
                log("WARN", f"Worker {agent} failed: {result.get('error')}")
        
        elif action == "complete":
            log("INFO", "Task completed successfully!")
            state["status"] = "complete"
            state["completed_at"] = datetime.now().isoformat()
        
        elif action == "escalate":
            reason = decision.get("thought", decision.get("reason", "Unknown reason"))
            log("WARN", f"Escalating: {reason}")
            create_alert("Director Escalation", "MEDIUM", reason, state)
            state["status"] = "escalated"
        
        elif action == "halt":
            reason = decision.get("thought", decision.get("reason", "Director requested halt"))
            log("INFO", f"Halting: {reason}")
            state["status"] = "halted"
        
        else:
            log("WARN", f"Unknown action: {action}")
            state["consecutive_failures"] += 1
        
        # Checkpoint after each turn
        save_checkpoint(state)
        
        # Brief pause to avoid hammering APIs
        time.sleep(1)
    
    # Final status
    if state["turn"] >= MAX_TURNS and state["status"] == "running":
        log("WARN", f"Max turns ({MAX_TURNS}) reached")
        create_alert("Max Turns Reached", "MEDIUM", f"Task did not complete in {MAX_TURNS} turns", state)
        state["status"] = "max_turns"
    
    save_checkpoint(state)
    log("INFO", f"Orchestrator finished. Status: {state['status']}")
    log_json({"event": "orchestrator_end", "status": state["status"], "turns": state["turn"]})
    
    return state

# =============================================================================
# CLI
# =============================================================================

def print_usage():
    print(__doc__)

def main():
    if len(sys.argv) < 2:
        print_usage()
        sys.exit(1)
    
    if sys.argv[1] == "--resume":
        run_orchestrator(resume=True)
    elif sys.argv[1] == "--help" or sys.argv[1] == "-h":
        print_usage()
    else:
        task_file = sys.argv[1]
        run_orchestrator(task_file=task_file)

if __name__ == "__main__":
    main()
