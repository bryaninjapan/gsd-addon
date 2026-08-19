---
phase: 6
type: diagnostic-plan
title: "Layer 5 Hang Diagnosis — Execute/Check Mode Deadlock"
date: 2026-08-20
---

# 層級 5 深度診斷計畫

## 問題陳述

根據 Phase 3 在 soapwavehealing 的實際觀察：

### 症狀 A：Execute 派工卡頓
```
時間軸：
- 20:15 UTC — execute 派工啟動
- 20:47 UTC (+32min) — 仍無進展，10+ opencode 進程堆積
- 21:00 UTC — 手動終止（無 SUMMARY.md 產出）

預期：30 分鐘完成 → 實際：無限期卡頓
```

### 症狀 B：Check 派工間歇性卡頓
```
第一次運行（21:15 UTC）
  ✓ 完成（513 行輸出）
  ⏱️ 耗時 2-3 分鐘
  ✓ 產出 VERDICT（1 Blocker + 5 Warnings）

第二次運行（21:35 UTC）
  ⏱️ 卡在「Read admin/main.tsx」
  ❌ 120+ 秒後無進展
  ❌ 進程堆積 8 個 opencode
  ❌ 無 VERDICT 輸出
```

## 假設 1：高負載內容導致的資源洩漏

**前提：** Phase 3 soapwavehealing 包含
- ROADMAP.md: 86 行
- 5 個 PLAN.md：~1,674 行總計
- 合計：~1MB+ JSON/YAML/Markdown 解析

**假設：** OpenCode/Deepseek 派工時，`gsd-dispatch.sh` 將 ROADMAP + 5 個 PLAN.md 內容傳給 opencode，opencode 可能在以下環節卡頓：

1. **JSON 序列化** — 5 個大型 PLAN.md 序列化為 JSON 時內存峰值
2. **Prompt 構建** — `build_prompt()` 插值 1MB+ 內容，生成超大 prompt（可能 > 10MB）
3. **模型推理** — Deepseek 接收超大 prompt，token 數超過限制或觸發內存警告
4. **並行派工干擾** — 多個 opencode 進程同時處理相同大文件，競爭 I/O

## 假設 2：Opencode 伺服器端限制

**可能的伺服器側限制：**
- Request size limit（超過則拒絕或卡頓）
- Prompt token limit（Deepseek 有上限）
- 進程池耗盡（同時太多派工請求）
- 模型推理超時（沒有正確處理超時）

## 假設 3：派工腳本層的 bug

**可能的腳本問題：**
- `build_prompt()` 中的環境變數插值遺漏，導致 prompt 不完整
- TARGET_DIR 邏輯導致重複讀取文件
- 子進程管理問題（zombie 進程、fd 洩漏）

---

## 診斷步驟（執行順序）

### 步驟 1：重現卡頓（可控環境）

**目標：** 在已知條件下重現 Execute/Check 卡頓

```bash
cd /Users/bryan/Documents/soapwavehealing

# 準備：確保 Phase 3 工作區完整
ls -lh .planning/phases/03-admin-api-d1-sync/03-*.md

# 重現 Check 派工卡頓
time MODE=check TARGET_DIR=. timeout 120 \
  ~/.claude/gsd-addon/scripts/gsd-dispatch.sh 3 2>&1 | tee check-hangtest.log

# 記錄進程狀態
ps aux | grep opencode | grep -v grep > process-snapshot.txt
```

**預期結果：**
- ✓ 快速完成（< 30s）→ 正常
- ⏱️ 10-120s 卡住 → 重現問題
- ⏰ 120s 超時 → 確認卡頓

### 步驟 2：分析內容大小和複雜度

**假設 1 驗證 — 內容負載測試**

