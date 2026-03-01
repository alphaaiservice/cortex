#!/bin/bash
# Session Context Loader — Shows plugin persona and loads project context
# Fires on SessionStart hook

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║     █████╗ ██╗     ██████╗ ██╗  ██╗ █████╗                  ║"
echo "║    ██╔══██╗██║     ██╔══██╗██║  ██║██╔══██╗                 ║"
echo "║    ███████║██║     ██████╔╝███████║███████║                 ║"
echo "║    ██╔══██║██║     ██╔═══╝ ██╔══██║██╔══██║                 ║"
echo "║    ██║  ██║███████╗██║     ██║  ██║██║  ██║                 ║"
echo "║    ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝                 ║"
echo "║                                                              ║"
echo "║        ⚒  Cortex v1.0.0 — SDLC Automation Engine        ║"
echo "║           Forge Production-Ready Software                    ║"
echo "║           Alpha AI Service Pvt Ltd                           ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Plugin stats
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
CMD_COUNT=$(ls "$PLUGIN_ROOT/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
AGENT_COUNT=$(ls "$PLUGIN_ROOT/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
SKILL_COUNT=$(find "$PLUGIN_ROOT/skills/" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')

echo "Plugin Loaded: ${CMD_COUNT} commands | ${AGENT_COUNT} agents | ${SKILL_COUNT} skills"
echo ""

# Git context
if git rev-parse --is-inside-work-tree &>/dev/null; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo 'detached')
  LAST_COMMIT=$(git log --oneline -1 2>/dev/null || echo 'no commits')
  DIRTY=$(git status --short 2>/dev/null | wc -l | tr -d ' ')

  echo "Git: ${BRANCH} | Last: ${LAST_COMMIT}"
  if [ "$DIRTY" -gt 0 ]; then
    echo "  ${DIRTY} uncommitted changes"
  fi
  echo ""
fi

# Project type detection
if [ -f "PRD.md" ]; then
  echo "Project: PRD.md found -- use /auto-build ./PRD.md to build"
elif [ -f "requirements.txt" ] && [ -d "app" ]; then
  echo "Project: FastAPI project detected"
elif [ -f "package.json" ]; then
  NAME=$(jq -r '.name // "unknown"' package.json 2>/dev/null)
  echo "Project: ${NAME}"
elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
  echo "Project: Python project"
else
  echo "Project: No project detected -- use /gen-prd 'your idea' to start"
fi

# Sprint status
if [ -f "SPRINT_PLAN.md" ]; then
  DONE=$(grep -c "done" SPRINT_PLAN.md 2>/dev/null || echo "0")
  TOTAL=$(grep -cE "^\|.*\|.*\|" SPRINT_PLAN.md 2>/dev/null || echo "0")
  echo "Sprint: ${DONE}/${TOTAL} tasks complete"
fi

echo ""
echo "Quick Start:"
echo "  /gen-prd 'idea'      Generate PRD + Sprint Plan"
echo "  /auto-build PRD.md   Build entire product autonomously"
echo "  /init-project name   Scaffold new project"
echo "  /code-review         Multi-agent code review"
echo "  /debug               AI-powered debugging"
echo "  /ship                Lint + test + commit + PR"
echo "  /gap-analysis        Check standards compliance"
echo "  /security-scan       OWASP Top 10 scan"
echo ""
echo "Type /help to see all ${CMD_COUNT} commands"
echo ""
