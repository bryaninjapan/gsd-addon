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
#   MODE=check ./scripts/gsd-dispatch.sh 2                   # 切換 check mode(gsd-plan-checker,驗證已產出的 PLAN.md)
#   MODE=revise ./scripts/gsd-dispatch.sh 2                  # 切換 revise mode(依 PLAN-CHECK.md 修訂 PLAN.md)
#   MODEL="opencode-go/kimi-k2.6" ./scripts/gsd-dispatch.sh 6.3
#   VARIANT=minimal ./scripts/gsd-dispatch.sh 7              # 改成 effort minimal(便宜模式)
#
# 環境變數:
#   MODE     派工模式:research | plan | check | revise | execute(預設 execute)
#   MODEL    士兵模型(預設 opencode-go/deepseek-v4-flash)
#   VARIANT  reasoning effort:high / max / minimal(預設 high)
#   SERVER_URL  共享 server URL(設了就 attach)
#   TARGET_DIR  跨專案派工的目標專案(預設=PROJECT_DIR)
#
# 範例:
#   ./scripts/gsd-dispatch.sh 7
#   MODE=research ./scripts/gsd-dispatch.sh 8
#   MODE=plan ./scripts/gsd-dispatch.sh 2
#   MODE=check ./scripts/gsd-dispatch.sh 2
#   ./scripts/gsd-dispatch.sh 6.3 opencode/kimi-k2.6
#   SERVER_URL=http://localhost:4096 TARGET_DIR=/etf-project ./scripts/gsd-dispatch.sh 8
#
# 注意:MODE=plan 一次只會產出「下一份」缺的 PLAN.md(gsd-plan-phase 的標準行為
# 是規劃整個 phase 的所有 plan)。若某個 phase 已經有部分 PLAN.md 在磁碟上
# (例如前一次派工中途失敗),gsd-plan-phase 會偵測已存在的 plan 並接著補完,
# 不會重新覆寫。
#
# 派工提示詞(prompt)不再依賴 `opencode run --command`(該機制需要目標端有
# ClaudeWiki 的 .opencode/command + gsd-tools CLI,跨專案派工時常常解析不到,
# 士兵會讀不到指令而空手而回或中途卡住)。改為:每個 MODE 對應
# scripts/../prompts/<mode>.md 一份自包含的詳細提示詞範本(角色、檢查維度、
# 產出檔案格式全部寫在範本裡),用 {{PHASE}} / {{TARGET_DIR}} / {{TODAY}} /
# {{PHASE_SECTION}}(從 TARGET_DIR/.planning/ROADMAP.md 動態擷取的 phase 段落)
# 做變數代換後,直接當作 freeform prompt 派給士兵,並且會先 cd 進 TARGET_DIR
# 再執行,讓士兵能用專案內的相對路徑讀寫檔案。修改 prompts/*.md 就能讓某個
# mode 的檢查更嚴謹,不需要改這支腳本本身。
#
set -euo pipefail

# ---- 純 bash 逾時保護 helper ----
# 用法: run_with_timeout <秒數> <command...>
# 背景執行命令 + watcher 計時器,逾時以 SIGTERM 終止命令,
# 回傳 exit code 124(與 GNU timeout 慣例一致)。
# 不依賴外部 timeout/gtimeout(macOS 預設沒有),任何 bash 3.2+ 環境皆可跑。
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
    # wait 回傳 128+15=143(SIGTERM)代表被逾時終止,統一映射成 124
    exit_code=$?
    [[ "$exit_code" -eq 143 ]] && exit_code=124
  fi
  # Kill watcher's process group to reduce PID-reuse race window (WR-05):
  # if cmd exited naturally and its PID was reused before we reach this line,
  # killing the watcher's process group (sleep + kill subshell) avoids sending
  # SIGTERM to a recycled PID. Note: does not fully eliminate the race, but
  # substantially reduces the window.
  kill -TERM "-$watcher_pid" 2>/dev/null
  wait "$watcher_pid" 2>/dev/null
  return "$exit_code"
}

