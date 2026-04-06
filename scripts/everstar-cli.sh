#!/bin/bash
# Everstar CLI - Automated ticket execution with AI agents
# Usage: ./everstar-cli.sh ENG-XXXX [USER_PREFIX] [OPTIONS]
#
# Options:
#   --interactive, -i     Pause between phases for user approval
#   --resume, -r          Resume from checkpoint
#   --mode=MODE           Execution mode: "simple" (default) or "swarm"
#   --simple              Use simple mode (Claude Code native agents - RECOMMENDED)
#   --swarm               Use swarm mode (Ruflo MCP coordination - EXPERIMENTAL)
#
# Examples:
#   ./everstar-cli.sh ENG-5000              # Simple mode, auto-detect user
#   ./everstar-cli.sh ENG-5000 kevjand     # Simple mode, specific user
#   ./everstar-cli.sh ENG-5000 --interactive  # Pause between phases
#   ./everstar-cli.sh ENG-5000 --swarm      # Use Ruflo swarm (experimental)
#
# Modes:
#   simple: Sequential execution with Claude Code native agents (default, working now)
#   swarm:  Parallel execution with Ruflo MCP coordination (advanced, experimental)
#
# Requires: claude CLI running or will start it

set -e

# Load environment variables from .env if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    source "$SCRIPT_DIR/../.env"
fi

# Load checkpoint functions
source "$SCRIPT_DIR/checkpoint.sh"

# Parse arguments
INTERACTIVE_MODE=false
RESUME_MODE=false
EXECUTION_MODE="simple"  # Default to simple mode (working now)
TICKET_ID=""
CLI_USER_PREFIX=""  # Store CLI arg separately to not override .env

for arg in "$@"; do
    case $arg in
        --interactive|-i)
            INTERACTIVE_MODE=true
            shift
            ;;
        --resume|-r)
            RESUME_MODE=true
            shift
            ;;
        --mode=*)
            EXECUTION_MODE="${arg#*=}"
            shift
            ;;
        --simple)
            EXECUTION_MODE="simple"
            shift
            ;;
        --swarm)
            EXECUTION_MODE="swarm"
            shift
            ;;
        *)
            if [ -z "$TICKET_ID" ]; then
                TICKET_ID=$arg
            elif [ -z "$CLI_USER_PREFIX" ]; then
                CLI_USER_PREFIX=$arg
            fi
            ;;
    esac
done

# Validate execution mode
if [[ "$EXECUTION_MODE" != "simple" && "$EXECUTION_MODE" != "swarm" ]]; then
    echo "ERROR: Invalid execution mode '$EXECUTION_MODE'. Must be 'simple' or 'swarm'"
    exit 1
fi

# Set USER_PREFIX with proper precedence: CLI arg > .env > "auto"
if [ -n "$CLI_USER_PREFIX" ]; then
    USER_PREFIX="$CLI_USER_PREFIX"
elif [ -z "$USER_PREFIX" ]; then
    USER_PREFIX="auto"
fi

# Auto-detect everstar repo location (works for any team member)
if [ -z "$EVERSTAR_REPO" ]; then
    # Try common locations
    if [ -d "$HOME/everstar/everstar" ]; then
        EVERSTAR_REPO="/Users/kevinandrade/Desktop/everstar/everstar"
    elif [ -d "$HOME/Desktop/everstar/everstar" ]; then
        EVERSTAR_REPO="/Users/kevinandrade/Desktop/everstar/everstar"
    elif [ -d "$HOME/workspace/everstar" ]; then
        EVERSTAR_REPO="/Users/kevinandrade/Desktop/everstar/everstar"
    else
        echo "[ERROR] Cannot find everstar repo. Set EVERSTAR_REPO env variable in .env:"
        echo "   echo 'EVERSTAR_REPO=/path/to/everstar' >> .env"
        exit 1
    fi
fi

echo "[DIR] Everstar repo: $EVERSTAR_REPO"

if [ -z "$TICKET_ID" ]; then
    echo "Usage: ./everstar-cli.sh ENG-XXXX [USER_PREFIX] [--interactive] [--resume]"
    echo ""
    echo "Examples:"
    echo "  ./everstar-cli.sh ENG-4214 kevjand              # Full automation (with agent timeouts)"
    echo "  ./everstar-cli.sh ENG-4214 kevjand --interactive # Approval required between phases"
    echo "  ./everstar-cli.sh ENG-4214 --resume            # Resume from checkpoint"
    echo ""
    echo "Flags:"
    echo "  --interactive, -i    Require approval at the end of each phase (0,1,2,3)"
    echo "  --resume, -r         Resume from last checkpoint"
    echo ""
    echo "Note: All agents have 15-minute timeouts to prevent hanging"
    exit 1
