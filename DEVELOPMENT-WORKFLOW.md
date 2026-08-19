# GSD Addon Development Workflow

**Q: 如果修改 gsd-addon，需要重新安裝嗎？**

**A: 取決於修改位置和環境。**

---

## 修改場景

### 場景 1: 本地開發 (推薦方式)

**情況**: 在 `~/Documents/gsd-addon` 修改程式碼，準備測試

**流程**:
```bash
cd ~/Documents/gsd-addon

# 1. 修改程式碼
# vim gsd-test/engine/workflow_engine.py
# vim gsd-test/workflows/booking-e2e.workflow.yml
# ...

# 2. 在 soapwavehealing 測試
cd ~/Documents/soapwavehealing
gsd-test --workflow booking-e2e.workflow.yml

# 3. 修改生效立即反映 ✅ (不需要重新安裝)
```

**原因**: 
- `install.sh` 安裝的是 **symlink** 或 **copy** 指向 `~/.claude/gsd-addon/`
- 如果修改 `~/Documents/gsd-addon` 本身，**本地測試直接讀取源目錄**
- 只要 `gsd-test` 指向正確的源路徑，修改立即生效

### 場景 2: 發佈到 GitHub 後

**情況**: 提交修改到 GitHub，其他人或其他機器拉取

**流程**:
```bash
# 在 ~/Documents/gsd-addon 修改
cd ~/Documents/gsd-addon
vim gsd-test/engine/workflow_engine.py

# 提交到 GitHub
git add -A
git commit -m "feat: improve workflow execution"
git push origin main

# 發佈新版本（可選）
git tag -a v1.0.1 -m "Bug fix: improve error handling"
git push origin v1.0.1

# ======================================

# 其他機器或其他項目更新
cd ~/Documents/gsd-addon
git pull origin main
bash install.sh  # ← 現在需要重新安裝，同步到 ~/.claude/gsd-addon/
```

**重新安裝的原因**:
- GitHub 上的版本 vs 本地 `~/.claude/gsd-addon/` 可能不同步
- `install.sh` 確保兩者一致

### 場景 3: 在 ~/.claude/gsd-addon/ 直接修改 (不推薦)

**情況**: 直接編輯全域安裝目錄

```bash
# ❌ 不推薦
cd ~/.claude/gsd-addon/
vim gsd-test/engine/workflow_engine.py

# 修改生效，但:
# - 本地倉庫 ~/Documents/gsd-addon 不同步
# - GitHub 上沒有記錄
# - 其他機器無法獲得修改
# - 下次 install.sh 會覆蓋修改
```

**結論**: 總是在 `~/Documents/gsd-addon` 修改，不要直接編輯 `~/.claude/gsd-addon/`

---

## 開發工作流 (推薦)

### 步驟 1: 在本地開發環境修改

```bash
cd ~/Documents/gsd-addon

# 修改源代碼
vim gsd-test/engine/workflow_engine.py
vim gsd-test/workflows/booking-e2e.workflow.yml
vim gsd-config.sh
# ... 等等
```

### 步驟 2: 在 soapwavehealing (或其他項目) 測試

```bash
cd ~/Documents/soapwavehealing

# 修改自動生效 ✅
gsd-test --workflow booking-e2e.workflow.yml

# 如果有錯，回到 ~/Documents/gsd-addon 修改並重新測試
```

### 步驟 3: 驗證沒有問題

```bash
# 1. 所有工作流都通過
gsd-test --workflow booking-e2e.workflow.yml ✅
gsd-test --workflow api-smoke.workflow.yml ✅

# 2. 命令都正常
gsd-config verify ✅
gsd-dispatch --help ✅

# 3. 其他項目也能用
cd ~/Documents/another-project
gsd-test --workflow booking-e2e.workflow.yml ✅
```

### 步驟 4: 提交到本地 git

```bash
cd ~/Documents/gsd-addon

git status  # 查看修改
git add -A  # 暫存所有修改
git commit -m "feat: improve workflow engine

- Add support for dynamic job scheduling
- Fix variable interpolation edge cases
- Update documentation

Co-Authored-By: Bryan Lee <gn01968711@gmail.com>"
```

### 步驟 5: 推送到 GitHub

```bash
git push origin main
```

### 步驟 6: 創建 release (如果是重要更新)

```bash
# 標記版本
git tag -a v1.0.1 -m "Release v1.0.1

- Improved workflow execution
- Bug fixes

Ready for production."

# 推送標籤
git push origin v1.0.1
```

### 步驟 7: 其他機器更新 (可選)

```bash
# 在其他機器/其他項目
cd ~/Documents/gsd-addon
git pull origin main
bash install.sh

# 現在 ~/.claude/gsd-addon/ 同步最新版本
```

---

## 版本管理策略

### 本地開發版本

