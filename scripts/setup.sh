#!/bin/bash
# Everstar Automation Setup Script
# Prepares your environment for autonomous ticket execution
# Usage: ./scripts/setup.sh

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Everstar Automation Setup           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Function to check command existence
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to prompt for input
prompt() {
    local prompt_text="$1"
    local var_name="$2"
    local default_value="$3"

    if [ -n "$default_value" ]; then
        read -p "$prompt_text [$default_value]: " input
        eval "$var_name=\"\${input:-$default_value}\""
    else
        read -p "$prompt_text: " input
        eval "$var_name=\"$input\""
    fi
}

echo -e "${CYAN}Step 1: Checking Prerequisites${NC}"
echo ""

# Check Claude CLI
if command_exists claude; then
    echo -e "${GREEN}✓${NC} Claude CLI installed: $(which claude)"
else
    echo -e "${RED}✗${NC} Claude CLI not found"
    echo -e "  ${YELLOW}Install:${NC} npm install -g @anthropic-ai/claude-code"
    echo -e "  ${YELLOW}Or:${NC} brew install claude-ai/tap/claude"
    exit 1
fi

# Check GitHub CLI
if command_exists gh; then
    echo -e "${GREEN}✓${NC} GitHub CLI installed: $(which gh)"

    # Check GitHub auth
    if gh auth status &> /dev/null; then
        GH_USER=$(gh api user -q .login)
        echo -e "${GREEN}✓${NC} GitHub authenticated as: $GH_USER"
    else
        echo -e "${YELLOW}!${NC} GitHub not authenticated"
        echo -e "  Run: ${CYAN}gh auth login${NC}"
        echo ""
        read -p "Authenticate now? (y/n): " auth_now
        if [ "$auth_now" = "y" ]; then
            gh auth login
        else
            echo -e "${RED}Setup incomplete. Please run 'gh auth login' and try again.${NC}"
            exit 1
        fi
    fi
else
    echo -e "${RED}✗${NC} GitHub CLI not found"
    echo -e "  ${YELLOW}Install:${NC} brew install gh"
    exit 1
fi

# Check Node/npm
if command_exists npm; then
    echo -e "${GREEN}✓${NC} npm installed: $(npm --version)"
else
    echo -e "${RED}✗${NC} npm not found"
    echo -e "  ${YELLOW}Install:${NC} brew install node"
    exit 1
fi

echo ""
echo -e "${CYAN}Step 2: Configure Repository Path${NC}"
echo ""

# Default everstar repo path
DEFAULT_REPO="/Users/$(whoami)/Desktop/everstar/everstar"
prompt "Everstar repository path" EVERSTAR_REPO "$DEFAULT_REPO"

# Verify repo exists
if [ ! -d "$EVERSTAR_REPO" ]; then
    echo -e "${RED}✗${NC} Repository not found at: $EVERSTAR_REPO"
    echo -e "  Please clone the repository first or provide correct path"
    exit 1
fi

# Verify it's a git repo
if [ ! -d "$EVERSTAR_REPO/.git" ]; then
    echo -e "${RED}✗${NC} Not a git repository: $EVERSTAR_REPO"
    exit 1
fi

echo -e "${GREEN}✓${NC} Repository found: $EVERSTAR_REPO"

# Update everstar-cli.sh with correct path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sed -i.bak "s|EVERSTAR_REPO=\".*\"|EVERSTAR_REPO=\"$EVERSTAR_REPO\"|" "$SCRIPT_DIR/everstar-cli.sh"
rm -f "$SCRIPT_DIR/everstar-cli.sh.bak"
echo -e "${GREEN}✓${NC} Updated everstar-cli.sh with repository path"

echo ""
echo -e "${CYAN}Step 3: Configure Linear MCP${NC}"
echo ""

echo "You need a Linear API key to fetch ticket details automatically."
echo "Get your key from: https://linear.app/settings/api"
echo ""

# Check if Linear MCP already configured
if grep -q "@hatcloud/linear-mcp" ~/.claude.json 2>/dev/null; then
    echo -e "${YELLOW}!${NC} Linear MCP already configured in ~/.claude.json"
    read -p "Reconfigure? (y/n): " reconfig
    if [ "$reconfig" != "y" ]; then
        echo -e "${GREEN}✓${NC} Using existing Linear configuration"
        LINEAR_CONFIGURED=true
    fi
fi

