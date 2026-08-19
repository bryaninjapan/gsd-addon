---
phase: 6
name: "GSD-Dispatch Debug Tool"
milestone: "1.2"
status: "Planned"
timeline: "2026-08-20"
---

# Phase 6：GSD-Dispatch Debug Tool

**目標**: 創建 `gsd-dispatch-debug.sh` 診斷工具，用於快速定位和解決派工故障

**成功標準**:
- [ ] `scripts/gsd-dispatch-debug.sh` 創建（~200 行）
- [ ] 支援 6 種 debug 模式：status / install / retry / logs / check-env / diagnose
- [ ] 彩色輸出（✓/✗/⚠）+ 自動建議修復
- [ ] 整合到 install.sh（`--verify` 選項）
- [ ] 創建 `/gsd:dispatch-debug` skill（可選）
- [ ] bash -n 語法檢查通過

**責任人**: Claude Code
**前置依賴**: Phase 5 完成
**預期時間**: 1-1.5 小時

---

## Debug 模式分解

### 模式 1: status
檢查 dispatch 進程、log、最後狀態
- 是否有進程在運行（PID）
- 最新 log 檔案
- 上次派工的 exit code

### 模式 2: install
驗證安裝完整性
- gsd-dispatch.sh ✓
- dispatch-with-retry.sh ✓
- prompts/ (5 files) ✓
- gsd-config.sh ✓
- ~/.local/bin/gsd-dispatch ✓

### 模式 3: retry
檢查 RETRY 邏輯
- RETRY 環境變數
- dispatch-with-retry.sh 可執行性
- 錯誤分類規則驗證

### 模式 4: logs
查看最新 log
- 列出 log 檔案
- tail -N 最後 N 行
- 搜尋錯誤標記 (err_、timeout、permission)

### 模式 5: check-env
驗證環境
- GSD_ADDON_HOME 設置
- PATH 是否包含 ~/.local/bin
- 檔案可執行性

### 模式 6: diagnose
全面診斷 + 建議修復
- 結合上述 5 種模式
- 輸出診斷報告
- 提供 1-2 個快速修復建議

---

## 輸出格式

```
════════════════════════════════════════════════════════
  GSD-Dispatch Diagnostic Report — status
════════════════════════════════════════════════════════

✓ gsd-dispatch.sh (22KB, executable)
✓ dispatch-with-retry.sh (4KB, executable)
✗ Last dispatch FAILED (exit 1)
  → Log: phase-5-20260819-193338.log
  → Error: err_13bbe49a (OpenCode server error)
  → Suggestion: Check OpenCode status

⚠ RETRY=true not set (default: false)
  → To enable: export RETRY=true

════════════════════════════════════════════════════════
```

---

## 完成後動作

1. 提交 scripts/gsd-dispatch-debug.sh
2. 更新 install.sh 添加 `--verify` 選項
3. 可選：創建 `/gsd:dispatch-debug` skill
4. 更新 DEVELOPMENT-WORKFLOW.md 排障章節

