# ⚡ 快速開始檢查清單

**目標**: 5 分鐘內運行你的第一個自動化測試

---

## 第 1 步：驗證環境（1 分鐘）

```bash
# 檢查 Python 版本
python --version          # 需要 3.7+

# 檢查 YAML 支持
python -c "import yaml; print('✓ PyYAML 可用')"

# 進入項目目錄
cd /Users/bryan/Documents/soapwavehealing
```

✅ **預期**: Python 3.7+，能導入 yaml

---

## 第 2 步：查看可用測試（1 分鐘）

```bash
# 列出所有 workflow
ls -la .gsd-test/workflows/

# 查看預設 workflow 內容
cat .gsd-test/workflows/booking-e2e.workflow.yml | head -30
```

✅ **預期**: 看到 `booking-e2e.workflow.yml` 等文件

---

## 第 3 步：運行測試（3 分鐘）

### 3.1 基本運行

```bash
# 最簡單的方式
python .gsd-test/cli.py --workflow .gsd-test/workflows/booking-e2e.workflow.yml
```

✅ **預期**:
```
🚀 Workflow: Booking Form Complete E2E Test
🔵 Job: setup
   → Update launch configuration
      ✓ Success
   ...
```

### 3.2 在 Staging 環境運行

```bash
python .gsd-test/cli.py \
  --workflow .gsd-test/workflows/booking-e2e.workflow.yml \
  --env staging
```

### 3.3 保存結果為 JSON

```bash
python .gsd-test/cli.py \
  --workflow .gsd-test/workflows/booking-e2e.workflow.yml \
  --output results.json

# 查看結果
cat results.json | python -m json.tool
```

### 3.4 詳細輸出

```bash
python .gsd-test/cli.py \
  --workflow .gsd-test/workflows/booking-e2e.workflow.yml \
  --verbose
```

---

## 第 4 步：自定義參數（額外）

```bash
# 覆蓋 workflow 變數
python .gsd-test/cli.py \
  --workflow .gsd-test/workflows/booking-e2e.workflow.yml \
  --var name="My Custom Name" \
  --var phone="+60 98765432"
```

---

## 常用命令速查

| 場景 | 命令 |
|------|------|
| **本地測試** | `python cli.py --workflow booking-e2e.workflow.yml` |
| **Staging** | `python cli.py --workflow booking-e2e.workflow.yml --env staging` |
| **保存結果** | `python cli.py --workflow booking-e2e.workflow.yml --output results.json` |
| **詳細輸出** | `python cli.py --workflow booking-e2e.workflow.yml --verbose` |
| **所有幫助** | `python cli.py --help` |

---

## 💡 接下來可以做什麼

### 1. 閱讀完整指南（15 分鐘）

```bash
cat .gsd-test/TEST-ORCHESTRATION-GUIDE.md | less
```

### 2. 創建自己的 Workflow（30 分鐘）

```bash
# 複製範本
cp .gsd-test/workflows/booking-e2e.workflow.yml \
   .gsd-test/workflows/my-custom-test.workflow.yml

# 編輯內容
nano .gsd-test/workflows/my-custom-test.workflow.yml

# 運行你的 workflow
python cli.py --workflow .gsd-test/workflows/my-custom-test.workflow.yml
```

### 3. 集成到 CI/CD（1 小時）

```bash
# 添加到 GitHub Actions
nano .github/workflows/test.yml

# 內容模板:
# - name: Run automated tests
#   run: |
#     python .gsd-test/cli.py \
#       --workflow .gsd-test/workflows/booking-e2e.workflow.yml \
#       --env docker
```

### 4. 在 Claude Code 中使用（5 分鐘）

```python
# 在 Claude Code 對話中
from .gsd_test.engine import WorkflowEngine

engine = WorkflowEngine('.gsd-test/workflows/booking-e2e.workflow.yml', env='local')
success = engine.execute()
print("✅ Tests passed" if success else "❌ Tests failed")
```

---

## 🆘 常見問題速解

### Q: 在哪裡？

**A**: 所有文件在 `.gsd-test/` 目錄下

### Q: 怎樣看幫助？

**A**: `python cli.py --help`

### Q: 怎樣看詳細日誌？

**A**: `python cli.py --workflow booking-e2e.workflow.yml --verbose`

### Q: 怎樣自定義測試？

**A**: 複製 `workflows/booking-e2e.workflow.yml` 並修改

### Q: 支持並行嗎？

**A**: 是。不同 job 自動並行（如果沒有 `needs:` 依賴）

### Q: 支持哪些環境？

**A**: local, docker, staging, production（在 `environments.yaml` 中配置）

### Q: 怎樣添加新環境？

**A**: 在 `environments/environments.yaml` 中添加新 section

### Q: 結果存到哪裡？

**A**: 
- 控制台輸出（默認）
- `--output results.json` 存為 JSON 文件

---

## 📖 重要文檔連結

| 文檔 | 用途 | 讀取時間 |
|------|------|---------|
| [README.md](./../.gsd-test/README.md) | 快速參考 | 5 min |
| [TEST-ORCHESTRATION-GUIDE.md](./../.gsd-test/TEST-ORCHESTRATION-GUIDE.md) | 完整指南 | 30 min |
| [gsd-test-orchestrator.md](./../.gsd-test/agents/gsd-test-orchestrator.md) | Agent 定義 | 15 min |
| [GSD-TEST-ORCHESTRATION-INTEGRATION.md](./../.planning/GSD-TEST-ORCHESTRATION-INTEGRATION.md) | 框架整合 | 20 min |

---

## ✨ 成功標誌

✅ 當你看到這個時，代表一切正常：

```
============================================================
🚀 Workflow: [Your Workflow Name]
📍 Environment: local
============================================================

🔵 Job: [job_name]
   → [step_name]
      ✓ Success (123ms)

============================================================
📊 Summary
Total steps: N
Passed:      N ✓
Failed:      0 ✗
============================================================
```

---

**準備好了嗎？ 👉 執行: `python cli.py --workflow booking-e2e.workflow.yml`**

有問題？見完整文檔或執行 `python cli.py --help`。

**Happy Testing! 🎉**
