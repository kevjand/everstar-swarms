#!/bin/bash
# Everstar Automation Cleanup Script
# Cleans up old branches, tmp files, and swarm state
# Usage: ./scripts/cleanup.sh [--all|--branches|--tmp|--swarm]

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get everstar repo path from everstar-cli.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVERSTAR_REPO=$(grep 'EVERSTAR_REPO=' "$SCRIPT_DIR/everstar-cli.sh" | cut -d'"' -f2)

if [ ! -d "$EVERSTAR_REPO" ]; then
    echo -e "${RED}✗${NC} Everstar repository not found: $EVERSTAR_REPO"
    echo "  Run setup.sh first: ./scripts/setup.sh"
    exit 1
fi

MODE="${1:---all}"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Everstar Automation Cleanup          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

cleanup_branches() {
    echo -e "${CYAN}Cleaning up old automation branches...${NC}"
    echo ""

    cd "$EVERSTAR_REPO"

    # Find all branches matching *-auto pattern
    AUTO_BRANCHES=$(git branch | grep -E '.*-auto$' | sed 's/^[ *]*//' || true)

    if [ -z "$AUTO_BRANCHES" ]; then
        echo -e "${GREEN}OK${NC} No automation branches to clean"
        return
    fi

    echo "Found automation branches:"
    echo "$AUTO_BRANCHES" | while read branch; do
        echo "  • $branch"
    done
    echo ""

    read -p "Delete these branches? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Skipped branch cleanup"
        return
    fi

    CURRENT_BRANCH=$(git branch --show-current)

    echo "$AUTO_BRANCHES" | while read branch; do
        if [ "$branch" = "$CURRENT_BRANCH" ]; then
            echo -e "${YELLOW}⊙${NC} Skipping current branch: $branch"
        else
            # Check if branch has remote
            if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
                echo -e "${YELLOW}→${NC} Deleting local and remote: $branch"
                git branch -D "$branch" 2>/dev/null || true
                git push origin --delete "$branch" 2>/dev/null || true
            else
                echo -e "${YELLOW}→${NC} Deleting local: $branch"
                git branch -D "$branch" 2>/dev/null || true
            fi
        fi
    done

    echo -e "${GREEN}OK${NC} Branch cleanup complete"
    echo ""
}

cleanup_tmp() {
    echo -e "${CYAN}Cleaning up temporary files...${NC}"
    echo ""

    # Find all Ruflo temporary files
    TMP_FILES=$(find /tmp -name "ruflo-*" -o -name "everstar-*" 2>/dev/null || true)

    if [ -z "$TMP_FILES" ]; then
        echo -e "${GREEN}OK${NC} No temporary files to clean"
        return
    fi

    echo "Found temporary files:"
    echo "$TMP_FILES" | while read file; do
        SIZE=$(du -h "$file" 2>/dev/null | cut -f1)
        echo "  • $(basename "$file") ($SIZE)"
    done
    echo ""

    FILE_COUNT=$(echo "$TMP_FILES" | wc -l | tr -d ' ')
    read -p "Delete $FILE_COUNT temporary files? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Skipped tmp cleanup"
        return
    fi

    echo "$TMP_FILES" | while read file; do
        rm -f "$file"
    done

    echo -e "${GREEN}OK${NC} Temporary files cleaned"
    echo ""
}

cleanup_swarm() {
    echo -e "${CYAN}Resetting swarm state...${NC}"
    echo ""

    # Check if swarm is active
    if npx @claude-flow/cli@latest swarm status &> /dev/null; then
        echo "Active swarm detected"
        read -p "Shutdown active swarm? (y/n): " confirm
        if [ "$confirm" = "y" ]; then
            npx @claude-flow/cli@latest swarm shutdown &> /dev/null || true
            echo -e "${GREEN}OK${NC} Swarm shutdown"
        fi
    else
        echo -e "${GREEN}OK${NC} No active swarm"
    fi

    # Check if hive-mind is active
    if npx @claude-flow/cli@latest hive-mind status &> /dev/null; then
        echo "Active hive-mind detected"
        read -p "Shutdown hive-mind? (y/n): " confirm
        if [ "$confirm" = "y" ]; then
            npx @claude-flow/cli@latest hive-mind shutdown &> /dev/null || true
            echo -e "${GREEN}OK${NC} Hive-mind shutdown"
        fi
    else
        echo -e "${GREEN}OK${NC} No active hive-mind"
    fi

    # Clean memory namespace
    echo "Cleaning active-tickets memory namespace..."
    npx @claude-flow/cli@latest memory delete --namespace "active-tickets" --all &> /dev/null || true
    echo -e "${GREEN}OK${NC} Memory cleaned"

    echo ""
}

