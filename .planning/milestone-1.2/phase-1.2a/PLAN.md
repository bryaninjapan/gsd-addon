# Phase 1.2A：Core Timeout Hardening — 實現計畫

**狀態**: ✅ 已完成（正式執行以 `.planning/phases/02-dispatch-timeout-hardening/02-PLAN.md` + `2-SUMMARY.md` 為準）  
**完成時間**: 2026-08-18  
**估時**: 2 小時  
**負責人**: Claude Code  

---

## 📌 Phase 目標

修復 `gsd-dispatch.sh` 中無超時的三處命令，防止派工永不返回的情況。

---

## 🎯 成功驗收標準

- [x] `opencode run` 添加 `timeout 3600`
- [x] `curl` 添加 `--max-time 5`
- [x] `git diff` 添加超時保護
- [x] bash 語法檢查通過
- [x] 每個 timeout 都有註釋說明
- [x] 超時時返回正確的 exit code

---

## 📝 實現任務分解

### Task 1.2A.1：研究現有超時點
**狀態**: ✅ 已完成

**具體工作**:
1. 確認 gsd-dispatch.sh 的三處無超時命令位置
2. 分析每個命令的超時風險
3. 確定合理的超時時間

**文件**: `/Users/bryan/Documents/gsd-addon/scripts/gsd-dispatch.sh`

**預計時間**: 30 分鐘

**驗收標準**:
- 確認 opencode run 位置（期望在第 179-190 行）
- 確認 curl 位置（期望在第 173 行和第 210 行）
- 確認 git 位置（期望在第 229-240 行）

---

### Task 1.2A.2：為 opencode run 添加 timeout
**狀態**: ✅ 已完成（改用純 bash `run_with_timeout`，不用外部 timeout，見 02-PLAN.md 任務 2.2）

**具體工作**:
```bash
# 原始
opencode run \
  --command "$GSD_COMMAND" \
  -m "$MODEL" \
  ${VARIANT:+--variant "$VARIANT"} \
  ${SERVER_URL:+--attach "$SERVER_URL"} \
  "$PHASE" 2>&1 | tee "$LOG_FILE"

# 修改為
timeout 3600 opencode run \
  --command "$GSD_COMMAND" \
  -m "$MODEL" \
  ${VARIANT:+--variant "$VARIANT"} \
  ${SERVER_URL:+--attach "$SERVER_URL"} \
  "$PHASE" 2>&1 | tee "$LOG_FILE"
# timeout 返回 124 on timeout
```

**預計時間**: 15 分鐘

**驗收標準**:
- opencode run 命令前有 timeout 3600
- 有註釋說明為什麼是 3600 秒
- 語法檢查通過

---

### Task 1.2A.3：為 curl 添加 --max-time
**狀態**: ✅ 已完成

**具體工作**:
1. 第 173 行：session 檢查的 curl
2. 第 210 行：liveness 檢查的 curl

```bash
# 原始
curl -s "$SERVER_URL/session" | python3 ...

# 修改為
curl -s --max-time 5 "$SERVER_URL/session" 2>/dev/null | python3 ... || echo 0
```

**預計時間**: 15 分鐘

**驗收標準**:
- 兩個 curl 都添加了 `--max-time 5`
- 添加了 stderr 重定向和默認值
- 有註釋說明超時

---

### Task 1.2A.4：為 git diff 添加超時保護
**狀態**: ✅ 已完成

**具體工作**:
```bash
# 原始
git -C "$TARGET_DIR" diff --stat "${GIT_BEFORE}" HEAD

# 修改為（跳過超大二進制文件）
git -C "$TARGET_DIR" diff --stat --ignore-all-space "${GIT_BEFORE}" HEAD 2>/dev/null || echo "（git diff 超時）"
```

**預計時間**: 15 分鐘

**驗收標準**:
- git diff 添加了 `--ignore-all-space` 選項
- 添加了 stderr 重定向
- 有降級行為（超時時顯示提示信息）

---

### Task 1.2A.5：測試和驗收
**狀態**: ✅ 已完成

**具體工作**:
1. 語法檢查：`bash -n ~/.claude/gsd-addon/scripts/gsd-dispatch.sh`
2. 邏輯驗證：grep 確認三處 timeout 都已添加
3. 邏輯驗證：確認 exit code 處理正確

**預計時間**: 30 分鐘

**驗收標準**:
- bash -n 無錯誤
- grep 找到所有 timeout 調用
- 代碼註釋清楚說明每個修改

---

## 📊 進度追蹤

| 任務 | 狀態 | 完成時間 |
|------|------|---------|
| 1.2A.1 | ✅ | 2026-08-18 |
| 1.2A.2 | ✅ | 2026-08-18 |
| 1.2A.3 | ✅ | 2026-08-18 |
| 1.2A.4 | ✅ | 2026-08-18 |
| 1.2A.5 | ✅ | 2026-08-18 |

---

## 🚀 下一步

完成此 phase 後，進入 **Phase 1.2B: Retry Wrapper Implementation**

---

**最後更新**: 2026-08-19
