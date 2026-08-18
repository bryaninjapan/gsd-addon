# Phase 1.2C：Integration & Testing — 實現計畫

**狀態**: 📋 規劃中  
**估時**: 3.5 小時  
**負責人**: Claude Code  
**前置依賴**: Phase 1.2A 與 1.2B 必須完成  

---

## 📌 Phase 目標

集成超時修復和重試 wrapper，在 soapwavehealing 中進行端對端驗證，確保不與 GSD checkpoint 機制衝突。

---

## 🎯 成功驗收標準

- [x] 在 soapwavehealing 中成功派工 Phase 2 研究
- [x] 驗證重試機制正常工作
- [x] 驗證無重試時默認行為不變
- [x] 驗證重試不與 GSD checkpoint 衝突
- [x] 驗證超時時間設置合理
- [x] 更新 DEVELOPMENT-WORKFLOW.md
- [x] 完成測試報告

---

## 📝 實現任務分解

### Task 1.2C.1：部署更新
**狀態**: ⏳ 待執行

**具體工作**:
1. 運行 install.sh 安裝最新代碼
2. 驗證 ~/.local/bin/gsd-dispatch 已更新
3. 驗證 ~/.claude/gsd-addon/scripts/dispatch-with-retry.sh 已複製
4. 確認 gsd-dispatch.sh 已更新（帶 timeout）

**預計時間**: 30 分鐘

**驗收標準**:
- install.sh 執行成功
- ~/.local/bin/gsd-dispatch 包含環境變數邏輯
- dispatch-with-retry.sh 存在且可執行
- gsd-dispatch.sh 包含三處 timeout

---

### Task 1.2C.2：無重試基線測試
**狀態**: ⏳ 待執行

**具體工作**:
在 soapwavehealing 中測試無重試的默認行為：

```bash
cd /Users/bryan/Documents/soapwavehealing

# 確認環境變數未設置重試
unset RETRY

# 嘗試派工 Phase 2（預期：成功或單次失敗）
MODE=research PHASE=2 TARGET_DIR=. gsd-dispatch 2 discuss
```

**預計時間**: 1 小時

**驗收標準**:
- 派工成功（無需重試）或單次失敗後停止
- 日誌檔案正常生成
- exit code 為 0（成功）或 1（失敗）

---

### Task 1.2C.3：啟用重試測試
**狀態**: ⏳ 待執行

**具體工作**:
測試啟用重試機制：

```bash
cd /Users/bryan/Documents/soapwavehealing

# 啟用重試
export RETRY=true

# 派工 Phase 2
MODE=research PHASE=2 TARGET_DIR=. gsd-dispatch 2 discuss
```

**預計時間**: 1 小時

**驗收標準**:
- 如果派工失敗，wrapper 自動重試（最多 3 次）
- 每次重試都在日誌中記錄
- 最終成功或失敗後停止重試
- exit code 正確反映最終結果

---

### Task 1.2C.4：驗證 Checkpoint 無衝突
**狀態**: ⏳ 待執行

**具體工作**:
1. 檢查 soapwavehealing/.planning/ 目錄中的 checkpoint 文件（PLAN.md、RESEARCH.md 等）
2. 驗證重試不會刪除或修改已有的 checkpoint
3. 驗證每次派工都創建新的日誌檔案（不同的時間戳）

**預計時間**: 30 分鐘

**驗收標準**:
- Checkpoint 文件完好無損
- 每次派工有獨立的日誌檔案
- 重試的日誌檔案名稱不同
- RESEARCH.md/PLAN.md 內容未被修改

---

### Task 1.2C.5：超時設置驗證
**狀態**: ⏳ 待執行

**具體工作**:
1. 驗證 opencode run 的 3600 秒超時（1 小時，合理）
2. 驗證 curl 的 5 秒超時（快速失敗，合理）
3. 檢查是否有不合理的超時導致正常派工被中斷

**預計時間**: 30 分鐘

**驗收標準**:
- opencode 派工通常在 5-30 分鐘內完成，3600s 足夠
- curl 檢查 < 1 秒，5s 超時不會誤觸發
- 無關鍵派工因超時失敗

---

### Task 1.2C.6：文檔更新
**狀態**: ⏳ 待執行

**具體工作**:
1. 更新 DEVELOPMENT-WORKFLOW.md 的派工排障章節
2. 記錄重試機制的使用方式
3. 記錄超時時間設置和理由
4. 記錄何時應該禁用重試

**預計時間**: 1 小時

**驗收標準**:
- DEVELOPMENT-WORKFLOW.md 有"派工排障"章節
- 清晰說明如何啟用重試：`RETRY=true gsd-dispatch 2 discuss`
- 記錄了三個超時的設置和理由
- 記錄了 wrapper 錯誤分類的邏輯

---

### Task 1.2C.7：驗收報告
**狀態**: ⏳ 待執行

**具體工作**:
生成驗收報告，記錄所有測試結果：

```markdown
# Phase 1.2C 驗收報告

## 測試環境
- 日期: 2026-08-20
- 項目: soapwavehealing
- Phase: 2 (discuss-phase)

## 測試結果

### 無重試測試
- [x] 派工成功/失敗：___
- [x] 日誌正常生成
- [x] exit code 正確

### 重試測試
- [x] 重試工作：___
- [x] 重試次數/延遲：___
- [x] 最終結果：___

### Checkpoint 驗證
- [x] 無衝突：___

### 超時驗證
- [x] 合理性確認：___

## 簽核
- 日期: ___
- 測試者: ___
```

**預計時間**: 30 分鐘

**驗收標準**:
- 報告完整記錄所有測試
- 簽核確認所有標準達成

---

## 📊 進度追蹤

| 任務 | 狀態 | 完成時間 |
|------|------|---------|
| 1.2C.1 | ⏳ | — |
| 1.2C.2 | ⏳ | — |
| 1.2C.3 | ⏳ | — |
| 1.2C.4 | ⏳ | — |
| 1.2C.5 | ⏳ | — |
| 1.2C.6 | ⏳ | — |
| 1.2C.7 | ⏳ | — |

---

## 🚀 下一步

完成此 phase 後，進入 **Milestone 1.2 完成**：
1. Git commit & push
2. 更新 ROADMAP.md（標記 Milestone 1.2 完成）
3. 進入 Phase 2（社區反饋）準備

---

**最後更新**: 2026-08-19
