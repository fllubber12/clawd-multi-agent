# ESCALATION: Engine Segfault During Link Summon Test

**Timestamp**: 2026-01-30T03:45:00Z
**Severity**: CRITICAL
**Agent**: Inspector
**Task**: abaoaqu-debug-001

---

## Issue

The ygopro-core engine crashed with a segmentation fault when testing the A Bao A Qu Link Summon fix.

```
Traceback:
  File "src/engine_wrapper.py", line 234, in execute_action
    result = self._core.process_action(action_id)
  ...
Segmentation fault (core dumped)
```

## Context

- Builder implemented a fix for priority scoring in `src/priority.py`
- Change passed unit tests
- Segfault occurred during integration test with full combo sequence
- Crash is reproducible (3/3 attempts)

## State at Crash

- Game state: Step 16 complete (Rextremende + Agnumday on field)
- Attempting: Link Summon A Bao A Qu
- Materials selected: Rextremende (zone 1), Agnumday (zone 3)

## Attempted Solutions

1. **Reverted priority.py changes** - Still crashes
   - Indicates bug may not be in our fix
   
2. **Tested with different materials** - Still crashes
   - Crash seems specific to A Bao A Qu, not materials
   
3. **Checked A Bao A Qu card definition** - Looks valid
   - Entry exists in locked_library.json
   - Link requirements appear correct

## Diagnosis

Likely causes (in order of probability):
1. Bug in ygopro-core Lua script for A Bao A Qu
2. Invalid state being passed to engine
3. Memory corruption from earlier in sequence

## Human Action Needed

This appears to be a bug in ygopro-core or the CFFI layer, which is OUT OF SCOPE.

**Options**:
1. Investigate ygopro-core Lua scripts (requires Lua expertise)
2. Try different version of ygopro-core
3. Skip A Bao A Qu task and try different first task
4. Debug further with core dump analysis

## Deadline

**HALTED** - Cannot proceed until resolved.

Current state checkpointed at: `memory/checkpoints/chk-20260130-034500-crash.json`

## Files to Examine

- `src/engine_wrapper.py` - Line 234 and surrounding
- `data/locked_library.json` - A Bao A Qu entry
- ygopro-core scripts for A Bao A Qu (if accessible)

---

*Alert raised by Inspector at 2026-01-30T03:47:00Z*
*Awaiting human response*
