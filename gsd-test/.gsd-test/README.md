# Test Orchestration Framework

**自動化測試工作流編排 — 支持所有 agent、所有環境、無外部依賴**

## 🚀 快速開始

```bash
# 運行預約 E2E 測試
python cli.py --workflow workflows/booking-e2e.workflow.yml

# 在 staging 環境
python cli.py --workflow workflows/booking-e2e.workflow.yml --env staging

# 保存結果
python cli.py --workflow workflows/booking-e2e.workflow.yml --output results.json
```

## 📁 結構

```
.gsd-test/
├── engine/                      # 核心引擎
│   ├── workflow_engine.py       # 主引擎
│   ├── context.py               # 上下文
│   ├── tools.py                 # 工具適配
│   └── __init__.py
├── workflows/                   # 測試定義
│   ├── booking-e2e.workflow.yml
│   └── api-smoke.workflow.yml
├── environments/                # 環境配置
│   └── environments.yaml
├── agents/                      # GSD 適配
│   └── gsd-test-orchestrator.md
├── cli.py                       # CLI 工具
├── README.md                    # 本文件
└── TEST-ORCHESTRATION-GUIDE.md  # 完整指南
```

## 💡 使用方式

| 場景 | 命令 |
|------|------|
| 本地開發測試 | `python cli.py --workflow workflows/booking-e2e.workflow.yml` |
| Staging 驗證 | `python cli.py --workflow workflows/booking-e2e.workflow.yml --env staging` |
| 覆蓋參數 | `python cli.py --workflow workflows/booking-e2e.workflow.yml --var name="Custom"` |
| 保存結果 | `python cli.py --workflow workflows/booking-e2e.workflow.yml --output results.json` |
| 詳細輸出 | `python cli.py --workflow workflows/booking-e2e.workflow.yml --verbose` |

## 🎯 支持的工具

- `bash` — 執行 shell 命令
- `preview_start` — 啟動開發服務器
- `preview_stop` — 停止服務器
- `read_page` — 讀取頁面
- `form_input` — 填表單
- `computer` — 滑鼠/鍵盤操作
- `wait` — 等待
- `file_read` / `file_write` — 檔案操作
- `assert` — 驗證

## 🌍 支持的環境

- `local` — 本地 Wrangler Pages
- `docker` — Docker Compose
- `staging` — Staging 環境
- `production` — 生產環境（唯讀）

## 🔗 與 GSD 框架整合

```bash
# Phase 執行完自動驗證
/gsd:verify-work 1
  ↓ (內部使用)
python cli.py --workflow workflows/phase-01-e2e.workflow.yml
```

## 📖 文檔

- [完整使用指南](./TEST-ORCHESTRATION-GUIDE.md)
- [GSD Agent 定義](./agents/gsd-test-orchestrator.md)

## ⚡ 典型工作流

```yaml
jobs:
  setup:
    steps:
      - name: Start server
        tool: preview_start

  test:
    needs: [setup]
    steps:
      - name: Fill form
        tool: form_input
      - name: Submit
        tool: computer

  verify:
    needs: [test]
    steps:
      - name: Check result
        tool: assert
```

## 🛠️ 創建自定義測試

1. 複製 `workflows/booking-e2e.workflow.yml`
2. 修改為你的場景
3. 運行 `python cli.py --workflow workflows/your-test.workflow.yml`

## 📊 CI/CD 集成

```yaml
# .github/workflows/test.yml
- name: Run E2E test
  run: |
    python .gsd-test/cli.py \
      --workflow .gsd-test/workflows/booking-e2e.workflow.yml \
      --env docker \
      --output results.json
```

## 🆘 常見問題

**Q: 需要安裝什麼依賴？**  
A: 無。僅需 Python 3.7+

**Q: 支持並行執行嗎？**  
A: 是。不同 job 可並行

**Q: 可以在任何環境運行嗎？**  
A: 是。支持 local / docker / staging / production

**Q: 怎樣添加自定義工具？**  
A: 在 `engine/tools.py` 中註冊

---

**更多詳情見 [TEST-ORCHESTRATION-GUIDE.md](./TEST-ORCHESTRATION-GUIDE.md)**
