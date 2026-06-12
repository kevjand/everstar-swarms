#!/bin/bash
# Everstar Automation Cleanup Script
# Cleans ticket-scoped temp files/worktrees, old branches, and swarm state.
# Usage: ./scripts/cleanup.sh [--status|--ticket ENG-XXXX [--tmp] [--worktree]|--branches|--swarm|--archive|--all]

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

if [ -z "$EVERSTAR_REPO" ]; then
    for candidate in \
        "$HOME/files/everstar" \
        "$HOME/everstar/everstar" \
        "$HOME/Desktop/everstar/everstar" \
        "$HOME/workspace/everstar"; do
        if [ -d "$candidate/.git" ]; then
            EVERSTAR_REPO="$candidate"
            break
        fi
    done
fi

if [ ! -d "$EVERSTAR_REPO/.git" ]; then
    echo -e "${RED}[ERROR]${NC} Everstar repository not found: ${EVERSTAR_REPO:-unset}"
    echo "  Set EVERSTAR_REPO in .env or run ./scripts/setup.sh"
    exit 1
fi

MODE="--status"
TICKET_ID=""
SHOULD_CLEAN_TICKET_TMP=false
SHOULD_CLEAN_TICKET_WORKTREE=false

while [ $# -gt 0 ]; do
    case "$1" in
        --ticket)
            TICKET_ID="$2"
            MODE="--ticket"
            shift 2
            ;;
        --tmp)
            if [ "$MODE" = "--ticket" ]; then
                SHOULD_CLEAN_TICKET_TMP=true
            else
                MODE="--tmp"
            fi
            shift
            ;;
        --worktree)
            if [ "$MODE" = "--ticket" ]; then
                SHOULD_CLEAN_TICKET_WORKTREE=true
            else
                echo -e "${RED}[ERROR]${NC} --worktree must be used with --ticket ENG-XXXX"
                exit 1
            fi
            shift
            ;;
        --status|--branches|--swarm|--archive|--all)
            MODE="$1"
            shift
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ "$MODE" = "--ticket" ] && [ -z "$TICKET_ID" ]; then
    echo -e "${RED}[ERROR]${NC} --ticket requires a ticket id, e.g. ENG-4214"
    exit 1
fi

if [ "$MODE" = "--ticket" ] && [ "$SHOULD_CLEAN_TICKET_TMP" = false ] && [ "$SHOULD_CLEAN_TICKET_WORKTREE" = false ]; then
    SHOULD_CLEAN_TICKET_TMP=true
    SHOULD_CLEAN_TICKET_WORKTREE=true
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Everstar Automation Cleanup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

confirm() {
    local prompt_text="$1"
    read -p "$prompt_text (y/n): " confirm_value
    [ "$confirm_value" = "y" ]
}

cleanup_branches() {
    echo -e "${CYAN}Checking old automation branches...${NC}"
    echo ""

    cd "$EVERSTAR_REPO"

    AUTO_BRANCHES=$(git branch | grep -E '.*-auto$' | sed 's/^[ *]*//' || true)

    if [ -z "$AUTO_BRANCHES" ]; then
        echo -e "${GREEN}[OK]${NC} No automation branches to clean"
        return
    fi

    echo "Found automation branches:"
    echo "$AUTO_BRANCHES" | while read -r branch; do
        echo "  - $branch"
    done
    echo ""

    if ! confirm "Delete these local branches"; then
        echo "Skipped branch cleanup"
        return
    fi

    CURRENT_BRANCH=$(git branch --show-current)

    echo "$AUTO_BRANCHES" | while read -r branch; do
        if [ "$branch" = "$CURRENT_BRANCH" ]; then
            echo -e "${YELLOW}[SKIP]${NC} Current branch: $branch"
            continue
        fi

        echo -e "${YELLOW}[DELETE]${NC} Local branch: $branch"
        git branch -D "$branch" 2>/dev/null || true

        if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
            if confirm "Also delete remote branch origin/$branch"; then
                git push origin --delete "$branch" 2>/dev/null || true
            else
                echo "Skipped remote branch: origin/$branch"
            fi
        fi
    done

    echo -e "${GREEN}[OK]${NC} Branch cleanup complete"
    echo ""
}

list_ticket_tmp_files() {
    find /tmp \
        \( -name "ruflo-*${TICKET_ID}*" \
        -o -name "linear-ticket-${TICKET_ID}.json" \
        -o -name "everstar-${TICKET_ID}.log" \
        -o -name "everstar-automation-checkpoint-${TICKET_ID}.json" \) \
        -maxdepth 1 2>/dev/null | sort || true
}

