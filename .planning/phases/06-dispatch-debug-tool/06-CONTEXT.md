---
phase: 6
title: "GSD-Dispatch Debug Tool — Context & Decisions"
date: 2026-08-19
status: "Discussion Complete"
---

# Phase 6：GSD-Dispatch Debug Tool — 實現決策

## 背景與問題陳述

**Milestone 1.2 已完成** 派工系統的核心修復（超時保護、智能重試、prompts-based 架構），但用戶在實際使用中發現派工系統**仍存在多個使用難點**：

### 已知痛點（從 wiki 踩坑記錄）

1. **派工鏈自動串聯不可靠**（gsd-dispatch-chain-broken.md）
   - research→plan→check 鏈式執行失敗
   - Execute/Check 模式卡頓、多進程竞争
   - 需要手動逐個派工確認完成

2. **派工狀態難以判斷**（2026-08-17-dispatch-plan-mode-and-tail-gotcha.md）
   - `tail` 看 log 誤判派工失敗（\r 字符問題）
   - 難以區分「在運行」vs「已完成」vs「卡住」
   - 需要複雜的檔案檢查和 git 提交查證

3. **環境配置容易出錯**
   - TARGET_DIR 未明確指定導致檢查錯誤項目
   - RETRY=true 路由不直覺
   - 環境變數、PATH、執行權限混亂

4. **故障排查缺乏工具**
   - 派工失敗時需手動分析 log
   - 無法快速判斷是「參數錯誤」vs「超時」vs「伺服器故障」
   - 無法自動建議修復方案

## Phase 6 使用意圖

**Debug Tool 的核心目的：降低派工系統的使用門檻**
- 讓非技術人員也能快速診斷派工故障
- 提供自動化、可視化的故障報告
- 給出「下一步該做什麼」的建議

## 已鎖定的決策

### 1. Debug Tool 應該涵蓋哪些情景？

**決策：同時支援「功能診斷」和「故障排查」**

| 情景 | 用途 | 對應模式 |
|------|------|--------|
| 確認派工沒有在進行中 | 啟動派工前檢查 | `status` |
| 驗證安裝完整（装機後、更新後） | 確保環境正常 | `install` |
| 判斷派工是否真的失敗了 | 區分「卡住」vs「完成」 | `logs` + 文件檢查 |
| 快速定位故障原因 | 自動分類錯誤類型 | `diagnose` |
| 確認 RETRY 機制工作 | 驗證重試邏輯 | `retry` |
| 檢查環境變數和 PATH | 解決權限/路由問題 | `check-env` |

**理由：** 根據 wiki 踩坑記錄，派工故障的根本原因來自 5 個層面（設計缺口、協調缺失、失敗攔截、多進程管理、模式不穩定），Debug Tool 應當提供分層診斷能力，而非單一「全能」模式。

### 2. 輸出風格如何平衡「易於人類閱讀」vs「易於腳本解析」？

**決策：彩色人類輸出為主，支援 JSON 輸出為輔助**

```
預設輸出：彩色、表格、建議提示（terminal 友好）
  gsd-dispatch-debug status
  
JSON 輸出（可選）：用於自動化工具集成
  gsd-dispatch-debug status --json
```

**理由：** 派工系統主要被「人」在終端機中使用，彩色輸出和結構化提示能大幅降低認知負擔。JSON 輸出作為選項，為未來自動化整合（如 Dashboard、CI/CD 鉤子）預留接口。

### 3. 自動建議修復時應該涵蓋哪些常見問題？

**決策：聚焦「用戶可自助修復」的問題，忽略「需人工介入」的問題**

**可自助修復**（提供建議）：
- ❌ gsd-dispatch.sh 缺少執行權限 → `chmod +x`
- ❌ ~/.local/bin 不在 PATH → 提示如何修改 .zshrc / .bashrc
- ❌ RETRY 未啟用 → `export RETRY=true`
- ❌ 舊版本 dispatch-with-retry.sh 與新版本 gsd-dispatch.sh 不同步 → `bash install.sh`
- ⚠️ 派工卡住/超時 → 提示檢查 OpenCode 伺服器狀態、增加 timeout 值

