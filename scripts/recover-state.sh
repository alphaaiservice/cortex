#!/bin/bash
#====================================================================
# Cortex — Build State Recovery
#
# Reconstructs AUTO_BUILD_STATE.json from git history and backups
# when the state file is missing or corrupted after a crash.
#
# Usage:
#   ./recover-state.sh              # Auto-recover from best source
#   ./recover-state.sh --from-git   # Force recovery from git commits
#   ./recover-state.sh --from-backup # Force recovery from backup dir
#
# Author: Alpha AI Service Pvt Ltd
#====================================================================

set -euo pipefail

STATE_FILE="AUTO_BUILD_STATE.json"
BACKUP_DIR=".cortex/state-backups"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

MODE="${1:-auto}"

echo -e "${CYAN}Cortex — Build State Recovery${NC}"
echo ""

# ======================== RECOVERY FROM BACKUPS ========================

recover_from_backup() {
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED}No backup directory found at $BACKUP_DIR${NC}"
        return 1
    fi

    LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*.json 2>/dev/null | head -1)
    if [ -z "$LATEST_BACKUP" ]; then
        echo -e "${RED}No backup files found in $BACKUP_DIR${NC}"
        return 1
    fi

    # Validate JSON
    if ! jq empty "$LATEST_BACKUP" 2>/dev/null; then
        echo -e "${RED}Latest backup is corrupted: $LATEST_BACKUP${NC}"
        return 1
    fi

    cp "$LATEST_BACKUP" "$STATE_FILE"
    PHASE=$(jq -r '.current_phase // "unknown"' "$STATE_FILE" 2>/dev/null)
    PCT=$(jq -r '.completion_percentage // 0' "$STATE_FILE" 2>/dev/null)
    echo -e "${GREEN}Recovered from backup: $LATEST_BACKUP${NC}"
    echo -e "  Phase: ${PHASE} | Progress: ${PCT}%"

    # Add recovery event to log
    jq --arg ts "$(date -Iseconds)" --arg src "$LATEST_BACKUP" \
        '.event_log = (.event_log // []) + [{"event": "state_recovered", "timestamp": $ts, "source": $src}]' \
        "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

    return 0
}

# ======================== RECOVERY FROM GIT ========================

