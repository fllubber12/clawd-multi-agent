# Skill: Sentry Error Triage

Automatically triage and potentially fix errors reported by Sentry.

## Trigger

Activated when Molty receives a Sentry webhook notification containing:
- Error type and message
- File location and line number
- Stack trace
- Project name

## Triage Decision Matrix

### ✅ Auto-Fix (proceed without human approval)

These error types have deterministic fixes with low risk:

| Error Type | Pattern | Auto-Fix Action |
|------------|---------|-----------------|
| **ImportError** | `No module named 'X'` | Add missing import |
| **NameError** | `name 'X' is not defined` | Add import or fix typo |
| **TypeError** | `NoneType has no attribute` | Add null check |
| **AttributeError** | `'X' has no attribute 'Y'` | Add null check or fix typo |
| **KeyError** | `KeyError: 'X'` | Use `.get()` with default |
| **IndexError** | `list index out of range` | Add bounds check |
| **FileNotFoundError** | `No such file or directory` | Add existence check |
| **SyntaxError** | Any | Fix syntax (obvious from context) |
| **IndentationError** | Any | Fix indentation |

**Auto-fix constraints:**
- Change must be < 10 lines
- Must not modify function signatures
- Must not change business logic
- Must pass existing tests after fix

### ⚠️ Escalate to Human (do not auto-fix)

| Category | Examples | Why |
|----------|----------|-----|
| **Architecture** | Circular imports, module restructuring | Design decisions needed |
| **Security** | Auth failures, permission errors, injection | Risk too high |
| **Business Logic** | Calculation errors, wrong outcomes | Domain knowledge needed |
| **Data Corruption** | Database errors, state inconsistency | Investigation needed |
| **External Services** | API failures, network issues | May be transient |
| **Performance** | Timeouts, memory errors | Root cause analysis needed |
| **Unknown** | Can't determine cause | Human judgment needed |

## Workflow

### 1. Receive Alert
```
Sentry webhook → sentry-webhook-handler.py → Molty notification
```

### 2. Load Context
```bash
# Read the context file from webhook handler
cat ~/clawd/logs/sentry-webhooks/context_*.json | tail -1
```

### 3. Determine Project
```bash
# Load repository config
cat ~/clawd/config/repositories.json
```

### 4. Create Isolated Environment (for auto-fix)
```bash
# Create worktree for isolated fix
~/clawd/scripts/worktree-create.sh <project> sentry-fix-<issue_id>

# Example:
~/clawd/scripts/worktree-create.sh polymarket sentry-fix-12345
```

### 5. Dispatch to Claude Code
```bash
# For auto-fixable errors:
cd <worktree_path>
claude --print "Fix the following error: <error_details>"

# For escalation:
clawdbot gateway wake --text "⚠️ Sentry escalation needed: <summary>" --mode now
```

### 6. Verify Fix
```bash
# Run tests in worktree
cd <worktree_path>
source .venv/bin/activate
python -m pytest tests/ -x

# If tests pass, create PR or merge
git add -A
git commit -m "fix: <error_type> in <file>"
```

### 7. Cleanup
```bash
~/clawd/scripts/worktree-cleanup.sh <worktree_name>
```

## Auto-Fix Templates

### NoneType / AttributeError
```python
# Before (error: 'NoneType' has no attribute 'foo')
result = obj.foo

# After
result = obj.foo if obj else None
# OR
if obj is not None:
    result = obj.foo
```

### KeyError
```python
# Before (error: KeyError: 'key')
value = data['key']

# After
value = data.get('key', default_value)
```

### ImportError
```python
# Before (error: No module named 'foo')
from foo import bar

# After (add to imports at top of file)
from foo import bar  # Verify package is installed
```

### IndexError
```python
# Before (error: list index out of range)
item = items[index]

# After
item = items[index] if index < len(items) else None
```

## Context Required

For auto-fix to work, the Sentry payload must include:
- `file` - Path to file with error
- `line` - Line number
- `error_type` - Exception class name
- `error_message` - Exception message
- `stack_trace` - Call stack for context

## Safety Checks

Before applying any auto-fix:

1. **Verify file exists** in the target repository
2. **Check git status** - don't fix if uncommitted changes
3. **Run tests before** - baseline must pass
4. **Run tests after** - fix must not break anything
5. **Limit scope** - only modify the specific file/function
6. **Log everything** - audit trail in `~/clawd/logs/sentry-fixes/`

## Escalation Message Format

When escalating to human:
```
⚠️ Sentry Escalation: [project]

Error: [error_type]: [error_message]
File: [file]:[line]
Reason: [why_not_auto_fixable]

Sentry URL: [link]
Context file: [path_to_context_json]

Recommended action: [suggestion]
```

## Metrics to Track

Log to `~/clawd/logs/sentry-metrics.json`:
- Total alerts received
- Auto-fixes attempted
- Auto-fixes successful
- Escalations
- False positives (auto-fix broke tests)
