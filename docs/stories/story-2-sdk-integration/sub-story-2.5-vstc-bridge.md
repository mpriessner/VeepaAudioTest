# Sub-Story 2.5: Copy VSTCBridge for SDK Symbol Access

**Goal**: Copy VSTCBridge.swift for low-level SDK symbol access (advanced debugging feature)

⏱️ **Estimated Time**: 15-20 minutes

---

## 📋 Overview

The VSTCBridge provides **advanced SDK diagnostics** by accessing internal symbols in libVSTC.a using `dlsym()`. This is used for:
- Reading internal timeout variables
- Modifying keep-alive intervals
- Calling internal SDK functions

**For VeepaAudioTest**: This is **optional** but useful for debugging. We'll copy it for potential use in troubleshooting audio issues.

---

## 🔍 Analysis of Source Code

From `SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Services/VSTCBridge.swift` (408 lines):

**Key sections**:
- Lines 1-56: Symbol resolution via dlsym (lookup SDK internal symbols)
- Lines 57-200: Timeout variable access (sessionAliveSeconds, listenTimeout, etc.)
- Lines 201-280: P2P keep-alive functions (Send_Pkt_Alive, CSession_Maintain)
- Lines 281-350: Parameter discovery (GlobalParamsGet/Set)
- Lines 351-408: Diagnostics reporting

**What to adapt:**
- ✅ **Copy exactly** - This is low-level SDK access code
- ✅ Cannot modify - dlsym symbol names must match SDK exactly
- ✅ Safe to copy - Only reads/writes app memory, doesn't touch camera

**Why copy exactly?**
- Symbol names are hardcoded in libVSTC.a
- Any typo breaks functionality
- This is advanced debugging code, not core functionality

---

## 🛠️ Implementation Steps

### Step 2.5.1: Copy VSTCBridge.swift (5 min)

**Copy from**: `SciSymbioLens/Services/VSTCBridge.swift`

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest

# Copy VSTCBridge exactly (no modifications)
cp /Users/mpriessner/windsurf_repos/SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Services/VSTCBridge.swift \
   Services/

echo "✅ VSTCBridge.swift copied"
```

**✅ Verification:**
```bash
# Verify file copied
test -f Services/VSTCBridge.swift && echo "✅ VSTCBridge.swift exists"

# Check file size (should be ~408 lines)
wc -l Services/VSTCBridge.swift
# Expected: ~408 lines

# Check for key symbol names
grep "cs2p2p_gSessAliveSec" Services/VSTCBridge.swift
grep "Send_Pkt_Alive" Services/VSTCBridge.swift
# ✅ Expected: Both found
```

---

### Step 2.5.2: Verify Compilation (5 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest

# Regenerate Xcode project (includes new file)
xcodegen generate

# Test compilation
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  build | tail -n 1
# ✅ Expected: "** BUILD SUCCEEDED **"
```

---

### Step 2.5.3: Add Bridging Header Comment (Optional, 3 min)

Add a comment to document what VSTCBridge does.

Edit `ios/VeepaAudioTest/VeepaAudioTest/Services/VSTCBridge.swift` - add comment at top:

```swift
// COPIED EXACTLY FROM: SciSymbioLens/Services/VSTCBridge.swift
// Purpose: Advanced SDK diagnostics via dlsym symbol access
// Use: Optional - for debugging P2P session timeouts and keep-alive
//
// THIS FILE MUST BE COPIED EXACTLY - DO NOT MODIFY SYMBOL NAMES
// Symbol names must match libVSTC.a internal implementation
//
import Foundation
import Darwin
// ... rest of file unchanged ...
```

---

## ✅ Sub-Story 2.5 Verification

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest

# 1. File exists
test -f Services/VSTCBridge.swift && echo "✅ File exists"

# 2. File has correct line count (~408 lines)
LINES=$(wc -l < Services/VSTCBridge.swift)
if [ $LINES -gt 400 ] && [ $LINES -lt 420 ]; then
  echo "✅ File has ~408 lines ($LINES)"
else
  echo "⚠️ Line count unexpected: $LINES (expected ~408)"
fi

# 3. Key symbols present
grep -q "cs2p2p_gSessAliveSec" Services/VSTCBridge.swift && echo "✅ Session timeout symbols present"
grep -q "Send_Pkt_Alive" Services/VSTCBridge.swift && echo "✅ Keep-alive functions present"

# 4. Project compiles
cd ../
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  clean build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)"
# ✅ Expected: "** BUILD SUCCEEDED **"
```

---

## 🎯 Acceptance Criteria

- [ ] VSTCBridge.swift copied (408 lines)
- [ ] File copied exactly (no modifications to symbol names)
- [ ] Comment added explaining purpose
- [ ] File compiles without errors
- [ ] Symbol names unchanged: cs2p2p_gSessAliveSec, Send_Pkt_Alive, etc.

---

## 📝 What We Built

**VSTCBridge** provides:
- ✅ dlsym-based symbol resolution for libVSTC.a internals
- ✅ Read/write access to timeout variables
- ✅ Direct calls to internal keep-alive functions
- ✅ SDK parameter discovery (GlobalParamsGet/Set)
- ✅ Comprehensive diagnostics reporting

**Use cases for VeepaAudioTest**:
- Debug P2P session timeouts (if connection drops after 3 minutes)
- Investigate keep-alive mechanisms
- Modify timeout thresholds dynamically
- **Not needed for basic audio testing** - but useful if issues arise

---

## 🚨 Important Notes

### Why Copy Exactly?

VSTCBridge uses `dlsym()` to look up symbols by name in libVSTC.a:
```swift
dlsym(handle, "cs2p2p_gSessAliveSec")  // Must match SDK exactly
```

If symbol names don't match the SDK's internal names **exactly**, lookups fail silently. This is low-level code that must be copied verbatim.

### Safety

VSTCBridge is **safe** because:
- Only reads/writes app memory (not camera firmware)
- `dlsym()` only accesses our own process
- Cannot damage hardware or firmware
- Used by SciSymbioLens in production

### When to Use

VSTCBridge is useful for:
- **Debugging connection timeouts** (if P2P drops after 3 minutes)
- **Investigating keep-alive** (understand SDK's ping mechanism)
- **Advanced troubleshooting** (when standard logs aren't enough)

For basic audio testing in VeepaAudioTest, you likely **won't need** VSTCBridge initially. But it's valuable to have available if audio issues are related to connection stability.

---

## 🔗 Navigation

← **Previous**: [Sub-Story 2.4 - Copy Flutter Engine Manager](sub-story-2.4-flutter-engine-manager.md)
→ **Next**: [Sub-Story 2.6 - Create Simplified Connection Bridge](sub-story-2.6-connection-bridge.md)
↑ **Story Overview**: [Story 2 README](README.md)

---

**Created**: 2026-02-02
**Copied From**: SciSymbioLens VSTCBridge.swift (exact copy, 408 lines)
