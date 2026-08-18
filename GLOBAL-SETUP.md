# GSD Global Framework Setup Guide

**目標**: 把 dispatch.sh 和 gsd-test 做成全局工具，所有項目都能使用

---

## 📋 安裝步驟

### 步驟 1：複製框架到全局位置

```bash
# 假設你在 soapwavehealing 項目目錄
cd /Users/bryan/Documents/soapwavehealing

# 複製到全局位置
mkdir -p ~/.claude/gsd-addon
cp scripts/gsd-dispatch.sh ~/.claude/gsd-addon/dispatch/
cp -r .gsd-test ~/.claude/gsd-addon/
cp .gsd-test/gsd-config.sh ~/.claude/gsd-addon/
cp .gsd-test/install.sh ~/.claude/gsd-addon/
```

### 步驟 2：運行安裝腳本

```bash
cd ~/.claude/gsd-addon
bash install.sh
```

**預期輸出**:
```
🚀 Installing GSD Global Framework
📦 Installing dispatch.sh...
✓ dispatch.sh installed
📦 Installing gsd-test framework...
✓ gsd-test framework installed
📦 Creating global commands...
✓ gsd-dispatch command installed
✓ gsd-test command installed
✓ gsd-config command installed
🔍 Verifying installation...
✅ GSD Global Framework installed successfully!
```

### 步驟 3：添加到 PATH

編輯 `~/.bashrc` 或 `~/.zshrc`:

```bash
# 添加這一行
export PATH="$PATH:$HOME/.local/bin"

# 然後重新加載
source ~/.bashrc  # 或 source ~/.zshrc
```

驗證安裝:

```bash
gsd-config show
```

---

## 🏗️ 全局結構

```
~/.claude/gsd-addon/
├── gsd-config.sh                   # 配置管理器
├── install.sh                      # 安裝腳本
├── dispatch/
│   └── dispatch.sh                 # 全局 dispatch
├── gsd-test/
│   ├── engine/
│   │   ├── workflow_engine.py
│   │   ├── context.py
│   │   ├── tools.py
│   │   └── __init__.py
│   ├── environments/
│   │   └── environments.yaml       # 全局環境配置
│   ├── workflows/                  # 全局 workflow 模板
│   │   └── booking-e2e.workflow.yml
│   ├── cli.py
│   ├── README.md
│   └── TEST-ORCHESTRATION-GUIDE.md
├── templates/
│   └── .gsd-test.config            # 項目初始化模板
└── GLOBAL-SETUP.md                 # 本文件

$HOME/.local/bin/
├── gsd-dispatch                    # 全局命令
├── gsd-test                        # 全局命令
└── gsd-config                      # 全局命令
```

---

## 📁 項目級結構

### 新項目初始化

```bash
# 創建新項目
mkdir my-new-project
cd my-new-project

# 初始化 GSD
gsd-config init
```

**結果**:

```
my-new-project/
├── .gsd-test/
│   ├── workflows/                  # 項目特定的 workflows（可選）
│   └── environments/               # 項目特定的環境配置（可選）
├── .gsd-test.config               # 項目配置（可選 override）
└── .planning/
    └── ... (項目的計劃文檔)
```

### 現有項目遷移

```bash
cd existing-project

# 1. 保留現有 .gsd-test（可選，用於 override）
# 2. 初始化配置文件
gsd-config init

# 3. 現在可以使用全局命令
gsd-test --workflow booking-e2e.workflow.yml
gsd-dispatch 1 local
```

---

## 🔧 項目配置 (.gsd-test.config)

### 示例 1：使用全局 workflow

```bash
# my-project/.gsd-test.config

# 使用全局 workflow（不需要本地副本）
export GSD_TEST_ENV="local"
export GSD_DISPATCH_TARGET="opencode"
export GSD_DISPATCH_MODE="test"
export GSD_WORKFLOW_TIMEOUT=300
```

**運行**:
```bash
cd my-project
gsd-test --workflow booking-e2e.workflow.yml
```

### 示例 2：Override 全局 workflow

```bash
# my-project/.gsd-test.config

export GSD_TEST_ENV="staging"
export GSD_DISPATCH_TARGET="claude"
export GSD_CUSTOM_WORKFLOWS="yes"  # 使用本地 workflows
```

**本地 workflow**:
```bash
my-project/.gsd-test/workflows/
├── my-custom-test.workflow.yml     # 項目特定的測試
└── override-booking.workflow.yml   # Override 全局 workflow
```

**運行**:
```bash
cd my-project
gsd-test --workflow my-custom-test.workflow.yml
```

### 示例 3：自定義環境

```bash
# my-project/.gsd-test.config

export GSD_TEST_ENV="custom"
export GSD_CUSTOM_ENVS="yes"
```

**本地環境配置**:
```bash
my-project/.gsd-test/environments/environments.yaml
# 添加自定義環境，override 全局配置
```

---

## 🚀 使用全局命令

### 命令 1：gsd-dispatch

```bash
# 在任何項目中運行 dispatch
cd my-project
gsd-dispatch 1 local          # Phase 1, local env
gsd-dispatch 2 staging        # Phase 2, staging env

# 自動使用項目的 .gsd-test.config 配置
# 自動選擇派工目標（opencode 或 claude）
```

### 命令 2：gsd-test

```bash
# 在任何項目中運行測試
cd my-project

# 基本用法
gsd-test --workflow booking-e2e.workflow.yml

# 指定環境
gsd-test --workflow booking-e2e.workflow.yml --env staging

# 保存結果
gsd-test --workflow booking-e2e.workflow.yml --output results.json

# 覆蓋變數
gsd-test --workflow booking-e2e.workflow.yml --var name="Custom"
```

