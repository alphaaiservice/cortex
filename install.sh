#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║  AlphaForge — Installation Script                                 ║
# ║  By Alpha AI Service Pvt Ltd                                     ║
# ║                                                                   ║
# ║  Usage:                                                           ║
# ║    ./install.sh              # Interactive install                ║
# ║    ./install.sh --global     # Install globally for all sessions  ║
# ║    ./install.sh --link       # Symlink (dev mode)                 ║
# ║    ./install.sh --agent-teams # Also enable Agent Teams           ║
# ║    ./install.sh --uninstall  # Remove the plugin                  ║
# ║    ./install.sh --status     # Check installation status          ║
# ╚══════════════════════════════════════════════════════════════════╝
#
set -euo pipefail

# ─────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────
PLUGIN_NAME="alpha-forge"
PLUGIN_VERSION="1.0.0"
PLUGIN_AUTHOR="Alpha AI Service Pvt Ltd"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
CLAUDE_PLUGINS_DIR="$CLAUDE_DIR/plugins"
INSTALL_DIR="$CLAUDE_PLUGINS_DIR/$PLUGIN_NAME"

# Colors (support --no-color)
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    DIM='\033[2m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE='' DIM='' BOLD='' NC=''
fi

# ─────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step()    { echo -e "\n${CYAN}${BOLD}$*${NC}"; }
dim()     { echo -e "${DIM}$*${NC}"; }

