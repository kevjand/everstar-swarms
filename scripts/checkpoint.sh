#!/bin/bash
# Checkpoint system for resumable automation

CHECKPOINT_FILE="/tmp/everstar-automation-checkpoint.json"

checkpoint_save() {
    local ticket_id=$1
    local phase=$2
    local status=$3
    local worktree=$4

    cat > "$CHECKPOINT_FILE" << EOF
{
  "ticket_id": "$ticket_id",
  "phase": "$phase",
  "status": "$status",
  "worktree": "$worktree",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    echo "[CHECKPOINT] Saved: Phase $phase - $status"
}

checkpoint_load() {
    if [ -f "$CHECKPOINT_FILE" ]; then
        cat "$CHECKPOINT_FILE"
    else
        echo "{}"
    fi
}

checkpoint_clear() {
    rm -f "$CHECKPOINT_FILE"
}

# Export functions
export -f checkpoint_save
export -f checkpoint_load
export -f checkpoint_clear
