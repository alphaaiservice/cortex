#!/bin/bash
# Auto-Format — PostToolUse hook that formats files after Write or Edit
# Picks the right formatter based on file extension:
#   .py        → ruff (preferred) or black
#   .ts/tsx/   → prettier (prefer node_modules-local install)
#   .js/jsx
#   .java      → google-java-format
# Silently no-ops if no formatter is installed for the file type.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE" ]; then
  exit 0
fi

case "$FILE" in
  *.py)
    if command -v ruff &>/dev/null; then
      ruff format "$FILE" 2>/dev/null && \
        ruff check --fix "$FILE" 2>/dev/null && \
        echo "Auto-formatted (Python): $FILE"
    elif command -v black &>/dev/null; then
      black --quiet "$FILE" 2>/dev/null && \
        echo "Auto-formatted (Python): $FILE"
    fi
    ;;
  *.ts|*.tsx|*.js|*.jsx)
    if [ -x node_modules/.bin/prettier ]; then
      node_modules/.bin/prettier --write "$FILE" 2>/dev/null && \
        echo "Auto-formatted (JS/TS): $FILE"
    elif command -v prettier &>/dev/null; then
      prettier --write "$FILE" 2>/dev/null && \
        echo "Auto-formatted (JS/TS): $FILE"
    fi
    ;;
  *.java)
    if command -v google-java-format &>/dev/null; then
      google-java-format --replace "$FILE" 2>/dev/null && \
        echo "Auto-formatted (Java): $FILE"
    fi
    ;;
esac

exit 0
