#!/bin/bash
# Auto-recovery for stuck automation

WORKTREE_BASE="/tmp/everstar-worktrees"

detect_incomplete_work() {
    for worktree in "$WORKTREE_BASE"/*/*; do
        if [ ! -d "$worktree" ]; then continue; fi

        cd "$worktree" 2>/dev/null || continue

        # Check if there are uncommitted changes
        if git diff --quiet && git diff --cached --quiet; then
            continue
        fi

        # Extract ticket from path
        ticket=$(basename "$(dirname "$worktree")")/$(basename "$worktree") | grep -o 'ENG-[0-9]*')

        echo "Found incomplete work: $ticket in $worktree"
        echo "  - Branch: $(git branch --show-current)"
        echo "  - Changed files: $(git status --short | wc -l)"
        echo ""
        echo "To recover:"
        echo "  ./scripts/everstar-cli.sh $ticket --resume"
        echo ""
    done
}

# Run detection
detect_incomplete_work
