# Sub-Story 2.4: Copy Flutter Engine Manager

**Goal**: Copy FlutterEngineManager.swift to handle Flutter engine lifecycle and method channel communication

⏱️ **Estimated Time**: 25-30 minutes

---

## 📋 Overview

The FlutterEngineManager is the iOS-side service that:
- Initializes and manages the Flutter engine
- Sets up method channels for iOS ↔ Flutter communication
- Handles the critical "flutterReady" signal
- Provides async method invocation to Flutter

This is a **critical component** - without it, iOS cannot communicate with Flutter at all.

---

## 🔍 Analysis of Source Code

From `SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Services/Flutter/FlutterEngineManager.swift` (385 lines):

**Key sections discovered**:
- Lines 1-24: Class definition, singleton pattern, @Published properties
- Lines 25-63: Engine initialization and plugin registration (CRITICAL)
- Lines 64-104: VSTC diagnostics (for timeout investigation - can remove for VeepaAudioTest)
- Lines 105-145: initializeAndWaitForReady with timeout (CRITICAL)
- Lines 147-186: Channel setup (method + event channels)
- Lines 187-280: Method call handler (processes flutterReady, delegates events)
- Lines 281-304: Method invocation (iOS → Flutter)
- Lines 305-361: Credential refresh helpers (for reconnection - can simplify)
- Lines 362-385: Error definitions

**What to adapt:**
- ✅ Keep: Engine initialization, plugin registration, channel setup
- ✅ Keep: flutterReady signal handling, initializeAndWaitForReady
- ✅ Keep: Method invocation (invoke, ping)
- ✏️ Simplify: Remove VSTC diagnostics (not needed for initial audio testing)
- ✏️ Simplify: Remove credential refresh (can add later if needed)
- ✏️ Adapt: Remove video frame event channel
- ✏️ Adapt: Change channel name from "com.scisymbiolens/veepa" → "com.veepatest/audio"

---

## 🛠️ Implementation Steps

### Step 2.4.1: Create Services Directory Structure (2 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest

# Create Services directory
mkdir -p Services/Flutter
```

**✅ Verification:**
```bash
ls -la Services/Flutter/
# Expected: Empty directory created
```

---

### Step 2.4.2: Create Adapted FlutterEngineManager.swift (20 min)

**Adapt from**: `SciSymbioLens/Services/Flutter/FlutterEngineManager.swift`

Create `ios/VeepaAudioTest/VeepaAudioTest/Services/Flutter/FlutterEngineManager.swift`:

```swift
// ADAPTED FROM: SciSymbioLens/Services/Flutter/FlutterEngineManager.swift
// Changes: Simplified for audio-only testing
//   - Removed VSTC diagnostics (not needed for initial testing)
//   - Removed video frame event channel
//   - Removed provisioning event channel
//   - Removed credential refresh helpers (can add later if reconnection fails)
//   - Changed channel name: com.scisymbiolens/veepa → com.veepatest/audio
//
import Foundation
import Flutter

/// Manages the Flutter engine for Veepa camera integration
@MainActor
final class FlutterEngineManager: ObservableObject {
    static let shared = FlutterEngineManager()

    private(set) var engine: FlutterEngine?
    private(set) var methodChannel: FlutterMethodChannel?

    @Published private(set) var isInitialized = false
    @Published private(set) var isFlutterReady = false

    /// External method call handler (for bridges to receive events)
    private var externalMethodCallHandler: FlutterMethodCallHandler?

    private init() {}

    // MARK: - Initialization

    /// Initialize the Flutter engine (non-blocking)
    /// Note: Use initializeAndWaitForReady() if you need to call methods immediately
    func initialize() {
        guard engine == nil else { return }

        let flutterEngine = FlutterEngine(name: "veepa_audio")
        flutterEngine.run()

        // Register Flutter plugins (required for platform channels to work)
        registerPlugins(with: flutterEngine)

        setupChannels(engine: flutterEngine)

        self.engine = flutterEngine
        self.isInitialized = true

        print("[FlutterEngineManager] Engine initialized, waiting for Flutter ready signal...")
    }

    /// Register native plugins with the Flutter engine
    /// This is critical for P2P SDK communication via platform channels
    private func registerPlugins(with engine: FlutterEngine) {
        // Register all Flutter module plugins
        GeneratedPluginRegistrant.register(with: engine)
        print("[FlutterEngineManager] GeneratedPluginRegistrant registered")

        // Register VsdkPlugin (Veepa P2P SDK bridge)
        if let registrar = engine.registrar(forPlugin: "VsdkPlugin") {
            VsdkPlugin.register(with: registrar)
            print("[FlutterEngineManager] ✅ VsdkPlugin registered")
        } else {
            print("[FlutterEngineManager] ❌ WARNING: Failed to get registrar for VsdkPlugin")
        }
    }

