# Sub-Story 2.6: Create Simplified Connection Bridge

**Goal**: Adapt VeepaConnectionBridge.swift for simplified P2P connection management (audio testing only)

⏱️ **Estimated Time**: 20-25 minutes

---

## 📋 Overview

The VeepaConnectionBridge is the iOS-side service that:
- Manages P2P connection state
- Connects to camera using P2P credentials
- Handles disconnect operations
- Tracks connection errors

This bridge is simpler than the source because:
- No state polling (removed 0.5s refresh loop)
- No auto-reconnect logic
- No discovery or provisioning
- Just basic connect/disconnect/error tracking

---

## 🔍 Analysis of Source Code

From `SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Services/Flutter/VeepaConnectionBridge.swift` (340 lines):

**Key sections discovered**:
- Lines 1-45: VeepaConnectionState enum (7 states)
- Lines 46-69: VeepaConnectionError struct
- Lines 70-83: Class definition with @Published properties
- Lines 84-129: Event handler setup (connectionEvent handling)
- Lines 130-194: connectWithCredentials (P2P connection - CRITICAL)
- Lines 195-225: connect(to device) - for discovered devices
- Lines 226-240: disconnect()
- Lines 241-263: startStreaming/stopStreaming
- Lines 264-281: retry() - auto-reconnect
- Lines 282-297: refreshState() - called by polling
- Lines 298-305: reset()
- Lines 306-322: State polling (every 0.5s - REMOVE)
- Lines 323-340: Error definitions

**What to adapt:**
- ✅ Keep: P2P connection methods (connectWithCredentials, disconnect)
- ✅ Keep: Connection state tracking (VeepaConnectionState enum)
- ✅ Keep: Error handling (VeepaConnectionError struct)
- ✅ Keep: Basic event handling from Flutter
- ❌ Remove: State polling (startStatePolling, stopStatePolling, refreshState)
- ❌ Remove: Auto-reconnect (retry method)
- ❌ Remove: Discovery connection (connect(to device))
- ❌ Remove: Streaming methods (handled by audio bridge)
- ✏️ Simplify: Reduce state enum to 4 states (idle, connecting, connected, error)

---

## 🛠️ Implementation Steps

### Step 2.6.1: Create Simplified VeepaConnectionBridge.swift (18 min)

**Adapt from**: `SciSymbioLens/Services/Flutter/VeepaConnectionBridge.swift`

Create `ios/VeepaAudioTest/VeepaAudioTest/Services/Flutter/VeepaConnectionBridge.swift`:

```swift
// ADAPTED FROM: SciSymbioLens/Services/Flutter/VeepaConnectionBridge.swift
// Changes: Simplified for audio-only testing
//   - Removed state polling (no refreshState every 0.5s)
//   - Removed auto-reconnect (retry method)
//   - Removed discovery connection (connect(to device))
//   - Removed streaming methods (startStreaming/stopStreaming - handled by audio bridge)
//   - Simplified state enum: 7 states → 4 states (idle, connecting, connected, error)
//   - Kept: P2P connection (connectWithCredentials), disconnect, error tracking
//
import Foundation
import Flutter

/// Connection state for VeepaAudioTest (simplified)
enum VeepaConnectionState: String, CaseIterable, Equatable {
    case idle          // Not connected
    case connecting    // Connection in progress
    case connected     // Connected and ready
    case error         // Connection failed

    var canConnect: Bool {
        self == .idle || self == .error
    }

    var isConnected: Bool {
        self == .connected
    }

    var displayName: String {
        switch self {
        case .idle:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error:
            return "Connection Failed"
        }
    }
}

/// Connection error from Flutter
struct VeepaConnectionError: Equatable {
    let code: String
    let message: String
    let timestamp: Date

    init(code: String, message: String, timestamp: Date = Date()) {
        self.code = code
        self.message = message
        self.timestamp = timestamp
    }

    init(from dictionary: [String: Any]) {
        self.code = dictionary["code"] as? String ?? "UNKNOWN"
        self.message = dictionary["message"] as? String ?? "Unknown error"
        if let dateString = dictionary["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            self.timestamp = formatter.date(from: dateString) ?? Date()
        } else {
            self.timestamp = Date()
        }
    }
}

/// Bridge for Veepa camera P2P connection (simplified)
@MainActor
final class VeepaConnectionBridge: ObservableObject {
    static let shared = VeepaConnectionBridge()

    @Published private(set) var state: VeepaConnectionState = .idle
    @Published private(set) var lastError: VeepaConnectionError?

    private let engineManager = FlutterEngineManager.shared

    private init() {}

    // MARK: - Event Handling

    /// Set up the event handler for connection events from Flutter
    func setupEventHandler() {
        engineManager.setMethodCallHandler { [weak self] call, result in
            guard let self = self else {
                result(nil)
                return
            }

            Task { @MainActor in
                if call.method == "connectionEvent" {
                    if let args = call.arguments as? [String: Any] {
                        self.handleConnectionEvent(args)
                    }
                    result(nil)
                } else {
                    result(FlutterMethodNotImplemented)
                }
            }
        }
    }

    private func handleConnectionEvent(_ event: [String: Any]) {
        guard let type = event["type"] as? String else { return }

        switch type {
        case "stateChange":
            if let stateName = event["state"] as? String {
                // Map Flutter state to simplified state
                updateStateFromFlutter(stateName)
            }

        case "error":
            if let errorDict = event["error"] as? [String: Any] {
                lastError = VeepaConnectionError(from: errorDict)
                state = .error
            }

        default:
            break
        }
    }

    /// Map Flutter's detailed states to our simplified 4-state model
    private func updateStateFromFlutter(_ flutterState: String) {
        switch flutterState {
        case "disconnected":
            state = .idle
        case "connecting", "reconnecting":
            state = .connecting
        case "connected", "streaming":
            state = .connected
        case "error":
            state = .error
        default:
            NSLog("[VeepaConnectionBridge] Unknown Flutter state: \(flutterState)")
        }
    }

    // MARK: - Public API

    /// Connect to camera using P2P credentials
    /// This is the primary connection method for VeepaAudioTest
    /// - Parameters:
    ///   - credentials: P2PCredentials with clientId and serviceParam
    ///   - password: Camera login password (default: "888888")
    /// - Returns: True if connection was initiated successfully
    func connectWithCredentials(_ credentials: P2PCredentials, password: String = "888888") async -> Bool {
        NSLog("🔵 [VeepaConnectionBridge] connectWithCredentials() called")
        NSLog("🔵 [VeepaConnectionBridge] Current state: %@, canConnect: %@",
              String(describing: state), state.canConnect ? "true" : "false")
        NSLog("🔵 [VeepaConnectionBridge] cameraUid: %@", credentials.cameraUid)

        guard state.canConnect else {
            NSLog("🔵 [VeepaConnectionBridge] Cannot connect - state doesn't allow it")
            return false
        }

        state = .connecting
        lastError = nil
        NSLog("🔵 [VeepaConnectionBridge] State changed to connecting")

        do {
            let actualPassword = credentials.password ?? password
            let args: [String: Any] = [
                "cameraUid": credentials.cameraUid,
                "clientId": credentials.clientId,
                "serviceParam": credentials.serviceParam,
                "password": actualPassword
            ]

            NSLog("🔵 [VeepaConnectionBridge] Invoking Flutter connectWithCredentials...")

            let result = try await engineManager.invoke("connectWithCredentials", arguments: args)
            let success = result as? Bool ?? false
            NSLog("🔵 [VeepaConnectionBridge] Flutter returned: %@", success ? "SUCCESS" : "FAILED")

            if success {
                // SIMPLIFIED: No state polling - Flutter will send events
                state = .connected
                NSLog("🔵 [VeepaConnectionBridge] State set to connected")
            } else {
                NSLog("🔵 [VeepaConnectionBridge] Connection failed - Flutter returned false")
                state = .error
            }

            return success
        } catch {
            NSLog("🔵 [VeepaConnectionBridge] ERROR: %@", error.localizedDescription)
            lastError = VeepaConnectionError(
                code: "P2P_CONNECTION_FAILED",
                message: error.localizedDescription
            )
            state = .error
            return false
        }
    }

    /// Disconnect from current camera
    func disconnect() async {
        NSLog("🔵 [VeepaConnectionBridge] disconnect() called")

        do {
            try await engineManager.invoke("disconnect")
            state = .idle
            NSLog("🔵 [VeepaConnectionBridge] Disconnected successfully")
        } catch {
            NSLog("🔵 [VeepaConnectionBridge] Disconnect error: \(error)")
            // Still mark as idle even if disconnect fails
            state = .idle
        }
    }

    /// Reset bridge state (for testing)
    func reset() {
        state = .idle
        lastError = nil
    }
}

// MARK: - P2P Credentials

/// P2P connection credentials from provisioning
struct P2PCredentials {
    let cameraUid: String
    let clientId: String
    let serviceParam: String
    let password: String?

    init(cameraUid: String, clientId: String, serviceParam: String, password: String? = nil) {
        self.cameraUid = cameraUid
        self.clientId = clientId
        self.serviceParam = serviceParam
        self.password = password
    }
}

// MARK: - Errors

enum ConnectionBridgeError: Error, LocalizedError {
    case notConnected
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to camera"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        }
    }
}
```

**Key simplifications**:
- ✅ Kept: P2P connection (connectWithCredentials), disconnect
- ✅ Kept: Error tracking and state management
- ❌ Removed: State polling (60 lines removed)
- ❌ Removed: Auto-reconnect (18 lines removed)
- ❌ Removed: Discovery connection (30 lines removed)
- ❌ Removed: Streaming methods (25 lines removed)
- ✏️ Simplified: 7 states → 4 states (idle, connecting, connected, error)

**Result**: 238 lines (down from 340 lines, 30% reduction)

---

### Step 2.6.2: Verify Swift File (2 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest

# Verify file created
test -f Services/Flutter/VeepaConnectionBridge.swift && echo "✅ VeepaConnectionBridge.swift created"