fi

# Handle resume mode
if [ "$RESUME_MODE" = true ]; then
    echo "[RESUME] Loading checkpoint..."
    CHECKPOINT_DATA=$(checkpoint_load)

    if [ "$CHECKPOINT_DATA" = "{}" ]; then
        echo "[ERROR] No checkpoint found. Cannot resume."
        exit 1
    fi

    # Extract checkpoint data
    CHECKPOINT_TICKET=$(echo "$CHECKPOINT_DATA" | jq -r '.ticket_id')
    CHECKPOINT_PHASE=$(echo "$CHECKPOINT_DATA" | jq -r '.phase')
    CHECKPOINT_STATUS=$(echo "$CHECKPOINT_DATA" | jq -r '.status')
    CHECKPOINT_WORKTREE=$(echo "$CHECKPOINT_DATA" | jq -r '.worktree')
    CHECKPOINT_TIME=$(echo "$CHECKPOINT_DATA" | jq -r '.timestamp')

    # Verify ticket matches
    if [ "$CHECKPOINT_TICKET" != "$TICKET_ID" ]; then
        echo "[ERROR] Checkpoint is for ticket $CHECKPOINT_TICKET, but you requested $TICKET_ID"
        exit 1
    fi

    # Verify worktree exists
    if [ ! -d "$CHECKPOINT_WORKTREE" ]; then
        echo "[ERROR] Checkpoint worktree does not exist: $CHECKPOINT_WORKTREE"
        exit 1
    fi

    echo "[RESUME] Checkpoint found:"
    echo "  Ticket: $CHECKPOINT_TICKET"
    echo "  Phase: $CHECKPOINT_PHASE"
    echo "  Status: $CHECKPOINT_STATUS"
    echo "  Worktree: $CHECKPOINT_WORKTREE"
    echo "  Timestamp: $CHECKPOINT_TIME"
    echo ""
    echo "[RESUME] Resuming from Phase $CHECKPOINT_PHASE..."

    # Set variables from checkpoint
    BRANCH=$(basename "$(dirname "$CHECKPOINT_WORKTREE")")/$(basename "$CHECKPOINT_WORKTREE")
    WORKTREE_PATH="$CHECKPOINT_WORKTREE"
fi

echo "> Processing ticket $TICKET_ID via Claude CLI..."

# 1. Prep main repo
cd "$EVERSTAR_REPO"
git fetch origin dev --quiet 2>/dev/null || true

# 2. Create worktree for parallel execution
BRANCH="$USER_PREFIX/$TICKET_ID"
WORKTREE_PATH="/tmp/everstar-worktrees/$BRANCH"

# Clean up old worktree if exists
if [ -d "$WORKTREE_PATH" ]; then
    echo "[WARN]  Cleaning up existing worktree..."
    git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || true
fi

# Create fresh worktree from dev
mkdir -p /tmp/everstar-worktrees
git worktree add -b "$BRANCH" "$WORKTREE_PATH" origin/dev 2>/dev/null || \
git worktree add "$WORKTREE_PATH" "$BRANCH" 2>/dev/null

cd "$WORKTREE_PATH"
echo "OK Worktree: $WORKTREE_PATH"
echo "OK Branch: $BRANCH"

# 3. Initialize Ruflo swarm (conditional based on mode)
if [ "$EXECUTION_MODE" = "swarm" ]; then
    echo "OK Initializing Ruflo swarm (SWARM MODE)..."
    npx @claude-flow/cli@latest swarm init --topology hierarchical --max-agents 8 --strategy specialized > /tmp/ruflo-swarm-init.log 2>&1
    if [ $? -eq 0 ]; then
        echo "OK Ruflo swarm ready"
        SWARM_STATUS="READY"
    else
        echo "WARN Swarm init failed, falling back to simple mode"
        EXECUTION_MODE="simple"
        SWARM_STATUS="DISABLED (fallback)"
    fi
