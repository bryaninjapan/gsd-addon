# GSD Dispatch System

**軍師士兵派工框架** — 統一的 Phase 執行系統，支援多運行時與動態編排

## 🎯 Dispatch 是什麼？

Dispatch 是 GSD 的派工層，負責：

1. **派工選擇** — 決定派給 OpenCode（執行）還是 Claude（分析）
2. **三模式支持** — `research` / `plan` / `execute` 分離
3. **跨項目派工** — 同一個軍師派工到多個項目
4. **動態編排** — 支持立即派工、背景派工、延時派工
5. **完整日誌** — `.planning/soldier-logs/` 落地全程
6. **多運行時** — Claude Code · OpenCode · Codex（規劃中） · Hermes（規劃中）

---

## 🚀 快速開始

### 基本派工

```bash
# 執行 Phase 2（預設 execute 模式）
./scripts/gsd-dispatch.sh 2

# 規劃模式
MODE=plan ./scripts/gsd-dispatch.sh 2

# 研究模式
MODE=research ./scripts/gsd-dispatch.sh 2
```

### 跨項目派工

```bash
# 從 vault 派工到 /etf-flow-database
TARGET_DIR=~/Documents/etf-flow-database ./scripts/gsd-dispatch.sh 8

# 自動檢查與修復跨項目權限
./scripts/gsd-permission-audit.sh --target ~/Documents/etf-flow-database --fix
```

### 延時派工（Claude Code）

```bash
# 使用 ScheduleWakeup 工具延時派工
ScheduleWakeup({
  delaySeconds: 3600,  # 1 小時後
  prompt: "cd ~/my-project && ./scripts/gsd-dispatch.sh 3 execute",
  reason: "Dispatch phase 3"
})
```

---

## 📚 完整文檔

| 文檔 | 內容 |
|------|------|
| **[DISPATCH-COMPLETE-GUIDE.md](./DISPATCH-COMPLETE-GUIDE.md)** | 完整指南（三種模式、跨項目、動態編排、陷阱）|
| **[../GLOBAL-SETUP.md](../GLOBAL-SETUP.md)** | 全局安裝與配置 |
| **軍師士兵 SOP** | 見 ClaudeWiki: `junshi-shibing-gsd-dispatch-sop.md` |

---

## 🔧 三種派工模式

### 1. `MODE=research` — 研究階段
蒐集背景、分析選項 → 產出 `RESEARCH.md`

### 2. `MODE=plan` — 規劃階段  
根據研究產出執行計畫 → 產出 `PLAN.md`

### 3. `MODE=execute`（預設） — 執行階段
實裝所有任務，寫程式、測試、commit → 產出 `SUMMARY.md` + 代碼

---

## ⚙️ 環境變數

```bash
MODE              # 派工模式: research | plan | execute（預設）
MODEL             # 士兵模型: opencode-go/deepseek-v4-flash（預設）
VARIANT           # 推理 effort: minimal | high（預設）| max
SERVER_URL        # 共享 server 地址（設了就 attach）
TARGET_DIR        # 跨項目派工的目標專案（預設=派工源）
OPENCODE_CONFIG   # .opencode.json 路徑
```

**例**：
```bash
MODE=plan VARIANT=max ./scripts/gsd-dispatch.sh 5
TARGET_DIR=/etf ./scripts/gsd-dispatch.sh 8 opencode-go/kimi-k2.6
SERVER_URL=http://localhost:4096 ./scripts/gsd-dispatch.sh 3
```

---

## 🎯 派工流程

```
研究         規劃        執行        驗收
───────────────────────────────────────
MODE=research → MODE=plan → execute → verify-work
   ↓           ↓          ↓         ↓
RESEARCH.md   PLAN.md   代碼+tests  ✅
```

---

## 🚨 常見陷阱

| 陷阱 | 症狀 | 修復 |
|------|------|------|
| **tail 誤判** | 看 log 以為卡住，其實做完了 | 看 `git log` 和檔案存在性 |
| **自動拒權外部路徑** | 士兵讀不到 vault 檔案 | `gsd-permission-audit.sh --fix` |
| **OpenCode 自改寫** | diff 顯示 .opencode 變動 | 正常行為，dispatch 自動排除 |
| **`--command` bug** | 跨項目派工崩潰 | dispatch.sh 已內建 workaround |

詳見 [DISPATCH-COMPLETE-GUIDE.md](./DISPATCH-COMPLETE-GUIDE.md) 的「陷阱與解決方案」。

---

## 🌍 運行時支持

| 運行時 | ScheduleWakeup | 派工 | 狀態 |
|--------|---|---|---|
| Claude Code | ✅ 原生 | ✅ | 生產 |
| OpenCode | ⏳ 規劃 | ✅ | 生產 |
| Codex | ⏳ 規劃 | ⏳ | 設計中 |
| Hermes | ⏳ 規劃 | ⏳ | 設計中 |

---

## 📖 更多資源

- **完整指南** — [DISPATCH-COMPLETE-GUIDE.md](./DISPATCH-COMPLETE-GUIDE.md)
- **軍師士兵模式** — ClaudeWiki: `junshi-shibing-gsd-dispatch-sop.md`
- **跨項目派工** — ClaudeWiki: `junshi-shibing-cross-project-dispatch-guide.md`
- **Gotcha 記錄** — ClaudeWiki: `2026-08-17-dispatch-plan-mode-and-tail-gotcha.md`

---

**支持所有 GSD 運行時的統一派工系統**

v1.0.0 | Production Ready | MIT License
