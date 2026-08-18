# GSD Addon — Workflow Reference

Quick reference for DAG-based workflow definitions.

## What is a Workflow?

A **workflow** is a YAML-defined job orchestration plan with:
- **Jobs** — Individual execution units
- **Dependencies** — Which jobs must complete first
- **Conditions** — When jobs run
- **Variables** — Data passed between jobs
- **Assertions** — Validation checks

## Quick Start

### Define a Workflow

```yaml
# workflows/my-test.workflow.yml
name: my-test
version: 1.0

jobs:
  setup:
    tool: bash
    commands:
      - npm install
  
  test:
    depends_on: [setup]
    tool: bash
    commands:
      - npm test
    
  report:
    depends_on: [test]
    tool: bash
    commands:
      - echo "Tests passed!"
```

### Run It

```bash
gsd-test --workflow my-test.workflow.yml
```

---

## Workflow Structure

### Root Level

```yaml
name: booking-e2e              # Workflow name (required)
description: Full booking flow # Description (optional)
version: 1.0                   # Version (optional)

environment:                   # Global environment variables (optional)
  api_url: "{{ env.API_URL }}"
  timeout: 30

jobs:                          # Jobs to execute (required)
  setup: {...}
  test: {...}
  verify: {...}
```

### Job Structure

```yaml
jobs:
  my_job:
    description: "What this job does"        # (optional)
    tool: bash | browser | api | assertion   # (required)
    commands: [...]                          # (required for bash/browser/api)
    depends_on: [job1, job2]                 # (optional) — wait for these
    if: "{{ condition }}"                    # (optional) — run if true
    retries: 2                               # (optional) — retry on failure
    timeout: 60                              # (optional) — seconds
    assertions: [...]                        # (optional) — validation checks
    output:                                  # (optional) — capture output
      name: result
```

---

## Tools

### bash — Shell Commands

```yaml
jobs:
  run_tests:
    tool: bash
    commands:
      - npm run dev &
      - sleep 2
      - npm test
    timeout: 120
```

### browser — UI Automation

```yaml
jobs:
  test_ui:
    tool: browser
    commands:
      - navigate: https://example.com/booking
      - fill: input[name=name] with "John Doe"
      - click: button[type=submit]
      - wait: 2
      - assert: text contains "Success"
```

### api — HTTP Requests

```yaml
jobs:
  api_call:
    tool: api
    commands:
      - method: POST
        url: "{{ env.api_url }}/bookings"
        headers:
          Authorization: "Bearer {{ env.TOKEN }}"
        body:
          name: "John"
          phone: "+60123456789"
    timeout: 30
```

### assertion — Validation Checks

```yaml
jobs:
  verify:
    tool: assertion
    assertions:
      - type: status_code
        expected: 200
      
      - type: response_body
        field: "message"
        expected: "Success"
      
      - type: text_contains
        text: "Booking confirmed"
      
      - type: timeout
        max_seconds: 10
```

---

## Syntax

### Dependencies

**Wait for one job**:
```yaml
depends_on: [setup]
```

**Wait for multiple jobs**:
```yaml
depends_on: [setup, verify_api]
```

**No dependencies** (runs in parallel):
```yaml
# Don't include depends_on
```

### Conditionals

```yaml
# Run if variable is true
if: "{{ env.SKIP_TESTS == false }}"

# Run if environment is staging
if: "{{ env.ENVIRONMENT == staging }}"

# Run if job output exists
if: "{{ outputs.setup.status == success }}"
```

### Variables

**Environment variables**:
```yaml
api_url: "{{ env.API_URL }}"
```

**Job outputs**:
```yaml
phone: "{{ outputs.create_booking.phone }}"
```

**Hardcoded**:
```yaml
name: "John Doe"
timeout: 30
```

---

## Execution Order

### Linear Dependency

```yaml
jobs:
  job1: {...}
  job2:
    depends_on: [job1]  # Wait for job1
  job3:
    depends_on: [job2]  # Wait for job2
```

