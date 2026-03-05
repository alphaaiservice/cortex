#!/bin/bash
#====================================================================
# Cortex — Auto-Build Stop Hook
#
# This hook fires when Claude tries to stop during an auto-build.
# If the build isn't complete, it blocks the exit and prompts
# Claude to continue working.
#
# This implements the Ralph Wiggum pattern for persistent loops.
#====================================================================

# Read stdin safely — may or may not be valid JSON
INPUT=$(cat 2>/dev/null || true)
STATE_FILE="AUTO_BUILD_STATE.json"
COMPLETION_PROMISE="PRODUCT_COMPLETE"

# Check if we're in auto-build mode
if [ ! -f "$STATE_FILE" ]; then
    # Not in auto-build mode, allow normal exit
    exit 0
fi

# Check if auto-build mode is active (with safe jq parsing)
AUTO_BUILD_ACTIVE=$(jq -r '.build_status // "not_started"' "$STATE_FILE" 2>/dev/null || echo "not_started")
if [ "$AUTO_BUILD_ACTIVE" = "not_started" ] || [ "$AUTO_BUILD_ACTIVE" = "complete" ]; then
    exit 0
fi

# Check if the completion promise was output (safely parse transcript path)
TRANSCRIPT=""
if echo "$INPUT" | jq empty 2>/dev/null; then
    TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || true)
fi

if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    if grep -q "<promise>$COMPLETION_PROMISE</promise>" "$TRANSCRIPT" 2>/dev/null; then
        # Product is complete! Allow exit.
        jq '.build_status = "complete"' "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null && mv "${STATE_FILE}.tmp" "$STATE_FILE"
        echo "Product build complete. Allowing exit." >&2
        exit 0
    fi
fi

# Check completion percentage (with safe jq parsing)
COMPLETION=$(jq -r '.completion_percentage // 0' "$STATE_FILE" 2>/dev/null || echo "0")
CURRENT_PHASE=$(jq -r '.current_phase // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")

# Auto-commit checkpoint before blocking exit
if git rev-parse --is-inside-work-tree &>/dev/null; then
    DIRTY=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
    if [ "$DIRTY" -gt 0 ]; then
        git add -A 2>/dev/null
        git commit -m "checkpoint(phase-${CURRENT_PHASE}): auto-save at ${COMPLETION}% before continue" 2>/dev/null
        echo "Auto-committed checkpoint (phase: ${CURRENT_PHASE}, ${COMPLETION}%)." >&2
    fi
fi

# Backup state file
BACKUP_DIR=".cortex/state-backups"
mkdir -p "$BACKUP_DIR" 2>/dev/null
cp "$STATE_FILE" "$BACKUP_DIR/stop-hook-$(date +%Y%m%d_%H%M%S).json" 2>/dev/null

# Log event to state file
jq --arg ts "$(date -Iseconds)" --arg phase "$CURRENT_PHASE" --arg pct "$COMPLETION" \
    '.event_log = (.event_log // []) + [{"event": "stop_blocked", "timestamp": $ts, "phase": $phase, "completion": $pct}]' \
    "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null && mv "${STATE_FILE}.tmp" "$STATE_FILE"

# Product not complete — block exit and continue
echo "Auto-build in progress (${COMPLETION}% complete, phase: ${CURRENT_PHASE}). Continuing..." >&2
echo "" >&2
echo "The product is not yet complete. Continue building from where you left off." >&2
echo "Read AUTO_BUILD_STATE.json for current progress and continue with the next task." >&2
echo "Remember: NEVER ask the user for input. Make decisions and document them." >&2
echo "When completely done, output: <promise>$COMPLETION_PROMISE</promise>" >&2

# Exit code 2 blocks Claude from stopping
exit 2