show_status() {
    echo -e "${CYAN}Current Status:${NC}"
    echo ""

    cd "$EVERSTAR_REPO"

    # Current branch
    CURRENT_BRANCH=$(git branch --show-current)
    echo -e "  ${YELLOW}Branch:${NC} $CURRENT_BRANCH"

    # Uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        CHANGES=$(git status --short | wc -l | tr -d ' ')
        echo -e "  ${YELLOW}Changes:${NC} $CHANGES uncommitted files"
    else
        echo -e "  ${GREEN}Changes:${NC} Working tree clean"
    fi

    # Automation branches
    AUTO_BRANCHES=$(git branch | grep -E '.*-auto$' | wc -l | tr -d ' ')
    echo -e "  ${YELLOW}Auto Branches:${NC} $AUTO_BRANCHES"

    # Temporary files
    TMP_COUNT=$(find /tmp -name "ruflo-*" -o -name "everstar-*" 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${YELLOW}Tmp Files:${NC} $TMP_COUNT"

    # Swarm status
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

    # Find merged automation branches
    cd "$EVERSTAR_REPO"
    MERGED_BRANCHES=$(git branch --merged dev | grep -E '.*-auto$' | sed 's/^[ *]*//' || true)

    if [ -z "$MERGED_BRANCHES" ]; then
        echo -e "${GREEN}OK${NC} No merged branches to archive"
        return
    fi

    echo "Merged automation branches:"
    echo "$MERGED_BRANCHES" | while read branch; do
        echo "  • $branch"
    done
    echo ""

    read -p "Archive these branches? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Skipped archiving"
        return
    fi

    echo "$MERGED_BRANCHES" | while read branch; do
        # Extract ticket ID
        TICKET_ID=$(echo "$branch" | grep -oE 'eng-[0-9]+' | tr '[:lower:]' '[:upper:]')

        # Get branch info
        LAST_COMMIT=$(git log "$branch" -1 --format="%H %s")
        PR_NUMBER=$(gh pr list --search "head:$branch" --json number --jq '.[0].number' 2>/dev/null || echo "N/A")

        # Write archive file
        ARCHIVE_FILE="$ARCHIVE_DIR/$TICKET_ID.txt"
        cat > "$ARCHIVE_FILE" << EOF
Ticket: $TICKET_ID
Branch: $branch
PR: #$PR_NUMBER
Merged: $(date)
Last Commit: $LAST_COMMIT

$(git log "$branch" --format="%h %s" --reverse)
EOF

        echo -e "${GREEN}OK${NC} Archived: $TICKET_ID → $ARCHIVE_FILE"

        # Delete branch
        git branch -d "$branch" 2>/dev/null || true
        git push origin --delete "$branch" 2>/dev/null || true
    done

    echo -e "${GREEN}OK${NC} Archiving complete: $ARCHIVE_DIR"
    echo ""
}

# Main execution
case "$MODE" in
    --all)
        show_status
        cleanup_tmp
        cleanup_swarm
        cleanup_branches
        archive_completed
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
        echo "Usage: $0 [--all|--branches|--tmp|--swarm|--archive|--status]"
        echo ""
        echo "Options:"
        echo "  --all       Clean everything (default)"
        echo "  --branches  Clean up old automation branches"
        echo "  --tmp       Clean temporary files"
        echo "  --swarm     Reset swarm/hive-mind state"
        echo "  --archive   Archive merged branches"
        echo "  --status    Show current status"
        exit 1
        ;;
esac

echo -e "${GREEN}OK${NC} Cleanup complete!"
echo ""