# ---- 參數 ----
PHASE="${1:-}"
MODEL="${2:-${MODEL:-opencode-go/deepseek-v4-flash}}"
VARIANT="${VARIANT:-high}"
case "$VARIANT" in
  high|max|minimal) ;;
  *)
    echo "✗ VARIANT 必須是 high、max 或 minimal,得到: $VARIANT"
    exit 1
    ;;
esac
MODE="${MODE:-execute}"  # research | plan | execute
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# 跨專案派工:被執行 phase 的目標專案(預設=派工方自己=vault)
TARGET_DIR="${TARGET_DIR:-$PROJECT_DIR}"
# 共享 server:設了就 attach,session 對使用者 TUI 可見(脫離 cwd 分群)
SERVER_URL="${SERVER_URL:-}"
LOG_DIR="${PROJECT_DIR}/.planning/soldier-logs"
LOG_FILE="${LOG_DIR}/phase-${PHASE}-$(date +%Y%m%d-%H%M%S).log"
PROMPTS_DIR="${PROJECT_DIR}/prompts"

# 選擇指令(GSD_COMMAND 僅供顯示/log 用,實際派工一律用 prompts/<mode>.md 範本)
case "$MODE" in
  research)     GSD_COMMAND="gsd-phase-researcher" ;;
  plan)         GSD_COMMAND="gsd-planner" ;;
  check)        GSD_COMMAND="gsd-plan-checker" ;;
  revise)       GSD_COMMAND="gsd-planner (revision)" ;;
  execute)      GSD_COMMAND="gsd-executor" ;;
  code-review)  GSD_COMMAND="gsd-code-reviewer" ;;
  verify)       GSD_COMMAND="gsd-verifier" ;;
  *)
    echo "✗ MODE 必須是 research、plan、check、revise、execute、code-review 或 verify,得到: $MODE"
    exit 1
    ;;
esac

PROMPT_TEMPLATE="${PROMPTS_DIR}/${MODE}.md"
if [[ ! -f "$PROMPT_TEMPLATE" ]]; then
  echo "✗ 找不到 prompt 範本: $PROMPT_TEMPLATE"
  exit 1
fi

