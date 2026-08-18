# Schedule Wakeup & 動態編排 — 跨運行時指南

**目標**：無論是 Claude Code、OpenCode、Codex 還是 Hermes，都能支援延時派工和動態編排

---

## 📋 概述

### 什麼是動態編排？

派工不是一成不變的「現在執行」，而是根據需求**動態調整執行時機**：

| 場景 | 方式 | 用途 |
|------|------|------|
| **立即派工** | `./scripts/gsd-dispatch.sh 3` | 現在就要結果 |
| **背景派工** | `nohup ./scripts/gsd-dispatch.sh 3 &` | 派工後立即回到軍師 |
| **延時派工** | `ScheduleWakeup` / `cron` | 凌晨派工省成本 |
| **條件派工** | phase 2 失敗時重試 | 自動恢復 |
| **平行派工** | 多個無依賴 phase 同時執行 | 加速 |

### 運行時的差異

不同運行時對動態編排的支持程度不同，但 **gsd-addon 的腳本設計已預留擴展空間**：

| 功能 | Claude Code | OpenCode | Codex | Hermes |
|------|---|---|---|---|
| **立即派工** | ✅ | ✅ | ✅ | ✅ |
| **背景派工** | ✅ | ✅ | ✅ | ✅ |
| **ScheduleWakeup** | ✅ 原生 | ⏳ 規劃 | ⏳ 規劃 | ⏳ 規劃 |
| **系統 cron** | ✅ | ✅ | ✅ | ✅ |
| **條件派工** | ✅ 腳本可實現 | ✅ | ✅ | ✅ |
| **平行派工** | ✅ | ✅ | ✅ | ✅ |

---

## 🚀 Claude Code（當前）

### 1. 立即派工（阻斷式）

```bash
# 執行並等待結果
./scripts/gsd-dispatch.sh 3 execute

# 檢查結果
ls .planning/phases/03-*/SUMMARY.md
```

**特點**：
- ✅ 簡單直接
- ✅ 實時回饋
- ❌ 長 phase 會阻斷 Claude 輸入

---

### 2. 背景派工（非阻斷）

```bash
# 派工到背景
nohup ./scripts/gsd-dispatch.sh 3 execute > /tmp/phase3.log 2>&1 &
JOB_PID=$!
echo "派工已啟動，PID: $JOB_PID"

# 軍師繼續下一個 phase
/gsd:plan-phase 4

# 稍後檢查結果
wait $JOB_PID
echo "Phase 3 完成"
```

**特點**：
- ✅ 派工後立即返回
- ✅ 軍師可同時工作
- ⚠️ 需要手動 wait，否則不知道何時完成

---

### 3. 延時派工（ScheduleWakeup）— Claude Code 特有

**核心能力**：Claude Code 提供 `ScheduleWakeup` 工具，支援延時執行任意命令

#### 用法 A：直接延時

```bash
ScheduleWakeup({
  delaySeconds: 3600,                    # 1 小時後
  prompt: "cd ~/Documents/my-project && ./scripts/gsd-dispatch.sh 3 execute",
  reason: "Dispatch phase 3 execution after 1 hour"
})
```

Claude 會在 1 小時後自動重新喚醒並執行派工。

#### 用法 B：凌晨派工（省成本）

```bash
# 計算到凌晨 2 點的秒數
import time
from datetime import datetime, timedelta

now = datetime.now()
next_2am = (now + timedelta(days=1)).replace(hour=2, minute=0, second=0)
delay = int((next_2am - now).total_seconds())

ScheduleWakeup({
  delaySeconds: delay,
  prompt: "cd ~/Documents/my-project && VARIANT=minimal ./scripts/gsd-dispatch.sh 5 execute",
  reason: f"Cost-optimized dispatch at 2 AM (delay: {delay}s)"
})
```

#### 用法 C：多階段自動派工鏈

```bash
# Phase 2 完成後自動派工 Phase 3

ScheduleWakeup({
  delaySeconds: 300,  # 5 分鐘後檢查
  prompt: """
    if [ -f .planning/phases/02-*/SUMMARY.md ]; then
      ./scripts/gsd-dispatch.sh 3 execute
    else
      echo "Phase 2 still running"
    fi
  """,
  reason: "Check phase 2 completion and dispatch phase 3"
})
```

**特點**：
- ✅ 完全自動化
- ✅ 支援複雜邏輯
- ✅ 無需人工介入
- ✅ 凌晨派工省成本

---

### 4. 條件派工（根據上階段結果）

