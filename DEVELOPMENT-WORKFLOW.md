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