```bash
# 測量 prompt 大小
cd /Users/bryan/Documents/soapwavehealing

# 計算 ROADMAP + PLAN 組合大小
cat .planning/ROADMAP.md .planning/phases/03-*/*.md | wc -c

# 估算 build_prompt() 的輸出大小（模擬）
# gsd-dispatch.sh 會做：
# prompt=$(cat prompts/check.md)
# prompt=${prompt//\$\{ROADMAP\}/"$(cat .planning/ROADMAP.md)"}
# prompt=${prompt//\$\{PHASE_PLANS\}/"$(cat .planning/phases/03-*/*.md)"}

# 實際大小（粗估）
SIZE=$(cat .planning/ROADMAP.md .planning/phases/03-*/*.md | wc -c)
echo "ROADMAP + Phase 3 Plans combined: $SIZE bytes"
echo "Estimated tokens (4 chars ≈ 1 token): $((SIZE / 4))"
```

**閾值判斷：**
- < 100KB → 應該無問題
- 100KB - 500KB → 邊界，可能卡頓
- \> 500KB → 高危，容易觸發 OpenCode 限制

### 步驟 3：檢查派工腳本層的邏輯

**假設 3 驗證 — 腳本邏輯審計**

```bash
# 1. 檢查 build_prompt() 是否正確注入 ROADMAP
grep -n "ROADMAP" ~/.claude/gsd-addon/scripts/gsd-dispatch.sh | head -10

# 2. 檢查 MODE=check 的 prompt 構建
grep -A 20 "MODE.*check" ~/.claude/gsd-addon/scripts/gsd-dispatch.sh | head -30

# 3. 檢查環境變數注入
grep -n "extract_phase_section\|build_prompt" ~/.claude/gsd-addon/scripts/gsd-dispatch.sh

# 4. 手動測試 prompt 構建（不派工，只生成 prompt）
# 提取派工腳本中的 build_prompt() 函數並測試
```

### 步驟 4：監測派工進程的資源使用

**目標：** 收集進程狀態、內存、CPU、文件描述符

```bash
# 準備監測腳本
cat > monitor-dispatch.sh << 'EOF'
#!/bin/bash
DISPATCH_PID=$1
INTERVAL=${2:-2}

echo "Monitoring PID $DISPATCH_PID every ${INTERVAL}s..."
echo "Time,PID,STAT,VSZ(MB),RSS(MB),CPU(%),FD_COUNT,OPENCODE_PROCS"

while kill -0 "$DISPATCH_PID" 2>/dev/null; do
  STAT=$(ps -p "$DISPATCH_PID" -o stat=)
  VSZ=$(ps -p "$DISPATCH_PID" -o vsz=)
  RSS=$(ps -p "$DISPATCH_PID" -o rss=)
  CPU=$(ps -p "$DISPATCH_PID" -o %cpu=)
  FD_COUNT=$(ls /proc/"$DISPATCH_PID"/fd 2>/dev/null | wc -l)
  OC_PROCS=$(pgrep -f "opencode" | wc -l)
  
  echo "$(date '+%H:%M:%S'),${DISPATCH_PID},${STAT},$(( VSZ / 1024 )),$(( RSS / 1024 )),${CPU},${FD_COUNT},${OC_PROCS}"
  
  sleep "$INTERVAL"
done
EOF

chmod +x monitor-dispatch.sh

# 實際監測執行
cd /Users/bryan/Documents/soapwavehealing

# 背景啟動派工
timeout 180 bash ~/.claude/gsd-addon/scripts/gsd-dispatch.sh 3 > dispatch.log 2>&1 &
DISPATCH_PID=$!

# 監測派工進程
./monitor-dispatch.sh "$DISPATCH_PID" 1 > monitor.csv

# 等待派工結束
wait "$DISPATCH_PID"
EXIT_CODE=$?

echo "Dispatch exit code: $EXIT_CODE"
```

**分析 monitor.csv：**
- VSZ/RSS 持續增長 → 內存洩漏
- FD_COUNT 持續增長 → 文件描述符洩漏
- STAT 長期為 S（sleep）或 D（disk wait） → 卡在 I/O 或鎖定
- OPENCODE_PROCS 持續增長 → 派工無法終止

### 步驟 5：檢查 OpenCode 伺服器端日誌

**前提條件：** 需要 OpenCode 的存取權限

