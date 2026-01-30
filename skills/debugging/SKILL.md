---
name: debugging
description: Finds and fixes bugs, errors, and unexpected behavior. Use when asked to debug, fix, troubleshoot, or investigate issues. Triggered by keywords like "debug", "fix", "error", "bug", "not working", "investigate", "broken".
---

# Debugging Issues

## Workflow

1. **Reproduce the issue**
   - Understand the expected vs actual behavior
   - Identify steps to reproduce
   - Note any error messages verbatim

2. **Gather information**
   - Check logs for relevant errors
   - Review recent changes (git log/diff)
   - Identify the scope (which files/functions affected)

3. **Form hypotheses**
   - List possible causes (most likely first)
   - Consider recent changes that might be related
   - Check for similar past issues in `memory/learnings/`

4. **Investigate systematically**
   - Test hypotheses one at a time
   - Add diagnostic logging if needed
   - Narrow down the root cause

5. **Fix and verify**
   - Implement the minimal fix
   - Verify the fix resolves the issue
   - Check for regressions

6. **Document**
   - Record the root cause and fix
   - Add to learnings if it's a reusable lesson

## Diagnostic Commands

### Python
```bash
# Run with verbose output
python -v script.py

# Run with debugging
python -m pdb script.py

# Check for syntax errors
python -m py_compile script.py
```

### Node.js
```bash
# Run with debugging
node --inspect script.js

# Check for issues
npm run lint
```

### General
```bash
# Check recent changes
git log --oneline -10
git diff HEAD~1

# Search for patterns
grep -r "error_pattern" .

# Check file permissions
ls -la problematic_file
```

## Common Bug Categories

### 1. Syntax/Type Errors
- **Symptom**: Immediate crash with clear error message
- **Approach**: Read error message, fix at indicated line
- **Tip**: Check for typos, missing imports, type mismatches

### 2. Logic Errors
- **Symptom**: Wrong output, no error
- **Approach**: Add logging, trace through logic manually
- **Tip**: Check boundary conditions, off-by-one errors

### 3. State/Race Conditions
- **Symptom**: Intermittent failures
- **Approach**: Review state mutations, add synchronization
- **Tip**: Check async operations, shared resources

### 4. Environment Issues
- **Symptom**: Works locally, fails elsewhere
- **Approach**: Compare environments, check dependencies
- **Tip**: Check PATH, environment variables, versions

### 5. Integration Issues
- **Symptom**: Fails when components interact
- **Approach**: Test components in isolation, check interfaces
- **Tip**: Verify API contracts, data formats

## Debugging Mindset

### ❌ Don't
- Make random changes hoping something works
- Assume you know the cause without evidence
- Skip reproducing the issue first
- Forget to remove debug logging

### ✅ Do
- Read error messages carefully (they often tell you exactly what's wrong)
- Use binary search to narrow down (comment out half, repeat)
- Check the simplest explanations first
- Take notes as you investigate

## Output Format

When debugging is complete, provide:

```markdown
## Bug Fix Summary

**Issue**: [Brief description of the problem]

**Root cause**: [What was actually wrong]

**Fix**: [What was changed]

**Files modified:**
- path/to/file.py - [what changed]

**Verification**: [How you confirmed the fix works]

**Prevention**: [How to avoid this in future, if applicable]
```

## Escalation

Escalate if:
- Unable to reproduce after multiple attempts
- Root cause unclear after 30 minutes of investigation
- Fix requires architectural changes
- Multiple interdependent bugs discovered

## Reference

For known issues and fixes, check:
- `memory/learnings/` for past bug fixes
- Project issue tracker if available
- Error message in web search for external libraries
