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
        // Note: GeneratedPluginRegistrant is not available in Flutter module builds with no plugins
        // GeneratedPluginRegistrant.register(with: engine)
        // print("[FlutterEngineManager] GeneratedPluginRegistrant registered")

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
