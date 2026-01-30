# Smoke Test Task: Create Hello World File

> **Purpose**: Validate the orchestration loop works end-to-end before running real tasks.
> This is intentionally trivial - if this fails, debug the infrastructure, not the task.

## Objective

Create a file called `test-output.txt` containing the text "Hello from Clawd!"

## Success Criteria

- [ ] File `~/clawd/workspace/test-output.txt` exists
- [ ] File contains exactly: "Hello from Clawd!"
- [ ] No errors in orchestrator log

## Expected Agent Flow

1. **Director** → Spawns **Builder** to create the file
2. **Builder** → Creates the file
3. **Director** → Spawns **Inspector** to verify
4. **Inspector** → Confirms file exists and has correct content
5. **Director** → Marks task complete

## Scope Boundaries

**IN SCOPE**:
- Creating a single text file
- Verifying the file exists

**OUT OF SCOPE**:
- Everything else

## Abort Conditions

- Any agent fails to respond → Halt and check infrastructure
- File creation fails → Check workspace permissions

## Estimated Complexity

**Trivial** (should complete in < 5 turns, < 2 minutes)

## What This Tests

| Component | What We're Validating |
|-----------|----------------------|
| orchestrator.py | Main loop runs without crashing |
| Claude API | Director can be called and responds |
| call-agent.sh | Workers can be spawned |
| Ollama | Local model responds (if available) |
| Checkpointing | State is saved each turn |
| Decision parsing | Director's JSON is parsed correctly |

## If This Fails

1. Check `ANTHROPIC_API_KEY` is set
2. Check Ollama is running (if testing workers)
3. Check `~/clawd/workspace/` directory exists
4. Check orchestrator logs in `~/clawd/memory/logs/`
5. Check for Python errors in terminal output

## Running the Test

```bash
# From ~/clawd directory
python scripts/orchestrator.py memory/smoke-test-task.md

# Or with explicit path
python ~/clawd/scripts/orchestrator.py ~/clawd/memory/smoke-test-task.md
```

## Expected Output

```
[timestamp] [INFO] Starting new task: task-YYYYMMDD-HHMMSS
[timestamp] [INFO] Checkpoint saved: chk-task-...-....json
[timestamp] [INFO] Calling Director (turn 1)
[timestamp] [INFO] Director responded in X.Xs
[timestamp] [INFO] Director decision: spawn_agent
[timestamp] [INFO] Calling worker: builder
[timestamp] [INFO] Worker builder responded in X.Xs
[timestamp] [INFO] Checkpoint saved: ...
[timestamp] [INFO] Calling Director (turn 2)
...
[timestamp] [INFO] Task completed successfully!
[timestamp] [INFO] Orchestrator finished. Status: complete
```

---

*This smoke test was created to validate clawd infrastructure before running the A Bao A Qu debugging task.*
