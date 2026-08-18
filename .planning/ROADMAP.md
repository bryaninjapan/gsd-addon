# GSD Addon — 路線圖

**Roadmap Version**: 1.0  
**Total Phases**: 4  
**Total Milestones**: 2  
**Status**: Phase 1 In Progress

---

## 里程碑 1：GitHub 推送與驗證

**交付物**: 項目上線 + 生產驗證  
**時間估算**: Phase 1 (當前)  
**成功標準**: 代碼上線 + 文檔完成 + 至少 1 個生產項目驗證

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

- [ ] 創建 GitHub 倉庫 (或使用現有)
- [ ] 推送代碼到 origin/main
- [ ] 驗證 GitHub 顯示正確（文件 + 提交歷史）
- [ ] 檢查 Actions（如有配置）
- **負責人**: You  
- **時間估算**: 30 分鐘

#### 1.3 本地驗證

- [ ] 新環境安裝測試：`bash install.sh`
- [ ] 驗證 gsd-test 命令可用
- [ ] 驗證 gsd-dispatch.sh 可執行
- [ ] 驗證 gsd-permission-audit.sh 可執行
- [ ] 檢查所有文檔正確連結
- **時間估算**: 1 小時

#### 1.4 soapwavehealing 生產驗證

- [ ] 在 soapwavehealing 項目中測試 gsd-test
  - 命令: `gsd-test --workflow booking-e2e.workflow.yml`
  - 期望: workflow 執行成功，產出結果
- [ ] 在 soapwavehealing 測試 gsd-dispatch
  - 命令: `TARGET_DIR=. ./scripts/gsd-dispatch.sh 1 execute`
  - 期望: 派工腳本正常運行，無權限錯誤
- [ ] 驗證 ScheduleWakeup 動態派工
  - 設置 1 分鐘後派工
  - 驗證派工自動執行
- **時間估算**: 2 小時
- **依賴**: soapwavehealing 項目已初始化

#### 1.5 文檔完善

- [ ] 更新 README.md GitHub 連結
- [ ] 補充「已驗證的運行時」清單
- [ ] 更新「快速開始」章節中的實際指令
- [ ] 新增「已知限制」章節
- **時間估算**: 1 小時

### Phase 1 成功標準

✅ **代碼**:
- [x] 所有代碼已上線 GitHub
- [x] install.sh 執行成功
- [ ] 新環境安裝無錯誤

✅ **功能**:
- [ ] gsd-test 在 soapwavehealing 運行成功
- [ ] gsd-dispatch 派工成功
- [ ] ScheduleWakeup 延時派工驗證

✅ **文檔**:
- [x] 所有文檔完成（README、指南、集成指南）
- [ ] README 中的所有連結有效
- [ ] GitHub 上的展示正確

---

## 里程碑 2：社區反饋與迭代

**交付物**: v1.1 Bug Fix 版  
**時間估算**: Phase 2 (2 週後)  
**成功標準**: 社區反饋 → 修復 → 新版本發佈

---

## Phase 2: 社區反饋與迭代

**目標**: 收集反饋並修復 Phase 1 發現的問題

**時間**: 2026-09-01 ~ 2026-09-15（2 週）

### 預期改進

#### 2.1 基於社區反饋的修復

- [ ] 修復 GitHub issues（若有提交）
- [ ] 更新文檔釐清常見誤解
- [ ] 修復發現的 bug（若有）
- [ ] 支持更多環境（若需要）

#### 2.2 性能優化

- [ ] 派工腳本執行時間優化
- [ ] 測試框架記憶體優化（如需要）
- [ ] 文檔快速查找改善

#### 2.3 擴展功能

- [ ] 補充更多派工模式範例
- [ ] 新增故障恢復腳本（如需要）
- [ ] 擴展環境配置支持

### Phase 2 成功標準

- [ ] 至少 5 個 GitHub issue 已關閉
- [ ] v1.1 版本發佈
- [ ] 新文檔「常見問題」發佈

---

## Phase 3: OpenCode/Codex 支持擴展

**目標**: 為 OpenCode 和 Codex 添加 ScheduleWakeup 支持

