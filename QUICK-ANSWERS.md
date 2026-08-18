# 快速答案（Q&A）

## ❓ 問題 1：gsd-addon 能不能跟全域 gsd-framework 結合？

### 答案：✅ **完全可以，已修復衝突**

| 方面 | 狀態 | 說明 |
|------|------|------|
| 和平共存 | ✅ | 兩個框架使用不同的環境變數和命令名稱 |
| 命令衝突 | ✅ 已修復 | `gsd-addon-config` 而非 `gsd-config` |
| 配置衝突 | ✅ 已修復 | `GSD_ADDON_HOME` 獨立於 `GSD_GLOBAL_HOME` |
| 工作流衝突 | ❌ 無 | 支持層級查找（項目 → Addon → Framework）|

**修復清單**：
- ✅ install.sh：修正路徑和環境變數
- ✅ gsd-config.sh：使用 `GSD_ADDON_HOME`
- ✅ 命令包裝器：避免覆蓋 gsd-framework 命令

---

## ❓ 問題 2：gsd-test 能不能直接啟動？

### 答案：✅ **可以，立即可用**

```bash
# 直接運行
gsd-test --workflow booking-e2e.workflow.yml

# 帶環境
gsd-test --workflow booking-e2e.workflow.yml --env staging

# 保存結果
gsd-test --workflow booking-e2e.workflow.yml --output results.json
```

**原因**：
- cli.py 是**完整的 Python 可執行程序**
- 已包含所有必要的工作流和環境配置
- 不依賴 bash 配置系統
- 安裝後立即可用

**可用的工作流**：
- `booking-e2e.workflow.yml` ← 示例 workflow
- 可自定義新 workflows

**支持的環境**：
- `local` （默認）
- `docker`
- `staging`
- `production`

---

## ❓ 問題 3：gsd-dispatch 1 和 2 分別是什麼？

### 答案：**Phase 執行命令，數字 = Phase 編號**

```
┌─────────────────────────────────────────────────────┐
│ gsd-dispatch <phase_number> <environment>          │
├─────────────────────────────────────────────────────┤
│ 第 1 個參數：Phase 編號（1, 2, 3, ...）            │
│ 第 2 個參數：環境（local, staging, production）    │
└─────────────────────────────────────────────────────┘
```

### 例子

```bash
gsd-dispatch 1 local       # Phase 1（計畫）   → 本機運行
gsd-dispatch 2 staging     # Phase 2（實作）   → Staging 運行
gsd-dispatch 3 production  # Phase 3（驗證）   → 生產運行
```

### Phase 對應

Phase 編號對應 `.planning/phases/` 中的目錄：

```
.planning/phases/
├── 01-plan/                ← gsd-dispatch 1
│   ├── 01-PLAN.md
│   ├── 01-RESEARCH.md
│   └── ...
├── 02-implement/           ← gsd-dispatch 2
│   ├── 02-PLAN.md
│   ├── implementation/
│   └── ...
├── 03-verify/              ← gsd-dispatch 3
│   ├── 03-PLAN.md
│   └── ...
└── ...
```

### 環境說明

| 環境 | 類型 | 用途 |
|------|------|------|
| `local` | 開發 | 本地開發，快速迭代 |
| `docker` | 容器 | Docker Compose 環境 |
| `staging` | 預發行 | 預發行環境測試 |
| `production` | 生產 | 生產環境（通常唯讀） |

### 工作流

```
Phase 1（local）→ Phase 2（staging）→ Phase 3（production）
   ↓                 ↓                  ↓
 計畫/研究    實作/測試             驗證/監控
```

---

## ❓ 問題 4：gsd-config 會跟 gsd-framework 衝突嗎？

### 答案：✅ **已完全解決，無衝突**

**變更**：
- ❌ 舊：`gsd-config` (會與 gsd-framework 衝突)
- ✅ 新：`gsd-addon-config` (獨立，避免衝突)

### 環境變數隔離

```bash
# gsd-framework 使用
export GSD_GLOBAL_HOME="~/.claude/gsd-framework"
export GSD_FRAMEWORK_HOME="~/.claude/gsd-framework"

# gsd-addon 使用
export GSD_ADDON_HOME="~/.claude/gsd-addon"

# 保持向後兼容（addon 內部）
# export GSD_GLOBAL_HOME="${GSD_ADDON_HOME}"
```

### 命令對應

| 操作 | gsd-addon | gsd-framework |
|------|-----------|---------------|
| 配置管理 | `gsd-addon-config` | `gsd-config` |
| 測試運行 | `gsd-test` | （無直接對應）|
| Phase 執行 | `gsd-dispatch` | 通常手動或通過 phase plan |

### 如何使用（避免衝突）

```bash
# ✅ Addon 操作
gsd-addon-config show                           # 顯示 addon 配置
gsd-test --workflow booking-e2e.workflow.yml    # 運行測試

# ✅ Framework 操作
gsd-config show                                 # 顯示主 gsd 配置
cd .planning/phases/01-plan && gsd review      # 框架命令

# ❌ 不會衝突
# 即使兩個都安裝，也各自獨立運行
```

---

## 📋 修復總結

### 已修復的問題

| 問題 | 位置 | 修復方式 |
|------|------|---------|
| dispatch.sh 缺失 | install.sh:32 | 使改為可選，不再強制要求 |
| 環境變數衝突 | gsd-config.sh:10 | `GSD_GLOBAL_HOME` → `GSD_ADDON_HOME` |
| 命令名稱衝突 | install.sh:99 | `gsd-config` → `gsd-addon-config` |
| 路徑查找錯誤 | install.sh:45 | `.gsd-test` → `gsd-test/.gsd-test` |

### 驗證修復

```bash
# 檢查環境變數
echo $GSD_ADDON_HOME         # ~/.claude/gsd-addon
echo $GSD_GLOBAL_HOME        # ~/.claude/gsd-framework

# 檢查命令
which gsd-addon-config       # ~/.local/bin/gsd-addon-config
which gsd-config             # ~/.local/bin/gsd-config (gsd-framework)

# 測試可用性
gsd-test --workflow booking-e2e.workflow.yml --verbose
```

---

## 🚀 立即行動

```bash
# 1. 推送修復到 GitHub
git add install.sh gsd-config.sh INTEGRATION-GUIDE.md QUICK-ANSWERS.md
git commit -m "fix: resolve gsd-framework integration conflicts"
git push

# 2. 在新環境安裝
cd ~/.claude/gsd-addon
bash install.sh

# 3. 測試三個功能
gsd-test --workflow booking-e2e.workflow.yml
gsd-addon-config show
gsd-dispatch 1 local
```

---

**Summary**: ✅ 完全可以結合 | ✅ 直接啟動 | ✅ 無衝突 | ✅ 已修復
