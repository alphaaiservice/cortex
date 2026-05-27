#!/bin/bash
# TaskCompleted Quality Gate — Agent Teams hook (experimental).
# Inspects task_output for sloppy completion signals. Exits 2 with a
# message on stderr to reject the completion when issues are found,
# forcing the teammate to address them before marking the task done.
#
# Checks performed:
#   1. Unresolved TODO/FIXME/HACK/XXX markers in the output.
#   2. Tests that appear to have been skipped.
#   3. Possible hardcoded secrets (password/secret/api_key) outside of
#      env/config/example/template/documentation contexts.

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

# Two-pass secrets check: find candidate lines matching secret keywords,
# then filter out lines that appear in obviously safe contexts (env file
# references, example/template docs, config-loading code).
# The previous one-liner used `grep -q | grep -q` which silently never
# fired because -q suppresses stdout to the second grep. v1.3.1 fix.
SECRET_CANDIDATES=$(echo "$TASK_OUTPUT" \
  | grep -iE "password|secret|api[._-]?key" \
  | grep -ivE "\.env|\.example|example\.|config\.|template|placeholder|TODO|FIXME|<your-|YOUR_|\\\$\\{|process\\.env|os\\.environ|os\\.getenv|System\\.getenv")
if [ -n "$SECRET_CANDIDATES" ]; then
  ISSUES="${ISSUES}Possible hardcoded secrets detected. "
fi

if [ -n "$ISSUES" ]; then
  echo "Quality gate: ${ISSUES}Task: ${TASK_NAME}. Please address these issues before marking complete." >&2
  exit 2
fi

exit 0
