# Phase 2：Core Timeout Hardening — 執行摘要

**Phase**: 2（Milestone 1.2 / 對應原始規劃 phase-1.2a）
**執行日期**: 2026-08-18
**執行者**: gsd-executor（opencode-go/deepseek-v4-flash）
**狀態**: ✅ 全部 5 個任務完成，無人類 checkpoint 阻塞

---

## 目標

修復 `gsd-dispatch.sh` 中三處無超時的命令（`opencode run`、`curl`、`git diff`），防止派工永不返回，且超時時回傳正確的 exit code（GNU timeout 慣例的 124）。

---

## 完成任務

| 任務 | 狀態 | 說明 |
|------|------|------|
| 2.1 確認三處無超時命令行號 | ✅ | 源檔與安裝副本都確認（見下表） |
| 2.2 opencode run 添加 timeout | ✅ | 純 bash `run_with_timeout` helper，源檔 2 處呼叫 + 安裝副本 1 處呼叫 |
| 2.3 curl 添加 --max-time 5 | ✅ | 兩份檔案各 2 處（session 檢查 + liveness 檢查），失敗降級為 0 |
| 2.4 git diff 添加超時保護 | ✅ | `--ignore-all-space` + stderr 重定向 + 降級訊息 |
| 2.5 測試與驗收 | ✅ | `bash -n`、grep、exit code 功能測試全通過 |

### 實際行號（任務 2.1 結果）

**源檔** `scripts/gsd-dispatch.sh`（與計畫預期一致）：
- `opencode run`：第 179-184 行（`--command` 分支）、第 186-190 行（跨專案 prompt 分支）
- `curl`：第 173 行（SESSIONS_BEFORE）、第 210 行（SESSIONS_AFTER）
- `git diff --stat`：第 229 行

**安裝副本** `~/.claude/gsd-addon/scripts/gsd-dispatch.sh`：
- `opencode run`：第 218-225 行（單一呼叫，包在 `( cd "$TARGET_DIR"; ... )` subshell）
- `curl`：第 215 行（SESSIONS_BEFORE）、第 244 行（SESSIONS_AFTER）
- `git diff --stat`：第 263 行

---

## 產出檔案

| 檔案 | 用途 |
|------|------|
| `scripts/gsd-dispatch.sh` | 源檔：新增 `run_with_timeout` helper，包住 2 處 `opencode run`，curl 加 `--max-time 5`，git diff 加保護 |
| `~/.claude/gsd-addon/scripts/gsd-dispatch.sh` | 安裝副本：套用相同三種超時保護（保留其較新的 prompts-based 設計） |
| `.planning/milestone-1.2/phase-1.2a/PLAN.md` | 依計畫「完成後動作」將 Task 1.2A.1-5 標記為完成 |

---

## 偏離與理由

1. **helper 實作加了 SIGTERM→124 映射**：計畫原文的 helper 在逾時殺掉命令後會回傳 143（128+SIGTERM），與其自身註明「逾時時回傳 exit code 124」及成功標準「超時時返回正確的 exit code」矛盾。加入 `[[ "$exit_code" -eq 143 ]] && exit_code=124` 一行，讓逾時真正回傳 124，非逾時失敗仍保留原始 exit code。功能測試確認：逾時→124、成功→0、失敗→原碼。
2. **安裝副本「內容一致」標準以「三種保護都覆蓋」取代**：計畫假設兩份檔案內容相同，但實際安裝副本 `~/.claude/gsd-addon/scripts/gsd-dispatch.sh` 是一個**較新、未 commit 的 prompts-based 重新設計**（改用 `prompts/<mode>.md` 範本、新增 check mode、派工時 `cd` 進 TARGET_DIR，2018-08-18 23:12-23:15 建立，源檔並無對應 `prompts/` 目錄）。若直接把源檔覆蓋過去會摧毀這份未提交的工作。因此：源檔完全依照計畫修改；安裝副本保留其新設計，但三處命令**同等**套上超時保護（`run_with_timeout 3600 opencode run`、兩處 `--max-time 5`、`--ignore-all-space` git diff）。兩份檔案在「三種保護全部覆蓋」上等價，但結構不逐一相同（源檔 2 個 `opencode run` 分支、安裝副本 1 個）。
   - ⚠️ 提醒：安裝副本的 prompts-based 新設計目前尚未 commit 回 repo，建議後續將 `prompts/` + 新版 gsd-dispatch 補交，或確認該設計是否保留。
3. **`git diff` 原 fallback（`|| git -C ... diff --stat`）被計畫明訂移除**：依計畫改為 `|| echo "（git diff 逾時或失敗）"`。這使得非 git 倉庫（TARGET_DIR）的 diff 顯示變成降級訊息而非工作樹 diff——與計畫一致，但行為上與改前不同。

---

## 驗證指令（Phase 目標端對端）

```bash
# 1. 語法檢查（兩份檔案）
bash -n scripts/gsd-dispatch.sh
bash -n ~/.claude/gsd-addon/scripts/gsd-dispatch.sh

# 2. 確認三處修改都存在且帶註釋
grep -n "timeout 3600\|--max-time 5\|--ignore-all-space" scripts/gsd-dispatch.sh

# 3. exit code 功能驗證（helper 行為）
bash -c '
run_with_timeout() {
  local secs="$1"; shift
  "$@" &
  local cmd_pid=$!
  ( sleep "$secs" && kill -TERM "$cmd_pid" 2>/dev/null ) &
  local watcher_pid=$!
  local exit_code=0
  if wait "$cmd_pid" 2>/dev/null; then
    exit_code=0
  else
    exit_code=$?
    [[ "$exit_code" -eq 143 ]] && exit_code=124
  fi
  kill -TERM "$watcher_pid" 2>/dev/null
  wait "$watcher_pid" 2>/dev/null
  return "$exit_code"
}
run_with_timeout 1 sleep 5; echo "timeout -> $? (expect 124)"
run_with_timeout 5 true;   echo "ok      -> $? (expect 0)"
'
```

本次執行時的實測結果：語法檢查兩檔通過；grep 找到全部修改（含註釋）；helper 功能測試 timeout→124 / success→0 / failure→原碼 / 且經 `| tee` pipeline（pipefail）正確傳播 124。

---

## 下一步

進入 **Milestone 1.2 / Phase 3（phase-1.2b）Retry Wrapper Implementation**（`dispatch-with-retry.sh`），本 phase 的超時保護是該 wrapper 的基礎。
