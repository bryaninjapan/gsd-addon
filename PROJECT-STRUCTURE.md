# GSD Addon Project Structure

## Separation of Concerns

### 🏗️ gsd-addon (This Repository)

**Purpose**: Global, reusable testing and dispatch framework

**Scope**:
- Test Orchestration Engine (`gsd-test/engine/`)
- Global workflow templates (`gsd-test/workflows/`)
- Global environment configurations (`gsd-test/environments/`)
- Dispatch system (`dispatch/dispatch.sh`)
- Configuration management (`gsd-config.sh`)
- Installation automation (`install.sh`)
- Framework documentation

**Used By**: Any project that needs automated testing and dispatch

**Installation**:
```bash
git clone https://github.com/yourusername/gsd-addon.git
cd gsd-addon
bash install.sh
```

**Result**:
- Global commands: `gsd-test`, `gsd-dispatch`, `gsd-config`
- Framework in: `~/.claude/gsd-addon/`
- Available in: Any project

---

### 📦 soapwavehealing (Application Repository)

**Purpose**: Booking platform application using GSD Addon

**Scope**:
- Application-specific code
- Project-level workflow overrides (`.gsd-test/workflows/`)
- Project-level environment customization (`.gsd-test/environments/`)
- Project configuration (`.gsd-test.config`)
- Application planning and architecture
- Application-specific tests and verification

**Dependencies**: Uses global gsd-addon

**Structure**:
```
soapwavehealing/
├── src/                      # Application code
├── .gsd-test/                # Project-level overrides
│   ├── workflows/            # Custom test workflows
│   └── environments/         # Custom environment configs
├── .gsd-test.config          # Project configuration
├── .planning/                # Phase plans and documentation
└── GLOBAL-DEPLOY.md          # How to use gsd-addon
```

---

## Relationship Diagram

```
gsd-addon (Standalone)
    ↓ (installed globally)
    
~/.claude/gsd-addon/
    ↑ (used by)
    
Any Project (including soapwavehealing)
    ├── Global workflows (via symlink or reference)
    └── Project-level overrides in .gsd-test/
```

---

## Workflow Resolution Order

When running: `gsd-test --workflow booking-e2e.workflow.yml`

```
1. Check project-level
   soapwavehealing/.gsd-test/workflows/booking-e2e.workflow.yml
   
   If found → Use it
   
2. Check global
   ~/.claude/gsd-addon/gsd-test/workflows/booking-e2e.workflow.yml
   
   If found → Use it
   
3. Error
   Workflow not found
```

---

## Configuration Resolution Order

When loading: `.gsd-test.config`

```
1. Project configuration
   soapwavehealing/.gsd-test.config
   
   Variables and settings defined here
   
2. Global configuration
   ~/.claude/gsd-addon/gsd-config.sh
   
   Fallback for undefined variables
   
3. Defaults
   Hardcoded defaults in engine
```

---

## Multi-Project Setup

### Project A: soapwavehealing

```bash
cd ~/Documents/soapwavehealing

# Initialize
gsd-config init

# Use global workflows
gsd-test --workflow booking-e2e.workflow.yml

# Use custom workflows
gsd-test --workflow custom-soapwave-test.workflow.yml
```

### Project B: another-app

```bash
cd ~/Documents/another-app

# Initialize
gsd-config init

# Use same global workflows
gsd-test --workflow booking-e2e.workflow.yml  # Reusable!

# Use project-specific customization
cat .gsd-test.config  # Different settings than soapwavehealing
```

---

## Version Management

### gsd-addon Releases

```
v1.0.0 — Initial release with test orchestration
v1.1.0 — Global installation support
v1.2.0 — Extended workflow features
v2.0.0 — (Future) Major enhancements
```

Each soapwavehealing release can pin to a specific gsd-addon version:

```bash
# In soapwavehealing/.gsd-test.config
export GSD_FRAMEWORK_VERSION="v1.0.0"

# Or use latest (default)
export GSD_FRAMEWORK_VERSION="latest"
```

---

## Maintenance

### Update gsd-addon

```bash
# Pull latest from repository
cd ~/Documents/gsd-addon
git pull origin main

# Update global installation
bash install.sh

# All projects automatically get updates
```

### Update soapwavehealing

```bash
# soapwavehealing pulls its own updates
cd ~/Documents/soapwavehealing
git pull origin main

# Does NOT require re-installing gsd-addon
```

---

## Key Benefits of Separation

✅ **Independent versioning** — gsd-addon and soapwavehealing evolve separately  
✅ **Reusability** — gsd-addon works with multiple projects  
✅ **Clean dependencies** — soapwavehealing only depends on global framework  
✅ **Clear ownership** — Framework vs application concerns clearly divided  
✅ **Easy updates** — Update either repository independently  
✅ **Community sharing** — gsd-addon is a public, reusable tool  

---

## Related Documentation

- [gsd-addon README](./README.md)
- [soapwavehealing README](https://github.com/yourusername/soapwavehealing)
- [Global Setup Guide](./GLOBAL-SETUP.md)
- [Test Orchestration Guide](./gsd-test/TEST-ORCHESTRATION-GUIDE.md)

---

**gsd-addon is a standalone, reusable tool. soapwavehealing is one project that uses it.**
