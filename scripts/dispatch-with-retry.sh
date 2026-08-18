#!/usr/bin/env bash
#
# dispatch-with-retry.sh — 派工重試 wrapper(外層包裝)
#
# gsd-dispatch.sh 的智能重試外殼:當派工失敗時,依錯誤分類決定是否重試。
# 不改動 gsd-dispatch.sh 核心邏輯,只在外面包一層重試迴圈。
# 透過 `RETRY=true gsd-dispatch <phase>` 啟用(見 ~/.local/bin/gsd-dispatch)。
#
# 用法:
#   RETRY=true gsd-dispatch <phase> [model]
#   或直接: ./scripts/dispatch-with-retry.sh <phase> [model]
#
# 重試策略:
#   - MAX_RETRIES=3(最多 3 次嘗試,含第一次;可用環境變數覆蓋)
#   - 指數退避:attempt 1→2→3 之間延遲 1s / 2s(delay = 2 ** (attempt-1))
#   - MODE / MODEL / VARIANT / TARGET_DIR / SERVER_URL 等環境變數原樣透傳
#
# 錯誤分類(exit code + 最新 log 檔案內容,log 路徑與 gsd-dispatch.sh 一致):
#   不重試(直接退出):
#     - 參數/配置錯誤:無 log(用法、VARIANT/MODE 非法、prompt 範本缺失、TARGET_DIR 無效)
#     - 權限錯誤:log 含 "permission denied"
#     - 使用者中斷:exit 130(SIGINT) / 143(SIGTERM)
#   重試:
#     - 逾時:exit 124(run_with_timeout 的逾時約定)
#     - OpenCode 伺服器錯誤:log 含 "err_" 或 "Unexpected server error"
#     - 網路失敗:log 含 "curl failed" / "network"
#     - 其他任何已開始派工後的失敗(有 log 但無上述不可重試關鍵字)
#
# 信號處理:Ctrl+C(SIGINT)/ SIGTERM → _cleanup + exit 130,立即退出,不重試。
#
# 每次失敗都會記錄 attempt 編號、delay、exit code 到 stdout + 最新 log 檔。
#
set -euo pipefail

MAX_RETRIES="${MAX_RETRIES:-3}"
INITIAL_DELAY="${INITIAL_DELAY:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH_SCRIPT="${SCRIPT_DIR}/gsd-dispatch.sh"
# 與 gsd-dispatch.sh 相同的 PROJECT_DIR / LOG_DIR 推算方式,
# 這樣才能讀到它剛寫下的派工 log。
PROJECT_DIR="$(cd "$(dirname "${DISPATCH_SCRIPT}")/.." && pwd)"
LOG_DIR="${PROJECT_DIR}/.planning/soldier-logs"

PHASE="${1:-}"

# ---- 錯誤分類:不可重試回傳 0,可重試回傳 1 ----
# 只信任「最近 15 分鐘內」的 log,避免誤讀舊 session 的殘留檔案。
_is_non_retryable() {
  local rc="$1"
  local logfile

  # 使用者中斷(130/143)一律不重試
  if [[ "$rc" -eq 130 || "$rc" -eq 143 ]]; then
    return 0
  fi
  # 逾時(124)明確歸類為可重試
  if [[ "$rc" -eq 124 ]]; then
    return 1
  fi

  logfile="$(find "$LOG_DIR" -maxdepth 1 -type f -name "phase-${PHASE}-*.log" -mmin -15 2>/dev/null | sort | tail -1)"
  if [[ -z "$logfile" ]]; then
    # 沒有 log = 派工根本沒開始(參數/配置錯誤),重試沒有意義
    return 0
  fi
  # log 含參數錯誤或權限錯誤關鍵字 → 不重試
  if grep -Eq 'permission denied|✗ MODE 必須是|✗ VARIANT 必須是|✗ 找不到 prompt 範本|✗ FAIL: TARGET_DIR not found|用法:' "$logfile"; then
    return 0
  fi
  # 其餘(含 err_xxxxxxxx 伺服器錯誤、curl failed、network)→ 重試
  return 1
}

_latest_log() {
  find "$LOG_DIR" -maxdepth 1 -type f -name "phase-${PHASE}-*.log" -mmin -15 2>/dev/null | sort | tail -1
}

_cleanup() { : ; }
trap '_cleanup; exit 130' INT TERM

echo "[retry] dispatch-with-retry.sh engaged (max ${MAX_RETRIES} attempts, retry delay 2**(n-1)s)"

attempt=1
rc=1
while [ "$attempt" -le "$MAX_RETRIES" ]; do
  # 捕捉 exit code 而不讓 set -e 中止迴圈
  "$DISPATCH_SCRIPT" "$@" && rc=0 || rc=$?
  [ "$rc" -eq 0 ] && exit 0

  logfile=""
  logfile="$(_latest_log)"

  if _is_non_retryable "$rc"; then
    echo "[retry] attempt $attempt/$MAX_RETRIES failed (exit $rc) — non-retryable error, aborting." >&2
    [ -n "$logfile" ] && echo "[retry] attempt $attempt/$MAX_RETRIES failed (exit $rc) — non-retryable, aborted." >> "$logfile" 2>/dev/null || true
    exit "$rc"
  fi

  [ "$attempt" -ge "$MAX_RETRIES" ] && break

  delay=""
  delay=$(( INITIAL_DELAY * (2 ** (attempt - 1)) ))
  echo "[retry] attempt $attempt/$MAX_RETRIES failed (exit $rc). Retrying in ${delay}s..." >&2
  [ -n "$logfile" ] && echo "[retry] attempt $attempt/$MAX_RETRIES failed (exit $rc). Retrying in ${delay}s..." >> "$logfile" 2>/dev/null || true
  sleep "$delay"
  attempt=$(( attempt + 1 ))
done

echo "[retry] All $MAX_RETRIES attempts failed (last exit $rc)." >&2
[ -n "$logfile" ] && echo "[retry] All $MAX_RETRIES attempts failed (last exit $rc)." >> "$logfile" 2>/dev/null || true
exit "$rc"