**時間**: 2026-09-15 ~ 2026-10-15（1 個月）

### 任務清單

#### 3.1 OpenCode ScheduleWakeup 實現

- [ ] 研究 OpenCode 的排程 API（待發佈）
- [ ] 實現 `scripts/schedule-wakeup/opencode.sh`
- [ ] 編寫文檔與範例
- [ ] 在生產項目驗證

#### 3.2 Codex 支持

- [ ] 設計 Codex 派工 API
- [ ] 實現 `scripts/dispatch/codex.py`
- [ ] 實現 Codex ScheduleWakeup
- [ ] 集成測試

#### 3.3 通用排程層

- [ ] 抽象派工層（使不同運行時可互換）
- [ ] 統一 ScheduleWakeup 接口
- [ ] 性能對標（各運行時）

### Phase 3 成功標準

- [ ] OpenCode ScheduleWakeup 實現完成
- [ ] Codex 派工完整支持
- [ ] 通用排程層抽象完成
- [ ] v2.0 版本發佈

---

## Phase 4: Hermes 工作流集成

**目標**: 集成 Hermes 分佈式工作流引擎

**時間**: 2026-10-15 ~ 2026-11-15（1 個月）

### 任務清單

#### 4.1 Hermes 集成

- [ ] 研究 Hermes 工作流語言
- [ ] 實現 `scripts/dispatch/hermes.cjs`
- [ ] 支持複雜工作流（條件、平行、重試）

#### 4.2 工作流範本庫

- [ ] 建立 phase 工作流範本（phase 1→2→3 自動化）
- [ ] 建立失敗恢復工作流
- [ ] 建立成本優化工作流（凌晨派工等）

#### 4.3 集群支持

- [ ] 支持多機器派工協調
- [ ] 實現工作流進度追蹤
- [ ] 集成監控與告警

### Phase 4 成功標準

- [ ] Hermes 完整集成
- [ ] 工作流範本庫完成（≥5 個範本）
- [ ] 集群派工驗證成功
- [ ] v3.0 版本發佈

---

## 關鍵日期

| 里程碑 | Phase | 預定日期 | 狀態 |
|--------|-------|---------|------|
| 推送驗證 | 1 | 2026-08-22 | 🔄 進行中 |
| 社區反饋 | 2 | 2026-09-15 | ⏳ 待執行 |
| OpenCode/Codex | 3 | 2026-10-15 | ⏳ 待執行 |
| Hermes 集成 | 4 | 2026-11-15 | ⏳ 待執行 |

---

## 依賴關係

```
Phase 1 (推送驗證) ✅
    ↓
Phase 2 (社區反饋) ⏳
    ↓
Phase 3 (OpenCode/Codex) ⏳
    ↓
Phase 4 (Hermes) ⏳
```

**Phase 1 必須完成**才能進入 Phase 2。  
**Phase 2-4 可基於需求優先順序調整。**

---

## 資源與成本

| Phase | 開發時間 | 文檔時間 | 驗證時間 | 總計 |
|-------|---------|---------|---------|------|
| 1 | 完成 | 完成 | 4h | ✅ 進行中 |
| 2 | 16h | 4h | 8h | 28h |
| 3 | 32h | 8h | 16h | 56h |
| 4 | 48h | 12h | 24h | 84h |

**總體估算**: 138 小時 ≈ 3.5 週 (全職)

---

## 決策點

### 何時停止擴展？

若滿足以下條件，可考慮完成當前階段：
- ✅ 核心功能穩定（Phase 1 完成）
- ✅ 社區採用 ≥ 5 個項目（Phase 2 完成）
- ✅ 多運行時支持完整（Phase 3/4 完成）

### 優先順序調整

若時間或資源限制，優先順序：
1. **高**: Phase 1（GitHub 推送）
2. **高**: Phase 2（社區驗證）
3. **中**: Phase 3（OpenCode 支持）
4. **低**: Phase 4（Hermes 集成）

---

## 監控與進度追蹤

每個 Phase 的進度將在 `.planning/phases/*/STATE.md` 中記錄。

見 [PROJECT.md](./PROJECT.md) 項目概述。
