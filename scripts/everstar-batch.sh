#!/bin/bash
# Everstar Batch CLI - Run multiple tickets in parallel using worktrees
# Usage: ./everstar-batch.sh USER_PREFIX TICKET1 TICKET2 TICKET3...
# Example: ./everstar-batch.sh kevjand ENG-4214 ENG-4215 ENG-4216

set -e

USER_PREFIX=$1
shift  # Remove first arg, rest are tickets

if [ -z "$USER_PREFIX" ] || [ $# -eq 0 ]; then
    echo "Usage: ./everstar-batch.sh USER_PREFIX TICKET1 [TICKET2 TICKET3 ...]"
    echo "Example: ./everstar-batch.sh kevjand ENG-4214 ENG-4215 ENG-4216"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TICKETS=("$@")

echo "🚀 Processing ${#TICKETS[@]} tickets in parallel..."
echo "   User: $USER_PREFIX"
echo "   Tickets: ${TICKETS[*]}"
echo ""

# Spawn each ticket in background
for TICKET in "${TICKETS[@]}"; do
    echo "  ▶️  Starting $TICKET..."
    "$SCRIPT_DIR/everstar-cli.sh" "$TICKET" "$USER_PREFIX" > "/tmp/everstar-$TICKET.log" 2>&1 &

    # Stagger starts by 10 seconds to avoid conflicts
    sleep 10
done

echo ""
echo "✅ All tickets started!"
echo ""
echo "📊 Monitor progress:"
for TICKET in "${TICKETS[@]}"; do
    echo "   tail -f /tmp/everstar-$TICKET.log"
done
echo ""
echo "⏳ Waiting for all tickets to complete..."
echo ""

# Wait for all background jobs
wait

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Batch complete: ${#TICKETS[@]} tickets processed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show summary
echo "📊 Summary:"
for TICKET in "${TICKETS[@]}"; do
    WORKTREE="/tmp/everstar-worktrees/$USER_PREFIX/$TICKET"
    if [ -d "$WORKTREE" ]; then
        cd "$WORKTREE"
        if git diff-index --quiet HEAD --; then
            echo "  ❌ $TICKET - No changes"
        else
            echo "  ✅ $TICKET - Changes made"
        fi
    else
        echo "  ⚠️  $TICKET - Worktree not found"
    fi
done

echo ""
echo "💡 Check logs at: /tmp/everstar-*.log"
echo ""
