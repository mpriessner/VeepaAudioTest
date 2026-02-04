// ADAPTED FROM: Story 4 original AudioStreamService with strategy support
// Changes: Added strategy pattern for testing different audio session configurations
//   - Four strategies: Baseline, Pre-Initialize, Swizzled, Locked
//   - Strategy selection via published property
//   - Removed inline audio session configuration (delegated to strategies)
//
import Foundation
import AVFoundation

@MainActor
final class AudioStreamService: ObservableObject {
    // MARK: - Published State

    @Published var isPlaying = false
    @Published var isMuted = false
    @Published var debugLogs: [String] = []
    @Published var currentStrategy: AudioSessionStrategy = PreInitializeStrategy() {
        didSet {
            log("🔄 Switched to strategy: \(currentStrategy.name)")
            log("   Description: \(currentStrategy.description)")
        }
    }

    // MARK: - Available Strategies

    let strategies: [AudioSessionStrategy] = [
        BaselineStrategy(),
        PreInitializeStrategy(),
        SwizzledStrategy(),
        LockedSessionStrategy()
    ]

    // MARK: - Dependencies

    private let flutterEngine = FlutterEngineManager.shared

    // MARK: - Audio Control Methods

    func startAudio() async throws {
        log("🎵 Starting audio with \(currentStrategy.name) strategy...")

        // Configure AVAudioSession using selected strategy
        do {
            try currentStrategy.prepareAudioSession()
        } catch {
            log("   ❌ Audio session preparation failed: \(error.localizedDescription)")
            throw error
        }

        // Call Flutter method
        do {
            log("   Calling startVoice()...")
            let result = try await flutterEngine.invoke("startAudio")
            log("   startVoice result: \(result ?? "nil")")

            isPlaying = true
            log("   ✅ Audio started successfully")

        } catch {
            log("   ❌ startAudio failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Start audio WITHOUT reconfiguring audio session
    /// Used when AudioHookBridge is active to avoid disrupting AudioBridgeEngine
    func startAudioDirect() async throws {
        log("🎵 Starting audio DIRECTLY (no audio session changes)...")
        log("   💡 AudioBridgeEngine's audio session will be preserved")

        // Skip audio session configuration - just call startVoice
        do {
            log("   Calling startVoice()...")
            let result = try await flutterEngine.invoke("startAudio")
            log("   startVoice result: \(result ?? "nil")")

            isPlaying = true
            log("   ✅ Audio started successfully (hooked mode)")

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

            // Clean up audio session using strategy
            currentStrategy.cleanupAudioSession()

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
