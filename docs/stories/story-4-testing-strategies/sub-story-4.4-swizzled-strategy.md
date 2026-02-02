# Sub-Story 4.4: Swizzled Strategy Implementation

**Goal**: Implement method swizzling strategy to intercept and force 8kHz audio format

**Estimated Time**: 25-30 minutes

---

## 📋 Analysis of Approach

The swizzled strategy uses Objective-C runtime method swizzling to intercept calls to `setPreferredSampleRate:` and force 8kHz regardless of what the SDK requests.

**How Method Swizzling Works:**
1. At runtime, we swap the implementation of `setPreferredSampleRate:` with our custom version
2. When SDK calls `setPreferredSampleRate(48000)`, our method intercepts it
3. Our method calls the original implementation but with `8000` instead
4. SDK thinks it set 48kHz, but system actually uses 8kHz

**Risks:**
- Invasive technique that modifies system behavior
- Could interfere with other audio code
- Should only be used as last resort

---

## 🛠️ Implementation Steps

### Step 4.4.1: Create SwizzledStrategy.swift (20 min)

Create `ios/VeepaAudioTest/VeepaAudioTest/Strategies/SwizzledStrategy.swift`:

```swift
// ADAPTED FROM: Story 4 original Swizzled strategy design
import Foundation
import AVFoundation
import ObjectiveC

/// Swizzled strategy: Method swizzling to force 8kHz audio format
/// Intercepts calls to setPreferredSampleRate: and forces 8000 Hz
/// This is an invasive technique that modifies AVAudioSession behavior at runtime
class SwizzledStrategy: AudioSessionStrategy {
    // MARK: - Protocol Properties

    let name = "Swizzled"

    let description = "Method swizzling to force 8kHz sample rate (intercepts SDK calls)"

    // MARK: - State

    private static var didSwizzle = false

    // MARK: - Protocol Methods

    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        // Install swizzling ONCE (before any audio session calls)
        if !Self.didSwizzle {
            print("[Swizzle] 🔀 Installing method swizzling...")
            installSwizzling()
            Self.didSwizzle = true
            print("[Swizzle] ✅ Method swizzling installed")
        }

        // Standard configuration (our swizzled methods will intercept)
        print("[Swizzle] 🔧 Configuring AVAudioSession (with swizzling active)...")

        do {
            try session.setCategory(
                .playAndRecord,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setMode(.videoChat)

            // Try to set preferred rate (will be intercepted by our swizzled method)
            try session.setPreferredSampleRate(8000)
            try session.setPreferredIOBufferDuration(0.02)

            try session.setActive(true)

            print("[Swizzle] ✅ AVAudioSession activated")
            print("[Swizzle]    Sample Rate: \(session.sampleRate) Hz")
            print("[Swizzle]    IO Buffer: \(session.ioBufferDuration * 1000) ms")

            // Check if swizzling worked
            if session.sampleRate == 8000 {
                print("[Swizzle] ✅ SUCCESS! Swizzling forced 8kHz sample rate")
            } else {
                print("[Swizzle] ⚠️ Swizzling didn't affect sample rate: \(session.sampleRate) Hz")
            }

            // Log full state
            logAudioSessionState(prefix: "Swizzle")

        } catch {
            print("[Swizzle] ❌ Configuration failed: \(error.localizedDescription)")
            throw AudioSessionStrategyError.configurationFailed(error.localizedDescription)
        }
    }

    func cleanupAudioSession() {
        print("[Swizzle] 🧹 Cleaning up AVAudioSession...")

        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
            print("[Swizzle] ✅ AVAudioSession deactivated")
        } catch {
            print("[Swizzle] ⚠️ Deactivation warning: \(error.localizedDescription)")
        }

        // NOTE: Swizzling persists for app lifetime - cannot be undone safely
        print("[Swizzle] ⚠️ Method swizzling remains active (restart app to reset)")
    }

    // MARK: - Swizzling Implementation

    private func installSwizzling() {
        // Swizzle setPreferredSampleRate: to force 8000 Hz
        let originalSelector = #selector(AVAudioSession.setPreferredSampleRate(_:))
        let swizzledSelector = #selector(AVAudioSession.swizzled_setPreferredSampleRate(_:))

        guard let originalClass = object_getClass(AVAudioSession.sharedInstance()) else {
            print("[Swizzle] ❌ Failed to get AVAudioSession class")
            return
        }

        guard let originalMethod = class_getInstanceMethod(originalClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(originalClass, swizzledSelector) else {
            print("[Swizzle] ❌ Failed to get methods for swizzling")
            return
        }

        // Swap implementations
        method_exchangeImplementations(originalMethod, swizzledMethod)
        print("[Swizzle] ✅ Swizzled setPreferredSampleRate:")
    }
}

// MARK: - AVAudioSession Extension (Swizzled Methods)

extension AVAudioSession {
    /// Swizzled version of setPreferredSampleRate:
    /// This method REPLACES the original at runtime
    /// The naming is intentional - Swift will swap implementations
    @objc dynamic func swizzled_setPreferredSampleRate(_ sampleRate: Double) throws {
        print("[Swizzle] 🎵 Intercepted setPreferredSampleRate(\(sampleRate))")

        // Force 8000 Hz regardless of requested rate
        let forcedRate: Double = 8000

        if sampleRate != forcedRate {
            print("[Swizzle]    Forcing: \(sampleRate) Hz → \(forcedRate) Hz")
        }

        // Call original implementation (which is now named "swizzled_setPreferredSampleRate")
        // This is NOT recursive - method_exchangeImplementations swapped the names
        try self.swizzled_setPreferredSampleRate(forcedRate)
    }
}
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest

# Check file created
ls -la VeepaAudioTest/Strategies/SwizzledStrategy.swift
# Expected: File exists (~130 lines)

# Build
xcodegen generate
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

### Step 4.4.2: Add Swizzling Safety Notes (3 min)

The code already includes safety warnings:
- Swizzling can only be done once per app lifetime
- Cannot be safely undone without app restart
- May interfere with other audio code

These are documented in `cleanupAudioSession()` with warning logs.

---

### Step 4.4.3: Test Swizzling Compiles (3 min)

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

## ✅ Sub-Story 4.4 Complete Verification

Run all checks:

```bash
cd ios/VeepaAudioTest

