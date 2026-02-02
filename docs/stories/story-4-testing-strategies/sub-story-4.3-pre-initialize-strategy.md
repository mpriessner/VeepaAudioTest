# Sub-Story 4.3: Pre-Initialize Strategy Implementation

**Goal**: Implement strategy that configures audio session BEFORE Flutter engine starts

**Estimated Time**: 20-25 minutes

---

## 📋 Analysis of Approach

The pre-initialize strategy tests the hypothesis that setting audio preferences early (before Flutter initializes) might prevent the SDK from imposing incompatible settings.

**Key Idea:**
- Set preferred sample rate to 8000 Hz BEFORE any other audio code runs
- Configure buffer duration and channels early
- Hope that iOS honors these preferences when the SDK starts

**Expected Outcome:**
- System might accept 8kHz as preferred rate
- OR system might still override with 48kHz (device default)

---

## 🛠️ Implementation Steps

### Step 4.3.1: Create PreInitializeStrategy.swift (15 min)

Create `ios/VeepaAudioTest/VeepaAudioTest/Strategies/PreInitializeStrategy.swift`:

```swift
// ADAPTED FROM: Story 4 original Pre-Initialize strategy design
import Foundation
import AVFoundation

/// Pre-initialize strategy: Configure AVAudioSession BEFORE Flutter engine starts
/// Sets G.711-compatible audio format (8kHz mono) as early as possible
/// to prevent SDK from forcing incompatible settings later
class PreInitializeStrategy: AudioSessionStrategy {
    // MARK: - Protocol Properties

    let name = "Pre-Initialize"

    let description = "Configure AVAudioSession BEFORE Flutter engine starts (set 8kHz early)"

    // MARK: - State

    private var didEarlyInitialize = false

    // MARK: - Protocol Methods

    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        // EARLY initialization (do this ONCE, before Flutter engine)
        if !didEarlyInitialize {
            print("[PreInit] 🔧 EARLY audio session configuration (before Flutter)")

            do {
                // Set G.711-compatible format preferences
                try session.setPreferredSampleRate(8000)  // G.711 uses 8kHz
                try session.setPreferredIOBufferDuration(0.02)  // 20ms buffer
                try session.setPreferredInputNumberOfChannels(1)  // Mono input
                try session.setPreferredOutputNumberOfChannels(1)  // Mono output

                print("[PreInit]    Preferred Sample Rate: 8000 Hz")
                print("[PreInit]    Preferred Buffer: 20ms")
                print("[PreInit]    Preferred Channels: 1 (mono)")

                didEarlyInitialize = true
                print("[PreInit] ✅ Early initialization complete")

            } catch {
                print("[PreInit] ⚠️ Early initialization failed: \(error.localizedDescription)")
                // Continue anyway - we'll try again during activation
            }
        }

        // STANDARD activation (same as baseline, but with early prefs set)
        print("[PreInit] 🔧 Activating AVAudioSession...")

        do {
            try session.setCategory(
                .playAndRecord,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setMode(.videoChat)
            try session.setActive(true)

            print("[PreInit] ✅ AVAudioSession activated")
            print("[PreInit]    Actual Sample Rate: \(session.sampleRate) Hz")
            print("[PreInit]    Actual Buffer: \(session.ioBufferDuration * 1000) ms")
            print("[PreInit]    Actual Input Channels: \(session.inputNumberOfChannels)")
            print("[PreInit]    Actual Output Channels: \(session.outputNumberOfChannels)")

            // Check if our preferences were honored
            if session.sampleRate == 8000 {
                print("[PreInit] ✅ SUCCESS! System is using 8kHz sample rate")
            } else {
                print("[PreInit] ⚠️ System overrode our preference: using \(session.sampleRate) Hz instead of 8000 Hz")
            }

            // Log full state
            logAudioSessionState(prefix: "PreInit")

        } catch {
            print("[PreInit] ❌ Activation failed: \(error.localizedDescription)")
            throw AudioSessionStrategyError.configurationFailed(error.localizedDescription)
        }
    }

    func cleanupAudioSession() {
        print("[PreInit] 🧹 Cleaning up AVAudioSession...")

        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
            print("[PreInit] ✅ AVAudioSession deactivated")
        } catch {
            print("[PreInit] ⚠️ Deactivation warning: \(error.localizedDescription)")
        }
    }
}
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest

# Check file created
ls -la VeepaAudioTest/Strategies/PreInitializeStrategy.swift
# Expected: File exists (~100 lines)

# Build
xcodegen generate
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

### Step 4.3.2: Add Early Initialization Hook (8 min)

For this strategy to work optimally, the early initialization should happen at app launch.

Update `ios/VeepaAudioTest/VeepaAudioTest/VeepaAudioTestApp.swift`:

```swift
import SwiftUI

