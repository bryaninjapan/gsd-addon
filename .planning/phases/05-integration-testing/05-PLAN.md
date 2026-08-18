---
phase: 5
name: "Integration & Testing"
milestone: "1.2"
status: "Ready"
timeline: "2026-08-20"
---

# Phase 5：Integration & Testing

**目標**: 集成超時修復（Phase 2）和重試 wrapper（Phase 4），在 soapwavehealing 中進行端對端驗證，
確保重試機制不與 GSD checkpoint 機制衝突，並更新相關文檔。

**成功標準**:
- [ ] `bash install.sh` 執行成功，所有組件正確安裝
- [ ] 無重試基線測試：`gsd-dispatch <phase>` 行為不變
- [ ] 重試測試：`RETRY=true gsd-dispatch <phase>` 在失敗時自動重試（最多 3 次）
- [ ] Checkpoint 無衝突：重試不會刪除或覆蓋既有的 RESEARCH.md/PLAN.md 等
- [ ] 超時設置合理：opencode 3600s、curl 5s 在實際派工中不誤觸發
- [ ] `DEVELOPMENT-WORKFLOW.md` 更新：加入派工排障章節、重試機制使用說明
- [ ] Milestone 1.2 驗收完成

**責任人**: Claude Code
**前置依賴**: Phase 4 完成（dispatch-with-retry.sh 存在且可執行）
**預期時間**: 2-3 小時

---

## 任務分解

### 任務 5.1：部署最新代碼

**動作**:
1. 在 gsd-addon source repo 執行 `bash install.sh`
2. 驗證安裝結果：
   - `~/.local/bin/gsd-dispatch` 包含 RETRY 分支邏輯
   - `~/.claude/gsd-addon/scripts/dispatch-with-retry.sh` 存在且可執行
   - `~/.claude/gsd-addon/scripts/gsd-dispatch.sh` 與 source repo 版本一致
   - `~/.claude/gsd-addon/prompts/` 5 個範本存在

**驗收標準**: `bash install.sh` 輸出全部 ✓，無任何 ✗

---

### 任務 5.2：無重試基線測試（soapwavehealing）

**動作**:
在 soapwavehealing 中確認默認行為不變：
```bash
cd /Users/bryan/Documents/soapwavehealing
unset RETRY
# 選擇一個實際存在的 phase 執行
MODE=research TARGET_DIR=. gsd-dispatch <phase>
```

確認：
- exit code 與預期一致（成功=0，失敗≠0）
- log 檔案正常生成在 `~/.claude/gsd-addon/logs/`
- 無任何重試行為

**驗收標準**: 派工完成，行為與 Phase 2/3 修復前邏輯一致（只是現在有超時保護）

---

### 任務 5.3：啟用重試測試

**動作**:
```bash
cd /Users/bryan/Documents/soapwavehealing
RETRY=true gsd-dispatch <phase>
```

觀察：
- 若派工成功：正常退出，無重試（`RETRY=true` 只在失敗時生效）
- 若派工失敗：自動重試，日誌顯示 `[retry] attempt N/3 failed...`
- 最終 exit code 正確反映最後一次結果

**驗收標準**: 重試行為如預期；日誌清晰記錄每次嘗試

---

### 任務 5.4：Checkpoint 無衝突驗證

**動作**:
1. 在 soapwavehealing 執行一次派工（或確認有現存的 .planning/ checkpoint 文件）
2. 執行 `RETRY=true gsd-dispatch <phase>` 並觀察重試
3. 驗證：
   - `.planning/` 下既有文件（RESEARCH.md、PLAN.md 等）未被刪除或覆蓋
   - 每次重試使用獨立的 log 檔案（不同時間戳）
   - 重試不會重置 GSD checkpoint

**驗收標準**: Checkpoint 文件完好；每次重試有獨立 log；gsd-executor 的 checkpoint 未受影響

---

### 任務 5.5：超時合理性驗證

**動作**:
1. 確認 opencode 3600s 超時：正常派工通常 5-30 分鐘，3600s 不會誤觸發
2. 確認 curl 5s 超時：session/liveness check 通常 < 1s，5s 不會誤觸發
3. 若有疑慮，讀取最近幾個 log 檔案確認 curl 回應時間

**驗收標準**: 超時設置在實際使用中無誤觸發；不需調整

---

### 任務 5.6：更新 DEVELOPMENT-WORKFLOW.md

**動作**:
在 `DEVELOPMENT-WORKFLOW.md` 新增/更新「派工排障」章節，內容包含：
1. 如何啟用重試：`RETRY=true gsd-dispatch <phase>`
2. 何時不應重試：參數錯誤、權限問題（retry wrapper 會自動識別並跳過）
3. 超時設置說明（opencode 3600s / curl 5s / git diff 保護）
4. 常見 OpenCode 伺服器錯誤（err_xxxxxxxx）的處理方式
5. 如何排查 log 檔案

**驗收標準**: 文檔清晰，新使用者看完能獨立排障

---

### 任務 5.7：Milestone 1.2 驗收

**動作**:
執行最終驗收：
- [ ] Phase 2：3 處超時保護（opencode/curl/git）確認存在 ✅
- [ ] Phase 3：source repo 與安裝副本完全一致 ✅
- [ ] Phase 4：dispatch-with-retry.sh 可執行、RETRY 環境變數有效
- [ ] Phase 5：soapwavehealing 端對端驗證通過
- [ ] Code Review 8 項 bug 修復確認

產出 `05-SUMMARY.md`，標記 Milestone 1.2 完成。

**驗收標準**: 所有 checkbox 勾選；SUMMARY.md 完整記錄測試結果

---

## 完成後動作

1. 產出 `05-SUMMARY.md`（含驗收報告）
2. 更新 ROADMAP.md 標記 Milestone 1.2 ✅ 完成
3. 更新 STATE.md
4. Git commit & push（可選）
5. 準備進入 Phase 6（社區反饋）
