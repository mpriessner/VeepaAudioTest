# Sub-Story 3.1: Audio Connection Service

**Goal**: Create AudioConnectionService that wraps VeepaConnectionBridge for SwiftUI integration

**Estimated Time**: 20-25 minutes

---

## 📋 Analysis of Source Code

From `SciSymbioLens/ios/SciSymbioLens/Services/`:
- Services use ObservableObject protocol for SwiftUI integration
- @Published properties trigger UI updates automatically
- Async/await for connection operations
- Debug logging to published arrays for UI display

**What to adapt:**
- ✅ Copy ObservableObject pattern
- ✅ Copy @Published state management
- ✅ Use VeepaConnectionBridge from Story 2
- ✅ Add comprehensive logging
- ❌ Remove: Discovery features, state polling

---

## 🛠️ Implementation Steps

### Step 3.1.1: Create Services Directory (2 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest

# Create Services directory structure
mkdir -p ios/VeepaAudioTest/VeepaAudioTest/Services
```

**✅ Verification:**
```bash
ls -la ios/VeepaAudioTest/VeepaAudioTest/Services/
# Expected: Empty directory created
```

---

### Step 3.1.2: Create AudioConnectionService.swift (15 min)

**Adapt from**: SciSymbioLens service patterns + Story 3 original

Create `ios/VeepaAudioTest/VeepaAudioTest/Services/AudioConnectionService.swift`:

```swift
// ADAPTED FROM: SciSymbioLens service architecture patterns
import Foundation

@MainActor
final class AudioConnectionService: ObservableObject {
    // MARK: - Published State

    @Published var connectionState: ConnectionState = .disconnected
    @Published var clientPtr: Int? = nil
    @Published var debugLogs: [String] = []

    // MARK: - Connection State

    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case error(String)

        var description: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .error(let msg): return "Error: \(msg)"
            }
        }
    }

    // MARK: - Dependencies

    private let flutterEngine = FlutterEngineManager.shared
    private let connectionBridge = VeepaConnectionBridge.shared

    // MARK: - Connection Methods

    func connect(uid: String, serviceParam: String) async {
        log("🔌 Connecting to camera...")
        log("   UID: \(uid)")
        log("   ServiceParam: \(serviceParam.prefix(20))...")

        connectionState = .connecting

        do {
            // Initialize Flutter if needed
            if !flutterEngine.isFlutterReady {
                log("   Initializing Flutter engine...")
                try await flutterEngine.initializeAndWaitForReady(timeout: 10.0)
                log("   ✅ Flutter ready")
            }

            // Connect via VeepaConnectionBridge
            log("   Establishing P2P connection...")
            try await connectionBridge.connect(uid: uid, serviceParam: serviceParam)

            // Get clientPtr
            guard let ptr = connectionBridge.clientPtr else {
                throw NSError(
                    domain: "AudioTest",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Connection succeeded but clientPtr is nil"]
                )
            }

            clientPtr = ptr
            connectionState = .connected
            log("   ✅ Connected! clientPtr: \(ptr)")

            // Notify Flutter of clientPtr
            try await flutterEngine.invoke("setClientPtr", arguments: ptr)
            log("   ✅ Flutter notified of clientPtr")

        } catch {
            connectionState = .error(error.localizedDescription)
            log("   ❌ Connection failed: \(error.localizedDescription)")
        }
    }

    func disconnect() async {
        log("🔌 Disconnecting...")

        do {
            try await connectionBridge.disconnect()
            clientPtr = nil
            connectionState = .disconnected
            log("   ✅ Disconnected")
        } catch {
            log("   ❌ Disconnect error: \(error.localizedDescription)")
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
# Compile check (will add to Xcode project in next step)
cd ios/VeepaAudioTest
xcodegen generate

# Open and build
open VeepaAudioTest.xcodeproj
# In Xcode: Product → Build (Cmd+B)
# Expected: Build succeeds (or specific errors if dependencies missing)
```

---

### Step 3.1.3: Add to Xcode Project via XcodeGen (5 min)

Update `ios/VeepaAudioTest/project.yml` to include Services:

```yaml
# In the targets → VeepaAudioTest → sources section, add:
sources:
  - path: VeepaAudioTest
    name: App
    type: group
  - path: VeepaAudioTest/Services  # ADD THIS
    name: Services
    type: group
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest
xcodegen generate

# Verify Services group appears in Xcode project
open VeepaAudioTest.xcodeproj
# In Xcode Navigator: Should see "Services" group with AudioConnectionService.swift
```

---

## ✅ Sub-Story 3.1 Complete Verification

Run all checks:

```bash
cd ios/VeepaAudioTest

# 1. File exists
ls -la VeepaAudioTest/Services/AudioConnectionService.swift
# ✅ Expected: File present

# 2. Xcode project includes it
xcodegen generate
grep -r "AudioConnectionService" VeepaAudioTest.xcodeproj/
# ✅ Expected: File referenced in project

# 3. Compiles without errors
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
# ✅ Expected: BUILD SUCCEEDED
```

---

## 🎯 Acceptance Criteria

- [ ] AudioConnectionService.swift created (~120 lines)
- [ ] ObservableObject with @Published state
- [ ] ConnectionState enum (disconnected, connecting, connected, error)
- [ ] connect(uid:serviceParam:) async method
- [ ] disconnect() async method
- [ ] Debug logging to published array
- [ ] File added to Xcode project via XcodeGen
- [ ] File compiles without errors

---

## 🔗 Navigation

- ← Previous: [Story 2: SDK Integration](../story-2-sdk-integration/README.md)
- → Next: [Sub-Story 3.2: Audio Stream Service](sub-story-3.2-audio-stream-service.md)
- ↑ Story Overview: [README.md](README.md)
