#!/usr/bin/env bash

set -euo pipefail

PREFIX="${HOME}/.bash_prompt"

# Color output for installer (using tput for better compatibility)
if command -v tput &>/dev/null && [ -t 1 ]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    RESET=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    CYAN=""
    RESET=""
fi

info() { echo -e "${CYAN}[*]${RESET} $1"; }
success() { echo -e "${GREEN}[âœ“]${RESET} $1"; }
warning() { echo -e "${YELLOW}[!]${RESET} $1" >&2; }
error() { echo -e "${RED}[âœ—]${RESET} $1" >&2; }

info "Installing Bash Prompt Framework â†’ $PREFIX"

# Create directory structure
mkdir -p "$PREFIX"/{modules,lib,bin,completions}

# Detect Termux
if [[ -d "/data/data/com.termux" ]]; then
    warning "Termux detected - using compatible settings"
    export IS_TERMUX=true  # Make available to subshells/sourced scripts
else
    export IS_TERMUX=false
fi

# -----------------------------
# Core library files
# -----------------------------

cat >"$PREFIX/lib/colors.sh" <<'EOF'
# ANSI color codes for prompt (escaped for PS1)
# Termux-friendly colors
C_RESET="\[\033[0m\]"
C_BOLD="\[\033[1m\]"
C_DIM="\[\033[2m\]"

# Basic colors
C_BLACK="\[\033[30m\]"
C_RED="\[\033[31m\]"
C_GREEN="\[\033[32m\]"
C_YELLOW="\[\033[33m\]"
C_BLUE="\[\033[34m\]"
C_MAGENTA="\[\033[35m\]"
C_CYAN="\[\033[36m\]"
C_WHITE="\[\033[37m\]"
C_GRAY="\[\033[90m\]"

# Bright variants
C_BRIGHT_RED="\[\033[91m\]"
C_BRIGHT_GREEN="\[\033[92m\]"
C_BRIGHT_YELLOW="\[\033[93m\]"
C_BRIGHT_BLUE="\[\033[94m\]"
C_BRIGHT_MAGENTA="\[\033[95m\]"
C_BRIGHT_CYAN="\[\033[96m\]"
C_BRIGHT_WHITE="\[\033[97m\]"

# Background colors
BG_RED="\[\033[41m\]"
BG_GREEN="\[\033[42m\]"
BG_YELLOW="\[\033[43m\]"
BG_BLUE="\[\033[44m\]"
BG_MAGENTA="\[\033[45m\]"
BG_CYAN="\[\033[46m\]"

# Git-specific colors
C_GIT_CLEAN="\[\033[32m\]"
C_GIT_DIRTY="\[\033[31m\]"
C_GIT_STAGED="\[\033[33m\]"
EOF

cat >"$PREFIX/lib/utils.sh" <<'EOF'
# Smart path shortening
shorten_path() {
    local max_len=${PROMPT_PATH_MAX_LEN:-50}
    local home_replaced="${PWD/#$HOME/~}"

    # Handle Android/Termux paths
    if [[ -d "/data/data/com.termux" ]]; then
        home_replaced="${home_replaced/#\/data\/data\/com.termux\/files\/home/\~}"
    fi

    if [ ${#home_replaced} -le $max_len ]; then
        echo "$home_replaced"
    else
        echo "...${home_replaced: -$max_len}"
    fi
}

# Git utilities
git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null
}

git_status() {
    local status=$(git status --porcelain 2>/dev/null)
    if [ -n "$status" ]; then
        echo "dirty"
    else
        echo "clean"
    fi
}

git_ahead_behind() {
    local ahead behind
    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null)
    behind=$(git rev-list --count HEAD..@{u} 2>/dev/null)

    [ "$ahead" -gt 0 ] && echo -n "â†‘$ahead"
    [ "$behind" -gt 0 ] && echo -n "â†“$behind"
}

# Virtual environment detection
venv_name() {
    if [ -n "$VIRTUAL_ENV" ]; then
        basename "$VIRTUAL_ENV"
    elif [ -n "$CONDA_DEFAULT_ENV" ]; then
        echo "$CONDA_DEFAULT_ENV"
    fi
}

# SSH connection detection
is_ssh() {
    [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]
}

