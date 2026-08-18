---
status: resolved
trigger: gsd-dispatch global wrapper path mismatch - looking for dispatch/dispatch.sh but actual file is in scripts/gsd-dispatch.sh, causing silent fallback to non-existent opencode sub-command
created: 2026-08-18
updated: 2026-08-18
---

# Debug Session: gsd-dispatch Path Mismatch

## Symptoms

**Expected behavior**: `gsd-dispatch 1 local` should execute the dispatch workflow from `scripts/gsd-dispatch.sh`

**Actual behavior**: Command runs silently but produces no output from dispatch system, instead prints opencode help screen (exit code 0)

**Error messages**: None (silent failure - that's the problem)

**Timeline**: Discovered in soapwavehealing project testing; wrapper was created during gsd-addon v1.0.0 release but never smoke-tested

**Reproduction**: 
```bash
gsd-dispatch 1 local
# Shows opencode help screen instead of dispatch output
```

## Current Focus

**Hypothesis**: Global wrapper at `~/.local/bin/gsd-dispatch` looks for dispatch script at wrong path: `$GSD_ADDON_HOME/dispatch/dispatch.sh` (doesn't exist), then falls back to `opencode gsd dispatch` (invalid sub-command), causing silent failure with help screen

**Test**: Trace actual file locations and wrapper logic

**Expecting**: Path mismatch in wrapper + invalid fallback command confirmed

**Next action**: Gather initial evidence on file structure and wrapper behavior

**Reasoning checkpoint**: Bug is reproducible, path issue is documented in wiki, root cause appears clear but need to verify exact wrapper behavior

## Evidence

- timestamp: 2026-08-18 14:00
  source: gsd-dispatch-wrapper-bug-fix.md (ClaudeWiki)
  finding: Wrapper searches for dispatch/dispatch.sh (doesn't exist) then fallback to opencode gsd dispatch (invalid)
  
- timestamp: 2026-08-18 14:05
  source: file system check
  finding: Real file is at scripts/gsd-dispatch.sh (755 lines, complete implementation)
  
- timestamp: 2026-08-18 14:10
  source: wrapper inspection (/Users/bryan/.local/bin/gsd-dispatch line 21)
  finding: "if [ -f "$GSD_ADDON_HOME/dispatch/dispatch.sh" ];" - hardcoded wrong path
  
- timestamp: 2026-08-18 14:15
  source: wrapper fallback (line 25)
  finding: "exec opencode gsd dispatch "$@"" - fallback command doesn't exist in opencode

## Eliminated

(None yet)

## Root Cause

**Planning vs. Implementation Mismatch**:
- Original roadmap assumed dispatch script would be at `dispatch/dispatch.sh`
- Actual implementation placed it at `scripts/gsd-dispatch.sh`
- install.sh and wrapper were never updated to match implementation
- Silent fallback to invalid `opencode gsd dispatch` made the bug invisible

## Resolution

✅ **FIXED** (2026-08-18)

**Applied Fix**: Dual-location update (source + deployed)

1. **install.sh** (line 94):
   - Changed: `$GSD_ADDON_HOME/dispatch/dispatch.sh` 
   - To: `$GSD_ADDON_HOME/scripts/gsd-dispatch.sh`
   - Removed invalid fallback to `opencode gsd dispatch`

2. **~/.local/bin/gsd-dispatch** (line 21):
   - Changed: `$GSD_ADDON_HOME/dispatch/dispatch.sh`
   - To: `$GSD_ADDON_HOME/scripts/gsd-dispatch.sh`
   - Removed invalid fallback, added explicit error message

**Verification**:
- ✅ gsd-dispatch command now correctly locates script at scripts/gsd-dispatch.sh
- ✅ Help output shows correct dispatch system (not opencode help screen)
- ✅ No more silent failures
- ✅ Clear error messages if file is not found
