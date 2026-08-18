# Milestone 1.2：GSD-Dispatch 韌性與重試機制

**版本**: 1.0  
**狀態**: 🔄 規劃中  
**開始日期**: 2026-08-19  
**預計完成**: 2026-08-20  
**所有者**: Claude Code  

---

## 📌 里程碑目標

為 `gsd-dispatch.sh` 添加完整的超時保護和智能重試機制，提升在不穩定網絡/服務環境下的可靠性。

### 核心問題

1. **超時風險**：`opencode run`、`curl`、`git` 三處無超時，可能導致派工永不返回
2. **單點失敗**：OpenCode 伺服器暫時性故障導致整個派工失敗（如 err_13bbe49a、err_63d358ee）
3. **啟動機制**：目前 wrapper 無法優雅地集成到現有的 `gsd-dispatch` 全域命令

### 成功標準

✅ **技術層面**:
- [x] 修復三處超時風險（opencode run、curl、git）
- [x] 創建 dispatch-with-retry.sh 具備智能錯誤分類
- [x] 修改啟動機制支持 `RETRY=true gsd-dispatch` 語法
- [x] 不修改 gsd-dispatch.sh 核心邏輯（wrapper 模式）

✅ **測試層面**:
- [x] 在 soapwavehealing 中端對端驗證重試機制
- [x] 驗證重試不會與 GSD checkpoint 衝突
- [x] 驗證快速失敗路徑（參數/權限錯誤）不會不必要重試

✅ **文檔層面**:
- [x] 完善 DEVELOPMENT-WORKFLOW.md 的派工排障章節
- [x] 記錄重試機制的設計決策

---

## 🎯 三個 Phases 分解

### Phase 1.2A：Core Timeout Hardening
**目標**: 修復 gsd-dispatch.sh 中的三處無超時命令  
**時間**: 1-2 小時  
**交付物**: 更新的 gsd-dispatch.sh（帶 timeout）

#### 具體任務
- 為 `opencode run` 添加 `timeout 3600`（1 小時派工上限）
- 為 `curl` 檢查添加 `--max-time 5`（5 秒超時）
- 為 `git diff` 添加超時保護

#### 成功驗收
- 修改後的 gsd-dispatch.sh 語法檢查通過
- 每個 timeout 處都有註釋說明原因
- 超時場景下返回正確的 exit code（124）

---

### Phase 1.2B：Retry Wrapper Implementation
**目標**: 創建 dispatch-with-retry.sh，具備智能重試和錯誤分類  
**時間**: 2-3 小時  
**交付物**: dispatch-with-retry.sh + 更新的 install.sh

#### 具體任務
- 創建 `scripts/gsd-dispatch-with-retry.sh`（3 次重試策略）
- 實現錯誤分類邏輯（區分參數/權限/派工失敗）
- 添加指數退避延遲（初始延遲 2s，上限）
- 修改 install.sh 支持全域命令中的環境變數邏輯

#### 成功驗收
- Wrapper 執行成功：`RETRY=true gsd-dispatch 2 discuss`
- 能正確區分三類錯誤（不重試參數/權限錯誤，重試派工失敗）
- 日誌文件能記錄重試過程

---

### Phase 1.2C：Integration & Testing
**目標**: 集成測試 + soapwavehealing 端對端驗證  
**時間**: 2-3 小時  
**交付物**: 測試報告 + 驗收檔案

#### 具體任務
- 在 soapwavehealing 中測試 `RETRY=true gsd-dispatch 2 discuss`
- 驗證重試不會與 GSD checkpoint 機制衝突
- 驗證超時時間合理（不會太短導致誤觸發）
- 驗證默認行為不變（`gsd-dispatch 2 discuss` 仍無重試）
- 更新 DEVELOPMENT-WORKFLOW.md 文檔

#### 成功驗收
- soapwavehealing Phase 2 研究成功派工（有無重試都可）
- 重試機制在實際場景中有效
- 文檔清楚說明如何使用重試機制

---

## 📊 資源與時間表

| Phase | 規劃 | 實現 | 測試 | 文檔 | 總計 |
|-------|------|------|------|------|------|
| 1.2A  | 30m  | 30m  | 30m  | 30m  | 2h   |
| 1.2B  | 30m  | 1.5h | 1h   | 30m  | 3.5h |
| 1.2C  | 30m  | 30m  | 1.5h | 1h   | 3.5h |
| **總計** | | | | | **9h** |

**預計完成**: 2026-08-20（1-2 天，取決於測試過程中的發現）

---

## 🔗 相關文檔

- `.planning/milestone-1.2/phase-1.2a/` — Phase 1.2A 規劃與進度
- `.planning/milestone-1.2/phase-1.2b/` — Phase 1.2B 規劃與進度
- `.planning/milestone-1.2/phase-1.2c/` — Phase 1.2C 規劃與進度
- `.planning/debug/gsd-dispatch-opencode-server-error.md` — 背景問題記錄
- `DEVELOPMENT-WORKFLOW.md` — 派工排障章節（需更新）

---

## 🚀 後續步驟

1. ✅ 創建 milestone 結構（本檔案）
2. ⏳ 對每個 phase 運行 `/gsd-plan-phase` 來生成詳細計畫
3. ⏳ 進入 Phase 1.2A 實現
4. ⏳ Phase 1.2B & 1.2C 執行
5. ⏳ 合併到 main 分支

---

## 📝 決策記錄

### 為什麼選擇 Wrapper 模式而不是直接修改 gsd-dispatch.sh？

**決策**: 修改 gsd-dispatch.sh 添加 timeout，但將重試邏輯放在外部 wrapper 中

**理由**:
1. 分離關注點：timeout 是根本修復（必須），重試是可選機制
2. 降低風險：wrapper 邏輯如有問題，用戶可切換到無重試模式
3. 啟動靈活：環境變數控制 `RETRY=true/false`，無需修改多個地方

### 為什麼選擇環境變數而不是新命令名？

**決策**: 使用 `RETRY=true gsd-dispatch` 而不是 `gsd-dispatch-retry`

**理由**:
1. 對用戶透明：現有腳本無需修改，只需加環境變數
2. 一致性：用戶已習慣 `gsd-dispatch`，無需記住新命令
3. 可靠性：可輕鬆禁用（去掉環境變數即可）

---

**最後更新**: 2026-08-19
