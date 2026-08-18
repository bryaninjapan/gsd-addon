#!/bin/bash
#
# GSD Global Framework 安裝腳本
# 將 dispatch.sh 和 gsd-test framework 安裝到全局位置
# 讓所有項目都能使用
#

set -e

# 顏色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

GSD_ADDON_HOME="${GSD_ADDON_HOME:-$HOME/.claude/gsd-addon}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

echo -e "${BLUE}🚀 Installing GSD Addon Framework${NC}"
echo "   Addon Home: $GSD_ADDON_HOME"
echo "   Bin Dir:     $BIN_DIR"
echo ""

# 創建目錄
mkdir -p "$GSD_ADDON_HOME"
mkdir -p "$BIN_DIR"

# ==================== 安裝 dispatch 框架 ====================

echo -e "${BLUE}📦 Installing dispatch framework...${NC}"

if [ -d "dispatch" ]; then
    mkdir -p "$GSD_ADDON_HOME/dispatch"
    cp -r dispatch/* "$GSD_ADDON_HOME/dispatch/" 2>/dev/null || true
    echo -e "${GREEN}✓ dispatch framework installed${NC}"
else
    echo -e "${YELLOW}⚠ dispatch directory not found (optional)${NC}"
fi

# ==================== 安裝 dispatch 腳本與工具 ====================

echo -e "${BLUE}📦 Installing dispatch scripts...${NC}"

if [ -d "scripts" ]; then
    mkdir -p "$GSD_ADDON_HOME/scripts"
    cp -r scripts/* "$GSD_ADDON_HOME/scripts/" 2>/dev/null || true
    # 確保腳本可執行
    chmod +x "$GSD_ADDON_HOME/scripts/"*.sh 2>/dev/null || true
    echo -e "${GREEN}✓ dispatch scripts installed${NC}"
else
    echo -e "${YELLOW}⚠ scripts directory not found (optional)${NC}"
fi

# ==================== 安裝 prompt 範本 ====================

echo -e "${BLUE}📦 Installing dispatch prompt templates...${NC}"

if [ -d "prompts" ]; then
    mkdir -p "$GSD_ADDON_HOME/prompts"
    cp -r prompts/* "$GSD_ADDON_HOME/prompts/" 2>/dev/null || true
    echo -e "${GREEN}✓ dispatch prompts installed ($(ls prompts/*.md 2>/dev/null | wc -l | tr -d ' ') templates)${NC}"
else
    echo -e "${RED}✗ prompts directory not found — dispatch requires prompts/ templates${NC}"
    exit 1
fi

# ==================== 安裝 gsd-test 框架 ====================

echo -e "${BLUE}📦 Installing gsd-test framework...${NC}"

if [ -d "gsd-test/.gsd-test" ]; then
    mkdir -p "$GSD_ADDON_HOME/gsd-test"
    cp -r gsd-test/.gsd-test/* "$GSD_ADDON_HOME/gsd-test/"
    chmod +x "$GSD_ADDON_HOME/gsd-test/cli.py"
    echo -e "${GREEN}✓ gsd-test framework installed${NC}"
else
    echo -e "${RED}✗ gsd-test/.gsd-test directory not found${NC}"
    exit 1
fi

# ==================== 安裝 gsd-config.sh ====================

echo -e "${BLUE}📦 Installing gsd-config.sh...${NC}"

if [ -f "gsd-config.sh" ]; then
    cp gsd-config.sh "$GSD_ADDON_HOME/gsd-config.sh"
    echo -e "${GREEN}✓ gsd-config.sh installed${NC}"
else
    echo -e "${YELLOW}⚠ gsd-config.sh not found (optional)${NC}"
fi

# ==================== 創建全局命令 ====================

echo -e "${BLUE}📦 Creating global commands...${NC}"

# gsd-dispatch 命令
cat > "$BIN_DIR/gsd-dispatch" << 'EOF'
#!/bin/bash
# Global GSD Dispatch command
#
# Usage: gsd-dispatch <phase> [env]
#        RETRY=true gsd-dispatch <phase> [env]   # 啟用重試 wrapper
#
# Routes to: gsd-framework dispatch system
#

export GSD_ADDON_HOME="${GSD_ADDON_HOME:-$HOME/.claude/gsd-addon}"
export GSD_GLOBAL_HOME="${GSD_GLOBAL_HOME:-$HOME/.claude/gsd-framework}"

# 加載 addon 配置（用 load 避免觸發 gsd-config.sh 的 usage 輸出）
if [ -f "$GSD_ADDON_HOME/gsd-config.sh" ]; then
    source "$GSD_ADDON_HOME/gsd-config.sh" load
fi

RETRY="${RETRY:-false}"

# 查找 dispatch 可執行檔
if [ ! -f "$GSD_ADDON_HOME/scripts/gsd-dispatch.sh" ]; then
    echo "❌ gsd-dispatch.sh not found at $GSD_ADDON_HOME/scripts/" >&2
    echo "   Please check your gsd-addon installation." >&2
    exit 1
fi

if [[ "$RETRY" == "true" ]]; then
    if [ -f "$GSD_ADDON_HOME/scripts/dispatch-with-retry.sh" ]; then
        exec "$GSD_ADDON_HOME/scripts/dispatch-with-retry.sh" "$@"
    else
        echo "❌ dispatch-with-retry.sh not found at $GSD_ADDON_HOME/scripts/ (RETRY=true)" >&2
        exit 1
    fi
else
    exec "$GSD_ADDON_HOME/scripts/gsd-dispatch.sh" "$@"
fi
EOF
chmod +x "$BIN_DIR/gsd-dispatch"
echo -e "${GREEN}✓ gsd-dispatch command installed${NC}"

# gsd-test 命令
cat > "$BIN_DIR/gsd-test" << 'EOF'
#!/bin/bash
# Global GSD Test command (Test Orchestration Framework)
#
# Usage: gsd-test --workflow <workflow.yml> [--env <env>] [--output <file>]
#

export GSD_ADDON_HOME="${GSD_ADDON_HOME:-$HOME/.claude/gsd-addon}"

# 加載 addon 配置（用 load 避免觸發 gsd-config.sh 的 usage 輸出）
if [ -f "$GSD_ADDON_HOME/gsd-config.sh" ]; then
    source "$GSD_ADDON_HOME/gsd-config.sh" load
fi

# 運行 test orchestrator
python3 "$GSD_ADDON_HOME/gsd-test/cli.py" "$@"
EOF
chmod +x "$BIN_DIR/gsd-test"
echo -e "${GREEN}✓ gsd-test command installed${NC}"

# gsd-addon-config 命令（避免與 gsd-framework 的 gsd-config 衝突）
cat > "$BIN_DIR/gsd-addon-config" << 'EOF'
#!/bin/bash
# GSD Addon Configuration command

export GSD_ADDON_HOME="${GSD_ADDON_HOME:-$HOME/.claude/gsd-addon}"

exec "$GSD_ADDON_HOME/gsd-config.sh" "$@"
EOF
chmod +x "$BIN_DIR/gsd-addon-config"
echo -e "${GREEN}✓ gsd-addon-config command installed${NC}"

# ==================== 更新 PATH ====================

echo -e "${BLUE}📝 Updating PATH...${NC}"

if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
    echo -e "${GREEN}✓ $BIN_DIR already in PATH${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠ Add this to your ~/.bashrc or ~/.zshrc:${NC}"
    echo ""
    echo "  export PATH=\"\$PATH:$BIN_DIR\""
    echo ""
    echo -e "${YELLOW}Then run: source ~/.bashrc (or ~/.zshrc)${NC}"
fi

# ==================== 驗證安裝 ====================

echo -e "${BLUE}🔍 Verifying installation...${NC}"

source "$GSD_ADDON_HOME/gsd-config.sh"
if declare -f gsd_verify_setup > /dev/null; then
    gsd_verify_setup
fi

# ==================== 完成 ====================

echo ""
echo -e "${GREEN}✅ GSD Addon Framework installed successfully!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Add to PATH: export PATH=\"\$PATH:$BIN_DIR\""
echo "  2. Run tests: gsd-test --workflow booking-e2e.workflow.yml"
echo "  3. Try dispatch: cd my-project && $GSD_ADDON_HOME/scripts/gsd-dispatch.sh 1 execute"
echo ""
echo -e "${BLUE}Available commands:${NC}"
echo "  gsd-test --workflow <name>           # Run test workflow"
echo "  gsd-test --workflow <name> --env <env>  # Specify environment"
echo "  gsd-addon-config show                # Show addon configuration"
echo ""
echo -e "${BLUE}Dispatch scripts:${NC}"
echo "  $GSD_ADDON_HOME/scripts/gsd-dispatch.sh      # Phase dispatch (research/plan/execute)"
echo "  $GSD_ADDON_HOME/scripts/dispatch-with-retry.sh # Retry wrapper (RETRY=true gsd-dispatch)"
echo "  $GSD_ADDON_HOME/scripts/gsd-permission-audit.sh  # Cross-project permission check"
echo ""
echo -e "${YELLOW}ℹ️  Documentation:${NC}"
echo "  - Dispatch guide: $GSD_ADDON_HOME/dispatch/DISPATCH-COMPLETE-GUIDE.md"
echo "  - ScheduleWakeup & scheduling: $GSD_ADDON_HOME/SCHEDULE-WAKEUP-GUIDE.md"
echo "  - Integration guide: $GSD_ADDON_HOME/INTEGRATION-GUIDE.md"
echo ""
echo -e "${YELLOW}ℹ️  Notes:${NC}"
echo "  - GSD Addon works alongside gsd-framework (no conflicts)"
echo "  - Use 'gsd-addon-config' for addon-specific config"
echo "  - Use 'gsd-config' (from gsd-framework) for main GSD config"
echo "  - Dispatch supports: research/plan/execute modes + cross-project + dynamic scheduling"
echo ""
