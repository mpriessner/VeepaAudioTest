#!/bin/bash

# Claude Code Ralph Loop for VeepaAudioTest
# Adapted from SciSymbioLens ralph_loop.sh
# Purpose: Autonomous implementation of 27 sub-stories for VeepaAudioTest

set -e  # Exit on any error

# Source library components
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/lib/date_utils.sh"
source "$SCRIPT_DIR/lib/response_analyzer.sh"
source "$SCRIPT_DIR/lib/circuit_breaker.sh"

# Configuration
PROMPT_FILE="$SCRIPT_DIR/PROMPT.md"
LOG_DIR="$SCRIPT_DIR/logs"
STATUS_FILE="$SCRIPT_DIR/.status.json"
PROGRESS_FILE="$SCRIPT_DIR/.progress.json"
CLAUDE_CODE_CMD="claude"
MAX_CALLS_PER_HOUR=100
VERBOSE_PROGRESS=true  # Enable verbose for VeepaAudioTest
CLAUDE_TIMEOUT_MINUTES=20  # Longer timeout for complex implementations
SLEEP_DURATION=3600
CALL_COUNT_FILE="$SCRIPT_DIR/.call_count"
TIMESTAMP_FILE="$SCRIPT_DIR/.last_reset"
USE_TMUX=false

# Modern Claude CLI configuration
CLAUDE_OUTPUT_FORMAT="json"
CLAUDE_ALLOWED_TOOLS="Write,Read,Edit,Bash(git *),Bash(flutter *),Bash(xcodebuild *),Bash(xcodegen *),Glob,Grep"
CLAUDE_USE_CONTINUE=true
CLAUDE_SESSION_FILE="$SCRIPT_DIR/.claude_session_id"
CLAUDE_MIN_VERSION="2.0.76"

# Session management
RALPH_SESSION_FILE="$SCRIPT_DIR/.ralph_session"
RALPH_SESSION_HISTORY_FILE="$SCRIPT_DIR/.ralph_session_history"

# Exit detection configuration
EXIT_SIGNALS_FILE="$SCRIPT_DIR/.exit_signals"
MAX_CONSECUTIVE_TEST_LOOPS=3
MAX_CONSECUTIVE_DONE_SIGNALS=2
TEST_PERCENTAGE_THRESHOLD=30

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Initialize directories
mkdir -p "$LOG_DIR"

# Check if tmux is available
check_tmux_available() {
    if ! command -v tmux &> /dev/null; then
        log_status "ERROR" "tmux is not installed. Please install tmux or run without --monitor flag."
        echo "Install tmux:"
        echo "  Ubuntu/Debian: sudo apt-get install tmux"
        echo "  macOS: brew install tmux"
        echo "  CentOS/RHEL: sudo yum install tmux"
        exit 1
    fi
}

# Setup tmux session with monitor
setup_tmux_session() {
    local session_name="ralph-veepa-$(date +%s)"

    log_status "INFO" "Setting up tmux session: $session_name"

    # Create new tmux session detached
    tmux new-session -d -s "$session_name" -c "$(pwd)"

    # Split window vertically to create monitor pane on the right
    tmux split-window -h -t "$session_name" -c "$(pwd)"

    # Start monitor in the right pane
    tmux send-keys -t "$session_name:0.1" "$SCRIPT_DIR/ralph_monitor.sh" Enter

    # Start ralph loop in the left pane
    tmux send-keys -t "$session_name:0.0" "$0 --no-tmux" Enter

    # Focus on left pane
    tmux select-pane -t "$session_name:0.0"

    # Set window title
    tmux rename-window -t "$session_name:0" "Ralph: VeepaAudioTest"

    log_status "SUCCESS" "Tmux session created. Attaching..."
    log_status "INFO" "Use Ctrl+B then D to detach from session"
    log_status "INFO" "Use 'tmux attach -t $session_name' to reattach"

    # Attach to session
    tmux attach-session -t "$session_name"

    exit 0
}

# Initialize call tracking
init_call_tracking() {
    local current_hour=$(date +%Y%m%d%H)
    local last_reset_hour=""

    if [[ -f "$TIMESTAMP_FILE" ]]; then
        last_reset_hour=$(cat "$TIMESTAMP_FILE")
    fi

    # Reset counter if it's a new hour
    if [[ "$current_hour" != "$last_reset_hour" ]]; then
        echo "0" > "$CALL_COUNT_FILE"
        echo "$current_hour" > "$TIMESTAMP_FILE"
        log_status "INFO" "Call counter reset for new hour: $current_hour"
    fi

    # Initialize exit signals tracking
    if [[ ! -f "$EXIT_SIGNALS_FILE" ]]; then
        echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    fi

    # Initialize circuit breaker
    init_circuit_breaker
}

