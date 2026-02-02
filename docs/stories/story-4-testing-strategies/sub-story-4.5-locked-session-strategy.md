# Sub-Story 4.5: Locked Session Strategy Implementation

**Goal**: Implement strategy that locks audio session configuration to prevent SDK changes

**Estimated Time**: 20-25 minutes

---

## 📋 Analysis of Approach

The locked session strategy pre-configures AVAudioSession with G.711-compatible settings and activates it with high priority, attempting to prevent the SDK from making any subsequent changes.

**Key Idea:**
- Configure ALL audio preferences (sample rate, channels, buffer, mode)
- Activate session BEFORE SDK tries to configure it
- Use highest priority options to lock configuration
- Hope that iOS respects our "first claim" on audio session

**Configuration Details:**
- Sample rate: 8000 Hz (G.711 standard)
- Channels: 1 (mono, both input and output)
- Buffer duration: 20ms (low latency)
- Mode: videoChat (optimized for voice)

---

## 🛠️ Implementation Steps

### Step 4.5.1: Create LockedSessionStrategy.swift (18 min)

Create `ios/VeepaAudioTest/VeepaAudioTest/Strategies/LockedSessionStrategy.swift`:

```swift
// ADAPTED FROM: Story 4 original Locked Session strategy design
import Foundation
import AVFoundation

/// Locked session strategy: Configure and lock audio session to prevent SDK changes
/// Pre-configures with G.711-compatible settings (8kHz mono) and activates with
/// high priority to prevent the SDK from imposing incompatible configuration
class LockedSessionStrategy: AudioSessionStrategy {
    // MARK: - Protocol Properties

    let name = "Locked"

    let description = "Lock audio session with G.711 format (8kHz mono) to prevent SDK changes"

    // MARK: - Protocol Methods

    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        print("[Locked] 🔒 Configuring and locking audio session...")

        do {
            // Set category with ALL relevant options
            try session.setCategory(
                .playAndRecord,
                options: [
                    .defaultToSpeaker,
                    .allowBluetooth,
                    .allowBluetoothA2DP,
                    .mixWithOthers  // Allow mixing with other audio
                ]
            )
            print("[Locked] ✅ Category set with maximum options")

            // Set mode optimized for voice
            try session.setMode(.videoChat)
            print("[Locked] ✅ Mode set to videoChat")

            // Force G.711-compatible audio format
            try session.setPreferredSampleRate(8000)  // G.711 uses 8kHz
            print("[Locked]    Preferred sample rate: 8000 Hz")

            try session.setPreferredIOBufferDuration(0.02)  // 20ms latency
            print("[Locked]    Preferred buffer: 20ms")

            try session.setPreferredInputNumberOfChannels(1)  // Mono input
            print("[Locked]    Preferred input channels: 1")

            try session.setPreferredOutputNumberOfChannels(1)  // Mono output
            print("[Locked]    Preferred output channels: 1")

            // Activate session with NO special options (default priority)
            // The "lock" comes from doing this BEFORE SDK tries to configure
            try session.setActive(true, options: [])

            print("[Locked] ✅ Audio session locked and activated")
            print("[Locked]    Actual sample rate: \(session.sampleRate) Hz")
            print("[Locked]    Actual buffer: \(session.ioBufferDuration * 1000) ms")
            print("[Locked]    Actual input channels: \(session.inputNumberOfChannels)")
            print("[Locked]    Actual output channels: \(session.outputNumberOfChannels)")

            // Verify configuration was accepted
            if session.sampleRate == 8000 {
                print("[Locked] ✅ SUCCESS! Session locked at 8kHz")
            } else {
                print("[Locked] ⚠️ System used \(session.sampleRate) Hz instead of requested 8000 Hz")
            }

            // Log hardware format details
            logHardwareFormat(session)

            // Log full state
            logAudioSessionState(prefix: "Locked")

        } catch {
            print("[Locked] ❌ Configuration failed: \(error.localizedDescription)")
            throw AudioSessionStrategyError.configurationFailed(error.localizedDescription)
        }
    }

    func cleanupAudioSession() {
        print("[Locked] 🧹 Cleaning up and unlocking AVAudioSession...")

        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
            print("[Locked] ✅ AVAudioSession deactivated and unlocked")
        } catch {
            print("[Locked] ⚠️ Deactivation warning: \(error.localizedDescription)")
        }
    }

    // MARK: - Hardware Diagnostics

    private func logHardwareFormat(_ session: AVAudioSession) {
        print("[Locked] 📊 Hardware Audio Format:")

        // Log available inputs
        if let inputs = session.availableInputs {
            print("[Locked]    Available inputs: \(inputs.count)")
            for (index, input) in inputs.enumerated() {
                print("[Locked]       [\(index + 1)] \(input.portName) (\(input.portType.rawValue))")

                // Log data sources if available
                if let dataSources = input.dataSources {
                    for source in dataSources {
                        print("[Locked]           - \(source.dataSourceName)")
                    }
                }
            }
        } else {
            print("[Locked]    Available inputs: None")
        }

        // Log current input
        if let currentInput = session.currentRoute.inputs.first {
            print("[Locked]    Current input: \(currentInput.portName)")
        }

        // Log current output
        if let currentOutput = session.currentRoute.outputs.first {
            print("[Locked]    Current output: \(currentOutput.portName)")
        }

        // Log input latency
        print("[Locked]    Input latency: \(session.inputLatency * 1000) ms")
        print("[Locked]    Output latency: \(session.outputLatency * 1000) ms")
    }
}
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest

# Check file created
ls -la VeepaAudioTest/Strategies/LockedSessionStrategy.swift
# Expected: File exists (~120 lines)

# Build
xcodegen generate
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

### Step 4.5.2: Add Comprehensive Diagnostics (already included)

The strategy includes extensive hardware diagnostics:
- Available audio inputs
- Current input/output routing
- Input/output latency measurements
- Data sources for each input

These diagnostics help understand why configuration might succeed or fail.

---

### Step 4.5.3: Test Locked Strategy Compiles (3 min)

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

## ✅ Sub-Story 4.5 Complete Verification

Run all checks:

```bash
cd ios/VeepaAudioTest

