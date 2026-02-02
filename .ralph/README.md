# RALPH Loop for VeepaAudioTest

**RALPH** (Recursive Autonomous Loop for Project Handling) - Autonomous AI development agent that implements all 27 sub-stories sequentially using Claude Code.

---

## 🎯 What is RALPH?

RALPH is an autonomous loop that:
1. Feeds Claude Code the PROMPT.md instructions
2. Monitors Claude's responses for progress and completion
3. Automatically proceeds to the next sub-story
4. Tracks progress in @fix_plan.md
5. Exits gracefully when all 27 sub-stories are complete

**Expected outcome**: Complete VeepaAudioTest implementation in 8-10.5 hours of autonomous work.

---

## 🚀 Quick Start

### Option 1: With Monitoring (Recommended)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest
.ralph/ralph_loop.sh --monitor
```

This starts RALPH in a tmux session with live monitoring dashboard showing:
- Loop count and API usage
- Current sub-story progress (X/27 complete)
- Real-time logs
- Claude Code execution status

**Controls**:
- `Ctrl+B` then `D` - Detach from tmux session (RALPH keeps running)
- `tmux attach` - Reattach to running session
- `Ctrl+C` - Stop RALPH

### Option 2: Basic Mode

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest
.ralph/ralph_loop.sh
```

Runs RALPH without tmux monitoring.

---

## 📊 Monitoring Progress

### Live Dashboard

If using `--monitor`, you'll see a live dashboard with:

```
╔════════════════════════════════════════════════════════════════════════╗
║                    🤖 RALPH MONITOR - VeepaAudioTest                    ║
║                   Autonomous Story Implementation                      ║
╚════════════════════════════════════════════════════════════════════════╝

┌─ Current Status ────────────────────────────────────────────────────────┐
│ Loop Count:     #15
│ Status:         running
│ Last Action:    completed
│ API Calls:      15/100 this hour
│ Progress:       [███████░░░░░░░░░░░░░░░░░░░░░░░░░] 15%
└─────────────────────────────────────────────────────────────────────────┘

┌─ Story Progress (27 Sub-Stories) ──────────────────────────────────────┐
│ Completed:      8 / 27 (29%)
│ Progress:       [████████░░░░░░░░░░░░░░░░░░░░░] 29%
│ Current:        2.4 - Copy Flutter Engine Manager
└─────────────────────────────────────────────────────────────────────────┘

┌─ Recent Activity ───────────────────────────────────────────────────────┐
│ [2026-02-02 23:45:12] [SUCCESS] ✅ Sub-Story 2.3 complete
│ [2026-02-02 23:45:15] [INFO] Starting Sub-Story 2.4...
│ [2026-02-02 23:46:30] [INFO] ⏳ Claude Code working... (150s elapsed)
└─────────────────────────────────────────────────────────────────────────┘
```

### Check Status Manually

```bash
.ralph/ralph_loop.sh --status
```

Shows current loop count, API usage, and status in JSON format.

### View Progress File

```bash
cat @fix_plan.md
```

Shows checklist of all 27 sub-stories with `[x]` marking completed ones.

---

## 🛠️ Configuration

### Key Settings (in ralph_loop.sh)

```bash
MAX_CALLS_PER_HOUR=100         # API call limit per hour
CLAUDE_TIMEOUT_MINUTES=20      # Timeout per Claude Code execution
VERBOSE_PROGRESS=true          # Show detailed progress logs
```

### Allowed Tools

RALPH restricts Claude Code to safe operations:
- `Write`, `Read`, `Edit` - File operations
- `Bash(git *)` - Git commands only
- `Bash(flutter *)` - Flutter commands only
- `Bash(xcodebuild *)` - Xcode build commands only
- `Bash(xcodegen *)` - XcodeGen commands only
- `Glob`, `Grep` - File searching

**NOT allowed**: Destructive bash commands (`rm -rf`, etc.)

---

## 📁 Files & Structure

