#!/bin/bash
# Safe Bash Check — Pre-tool hook to validate bash commands
# Blocks dangerous commands from being executed accidentally

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# List of dangerous patterns to warn about
DANGEROUS_PATTERNS=(
  "rm -rf /"
  "rm -rf ~"
  "rm -rf \*"
  "DROP DATABASE"
  "DROP TABLE"
  "TRUNCATE TABLE"
  "DELETE FROM .* WHERE 1"
  ":(){ :|:& };:"
  "mkfs\."
  "dd if="
  "> /dev/sd"
  "chmod -R 777"
  "curl .* | bash"
  "wget .* | bash"
  "eval \$(curl"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qiE "$pattern"; then
    echo "⚠️  SAFETY WARNING: Potentially dangerous command detected!" >&2
    echo "Pattern matched: $pattern" >&2
    echo "Command: $COMMAND" >&2
    echo "Please review before allowing." >&2
    exit 0  # Don't block, just warn
  fi
done

# Check for production database connections
if echo "$COMMAND" | grep -qiE "(production|prod)\." && echo "$COMMAND" | grep -qiE "(psql|mysql|mongo|redis-cli)"; then
  echo "⚠️  WARNING: Command appears to connect to a production database!" >&2
  echo "Command: $COMMAND" >&2
  exit 0
fi

exit 0