# Command duration formatting
format_duration() {
    local seconds=$1
    if [ $seconds -lt 60 ]; then
        echo "${seconds}s"
    elif [ $seconds -lt 3600 ]; then
        echo "$((seconds / 60))m $((seconds % 60))s"
    else
        echo "$((seconds / 3600))h $(((seconds % 3600) / 60))m"
    fi
}

# Check if running in Termux
is_termux() {
    [[ -d "/data/data/com.termux" ]]
}
EOF

# Fix: Install config.sh in the correct location (root, not lib)
cat >"$PREFIX/config.sh" <<'EOF'
# ================================
# Bash Prompt Configuration
# ================================

# Module order (loaded in this sequence)
PROMPT_MODULES=(user host path git venv kubecontext status jobs time)

# Left side modules (main prompt line)
PROMPT_LEFT=(user host path git)

# Right side modules (status line)
PROMPT_RIGHT=(venv kubecontext status jobs time)

# Prompt symbol and style
PROMPT_SYMBOL="â¯"
PROMPT_SYMBOL_ROOT="#"

# Path shortening
PROMPT_PATH_MAX_LEN=40

# Git settings
PROMPT_GIT_SHOW_BRANCH=true
PROMPT_GIT_SHOW_STATUS=true
PROMPT_GIT_SHOW_AHEAD_BEHIND=true

# Show exit code for non-zero
PROMPT_SHOW_EXIT_CODE=true

# Command duration threshold (seconds)
PROMPT_DURATION_THRESHOLD=1

# Multi-line prompt
PROMPT_NEWLINE_BEFORE=true  # Newline before prompt symbol
PROMPT_NEWLINE_AFTER=false  # Newline after prompt symbol

# Termux specific
if [[ -d "/data/data/com.termux" ]]; then
    PROMPT_PATH_MAX_LEN=30
    PROMPT_SYMBOL="âž¤"
fi
EOF

# -----------------------------
# Enhanced modules
# -----------------------------

cat >"$PREFIX/modules/user.sh" <<'EOF'
__prompt_user() {
    local user_color="$C_BLUE"
    [ "$USER" = "root" ] && user_color="$C_RED"

    # Termux user display
    if is_termux; then
        printf "%sðŸ“± %s%s " "$user_color" "$USER" "$C_RESET"
    else
        printf "%s%s%s " "$user_color" "$USER" "$C_RESET"
    fi
}
EOF

cat >"$PREFIX/modules/host.sh" <<'EOF'
__prompt_host() {
    if is_ssh; then
        printf "%s@%s%s " "$C_YELLOW" "$HOSTNAME" "$C_RESET"
    fi
}
EOF

cat >"$PREFIX/modules/path.sh" <<'EOF'
__prompt_path() {
    printf "%s%s%s " "$C_CYAN" "$(shorten_path)" "$C_RESET"
}
EOF

cat >"$PREFIX/modules/git.sh" <<'EOF'
__prompt_git() {
    local branch=$(git_branch)
    [ -z "$branch" ] && return

    local status=$(git_status)
    local status_color="$C_GIT_CLEAN"
    [ "$status" = "dirty" ] && status_color="$C_GIT_DIRTY"

    local ahead_behind=""
    if [ "$PROMPT_GIT_SHOW_AHEAD_BEHIND" = true ]; then
        ahead_behind=$(git_ahead_behind)
        [ -n "$ahead_behind" ] && ahead_behind=" $ahead_behind"
    fi

    printf "%sâŽ‡ %s%s%s " "$status_color" "$branch" "$ahead_behind" "$C_RESET"
}
EOF

cat >"$PREFIX/modules/venv.sh" <<'EOF'
__prompt_venv() {
    local venv=$(venv_name)
    [ -n "$venv" ] && printf "%sðŸ %s%s " "$C_GREEN" "$venv" "$C_RESET"
}
EOF

cat >"$PREFIX/modules/kubecontext.sh" <<'EOF'
__prompt_kubecontext() {
    if command -v kubectl &>/dev/null && [ -f "$HOME/.kube/config" ]; then
        local context=$(kubectl config current-context 2>/dev/null)
        local namespace=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)

        if [ -n "$context" ]; then
            if [ -n "$namespace" ]; then
                printf "%sâŽˆ %s/%s%s " "$C_MAGENTA" "$context" "$namespace" "$C_RESET"
            else
                printf "%sâŽˆ %s%s " "$C_MAGENTA" "$context" "$C_RESET"
            fi
        fi
    fi
}
EOF