# Log function with timestamps and colors
log_status() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color=""

    case $level in
        "INFO")  color=$BLUE ;;
        "WARN")  color=$YELLOW ;;
        "ERROR") color=$RED ;;
        "SUCCESS") color=$GREEN ;;
        "LOOP") color=$PURPLE ;;
    esac

    echo -e "${color}[$timestamp] [$level] $message${NC}"
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/ralph.log"
}

# Update status JSON
update_status() {
    local loop_count=$1
    local calls_made=$2
    local last_action=$3
    local status=$4
    local exit_reason=${5:-""}

    cat > "$STATUS_FILE" << STATUSEOF
{
    "timestamp": "$(get_iso_timestamp)",
    "loop_count": $loop_count,
    "calls_made_this_hour": $calls_made,
    "max_calls_per_hour": $MAX_CALLS_PER_HOUR,
    "last_action": "$last_action",
    "status": "$status",
    "exit_reason": "$exit_reason",
    "next_reset": "$(get_next_hour_time)"
}
STATUSEOF
}

# Check if we can make another call
can_make_call() {
    local calls_made=0
    if [[ -f "$CALL_COUNT_FILE" ]]; then
        calls_made=$(cat "$CALL_COUNT_FILE")
    fi

    if [[ $calls_made -ge $MAX_CALLS_PER_HOUR ]]; then
        return 1
    else
        return 0
    fi
}

# Increment call counter
increment_call_counter() {
    local calls_made=0
    if [[ -f "$CALL_COUNT_FILE" ]]; then
        calls_made=$(cat "$CALL_COUNT_FILE")
    fi

    ((calls_made++))
    echo "$calls_made" > "$CALL_COUNT_FILE"
    echo "$calls_made"
}

# Wait for rate limit reset
wait_for_reset() {
    local calls_made=$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")
    log_status "WARN" "Rate limit reached ($calls_made/$MAX_CALLS_PER_HOUR). Waiting for reset..."

    local current_minute=$(date +%M)
    local current_second=$(date +%S)
    local wait_time=$(((60 - current_minute - 1) * 60 + (60 - current_second)))

    log_status "INFO" "Sleeping for $wait_time seconds until next hour..."

    # Countdown display
    while [[ $wait_time -gt 0 ]]; do
        local hours=$((wait_time / 3600))
        local minutes=$(((wait_time % 3600) / 60))
        local seconds=$((wait_time % 60))

        printf "\r${YELLOW}Time until reset: %02d:%02d:%02d${NC}" $hours $minutes $seconds
        sleep 1
        ((wait_time--))
    done
    printf "\n"

    # Reset counter
    echo "0" > "$CALL_COUNT_FILE"
    echo "$(date +%Y%m%d%H)" > "$TIMESTAMP_FILE"
    log_status "SUCCESS" "Rate limit reset! Ready for new calls."
}

# Check for graceful exit
should_exit_gracefully() {
    if [[ ! -f "$EXIT_SIGNALS_FILE" ]]; then
        return 1
    fi

    local signals=$(cat "$EXIT_SIGNALS_FILE")

    # Check @fix_plan.md for completion
    if [[ -f "@fix_plan.md" ]]; then
        local total_items=$(grep -c "^- \[" "@fix_plan.md" 2>/dev/null || echo "0")
        local completed_items=$(grep -c "^- \[x\]" "@fix_plan.md" 2>/dev/null || echo "0")

        [[ -z "$total_items" ]] && total_items=0
        [[ -z "$completed_items" ]] && completed_items=0

        if [[ $total_items -gt 0 ]] && [[ $completed_items -eq $total_items ]]; then
            log_status "WARN" "Exit condition: All fix_plan.md items completed ($completed_items/$total_items)"
            echo "plan_complete"
            return 0
        fi
    fi

    # Check for EXIT_SIGNAL: true in response
    local recent_done_signals=$(echo "$signals" | jq '.done_signals | length' 2>/dev/null || echo "0")
    if [[ $recent_done_signals -ge $MAX_CONSECUTIVE_DONE_SIGNALS ]]; then
        log_status "WARN" "Exit condition: Multiple EXIT_SIGNAL: true detected"
        echo "completion_signals"
        return 0
    fi

    echo ""
}

# Generate session ID
generate_session_id() {
    local ts=$(date +%s)
    local rand=$RANDOM
    echo "ralph-veepa-${ts}-${rand}"
}

# Initialize session tracking
init_session_tracking() {
    local ts=$(get_iso_timestamp)

    if [[ ! -f "$RALPH_SESSION_FILE" ]]; then
        local new_session_id=$(generate_session_id)

        jq -n \
            --arg session_id "$new_session_id" \
            --arg created_at "$ts" \
            --arg last_used "$ts" \
            '{
                session_id: $session_id,
                created_at: $created_at,
                last_used: $last_used
            }' > "$RALPH_SESSION_FILE"

        log_status "INFO" "Initialized session: $new_session_id"
    fi
}

