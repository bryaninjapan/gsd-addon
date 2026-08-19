---
phase: 6
type: implementation-checklist
title: "Layer 1-4 Fix Implementation Checklist"
date: 2026-08-20
---

# 層級 1-4 修復 — 實施清單

## 待確認的設計細節

### ❓ 問題 1：MODE 順序和包含範圍

**選項 A：** research → plan → check
```bash
for mode in research plan check; do
  MODE="$mode" gsd-dispatch.sh "$PHASE"
done
```

**選項 B：** research → plan → execute
```bash
for mode in research plan execute; do
  MODE="$mode" gsd-dispatch.sh "$PHASE"
done
```

**我的理解：** 
- Check mode = 計畫驗證（無需 execute）
- Execute mode = 實際執行任務
- 派工鏈的目的是「研究→規劃→驗證」，不是「執行任務」

**建議：** Option A（research → plan → check）

✅ **你的決定：** [ ] Option A  [ ] Option B  [ ] 其他

---

### ❓ 問題 2：輸出檔案路徑確認

根據觀察，三個 mode 的輸出檔案應該是：
```
research  → .planning/phases/<PHASE>/<PADDED>-RESEARCH.md
plan      → .planning/phases/<PHASE>/<PADDED>-PLAN.md
check     → .planning/phases/<PHASE>/<PADDED>-PLAN-CHECK.md
```

**問題：** `<PADDED>` 是什麼？例如 `02-research.md` 還是 `02-01-research.md`？

查証：
```bash
# gsd-addon Phase 5 的實際輸出
ls -1 /Users/bryan/Documents/gsd-addon/.planning/phases/05-*/

# soapwavehealing Phase 3 的實際輸出
ls -1 /Users/bryan/Documents/soapwavehealing/.planning/phases/03-*/
```

**我的假設：** 
- Phase 2-3：`03-RESEARCH.md`, `03-PLAN.md`, `03-PLAN-CHECK.md`（無子任務編號）
- Phase 5 可能有波次：`05-01-SUMMARY.md`, `05-02-SUMMARY.md`（有子任務編號）

**建議：** 使用 glob pattern `<PHASE_DIR>/*-RESEARCH.md` 而非精確路徑

✅ **你的決定：** [ ] 精確路徑 `03-RESEARCH.md`  [ ] Glob pattern `*-RESEARCH.md`  [ ] 其他

---

### ❓ 問題 3：失敗時的行為

**選項 A：** 第一個失敗就停止（fail-fast）
```bash
MODE="$mode" gsd-dispatch.sh "$PHASE"
if [[ $? -ne 0 ]]; then
  echo "✗ $mode 派工失敗，中止鏈式執行"
  exit 1
fi
```

**選項 B：** 所有 mode 都跑完，最後回報失敗
```bash
FAILED=false
for mode in research plan check; do
  if ! MODE="$mode" gsd-dispatch.sh "$PHASE"; then
    FAILED=true
  fi
done
[[ "$FAILED" == true ]] && exit 1
```

**我的理解：**
- Option A 更快（失敗立即停止）
- Option B 更資訊豐富（知道哪些 mode 失敗）

**建議：** Option A（fail-fast，符合派工鏈的邏輯）

✅ **你的決定：** [ ] Option A  [ ] Option B  [ ] 其他

---

### ❓ 問題 4：跨專案派工支援（TARGET_DIR）

**選項 A：** 只支援本地派工（不用 TARGET_DIR）
```bash
gsd-dispatch-chain.sh 3
```

**選項 B：** 支援跨專案派工
```bash
TARGET_DIR=/Users/bryan/Documents/soapwavehealing \
  gsd-dispatch-chain.sh 3
```

**我的理解：**
- 派工鏈的主要用途是「當前專案」的 research→plan→check
- 跨專案派工（Phase 5 中已測試過）需要明確指定 TARGET_DIR
- 複雜度：Option B 需要額外 10-15 行

**建議：** Option A（簡單優先），若需要跨專案可後期擴展

✅ **你的決定：** [ ] Option A  [ ] Option B  [ ] 其他

---

### ❓ 問題 5：MODEL 選擇支援

**選項 A：** 使用預設模型（opencode-go/deepseek-v4-flash）
```bash
gsd-dispatch-chain.sh 3
```

**選項 B：** 允許自訂模型
```bash
gsd-dispatch-chain.sh 3 "opencode-go/gpt-4-turbo"
```

**我的理解：**
- 派工鏈是自動化工具，應該有合理的預設
- 用戶若需要自訂可以直接改腳本或環境變數
- 複雜度：Option B 需要額外 5 行

**建議：** Option A（預設 deepseek），若需要自訂可以 `export MODEL=...` 後再跑

✅ **你的決定：** [ ] Option A  [ ] Option B  [ ] 其他

---

### ❓ 問題 6：重試邏輯

**選項 A：** 不重試，失敗直接停止
```bash
if [[ $? -ne 0 ]]; then
  exit 1
fi
```

**選項 B：** 自動重試失敗的 mode（3 次）
```bash
for retry in 1 2 3; do
  if MODE="$mode" gsd-dispatch.sh "$PHASE"; then
    break
  fi
  echo "重試 $retry/3..."
done
```

