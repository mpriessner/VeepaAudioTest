// ADAPTED FROM: Story 4 original Locked Session strategy design
// Changes: Lock audio session with G.711-compatible settings early
//   - Pre-configure all audio preferences (8kHz mono)
//   - Activate before SDK to claim audio session
//   - Maximum options to prevent SDK from changing configuration
//
import Foundation
import AVFoundation

/// Locked session strategy: Configure and lock audio session to prevent SDK changes
/// Pre-configures with G.711-compatible settings (8kHz mono) and activates with
/// high priority to prevent the SDK from imposing incompatible configuration
class LockedSessionStrategy: AudioSessionStrategy {
    // MARK: - Protocol Properties

    let name = "Locked"

    let description = "Lock audio session with G.711 format (8kHz mono) to prevent SDK changes"

    // MARK: - Protocol Methods

    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        print("[Locked] 🔒 Configuring and locking audio session...")

        do {
            // Set category with ALL relevant options
            try session.setCategory(
                .playAndRecord,
                options: [
                    .defaultToSpeaker,
                    .allowBluetooth,
                    .allowBluetoothA2DP,
                    .mixWithOthers  // Allow mixing with other audio
                ]
            )
            print("[Locked] ✅ Category set with maximum options")

            // Set mode optimized for voice
            try session.setMode(.videoChat)
            print("[Locked] ✅ Mode set to videoChat")

            // Force G.711-compatible audio format
            try session.setPreferredSampleRate(8000)  // G.711 uses 8kHz
            print("[Locked]    Preferred sample rate: 8000 Hz")

            try session.setPreferredIOBufferDuration(0.02)  // 20ms latency
            print("[Locked]    Preferred buffer: 20ms")

            try session.setPreferredInputNumberOfChannels(1)  // Mono input
            print("[Locked]    Preferred input channels: 1")

            try session.setPreferredOutputNumberOfChannels(1)  // Mono output
            print("[Locked]    Preferred output channels: 1")

            // Activate session with NO special options (default priority)
            // The "lock" comes from doing this BEFORE SDK tries to configure
            try session.setActive(true, options: [])

            print("[Locked] ✅ Audio session locked and activated")
            print("[Locked]    Actual sample rate: \(session.sampleRate) Hz")
            print("[Locked]    Actual buffer: \(session.ioBufferDuration * 1000) ms")
            print("[Locked]    Actual input channels: \(session.inputNumberOfChannels)")
            print("[Locked]    Actual output channels: \(session.outputNumberOfChannels)")

            // Verify configuration was accepted
            if session.sampleRate == 8000 {
                print("[Locked] ✅ SUCCESS! Session locked at 8kHz")
            } else {
                print("[Locked] ⚠️ System used \(session.sampleRate) Hz instead of requested 8000 Hz")
            }

            // Log hardware format details
            logHardwareFormat(session)

            // Log full state
            logAudioSessionState(prefix: "Locked")

        } catch {
            print("[Locked] ❌ Configuration failed: \(error.localizedDescription)")
            throw AudioSessionStrategyError.configurationFailed(error.localizedDescription)
        }
    }

    func cleanupAudioSession() {
        print("[Locked] 🧹 Cleaning up and unlocking AVAudioSession...")

        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
            print("[Locked] ✅ AVAudioSession deactivated and unlocked")
        } catch {
            print("[Locked] ⚠️ Deactivation warning: \(error.localizedDescription)")
        }
    }

    // MARK: - Hardware Diagnostics

    private func logHardwareFormat(_ session: AVAudioSession) {
        print("[Locked] 📊 Hardware Audio Format:")

        // Log available inputs
        if let inputs = session.availableInputs {
            print("[Locked]    Available inputs: \(inputs.count)")
            for (index, input) in inputs.enumerated() {
                print("[Locked]       [\(index + 1)] \(input.portName) (\(input.portType.rawValue))")

                // Log data sources if available
                if let dataSources = input.dataSources {
                    for source in dataSources {
                        print("[Locked]           - \(source.dataSourceName)")
                    }
                }
            }
        } else {
            print("[Locked]    Available inputs: None")
        }

        // Log current input
        if let currentInput = session.currentRoute.inputs.first {
            print("[Locked]    Current input: \(currentInput.portName)")
        }

        // Log current output
        if let currentOutput = session.currentRoute.outputs.first {
            print("[Locked]    Current output: \(currentOutput.portName)")
        }

        // Log input latency
        print("[Locked]    Input latency: \(session.inputLatency * 1000) ms")
        print("[Locked]    Output latency: \(session.outputLatency * 1000) ms")
    }
}
