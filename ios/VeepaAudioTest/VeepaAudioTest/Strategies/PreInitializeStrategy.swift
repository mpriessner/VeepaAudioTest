// ADAPTED FROM: Story 4 original Pre-Initialize strategy design
// Changes: Configure AVAudioSession early before Flutter engine starts
//   - Sets 16kHz as preferred (CONFIRMED from O-KAM Pro logs!)
//   - The camera sends 16kHz mono Int16 audio, NOT 8kHz
//   - Attempts to lock in settings before SDK can impose incompatible ones
//   - Tests hypothesis: early configuration prevents sample rate mismatch
//
// CRITICAL FINDING (2026-02-03):
//   Console logs from O-KAM Pro show: "from 1 ch, 16000 Hz, Int16 to 2 ch, 48000 Hz, Float32"
//   This proves the camera sends 16kHz, not 8kHz as previously assumed!
//
import Foundation
import AVFoundation

/// Pre-initialize strategy: Configure AVAudioSession BEFORE Flutter engine starts
/// Sets 16kHz audio format (confirmed from O-KAM Pro logs) as early as possible
/// to prevent SDK from forcing incompatible 48kHz settings later
class PreInitializeStrategy: AudioSessionStrategy {
    // MARK: - Protocol Properties

    let name = "Pre-Initialize"

    let description = "Configure AVAudioSession BEFORE Flutter engine starts (set 16kHz early - confirmed from O-KAM Pro)"

    // MARK: - State

    private var didEarlyInitialize = false

    // MARK: - Protocol Methods

    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        print("[PreInit] ================================================================")
        print("[PreInit] 🎯 AUDIO CONFIGURATION VERIFICATION")
        print("[PreInit] ================================================================")

        // EARLY initialization (do this ONCE, before Flutter engine)
        if !didEarlyInitialize {
            print("[PreInit] 📋 Step 1: Setting Preferred Audio Parameters")
            print("[PreInit] ----------------------------------------------------------------")
            print("[PreInit] BEFORE configuration:")
            print("[PreInit]    Current Sample Rate: \(session.sampleRate) Hz")
            print("[PreInit]    Current Buffer Duration: \(session.ioBufferDuration * 1000) ms")
            print("[PreInit]    Current Input Channels: \(session.inputNumberOfChannels)")
            print("[PreInit]    Current Output Channels: \(session.outputNumberOfChannels)")
            print("[PreInit] ----------------------------------------------------------------")

            do {
                // CRITICAL: Camera sends 16kHz mono Int16 audio (confirmed from O-KAM Pro logs)
                // NOT 8kHz as previously assumed!
                print("[PreInit] 🔧 Configuring for camera audio (16kHz mono - CONFIRMED from O-KAM Pro)...")

                try session.setPreferredSampleRate(16000)  // Camera sends 16kHz!
                print("[PreInit]    ✅ Requested: Sample Rate = 16000 Hz (camera's native rate)")

                try session.setPreferredIOBufferDuration(0.02)  // 20ms buffer
                print("[PreInit]    ✅ Requested: Buffer Duration = 20 ms")

                try session.setPreferredInputNumberOfChannels(1)  // Mono input
                print("[PreInit]    ✅ Requested: Input Channels = 1 (mono)")

                try session.setPreferredOutputNumberOfChannels(2)  // Stereo output (iOS prefers this)
                print("[PreInit]    ✅ Requested: Output Channels = 2 (stereo - iOS converts mono→stereo)")

                didEarlyInitialize = true
                print("[PreInit] ✅ Preferences set successfully")

            } catch {
                print("[PreInit] ❌ Failed to set preferences: \(error.localizedDescription)")
                print("[PreInit]    Error code: \((error as NSError).code)")
                print("[PreInit]    Error domain: \((error as NSError).domain)")
                // Continue anyway - we'll see what iOS gives us
            }
            print("[PreInit] ----------------------------------------------------------------")
        }

        // STANDARD activation (same as baseline, but with early prefs set)
        print("[PreInit] 📋 Step 2: Activating AVAudioSession")
        print("[PreInit] ----------------------------------------------------------------")

