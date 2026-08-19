---
phase: 7
type: context
title: "Phase 7 Design Decisions — Cross-Runtime Dispatch Robustness"
date: 2026-08-20
---

# Phase 7 Context: Cross-Runtime Dispatch Robustness

## Phase Overview

**Goal**: Solve cross-project dispatch failures in gsd-addon's cross-runtime dispatch system by adopting GSD Core's best practices (git-root auto-detection, early validation, error messaging).

**Scope**: Robustness improvements to gsd-dispatch.sh, gsd-dispatch-chain.sh, and gsd-dispatch-debug.sh

**Estimated Effort**: 3-4 weeks

---

## Design Decisions

### Decision 1: Project Root Detection Strategy
**Question**: How should gsd-dispatch.sh determine the target project directory?

**Option A**: Keep script-relative path (current)
```bash
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
```
- ❌ Always points to ~/.claude/gsd-addon (wrong for cross-project dispatch)
- ❌ Requires manual TARGET_DIR in 95% of cross-project cases
- ✅ No change needed (status quo)

**Option B**: Git repository root auto-detection (GSD Core pattern) ✅ **CHOSEN**
```bash
_GSD_RUNTIME_ROOT="${RUNTIME_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TARGET_DIR="${TARGET_DIR:-$_GSD_RUNTIME_ROOT}"
```
- ✅ Auto-detects target project from current directory
- ✅ No manual TARGET_DIR required
- ✅ Fails gracefully (falls back to pwd)
- ✅ Matches GSD Core's pattern
- ⚠️ Requires testing in non-git directories

**Why Option B**: soapwavehealing incident (Wave 2-5 failure) directly caused by script-relative PROJECT_DIR. Auto-detection solves 95% of real-world cross-project dispatch failures without requiring users to remember TARGET_DIR.

**Backwards Compatibility**: TARGET_DIR env var still honored (Option B checks it first), so existing workflows continue working.

---

### Decision 2: PHASE Format Validation
**Question**: Should gsd-dispatch.sh validate PHASE format before dispatch?

**Option A**: No validation (current)
- ❌ Accepts `--cwd` as PHASE (causes silent failure in Wave 2-3)
- ✅ No overhead
- ✅ Flexible for future wave notation (3.2, etc.)

**Option B**: Strict validation ✅ **CHOSEN**
```bash
if [[ ! "$PHASE" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "✗ FAIL: PHASE must be a number (e.g., 3, 6.2)"
  echo "  gsd-dispatch 3           (dispatch Phase 3)"
  echo "  gsd-dispatch 6.2         (dispatch Phase 6, Wave 2)"
  exit 1
fi
```
- ✅ Prevents `--cwd` being accepted as phase
- ✅ Clear error message guides user to correct format
- ✅ Supports future wave notation (3.2)
- ⚠️ Slightly stricter than before

**Why Option B**: soapwavehealing Wave 4 failure shows that accepting invalid PHASE allows bad dispatch to proceed until executor stage. Early validation catches errors immediately with actionable guidance.

---

### Decision 3: Cross-Project Validation
**Question**: Should gsd-dispatch.sh validate TARGET_DIR structure before dispatch?

**Option A**: No validation (current)
- ✅ Fast (no extra file checks)
- ❌ Leads to silent failures (Wave 2-3 emit 0 bytes)
- ❌ Hard to diagnose "why did nothing happen"

**Option B**: Full pre-flight validation ✅ **CHOSEN**
```bash
# 1. TARGET_DIR exists
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "✗ FAIL: TARGET_DIR not found: $TARGET_DIR"
  exit 1
fi

# 2. .planning/ROADMAP.md exists
if [[ ! -f "$TARGET_DIR/.planning/ROADMAP.md" ]]; then
  echo "✗ FAIL: Not a GSD project (missing .planning/ROADMAP.md)"
  exit 1
fi

# 3. PHASE defined in target's ROADMAP
if ! grep -q "^### Phase $PHASE" "$TARGET_DIR/.planning/ROADMAP.md"; then
  echo "✗ FAIL: Phase $PHASE not found in ROADMAP"
  echo "  Available: $(grep '^### Phase ' ... | extract numbers)"
  exit 1
fi
```
- ✅ Detects errors before OpenCode dispatch (fail-fast)
- ✅ Clear, actionable error messages
- ✅ Prevents 0-byte output silent failures
- ⚠️ 3 extra file I/O operations

**Why Option B**: soapwavehealing Wave 2 output 0 bytes with no error. Pre-flight validation would have caught "Phase 3 not found in gsd-addon's ROADMAP" and prevented dispatch. 3 file checks are negligible overhead vs. 100+ second OpenCode dispatch.

---

### Decision 4: Log Directory Location
**Question**: Where should dispatch logs be written?

**Option A**: PROJECT_DIR (current — always ~/.claude/gsd-addon)
```bash
LOG_DIR="${PROJECT_DIR}/.planning/soldier-logs"
```
- ✅ Logs in one central location
- ❌ User in soapwavehealing looks for logs in soapwavehealing/.planning/
- ❌ Adds friction to cross-project dispatch debugging

