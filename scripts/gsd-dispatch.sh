#!/usr/bin/env bash
#
# gsd-dispatch.sh — 軍師士兵派工腳本
#
# 軍師(Claude Code)跑完 /gsd:plan-phase N 產出 PLAN.md 後,
# 用這個腳本把「執行」轉嫁給士兵(OpenCode + 便宜模型),
# 軍師最後只讀 SUMMARY.md + git diff 驗收,省下大量 token。
#
# 用法:
#   ./scripts/gsd-dispatch.sh <phase>                        # 預設 execute + opencode-go effort high
#   ./scripts/gsd-dispatch.sh <phase> <model>                # 指定模型
#   MODE=research ./scripts/gsd-dispatch.sh 8                # 切換 research mode
#   MODE=plan ./scripts/gsd-dispatch.sh 2                    # 切換 plan mode(gsd-plan-phase)
#   MODEL="opencode-go/kimi-k2.6" ./scripts/gsd-dispatch.sh 6.3
#   VARIANT=minimal ./scripts/gsd-dispatch.sh 7              # 改成 effort minimal(便宜模式)
#
# 環境變數:
#   MODE     派工模式:research | plan | execute(預設 execute)
#   MODEL    士兵模型(預設 opencode-go/deepseek-v4-flash)
#   VARIANT  reasoning effort:high / max / minimal(預設 high)
#   SERVER_URL  共享 server URL(設了就 attach)
#   TARGET_DIR  跨專案派工的目標專案(預設=PROJECT_DIR)
#
# 範例:
#   ./scripts/gsd-dispatch.sh 7
#   MODE=research ./scripts/gsd-dispatch.sh 8
#   MODE=plan ./scripts/gsd-dispatch.sh 2
#   ./scripts/gsd-dispatch.sh 6.3 opencode/kimi-k2.6
#   SERVER_URL=http://localhost:4096 TARGET_DIR=/etf-project ./scripts/gsd-dispatch.sh 8
#
# 注意:MODE=plan 一次只會產出「下一份」缺的 PLAN.md(gsd-plan-phase 的標準行為
# 是規劃整個 phase 的所有 plan)。若某個 phase 已經有部分 PLAN.md 在磁碟上
# (例如前一次派工中途失敗),gsd-plan-phase 會偵測已存在的 plan 並接著補完,
# 不會重新覆寫。跨專案派工(TARGET_DIR != PROJECT_DIR)尚未針對 plan mode 測試過。
#
set -euo pipefail

# ---- 參數 ----
PHASE="${1:-}"
MODEL="${2:-${MODEL:-opencode-go/deepseek-v4-flash}}"
VARIANT="${VARIANT:-high}"
MODE="${MODE:-execute}"  # research | plan | execute
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# 跨專案派工:被執行 phase 的目標專案(預設=派工方自己=vault)
TARGET_DIR="${TARGET_DIR:-$PROJECT_DIR}"
# 共享 server:設了就 attach,session 對使用者 TUI 可見(脫離 cwd 分群)
SERVER_URL="${SERVER_URL:-}"
LOG_DIR="${PROJECT_DIR}/.planning/soldier-logs"
LOG_FILE="${LOG_DIR}/phase-${PHASE}-$(date +%Y%m%d-%H%M%S).log"

# 選擇指令
case "$MODE" in
  research)  GSD_COMMAND="gsd-research-phase" ;;
  plan)      GSD_COMMAND="gsd-plan-phase" ;;
  execute)   GSD_COMMAND="gsd-execute-phase" ;;
  *)
    echo "✗ MODE 必須是 research、plan 或 execute,得到: $MODE"
    exit 1
    ;;
esac

if [[ -z "$PHASE" ]]; then
  echo "用法: $0 <phase> [model]"
  echo "範例: $0 7                         (execute mode)"
  echo "      MODE=research $0 8            (research mode)"
  echo "      MODE=plan $0 2                (plan mode)"
  echo "      $0 6.3 opencode/kimi-k2.6"
  echo "      SERVER_URL=http://localhost:4096 TARGET_DIR=/etf $0 8"
  exit 1
