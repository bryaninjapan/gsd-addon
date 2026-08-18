---
phase: 1
name: "GitHub 推送與驗證"
status: "In Progress"
timeline: "2026-08-18 ~ 2026-08-22"
---

# Phase 1：GitHub 推送與驗證

**目標**: 將 gsd-addon 推送到 GitHub 並驗證完整功能

**成功標準**:
- [x] 代碼已推送 GitHub
- [ ] 新環境安裝無誤
- [ ] 生產驗證（soapwavehealing）成功
- [ ] 所有文檔連結有效

**責任人**: You  
**預期時間**: 5 天

---

## 任務分解

### 任務 1.1：GitHub 推送準備 ✅ 完成

**負責人**: You  
**時間**: 2026-08-18 (今天)

#### 檢查清單

- [x] 初始化 git 倉庫
- [x] 編寫完整文檔（README、GLOBAL-SETUP、集成指南等）
- [x] 修復所有衝突（dispatch.sh 缺失、路徑問題等）
- [x] 補完 dispatch 系統（gsd-dispatch.sh、gsd-permission-audit.sh）
- [x] 補完文檔（DISPATCH-COMPLETE-GUIDE.md、SCHEDULE-WAKEUP-GUIDE.md）
- [x] 2 個完整 git commits（初始化 + dispatch 補完）
- [x] Working tree clean（無未提交改動）

#### 產出

```
✅ 2 commits 已創建
   - 0d455ee Initial commit: GSD Addon test orchestration and dispatch framework
   - 5d4c262 feat: add complete dispatch system with dynamic scheduling

✅ 文件結構：
   ├─ scripts/
   │  ├─ gsd-dispatch.sh              (755 行, 派工核心)
   │  └─ gsd-permission-audit.sh      (218 行, 權限審計)
   ├─ gsd-test/
   │  └─ .gsd-test/                   (完整的 test framework)
   ├─ dispatch/
   │  ├─ README.md                    (更新)
   │  └─ DISPATCH-COMPLETE-GUIDE.md   (550+ 行)
   ├─ .planning/
   │  ├─ PROJECT.md                   (本文件)
   │  └─ ROADMAP.md
   └─ 其他文檔 (README, 集成指南等)
```

---

### 任務 1.2：GitHub 推送執行 ⏳ 待做

**負責人**: You  
**時間**: 2026-08-19  
**預期耗時**: 30 分鐘

#### 步驟

1. **創建或檢查 GitHub 倉庫**

   ```bash
   # 假設使用 GitHub 上已有的倉庫
   # 或創建新倉庫：https://github.com/new
   
   # 設置遠程
   git remote add origin https://github.com/yourusername/gsd-addon.git
   # 或更新現有
   git remote set-url origin https://github.com/yourusername/gsd-addon.git
   ```

2. **推送代碼**

   ```bash
   git push -u origin main
   ```

3. **驗證 GitHub 正確**

   - [ ] 代碼已上線
   - [ ] 2 個 commits 可見
   - [ ] 所有檔案顯示正確
   - [ ] .gitignore 生效（無 node_modules、.env 等）

#### 交付物

- [x] GitHub 倉庫公開
- [x] main 分支已推送
- [x] README 在 GitHub 正確顯示
- [x] 代碼可克隆

---

### 任務 1.3：本地驗證 ⏳ 待做

**負責人**: You  
**時間**: 2026-08-19  
**預期耗時**: 1 小時

#### 驗證流程

1. **新環境安裝測試**

   ```bash
   # 在臨時目錄測試
   cd /tmp
   git clone https://github.com/yourusername/gsd-addon.git gsd-addon-test
   cd gsd-addon-test
   
   # 運行安裝
   bash install.sh
   
   # 檢查輸出
   # 預期: ✅ GSD Addon Framework installed successfully!
   ```