recover_from_git() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo -e "${RED}Not a git repository${NC}"
        return 1
    fi

    # Find the latest checkpoint commit
    CHECKPOINT_COMMIT=$(git log --oneline --grep="checkpoint(phase-" -1 --format="%H" 2>/dev/null)
    FEAT_COMMIT=$(git log --oneline --grep="feat(phase-" -1 --format="%H" 2>/dev/null)

    # Use whichever is more recent
    RECOVERY_COMMIT=""
    if [ -n "$CHECKPOINT_COMMIT" ] && [ -n "$FEAT_COMMIT" ]; then
        if git merge-base --is-ancestor "$FEAT_COMMIT" "$CHECKPOINT_COMMIT" 2>/dev/null; then
            RECOVERY_COMMIT="$CHECKPOINT_COMMIT"
        else
            RECOVERY_COMMIT="$FEAT_COMMIT"
        fi
    elif [ -n "$CHECKPOINT_COMMIT" ]; then
        RECOVERY_COMMIT="$CHECKPOINT_COMMIT"
    elif [ -n "$FEAT_COMMIT" ]; then
        RECOVERY_COMMIT="$FEAT_COMMIT"
    fi

    if [ -z "$RECOVERY_COMMIT" ]; then
        echo -e "${RED}No auto-build commits found in git history${NC}"
        return 1
    fi

    # Try to extract state file from that commit
    if git show "${RECOVERY_COMMIT}:AUTO_BUILD_STATE.json" > "$STATE_FILE" 2>/dev/null; then
        PHASE=$(jq -r '.current_phase // "unknown"' "$STATE_FILE" 2>/dev/null)
        PCT=$(jq -r '.completion_percentage // 0' "$STATE_FILE" 2>/dev/null)
        COMMIT_MSG=$(git log --oneline -1 "$RECOVERY_COMMIT" 2>/dev/null)
        echo -e "${GREEN}Recovered from git commit: $COMMIT_MSG${NC}"
        echo -e "  Phase: ${PHASE} | Progress: ${PCT}%"

        jq --arg ts "$(date -Iseconds)" --arg src "git:$RECOVERY_COMMIT" \
            '.event_log = (.event_log // []) + [{"event": "state_recovered", "timestamp": $ts, "source": $src}]' \
            "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
        return 0
    fi

    # State file wasn't in that commit — reconstruct from commit messages
    echo -e "${YELLOW}State file not found in commit. Reconstructing from git log...${NC}"

    # Count completed phases from commit messages
    COMPLETED_PHASES=$(git log --oneline --grep="feat(phase-" --format="%s" 2>/dev/null | grep -oP "phase-\K[0-9]+" | sort -n | tail -1 || echo "0")
    CHECKPOINT_PHASES=$(git log --oneline --grep="checkpoint(phase-" --format="%s" 2>/dev/null | grep -oP "phase-\K[^)]*" | tail -1 || echo "")

    LAST_PHASE="${CHECKPOINT_PHASES:-$COMPLETED_PHASES}"
    if [ -z "$LAST_PHASE" ] || [ "$LAST_PHASE" = "0" ]; then
        echo -e "${RED}Cannot determine build phase from git history${NC}"
        return 1
    fi

    # Estimate completion (15 phases total)
    ESTIMATED_PCT=$(( (LAST_PHASE * 100) / 15 ))
    if [ "$ESTIMATED_PCT" -gt 100 ]; then ESTIMATED_PCT=95; fi

    # Build a minimal state file
    cat > "$STATE_FILE" <<EOSTATE
{
  "build_status": "in_progress",
  "current_phase": "phase-${LAST_PHASE}",
  "completion_percentage": ${ESTIMATED_PCT},
  "build_mode": "sequential",
  "last_updated": "$(date -Iseconds)",
  "recovered": true,
  "recovery_source": "git_log_reconstruction",
  "event_log": [
    {"event": "state_reconstructed", "timestamp": "$(date -Iseconds)", "source": "git_log", "last_phase_found": "${LAST_PHASE}"}
  ]
}
EOSTATE

    echo -e "${GREEN}Reconstructed state from git log${NC}"
    echo -e "  Last phase found: ${LAST_PHASE} | Estimated progress: ${ESTIMATED_PCT}%"
    echo -e "${YELLOW}  Note: This is an estimate. Run /resume-build to verify and continue.${NC}"
    return 0
}

# ======================== AUTO RECOVERY ========================

auto_recover() {
    # Priority 1: Backup directory (most recent, most accurate)
    if recover_from_backup 2>/dev/null; then
        return 0
    fi

    # Priority 2: Git history
    if recover_from_git 2>/dev/null; then
        return 0
    fi

    # Priority 3: Check for PRD to suggest fresh start
    echo -e "${RED}Could not recover build state from any source.${NC}"
    echo ""
    if [ -f "PRD.md" ]; then
        echo -e "${YELLOW}PRD.md found. Run /auto-build ./PRD.md to start a fresh build.${NC}"
    else
        echo -e "${YELLOW}Run /gen-prd 'your idea' to start from scratch.${NC}"
    fi
    return 1
}

# ======================== MAIN ========================

case "$MODE" in
    --from-backup)
        recover_from_backup
        ;;
    --from-git)
        recover_from_git
        ;;
    auto|*)
        # Check if state file already exists and is valid
        if [ -f "$STATE_FILE" ] && jq empty "$STATE_FILE" 2>/dev/null; then
            PHASE=$(jq -r '.current_phase // "unknown"' "$STATE_FILE" 2>/dev/null)
            PCT=$(jq -r '.completion_percentage // 0' "$STATE_FILE" 2>/dev/null)
            echo -e "${GREEN}State file exists and is valid.${NC}"
            echo -e "  Phase: ${PHASE} | Progress: ${PCT}%"
            echo -e "  Run /resume-build to continue."
        else
            echo -e "${YELLOW}State file missing or corrupted. Attempting recovery...${NC}"
            echo ""
            auto_recover
        fi
        ;;
esac