fi

mkdir -p "$LOG_DIR"

# ---- 預檢:跨專案外部目錄權限 ----
# 無頭模式對工作目錄以外的路徑會 auto-reject。掃 PLAN.md 找外部絕對路徑,
# 對照 opencode.json 白名單,缺的話先警告(否則士兵會空手而回)。
preflight_external_perms() {
  local plan oc_json="${PROJECT_DIR}/.opencode/opencode.json"
  # 若 TARGET_DIR/.planning 不存在，無外部路徑需檢查
  [[ ! -d "${TARGET_DIR}/.planning" ]] && return 0
  plan="$(find "${TARGET_DIR}/.planning" -path "*${PHASE}*" -name 'PLAN.md' 2>/dev/null | head -1)" || true
  [[ -z "$plan" || ! -f "$oc_json" ]] && return 0
  # 抓 PLAN 裡 /Users/... 形式、且不在工作目錄底下的絕對路徑根(取前 4 段)
  local ext_roots
  ext_roots="$(grep -oE '/Users/[^ )"'"'"']+' "$plan" 2>/dev/null \
    | grep -v "^${PROJECT_DIR}" \
    | sed -E 's#(/[^/]+/[^/]+/[^/]+/[^/]+)/.*#\1#' | sort -u)"
  [[ -z "$ext_roots" ]] && return 0
  local missing=()
  while IFS= read -r root; do
    [[ -z "$root" ]] && continue
    grep -q "$root" "$oc_json" || missing+=("$root")
  done <<< "$ext_roots"
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "⚠️  預檢警告:PLAN.md 引用了工作目錄以外的路徑,但 opencode.json 未授權讀取:"
    printf '     %s\n' "${missing[@]}"
    echo "     無頭模式會自動拒權 → 士兵讀不到、空手而回。"
    echo "     修法:在 .opencode/opencode.json 的 read 與 external_directory 兩處各加:"
    echo "       \"<上述路徑>/**\": \"allow\""
    echo "────────────────────────────────────────────────────────"
  fi
}
preflight_external_perms

# ---- 派工前檢查:TARGET_DIR 有效性(本地 + 跨專案都驗證) ----
# 驗證 TARGET_DIR 存在且是目錄
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "✗ FAIL: TARGET_DIR not found or not a directory: $TARGET_DIR"
  exit 1
fi

# 驗證是 git 倉庫
if ! git -C "$TARGET_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  echo "⚠️  Warning: TARGET_DIR is not a git repository: $TARGET_DIR"
  echo "   (派工可能仍會執行,但 git diff 驗收會失敗)"
fi

# ---- 派工前檢查:TARGET_DIR 的 .opencode.json 權限 ----
if [[ "$TARGET_DIR" != "$PROJECT_DIR" ]]; then
  echo ""
  echo "════════════════════════════════════════════════════════"
  echo "  跨專案權限審計 — gsd-permission-audit"
  echo "════════════════════════════════════════════════════════"

  AUDIT_SCRIPT="${PROJECT_DIR}/scripts/gsd-permission-audit.sh"
  if [[ ! -f "$AUDIT_SCRIPT" ]]; then
    echo "✗ gsd-permission-audit.sh not found at $AUDIT_SCRIPT"
    exit 1
  fi

  # 先只檢查(--fix 需使用者明確要求)
  if ! "$AUDIT_SCRIPT" --target "$TARGET_DIR" 2>&1; then
    echo ""
    echo "⚠️  權限不足。可執行以下命令自動修復:"
    echo "  $AUDIT_SCRIPT --target \"$TARGET_DIR\" --fix"
    echo ""
    exit 1
  fi
  echo ""
fi

# ---- 派工前快照(供軍師事後比對) ----
GIT_BEFORE="$(git -C "$TARGET_DIR" rev-parse HEAD 2>/dev/null || echo 'no-git')"

