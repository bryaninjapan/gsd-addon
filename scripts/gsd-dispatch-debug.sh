#!/bin/bash
# gsd-dispatch-debug.sh — GSD Dispatch 診斷工具
#
# 用法：gsd-dispatch-debug.sh [mode] [options]
# 模式：status | install | retry | logs | check-env | diagnose
#
# 功能：診斷派工系統的狀態、環境、故障
# 特性：彩色輸出、自動建議修復、支持多模式組合

set -e

# ─────────────────────────────────────────────────────────────
# 色彩和格式化
# ─────────────────────────────────────────────────────────────

BOLD='\033[1m'
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

# ─────────────────────────────────────────────────────────────
# 工具函數
# ─────────────────────────────────────────────────────────────

check_mark() { echo -e "${GREEN}✓${RESET}"; }
cross_mark() { echo -e "${RED}✗${RESET}"; }
warning_mark() { echo -e "${YELLOW}⚠${RESET}"; }

log_success() { echo -e "${GREEN}✓ $1${RESET}"; }
log_error() { echo -e "${RED}✗ $1${RESET}"; }
log_warning() { echo -e "${YELLOW}⚠ $1${RESET}"; }
log_info() { echo -e "${BLUE}ℹ $1${RESET}"; }

# ─────────────────────────────────────────────────────────────
# 模式：status — 派工進程和最後狀態
# ─────────────────────────────────────────────────────────────

mode_status() {
  echo -e "${BOLD}派工狀態診斷${RESET}"
  echo ""

  # 檢查進程
  OC_PROCS=$(pgrep -f "opencode" 2>/dev/null | wc -l)
  if [[ $OC_PROCS -gt 0 ]]; then
    log_warning "OpenCode 進程運行中：$OC_PROCS 個"
  else
    log_success "無 OpenCode 進程運行"
  fi

  # 檢查最新 log
  LATEST_LOG=$(ls -t ~/.claude/gsd-addon/.planning/soldier-logs/phase-*.log 2>/dev/null | head -1)
  if [[ -n "$LATEST_LOG" ]]; then
    echo ""
    echo -e "${BOLD}最新派工日誌：${RESET}"
    ls -lh "$LATEST_LOG"

    echo ""
    echo -e "${BOLD}日誌末尾（最後 10 行）：${RESET}"
    tail -10 "$LATEST_LOG" | sed 's/^/  /'
  else
    log_warning "未找到派工日誌"
  fi

  echo ""
}

# ─────────────────────────────────────────────────────────────
# 模式：install — 驗證安裝完整性
# ─────────────────────────────────────────────────────────────

