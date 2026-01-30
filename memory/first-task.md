# First Task: A Bao A Qu Link Summon Debug

> **NOTE**: This is an EXAMPLE task definition to demonstrate the format.
> Do not work on this task during prepwork. Focus on clawdbot infrastructure first.
> Finalize and execute this task when hardware arrives and the system is operational.

## Objective

Determine why A Bao A Qu Link Summon never occurs at step 17, and fix it.

## Repository

- **Source**: https://github.com/fllubber12/ygo-combo-pipeline
- **Clone to**: `~/clawd/workspace/ygo-combo-pipeline`

## Context

The ygo-combo-pipeline exhaustively enumerates Yu-Gi-Oh action sequences to find optimal endboards. It uses CFFI integration with the official YGOPro/EDOPro Lua engine for 100% accurate card effect execution.

**Current Problem**:
- Step 16 produces Rextremende + Agnumday on field
- Step 17 should Link Summon A Bao A Qu using these as materials
- 0 terminals ever reach this step

**Why This Matters**:
- A Bao A Qu is a key combo piece for S-tier endboards
- If the Link Summon isn't happening, we're missing optimal lines

## Success Criteria

- [ ] At least 1 terminal contains A Bao A Qu on field
- [ ] **Bonus**: Terminal contains BOTH A Bao A Qu AND Caesar
- [ ] All existing tests still pass
- [ ] Root cause documented in `memory/decisions-log.md`

## Investigation Steps

### Phase 1: Understand the State (Scout + Architect)

1. Clone repo and understand structure
2. Find a terminal that reached step 16
3. Document the game state at step 16:
   - Monsters on field (zones, attributes, types)
   - Available Extra Deck monsters
   - Any restrictions in effect

### Phase 2: Diagnose (Inspector + Scout)

4. Check if A Bao A Qu appears in `spsummon` list at step 17
5. **If YES** → Prioritization issue (not being selected)
   - Why is something else chosen over A Bao A Qu?
   - Check priority/scoring logic
6. **If NO** → Legality issue
   - Check Link Summon requirements for A Bao A Qu
   - Verify materials meet requirements (types, attributes, link ratings)
   - Check for restrictions (once-per-turn, "cannot be used as material")
   - Check zone availability

### Phase 3: Fix (Builder)

7. Implement fix based on diagnosis
8. Add debug logging if needed to verify fix
9. Run tests to confirm no regressions

### Phase 4: Verify (Inspector)

10. Verify A Bao A Qu appears in at least one terminal
11. Run full test suite
12. Document root cause and fix

## Scope Boundaries

### IN SCOPE
- Investigating the Link Summon failure
- Fixing prioritization or legality bugs
- Adding debug logging as needed
- Modifying combo enumeration logic
- Updating priority/scoring weights

### OUT OF SCOPE
- Refactoring unrelated code
- Changing ygopro-core bindings
- Fixing unrelated bugs (log them in `memory/technical-debt.md`)
- Performance optimization
- Adding new cards to the library

## Abort Conditions

**HALT immediately and escalate if**:
- Engine segfaults or crashes
- Same error 3+ times with no progress
- A Bao A Qu missing from `locked_library.json`
- Any design decision needed (e.g., "should we change how priorities work?")
- Modifications needed to ygopro-core or CFFI layer
- Tests fail in ways unrelated to the fix

## Estimated Complexity

**Medium** (2-4 hours if straightforward, up to 8 if deep bug)

Likely causes (in order of probability):
1. Prioritization issue - A Bao A Qu is legal but something else is chosen
2. Zone issue - No available Extra Monster Zone
3. Material issue - Materials don't meet requirements
4. Restriction issue - Some effect preventing the Link Summon

## Key Files to Examine

*Fill in after cloning repo - Scout's first task*

```
ygo-combo-pipeline/
├── src/
│   ├── ?                # Main combo logic
│   ├── ?                # Priority/scoring
│   └── ?                # Link Summon handling
├── data/
│   └── locked_library.json  # Card definitions
└── tests/
    └── ?                # Test files
```

## Notes

- This is the first task for the multi-agent system
- Success here validates the entire pipeline
- Be conservative - working is better than fast
- Document everything for morning review