else
    echo "OK Using simple mode (sequential Claude Code agents)"
    SWARM_STATUS="DISABLED (simple mode)"
fi

# 5. Create prompt for Claude Code to execute
echo "OK Preparing execution..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Worktree: $WORKTREE_PATH"
echo "  Branch: $BRANCH"
echo "  Ticket: $TICKET_ID"
echo "  Execution Mode: $EXECUTION_MODE"
echo "  Ruflo Swarm: $SWARM_STATUS"
if [ "$INTERACTIVE_MODE" = true ]; then
    echo "  Mode: INTERACTIVE (approval required between phases)"
else
    echo "  Mode: AUTONOMOUS (fully automated)"
fi
echo "  Agent Timeouts: 15 minutes per agent"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create execution mode instructions
EXECUTION_MODE_INSTRUCTIONS=""
if [ "$EXECUTION_MODE" = "swarm" ]; then
    EXECUTION_MODE_INSTRUCTIONS="
EXECUTION MODE: RUFLO SWARM (Advanced)

Use Ruflo MCP tools for true parallel multi-agent coordination:
1. FIRST: Load Ruflo MCP tools using ToolSearch
2. THEN: Spawn agents using mcp__claude-flow__agent_spawn
3. Agents coordinate via Ruflo message-bus and shared memory namespace
4. Support true parallel execution with Byzantine consensus