cat >"$PREFIX/modules/status.sh" <<'EOF'
__prompt_status() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        printf "%sâœ— %s%s " "$C_RED" "$exit_code" "$C_RESET"
    fi
}
EOF

cat >"$PREFIX/modules/jobs.sh" <<'EOF'
__prompt_jobs() {
    local j=$(jobs -p | wc -l)
    [ "$j" -gt 0 ] && printf "%s[%d]%s " "$C_GREEN" "$j" "$C_RESET"
}
EOF

cat >"$PREFIX/modules/time.sh" <<'EOF'
__prompt_time() {
    if [ -n "$__cmd_duration" ] && [ "$__cmd_duration" -ge "$PROMPT_DURATION_THRESHOLD" ]; then                                          printf "%s%s%s " "$C_GRAY" "$(format_duration $__cmd_duration)" "$C_RESET"
    fi
}
EOF                                        
# -----------------------------
# Main prompt script (FIXED)
# -----------------------------            
cat >"$PREFIX/prompt.sh" <<'EOF'           # Prevent recursive sourcing
if [ -n "$__PROMPT_LOADED" ]; then             return
fi                                         export __PROMPT_LOADED=1
                                           PROMPT_DIR="${PROMPT_DIR:-$HOME/.bash_prompt}"                                        
# Validate installation
if [ ! -d "$PROMPT_DIR" ]; then                echo "Error: Bash Prompt not found at $PROMPT_DIR" >&2
    return 1
fi

# Source core files (colors and utils from lib, config from root)
if [ -f "$PROMPT_DIR/lib/colors.sh" ]; then    source "$PROMPT_DIR/lib/colors.sh"
else
    echo "Warning: Missing $PROMPT_DIR/lib/colors.sh" >&2
fi
                                           if [ -f "$PROMPT_DIR/lib/utils.sh" ]; then
    source "$PROMPT_DIR/lib/utils.sh"
else
    echo "Warning: Missing $PROMPT_DIR/lib/utils.sh" >&2
fi                                                                                    # FIXED: Source config from root directory, not lib
if [ -f "$PROMPT_DIR/config.sh" ]; then
    source "$PROMPT_DIR/config.sh"
else
    echo "Warning: Missing $PROMPT_DIR/config.sh" >&2
fi

# Source enabled modules
for mod in "${PROMPT_MODULES[@]}"; do
    if [ -f "$PROMPT_DIR/modules/$mod.sh" ]; then
        source "$PROMPT_DIR/modules/$mod.sh"
    else
        echo "Warning: Module '$mod' not found" >&2
    fi
done

