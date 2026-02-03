// ADAPTED FROM: Story 4 original Pre-Initialize strategy design
// Changes: Configure AVAudioSession early before Flutter engine starts
//   - Sets G.711-compatible format (8kHz) as preferred
//   - Attempts to lock in settings before SDK can impose incompatible ones
//   - Tests hypothesis: early configuration prevents sample rate mismatch
//
import Foundation
import AVFoundation

/// Pre-initialize strategy: Configure AVAudioSession BEFORE Flutter engine starts
/// Sets G.711-compatible audio format (8kHz mono) as early as possible
/// to prevent SDK from forcing incompatible settings later
class PreInitializeStrategy: AudioSessionStrategy {
    // MARK: - Protocol Properties

    let name = "Pre-Initialize"

    let description = "Configure AVAudioSession BEFORE Flutter engine starts (set 8kHz early)"

    // MARK: - State

    private var didEarlyInitialize = false

    // MARK: - Protocol Methods

    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        // EARLY initialization (do this ONCE, before Flutter engine)
        if !didEarlyInitialize {
            print("[PreInit] 🔧 EARLY audio session configuration (before Flutter)")

            do {
                // Set G.711-compatible format preferences
                try session.setPreferredSampleRate(8000)  // G.711 uses 8kHz
                try session.setPreferredIOBufferDuration(0.02)  // 20ms buffer
                try session.setPreferredInputNumberOfChannels(1)  // Mono input
                try session.setPreferredOutputNumberOfChannels(1)  // Mono output

                print("[PreInit]    Preferred Sample Rate: 8000 Hz")
                print("[PreInit]    Preferred Buffer: 20ms")
                print("[PreInit]    Preferred Channels: 1 (mono)")

                didEarlyInitialize = true
                print("[PreInit] ✅ Early initialization complete")

            } catch {
                print("[PreInit] ⚠️ Early initialization failed: \(error.localizedDescription)")
                // Continue anyway - we'll try again during activation
            }
        }

        // STANDARD activation (same as baseline, but with early prefs set)
        print("[PreInit] 🔧 Activating AVAudioSession...")

        do {
            try session.setCategory(
                .playAndRecord,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setMode(.videoChat)
            try session.setActive(true)

            print("[PreInit] ✅ AVAudioSession activated")
            print("[PreInit]    Actual Sample Rate: \(session.sampleRate) Hz")
            print("[PreInit]    Actual Buffer: \(session.ioBufferDuration * 1000) ms")
            print("[PreInit]    Actual Input Channels: \(session.inputNumberOfChannels)")
            print("[PreInit]    Actual Output Channels: \(session.outputNumberOfChannels)")

            // Check if our preferences were honored
            if session.sampleRate == 8000 {
                print("[PreInit] ✅ SUCCESS! System is using 8kHz sample rate")
            } else {
                print("[PreInit] ⚠️ System overrode our preference: using \(session.sampleRate) Hz instead of 8000 Hz")
            }

            // Log full state
            logAudioSessionState(prefix: "PreInit")

        } catch {
            print("[PreInit] ❌ Activation failed: \(error.localizedDescription)")
            throw AudioSessionStrategyError.configurationFailed(error.localizedDescription)
        }
    }

    func cleanupAudioSession() {
        print("[PreInit] 🧹 Cleaning up AVAudioSession...")

        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
            print("[PreInit] ✅ AVAudioSession deactivated")
        } catch {
            print("[PreInit] ⚠️ Deactivation warning: \(error.localizedDescription)")
        }
    }
}
