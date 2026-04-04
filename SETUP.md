# Team Setup Guide

Complete setup instructions for the Everstar automated ticket system.

## Prerequisites

Before running the setup script, you need:

### 1. GitHub Access

- **GitHub account** with access to the Everstar repository
- **GitHub CLI** installed: `brew install gh`
- You'll authenticate during setup via `gh auth login`

### 2. Linear Access

- **Linear account** with access to the Everstar workspace
- **Linear API key** from: https://linear.app/settings/api
  - Click "Create key"
  - Name it: "Everstar Automation"
  - Copy the key (you'll need it during setup)

### 3. System Requirements

- **macOS** (tested on macOS 12+)
- **Node.js 18+**: `brew install node`
- **Claude CLI**: `npm install -g @anthropic-ai/claude-code`
- **Everstar repository** cloned locally

## Setup Steps

### Step 1: Clone This Repository

```bash
git clone git@github.com:everstarai/everstar-swarms.git
cd everstar-swarms
```

### Step 2: Run Setup Script

```bash
./scripts/setup.sh
```

The script will guide you through:

#### 2a. Prerequisites Check

Verifies:
- Claude CLI installed
- GitHub CLI installed
- npm installed

If any are missing, it will tell you how to install them.

#### 2b. GitHub Authentication

```
GitHub CLI installed: /opt/homebrew/bin/gh
! GitHub not authenticated
  Run: gh auth login

Authenticate now? (y/n): y
```

**What to do:**
- Type `y` and press Enter
- Follow the interactive prompts:
  1. Choose "GitHub.com"
  2. Choose "HTTPS" protocol
  3. Choose "Login with a web browser"
  4. Copy the one-time code shown
  5. Press Enter to open browser
  6. Paste code and authorize

You'll see: `✓ GitHub authenticated as: <your-username>`

#### 2c. Repository Path

```
Everstar repository path [/Users/you/Desktop/everstar/everstar]:
```

**What to do:**
- Press Enter to use default path
- OR type the full path to your Everstar clone

#### 2d. Linear MCP Configuration

```
You need a Linear API key to fetch ticket details automatically.
Get your key from: https://linear.app/settings/api

Linear API Key:
```

**What to do:**
1. Open https://linear.app/settings/api in your browser
2. Click "Create key"
3. Name: "Everstar Automation"
4. Copy the generated key (starts with `lin_api_`)
5. Paste into terminal and press Enter

The script will:
- Save key to `~/.claude.json`
- Test the connection
- Show: `✓ Linear API working! Connected as: <your-name>`

### Step 3: Verify Setup

The script automatically runs verification:

```
✓ Everstar repository configured
✓ Claude CLI ready
✓ GitHub authenticated
✓ Linear MCP configured
✓ claude-flow CLI available
```

If all checks pass: **Setup Complete!**

## First Run

Test the automation:

```bash
./scripts/everstar-cli.sh ENG-XXXX
```

Replace `ENG-XXXX` with a real Linear ticket ID from your workspace.

**What happens:**
1. Fetches ticket from Linear (2-3 min)
2. Analyzes and enriches if needed (2-3 min)
3. Creates implementation plan (3-5 min)
4. Reviews plan automatically (2-3 min)
5. Spawns 6 agents to implement (15-25 min)
6. Creates PR with tests and quality gates

**Total:** ~25-30 minutes for complete ticket → PR

## Troubleshooting

### GitHub Auth Issues

**Error:** `GitHub not authenticated`

**Fix:**
```bash
gh auth login
# Follow prompts to authenticate
```

**Verify:**
```bash
gh auth status
# Should show: ✓ Logged in to github.com as <username>
```

### Linear API Issues

**Error:** `Linear API test failed`

**Fix:**
1. Verify key is valid: https://linear.app/settings/api
2. Regenerate if needed
3. Reconfigure:
   ```bash
   ./scripts/setup.sh
   # Choose "y" when asked to reconfigure Linear
   ```

**Verify:**
```bash
grep "LINEAR_API_KEY" ~/.claude.json
# Should show: "LINEAR_API_KEY": "lin_api_..."
```

### Repository Path Issues

**Error:** `Repository not found at: /path/to/everstar`

**Fix:**
1. Clone Everstar repo if not already:
   ```bash
   git clone <everstar-repo-url> ~/Desktop/everstar/everstar
   ```
2. Run setup again:
   ```bash
   ./scripts/setup.sh
   # Enter correct path when prompted
   ```

### Claude CLI Issues

**Error:** `Claude CLI not found`

**Fix:**
```bash
npm install -g @anthropic-ai/claude-code
```

**Verify:**
```bash
claude --version
# Should show version number
```

## Security Notes

### API Keys

- Your Linear API key is stored in `~/.claude.json`
- This file is in your home directory (not in the repo)
- **Never commit `.claude.json` to git**
- Keep your API key private

### GitHub Authentication

- GitHub CLI uses OAuth (no passwords stored)
- Authentication is system-wide (all terminals)
- To logout: `gh auth logout`

## Configuration Files

After setup, these files are configured:

### `~/.claude.json`
```json
{
  "projects": {
    "/Users/you/path/to/everstar-swarms": {
      "mcpServers": {
        "linear": {
          "type": "stdio",
          "command": "npx",
          "args": ["-y", "@hatcloud/linear-mcp"],
          "env": {
            "LINEAR_API_KEY": "lin_api_..."
          }
        }
      }
    }
  }
}
```

### `scripts/everstar-cli.sh`
```bash
EVERSTAR_REPO="/Users/you/Desktop/everstar/everstar"
```

## Team Best Practices

### 1. Keep Keys Updated

If you regenerate your Linear API key:
```bash
./scripts/setup.sh
# Choose "y" to reconfigure
```

### 2. Verify Before Running

Always check status before automation:
```bash
cd /Users/you/Desktop/everstar/everstar
git status
# Make sure working tree is clean
```

### 3. Monitor Progress

Automation outputs to `/tmp/`:
- `/tmp/ruflo-ticket-enriched-ENG-XXXX.md` - Enriched ticket
- `/tmp/ruflo-plan-ENG-XXXX.md` - Implementation plan
- `/tmp/ruflo-execution-ENG-XXXX.md` - Execution log

### 4. Review PRs

Always review the generated PR before merging:
- Check implementation matches requirements
- Verify tests pass (85%+ coverage)
- Review security scan results
- Confirm CLAUDE.md standards followed

## Getting Help

### Setup Issues

1. Check this guide's Troubleshooting section
2. Verify prerequisites with: `./scripts/cleanup.sh --status`
3. Re-run setup: `./scripts/setup.sh`
4. Ask in #engineering-tools Slack channel

### Automation Issues

1. Check output files in `/tmp/ruflo-*.md`
2. Verify swarm status:
   ```bash
   cd /Users/you/Desktop/everstar/everstar
   npx @claude-flow/cli@latest swarm status
   ```
3. Reset if needed:
   ```bash
   ./scripts/cleanup.sh --swarm
   ```

### Questions

- **Documentation:** Check [README.md](README.md)
- **Standards:** See [.claude/ticket-bot-standards.md](.claude/ticket-bot-standards.md)
- **Research:** Read [docs/ticket-enrichment-research.md](docs/ticket-enrichment-research.md)
- **Slack:** #engineering-tools channel

## Next Steps

Once setup is complete:

1. **Read the README:** [README.md](README.md)
2. **Review standards:** [.claude/ticket-bot-standards.md](.claude/ticket-bot-standards.md)
3. **Run first ticket:** `./scripts/everstar-cli.sh ENG-XXXX`
4. **Share feedback:** #engineering-tools Slack channel

---

**Welcome to automated ticket execution! Setup should take 5 minutes, and you'll save 4-5 hours per ticket.**
