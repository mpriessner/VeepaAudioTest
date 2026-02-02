# Sub-Story 4.1: Audio Session Strategy Protocol

**Goal**: Create protocol and manager for audio session strategies

**Estimated Time**: 20-25 minutes

---

## 📋 Analysis of Approach

From Story 4 original design:
- Strategy pattern allows testing different audio configurations
- Protocol defines interface for all strategies
- Each strategy can configure AVAudioSession differently
- Strategies are swappable at runtime via UI

**What to implement:**
- ✅ AudioSessionStrategy protocol with required methods
- ✅ Common interface for prepare/cleanup
- ✅ Name and description properties for UI display
- ❌ Remove: Complex factory patterns, dependency injection

---

## 🛠️ Implementation Steps

### Step 4.1.1: Create Strategies Directory (2 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest

# Create Strategies directory
mkdir -p ios/VeepaAudioTest/VeepaAudioTest/Strategies
```

**✅ Verification:**
```bash
ls -la ios/VeepaAudioTest/VeepaAudioTest/Strategies/
# Expected: Empty directory created
```

---

### Step 4.1.2: Create AudioSessionStrategy Protocol (15 min)

Create `ios/VeepaAudioTest/VeepaAudioTest/Strategies/AudioSessionStrategy.swift`:

```swift
// ADAPTED FROM: Story 4 original AudioSessionStrategy design
import Foundation
import AVFoundation

/// Protocol for audio session configuration strategies
/// Each strategy implements a different approach to resolving AudioUnit error -50
protocol AudioSessionStrategy {
    /// Display name for UI picker
    var name: String { get }

    /// Detailed description of strategy approach
    var description: String { get }

    /// Configure audio session BEFORE startVoice() is called
    /// - Throws: Error if configuration fails
    func prepareAudioSession() throws

    /// Clean up audio session AFTER stopVoice() is called
    func cleanupAudioSession()
}

// MARK: - Strategy Error Types

enum AudioSessionStrategyError: Error, LocalizedError {
    case configurationFailed(String)
    case swizzlingFailed(String)
    case unsupportedConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .configurationFailed(let msg):
            return "Audio session configuration failed: \(msg)"
        case .swizzlingFailed(let msg):
            return "Method swizzling failed: \(msg)"
        case .unsupportedConfiguration(let msg):
            return "Unsupported configuration: \(msg)"
        }
    }
}

// MARK: - Logging Helper Extension

extension AudioSessionStrategy {
    /// Helper to log audio session state consistently across strategies
    func logAudioSessionState(prefix: String) {
        let session = AVAudioSession.sharedInstance()

        print("[\(prefix)] 📊 Audio Session State:")
        print("[\(prefix)]    Category: \(session.category.rawValue)")
        print("[\(prefix)]    Mode: \(session.mode.rawValue)")
        print("[\(prefix)]    Sample Rate: \(session.sampleRate) Hz")
        print("[\(prefix)]    Preferred Sample Rate: \(session.preferredSampleRate) Hz")
        print("[\(prefix)]    IO Buffer Duration: \(session.ioBufferDuration * 1000) ms")
        print("[\(prefix)]    Input Channels: \(session.inputNumberOfChannels)")
        print("[\(prefix)]    Output Channels: \(session.outputNumberOfChannels)")

        // Log current route
        let route = session.currentRoute
        if !route.inputs.isEmpty {
            print("[\(prefix)]    Inputs:")
            for input in route.inputs {
                print("[\(prefix)]       - \(input.portName) (\(input.portType.rawValue))")
            }
        }
        if !route.outputs.isEmpty {
            print("[\(prefix)]    Outputs:")
            for output in route.outputs {
                print("[\(prefix)]       - \(output.portName) (\(output.portType.rawValue))")
            }
        }
    }
}
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest

# Check file created
ls -la VeepaAudioTest/Strategies/AudioSessionStrategy.swift
# Expected: File exists (~80 lines)

# Build to check syntax
xcodegen generate
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

### Step 4.1.3: Update project.yml to Include Strategies (5 min)

Update `ios/VeepaAudioTest/project.yml`:

```yaml
targets:
  VeepaAudioTest:
    type: application
    platform: iOS
    deploymentTarget: "15.0"

    sources:
      - path: VeepaAudioTest
        name: App
        type: group
        excludes:
          - "*.md"
          - ".DS_Store"
      - path: VeepaAudioTest/Services
        name: Services
        type: group
      - path: VeepaAudioTest/Views
        name: Views
        type: group
      - path: VeepaAudioTest/Strategies  # ADD THIS
        name: Strategies
        type: group
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest

# Regenerate project
xcodegen generate

# Verify Strategies group in project
grep -r "Strategies" VeepaAudioTest.xcodeproj/project.pbxproj
# Expected: Strategies group referenced

# Build
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

## ✅ Sub-Story 4.1 Complete Verification

Run all checks:

```bash
cd ios/VeepaAudioTest

# 1. Protocol file exists
ls -la VeepaAudioTest/Strategies/AudioSessionStrategy.swift
# ✅ Expected: File present

# 2. Protocol has required members
grep -n "protocol AudioSessionStrategy" VeepaAudioTest/Strategies/AudioSessionStrategy.swift
grep -n "var name: String" VeepaAudioTest/Strategies/AudioSessionStrategy.swift
grep -n "var description: String" VeepaAudioTest/Strategies/AudioSessionStrategy.swift
grep -n "func prepareAudioSession" VeepaAudioTest/Strategies/AudioSessionStrategy.swift
grep -n "func cleanupAudioSession" VeepaAudioTest/Strategies/AudioSessionStrategy.swift
# ✅ Expected: All members found

# 3. Helper extension exists
grep -n "extension AudioSessionStrategy" VeepaAudioTest/Strategies/AudioSessionStrategy.swift
grep -n "func logAudioSessionState" VeepaAudioTest/Strategies/AudioSessionStrategy.swift
# ✅ Expected: Extension with logging helper found

# 4. Project builds
xcodegen generate
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# ✅ Expected: BUILD SUCCEEDED
```

---

## 🎯 Acceptance Criteria

- [ ] AudioSessionStrategy protocol defined
- [ ] Protocol methods: prepareAudioSession(), cleanupAudioSession()
- [ ] Protocol properties: name, description
- [ ] AudioSessionStrategyError enum for error handling
- [ ] Extension with logAudioSessionState() helper
- [ ] Strategies directory created
- [ ] project.yml updated with Strategies group
- [ ] File compiles without errors

---

## 🔗 Navigation

- ← Previous: [Story 3: Camera Connection](../story-3-camera-connection/README.md)
- → Next: [Sub-Story 4.2: Baseline Strategy](sub-story-4.2-baseline-strategy.md)
- ↑ Story Overview: [README.md](README.md)
