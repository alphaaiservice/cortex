#!/bin/bash
# Safe Bash Check — Pre-tool hook to validate bash commands
# Blocks dangerous commands from being executed accidentally

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Critical patterns — BLOCK these (exit 2)
CRITICAL_PATTERNS=(
  "rm -rf /"
  "rm -rf ~"
  "rm -rf \*"
  ":(){ :|:& };:"
  "mkfs\."
  "dd if="
  "> /dev/sd"
  "eval \$(curl"
)

# Warning patterns — warn but allow (exit 0)
WARNING_PATTERNS=(
  "DROP DATABASE"
  "DROP TABLE"
  "TRUNCATE TABLE"
  "DELETE FROM .* WHERE 1"
  "chmod -R 777"
  "curl .* | bash"
  "wget .* | bash"
)

# Check critical patterns first — block execution
for pattern in "${CRITICAL_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qiE "$pattern"; then
    echo "BLOCKED: Critically dangerous command detected!" >&2
    echo "Pattern matched: $pattern" >&2
    echo "Command: $COMMAND" >&2
    echo "This command has been blocked for safety." >&2
    exit 2  # Block the action
  fi
done

# Check warning patterns — warn but allow
for pattern in "${WARNING_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qiE "$pattern"; then
    echo "WARNING: Potentially dangerous command detected." >&2
    echo "Pattern matched: $pattern" >&2
    echo "Command: $COMMAND" >&2
    echo "Please review before allowing." >&2
    exit 0  # Warn only
  fi
done

# Check for production database connections — warn but allow
if echo "$COMMAND" | grep -qiE "(production|prod)\." && echo "$COMMAND" | grep -qiE "(psql|mysql|mongo|redis-cli)"; then
  echo "WARNING: Command appears to connect to a production database!" >&2
  echo "Command: $COMMAND" >&2
  exit 0
fi

exit 0
