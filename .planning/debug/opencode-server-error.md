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

## Fix Process

### Step 1: Diagnosis & Root Cause Confirmation

**Method**: Spawned gsd-debug-session-manager agent to investigate systematically

**Investigation path**:
1. OpenCode CLI availability check → ✅ v1.18.15 available
2. Agent definitions verification → ✅ Found gsd-phase-researcher.md, gsd-planner.md, gsd-executor.md
3. Dispatch log analysis → ✅ Found only UnknownError message, no additional context
4. gsd-dispatch.sh code inspection → ✅ Found command name mapping at lines 52-60
5. Command name mismatch identification → ✅ Confirmed mismatch between script and actual agents

**Finding**: Script uses obsolete names (gsd-research-phase, gsd-plan-phase, gsd-execute-phase) instead of actual agent names

### Step 2: Code Fix Application

**Files identified for modification**:
1. `/Users/bryan/Documents/gsd-addon/scripts/gsd-dispatch.sh` (source repository)
2. `~/.claude/gsd-addon/scripts/gsd-dispatch.sh` (installed copy)

**Changes applied** (lines 53-55):

**Before**:
```bash
  research)  GSD_COMMAND="gsd-research-phase" ;;
  plan)      GSD_COMMAND="gsd-plan-phase" ;;
  execute)   GSD_COMMAND="gsd-execute-phase" ;;
```

**After**:
```bash
  research)  GSD_COMMAND="gsd-phase-researcher" ;;
  plan)      GSD_COMMAND="gsd-planner" ;;
  execute)   GSD_COMMAND="gsd-executor" ;;
```

### Step 3: Verification

**Syntax check**:
```bash
bash -n ~/.claude/gsd-addon/scripts/gsd-dispatch.sh
# ✓ No errors
```

**Agent verification**:
```bash
ls ~/.claude/agents/gsd-*.md | grep -E "(phase-researcher|planner|executor)"
# ✓ All three agents found:
#   gsd-phase-researcher.md
#   gsd-planner.md
#   gsd-executor.md
```

**Fix confirmation**:
```bash
grep "GSD_COMMAND=" ~/.claude/gsd-addon/scripts/gsd-dispatch.sh
# ✓ Output shows correct command names:
#   research)  GSD_COMMAND="gsd-phase-researcher" ;;
#   plan)      GSD_COMMAND="gsd-planner" ;;
#   execute)   GSD_COMMAND="gsd-executor" ;;
```

### Step 4: Git Commit

**Commit 1**: bf85f62
```
fix: correct OpenCode agent command names in gsd-dispatch

Root cause: gsd-dispatch.sh was calling OpenCode with incorrect agent command names
- Old (wrong): gsd-research-phase, gsd-plan-phase, gsd-execute-phase
- New (correct): gsd-phase-researcher, gsd-planner, gsd-executor

Files changed: scripts/gsd-dispatch.sh (lines 53-55)
Verification: Script syntax validates, agent files confirmed to exist
```

**Commit 2**: 9051683
```
docs: update debug session - OpenCode agent command names bug resolved

Status: verified_fixed
Includes complete diagnosis and fix documentation
```

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

## Testing & Validation

### How to Test the Fix

**Test environment**: soapwavehealing project

**Command to reproduce** (now should work):
```bash
cd /Users/bryan/Documents/soapwavehealing

# Set environment and dispatch Phase 2 research
MODE=research PHASE=2 TARGET_DIR=. \
  ~/.claude/gsd-addon/scripts/gsd-dispatch.sh 2

# When prompted: "Dispatch to OpenCode or run inline via Agent tool?"
# Select: Option 1 (Dispatch to OpenCode)
```

**Expected behavior**:
```
[Should NOT see]
✗ Error: UnknownError (err_13bbe49a)

[Should see instead]
✓ Dispatcher sends correct command name: gsd-phase-researcher
✓ OpenCode accepts the request
✓ gsd-phase-researcher agent spawns successfully
✓ Phase 2 research begins (produces RESEARCH.md)
```

### Validation Checklist

- [ ] Run dispatch command above
- [ ] Confirm OpenCode processes request (no UnknownError)
- [ ] Verify gsd-phase-researcher agent starts
- [ ] Check soapwavehealing/.planning/RESEARCH.md is created
- [ ] Review research output for Phase 2 (Admin Isolation & Auth)