# Update session timestamp
update_session_last_used() {
    if [[ ! -f "$RALPH_SESSION_FILE" ]]; then
        return 0
    fi

    local ts=$(get_iso_timestamp)
    local updated=$(jq --arg last_used "$ts" '.last_used = $last_used' "$RALPH_SESSION_FILE" 2>/dev/null)

    if [[ $? -eq 0 && -n "$updated" ]]; then
        echo "$updated" > "$RALPH_SESSION_FILE"
    fi
}

# Build Claude command
declare -a CLAUDE_CMD_ARGS=()

build_claude_command() {
    local prompt_file=$1

    CLAUDE_CMD_ARGS=("$CLAUDE_CODE_CMD")

    if [[ ! -f "$prompt_file" ]]; then
        log_status "ERROR" "Prompt file not found: $prompt_file"
        return 1
    fi

    # Output format
    if [[ "$CLAUDE_OUTPUT_FORMAT" == "json" ]]; then
        CLAUDE_CMD_ARGS+=("--output-format" "json")
    fi

    # Allowed tools
    if [[ -n "$CLAUDE_ALLOWED_TOOLS" ]]; then
        CLAUDE_CMD_ARGS+=("--allowedTools")
        local IFS=','
        read -ra tools_array <<< "$CLAUDE_ALLOWED_TOOLS"
        for tool in "${tools_array[@]}"; do
            tool=$(echo "$tool" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$tool" ]]; then
                CLAUDE_CMD_ARGS+=("$tool")
            fi
        done
    fi

    # Session continuity
    if [[ "$CLAUDE_USE_CONTINUE" == "true" ]]; then
        CLAUDE_CMD_ARGS+=("--continue")
    fi

    # Read prompt content
    local prompt_content=$(cat "$prompt_file")
    CLAUDE_CMD_ARGS+=("-p" "$prompt_content")
}

# Main execution function
execute_claude_code() {
    local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local output_file="$LOG_DIR/claude_output_${timestamp}.log"
    local loop_count=$1
    local calls_made=$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")
    calls_made=$((calls_made + 1))

    log_status "LOOP" "Executing Claude Code (Call $calls_made/$MAX_CALLS_PER_HOUR)"
    local timeout_seconds=$((CLAUDE_TIMEOUT_MINUTES * 60))
    log_status "INFO" "⏳ Starting Claude Code execution... (timeout: ${CLAUDE_TIMEOUT_MINUTES}m)"

    # Build command
    if ! build_claude_command "$PROMPT_FILE"; then
        return 1
    fi

    log_status "INFO" "Using modern CLI mode (JSON output)"

    # Execute
    if timeout ${timeout_seconds}s "${CLAUDE_CMD_ARGS[@]}" > "$output_file" 2>&1 &
    then
        local claude_pid=$!
        local progress_counter=0

        # Monitor progress
        while kill -0 $claude_pid 2>/dev/null; do
            progress_counter=$((progress_counter + 1))

            if [[ "$VERBOSE_PROGRESS" == "true" ]]; then
                log_status "INFO" "⏳ Claude Code working... (${progress_counter}0s elapsed)"
            fi

            sleep 10
        done

        # Wait for completion
        wait $claude_pid
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            echo "$calls_made" > "$CALL_COUNT_FILE"
            log_status "SUCCESS" "✅ Claude Code execution completed successfully"

            # Analyze response
            log_status "INFO" "🔍 Analyzing response..."
            analyze_response "$output_file" "$loop_count"

            # Update exit signals
            update_exit_signals

            # Log analysis summary
            log_analysis_summary

            # Circuit breaker check
            local files_changed=$(git diff --name-only 2>/dev/null | wc -l || echo 0)
            local has_errors="false"

            if grep -qE '(Error:|ERROR:|error:|\]: error|Exception|Fatal)' "$output_file" 2>/dev/null; then
                has_errors="true"
                log_status "WARN" "Errors detected in output"
            fi

            local output_length=$(wc -c < "$output_file" 2>/dev/null || echo 0)

            record_loop_result "$loop_count" "$files_changed" "$has_errors" "$output_length"
            local circuit_result=$?

            if [[ $circuit_result -ne 0 ]]; then
                log_status "WARN" "Circuit breaker opened - halting execution"
                return 3
            fi

            return 0
        else
            log_status "ERROR" "❌ Claude Code execution failed, check: $output_file"
            return 1
        fi
    else
        log_status "ERROR" "❌ Failed to start Claude Code process"
        return 1
    fi
}

# Cleanup
cleanup() {
    log_status "INFO" "Ralph loop interrupted. Cleaning up..."
    update_status "$loop_count" "$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")" "interrupted" "stopped"
    exit 0
}

