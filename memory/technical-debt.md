# Technical Debt - Deferred Issues

*Log issues found but out of scope for current task*

## Purpose

During task execution, agents will discover issues that:
- Are real problems
- Are NOT in scope for the current task
- Should be addressed eventually

Log them here. Don't fix them. Stay focused.

---

## Active Debt

### [DEBT-001] [Title]

**Found**: [timestamp]
**Agent**: [who found it]
**Location**: [file:line or general area]
**Severity**: LOW | MEDIUM | HIGH

**Description**:
[What's the issue]

**Why Not Now**:
[Why it's out of scope]

**Suggested Fix**:
[Brief description of fix approach]

**Estimated Effort**: [hours]

---

## Debt Categories

- `[REFACTOR]` - Code quality improvement
- `[TEST]` - Missing or inadequate tests
- `[DOCS]` - Documentation gaps
- `[PERF]` - Performance issue
- `[SECURITY]` - Security concern
- `[UX]` - User experience issue
- `[BUG]` - Bug unrelated to current task

## Priority Guide

**HIGH**: 
- Security issues
- Data integrity risks
- Crashes in common paths

**MEDIUM**:
- Performance issues
- Missing test coverage
- Confusing code

**LOW**:
- Style inconsistencies
- Minor optimization opportunities
- Nice-to-have features

---

## Resolved Debt

*Move items here when addressed in future tasks*

---

*Last updated: [timestamp]*
