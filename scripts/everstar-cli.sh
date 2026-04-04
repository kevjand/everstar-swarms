#!/bin/bash
# Everstar CLI - Send prompt directly to Claude CLI
# Usage: ./everstar-cli.sh ENG-XXXX [USER_PREFIX]
# Requires: claude CLI running or will start it

set -e

TICKET_ID=$1
USER_PREFIX=${2:-"auto"}  # Default to "auto" if not provided (e.g., kevjand/ENG-4214)

# Auto-detect everstar repo location (works for any team member)
if [ -z "$EVERSTAR_REPO" ]; then
    # Try common locations
    if [ -d "$HOME/everstar/everstar" ]; then
        EVERSTAR_REPO="$HOME/everstar/everstar"
    elif [ -d "$HOME/Desktop/everstar/everstar" ]; then
        EVERSTAR_REPO="$HOME/Desktop/everstar/everstar"
    elif [ -d "$HOME/workspace/everstar" ]; then
        EVERSTAR_REPO="$HOME/workspace/everstar"
    else
        echo "❌ Cannot find everstar repo. Set EVERSTAR_REPO env variable:"
        echo "   export EVERSTAR_REPO=/path/to/everstar"
        exit 1
    fi
fi

echo "📁 Everstar repo: $EVERSTAR_REPO"

if [ -z "$TICKET_ID" ]; then
    echo "Usage: ./everstar-cli.sh ENG-XXXX [USER_PREFIX]"
    echo "Example: ./everstar-cli.sh ENG-4214 kevjand"
    exit 1
fi

echo "🚀 Processing ticket $TICKET_ID via Claude CLI..."

# 1. Prep main repo
cd "$EVERSTAR_REPO"
git fetch origin dev --quiet 2>/dev/null || true

# 2. Create worktree for parallel execution
BRANCH="$USER_PREFIX/$TICKET_ID"
WORKTREE_PATH="/tmp/everstar-worktrees/$BRANCH"

# Clean up old worktree if exists
if [ -d "$WORKTREE_PATH" ]; then
    echo "⚠️  Cleaning up existing worktree..."
    git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || true
fi

# Create fresh worktree from dev
mkdir -p /tmp/everstar-worktrees
git worktree add -b "$BRANCH" "$WORKTREE_PATH" origin/dev 2>/dev/null || \
git worktree add "$WORKTREE_PATH" "$BRANCH" 2>/dev/null

cd "$WORKTREE_PATH"
echo "✓ Worktree: $WORKTREE_PATH"
echo "✓ Branch: $BRANCH"

# 3. Initialize swarm
npx @claude-flow/cli@latest swarm init --topology hierarchical --max-agents 8 > /dev/null 2>&1
echo "✓ Swarm initialized"

# 4. Initialize hive-mind
echo "✓ Initializing hive-mind..."
npx @claude-flow/cli@latest hive-mind init \
  --objective "Implement Linear ticket $TICKET_ID" \
  --workers 6 \
  --consensus byzantine \
  --topology hierarchical-mesh > /dev/null 2>&1
echo "✓ Hive-mind initialized"

# 5. Create prompt for Claude Code to execute within Ruflo framework
echo "✓ Preparing execution..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Worktree: $WORKTREE_PATH"
echo "  Branch: $BRANCH"
echo "  Ticket: $TICKET_ID"
echo "  Ruflo Swarm: READY"
echo "  Hive-Mind: INITIALIZED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create prompt for Claude Code with fully autonomous 3-phase approach
PROMPT="RUFLO TICKET EXECUTION BOT - $TICKET_ID

Worktree: $WORKTREE_PATH
Branch: $BRANCH
Ruflo Swarm: INITIALIZED (hierarchical, 8 agents max)
Hive-Mind: READY (Byzantine consensus, hierarchical-mesh)

TASK: Execute ticket $TICKET_ID using FULLY AUTONOMOUS 4-PHASE approach with ticket enrichment and automated plan validation.

CRITICAL: You are working in a git worktree at $WORKTREE_PATH (isolated from main repo).