@main
struct VeepaAudioTestApp: App {
    init() {
        print("🚀 VeepaAudioTest app initializing...")

        // OPTIONAL: Trigger early audio session initialization
        // This can help the Pre-Initialize strategy work better
        // Uncomment when testing PreInitializeStrategy:
        // _ = PreInitializeStrategy().prepareAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Note**: We'll actually trigger this via the strategy when selected, not at app launch. This is just documentation of where it *could* be called.

---

## ✅ Sub-Story 4.3 Complete Verification

Run all checks:

```bash
cd ios/VeepaAudioTest

# 1. File exists
ls -la VeepaAudioTest/Strategies/PreInitializeStrategy.swift
# ✅ Expected: File present

# 2. Has early initialization guard
grep -n "didEarlyInitialize" VeepaAudioTest/Strategies/PreInitializeStrategy.swift
# ✅ Expected: State variable found

# 3. Sets 8kHz preference
grep -n "setPreferredSampleRate(8000)" VeepaAudioTest/Strategies/PreInitializeStrategy.swift
# ✅ Expected: 8kHz configuration found

# 4. Checks if preference was honored
grep -n "session.sampleRate == 8000" VeepaAudioTest/Strategies/PreInitializeStrategy.swift
# ✅ Expected: Success check found

# 5. Builds successfully
xcodegen generate
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# ✅ Expected: BUILD SUCCEEDED
```

---

## 🎯 Acceptance Criteria

- [ ] PreInitializeStrategy class created
- [ ] Implements AudioSessionStrategy protocol
- [ ] Sets preferred sample rate to 8000 Hz early
- [ ] Sets preferred buffer duration and channels
- [ ] Initialization guard (only configure once)
- [ ] Logging shows early vs actual configuration
- [ ] Success check: compares actual vs preferred rate
- [ ] File compiles without errors

---

## 🚨 Expected Test Results

**Scenario A: Strategy Works (Ideal)**
```
[PreInit] 🔧 EARLY audio session configuration (before Flutter)
[PreInit]    Preferred Sample Rate: 8000 Hz
[PreInit]    Preferred Buffer: 20ms
[PreInit]    Preferred Channels: 1 (mono)
[PreInit] ✅ Early initialization complete
[PreInit] 🔧 Activating AVAudioSession...
[PreInit] ✅ AVAudioSession activated
[PreInit]    Actual Sample Rate: 8000.0 Hz
[PreInit]    Actual Buffer: 20.0 ms
[PreInit]    Actual Input Channels: 1
[PreInit]    Actual Output Channels: 1
[PreInit] ✅ SUCCESS! System is using 8kHz sample rate

[Flutter] startVoice result: 0
[Flutter] ✅ Audio started successfully
```

**Scenario B: Strategy Fails (System Overrides)**
```
[PreInit] 🔧 EARLY audio session configuration (before Flutter)
[PreInit]    Preferred Sample Rate: 8000 Hz
[PreInit] ✅ Early initialization complete
[PreInit] 🔧 Activating AVAudioSession...
[PreInit] ✅ AVAudioSession activated
[PreInit]    Actual Sample Rate: 48000.0 Hz
[PreInit] ⚠️ System overrode our preference: using 48000.0 Hz instead of 8000 Hz

[Flutter] ❌ startAudio failed: Error -50
```

---

## 🔗 Navigation

- ← Previous: [Sub-Story 4.2: Baseline Strategy](sub-story-4.2-baseline-strategy.md)
- → Next: [Sub-Story 4.4: Swizzled Strategy](sub-story-4.4-swizzled-strategy.md)
- ↑ Story Overview: [README.md](README.md)