**我的理解：**
- 派工鏈是「順序執行」工具，自動重試應該由 gsd-dispatch 本身（RETRY=true）負責
- 派工鏈層面不應該引入重試邏輯（會複雜化）

**建議：** Option A（無重試），用戶若需要可用 `RETRY=true gsd-dispatch-chain.sh 3`

✅ **你的決定：** [ ] Option A  [ ] Option B  [ ] 其他

---

## 實施步驟

### Step 1：寫 gsd-dispatch-chain.sh（~100 行）
```bash
#!/bin/bash
# 用法：gsd-dispatch-chain.sh <PHASE>
# 功能：串聯 research → plan → check

PHASE="${1:?Phase number required}"

echo "═══════════════════════════════════════════════════"
echo "派工鏈啟動：Phase $PHASE (research → plan → check)"
echo "═══════════════════════════════════════════════════"
echo ""

for mode in research plan check; do
  echo "【$mode】啟動派工..."
  
  if ! MODE="$mode" ~/.claude/gsd-addon/scripts/gsd-dispatch.sh "$PHASE"; then
    echo "✗ $mode 派工失敗（exit $?）"
    exit 1
  fi
  
  # 驗證輸出檔案
  case "$mode" in
    research)
      if ! ls .planning/phases/$PHASE/*-RESEARCH.md 2>/dev/null | grep -q .; then
        echo "✗ RESEARCH.md 未產出"
        exit 1
      fi
      ;;
    plan)
      if ! ls .planning/phases/$PHASE/*-PLAN.md 2>/dev/null | grep -q .; then
        echo "✗ PLAN.md 未產出"
        exit 1
      fi
      ;;
    check)
      if ! ls .planning/phases/$PHASE/*-PLAN-CHECK.md 2>/dev/null | grep -q .; then
        echo "✗ PLAN-CHECK.md 未產出"
        exit 1
      fi
      ;;
  esac
  
  echo "✓ $mode 完成"
  echo ""
done

echo "═══════════════════════════════════════════════════"
echo "✓ 派工鏈完成：research → plan → check"
echo "═══════════════════════════════════════════════════"
```

---

### Step 2：整合到 install.sh

在 install.sh 中添加可選的派工鏈驗證：
```bash
if [[ "$VERIFY" == "true" ]]; then
  echo "驗證派工鏈..."
  bash scripts/gsd-dispatch-chain.sh 2  # 測試 Phase 2
  if [[ $? -eq 0 ]]; then
    echo "✓ 派工鏈驗證通過"
  else
    echo "✗ 派工鏈驗證失敗"
    exit 1
  fi
fi
```

使用方式：
```bash
bash install.sh --verify  # 安裝 + 驗證派工鏈
```

---

### Step 3：測試

#### 本地測試（gsd-addon）
```bash
cd /Users/bryan/Documents/gsd-addon
bash scripts/gsd-dispatch-chain.sh 6
# 預期：research → plan → check 順序執行，都通過
```

#### 跨專案測試（soapwavehealing）
```bash
cd /Users/bryan/Documents/soapwavehealing
bash ~/.claude/gsd-addon/scripts/gsd-dispatch-chain.sh 3
# 預期：Phase 3 已有產出，應該快速通過檢查
```

---

### Step 4：更新文檔

在 DEVELOPMENT-WORKFLOW.md 中添加「派工鏈」章節：
```markdown
## 派工鏈（自動順序執行）

### 用途
自動執行 research → plan → check 的完整流程

### 用法
```bash
gsd-dispatch-chain.sh <PHASE>
```

### 例子
```bash
gsd-dispatch-chain.sh 3
# 自動順序執行：
#   1. MODE=research gsd-dispatch.sh 3
#   2. MODE=plan gsd-dispatch.sh 3
#   3. MODE=check gsd-dispatch.sh 3
```

### 若需要重試
```bash
RETRY=true gsd-dispatch-chain.sh 3
```

### 已知限制
- 不支援跨專案派工（需要 TARGET_DIR，可後期添加）
- 若 check 派工卡頓（已知問題），可設置 timeout：
  ```bash
  timeout 300 gsd-dispatch-chain.sh 3
  ```
```

---

## 成功標準

- [ ] gsd-dispatch-chain.sh 可執行，bash -n 通過
- [ ] 本地測試通過（gsd-addon Phase 6）
- [ ] 跨專案測試通過（soapwavehealing Phase 3）
- [ ] 整合到 install.sh --verify 成功
- [ ] DEVELOPMENT-WORKFLOW.md 已更新
- [ ] git commit 完成

---

## 預期時間

| 步驟 | 預估 |
|------|------|
| 1. 寫腳本 | 30min |
| 2. 整合 install.sh | 15min |
| 3. 測試 | 30min |
| 4. 文檔 | 15min |
| **合計** | **1.5-2h** |

---

## 你的輸入需要

請確認上述 6 個問題的答案，我會根據你的決定直接開始 implement。

最快的方式：
```
✅ 確認 6 個問題的答案
↓
✅ 我直接 execute（1.5-2h）
↓
✅ git commit + push
```