cleanup_ticket_tmp() {
    echo -e "${CYAN}Checking temporary files for $TICKET_ID...${NC}"
    echo ""

    TMP_FILES=$(list_ticket_tmp_files)

    if [ -z "$TMP_FILES" ]; then
        echo -e "${GREEN}[OK]${NC} No ticket temporary files found"
        return
    fi

    echo "Found ticket temporary files:"
    echo "$TMP_FILES" | while read -r file; do
        SIZE=$(du -h "$file" 2>/dev/null | cut -f1)
        echo "  - $file ($SIZE)"
    done
    echo ""

    FILE_COUNT=$(echo "$TMP_FILES" | wc -l | tr -d ' ')
    if ! confirm "Delete $FILE_COUNT temporary files for $TICKET_ID"; then
        echo "Skipped ticket tmp cleanup"
        return
    fi

    echo "$TMP_FILES" | while read -r file; do
        rm -f "$file"
    done

    echo -e "${GREEN}[OK]${NC} Ticket temporary files cleaned"
    echo ""
}

cleanup_tmp() {
    echo -e "${CYAN}Broad temporary cleanup is intentionally disabled by default.${NC}"
    echo "Use ticket-scoped cleanup instead: ./scripts/cleanup.sh --ticket ENG-XXXX --tmp"
    echo ""

    TMP_FILES=$(find /tmp -maxdepth 1 \( -name "ruflo-*" -o -name "everstar-*" \) 2>/dev/null | sort || true)

    if [ -z "$TMP_FILES" ]; then
        echo -e "${GREEN}[OK]${NC} No broad automation temporary files found"
        return
    fi

    echo "Found broad automation temporary files:"
    echo "$TMP_FILES" | while read -r file; do
        SIZE=$(du -h "$file" 2>/dev/null | cut -f1)
        echo "  - $file ($SIZE)"
    done
    echo ""

    echo -e "${YELLOW}[WARN]${NC} This may include files from other active tickets."
    read -p "Type DELETE to remove all listed files: " confirm_value
    if [ "$confirm_value" != "DELETE" ]; then
        echo "Skipped broad tmp cleanup"
        return
    fi

    echo "$TMP_FILES" | while read -r file; do
        rm -rf "$file"
    done

    echo -e "${GREEN}[OK]${NC} Broad temporary files cleaned"
    echo ""
}

cleanup_ticket_worktrees() {
    echo -e "${CYAN}Checking worktrees for $TICKET_ID...${NC}"
    echo ""

    WORKTREES=$(find /tmp/everstar-worktrees -mindepth 2 -maxdepth 2 -type d -name "$TICKET_ID" 2>/dev/null | sort || true)

    if [ -z "$WORKTREES" ]; then
        echo -e "${GREEN}[OK]${NC} No ticket worktrees found"
        return
    fi

    cd "$EVERSTAR_REPO"

    echo "$WORKTREES" | while read -r worktree; do
        echo "Worktree: $worktree"
        if [ -d "$worktree/.git" ] || git -C "$worktree" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            git -C "$worktree" status --short
            if ! git -C "$worktree" diff --quiet || ! git -C "$worktree" diff --cached --quiet; then
                echo -e "${YELLOW}[WARN]${NC} Worktree has uncommitted changes."
                if ! confirm "Remove $worktree and discard these changes"; then
                    echo "Skipped worktree: $worktree"
                    continue
                fi
                git worktree remove "$worktree" --force
            else
                if confirm "Remove clean worktree $worktree"; then
                    git worktree remove "$worktree"
                else
                    echo "Skipped worktree: $worktree"
                fi
            fi
        else
            echo -e "${YELLOW}[WARN]${NC} Path is not a git worktree."
            if confirm "Remove directory $worktree"; then
                rm -rf "$worktree"
            fi
        fi
    done

    echo -e "${GREEN}[OK]${NC} Ticket worktree cleanup complete"
    echo ""
}

cleanup_swarm() {
    echo -e "${CYAN}Resetting swarm state...${NC}"
    echo ""

    if npx @claude-flow/cli@latest swarm status &> /dev/null; then
        echo "Active swarm detected"
        if confirm "Shutdown active swarm"; then
            npx @claude-flow/cli@latest swarm shutdown &> /dev/null || true
            echo -e "${GREEN}[OK]${NC} Swarm shutdown"
        fi
    else
        echo -e "${GREEN}[OK]${NC} No active swarm"
    fi

    if npx @claude-flow/cli@latest hive-mind status &> /dev/null; then
        echo "Active hive-mind detected"
        if confirm "Shutdown active hive-mind"; then
            npx @claude-flow/cli@latest hive-mind shutdown &> /dev/null || true
            echo -e "${GREEN}[OK]${NC} Hive-mind shutdown"
        fi
    else
        echo -e "${GREEN}[OK]${NC} No active hive-mind"
    fi

    if confirm "Delete claude-flow active-tickets memory namespace"; then
        npx @claude-flow/cli@latest memory delete --namespace "active-tickets" --all &> /dev/null || true
        echo -e "${GREEN}[OK]${NC} Memory cleaned"
    else
        echo "Skipped memory cleanup"
    fi

    echo ""
}

