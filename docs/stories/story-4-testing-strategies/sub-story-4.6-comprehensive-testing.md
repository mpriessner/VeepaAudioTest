# Sub-Story 4.6: Comprehensive Testing and Documentation

**Goal**: Test all strategies systematically and document results

**Estimated Time**: 30-40 minutes

---

## 📋 Test Overview

This sub-story involves:
1. Updating AudioStreamService to support strategy selection
2. Adding UI picker for strategy selection
3. Testing each strategy with a real camera
4. Documenting all test results
5. Providing clear recommendation for next steps

---

## 🛠️ Implementation Steps

### Step 4.6.1: Update AudioStreamService with Strategies (12 min)

Update `ios/VeepaAudioTest/VeepaAudioTest/Services/AudioStreamService.swift`:

```swift
// ADAPTED FROM: Story 4 original AudioStreamService with strategy support
import Foundation
import AVFoundation

@MainActor
final class AudioStreamService: ObservableObject {
    // MARK: - Published State

    @Published var isPlaying = false
    @Published var isMuted = false
    @Published var debugLogs: [String] = []
    @Published var currentStrategy: AudioSessionStrategy = BaselineStrategy() {
        didSet {
            log("🔄 Switched to strategy: \(currentStrategy.name)")
            log("   Description: \(currentStrategy.description)")
        }
    }

    // MARK: - Available Strategies

    let strategies: [AudioSessionStrategy] = [
        BaselineStrategy(),
        PreInitializeStrategy(),
        SwizzledStrategy(),
        LockedSessionStrategy()
    ]

    // MARK: - Dependencies

    private let flutterEngine = FlutterEngineManager.shared

    // MARK: - Audio Control Methods

    func startAudio() async throws {
        log("🎵 Starting audio with \(currentStrategy.name) strategy...")

        // Configure AVAudioSession using selected strategy
        do {
            try currentStrategy.prepareAudioSession()
        } catch {
            log("   ❌ Audio session preparation failed: \(error.localizedDescription)")
            throw error
        }

        // Call Flutter method
        do {
            log("   Calling startVoice()...")
            let result = try await flutterEngine.invoke("startAudio")
            log("   startVoice result: \(result ?? "nil")")

            isPlaying = true
            log("   ✅ Audio started successfully")

        } catch {
            log("   ❌ startAudio failed: \(error.localizedDescription)")
            throw error
        }
    }

    func stopAudio() async throws {
        log("🛑 Stopping audio...")

        do {
            let result = try await flutterEngine.invoke("stopAudio")
            log("   stopVoice result: \(result ?? "nil")")

            isPlaying = false
            log("   ✅ Audio stopped")

            // Clean up audio session
            currentStrategy.cleanupAudioSession()

        } catch {
            log("   ❌ stopAudio failed: \(error.localizedDescription)")
            throw error
        }
    }

    func setMute(_ muted: Bool) async throws {
        log("🔇 Setting mute: \(muted)")

        do {
            let result = try await flutterEngine.invoke("setMute", arguments: muted)
            log("   setMute result: \(result ?? "nil")")

            isMuted = muted
            log("   ✅ Mute set to \(muted)")

        } catch {
            log("   ❌ setMute failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Logging

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .none,
            timeStyle: .medium
        )
        let entry = "[\(timestamp)] \(message)"
        debugLogs.append(entry)
        print(entry)
    }
}
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest

# Build
xcodegen generate
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

### Step 4.6.2: Add Strategy Picker to ContentView (10 min)

Update `ios/VeepaAudioTest/VeepaAudioTest/Views/ContentView.swift` to add strategy selection:

Add state variable:
```swift
@State private var selectedStrategyIndex = 0
```

Add new section after audioControlsSection:
```swift
// MARK: - Strategy Selection Section

