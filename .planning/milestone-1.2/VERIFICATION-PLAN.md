---
type: "verification-plan"
milestone: "1.2"
status: "Ready for dispatch"
---

# Milestone 1.2 UAT 派工計畫

**目標**: 用 gsd-executor 自動化執行 Milestone 1.2 的 27 個驗收項目

---

## 驗收任務分解

### Phase 2: Timeout Hardening (6 項)

**Task 2.1-2.6**: 驗證 3 層超時保護

```bash
# 2.1: run_with_timeout() 存在
grep -c "run_with_timeout()" scripts/gsd-dispatch.sh

# 2.2: opencode run 3600s 超時
grep -c "run_with_timeout 3600 opencode run" scripts/gsd-dispatch.sh

# 2.3: curl 5s 超時
grep -c "curl.*--max-time 5" scripts/gsd-dispatch.sh

# 2.4: git diff 保護
grep -c "git diff.*--ignore-all-space" scripts/gsd-dispatch.sh

# 2.5: SIGTERM → 124 映射
grep -c "\[[ ]*\$exit_code.*143.*124" scripts/gsd-dispatch.sh

# 2.6: Helper 函式完整
bash -n scripts/gsd-dispatch.sh && echo "✓ syntax check"
```

**驗收標準**: 6/6 grep 命中 + syntax check 通過

---

### Phase 3: Source/Install Drift Fix (6 項)

**Task 3.1-3.6**: 驗證分岔修復 + code review

```bash
# 3.1: prompts/ 有 5 個檔案
[ $(ls ~/.claude/gsd-addon/prompts/ | wc -l) -eq 5 ] && echo "✓"

# 3.2: gsd-dispatch.sh 有 build_prompt()
grep -c "build_prompt()" scripts/gsd-dispatch.sh

# 3.3: extract_phase_section() 存在
grep -c "extract_phase_section()" scripts/gsd-dispatch.sh

# 3.4: 兩份檔案完全一致
diff -q scripts/gsd-dispatch.sh ~/.claude/gsd-addon/scripts/gsd-dispatch.sh && echo "✓ identical"

# 3.5: install.sh 複製 prompts
grep -c "cp.*prompts/" install.sh

# 3.6: Code review 修復（8 項）
grep -c "|| DISPATCH_RC=\|research.*\]\]\|stat.*wc" scripts/gsd-dispatch.sh
```

**驗收標準**: 6/6 檔案/語法檢查通過

---

### Phase 4: Retry Wrapper (7 項)

**Task 4.1-4.7**: 驗證重試機制

```bash
# 4.1: dispatch-with-retry.sh 存在且可執行
[ -x ~/.claude/gsd-addon/scripts/dispatch-with-retry.sh ] && echo "✓"

# 4.2: RETRY=false 路由檢查
gsd-dispatch --help 2>&1 | grep -q "gsd-dispatch.sh" && echo "✓"

# 4.3: RETRY=true 路由檢查
RETRY=true gsd-dispatch --help 2>&1 | grep -q "dispatch-with-retry.sh engaged" && echo "✓"

# 4.4: 錯誤分類邏輯存在
grep -c "_is_non_retryable\|exit_code" ~/.claude/gsd-addon/scripts/dispatch-with-retry.sh

# 4.5: 指數退避邏輯存在
grep -c "INITIAL_DELAY\|2 \*\* (attempt" ~/.claude/gsd-addon/scripts/dispatch-with-retry.sh

# 4.6: Signal handling
grep -c "trap.*exit 130\|INT TERM" ~/.claude/gsd-addon/scripts/dispatch-with-retry.sh

# 4.7: MAX_RETRIES=3
grep -c "MAX_RETRIES=3" ~/.claude/gsd-addon/scripts/dispatch-with-retry.sh
```

**驗收標準**: 7/7 檢查通過

---

### Phase 5: Integration Testing (8 項)

**Task 5.1-5.7**: 驗證端對端功能

```bash
# 5.1: install.sh 成功
cd /Users/bryan/Documents/gsd-addon && bash install.sh 2>&1 | grep -c "✅.*GSD Addon.*installed"

# 5.2: 無重試派工可執行
cd /Users/bryan/Documents/soapwavehealing && unset RETRY && MODE=research gsd-dispatch 1 2>&1 | grep -q "MODE: research" && echo "✓"

# 5.3: RETRY=true 派工啟用 wrapper
export RETRY=true && MODE=research gsd-dispatch 1 2>&1 | grep -q "dispatch-with-retry.sh engaged" && echo "✓"

# 5.4: Checkpoint 完好
find .planning -name "*.md" -type f 2>/dev/null | wc -l

# 5.5: 超時值正確
grep -c "3600\|5" ~/.claude/gsd-addon/scripts/gsd-dispatch.sh

# 5.6: 文檔更新
grep -c "派工排障\|RETRY=true" /Users/bryan/Documents/gsd-addon/DEVELOPMENT-WORKFLOW.md

# 5.7: Milestone 狀態
grep "status.*complete" .planning/STATE.md | grep -i "phase.*0[2-5]"
```

**驗收標準**: 8/8 項目通過

---

## 派工執行

### 方案 1: 串行 UAT 派工

```bash
MODE=execute TARGET_DIR=/Users/bryan/Documents/gsd-addon gsd-dispatch "milestone-1.2"
```

### 方案 2: 並行驗收（4 phases）

```bash
bash run-parallel-uat.sh
```

---

## 預期結果

**通過標準**:
- ✅ Phase 2: 6/6 超時保護驗證通過
- ✅ Phase 3: 6/6 分岔修復驗證通過
- ✅ Phase 4: 7/7 重試機制驗證通過
- ✅ Phase 5: 8/8 集成測試驗證通過

**總計**: 27/27 UAT 項目通過

**失敗標準**:
- 任何 phase 未達 100% 通過
- 派工本身失敗（exit code ≠ 0）
- Log 中出現 `CRITICAL` 錯誤

---

## 驗收報告

完成後產出：
- `.planning/milestone-1.2/VERIFICATION-RESULTS.md` — 詳細結果
- `git commit` — UAT 驗收記錄

---

**執行方式**: 
派工執行此計畫，由 gsd-executor 自動驗收所有 27 項檢查點。
