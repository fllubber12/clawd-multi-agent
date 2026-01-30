---
name: implementing
description: Implements new features and code following project conventions. Use when asked to build, create, implement, or add new functionality. Triggered by keywords like "implement", "create", "build", "add feature", "write code".
---

# Implementing New Code

## Workflow

1. **Understand the requirement**
   - Read the task specification completely
   - Identify acceptance criteria
   - Note any constraints or dependencies

2. **Research existing patterns**
   - Search codebase for similar implementations
   - Check `memory/learnings/` for relevant patterns
   - Review any referenced documentation

3. **Plan before coding**
   - Outline the approach
   - Identify files to create/modify
   - Consider edge cases

4. **Implement incrementally**
   - Start with the core functionality
   - Add error handling
   - Include logging where appropriate

5. **Validate**
   - Run relevant tests
   - Check for lint errors
   - Verify acceptance criteria

## Conventions

### File Organization
- Place new files in appropriate directories per project structure
- Follow existing naming conventions (check nearby files)
- One responsibility per file where practical

### Code Style
- Match the style of surrounding code
- Use descriptive variable/function names
- Add comments for non-obvious logic only

### Error Handling
- Always handle potential errors
- Provide meaningful error messages
- Log errors with context

### Testing
- Consider testability during implementation
- If tests exist, ensure new code doesn't break them
- Add tests for complex logic (ask if unsure)

## Common Pitfalls

### ❌ Don't
- Jump straight to coding without understanding the task
- Ignore existing patterns in the codebase
- Leave error cases unhandled
- Create overly complex solutions

### ✅ Do
- Ask clarifying questions if requirements are unclear
- Reuse existing utilities and patterns
- Keep implementations simple and readable
- Document non-obvious decisions

## Output Format

When implementation is complete, provide:

```markdown
## Implementation Summary

**Files created/modified:**
- path/to/file1.py - [brief description]
- path/to/file2.py - [brief description]

**Key decisions:**
- [Decision 1 and rationale]
- [Decision 2 and rationale]

**Testing:**
- [How it was validated]

**Notes:**
- [Any caveats or follow-up needed]
```

## Reference

For project-specific patterns, see:
- `memory/learnings/patterns.md` (if exists)
- Nearby files in the same directory
- `CLAUDE.md` for project conventions