```
.ralph/
├── README.md                    # This file
├── PROMPT.md                    # Master instructions for Claude Code
├── ralph_loop.sh                # Main RALPH loop script
├── ralph_monitor.sh             # Live monitoring dashboard
├── lib/                         # Library components
│   ├── circuit_breaker.sh       # Prevents infinite loops
│   ├── response_analyzer.sh     # Analyzes Claude's responses
│   └── date_utils.sh            # Timestamp utilities
├── logs/                        # Execution logs
│   ├── ralph.log                # Main RALPH log
│   └── claude_output_*.log      # Individual Claude Code outputs
├── .status.json                 # Current loop status
├── .progress.json               # Real-time progress data
├── .call_count                  # API call counter
├── .last_reset                  # Rate limit reset timestamp
└── .ralph_session               # Session tracking

../
├── @fix_plan.md                 # Progress checklist (27 sub-stories)
└── docs/stories/                # Detailed sub-story documentation
```

---

## 🔄 How RALPH Works

### Loop Lifecycle

```
1. Initialize
   ↓
2. Read PROMPT.md
   ↓
3. Execute Claude Code with prompt
   ↓
4. Analyze Claude's response
   ├─ Extract status (IN_PROGRESS, COMPLETE, BLOCKED)
   ├─ Extract current sub-story (X.Y)
   ├─ Check EXIT_SIGNAL (true/false)
   └─ Update @fix_plan.md
   ↓
5. Check exit conditions:
   ├─ All 27 sub-stories complete? → EXIT
   ├─ EXIT_SIGNAL: true? → EXIT
   ├─ Circuit breaker triggered? → EXIT
   └─ Rate limit reached? → WAIT
   ↓
6. Loop back to step 2
```

### Exit Conditions

RALPH exits gracefully when:
1. **All sub-stories complete**: @fix_plan.md shows 27/27 `[x]`
2. **EXIT_SIGNAL received**: Claude reports `EXIT_SIGNAL: true` in status
3. **Circuit breaker triggered**: Too many loops with no progress
4. **Manual stop**: User presses Ctrl+C

### Circuit Breaker

Prevents infinite loops by monitoring:
- Consecutive loops with no file changes
- Loops with errors
- Stagnation (same sub-story for 5+ loops)

**Reset circuit breaker**:
```bash
.ralph/ralph_loop.sh --reset-circuit
```

---

## 📝 Status Reporting

Claude Code MUST include this status block at the end of each response:

```markdown
---RALPH_STATUS---
STATUS: IN_PROGRESS | COMPLETE | BLOCKED
CURRENT_STORY: X.Y
SUB_STORY_TITLE: <title>
TASKS_COMPLETED_THIS_LOOP: <number>
FILES_CREATED: <number>
FILES_MODIFIED: <number>
VERIFICATION_STATUS: PASSING | FAILING | PARTIAL
ACCEPTANCE_CRITERIA_MET: X of Y
WORK_TYPE: IMPLEMENTATION | VERIFICATION | DEBUGGING
EXIT_SIGNAL: false | true
NEXT_ACTION: <one line description>
RECOMMENDATION: <next sub-story or verification step>
---END_RALPH_STATUS---
```

RALPH parses this to:
- Track progress
- Update @fix_plan.md
- Determine when to exit

---

## 🧪 Testing RALPH Setup

### 1. Verify Library Files

```bash
ls -la .ralph/lib/
# Should show: circuit_breaker.sh, response_analyzer.sh, date_utils.sh
```

### 2. Test PROMPT.md

```bash
cat .ralph/PROMPT.md | head -20
# Should show "Ralph Development Instructions - VeepaAudioTest"
```

### 3. Dry Run (Status Check)

```bash
.ralph/ralph_loop.sh --status
# Should show: "No status file found. Ralph may not be running."
```

### 4. Check Circuit Breaker

```bash
.ralph/ralph_loop.sh --circuit-status
# Should show: Circuit Breaker: CLOSED (Ready)
```