banner() {
    echo -e "${MAGENTA}"
    cat << 'BANNER'

     _    _       _              ____             ___
    / \  | |_ __ | |__   __ _  |  _ \  _____   _/ _ \ _ __  ___
   / _ \ | | '_ \| '_ \ / _` | | | | |/ _ \ \ / / | | | '_ \/ __|
  / ___ \| | |_) | | | | (_| | | |_| |  __/\ V /| |_| | |_) \__ \
 /_/   \_\_| .__/|_| |_|\__,_| |____/ \___| \_/  \___/| .__/|___/
            |_|                                         |_|

BANNER
    echo -e "${NC}"
    echo -e "  ${WHITE}${BOLD}AlphaForge — SDLC Automation Engine${NC}"
    echo -e "  ${DIM}v${PLUGIN_VERSION} by ${PLUGIN_AUTHOR}${NC}"
    echo ""
    echo -e "  ${DIM}37 Commands | 11 Agents | 9 Skills | 6 Hooks${NC}"
    echo ""
}

separator() {
    echo -e "${DIM}$(printf '%.0s─' {1..60})${NC}"
}

# ─────────────────────────────────────────────────
# Prerequisite Checks
# ─────────────────────────────────────────────────
check_os() {
    local os
    os="$(uname -s)"
    case "$os" in
        Darwin) info "Platform: macOS ($(uname -m))" ;;
        Linux)  info "Platform: Linux ($(uname -m))" ;;
        MINGW*|MSYS*|CYGWIN*)
            warn "Windows detected. WSL2 is recommended for best experience."
            info "Platform: Windows ($os)"
            ;;
        *)
            error "Unsupported OS: $os"
            error "Supported: macOS, Linux, WSL2"
            exit 1
            ;;
    esac
}

check_shell() {
    local current_shell
    current_shell="$(basename "${SHELL:-/bin/bash}")"
    info "Shell: $current_shell"

    case "$current_shell" in
        zsh)  SHELL_RC="$HOME/.zshrc" ;;
        bash) SHELL_RC="$HOME/.bashrc" ;;
        fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
        *)    SHELL_RC="$HOME/.profile"; warn "Unknown shell '$current_shell', using ~/.profile" ;;
    esac
}

check_claude_cli() {
    if command -v claude &>/dev/null; then
        local version
        version="$(claude --version 2>/dev/null || echo 'unknown')"
        success "Claude Code CLI found: $version"
        return 0
    else
        error "Claude Code CLI not found."
        echo ""
        echo "  Install Claude Code:"
        echo "    npm install -g @anthropic-ai/claude-code"
        echo ""
        echo "  Then authenticate:"
        echo "    claude login"
        echo ""
        return 1
    fi
}

check_jq() {
    if command -v jq &>/dev/null; then
        return 0
    else
        warn "jq not found. Installing..."
        if command -v brew &>/dev/null; then
            brew install jq 2>/dev/null || true
        elif command -v apt-get &>/dev/null; then
            sudo apt-get install -y jq 2>/dev/null || true
        elif command -v yum &>/dev/null; then
            sudo yum install -y jq 2>/dev/null || true
        fi

        if command -v jq &>/dev/null; then
            success "jq installed"
            return 0
        else
            warn "Could not install jq automatically. Some features may be limited."
            warn "Install manually: https://stedolan.github.io/jq/download/"
            return 1
        fi
    fi
}

check_git() {
    if command -v git &>/dev/null; then
        return 0
    else
        warn "git not found. Some plugin features require git."
        return 1
    fi
}

check_plugin_files() {
    local missing=0

    if [[ ! -f "$SCRIPT_DIR/.claude-plugin/plugin.json" ]]; then
        error "Missing: .claude-plugin/plugin.json"
        missing=1
    fi

    if [[ ! -d "$SCRIPT_DIR/commands" ]]; then
        error "Missing: commands/ directory"
        missing=1
    fi

    if [[ ! -d "$SCRIPT_DIR/agents" ]]; then
        error "Missing: agents/ directory"
        missing=1
    fi

    if [[ ! -d "$SCRIPT_DIR/skills" ]]; then
        error "Missing: skills/ directory"
        missing=1
    fi

    if [[ ! -f "$SCRIPT_DIR/hooks/hooks.json" ]]; then
        error "Missing: hooks/hooks.json"
        missing=1
    fi

    if [[ $missing -eq 1 ]]; then
        error "Plugin files incomplete. Make sure you're running install.sh from the plugin root."
        exit 1
    fi

    success "Plugin files verified"
}

# ─────────────────────────────────────────────────
# Count Plugin Components
# ─────────────────────────────────────────────────
count_components() {
    local commands agents skills hooks total_lines

    commands=$(find "$SCRIPT_DIR/commands" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    agents=$(find "$SCRIPT_DIR/agents" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    skills=$(find "$SCRIPT_DIR/skills" -name "SKILL.md" -type f 2>/dev/null | wc -l | tr -d ' ')

    if command -v jq &>/dev/null && [[ -f "$SCRIPT_DIR/hooks/hooks.json" ]]; then
        hooks=$(jq '.hooks | keys | length' "$SCRIPT_DIR/hooks/hooks.json" 2>/dev/null || echo "?")
    else
        hooks="?"
    fi

    total_lines=$(find "$SCRIPT_DIR" -name "*.md" -o -name "*.sh" -o -name "*.json" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')

    echo ""
    echo -e "  ${WHITE}Plugin Components:${NC}"
    echo -e "    Commands:     ${GREEN}$commands${NC} slash commands"
    echo -e "    Agents:       ${GREEN}$agents${NC} specialized subagents"
    echo -e "    Skills:       ${GREEN}$skills${NC} auto-invoked skills"
    echo -e "    Hook Events:  ${GREEN}$hooks${NC} event-driven automations"
    echo -e "    Total Lines:  ${DIM}${total_lines:-?} lines of AI instructions${NC}"
    echo ""
}

# ─────────────────────────────────────────────────
# Installation Methods
# ─────────────────────────────────────────────────
make_scripts_executable() {
    step "Making scripts executable..."
    local count=0
    for script in "$SCRIPT_DIR"/scripts/*.sh; do
        if [[ -f "$script" ]]; then
            chmod +x "$script"
            count=$((count + 1))
            dim "  chmod +x $(basename "$script")"
        fi
    done
    chmod +x "$SCRIPT_DIR/install.sh" 2>/dev/null || true
    success "$count scripts made executable"
}

validate_hooks_json() {
    if command -v jq &>/dev/null; then
        if jq empty "$SCRIPT_DIR/hooks/hooks.json" 2>/dev/null; then
            success "hooks.json is valid JSON"
        else
            error "hooks.json is invalid JSON. Hooks may not load correctly."
            return 1
        fi
    fi
}

install_copy() {
    step "Installing plugin to $INSTALL_DIR..."

    mkdir -p "$CLAUDE_PLUGINS_DIR"

    if [[ -d "$INSTALL_DIR" ]]; then
        warn "Existing installation found at $INSTALL_DIR"
        read -rp "  Overwrite? [y/N] " answer
        case "$answer" in
            [yY]|[yY][eE][sS])
                rm -rf "$INSTALL_DIR"
                info "Removed old installation"
                ;;
            *)
                error "Installation cancelled."
                exit 0
                ;;
        esac
    fi

    # Copy all plugin files
    cp -R "$SCRIPT_DIR" "$INSTALL_DIR"

    # Remove install script and git files from the installed copy
    rm -f "$INSTALL_DIR/install.sh"
    rm -rf "$INSTALL_DIR/.git" "$INSTALL_DIR/.gitignore"

    success "Plugin copied to $INSTALL_DIR"
}

install_symlink() {
    step "Creating symlink (development mode)..."

    mkdir -p "$CLAUDE_PLUGINS_DIR"

    if [[ -e "$INSTALL_DIR" ]]; then
        if [[ -L "$INSTALL_DIR" ]]; then
            rm "$INSTALL_DIR"
            info "Removed old symlink"
        else
            warn "Existing non-symlink installation at $INSTALL_DIR"
            read -rp "  Replace with symlink? [y/N] " answer
            case "$answer" in
                [yY]|[yY][eE][sS])
                    rm -rf "$INSTALL_DIR"
                    ;;
                *)
                    error "Installation cancelled."
                    exit 0
                    ;;
            esac
        fi
    fi

    ln -s "$SCRIPT_DIR" "$INSTALL_DIR"
    success "Symlinked: $INSTALL_DIR -> $SCRIPT_DIR"
    info "Changes to plugin source will take effect immediately"
}

# ─────────────────────────────────────────────────
# Configure Claude Code Settings
# ─────────────────────────────────────────────────
configure_settings() {
    local enable_agent_teams="${1:-false}"

    step "Configuring Claude Code settings..."

    mkdir -p "$CLAUDE_DIR"

    # Create settings.json if it doesn't exist
    if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
        echo '{}' > "$CLAUDE_SETTINGS"
        info "Created $CLAUDE_SETTINGS"
    fi

    if ! command -v jq &>/dev/null; then
        warn "jq not available. Skipping automatic settings configuration."
        echo ""
        echo "  Please manually add this to $CLAUDE_SETTINGS:"
        echo ""
        echo '  {'
        echo '    "plugins": {'
        echo '      "directories": ['
        echo "        \"$INSTALL_DIR\""
        echo '      ]'
        echo '    }'
        echo '  }'
        echo ""
        return
    fi

    # Backup existing settings
    cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.backup.$(date +%s)" 2>/dev/null || true

    # Add plugin directory to settings
    local temp_file
    temp_file=$(mktemp)

    # Ensure plugins.directories exists and add our directory
    jq --arg dir "$INSTALL_DIR" '
        .plugins //= {} |
        .plugins.directories //= [] |
        if (.plugins.directories | index($dir)) then .
        else .plugins.directories += [$dir]
        end
    ' "$CLAUDE_SETTINGS" > "$temp_file" 2>/dev/null

    if [[ $? -eq 0 ]] && jq empty "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$CLAUDE_SETTINGS"
        success "Plugin directory registered in settings.json"
    else
        rm -f "$temp_file"
        warn "Could not update settings.json automatically."
        echo "  Add manually: \"plugins.directories\": [\"$INSTALL_DIR\"]"
    fi

    # Enable Agent Teams if requested
    if [[ "$enable_agent_teams" == "true" ]]; then
        configure_agent_teams
    fi
}

configure_agent_teams() {
    step "Enabling Agent Teams (experimental)..."

    if ! command -v jq &>/dev/null; then
        warn "jq not available. Manually set in $CLAUDE_SETTINGS:"
        echo '  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }'
        return
    fi

    local temp_file
    temp_file=$(mktemp)

    jq '.env //= {} | .env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"' \
        "$CLAUDE_SETTINGS" > "$temp_file" 2>/dev/null

    if [[ $? -eq 0 ]] && jq empty "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$CLAUDE_SETTINGS"
        success "Agent Teams enabled (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)"
        info "Features unlocked:"
        info "  - Parallel Builder: real teammate sessions"
        info "  - Code Review: adversarial debate mode"
        info "  - Debug: competing hypothesis mode"
        info "  - Auto-Build: overlapping phase execution"
    else
        rm -f "$temp_file"
        warn "Could not enable Agent Teams automatically."
    fi
}

# ─────────────────────────────────────────────────
# Shell Alias Setup
# ─────────────────────────────────────────────────
setup_shell_alias() {
    local install_path="$1"

    step "Setting up shell alias..."

    local alias_line
    local shell_name
    shell_name="$(basename "${SHELL:-/bin/bash}")"

    if [[ "$shell_name" == "fish" ]]; then
        alias_line="alias alphaforge='claude --plugin-dir $install_path'"
        local fish_config="$HOME/.config/fish/config.fish"
        if [[ -f "$fish_config" ]] && grep -q "alphaforge" "$fish_config" 2>/dev/null; then
            info "Alias 'alphaforge' already exists in fish config"
            return
        fi
    else
        alias_line="alias alphaforge='claude --plugin-dir $install_path'"
        if [[ -f "$SHELL_RC" ]] && grep -q "alphaforge" "$SHELL_RC" 2>/dev/null; then
            info "Alias 'alphaforge' already exists in $SHELL_RC"
            return
        fi
    fi

    echo ""
    echo -e "  ${WHITE}Add a shell alias for quick access?${NC}"
    echo ""
    echo -e "  This adds to ${CYAN}$SHELL_RC${NC}:"
    echo -e "    ${DIM}$alias_line${NC}"
    echo ""
    read -rp "  Add alias? [Y/n] " answer

    case "$answer" in
        ""|[yY]|[yY][eE][sS])
            echo "" >> "$SHELL_RC"
            echo "# AlphaForge — Claude Code" >> "$SHELL_RC"
            echo "$alias_line" >> "$SHELL_RC"
            success "Alias added to $SHELL_RC"
            info "Run 'source $SHELL_RC' or restart your terminal to use it"
            info "Then just type: ${GREEN}alphaforge${NC}"
            ;;
        *)
            info "Skipped alias setup."
            dim "  You can always run: claude --plugin-dir $install_path"
            ;;
    esac
}

# ─────────────────────────────────────────────────
# Verification
# ─────────────────────────────────────────────────
verify_installation() {
    local install_path="$1"

    step "Verifying installation..."

    local errors=0

    # Check plugin.json exists
    if [[ -f "$install_path/.claude-plugin/plugin.json" ]]; then
        success "plugin.json found"
    else
        error "plugin.json not found at $install_path/.claude-plugin/"
        errors=$((errors + 1))
    fi

    # Count and verify commands
    local cmd_count
    cmd_count=$(find "$install_path/commands" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ $cmd_count -ge 30 ]]; then
        success "Commands: $cmd_count found"
    else
        warn "Commands: only $cmd_count found (expected 36+)"
    fi

    # Count and verify agents
    local agent_count
    agent_count=$(find "$install_path/agents" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ $agent_count -ge 8 ]]; then
        success "Agents: $agent_count found"
    else
        warn "Agents: only $agent_count found (expected 10+)"
    fi

    # Count and verify skills
    local skill_count
    skill_count=$(find "$install_path/skills" -name "SKILL.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ $skill_count -ge 7 ]]; then
        success "Skills: $skill_count found"
    else
        warn "Skills: only $skill_count found (expected 9+)"
    fi

    # Verify hooks.json
    if [[ -f "$install_path/hooks/hooks.json" ]]; then
        if command -v jq &>/dev/null && jq empty "$install_path/hooks/hooks.json" 2>/dev/null; then
            local hook_count
            hook_count=$(jq '.hooks | keys | length' "$install_path/hooks/hooks.json" 2>/dev/null || echo "?")
            success "Hooks: $hook_count events (valid JSON)"
        else
            warn "hooks.json exists but could not validate"
        fi
    else
        error "hooks.json not found"
        errors=$((errors + 1))
    fi

    # Verify scripts are executable
    local non_exec=0
    for script in "$install_path"/scripts/*.sh; do
        if [[ -f "$script" ]] && [[ ! -x "$script" ]]; then
            non_exec=$((non_exec + 1))
        fi
    done
    if [[ $non_exec -eq 0 ]]; then
        success "All scripts are executable"
    else
        warn "$non_exec scripts are not executable"
    fi

    # Check settings.json
    if [[ -f "$CLAUDE_SETTINGS" ]] && command -v jq &>/dev/null; then
        if jq -e ".plugins.directories[]? | select(. == \"$install_path\")" "$CLAUDE_SETTINGS" &>/dev/null; then
            success "Plugin registered in settings.json"
        else
            warn "Plugin not yet registered in settings.json"
        fi
    fi

    # Check Agent Teams
    if [[ -f "$CLAUDE_SETTINGS" ]] && command -v jq &>/dev/null; then
        local at_enabled
        at_enabled=$(jq -r '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS // "0"' "$CLAUDE_SETTINGS" 2>/dev/null)
        if [[ "$at_enabled" == "1" ]]; then
            success "Agent Teams: ENABLED"
        else
            dim "  Agent Teams: not enabled (use --agent-teams to enable)"
        fi
    fi

    echo ""
    if [[ $errors -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}Installation verified successfully!${NC}"
    else
        echo -e "  ${RED}${BOLD}Installation has $errors error(s). Check the output above.${NC}"
    fi

    return $errors
}

# ─────────────────────────────────────────────────
# Status Check
# ─────────────────────────────────────────────────
check_status() {
    banner
    step "Installation Status"

    # Check if installed at standard location
    if [[ -d "$INSTALL_DIR" ]]; then
        if [[ -L "$INSTALL_DIR" ]]; then
            local target
            target=$(readlink "$INSTALL_DIR" 2>/dev/null || echo "unknown")
            success "Installed (symlink): $INSTALL_DIR -> $target"
        else
            success "Installed (copy): $INSTALL_DIR"
        fi
        verify_installation "$INSTALL_DIR"
    else
        warn "Not installed at standard location ($INSTALL_DIR)"
        echo ""
        echo "  You may be using --plugin-dir mode."
        echo "  Run: claude --plugin-dir $SCRIPT_DIR"
    fi

    # Check settings
    if [[ -f "$CLAUDE_SETTINGS" ]] && command -v jq &>/dev/null; then
        echo ""
        step "Settings"
        local dirs
        dirs=$(jq -r '.plugins.directories[]? // empty' "$CLAUDE_SETTINGS" 2>/dev/null)
        if [[ -n "$dirs" ]]; then
            info "Registered plugin directories:"
            echo "$dirs" | while read -r d; do
                if [[ -d "$d" ]]; then
                    echo -e "    ${GREEN}$d${NC}"
                else
                    echo -e "    ${RED}$d (NOT FOUND)${NC}"
                fi
            done
        fi

        local at_enabled
        at_enabled=$(jq -r '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS // "0"' "$CLAUDE_SETTINGS" 2>/dev/null)
        if [[ "$at_enabled" == "1" ]]; then
            success "Agent Teams: ENABLED"
        else
            info "Agent Teams: disabled"
        fi
    fi

    # Check shell alias
    echo ""
    step "Shell Alias"
    if grep -q "alphaforge" "$SHELL_RC" 2>/dev/null; then
        success "Alias 'alphaforge' found in $SHELL_RC"
    else
        dim "  No 'alphaforge' alias found"
    fi

    exit 0
}

# ─────────────────────────────────────────────────
# Uninstall
# ─────────────────────────────────────────────────
uninstall() {
    banner
    step "Uninstalling AlphaForge"
    echo ""

    local removed=0

    # Remove installed directory
    if [[ -d "$INSTALL_DIR" ]] || [[ -L "$INSTALL_DIR" ]]; then
        echo -e "  Found: ${CYAN}$INSTALL_DIR${NC}"
        read -rp "  Remove? [y/N] " answer
        case "$answer" in
            [yY]|[yY][eE][sS])
                rm -rf "$INSTALL_DIR"
                success "Removed $INSTALL_DIR"
                removed=1
                ;;
            *)
                info "Kept $INSTALL_DIR"
                ;;
        esac
    else
        info "No installation found at $INSTALL_DIR"
    fi

    # Remove from settings.json
    if [[ -f "$CLAUDE_SETTINGS" ]] && command -v jq &>/dev/null; then
        if jq -e ".plugins.directories[]? | select(. == \"$INSTALL_DIR\")" "$CLAUDE_SETTINGS" &>/dev/null; then
            echo ""
            read -rp "  Remove from settings.json? [y/N] " answer
            case "$answer" in
                [yY]|[yY][eE][sS])
                    local temp_file
                    temp_file=$(mktemp)
                    jq --arg dir "$INSTALL_DIR" '
                        .plugins.directories = [.plugins.directories[]? | select(. != $dir)]
                    ' "$CLAUDE_SETTINGS" > "$temp_file" 2>/dev/null
                    if jq empty "$temp_file" 2>/dev/null; then
                        mv "$temp_file" "$CLAUDE_SETTINGS"
                        success "Removed from settings.json"
                    else
                        rm -f "$temp_file"
                        warn "Could not update settings.json"
                    fi
                    ;;
            esac
        fi

        # Optionally disable Agent Teams
        local at_enabled
        at_enabled=$(jq -r '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS // "0"' "$CLAUDE_SETTINGS" 2>/dev/null)
        if [[ "$at_enabled" == "1" ]]; then
            echo ""
            read -rp "  Disable Agent Teams? [y/N] " answer
            case "$answer" in
                [yY]|[yY][eE][sS])
                    local temp_file
                    temp_file=$(mktemp)
                    jq 'del(.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS)' "$CLAUDE_SETTINGS" > "$temp_file" 2>/dev/null
                    if jq empty "$temp_file" 2>/dev/null; then
                        mv "$temp_file" "$CLAUDE_SETTINGS"
                        success "Agent Teams disabled"
                    else
                        rm -f "$temp_file"
                    fi
                    ;;
            esac
        fi
    fi

    # Remove shell alias
    if [[ -f "$SHELL_RC" ]] && grep -q "alphaforge" "$SHELL_RC" 2>/dev/null; then
        echo ""
        read -rp "  Remove 'alphaforge' alias from $SHELL_RC? [y/N] " answer
        case "$answer" in
            [yY]|[yY][eE][sS])
                # Remove the alias and the comment line before it
                local temp_file
                temp_file=$(mktemp)
                grep -v "alphaforge\|# AlphaForge" "$SHELL_RC" > "$temp_file"
                mv "$temp_file" "$SHELL_RC"
                success "Alias removed from $SHELL_RC"
                ;;
        esac
    fi

    echo ""
    separator
    if [[ $removed -eq 1 ]]; then
        echo -e "\n  ${GREEN}${BOLD}AlphaForge uninstalled.${NC}"
    else
        echo -e "\n  ${YELLOW}Uninstall completed (some items may have been kept).${NC}"
    fi
    echo -e "  ${DIM}Restart Claude Code for changes to take effect.${NC}\n"
    exit 0
}

# ─────────────────────────────────────────────────
# Interactive Install Mode Selection
# ─────────────────────────────────────────────────
prompt_install_mode() {
    echo -e "  ${WHITE}${BOLD}Choose installation method:${NC}"
    echo ""
    echo -e "    ${GREEN}1)${NC} Global Install ${DIM}(copy to ~/.claude/plugins/ — persistent across sessions)${NC}"
    echo -e "    ${GREEN}2)${NC} Symlink Install ${DIM}(dev mode — changes to source take effect immediately)${NC}"
    echo -e "    ${GREEN}3)${NC} Plugin Dir Only ${DIM}(just set up scripts — use with --plugin-dir flag)${NC}"
    echo ""
    read -rp "  Select [1/2/3]: " choice

    case "$choice" in
        1) INSTALL_MODE="copy" ;;
        2) INSTALL_MODE="link" ;;
        3) INSTALL_MODE="dir" ;;
        *)
            warn "Invalid choice. Defaulting to Global Install."
            INSTALL_MODE="copy"
            ;;
    esac
}

prompt_agent_teams() {
    echo ""
    echo -e "  ${WHITE}${BOLD}Enable Agent Teams? (experimental)${NC}"
    echo ""
    echo -e "  ${DIM}Agent Teams allows multiple Claude instances to work as a coordinated team${NC}"
    echo -e "  ${DIM}with shared task lists, inter-agent messaging, and quality gate hooks.${NC}"
    echo ""
    echo -e "    ${GREEN}1)${NC} Yes — enable Agent Teams"
    echo -e "    ${GREEN}2)${NC} No  — use standard subagent mode"
    echo ""
    read -rp "  Select [1/2]: " choice

    case "$choice" in
        1) ENABLE_AGENT_TEAMS="true" ;;
        *) ENABLE_AGENT_TEAMS="false" ;;
    esac
}

# ─────────────────────────────────────────────────
# Main Installation Flow
# ─────────────────────────────────────────────────
main() {
    local mode=""
    local agent_teams="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --global)       mode="copy"; shift ;;
            --link|--dev)   mode="link"; shift ;;
            --dir)          mode="dir"; shift ;;
            --agent-teams)  agent_teams="true"; shift ;;
            --uninstall)    check_shell; uninstall ;;
            --status)       check_shell; check_status ;;
            --no-color)     RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE='' DIM='' BOLD='' NC=''; shift ;;
            --help|-h)
                echo "Usage: ./install.sh [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --global        Install globally (copy to ~/.claude/plugins/)"
                echo "  --link, --dev   Symlink install (development mode)"
                echo "  --dir           Just make scripts executable (use with --plugin-dir)"
                echo "  --agent-teams   Enable Agent Teams (experimental feature)"
                echo "  --uninstall     Remove the plugin"
                echo "  --status        Check installation status"
                echo "  --no-color      Disable colored output"
                echo "  -h, --help      Show this help"
                echo ""
                echo "Interactive mode (no flags):"
                echo "  ./install.sh    # Guided installation"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                echo "  Run: ./install.sh --help"
                exit 1
                ;;
        esac
    done

    # Show banner
    banner
    separator

    # Run prerequisite checks
    step "Step 1: Checking Prerequisites"
    check_os
    check_shell
    local has_jq=0; check_jq && has_jq=1 || true
    check_git || true
    local has_claude=0; check_claude_cli && has_claude=1 || true
    check_plugin_files

    if [[ $has_claude -eq 0 ]]; then
        echo ""
        warn "Claude Code CLI not found. The plugin will be installed but won't work until Claude Code is available."
        read -rp "  Continue anyway? [y/N] " answer
        case "$answer" in
            [yY]|[yY][eE][sS]) ;;
            *) exit 0 ;;
        esac
    fi

    # Show component counts
    count_components
    separator

    # Choose install mode
    step "Step 2: Installation Method"

    if [[ -z "$mode" ]]; then
        prompt_install_mode
        mode="$INSTALL_MODE"
    fi

    # Ask about Agent Teams if not specified
    if [[ "$agent_teams" == "false" ]] && [[ "$mode" != "dir" ]]; then
        prompt_agent_teams
        agent_teams="$ENABLE_AGENT_TEAMS"
    fi

    separator

    # Execute installation
    step "Step 3: Installing"

    # Always make scripts executable
    make_scripts_executable

    # Validate hooks
    validate_hooks_json || true

    local final_path

    case "$mode" in
        copy)
            install_copy
            final_path="$INSTALL_DIR"
            configure_settings "$agent_teams"
            ;;
        link)
            install_symlink
            final_path="$INSTALL_DIR"
            configure_settings "$agent_teams"
            ;;
        dir)
            final_path="$SCRIPT_DIR"
            info "Plugin directory mode. Use with:"
            echo -e "    ${GREEN}claude --plugin-dir $SCRIPT_DIR${NC}"
            if [[ "$agent_teams" == "true" ]]; then
                configure_agent_teams
            fi
            ;;
    esac

    separator

    # Set up shell alias
    step "Step 4: Shell Alias"
    setup_shell_alias "$final_path"

    separator

    # Verify
    step "Step 5: Verification"
    verify_installation "$final_path" || true

    separator

    # Final summary
    echo ""
    echo -e "${GREEN}${BOLD}"
    cat << 'DONE'
  ╔══════════════════════════════════════════════════════════╗
  ║  INSTALLATION COMPLETE!                                  ║
  ╚══════════════════════════════════════════════════════════╝
DONE
    echo -e "${NC}"

    case "$mode" in
        copy|link)
            echo -e "  ${WHITE}Start Claude Code with the plugin:${NC}"
            echo ""
            echo -e "    ${GREEN}claude${NC}              ${DIM}# Auto-loads from settings.json${NC}"
            echo -e "    ${GREEN}alphaforge${NC}         ${DIM}# If you added the shell alias${NC}"
            ;;
        dir)
            echo -e "  ${WHITE}Start Claude Code with the plugin:${NC}"
            echo ""
            echo -e "    ${GREEN}claude --plugin-dir $final_path${NC}"
            echo -e "    ${GREEN}alphaforge${NC}         ${DIM}# If you added the shell alias${NC}"
            ;;
    esac

    echo ""
    echo -e "  ${WHITE}Quick Start:${NC}"
    echo -e "    ${CYAN}/help${NC}                    ${DIM}# See all 37 commands${NC}"
    echo -e "    ${CYAN}/gen-prd \"your idea\"${NC}     ${DIM}# Generate a PRD${NC}"
    echo -e "    ${CYAN}/auto-build ./PRD.md${NC}     ${DIM}# Build the entire product${NC}"
    echo -e "    ${CYAN}/health-check${NC}            ${DIM}# Audit your project${NC}"

    if [[ "$agent_teams" == "true" ]]; then
        echo ""
        echo -e "  ${MAGENTA}Agent Teams: ENABLED${NC}"
        echo -e "    ${DIM}Parallel builder, code review debates, and competing hypothesis debugging active.${NC}"
    fi

    echo ""
    echo -e "  ${DIM}Documentation: README.md | CLAUDE.md${NC}"
    echo -e "  ${DIM}Uninstall:     ./install.sh --uninstall${NC}"
    echo -e "  ${DIM}Status:        ./install.sh --status${NC}"
    echo ""
}

# ─────────────────────────────────────────────────
# Entry Point
# ─────────────────────────────────────────────────
main "$@"