# Check line count
wc -l Services/Flutter/VeepaConnectionBridge.swift
# Expected: ~238 lines

# Check for key patterns
grep "connectWithCredentials" Services/Flutter/VeepaConnectionBridge.swift
# ✅ Expected: Found (P2P connection method)

grep "P2PCredentials" Services/Flutter/VeepaConnectionBridge.swift
# ✅ Expected: Found (credentials struct)

# Verify state polling was removed
! grep "startStatePolling" Services/Flutter/VeepaConnectionBridge.swift && echo "✅ State polling removed"
! grep "refreshState" Services/Flutter/VeepaConnectionBridge.swift && echo "✅ Refresh removed"
```

---

### Step 2.6.3: Update Xcode Project (3 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest

# Regenerate Xcode project (file will be auto-included)
xcodegen generate

# Check if file appears in project
grep -r "VeepaConnectionBridge" VeepaAudioTest.xcodeproj/project.pbxproj
# ✅ Expected: Found (file included in project)
```

---

### Step 2.6.4: Test Compilation (2 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest

# Quick syntax check
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  clean build | tail -n 1
# ✅ Expected: "** BUILD SUCCEEDED **"
```

---

## ✅ Sub-Story 2.6 Verification

Run these tests to verify everything works:

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest

# 1. File exists with correct content
test -f VeepaAudioTest/Services/Flutter/VeepaConnectionBridge.swift && echo "✅ File exists"

# 2. P2P connection method present
grep -q "connectWithCredentials" VeepaAudioTest/Services/Flutter/VeepaConnectionBridge.swift && echo "✅ P2P method present"

# 3. Credentials struct present
grep -q "struct P2PCredentials" VeepaAudioTest/Services/Flutter/VeepaConnectionBridge.swift && echo "✅ Credentials struct present"

# 4. State polling removed (should NOT be found)
! grep -q "startStatePolling" VeepaAudioTest/Services/Flutter/VeepaConnectionBridge.swift && echo "✅ State polling removed"
! grep -q "statePollingTask" VeepaAudioTest/Services/Flutter/VeepaConnectionBridge.swift && echo "✅ Polling task removed"

# 5. Auto-reconnect removed (should NOT be found)
! grep -q "func retry" VeepaAudioTest/Services/Flutter/VeepaConnectionBridge.swift && echo "✅ Retry removed"

# 6. Discovery removed (should NOT be found)
! grep -q "connect(to device:" VeepaAudioTest/Services/Flutter/VeepaConnectionBridge.swift && echo "✅ Discovery removed"

# 7. Streaming removed (should NOT be found)
! grep -q "startStreaming" VeepaAudioTest/Services/Flutter/VeepaConnectionBridge.swift && echo "✅ Streaming removed"

# 8. Simplified state enum (4 states)
grep "enum VeepaConnectionState" -A 20 VeepaAudioTest/Services/Flutter/VeepaConnectionBridge.swift | grep -c "case " | grep -q "4" && echo "✅ 4 states only"

# 9. Project compiles successfully
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  clean build | tail -n 1
# ✅ Expected: "** BUILD SUCCEEDED **"
```

---

## 🎯 Acceptance Criteria

- [ ] VeepaConnectionBridge.swift created (~238 lines)
- [ ] P2P connection method (connectWithCredentials) present
- [ ] P2PCredentials struct present
- [ ] Disconnect method present
- [ ] State enum simplified to 4 states (idle, connecting, connected, error)
- [ ] Error handling present
- [ ] State polling removed (startStatePolling, stopStatePolling, refreshState)
- [ ] Auto-reconnect removed (retry method)
- [ ] Discovery connection removed (connect(to device))
- [ ] Streaming methods removed (startStreaming, stopStreaming)
- [ ] File compiles without errors
- [ ] Xcode project includes new file

---

## 📝 What We Built

**VeepaConnectionBridge** now provides:
- ✅ P2P connection management (connectWithCredentials)
- ✅ Disconnect operations
- ✅ Connection state tracking (4 simple states)
- ✅ Error tracking and reporting
- ✅ Event handling from Flutter

**Simplified from source**:
- Removed 102 lines of complex code (30% reduction)
- No state polling (simpler, more efficient)
- No auto-reconnect (handle manually if needed)
- No discovery (P2P credentials come from external source)
- Focused on core connection/disconnect only

**Why these simplifications work**:
1. State polling: Flutter sends events when state changes - no need to poll
2. Auto-reconnect: For testing, manual reconnection is clearer
3. Discovery: Not needed - we get P2P credentials from external source
4. Streaming: Handled by VeepaAudioBridge (separate concern)

---

## 🔗 Navigation

← **Previous**: [Sub-Story 2.5 - Copy VSTCBridge](sub-story-2.5-vstc-bridge.md)
→ **Next**: [Sub-Story 2.7 - Verify Flutter-iOS Communication](sub-story-2.7-verify-communication.md)
↑ **Story Overview**: [Story 2 README](README.md)

---

**Created**: 2026-02-02
**Adapted From**: SciSymbioLens VeepaConnectionBridge.swift (340 lines → 238 lines)