# ---- 用法/--help ----
show_usage() {
  echo "用法: $0 <phase> [model]"
  echo "範例: $0 7                         (execute mode)"
  echo "      MODE=research $0 8            (research mode)"
  echo "      MODE=plan $0 2                (plan mode)"
  echo "      MODE=check $0 2               (check mode — 驗證已存在的 PLAN.md)"
  echo "      MODE=revise $0 2              (revise mode — 依 PLAN-CHECK.md 修訂 PLAN.md)"
  echo "      MODE=code-review $0 2         (code-review mode — 審查已執行 phase 的 commit,產出 REVIEW.md)"
  echo "      MODE=verify $0 2              (verify mode — goal-backward 驗證 success criteria,產出 VERIFICATION.md)"
  echo "      $0 6.3 opencode/kimi-k2.6"
  echo "      SERVER_URL=http://localhost:4096 TARGET_DIR=/etf $0 8"
  echo "      RETRY=true gsd-dispatch 4     (啟用重試 wrapper:最多 3 次,指數退避)"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_usage
  exit 0
fi

if [[ -z "$PHASE" ]]; then
  show_usage
  exit 1
fi

mkdir -p "$LOG_DIR"

# ---- 從 TARGET_DIR/.planning/ROADMAP.md 動態擷取「### Phase N」段落 ----
# 擷取範圍:從符合 "### Phase <PHASE>[:.]" 的標題開始,到下一個 "### Phase " 標題(不含)為止。
extract_phase_section() {
  local roadmap="${TARGET_DIR}/.planning/ROADMAP.md"
  if [[ ! -f "$roadmap" ]]; then
    echo "(找不到 ${roadmap},請確認 TARGET_DIR 底下有 .planning/ROADMAP.md)"
    return
  fi
  awk -v phase="$PHASE" '
    BEGIN { found=0 }
    $0 == "### Phase " phase ":" || $0 == "### Phase " phase "." { found=1; print; next }
    found && /^### Phase / { exit }
    found { print }
  ' "$roadmap"
}

# ---- 用 prompts/<mode>.md 範本 + 變數代換,組出士兵的 freeform prompt ----
# 用 python3 做替換(避免 ROADMAP 內容含 / 或特殊字元弄壞 sed)。
build_prompt() {
  local template="$1" phase="$2" target_dir="$3" today="$4" phase_section="$5"
  TPL="$template" PHASE="$phase" TARGET_DIR="$target_dir" TODAY="$today" PHASE_SECTION="$phase_section" \
    python3 -c '
import os
with open(os.environ["TPL"], "r") as f:
    text = f.read()
text = text.replace("{{PHASE}}", os.environ["PHASE"])
text = text.replace("{{TARGET_DIR}}", os.environ["TARGET_DIR"])
text = text.replace("{{TODAY}}", os.environ["TODAY"])
text = text.replace("{{PHASE_SECTION}}", os.environ["PHASE_SECTION"])
print(text)
'
}

# NOTE: preflight_external_perms() was removed (WR-02).
# It was only relevant to --command dispatch mode (required TARGET_DIR paths to be
# whitelisted in PROJECT_DIR's opencode.json). Now dispatch always cd's into TARGET_DIR
# and uses relative paths in prompt templates, so cross-directory whitelisting is no
# longer needed. The function was never called; it has been deleted rather than retained
# as dead code.

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

# 註:先前這裡會呼叫 gsd-permission-audit.sh 檢查 opencode.json 跨目錄白名單。
# 現在派工一律 cd 進 TARGET_DIR 執行(見下方 opencode run),TARGET_DIR 底下
# 的檔案對士兵來說就是 cwd 內的檔案,不再需要外部目錄白名單,故跳過此檢查。

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

# ---- 派工:士兵執行 prompts/<mode>.md 組出的自包含 prompt ----
# default 格式(人類可讀)+ tee 落地;軍師不讀這個流,只讀下方 SUMMARY+diff
# 一律 cd 進 TARGET_DIR 再執行(prompt 範本用的是相對路徑),這樣士兵讀寫的
# 就是專案內的真實檔案,不需要 opencode.json 的跨目錄白名單,也不依賴
# --command 解析(該機制在 TARGET_DIR 沒有 .opencode/command 時常常失敗)。

PHASE_SECTION="$(extract_phase_section)"
TODAY="$(date +%Y-%m-%d)"
FULL_PROMPT="$(build_prompt "$PROMPT_TEMPLATE" "$PHASE" "$TARGET_DIR" "$TODAY" "$PHASE_SECTION")"

echo "士兵執行中…(完整過程寫入 log,可另開終端 tail -f 觀看)"
echo "  MODE: $MODE → $GSD_COMMAND  (prompt: ${PROMPT_TEMPLATE#$PROJECT_DIR/})"
if [[ -n "$SERVER_URL" ]]; then
  echo "  Session 監看: curl -s http://localhost:4096/session | jq '.[] | .title'"
fi
echo ""

# 記錄派工前的 session 數(用於 liveness 檢查)
SESSIONS_BEFORE=0
if [[ -n "$SERVER_URL" ]]; then
  # --max-time 5: 避免 SERVER_URL 無回應導致腳本卡住；失敗時降級為 0
  SESSIONS_BEFORE=$(curl -s --max-time 5 "$SERVER_URL/session" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
fi

# Timeout: 3600s(1 小時)避免伺服器無回應導致腳本永不返回，逾時回傳 exit code 124
# Capture the dispatch exit code without letting set -e abort the script
DISPATCH_RC=0
(
  cd "$TARGET_DIR"
  run_with_timeout 3600 opencode run \
    -m "$MODEL" \
    ${VARIANT:+--variant "$VARIANT"} \
    ${SERVER_URL:+--attach "$SERVER_URL"} \
    "$FULL_PROMPT"
) 2>&1 | tee "$LOG_FILE" || DISPATCH_RC=$?

if [[ $DISPATCH_RC -ne 0 ]]; then
  [[ $DISPATCH_RC -eq 124 ]] \
    && echo "✗ TIMEOUT: opencode did not finish within 3600s (exit 124)" \
    || echo "✗ opencode exited with code $DISPATCH_RC"
fi
# Continue to liveness checks regardless

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Liveness 檢查 — 確認士兵真的有產出"
echo "════════════════════════════════════════════════════════"

# ---- Liveness 檢查 1:log 檔大小 ----
LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
if [[ $LOG_SIZE -eq 0 ]]; then
  echo "✗ FAIL: log 檔 0 bytes — 士兵執行失敗或 process 被殺"
  echo "  檔案: $LOG_FILE"
  exit 1
else
  echo "✓ log 檔大小: $LOG_SIZE bytes"
fi

# ---- Liveness 檢查 2:server session 數(若有 attach) ----
if [[ -n "$SERVER_URL" ]]; then
  # --max-time 5: 避免 SERVER_URL 無回應導致腳本卡住；失敗時降級為 0
  SESSIONS_AFTER=$(curl -s --max-time 5 "$SERVER_URL/session" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
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
# --ignore-all-space 加速大型 diff；失敗時顯示降級訊息而非卡住
git -C "$TARGET_DIR" diff --stat --ignore-all-space "${GIT_BEFORE}" HEAD 2>/dev/null || echo "（git diff 逾時或失敗）"
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
elif [[ "$MODE" == "check" ]]; then
  echo "── 士兵產出的 PLAN-CHECK.md(軍師讀結論)─────────────────"
  CHECK_FILES="$(find "${TARGET_DIR}/.planning/phases" -path "*${PHASE}*" -name '*-PLAN-CHECK.md' 2>/dev/null | sort)"
  if [[ -n "$CHECK_FILES" ]]; then
    echo "$CHECK_FILES" | sed "s#^#找到: #; s#${PROJECT_DIR}/##"
  else
    echo "（未找到 Phase ${PHASE} 的 PLAN-CHECK.md,請查 log: ${LOG_FILE#$PROJECT_DIR/}）"
  fi
elif [[ "$MODE" == "revise" ]]; then
  echo "── 修訂後的 PLAN.md(軍師看 git diff 確認修法)────────────"
  PLAN_FILES="$(find "${TARGET_DIR}/.planning/phases" -path "*${PHASE}*" -name '*-PLAN.md' 2>/dev/null | sort)"
  if [[ -n "$PLAN_FILES" ]]; then
    echo "$PLAN_FILES" | sed "s#^#找到: #; s#${PROJECT_DIR}/##"
  else
    echo "（未找到 Phase ${PHASE} 的 PLAN.md,請查 log: ${LOG_FILE#$PROJECT_DIR/}）"
  fi
elif [[ "$MODE" == "research" ]]; then
  echo "── 士兵產出的 RESEARCH.md(軍師讀結論)────────────────────"
  RESEARCH_FILES="$(find "${TARGET_DIR}/.planning/phases" -path "*${PHASE}*" \
    -name "*-RESEARCH.md" 2>/dev/null | sort)"
  if [[ -n "$RESEARCH_FILES" ]]; then
    echo "$RESEARCH_FILES" | sed "s#^#找到: #; s#${PROJECT_DIR}/##"
  else
    echo "（未找到 Phase ${PHASE} 的 RESEARCH.md,請查 log: ${LOG_FILE#$PROJECT_DIR/}）"
  fi
elif [[ "$MODE" == "code-review" ]]; then
  echo "── 士兵產出的 REVIEW.md(軍師讀結論)──────────────────────"
  REVIEW_FILES="$(find "${TARGET_DIR}/.planning/phases" -path "*${PHASE}*" -name '*-REVIEW.md' 2>/dev/null | sort)"
  if [[ -n "$REVIEW_FILES" ]]; then
    echo "$REVIEW_FILES" | sed "s#^#找到: #; s#${PROJECT_DIR}/##"
  else
    echo "（未找到 Phase ${PHASE} 的 REVIEW.md,請查 log: ${LOG_FILE#$PROJECT_DIR/}）"
  fi
elif [[ "$MODE" == "verify" ]]; then
  echo "── 士兵產出的 VERIFICATION.md(軍師讀結論)────────────────"
  VERIFY_FILES="$(find "${TARGET_DIR}/.planning/phases" -path "*${PHASE}*" \( -name '*-VERIFICATION.md' -o -name 'VERIFICATION.md' \) 2>/dev/null | sort)"
  if [[ -n "$VERIFY_FILES" ]]; then
    echo "$VERIFY_FILES" | sed "s#^#找到: #; s#${PROJECT_DIR}/##"
  else
    echo "（未找到 Phase ${PHASE} 的 VERIFICATION.md,請查 log: ${LOG_FILE#$PROJECT_DIR/}）"
  fi
else
  # execute mode
  echo "── 士兵產出的 SUMMARY.md(軍師讀結論)────────────────────"
  SUMMARY="$(find "${TARGET_DIR}/.planning/phases" -path "*${PHASE}*" -name '*-SUMMARY.md' 2>/dev/null | head -1)"
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
  echo "    3. 滿意 → MODE=check $0 ${PHASE} 驗證,再 /gsd:execute-phase ${PHASE}"
elif [[ "$MODE" == "research" ]]; then
  echo "    1. 讀上面產出的 RESEARCH.md + git log"
  echo "    2. 有疑慮才深入看 log 或特定檔案"
  echo "    3. 滿意 → MODE=plan $0 ${PHASE}"
elif [[ "$MODE" == "check" ]]; then
  echo "    1. 讀上面的 PLAN-CHECK.md,看有沒有 blocker"
  echo "    2. 0 blocker → 直接執行;有 warning → 視情況先修 PLAN.md 再執行"
  echo "    3. 有 blocker → MODE=revise $0 ${PHASE} 自動修訂,再 MODE=check 重新驗證"
  echo "    4. 滿意 → $0 ${PHASE}(execute mode)"
elif [[ "$MODE" == "revise" ]]; then
  echo "    1. 讀 git diff 確認 PLAN.md 的修法符合 PLAN-CHECK.md 的 fix_hint"
  echo "    2. 有疑慮才深入看 log 或特定檔案"
  echo "    3. 滿意 → MODE=check $0 ${PHASE} 重新驗證,確認 blocker 歸零"
elif [[ "$MODE" == "code-review" ]]; then
  echo "    1. 讀上面的 REVIEW.md,看有沒有 CRITICAL/HIGH"
  echo "    2. 0 CRITICAL/HIGH → 可以 merge;有的話先修再重跑 code-review"
  echo "    3. 滿意 → MODE=verify $0 ${PHASE} 做最終 goal-backward 驗證"
elif [[ "$MODE" == "verify" ]]; then
  echo "    1. 讀上面的 VERIFICATION.md,看每條 success criterion 的 verdict"
  echo "    2. 全部 PASS → phase 完成,可以 commit+push、進下一個 phase"
  echo "    3. 有 FAIL → 依報告裡的 Recommendation 修復,再重跑 MODE=verify"
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

# ---- 回傳派工結果(供 retry wrapper / 呼叫方判斷成敗)----
# 之前這裡一律隱式 exit 0,即使 opencode 失敗也傳 0,retry wrapper 因而
# 無法偵測失敗。現在把 DISPATCH_RC 傳出去:成功=0,逾時=124,其他=opencode exit code。
exit "$DISPATCH_RC"
