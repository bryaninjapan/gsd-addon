# Milestone 1.2：GSD-Dispatch 韌性與重試機制 — 文檔索引

**創建日期**: 2026-08-19  
**狀態**: 🔄 進行中（Phase 2 完成，4/5 個 phases 待執行）  
**所有者**: Bryan (claude)  

**編號對照**: 本目錄下的 `phase-1.2a/b/c` 是最初規劃時的命名，實際執行改用 GSD 標準目錄結構
`.planning/phases/NN-slug/`（ROADMAP 正式編號 Phase 2-5）。Phase 1.2A → 正式 Phase 2（已完成）；
執行 Phase 2 時發現 source/安裝副本分岔問題，插入新的正式 Phase 3；原 Phase 1.2B → 正式 Phase 4；
原 Phase 1.2C → 正式 Phase 5。

---

## 📚 文檔清單

### 核心規劃文檔

| 文檔 | 用途 | 狀態 |
|------|------|------|
| [OVERVIEW.md](./OVERVIEW.md) | Milestone 整體目標、四個 phases、成功標準 | ✅ 完成 |
| [INDEX.md](./INDEX.md) | 本檔案，文檔索引 | ✅ 完成 |

### Phase 規劃文檔

#### Phase 2：Core Timeout Hardening ✅ 已完成
| 文檔 | 用途 | 狀態 |
|------|------|------|
| [../phases/02-dispatch-timeout-hardening/02-PLAN.md](../phases/02-dispatch-timeout-hardening/02-PLAN.md) | 權威實現計畫 | ✅ 完成 |
| [../phases/02-dispatch-timeout-hardening/2-SUMMARY.md](../phases/02-dispatch-timeout-hardening/2-SUMMARY.md) | 執行結果 SUMMARY | ✅ 完成 |
| phase-1.2a/PLAN.md | 原始規劃文檔（歷史參考，已被上方權威版取代） | 📁 存檔 |

#### Phase 3：Source/安裝副本分岔修復 🆕
| 文檔 | 用途 | 狀態 |
|------|------|------|
| [../phases/03-dispatch-source-install-drift/03-PLAN.md](../phases/03-dispatch-source-install-drift/03-PLAN.md) | 權威實現計畫 | ✅ 完成 |
| ../phases/03-dispatch-source-install-drift/3-SUMMARY.md | 執行結果 SUMMARY | 📋 待執行 |

#### Phase 4（原 1.2B）：Retry Wrapper Implementation
| 文檔 | 用途 | 狀態 |
|------|------|------|
| [phase-1.2b/PLAN.md](./phase-1.2b/PLAN.md) | 實現計畫、5 個任務分解 | ✅ 完成（待轉為 `.planning/phases/04-*/04-PLAN.md` 標準結構） |

#### Phase 5（原 1.2C）：Integration & Testing
| 文檔 | 用途 | 狀態 |
|------|------|------|
| [phase-1.2c/PLAN.md](./phase-1.2c/PLAN.md) | 實現計畫、7 個任務分解 | ✅ 完成（待轉為 `.planning/phases/05-*/05-PLAN.md` 標準結構） |

---

## 📋 快速導航

### 我想了解 Milestone 的整體目標？
→ 閱讀 [OVERVIEW.md](./OVERVIEW.md)

### 我想看 Phase 1.2A 的具體任務？
→ 閱讀 [phase-1.2a/PLAN.md](./phase-1.2a/PLAN.md)

### 我想看 Phase 1.2B 的具體任務？
→ 閱讀 [phase-1.2b/PLAN.md](./phase-1.2b/PLAN.md)

### 我想看 Phase 1.2C 的具體任務？
→ 閱讀 [phase-1.2c/PLAN.md](./phase-1.2c/PLAN.md)

### 我想追蹤 Phase 執行進度？
→ 查看各 phase 的 STATE.md（待執行時創建）

### 我想看 Phase 驗收標準？
→ 查看各 phase 的 VERIFICATION.md（待執行時創建）

---

## 🚀 下一步

1. ✅ **規劃階段完成**（本檔案）
2. ⏳ **進入 Phase 1.2A**：執行 [phase-1.2a/PLAN.md](./phase-1.2a/PLAN.md)
   - 預計時間：2 小時
   - 任務：修復 gsd-dispatch.sh 中的三處無超時命令
3. ⏳ **進入 Phase 1.2B**：執行 [phase-1.2b/PLAN.md](./phase-1.2b/PLAN.md)
   - 預計時間：3.5 小時
   - 任務：創建 dispatch-with-retry.sh + 環境變數集成
4. ⏳ **進入 Phase 1.2C**：執行 [phase-1.2c/PLAN.md](./phase-1.2c/PLAN.md)
   - 預計時間：3.5 小時
   - 任務：集成測試 + soapwavehealing 驗證

---

## 📊 Milestone 統計

| 項目 | 數值 |
|------|------|
| 總 Phases | 3 |
| 總任務 | 17 |
| 總規劃文檔 | 3 |
| 總執行文檔 | 9 |
| 預計總時間 | 9 小時 |
| 預計完成日期 | 2026-08-20 |

---

## 🔗 相關文檔

**上層**:
- [`../.ROADMAP.md`](../ROADMAP.md) — gsd-addon 總體路線圖

**外部**:
- [`.planning/debug/gsd-dispatch-opencode-server-error.md`](../debug/gsd-dispatch-opencode-server-error.md) — 背景問題記錄
- [`DEVELOPMENT-WORKFLOW.md`](../../DEVELOPMENT-WORKFLOW.md) — 派工排障指南（需更新）

---

## 📝 變更歷史

| 日期 | 異動 | 作者 |
|------|------|------|
| 2026-08-19 | 初始創建：OVERVIEW.md + 三個 Phase PLAN.md | Claude Code |
| — | — | — |

---

**最後更新**: 2026-08-19