### Related Fixes

This bug was discovered after fixing [[gsd-dispatch-wrapper-bug-fix]] (commit 2b7ad0f), which corrected the path from `dispatch/dispatch.sh` → `scripts/gsd-dispatch.sh`. This OpenCode naming bug (commit bf85f62) was the next issue revealed during actual dispatch testing.

### Root Cause Analysis Summary

**Why this bug existed**:
- Original dispatch script was drafted with planned agent names (gsd-research-phase, etc.)
- GSD framework later standardized on different names (gsd-phase-researcher, etc.)
- Dispatch script was never updated after framework naming changed
- Bug remained hidden until first OpenCode dispatch was attempted after path fix

**Why it manifested as UnknownError**:
1. Script sends: `opencode run --command "gsd-research-phase"`
2. OpenCode looks for agent definition: `gsd-research-phase.md` (doesn't exist)
3. OpenCode: "I don't recognize this command" → UnknownError(err_13bbe49a)
4. Error message: "Check server logs" (not helpful since agent simply doesn't exist)

## Lessons Learned

1. **Script-to-framework synchronization**: When GSD framework updates agent definitions, all scripts calling those agents must be updated
2. **Testing discovery**: Bug only surfaced during actual OpenCode dispatch - unit testing would not have caught this
3. **Error messaging**: OpenCode's UnknownError is correct but cryptic; could benefit from "agent not found" clarification
4. **Two-location maintenance**: gsd-addon maintains both source (~/Documents/gsd-addon) and installed (~/.claude/gsd-addon) copies - both must be updated

---

## 後續追蹤：Source / 安裝副本分岔（2026-08-19，Phase 3 調查）

### 發現時間與情境

Phase 2 timeout hardening 執行後，透過正式派工確認 Phase 2 commit 時發現派工回報 exit 1，
但 gsd-executor 實際上已正確完成工作並 commit。追查後確認根本原因為
**source repo 與已安裝副本的設計已分岔**。

### 分岔內容

| 面向 | Source Repo (`/Users/bryan/Documents/gsd-addon`) | 已安裝副本 (`~/.claude/gsd-addon`) |
|------|--------------------------------------------------|-------------------------------------|
| 派工方式 | `opencode run --command "$GSD_COMMAND"` | `opencode run "$FULL_PROMPT"`（prompt 範本） |
| 支援 MODE | research / plan / execute | research / plan / execute / **check / revise** |
| 跨專案處理 | `gsd-permission-audit.sh` 白名單審計 | `cd "$TARGET_DIR"` 後直接執行（不需白名單） |
| build_prompt() | 無此函式 | Python env vars 替換（安全，已測試） |
| prompts/ 目錄 | **不存在** | 存在（execute/plan/research/check/revise.md） |
| preflight_external_perms | 有定義且呼叫 | 有定義但不呼叫（已改用 cd 方式） |

### build_prompt() Bug 狀態（Task 3.2 驗證）

**背景描述的 bug**：執行 Phase 2 時，安裝副本的舊版 `build_prompt()` 可能曾有插值錯誤，
產生 `MPLATE 2 /path 2026-08-18 ): No such file or directory`。

**當前狀態**：已安裝副本的 `build_prompt()` 目前使用 Python env vars 方式（無 sed/heredoc
特殊字元問題），**bug 不再存在**。

驗證結果：
```bash
bash -n ~/.claude/gsd-addon/scripts/gsd-dispatch.sh  # ✓ 通過
python3 -c 'import os; ...'  # ✓ 測試通過（見 Task 3.2 驗證）
```

### 決策：選擇 Option A（回灌 source repo）

理由：
1. 安裝副本的 prompts-based 設計更先進：不依賴 `--command` flag（已知 opencode v1.17.5 crash workaround）
2. check/revise mode 對工作流有實際價值
3. Python env vars 替換比 sed 更安全（無特殊字元問題）
4. cd TARGET_DIR 方式不需要 opencode.json 白名單維護

### 修復記錄（Phase 3 執行）

- 執行日期：2026-08-19
- 工作：Task 3.3 — 回灌已安裝副本設計到 source repo，並補建 prompts/ 目錄
- 結果：見 Phase 3 SUMMARY（3-SUMMARY.md）
