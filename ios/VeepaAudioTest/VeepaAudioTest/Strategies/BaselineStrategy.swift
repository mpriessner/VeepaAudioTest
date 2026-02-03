// ADAPTED FROM: Story 3 AudioStreamService configureAudioSession method
// Changes: Extracted as strategy for testing
//   - Standard AVAudioSession configuration
//   - Expected to fail with error -50
//   - Serves as control group for strategy comparison
//
import Foundation
import AVFoundation

/// Baseline strategy using standard AVAudioSession configuration
/// This is expected to fail with error -50 because the system's default
/// sample rate (48kHz) is incompatible with the SDK's G.711 codec (8kHz)
class BaselineStrategy: AudioSessionStrategy {
    // MARK: - Protocol Properties

    let name = "Baseline"

    let description = "Standard AVAudioSession setup (expected to fail with error -50)"

    // MARK: - Protocol Methods

    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        print("[Baseline] 🔧 Configuring AVAudioSession...")

        do {
            // Standard configuration
            try session.setCategory(
                .playAndRecord,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setMode(.videoChat)
            try session.setActive(true)

            print("[Baseline] ✅ AVAudioSession configured")
            print("[Baseline]    Category: \(session.category.rawValue)")
            print("[Baseline]    Mode: \(session.mode.rawValue)")
            print("[Baseline]    Sample Rate: \(session.sampleRate) Hz")
            print("[Baseline]    IO Buffer Duration: \(session.ioBufferDuration * 1000) ms")

            // Log full state for diagnostics
            logAudioSessionState(prefix: "Baseline")

        } catch {
            print("[Baseline] ❌ Configuration failed: \(error.localizedDescription)")
            throw AudioSessionStrategyError.configurationFailed(error.localizedDescription)
        }
    }

    func cleanupAudioSession() {
        print("[Baseline] 🧹 Cleaning up AVAudioSession...")

        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
            print("[Baseline] ✅ AVAudioSession deactivated")
        } catch {
            print("[Baseline] ⚠️ Deactivation warning: \(error.localizedDescription)")
        }
    }
}
