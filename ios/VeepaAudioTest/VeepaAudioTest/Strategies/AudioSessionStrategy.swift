// ADAPTED FROM: Story 4 original AudioSessionStrategy design
// Changes: Strategy pattern for testing different audio session configurations
//   - Protocol defines interface for all strategies
//   - Each strategy can configure AVAudioSession differently
//   - Swappable at runtime for testing
//
import Foundation
import AVFoundation

/// Protocol for audio session configuration strategies
/// Each strategy implements a different approach to resolving AudioUnit error -50
protocol AudioSessionStrategy {
    /// Display name for UI picker
    var name: String { get }

    /// Detailed description of strategy approach
    var description: String { get }

    /// Configure audio session BEFORE startVoice() is called
    /// - Throws: Error if configuration fails
    func prepareAudioSession() throws

    /// Clean up audio session AFTER stopVoice() is called
    func cleanupAudioSession()
}

// MARK: - Strategy Error Types

enum AudioSessionStrategyError: Error, LocalizedError {
    case configurationFailed(String)
    case swizzlingFailed(String)
    case unsupportedConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .configurationFailed(let msg):
            return "Audio session configuration failed: \(msg)"
        case .swizzlingFailed(let msg):
            return "Method swizzling failed: \(msg)"
        case .unsupportedConfiguration(let msg):
            return "Unsupported configuration: \(msg)"
        }
    }
}

// MARK: - Logging Helper Extension

extension AudioSessionStrategy {
    /// Helper to log audio session state consistently across strategies
    func logAudioSessionState(prefix: String) {
        let session = AVAudioSession.sharedInstance()

        print("[\(prefix)] 📊 Audio Session State:")
        print("[\(prefix)]    Category: \(session.category.rawValue)")
        print("[\(prefix)]    Mode: \(session.mode.rawValue)")
        print("[\(prefix)]    Sample Rate: \(session.sampleRate) Hz")
        print("[\(prefix)]    Preferred Sample Rate: \(session.preferredSampleRate) Hz")
        print("[\(prefix)]    IO Buffer Duration: \(session.ioBufferDuration * 1000) ms")
        print("[\(prefix)]    Input Channels: \(session.inputNumberOfChannels)")
        print("[\(prefix)]    Output Channels: \(session.outputNumberOfChannels)")

        // Log current route
        let route = session.currentRoute
        if !route.inputs.isEmpty {
            print("[\(prefix)]    Inputs:")
            for input in route.inputs {
                print("[\(prefix)]       - \(input.portName) (\(input.portType.rawValue))")
            }
        }
        if !route.outputs.isEmpty {
            print("[\(prefix)]    Outputs:")
            for output in route.outputs {
                print("[\(prefix)]       - \(output.portName) (\(output.portType.rawValue))")
            }
        }
    }
}
