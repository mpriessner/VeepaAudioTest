// ADAPTED FROM: Story 4 original Swizzled strategy design
// Changes: Advanced method swizzling to force 8kHz audio
//   - Intercepts setPreferredSampleRate: calls at runtime
//   - Forces 8000 Hz regardless of what SDK requests
//   - Invasive technique - use as last resort only
//
import Foundation
import AVFoundation
import ObjectiveC

/// Swizzled strategy: Method swizzling to force 8kHz audio format
/// Intercepts calls to setPreferredSampleRate: and forces 8000 Hz
/// This is an invasive technique that modifies AVAudioSession behavior at runtime
class SwizzledStrategy: AudioSessionStrategy {
    // MARK: - Protocol Properties

    let name = "Swizzled"

    let description = "Method swizzling to force 8kHz sample rate (intercepts SDK calls)"

    // MARK: - State

    private static var didSwizzle = false

    // MARK: - Protocol Methods

    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        // Install swizzling ONCE (before any audio session calls)
        if !Self.didSwizzle {
            print("[Swizzle] 🔀 Installing method swizzling...")
            installSwizzling()
            Self.didSwizzle = true
            print("[Swizzle] ✅ Method swizzling installed")
        }

        // Standard configuration (our swizzled methods will intercept)
        print("[Swizzle] 🔧 Configuring AVAudioSession (with swizzling active)...")

        do {
            try session.setCategory(
                .playAndRecord,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setMode(.videoChat)

            // Try to set preferred rate (will be intercepted by our swizzled method)
            try session.setPreferredSampleRate(8000)
            try session.setPreferredIOBufferDuration(0.02)

            try session.setActive(true)

            print("[Swizzle] ✅ AVAudioSession activated")
            print("[Swizzle]    Sample Rate: \(session.sampleRate) Hz")
            print("[Swizzle]    IO Buffer: \(session.ioBufferDuration * 1000) ms")

            // Check if swizzling worked
            if session.sampleRate == 8000 {
                print("[Swizzle] ✅ SUCCESS! Swizzling forced 8kHz sample rate")
            } else {
                print("[Swizzle] ⚠️ Swizzling didn't affect sample rate: \(session.sampleRate) Hz")
            }

            // Log full state
            logAudioSessionState(prefix: "Swizzle")

        } catch {
            print("[Swizzle] ❌ Configuration failed: \(error.localizedDescription)")
            throw AudioSessionStrategyError.configurationFailed(error.localizedDescription)
        }
    }

    func cleanupAudioSession() {
        print("[Swizzle] 🧹 Cleaning up AVAudioSession...")

        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
            print("[Swizzle] ✅ AVAudioSession deactivated")
        } catch {
            print("[Swizzle] ⚠️ Deactivation warning: \(error.localizedDescription)")
        }

        // NOTE: Swizzling persists for app lifetime - cannot be undone safely
        print("[Swizzle] ⚠️ Method swizzling remains active (restart app to reset)")
    }

    // MARK: - Swizzling Implementation

    private func installSwizzling() {
        // Swizzle setPreferredSampleRate: to force 8000 Hz
        let originalSelector = #selector(AVAudioSession.setPreferredSampleRate(_:))
        let swizzledSelector = #selector(AVAudioSession.swizzled_setPreferredSampleRate(_:))

        guard let originalClass = object_getClass(AVAudioSession.sharedInstance()) else {
            print("[Swizzle] ❌ Failed to get AVAudioSession class")
            return
        }

        guard let originalMethod = class_getInstanceMethod(originalClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(originalClass, swizzledSelector) else {
            print("[Swizzle] ❌ Failed to get methods for swizzling")
            return
        }

        // Swap implementations
        method_exchangeImplementations(originalMethod, swizzledMethod)
        print("[Swizzle] ✅ Swizzled setPreferredSampleRate:")
    }
}

// MARK: - AVAudioSession Extension (Swizzled Methods)

extension AVAudioSession {
    /// Swizzled version of setPreferredSampleRate:
    /// This method REPLACES the original at runtime
    /// The naming is intentional - Swift will swap implementations
    @objc dynamic func swizzled_setPreferredSampleRate(_ sampleRate: Double) throws {
        print("[Swizzle] 🎵 Intercepted setPreferredSampleRate(\(sampleRate))")

        // Force 8000 Hz regardless of requested rate
        let forcedRate: Double = 8000

        if sampleRate != forcedRate {
            print("[Swizzle]    Forcing: \(sampleRate) Hz → \(forcedRate) Hz")
        }

        // Call original implementation (which is now named "swizzled_setPreferredSampleRate")
        // This is NOT recursive - method_exchangeImplementations swapped the names
        try self.swizzled_setPreferredSampleRate(forcedRate)
    }
}