echo "════════════════════════════════════════════════════════"
echo "  軍師士兵派工 — Phase ${PHASE}"
echo "════════════════════════════════════════════════════════"
echo "  士兵模型 : ${MODEL}${VARIANT:+  (effort: ${VARIANT})}"
echo "  目標專案 : ${TARGET_DIR}${SERVER_URL:+   (attach: ${SERVER_URL})}"
echo "  cwd/config: ${PROJECT_DIR}  (vault,保住白名單)"
echo "  日誌落地 : ${LOG_FILE}"
echo "  起始提交 : ${GIT_BEFORE:0:8}"
echo "────────────────────────────────────────────────────────"
echo "  士兵執行中…(完整過程寫入 log,可另開終端 tail -f 觀看)"
echo "════════════════════════════════════════════════════════"
echo ""

# ---- 派工:士兵執行 gsd-research-phase 或 gsd-execute-phase ----
# default 格式(人類可讀)+ tee 落地;軍師不讀這個流,只讀下方 SUMMARY+diff
# ⚠️ DO NOT cd to $TARGET_DIR. cwd must stay at $PROJECT_DIR (vault)
# for .opencode/opencode.json whitelist to apply.

echo "士兵執行中…(完整過程寫入 log,可另開終端 tail -f 觀看)"
echo "  MODE: $MODE → $GSD_COMMAND"
if [[ -n "$SERVER_URL" ]]; then
  echo "  Session 監看: curl -s http://localhost:4096/session | jq '.[] | .title'"
fi
echo ""

