# GSD Addon

**A comprehensive testing and deployment orchestration framework for the GSD (General-Soldier) methodology**

Version: 1.0.0  
Status: Production Ready

---

## 🎯 What is GSD Addon?

GSD Addon provides:

- **🧪 Test Orchestration** — YAML-based workflow definitions for automated testing across environments
- **📦 Dispatch System** — Automated code execution with smart tool routing (OpenCode vs Claude)
- **🌍 Multi-Environment Support** — Same workflows run on local/docker/staging/production
- **⚙️ Global Commands** — `gsd-test`, `gsd-dispatch`, `gsd-config` available in any project
- **🔄 Cross-Project Reusability** — Define once, use everywhere

---

## ⚡ Quick Answer: Do I Need to Reinstall?

| Scenario | Reinstall? | When? |
|----------|-----------|-------|
| Modify `/Documents/gsd-addon` locally | ❌ No | Changes apply immediately |
| Modify `~/.claude/gsd-addon/` directly | ❌ No | But sync back to source! |
| Pull new changes from GitHub | ✅ Yes | After `git pull`, run `bash install.sh` |
| Use in another project | ❌ No | All projects share global version |

**👉 See [DEVELOPMENT-WORKFLOW.md](./DEVELOPMENT-WORKFLOW.md) for detailed development guide.**

---

## 📦 Installation

### Quick Start (3 minutes)

```bash
# Clone this repository
git clone https://github.com/bryaninjapan/gsd-addon.git
cd gsd-addon

# Run installation
bash install.sh

# Verify
gsd-config verify
```

### What Gets Installed

- Global commands in `~/.local/bin/`
- Framework in `~/.claude/gsd-addon/`
- Configuration system with auto-discovery

### Add to PATH

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$PATH:$HOME/.local/bin"

# Reload
source ~/.bashrc
```

---

## 🚀 Usage

### Initialize a Project

```bash
cd my-project
gsd-config init
```

Creates:
- `.gsd-test/` — Project-specific overrides (optional)
- `.gsd-test.config` — Project configuration

### Run Tests

```bash
# Use global workflow
gsd-test --workflow booking-e2e.workflow.yml

# Use project-specific workflow
gsd-test --workflow my-custom-test.workflow.yml --env staging

# Save results
gsd-test --workflow booking-e2e.workflow.yml --output results.json
```

### Run Dispatch

```bash
gsd-dispatch 1 local      # Phase 1, local environment
gsd-dispatch 2 staging    # Phase 2, staging environment
```

### Manage Configuration

```bash
gsd-config show           # Display current configuration
gsd-config verify         # Verify framework installation
gsd-config init           # Initialize project
```

---

## 🏗️ Project Structure

```
gsd-addon/
├── README.md                        # This file
├── LICENSE                          # MIT License
├── CONTRIBUTING.md                  # Contribution guidelines
│
├── gsd-test/                        # Test Orchestration Framework
│   ├── engine/
│   │   ├── workflow_engine.py       # YAML workflow parser
│   │   ├── context.py               # Execution context
│   │   ├── tools.py                 # Tool adapters
│   │   └── __init__.py
│   ├── workflows/
│   │   └── booking-e2e.workflow.yml # Example workflow
│   ├── environments/
│   │   └── environments.yaml        # Environment configurations
│   ├── agents/
│   │   └── gsd-test-orchestrator.md # GSD agent definition
│   ├── cli.py                       # CLI tool
│   ├── README.md
│   ├── TEST-ORCHESTRATION-GUIDE.md
│   ├── QUICK-START.md
│   └── IMPLEMENTATION-SUMMARY.md
│
├── dispatch/
│   └── dispatch.sh                  # Automated dispatch system
│
├── gsd-config.sh                    # Global configuration manager
├── install.sh                       # Installation script
└── GLOBAL-SETUP.md                  # Detailed setup guide
```

---

## 📚 Documentation

- **[QUICK-START.md](./gsd-test/QUICK-START.md)** — 5-minute getting started
- **[GLOBAL-SETUP.md](./GLOBAL-SETUP.md)** — Comprehensive setup guide
- **[TEST-ORCHESTRATION-GUIDE.md](./gsd-test/TEST-ORCHESTRATION-GUIDE.md)** — Complete framework documentation
- **[gsd-test-orchestrator.md](./gsd-test/agents/gsd-test-orchestrator.md)** — GSD integration documentation

---

## 🔄 Environment Support

| Environment | Type | Use Case |
|-------------|------|----------|
| `local` | Wrangler Pages | Local development |
| `docker` | Docker Compose | Containerized testing |
| `staging` | Cloud staging | Pre-production validation |
| `production` | Production | Read-only verification |

Configure in `gsd-test/environments/environments.yaml` or project-level `.gsd-test/environments/`.

---

## 🎯 Global Commands

### gsd-test

Run automated test workflows.

```bash
gsd-test --workflow <name>           # Run test
gsd-test --workflow <name> --env prod # Specify environment
gsd-test --workflow <name> --output out.json  # Save results
gsd-test --workflow <name> --var key=value  # Override variables
```

### gsd-dispatch

Execute GSD dispatch with automatic tool routing.

```bash
gsd-dispatch <phase> <env>           # Run phase in environment
```

Routes to:
- OpenCode (default) — for execution tasks
- Claude — for analysis/planning tasks

### gsd-config

Manage GSD configuration.

```bash
gsd-config init                      # Initialize project
gsd-config show                      # Display configuration
gsd-config verify                    # Verify installation
```

---

## 🔧 Workflow Definition

Workflows are defined in YAML:

```yaml
name: "Test Name"
description: "What this tests"

env:
  BASE_URL: "http://localhost:8788"

variables:
  username: "test_user"

jobs:
  setup:
    steps:
      - name: "Start server"
        tool: preview_start
        params:
          name: dev
      
  test:
    needs: [setup]
    steps:
      - name: "Run test"
        tool: bash
        params:
          command: "curl {{ env.BASE_URL }}/api/health"
        assertions:
          - contains: "ok"
```

Features:
- Variable interpolation (`{{ env.VAR }}`, `{{ variables.var }}`)
- Conditional execution (`if:` statements)
- Job dependencies (`needs:` declaration)
- Failure handling and retry
- Assertions and validation

---

## 📊 Integration with GSD

Integrates seamlessly with the GSD (General-Soldier) methodology:

- **Planner** — Define test workflows in phase plans
- **Executor** — Auto-run tests after execution completes
- **Verifier** — Verify phase goals with automated tests
- **Claude** — All agents can invoke test framework

---

## 🤝 Contributing

Contributions welcome! Please:

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

---

## 📄 License

This project is licensed under the MIT License — see [LICENSE](./LICENSE) file for details.

---

## 🆘 Support

- **Quick Start**: [QUICK-START.md](./gsd-test/QUICK-START.md)
- **Setup Guide**: [GLOBAL-SETUP.md](./GLOBAL-SETUP.md)
- **Full Documentation**: [TEST-ORCHESTRATION-GUIDE.md](./gsd-test/TEST-ORCHESTRATION-GUIDE.md)
- **Issues**: Open a GitHub issue for bugs and questions

---

## 🚀 Quick Links

- **Repository**: [github.com/bryaninjapan/gsd-addon](https://github.com/bryaninjapan/gsd-addon)
- **Releases**: [Releases](https://github.com/bryaninjapan/gsd-addon/releases)
- **Issues**: [GitHub Issues](https://github.com/bryaninjapan/gsd-addon/issues)

---

**Made with ❤️ for the GSD community**

v1.0.0 | MIT License | 2026