if [ "$LINEAR_CONFIGURED" != "true" ]; then
    prompt "Linear API Key" LINEAR_API_KEY

    if [ -z "$LINEAR_API_KEY" ]; then
        echo -e "${RED}✗${NC} Linear API key required"
        exit 1
    fi

    # Backup existing .claude.json
    if [ -f ~/.claude.json ]; then
        cp ~/.claude.json ~/.claude.json.backup.$(date +%Y%m%d_%H%M%S)
        echo -e "${GREEN}✓${NC} Backed up existing ~/.claude.json"
    fi

    # Add/update Linear MCP configuration
    if [ ! -f ~/.claude.json ]; then
        echo '{}' > ~/.claude.json
    fi

    # Use jq to update config (install if needed)
    if ! command_exists jq; then
        echo -e "${YELLOW}Installing jq for JSON manipulation...${NC}"
        brew install jq
    fi

    # Update Linear MCP config
    tmp_config=$(mktemp)
    jq --arg key "$LINEAR_API_KEY" '
        .projects = (.projects // {}) |
        .projects["/Users/\(env.USER)/Desktop/swarm-exp"] = (
            .projects["/Users/\(env.USER)/Desktop/swarm-exp"] // {} |
            .mcpServers.linear = {
                "type": "stdio",
                "command": "npx",
                "args": ["-y", "@hatcloud/linear-mcp"],
                "env": {
                    "LINEAR_API_KEY": $key
                }
            }
        )
    ' ~/.claude.json > "$tmp_config"

    mv "$tmp_config" ~/.claude.json
    echo -e "${GREEN}✓${NC} Linear MCP configured in ~/.claude.json"
fi

echo ""
echo -e "${CYAN}Step 4: Test Linear Connection${NC}"
echo ""

# Test Linear API
echo "Testing Linear API connection..."
if [ -n "$LINEAR_API_KEY" ]; then
    TEST_KEY="$LINEAR_API_KEY"
else
    TEST_KEY=$(jq -r '.projects["/Users/\(env.USER)/Desktop/swarm-exp"].mcpServers.linear.env.LINEAR_API_KEY // empty' ~/.claude.json 2>/dev/null)
fi

if [ -z "$TEST_KEY" ]; then
    echo -e "${YELLOW}!${NC} Could not extract Linear API key for testing"
else
    VIEWER=$(curl -s -H "Authorization: $TEST_KEY" \
        -H "Content-Type: application/json" \
        -d '{"query":"query { viewer { name email } }"}' \
        https://api.linear.app/graphql | jq -r '.data.viewer.name // empty')

    if [ -n "$VIEWER" ]; then
        echo -e "${GREEN}✓${NC} Linear API working! Connected as: $VIEWER"
    else
        echo -e "${RED}✗${NC} Linear API test failed. Check your API key."
        exit 1
    fi
fi

echo ""
echo -e "${CYAN}Step 5: Install claude-flow CLI${NC}"
echo ""

# Test claude-flow CLI
if npx @claude-flow/cli@latest --version &> /dev/null; then
    echo -e "${GREEN}✓${NC} claude-flow CLI accessible"
else
    echo -e "${YELLOW}!${NC} Installing claude-flow CLI..."
    npm install -g @claude-flow/cli@latest
    echo -e "${GREEN}✓${NC} claude-flow CLI installed"
fi

echo ""
echo -e "${CYAN}Step 6: Create Required Directories${NC}"
echo ""

# Create necessary directories
mkdir -p "$EVERSTAR_REPO/.claude"
echo -e "${GREEN}✓${NC} Created $EVERSTAR_REPO/.claude/"

# Copy ticket-bot-standards.md to everstar repo
cp "$SCRIPT_DIR/../.claude/ticket-bot-standards.md" "$EVERSTAR_REPO/.claude/"
echo -e "${GREEN}✓${NC} Copied ticket-bot-standards.md to everstar repo"

echo ""
echo -e "${CYAN}Step 7: Verify Setup${NC}"
echo ""

# Run verification checks
echo "Running verification checks..."
echo ""

# Check 1: Repository
if [ -d "$EVERSTAR_REPO/.git" ]; then
    echo -e "${GREEN}✓${NC} Everstar repository configured"
else
    echo -e "${RED}✗${NC} Everstar repository issue"
fi

# Check 2: Claude CLI
if command_exists claude; then
    echo -e "${GREEN}✓${NC} Claude CLI ready"
else
    echo -e "${RED}✗${NC} Claude CLI missing"
fi

# Check 3: GitHub auth
if gh auth status &> /dev/null; then
    echo -e "${GREEN}✓${NC} GitHub authenticated"
else
    echo -e "${RED}✗${NC} GitHub not authenticated"
fi

# Check 4: Linear MCP
if grep -q "@hatcloud/linear-mcp" ~/.claude.json 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Linear MCP configured"
else
    echo -e "${RED}✗${NC} Linear MCP not configured"
fi

# Check 5: claude-flow CLI
if npx @claude-flow/cli@latest --version &> /dev/null; then
    echo -e "${GREEN}✓${NC} claude-flow CLI available"
else
    echo -e "${RED}✗${NC} claude-flow CLI missing"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Setup Complete!                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}Quick Start:${NC}"
echo ""
echo -e "  1. Run automation:"
echo -e "     ${YELLOW}./scripts/everstar-cli.sh ENG-XXXX${NC}"
echo ""
echo -e "  2. Check status:"
echo -e "     ${YELLOW}cd $EVERSTAR_REPO && git status${NC}"
echo ""
echo -e "  3. Cleanup old work:"
echo -e "     ${YELLOW}./scripts/cleanup.sh${NC}"
echo ""

echo -e "${CYAN}Documentation:${NC}"
echo -e "  • README: ./README.md"
echo -e "  • Standards: ./.claude/ticket-bot-standards.md"
echo -e "  • Research: ./docs/ticket-enrichment-research.md"
echo ""

echo -e "${CYAN}Need Help?${NC}"
echo -e "  • Ask in #engineering-tools Slack channel"
echo -e "  • File issue: https://github.com/everstarai/automation/issues"
echo ""