# 記錄派工前的 session 數(用於 liveness 檢查)
SESSIONS_BEFORE=0
if [[ -n "$SERVER_URL" ]]; then
  SESSIONS_BEFORE=$(curl -s "$SERVER_URL/session" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
fi

# Workaround: opencode v1.17.5 bug — --command + --dir 組合會崩潰。
# 若 TARGET_DIR != PROJECT_DIR(跨專案），把 --dir 移到 prompt 指示中。
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

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Liveness 檢查 — 確認士兵真的有產出"
echo "════════════════════════════════════════════════════════"

# ---- Liveness 檢查 1:log 檔大小 ----
LOG_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
if [[ $LOG_SIZE -eq 0 ]]; then
  echo "✗ FAIL: log 檔 0 bytes — 士兵執行失敗或 process 被殺"
  echo "  檔案: $LOG_FILE"
  exit 1
else
  echo "✓ log 檔大小: $LOG_SIZE bytes"
fi

# ---- Liveness 檢查 2:server session 數(若有 attach) ----
if [[ -n "$SERVER_URL" ]]; then
  SESSIONS_AFTER=$(curl -s "$SERVER_URL/session" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
  if [[ $SESSIONS_AFTER -gt $SESSIONS_BEFORE ]]; then
    SESSION_DIFF=$((SESSIONS_AFTER - SESSIONS_BEFORE))
    echo "✓ server session: $SESSIONS_BEFORE → $SESSIONS_AFTER (+$SESSION_DIFF)"
    echo "  派工已上線至 shared server"
  else
    echo "⚠️  server session 無增加: $SESSIONS_BEFORE → $SESSIONS_AFTER"
    echo "  (可能: --attach 不起作用,或派工還未產出 session)"
  fi
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  士兵回報 — 以下是軍師需要讀的兩樣東西"
echo "════════════════════════════════════════════════════════"

# ---- 軍師驗收材料 1:git diff 摘要 ----
echo ""
echo "── git diff --stat(軍師看改了什麼)──────────────────────"
git -C "$TARGET_DIR" diff --stat "${GIT_BEFORE}" HEAD 2>/dev/null || git -C "$TARGET_DIR" diff --stat
echo ""
echo "── 新增的提交 ───────────────────────────────────────────"
git -C "$TARGET_DIR" log --oneline "${GIT_BEFORE}..HEAD" 2>/dev/null || echo "（無新提交,或士兵未自動 commit）"

# ---- 越界檢查(扣掉 OpenCode 自我改寫白名單)----
# OpenCode 每次啟動會自動改寫自己的這些檔,不是士兵的越界,需排除以免假警報
echo ""
echo "── 越界檢查(士兵有沒有動非預期的檔)────────────────────"
OPENCODE_SELF='\.opencode/opencode\.json|\.opencode/package\.json|\.opencode/.*\.lock|\.planning/soldier-logs/'
STRAY="$(git -C "$TARGET_DIR" diff --name-only "${GIT_BEFORE}" HEAD 2>/dev/null | grep -Ev "$OPENCODE_SELF" || true)"
STRAY_UNSTAGED="$(git -C "$TARGET_DIR" diff --name-only 2>/dev/null | grep -Ev "$OPENCODE_SELF" || true)"
ALL_STRAY="$(printf '%s\n%s\n' "$STRAY" "$STRAY_UNSTAGED" | sort -u | grep -v '^$' || true)"
if [[ -n "$ALL_STRAY" ]]; then
  echo "$ALL_STRAY" | sed 's/^/  改動: /'
  echo "  （以上為士兵實際觸及的檔,已自動排除 OpenCode 自我改寫;請軍師確認都在 PLAN 範圍內）"
else
  echo "  ✓ 無改動,或僅 OpenCode 自我改寫(已排除)"
fi

# ---- 軍師驗收材料 2:產出檔案路徑(依 MODE 找不同的檔)----
# 注意:log 檔內容可能大量夾雜 \r(進度覆寫符),用 tail 人工檢查行數會誤判
# 成「卡住」——判斷是否真的完成,以下面的「檔案是否存在」+ git log 為準,
# 不要單憑 tail 看 log 判斷派工死活。
echo ""
if [[ "$MODE" == "plan" ]]; then
  echo "── 士兵產出的 PLAN.md(軍師讀結論)───────────────────────"
  PLAN_FILES="$(find "${TARGET_DIR}/.planning/phases" -path "*${PHASE}*" -name '*-PLAN.md' 2>/dev/null | sort)"
  if [[ -n "$PLAN_FILES" ]]; then
    echo "$PLAN_FILES" | sed "s#^#找到: #; s#${PROJECT_DIR}/##"
  else
    echo "（未找到 Phase ${PHASE} 的 PLAN.md,請查 log: ${LOG_FILE#$PROJECT_DIR/}）"
  fi
else
  echo "── 士兵產出的 SUMMARY.md(軍師讀結論)────────────────────"
  SUMMARY="$(find "${TARGET_DIR}/.planning/phases" -path "*${PHASE}*" -name 'SUMMARY.md' 2>/dev/null | head -1)"
  if [[ -n "$SUMMARY" ]]; then
    echo "找到: ${SUMMARY#$PROJECT_DIR/}"
  else
    echo "（未找到 Phase ${PHASE} 的 SUMMARY.md,請查 log: ${LOG_FILE#$PROJECT_DIR/}）"
  fi
fi

echo ""
echo ""
echo "════════════════════════════════════════════════════════"
echo "  下一步(軍師):"
if [[ "$MODE" == "plan" ]]; then
  echo "    1. 讀上面的 PLAN.md + git log 確認 requirements 覆蓋完整"
  echo "    2. 有疑慮才深入看 log 或特定檔案"
  echo "    3. 滿意 → gsd-plan-checker 驗證,再 /gsd:execute-phase ${PHASE}"
elif [[ "$MODE" == "research" ]]; then
  echo "    1. 讀上面產出的 RESEARCH.md + git log"
  echo "    2. 有疑慮才深入看 log 或特定檔案"
  echo "    3. 滿意 → MODE=plan $0 ${PHASE}"
else
  echo "    1. 讀上面的 SUMMARY.md + git diff 驗收"
  echo "    2. 有疑慮才深入看 log 或特定檔案"
  echo "    3. 滿意 → /gsd:verify-work ${PHASE}"
fi
echo ""
if [[ -n "$SERVER_URL" ]]; then
  echo "  可視化(實時監看 session):"
  echo "    終端 1: curl -s $SERVER_URL/session | jq '.[] | {title, time}' | head"
  echo "    終端 2: opencode attach $SERVER_URL"
  echo "    終端 3: tail -f $LOG_FILE"
else
  echo "  可視化(本地 log):"
  echo "    tail -f $LOG_FILE"
fi
echo "════════════════════════════════════════════════════════"
