# GSD Addon — 統一派工與測試框架

**Project Code**: GSD-ADDON  
**Initiative**: Unified dispatch, test orchestration, and dynamic scheduling across GSD runtimes  
**Scope**: Complete test framework + dispatch system + multi-runtime scheduling support  
**Timeline**: 2 milestones, 4 phases  
**Status**: Phase 1 initiated 2026-08-18  

---

## 願景

建立 GSD 的**補充工具層**，為軍師士兵派工模式提供：

- 🧪 **測試編排框架** — YAML 工作流定義、環境抽象、assertion 系統
- 📦 **Dispatch 系統** — 完整的派工包裝層（research/plan/execute 三模式）
- 🌍 **跨項目派工** — 自動化權限審計、本地與跨項目無縫支援
- ⚙️ **動態編排** — 立即/背景/延時派工，ScheduleWakeup + cron 支援
- 🔄 **多運行時** — Claude Code（當前完全支援）+ OpenCode/Codex/Hermes（規劃中）

**核心價值**：
- ✅ 統一派工系統，減少維護負擔（不與 gsd-framework 衝突）
- ✅ 測試與派工分離，各運行時可獨立實現
- ✅ 為未來運行時預留擴展空間
- ✅ 所有已知陷阱文檔化，降低採用門檻

---

## 關鍵特性

### 1️⃣ 測試編排框架

| 特性 | 說明 | 狀態 |
|------|------|------|
| YAML Workflow 定義 | 聲明式測試流程 | ✅ 完成 |
| 環境抽象 | local/docker/staging/production | ✅ 完成 |
| Assertion 系統 | 結果驗證 | ✅ 完成 |
| Python CLI | 獨立可執行，無依賴 | ✅ 完成 |
| 全局命令 | `gsd-test` | ✅ 完成 |

**狀態**: Production Ready

---

### 2️⃣ Dispatch 系統

| 特性 | 說明 | 狀態 |
|------|------|------|
| 軍師士兵模式 | gsd-dispatch.sh 包裝層 | ✅ 完成 |
| 三種模式 | research / plan / execute | ✅ 完成 |
| 跨項目派工 | TARGET_DIR 支援 | ✅ 完成 |
| 權限審計 | 自動化 opencode.json 修復 | ✅ 完成 |
| 模型選擇 | MODEL + VARIANT 支援 | ✅ 完成 |
| Liveness 檢查 | 派工死活判斷 + 驗收 | ✅ 完成 |

**狀態**: Production Ready

---

### 3️⃣ 動態編排

| 特性 | 說明 | Claude Code | OpenCode | Codex | Hermes |
|------|------|---|---|---|---|
| 立即派工 | 同步執行 | ✅ | ✅ | ✅ | ✅ |
| 背景派工 | nohup ... & | ✅ | ✅ | ✅ | ✅ |
| ScheduleWakeup | 原生延時派工 | ✅ | ⏳ | ⏳ | ⏳ |
| 系統 cron | 通用排程 | ✅ | ✅ | ✅ | ✅ |
| 條件派工 | 失敗重試 | ✅ | ✅ | ⏳ | ✅ |
| 平行派工 | 多 phase 同時 | ✅ | ✅ | ✅ | ✅ |

**狀態**: Claude Code 完全、其他運行時設計完成

---

## 內容層級

### Tier 1：快速上手
- README.md — 項目概述 + 5 分鐘快速開始
- QUICK-START.md — 基本命令範例
- INTEGRATION-GUIDE.md — 與 gsd-framework 的集成

### Tier 2：深度使用
- DISPATCH-COMPLETE-GUIDE.md — 三種派工模式 + 跨項目 + 陷阱
- SCHEDULE-WAKEUP-GUIDE.md — 動態編排 + 多運行時規劃
- GLOBAL-SETUP.md — 安裝與配置

### Tier 3：進階參考
- dispatch/README.md — 派工系統設計
- gsd-test/ 內文檔 — 測試框架詳細設計
- test-orchestration-guide.md — 工作流寫法與最佳實踐

---

## 成功標準

✅ **功能完整**:
- [x] 測試框架立即可用（`gsd-test` 命令）
- [x] 派工系統支援三種模式
- [x] 跨項目派工有權限自動修復
- [x] 動態編排支援立即/背景/延時
- [x] 多運行時設計完成

✅ **文檔完整**:
- [x] 所有 Gotcha 文檔化（4 個已知陷阱）
- [x] 每個功能有使用範例
- [x] 多運行時路線圖清晰
- [x] 疑難排解指南完成

✅ **質量**:
- [x] 代碼無依賴（dispatch.sh 通用 bash）
- [x] 與 gsd-framework 零衝突
- [x] 安裝腳本驗證正確
- [x] Git 提交歷史清晰

---

## 內容來源

### 一級來源（已驗證）
- ✅ gsd-framework（～/.claude/gsd-framework/）— 完整的 GSD 主框架
- ✅ ClaudeWiki 派工經驗（junshi-shibing-*.md）— 真實派工案例與陷阱
- ✅ soapwavehealing 項目驗證 — 生產環境測試
- ✅ OpenCode 官方文檔 — 無頭模式行為 + bug workaround

### 二級來源（規劃中）
- 🔍 Codex 設計文檔（待發佈）
- 🔍 Hermes 工作流引擎（內部）
- 🔍 社區反饋（GitHub issues）

---

## 假設與風險

### 假設
1. gsd-core 的派工指令穩定（research/plan/execute）
2. OpenCode 無頭模式行為保持一致
3. Claude Code ScheduleWakeup 能力穩定

### 風險
| 風險 | 影響 | 緩解 |
|------|------|------|
| OpenCode 更新改變無頭模式行為 | 中 | 版本偵測、graceful fallback |
| gsd-core Phase 命名變更 | 中 | 環境變數化模式名稱 |
| 未來運行時的調度機制不同 | 低 | 模塊化設計，各運行時可實現自己的 schedule-wakeup |

---

## 相關項目

- [[gsd-framework]] — 主 GSD 方法論與框架
- [[soapwavehealing]] — 生產驗證專案
- [[ClaudeWiki]] — 派工經驗與陷阱記錄

---

## 下一步

**Phase 1**: GitHub 推送與驗證（當前）  
**Phase 2**: 社區反饋與迭代  
**Phase 3**: OpenCode/Codex 支援擴展  
**Phase 4**: Hermes 工作流集成  

見 [ROADMAP.md](./ROADMAP.md) 詳細計畫。
