# GSD Dispatch 完整指南 — 軍師士兵模式 & 動態編排

**目標**：統一的派工系統，支援立即派工、延時派工、多運行時（Claude Code、OpenCode、Codex、Hermes）

---

## 📋 目錄

1. [快速開始](#快速開始)
2. [三大派工模式](#三大派工模式)
3. [跨項目派工](#跨項目派工)
4. [動態編排與調度](#動態編排與調度)
5. [運行時支持](#運行時支持)
6. [陷阱與解決方案](#陷阱與解決方案)
7. [疑難排解](#疑難排解)

---

## 快速開始

### 基本用法

```bash
# 立即執行（當前工作目錄的 Phase 2）
./scripts/gsd-dispatch.sh 2

# 指定派工模式
MODE=plan ./scripts/gsd-dispatch.sh 2      # 規劃模式
MODE=research ./scripts/gsd-dispatch.sh 2  # 研究模式
MODE=execute ./scripts/gsd-dispatch.sh 2   # 執行模式（預設）

# 指定模型與難度
./scripts/gsd-dispatch.sh 3 opencode-go/kimi-k2.6
VARIANT=minimal ./scripts/gsd-dispatch.sh 7
```

### 跨項目派工

```bash
# 從 vault 派工到 /etf-flow-database
TARGET_DIR=/etf-flow-database ./scripts/gsd-dispatch.sh 8 execute

# 附加到共享 server（session 在軍師 TUI 可見）
SERVER_URL=http://localhost:4096 TARGET_DIR=/project ./scripts/gsd-dispatch.sh 5
```

---

## 三大派工模式

派工腳本支持三種模式，對應 GSD 的三個核心指令：

### 1️⃣ `MODE=research` — 研究階段

**派工目標**：`gsd-research-phase N`  
**職責**：蒐集背景資訊、分析先例、提出選項

```bash
MODE=research ./scripts/gsd-dispatch.sh 3
```

**士兵產出**：
- `.planning/phases/03-*/RESEARCH.md`
- Git commit 記錄研究過程

**軍師驗收**：
```
讀 RESEARCH.md + git log
→ 確認蒐集了必要的背景資訊
→ 下一步: MODE=plan
```

**下一步**：
```bash
MODE=plan ./scripts/gsd-dispatch.sh 3
```

---

### 2️⃣ `MODE=plan` — 規劃階段

**派工目標**：`gsd-plan-phase N`  
**職責**：根據 RESEARCH 產出執行計畫

```bash
MODE=plan ./scripts/gsd-dispatch.sh 3
```

**士兵產出**：
- `.planning/phases/03-*/03-PLAN.md`（及其他 PLAN 檔，如 03-PLAN-02.md）
- Git commit 記錄規劃決策

**特殊行為**（與 execute/research 不同）：
- 一次只產出「缺的」PLAN.md（不會整個重寫）
- 若某 phase 已有部分 PLAN.md，`gsd-plan-phase` 會偵測並接著補完
- 跨專案派工時尚未完全測試 — 優先用於本地派工

**軍師驗收**：
```
讀 PLAN.md + git log
→ 確認 plan 覆蓋所有 requirements
→ 有疑慮 → gsd-plan-checker 驗證
→ 滿意 → /gsd:execute-phase
```

**下一步**：
```bash
# 若要派工執行
./scripts/gsd-dispatch.sh 3 execute

# 或手動執行
/gsd:execute-phase 3
```

---

### 3️⃣ `MODE=execute`（預設）— 執行階段

**派工目標**：`gsd-execute-phase N`  
**職責**：實裝 PLAN 中的所有任務、寫程式、跑測試、commit

```bash
./scripts/gsd-dispatch.sh 3        # 等同 MODE=execute
MODE=execute ./scripts/gsd-dispatch.sh 3
```

**士兵產出**：
- 實裝的程式碼 + 測試
- `.planning/phases/03-*/SUMMARY.md`（士兵總結結果）
- Git commit（每個任務一個原子 commit）

**軍師驗收**：
```
讀 SUMMARY.md + git diff --stat
→ 確認所有代碼改動都在 PLAN 範圍內
→ 讀 log 若發現異常
→ 滿意 → /gsd:verify-work 3
```

**下一步**：
```bash
/gsd:verify-work 3
```

---

## 跨項目派工

### 場景：從 vault 規劃，派工到 ETF 專案執行

```bash
# vault 中運行派工指令
cd ~/Documents/ClaudeWiki
TARGET_DIR=~/Documents/etf-flow-database ./scripts/gsd-dispatch.sh 8
```

### 權限與配置

跨專案派工涉及 **6 個獨立維度** 的權限與配置：

| 維度 | 問題 | 根因 | 解決方案 |
|------|------|------|---------|
| **A** | Session 不可見（軍師 TUI 看不到） | cwd 分群 | `--attach $SERVER_URL` |
| **B** | PLAN/SUMMARY 路徑錯誤 | PROJECT_DIR 寫死 | `TARGET_DIR` env var |
| **C** | ❌ `cd` 到目標目錄 | 會破壞權限白名單 | **不這樣做** |
| **D** | 無頭模式自動拒權外部路徑 | OpenCode CLI 設計 | `gsd-permission-audit.sh` 白名單 |
| **E** | gsd-core 不在目標目錄 | 工具庫位置 | 保持 cwd=vault |
| **F** | 目標 phase 無 PLAN.md | 尚未執行 plan-phase | 先跑 research → plan |

### 自動權限修復

```bash
# 檢查並修復外部路徑權限
./scripts/gsd-permission-audit.sh --target ~/Documents/etf-flow-database --fix
```

這會：
1. 掃 `TARGET_DIR/.planning/` 中的外部路徑引用
2. 檢查 `.opencode/opencode.json` 的白名單
3. 自動補充缺失的 `read` 和 `external_directory` 權限

### 完整跨項目流程

```bash
# 步驟 1：權限準備（一次性）
./scripts/gsd-permission-audit.sh --target ~/Documents/etf-flow-database --fix

# 步驟 2：派工
TARGET_DIR=~/Documents/etf-flow-database ./scripts/gsd-dispatch.sh 8 execute

# 步驟 3：監看（可選，若有 server）
SERVER_URL=http://localhost:4096 TARGET_DIR=~/Documents/etf-flow-database \
  ./scripts/gsd-dispatch.sh 8 execute

# 步驟 4：驗收（回到 Claude Code）
# 讀 SUMMARY.md + git diff
```

---

## 動態編排與調度

### 1. 立即派工（同步）

**場景**：軍師規劃完立即派工，等結果回來

```bash
# 在終端執行，阻斷式等待
./scripts/gsd-dispatch.sh 3 execute
# ← 完成後才返回

# 檢查結果
ls .planning/phases/03-*/SUMMARY.md
```

### 2. 背景派工（非阻斷）

**場景**：派工後立即回到軍師做下一個 phase，士兵後台執行

```bash
# 派工到背景
nohup ./scripts/gsd-dispatch.sh 3 execute > /tmp/phase3.log 2>&1 &
JOB_PID=$!

# 軍師繼續下一個 phase
/gsd:plan-phase 4

# 稍後檢查士兵進度
tail -f .planning/soldier-logs/phase-3-*.log

# 等待完成
wait $JOB_PID
```

### 3. 延時派工（Claude Code 的 ScheduleWakeup）

**場景**：設定時間后再派工（例：凌晨派工省成本）

#### 方案 A：Claude Code 內部（native）

```bash
# Claude Code 提供 ScheduleWakeup 工具
# （此為 Claude Code 特有能力，其他運行時實現不同）

# 在 Claude Code session 中：
ScheduleWakeup({
  delaySeconds: 3600,  # 1 小時後
  prompt: `
    cd ~/Documents/my-project
    MODE=execute ./scripts/gsd-dispatch.sh 2
  `,
  reason: "Dispatch phase 2 execution after 1 hour"
})
```

#### 方案 B：系統層 cron（通用，所有運行時）

```bash
# 編輯 crontab
crontab -e

# 加入（每日凌晨 2 點派工）
0 2 * * * cd /Users/user/Documents/my-project && \
          MODE=execute ./scripts/gsd-dispatch.sh 3 >> .planning/soldier-logs/cron-phase3.log 2>&1
```

#### 方案 C：Shell wrapper 延時啟動

```bash
# 1 小時後派工
(sleep 3600 && cd ~/Documents/my-project && ./scripts/gsd-dispatch.sh 2) &
# 返回立即控制權，後台執行
```

### 4. 平行派工（無依賴的 phase 同時執行）

**場景**：Wave 結構中的獨立 phase 可平行派工

```bash
# ✅ 可平行（無依賴）
./scripts/gsd-dispatch.sh 6.2 &
./scripts/gsd-dispatch.sh 6.4 &
wait

# ❌ 不可平行（有依賴）
# 6.1 → 6.2 → 6.3（必須串行，因為 6.2 依賴 6.1 的輸出）
./scripts/gsd-dispatch.sh 6.1 && \
./scripts/gsd-dispatch.sh 6.2 && \
./scripts/gsd-dispatch.sh 6.3
```

### 5. 模型升級動態派工

**場景**：複雜 phase 臨時升級模型

```bash
# 免費模型卡住了，臨時升級到付費模型
./scripts/gsd-dispatch.sh 5.2 opencode-go/kimi-k2.6

# 或同時控制 effort
VARIANT=max ./scripts/gsd-dispatch.sh 5.2 opencode-go/deepseek-v4-flash
```

---

## 運行時支持

### 現狀與規劃

| 運行時 | ScheduleWakeup | 派工支持 | 模型選擇 | 狀態 |
|--------|---|---|---|---|
| **Claude Code** | ✅ 原生 | ✅ dispatch.sh | ✅ 支持 | 生產 |
| **OpenCode** | ⏳ 規劃 | ✅ dispatch.sh | ✅ 支持 | 生產 |
| **Codex** | ⏳ 規劃 | ⏳ 規劃 | ⏳ 規劃 | 設計中 |
| **Hermes** | ⏳ 規劃 | ⏳ 規劃 | ⏳ 規劃 | 設計中 |

### 運行時特定用法

#### Claude Code（當前）

```bash
# 最完整支持
./scripts/gsd-dispatch.sh 3 execute                    # ✅ 立即派工
ScheduleWakeup({ delaySeconds: 3600, ... })           # ✅ 延時派工
/gsd:verify-work 3                                      # ✅ Claude 指令

# 監看
tail -f .planning/soldier-logs/phase-3-*.log           # ✅ 實時 log
curl http://localhost:4096/session | jq               # ✅ server session
```

#### OpenCode（未來）

```bash
# 預期支持（當前已有派工腳本）
opencode run --command "
  cd ~/Documents/my-project && \
  ./scripts/gsd-dispatch.sh 3 execute
"

# ScheduleWakeup 待實現
# （可用系統 cron 作臨時替代）
```

#### Codex（規劃中）

```bash
# 預期 API：dispatch phase 與 schedule
codex.dispatch.phase(project_dir, phase=3, mode="execute")
codex.schedule.after_seconds(3600, lambda: codex.dispatch.phase(...))
```

#### Hermes（規劃中）

```bash
# 預期與 OpenCode 類似的指令集
hermes execute --phase 3 --project /path/to/project
hermes schedule cron "0 2 * * *" "hermes execute --phase 4"
```

### 為未來運行時預留的接口

gsd-addon 設計時已考慮未來擴展：

```bash
# 環境變數化的配置（便於不同運行時替換實現）
DISPATCH_BACKEND=opencode    # 預設
DISPATCH_BACKEND=codex       # 未來
DISPATCH_BACKEND=hermes      # 未來

# 模塊化設計（run_time/$DISPATCH_BACKEND/dispatch 的方式）
# 當前：scripts/gsd-dispatch.sh（通用 bash）
# 未來：scripts/dispatch/$DISPATCH_BACKEND.py / .cjs / .go
```

---

## 陷阱與解決方案

### 🚨 Gotcha 1：tail 誤判成「士兵崩潰」

**症狀**：
```bash
tail -80 .planning/soldier-logs/phase-3-*.log
# 輸出停在某個地方，以為士兵卡住了
```

**根因**：
OpenCode 大量用 `\r`（carriage return）原地覆寫終端進度行，而不是換行。
這在終端看起來很省空間，但寫進 log 檔時 `\r` 照樣被完整保留。

用 `tail -N` 這種**以 `\n` 計行數**的工具看 log，會嚴重低估內容長度。

**正確判斷死活的方法**：
```bash
# 方法 1：看有沒有新的 git commit ✅✅✅
git log --oneline -5

# 方法 2：看預期產出檔案是否存在 ✅✅✅
ls -lh .planning/phases/03-*/SUMMARY.md

# 方法 3：看 log 尾端原始 bytes（才能看 \r）
xxd -l 200 -s $(($(stat -f%z log) - 200)) .planning/soldier-logs/phase-3-*.log | tail -5

# 方法 4（錯誤）：單純 tail ❌
# 會嚴重誤判！
```

**修復**：
- 判斷派工死活優先看 git log + 檔案存在性
- 不要單憑 `tail` 的行數判斷
- 深入看 log 用 `xxd`/`strings` 或 `less`，不用 `tail -N`

---

### 🚨 Gotcha 2：OpenCode 自我改寫假警報

**症狀**：
```
越界檢查(士兵有沒有動非預期的檔)
  改動: .opencode/opencode.json
  改動: .opencode/package.json
  改動: .opencode/*/...lock
```

**根因**：
OpenCode 每次啟動會自動改寫自己的配置檔（補 schema、plugin 依賴等）。
這**不是士兵越界**，是 OpenCode 的正常行為。

**修復**：
dispatch.sh 已內建白名單排除它們。如果你看到這些提醒，可以安心忽略。

```bash
# dispatch 的白名單
OPENCODE_SELF='\.opencode/opencode\.json|\.opencode/package\.json|\.opencode/.*\.lock|\.planning/soldier-logs/'
# 自動排除這些文件的 diff
```

---

### 🚨 Gotcha 3：無頭模式自動拒權外部路徑

**症狀**：
```
士兵運行中...
→ log 檔顯示成功
→ 但 SUMMARY.md 沒產出，git 也沒新 commit

檢查 log：
  Read /vault/wiki/... failed: user rejected permission (auto-reject, headless mode)
```

**根因**：
OpenCode 無頭模式（`opencode run`）碰到工作目錄**以外**的路徑時，
不會跳出來問你，而是**直接自動拒權**（`auto-reject`）。

若 PLAN.md 或其他檔案引用 vault wiki、另一個專案的路徑等，士兵讀不到。

**修復**：
```bash
# 自動檢查與修復
./scripts/gsd-permission-audit.sh --target ~/Documents/my-project --fix

# 手動修復
# 編輯 .opencode/opencode.json，在 permission.read 和 permission.external_directory 兩處加：
{
  "permission": {
    "read": {
      "/vault/**": "allow"      # ← 加這行
    },
    "external_directory": {
      "/vault/**": "allow"      # ← 也要加這行
    }
  }
}
```

dispatch.sh 派工前會先警告此問題：
```
⚠️ 預檢警告: PLAN.md 引用了工作目錄以外的路徑...
   無頭模式會自動拒權 → 士兵讀不到、空手而回。
   修法: gsd-permission-audit.sh --target ... --fix
```

---

### 🚨 Gotcha 4：OpenCode v1.17.5 `--command + --dir` bug（跨專案必知）

**症狀**：
```
派工到跨專案時收到：
  0 bytes log + "Unexpected server error"
  或 "SessionPrompt.command crash, UnknownError"
```

**根因**：
OpenCode 無頭模式在同時使用 `--command` 和 `--dir` 標誌時會崩潰。
這是 CLI 參數解析器的 bug，非環境或權限問題。

**修復**（已內建於 dispatch.sh）：
```bash
# 本地派工：用 --command（快、清晰）
opencode run --command gsd-execute-phase --dir /local/project 3

# 跨專案派工：改用 prompt 嵌入目標目錄（規避 bug）
opencode run \
  "Run the /gsd-execute-phase command for phase 3. \
   IMPORTANT: The target project is /etf-flow-database ..."
```

**使用者端無感**：dispatch.sh 內部自動選擇正確方式。

---

## 疑難排解

### Q1：派工卡住，怎麼辦？

```bash
# 檢查 1：log 是否還在寫入（不是真的卡住）
tail -f .planning/soldier-logs/phase-3-*.log

# 檢查 2：git 是否有新 commit
git log --oneline -5

# 檢查 3：目標檔案（SUMMARY.md）是否存在
ls -lh .planning/phases/03-*/SUMMARY.md

# 檢查 4：若有 server，session 是否仍活著
curl -s http://localhost:4096/session | jq '.[] | {title, time}'

# 強制中止（如確認真的卡住）
pkill -f "opencode run"
```

### Q2：士兵讀不到外部檔案

```bash
# 自動診斷與修復
./scripts/gsd-permission-audit.sh --target ~/Documents/my-project --fix

# 或手動檢查
cat .opencode/opencode.json | jq '.permission'
```

### Q3：想看詳細 log，但 tail -f 看不清

```bash
# 用 less 分頁（能正確處理 \r）
less -R .planning/soldier-logs/phase-3-*.log

# 或用 xxd 看原始 bytes
xxd .planning/soldier-logs/phase-3-*.log | less
```

### Q4：派工失敗，想重試但不清楚從哪重新開始

```bash
# 檢查目前狀態
ls -lh .planning/phases/03-*/
git log --oneline -10

# 若 PLAN.md 缺失：重跑 plan phase
MODE=plan ./scripts/gsd-dispatch.sh 3

# 若 SUMMARY.md 缺失但 PLAN.md 存在：重跑 execute
./scripts/gsd-dispatch.sh 3 execute

# 若想完全重做這個 phase：刪除現有檔案再派工
rm -rf .planning/phases/03-* 
./scripts/gsd-dispatch.sh 3 execute
```

### Q5：不想用派工腳本，手動執行 gsd 指令行不行？

**可以，但失去以下好處**：
- ❌ 無 log 落地（dispatch 的 `tee` 記錄）
- ❌ 無 liveness 檢查（確認士兵真的完成）
- ❌ 無權限預檢（跨專案會卡）
- ❌ 無驗收摘要（git diff 總結）

**手動方式**（不推薦）：
```bash
# 直接執行 gsd 指令（需要 gsd-core 在 PATH）
gsd-execute-phase 3
gsd-plan-phase 2
/gsd:verify-work 3  # Claude Code 指令
```

---

## 環境變數速查

| 變數 | 用途 | 預設 | 例子 |
|------|------|------|------|
| `MODE` | 派工模式 | `execute` | `research`, `plan`, `execute` |
| `MODEL` | 士兵模型 | `opencode-go/deepseek-v4-flash` | `opencode-go/kimi-k2.6` |
| `VARIANT` | 推理 effort | `high` | `minimal`, `high`, `max` |
| `SERVER_URL` | 共享 server 地址 | 無 | `http://localhost:4096` |
| `TARGET_DIR` | 跨專案派工目標 | `$PROJECT_DIR` | `/path/to/project` |
| `OPENCODE_CONFIG` | .opencode.json 路徑 | `./.opencode/opencode.json` | 自訂路徑 |

---

## 下一步

- ✅ 本地派工已驗證 — [快速開始](#快速開始)
- ⏳ 跨項目派工 — 執行 gsd-permission-audit.sh
- ⏳ ScheduleWakeup 延時派工 — 用 Claude Code 的 ScheduleWakeup 或系統 cron
- 📅 多運行時支持 — 待 OpenCode/Codex/Hermes 實現相應功能

---

**Made with ❤️ for unified dispatch across all GSD runtimes**

v1.0.0 | Production Ready | Claude Code · OpenCode · Codex · Hermes
