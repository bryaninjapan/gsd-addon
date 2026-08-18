# GSD Dispatch System

Automated tool routing and execution framework for the GSD methodology.

## What is Dispatch?

Dispatch system automatically:

1. **Routes tasks** to appropriate tools (OpenCode vs Claude)
2. **Executes Phase plans** with minimal configuration
3. **Handles failures** with intelligent retry logic
4. **Manages state** across execution steps
5. **Logs all operations** for audit and debugging

## Usage

```bash
# Run Phase 1 in local environment
gsd-dispatch 1 local

# Run Phase 2 in staging
gsd-dispatch 2 staging

# Run with custom configuration
TARGET_ENV=staging gsd-dispatch 1 --mode plan
```

## Features

- **Smart Routing** — Decides whether to dispatch to OpenCode (for execution) or Claude (for analysis)
- **Error Recovery** — Automatic retry with exponential backoff
- **Environment Awareness** — Automatically detects and adapts to local/docker/staging/prod
- **Logging** — Detailed logs in `.planning/soldier-logs/`
- **State Management** — Tracks execution state across steps

## Configuration

Configure in project `.gsd-test.config`:

```bash
# Dispatch target (opencode or claude)
export GSD_DISPATCH_TARGET="opencode"

# Dispatch mode (plan, execute, test, research)
export GSD_DISPATCH_MODE="plan"

# Environment
export GSD_TEST_ENV="local"
```

## Integration

Works with:
- Phase plans (`.planning/phases/NN-*/NN-PLAN.md`)
- Test workflows (`.gsd-test/workflows/`)
- GSD agent framework

---

For complete documentation, see [../GLOBAL-SETUP.md](../GLOBAL-SETUP.md)