```bash
# Phase 2 失敗時自動重試

ScheduleWakeup({
  delaySeconds: 60,
  prompt: """
    # 檢查 phase 2 是否成功
    if grep -q "FAILED\|ERROR" .planning/soldier-logs/phase-2-*.log; then
      echo "Phase 2 failed, retrying with higher effort..."
      VARIANT=max ./scripts/gsd-dispatch.sh 2 execute
    else
      echo "Phase 2 succeeded, proceeding to phase 3"
      ./scripts/gsd-dispatch.sh 3 execute
    fi
  """,
  reason: "Conditional retry: Phase 2 if failed, else Phase 3"
})
```

---

### 5. 平行派工（無依賴 phase）

```bash
# Wave 結構中的獨立 phase 平行派工

import subprocess
import time

phases = [6.2, 6.4, 6.6]  # 假設這三個 phase 無依賴

# 啟動所有派工
jobs = []
for phase in phases:
  proc = subprocess.Popen(
    f"./scripts/gsd-dispatch.sh {phase} execute",
    shell=True,
    cwd="/Users/user/Documents/my-project"
  )
  jobs.append((phase, proc))
  print(f"Started phase {phase}, PID {proc.pid}")

# 等待全部完成
for phase, proc in jobs:
  proc.wait()
  print(f"Phase {phase} completed")

print("✅ All phases done")
```

---

## 🔄 OpenCode（規劃中的支持）

### 現狀
派工腳本已完全支援 OpenCode，但**延時派工**仍需通過系統級方案（cron）

### 未來規劃

**目標**：OpenCode 實現類似 Claude Code 的 ScheduleWakeup 工具

#### 預期 API（設計草案）

```bash
# 方案 A：擴展 opencode 命令
opencode schedule --delay 3600 --command "cd ~/project && ./scripts/gsd-dispatch.sh 3"

# 方案 B：通過 MCP（Model Context Protocol）
opencode mcp schedule.wakeup {
  "delaySeconds": 3600,
  "action": "shell",
  "command": "./scripts/gsd-dispatch.sh 3"
}
```

#### 臨時方案（當前可用）

```bash
# 使用系統 cron（通用，所有運行時都支援）
crontab -e

# 加入（每日凌晨 2 點派工）
0 2 * * * cd /Users/user/Documents/my-project && \
          ./scripts/gsd-dispatch.sh 3 execute >> .planning/soldier-logs/cron.log 2>&1
```

---

## 🛠️ Codex（規劃中）

### 預期設計

Codex 是 Anthropic 的代碼助手（未正式發佈），預期設計如下：

```python
# codex/dispatch.py（設計假設）

from codex import Agent, Schedule

class GSDDispatcher(Agent):
    def dispatch_phase(self, phase, mode="execute", model="gpt-4"):
        """派工單個 phase"""
        return self.run(f"./scripts/gsd-dispatch.sh {phase} {mode}")
    
    def schedule_dispatch(self, phase, delay_seconds, mode="execute"):
        """延時派工"""
        return Schedule.delay(
            delay_seconds=delay_seconds,
            callback=lambda: self.dispatch_phase(phase, mode)
        )

# 使用
dispatcher = GSDDispatcher(project_dir="/path/to/project")
dispatcher.schedule_dispatch(phase=3, delay_seconds=3600)
```

### 預期特性
- 原生支援延時派工
- 整合代碼執行環境
- 實時監看 log
- 自動重試機制

---

## ⚙️ Hermes（規劃中）

### 預期設計

Hermes 是 Anthropic 內部使用的編排系統，預期設計如下：

```bash
# hermes CLI（設計假設）

# 基本派工
hermes task execute \
  --project /Users/user/Documents/my-project \
  --command "./scripts/gsd-dispatch.sh 3"

# 延時派工
hermes schedule after-delay \
  --delay 3600 \
  --project /Users/user/Documents/my-project \
  --command "./scripts/gsd-dispatch.sh 3"

# 條件派工
hermes workflow create --name "phase-2-to-3" \
  --condition "file_exists(.planning/phases/02-*/SUMMARY.md)" \
  --on-true "./scripts/gsd-dispatch.sh 3 execute" \
  --on-false "./scripts/gsd-dispatch.sh 2 execute --retry"

# Cron 派工
hermes schedule cron \
  --pattern "0 2 * * *" \
  --project /Users/user/Documents/my-project \
  --command "./scripts/gsd-dispatch.sh 3 execute"
```

### 預期特性
- 完整工作流編排
- 複雜條件邏輯
- 分佈式執行
- 實時監控面板

---

## 📦 通用方案：系統 cron

**適用於所有運行時**，無需特殊支持

### 基本用法

