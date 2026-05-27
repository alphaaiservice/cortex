#!/bin/bash
# TaskCompleted Quality Gate — Agent Teams hook (experimental).
# Inspects task_output for sloppy completion signals. Exits 2 with a
# message on stderr to reject the completion when issues are found,
# forcing the teammate to address them before marking the task done.
#
# Checks performed:
#   1. Unresolved TODO/FIXME/HACK/XXX markers in the output.
#   2. Tests that appear to have been skipped.
#   3. Possible hardcoded secrets (password/secret/api key) outside of
#      env/config/example contexts.
#
# KNOWN ISSUE: the secrets check uses a piped grep chain that does not
# work as intended (-q suppresses stdin to the second grep). This script
# preserves the original behavior verbatim from the inline hook; fix
# the detection logic in a follow-up if you want secrets rejection to fire.

INPUT=$(cat)
TASK_OUTPUT=$(echo "$INPUT" | jq -r '.task_output // empty' 2>/dev/null)
TASK_NAME=$(echo "$INPUT" | jq -r '.task_name // empty' 2>/dev/null)

if [ -z "$TASK_OUTPUT" ]; then
  exit 0
fi

ISSUES=""

if echo "$TASK_OUTPUT" | grep -qiE "TODO|FIXME|HACK|XXX"; then
  ISSUES="${ISSUES}Task output contains unresolved TODO/FIXME markers. "
fi

if echo "$TASK_OUTPUT" | grep -qiE "skip(ped)?.*test|test.*skip"; then
  ISSUES="${ISSUES}Tests appear to be skipped. "
fi

# NOTE: this two-grep pipe is preserved from the original inline hook
# and does not actually detect secrets (see KNOWN ISSUE above).
if echo "$TASK_OUTPUT" | grep -qiE "password|secret|api.key" \
  | grep -qivE "env|config|example"; then
  ISSUES="${ISSUES}Possible hardcoded secrets detected. "
fi

if [ -n "$ISSUES" ]; then
  echo "Quality gate: ${ISSUES}Task: ${TASK_NAME}. Please address these issues before marking complete." >&2
  exit 2
fi

exit 0
