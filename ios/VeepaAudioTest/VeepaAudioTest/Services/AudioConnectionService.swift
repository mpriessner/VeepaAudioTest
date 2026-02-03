// ADAPTED FROM: SciSymbioLens service architecture patterns
// Changes: Adapted to work with VeepaConnectionBridge from Sub-Story 2.6
//   - Uses P2PCredentials struct instead of separate uid/serviceParam
//   - Maps VeepaConnectionState to ConnectionState
//   - Removed clientPtr tracking (not exposed by bridge)
//   - Added debug logging for UI display
//
import Foundation

@MainActor
final class AudioConnectionService: ObservableObject {
    // MARK: - Published State

    @Published var connectionState: ConnectionState = .disconnected
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

    init() {
        // Observe connection bridge state changes
        observeBridgeState()
    }

    // MARK: - State Observation

    private func observeBridgeState() {
        // Map VeepaConnectionBridge state to ConnectionState
        // This will be updated when we add Combine subscriptions
        // For now, we'll manually sync state in connect/disconnect methods
    }

    // MARK: - Connection Methods

    /// Connect to camera using P2P credentials
    /// - Parameters:
    ///   - uid: Camera UID
    ///   - serviceParam: P2P service parameter
    ///   - password: Camera password (default: "888888")
    func connect(uid: String, serviceParam: String, password: String = "888888") async {
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

            // Create P2P credentials
            let credentials = P2PCredentials(
                cameraUid: uid,
                clientId: uid,  // For simplified version, use UID as clientId
                serviceParam: serviceParam,
                password: password
            )

            // Connect via VeepaConnectionBridge
            log("   Establishing P2P connection...")
            let success = await connectionBridge.connectWithCredentials(credentials, password: password)

            if success {
                connectionState = .connected
                log("   ✅ Connected successfully!")
            } else {
                let errorMsg = connectionBridge.lastError?.message ?? "Unknown error"
                connectionState = .error(errorMsg)
                log("   ❌ Connection failed: \(errorMsg)")
            }

        } catch {
            connectionState = .error(error.localizedDescription)
            log("   ❌ Connection failed: \(error.localizedDescription)")
        }
    }

    /// Disconnect from current camera
    func disconnect() async {
        log("🔌 Disconnecting...")

        await connectionBridge.disconnect()
        connectionState = .disconnected
        log("   ✅ Disconnected")
    }

    /// Clear debug logs
    func clearLogs() {
        debugLogs.removeAll()
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