__prompt_symbol() {                            local symbol="$PROMPT_SYMBOL"
    [ "$EUID" -eq 0 ] && symbol="$PROMPT_SYMBOL_ROOT"
                                               printf "%s%s%s" "$C_GREEN" "$symbol" "$C_RESET"                                   }
                                           __prompt_build() {
    local left="" right=""                 
    # Build left side
    for mod in "${PROMPT_LEFT[@]}"; do             local func="__prompt_$mod"
        if declare -f "$func" >/dev/null 2>&1; then
            left+="$($func)"
        fi
    done

    # Build right side
    for mod in "${PROMPT_RIGHT[@]}"; do
        local func="__prompt_$mod"
        if declare -f "$func" >/dev/null 2>&1; then
            right+="$($func)"
        fi                                     done

    # Handle right alignment
    if [ -n "$right" ]; then
        local cols=$(tput cols 2>/dev/null || echo 80)                                        # Strip color codes for length calculation
        local right_plain=$(echo -e "$right" | sed 's/\\\[\\033\[[0-9;]*m\\\]//g')
        local right_len=${#right_plain}
        local pad=$((cols - right_len))            [ $pad -lt 0 ] && pad=0
        printf -v right "%*s%s" "$pad" "" "$right"
    fi

    # Assemble PS1
    PS1=""
    [ "$PROMPT_NEWLINE_BEFORE" = true ] && PS1+="\n"
    PS1+="${left}"                         
    if [ -n "$right" ]; then                       PS1+="\n${right}"
    fi

    [ "$PROMPT_NEWLINE_AFTER" = true ] && PS1+="\n"
    PS1+="\n$(__prompt_symbol) "
}

__prompt_preexec() {                           __cmd_start=$(date +%s 2>/dev/null || echo 0)
}

__prompt_precmd() {                            __cmd_end=$(date +%s 2>/dev/null || echo 0)                                           __cmd_duration=$((__cmd_end - __cmd_start))                                           __prompt_build
}                                          
# Setup traps and hooks                    trap '__prompt_preexec' DEBUG
PROMPT_COMMAND="__prompt_precmd"           
# Export functions for use in modules
export -f shorten_path git_branch git_status git_ahead_behind
export -f venv_name is_ssh format_duration is_termux
EOF

# -----------------------------
# CLI tool (enhanced)
# -----------------------------            
cat >"$PREFIX/bin/prompt" <<'EOF'          #!/usr/bin/env bash                                                                   PROMPT_DIR="${HOME}/.bash_prompt"          CONFIG_FILE="$PROMPT_DIR/config.sh"                                                   show_help() {
    cat <<HELP                             Bash Prompt Framework - CLI Manager                                                   Usage: prompt <command> [options]
                                           Commands:                                      list                        List all available modules
    status                      Show current configuration                                enable <module>             Enable a module                                           disable <module>            Disable a module                                          left <modules...>           Set left side modules (space-separated)                   right <modules...>          Set right side modules (space-separated)                  symbol [symbol]             Show or set prompt symbol                                 reload                      Reload prompt configuration
    fix                         Attempt to fix common issues                              info                        Show debug information
    help                        Show this help message                                                                           Examples:
    prompt list                                prompt enable kubecontext                  prompt disable time                        prompt left user host path git
    prompt right venv status jobs
    prompt symbol 'âžœ'                          prompt reload                              prompt fix                                                                        HELP                                       }                                          
list_modules() {                               echo "Available modules:"                  for mod in "$PROMPT_DIR"/modules/*.sh; do
        basename "$mod" .sh                    done | column                          }                                          
show_status() {                                if [ -f "$CONFIG_FILE" ]; then                 source "$CONFIG_FILE"
        echo "Current Configuration:"              echo "  Left modules:  ${PROMPT_LEFT[*]}"                                             echo "  Right modules: ${PROMPT_RIGHT[*]}"                                            echo "  Symbol:        $PROMPT_SYMBOL"                                                echo "  Path length:   ${PROMPT_PATH_MAX_LEN:-50}"                                else                                           echo "Error: Config file not found at $CONFIG_FILE"                               fi                                     }                                          
enable_module() {                              local module=$1                            if [ ! -f "$PROMPT_DIR/modules/$module.sh" ]; then
        echo "Error: Module '$module' not found" >&2                                          return 1                               fi

    if grep -q "PROMPT_MODULES=.*\<$module\>" "$CONFIG_FILE"; then                            echo "Module '$module' already enabled"                                               return 0
    fi                                                                                    sed -i.bak "s/^PROMPT_MODULES=(/PROMPT_MODULES=($module /" "$CONFIG_FILE"
    echo "Enabled module: $module"
}

disable_module() {
    local module=$1
    sed -i.bak "s/\<$module\>//g" "$CONFIG_FILE"
    sed -i.bak "s/  / /g" "$CONFIG_FILE"
    echo "Disabled module: $module"
}

set_left() {
    local modules=("${@:1}")                   sed -i.bak "s/^PROMPT_LEFT=(.*)/PROMPT_LEFT=(${modules[*]})/" "$CONFIG_FILE"          echo "Left modules set: ${modules[*]}"
}

set_right() {
    local modules=("${@:1}")
    sed -i.bak "s/^PROMPT_RIGHT=(.*)/PROMPT_RIGHT=(${modules[*]})/" "$CONFIG_FILE"        echo "Right modules set: ${modules[*]}"
}                                          
set_symbol() {                                 local symbol=$1
    sed -i.bak "s/^PROMPT_SYMBOL=.*/PROMPT_SYMBOL=\"$symbol\"/" "$CONFIG_FILE"
    echo "Symbol set to: $symbol"          }
                                           reload_prompt() {
    if [ -f "$PROMPT_DIR/prompt.sh" ]; then        source "$PROMPT_DIR/prompt.sh"
        echo "Prompt reloaded"                 else
        echo "Error: prompt.sh not found"
    fi
}                                          
fix_installation() {
    echo "Attempting to fix common issues..."

    # Re-create config if missing
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Recreating config.sh..."
        cat > "$CONFIG_FILE" <<'CONFIG'
PROMPT_MODULES=(user host path git venv kubecontext status jobs time)
PROMPT_LEFT=(user host path git)
PROMPT_RIGHT=(venv kubecontext status jobs time)
PROMPT_SYMBOL="â¯"                          PROMPT_SYMBOL_ROOT="#"
PROMPT_PATH_MAX_LEN=40
PROMPT_GIT_SHOW_BRANCH=true
PROMPT_GIT_SHOW_STATUS=true
PROMPT_GIT_SHOW_AHEAD_BEHIND=true
PROMPT_SHOW_EXIT_CODE=true
PROMPT_DURATION_THRESHOLD=1
PROMPT_NEWLINE_BEFORE=true
PROMPT_NEWLINE_AFTER=false                 CONFIG
    fi

    # Ensure bashrc has the source line
    if ! grep -q "bash_prompt/prompt.sh" "$HOME/.bashrc" 2>/dev/null; then                    echo "Adding source to .bashrc..."
        echo "" >> "$HOME/.bashrc"
        echo "# Bash Prompt Framework" >> "$HOME/.bashrc"
        echo "source $PROMPT_DIR/prompt.sh" >> "$HOME/.bashrc"
    fi                                     
    echo "Fix complete! Run 'source ~/.bashrc' to reload"
}