    /// Initialize and wait for Flutter to signal it's ready
    /// This ensures the method channel handler is set up before returning
    func initializeAndWaitForReady(timeout: TimeInterval = 10.0) async throws {
        // If already ready, return immediately
        if isFlutterReady {
            print("[FlutterEngineManager] Already ready")
            return
        }

        // Initialize engine if needed
        if !isInitialized {
            initialize()
        }

        // Wait for Flutter ready signal with timeout using polling
        let startTime = Date()
        let pollInterval: UInt64 = 50_000_000 // 50ms

        while !isFlutterReady {
            // Check timeout
            if Date().timeIntervalSince(startTime) > timeout {
                print("[FlutterEngineManager] ⏱️ Timeout waiting for Flutter ready signal")
                throw FlutterBridgeError.flutterNotReady
            }

            try await Task.sleep(nanoseconds: pollInterval)
        }

        print("[FlutterEngineManager] ✅ Flutter ready after \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
    }

    func shutdown() {
        engine?.destroyContext()
        engine = nil
        methodChannel = nil
        isInitialized = false
        isFlutterReady = false
        externalMethodCallHandler = nil
    }

    // MARK: - Channel Setup

    private func setupChannels(engine: FlutterEngine) {
        let messenger = engine.binaryMessenger

        // ADAPTED: Changed channel name from com.scisymbiolens/veepa → com.veepatest/audio
        methodChannel = FlutterMethodChannel(
            name: "com.veepatest/audio",
            binaryMessenger: messenger
        )

        // Set up internal method call handler to catch flutterReady signal
        print("[FlutterEngineManager] Setting up method call handler...")
        methodChannel?.setMethodCallHandler { [weak self] call, result in
            print("[FlutterEngineManager] Received method call: \(call.method)")

            guard let self = self else {
                print("[FlutterEngineManager] Self is nil, returning")
                result(nil)
                return
            }

            Task { @MainActor in
                self.handleMethodCall(call, result: result)
            }
        }
        print("[FlutterEngineManager] Method call handler set up")
    }

    /// Internal method call handler - processes flutterReady and delegates to external handler
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // CRITICAL: Handle flutterReady signal from Flutter
        if call.method == "flutterReady" {
            print("[FlutterEngineManager] ✅ Received flutterReady signal from Flutter")
            isFlutterReady = true
            result(nil)
            return
        }

        // Handle known event methods - these are sent FROM Flutter TO Swift
        // We must return nil (success) to avoid MissingPluginException
        let knownEventMethods = ["connectionEvent", "audioEvent"]
        if knownEventMethods.contains(call.method) {
            // Delegate to external handler if set, otherwise just acknowledge
            if let handler = externalMethodCallHandler {
                handler(call, result)
            } else {
                // No handler set, but we still acknowledge the event to avoid exception
                NSLog("[FlutterEngineManager] Event '%@' received but no handler set", call.method)
                result(nil)
            }
            return
        }

        // Delegate to external handler for other methods
        if let handler = externalMethodCallHandler {
            handler(call, result)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    /// Set a method call handler to receive events from Flutter
    /// Note: flutterReady is handled internally, all other methods are delegated to this handler
    func setMethodCallHandler(_ handler: @escaping FlutterMethodCallHandler) {
        externalMethodCallHandler = handler
    }

    // MARK: - Method Calls (iOS → Flutter)

    /// Invoke a method on Flutter and wait for response
    func invoke(_ method: String, arguments: Any? = nil) async throws -> Any? {
        guard let channel = methodChannel else {
            throw FlutterBridgeError.notInitialized
        }

        return try await withCheckedThrowingContinuation { continuation in
            channel.invokeMethod(method, arguments: arguments) { result in
                if let error = result as? FlutterError {
                    continuation.resume(throwing: FlutterBridgeError.methodFailed(error.message ?? "Unknown error"))
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }

    /// Simple ping test to verify communication
    func ping() async throws -> String {
        let result = try await invoke("ping")
        return result as? String ?? "no response"
    }
}

// MARK: - Errors

enum FlutterBridgeError: Error, LocalizedError {
    case notInitialized
    case flutterNotReady
    case methodFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Flutter engine not initialized"
        case .flutterNotReady:
            return "Flutter channel not ready (timeout waiting for ready signal)"
        case .methodFailed(let reason):
            return "Flutter method failed: \(reason)"
        case .invalidResponse:
            return "Invalid response from Flutter"
        }
    }
}
```

**Key adaptations**:
- ✅ Kept: Core engine management, plugin registration, ready signal
- ❌ Removed: VSTC diagnostics (67 lines removed)
- ❌ Removed: Video frame event channel
- ❌ Removed: Provisioning event channel
- ❌ Removed: Credential refresh helpers (55 lines removed)
- ✏️ Changed: Channel name to "com.veepatest/audio"

**Result**: 220 lines (down from 385 lines, 43% reduction)

---

### Step 2.4.3: Verify Swift File (3 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest

# Verify file created
test -f Services/Flutter/FlutterEngineManager.swift && echo "✅ FlutterEngineManager.swift created"

# Check line count
wc -l Services/Flutter/FlutterEngineManager.swift
# Expected: ~220 lines

# Check for key patterns
grep "com.veepatest/audio" Services/Flutter/FlutterEngineManager.swift
# ✅ Expected: Found (adapted channel name)

grep "flutterReady" Services/Flutter/FlutterEngineManager.swift
# ✅ Expected: Found (ready signal handling)

grep "VsdkPlugin.register" Services/Flutter/FlutterEngineManager.swift
# ✅ Expected: Found (plugin registration)
```

---

### Step 2.4.4: Update project.yml to Include New File (3 min)

Edit `ios/VeepaAudioTest/project.yml` to add the new file:

```yaml
targets:
  VeepaAudioTest:
    sources:
      - path: VeepaAudioTest
        # Xcode will recursively include all .swift files
        # FlutterEngineManager.swift will be picked up automatically
```

Since XcodeGen recursively includes all Swift files in the path, the new file will be automatically included. No changes needed!

**✅ Verification:**
```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest

# Regenerate Xcode project
xcodegen generate

# Check if file appears in project
grep -r "FlutterEngineManager" VeepaAudioTest.xcodeproj/project.pbxproj
# ✅ Expected: Found (file included in project)
```

---

## ✅ Sub-Story 2.4 Verification

Run these tests to verify everything works:

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest

# 1. File exists with correct content
test -f VeepaAudioTest/Services/Flutter/FlutterEngineManager.swift && echo "✅ File exists"

# 2. File contains adapted channel name
grep -q "com.veepatest/audio" VeepaAudioTest/Services/Flutter/FlutterEngineManager.swift && echo "✅ Channel name adapted"

# 3. File contains plugin registration
grep -q "VsdkPlugin.register" VeepaAudioTest/Services/Flutter/FlutterEngineManager.swift && echo "✅ Plugin registration present"

# 4. VSTC diagnostics removed (should NOT be found)
! grep -q "runVSTCDiagnostics" VeepaAudioTest/Services/Flutter/FlutterEngineManager.swift && echo "✅ Diagnostics removed"

# 5. Xcode project regenerates successfully
xcodegen generate
# ✅ Expected: No errors

# 6. Project compiles (quick syntax check)
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  clean build | tail -n 1
# ✅ Expected: "** BUILD SUCCEEDED **"
```

---

## 🎯 Acceptance Criteria

- [ ] Services/Flutter/ directory created
- [ ] FlutterEngineManager.swift created (~220 lines)
- [ ] Channel name changed to "com.veepatest/audio"
- [ ] Plugin registration (VsdkPlugin) present
- [ ] flutterReady signal handling present
- [ ] VSTC diagnostics removed
- [ ] Video/provisioning event channels removed
- [ ] Credential refresh helpers removed
- [ ] File compiles without errors
- [ ] Xcode project includes new file

---

## 📝 What We Built

**FlutterEngineManager** now provides:
- ✅ Flutter engine initialization and lifecycle
- ✅ Platform channel setup (method channel)
- ✅ Critical flutterReady signal handling
- ✅ Plugin registration (including VsdkPlugin for P2P SDK)
- ✅ Async method invocation (iOS → Flutter)
- ✅ Method call handling (Flutter → iOS)

**Simplified from source**:
- Removed 165 lines of non-essential code (43% reduction)
- Kept all critical functionality for audio testing
- Ready for audio control in Story 3

---

## 🔗 Navigation

← **Previous**: [Sub-Story 2.3 - Update Main Dart Entry Point](sub-story-2.3-main-dart.md)
→ **Next**: [Sub-Story 2.5 - Copy VSTCBridge](sub-story-2.5-vstc-bridge.md)
↑ **Story Overview**: [Story 2 README](README.md)

---

**Created**: 2026-02-02
**Adapted From**: SciSymbioLens FlutterEngineManager.swift (385 lines → 220 lines)