CRITICAL PROJECT GUIDELINES:
1. FIRST ACTION: Read $WORKTREE_PATH/CLAUDE.md - This contains MANDATORY project-specific rules you MUST follow
2. Read /Users/kevinandrade/Desktop/everstar-swarms/.claude/ticket-bot-standards.md - General quality requirements
3. If CLAUDE.md conflicts with ticket-bot-standards.md, CLAUDE.md takes precedence (project-specific overrides general)

ALL AGENTS MUST:
- Read and strictly follow $WORKTREE_PATH/CLAUDE.md before any code changes
- Follow file organization rules from CLAUDE.md
- Obey project-specific conventions (naming, structure, testing) from CLAUDE.md
- Apply ticket-bot-standards.md for quality gates not covered by CLAUDE.md

==== PHASE 0: TICKET ANALYSIS & ENRICHMENT ====

1. Use Linear MCP to fetch ticket $TICKET_ID details

2. Spawn ticket-analyzer agent (run_in_background: true):
   Agent(subagent_type: reviewer, run_in_background: true)

   Ticket-analyzer must analyze ticket quality and conditionally enrich:

   SCORING CRITERIA (0-100 points):
   - Acceptance Criteria: 25pts (explicit Given-When-Then format)
   - Edge Cases: 20pts (boundaries, errors, concurrency, performance)
   - Test Requirements: 20pts (unit, integration, e2e scenarios specified)
   - Prerequisites/Dependencies: 15pts (backend, frontend, services, migrations)
   - Security Considerations: 10pts (auth, validation, data exposure, rate limits)
   - Technical Details: 10pts (components, APIs, data models, UI/UX)

   CONDITIONAL ENRICHMENT (if score < 70):
   Generate and append to ticket:

   ## ENRICHMENT

   ### Generated Acceptance Criteria
   - AC1: [Given-When-Then format]
   - AC2: [Edge case handling]
   - AC3: [Error scenarios]

   ### Identified Edge Cases
   - Boundary: Empty inputs, max limits, special characters
   - Errors: Network failures, timeouts, invalid data
   - Concurrency: Race conditions, simultaneous updates
   - Performance: Large datasets, slow connections
   - Compatibility: Browser support, mobile devices

   ### Test Scenarios Required
   - Unit Tests (>85% coverage): List specific test cases
   - Integration Tests: API/DB/service integration points
   - E2E Tests: Complete user workflow scenarios

   ### Prerequisites & Dependencies
   - Backend: List required libraries, migrations, env vars
   - Frontend: List required components, state management, routes

   ### Security Checklist
   - Authentication: Required or not
   - Authorization: Role-based access control
   - Input Validation: SQL injection, XSS prevention
   - Data Exposure: PII handling, sensitive fields
   - Rate Limiting: API throttling requirements

   Analyzer writes to: /tmp/ruflo-ticket-enriched-$TICKET_ID.md (if enrichment needed)

   OUTPUT:
   - Quality score (0-100)
   - Enrichment status (NEEDED/NOT_NEEDED)
   - File path if enriched, or \"ORIGINAL_TICKET_OK\"

==== PHASE 1: PLANNING ====

3. Spawn planner agent (run_in_background: true):
   Agent(subagent_type: planner, run_in_background: true)

   INPUT: Use enriched ticket if Phase 0 generated one, otherwise use original Linear ticket

   BEFORE PLANNING: Planner MUST read $WORKTREE_PATH/CLAUDE.md to understand:
   - Project architecture and conventions
   - File organization rules
   - Coding standards and constraints
   - Testing requirements
   - Any project-specific guidelines

   Planner must create comprehensive plan file including:
   - Analysis of ticket requirements and acceptance criteria (from enriched or original ticket)
   - Affected files and components
   - Architecture decisions and rationale
   - Implementation approach (step-by-step)
   - Test strategy (unit, integration, edge cases) - use enriched test scenarios if available
   - Security considerations - reference enriched security checklist if available
   - Potential risks and mitigation
   - Estimated complexity

   Planner writes plan to: /tmp/ruflo-plan-$TICKET_ID.md

==== PHASE 2: AUTOMATED PLAN REVIEW ====