private var strategySelectionSection: some View {
    VStack(spacing: 12) {
        Text("Test Strategy")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)

        Picker("Audio Strategy", selection: $selectedStrategyIndex) {
            ForEach(audioService.strategies.indices, id: \.self) { index in
                Text(audioService.strategies[index].name)
                    .tag(index)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedStrategyIndex) { _, newIndex in
            audioService.currentStrategy = audioService.strategies[newIndex]
        }
        .disabled(isConnected && audioService.isPlaying)

        Text(audioService.currentStrategy.description)
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)

        // Warning for swizzled strategy
        if audioService.currentStrategy.name == "Swizzled" {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Requires app restart to reset")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }
    .padding()
}
```

Update body to include new section:
```swift
var body: some View {
    NavigationView {
        VStack(spacing: 0) {
            // Connection Section
            connectionSection

            Divider()

            // Strategy Selection Section (ADD THIS)
            strategySelectionSection

            Divider()

            // Audio Controls Section
            audioControlsSection

            Divider()

            // Debug Log Section
            debugLogSection
        }
        .navigationTitle("Veepa Audio Test")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { showingError = false }
        } message: {
            Text(errorMessage)
        }
    }
}
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest

# Build and run
open VeepaAudioTest.xcodeproj
# In Xcode: Run on device, verify strategy picker appears between connection and audio sections
```

---

### Step 4.6.3: Create Test Results Template (5 min)

Create `ios/VeepaAudioTest/TEST_RESULTS_STORY4.md`:

```markdown
# Story 4: Audio Session Strategy Test Results

**Date**: [Current Date]
**Device**: [iPhone model]
**iOS Version**: [Version]
**Camera**: Veepa [Model]
**Camera UID**: [UID]

---

## Test Matrix

| Strategy | Audio Plays? | Error Code | Sample Rate | Notes |
|----------|--------------|------------|-------------|-------|
| Baseline | ❌ / ✅ | -50 / N/A | [Hz] | [notes] |
| Pre-Initialize | ❌ / ✅ | -50 / N/A | [Hz] | [notes] |
| Swizzled | ❌ / ✅ | -50 / N/A | [Hz] | [notes] |
| Locked | ❌ / ✅ | -50 / N/A | [Hz] | [notes] |

---

## Baseline Strategy Test

**Date**: [timestamp]
**Result**: ✅ PASS / ❌ FAIL

### Console Logs
```
[Paste complete console output here]
```

### AVAudioSession State
- Category: [value]
- Mode: [value]
- Sample Rate: [Hz]
- IO Buffer: [ms]
- Input Channels: [number]
- Output Channels: [number]

### Outcome
- [ ] Audio heard
- [ ] Error -50 received
- [ ] Other error: [describe]

---

## Pre-Initialize Strategy Test

**Date**: [timestamp]
**Result**: ✅ PASS / ❌ FAIL

### Console Logs
```
[Paste complete console output here]
```

### AVAudioSession State
- Preferred Sample Rate: [Hz]
- Actual Sample Rate: [Hz]
- [other values]

### Outcome
- [ ] System honored 8kHz preference
- [ ] System overrode with [Hz]
- [ ] Audio playback: [success/fail]

---

## Swizzled Strategy Test

**Date**: [timestamp]
**Result**: ✅ PASS / ❌ FAIL
**App Restarted Before Test**: ✅ YES / ❌ NO

### Console Logs
```
[Paste complete console output here]
```

### Swizzling Diagnostics
- [ ] Method swizzling installed successfully
- [ ] Interception logs visible
- [ ] Sample rate forced to 8kHz
- [ ] Audio playback: [success/fail]

---

## Locked Strategy Test

**Date**: [timestamp]
**Result**: ✅ PASS / ❌ FAIL

### Console Logs
```
[Paste complete console output here]
```

### Hardware Audio Format
- Available inputs: [number]
- Current input: [name]
- Current output: [name]
- Input latency: [ms]
- Output latency: [ms]

---

## Conclusion

### Working Strategy

**Winner**: [Strategy Name] / None

**Why it worked**:
[Explanation of why this approach succeeded]

### Recommendation for SciSymbioLens

**If a strategy worked:**
1. [Step-by-step implementation plan]
2. [Code changes needed]
3. [Testing approach]
4. [Estimated effort: X hours]

**If all strategies failed:**
1. Contact SDK vendor with this minimal reproducible case
2. Provide TEST_RESULTS_STORY4.md and all console logs
3. Consider alternatives:
   - Custom AudioUnit decoder implementation
   - Ship video-only mode
   - Use different camera SDK

