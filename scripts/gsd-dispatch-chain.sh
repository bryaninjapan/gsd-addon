#!/bin/bash
# gsd-dispatch-chain.sh — 派工鏈（自動順序執行）
#
# 用法：
#   gsd-dispatch-chain.sh <PHASE>
#   TARGET_DIR=/path/to/project gsd-dispatch-chain.sh <PHASE>
#
# 功能：串聯 research → plan → check 的完整流程
# 特性：
#   - Fail-fast：第一個失敗直接停止
#   - 輸出驗證：確保每個 mode 產出預期檔案
#   - TARGET_DIR 支援：跨專案派工
#   - 彩色輸出：易於閱讀

set -e

# ─────────────────────────────────────────────────────────────
# 參數驗證
# ─────────────────────────────────────────────────────────────

PHASE="${1:?Error: Phase number required. Usage: $0 <PHASE>}"
TARGET_DIR="${TARGET_DIR:-.}"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "✗ Error: TARGET_DIR not found: $TARGET_DIR"
  exit 1
fi

if [[ ! -d "$TARGET_DIR/.planning" ]]; then
  echo "✗ Error: .planning directory not found in $TARGET_DIR"
  exit 1
fi

# ─────────────────────────────────────────────────────────────
# 色彩和格式化
# ─────────────────────────────────────────────────────────────

BOLD='\033[1m'
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
RESET='\033[0m'

# ─────────────────────────────────────────────────────────────
# 派工鏈啟動
# ─────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}派工鏈啟動：Phase $PHASE (research → plan → check)${RESET}"
if [[ "$TARGET_DIR" != "." ]]; then
  echo -e "${BOLD}專案目錄：$TARGET_DIR${RESET}"
fi
echo -e "${BOLD}═══════════════════════════════════════════════════${RESET}"
echo ""

# ─────────────────────────────────────────────────────────────
# 派工鏈執行
# ─────────────────────────────────────────────────────────────

for mode in research plan check; do
  echo -e "${BOLD}【$mode】啟動派工...${RESET}"

  # 執行派工
  if ! MODE="$mode" TARGET_DIR="$TARGET_DIR" ~/.claude/gsd-addon/scripts/gsd-dispatch.sh "$PHASE"; then
    EXIT_CODE=$?
    echo -e "${RED}✗ $mode 派工失敗（exit code: $EXIT_CODE）${RESET}"
    exit 1
  fi

  # 驗證輸出檔案
  case "$mode" in
    research)
      if ! ls "$TARGET_DIR/.planning/phases/$PHASE"/*-RESEARCH.md 2>/dev/null | grep -q .; then
        echo -e "${RED}✗ RESEARCH.md 未產出（位置：$TARGET_DIR/.planning/phases/$PHASE/*-RESEARCH.md）${RESET}"
        exit 1
      fi
      FILE_COUNT=$(ls "$TARGET_DIR/.planning/phases/$PHASE"/*-RESEARCH.md 2>/dev/null | wc -l)
      echo -e "${GREEN}✓ research 完成（$FILE_COUNT 個 RESEARCH.md）${RESET}"
      ;;
    plan)
      if ! ls "$TARGET_DIR/.planning/phases/$PHASE"/*-PLAN.md 2>/dev/null | grep -q .; then
        echo -e "${RED}✗ PLAN.md 未產出（位置：$TARGET_DIR/.planning/phases/$PHASE/*-PLAN.md）${RESET}"
        exit 1
      fi
      FILE_COUNT=$(ls "$TARGET_DIR/.planning/phases/$PHASE"/*-PLAN.md 2>/dev/null | wc -l)
      echo -e "${GREEN}✓ plan 完成（$FILE_COUNT 個 PLAN.md）${RESET}"
      ;;
    check)
      if ! ls "$TARGET_DIR/.planning/phases/$PHASE"/*-PLAN-CHECK.md 2>/dev/null | grep -q .; then
        echo -e "${RED}✗ PLAN-CHECK.md 未產出（位置：$TARGET_DIR/.planning/phases/$PHASE/*-PLAN-CHECK.md）${RESET}"
        exit 1
      fi
      FILE_COUNT=$(ls "$TARGET_DIR/.planning/phases/$PHASE"/*-PLAN-CHECK.md 2>/dev/null | wc -l)
      echo -e "${GREEN}✓ check 完成（$FILE_COUNT 個 PLAN-CHECK.md）${RESET}"
      ;;
  esac

  echo ""
done

# ─────────────────────────────────────────────────────────────
# 派工鏈完成
# ─────────────────────────────────────────────────────────────

echo -e "${BOLD}═══════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}✓ 派工鏈完成：research → plan → check${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════${RESET}"
echo ""

exit 0