        do {
            // Use .default mode instead of .videoChat
            // .videoChat may force 48kHz for high-quality voice
            // .default allows more flexibility with sample rates
            try session.setCategory(
                .playAndRecord,
                mode: .default,  // NOT .videoChat - that forces higher sample rates
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            print("[PreInit]    ✅ Category set: PlayAndRecord")
            print("[PreInit]    ✅ Mode set: Default (not VideoChat - allows 16kHz)")

            try session.setActive(true)
            print("[PreInit]    ✅ Session activated")

            print("[PreInit] ----------------------------------------------------------------")
            print("[PreInit] 📋 Step 3: Verifying Actual Configuration")
            print("[PreInit] ----------------------------------------------------------------")
            print("[PreInit] AFTER activation:")
            print("[PreInit]    Actual Sample Rate: \(session.sampleRate) Hz")
            print("[PreInit]    Actual Buffer Duration: \(session.ioBufferDuration * 1000) ms")
            print("[PreInit]    Actual Input Channels: \(session.inputNumberOfChannels)")
            print("[PreInit]    Actual Output Channels: \(session.outputNumberOfChannels)")
            print("[PreInit] ----------------------------------------------------------------")

            // Verify sample rate matching
            print("[PreInit] 🔍 VERIFICATION: Sample Rate Matching")
            print("[PreInit] ----------------------------------------------------------------")
            print("[PreInit]    Camera sends: 16000 Hz (confirmed from O-KAM Pro logs)")
            print("[PreInit]    iOS provided: \(session.sampleRate) Hz")

            let sampleRateMatch = session.sampleRate == 16000
            let sampleRateAcceptable = session.sampleRate == 16000 || session.sampleRate == 48000

            if sampleRateMatch {
                print("[PreInit]    ✅ PERFECT MATCH! No resampling needed")
                print("[PreInit]    Audio should work correctly")
            } else if session.sampleRate == 48000 {
                let ratio = session.sampleRate / 16000.0
                print("[PreInit]    ⚠️ iOS forced 48kHz (ratio: \(ratio)x)")
                print("[PreInit]    SDK needs to resample 16kHz → 48kHz")
                print("[PreInit]    This is a 3x upsample (should be manageable)")
            } else {
                let ratio = session.sampleRate / 16000.0
                print("[PreInit]    ⚠️ MISMATCH detected!")
                print("[PreInit]    Ratio: \(ratio)x (\(session.sampleRate) / 16000)")
                print("[PreInit]    Unexpected sample rate - may cause issues")
            }

            // Verify channel matching
            print("[PreInit] ----------------------------------------------------------------")
            print("[PreInit] 🔍 VERIFICATION: Channel Configuration")
            print("[PreInit] ----------------------------------------------------------------")
            print("[PreInit]    SDK expects: 1 channel (mono)")
            print("[PreInit]    iOS input: \(session.inputNumberOfChannels) channel(s)")
            print("[PreInit]    iOS output: \(session.outputNumberOfChannels) channel(s)")

            if session.outputNumberOfChannels == 1 {
                print("[PreInit]    ✅ Output is mono - matches SDK expectation")
            } else {
                print("[PreInit]    ⚠️ Output is stereo - SDK sends mono, iOS expects stereo")
                print("[PreInit]    iOS should auto-convert mono→stereo (duplicate channels)")
            }

            print("[PreInit] ================================================================")
            print("[PreInit] 📊 CONFIGURATION SUMMARY")
            print("[PreInit] ================================================================")
            print("[PreInit]    Sample Rate Match: \(sampleRateMatch ? "✅ YES" : "❌ NO")")
            print("[PreInit]    Expected Outcome: \(sampleRateMatch ? "Audio should work" : "May fail with error -50")")
            print("[PreInit] ================================================================")

            // Log full state for detailed diagnostics
            logAudioSessionState(prefix: "PreInit")

            // Throw error if critical mismatch
            if !sampleRateMatch {
                print("[PreInit] ⚠️ WARNING: Sample rate mismatch may cause audio failure")
                print("[PreInit]    Continuing anyway to test behavior...")
            }

        } catch {
            print("[PreInit] ❌ Activation failed: \(error.localizedDescription)")
            print("[PreInit]    Error code: \((error as NSError).code)")
            print("[PreInit]    Error domain: \((error as NSError).domain)")
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
