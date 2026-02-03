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

            // Parse result Map from Flutter
            guard let resultMap = result as? [String: Any],
                  let success = resultMap["success"] as? Bool else {
                NSLog("🔵 [VeepaConnectionBridge] Invalid result format: %@", String(describing: result))
                state = .error
                return false
            }

            NSLog("🔵 [VeepaConnectionBridge] Flutter returned: %@", success ? "SUCCESS" : "FAILED")

            if success {
                // SIMPLIFIED: No state polling - Flutter will send events
                state = .connected
                if let clientPtr = resultMap["clientPtr"] as? Int {
                    NSLog("🔵 [VeepaConnectionBridge] State set to connected (clientPtr: %d)", clientPtr)
                } else {
                    NSLog("🔵 [VeepaConnectionBridge] State set to connected")
                }
            } else {
                let errorMsg = resultMap["error"] as? String ?? "Unknown error"
                NSLog("🔵 [VeepaConnectionBridge] Connection failed: %@", errorMsg)
                lastError = VeepaConnectionError(
                    code: "CONNECTION_FAILED",
                    message: errorMsg
                )
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

// MARK: - Errors
// Note: P2PCredentials struct moved to Models/P2PCredentials.swift for shared use

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
