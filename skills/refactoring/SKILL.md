---
name: refactoring
description: Improves existing code without changing behavior. Use when asked to refactor, clean up, improve, optimize, or restructure code. Triggered by keywords like "refactor", "clean up", "improve", "optimize", "simplify", "restructure".
---

# Refactoring Code

## Core Principle

> Refactoring changes the structure of code without changing its behavior.

Always verify behavior is preserved after refactoring.

## Workflow

1. **Understand current behavior**
   - Read and understand the existing code
   - Identify what it does and why
   - Note any tests that verify behavior

2. **Identify improvement opportunities**
   - Code smells (duplication, long functions, etc.)
   - Performance issues
   - Readability problems
   - Inconsistent patterns

3. **Plan the refactoring**
   - List specific changes to make
   - Prioritize by impact and risk
   - Identify potential breaking changes

4. **Refactor incrementally**
   - Make one change at a time
   - Verify behavior after each change
   - Commit frequently

5. **Verify**
   - Run all relevant tests
   - Check for regressions
   - Confirm readability improved

## Common Refactoring Patterns

### Extract Function
**When**: Code block does one thing and could be reused or named
```python
# Before
def process():
    # ... 20 lines doing X ...
    # ... 20 lines doing Y ...

# After
def process():
    do_x()
    do_y()

def do_x():
    # ... 20 lines doing X ...

def do_y():
    # ... 20 lines doing Y ...
```

### Rename for Clarity
**When**: Names don't convey meaning
```python
# Before
def proc(d):
    for i in d:
        # ...

# After  
def process_users(user_data):
    for user in user_data:
        # ...
```

### Remove Duplication
**When**: Same code appears multiple times
```python
# Before
if user.role == 'admin':
    log("Admin access")
    check_permissions()
    do_thing()
if user.role == 'manager':
    log("Manager access")
    check_permissions()
    do_thing()

# After
if user.role in ['admin', 'manager']:
    log(f"{user.role} access")
    check_permissions()
    do_thing()
```

### Simplify Conditionals
**When**: Complex nested if/else
```python
# Before
if condition1:
    if condition2:
        if condition3:
            do_thing()

# After (early returns)
if not condition1:
    return
if not condition2:
    return
if not condition3:
    return
do_thing()
```

### Replace Magic Numbers
**When**: Unexplained literal values
```python
# Before
if len(password) < 8:
    return False

# After
MIN_PASSWORD_LENGTH = 8
if len(password) < MIN_PASSWORD_LENGTH:
    return False
```

## Code Smells to Watch For

| Smell | Sign | Fix |
|-------|------|-----|
| **Long function** | >20 lines | Extract functions |
| **Deep nesting** | >3 levels | Early returns, extract |
| **Duplication** | Similar code 2+ places | Extract and reuse |
| **God object** | Class does everything | Split responsibilities |
| **Primitive obsession** | Lots of raw strings/ints | Create domain types |
| **Long parameter list** | >3 parameters | Create parameter object |

## Refactoring Safely

### ❌ Don't
- Refactor and add features at the same time
- Make large changes without intermediate verification
- Refactor code you don't understand
- Change behavior while refactoring

### ✅ Do
- Have tests before refactoring (or add them first)
- Make small, reversible changes
- Commit after each successful refactoring step
- Keep a clear goal in mind

## Output Format

When refactoring is complete, provide:

```markdown
## Refactoring Summary

**Goal**: [What improvement was targeted]

**Changes made:**
1. [Change 1]: [Rationale]
2. [Change 2]: [Rationale]

**Files modified:**
- path/to/file.py - [summary of changes]

**Behavior verification:**
- [How you confirmed behavior unchanged]

**Metrics** (if applicable):
- Lines of code: X → Y
- Cyclomatic complexity: X → Y
- Duplication: X% → Y%
```

## When NOT to Refactor

- Code is about to be deleted/replaced
- No tests exist and you can't add them
- Deadline pressure (refactor later)
- You don't understand what the code does
- The "improvement" is just personal preference

## Reference

For project style guidelines, see:
- `CLAUDE.md` for project conventions
- Existing code in the same directory for patterns
- `memory/learnings/` for established patterns
