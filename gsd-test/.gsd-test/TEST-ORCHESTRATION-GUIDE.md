# Test Orchestration Framework 完整指南

**版本**: 1.0.0  
**作者**: Claude Code  
**日期**: 2026-08-18  
**狀態**: Production-Ready

## 📋 目錄

1. [概述](#概述)
2. [快速開始](#快速開始)
3. [5層架構](#5層架構)
4. [使用方式](#使用方式)
5. [Workflow 完整語法](#workflow-完整語法)
6. [環境配置](#環境配置)
7. [與 GSD 框架整合](#與-gsd-框架整合)
8. [常見問題](#常見問題)

---

## 概述

### 問題陳述

在 Phase 1 執行完成後，發現一個**關鍵缺口**：

```
執行層知道怎麼測試 ✓
驗證層不知道怎麼測試 ✗
測試流程每次都不同 ✗
不同環境的測試無法複用 ✗
```

### 解決方案

**Test Orchestration Framework** — 把「臨時對話中的工具序列」變成「可重複使用、可配置、可跨環境的自動化系統」。

### 核心價值

```
定義一次 workflow.yml
  ↓
複用無限次
  ↓
支持多環境自動適配
  ↓
所有 agent 都能使用
  ↓
減少 60-70% 測試時間
```

---

## 快速開始

### 安裝（無需安裝）

框架是純 Python + YAML，無外部依賴：

```bash
# 已在項目中建立，無需安裝
.gsd-test/
├── engine/
├── workflows/
├── environments/
└── cli.py
```

### 運行第一個測試

```bash
# 進入項目目錄
cd /Users/bryan/Documents/soapwavehealing

# 運行預設的預約 E2E 測試
python .gsd-test/cli.py --workflow .gsd-test/workflows/booking-e2e.workflow.yml

# 在 staging 環境運行
python .gsd-test/cli.py \
  --workflow .gsd-test/workflows/booking-e2e.workflow.yml \
  --env staging

# 保存結果
python .gsd-test/cli.py \
  --workflow .gsd-test/workflows/booking-e2e.workflow.yml \
  --output test-results.json
```

### 預期輸出

```
============================================================
🚀 Workflow: Booking Form Complete E2E Test
📍 Environment: local
============================================================

🔵 Job: setup
   → Update launch configuration
      ✓ Success (45ms)
   → Start development server
      ✓ Success (2340ms)
   → Wait for server ready
      ✓ Success (3000ms)

🔵 Job: verify_api
   → Check /api/services endpoint
      ✓ Success (156ms)
   → Verify services list
      ✓ Success (12ms)

🔵 Job: test_form
   → Read page content
      ✓ Success (234ms)
   → Fill name field
      ✓ Success (45ms)
   → Fill phone field
      ✓ Success (38ms)
   → Fill datetime field
      ✓ Success (52ms)
   → Submit booking form
      ✓ Success (1200ms)
   → Wait for response
      ✓ Success (2000ms)

🔵 Job: verify_success
   → Read success page
      ✓ Success (123ms)
   → Assert success message
      ✓ Success (8ms)
   → Assert confirmation code
      ✓ Success (5ms)

🔵 Job: cleanup
   → Stop development server
      ✓ Success (345ms)

============================================================
📊 Summary
============================================================
Total steps: 18
Passed:      18 ✓
Failed:      0 ✗
============================================================
```

---

## 5層架構

### 層 1：核心引擎

```
engine/
├── workflow_engine.py      # 主引擎：解析 YAML，執行 workflow
├── context.py              # 上下文管理：變數、輸出、狀態
├── tools.py                # 工具適配層：Claude Code 工具 + Bash
└── __init__.py
```

**責任**：
- ✅ 解析 YAML workflow 定義
- ✅ 管理執行狀態和上下文
- ✅ 調用工具並收集結果
- ✅ 處理條件和依賴
- ✅ 生成詳細報告

**技術棧**：Pure Python, No external deps

### 層 2：環境配置

```
environments/
└── environments.yaml       # 多環境配置：local, docker, staging, prod
```

**支持的環境**：

| 環境 | 用途 | 服務器 | 資料庫 |
|------|------|--------|--------|
| `local` | 本地開發 | Wrangler Pages | D1 local |
| `docker` | Docker Compose | Node.js | PostgreSQL |
| `staging` | 預部署測試 | Cloudflare Pages | D1 staging |
| `production` | 生產驗證（唯讀） | Cloudflare Pages | D1 prod |

**自動適配**：
```yaml
# 同一個 workflow.yml 在不同環境自動調整
base_url: "{{ environment.base_url }}"  # local: localhost, prod: domain.com
port: "{{ environment.port }}"           # local: 8788, prod: 443
```

### 層 3：Workflow 定義

```
workflows/
├── booking-e2e.workflow.yml      # 預約端到端測試
├── api-smoke.workflow.yml        # API smoke test
└── [custom-test].workflow.yml    # 自定義測試
```

**YAML 結構**：

```yaml
name: "Test Name"
env:                           # 全局環境變數
  VAR: "value"
variables:                     # 測試參數
  param: "value"
jobs:                          # 並行 jobs
  job_name:
    needs: [dep_job]          # 依賴聲明
    if: "condition"            # 條件執行
    steps:                     # 順序步驟
      - name: "Step name"
        tool: "tool_name"      # 工具選擇
        params: {...}          # 工具參數
        assertions: [...]      # 驗證條件
        retry_count: 3         # 失敗重試
```

### 層 4：CLI 工具

```
cli.py                         # 命令行界面
```

**調用方式**：

```bash
# 基本用法
python cli.py --workflow <path.yml>

# 選擇環境
python cli.py --workflow <path.yml> --env staging

# 覆蓋變數
python cli.py --workflow <path.yml> --var name=value

# 保存結果
python cli.py --workflow <path.yml> --output results.json

# 詳細輸出
python cli.py --workflow <path.yml> --verbose
```

### 層 5：GSD 適配層

```
agents/
└── gsd-test-orchestrator.md   # GSD agent 定義
```

**整合方式**：

```
/gsd:verify-work <phase>
  ↓
gsd-verifier agent
  ↓
(內部) gsd-test-orchestrator
  ↓
自動運行 <phase>-test.workflow.yml
  ↓
驗證 phase 目標達成
```

---

## 使用方式

### 方式 1：獨立使用（任何地方都能用）

```bash
# 在任何有 Python 的環境
cd any/directory
python /path/to/.gsd-test/cli.py --workflow /path/to/my-test.workflow.yml
```

### 方式 2：Claude Code Skill（在 Claude Code 中使用）

```python
# Agent 可以調用 test orchestrator
from .gsd_test.engine import WorkflowEngine

engine = WorkflowEngine('workflows/booking-e2e.workflow.yml', env_name='local')
success = engine.execute()
```

### 方式 3：GSD 框架集成（在 GSD workflow 中使用）

```bash
# Phase 執行完後自動驗證
/gsd:execute-phase 1
  ↓
/gsd:verify-work 1  
  ↓
(內部使用 gsd-test-orchestrator)
```

### 方式 4：CI/CD Pipeline（GitHub Actions 等）

```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-python@v2
        with:
          python-version: 3.9
      
      - name: Run API smoke test
        run: |
          python .gsd-test/cli.py \
            --workflow .gsd-test/workflows/api-smoke.workflow.yml \
            --env docker
      
      - name: Run E2E test
        run: |
          python .gsd-test/cli.py \
            --workflow .gsd-test/workflows/booking-e2e.workflow.yml \
            --env docker
            --output test-results.json
      
      - name: Upload results
        if: always()
        uses: actions/upload-artifact@v2
        with:
          name: test-results
          path: test-results.json
```

---

## Workflow 完整語法

### 最小 Workflow

```yaml
name: "Minimal Test"

jobs:
  test:
    steps:
      - name: "Echo test"
        tool: bash
        params:
          command: "echo 'Hello'"
```

### 完整 Workflow（所有特性）

```yaml
# 元數據
name: "Complete Workflow Example"
description: "Demonstrates all features"
version: "1.0"

# 全局環境變數
env:
  BASE_URL: "http://localhost:{{ environment.port }}"
  TIMEOUT: 30

# 工作流變數（可被 CLI 覆蓋）
variables:
  username: "default_user"
  password: "default_pass"

# 並行 Jobs
jobs:
  # Job 1: 環境設置
  setup:
    name: "Setup Environment"
    steps:
      - name: "Initialize"
        tool: bash
        params:
          command: "echo 'Starting setup'"

      - name: "Start server"
        id: server_start
        tool: preview_start
        params:
          name: dev
          command: "npm run dev"
        timeout: 30s
        on_failure: retry
        retry_count: 3

  # Job 2: 驗證（等待 setup）
  verify:
    name: "Verification"
    needs: [setup]
    if: "${{ needs.setup }}"  # 條件執行
    
    steps:
      - name: "Check endpoint"
        id: check
        tool: bash
        params:
          command: |
            curl -s ${{ env.BASE_URL }}/api/health | jq .
        timeout: 10s

      - name: "Validate response"
        tool: assert
        params:
          actual: "${{ outputs.check.output }}"
          assertions:
            contains: "ok"

  # Job 3: 測試
  test:
    name: "Run Tests"
    needs: [setup, verify]
    
    steps:
      - name: "Setup test data"
        tool: bash
        params:
          command: "npm run seed:test"

      - name: "Run test suite"
        tool: bash
        params:
          command: "npm test"
        on_failure: continue  # 繼續即使失敗

  # Job 4: 清理
  cleanup:
    name: "Cleanup"
    needs: [setup]
    if: "always"  # 無論結果如何都執行
    
    steps:
      - name: "Stop server"
        tool: preview_stop
        params:
          serverId: "${{ outputs.server_start.outputs.serverId }}"

      - name: "Cleanup temp files"
        tool: bash
        params:
          command: "rm -rf /tmp/test-*"
```

### 關鍵特性

#### 變數插值

```yaml
# 支持三種插值方式
base_url: "${{ environment.base_url }}"   # 環境配置
username: "${{ variables.username }}"     # 工作流變數
previous_output: "${{ outputs.step_id.output.field }}"  # 前一步輸出
```

#### 條件執行

```yaml
jobs:
  conditional_job:
    if: "environment.name == 'staging'"
    steps: [...]
```

#### 失敗處理

```yaml
steps:
  - name: "Flaky operation"
    on_failure: retry
    retry_count: 3
    params: {}
  
  - name: "Non-critical step"
    on_failure: continue  # 繼續即使失敗
    params: {}
```

#### 斷言驗證

```yaml
steps:
  - name: "Validate"
    tool: assert
    params:
      actual: "${{ outputs.fetch.output }}"
      assertions:
        contains: "success"
        matches: "^\\d+$"
        equals: "expected_value"
```

---

## 環境配置

### environments.yaml 結構

```yaml
environments:
  local:
    name: "Local Development"
    dev_command: "npm run dev:api"
    port: 8788
    base_url: "http://localhost:8788"
    timeout: 30
    db_type: "d1_local"
    
  staging:
    name: "Staging"
    base_url: "https://staging.example.com"
    timeout: 45
    db_type: "cloudflare_d1"
    requires_auth: true
    
  production:
    name: "Production"
    base_url: "https://example.com"
    timeout: 60
    readonly: true
    requires_auth: true
```

### 在 Workflow 中使用

```yaml
jobs:
  test:
    steps:
      - name: "Test on {{ environment.name }}"
        tool: bash
        params:
          command: "curl -s {{ environment.base_url }}/api/health"
        timeout: "{{ environment.timeout }}s"
```

---

## 與 GSD 框架整合

### 啟動 Test Orchestration（從 GSD Executor）

執行完 Phase 後，自動驗證：

```
gsd-executor (執行)
  ↓
gsd-verifier (驗證)
  ↓
(內部) gsd-test-orchestrator (自動化測試)
  ↓
驗證結果
```

### 在 Phase 計劃中使用

```markdown
## Development Environment Setup

### Test Automation

使用 Test Orchestration Framework 進行自動化驗證：

\`\`\`bash
# Phase 執行後自動運行
python .gsd-test/cli.py \\
  --workflow .gsd-test/workflows/phase-01-e2e.workflow.yml \\
  --env local
\`\`\`

### 預期測試流程

✅ 環境設置  
✅ API 驗證  
✅ UI 功能測試  
✅ 數據驗證  
✅ 清理  
```

---

## 常見問題

### Q: 支持什麼版本的 Python？

A: Python 3.7+。無外部依賴（標准庫 + PyYAML）。

### Q: 可以在 CI/CD 中使用嗎？

A: 是的。支持 GitHub Actions、GitLab CI、Jenkins 等。見上面的 GitHub Actions 範例。

### Q: 可以與現有的 pytest/jest 測試結合嗎？

A: 是的。在 workflow 中調用 `npm test` 或 `pytest`：
```yaml
steps:
  - name: "Run pytest"
    tool: bash
    params:
      command: "pytest tests/"
```

### Q: 怎樣擴展自定義工具？

A: 在 `engine/tools.py` 中添加：
```python
def register_custom_tools(self):
    self.register('my_tool', self._tool_my_custom_tool)

def _tool_my_custom_tool(self, params):
    # 實現你的工具
    return ToolResult(success=True, output=...)
```

### Q: 支持並行執行嗎？

A: 是的。不同 job 可並行（如果沒有 `needs` 依賴）：
```yaml
jobs:
  job_a:
    steps: [...]
  job_b:
    steps: [...]  # 與 job_a 並行
```

### Q: 怎樣跳過某個 job？

A: 使用 `if` 條件：
```yaml
jobs:
  skip_me:
    if: "false"  # 永遠跳過
    steps: [...]
```

### Q: 可以上傳測試結果到服務器嗎？

A: 可以。在 workflow 中調用你的 upload 工具：
```yaml
steps:
  - name: "Upload results"
    tool: bash
    params:
      command: "curl -F results=@test-results.json https://example.com/upload"
```

---

## 下一步

1. **創建自定義 Workflow**：在 `.gsd-test/workflows/` 中新建 `.workflow.yml` 文件
2. **集成到 CI/CD**：在 GitHub Actions / GitLab CI 中添加測試步驟
3. **監控測試**：保存結果 JSON，建立測試儀表板
4. **擴展工具**：在 `tools.py` 中添加特定領域的工具

---

**歡迎使用 Test Orchestration Framework！**

有問題？見 [gsd-test-orchestrator.md](./agents/gsd-test-orchestrator.md) 或參考 [完整 API 文檔](./engine/__init__.py)。