### Next Steps

- [ ] [Specific action item 1]
- [ ] [Specific action item 2]
- [ ] [Specific action item 3]
```

---

### Step 4.6.4: Conduct Systematic Testing (20 min)

**Test Procedure for Each Strategy:**

1. **Before Each Test:**
   ```bash
   # For Swizzled strategy, RESTART APP
   # For other strategies, disconnect and clear logs is sufficient
   ```

2. **Test Baseline Strategy:**
   - Open app
   - Select "Baseline" strategy
   - Enter credentials and connect
   - Tap "Start Audio"
   - Capture console logs
   - Document result in TEST_RESULTS_STORY4.md

3. **Test Pre-Initialize Strategy:**
   - Disconnect
   - Select "Pre-Initialize" strategy
   - Connect and start audio
   - Capture console logs
   - Document result

4. **Test Swizzled Strategy:**
   - RESTART APP (important!)
   - Select "Swizzled" strategy
   - Connect and start audio
   - Capture console logs
   - Document result

5. **Test Locked Strategy:**
   - Disconnect (or restart app for clean slate)
   - Select "Locked" strategy
   - Connect and start audio
   - Capture console logs
   - Document result

**For Each Test, Capture:**
- Full console logs (Xcode → View → Debug Area → Show Debug Area)
- Screenshot of UI showing strategy selected
- AVAudioSession state from logs
- Audio outcome (heard audio? error code?)

---

### Step 4.6.5: Document Final Results (10 min)

Complete TEST_RESULTS_STORY4.md with all findings:

1. Fill in test matrix with ✅/❌
2. Paste complete console logs for each strategy
3. Document AVAudioSession states
4. Identify winning strategy (if any)
5. Write clear recommendation for next steps

---

## ✅ Sub-Story 4.6 Complete Verification

All checks must pass:

```bash
cd ios/VeepaAudioTest

# 1. AudioStreamService has strategies
grep -n "let strategies" VeepaAudioTest/Services/AudioStreamService.swift
# ✅ Expected: Array of strategies found

# 2. ContentView has strategy picker
grep -n "strategySelectionSection" VeepaAudioTest/Views/ContentView.swift
# ✅ Expected: Strategy picker section found

# 3. All strategies tested
cat ios/VeepaAudioTest/TEST_RESULTS_STORY4.md
# ✅ Expected: All 4 strategies have test results documented

# 4. Test results are comprehensive
# ✅ Expected: Console logs, AVAudioSession state, and outcomes for each strategy

# 5. Clear recommendation provided
# ✅ Expected: "Conclusion" section identifies winner or next steps
```

---

## 🎯 Acceptance Criteria

- [ ] Updated AudioStreamService with strategy selection
- [ ] Updated ContentView with strategy picker UI
- [ ] All 4 strategies tested with real camera
- [ ] TEST_RESULTS_STORY4.md created with detailed findings
- [ ] Console logs captured for each strategy
- [ ] AVAudioSession state documented for each strategy
- [ ] Test matrix completed
- [ ] Clear recommendation for SciSymbioLens implementation
- [ ] If none work: Minimal reproducible case ready for SDK vendor

---

## 🎉 Story 4 Complete!

**Possible Outcomes:**

### Outcome A: At Least One Strategy Works ✅
- 🎉 Success! You've found a solution to error -50
- Document the winning strategy's implementation details
- Create implementation plan for SciSymbioLens
- Estimated effort: 15-30 minutes to adapt to main app

### Outcome B: All Strategies Fail ❌
- You have a comprehensive minimal reproducible case
- Complete diagnostic data for SDK vendor
- Clear evidence that SDK audio is incompatible with iOS
- Next steps:
  1. Contact SDK vendor with VeepaAudioTest project + TEST_RESULTS_STORY4.md
  2. Explore custom AudioUnit decoder
  3. Consider video-only mode for SciSymbioLens

---

## 🔗 Navigation

- ← Previous: [Sub-Story 4.5: Locked Session Strategy](sub-story-4.5-locked-session-strategy.md)
- ↑ Story Overview: [README.md](README.md)

**🏁 Project Complete!**
