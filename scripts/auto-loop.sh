#!/bin/bash
#====================================================================
# Cortex — Autonomous Build Loop Runner
# 
# This script implements the Ralph Wiggum pattern for autonomous
# product development. It runs Claude Code in a loop until the
# product is complete or max iterations are reached.
#
# Usage:
#   ./auto-loop.sh "Build a SaaS invoicing platform with Next.js and Prisma"
#   ./auto-loop.sh ./prd.md
#   ./auto-loop.sh ./prd.md --max-iterations 50
#   ./auto-loop.sh ./prd.md --max-iterations 50 --monitor
#
# Requirements:
#   - Claude Code CLI installed (claude command available)
#   - tmux (optional, for monitoring mode)
#
# Author: Alpha AI Service Pvt Ltd
#====================================================================

set -euo pipefail

# ======================== CONFIGURATION ========================

MAX_ITERATIONS=100
COMPLETION_PROMISE="PRODUCT_COMPLETE"
ITERATION=0
LOG_DIR=".cortex/logs"
STATE_FILE="AUTO_BUILD_STATE.json"
MONITOR_MODE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ======================== ARGUMENT PARSING ========================

PRD_INPUT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --max-iterations)
            shift
            MAX_ITERATIONS="${1:-100}"
            ;;
        --monitor)
            MONITOR_MODE=true
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
        *)
            if [ -z "$PRD_INPUT" ]; then
                PRD_INPUT="$1"
            fi
            ;;
    esac
    shift
done

if [ -z "$PRD_INPUT" ]; then
    echo -e "${RED}Error: No input provided${NC}"
    echo ""
    echo "Usage:"
    echo "  ./auto-loop.sh \"Product description here\""
    echo "  ./auto-loop.sh ./path/to/prd.md"
    echo "  ./auto-loop.sh ./prd.md --max-iterations 50"
    echo "  ./auto-loop.sh ./prd.md --max-iterations 50 --monitor"
    exit 1
fi

# ======================== SETUP ========================

mkdir -p "$LOG_DIR"
START_TIME=$(date +%s)
START_DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Determine if input is a file or text
if [ -f "$PRD_INPUT" ]; then
    PRD_CONTENT=$(cat "$PRD_INPUT")
    echo -e "${GREEN}📄 Reading PRD from: $PRD_INPUT${NC}"
else
    PRD_CONTENT="$PRD_INPUT"
    echo -e "${GREEN}📝 Using inline product description${NC}"
fi

# ======================== BANNER ========================

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                                                          ║"
echo "║   ⚒  Cortex — Autonomous Product Builder              ║"
echo "║   ──────────────────────────────────────────────         ║"
echo "║   Mode:           Fully Autonomous                       ║"
echo "║   Max Iterations:  $MAX_ITERATIONS                              ║"
echo "║   Started:         $START_DATE               ║"
echo "║   Completion:      $COMPLETION_PROMISE                 ║"
echo "║                                                          ║"
echo "║   Press Ctrl+C to stop at any time                       ║"
echo "║                                                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ======================== PROMPT CONSTRUCTION ========================

BUILD_PROMPT="You are an autonomous product builder. Build this product completely without asking any questions.

## Product Specification
$PRD_CONTENT

## Instructions
1. Read AUTO_BUILD_STATE.json if it exists to resume from where you left off
2. If starting fresh, run /auto-build with the above specification
3. Execute each phase completely — scaffold, data, logic, API, frontend, auth, tests, docs, CI/CD
4. After each phase: run tests, fix failures, commit to git
5. NEVER ask the user for input — make reasonable decisions and document them
6. Update AUTO_BUILD_STATE.json after every significant step
7. When the ENTIRE product is built, tested, and documented, output exactly: <promise>$COMPLETION_PROMISE</promise>

## Decision-Making Rules (when ambiguous)
- Framework: Use the most popular/stable option for the stack
- Database: MySQL for relational, MongoDB for document-based
- Auth: JWT with refresh tokens
- Styling: Tailwind CSS for frontend
- Testing: Jest/Vitest for JS, Pytest for Python
- API format: REST with JSON unless GraphQL is specified
- Package manager: npm (Node.js), pip/uv (Python)

## Self-Healing Rules
- If a test fails: read the error, fix the code or the test, retry (max 3 times)
- If a dependency is missing: install it
- If a build fails: check config, fix, retry
- If stuck on a task for 3+ retries: log it as a blocker, skip, continue
- NEVER stop working unless you output <promise>$COMPLETION_PROMISE</promise>

## Current State
Check AUTO_BUILD_STATE.json for progress. If it doesn't exist, start from Phase 1."

# ======================== RATE LIMITING ========================

RATE_LIMIT_CALLS=0
RATE_LIMIT_HOUR=$(date +%H)
RATE_LIMIT_MAX=95  # Leave buffer under API limits

