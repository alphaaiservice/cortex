#!/bin/bash
# TeammateIdle Reassign — Agent Teams hook (experimental).
# Fires when a teammate has no tasks. If pending tasks remain on the
# shared task list at ~/.claude/tasks/<team>, instruct the teammate to
# claim the next one by exiting 2 with a message on stderr.
# Exits 0 (idle is fine) when no pending tasks remain.

INPUT=$(cat)
TEAM=$(echo "$INPUT" | jq -r '.team_name // empty' 2>/dev/null)

if [ -z "$TEAM" ] || [ ! -d "$HOME/.claude/tasks/${TEAM}" ]; then
  exit 0
fi

PENDING=$(cat "$HOME/.claude/tasks/${TEAM}"/*.json 2>/dev/null \
  | jq -s '[.[] | select(.status == "pending")] | length' 2>/dev/null \
  || echo 0)

if [ "$PENDING" -gt 0 ]; then
  echo "$PENDING pending tasks remain. Claim next available task." >&2
  exit 2
fi

exit 0
