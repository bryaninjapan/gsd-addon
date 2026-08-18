#!/usr/bin/env bash
#
# gsd-permission-audit.sh — 跨專案派工權限審計
#
# 檢查與修復 OpenCode 無頭模式下的跨專案讀取權限。
# gsd-dispatch.sh 在跨專案派工前會呼叫此腳本做預檢。
#
# 用法:
#   ./scripts/gsd-permission-audit.sh --target <target-project>         # 檢查
#   ./scripts/gsd-permission-audit.sh --target <target-project> --fix   # 自動修復
#
# 環境變數:
#   OPENCODE_CONFIG  .opencode/opencode.json 的路徑（預設：$PWD/.opencode/opencode.json）
#
# 原理:
#   OpenCode 無頭模式(`opencode run`)對工作目錄**以外**的路徑會自動拒權。
#   若 PLAN.md 或其他派工相關檔案引用外部路徑(如 vault 上的 wiki),
#   需要在 .opencode/opencode.json 的 read 與 external_directory 兩處
#   都加上該路徑的 glob 白名單,士兵才能讀取。
#
#   例: 派工到 /etf-flow-database,但 PLAN 引用 /vault/wiki/...
#   → 需在 .opencode/opencode.json 中加:
#      "read":               { "/vault/**": "allow" },
#      "external_directory": { "/vault/**": "allow" }
#

set -euo pipefail

# ---- 參數與配置 ----
TARGET_DIR="${TARGET_DIR:-.}"
FIX_MODE=false
OPENCODE_CONFIG="${OPENCODE_CONFIG:-./.opencode/opencode.json}"
PROJECT_DIR="$(pwd)"

# 解析命令列
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET_DIR="$2"
      shift 2
      ;;
    --fix)
      FIX_MODE=true
      shift
      ;;
    *)
      echo "未知選項: $1"
      echo "用法: $0 --target <target-project> [--fix]"
      exit 1
      ;;
  esac
done

# ---- 驗證 ----
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "✗ TARGET_DIR 不存在: $TARGET_DIR"
  exit 1
fi

if [[ ! -f "$OPENCODE_CONFIG" ]]; then
  echo "⚠️  警告: .opencode/opencode.json 不存在: $OPENCODE_CONFIG"
  echo "   (可能此派工是本地派工，不需跨專案權限)"
  exit 0
fi

# ---- 掃描 TARGET_DIR 中的外部路徑引用 ----
echo "════════════════════════════════════════════════════════"
echo "  跨專案權限審計 — gsd-permission-audit"
echo "════════════════════════════════════════════════════════"
echo "  派工源    : $PROJECT_DIR"
echo "  目標專案  : $TARGET_DIR"
echo "  設定檔    : $OPENCODE_CONFIG"
echo "────────────────────────────────────────────────────────"

# 掃 TARGET_DIR/.planning 中的所有檔，尋找外部絕對路徑
find_external_paths() {
  local planning_dir="$TARGET_DIR/.planning"
  [[ ! -d "$planning_dir" ]] && return 0

  # 搜尋 /Users/... 形式的絕對路徑，且不在 TARGET_DIR 底下的
  grep -rh -oE '/Users/[^ )"'"'"']+' "$planning_dir" 2>/dev/null | \
    grep -v "^${TARGET_DIR}" | \
    sed -E 's#(/[^/]+/[^/]+/[^/]+/[^/]+)/.*#\1#' | \
    sort -u || true
}

EXTERNAL_PATHS=$(find_external_paths)

if [[ -z "$EXTERNAL_PATHS" ]]; then
  echo "✓ 無外部路徑引用 — 無需跨專案權限"
  exit 0
fi

echo "📋 偵測到的外部路徑根:"
echo "$EXTERNAL_PATHS" | sed 's/^/   /'
echo ""

# ---- 檢查 opencode.json 中的白名單 ----
echo "🔍 掃描 opencode.json 中的授權..."
MISSING_PERMS=()
while IFS= read -r ext_root; do
  [[ -z "$ext_root" ]] && continue

  # 轉成 glob pattern
  GLOB_PATTERN="${ext_root}/**"

  # 檢查是否已在 read 或 external_directory 中授權
  if ! grep -q "$ext_root" "$OPENCODE_CONFIG"; then
    MISSING_PERMS+=("$GLOB_PATTERN")
    echo "   ✗ 未授權: $GLOB_PATTERN"
  else
    echo "   ✓ 已授權: $GLOB_PATTERN"
  fi
done <<< "$EXTERNAL_PATHS"

if [[ ${#MISSING_PERMS[@]} -eq 0 ]]; then
  echo ""
  echo "════════════════════════════════════════════════════════"
  echo "✅ 所有外部路徑都已授權"
  echo "════════════════════════════════════════════════════════"
  exit 0
fi

# ---- 缺失權限 — 是否自動修復 ----
echo ""
echo "⚠️  缺失以下跨專案讀取權限:"
printf '   %s\n' "${MISSING_PERMS[@]}"
echo ""

if [[ "$FIX_MODE" == false ]]; then
  echo "✗ 權限檢查失敗。執行以下命令自動修復:"
  echo ""
  echo "  $0 --target \"$TARGET_DIR\" --fix"
  echo ""
  exit 1
fi

# ---- --fix 模式：自動補充白名單 ----
echo "🔧 自動修復中..."

# 備份原始檔
BACKUP_FILE="${OPENCODE_CONFIG}.bak.$(date +%s)"
cp "$OPENCODE_CONFIG" "$BACKUP_FILE"
echo "   備份: $BACKUP_FILE"

# 用 Python 修改 JSON（比 jq 更穩定處理多層結構）
python3 << PYTHON_EOF
import json
import os

config_file = "$OPENCODE_CONFIG"
with open(config_file, 'r') as f:
    config = json.load(f)

# 確保 permission 物件存在
if 'permission' not in config:
    config['permission'] = {}

# 確保 read 和 external_directory 存在
if 'read' not in config['permission']:
    config['permission']['read'] = {}
if 'external_directory' not in config['permission']:
    config['permission']['external_directory'] = {}

# 補充缺失的權限
external_paths = """$EXTERNAL_PATHS""".strip().split('\n')
for ext_path in external_paths:
    if not ext_path:
        continue
    glob_pattern = f"{ext_path}/**"
    config['permission']['read'][glob_pattern] = "allow"
    config['permission']['external_directory'][glob_pattern] = "allow"
    print(f"   加入: {glob_pattern}")

# 寫回
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print(f"\n✓ 已更新: {config_file}")
PYTHON_EOF

if [[ $? -eq 0 ]]; then
  echo ""
  echo "════════════════════════════════════════════════════════"
  echo "✅ 權限已修復"
  echo "════════════════════════════════════════════════════════"
  echo ""
  echo "下次派工時將能讀取外部路徑。"
  exit 0
else
  echo ""
  echo "✗ Python 執行失敗。手動修復:"
  echo ""
  echo "編輯 $OPENCODE_CONFIG，在 permission.read 和"
  echo "permission.external_directory 兩處各加:"
  echo ""
  for glob in "${MISSING_PERMS[@]}"; do
    echo "  \"$glob\": \"allow\""
  done
  echo ""
  exit 1
fi