Agent spawning syntax:
ToolSearch(query: \"select:mcp__claude-flow__agent_spawn\")
mcp__claude-flow__agent_spawn(
    type: \"agent-type\",
    name: \"agent-name\",
    prompt: \"detailed instructions\"
)
"
else
    EXECUTION_MODE_INSTRUCTIONS="
EXECUTION MODE: SIMPLE (Recommended - Working Now)

Use Claude Code's native Agent tool for sequential coordination:
1. Spawn agents using Agent() tool directly
2. Agents coordinate via shared filesystem and git worktree
3. Sequential phase execution with file-based handoffs
4. Proven reliable, fast, and simple

Agent spawning syntax:
Agent(
    subagent_type: \"agent-type\",
    description: \"Short description\",
    prompt: \"detailed instructions\",
    run_in_background: true
)
"
fi

# Create interactive mode instructions
INTERACTIVE_INSTRUCTIONS=""
if [ "$INTERACTIVE_MODE" = true ]; then
    INTERACTIVE_INSTRUCTIONS="
INTERACTIVE MODE: ENABLED

After completing each phase (0, 1, 2, 3), you MUST:
1. Summarize what was accomplished in the phase
2. Show key findings, decisions, or concerns
3. Use AskUserQuestion tool to ask: \"Proceed to next phase?\" with options:
   - \"Continue\" (proceed to next phase)
   - \"Stop\" (halt automation, keep worktree for manual inspection)
   - \"Skip to Phase X\" (jump to specific phase)
4. Wait for user response before proceeding

Do NOT proceed automatically between phases in interactive mode.
"
else
    INTERACTIVE_INSTRUCTIONS="
AUTONOMOUS MODE: ENABLED

Execute all 4 phases automatically without pausing for approval. Only stop if critical errors occur.
"
fi

# Create prompt for Claude Code with fully autonomous 3-phase approach
PROMPT="RUFLO TICKET EXECUTION BOT - $TICKET_ID

Worktree: $WORKTREE_PATH
Branch: $BRANCH
Ruflo Swarm: $SWARM_STATUS
$INTERACTIVE_INSTRUCTIONS
$EXECUTION_MODE_INSTRUCTIONS

TASK: Execute ticket $TICKET_ID using 4-PHASE approach with ticket enrichment and automated plan validation.

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

1. Fetch ticket $TICKET_ID details using Linear REST API (GraphQL):
   - Use Bash to call Linear GraphQL API directly (much faster than MCP search):
     curl -s -X POST https://api.linear.app/graphql \\
       -H \"Authorization: \$LINEAR_API_KEY\" \\
       -H \"Content-Type: application/json\" \\
       -d '{\"query\": \"query { issue(id: \\\"$TICKET_ID\\\") { id title description state { name } priority team { name } assignee { name } labels { nodes { name } } createdAt updatedAt } }\"}'

   - Parse the response and extract ticket details
   - If API returns error or ticket not found: STOP and report \"[ERROR] Cannot fetch ticket $TICKET_ID from Linear. Check ticket ID or LINEAR_API_KEY.\"
   - Save ticket data to: /tmp/linear-ticket-$TICKET_ID.json for later reference
   - Timeout: 10 seconds max (should be < 1 second normally)

   CRITICAL: Linear API key is REQUIRED. If \$LINEAR_API_KEY is empty or request fails, exit with error.

2. Spawn ticket-analyzer agent using syntax from EXECUTION MODE above:
   - For simple mode: Use Agent() tool
   - For swarm mode: Use ToolSearch + mcp__claude-flow__agent_spawn

   Agent configuration:
   - Type: reviewer
   - Name: ticket-analyzer
   - Description: Analyze ticket quality
   - Prompt: \"Analyze ticket $TICKET_ID quality and generate enrichment if score < 70. Read /tmp/linear-ticket-$TICKET_ID.json for ticket data. Write enriched ticket to /tmp/ruflo-ticket-enriched-$TICKET_ID.md if needed, else write 'ORIGINAL_TICKET_OK' to /tmp/ruflo-ticket-status-$TICKET_ID.txt\"

   AFTER SPAWNING: Report status
   \"Ticket analyzer agent spawned - analyzing ticket quality and generating enrichment if needed. This typically takes 30-90 seconds...\"

   Ticket-analyzer must analyze ticket quality and conditionally enrich:

   SCORING CRITERIA (0-100 points):
   - Acceptance Criteria: 25pts (explicit Given-When-Then format)
   - Edge Cases: 20pts (boundaries, errors, concurrency, performance)
   - Test Requirements: 20pts (unit, integration, e2e scenarios specified)
   - Prerequisites/Dependencies: 15pts (backend, frontend, services, migrations)
   - Security Considerations: 10pts (auth, validation, data exposure, rate limits)
   - Technical Details: 10pts (components, APIs, data models, UI/UX)

   CONDITIONAL ENRICHMENT (if score < 70):

   CRITICAL ENRICHMENT RULES - CONSERVATIVE ONLY:
   1. DO NOT invent new features or requirements
   2. ONLY clarify and structure what is ALREADY mentioned in the ticket
   3. If ticket says \"fix X\", do NOT add \"also implement Y\"
   4. DO NOT assume requirements based on \"best practices\"
   5. If information is missing, note it as \"[Not specified in ticket]\" - do NOT make assumptions
   6. Focus: format existing info into structured acceptance criteria

   Generate ONLY what is missing from ticket (conservative):

   ## ENRICHMENT

   ### Structured Acceptance Criteria (ONLY from ticket content)
   - AC1: [Reformat ticket requirement into Given-When-Then IF ticket has requirements]
   - AC2: [Only if explicitly mentioned in ticket]
   - [If no acceptance criteria in ticket, write: \"No explicit acceptance criteria - defer to ticket description\"]

   ### Edge Cases (ONLY those mentioned or directly implied by ticket)
   - [List ONLY if ticket mentions error handling, boundaries, or edge cases]
   - [If not mentioned, write: \"Edge cases not specified in ticket\"]

   ### Test Requirements (based on ticket scope ONLY)
   - [Unit/Integration tests ONLY for components explicitly mentioned in ticket]
   - [If testing not mentioned, write: \"Test requirements not specified - use standard coverage\"]

   ### Prerequisites (ONLY what ticket mentions)
   - [Backend/Frontend dependencies ONLY if ticket specifies them]
   - [If not mentioned, write: \"Prerequisites not specified in ticket\"]

   ### Security (ONLY if ticket mentions security concerns)
   - [Auth/validation ONLY if ticket explicitly requires it]
   - [If not mentioned, write: \"No security requirements specified in ticket\"]

   Analyzer writes to: /tmp/ruflo-ticket-enriched-$TICKET_ID.md (if enrichment needed)

   OUTPUT:
   - Quality score (0-100)
   - Enrichment status (NEEDED/NOT_NEEDED)
   - File path if enriched, or \"ORIGINAL_TICKET_OK\"

   AFTER PHASE 0 COMPLETES:
   - Read and DISPLAY enriched ticket to user (if created): Read /tmp/ruflo-ticket-enriched-$TICKET_ID.md
   - Show score and key changes made
   - This allows user visibility into what was added
   - CHECKPOINT: Save state using Bash: source $SCRIPT_DIR/checkpoint.sh && checkpoint_save \"$TICKET_ID\" \"0\" \"complete\" \"$WORKTREE_PATH\"

==== PHASE 1: PLANNING ====

3. Spawn planner agent using syntax from EXECUTION MODE above:
   - For simple mode: Use Agent() tool
   - For swarm mode: Use ToolSearch + mcp__claude-flow__agent_spawn

   Agent configuration:
   - Type: planner
   - Name: planner
   - Description: Create implementation plan
   - Prompt: \"Create implementation plan for ticket $TICKET_ID. Read ticket from /tmp/ruflo-ticket-enriched-$TICKET_ID.md (or /tmp/linear-ticket-$TICKET_ID.json if no enrichment). Read $WORKTREE_PATH/CLAUDE.md for project conventions. Write plan to /tmp/ruflo-plan-$TICKET_ID.md\"

   AFTER SPAWNING: Report status
   \"Planner agent spawned - analyzing requirements and creating implementation plan. This typically takes 2-4 minutes depending on complexity...\"

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

   AFTER PHASE 1 COMPLETES:
   - Read and DISPLAY plan to user: Read /tmp/ruflo-plan-$TICKET_ID.md
   - Summarize: complexity, files affected, key decisions, estimated timeline
   - This allows user visibility into implementation approach
   - CHECKPOINT: Save state using Bash: source $SCRIPT_DIR/checkpoint.sh && checkpoint_save \"$TICKET_ID\" \"1\" \"complete\" \"$WORKTREE_PATH\"

==== PHASE 2: AUTOMATED PLAN REVIEW ====

4. Spawn plan-reviewer agent using syntax from EXECUTION MODE above:
   - For simple mode: Use Agent() tool
   - For swarm mode: Use ToolSearch + mcp__claude-flow__agent_spawn

   Agent configuration:
   - Type: reviewer
   - Name: plan-reviewer
   - Description: Review implementation plan
   - Prompt: \"Review plan at /tmp/ruflo-plan-$TICKET_ID.md for quality, completeness, and alignment with ticket requirements. Write review results to /tmp/ruflo-plan-review-$TICKET_ID.md. End with 'PLAN APPROVED' or 'PLAN REJECTED'\"

   AFTER SPAWNING: Report status
   \"Plan reviewer agent spawned - validating plan against quality standards. This typically takes 1-2 minutes...\"

   Plan-reviewer validates the plan against .claude/ticket-bot-standards.md:
   - OK All requirements from ticket are addressed
   - OK Edge cases identified and handled
   - OK Test strategy meets 85%+ coverage requirement
   - OK Security considerations included
   - OK Architecture decisions have clear rationale
   - OK Implementation steps are clear and sequenced
   - OK Risk assessment and mitigation included

   If ANY validation fails, plan-reviewer provides specific feedback and requests plan revision.
   Only proceed to Phase 3 if plan-reviewer approves with \"PLAN APPROVED\".

   AFTER PHASE 2 COMPLETES:
   - Read and DISPLAY plan review results to user: Read /tmp/ruflo-plan-review-$TICKET_ID.md
   - Show: approval score, criteria passed/failed, any concerns or recommendations
   - This allows user visibility into quality validation
   - CHECKPOINT: Save state using Bash: source $SCRIPT_DIR/checkpoint.sh && checkpoint_save \"$TICKET_ID\" \"2\" \"complete\" \"$WORKTREE_PATH\"

==== PHASE 3: EXECUTION (AFTER AUTOMATED APPROVAL) ====

5. After plan-reviewer approval, spawn 5 implementation agents in ONE message:

   AGENT TIMEOUT PROTECTION: Each agent has a 15-minute timeout.

   Spawn ALL 5 agents in ONE message using syntax from EXECUTION MODE above:
   - For simple mode: Use Agent() tool with run_in_background: true
   - For swarm mode: Use ToolSearch + mcp__claude-flow__agent_spawn (for true parallel execution)

   Agent configurations for Phase 3:

   1. Backend Coder
      - Type: coder
      - Name: backend-coder
      - Description: Backend implementation
      - Prompt: \"Read $WORKTREE_PATH/CLAUDE.md first. Implement backend per plan at /tmp/ruflo-plan-$TICKET_ID.md. Python/FastAPI, TDD, full type hints, follow project structure from CLAUDE.md. Working directory: $WORKTREE_PATH\"

   2. Frontend Coder
      - Type: coder
      - Name: frontend-coder
      - Description: Frontend implementation
      - Prompt: \"Read $WORKTREE_PATH/CLAUDE.md first. Implement frontend per plan at /tmp/ruflo-plan-$TICKET_ID.md. TypeScript/React, component-based, follow project structure from CLAUDE.md. Working directory: $WORKTREE_PATH\"

   3. Behavioral Tester
      - Type: tester
      - Name: behavioral-tester
      - Description: Behavioral testing
      - Prompt: \"CRITICAL - Read LINEAR TICKET at /tmp/linear-ticket-$TICKET_ID.json to understand acceptance criteria. Read $WORKTREE_PATH/CLAUDE.md for testing conventions. Write tests that verify ACCEPTANCE CRITERIA and USER BEHAVIOR (not implementation details). Focus on: Does the feature actually work? Include: integration tests (70%), unit tests (20%), edge cases. TESTING WORKFLOW: (1) Create new test files, (2) Run your new tests: npm test -- path/to/your-new-test-file.test.tsx, (3) Fix your new tests if they fail, (4) FINAL CHECK: Run npm test (NO extra flags - matches CI/CD) to ensure implementation didn't break existing tests, (5) If existing tests fail, report the issue - implementation is broken. Test behavior not structure (GOOD: clicking keeps sidebar expanded. BAD: has icon property). DO NOT create .md documentation files (Test Summary, etc.) - only create test code files (.test.ts, .test.tsx, .spec.ts, test_*.py, etc.). DO NOT modify existing test infrastructure (setup.js, jest.config.js, vitest.config.js, jest.setup.js, etc.) - use existing test setup as-is. DO NOT mark tests as .skip - all new tests must run. Respect existing .skip tests - they are intentional. Only create NEW test files. Working directory: $WORKTREE_PATH\"

   4. Security Scanner
      - Type: security-auditor
      - Name: security-scanner
      - Description: Security scan
      - Prompt: \"Vulnerability scan, input validation, no secrets, check against $WORKTREE_PATH/CLAUDE.md security rules. Write findings to /tmp/ruflo-security-$TICKET_ID.md. Working directory: $WORKTREE_PATH\"

   5. Code Reviewer
      - Type: reviewer
      - Name: code-reviewer
      - Description: Code review
      - Prompt: \"Read LINEAR TICKET at /tmp/linear-ticket-$TICKET_ID.json to understand requirements. Verify $WORKTREE_PATH/CLAUDE.md compliance. Review implementation: Does it actually solve the ticket requirement? Review tests: Do they verify acceptance criteria and user behavior? Check RED FLAGS: tests only check structure not behavior, implementation looks incomplete, acceptance criteria not addressed. Write review to /tmp/ruflo-review-$TICKET_ID.md with PASS or FAIL. Working directory: $WORKTREE_PATH\"

   IMMEDIATELY AFTER SPAWNING ALL 5: Report status
   \"Phase 3 execution started - all 5 implementation agents launched in parallel via Ruflo:
   1. backend-coder - Implementing backend changes per plan
   2. frontend-coder - Implementing frontend changes per plan
   3. behavioral-tester - Writing and running behavioral tests (verify acceptance criteria)
   4. security-scanner - Security scan and vulnerability check
   5. code-reviewer - Code review and quality gates

   Estimated time: 5-10 minutes for all agents to complete. You'll receive notifications as each finishes...\"

5b. WAIT for ALL 5 agents to complete. You will receive notifications as each finishes. Do NOT proceed until you have confirmation that ALL 5 are done.

   WHILE WAITING - Provide periodic status updates (every 60 seconds):
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   AGENT PROGRESS UPDATE (X minutes elapsed)

   Completed: [list completed agents with brief summary]
   In Progress: [list remaining agents]

   Current Activity:
   - Tester: Writing/running tests (typically takes 2-5 min)
   - Reviewer: Code review in progress
   - [etc for remaining agents]

   Status: X/5 agents complete, waiting for Y more...
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   This keeps user informed that automation is actively running.

5c. AFTER ALL 5 AGENTS COMPLETE, spawn pr-manager agent using syntax from EXECUTION MODE above:
   - For simple mode: Use Agent() tool
   - For swarm mode: Use ToolSearch + mcp__claude-flow__agent_spawn

   Agent configuration:
   - Type: reviewer
   - Name: pr-manager
   - Description: PR creation and quality gates
   - Prompt: \"Review all agent outputs, run quality gates, commit changes, push to remote, create PR. Read instructions in section 6 below. Working directory: $WORKTREE_PATH\"
     )

6. The pr-manager agent instructions (spawned AFTER the 5 agents complete):

   CRITICAL: DO NOT CREATE PR UNLESS TESTS VERIFY ACCEPTANCE CRITERIA

   Step 1: Read acceptance criteria from ticket/enrichment - THIS is what needs to work
   Step 2: Review test files - do they ACTUALLY test ALL acceptance criteria?
      - LIST every acceptance criterion from the ticket
      - For EACH criterion, identify which test(s) verify it
      - Each acceptance criterion MUST have corresponding behavioral test(s)
      - GOOD: test \"clicking Schematics keeps sidebar expanded\" (directly tests AC)
      - BAD: test \"schematicsEntry has icon property\" (structural, not AC)
      - If ANY acceptance criterion is missing test coverage: FAIL and report \"Missing test coverage for AC: [criterion]\"
      - If tests check structure not behavior: FAIL and report \"Tests do not verify acceptance criteria\"
      - EVERY AC must be proven by a passing test
   Step 3: Check for NEW skipped tests (DO NOT allow tester to add skipped tests):
      - Check git diff for new test files that were created
      - If new test files contain .skip or test.skip() or describe.skip(): Check if these are NEW
      - EXISTING skipped tests (already in codebase before automation): OK (intentional)
      - NEW skipped tests (added by tester agent): NOT OK (incomplete work)
      - If tester added new skipped tests: STOP and report \"Tester added skipped tests - all new tests must be runnable\"
   Step 4: RUN ALL TESTS to ensure nothing is broken:
      CRITICAL: Implementation changes can break existing tests, so we MUST run all tests EXACTLY as CI/CD does.

      - First, identify which test files were CREATED (check git status --short for new files)
      - Run tests EXACTLY as CI/CD does:
        Frontend: npm test (no extra flags - uses default jest/vitest config)
        Backend: pytest (no extra flags - uses default pytest config)
      - Tests marked .skip or .todo are INTENTIONAL - do NOT try to run them or remove them
      - If ANY non-skipped test fails (new OR existing): STOP, report failures, investigate what broke, DO NOT create PR
      - Review new test output specifically: verify new tests cover acceptance criteria
      - If tests pass but new tests don't verify acceptance criteria: STOP, report issue

      Why run all tests: Code changes can break existing functionality. A passing new test but failing existing test means the implementation is broken.

      IMPORTANT: Use default test commands (npm test, pytest) with NO extra parameters. This matches CI/CD behavior exactly.
   Step 5: Run other quality gates (only after tests pass):
      - Linting: ruff (Python), npm lint (TypeScript)
      - Verify no TODO/FIXME comments
      - Check security findings (critical vs follow-up)
   Step 6: Remove unwanted files before commit:
      - Delete any .md documentation files created by agents (Test Summary, IMPLEMENTATION.md, CHANGES.md, etc.)
      - Run: find $WORKTREE_PATH -name \"*Test Summary*.md\" -o -name \"IMPLEMENTATION.md\" -o -name \"CHANGES.md\" | xargs rm -f
      - ONLY commit: source code, tests, and configuration files
      - DO NOT commit: documentation, summaries, or markdown files (unless explicitly part of the ticket)
   Step 7: ONLY if all tests pass and quality gates pass:
      - Stage all changes: git add -A
      - Create commit: eng-XXXX: [description] with Co-Authored-By: claude-flow
      - Push to remote: git push origin $BRANCH
      - Create PR: gh pr create --base dev --head $BRANCH
      - DISPLAY FINAL SUMMARY to user:
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        AUTOMATION COMPLETE - $TICKET_ID

        PR Created: [URL]
        Commit: [hash]
        Branch: $BRANCH

        Changes:
        - Files modified: X
        - Files created: X
        - Lines added/removed: +X/-X

        Quality Gates:
        - Tests: PASSED (X tests, Y% coverage)
        - Linting: PASSED
        - Security: PASSED (X findings, severity: ...)
        - Acceptance Criteria: VERIFIED

        Next Steps:
        - Review PR at [URL]
        - Verify feature works as expected
        - Merge when ready
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   AFTER PR CREATION:
   - CHECKPOINT: Save state using Bash: source $SCRIPT_DIR/checkpoint.sh && checkpoint_save \"$TICKET_ID\" \"3\" \"complete\" \"$WORKTREE_PATH\"
   - CLEAR CHECKPOINT: Mark as fully complete using Bash: source $SCRIPT_DIR/checkpoint.sh && checkpoint_clear

   BLOCKING RULES - DO NOT CREATE PR IF:
   1. ANY tests fail (new tests OR existing tests) - Must run npm test and pytest to verify
   2. New tests don't verify acceptance criteria (structural tests only)
   3. Acceptance criteria not covered by tests (missing test coverage)
   4. Code changes broke existing tests (regression)

   ONLY CREATE PR if:
   - ALL tests pass (run npm test and pytest, not just new tests)
   - New tests prove acceptance criteria are met
   - No regressions in existing functionality

7. Your role as orchestrator using Ruflo MCP:
   - Step 5: Spawn 5 implementation agents in ONE message using mcp__claude-flow__agent_spawn (6 tool calls total: 1 ToolSearch + 5 spawns)
   - Step 5b: Use mcp__claude-flow__swarm_status to check agent completion status
   - Step 5c: After all 5 finish, spawn pr-manager agent (2 tool calls: 1 ToolSearch + 1 spawn)
   - Do NOT manually run quality gates, commits, or create PRs - let pr-manager handle everything

   IMPORTANT: All agent spawns go through Ruflo MCP, not Claude Code's Agent tool. This enables proper swarm coordination.

FORBIDDEN: Do NOT create ANY markdown documentation files (IMPLEMENTATION.md, CHANGES.md, Test Summary.md, etc.). The code, tests, and commit messages are the documentation. Only commit source code, tests, and configuration files.

WORKFLOW PHASES:
- Phase 0: Ticket analysis & conditional enrichment (score < 70)
- Phase 1: Planning (uses enriched or original ticket)
- Phase 2: Automated plan review
- Phase 3: Execution with quality gates

STATUS REPORTING - Display at start of each phase:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TICKET AUTOMATION STATUS - $TICKET_ID

Phase 0: [DONE/IN PROGRESS/PENDING] Ticket Analysis (score: X/100, enriched: yes/no)
Phase 1: [DONE/IN PROGRESS/PENDING] Planning (complexity: X, files: X)
Phase 2: [DONE/IN PROGRESS/PENDING] Plan Review (score: X/100, approved: yes/no)
Phase 3: [DONE/IN PROGRESS/PENDING] Execution (agents: X/5 complete)

Current Phase: [Name]
Next Action: [What's happening next]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Remember: $([ "$INTERACTIVE_MODE" = true ] && echo "INTERACTIVE MODE - Ask for approval between phases" || echo "AUTONOMOUS MODE - Execute all phases automatically")"

echo "[BOT] Starting Claude Code execution..."
echo ""

# Check if claude CLI is available
if ! command -v claude &> /dev/null; then
    echo "[ERROR] Claude CLI not found. Install: npm install -g @anthropic-ai/claude-code"
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
        echo "  [TASK] Ticket: $TICKET_ID"
        echo "  [BRANCH] Branch: $BRANCH"
        echo "  [DIR] Worktree: $WORKTREE_PATH"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        npx @claude-flow/cli@latest agent list 2>/dev/null || echo "  [WAIT] Agents starting..."
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
echo "[DONE] Execution complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  [BRANCH] Branch: $BRANCH"
echo "  [DIR] Worktree: $WORKTREE_PATH"
echo ""

# Check for changes
if git diff-index --quiet HEAD --; then
    echo "  [INFO]  No changes made"
    echo ""
    echo "  [CLEAN] Cleaning up worktree..."
    cd "$EVERSTAR_REPO"
    git worktree remove "$WORKTREE_PATH" --force
else
    echo "  [STATS] Changes made:"
    git status --short
    echo ""
    echo "  [SEARCH] Recent commits:"
    git log --oneline -3
    echo ""
    echo "  [NEW] PR created or ready for review"
    echo ""
    echo "  [INFO] To clean up worktree after PR merge:"
    echo "     cd $EVERSTAR_REPO && git worktree remove $WORKTREE_PATH"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
