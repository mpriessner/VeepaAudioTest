// ADAPTED FROM: Story 1 iOS app entry point pattern
// Changes: Pure SwiftUI app lifecycle (no UIKit AppDelegate)
//   - WindowGroup with ContentView as root
//   - CRITICAL: Configure AVAudioSession at 16kHz BEFORE anything else
//
// CRITICAL FINDING (2026-02-03):
//   O-KAM Pro logs show camera sends 16kHz mono audio, NOT 8kHz!
//   We must configure AVAudioSession BEFORE Flutter engine starts.
//
import SwiftUI
import AVFoundation

@main
struct VeepaAudioTestApp: App {
    init() {
        print("🚀 VeepaAudioTest app initializing...")

        // CRITICAL: Configure audio session FIRST, before anything else
        // This must happen before Flutter engine initializes the SDK
        configureAudioSessionEarly()
    }

    /// Configure AVAudioSession at app launch - BEFORE Flutter engine
    /// This is critical because the SDK's AudioUnit initialization fails
    /// if the session is already locked to 48kHz
    private func configureAudioSessionEarly() {
        print("[AppInit] ════════════════════════════════════════════════")
        print("[AppInit] 🎯 EARLY AUDIO SESSION CONFIGURATION")
        print("[AppInit] ════════════════════════════════════════════════")
        print("[AppInit] Camera sends: 16kHz mono Int16 (confirmed from O-KAM Pro)")
        print("[AppInit] Goal: Pre-configure session before SDK initializes")
        print("[AppInit] ────────────────────────────────────────────────")

        let session = AVAudioSession.sharedInstance()

        do {
            // Step 1: Set preferred sample rate to 16kHz (camera's native rate)
            try session.setPreferredSampleRate(16000)
            print("[AppInit] ✅ Preferred sample rate set: 16000 Hz")

            // Step 2: Set category with .default mode (not .videoChat which forces 48kHz)
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            print("[AppInit] ✅ Category: playAndRecord, Mode: default")

            // Step 3: Activate the session early
            try session.setActive(true)
            print("[AppInit] ✅ Session activated")

            // Step 4: Report what iOS actually gave us
            print("[AppInit] ────────────────────────────────────────────────")
            print("[AppInit] 📊 ACTUAL CONFIGURATION:")
            print("[AppInit]    Sample Rate: \(session.sampleRate) Hz")
            print("[AppInit]    Buffer Duration: \(session.ioBufferDuration * 1000) ms")
            print("[AppInit]    Output Channels: \(session.outputNumberOfChannels)")

            if session.sampleRate == 16000 {
                print("[AppInit] ✅ SUCCESS: iOS accepted 16kHz!")
            } else if session.sampleRate == 48000 {
                print("[AppInit] ⚠️ iOS forced 48kHz - SDK will need to resample")
                print("[AppInit]    Ratio: 3x (16000 → 48000)")
            } else {
                print("[AppInit] ⚠️ Unexpected rate: \(session.sampleRate) Hz")
            }

        } catch {
            print("[AppInit] ❌ Audio session configuration failed: \(error)")
            print("[AppInit]    Error code: \((error as NSError).code)")
        }

        print("[AppInit] ════════════════════════════════════════════════")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
