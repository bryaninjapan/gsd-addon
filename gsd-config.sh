#!/bin/bash
#
# GSD Addon 全局配置管理
# 支持全局 + 項目級別的配置覆蓋
#

set -e

# 全局 GSD Addon 框架路徑（避免與 gsd-framework 衝突）
GSD_ADDON_HOME="${GSD_ADDON_HOME:-$HOME/.claude/gsd-addon}"
GSD_PROJECT_HOME="${GSD_PROJECT_HOME:-.}"

# 保持向後兼容性
GSD_GLOBAL_HOME="${GSD_ADDON_HOME}"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ==================== 配置加載函數 ====================

gsd_load_config() {
    # 加載配置，優先級:
    # 1. 項目級別 .gsd-test.config
    # 2. 全局 ~/.claude/gsd-addon/gsd-config.yaml
    # 3. 默認值

    local project_config="${GSD_PROJECT_HOME}/.gsd-test.config"
    local global_config="${GSD_GLOBAL_HOME}/gsd-config.yaml"

    # 默認配置
    export GSD_DISPATCH_MODE="plan"
    export GSD_TEST_ENV="local"
    export GSD_DISPATCH_TARGET="opencode"  # opencode or claude
    export GSD_TEST_PARALLEL=false
    export GSD_WORKFLOW_TIMEOUT=300

    # 加載全局配置
    if [ -f "$global_config" ]; then
        source "$global_config" 2>/dev/null || true
    fi

    # 加載項目配置（覆蓋全局）
    if [ -f "$project_config" ]; then
        source "$project_config" 2>/dev/null || true
    fi

    export GSD_CONFIG_LOADED=1
}

# ==================== 路徑解析函數 ====================

gsd_get_workflow_path() {
    # 獲取 workflow 路徑（支持項目級別 override）
    # 優先級：
    # 1. 項目: .gsd-test/workflows/xxx.workflow.yml
    # 2. 全局: ~/.claude/gsd-addon/gsd-test/workflows/xxx.workflow.yml

    local workflow_name="$1"
    local project_workflow="${GSD_PROJECT_HOME}/.gsd-test/workflows/${workflow_name}.workflow.yml"
    local global_workflow="${GSD_GLOBAL_HOME}/gsd-test/workflows/${workflow_name}.workflow.yml"

    if [ -f "$project_workflow" ]; then
        echo "$project_workflow"
    elif [ -f "$global_workflow" ]; then
        echo "$global_workflow"
    else
        echo "ERROR: Workflow not found: $workflow_name" >&2
        return 1
    fi
}

gsd_get_environments_path() {
    # 獲取環境配置路徑
    # 優先級：
    # 1. 項目: .gsd-test/environments/environments.yaml
    # 2. 全局: ~/.claude/gsd-addon/gsd-test/environments/environments.yaml

    local project_envs="${GSD_PROJECT_HOME}/.gsd-test/environments/environments.yaml"
    local global_envs="${GSD_GLOBAL_HOME}/gsd-test/environments/environments.yaml"

    if [ -f "$project_envs" ]; then
        echo "$project_envs"
    elif [ -f "$global_envs" ]; then
        echo "$global_envs"
    else
        return 1
    fi
}

gsd_get_cli_path() {
    # 獲取 CLI 工具路徑
    echo "${GSD_GLOBAL_HOME}/gsd-test/cli.py"
}

# ==================== 驗證函數 ====================

gsd_verify_setup() {
    # 驗證 GSD 框架是否正確安裝

    echo -e "${BLUE}🔍 Verifying GSD Addon setup...${NC}"

    local errors=0

    # 檢查全局框架
    if [ ! -d "$GSD_GLOBAL_HOME" ]; then
        echo -e "${RED}✗ Global framework not found: $GSD_GLOBAL_HOME${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✓ Global framework: $GSD_GLOBAL_HOME${NC}"
    fi

    # 檢查 dispatch 腳本（addon 的派工入口是 scripts/gsd-dispatch.sh）
    if [ ! -f "$GSD_GLOBAL_HOME/scripts/gsd-dispatch.sh" ]; then
        echo -e "${RED}✗ gsd-dispatch.sh not found${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✓ gsd-dispatch.sh found${NC}"
    fi

    # 檢查 test framework
    if [ ! -d "$GSD_GLOBAL_HOME/gsd-test" ]; then
        echo -e "${RED}✗ test framework not found${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✓ test framework found${NC}"
    fi

    # 檢查 Python
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}✗ Python 3 not found${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✓ Python 3: $(python3 --version)${NC}"
    fi

    # 檢查 PyYAML
    if ! python3 -c "import yaml" 2>/dev/null; then
        echo -e "${YELLOW}⚠ PyYAML not installed (optional)${NC}"
    else
        echo -e "${GREEN}✓ PyYAML installed${NC}"
    fi

    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}✅ GSD Addon setup OK${NC}"
        return 0
    else
        echo -e "${RED}❌ $errors error(s) found${NC}"
        return 1
    fi
}

