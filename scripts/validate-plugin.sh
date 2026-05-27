#!/bin/bash
# Plugin Validator — verifies the cortex plugin is well-formed.
#
# Runs 10 checks against the plugin structure, manifests, and content.
# Exit 0 on success, 1 on any failure. Designed to run both locally
# (before committing) and in CI (.github/workflows/validate-plugin.yml).
#
# Usage:  bash scripts/validate-plugin.sh
# Output: human-readable check log + final summary

set -u  # error on undefined vars (but NOT on errors — we tally them)

# --- Plumbing ---------------------------------------------------------------

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

if [ ! -t 1 ]; then
  GREEN=""; RED=""; YELLOW=""; BLUE=""; RESET=""
fi

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
FAILURES=()

pass() {
  echo -e "  ${GREEN}✓${RESET} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "  ${RED}✗${RESET} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILURES+=("$1")
}

warn() {
  echo -e "  ${YELLOW}!${RESET} $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

heading() {
  echo ""
  echo -e "${BLUE}── $1 ──${RESET}"
}

# Ensure we run from the plugin root regardless of where the user invokes us.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PLUGIN_ROOT"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}║   Cortex Plugin Validator                      ║${RESET}"
echo -e "${BLUE}║   Running 10 checks against plugin structure   ║${RESET}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${RESET}"
echo "Plugin root: $PLUGIN_ROOT"

# Hard prereqs
for tool in jq grep find awk; do
  if ! command -v "$tool" &>/dev/null; then
    echo -e "${RED}✗ Missing required tool: $tool${RESET}"
    exit 2
  fi
done

# --- Check 1: plugin.json -------------------------------------------------

heading "Check 1: .claude-plugin/plugin.json"

if [ ! -f .claude-plugin/plugin.json ]; then
  fail "plugin.json missing"
else
  if jq -e . .claude-plugin/plugin.json >/dev/null 2>&1; then
    pass "plugin.json is valid JSON"
  else
    fail "plugin.json is not valid JSON"
  fi

  for field in name version description author; do
    if jq -e ".${field}" .claude-plugin/plugin.json >/dev/null 2>&1; then
      pass "plugin.json has required field: $field"
    else
      fail "plugin.json missing required field: $field"
    fi
  done
fi

# --- Check 2: marketplace.json --------------------------------------------

heading "Check 2: .claude-plugin/marketplace.json"

if [ ! -f .claude-plugin/marketplace.json ]; then
  fail "marketplace.json missing"
else
  if jq -e . .claude-plugin/marketplace.json >/dev/null 2>&1; then
    pass "marketplace.json is valid JSON"

    # Cross-check: marketplace plugin version must match plugin.json version
    PLUGIN_VER=$(jq -r '.version // empty' .claude-plugin/plugin.json 2>/dev/null)
    MKT_VER=$(jq -r '.plugins[0].version // empty' .claude-plugin/marketplace.json 2>/dev/null)
    MKT_META_VER=$(jq -r '.metadata.version // empty' .claude-plugin/marketplace.json 2>/dev/null)

    if [ -n "$PLUGIN_VER" ] && [ "$PLUGIN_VER" = "$MKT_VER" ]; then
      pass "plugin.json version ($PLUGIN_VER) matches marketplace plugin version"
    else
      fail "version mismatch — plugin.json='$PLUGIN_VER' marketplace.plugins[0]='$MKT_VER'"
    fi

    if [ -n "$MKT_META_VER" ] && [ "$MKT_META_VER" = "$MKT_VER" ]; then
      pass "marketplace.metadata.version matches plugin version"
    else
      warn "marketplace.metadata.version='$MKT_META_VER' differs from plugin version (often fine, just FYI)"
    fi
  else
    fail "marketplace.json is not valid JSON"
  fi
fi

# --- Check 3: hooks.json valid + scripts exist + executable ---------------

heading "Check 3: hooks/hooks.json + referenced scripts"

if [ ! -f hooks/hooks.json ]; then
  fail "hooks/hooks.json missing"
else
  if jq -e . hooks/hooks.json >/dev/null 2>&1; then
    pass "hooks.json is valid JSON"

    # Extract every script path referenced by a hook command.
    # We look for bash invocations under hooks[*].hooks[*].command.
    SCRIPTS_REFERENCED=$(jq -r '
      .hooks
      | to_entries[]
      | .value[]
      | .hooks[]?
      | select(.type == "command")
      | .command
      | select(test("\\$\\{CLAUDE_PLUGIN_ROOT\\}/scripts/"))
      | capture("\\$\\{CLAUDE_PLUGIN_ROOT\\}/(?<p>scripts/[^ ]+)")
      | .p
    ' hooks/hooks.json 2>/dev/null | sort -u)

    if [ -z "$SCRIPTS_REFERENCED" ]; then
      warn "hooks.json references no plugin scripts (expected at least one)"
    else
      while IFS= read -r script_rel; do
        if [ ! -f "$script_rel" ]; then
          fail "hooks.json references missing script: $script_rel"
        elif [ ! -x "$script_rel" ]; then
          fail "hook script not executable (chmod +x): $script_rel"
        else
          pass "hook script OK: $script_rel"
        fi
      done <<< "$SCRIPTS_REFERENCED"
    fi
  else
    fail "hooks.json is not valid JSON"
  fi
fi

# --- Helper: extract YAML frontmatter field -------------------------------
# usage: get_frontmatter_field <file> <field>
# returns 0 if found (prints value), 1 if not.
get_frontmatter_field() {
  local file="$1"
  local field="$2"
  awk -v fld="$field" '
    BEGIN { in_fm = 0 }
    NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; next }
    in_fm && /^---[[:space:]]*$/ { exit }
    in_fm && $0 ~ "^" fld ":" {
      sub("^" fld "[[:space:]]*:[[:space:]]*", "")
      print
      exit
    }
  ' "$file"
}

# --- Check 4: every commands/*.md has frontmatter.description -------------

heading "Check 4: commands/*.md frontmatter"

CMD_COUNT=0
CMD_BAD=0
for cmd_file in commands/*.md; do
  [ -f "$cmd_file" ] || continue
  CMD_COUNT=$((CMD_COUNT + 1))
  if [ -z "$(get_frontmatter_field "$cmd_file" description)" ]; then
    fail "command missing frontmatter.description: $cmd_file"
    CMD_BAD=$((CMD_BAD + 1))
  fi
done

if [ "$CMD_BAD" -eq 0 ] && [ "$CMD_COUNT" -gt 0 ]; then
  pass "all $CMD_COUNT commands have frontmatter.description"
fi

# --- Check 5: every skills/*/SKILL.md has frontmatter.name + .description -

heading "Check 5: skills/*/SKILL.md frontmatter"

SKILL_COUNT=0
SKILL_BAD=0
for skill_dir in skills/*/; do
  skill_file="${skill_dir}SKILL.md"
  if [ ! -f "$skill_file" ]; then
    fail "skill directory missing SKILL.md: $skill_dir"
    SKILL_BAD=$((SKILL_BAD + 1))
    continue
  fi
  SKILL_COUNT=$((SKILL_COUNT + 1))
  missing=()
  for field in name description; do
    if [ -z "$(get_frontmatter_field "$skill_file" "$field")" ]; then
      missing+=("$field")
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    fail "skill missing frontmatter field(s) ${missing[*]}: $skill_file"
    SKILL_BAD=$((SKILL_BAD + 1))
  fi
done

if [ "$SKILL_BAD" -eq 0 ] && [ "$SKILL_COUNT" -gt 0 ]; then
  pass "all $SKILL_COUNT skills have frontmatter.name + .description"
fi

# --- Check 6: every agents/*.md has frontmatter.description ---------------

heading "Check 6: agents/*.md frontmatter"

AGENT_COUNT=0
AGENT_BAD=0
for agent_file in agents/*.md; do
  [ -f "$agent_file" ] || continue
  AGENT_COUNT=$((AGENT_COUNT + 1))
  if [ -z "$(get_frontmatter_field "$agent_file" description)" ]; then
    fail "agent missing frontmatter.description: $agent_file"
    AGENT_BAD=$((AGENT_BAD + 1))
  fi
done

if [ "$AGENT_BAD" -eq 0 ] && [ "$AGENT_COUNT" -gt 0 ]; then
  pass "all $AGENT_COUNT agents have frontmatter.description"
fi

# --- Check 7: no broken references to commands/references/*.md ------------

heading "Check 7: commands/references/*.md citations resolve"

REF_BAD=0
# Find every backtick-quoted path that looks like commands/references/SOMETHING.md
# across all .md files, and verify each cited file exists.
while IFS= read -r ref; do
  # ref looks like:  somefile.md:LINE:commands/references/X.md
  cited_path=$(echo "$ref" | awk -F: '{print $NF}' | tr -d '`"')
  citing_file=$(echo "$ref" | cut -d: -f1)
  if [ ! -f "$cited_path" ]; then
    fail "broken reference in $citing_file → $cited_path"
    REF_BAD=$((REF_BAD + 1))
  fi
done < <(
  grep -RhEon 'commands/references/[A-Za-z0-9_./-]+\.md' \
    commands skills CLAUDE.md 2>/dev/null \
    | grep -v "commands/references/" \
    | head -200
)

if [ "$REF_BAD" -eq 0 ]; then
  pass "all commands/references/*.md citations resolve to existing files"
fi

# --- Check 8: no broken references to skills/*/references/*.md ------------

heading "Check 8: skills/*/references/*.md citations resolve"

SREF_BAD=0
while IFS= read -r cited_path; do
  [ -z "$cited_path" ] && continue
  if [ ! -f "$cited_path" ]; then
    fail "broken skill-reference: $cited_path"
    SREF_BAD=$((SREF_BAD + 1))
  fi
done < <(
  grep -RhEo 'skills/[A-Za-z0-9_-]+/references/[A-Za-z0-9_./-]+\.md' \
    commands skills CLAUDE.md 2>/dev/null \
    | sort -u
)

if [ "$SREF_BAD" -eq 0 ]; then
  pass "all skills/*/references/*.md citations resolve to existing files"
fi

# --- Check 9: no stale *.backup files -------------------------------------

heading "Check 9: no stale *.backup or *.bak files"

BACKUP_FILES=$(find . -type f \( -name "*.backup" -o -name "*.bak" -o -name "*.old" \) \
  -not -path "./.git/*" -not -path "./node_modules/*" 2>/dev/null)

if [ -z "$BACKUP_FILES" ]; then
  pass "no stale backup files in tree"
else
  while IFS= read -r f; do
    fail "stale backup file (should be removed): $f"
  done <<< "$BACKUP_FILES"
fi

# --- Check 10: all scripts/*.sh are executable ----------------------------

heading "Check 10: scripts/*.sh are executable"

SCRIPT_BAD=0
for s in scripts/*.sh; do
  [ -f "$s" ] || continue
  if [ ! -x "$s" ]; then
    fail "script missing +x bit (run chmod +x): $s"
    SCRIPT_BAD=$((SCRIPT_BAD + 1))
  fi
done

if [ "$SCRIPT_BAD" -eq 0 ]; then
  pass "all scripts/*.sh are executable"
fi

# --- Summary ---------------------------------------------------------------

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}║   Summary                                      ║${RESET}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${RESET}"
echo -e "  ${GREEN}Passed:   $PASS_COUNT${RESET}"
echo -e "  ${YELLOW}Warnings: $WARN_COUNT${RESET}"
echo -e "  ${RED}Failed:   $FAIL_COUNT${RESET}"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo ""
  echo -e "${RED}Validation FAILED. Issues to fix:${RESET}"
  for f in "${FAILURES[@]}"; do
    echo -e "  ${RED}•${RESET} $f"
  done
  exit 1
fi

echo ""
echo -e "${GREEN}✓ Plugin validation passed.${RESET}"
exit 0
