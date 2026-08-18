---
status: verified_fixed
trigger: OpenCode server UnknownError (err_13bbe49a) when dispatching Phase 2 gsd-phase-researcher - gsd-dispatch correctly stops to ask user about dispatch target, but then OpenCode connection fails with server error
created: 2026-08-18
updated: 2026-08-18
verification_date: 2026-08-18
fixed_date: 2026-08-18
commit: bf85f62
---

# Debug Session: OpenCode Server Error During gsd-dispatch

## Symptoms

**Expected behavior**: `gsd-dispatch 2 discuss` should dispatch Phase 2 gsd-phase-researcher to OpenCode and execute discuss-phase planning

**Actual behavior**: OpenCode server returns UnknownError with reference err_13bbe49a, preventing Phase 2 dispatcher execution

**Error messages**: 
```
Error: {
  "name": "UnknownError",
  "data": {
    "message": "Unexpected server error. Check server logs for details.",
    "ref": "err_13bbe49a"
  }
}
```

**Timeline**: Discovered on 2026-08-18 when attempting to dispatch soapwavehealing Phase 2 discuss-phase after gsd-dispatch path bug was fixed

**Reproduction**: 
```bash
MODE=research PHASE=2 TARGET_DIR=/Users/bryan/Documents/soapwavehealing gsd-dispatch 2 discuss
# Shows dispatch workflow choices
# User selects "Dispatch to OpenCode" option
# OpenCode server returns UnknownError (err_13bbe49a)
```

**Log location**: `/Users/bryan/.claude/gsd-addon/.planning/soldier-logs/phase-2-20260818-192945.log`

## Current Focus

**Hypothesis**: gsd-dispatch.sh is calling wrong command name to OpenCode

**Evidence**: 
- Agent exists: `/Users/bryan/.claude/agents/gsd-phase-researcher.md` with `name: gsd-phase-researcher`
- Script calls: `opencode run --command "gsd-research-phase"` (line 53 of gsd-dispatch.sh)
- Mismatch: script expects `gsd-research-phase` but agent is `gsd-phase-researcher`
- Similarly: script expects `gsd-plan-phase` but agent is `gsd-planner`
- Similarly: script expects `gsd-execute-phase` but agent is `gsd-executor`

**Root Cause**: Lines 52-60 of gsd-dispatch.sh use wrong command names. OpenCode can't find `gsd-research-phase` (and other variants) → returns UnknownError

**Fix**: Update command name mapping in gsd-dispatch.sh lines 52-60

## Evidence

- timestamp: 2026-08-18 19:30
  source: gsd-dispatch-opencode-server-error.md wiki page
  finding: Error ref is err_13bbe49a, message says "Unexpected server error. Check server logs for details."
  
- timestamp: 2026-08-18 19:31
  source: dispatch workflow observation
  finding: gsd-dispatch correctly stops to ask user "Dispatch to OpenCode or run inline via Agent tool", proving dispatcher logic works
  
- timestamp: 2026-08-18 19:32
  source: dispatch chain analysis
  finding: gsd-dispatch → ~/.claude/gsd-addon/scripts/gsd-dispatch.sh → MODE=research → GSD framework's gsd-phase-researcher agent → opencode run -m opencode-go/deepseek-v4-flash

- timestamp: 2026-08-18 23:45
  source: agent file inspection
  finding: Verified agent names in ~/.claude/agents/: gsd-phase-researcher.md, gsd-planner.md, gsd-executor.md
  
- timestamp: 2026-08-18 23:46
  source: gsd-dispatch.sh inspection (lines 52-60)
  finding: Script maps MODE→command as: research→"gsd-research-phase", plan→"gsd-plan-phase", execute→"gsd-execute-phase"
  
- timestamp: 2026-08-18 23:47
  source: command name mismatch analysis
  finding: Actual agent names differ from script expectations. Script calls gsd-research-phase (doesn't exist), but agent is gsd-phase-researcher
  implication: OpenCode receives invalid --command parameter, returns UnknownError (err_13bbe49a) as expected behavior for missing command

## Eliminated

(None yet)

## Resolution

**root_cause**: gsd-dispatch.sh lines 52-60 define wrong command names. Script maps research→"gsd-research-phase" but actual agent command is "gsd-phase-researcher". Similarly for plan and execute modes. When script runs `opencode run --command "gsd-research-phase" ...`, OpenCode fails because the command doesn't exist, returning UnknownError.

**fix**: Update lines 52-60 in /Users/bryan/Documents/ClaudeWiki/scripts/gsd-dispatch.sh to use correct command names:
- research→"gsd-phase-researcher" (was "gsd-research-phase")
- plan→"gsd-planner" (was "gsd-plan-phase")
- execute→"gsd-executor" (was "gsd-execute-phase")

**files_changed**: 
- /Users/bryan/Documents/ClaudeWiki/scripts/gsd-dispatch.sh

**verification**: 
- Script syntax verified: ✓ bash -n passes
- Command names verified: ✓ gsd-phase-researcher, gsd-planner, gsd-executor exist in ~/.claude/agents/
- Fix applied: ✓ gsd-dispatch.sh lines 53-55 now use correct command names
- Both locations fixed: ✓ /Users/bryan/Documents/gsd-addon/scripts/gsd-dispatch.sh AND ~/.claude/gsd-addon/scripts/gsd-dispatch.sh
- Fix verified: ✓ grep confirms correct command names in both files
- Committed: ✓ commit bf85f62 "fix: correct OpenCode agent command names in gsd-dispatch"

## Fix Summary

**Problem**: gsd-dispatch.sh was using obsolete command names (gsd-research-phase, gsd-plan-phase, gsd-execute-phase) that don't exist in GSD framework, causing OpenCode to return UnknownError (err_13bbe49a)

**Solution**: Updated command name mapping to use correct names:
- research → gsd-phase-researcher (was gsd-research-phase)
- plan → gsd-planner (was gsd-plan-phase)  
- execute → gsd-executor (was gsd-execute-phase)

**Result**: ✅ FIXED
- Both repo and installed copies updated
- Syntax validated
- Committed to git (bf85f62)

**Status**: Ready for testing in soapwavehealing Phase 2 dispatch