# ==================== 顯示配置 ====================

gsd_show_config() {
    # 顯示當前配置

    gsd_load_config

    echo -e "${BLUE}═══ GSD Configuration ═══${NC}"
    echo "Global Home:         $GSD_GLOBAL_HOME"
    echo "Project Home:        $GSD_PROJECT_HOME"
    echo "Dispatch Mode:       $GSD_DISPATCH_MODE"
    echo "Test Environment:    $GSD_TEST_ENV"
    echo "Dispatch Target:     $GSD_DISPATCH_TARGET"
    echo "Workflow Timeout:    $GSD_WORKFLOW_TIMEOUT"
    echo ""

    local workflow_path
    workflow_path=$(gsd_get_workflow_path "booking-e2e" 2>/dev/null || echo "N/A")
    echo "Workflow Path:       $workflow_path"

    local envs_path
    envs_path=$(gsd_get_environments_path 2>/dev/null || echo "N/A")
    echo "Environments:        $envs_path"

    echo -e "${BLUE}═════════════════════════${NC}"
}

# ==================== 初始化項目 ====================

gsd_init_project() {
    # 初始化當前項目以使用全局 GSD 框架

    local project_dir="${GSD_PROJECT_HOME}"

    echo -e "${BLUE}🚀 Initializing GSD project in: $project_dir${NC}"

    # 創建 .gsd-test 目錄（如果不存在）
    mkdir -p "${project_dir}/.gsd-test/workflows"
    mkdir -p "${project_dir}/.gsd-test/environments"

    # 創建項目配置文件（如果不存在）
    if [ ! -f "${project_dir}/.gsd-test.config" ]; then
        cat > "${project_dir}/.gsd-test.config" << 'EOF'
#!/bin/bash
# GSD Project Configuration
# Copy or override any of these in your project to customize behavior

# 使用的環境
export GSD_TEST_ENV="local"

# 派工目標 (opencode 或 claude)
export GSD_DISPATCH_TARGET="opencode"

# 派工模式 (plan, execute, test, research)
export GSD_DISPATCH_MODE="test"

# Workflow 超時時間（秒）
export GSD_WORKFLOW_TIMEOUT=300

# 並行執行
export GSD_TEST_PARALLEL=false
EOF
        echo -e "${GREEN}✓ Created .gsd-test.config${NC}"
    else
        echo -e "${YELLOW}⚠ .gsd-test.config already exists${NC}"
    fi

    # 創建 .gitignore 規則（如果不存在）
    if [ ! -f "${project_dir}/.gsd-test/.gitignore" ]; then
        cat > "${project_dir}/.gsd-test/.gitignore" << 'EOF'
# GSD test framework - ignore local test outputs
test-results.json
test-results-*.json
*.log
__pycache__/
.pytest_cache/
EOF
        echo -e "${GREEN}✓ Created .gsd-test/.gitignore${NC}"
    fi

    echo -e "${GREEN}✅ Project initialized${NC}"
    gsd_show_config
}

# ==================== 主程序 ====================

case "${1:-help}" in
    load)
        gsd_load_config
        ;;
    verify)
        gsd_verify_setup
        ;;
    show)
        gsd_show_config
        ;;
    init)
        gsd_init_project
        ;;
    *)
        cat << 'EOF'
GSD Addon Global Configuration Manager

Usage:
  gsd-config load      Load configuration (sourced by dispatch.sh)
  gsd-config verify    Verify framework setup
  gsd-config show      Show current configuration
  gsd-config init      Initialize current project for GSD

Environment Variables (override in project .gsd-test.config):
  GSD_TEST_ENV             Test environment (local, docker, staging, prod)
  GSD_DISPATCH_TARGET      Dispatch target (opencode, claude)
  GSD_DISPATCH_MODE        Dispatch mode (plan, execute, test, research)
  GSD_WORKFLOW_TIMEOUT     Workflow timeout in seconds

Example:
  # Show current config
  gsd-config show

  # Initialize a new project
  cd my-project
  gsd-config init
EOF
        ;;
esac