```bash
# 編輯 crontab
crontab -e

# 常見派工模式
# 每日凌晨 2 點派工（省成本）
0 2 * * * cd ~/Documents/my-project && ./scripts/gsd-dispatch.sh 3 >> .planning/soldier-logs/cron.log 2>&1

# 每 6 小時派工一次
0 */6 * * * cd ~/Documents/my-project && ./scripts/gsd-dispatch.sh 4 execute >> .planning/soldier-logs/cron.log 2>&1

# 工作日晚上 6 點派工（下班後自動執行）
0 18 * * 1-5 cd ~/Documents/my-project && ./scripts/gsd-dispatch.sh 5 >> .planning/soldier-logs/cron.log 2>&1
```

### 優點
- ✅ 通用，所有 Unix 系統都支援
- ✅ 可靠，由 OS 管理
- ✅ 低開銷

### 缺點
- ❌ 不支援複雜邏輯（條件、重試）
- ❌ 需要手動配置
- ❌ 無原生監控

---

## 🎯 選擇派工方式的決策表

| 場景 | 推薦方式 | 原因 |
|------|---------|------|
| 現在就要結果 | 立即派工 | 同步，實時回饋 |
| 派工後做其他事 | 背景派工 | `nohup ... &` |
| 凌晨派工省成本 | ScheduleWakeup / cron | 自動化，無人工干預 |
| 多個無依賴 phase | 平行派工 | 加速完成 |
| Phase N 失敗時重試 | 條件派工 | 自動恢復 |
| 跨多個 phase 的複雜流程 | Hermes / Codex | 工作流引擎 |

---

## 🔧 實現細節：腳本設計

gsd-addon 的派工腳本已為**多運行時支持**預留設計空間：

### 當前設計（bash）

```bash
# scripts/gsd-dispatch.sh（通用）
# 可被任何運行時呼叫，無需改動

./scripts/gsd-dispatch.sh <phase> [model]
  ↓
gsd-execute-phase / gsd-plan-phase / gsd-research-phase
  ↓
.planning/soldier-logs/phase-*.log
  ↓
SUMMARY.md / PLAN.md / RESEARCH.md
```

### 未來擴展點

```
scripts/
├── gsd-dispatch.sh              # 當前：通用 bash
├── dispatch/
│   ├── claude-code/dispatch.py  # 未來：Claude Code 特定（ScheduleWakeup 集成）
│   ├── opencode/dispatch.js     # 未來：OpenCode 特定
│   ├── codex/dispatch.py        # 未來：Codex 特定
│   └── hermes/dispatch.cjs      # 未來：Hermes 特定
└── schedule-wakeup/
    ├── claude-code.sh           # ScheduleWakeup 編排
    ├── opencode.sh              # 待實現
    └── system-cron.sh           # 系統 cron 備選
```

### 運行時偵測

```bash
# 未來的 gsd-dispatch.sh 可偵測運行時並選擇最佳實現
RUNTIME=$(detect_runtime)  # claude-code / opencode / codex / hermes / unknown

if [[ "$RUNTIME" == "claude-code" ]]; then
  # 用 ScheduleWakeup
  dispatch_via_schedule_wakeup
elif [[ "$RUNTIME" == "opencode" ]]; then
  # 用 OpenCode 的 API（當實現時）
  dispatch_via_opencode
else
  # 回退到通用 bash
  dispatch_via_bash
fi
```

---

## 🎓 最佳實踐

### 1. 保持派工腳本獨立

```bash
# ✅ 好：派工腳本無需知道調用者是誰
./scripts/gsd-dispatch.sh 3

# ❌ 不好：在腳本內寫 Claude Code 特定邏輯
if [ "$RUNTIME" == "claude-code" ]; then
  ScheduleWakeup(...)
fi
```

### 2. 使用環境變數做配置

```bash
# ✅ 好：所有配置通過環境變數
MODE=plan VARIANT=high ./scripts/gsd-dispatch.sh 2

# ❌ 不好：寫死在腳本或配置檔
MODE="plan"  # 在腳本中硬編碼
```

### 3. 分離派工與編排邏輯

```bash
# 派工層（scripts/gsd-dispatch.sh）
  → 職責：執行 phase、收集結果、落地 log

# 編排層（ScheduleWakeup / cron / Hermes workflow）
  → 職責：決定何時派工、處理失敗、協調多個 phase

# ✅ 好的分層使不同運行時可各自實現編排層
# ❌ 混合會導致運行時鎖定
```

---

## 📞 支持與反饋

| 話題 | 資源 |
|------|------|
| 派工失敗 | 見 [DISPATCH-COMPLETE-GUIDE.md](./dispatch/DISPATCH-COMPLETE-GUIDE.md) 的「疑難排解」|
| ScheduleWakeup 用法 | Claude Code 文檔 |
| cron 配置 | `man crontab` 或 crontab.guru |
| 未來運行時支持 | 提交 Issue 或參與貢獻 |

---

**跨運行時的統一派工與編排系統**

v1.0.0 | Claude Code Ready | OpenCode/Codex/Hermes Compatible