check_rate_limit() {
    CURRENT_HOUR=$(date +%H)
    if [ "$CURRENT_HOUR" != "$RATE_LIMIT_HOUR" ]; then
        RATE_LIMIT_CALLS=0
        RATE_LIMIT_HOUR=$CURRENT_HOUR
    fi
    
    RATE_LIMIT_CALLS=$((RATE_LIMIT_CALLS + 1))
    
    if [ "$RATE_LIMIT_CALLS" -ge "$RATE_LIMIT_MAX" ]; then
        echo -e "${YELLOW}⏳ Rate limit approaching. Cooling down for 60 seconds...${NC}"
        sleep 60
        RATE_LIMIT_CALLS=0
    fi
}

# ======================== CIRCUIT BREAKER ========================

CONSECUTIVE_ERRORS=0
MAX_CONSECUTIVE_ERRORS=5
ITERATION_TIMEOUT=1800  # 30 minutes per iteration
LAST_PROGRESS=0
STALL_COUNT=0
MAX_STALL_COUNT=3  # Max iterations with no progress change

check_circuit_breaker() {
    if [ "$CONSECUTIVE_ERRORS" -ge "$MAX_CONSECUTIVE_ERRORS" ]; then
        echo -e "${RED}CIRCUIT BREAKER TRIGGERED: $MAX_CONSECUTIVE_ERRORS consecutive errors${NC}"
        echo -e "${RED}   Stopping to prevent runaway costs.${NC}"
        echo -e "${YELLOW}   Check logs in $LOG_DIR for details.${NC}"
        generate_final_report "circuit_breaker"
        exit 1
    fi
}

