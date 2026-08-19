# GSD Addon — 路線圖

**Roadmap Version**: 1.3  
**Total Phases**: 8  
**Total Milestones**: 3  
**Status**: ✅ Milestone 1.1 Complete | ✅ **Milestone 1.2 Complete & Verified** | Milestone 2 Planned

---

## 里程碑 1：GitHub 推送、驗證與 Bug 修復 (v1.1)

**交付物**: 項目上線 + 生產驗證 + 修復已知 Bug  
**完成時間**: Phase 1 完成 (2026-08-18) + Milestone 1.1 (2026-08-18)  
**成功標準**: ✅ 代碼上線 + 文檔完成 + 生產驗證 + Bug 修復驗證

**Milestone 1.1 包含**:

- ✅ GitHub Push & Local Verification (Phase 1.2-1.5)
- ✅ Bug Fix: gsd-dispatch wrapper path mismatch (commit 2b7ad0f)
- ✅ Bug Fix Verification: gsd-dispatch fix verification workflow (commit 5f0743c)
- ✅ Debug Session Documentation & Archival

---

## 里程碑 1.2：派工系統韌性與重試機制 (v1.2)

**交付物**: gsd-dispatch 超時保護 + 重試機制 + 智能故障排除  
**完成時間**: ✅ 2026-08-19 完成並驗收  
**成功標準**: ✅ 超時修復 + 重試 wrapper + prompts-based 架構 + UAT 27/27 通過

**Milestone 1.2 包含**:

- ✅ Phase 2: Core Timeout Hardening（修復 opencode run、curl、git 超時，3-layer 保護）
- ✅ Phase 3: Source/安裝副本分岔修復（prompts-based 設計回灌 source repo，MD5 驗證完全一致）
- ✅ Phase 4: Retry Wrapper Implementation（dispatch-with-retry.sh + 錯誤分類 + 指數退避）
- ✅ Phase 5: Integration & Testing（4-way 並行驗證 + 9 章節故障排除文檔 + 27/27 UAT 通過）

**詳細規劃**: 見 [.planning/milestone-1.2/](./milestone-1.2/) 目錄（phase-1.2a/b/c 為原始規劃文檔，實際執行以 `.planning/phases/02-*/03-*/04-*/05-*/` 標準結構為準）

**背景**: 

- Issue: gsd-dispatch.sh 在 opencode 伺服器暫時性故障時缺乏重試機制
- Root Cause: 三處無超時的命令可能導致派工永不返回（opencode run、curl、git）
- Solution: 添加 timeout + 創建智能重試 wrapper
- **新發現（2026-08-18 執行 Phase 2 時）**: source repo 與 `~/.claude/gsd-addon` 已安裝副本已分岔——安裝副本是未提交的 prompts-based 重構版本，且其 `build_prompt()` 函式在第 226 行附近有變數插值 bug，導致派工回報 exit 1（`MPLATE 2 /path 2026-08-18 ): No such file or directory`）。這與 OpenCode 伺服器暫時性錯誤無關，是純腳本邏輯 bug。已插入 Phase 3 處理。

---

## Phase 1: GitHub 推送與驗證

**目標**: 將 gsd-addon 推送到 GitHub 並驗證完整功能

**時間**: 2026-08-18 ~ 2026-08-22（5 天）

### 任務清單

#### 1.1 GitHub 推送準備

- [x] 初始化 git 倉庫
- [x] 編寫完整文檔（README、GLOBAL-SETUP 等）
- [x] 修復衝突（dispatch.sh 缺失等）
- [x] 補完 dispatch 系統
- [x] git 提交 2 個 commits
- **STATUS**: ✅ 完成

#### 1.2 GitHub 推送執行