```
~/Documents/gsd-addon/
    ↓ (修改並測試)
    ↓ 
    git commit + git push (to GitHub)
```

**特點**:
- 本地修改立即生效（無需重新安裝）
- 測試通過後提交
- 推送到 GitHub

### 全域安裝版本

```
GitHub gsd-addon repo
    ↓ (git pull)
~/.claude/gsd-addon/
    ↓ (由 install.sh 管理)
    ↓
所有項目使用此版本
```

**特點**:
- 安裝時才更新
- 所有項目共用同一版本
- 推薦定期更新 (`bash install.sh`)

---

## 修改清單

| 修改位置 | 位置 | 需要重新安裝？ | 何時同步？ |
|---------|------|-------------|---------|
| 本地開發 | `~/Documents/gsd-addon/` | ❌ 不需要 | 立即生效 |
| 全域安裝 | `~/.claude/gsd-addon/` | ❌ (自動) | 下次 install.sh |
| GitHub | repo | ✅ 需要 | git pull + install.sh |
| 其他項目 | project/.gsd-test/ | ❌ 不需要 | 立即生效 |

---

## 常見情況

### 情況 A: 修改引擎，在 soapwavehealing 測試

```bash
# 1. 修改
cd ~/Documents/gsd-addon
vim gsd-test/engine/workflow_engine.py

# 2. 測試 (自動讀取最新版本)
cd ~/Documents/soapwavehealing
gsd-test --workflow booking-e2e.workflow.yml ✅

# 3. 成功 → 提交
cd ~/Documents/gsd-addon
git add -A
git commit -m "fix: improve job dependency resolution"
git push origin main
```

**重新安裝？** ❌ 不需要

---

### 情況 B: 修改工作流定義

```bash
# 1. 修改全域工作流
cd ~/Documents/gsd-addon
vim gsd-test/workflows/booking-e2e.workflow.yml

# 2. soapwavehealing 立即看到新定義 ✅
cd ~/Documents/soapwavehealing
gsd-test --workflow booking-e2e.workflow.yml

# 3. 提交
cd ~/Documents/gsd-addon
git add gsd-test/workflows/booking-e2e.workflow.yml
git commit -m "feat: add phone validation to booking workflow"
git push origin main
```

**重新安裝？** ❌ 不需要

---

### 情況 C: 更新 GitHub，其他人要拉取

```bash
# 你的機器
cd ~/Documents/gsd-addon
git push origin main

# ======================================

# 其他人的機器
cd ~/Documents/gsd-addon
git pull origin main     # 同步代碼
bash install.sh          # 同步到全域 ~/.claude/gsd-addon/

# 現在可以用最新版本
gsd-test --workflow booking-e2e.workflow.yml ✅
```

**重新安裝？** ✅ 需要（git pull 之後）

---

### 情況 D: 同時修改多個項目的工作流

```bash
# 修改全域工作流
cd ~/Documents/gsd-addon
vim gsd-test/workflows/booking-e2e.workflow.yml

# 在 soapwavehealing 測試 ✅
cd ~/Documents/soapwavehealing
gsd-test --workflow booking-e2e.workflow.yml

# 切換到 another-project，也自動看到最新版本 ✅
cd ~/Documents/another-project
gsd-test --workflow booking-e2e.workflow.yml

# 兩個項目都用同一個全域工作流，自動同步
```

**重新安裝？** ❌ 不需要

---

## 最佳實踐

✅ **DO**:
1. 在 `~/Documents/gsd-addon` 修改
2. 立即在項目中測試（自動生效）
3. 測試通過後 commit
4. 定期 git push 到 GitHub
5. 創建 release tags (v1.0.0, v1.0.1, etc.)

❌ **DON'T**:
1. 不要直接編輯 `~/.claude/gsd-addon/`
2. 不要跳過本地測試
3. 不要在全域目錄手動修改後就以為完成
4. 不要忘記 git push（修改只在本地）

---

## 總結

| 問題 | 答案 |
|------|------|
| **修改後需要重新安裝嗎？** | ❌ 本地開發不需要；GitHub 更新需要 |
| **何時重新安裝？** | git pull 新版本後 (`bash install.sh`) |
| **本地修改何時生效？** | 立即生效（直接讀取源目錄） |
| **如何分發修改給其他人？** | git push + 他們執行 `bash install.sh` |
| **多個項目能共用修改嗎？** | ✅ 是的，全域 `~/.claude/gsd-addon/` 自動同步 |

---

**開發時在本地修改+測試，GitHub 同步時才需要重新安裝。**

---

## 派工排障與重試機制

### 什麼時候派工失敗？