# 1. File exists
ls -la VeepaAudioTest/Strategies/SwizzledStrategy.swift
# ✅ Expected: File present

# 2. Has swizzling implementation
grep -n "method_exchangeImplementations" VeepaAudioTest/Strategies/SwizzledStrategy.swift
# ✅ Expected: Swizzling code found

# 3. Has swizzled method in extension
grep -n "swizzled_setPreferredSampleRate" VeepaAudioTest/Strategies/SwizzledStrategy.swift
# ✅ Expected: Found in both class and extension

# 4. Forces 8kHz
grep -n "forcedRate: Double = 8000" VeepaAudioTest/Strategies/SwizzledStrategy.swift
# ✅ Expected: Hardcoded 8kHz found

# 5. Has swizzle guard
grep -n "didSwizzle" VeepaAudioTest/Strategies/SwizzledStrategy.swift
# ✅ Expected: Guard variable found

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

- [ ] SwizzledStrategy class created
- [ ] Implements AudioSessionStrategy protocol
- [ ] Method swizzling for setPreferredSampleRate implemented
- [ ] Forces 8000 Hz regardless of SDK requests
- [ ] Swizzle guard (only swizzle once)
- [ ] AVAudioSession extension with swizzled methods
- [ ] Comprehensive logging of interceptions
- [ ] Warning about swizzling persistence
- [ ] File compiles without errors

---

## 🚨 Expected Test Results

**Scenario A: Swizzling Works**
```
[Swizzle] 🔀 Installing method swizzling...
[Swizzle] ✅ Swizzled setPreferredSampleRate:
[Swizzle] ✅ Method swizzling installed
[Swizzle] 🔧 Configuring AVAudioSession (with swizzling active)...
[Swizzle] 🎵 Intercepted setPreferredSampleRate(8000.0)
[Swizzle] ✅ AVAudioSession activated
[Swizzle]    Sample Rate: 8000.0 Hz
[Swizzle] ✅ SUCCESS! Swizzling forced 8kHz sample rate

[Flutter] startVoice result: 0
[Flutter] ✅ Audio started successfully
```

**Scenario B: Swizzling Doesn't Help**
```
[Swizzle] 🔀 Installing method swizzling...
[Swizzle] ✅ Method swizzling installed
[Swizzle] 🔧 Configuring AVAudioSession (with swizzling active)...
[Swizzle] 🎵 Intercepted setPreferredSampleRate(8000.0)
[Swizzle] ✅ AVAudioSession activated
[Swizzle]    Sample Rate: 48000.0 Hz
[Swizzle] ⚠️ Swizzling didn't affect sample rate: 48000.0 Hz

[Flutter] ❌ startAudio failed: Error -50
```

**Important**: This strategy requires **app restart** between tests to reset swizzling state.

---

## 🔗 Navigation

- ← Previous: [Sub-Story 4.3: Pre-Initialize Strategy](sub-story-4.3-pre-initialize-strategy.md)
- → Next: [Sub-Story 4.5: Locked Session Strategy](sub-story-4.5-locked-session-strategy.md)
- ↑ Story Overview: [README.md](README.md)
