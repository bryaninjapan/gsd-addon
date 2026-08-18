# GSD Addon ↔ GSD Framework 集成指南

## 🎯 概述

GSD Addon 是 GSD Framework 的**補充工具**，提供：
- ✅ **獨立的測試編排框架** (gsd-test)
- ✅ **自動化 dispatch 系統** (可選)
- ✅ **無衝突的共存** 與 gsd-framework

兩者可以在同一個環境中無縫協作。

---

## 📦 安裝檢查清單

```bash
# 1. 驗證 gsd-framework 已安裝
ls -d ~/.claude/gsd-framework   # ✅ 應存在

# 2. 安裝 gsd-addon
cd /path/to/gsd-addon
bash install.sh

# 3. 驗證 PATH
echo $PATH | grep .local/bin    # ✅ 應包含 ~/.local/bin
```

---

## ⚠️ 避免衝突：命名約定

為了避免命令衝突，gsd-addon 使用不同的環境變數和命令名稱：

### 環境變數

| 環境變數 | 來源 | 用途 |
|---------|------|------|
| `GSD_ADDON_HOME` | gsd-addon | Addon 框架主目錄 |
| `GSD_GLOBAL_HOME` | gsd-framework | GSD 主框架目錄 |

### 全局命令

| 命令 | 來源 | 用途 |
|------|------|------|
| `gsd-test` | gsd-addon | 運行測試工作流 |
| `gsd-dispatch` | gsd-addon | 運行 phase dispatch |
| `gsd-addon-config` | gsd-addon | 管理 addon 配置（避免衝突）|
| `gsd-config` | gsd-framework | 管理主 GSD 配置 |

### 配置檔案

| 檔案 | 位置 | 用途 |
|------|------|------|
| `gsd-config.sh` | gsd-addon | Addon 配置系統 |
| `gsd-config.yaml` | gsd-framework | 主框架配置 |
| `.gsd-test.config` | 專案根目錄 | 專案級別覆蓋（兩者共用）|

---

## 🚀 使用指令

### 1️⃣ 運行測試（gsd-test）

```bash
# 基本用法
gsd-test --workflow booking-e2e.workflow.yml

# 指定環境
gsd-test --workflow booking-e2e.workflow.yml --env staging

# 保存結果
gsd-test --workflow booking-e2e.workflow.yml --output results.json

# 覆蓋變數
gsd-test --workflow booking-e2e.workflow.yml --var username="testuser"
```

**工作流位置**（優先級）：
1. 專案級別：`my-project/.gsd-test/workflows/` ← 優先
2. Addon 全局：`~/.claude/gsd-addon/gsd-test/workflows/`

### 2️⃣ 運行 Dispatch（gsd-dispatch）

```bash
# Phase 1, 本機環境
gsd-dispatch 1 local

# Phase 2, staging 環境
gsd-dispatch 2 staging

# Phase 3, 生產環境
gsd-dispatch 3 production
```

數字 = GSD Phase（`.planning/phases/01-*/` 中的目錄編號）  
參數 = 環境名稱

### 3️⃣ 管理 Addon 配置

```bash
# 顯示 addon 配置
gsd-addon-config show

# 驗證安裝
gsd-addon-config verify

# 初始化專案
gsd-addon-config init
```

---

## 🔀 配置優先級

當運行 `gsd-test` 或 `gsd-dispatch` 時，配置按以下順序加載：

```
1. 環境變數 (highest priority)
   ↓
2. 專案配置 (.gsd-test.config)
   ↓
3. Addon 全局配置 (~/.claude/gsd-addon/gsd-config.sh)
   ↓
4. 預設值 (lowest priority)
```

**例子**：

```bash
# 全局 addon 配置
~/.claude/gsd-addon/gsd-config.sh:
  export GSD_TEST_ENV="local"
  export GSD_DISPATCH_TARGET="opencode"

# 專案覆蓋
my-project/.gsd-test.config:
  export GSD_TEST_ENV="staging"      # ✓ 覆蓋全局設置
  # GSD_DISPATCH_TARGET 保持全局值

# 運行時環境變數（最高優先級）
export GSD_TEST_ENV="production"
gsd-test --workflow test.yml  # 使用 production 環境
```

---

## 📁 專案結構

### Addon 全局安裝