mode_install() {
  echo -e "${BOLD}安裝驗證${RESET}"
  echo ""

  GSD_ADDON_HOME="${GSD_ADDON_HOME:-$HOME/.claude/gsd-addon}"

  # 檢查主要檔案
  files=(
    "scripts/gsd-dispatch.sh"
    "scripts/dispatch-with-retry.sh"
    "scripts/gsd-dispatch-chain.sh"
    "gsd-config.sh"
  )

  for file in "${files[@]}"; do
    if [[ -f "$GSD_ADDON_HOME/$file" ]]; then
      SIZE=$(du -h "$GSD_ADDON_HOME/$file" | cut -f1)
      log_success "$file ($SIZE)"
    else
      log_error "$file 未找到"
    fi
  done

  # 檢查 prompts
  echo ""
  PROMPT_COUNT=$(ls "$GSD_ADDON_HOME/prompts"/*.md 2>/dev/null | wc -l)
  if [[ $PROMPT_COUNT -ge 5 ]]; then
    log_success "Prompts 目錄（$PROMPT_COUNT 個範本）"
  else
    log_error "Prompts 不完整（僅 $PROMPT_COUNT 個，需要 5 個）"
  fi

  # 檢查全局命令
  echo ""
  echo -e "${BOLD}全局命令：${RESET}"
  for cmd in gsd-dispatch gsd-test gsd-addon-config; do
    if command -v $cmd &> /dev/null; then
      log_success "$cmd"
    else
      log_error "$cmd 未找到"
    fi
  done

  echo ""
}

# ─────────────────────────────────────────────────────────────
# 模式：retry — RETRY 邏輯檢查
# ─────────────────────────────────────────────────────────────

mode_retry() {
  echo -e "${BOLD}RETRY 邏輯檢查${RESET}"
  echo ""

  GSD_ADDON_HOME="${GSD_ADDON_HOME:-$HOME/.claude/gsd-addon}"

  # 檢查 dispatch-with-retry.sh
  if [[ -f "$GSD_ADDON_HOME/scripts/dispatch-with-retry.sh" ]]; then
    log_success "dispatch-with-retry.sh 存在"

    # 檢查關鍵邏輯
    if grep -q "MAX_RETRIES" "$GSD_ADDON_HOME/scripts/dispatch-with-retry.sh"; then
      log_success "MAX_RETRIES 定義存在"
    else
      log_error "MAX_RETRIES 未找到"
    fi

    if grep -q "_is_non_retryable" "$GSD_ADDON_HOME/scripts/dispatch-with-retry.sh"; then
      log_success "錯誤分類邏輯存在"
    else
      log_warning "錯誤分類邏輯未明確定義"
    fi
  else
    log_error "dispatch-with-retry.sh 未找到"
  fi

  # 測試 RETRY 路由
  echo ""
  echo -e "${BOLD}測試 RETRY 路由：${RESET}"

  # 檢查 ~/.local/bin/gsd-dispatch
  if [[ -f "$HOME/.local/bin/gsd-dispatch" ]]; then
    if grep -q "RETRY" "$HOME/.local/bin/gsd-dispatch"; then
      log_success "RETRY 路由邏輯存在於 gsd-dispatch"
    else
      log_error "RETRY 路由邏輯未找到"
    fi
  else
    log_warning "gsd-dispatch 全局命令未找到"
  fi

  echo ""
  echo -e "${BOLD}RETRY 啟用方式：${RESET}"
  echo "  RETRY=true gsd-dispatch <phase>"
  echo "  或"
  echo "  RETRY=true gsd-dispatch-chain.sh <phase>"
  echo ""
}

# ─────────────────────────────────────────────────────────────
# 模式：logs — 查看最新 log
# ─────────────────────────────────────────────────────────────

mode_logs() {
  echo -e "${BOLD}派工日誌${RESET}"
  echo ""

  LOG_DIR="$HOME/.claude/gsd-addon/.planning/soldier-logs"

  if [[ ! -d "$LOG_DIR" ]]; then
    log_error "Log 目錄不存在：$LOG_DIR"
    return
  fi

  # 列出最新的 5 個 log
  echo -e "${BOLD}最近 5 個日誌：${RESET}"
  ls -1t "$LOG_DIR"/phase-*.log 2>/dev/null | head -5 | while read log; do
    SIZE=$(du -h "$log" | cut -f1)
    TIME=$(ls -l "$log" | awk '{print $6, $7, $8}')
    basename=$(basename "$log")
    printf "  %s %s\n" "$SIZE" "$basename"
  done

  # 顯示最新 log 的內容
  LATEST_LOG=$(ls -t "$LOG_DIR"/phase-*.log 2>/dev/null | head -1)
  if [[ -n "$LATEST_LOG" ]]; then
    echo ""
    echo -e "${BOLD}最新日誌詳情：${RESET}"
    echo "  路徑：$LATEST_LOG"
    echo "  大小：$(du -h "$LATEST_LOG" | cut -f1)"

    # 搜尋錯誤
    ERROR_COUNT=$(grep -c "error\|Error\|ERROR" "$LATEST_LOG" 2>/dev/null || echo "0")
    if [[ $ERROR_COUNT -gt 0 ]]; then
      log_error "檢測到 $ERROR_COUNT 個錯誤"
    else
      log_success "無明顯錯誤"
    fi

    echo ""
    echo -e "${BOLD}日誌末尾（最後 20 行）：${RESET}"
    tail -20 "$LATEST_LOG" | sed 's/^/  /'
  fi

  echo ""
}

# ─────────────────────────────────────────────────────────────
# 模式：check-env — 環境檢查
# ─────────────────────────────────────────────────────────────

mode_check_env() {
  echo -e "${BOLD}環境檢查${RESET}"
  echo ""

  GSD_ADDON_HOME="${GSD_ADDON_HOME:-$HOME/.claude/gsd-addon}"
  BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

  # 檢查 GSD_ADDON_HOME
  if [[ -d "$GSD_ADDON_HOME" ]]; then
    log_success "GSD_ADDON_HOME：$GSD_ADDON_HOME"
  else
    log_error "GSD_ADDON_HOME 不存在：$GSD_ADDON_HOME"
  fi

  # 檢查 ~/.local/bin 在 PATH 中
  if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
    log_success "~/.local/bin 在 PATH 中"
  else
    log_warning "~/.local/bin 不在 PATH 中"
    echo "  修復：添加到 ~/.bashrc 或 ~/.zshrc："
    echo "    export PATH=\"\$PATH:$BIN_DIR\""
  fi

  # 檢查全局命令可執行性
  echo ""
  echo -e "${BOLD}全局命令可執行性：${RESET}"
  for cmd in gsd-dispatch gsd-test gsd-addon-config; do
    if [[ -f "$BIN_DIR/$cmd" ]]; then
      if [[ -x "$BIN_DIR/$cmd" ]]; then
        log_success "$cmd 可執行"
      else
        log_error "$cmd 不可執行"
        echo "    修復：chmod +x $BIN_DIR/$cmd"
      fi
    else
      log_error "$cmd 未找到於 $BIN_DIR"
    fi
  done

  # 檢查 OpenCode 命令
  echo ""
  if command -v opencode &> /dev/null; then
    log_success "OpenCode 命令可用"
  else
    log_error "OpenCode 命令未找到"
    echo "  確認 OpenCode 已安裝並在 PATH 中"
  fi

  echo ""
}

# ─────────────────────────────────────────────────────────────
# 模式：diagnose — 全面診斷
# ─────────────────────────────────────────────────────────────

mode_diagnose() {
  echo -e "${BOLD}════════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}           派工系統全面診斷${RESET}"
  echo -e "${BOLD}════════════════════════════════════════════════════${RESET}"
  echo ""

  # 運行所有診斷模式
  mode_status
  mode_install
  mode_retry
  mode_check_env

  echo -e "${BOLD}════════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}診斷建議：${RESET}"
  echo ""

  # 簡單的建議邏輯
  if pgrep -f "opencode" &> /dev/null; then
    log_warning "OpenCode 進程仍在運行"
    echo "  建議：等待現有派工完成，或手動終止 opencode 進程"
  fi

  if ! command -v gsd-dispatch &> /dev/null; then
    log_warning "gsd-dispatch 全局命令不可用"
    echo "  建議：執行 bash install.sh 重新安裝"
  fi

  echo ""
  echo -e "${BOLD}常見問題排查：${RESET}"
  echo "  1. 派工卡頓 → 查看 MODE=execute 是否有已知限制（Layer 5 問題）"
  echo "  2. 文件未找到 → 檢查 install 完整性"
  echo "  3. RETRY 不工作 → 檢查 gsd-dispatch 全局命令中的路由邏輯"
  echo ""
}

# ─────────────────────────────────────────────────────────────
# 主程序
# ─────────────────────────────────────────────────────────────

MODE="${1:-diagnose}"

case "$MODE" in
  status)
    mode_status
    ;;
  install)
    mode_install
    ;;
  retry)
    mode_retry
    ;;
  logs)
    mode_logs
    ;;
  check-env)
    mode_check_env
    ;;
  diagnose)
    mode_diagnose
    ;;
  *)
    echo -e "${BOLD}GSD Dispatch Debug Tool${RESET}"
    echo ""
    echo "用法：gsd-dispatch-debug.sh [mode]"
    echo ""
    echo "模式："
    echo "  status      — 派工進程和最後狀態"
    echo "  install     — 驗證安裝完整性"
    echo "  retry       — RETRY 邏輯檢查"
    echo "  logs        — 查看最新 log"
    echo "  check-env   — 環境變數和 PATH 檢查"
    echo "  diagnose    — 全面診斷（預設）"
    echo ""
    echo "例子："
    echo "  gsd-dispatch-debug.sh                # 全面診斷"
    echo "  gsd-dispatch-debug.sh status         # 派工狀態"
    echo "  gsd-dispatch-debug.sh logs           # 查看日誌"
    echo ""
    exit 1
    ;;
esac