# Detect if build is making progress or stuck in a loop
check_stall_detection() {
    if [ -f "$STATE_FILE" ]; then
        CURRENT_PROGRESS=$(jq -r '.completion_percentage // 0' "$STATE_FILE" 2>/dev/null || echo "0")
        if [ "$CURRENT_PROGRESS" = "$LAST_PROGRESS" ]; then
            STALL_COUNT=$((STALL_COUNT + 1))
            if [ "$STALL_COUNT" -ge "$MAX_STALL_COUNT" ]; then
                echo -e "${YELLOW}STALL DETECTED: No progress for $MAX_STALL_COUNT iterations (stuck at ${CURRENT_PROGRESS}%)${NC}"
                echo -e "${YELLOW}   Injecting recovery hint into next prompt...${NC}"
                # Reset stall counter but add recovery context to prompt
                STALL_COUNT=0
                BUILD_PROMPT="${BUILD_PROMPT}

## STALL RECOVERY
Progress has been stuck at ${CURRENT_PROGRESS}% for multiple iterations. You may be in a loop.
- Read AUTO_BUILD_STATE.json event_log to see what you tried before
- Try a DIFFERENT approach than your last attempt
- If a task is blocking, skip it (add to blockers) and move to the next phase
- Run: bash ${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/scripts/recover-state.sh to check state integrity"
            fi
        else
            STALL_COUNT=0
            LAST_PROGRESS="$CURRENT_PROGRESS"
        fi
    fi
}

# ======================== MONITORING ========================

print_status() {
    local elapsed=$(($(date +%s) - START_TIME))
    local hours=$((elapsed / 3600))
    local minutes=$(((elapsed % 3600) / 60))
    local seconds=$((elapsed % 60))
    
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
    echo -e "${CYAN}  Iteration:  ${YELLOW}$ITERATION / $MAX_ITERATIONS${NC}"
    echo -e "${CYAN}  Elapsed:    ${NC}${hours}h ${minutes}m ${seconds}s"
    echo -e "${CYAN}  Errors:     ${NC}${CONSECUTIVE_ERRORS} consecutive"
    
    if [ -f "$STATE_FILE" ]; then
        local phase=$(jq -r '.current_phase // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")
        local pct=$(jq -r '.completion_percentage // 0' "$STATE_FILE" 2>/dev/null || echo "0")
        echo -e "${CYAN}  Phase:      ${NC}$phase"
        echo -e "${CYAN}  Progress:   ${GREEN}${pct}%${NC}"
    fi
    
    echo -e "${BLUE}────────────────────────────────────────────${NC}"
}

# ======================== REPORT GENERATOR ========================

generate_final_report() {
    local exit_reason="${1:-unknown}"
    local end_time=$(date +%s)
    local total_seconds=$((end_time - START_TIME))
    local hours=$((total_seconds / 3600))
    local minutes=$(((total_seconds % 3600) / 60))
    
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║              BUILD SESSION COMPLETE                      ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║  Exit Reason:    $exit_reason"
    echo "║  Iterations:     $ITERATION / $MAX_ITERATIONS"
    echo "║  Duration:       ${hours}h ${minutes}m"
    echo "║  Errors:         $CONSECUTIVE_ERRORS consecutive"
    
    if [ -f "$STATE_FILE" ]; then
        local pct=$(jq -r '.completion_percentage // 0' "$STATE_FILE" 2>/dev/null || echo "0")
        echo "║  Progress:       ${pct}%"
    fi
    
    echo "║  Logs:           $LOG_DIR/"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ======================== CLEANUP HANDLER ========================

cleanup() {
    echo ""
    echo -e "${YELLOW}⚠️  Interrupted by user (Ctrl+C)${NC}"
    generate_final_report "user_interrupt"
    exit 0
}

trap cleanup SIGINT SIGTERM

# ======================== MAIN LOOP ========================

echo -e "${GREEN}🚀 Starting autonomous build loop...${NC}"
echo ""

while [ "$ITERATION" -lt "$MAX_ITERATIONS" ]; do
    ITERATION=$((ITERATION + 1))
    LOG_FILE="$LOG_DIR/iteration_$(printf '%03d' $ITERATION).log"
    
    print_status
    echo -e "${GREEN}▶ Starting iteration $ITERATION...${NC}"
    
    # Rate limiting
    check_rate_limit
    
    # Circuit breaker check
    check_circuit_breaker

    # Stall detection — check if progress is advancing
    check_stall_detection

    # Run Claude Code with the build prompt (with per-iteration timeout)
    # Using --print for non-interactive mode, --output-format for parseable output
    set +e
    ITER_START=$(date +%s)
    CLAUDE_OUTPUT=$(timeout "$ITERATION_TIMEOUT" claude --print \
        --allowedTools "Read,Write,Edit,Bash,Glob,Grep,Agent,TodoWrite" \
        --max-turns 200 \
        "$BUILD_PROMPT" 2>&1)
    EXIT_CODE=$?
    ITER_ELAPSED=$(( $(date +%s) - ITER_START ))
    set -e

    # Check if iteration was killed by timeout
    if [ "$EXIT_CODE" -eq 124 ]; then
        echo -e "${YELLOW}  Iteration $ITERATION timed out after ${ITERATION_TIMEOUT}s${NC}"
        echo -e "${YELLOW}  Auto-committing progress and continuing...${NC}"
        if git rev-parse --is-inside-work-tree &>/dev/null; then
            DIRTY=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
            if [ "$DIRTY" -gt 0 ]; then
                git add -A 2>/dev/null
                git commit -m "checkpoint: auto-save after iteration $ITERATION timeout" 2>/dev/null || true
            fi
        fi
    fi
    
    # Log output
    echo "$CLAUDE_OUTPUT" > "$LOG_FILE"
    echo "Exit code: $EXIT_CODE" >> "$LOG_FILE"

    # Append event to state file event_log
    if [ -f "$STATE_FILE" ]; then
        PHASE=$(jq -r '.current_phase // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")
        PCT=$(jq -r '.completion_percentage // 0' "$STATE_FILE" 2>/dev/null || echo "0")
        jq --arg ts "$(date -Iseconds)" --arg iter "$ITERATION" --arg ec "$EXIT_CODE" --arg phase "$PHASE" --arg pct "$PCT" \
            '.event_log = (.event_log // []) + [{"event": "iteration_complete", "timestamp": $ts, "iteration": ($iter | tonumber), "exit_code": ($ec | tonumber), "phase": $phase, "completion": $pct}]' \
            "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi

    # Check for completion promise
    if echo "$CLAUDE_OUTPUT" | grep -q "<promise>$COMPLETION_PROMISE</promise>"; then
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                                                          ║${NC}"
        echo -e "${GREEN}║   🎉 PRODUCT COMPLETE!                                   ║${NC}"
        echo -e "${GREEN}║                                                          ║${NC}"
        echo -e "${GREEN}║   The autonomous builder has finished.                    ║${NC}"
        echo -e "${GREEN}║   Your product is ready for review.                       ║${NC}"
        echo -e "${GREEN}║                                                          ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        generate_final_report "product_complete"
        
        # Final git tag
        git tag -a "v1.0.0-auto-build" -m "Autonomous build complete - $(date)" 2>/dev/null || true
        
        exit 0
    fi
    
    # Check for errors
    if [ "$EXIT_CODE" -ne 0 ]; then
        CONSECUTIVE_ERRORS=$((CONSECUTIVE_ERRORS + 1))
        echo -e "${RED}  ❌ Iteration $ITERATION failed (exit code: $EXIT_CODE)${NC}"
        echo -e "${YELLOW}  Consecutive errors: $CONSECUTIVE_ERRORS / $MAX_CONSECUTIVE_ERRORS${NC}"
        
        # Exponential backoff on errors
        BACKOFF=$((CONSECUTIVE_ERRORS * 10))
        echo -e "${YELLOW}  Waiting ${BACKOFF}s before retry...${NC}"
        sleep "$BACKOFF"
    else
        CONSECUTIVE_ERRORS=0
        echo -e "${GREEN}  ✅ Iteration $ITERATION completed successfully${NC}"
    fi
    
    # Brief pause between iterations
    sleep 2
    
done

# Max iterations reached
echo ""
echo -e "${YELLOW}⚠️  Max iterations ($MAX_ITERATIONS) reached without completion.${NC}"
generate_final_report "max_iterations_reached"
exit 1
