#!/bin/bash
# PreCompact Checkpoint — fires before Claude Code compacts context.
# Backs up AUTO_BUILD_STATE.json and (if inside a git repo) auto-commits
# any dirty changes so /auto-build can resume cleanly after compaction.
# Always exits 0 — never block compaction.

STATE_FILE="AUTO_BUILD_STATE.json"

if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# Snapshot the state file into a timestamped backup
BACKUP_DIR=".cortex/state-backups"
mkdir -p "$BACKUP_DIR"
cp "$STATE_FILE" "$BACKUP_DIR/$(date +%Y%m%d_%H%M%S).json" 2>/dev/null

PHASE=$(jq -r '.current_phase // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")
PCT=$(jq -r '.completion_percentage // 0' "$STATE_FILE" 2>/dev/null || echo "0")
echo "State backed up before compaction (phase: $PHASE, progress: ${PCT}%)"

# If we're inside a git repo and there are dirty changes, commit a checkpoint
if git rev-parse --is-inside-work-tree &>/dev/null; then
  DIRTY=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
  if [ "$DIRTY" -gt 0 ]; then
    git add -A 2>/dev/null && \
      git commit -m "checkpoint(phase-${PHASE}): auto-save before context compaction [${PCT}%]" 2>/dev/null && \
      echo "Auto-committed checkpoint before compaction."
  fi
fi

exit 0
