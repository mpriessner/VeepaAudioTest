# Sub-Story 3.2: Audio Stream Service

**Goal**: Create AudioStreamService that wraps Flutter audio methods (startVoice, stopVoice, setMute)

**Estimated Time**: 20-25 minutes

---

## 📋 Analysis of Source Code

From Story 3 original `story-3-camera-connection-audio.md`:
- AudioStreamService calls Flutter methods via FlutterEngineManager
- Configures AVAudioSession before starting audio
- Tracks playing state and mute state
- Logs audio session configuration for debugging

**What to adapt:**
- ✅ Copy AVAudioSession configuration pattern
- ✅ Use FlutterEngineManager.invoke() for method calls
- ✅ Add comprehensive logging with session diagnostics
- ✅ Handle errors gracefully
- ❌ Remove: Video streaming methods

---

## 🛠️ Implementation Steps

### Step 3.2.1: Create AudioStreamService.swift (18 min)

Create `ios/VeepaAudioTest/VeepaAudioTest/Services/AudioStreamService.swift`:

```swift
// ADAPTED FROM: Story 3 original AudioStreamService
import Foundation
import AVFoundation

@MainActor
final class AudioStreamService: ObservableObject {
    // MARK: - Published State

    @Published var isPlaying = false
    @Published var isMuted = false
    @Published var debugLogs: [String] = []

    // MARK: - Dependencies

    private let flutterEngine = FlutterEngineManager.shared
    private var audioSession: AVAudioSession?

    // MARK: - Error Types

    enum AudioError: Error, LocalizedError {
        case notConnected
        case flutterError(String)

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "Camera not connected (no clientPtr)"
            case .flutterError(let msg):
                return "Flutter error: \(msg)"
            }
        }
    }

    // MARK: - Audio Control Methods

    func startAudio() async throws {
        log("🎵 Starting audio...")

        // Configure AVAudioSession
        try configureAudioSession()

        // Call Flutter method
        do {
            let result = try await flutterEngine.invoke("startAudio")
            log("   startVoice result: \(result ?? "nil")")

            isPlaying = true
            log("   ✅ Audio started")

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

            // Deactivate audio session
            deactivateAudioSession()

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

    // MARK: - AVAudioSession Configuration

    private func configureAudioSession() throws {
        log("   Configuring AVAudioSession...")

        let session = AVAudioSession.sharedInstance()
        audioSession = session

        do {
            // Set category to playAndRecord with defaultToSpeaker
            try session.setCategory(
                .playAndRecord,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setMode(.videoChat)
            try session.setActive(true)

            log("   ✅ AVAudioSession configured")
            log("      Category: \(session.category.rawValue)")
            log("      Mode: \(session.mode.rawValue)")
            log("      SampleRate: \(session.sampleRate) Hz")
            log("      IOBufferDuration: \(session.ioBufferDuration * 1000) ms")

        } catch {
            log("   ❌ AVAudioSession configuration failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func deactivateAudioSession() {
        log("   Deactivating AVAudioSession...")

        do {
            try audioSession?.setActive(false, options: .notifyOthersOnDeactivation)
            log("   ✅ AVAudioSession deactivated")
        } catch {
            log("   ⚠️ AVAudioSession deactivation warning: \(error.localizedDescription)")
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

# Regenerate Xcode project to include new file
xcodegen generate

# Build
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

### Step 3.2.2: Verify AVFoundation Import (2 min)

Ensure Bridging Header includes AVFoundation if needed:

```bash
# Check bridging header
cat ios/VeepaAudioTest/VeepaAudioTest/VeepaAudioTest-Bridging-Header.h
```

If AVFoundation is not automatically available, add to `project.yml`:

```yaml
# In targets → VeepaAudioTest → settings:
settings:
  SWIFT_OBJC_BRIDGING_HEADER: VeepaAudioTest/VeepaAudioTest-Bridging-Header.h
  # AVFoundation should be automatically available in Swift
```

**Note**: AVFoundation is a system framework and should be automatically available in Swift files. No explicit import in bridging header needed.

**✅ Verification:**
```bash
# Verify AVFoundation is accessible
cd ios/VeepaAudioTest
xcodegen generate
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: No errors about AVAudioSession
```

---

## ✅ Sub-Story 3.2 Complete Verification

Run all checks:

```bash
cd ios/VeepaAudioTest

# 1. File exists
ls -la VeepaAudioTest/Services/AudioStreamService.swift
# ✅ Expected: File present (~120 lines)

# 2. Contains required methods
grep -n "func startAudio" VeepaAudioTest/Services/AudioStreamService.swift
grep -n "func stopAudio" VeepaAudioTest/Services/AudioStreamService.swift
grep -n "func setMute" VeepaAudioTest/Services/AudioStreamService.swift
# ✅ Expected: All three methods found

# 3. Has AVAudioSession configuration
grep -n "configureAudioSession" VeepaAudioTest/Services/AudioStreamService.swift
# ✅ Expected: Method found

# 4. Compiles without errors
xcodegen generate
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# ✅ Expected: BUILD SUCCEEDED
```

---

## 🎯 Acceptance Criteria

- [ ] AudioStreamService.swift created (~120 lines)
- [ ] ObservableObject with @Published state (isPlaying, isMuted)
- [ ] startAudio() async throws method
- [ ] stopAudio() async throws method
- [ ] setMute(_:) async throws method
- [ ] AVAudioSession configuration in startAudio
- [ ] Debug logging to published array
- [ ] File compiles without errors

---

## 🔗 Navigation

- ← Previous: [Sub-Story 3.1: Audio Connection Service](sub-story-3.1-audio-connection-service.md)
- → Next: [Sub-Story 3.3: ContentView Layout](sub-story-3.3-contentview-layout.md)
- ↑ Story Overview: [README.md](README.md)
