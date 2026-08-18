---
phase: 4
name: "Retry Wrapper Implementation"
milestone: "1.2"
status: "Ready"
timeline: "2026-08-19"
---

# Phase 4：Retry Wrapper Implementation

**目標**: 創建 `dispatch-with-retry.sh` wrapper，具備智能重試、錯誤分類和優雅的環境變數集成，
使用者可透過 `RETRY=true gsd-dispatch <phase>` 語法啟用重試機制。

**成功標準**:
- [ ] `scripts/dispatch-with-retry.sh` 創建成功（3 次重試，指數退避）
- [ ] 正確區分三類錯誤：參數錯誤（不重試）、權限錯誤（不重試）、派工失敗（重試）
- [ ] `~/.local/bin/gsd-dispatch` 支持 `RETRY=true` 環境變數切換
- [ ] `install.sh` 自動複製 `dispatch-with-retry.sh` 到安裝位置
- [ ] `bash -n` 語法檢查通過
- [ ] 信號處理（Ctrl+C 立即退出，不重試）

**責任人**: Claude Code（可用 gsd-dispatch 或 Sonnet inline 執行）
**前置依賴**: Phase 3 完成（兩份 gsd-dispatch.sh 已一致）✅
**預期時間**: 2-3 小時

---

## 背景

Phase 3 完成後，source repo 與已安裝副本的 `gsd-dispatch.sh` 已完全一致，
且 8 項 code review bug 已修復（CR-01/02/03 + WR-01-05）。現在可以放心在
一份腳本基礎上實作 retry wrapper。

Wrapper 採用**外層包裝**模式：不修改 `gsd-dispatch.sh` 核心邏輯，
而是在外部建立 `dispatch-with-retry.sh` 腳本，讓 `~/.local/bin/gsd-dispatch`
根據 `RETRY` 環境變數決定呼叫哪個腳本。

---

## 任務分解

### 任務 4.1：設計重試邏輯與錯誤分類規則

**動作**:
1. 確定重試公式：`delay = 2 ** (attempt - 1)` 秒（attempt 1→2→3 對應延遲 1s/2s/4s）
2. 確定錯誤分類（基於日誌檔案內容）：
   - **不重試**：參數錯誤（usage/arg error）、權限錯誤（permission denied）
   - **重試**：OpenCode 伺服器錯誤（err_xxxxxxxx）、超時（exit 124）、網路失敗（curl failed）
3. 確定信號處理：`trap 'cleanup; exit 130' INT TERM`
4. 確定日誌記錄格式（每次重試都要記錄 attempt 編號、delay、exit code）

**驗收標準**: 分類規則文字化（可記錄在 SUMMARY.md），邏輯清晰

---

### 任務 4.2：創建 dispatch-with-retry.sh

**動作**:
在 `scripts/dispatch-with-retry.sh` 建立 wrapper 腳本：

```bash
#!/usr/bin/env bash
set -euo pipefail

MAX_RETRIES=3
INITIAL_DELAY=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH_SCRIPT="${SCRIPT_DIR}/gsd-dispatch.sh"

_cleanup() { : ; }
trap '_cleanup; exit 130' INT TERM

attempt=1
while [ $attempt -le $MAX_RETRIES ]; do
  # 呼叫 gsd-dispatch.sh，捕捉 exit code
  "$DISPATCH_SCRIPT" "$@"
  rc=$?

  [ $rc -eq 0 ] && exit 0

  # 錯誤分類：不可重試的立即退出
  # （讀最新的 log 檔案判斷）
  if _is_non_retryable "$rc"; then
    exit $rc
  fi

  [ $attempt -ge $MAX_RETRIES ] && break

  delay=$(( INITIAL_DELAY * (2 ** (attempt - 1)) ))
  echo "[retry] attempt $attempt/$MAX_RETRIES failed (exit $rc). Retrying in ${delay}s..."
  sleep $delay
  attempt=$(( attempt + 1 ))
done

echo "[retry] All $MAX_RETRIES attempts failed."
exit $rc
```

- `_is_non_retryable()` 讀取最新 log 檔案內容判斷是否含參數錯誤或權限錯誤關鍵字

**驗收標準**: `bash -n scripts/dispatch-with-retry.sh` 通過；可手動觸發測試

---

### 任務 4.3：修改 ~/.local/bin/gsd-dispatch 支持 RETRY 環境變數

**動作**:
修改 `~/.local/bin/gsd-dispatch`（全域命令）：

```bash
#!/bin/bash
export GSD_ADDON_HOME="${GSD_ADDON_HOME:-$HOME/.claude/gsd-addon}"
RETRY="${RETRY:-false}"

if [[ "$RETRY" == "true" ]]; then
  exec "$GSD_ADDON_HOME/scripts/dispatch-with-retry.sh" "$@"
else
  exec "$GSD_ADDON_HOME/scripts/gsd-dispatch.sh" "$@"
fi
```

注意：`install.sh` 負責生成這個全域命令，所以也要更新 install.sh 中生成 gsd-dispatch 的邏輯。

**驗收標準**: `RETRY=true gsd-dispatch 4` 和 `gsd-dispatch 4` 都能正確路由

---

### 任務 4.4：更新 install.sh 以複製 dispatch-with-retry.sh

**動作**:
1. 在 `install.sh` 中加入複製邏輯：
   ```bash
   cp scripts/dispatch-with-retry.sh "$GSD_ADDON_HOME/scripts/"
   chmod +x "$GSD_ADDON_HOME/scripts/dispatch-with-retry.sh"
   ```
2. 更新 `~/.local/bin/gsd-dispatch` 生成邏輯以包含 RETRY 分支
3. 確認 install.sh 執行後安裝狀態正確

**驗收標準**: `bash install.sh` 執行成功，安裝後 `RETRY=true gsd-dispatch --help` 不報錯

---

### 任務 4.5：Smoke Test

**動作**:
1. `bash -n scripts/dispatch-with-retry.sh` — 語法檢查
2. 手動測試 RETRY=false（默認）路由：`gsd-dispatch 4` 直接呼叫 gsd-dispatch.sh
3. 手動測試 RETRY=true 路由：`RETRY=true gsd-dispatch 4` 呼叫 dispatch-with-retry.sh
4. 確認 Ctrl+C 能立即退出（不觸發重試）

**驗收標準**: 以上測試全部通過，exit code 正確

---

## 完成後動作

1. 產出 `04-SUMMARY.md`
2. 更新 `.planning/STATE.md`
3. 準備進入 Phase 5（Integration & Testing）
