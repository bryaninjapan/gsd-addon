# Phase 1.2B：Retry Wrapper Implementation — 實現計畫

**狀態**: 📋 規劃中  
**估時**: 3.5 小時  
**負責人**: Claude Code  
**前置依賴**: Phase 1.2A 必須完成  

---

## 📌 Phase 目標

創建 `dispatch-with-retry.sh` wrapper，具備智能重試、錯誤分類和優雅的環境變數集成。

---

## 🎯 成功驗收標準

- [x] dispatch-with-retry.sh 創建成功
- [x] 實現 3 次重試策略（指數退避）
- [x] 正確區分三類錯誤（參數/權限/派工失敗）
- [x] 支持 RETRY=true 環境變數
- [x] 支持信號處理（Ctrl+C）
- [x] 完整的日誌記錄

---

## 📝 實現任務分解

### Task 1.2B.1：設計 Wrapper 邏輯
**狀態**: ⏳ 待執行

**具體工作**:
1. 確認重試策略（3 次，初始延遲 2s，指數退避）
2. 確認錯誤分類邏輯（如何區分三類錯誤）
3. 確認信號處理（Ctrl+C 時立即退出，不重試）
4. 確認日誌輸出格式

**預計時間**: 30 分鐘

**驗收標準**:
- 明確的重試公式（delay = initial_delay ** (attempt - 1)）
- 明確的錯誤分類規則（基於日誌檔案內容）
- 明確的信號處理方式

---

### Task 1.2B.2：創建 dispatch-with-retry.sh
**狀態**: ⏳ 待執行

**具體工作**:
1. 創建 `/Users/bryan/Documents/gsd-addon/scripts/dispatch-with-retry.sh`
2. 實現重試邏輯（3 次，指數退避）
3. 實現錯誤分類（檢查日誌檔案內容）
4. 實現信號處理（trap SIGINT/SIGTERM）
5. 實現日誌輸出（每次重試都記錄）

**文件位置**: 
- 源: `/Users/bryan/Documents/gsd-addon/scripts/dispatch-with-retry.sh`
- 安裝: `~/.claude/gsd-addon/scripts/dispatch-with-retry.sh`

**預計時間**: 1 小時

**驗收標準**:
- 腳本可執行
- bash -n 語法檢查通過
- 模擬測試能正確重試

---

### Task 1.2B.3：修改 ~/.local/bin/gsd-dispatch 支持環境變數
**狀態**: ⏳ 待執行

**具體工作**:
修改全域 `gsd-dispatch` 命令以支持 `RETRY=true` 環境變數：

```bash
# 原始
#!/bin/bash
export GSD_ADDON_HOME="${GSD_ADDON_HOME:-$HOME/.claude/gsd-addon}"
exec "$GSD_ADDON_HOME/scripts/gsd-dispatch.sh" "$@"

# 修改為
#!/bin/bash
export GSD_ADDON_HOME="${GSD_ADDON_HOME:-$HOME/.claude/gsd-addon}"
RETRY="${RETRY:-false}"

if [[ "$RETRY" == "true" ]]; then
  exec "$GSD_ADDON_HOME/scripts/dispatch-with-retry.sh" "$@"
else
  exec "$GSD_ADDON_HOME/scripts/gsd-dispatch.sh" "$@"
fi
```

**預計時間**: 30 分鐘

**驗收標準**:
- ~/.local/bin/gsd-dispatch 添加了環境變數檢查
- 邏輯清晰（if/else 結構）
- 有註釋說明

---

### Task 1.2B.4：修改 install.sh 確保 gsd-dispatch-with-retry.sh 被複製
**狀態**: ⏳ 待執行

**具體工作**:
檢查 install.sh 是否會自動複製 dispatch-with-retry.sh 到 ~/.claude/gsd-addon/scripts/

```bash
# 應該有類似於
cp scripts/dispatch-with-retry.sh ~/.claude/gsd-addon/scripts/
chmod +x ~/.claude/gsd-addon/scripts/dispatch-with-retry.sh
```

**預計時間**: 15 分鐘

**驗收標準**:
- install.sh 包含複製 dispatch-with-retry.sh 的邏輯
- 複製後設置可執行權限
- 有錯誤檢查

---

### Task 1.2B.5：測試 Wrapper 邏輯
**狀態**: ⏳ 待執行

**具體工作**:
1. 語法檢查：bash -n dispatch-with-retry.sh
2. 模擬測試：創建測試腳本模擬失敗
3. 驗證環境變數邏輯：RETRY=true 和 RETRY=false
4. 驗證信號處理：Ctrl+C 立即退出

**預計時間**: 1 小時

**驗收標準**:
- bash -n 無錯誤
- 能正確識別並分類錯誤
- 環境變數邏輯工作正常
- 信號處理有效

---

## 📊 進度追蹤

| 任務 | 狀態 | 完成時間 |
|------|------|---------|
| 1.2B.1 | ⏳ | — |
| 1.2B.2 | ⏳ | — |
| 1.2B.3 | ⏳ | — |
| 1.2B.4 | ⏳ | — |
| 1.2B.5 | ⏳ | — |

---

## 🚀 下一步

完成此 phase 後，進入 **Phase 1.2C: Integration & Testing**

---

**最後更新**: 2026-08-19