**Option B**: TARGET_DIR (the actual project being dispatched) ✅ **CHOSEN**
```bash
LOG_DIR="${TARGET_DIR}/.planning/soldier-logs"
```
- ✅ Logs appear where user expects them
- ✅ Better separation between dispatch runs
- ✅ User can `tail -f soapwavehealing/.planning/soldier-logs/phase-3-*.log`
- ⚠️ Multiple dispatches from different projects use different LOG_DIRs

**Why Option B**: soapwavehealing incident: user would have checked logs in soapwavehealing directory, not gsd-addon. Logs written to TARGET_DIR fix this mismatch and reduce debugging time.

---

### Decision 5: Output Validation Enhancement
**Question**: How detailed should gsd-dispatch-chain.sh's output file validation be?

**Option A**: Simple existence check (current)
```bash
if ! ls "$TARGET_DIR/.planning/phases/$PHASE"/*-RESEARCH.md 2>/dev/null | grep -q .; then
  echo "✗ RESEARCH.md not found"
  exit 1
fi
```
- ✅ Simple, fast
- ❌ No hint about what to do if validation fails

**Option B**: Detailed validation with diagnostics ✅ **CHOSEN**
```bash
FILE_COUNT=$(ls "$TARGET_DIR/.planning/phases/$PHASE"/*-RESEARCH.md 2>/dev/null | wc -l)
if [[ $FILE_COUNT -eq 0 ]]; then
  echo "✗ RESEARCH.md not produced"
  echo "  Expected: $TARGET_DIR/.planning/phases/$PHASE/*-RESEARCH.md"
  echo "  Diagnostics:"
  echo "    1. Check dispatch logs: gsd-dispatch-debug logs"
  echo "    2. Verify TARGET_DIR: gsd-dispatch-debug check-env"
  echo "    3. Full diagnosis: gsd-dispatch-debug diagnose"
  exit 1
fi
TOTAL_SIZE=$(du -sh "$TARGET_DIR/.planning/phases/$PHASE"/*-RESEARCH.md | awk '{sum+=$1} END {print sum}')
echo "✓ research complete ($FILE_COUNT files, $TOTAL_SIZE)"
```
- ✅ Shows file count and size (visibility)
- ✅ Provides next-step diagnostics (gsd-dispatch-debug)
- ✅ Guides user to self-service troubleshooting
- ⚠️ Slightly more verbose output

**Why Option B**: Phase 6 Debug Tool exists specifically for troubleshooting. Chain validation should guide users to it rather than leaving them in the dark.

---

### Decision 6: Error Message Pattern
**Question**: Should error messages include remediation guidance?

**Option A**: Just state the error
```bash
echo "✗ FAIL: PHASE must be a number"
```
- ✅ Concise
- ❌ User must infer the fix

**Option B**: Include examples + next steps ✅ **CHOSEN**
```bash
echo "✗ FAIL: PHASE must be a number (e.g., 3, 6.2)"
echo "  Available commands:"
echo "    gsd-dispatch 3           (local dispatch)"
echo "    gsd-dispatch 6.2         (wave-specific dispatch — if supported)"
echo "    TARGET_DIR=/path gsd-dispatch 3  (cross-project dispatch)"
```
- ✅ User sees exactly what format is expected
- ✅ Shows multiple usage patterns
- ✅ Reduces support burden (self-explanatory)
- ⚠️ Slightly longer error output

**Why Option B**: soapwavehealing user tried `gsd-dispatch --cwd . --plan "..." --target opencode` — they didn't know the correct format. Showing valid examples in the error message would have prevented this mistake immediately.

---

### Decision 7: gsd-dispatch-debug Cross-Project Mode
**Question**: Should gsd-dispatch-debug have a dedicated cross-project diagnostic mode?

**Option A**: Use existing modes (status, check-env, diagnose)
- ✅ No new code needed
- ❌ Users don't know which modes are relevant to cross-project issues

**Option B**: Add "cross-project" diagnostic mode ✅ **CHOSEN**
```bash
gsd-dispatch-debug cross-project
# Output:
# - Check: TARGET_DIR environment variable
# - Check: Current git repository root
# - Check: .planning/ROADMAP.md in both locations
# - Check: PHASE definitions match between projects
# - Check: Log directory accessibility
```
- ✅ Focused diagnostics for the common failure pattern
- ✅ Guides user through typical cross-project issues
- ⚠️ Adds one more mode to maintain

**Why Option B**: Cross-project dispatch is the #1 failure pattern (soapwavehealing incident). A dedicated diagnostic mode reduces support friction and improves self-service resolution.

---

### Decision 8: Backwards Compatibility
**Question**: Should Phase 7 changes maintain full backwards compatibility?

**Option A**: Break changes for clarity
- ✅ Simpler implementation
- ❌ Existing TARGET_DIR workflows break
- ❌ Breaks soapwavehealing's working (if they set TARGET_DIR manually)

**Option B**: Full backwards compatibility ✅ **CHOSEN**
- TARGET_DIR env var still honored (checked first)
- PROJECT_DIR still computed (used as fallback)
- Existing scripts continue working
- New auto-detection is additive

