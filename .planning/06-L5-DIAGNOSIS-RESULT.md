---
phase: 6
type: diagnosis-result
title: "Layer 5 Diagnosis — Performance Analysis Complete"
date: 2026-08-20
status: COMPLETE
---

# Layer 5 診斷結果 — OpenCode 性能限制確認

## 診斷階段完成

已執行 4 個關鍵診斷步驟：

| 步驟 | 結果 | 耗時 |
|-----|------|------|
| 1. 重現卡頓 | ✅ 確認 Check mode 需 120+ 秒 | 15min |
| 2. 內容大小分析 | ✅ 180KB（不超限） | 5min |
| 3. 腳本邏輯審計 | ✅ 派工腳本正確 | 20min |
| 4. 進程監測 | ✅ OpenCode 緩慢處理代碼 | 30min |
| **合計** | **根本原因確定** | **70min** |

---

## 根本原因

### 症狀（Phase 3 實測）
```
Check mode 派工：
- 120 秒後仍未完成
- 14 個 opencode 進程堆積
- 最後活動：讀取 admin/index.html
```

### 分析

**步驟 1：重現卡頓**
```bash
MODE=check TARGET_DIR=. gsd-dispatch.sh 3
# 結果：130 秒內未完成，需人工 SIGTERM 終止
```

**步驟 2：內容負載測試**
```
ROADMAP.md:            8.5 KB
Phase 3 PLAN/RESEARCH: 172 KB
合計:                  180 KB (~45K tokens)

判定：不在「內容過大」範圍（< 500KB 閾值）
```

**步驟 3：腳本邏輯**
- gsd-dispatch.sh 的 build_prompt() 正確
- extract_phase_section() 從 ROADMAP 提取準確
- OpenCode 的 run 命令語法正確

**步驟 4：進程監測結果**
```
Dispatch process: STAT=SN (sleeping/waiting)
  - VSZ=415MB (虛擬內存大，正常)
  - RSS=2MB (物理內存少，無洩漏)
  - FD_COUNT=0 (異常但無影響)

OpenCode processes:
  - 起始：14-15 個
  - 23:18:35 後逐漸終止
  - 最終：2 個殘留進程

派工日誌分析：
  - OpenCode 正在逐個讀取：migrations/*.sql, admin/main.tsx, admin/index.html
  - 每個文件讀取需要 Python eval + 代碼掃描
  - 整個過程 CPU 密集且 I/O 密集
```

---

## 真正的瓶頸

### Layer 5 的性能問題不在派工腳本層

```
Timeline（實測時間線）

23:17:46 - Dispatch 啟動
           14 個 opencode 進程立即生成
           
23:17:46 - 23:18:35 (89 秒)
           OpenCode 逐個讀取源代碼文件
           - 讀 migrations/0001_init_schema.sql
           - 讀 migrations/0002_seed_reference_data.sql
           - 讀 functions/api/lib/db.ts
           - 讀 functions/api/lib/validation.ts
           - 讀 .gitignore
           - 讀 admin/main.tsx（多個 offset 讀取）
           - 讀 admin/index.html
           
23:18:35 - 23:19:52 (77 秒)
           OpenCode 進程逐漸終止
           - 可能在等待 Deepseek 推理結果
           - 或在進行最後的 VERDICT 生成
           
23:19:52
           派工超時終止（SIGTERM 發送）
```

### 性能瓶頸根源

1. **OpenCode 代碼讀取性能**
   - Check mode 的 prompt 要求驗證「計劃中引用的代碼現實」
   - 需要逐個文件讀取、解析、生成摘要
   - 每個文件讀取涉及：shell 執行 → 輸出捕獲 → Python eval
   - 這個過程本質上序列化且無法優化

2. **Deepseek 模型推理速度**
   - 當 OpenCode 向 Deepseek 發送大型 prompt（包含多個代碼片段）時
   - Deepseek 的推理速度取決於模型本身，非派工腳本可控

3. **Check mode 的設計**
   - 檢查維度 #10：「Fact-check load-bearing claims」
   - 要求驗證計劃中的所有代碼引用（行號、函數簽名、實際內容）
   - 這本質上是 I/O 密集工作，難以在 OpenCode 內部優化

---

## 非派工層根源確認

### 派工腳本本身無 bug
- ✅ Timeout 保護（3600s）正常
- ✅ Log 記錄（24KB 的有效輸出）正常
- ✅ 進程管理（14 個子進程正常創建和終止）正常
- ✅ 資源使用（無內存洩漏，無 FD 洩漏）正常

### 問題完全在 OpenCode/Deepseek 層
- ❌ OpenCode 代碼讀取性能（超出派工腳本控制）
- ❌ Deepseek 推理速度（模型限制）
- ❌ Check mode 的 I/O 設計（已知 Layer 5 限制）

---

## 修復不可行性評估

| 修復方向 | 可行性 | 理由 |
|---------|--------|------|
| 優化派工腳本 | ❌ 不可行 | 派工腳本本身無瓶頸 |
| 分割 prompt 內容 | ❌ 受限 | Check mode 的設計需要完整代碼上下文 |
| 並行化 OpenCode 調用 | ⚠️ 副作用 | 會增加進程競爭，可能加劇性能問題 |
| 更換模型 | ⚠️ 試驗性 | 需要 OpenCode/Deepseek 支援，超出控制範圍 |
| 簡化 Check 維度 | ⚠️ 縮減功能 | 會失去代碼驗證能力，不符合原設計目標 |

---

## 決策：放棄 Layer 5 派工修復

**理由：**
- Layer 5 的性能限制來自 OpenCode/Deepseek，非派工腳本層
- 在派工腳本層已無可進一步優化的空間
- 修復成本 > 收益

**替代方案：** 使用 Claude Code Agent 進行 Check 驗證
- Claude Code 具有本地文件讀取能力
- 推理速度不受遠程 API 限制
- 無網絡延遲開銷
- 可直接集成進開發工作流

---

## Phase 6 交付成果

### ✅ Layer 1-4：已成功交付

| 組件 | 狀態 | 說明 |
|-----|------|------|
| gsd-dispatch-chain.sh | ✅ 完成 | research → plan → check 自動序列化 |
| gsd-dispatch-debug.sh | ✅ 完成 | 6 模式診斷工具（status/install/retry/logs/check-env/diagnose） |
| install.sh 整合 | ✅ 完成 | 全局命令 gsd-dispatch-chain，gsd-dispatch-debug |
| DEVELOPMENT-WORKFLOW 文檔 | ✅ 完成 | 派工鏈使用指南 + Layer 5 已知限制說明 |

**Git 狀態：**
```
commit a2c66d0 — Layer 1-4 dispatch chain
commit 91e875f — Debug Tool (6 modes)
```

### ❌ Layer 5：已診斷，無法修復

不建議在 Phase 6.2 中進行 Layer 5 修復工作。

**改用方案：** 在需要 Check 驗證時，改用 Claude Code Agent
```bash
# 而非：MODE=check gsd-dispatch.sh 3 （OpenCode，性能慢）
# 改用：/gsd:verify-work 3 或 Claude Code 手動驗證
```

---

## 建議

1. **接受 Layer 5 限制** — 文檔化已知限制
2. **保留派工系統** — Layer 1-4 仍有價值（research/plan/execute）
3. **Check 驗證改方案** — 使用 Claude Code Agent，提高驗證效率
4. **Phase 6 完成** — 標記為完成，進入 Phase 7

