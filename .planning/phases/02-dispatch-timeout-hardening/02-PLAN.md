---
phase: 2
name: "Core Timeout Hardening"
milestone: "1.2"
status: "Ready"
timeline: "2026-08-19"
---

# Phase 2：Core Timeout Hardening（對應 Milestone 1.2 / Phase 1.2A）

**目標**: 修復 `gsd-dispatch.sh` 中無超時的三處命令，防止派工永不返回的情況。

**成功標準**:
- [ ] `opencode run` 添加 `timeout 3600`
- [ ] `curl` 添加 `--max-time 5`
- [ ] `git diff` 添加超時保護
- [ ] bash 語法檢查通過
- [ ] 每個 timeout 都有註釋說明
- [ ] 超時時返回正確的 exit code

**責任人**: OpenCode (opencode-go/deepseek-v4-flash)
**預期時間**: 2 小時

---

## 背景

`gsd-dispatch.sh` 派工 OpenCode 時曾遇到伺服器暫時性錯誤（UnknownError err_13bbe49a），排查過程中發現腳本中有三處命令完全沒有 timeout 保護，一旦卡住會導致腳本永不返回 exit code，連帶使未來的重試 wrapper（Milestone 1.2 Phase 1.2B）失效。

修改對象文件：
- 源: `/Users/bryan/Documents/gsd-addon/scripts/gsd-dispatch.sh`
- 安裝副本: `~/.claude/gsd-addon/scripts/gsd-dispatch.sh`（兩處都要修改並保持一致）

---

## 任務分解

### 任務 2.1：確認三處無超時命令的實際行號

**動作**:
- 開啟 `scripts/gsd-dispatch.sh`
- 確認 `opencode run` 呼叫位置（原研究記錄約在第 179-190 行）
- 確認 `curl` 呼叫位置（原研究記錄約在第 173 行與第 210 行）
- 確認 `git diff` 呼叫位置（原研究記錄約在第 229-240 行）

**驗收標準**: 三處實際行號已確認（可能因後續修改而與原記錄略有偏差，以實際檔案內容為準）

---

### 任務 2.2：為 opencode run 添加 timeout(純 bash 實現，無外部依賴)

**重要環境發現**: macOS 預設不帶 GNU `timeout`(也沒有透過 coreutils 安裝的 `gtimeout`)。gsd-addon 是要給其他人直接 `git clone` 使用的開源專案，不能假設使用者機器裝了 coreutils。因此不用 `timeout` 指令，改用純 bash 背景行程 + kill 實現的 helper function，任何有 bash 的環境都能跑。

**額外發現**: `opencode run` 實際上有**兩處**呼叫(第 178-184 行 `--command` 分支、第 186-190 行跨專案 prompt 分支，見 `TARGET_DIR != PROJECT_DIR` 判斷),兩處都要加保護。

**新增 helper function**(加在腳本前段、`set -euo pipefail` 之後):
```bash
# 純 bash 逾時保護(無外部依賴，相容任何 bash 3.2+ 環境)
# 用法: run_with_timeout <秒數> <command...>
# 逾時時回傳 exit code 124(與 GNU timeout 慣例一致)
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
  fi
  kill -TERM "$watcher_pid" 2>/dev/null
  wait "$watcher_pid" 2>/dev/null
  return "$exit_code"
}
```

**修改前**（兩處呼叫）:
```bash
if [[ "$TARGET_DIR" == "$PROJECT_DIR" ]]; then
  opencode run \
    --command "$GSD_COMMAND" \
    -m "$MODEL" \
    ${VARIANT:+--variant "$VARIANT"} \
    ${SERVER_URL:+--attach "$SERVER_URL"} \
    "$PHASE" 2>&1 | tee "$LOG_FILE"
else
  opencode run \
    -m "$MODEL" \
    ${VARIANT:+--variant "$VARIANT"} \
    ${SERVER_URL:+--attach "$SERVER_URL"} \
    "Run the /$GSD_COMMAND command for phase $PHASE. IMPORTANT: The target project directory is $TARGET_DIR — all file reads, writes, and git operations must target that directory, not the current working directory." 2>&1 | tee "$LOG_FILE"
fi
```