**Why Option B**: soapwavehealing might have workarounds in place using TARGET_DIR. Phase 7 should improve the default experience without breaking existing solutions.

---

## Architectural Decisions

### Architecture Decision 1: Validation Layer
**Add pre-flight validation to gsd-dispatch.sh (before OpenCode dispatch)**

```
User invokes gsd-dispatch
  ↓
Parse arguments
  ↓
Validate PHASE format ← NEW
  ↓
Auto-detect or use TARGET_DIR ← NEW (with validation)
  ↓
Validate TARGET_DIR structure ← NEW
  ↓
OpenCode dispatch (unchanged)
```

**Rationale**: Fail-fast at earliest possible point. Catching errors before OpenCode dispatch saves 100+ seconds per failed dispatch.

---

### Architecture Decision 2: Diagnostic Routing
**gsd-dispatch-debug becomes the first-level support tool**

```
Dispatch fails
  ↓
User runs: gsd-dispatch-debug cross-project
  ↓
Tool identifies root cause (5-10 diagnostics)
  ↓
User sees:
  - ✗ Specific problem (e.g., "PHASE not in TARGET_DIR's ROADMAP")
  - ✅ How to fix it
  - 📝 Related command (e.g., "gsd-dispatch-debug check-env")
```

**Rationale**: Users can self-serve without opening issues or asking in chat. Debug tool becomes the authoritative source for "what went wrong".

---

## Scope Boundaries

### Included in Phase 7 ✅
1. Git-root auto-detection (gsd-dispatch.sh)
2. PHASE format validation (gsd-dispatch.sh)
3. TARGET_DIR structure validation (gsd-dispatch.sh)
4. Log directory unification (gsd-dispatch.sh)
5. Error message enhancement (gsd-dispatch.sh, gsd-dispatch-chain.sh)
6. Cross-project diagnostic mode (gsd-dispatch-debug.sh)
7. Documentation updates (DEVELOPMENT-WORKFLOW.md)

### Deferred to Phase 8+ ⏳
- Codex/Copilot dispatch support (multi-runtime extension)
- Wave-specific dispatch `gsd-dispatch 3.2` (requires ROADMAP redesign)
- Multi-project wave orchestration (requires state coordination)
- Parallel dispatch from multiple runtimes (requires coordination layer)

---

## Testing Strategy

### Unit Tests
- PHASE format validation (regex, edge cases)
- Git-root detection (in repo, outside repo, no .git)
- Path validation (missing .planning, missing ROADMAP.md, missing PHASE section)

### Integration Tests
- Local dispatch (gsd-addon) still works
- Cross-project dispatch (soapwavehealing) works without TARGET_DIR
- Backwards compat: explicit TARGET_DIR still honored
- Log directory correct for each TARGET_DIR

### E2E Tests (Using Actual Projects)
- soapwavehealing Phase 3 Wave 2-5 dispatch succeeds
- Logs appear in soapwavehealing/.planning/soldier-logs
- gsd-dispatch-debug cross-project identifies and fixes issues

---

## Dependencies on Other Phases

- **Phase 6** ✅: gsd-dispatch-chain.sh (will be enhanced with diagnostics)
- **Phase 6** ✅: gsd-dispatch-debug.sh (will get cross-project mode)
- **Milestone 1.2** ✅: Existing dispatch infrastructure

---

## Known Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Git-root detection fails in non-git directories | Low | Fallback to pwd; test coverage |
| Additional file I/O overhead | Low | Negligible (3 files vs. 100+ sec dispatch) |
| Backwards compat breaks existing workflows | Medium | Keep TARGET_DIR honored first |
| New diagnostic mode not discovered by users | Medium | Documentation + error messages reference it |
| Users still set wrong TARGET_DIR intentionally | Low | Validation will catch it; better error message |

---

## Success Criteria

1. **Auto-detection works** — Phase 3 dispatch from soapwavehealing without TARGET_DIR
2. **Validation prevents errors** — `gsd-dispatch --cwd` rejected with clear guidance
3. **Logs in correct place** — soapwavehealing/.planning/soldier-logs has Wave 2-5 logs
4. **Diagnostics accessible** — `gsd-dispatch-debug cross-project` runs successfully
5. **Backwards compatible** — Existing TARGET_DIR workflows unchanged
6. **Documentation updated** — DEVELOPMENT-WORKFLOW.md covers new patterns

---

## Design Rationale Summary

Phase 7 adopts GSD Core's proven patterns (git-root auto-detection, fail-fast validation) to solve the cross-project dispatch failures seen in soapwavehealing. Rather than inventing new patterns, we're standing on the shoulders of GSD Core's architecture while preserving gsd-addon's innovation (cross-runtime dispatch itself).

The design prioritizes:
1. **User experience** — Auto-detection removes manual setup burden
2. **Fail-fast** — Errors caught before expensive OpenCode dispatch
3. **Self-service** — Diagnostics guide users to solutions
4. **Backwards compatibility** — Existing workflows continue working

