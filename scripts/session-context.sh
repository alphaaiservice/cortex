#!/bin/bash
# Session Context Loader — Shows plugin persona and loads project context
# Fires on SessionStart hook

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║    █████╗ ██╗     ██████╗ ██╗  ██╗ █████╗                 ║"
echo "║   ██╔══██╗██║     ██╔══██╗██║  ██║██╔══██╗                ║"
echo "║   ███████║██║     ██████╔╝███████║███████║                ║"
echo "║   ██╔══██║██║     ██╔═══╝ ██╔══██║██╔══██║                ║"
echo "║   ██║  ██║███████╗██║     ██║  ██║██║  ██║                ║"
echo "║   ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝                ║"
echo "║                                                            ║"
echo "║       Cortex v1.0.0 — SDLC Automation Engine              ║"
echo "║       Forge Production-Ready Software                      ║"
echo "║       Alpha AI Service Pvt Ltd                             ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
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

# Auto-resume detection — check for interrupted builds FIRST
AUTO_RESUME=false
if [ -f "AUTO_BUILD_STATE.json" ]; then
  BUILD_STATUS=$(jq -r '.build_status // "unknown"' AUTO_BUILD_STATE.json 2>/dev/null || echo "unknown")
  if [ "$BUILD_STATUS" = "in_progress" ] || [ "$BUILD_STATUS" = "building" ]; then
    PHASE=$(jq -r '.current_phase // "unknown"' AUTO_BUILD_STATE.json 2>/dev/null || echo "unknown")
    PROGRESS=$(jq -r '.completion_percentage // 0' AUTO_BUILD_STATE.json 2>/dev/null || echo "0")
    LAST_UPDATE=$(jq -r '.last_updated // "unknown"' AUTO_BUILD_STATE.json 2>/dev/null || echo "unknown")
    BLOCKERS=$(jq -r '.blockers // [] | length' AUTO_BUILD_STATE.json 2>/dev/null || echo "0")
    BUILD_MODE=$(jq -r '.build_mode // "sequential"' AUTO_BUILD_STATE.json 2>/dev/null || echo "sequential")

    echo "INTERRUPTED BUILD DETECTED"
    echo "  Phase:     ${PHASE}"
    echo "  Progress:  ${PROGRESS}%"
    echo "  Mode:      ${BUILD_MODE}"
    echo "  Updated:   ${LAST_UPDATE}"
    if [ "$BLOCKERS" -gt 0 ]; then
      echo "  Blockers:  ${BLOCKERS} unresolved"
    fi
    echo ""
    echo "  Run /resume-build to continue automatically"
    echo ""
    AUTO_RESUME=true
  fi
fi

# Project type detection (skip if auto-resume detected)
if [ "$AUTO_RESUME" = "false" ]; then
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
fi

# Sprint status
if [ -f "SPRINT_PLAN.md" ]; then
  DONE=$(grep -c "done" SPRINT_PLAN.md 2>/dev/null || echo "0")
  TOTAL=$(grep -cE "^\|.*\|.*\|" SPRINT_PLAN.md 2>/dev/null || echo "0")
  echo "Sprint: ${DONE}/${TOTAL} tasks complete"
fi

# State backup count
BACKUP_COUNT=0
if [ -d ".cortex/state-backups" ]; then
  BACKUP_COUNT=$(ls .cortex/state-backups/*.json 2>/dev/null | wc -l | tr -d ' ')
fi

echo ""
if [ "$AUTO_RESUME" = "true" ]; then
  echo "Commands:"
  echo "  /resume-build        Resume interrupted build"
  echo "  /code-review         Multi-agent code review"
  echo "  /debug               AI-powered debugging"
  echo "  /ship                Lint + test + commit + PR"
  if [ "$BACKUP_COUNT" -gt 0 ]; then
    echo ""
    echo "  ${BACKUP_COUNT} state backup(s) in .cortex/state-backups/"
  fi
else
  echo "Quick Start:"
  echo "  /gen-prd 'idea'      Generate PRD + Sprint Plan"
  echo "  /auto-build PRD.md   Build entire product autonomously"
  echo "  /init-project name   Scaffold new project"
  echo "  /code-review         Multi-agent code review"
  echo "  /debug               AI-powered debugging"
  echo "  /ship                Lint + test + commit + PR"
  echo "  /gap-analysis        Check standards compliance"
  echo "  /security-scan       OWASP Top 10 scan"
fi
echo ""
echo "Type /help to see all ${CMD_COUNT} commands"
echo ""