**修改後**:
```bash
# Timeout: 3600s(1 小時)避免伺服器無回應導致腳本永不返回，逾時回傳 exit code 124
if [[ "$TARGET_DIR" == "$PROJECT_DIR" ]]; then
  run_with_timeout 3600 opencode run \
    --command "$GSD_COMMAND" \
    -m "$MODEL" \
    ${VARIANT:+--variant "$VARIANT"} \
    ${SERVER_URL:+--attach "$SERVER_URL"} \
    "$PHASE" 2>&1 | tee "$LOG_FILE"
else
  run_with_timeout 3600 opencode run \
    -m "$MODEL" \
    ${VARIANT:+--variant "$VARIANT"} \
    ${SERVER_URL:+--attach "$SERVER_URL"} \
    "Run the /$GSD_COMMAND command for phase $PHASE. IMPORTANT: The target project directory is $TARGET_DIR — all file reads, writes, and git operations must target that directory, not the current working directory." 2>&1 | tee "$LOG_FILE"
fi
```

**驗收標準**:
- `run_with_timeout` helper function 已加在腳本前段
- 兩處 `opencode run` 呼叫都已改用 `run_with_timeout 3600 opencode run ...`
- 未使用 `timeout` 或 `gtimeout` 外部指令(零依賴)
- 有註釋說明原因

---

### 任務 2.3：為 curl 添加 --max-time

**範圍**: session 檢查與 liveness 檢查，共兩處 curl 呼叫

**修改前**:
```bash
curl -s "$SERVER_URL/session" | python3 ...
```

**修改後**:
```bash
# --max-time 5: 避免 SERVER_URL 無回應導致腳本卡住；失敗時降級為 0
curl -s --max-time 5 "$SERVER_URL/session" 2>/dev/null | python3 ... || echo 0
```

**驗收標準**: 兩處 curl 都已加上 `--max-time 5`、stderr 重定向、失敗降級值，並有註釋說明

---

### 任務 2.4：為 git diff 添加超時保護

**修改前**:
```bash
git -C "$TARGET_DIR" diff --stat "${GIT_BEFORE}" HEAD
```

**修改後**:
```bash
# --ignore-all-space 加速大型 diff；失敗時顯示降級訊息而非卡住
git -C "$TARGET_DIR" diff --stat --ignore-all-space "${GIT_BEFORE}" HEAD 2>/dev/null || echo "（git diff 逾時或失敗）"
```

**驗收標準**: git diff 已加上上述選項與降級行為，並有註釋說明

---

### 任務 2.5：測試與驗收

**動作**:
1. 語法檢查：`bash -n scripts/gsd-dispatch.sh`（源檔案與安裝副本都要檢查）
2. 邏輯確認：`grep -n "timeout 3600\|--max-time 5\|--ignore-all-space" scripts/gsd-dispatch.sh`，應找到全部三處修改
3. 確保 `~/.claude/gsd-addon/scripts/gsd-dispatch.sh` 與源檔案內容一致（或透過 install.sh 重新安裝同步）

**驗收標準**:
- `bash -n` 兩個檔案皆無錯誤
- grep 能找到三處修改且各自帶有註釋
- 兩份檔案（源 + 安裝副本）內容一致

---

## 完成後動作

完成本 Phase 後：
1. 產出 `02-1-SUMMARY.md`（gsd-executor 標準輸出）
2. 更新 `.planning/milestone-1.2/phase-1.2a/PLAN.md` 標記對應任務為完成（原規劃文檔，供参考）
3. 準備進入 Milestone 1.2 / Phase 1.2B（Retry Wrapper Implementation，對應正式 Phase 3）
