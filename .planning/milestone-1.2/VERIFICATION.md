---
milestone: "1.2"
name: "派工系統韌性與重試機制"
status: "UAT 進行中"
started: "2026-08-19"
---

# Milestone 1.2 UAT 驗收清單

**目標**: 驗證 Milestone 1.2 的四個 Phase 在實際使用中達到目標

---

## Phase 2: Timeout Hardening

| # | 驗收項目 | 預期結果 | 狀態 | 備註 |
|----|---------|--------|------|------|
| 2.1 | `run_with_timeout` helper 存在 | 函式定義在 gsd-dispatch.sh 中 | ⏳ | |
| 2.2 | opencode run 有超時保護 | `timeout 3600 opencode run` | ⏳ | |
| 2.3 | curl 有超時保護 | `--max-time 5` 設置 | ⏳ | |
| 2.4 | git diff 有保護 | `--ignore-all-space` + 降級訊息 | ⏳ | |
| 2.5 | 超時回傳 exit 124 | SIGTERM → 124 映射 | ⏳ | |
| 2.6 | 無超時情況下回傳原始碼 | Success → 0, Failure → original code | ⏳ | |

**UAT**: 執行派工，檢查 exit code

---

## Phase 3: Source/Install Drift Fix

| # | 驗收項目 | 預期結果 | 狀態 | 備註 |
|----|---------|--------|------|------|
| 3.1 | prompts/ 目錄存在 | 5 個範本：execute/plan/research/check/revise | ⏳ | |
| 3.2 | gsd-dispatch.sh 是 prompts-based | `build_prompt()` 函式存在 | ⏳ | |
| 3.3 | extract_phase_section() 存在 | ROADMAP 動態注入 | ⏳ | |
| 3.4 | Source 與安裝副本一致 | `diff scripts/gsd-dispatch.sh ~/.claude/gsd-addon/scripts/gsd-dispatch.sh` | ⏳ | |
| 3.5 | install.sh 複製 prompts/ | 缺失時 exit 1 | ⏳ | |
| 3.6 | Code Review 修復已應用 | 8 項修復（CR-01/02/03, WR-01-05） | ⏳ | |

**UAT**: `bash install.sh` 驗證，檢查 code review 修復

---

## Phase 4: Retry Wrapper

| # | 驗收項目 | 預期結果 | 狀態 | 備註 |
|----|---------|--------|------|------|
| 4.1 | dispatch-with-retry.sh 存在 | 檔案可執行，4.3KB | ⏳ | |
| 4.2 | RETRY=false (default) 路由 | gsd-dispatch → gsd-dispatch.sh | ⏳ | |
| 4.3 | RETRY=true 路由 | gsd-dispatch → dispatch-with-retry.sh | ⏳ | |
| 4.4 | 錯誤分類正確 | 參數錯誤不重試，伺服器錯誤重試 | ⏳ | |
| 4.5 | 指數退避延遲 | 1s → 2s → 4s（MAX_RETRIES=3） | ⏳ | |
| 4.6 | Ctrl+C 立即退出 | Signal handling 正確（exit 130） | ⏳ | |
| 4.7 | Log 記錄重試 | `[retry] attempt N/3` 訊息 | ⏳ | |

**UAT**: `RETRY=true gsd-dispatch <phase>` 測試，檢查 log

---

## Phase 5: Integration Testing

| # | 驗收項目 | 預期結果 | 狀態 | 備註 |
|----|---------|--------|------|------|
| 5.1 | install.sh 成功 | 所有組件安裝，exit 0 | ⏳ | |
| 5.2 | 無重試基線測試 | `gsd-dispatch` 行為不變 | ⏳ | |
| 5.3 | RETRY=true 功能 | 派工失敗時自動重試 | ⏳ | |
| 5.4 | Checkpoint 無衝突 | .planning/ 檔案完好，各次重試獨立 log | ⏳ | |
| 5.5 | 超時設置合理 | 3600s/5s 不誤觸發 | ⏳ | |
| 5.6 | DEVELOPMENT-WORKFLOW.md 更新 | 派工排障章節完整 | ⏳ | |
| 5.7 | Milestone 完成 | 所有 phase 標記完成 | ⏳ | |

**UAT**: 實際派工測試 + 文檔檢查

---

## 整體驗收標準

✅ **必須通過**:
- [ ] Phase 2: 所有超時保護有效（exit 124 正確）
- [ ] Phase 3: source 與安裝副本完全一致，code review 修復全部應用
- [ ] Phase 4: RETRY=true 正確路由到 wrapper，錯誤分類準確
- [ ] Phase 5: 派工成功，checkpoint 無衝突，文檔完整

✅ **成功標準**:
- 4/4 phases 驗收通過
- 所有 UAT 項目 ✅ 完成
- 無已知 blocker
- 可進入 Phase 6（Debug Tool）

---

## 驗收方式

按 Phase 順序執行 UAT：

1. **Phase 2**: 語法檢查 + timeout 行為測試
2. **Phase 3**: install.sh 驗證 + 代碼對比
3. **Phase 4**: RETRY 路由 + 重試機制測試
4. **Phase 5**: 派工功能測試 + 文檔檢查

---

## 開始 UAT

狀態: 準備進行  
開始時間: 2026-08-19 20:30  
責任人: Bryan (User)  