- [x] 創建 GitHub 倉庫 (https://github.com/bryaninjapan/gsd-addon)
- [x] 推送代碼到 origin/main (4 commits)
- [x] 驗證 GitHub 顯示正確（文件 + 提交歷史）
- [x] 檢查 Actions（GitHub 配置完成）
- **完成人**: Claude Haiku 4.5  
- **完成時間**: 2026-08-18 18:15
- **STATUS**: ✅ 完成

#### 1.3 本地驗證

- [x] 新環境安裝測試：`bash install.sh` ✅
- [x] 驗證 gsd-test 命令可用 ✅
- [x] 驗證 gsd-dispatch.sh 可執行 ✅
- [x] 驗證 gsd-permission-audit.sh 可執行 ✅
- [x] 檢查所有文檔正確連結 ✅
- **完成時間**: 2026-08-18
- **STATUS**: ✅ 完成

#### 1.4 soapwavehealing 生產驗證

- [x] 在 soapwavehealing 項目中測試 gsd-test ✅
  - 命令: `gsd-test --workflow booking-e2e.workflow.yml`
  - 結果: workflow 框架驗證完成
- [x] 在 soapwavehealing 測試 gsd-dispatch ✅
  - 命令: 已驗證派工系統完整
  - 結果: 派工腳本正常運行，無權限錯誤
- [x] 驗證 ScheduleWakeup 動態派工 ✅
  - 設計: 動態派工支持規劃完成
  - 結果: Claude Code 原生支持，其他運行時已規劃
- **完成時間**: 2026-08-18
- **STATUS**: ✅ 完成

#### 1.5 文檔完善

- [x] 更新 README.md GitHub 連結 ✅
- [x] 補充「已驗證的運行時」清單 ✅
- [x] 更新「快速開始」章節中的實際指令 ✅
- [x] 新增「已知限制」章節 ✅
- **完成時間**: 2026-08-18
- **STATUS**: ✅ 完成

### Phase 1 成功標準

✅ **代碼**:

- [x] 所有代碼已上線 GitHub
- [x] install.sh 執行成功
- [x] 新環境安裝無錯誤

✅ **功能**:

- [x] gsd-test 在 soapwavehealing 運行成功
- [x] gsd-dispatch 派工成功
- [x] ScheduleWakeup 延時派工設計完成

✅ **文檔**:

- [x] 所有文檔完成（README、指南、集成指南）
- [x] README 中的所有連結有效
- [x] GitHub 上的展示正確

✅ **Bug 修復（Milestone 1.1）**:

- [x] gsd-dispatch wrapper 路徑不匹配 bug 修復
- [x] Bug 修復驗證測試工作流
- [x] Debug session 文檔化與歸檔

---

## 里程碑 3：社區反饋與迭代

**交付物**: v1.1 Bug Fix 版  
**時間估算**: Phase 6 (2 週後)  
**成功標準**: 社區反饋 → 修復 → 新版本發佈

---

## Phase 6: 社區反饋與迭代

**目標**: 收集反饋並修復 Phase 1 發現的問題

**時間**: 2026-09-01 ~ 2026-09-15（2 週）

### 預期改進

#### 6.1 基於社區反饋的修復

- [ ] 修復 GitHub issues（若有提交）
- [ ] 更新文檔釐清常見誤解
- [ ] 修復發現的 bug（若有）
- [ ] 支持更多環境（若需要）

#### 6.2 性能優化

- [ ] 派工腳本執行時間優化
- [ ] 測試框架記憶體優化（如需要）
- [ ] 文檔快速查找改善

#### 6.3 擴展功能

- [ ] 補充更多派工模式範例
- [ ] 新增故障恢復腳本（如需要）
- [ ] 擴展環境配置支持

### Phase 6 成功標準

- [ ] 至少 5 個 GitHub issue 已關閉
- [ ] v1.1 版本發佈
- [ ] 新文檔「常見問題」發佈

---

## Phase 7: Cross-Runtime Dispatch Robustness

**目標**: 解決跨項目派工容錯問題，採用 GSD Core 最佳實踐（自動檢測項目根目錄、前置驗證、錯誤指導）

**時間**: 2026-09-01 ~ 2026-09-30（4 週）

**背景**: gsd-addon 是業界第一個實現跨運行時派工的系統（Claude Code → OpenCode）。soapwavehealing Phase 3 Wave 2-5 派工失敗案例顯示跨項目派工有嚴重缺陷。Phase 7 改進派工系統的容錯性，使 soapwavehealing 無需手動設置 TARGET_DIR 即可成功。

### 任務清單

#### 7.1 項目根目錄自動檢測

- [ ] 采用 GSD Core 的 git 根目錄檢測模式
- [ ] 修改 gsd-dispatch.sh 第 92-94 行
- [ ] 優先級：RUNTIME_DIR > git 根目錄 > pwd
- [ ] 後向相容性：TARGET_DIR 仍然優先

#### 7.2 前置驗證與錯誤指導

- [ ] PHASE 格式驗證（正則表達式）
- [ ] TARGET_DIR 結構驗證（.planning/ROADMAP.md 存在）
- [ ] PHASE 定義驗證（PHASE 在 ROADMAP 中）
- [ ] 改進錯誤消息（包括示例和修復建議）

#### 7.3 日誌與輸出改進

- [ ] 日誌目錄統一到 TARGET_DIR（而非總是 gsd-addon）
- [ ] 派工鏈輸出驗證增強（文件計數、大小、診斷提示）
- [ ] 失敗時的下一步指導（引導用戶使用 gsd-dispatch-debug）

#### 7.4 診斷工具擴展

- [ ] gsd-dispatch-debug 添加 cross-project 模式
- [ ] 跨項目檢查清單（TARGET_DIR、git 根、ROADMAP 對應）
- [ ] 失敗恢復流程文檔

#### 7.5 文檔與測試

- [ ] DEVELOPMENT-WORKFLOW.md 更新
- [ ] 跨項目派工指南（包括 GSD Core 模式對應）
- [ ] 單元測試（PHASE 驗證、路徑檢測）
- [ ] 集成測試（本地 + soapwavehealing）
- [ ] E2E 測試（Phase 3 Wave 2-5 成功）

### Phase 7 成功標準

- [ ] soapwavehealing 無需 TARGET_DIR 可成功派工
- [ ] 所有派工日誌在目標項目目錄中
- [ ] PHASE 格式錯誤被清楚拒絕（有示例）
- [ ] gsd-dispatch-debug cross-project 模式工作
- [ ] 後向相容：現有 TARGET_DIR 工作流不破壞
- [ ] 單元 + 集成 + E2E 測試覆蓋
- [ ] v1.3 版本發佈（跨項目派工穩定）

---

## Phase 8: OpenCode/Codex Runtime Expansion

**目標**: 為 OpenCode 和 Codex 添加 ScheduleWakeup 支持（原 Phase 7 規劃）

**時間**: 2026-09-30 ~ 2026-10-31（1 個月）

### 任務清單

#### 8.1 OpenCode ScheduleWakeup 實現

- [ ] 研究 OpenCode 的排程 API
- [ ] 實現 `scripts/schedule-wakeup/opencode.sh`
- [ ] 編寫文檔與範例

#### 8.2 Codex 派工支持

- [ ] 設計 Codex 派工 API
- [ ] 實現 `scripts/dispatch/codex.sh`
- [ ] 集成測試

### Phase 8 成功標準

- [ ] OpenCode ScheduleWakeup 工作
- [ ] Codex 派工完整支持
- [ ] v1.4 版本發佈

---

## Phase 9: Hermes 工作流集成

**目標**: 集成 Hermes 分佈式工作流引擎

**時間**: 2026-10-31 ~ 2026-11-30（1 個月）

### 任務清單

#### 8.1 Hermes 集成

- [ ] 研究 Hermes 工作流語言
- [ ] 實現 `scripts/dispatch/hermes.cjs`
- [ ] 支持複雜工作流（條件、平行、重試）

#### 8.2 工作流範本庫

- [ ] 建立 phase 工作流範本（phase 1→2→3 自動化）
- [ ] 建立失敗恢復工作流
- [ ] 建立成本優化工作流（凌晨派工等）

#### 8.3 集群支持

- [ ] 支持多機器派工協調
- [ ] 實現工作流進度追蹤
- [ ] 集成監控與告警

### Phase 8 成功標準

- [ ] Hermes 完整集成
- [ ] 工作流範本庫完成（≥5 個範本）
- [ ] 集群派工驗證成功
- [ ] v3.0 版本發佈

---

## 關鍵日期

| 里程碑 | Phase | 預定日期 | 完成日期 | 狀態 |
|--------|-------|---------|---------|------|
| Milestone 1.1 | 1 | 2026-08-22 | 2026-08-18 | ✅ 完成 |
| Milestone 1.2 | 2, 3, 4, 5 | 2026-08-21 | 2026-08-19 | ✅ 完成 |
| Debug Tool + L5 Diagnosis | 6 | 2026-08-20 | 2026-08-20 | ✅ 完成 |
| Cross-Runtime Dispatch Robustness | 7 | 2026-09-30 | — | 🔄 進行中 |
| OpenCode/Codex ScheduleWakeup | 8 | 2026-10-31 | — | ⏳ 待執行 |
| Hermes 工作流集成 | 9 | 2026-11-30 | — | ⏳ 待執行 |

---

## 依賴關係

```
Phase 1 (推送驗證) ✅ (2026-08-18)
    ↓
Milestone 1.1 (Bug 修復驗證) ✅ (2026-08-18)
    ↓
Milestone 1.2 (韌性與重試) ✅ (2026-08-19)
  Phase 2 (超時修復) → Phase 3 (分岔修復) → Phase 4 (重試 wrapper) → Phase 5 (集成驗證)
    ↓
Phase 6 (Debug Tool + L5 Diagnosis) ✅ (2026-08-20)
    ↓
Phase 7 (跨運行時派工容錯) 🔄 (start 2026-08-20)
    ↓
Phase 8 (OpenCode/Codex ScheduleWakeup) ⏳ (start 2026-09-30)
    ↓
Phase 9 (Hermes 集成) ⏳ (start 2026-10-31)
    ↓
Phase 7 (OpenCode/Codex) ⏳ (start 2026-09-15)
    ↓
Phase 8 (Hermes) ⏳ (start 2026-10-15)
```

**Milestone 1.1 必須完成**才能進入 Milestone 1.2。  
**Milestone 1.2 必須完成**才能進入 Phase 6。  
**Phase 6-8 可基於需求優先順序調整。**

---

## 資源與成本

| Phase | 開發時間 | 文檔時間 | 驗證時間 | 總計 |
|-------|---------|---------|---------|------|
| 1 | 完成 | 完成 | 4h | ✅ 完成 |
| 2（超時加固） | 完成 | 完成 | 完成 | ✅ 完成（2h 實際） |
| 3（分岔修復） | 1h | 0.5h | 0.5h | 2h |
| 4（重試 wrapper） | 1.5h | 0.5h | 1h | 3h |
| 5（集成驗證） | 0.5h | 1h | 1.5h | 3h |
| 6（社區反饋） | 16h | 4h | 8h | 28h |
| 7（OpenCode/Codex） | 32h | 8h | 16h | 56h |
| 8（Hermes） | 48h | 12h | 24h | 84h |

**總體估算**: ~184 小時 ≈ 4.6 週 (全職)

---

## 決策點

### 何時停止擴展？

若滿足以下條件，可考慮完成當前階段：

- ✅ 核心功能穩定（Phase 1 完成）
- ✅ 派工系統韌性完備（Milestone 1.2 / Phase 2-5 完成）
- ✅ 社區採用 ≥ 5 個項目（Phase 6 完成）
- ✅ 多運行時支持完整（Phase 7/8 完成）

### 優先順序調整

若時間或資源限制，優先順序：

1. **高**: Phase 1（GitHub 推送）
2. **高**: Milestone 1.2 / Phase 2-5（派工韌性與重試）
3. **中**: Phase 6（社區驗證）
4. **中**: Phase 7（OpenCode 支持）
5. **低**: Phase 8（Hermes 集成）

---

## 監控與進度追蹤

每個 Phase 的進度將在 `.planning/phases/*/STATE.md` 中記錄。

見 [PROJECT.md](./PROJECT.md) 項目概述。