---

## 🎯 Expected Timeline

| Story | Sub-Stories | Estimated Time | Cumulative |
|-------|-------------|----------------|------------|
| **Story 1** | 1.1-1.6 (6) | 1.5-2 hours | 2 hours |
| **Story 2** | 2.1-2.7 (7) | 2-2.5 hours | 4.5 hours |
| **Story 3** | 3.1-3.8 (8) | 2-3 hours | 7.5 hours |
| **Story 4** | 4.1-4.6 (6) | 2-3 hours | **10.5 hours** |

**Total**: 27 sub-stories in 8-10.5 hours of autonomous implementation.

---

## 🚨 Troubleshooting

### RALPH Not Starting

```bash
# Check PROMPT.md exists
test -f .ralph/PROMPT.md && echo "✅ PROMPT.md found"

# Check library files
ls .ralph/lib/*.sh
# Should show 3 files

# Check permissions
ls -la .ralph/*.sh
# Should show -rwxr-xr-x (executable)
```

### Rate Limit Reached

```bash
# Check current usage
cat .ralph/.call_count
# If >= 100, wait for next hour or adjust limit:

.ralph/ralph_loop.sh --calls 150  # Increase limit
```

### Circuit Breaker Opened

```bash
# Check status
.ralph/ralph_loop.sh --circuit-status

# Reset if needed
.ralph/ralph_loop.sh --reset-circuit
```

### Claude Code Timeout

```bash
# Increase timeout (default: 20 minutes)
.ralph/ralph_loop.sh --timeout 30  # 30 minutes
```

### Session Issues

```bash
# Reset session state
.ralph/ralph_loop.sh --reset-session
```

---

## 🔧 Advanced Usage

### Custom Call Limit

```bash
.ralph/ralph_loop.sh --calls 50  # Limit to 50 calls/hour
```

### Longer Timeout

```bash
.ralph/ralph_loop.sh --timeout 30  # 30-minute timeout for complex tasks
```

### Verbose Mode

```bash
.ralph/ralph_loop.sh --verbose  # Show detailed progress
```

### Background Execution

```bash
# Start in tmux, detach, and let it run
.ralph/ralph_loop.sh --monitor
# Press Ctrl+B then D to detach

# Check progress later
tmux attach
```

---

## 📚 Documentation References

- **PROMPT.md** - Master instructions for Claude Code
- **docs/stories/NAVIGATION_INDEX.md** - Quick links to all 27 sub-stories
- **docs/ENHANCED_STORIES_COMPLETE.md** - Documentation summary
- **docs/DEEP_CODE_ANALYSIS.md** - 4,000+ lines of SciSymbioLens analysis
- **@fix_plan.md** - Progress checklist

---

## 🎉 Success Criteria

**RALPH has successfully completed when**:
- All 27 sub-stories marked `[x]` in @fix_plan.md
- `EXIT_SIGNAL: true` in final status report
- Flutter module builds successfully
- iOS app builds and runs
- All verification tests pass

**Expected deliverables**:
- Working Flutter module (veepa_audio)
- iOS app with XcodeGen configuration
- P2P SDK integrated
- Audio streaming UI complete
- 4 audio strategies implemented
- TEST_RESULTS.md with findings

---

## 📞 Help

### Common Commands

```bash
# Start RALPH with monitoring
.ralph/ralph_loop.sh --monitor

# Check status
.ralph/ralph_loop.sh --status

# Reset circuit breaker
.ralph/ralph_loop.sh --reset-circuit

# View help
.ralph/ralph_loop.sh --help
```

### Log Files

```bash
# Main RALPH log
tail -f .ralph/logs/ralph.log

# Latest Claude Code output
ls -t .ralph/logs/claude_output_*.log | head -1 | xargs cat

# Progress checklist
cat @fix_plan.md
```

---

**Ready to run RALPH!** 🚀

Start with: `.ralph/ralph_loop.sh --monitor`
