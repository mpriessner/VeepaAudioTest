#!/bin/bash

# RALPH Setup Verification Script
# Checks that all components are properly installed

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Verifying RALPH Setup for VeepaAudioTest..."
echo ""

ERRORS=0

# Function to check file exists
check_file() {
    local file=$1
    local description=$2

    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✅${NC} $description: $file"
    else
        echo -e "${RED}❌${NC} $description: $file NOT FOUND"
        ((ERRORS++))
    fi
}

# Function to check directory exists
check_dir() {
    local dir=$1
    local description=$2

    if [[ -d "$dir" ]]; then
        echo -e "${GREEN}✅${NC} $description: $dir"
    else
        echo -e "${RED}❌${NC} $description: $dir NOT FOUND"
        ((ERRORS++))
    fi
}

# Function to check executable
check_executable() {
    local file=$1
    local description=$2

    if [[ -x "$file" ]]; then
        echo -e "${GREEN}✅${NC} $description is executable"
    else
        echo -e "${RED}❌${NC} $description is NOT executable"
        echo -e "   ${YELLOW}Fix with: chmod +x $file${NC}"
        ((ERRORS++))
    fi
}

echo "📁 Core Files:"
check_file ".ralph/PROMPT.md" "Master instructions"
check_file ".ralph/ralph_loop.sh" "Main loop script"
check_file ".ralph/ralph_monitor.sh" "Monitor script"
check_file ".ralph/README.md" "Usage guide"

echo ""
echo "📚 Library Components:"
check_file ".ralph/lib/circuit_breaker.sh" "Circuit breaker"
check_file ".ralph/lib/response_analyzer.sh" "Response analyzer"
check_file ".ralph/lib/date_utils.sh" "Date utilities"

echo ""
echo "📂 Directories:"
check_dir ".ralph/lib" "Library directory"
check_dir ".ralph/logs" "Logs directory"
check_dir "docs/stories" "Stories directory"

echo ""
echo "🔐 Executable Permissions:"
check_executable ".ralph/ralph_loop.sh" "ralph_loop.sh"
check_executable ".ralph/ralph_monitor.sh" "ralph_monitor.sh"

echo ""
echo "📋 Progress Tracking:"
check_file "@fix_plan.md" "Progress checklist"

if [[ -f "@fix_plan.md" ]]; then
    SUB_STORY_COUNT=$(grep -c "^- \[" "@fix_plan.md")
    if [[ "$SUB_STORY_COUNT" -eq 27 ]]; then
        echo -e "${GREEN}✅${NC} @fix_plan.md has all 27 sub-stories"
    else
        echo -e "${RED}❌${NC} @fix_plan.md has $SUB_STORY_COUNT sub-stories (expected 27)"
        ((ERRORS++))
    fi
fi

echo ""
echo "🔧 Documentation:"
check_file "docs/DEEP_CODE_ANALYSIS.md" "Deep code analysis"
check_file "docs/ENHANCED_STORIES_COMPLETE.md" "Enhanced stories summary"
check_file "docs/stories/NAVIGATION_INDEX.md" "Navigation index"
check_file "RALPH_SETUP_COMPLETE.md" "Setup completion doc"

echo ""
echo "🧪 Functional Tests:"

# Test help command
if .ralph/ralph_loop.sh --help >/dev/null 2>&1; then
    echo -e "${GREEN}✅${NC} ralph_loop.sh --help works"
else
    echo -e "${RED}❌${NC} ralph_loop.sh --help failed"
    ((ERRORS++))
fi

# Test circuit breaker status command
if .ralph/ralph_loop.sh --circuit-status >/dev/null 2>&1; then
    echo -e "${GREEN}✅${NC} ralph_loop.sh --circuit-status works"
else
    echo -e "${RED}❌${NC} ralph_loop.sh --circuit-status failed"
    ((ERRORS++))
fi

# Check for required commands
echo ""
echo "🔍 Required Tools:"

for cmd in jq tmux claude; do
    if command -v $cmd >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC} $cmd is installed"
    else
        echo -e "${YELLOW}⚠️${NC}  $cmd is NOT installed (optional but recommended)"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}🎉 RALPH Setup: VERIFIED ✅${NC}"
    echo ""
    echo "All components are properly installed and ready to use."
    echo ""
    echo "Start RALPH with:"
    echo "  cd /Users/mpriessner/windsurf_repos/VeepaAudioTest"
    echo "  .ralph/ralph_loop.sh --monitor"
    echo ""
    echo "Expected completion: 8-10.5 hours for 27 sub-stories"
else
    echo -e "${RED}❌ RALPH Setup: ISSUES FOUND${NC}"
    echo ""
    echo "Found $ERRORS error(s). Please fix the issues above before running RALPH."
    echo ""
    echo "Common fixes:"
    echo "  chmod +x .ralph/*.sh           # Make scripts executable"
    echo "  brew install jq tmux           # Install required tools"
    exit 1
fi
