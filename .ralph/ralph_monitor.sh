#!/bin/bash

# Ralph Status Monitor for VeepaAudioTest
# Live terminal dashboard for monitoring autonomous implementation progress

set -e

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
STATUS_FILE="$SCRIPT_DIR/.status.json"
LOG_FILE="$SCRIPT_DIR/logs/ralph.log"
REFRESH_INTERVAL=2

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Clear screen and hide cursor
clear_screen() {
    clear
    printf '\033[?25l'  # Hide cursor
}

# Show cursor on exit
show_cursor() {
    printf '\033[?25h'  # Show cursor
}

# Cleanup function
cleanup() {
    show_cursor
    echo
    echo "Monitor stopped."
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM EXIT

# Main display function
display_status() {
    clear_screen

    # Header
    echo -e "${WHITE}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║                    🤖 RALPH MONITOR - VeepaAudioTest                    ║${NC}"
    echo -e "${WHITE}║                   Autonomous Story Implementation                      ║${NC}"
    echo -e "${WHITE}╚════════════════════════════════════════════════════════════════════════╝${NC}"
    echo

    # Status section
    if [[ -f "$STATUS_FILE" ]]; then
        # Parse JSON status
        local status_data=$(cat "$STATUS_FILE")
        local loop_count=$(echo "$status_data" | jq -r '.loop_count // "0"' 2>/dev/null || echo "0")
        local calls_made=$(echo "$status_data" | jq -r '.calls_made_this_hour // "0"' 2>/dev/null || echo "0")
        local max_calls=$(echo "$status_data" | jq -r '.max_calls_per_hour // "100"' 2>/dev/null || echo "100")
        local status=$(echo "$status_data" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
        local last_action=$(echo "$status_data" | jq -r '.last_action // "initializing"' 2>/dev/null || echo "initializing")

        echo -e "${CYAN}┌─ Current Status ────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC} Loop Count:     ${WHITE}#$loop_count${NC}"

        # Color-code status
        local status_color=$GREEN
        if [[ "$status" == "error" || "$status" == "halted" ]]; then
            status_color=$RED
        elif [[ "$status" == "running" || "$status" == "executing" ]]; then
            status_color=$YELLOW
        fi

        echo -e "${CYAN}│${NC} Status:         ${status_color}$status${NC}"
        echo -e "${CYAN}│${NC} Last Action:    $last_action"
        echo -e "${CYAN}│${NC} API Calls:      $calls_made/$max_calls this hour"

        # Progress bar for API calls
        local percent=$((calls_made * 100 / max_calls))
        local bar_length=30
        local filled=$((percent * bar_length / 100))
        local empty=$((bar_length - filled))

        local bar_color=$GREEN
        if [[ $percent -gt 80 ]]; then bar_color=$RED
        elif [[ $percent -gt 60 ]]; then bar_color=$YELLOW
        fi

        echo -ne "${CYAN}│${NC} Progress:       ${bar_color}["
        for ((i=0; i<filled; i++)); do echo -n "█"; done
        for ((i=0; i<empty; i++)); do echo -n "░"; done
        echo -e "] ${percent}%${NC}"

        echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────────┘${NC}"
        echo

    else
        echo -e "${RED}┌─ Status ────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${RED}│${NC} Status file not found. Ralph may not be running."
        echo -e "${RED}│${NC} Start Ralph with: .ralph/ralph_loop.sh"
        echo -e "${RED}└─────────────────────────────────────────────────────────────────────────┘${NC}"
        echo
    fi

    # Story Progress section (from @fix_plan.md)
    if [[ -f "@fix_plan.md" ]]; then
        local total_stories=$(grep -c "^- \[" "@fix_plan.md" 2>/dev/null || echo "0")
        local completed_stories=$(grep -c "^- \[x\]" "@fix_plan.md" 2>/dev/null || echo "0")

        if [[ $total_stories -gt 0 ]]; then
            local story_percent=$((completed_stories * 100 / total_stories))

            echo -e "${PURPLE}┌─ Story Progress (27 Sub-Stories) ──────────────────────────────────────┐${NC}"
            echo -e "${PURPLE}│${NC} Completed:      ${WHITE}$completed_stories / $total_stories${NC} (${story_percent}%)"

            # Story progress bar
            local sbar_length=30
            local sfilled=$((story_percent * sbar_length / 100))
            local sempty=$((sbar_length - sfilled))

            echo -ne "${PURPLE}│${NC} Progress:       ${GREEN}["
            for ((i=0; i<sfilled; i++)); do echo -n "█"; done
            for ((i=0; i<sempty; i++)); do echo -n "░"; done
            echo -e "] ${story_percent}%${NC}"

            # Show current story (last incomplete)
            local current_story=$(grep -m1 "^- \[ \]" "@fix_plan.md" 2>/dev/null | sed 's/^- \[ \] //')
            if [[ -n "$current_story" ]]; then
                echo -e "${PURPLE}│${NC} Current:        ${YELLOW}$current_story${NC}"
            fi

            echo -e "${PURPLE}└─────────────────────────────────────────────────────────────────────────┘${NC}"
            echo
        fi
    fi

    # Claude Code Progress section
    if [[ -f "$SCRIPT_DIR/.progress.json" ]]; then
        local progress_data=$(cat "$SCRIPT_DIR/.progress.json" 2>/dev/null)
        local progress_status=$(echo "$progress_data" | jq -r '.status // "idle"' 2>/dev/null || echo "idle")

        if [[ "$progress_status" == "executing" ]]; then
            local indicator=$(echo "$progress_data" | jq -r '.indicator // "⠋"' 2>/dev/null || echo "⠋")
            local elapsed=$(echo "$progress_data" | jq -r '.elapsed_seconds // "0"' 2>/dev/null || echo "0")
            local last_output=$(echo "$progress_data" | jq -r '.last_output // ""' 2>/dev/null || echo "")

            echo -e "${YELLOW}┌─ Claude Code Progress ──────────────────────────────────────────────────┐${NC}"
            echo -e "${YELLOW}│${NC} Status:         ${indicator} Working (${elapsed}s elapsed)"
            if [[ -n "$last_output" && "$last_output" != "" ]]; then
                # Truncate long output for display
                local display_output=$(echo "$last_output" | head -c 60)
                echo -e "${YELLOW}│${NC} Output:         ${display_output}..."
            fi
            echo -e "${YELLOW}└─────────────────────────────────────────────────────────────────────────┘${NC}"
            echo
        fi
    fi

    # Recent logs
    echo -e "${BLUE}┌─ Recent Activity ───────────────────────────────────────────────────────┐${NC}"
    if [[ -f "$LOG_FILE" ]]; then
        tail -n 8 "$LOG_FILE" | while IFS= read -r line; do
            # Truncate long lines for display
            local display_line=$(echo "$line" | head -c 70)
            echo -e "${BLUE}│${NC} $display_line"
        done
    else
        echo -e "${BLUE}│${NC} No log file found"
    fi
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────────────────┘${NC}"

    # Footer
    echo
    echo -e "${YELLOW}Controls: Ctrl+C to exit | Refreshes every ${REFRESH_INTERVAL}s | $(date '+%H:%M:%S')${NC}"
    echo -e "${CYAN}Project: VeepaAudioTest | Stories: 4 main, 27 sub | Target: 8-10.5 hours${NC}"
}

# Main monitor loop
main() {
    echo "Starting Ralph Monitor for VeepaAudioTest..."
    sleep 2

    while true; do
        display_status
        sleep "$REFRESH_INTERVAL"
    done
}

main