2. **驗證全局命令**

   ```bash
   # PATH 需要包含 ~/.local/bin
   export PATH="$PATH:$HOME/.local/bin"
   
   # 測試 gsd-test
   which gsd-test
   gsd-test --workflow booking-e2e.workflow.yml --verbose
   
   # 預期：workflow 執行，產出結果
   
   # 測試 gsd-dispatch
   cd /path/to/test/project
   ~/.local/bin/gsd-dispatch.sh 1 execute
   
   # 預期：派工腳本執行，不出錯
   
   # 測試 gsd-addon-config
   gsd-addon-config show
   
   # 預期：顯示配置
   ```

3. **驗證文檔**

   ```bash
   # 檢查所有文檔連結有效
   cat README.md | grep "\.md" | head -10
   
   # 開啟並檢查關鍵文檔
   cat dispatch/DISPATCH-COMPLETE-GUIDE.md | head -50
   cat SCHEDULE-WAKEUP-GUIDE.md | head -50
   ```

4. **檢查清單**

   - [ ] install.sh 執行成功（無錯誤）
   - [ ] gsd-test 命令可用
   - [ ] gsd-dispatch.sh 可執行
   - [ ] gsd-permission-audit.sh 可執行
   - [ ] gsd-addon-config 可用
   - [ ] 所有文檔連結有效
   - [ ] 無缺失的依賴

#### 交付物

- [ ] 安裝驗證通過
- [ ] 所有命令可用
- [ ] 文檔完整

---

### 任務 1.4：soapwavehealing 生產驗證 ⏳ 待做

**負責人**: You  
**時間**: 2026-08-19 ~ 2026-08-20  
**預期耗時**: 2 小時

#### 驗證項目：soapwavehealing

該項目已初始化 GSD 結構，用於驗證 gsd-addon 的實際功能。

#### 測試 1：gsd-test 工作流執行

```bash
cd ~/Documents/soapwavehealing

# 運行測試工作流
gsd-test --workflow booking-e2e.workflow.yml --verbose

# 期望：
# ✓ workflow 執行成功
# ✓ 產出 results.json 或類似結果檔
# ✓ 無錯誤
```

**檢查清單**:
- [ ] workflow 解析成功
- [ ] 環境變數正確加載
- [ ] 所有 jobs 執行
- [ ] 結果記錄正確

#### 測試 2：gsd-dispatch 派工

```bash
cd ~/Documents/soapwavehealing

# 嘗試派工（不實際執行 opencode，只測試腳本邏輯）
TARGET_DIR=. bash ~/.local/bin/gsd-dispatch.sh 1 --dry-run 2>&1 | head -30

# 或實際派工到 opencode（需要 opencode 已安裝）
TARGET_DIR=. ~/.local/bin/gsd-dispatch.sh 1 execute

# 期望：
# ✓ 派工腳本運行成功
# ✓ 無權限錯誤
# ✓ log 文件生成
# ✓ SUMMARY.md 產出
```

**檢查清單**:
- [ ] 派工腳本啟動
- [ ] 環境變數正確設置
- [ ] 無自動拒權錯誤
- [ ] git commit 記錄

#### 測試 3：ScheduleWakeup 動態派工

```bash
# 在 Claude Code 中設置 1 分鐘後派工
ScheduleWakeup({
  delaySeconds: 60,
  prompt: "cd ~/Documents/soapwavehealing && gsd-test --workflow booking-e2e.workflow.yml",
  reason: "Test ScheduleWakeup integration"
})

# 等待 1 分鐘，驗證派工自動執行

# 期望：
# ✓ 1 分鐘後自動執行
# ✓ workflow 成功運行
# ✓ 無人工干預
```

**檢查清單**:
- [ ] ScheduleWakeup 觸發成功
- [ ] 派工自動執行
- [ ] 結果正確記錄

#### 交付物

- [ ] gsd-test 驗證通過
- [ ] gsd-dispatch 驗證通過
- [ ] ScheduleWakeup 驗證通過
- [ ] 生產環境無問題

---

