# Setting Up gsd-addon on GitHub

Quick guide to push this independent project to GitHub.

## 1. Create Repository

Go to [github.com/new](https://github.com/new) and create:

- **Repository name**: `gsd-addon`
- **Description**: "Global testing and dispatch framework for GSD methodology"
- **Public**: Yes
- **Initialize**: No (we have files already)

Copy the repository URL: `https://github.com/yourusername/gsd-addon.git`

## 2. Initialize Git Locally

```bash
cd ~/Documents/gsd-addon

# Initialize git
git init

# Configure user
git config user.name "Bryan Lee"
git config user.email "gn01968711@gmail.com"

# Add all files
git add -A

# Initial commit
git commit -m "Initial commit: GSD Addon v1.0.0

- Test Orchestration Engine
- Global dispatch system
- Multi-environment support
- Configuration management
- Complete documentation

This is a standalone, reusable framework for automated testing and execution.

Co-Authored-By: Claude Code <noreply@anthropic.com>"

# Add remote
git remote add origin https://github.com/yourusername/gsd-addon.git

# Rename branch to main
git branch -M main

# Push to GitHub
git push -u origin main
```

## 3. Create Release Tag

```bash
# Tag first release
git tag -a v1.0.0 -m "First stable release: GSD Addon

- Complete test orchestration system
- Global command installation
- Multi-environment configuration
- Comprehensive documentation

Ready for production use."

# Push tag
git push origin v1.0.0
```

## 4. Verify on GitHub

Visit your repository:
- https://github.com/yourusername/gsd-addon
- Check all files are present
- Verify release tag is created

## 5. Test Installation

From anywhere on your system:

```bash
# Clone the repository
git clone https://github.com/yourusername/gsd-addon.git ~/gsd-test
cd ~/gsd-test

# Run installation
bash install.sh

# Verify
gsd-config verify
```

## Optional: Add CI/CD

Create `.github/workflows/test.yml`:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      
      - name: Install
        run: bash install.sh
      
      - name: Verify
        run: gsd-config verify
```

---

**Done! Your gsd-addon is now a standalone GitHub project.**

Now soapwavehealing can use it as a dependency:

```bash
cd ~/Documents/soapwavehealing

# Just reference the global installation
gsd-test --workflow booking-e2e.workflow.yml
```