show_status() {
    echo -e "${CYAN}Current Status:${NC}"
    echo ""

    cd "$EVERSTAR_REPO"

    CURRENT_BRANCH=$(git branch --show-current)
    echo -e "  ${YELLOW}Repo:${NC} $EVERSTAR_REPO"
    echo -e "  ${YELLOW}Branch:${NC} $CURRENT_BRANCH"

    if ! git diff-index --quiet HEAD --; then
        CHANGES=$(git status --short | wc -l | tr -d ' ')
        echo -e "  ${YELLOW}Changes:${NC} $CHANGES uncommitted files"
    else
        echo -e "  ${GREEN}Changes:${NC} Working tree clean"
    fi

    AUTO_BRANCHES=$(git branch | grep -E '.*-auto$' | wc -l | tr -d ' ')
    echo -e "  ${YELLOW}Auto Branches:${NC} $AUTO_BRANCHES"

    TMP_COUNT=$(find /tmp -maxdepth 1 \( -name "ruflo-*" -o -name "everstar-*" \) 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${YELLOW}Automation Tmp Files:${NC} $TMP_COUNT"

    WORKTREE_COUNT=$(find /tmp/everstar-worktrees -mindepth 2 -maxdepth 2 -type d 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    echo -e "  ${YELLOW}Automation Worktrees:${NC} $WORKTREE_COUNT"

    if npx @claude-flow/cli@latest swarm status &> /dev/null; then
        echo -e "  ${YELLOW}Swarm:${NC} Active"
    else
        echo -e "  ${GREEN}Swarm:${NC} Inactive"
    fi

    echo ""
}

archive_completed() {
    echo -e "${CYAN}Archiving completed work...${NC}"
    echo ""

    ARCHIVE_DIR="$SCRIPT_DIR/../archive/$(date +%Y-%m)"
    mkdir -p "$ARCHIVE_DIR"

    cd "$EVERSTAR_REPO"
    MERGED_BRANCHES=$(git branch --merged dev | grep -E '.*-auto$' | sed 's/^[ *]*//' || true)

    if [ -z "$MERGED_BRANCHES" ]; then
        echo -e "${GREEN}[OK]${NC} No merged branches to archive"
        return
    fi

    echo "Merged automation branches:"
    echo "$MERGED_BRANCHES" | while read -r branch; do
        echo "  - $branch"
    done
    echo ""

    if ! confirm "Archive these branches and delete local branches"; then
        echo "Skipped archiving"
        return
    fi

    echo "$MERGED_BRANCHES" | while read -r branch; do
        TICKET=$(echo "$branch" | grep -oE 'eng-[0-9]+' | tr '[:lower:]' '[:upper:]')
        LAST_COMMIT=$(git log "$branch" -1 --format="%H %s")
        PR_NUMBER=$(gh pr list --search "head:$branch" --json number --jq '.[0].number' 2>/dev/null || echo "N/A")
        ARCHIVE_FILE="$ARCHIVE_DIR/${TICKET:-unknown}.txt"

        cat > "$ARCHIVE_FILE" << EOF
Ticket: ${TICKET:-unknown}
Branch: $branch
PR: #$PR_NUMBER
Merged: $(date)
Last Commit: $LAST_COMMIT

$(git log "$branch" --format="%h %s" --reverse)
EOF

        echo -e "${GREEN}[OK]${NC} Archived: ${TICKET:-unknown} -> $ARCHIVE_FILE"
        git branch -d "$branch" 2>/dev/null || true

        if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
            if confirm "Delete remote branch origin/$branch"; then
                git push origin --delete "$branch" 2>/dev/null || true
            else
                echo "Skipped remote branch: origin/$branch"
            fi
        fi
    done

    echo -e "${GREEN}[OK]${NC} Archiving complete: $ARCHIVE_DIR"
    echo ""
}

case "$MODE" in
    --all)
        show_status
        cleanup_tmp
        cleanup_swarm
        cleanup_branches
        archive_completed
        ;;
    --ticket)
        if [ "$SHOULD_CLEAN_TICKET_TMP" = true ]; then
            cleanup_ticket_tmp
        fi
        if [ "$SHOULD_CLEAN_TICKET_WORKTREE" = true ]; then
            cleanup_ticket_worktrees
        fi
        ;;
    --branches)
        cleanup_branches
        ;;
    --tmp)
        cleanup_tmp
        ;;
    --swarm)
        cleanup_swarm
        ;;
    --archive)
        archive_completed
        ;;
    --status)
        show_status
        ;;
    *)
        echo "Usage: $0 [--status|--ticket ENG-XXXX [--tmp] [--worktree]|--all|--branches|--tmp|--swarm|--archive]"
        echo ""
        echo "Options:"
        echo "  --status              Show current status (default)"
        echo "  --ticket ENG-XXXX     Clean only files/worktrees for one ticket"
        echo "  --tmp                 With --ticket, clean ticket tmp files; alone, requires DELETE confirmation for broad tmp cleanup"
        echo "  --worktree            With --ticket, clean ticket worktrees"
        echo "  --branches            Clean old automation branches with confirmation"
        echo "  --swarm               Reset swarm/hive-mind state with confirmation"
        echo "  --archive             Archive merged automation branches with confirmation"
        echo "  --all                 Run broad cleanup flow with confirmations"
        exit 1
        ;;
esac

echo -e "${GREEN}[OK]${NC} Cleanup complete"
echo ""
