---
phase: 03-dispatch-source-install-drift
plan: "03"
subsystem: infra
tags: [bash, dispatch, opencode, prompts, template]

requires:
  - phase: 02-dispatch-timeout-hardening
    provides: run_with_timeout helper, curl --max-time 5, git diff --ignore-all-space (both files already had equivalent protection)

provides:
  - prompts-based dispatch design in source repo (execute/plan/research/check/revise modes)
  - build_prompt() Python env vars interpolation (safe, no special char issues)
  - extract_phase_section() for ROADMAP phase context injection
  - prompts/ directory (5 templates) in source repo
  - install.sh updated to copy prompts/ (fails loudly if missing)
  - source repo and installed copy now fully aligned

affects: [04-retry-wrapper, 05-integration-testing]

tech-stack:
  added: []
  patterns:
    - "prompts-based dispatch: each MODE maps to prompts/<mode>.md template with Python env vars substitution"
    - "cd TARGET_DIR before opencode run: no opencode.json cross-dir whitelist needed"
    - "extract_phase_section(): dynamic ROADMAP context injection via awk"

key-files:
  created:
    - prompts/execute.md
    - prompts/plan.md
    - prompts/research.md
    - prompts/check.md
    - prompts/revise.md
  modified:
    - scripts/gsd-dispatch.sh
    - install.sh
    - .planning/debug/opencode-server-error.md

key-decisions:
  - "Option A: backport installed copy's prompts-based design to source repo (not Option B: reinstall from source)"
  - "build_prompt() uses Python env vars, not sed/heredoc (safe for special chars in ROADMAP)"
  - "cd TARGET_DIR approach: eliminates opencode.json cross-dir whitelist dependency"
  - "prompts/ install failure is hard error (exit 1), not a warning"

requirements-completed: []

duration: 18min
completed: 2026-08-19
---

# Phase 3：Source/安裝副本分岔修復 Summary

**prompts-based dispatch（含 check/revise 模式）回灌 source repo；`build_prompt()` Python env vars 已驗證安全；兩份 gsd-dispatch.sh 現在完全一致**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-08-19T00:00:00Z（估計）
- **Completed:** 2026-08-19
- **Tasks:** 4 (3.1 audit + 3.2 verify + 3.3 backport + 3.4 validate)
- **Files modified:** 8 (gsd-dispatch.sh, install.sh, 5 prompts, debug doc)

## Accomplishments

- 完整盤點已安裝副本 prompts-based 設計與 source repo 舊版 `--command` 設計的所有差異點
- 確認 `build_prompt()` 插值 bug 在當前安裝副本**已不存在**（Python env vars 方式，測試通過）
- 選擇 Option A，將安裝副本的先進設計完整回灌 source repo，同時補建 `prompts/` 目錄
- 更新 `install.sh` 包含 `prompts/` 複製步驟（缺失時 exit 1）
- `diff`、`bash -n`、`build_prompt()` 功能測試全部通過

## Task Commits

1. **Task 3.1+3.2: 盤點分岔 + 確認 bug 狀態** - `34123d7` (chore)
2. **Task 3.3: 回灌 prompts-based 設計到 source repo** - `67070d9` (feat)
3. **Task 3.4: 端對端驗證** - `a9d58e7` (chore)

## Files Created/Modified

- `scripts/gsd-dispatch.sh` — 已更新為 prompts-based 版本（`build_prompt()`、`extract_phase_section()`、check/revise 模式、cd TARGET_DIR 方式）
- `prompts/execute.md` — gsd-executor 角色 + 執行規則範本
- `prompts/plan.md` — gsd-planner 角色 + 規劃規則範本
- `prompts/research.md` — gsd-phase-researcher 角色 + 研究維度範本
- `prompts/check.md` — gsd-plan-checker 角色 + 驗證維度範本
- `prompts/revise.md` — gsd-planner 修訂模式 + 修訂規則範本
- `install.sh` — 新增 `prompts/` 複製區塊（缺失時 exit 1）
- `.planning/debug/opencode-server-error.md` — 補充 2026-08-19 分岔發現記錄 + Task 3.4 驗證結果

## Decisions Made

- **Option A（回灌）優於 Option B（重裝 source 版本）**：安裝副本的 prompts-based 設計解決了 opencode v1.17.5 `--command + --dir` crash workaround，且 Python env vars 替換比 sed 更安全；丟棄這個設計會退步。
- **build_prompt() 現狀**：當前安裝副本的 Python env vars 方式不需要額外修復，bug 描述對應的是更早期版本的行為。
- **prompts/ 安裝為強制**：install.sh 中若 `prompts/` 目錄不存在則 exit 1（非警告），因為沒有 prompts 則整個 dispatch 無法運作。
- **cd TARGET_DIR 方式取代 opencode.json 白名單**：跨專案派工不再需要維護 opencode.json 的 read/external_directory 白名單。

## Deviations from Plan

### 偏離說明

**Task 3.2（修復 build_prompt() bug）— 無需修復**
- **發現**：當前已安裝副本的 `build_prompt()` 已使用 Python env vars 方式，插值 bug 不存在
- **處置**：改為驗證（確認無 bug）+ 記錄（說明 bug 對應更早期版本），沒有產生程式碼修改
- **影響**：無，實際修復工作量零，其他任務不受影響

---

**Total deviations:** 1（計畫說 bug 存在需修復，實際 bug 已修復無需動手）
**Impact on plan:** 無負面影響，驗證即為 Task 3.2 的完成準則

## Known Stubs

無。所有 5 個 prompt 範本均為完整可用內容，沒有佔位符或 TODO。

## Threat Flags

無新增安全面向。gsd-dispatch.sh 不涉及網路端點、驗證路徑或資料庫存取。

## Issues Encountered

- **prompts/ 目錄初始搜尋路徑誤判**：第一次搜尋時以為 prompts 在 `~/.claude/gsd-addon/scripts/prompts/`（不存在），後確認正確路徑為 `~/.claude/gsd-addon/prompts/`（存在，5 個檔案齊全）。不影響最終結果。

## Next Phase Readiness

- Phase 4（Retry Wrapper Implementation）：`scripts/gsd-dispatch.sh` 現在是 prompts-based 版本，retry wrapper 只需處理一份邏輯，不再有雙版本問題
- 跨專案派工（`TARGET_DIR` != `PROJECT_DIR`）：cd 方式已經可以直接使用，不需要額外白名單設定
- 新增 MODE：若需要新模式，只需在 `prompts/` 新增 `<mode>.md` + 在 case 語句加入對應項，無需大幅修改腳本邏輯

---
*Phase: 03-dispatch-source-install-drift*
*Completed: 2026-08-19*
