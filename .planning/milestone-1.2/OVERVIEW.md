# Milestone 1.2：GSD-Dispatch 韌性與重試機制

**版本**: 1.2  
**狀態**: ✅ **完成並驗證通過** (所有 4 phases 完成，UAT 27/27 通過)  
**開始日期**: 2026-08-18  
**實際完成**: 2026-08-19  
**所有者**: Claude Code  

---

## 📌 里程碑目標

為 `gsd-dispatch.sh` 添加完整的超時保護和智能重試機制，提升在不穩定網絡/服務環境下的可靠性。

### 核心問題

1. **超時風險**：`opencode run`、`curl`、`git` 三處無超時，可能導致派工永不返回（✅ Phase 2 已修復）
2. **單點失敗**：OpenCode 伺服器暫時性故障導致整個派工失敗（如 err_13bbe49a、err_63d358ee）
3. **啟動機制**：目前 wrapper 無法優雅地集成到現有的 `gsd-dispatch` 全域命令
4. **新發現（2026-08-18 執行 Phase 2 時）**：source repo 與 `~/.claude/gsd-addon` 已安裝副本已分岔
   ——已安裝副本是未提交的 prompts-based 重構版本，且帶有 `build_prompt()` 插值 bug，導致派工
   回報假性失敗（士兵其實已完成工作並 commit，但 dispatch 腳本自己收尾時崩潰回報 exit 1）

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

## 🎯 四個 Phases 分解（對應 ROADMAP 正式 Phase 2-5）

### Phase 2：Core Timeout Hardening ✅ 已完成
**目標**: 修復 gsd-dispatch.sh 中的三處無超時命令
**實際耗時**: ~30 分鐘（4 個 commits：3dde38d..fa0d305）
**交付物**: 更新的 gsd-dispatch.sh（純 bash `run_with_timeout`，零外部依賴）

**詳細規劃**: [`.planning/phases/02-dispatch-timeout-hardening/02-PLAN.md`](../phases/02-dispatch-timeout-hardening/02-PLAN.md)（權威版本，取代本文檔原本的 Phase 1.2A 規劃）

---

### Phase 3：Source/安裝副本分岔修復 ✅ 已完成（2026-08-19）
**目標**: 協調 source repo 與 `~/.claude/gsd-addon` 已安裝副本的分岔，修復 `build_prompt()` 插值 bug
**實際耗時**: ~20 分鐘（4 commits: 34123d7..9a89b42）+ Code Review 修復 ~10 分鐘（8 commits: 957c1ac..11a72f7）
**交付物**: 兩份 gsd-dispatch.sh 完全一致 + prompts/ 目錄新增至 source repo + 8 項 code review bug 修復

**詳細規劃**: [`.planning/phases/03-dispatch-source-install-drift/03-PLAN.md`](../phases/03-dispatch-source-install-drift/03-PLAN.md)

---

### Phase 4：Retry Wrapper Implementation ✅ 已完成（2026-08-19）
**目標**: 創建 dispatch-with-retry.sh，具備智能重試和錯誤分類  
**實際耗時**: ~40 分鐘（4 commits: bbc8821..681e835）
**交付物**: dispatch-with-retry.sh + RETRY=true 路由 + install.sh/gsd-config.sh 修復

#### 完成任務
- ✅ 創建 `scripts/dispatch-with-retry.sh`（MAX_RETRIES=3，指數退避 1s/2s/4s）
- ✅ 實現錯誤分類邏輯（5 可重試類型 + 3 不可重試類型）
- ✅ 修改全域命令支持 `RETRY=true gsd-dispatch <phase>` 路由
- ✅ 修復 install.sh 與 gsd-config.sh（invalid bash docstrings）

**詳細規劃**: [`.planning/phases/04-retry-wrapper/04-PLAN.md`](../phases/04-retry-wrapper/04-PLAN.md)

---

### Phase 5：Integration & Testing ✅ 已完成（2026-08-19）
**目標**: 集成測試 + soapwavehealing 端對端驗證  
**實際耗時**: ~45 分鐘（5 commits: 5c1eecd..6d18240）
**交付物**: 4-way 並行驗證 + 9 章節故障排除文檔 + UAT 27/27 通過

#### 完成任務
- ✅ Task 5.1: 部署最新代碼（install.sh 成功）
- ✅ Task 5.2: 基線測試（無重試，行為不變）
- ✅ Task 5.3: RETRY=true 功能測試（重試 wrapper 啟動）
- ✅ Task 5.4: Checkpoint 衝突驗證（.planning/ 文件完好）
- ✅ Task 5.5: 超時值合理性驗證（3600s/5s 無誤觸發）
- ✅ Task 5.6: DEVELOPMENT-WORKFLOW.md 更新（派工排障 + 重試機制 9 章節）
- ✅ UAT: 全部 27 項驗收通過

**詳細規劃**: [`.planning/phases/05-integration-testing/05-PLAN.md`](../phases/05-integration-testing/05-PLAN.md)  
**UAT 結果**: [`.planning/milestone-1.2/UAT-RESULTS.md`](./UAT-RESULTS.md)

---

## 📊 完成統計

| Phase | 規劃 | 實現 | 測試 | 文檔 | 總計 | 狀態 |
|-------|------|------|------|------|------|------|
| 2（超時加固） | 15m  | 20m  | 15m  | 10m  | ~1h  | ✅ 完成 |
| 3（分岔修復） | 10m  | 15m  | 10m  | 5m   | ~0.5h + CR 修復 | ✅ 完成 |
| 4（重試 wrapper） | 10m  | 30m  | 10m  | 10m  | ~40m | ✅ 完成 |
| 5（集成測試） | 15m  | 20m  | 15m  | 20m  | ~45m | ✅ 完成 |
| **Milestone 1.2 合計** | | | | | **~3.5h** | ✅ **完成** |

**實際完成**: 2026-08-19  
**UAT 驗證**: 27/27 項通過 ✅

---

## 🔗 相關文檔

- `.planning/phases/02-dispatch-timeout-hardening/` — Phase 2 權威規劃與 SUMMARY（✅ 已完成）
- `.planning/phases/03-dispatch-source-install-drift/` — Phase 3 權威規劃
- `.planning/milestone-1.2/phase-1.2b/` — Phase 4（原 1.2B）規劃參考
- `.planning/milestone-1.2/phase-1.2c/` — Phase 5（原 1.2C）規劃參考
- `.planning/debug/gsd-dispatch-opencode-server-error.md` — 背景問題記錄
- `DEVELOPMENT-WORKFLOW.md` — 派工排障章節（需更新）

---

## 🚀 後續步驟

1. ✅ 創建 milestone 結構與規劃（已完成）
2. ✅ Phase 2-5 實現與驗證（已完成）
3. ✅ 代碼審查與 bug 修復（已完成）
4. ✅ 端對端 UAT 驗證（27/27 通過）
5. ✅ Milestone 1.2 正式完成（2026-08-19）
6. ⏳ **Next: Phase 06 — GSD-Dispatch Debug Tool**（規劃中，詳見 `.planning/phases/06-dispatch-debug-tool/`）

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