### 任務 1.5：文檔完善 ⏳ 待做

**負責人**: You  
**時間**: 2026-08-21  
**預期耗時**: 1 小時

#### 更新清單

1. **README.md**
   - [ ] 更新 GitHub URL
   - [ ] 驗證所有連結可點擊
   - [ ] 補充「已驗證的運行時」
   - [ ] 新增「安裝驗證」小節

2. **INTEGRATION-GUIDE.md**
   - [ ] 確認所有路徑正確
   - [ ] 驗證命令示例可運行

3. **dispatch/README.md**
   - [ ] 更新使用範例路徑
   - [ ] 補充「GitHub 最新版本」連結

4. **新增「已知限制」**
   ```markdown
   ## 已知限制
   
   - ScheduleWakeup 當前只支持 Claude Code（其他運行時規劃中）
   - 跨項目派工需要手動設置 .opencode/opencode.json 白名單（gsd-permission-audit.sh 自動化）
   - OpenCode 無頭模式的已知 bug 已有 workaround（見 DISPATCH-COMPLETE-GUIDE.md）
   ```

5. **新增「貢獻指南」**
   - [ ] 建立 CONTRIBUTING.md
   - [ ] 記載派工系統擴展指南（如何為新運行時添加支持）

#### 交付物

- [ ] README 完善
- [ ] 所有連結驗證
- [ ] 新增指南完成
- [ ] v1.0 版本確認

---

## 驗收標準

### ✅ 代碼層面
- [x] 2 個完整 commits
- [ ] GitHub 上線
- [ ] 新環境安裝成功
- [ ] 無依賴丟失

### ✅ 功能層面
- [ ] gsd-test 可用
- [ ] gsd-dispatch 可用
- [ ] ScheduleWakeup 可用
- [ ] 跨項目派工無權限問題

### ✅ 文檔層面
- [x] 所有文檔寫完
- [ ] GitHub 顯示正確
- [ ] 所有連結有效
- [ ] 使用範例可運行

---

## 依賴與風險

### 依賴
- ✅ gsd-framework 已安裝（用於生產驗證）
- ✅ soapwavehealing 項目已初始化
- ✅ OpenCode 已安裝（用於派工驗證）

### 風險
| 風險 | 影響 | 緩解 |
|------|------|------|
| GitHub 連接失敗 | 高 | 檢查網絡，使用 HTTPS/SSH |
| OpenCode 無法連接 | 中 | 使用 --dry-run 模式測試 |
| 文檔連結錯誤 | 低 | 自動化連結檢查 |

---

## 進度追蹤

**當前狀態**: Phase 1 進行中 (2026-08-18)

### 完成度

```
準備階段  ████████████████████ 100% ✅
推送階段  ░░░░░░░░░░░░░░░░░░░░   0% ⏳
驗證階段  ░░░░░░░░░░░░░░░░░░░░   0% ⏳
完善階段  ░░░░░░░░░░░░░░░░░░░░   0% ⏳

總進度: ████████░░░░░░░░░░░░ 25%
```

### 下一步

1. **明天 (2026-08-19)**
   - [ ] 推送到 GitHub
   - [ ] 本地安裝驗證
   - [ ] 開始生產驗證

2. **後天 (2026-08-20)**
   - [ ] 完成 soapwavehealing 驗證
   - [ ] 所有測試通過

3. **2026-08-21**
   - [ ] 文檔完善
   - [ ] 最終驗收

---

## 相關文件

- [PROJECT.md](../PROJECT.md) — 項目總體規劃
- [ROADMAP.md](../ROADMAP.md) — 整體路線圖
- [README.md](../../README.md) — 項目概述
- [DISPATCH-COMPLETE-GUIDE.md](../../dispatch/DISPATCH-COMPLETE-GUIDE.md) — 派工完整指南

---

**Phase 1 - GitHub 推送與驗證**

開始日期: 2026-08-18  
預期完成: 2026-08-22  
狀態: 進行中 ⏳