show_info() {
    echo "Bash Prompt Framework - Debug Info"                                             echo "==================================="                                            echo "Installation: $PROMPT_DIR"
    echo "Bash version: $BASH_VERSION"         echo "Prompt loaded: ${__PROMPT_LOADED:-no}"                                          echo ""
                                               # Check for required files
    echo "File status:"                        for file in config.sh prompt.sh lib/colors.sh lib/utils.sh; do                            if [ -f "$PROMPT_DIR/$file" ]; then
            echo "  âœ“ $file"
        else
            echo "  âœ— $file (MISSING)"
        fi                                     done
                                               echo ""                                    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo "Configuration:"                      echo "  Left modules:  ${PROMPT_LEFT[*]}"
        echo "  Right modules: ${PROMPT_RIGHT[*]}"
        echo "  Total modules: ${#PROMPT_MODULES[@]}"
    fi                                     }
                                           # Main CLI
cmd="${1:-help}"                           case "$cmd" in
    list)       list_modules ;;                status)     show_status ;;
    enable)     enable_module "$2" ;;          disable)    disable_module "$2" ;;
    left)       shift; set_left "$@" ;;        right)      shift; set_right "$@" ;;
    symbol)     [ -n "$2" ] && set_symbol "$2" || echo "Current: $(grep PROMPT_SYMBOL "$CONFIG_FILE" | cut -d'"' -f2)";;
    reload)     reload_prompt ;;
    fix)        fix_installation ;;            info)       show_info ;;
    help|--help|-h) show_help ;;
    *)          echo "Unknown command: $cmd"; show_help; exit 1 ;;
esac                                       EOF

chmod +x "$PREFIX/bin/prompt"              
# Add to PATH in bashrc
if ! grep -q "export PATH=.*$PREFIX/bin" "$HOME/.bashrc" 2>/dev/null; then                echo "export PATH=\"\$PATH:$PREFIX/bin\"" >>"$HOME/.bashrc"
fi

# Source prompt in bashrc
if ! grep -q "bash_prompt/prompt.sh" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" << EOF

# Bash Prompt Framework
source $PREFIX/prompt.sh
EOF
fi
                                           success "Installation complete!"
info "Added modules: user, host, path, git, venv, kubecontext, status, jobs, time"
info "CLI tool available: prompt {list|enable|disable|left|right|symbol|reload|fix|info}"
info ""
info "To fix any issues, run: prompt fix"  info "To start using immediately, run: source ~/.bashrc"
info "Or open a new terminal session"

# Fix any existing issues immediately
if [ -f "$PREFIX/prompt.sh" ]; then            success "Prompt is ready to use!"
fi