```bash
# OpenCode 官方日誌位置（若可存取）
# ~/.opencode/logs/ 或類似位置

# 檢查是否有錯誤或超時記錄
grep -i "timeout\|error\|hang" ~/.opencode/logs/* 2>/dev/null

# 檢查請求日誌是否有異常
grep "dispatch\|gsd" ~/.opencode/logs/* 2>/dev/null
```

### 步驟 6：模型限制測試

**目標：** 確認是否為 Deepseek 模型的 token/prompt 大小限制

```bash
# 直接測試 Deepseek 與超大 prompt
LARGE_PROMPT=$(cat .planning/ROADMAP.md .planning/phases/03-*/*.md)

# 用 opencode 直接測試（繞過 gsd-dispatch.sh）
echo "Testing Deepseek with large prompt (~$(echo -n "$LARGE_PROMPT" | wc -c) bytes)..."

timeout 60 opencode run -m opencode-go/deepseek-v4-flash << EOF
你是一個代碼審查員。請分析以下計畫內容是否合理。

$LARGE_PROMPT

回覆：此計畫包含 $(echo "$LARGE_PROMPT" | wc -l) 行，已收到。
EOF

EXIT_CODE=$?
echo "Exit code: $EXIT_CODE (0=success, 124=timeout, other=error)"
```

---

## 預期發現和修復方向

### 發現 A：內容過大（> 500KB）
→ **修復方向：** 修改 `gsd-dispatch.sh`，分割內容
- 只傳送當前 phase 的相關 PLAN.md，不傳送全部
- 使用 `--excerpt` 提取 ROADMAP 的摘要而非全文

### 發現 B：進程資源洩漏
→ **修復方向：** 修改派工腳本
- 添加進程清理邏輯
- 檢查 fd 洩漏，顯式關閉文件句柄

### 發現 C：OpenCode 伺服器限制
→ **修復方向：** 調整派工參數或繞過限制
- 減少 prompt 大小
- 使用分批派工（多個小派工而非一個大派工）
- 更新 opencode 版本

### 發現 D：Deepseek 模型限制
→ **修復方向：** 更換模型或修改 prompt
- 嘗試 `opencode-go/gpt-4-turbo` 或其他模型
- 簡化 prompt 結構

---

## 執行時間表

| 步驟 | 預估時間 | 關鍵產出 |
|------|--------|--------|
| 1. 重現卡頓 | 15-30min | hang-test.log，process-snapshot.txt |
| 2. 內容分析 | 10min | 大小評估，token 計數 |
| 3. 腳本審計 | 20-30min | 邏輯流程圖，潛在 bug 清單 |
| 4. 進程監測 | 30min（含等待） | monitor.csv，資源使用趨勢 |
| 5. 伺服器日誌 | 10min | 若有存取，即時錯誤記錄 |
| 6. 模型限制測試 | 15min | Deepseek 限制確認 |
| **合計** | **100-135min** | **根本原因診斷** |

---

## 決策樹

```
診斷完成
  ├─ 發現內容過大 (A)
  │   └─ 修復：優化 prompt 構建，分批派工
  │
  ├─ 發現進程洩漏 (B)
  │   └─ 修復：修改派工腳本，添加清理邏輯
  │
  ├─ 發現 OpenCode 限制 (C)
  │   └─ 修復：減少 payload，或分批派工
  │
  ├─ 發現 Deepseek 限制 (D)
  │   └─ 修復：更換模型，或簡化 prompt
  │
  └─ 無明顯原因
      └─ 決策：放棄派工系統修復，改用 Claude Code Agent
```

---

## 預計成果

**若診斷成功（100-135min）：**
- ✅ 確切的根本原因
- ✅ 針對性的修復方案（Phase 6.1）
- ✅ 修復預計時間和複雜度估計

**若診斷失敗或無可控修復：**
- ✅ 明確的「無法修復」證據
- ✅ 正當的理由回歸「改用 Claude Code Agent」方案
- ✅ 已知限制文檔化