### 命令 3：gsd-config

```bash
# 顯示當前配置
gsd-config show

# 驗證 GSD 安裝
gsd-config verify

# 初始化項目
gsd-config init
```

---

## 🔍 配置優先級

1. **項目配置** (`.gsd-test.config`) — 最高優先級
2. **全局配置** (`~/.claude/gsd-addon/gsd-config.sh`)
3. **默認配置** (硬編碼默認值) — 最低優先級

### 例子

```bash
# 全局配置
~/.claude/gsd-addon/gsd-config.sh:
  export GSD_TEST_ENV="local"
  export GSD_DISPATCH_TARGET="opencode"

# 項目配置（覆蓋全局）
my-project/.gsd-test.config:
  export GSD_TEST_ENV="staging"      # ✓ 覆蓋
  # GSD_DISPATCH_TARGET 使用全局值   # opencode

# 結果
gsd-test --workflow test.yml
  環境: staging (項目級)
  派工: opencode (全局級)
```

---

## 📊 多項目場景

### 場景 1：相同配置多個項目

```bash
# 項目 A
cd ~/project-a
gsd-config init            # 使用默認配置

# 項目 B
cd ~/project-b
gsd-config init            # 使用相同默認配置

# 運行相同 workflow
gsd-test --workflow api-smoke.workflow.yml
```

### 場景 2：不同配置不同項目

```bash
# 項目 A（生產環境）
cd ~/project-a
# .gsd-test.config: GSD_TEST_ENV="production"
gsd-test --workflow booking-e2e.workflow.yml

# 項目 B（本地開發）
cd ~/project-b
# .gsd-test.config: GSD_TEST_ENV="local"
gsd-test --workflow booking-e2e.workflow.yml
```

### 場景 3：項目特定 workflow

```bash
# 全局 workflow（所有項目共用）
~/.claude/gsd-addon/gsd-test/workflows/
  ├── api-smoke.workflow.yml
  └── booking-e2e.workflow.yml

# 項目 A 特定 workflow（override）
~/project-a/.gsd-test/workflows/
  └── project-a-custom-test.workflow.yml

gsd-test --workflow project-a-custom-test.workflow.yml  # 使用項目級 workflow
gsd-test --workflow api-smoke.workflow.yml              # 使用全局 workflow
```

---

## 🔄 Workflow 查找順序

當運行 `gsd-test --workflow booking-e2e.workflow.yml`:

1. **項目級** — `my-project/.gsd-test/workflows/booking-e2e.workflow.yml`
   - 如果存在，使用此項
2. **全局級** — `~/.claude/gsd-addon/gsd-test/workflows/booking-e2e.workflow.yml`
   - 如果項目級不存在，使用此項
3. **錯誤** — 如果都不存在，報錯

---

## 🛠️ 高級使用

### 添加自定義工具

在項目中擴展全局工具（不修改全局）:

```bash
# my-project/.gsd-test/engine/custom_tools.py

from ...gsd_global_home/gsd_test.engine.tools import ToolRegistry

class CustomToolRegistry(ToolRegistry):
    def _register_builtin_tools(self):
        super()._register_builtin_tools()
        self.register('my_tool', self._tool_my_tool)
    
    def _tool_my_tool(self, params):
        # 項目特定的工具實現
        ...
```

### 共享 workflow 庫

```bash
# 在一個專屬倉庫中維護 workflows
git clone git@github.com:yourname/gsd-workflows.git ~/.claude/gsd-workflows

# 在項目中使用
export GSD_EXTRA_WORKFLOW_DIRS="$HOME/.claude/gsd-workflows"

# workflow 查找順序變為
1. 項目級
2. 全局級
3. 額外目錄級
```

---

## 📦 從現有項目遷移

### 步驟 1：備份現有 .gsd-test

```bash
cd existing-project
cp -r .gsd-test .gsd-test.backup
```

### 步驟 2：移除本地複製

```bash
# 保留 workflow 覆蓋（如果有）
# 刪除重複的全局 workflow
rm .gsd-test/engine
rm .gsd-test/cli.py
rm .gsd-test/README.md
```

### 步驟 3：初始化全局

```bash
gsd-config init
```

### 步驟 4：測試

```bash
gsd-test --workflow booking-e2e.workflow.yml
```

---

## 🚨 故障排除

### 命令不存在

```bash
# 檢查 PATH
echo $PATH | grep .local/bin

# 檢查文件
ls -la ~/.local/bin/gsd-*

# 重新加載 shell
source ~/.bashrc
```

### 找不到 workflow

```bash
# 檢查全局位置
ls -la ~/.claude/gsd-addon/gsd-test/workflows/

# 檢查項目位置
ls -la my-project/.gsd-test/workflows/

# 驗證配置
gsd-config show
```

### 配置不生效

```bash
# 檢查項目配置是否存在
cat my-project/.gsd-test.config

# 檢查語法
bash -n my-project/.gsd-test.config

# 強制重新加載
gsd-config load
gsd-config show
```

---

## 📚 相關文檔

- [GSD Test Framework Guide](./../gsd-test/TEST-ORCHESTRATION-GUIDE.md)
- [GSD Integration Guide](./../gsd-test/agents/gsd-test-orchestrator.md)
- [Dispatch Setup](./dispatch/README.md)

---

**安裝完成後，所有項目都能使用全局 GSD 工具！**

```bash
# 任何項目中
gsd-dispatch 1 local
gsd-test --workflow booking-e2e.workflow.yml
gsd-config show
```