# 1. File exists
ls -la VeepaAudioTest/Strategies/LockedSessionStrategy.swift
# ✅ Expected: File present

# 2. Sets all preferences
grep -n "setPreferredSampleRate(8000)" VeepaAudioTest/Strategies/LockedSessionStrategy.swift
grep -n "setPreferredIOBufferDuration" VeepaAudioTest/Strategies/LockedSessionStrategy.swift
grep -n "setPreferredInputNumberOfChannels" VeepaAudioTest/Strategies/LockedSessionStrategy.swift
grep -n "setPreferredOutputNumberOfChannels" VeepaAudioTest/Strategies/LockedSessionStrategy.swift
# ✅ Expected: All preference setters found

# 3. Has hardware diagnostics
grep -n "logHardwareFormat" VeepaAudioTest/Strategies/LockedSessionStrategy.swift
# ✅ Expected: Diagnostics method found

# 4. Checks for success
grep -n "session.sampleRate == 8000" VeepaAudioTest/Strategies/LockedSessionStrategy.swift
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

- [ ] LockedSessionStrategy class created
- [ ] Implements AudioSessionStrategy protocol
- [ ] Pre-configures with G.711-compatible settings (8kHz mono)
- [ ] Sets all audio preferences (sample rate, channels, buffer)
- [ ] Activates with high priority
- [ ] Logs hardware configuration details
- [ ] Success check: verifies 8kHz was accepted
- [ ] Comprehensive diagnostics (inputs, outputs, latency)
- [ ] File compiles without errors

---

## 🚨 Expected Test Results

**Scenario A: Locked Strategy Works**
```
[Locked] 🔒 Configuring and locking audio session...
[Locked] ✅ Category set with maximum options
[Locked] ✅ Mode set to videoChat
[Locked]    Preferred sample rate: 8000 Hz
[Locked]    Preferred buffer: 20ms
[Locked]    Preferred input channels: 1
[Locked]    Preferred output channels: 1
[Locked] ✅ Audio session locked and activated
[Locked]    Actual sample rate: 8000.0 Hz
[Locked]    Actual buffer: 20.0 ms
[Locked]    Actual input channels: 1
[Locked]    Actual output channels: 1
[Locked] ✅ SUCCESS! Session locked at 8kHz
[Locked] 📊 Hardware Audio Format:
[Locked]    Available inputs: 1
[Locked]       [1] iPhone Microphone (MicrophoneBuiltIn)
[Locked]    Current input: iPhone Microphone
[Locked]    Current output: Speaker
[Locked]    Input latency: 5.8 ms
[Locked]    Output latency: 8.3 ms

[Flutter] startVoice result: 0
[Flutter] ✅ Audio started successfully
```

**Scenario B: System Overrides Configuration**
```
[Locked] 🔒 Configuring and locking audio session...
[Locked] ✅ Audio session locked and activated
[Locked]    Actual sample rate: 48000.0 Hz
[Locked] ⚠️ System used 48000.0 Hz instead of requested 8000 Hz

[Flutter] ❌ startAudio failed: Error -50
```

---

## 🔗 Navigation

- ← Previous: [Sub-Story 4.4: Swizzled Strategy](sub-story-4.4-swizzled-strategy.md)
- → Next: [Sub-Story 4.6: Comprehensive Testing](sub-story-4.6-comprehensive-testing.md)
- ↑ Story Overview: [README.md](README.md)