```
~/.claude/gsd-addon/                  ← GSD_ADDON_HOME
├── gsd-config.sh                     # Addon 配置管理
├── gsd-test/                         # 測試編排框架
│   ├── cli.py                        # CLI 工具
│   ├── engine/
│   │   ├── workflow_engine.py
│   │   ├── context.py
│   │   ├── tools.py
│   │   └── __init__.py
│   ├── workflows/
│   │   └── booking-e2e.workflow.yml
│   ├── environments/
│   │   └── environments.yaml
│   └── README.md
├── dispatch/                         # Dispatch 系統（可選）
│   └── README.md
└── GLOBAL-SETUP.md

~/.local/bin/                         # 全局命令
├── gsd-test
├── gsd-dispatch
└── gsd-addon-config
```

### 專案級別

```
my-project/
├── .gsd-test/                       # 可選：專案特定配置
│   ├── workflows/                   # 專案特定 workflows
│   │   └── my-test.workflow.yml
│   └── environments/                # 專案特定環境配置
│       └── environments.yaml
├── .gsd-test.config                 # 專案配置（如果需要覆蓋）
├── .planning/
│   ├── phases/
│   │   ├── 01-plan/
│   │   ├── 02-implement/
│   │   └── ...
│   └── ...
└── ...
```

---

## 🔍 診斷和故障排除

### 檢查安裝

```bash
# 驗證兩個框架都已安裝
ls -d ~/.claude/gsd-addon      # GSD Addon
ls -d ~/.claude/gsd-framework  # GSD Framework

# 檢查命令可用性
which gsd-test
which gsd-dispatch
which gsd-addon-config
which gsd-config
```

### 測試 gsd-test

```bash
# 運行示例 workflow
gsd-test --workflow booking-e2e.workflow.yml --verbose

# 檢查工作流查找
echo "Checking workflow locations:"
ls ~/.claude/gsd-addon/gsd-test/workflows/
ls my-project/.gsd-test/workflows/ 2>/dev/null || echo "  (no project workflows)"
```

### 測試 gsd-dispatch

```bash
# 檢查 phase 目錄
ls -d .planning/phases/*/

# 嘗試 dispatch（dry-run）
gsd-dispatch 1 local --dry-run  # 如果支持
```

### 配置問題

```bash
# 檢查 addon 配置
gsd-addon-config show

# 檢查主框架配置
gsd-config show

# 檢查專案配置
cat my-project/.gsd-test.config 2>/dev/null || echo "No project config"
```

---

## 🤝 Addon ↔ Framework 交互

### gsd-test 與 gsd-framework 的關係

| 方面 | gsd-test | gsd-framework |
|------|----------|---------------|
| **用途** | 自動化測試工作流 | 全體 GSD 方法論 |
| **命令** | `gsd-test` | `gsd-config`, `gsd dispatch` |
| **配置** | `.gsd-test.config`, `gsd-config.sh` | `.planning/`, `gsd-config.yaml` |
| **工作流** | YAML 定義測試 | Phase-based 計畫 |
| **獨立性** | ✅ 可單獨使用 | ⚠️ 預期完整環境 |

### 最佳實踐

✅ **推薦做法**：
- 在 gsd-framework phase plans 中定義測試
- 使用 gsd-test 自動運行這些測試
- 在 `.planning/phases/*/` 中記錄結果

❌ **避免**：
- 不要同時使用 `gsd-config` 和 `gsd-addon-config` 管理同一個變數
- 不要在 gsd-framework 的 phase plan 中直接調用 gsd-addon （通過 workflow 間接調用）
- 不要依賴 gsd-test 進行主要的 phase 執行（這是 gsd-framework 的職責）

---

## 📚 相關文檔

- **[GSD Addon: GLOBAL-SETUP.md](./GLOBAL-SETUP.md)** — 詳細安裝和配置
- **[GSD Addon: TEST-ORCHESTRATION-GUIDE.md](./gsd-test/.gsd-test/TEST-ORCHESTRATION-GUIDE.md)** — 測試框架完整文檔
- **[GSD Framework 文檔](~/.claude/gsd-framework/)** — 主 GSD 方法論

---

## ✨ 快速開始

```bash
# 1. 安裝 gsd-addon（假設 gsd-framework 已安裝）
bash install.sh

# 2. 初始化專案
gsd-addon-config init

# 3. 運行測試
gsd-test --workflow booking-e2e.workflow.yml

# 4. 在 gsd-framework phase plan 中集成
# 編輯 .planning/phases/XX-*/XX-PLAN.md
# 添加任務: "Run tests: gsd-test --workflow booking-e2e.workflow.yml"

# 5. 執行 phase
gsd-dispatch 1 local
```

---

**Made with ❤️ for seamless GSD integration**

GSD Addon v1.0.0 | Compatible with gsd-framework