trap cleanup SIGINT SIGTERM

loop_count=0

# Main loop
main() {
    log_status "SUCCESS" "🚀 Ralph loop starting for VeepaAudioTest"
    log_status "INFO" "Max calls per hour: $MAX_CALLS_PER_HOUR"
    log_status "INFO" "Logs: $LOG_DIR/ | Status: $STATUS_FILE"

    if [[ ! -f "$PROMPT_FILE" ]]; then
        log_status "ERROR" "Prompt file not found: $PROMPT_FILE"
        exit 1
    fi

    init_session_tracking

    while true; do
        loop_count=$((loop_count + 1))

        update_session_last_used
        init_call_tracking

        log_status "LOOP" "=== Starting Loop #$loop_count ==="

        # Circuit breaker check
        if should_halt_execution; then
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE")" "circuit_breaker_open" "halted" "stagnation_detected"
            log_status "ERROR" "🛑 Circuit breaker has opened - execution halted"
            break
        fi

        # Rate limit check
        if ! can_make_call; then
            wait_for_reset
            continue
        fi

        # Graceful exit check
        local exit_reason=$(should_exit_gracefully)
        if [[ "$exit_reason" != "" ]]; then
            log_status "SUCCESS" "🏁 Graceful exit triggered: $exit_reason"
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE")" "graceful_exit" "completed" "$exit_reason"

            log_status "SUCCESS" "🎉 Ralph has completed VeepaAudioTest! Final stats:"
            log_status "INFO" "  - Total loops: $loop_count"
            log_status "INFO" "  - API calls used: $(cat "$CALL_COUNT_FILE")"
            log_status "INFO" "  - Exit reason: $exit_reason"

            break
        fi

        # Update status
        local calls_made=$(cat "$CALL_COUNT_FILE" 2>/dev/null || echo "0")
        update_status "$loop_count" "$calls_made" "executing" "running"

        # Execute Claude Code
        execute_claude_code "$loop_count"
        local exec_result=$?

        if [ $exec_result -eq 0 ]; then
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE")" "completed" "success"
            sleep 5
        elif [ $exec_result -eq 3 ]; then
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE")" "circuit_breaker_open" "halted"
            log_status "ERROR" "🛑 Circuit breaker opened - halting loop"
            break
        else
            update_status "$loop_count" "$(cat "$CALL_COUNT_FILE")" "failed" "error"
            log_status "WARN" "Execution failed, waiting 30 seconds before retry..."
            sleep 30
        fi

        log_status "LOOP" "=== Completed Loop #$loop_count ==="
    done
}

# Help
show_help() {
    cat << HELPEOF
Ralph Loop for VeepaAudioTest

Usage: $0 [OPTIONS]

Options:
    -h, --help              Show this help message
    -c, --calls NUM         Set max calls per hour (default: $MAX_CALLS_PER_HOUR)
    -s, --status            Show current status and exit
    -m, --monitor           Start with tmux session and live monitor
    -v, --verbose           Show detailed progress updates
    -t, --timeout MIN       Set Claude timeout in minutes (default: $CLAUDE_TIMEOUT_MINUTES)
    --reset-circuit         Reset circuit breaker
    --circuit-status        Show circuit breaker status
    --no-tmux               Internal flag - don't use directly

Examples:
    $0                      # Start Ralph loop
    $0 --monitor            # Start with monitoring
    $0 --calls 50           # Limit to 50 calls/hour
    $0 --status             # Check current status

HELPEOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--calls)
            MAX_CALLS_PER_HOUR="$2"
            shift 2
            ;;
        -s|--status)
            if [[ -f "$STATUS_FILE" ]]; then
                cat "$STATUS_FILE" | jq . 2>/dev/null || cat "$STATUS_FILE"
            else
                echo "No status file found."
            fi
            exit 0
            ;;
        -m|--monitor)
            USE_TMUX=true
            shift
            ;;
        -v|--verbose)
            VERBOSE_PROGRESS=true
            shift
            ;;
        -t|--timeout)
            CLAUDE_TIMEOUT_MINUTES="$2"
            shift 2
            ;;
        --reset-circuit)
            reset_circuit_breaker "Manual reset"
            exit 0
            ;;
        --circuit-status)
            show_circuit_status
            exit 0
            ;;
        --no-tmux)
            # Internal flag to prevent recursion
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Start tmux if requested
if [[ "$USE_TMUX" == "true" ]]; then
    check_tmux_available
    setup_tmux_session
fi

# Start main loop
main