**Execution**: job1 → job2 → job3 (sequential)

### Parallel Execution

```yaml
jobs:
  setup: {...}
  test1:
    depends_on: [setup]  # Wait for setup
  test2:
    depends_on: [setup]  # Wait for setup (can run with test1)
  verify:
    depends_on: [test1, test2]  # Wait for both
```

**Execution**:
```
setup
  ├→ test1 ──┐
  └→ test2 ──→ verify
   (parallel)
```

---

## Common Patterns

### Setup → Test → Verify

```yaml
jobs:
  setup:
    tool: bash
    commands: [npm install]
  
  test:
    depends_on: [setup]
    tool: bash
    commands: [npm test]
    assertions:
      - type: status_code
        expected: 0
  
  report:
    depends_on: [test]
    tool: bash
    commands: [npm run coverage]
```

### Conditional Testing

```yaml
jobs:
  check_changes:
    tool: bash
    commands:
      - git diff --name-only
  
  unit_tests:
    depends_on: [check_changes]
    if: "{{ outputs.check_changes.contains .ts }}"
    tool: bash
    commands: [npm run test:unit]
  
  e2e_tests:
    depends_on: [check_changes]
    if: "{{ outputs.check_changes.contains .tsx }}"
    tool: bash
    commands: [npm run test:e2e]
```

### Multi-Environment Testing

```yaml
jobs:
  test_local:
    tool: bash
    commands: [npm run test]
  
  test_staging:
    tool: bash
    commands:
      - export API_URL=https://staging.api.com
      - npm run test:integration
    if: "{{ env.ENVIRONMENT == staging }}"
```

---

## Running Workflows

### Basic

```bash
gsd-test --workflow my-test.workflow.yml
```

### With Environment Override

```bash
gsd-test --workflow my-test.workflow.yml --env staging
```

### With Variables

```bash
gsd-test --workflow my-test.workflow.yml \
  --var name="Custom Name" \
  --var timeout=60
```

### Save Output

```bash
gsd-test --workflow my-test.workflow.yml --output results.json
```

### Dry Run (Show plan)

```bash
gsd-test --workflow my-test.workflow.yml --dry-run
```

---

## Debugging

### View Execution Plan

```bash
gsd-test --workflow my-test.workflow.yml --dry-run
```

### Enable Verbose Logging

```bash
GSD_VERBOSE=1 gsd-test --workflow my-test.workflow.yml
```

### Check Job Outputs

```bash
# After workflow runs
cat .planning/soldier-logs/workflow-execution.json
```

### Retry Failed Job

```bash
# Restart from specific job
gsd-test --workflow my-test.workflow.yml --from test
```

---

## Best Practices

✅ **DO**:
- Keep jobs focused on a single responsibility
- Use meaningful job names (setup, test, verify)
- Use depends_on to clarify dependencies
- Add descriptions to complex jobs
- Use assertions to validate results
- Set appropriate timeouts

❌ **DON'T**:
- Create long chains without parallel opportunities
- Use shell operators (&&, ||) — use separate jobs instead
- Hardcode environment variables — use {{ env.VAR }}
- Skip assertions — validate all critical paths
- Ignore timeout defaults — set explicit values

---

## DAG Architecture

This workflow system is **DAG-based** (Directed Acyclic Graph):

| Concept | Explanation |
|---------|------------|
| **Job** | Node in the graph |
| **Dependency** | Edge between nodes (depends_on) |
| **Parallel** | Multiple jobs with same dependency can run together |
| **Acyclic** | No circular dependencies allowed |
| **Directed** | Execution flows one direction only |

**Key benefit**: Automatically parallelizes jobs where possible while respecting dependencies.

---

## Related Docs

- [GSD Addon Architecture](./README.md)
- [Global Setup Guide](./GLOBAL-SETUP.md)
- [Test Orchestration Guide](./gsd-test/TEST-ORCHESTRATION-GUIDE.md)

---

**GSD Addon is a reusable, multi-project testing orchestration system.**
