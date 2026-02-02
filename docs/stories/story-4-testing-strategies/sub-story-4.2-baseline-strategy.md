# Sub-Story 4.2: Baseline Strategy Implementation

**Goal**: Implement baseline strategy (current approach that produces error -50)

**Estimated Time**: 15-20 minutes

---

## 📋 Analysis of Approach

The baseline strategy represents our current implementation from Story 3:
- Standard AVAudioSession configuration
- playAndRecord category with defaultToSpeaker
- videoChat mode
- System's default sample rate (usually 48000 Hz)
- **Expected outcome**: Error -50 (kAudioUnitErr_FormatNotSupported)

This strategy serves as the control group for comparing other approaches.

---

## 🛠️ Implementation Steps

### Step 4.2.1: Create BaselineStrategy.swift (12 min)

Create `ios/VeepaAudioTest/VeepaAudioTest/Strategies/BaselineStrategy.swift`:

```swift
// ADAPTED FROM: Story 3 AudioStreamService configureAudioSession method
import Foundation
import AVFoundation

/// Baseline strategy using standard AVAudioSession configuration
/// This is expected to fail with error -50 because the system's default
/// sample rate (48kHz) is incompatible with the SDK's G.711 codec (8kHz)
class BaselineStrategy: AudioSessionStrategy {
    // MARK: - Protocol Properties

    let name = "Baseline"

    let description = "Standard AVAudioSession setup (expected to fail with error -50)"

    // MARK: - Protocol Methods

    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        print("[Baseline] 🔧 Configuring AVAudioSession...")

        do {
            // Standard configuration
            try session.setCategory(
                .playAndRecord,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setMode(.videoChat)
            try session.setActive(true)

            print("[Baseline] ✅ AVAudioSession configured")
            print("[Baseline]    Category: \(session.category.rawValue)")
            print("[Baseline]    Mode: \(session.mode.rawValue)")
            print("[Baseline]    Sample Rate: \(session.sampleRate) Hz")
            print("[Baseline]    IO Buffer Duration: \(session.ioBufferDuration * 1000) ms")

            // Log full state for diagnostics
            logAudioSessionState(prefix: "Baseline")

        } catch {
            print("[Baseline] ❌ Configuration failed: \(error.localizedDescription)")
            throw AudioSessionStrategyError.configurationFailed(error.localizedDescription)
        }
    }

    func cleanupAudioSession() {
        print("[Baseline] 🧹 Cleaning up AVAudioSession...")

        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
            print("[Baseline] ✅ AVAudioSession deactivated")
        } catch {
            print("[Baseline] ⚠️ Deactivation warning: \(error.localizedDescription)")
        }
    }
}
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest

# Check file created
ls -la VeepaAudioTest/Strategies/BaselineStrategy.swift
# Expected: File exists (~70 lines)

# Verify protocol conformance
grep -n "class BaselineStrategy: AudioSessionStrategy" VeepaAudioTest/Strategies/BaselineStrategy.swift
# Expected: Class declaration found

# Build
xcodegen generate
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

### Step 4.2.2: Add Documentation Comment (3 min)

The strategy includes inline documentation explaining why error -50 is expected:

**Key Points in Code Comments:**
```swift
/// This is expected to fail with error -50 because the system's default
/// sample rate (48kHz) is incompatible with the SDK's G.711 codec (8kHz)
```

This helps future developers understand that the baseline failure is by design.

---

### Step 4.2.3: Test Baseline Strategy Compiles (3 min)

```bash
cd ios/VeepaAudioTest

# Full rebuild
xcodebuild clean -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest

xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

## ✅ Sub-Story 4.2 Complete Verification

Run all checks:

```bash
cd ios/VeepaAudioTest

# 1. File exists
ls -la VeepaAudioTest/Strategies/BaselineStrategy.swift
# ✅ Expected: File present

# 2. Implements protocol
grep -n "AudioSessionStrategy" VeepaAudioTest/Strategies/BaselineStrategy.swift
# ✅ Expected: Protocol conformance declared

# 3. Has required methods
grep -n "func prepareAudioSession" VeepaAudioTest/Strategies/BaselineStrategy.swift
grep -n "func cleanupAudioSession" VeepaAudioTest/Strategies/BaselineStrategy.swift
# ✅ Expected: Both methods found

# 4. Has name and description
grep -n "let name" VeepaAudioTest/Strategies/BaselineStrategy.swift
grep -n "let description" VeepaAudioTest/Strategies/BaselineStrategy.swift
# ✅ Expected: Both properties found

# 5. Uses logging helper
grep -n "logAudioSessionState" VeepaAudioTest/Strategies/BaselineStrategy.swift
# ✅ Expected: Helper method called

# 6. Builds successfully
xcodegen generate
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# ✅ Expected: BUILD SUCCEEDED
```

---

## 🎯 Acceptance Criteria

- [ ] BaselineStrategy class created
- [ ] Implements AudioSessionStrategy protocol
- [ ] Standard AVAudioSession configuration (playAndRecord, videoChat)
- [ ] Comprehensive logging of session state
- [ ] Expected to produce error -50
- [ ] cleanupAudioSession() deactivates session properly
- [ ] File compiles without errors

---

## 🚨 Expected Test Results

When this strategy is tested in Sub-Story 4.6:

**Expected Console Output:**
```
[Baseline] 🔧 Configuring AVAudioSession...
[Baseline] ✅ AVAudioSession configured
[Baseline]    Category: AVAudioSessionCategoryPlayAndRecord
[Baseline]    Mode: AVAudioSessionModeVideoChat
[Baseline]    Sample Rate: 48000.0 Hz
[Baseline]    IO Buffer Duration: 10.0 ms
[Baseline] 📊 Audio Session State:
[Baseline]    Category: AVAudioSessionCategoryPlayAndRecord
[Baseline]    Mode: AVAudioSessionModeVideoChat
[Baseline]    Sample Rate: 48000.0 Hz
[Baseline]    Preferred Sample Rate: 48000.0 Hz
[Baseline]    Input Channels: 1
[Baseline]    Output Channels: 2
[Baseline]    Outputs:
[Baseline]       - Speaker (Speaker)

[Flutter] ❌ startAudio failed: Error -50 (kAudioUnitErr_FormatNotSupported)
```

**Why it fails:**
- System sample rate: 48000 Hz
- SDK expects: 8000 Hz (G.711 codec)
- AudioUnit cannot convert formats → Error -50

---

## 🔗 Navigation

- ← Previous: [Sub-Story 4.1: Audio Session Protocol](sub-story-4.1-audio-session-protocol.md)
- → Next: [Sub-Story 4.3: Pre-Initialize Strategy](sub-story-4.3-pre-initialize-strategy.md)
- ↑ Story Overview: [README.md](README.md)