**無法自助修復**（只報告，不建議）：
- 🚫 OpenCode 伺服器故障（err_* 錯誤） → 「等伺服器恢復或聯繫 OpenCode 支援」
- 🚫 派工內容本身有邏輯錯誤 → 「需人工檢查 .planning/ 檔案」
- 🚫 多進程卡頓（Phase 3 issue）→ 「已知限制，建議手動逐個派工」

**理由：** Debug Tool 的目的是減少用戶的調試工作量，而非變成「會修復一切的魔法工具」。明確區分「可診斷」vs「可修復」，避免虛假的自動化承諾。

### 4. Tool 的命令行 UX 應該是什麼？

**決策：遵循「unix 工具」風格，簡潔且易組合**

```bash
# 單一模式
gsd-dispatch-debug status
gsd-dispatch-debug logs
gsd-dispatch-debug diagnose

# 組合模式
gsd-dispatch-debug status logs              # status + logs
gsd-dispatch-debug install retry check-env  # 多個檢查

# 標誌
gsd-dispatch-debug logs --tail 50           # 自訂 log 行數
gsd-dispatch-debug logs --grep "err_"       # 搜尋特定模式
gsd-dispatch-debug diagnose --fix           # 自動嘗試修復（謹慎）
gsd-dispatch-debug status --json            # JSON 輸出
```

**理由：** 讓工具能應對「用戶想要某一個診斷」（快速路徑）以及「用戶想要全面診斷」（診斷模式）兩種工作流。

### 5. 何時整合到 install.sh？

**決策：作為可選的 `--verify` 步驟，而非強制執行**

```bash
bash install.sh                  # 預設安裝
bash install.sh --verify         # 安裝 + 自動診斷驗證
bash install.sh --verify --fix   # 安裝 + 診斷 + 嘗試自動修復
```

**理由：** 
- 安裝時執行診斷會增加時間（+10-20s）
- 某些環境下診斷可能失敗（如沙盒環境）
- 分離「安裝」和「驗證」讓用戶有選擇權

### 6. `/gsd:dispatch-debug` Skill 的優先級？

**決策：標記為「可選」（Phase 6.2），在 Phase 6.1 完成 shell tool 後評估**

**原因：**
- Shell tool 本身已能涵蓋 90% 的使用場景
- Skill 的主要價值是「讓人不用開終端機」
- 先交付 shell tool，根據用戶實際反饋再決定是否做 skill 版本

## 灰色區域解析（已決議）

| 灰色區域 | 考慮選項 | 決策 | 理由 |
|---------|---------|------|------|
| 派工鏈自動串聯修復 | 修復 vs 文檔化已知限制 | 文檔化限制 | 派工系統設計問題複雜，修復需大規模重構 |
| Execute/Check 卡頓診斷 | 診斷成因 vs 迴避方案 | 迴避方案 | 根本原因可能在 OpenCode 伺服器或資源洩漏，Debug Tool 提示「已知限制」 |
| 自動修復程度 | 完全自動 vs 引導式 | 引導式 | 避免副作用，提示用戶手動執行修復命令 |

## 下游工作流

**Phase 6 完成後的交付物：**
1. `scripts/gsd-dispatch-debug.sh` — 可執行工具
2. 更新 install.sh 的 `--verify` 選項
3. 更新 DEVELOPMENT-WORKFLOW.md 「派工排障」章節，納入 Debug Tool 使用說明
4. （可選）`/gsd:dispatch-debug` Skill

**誰會使用這個 Tool：**
- 開發人員在派工失敗時自我診斷
- CI/CD 流程自動檢查派工環境健康度
- 新用戶驗證 gsd-addon 安裝完整性

## 後續決策（不在 Phase 6 範圍內，deferred）

- 修復派工鏈自動串聯機制 → Phase 6.5（後續里程碑）
- 解決 Execute/Check 多進程卡頓 → 需深入 OpenCode 診斷（可能外包）
- 建立派工系統監控 Dashboard → 另一個里程碑
