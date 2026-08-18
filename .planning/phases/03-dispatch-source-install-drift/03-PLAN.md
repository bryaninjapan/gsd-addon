---
phase: 3
name: "Source/安裝副本分岔修復"
milestone: "1.2"
status: "Ready"
timeline: "2026-08-19"
---

# Phase 3：Source/安裝副本分岔修復

**目標**: 協調 `/Users/bryan/Documents/gsd-addon/scripts/gsd-dispatch.sh`（source repo）與
`~/.claude/gsd-addon/scripts/gsd-dispatch.sh`（已安裝副本）之間的分岔，並修復已安裝副本
`build_prompt()` 函式中的變數插值 bug。

**成功標準**:
- [ ] 確認已安裝副本「prompts-based 重構」的完整設計與 source repo 版本的差異範圍
- [ ] 決定策略：把重構版本回灌 source repo（推薦，因為更先進）還是保留 source repo 版本並重新安裝覆蓋已安裝副本
- [ ] 修復 `build_prompt()` 第 226 行附近的插值 bug（症狀：`MPLATE 2 /path 2026-08-18 ): No such file or directory`）
- [ ] 兩份檔案（source + 安裝副本）語法檢查通過且邏輯一致
- [ ] 執行一次真實派工驗證 bug 已修復

**責任人**: 建議 Sonnet（此任務需要判斷「該採用哪個設計版本」，屬於架構決策，不是機械式編輯）
**預期時間**: 2 小時

---

## 背景

執行 Phase 2（timeout hardening）時，透過 `gsd-dispatch 2`（正式派工）觸發 gsd-executor 修改
source repo 的 `gsd-dispatch.sh` 並提交成功（4 個 commits，見 Phase 2 SUMMARY）。但派工本身回報
`exit code 1`，追查後發現：

1. `~/.claude/gsd-addon/scripts/gsd-dispatch.sh`（已安裝副本，也就是 `gsd-dispatch` 全域指令實際
   執行的版本）已經是一個**未提交、更新過的 prompts-based 重構版本**，改用 `prompts/<mode>.md` 範本
   組出 freeform prompt，而不是 source repo 版本用的 `--command "$GSD_COMMAND"` CLI flag 方式。
2. 這個重構版本本身在 `build_prompt()` 函式（約第 130-150 行）附近有 bug，導致組出的變數在
   後續某處被錯誤地當成指令執行，產生 `No such file or directory` 錯誤，讓整個派工在士兵（gsd-executor）
   其實已經正確完成工作、正確 commit 之後，仍然回報失敗。
3. 這與先前懷疑的「OpenCode 伺服器暫時性錯誤」無關——本次是純粹的腳本邏輯 bug，且只存在於已安裝
   副本，source repo 版本沒有這個問題（因為 source repo 版本用的是舊的 `--command` 分支邏輯）。

**根本問題**：這個 gsd-addon 專案存在雙份 `gsd-dispatch.sh`（source repo + 安裝到 `~/.claude/gsd-addon`
的副本），過去的假設是「兩者應該永遠保持逐字元相同」（見 `.planning/debug/gsd-dispatch-opencode-server-error.md`
中 2026-08-18 稍早的 diff 驗證記錄）。但這個假設已經被打破——已安裝副本被獨立修改過，且從未同步回 source repo。

---

## 任務分解

### 任務 3.1：完整盤點已安裝副本的重構設計

**動作**:
1. 通讀 `~/.claude/gsd-addon/scripts/gsd-dispatch.sh` 全文，理解 `prompts/<mode>.md` 範本機制的完整設計
2. 確認 `prompts/` 目錄實際內容（`ls ~/.claude/gsd-addon/scripts/prompts/` 或類似路徑）
3. 列出這個重構版本相對於 source repo 版本的**所有**差異點（不只是 build_prompt bug）
4. 判斷這個重構版本是否解決了 source repo 版本原本就有的已知問題（例如 opencode v1.17.5 的
   `--command` + `--dir` 崩潰 workaround，重構版本用 `cd` 到 TARGET_DIR 的方式可能已經繞過這個問題）

**驗收標準**: 產出一份差異清單（可以是 SUMMARY.md 的一部分），並附上是否推薦回灌 source repo 的建議

---

### 任務 3.2：修復 build_prompt() 插值 bug

**動作**:
1. 重現錯誤：`bash -x ~/.claude/gsd-addon/scripts/gsd-dispatch.sh <phase>` 找出第 226 行附近實際
   出錯的變數插值
2. 檢查 `build_prompt()` 函式（python3 heredoc 插值）與其呼叫處 `FULL_PROMPT="$(build_prompt ...)"`
   之間是否有引號/展開問題
3. 修復後重新測試，確認 `bash -x` 不再出現 `MPLATE ...: No such file or directory` 這類指令注入
   式的錯誤

**驗收標準**: bug 修復後，`bash -x` 追蹤不再出現非預期的指令執行；`bash -n` 語法檢查通過

---

### 任務 3.3：決定並執行同步策略

**選項 A（推薦）**: 把已安裝副本的 prompts-based 重構（含 Phase 3.2 的 bug 修復）正式回灌到
source repo，取代 source repo 目前的 `--command` flag 版本，並把 Phase 2 已經加上去的
timeout 保護（`run_with_timeout`、`--max-time 5`、`--ignore-all-space`）移植過去。

**選項 B**: 捨棄已安裝副本的重構，用 `install.sh` 重新安裝、以 source repo 版本覆蓋已安裝副本。
風險：可能丟失重構版本已經解決的問題（例如 opencode v1.17.5 crash workaround 的替代方案）。

**動作**: 先完成任務 3.1 的差異盤點後才能做出決定；預設傾向選項 A，除非發現重構版本有更嚴重的
未知問題。

**驗收標準**: 兩份檔案內容一致（或明確記錄為何刻意不同）、`git diff` 乾淨、決策理由記錄在 SUMMARY.md

---

### 任務 3.4：端對端驗證

**動作**:
```bash
MODE=execute TARGET_DIR=/Users/bryan/Documents/gsd-addon gsd-dispatch <下一個測試用 phase 編號>
```
確認派工能正常完成且回報正確的 exit code（不再有 226 行附近的假性失敗）。

**驗收標準**: 派工 exit code 與士兵實際完成狀態一致（成功回 0、失敗回非 0，且失敗原因可從
log 判讀，不再有插值 bug 造成的假性失敗）

---

## 完成後動作

完成本 Phase 後：
1. 產出 `03-1-SUMMARY.md`
2. 更新 `.planning/debug/gsd-dispatch-opencode-server-error.md`，補充「2026-08-19 發現 source/
   安裝副本分岔」的後續記錄
3. 準備進入 Milestone 1.2 / Phase 4（Retry Wrapper Implementation）——此時兩份檔案應已一致，
   重試 wrapper 只需要處理一份邏輯