4. Spawn plan-reviewer agent (run_in_background: true):
   Agent(subagent_type: reviewer, run_in_background: true)

   Plan-reviewer validates the plan against .claude/ticket-bot-standards.md:
   - ✓ All requirements from ticket are addressed
   - ✓ Edge cases identified and handled
   - ✓ Test strategy meets 85%+ coverage requirement
   - ✓ Security considerations included
   - ✓ Architecture decisions have clear rationale
   - ✓ Implementation steps are clear and sequenced
   - ✓ Risk assessment and mitigation included

   If ANY validation fails, plan-reviewer provides specific feedback and requests plan revision.
   Only proceed to Phase 3 if plan-reviewer approves with \"PLAN APPROVED\".

==== PHASE 3: EXECUTION (AFTER AUTOMATED APPROVAL) ====

5. After plan-reviewer approval, spawn 5 execution agents in ONE message (run_in_background: true):

   ALL AGENTS MUST FIRST: Read $WORKTREE_PATH/CLAUDE.md and follow ALL project-specific rules

   - coder (backend): Read CLAUDE.md first, then implement backend per plan (Python/FastAPI, TDD, full type hints, follow project structure from CLAUDE.md)
   - coder (frontend): Read CLAUDE.md first, then implement frontend per plan (TypeScript/React, component-based, follow project structure from CLAUDE.md)
   - tester: Read CLAUDE.md first, then write tests per project testing conventions, >85% coverage, edge cases, integration tests
   - security-auditor: Vulnerability scan, input validation, no secrets, check against CLAUDE.md security rules
   - reviewer: Verify CLAUDE.md compliance (project-specific conventions, quality gates from ticket-bot-standards.md)

6. QUALITY GATES - Must pass before commit:
   - All tests passing (pytest with 85%+ coverage)
   - Linting passing (npm run lint, zero warnings)
   - CLAUDE.md compliant (verified by reviewer agent)
   - Security scan clean
   - No TODO/FIXME comments
   - No new markdown documentation files created (code is the documentation)

7. Final steps: commit (lowercase format), push to origin/$BRANCH, create PR

FORBIDDEN: Do NOT create implementation markdown files (e.g., IMPLEMENTATION.md, CHANGES.md). The code, tests, and commit messages are the documentation.

CRITICAL: This is FULLY AUTONOMOUS 4-PHASE workflow. No human intervention required.
- Phase 0: Ticket analysis & conditional enrichment (score < 70)
- Phase 1: Planning (uses enriched or original ticket)
- Phase 2: Automated plan review
- Phase 3: Execution with quality gates"

echo "🤖 Starting Claude Code execution..."
echo ""

# Check if claude CLI is available
if ! command -v claude &> /dev/null; then
    echo "❌ Claude CLI not found. Install: npm install -g @anthropic-ai/claude-code"
    echo ""
    echo "Alternative: Paste this into your Claude Code session:"
    echo "──────────────────────────────────────"
    echo "$PROMPT"
    echo "──────────────────────────────────────"
    exit 1
fi

# Run Claude Code with Ruflo integration in worktree
cd "$WORKTREE_PATH"

# Start simple progress monitor in background
(
    while ps aux | grep -q "[c]laude.*$TICKET_ID"; do
        clear
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  📋 Ticket: $TICKET_ID"
        echo "  🌳 Branch: $BRANCH"
        echo "  📁 Worktree: $WORKTREE_PATH"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        npx @claude-flow/cli@latest agent list 2>/dev/null || echo "  ⏳ Agents starting..."
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        sleep 5
    done
) &
MONITOR_PID=$!

# Execute in worktree
claude --dangerously-skip-permissions "$PROMPT"

# Stop monitor
kill $MONITOR_PID 2>/dev/null || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Execution complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  🌳 Branch: $BRANCH"
echo "  📁 Worktree: $WORKTREE_PATH"
echo ""

# Check for changes
if git diff-index --quiet HEAD --; then
    echo "  ℹ️  No changes made"
    echo ""
    echo "  🧹 Cleaning up worktree..."
    cd "$EVERSTAR_REPO"
    git worktree remove "$WORKTREE_PATH" --force
else
    echo "  📊 Changes made:"
    git status --short
    echo ""
    echo "  🔍 Recent commits:"
    git log --oneline -3
    echo ""
    echo "  ✨ PR created or ready for review"
    echo ""
    echo "  💡 To clean up worktree after PR merge:"
    echo "     cd $EVERSTAR_REPO && git worktree remove $WORKTREE_PATH"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