派工（`gsd-dispatch`）可能在以下情況失敗：
- **參數錯誤**: 無效的 phase 編號、TARGET_DIR 不存在
- **權限問題**: 檔案無讀寫權限、OpenCode 認證過期
- **網路問題**: OpenCode 伺服器暫時故障、curl 連線超時
- **超時**: 派工耗時超過 3600s (opencode) 或 5s (curl 檢查)

### 啟用重試機制

派工內建智能重試機制，可在失敗時自動重試（最多 3 次）。

**啟用方式**:
```bash
# 預設（無重試）
gsd-dispatch <phase>

# 啟用重試（自動重試最多 3 次）
RETRY=true gsd-dispatch <phase>
```

### 重試策略

| 失敗類型 | 自動重試？ | 理由 |
|---------|----------|------|
| 參數錯誤 (usage/arg) | ❌ | 快速失敗，允許修正 |
| 權限錯誤 (permission denied) | ❌ | 環境配置問題，重試無效 |
| 用户中斷 (Ctrl+C) | ❌ | 用户明確中止 |
| 超時 (exit 124) | ✅ | 暫時故障，可能恢復 |
| OpenCode 伺服器錯誤 (err_xxxxxxxx) | ✅ | 伺服器暫時故障 |
| 網路失敗 (curl failed) | ✅ | 網路抖動 |

**重試延遲**:
```
嘗試 1 → 失敗 → 延遲 1s
嘗試 2 → 失敗 → 延遲 2s
嘗試 3 → 失敗 → 放棄
```

### 超時設置

派工包含三層超時保護，防止永久卡住：

| 操作 | 超時時限 | 原因 |
|------|--------|------|
| `opencode run` | 3600s (1小時) | 派工通常 5-30 分鐘，給予緩衝 |
| `curl` (檢查) | 5s | 網路檢查通常 <1s |
| `git diff` | 無明確超時 | git repo 無響應時降級訊息 |

超時不會誤觸發：正常派工遠小於 3600s，網路檢查遠小於 5s。

### 常見錯誤與排查

#### 錯誤 1: err_xxxxxxxx (OpenCode 伺服器錯誤)

```
ERROR: err_13bbe49a: Unexpected server error
```

**原因**: OpenCode 伺服器暫時故障（網路抖動、過載等）

**排查**:
```bash
# 1. 查看 log
tail -100 ~/.claude/gsd-addon/.planning/soldier-logs/phase-*.log

# 2. 啟用重試
RETRY=true gsd-dispatch <phase>

# 3. 如果重試 3 次後仍失敗，稍等後重試
```

#### 錯誤 2: Permission denied

```
ERROR: permission denied: ~/.claude/gsd-addon/scripts/dispatch-with-retry.sh
```

**原因**: 檔案缺少執行權限

**排查**:
```bash
# 檢查檔案權限
ls -la ~/.claude/gsd-addon/scripts/dispatch-with-retry.sh

# 修復（重新安裝）
bash ~/Documents/gsd-addon/install.sh
```

#### 錯誤 3: Timeout (exit 124)

```
[retry] attempt 1/3 failed (exit 124). Retrying in 1s...
```

**原因**: 派工超過 3600s（罕見，通常表示伺服器完全無響應）

**排查**:
```bash
# 1. 檢查 OpenCode 伺服器狀態
# 2. 查看 log 最後部分看是否卡在某個操作
tail -50 ~/.claude/gsd-addon/.planning/soldier-logs/phase-*.log | grep -A5 "超時\|timeout"

# 3. 使用 RETRY=true 重試
RETRY=true gsd-dispatch <phase>
```

### 如何排查 Log 檔案

派工的完整執行記錄存放在 log 檔案中：

```bash
# 查看最新 log
LATEST_LOG=$(ls -t ~/.claude/gsd-addon/.planning/soldier-logs/phase-*.log | head -1)
tail -100 "$LATEST_LOG"

# 搜尋特定錯誤
grep -n "ERROR\|err_\|timeout\|permission" "$LATEST_LOG"

# 查看特定 phase 的 log
ls -lh ~/.claude/gsd-addon/.planning/soldier-logs/phase-<N>-*.log
```

**Log 檔案位置**:
```
~/.claude/gsd-addon/.planning/soldier-logs/phase-N-YYYYMMDD-HHMMSS.log
```

### 最佳實踐

✅ **DO**:
1. 派工失敗時先查看 log
2. 如果是伺服器錯誤，用 `RETRY=true` 重試
3. 超時時稍等後重試
4. 定期更新 `bash install.sh` 保持最新版本

❌ **DON'T**:
1. 不要在參數錯誤時重試（快速失敗更好）
2. 不要無限重試（3 次失敗後檢查根本原因）
3. 不要直接編輯 `dispatch-with-retry.sh`（改用 source repo）
4. 不要忽略 permission 錯誤（重新安裝是最快的修復）

---

**派工失敗時：先查 log → 判斷失敗類型 → 決定是否重試**
