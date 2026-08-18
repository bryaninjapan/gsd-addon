# gsd-test-orchestrator

**Type**: GSD Phase Executor (Test Automation)

**Description**: 
Orchestrates automated test workflows defined in YAML. Runs multi-step test scenarios (E2E, API smoke tests, UI regression) across different environments (local, docker, staging, production). Integrates with Claude Code's internal tools and provides dynamic execution with conditional branching, retries, and detailed reporting.

**Capability Level**: 
- 🟢 Local testing (dev environment)
- 🟢 API testing (REST endpoints)
- 🟡 UI testing (form automation, screenshot capture)
- 🟡 Multi-environment (local, staging, production)
- 🟢 Reporting (JSON output, detailed logs)

**When to Use**:
1. **Verify Phase Deliverables**: After execution phase completes, orchestrate test workflows to verify requirements
   ```
   /gsd:verify-work <phase>
   → Internally uses gsd-test-orchestrator to run booking-e2e.workflow.yml
   ```

2. **Continuous Regression Testing**: Run saved workflows on each commit
   ```bash
   python .gsd-test/cli.py --workflow booking-e2e.workflow.yml --env local
   ```

3. **Environment Validation**: Test same workflow across local/staging/prod
   ```bash
   for env in local staging production; do
     python .gsd-test/cli.py --workflow booking-e2e.workflow.yml --env $env
   done
   ```

4. **Custom Test Scenarios**: Create new .workflow.yml files for specific test flows

---

## Usage

### Quick Start

```bash
# Run default booking E2E test in local environment
python .gsd-test/cli.py --workflow .gsd-test/workflows/booking-e2e.workflow.yml

# Run in staging with results output
python .gsd-test/cli.py \
  --workflow .gsd-test/workflows/booking-e2e.workflow.yml \
  --env staging \
  --output test-results.json
```

### Workflow Definition Format

```yaml
name: "Test Name"
description: "What this test does"

env:
  VAR_NAME: "value"

variables:
  param_name: "param_value"

jobs:
  job_name:
    name: "Human-readable job name"
    needs: [dependency_job]        # 等待其他 job 完成
    if: "condition"                 # 條件執行

    steps:
      - name: "Step name"
        id: step_id                 # 用於引用輸出
        tool: "bash"                # 工具名稱
        params:
          command: "echo hello"
        timeout: 30s
        on_failure: retry            # 失敗時重試
        retry_count: 3
        assertions:                  # 斷言驗證
          contains: "expected text"
```

### Available Tools

| Tool | Purpose | Example |
|------|---------|---------|
| `bash` | Execute shell commands | `curl`, `npm run`, etc |
| `preview_start` | Start dev server | Launch Wrangler Pages dev |
| `preview_stop` | Stop dev server | Cleanup |
| `read_page` | Read page structure | Check HTML content |
| `form_input` | Fill form fields | Automate user input |
| `computer` | Click, type, etc | Simulate user actions |
| `wait` | Pause execution | Wait for async operations |
| `file_read` | Read file | Check config files |
| `file_write` | Write file | Create test fixtures |
| `assert` | Verify conditions | Validate test results |

### Environment Variables

```bash
# Override environment
TARGET_ENV=staging python .gsd-test/cli.py --workflow booking-e2e.workflow.yml --env staging

# Override workflow variables
python .gsd-test/cli.py \
  --workflow booking-e2e.workflow.yml \
  --var name="Custom Name" \
  --var phone="+60123456789"

# Verbose output
python .gsd-test/cli.py --workflow booking-e2e.workflow.yml --verbose
```

---

## Workflow Examples

### 1. API Smoke Test

```yaml
name: "API Smoke Test"
jobs:
  verify_endpoints:
    steps:
      - name: GET /api/services
        tool: bash
        params:
          command: "curl -s {{ environment.base_url }}/api/services | jq ."
```

### 2. Complete Booking Flow

```yaml
name: "Complete Booking E2E"
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
        params:
          fields:
            - ref: ref_121
              value: "Test Name"
```

### 3. Cross-Environment Test

```yaml
name: "Multi-Environment Test"
variables:
  environment: "{{ environment.name }}"

jobs:
  test:
    steps:
      - name: Test on {{ environment }}
        tool: bash
        params:
          command: "curl -s {{ environment.base_url }}/health"
```

---

## Output & Reporting

### Results Format

```json
{
  "env_name": "local",
  "variables": {...},
  "outputs": {
    "step_id": {"success": true, "output": "..."}
  },
  "job_results": {
    "job_name": {
      "status": "success",
      "steps": [
        {"name": "...", "tool": "...", "status": "success"}
      ]
    }
  },
  "failures": []
}
```

### Save Results

```bash
python .gsd-test/cli.py \
  --workflow booking-e2e.workflow.yml \
  --output results/2026-08-18-booking-e2e.json
```

---

## Integration with GSD

### gsd-verify-work Phase

The `/gsd:verify-work <phase>` command internally:

1. Reads PLAN.md to understand test scenarios
2. Generates or loads appropriate .workflow.yml
3. Runs orchestrator with `gsd-test-orchestrator` agent
4. Collects results and validates against phase requirements

### gsd-executor Phase

After `gsd-executor` completes a phase:

```
Plan → Execute → [auto run orchestrator] → Verify
                  ↓
           booking-e2e.workflow.yml
```

---

## Creating Custom Workflows

### Template

```yaml
name: "Your Test Name"
description: "What this tests"

env:
  BASE_URL: "http://localhost:{{ environment.port }}"

jobs:
  your_job:
    steps:
      - name: "Your step"
        tool: bash
        params:
          command: "echo 'Your test'"
```

### Place in `.gsd-test/workflows/`

```bash
.gsd-test/workflows/
├── booking-e2e.workflow.yml
├── api-smoke.workflow.yml
├── your-custom-test.workflow.yml  ← Add here
```

### Run

```bash
python .gsd-test/cli.py --workflow .gsd-test/workflows/your-custom-test.workflow.yml
```

---

## Advanced Features

### Conditional Execution

```yaml
jobs:
  test:
    if: "environment.name == 'staging'"
    steps: [...]
```

### Retry on Failure

```yaml
steps:
  - name: Flaky test
    tool: bash
    on_failure: retry
    retry_count: 3
    params:
      command: "npm test"
```

### Parallel Jobs

```yaml
jobs:
  job_a:
    steps: [...]
  
  job_b:
    steps: [...]
    # job_b runs in parallel with job_a
  
  job_c:
    needs: [job_a, job_b]  # Wait for both
```

### Output Referencing

```yaml
steps:
  - name: Get data
    id: fetch
    tool: bash
    params:
      command: "curl -s /api/data"
  
  - name: Use data
    tool: bash
    params:
      command: "echo ${{ outputs.fetch.output.stdout }}"
```

---

## Troubleshooting

### "Tool not found"

The tool you requested isn't registered. Check available tools above or add custom tools in `engine/tools.py`.

### "Environment not found"

Ensure `environments.yaml` contains the environment you're running in.

### "Assertion failed"

The verification step didn't match expected output. Check the `actual` value being tested.

### "Timeout"

Operation took longer than specified `timeout`. Increase timeout or check if environment is responding.

---

## Related Documentation

- [Test Orchestration Framework Guide](./../TEST-ORCHESTRATION-GUIDE.md)
- [Phase 1 Development Environment Setup](./../../../.planning/PHASE-PLANNING-TEMPLATE.md)
- [GSD Addon](./../../../.planning/gsd-addon/)
