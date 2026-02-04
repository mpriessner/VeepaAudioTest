//
//  AudioBridgeEngine.swift
//  VeepaAudioTest
//
//  Created for AudioUnit Hook implementation
//  Purpose: AVAudioEngine-based playback pipeline that accepts 16kHz audio
//           and plays it through iOS at 48kHz (automatic conversion)
//
//  Based on O-KAM Pro approach:
//  "Created a new in process converter from 1 ch, 16000 Hz, Int16 to 2 ch, 48000 Hz, Float32"
//

import AVFoundation
import AudioToolbox

/// Audio bridge engine that plays 16kHz audio from SDK through AVAudioEngine
///
/// Architecture:
/// ```
/// SDK Render Callback (16kHz Int16)
///         │
///         ▼
///   CircularAudioBuffer
///         │
///         ▼
///   AVAudioSourceNode (pulls 16kHz Int16)
///         │
///         ▼
///   AVAudioEngine (auto-converts to 48kHz)
///         │
///         ▼
///      Speaker
/// ```
///
final class AudioBridgeEngine {

    // MARK: - Singleton

    static let shared = AudioBridgeEngine()

    // MARK: - Audio Format Constants

    /// Input format: What the camera/SDK produces after G.711a decoding
    /// Verified from O-KAM Pro logs: "1 ch, 16000 Hz, Int16"
    private let inputSampleRate: Double = 16000
    private let inputChannels: AVAudioChannelCount = 1

    /// Output format: What iOS hardware requires
    /// Verified from O-KAM Pro logs: "2 ch, 48000 Hz, Float32"
    private let outputSampleRate: Double = 48000

    // MARK: - Audio Graph Components

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var inputFormat: AVAudioFormat?

    // MARK: - Buffer

    /// Circular buffer to receive samples from SDK
    let circularBuffer = CircularAudioBuffer(capacity: 32000)  // ~2 seconds at 16kHz

    // MARK: - State

    private(set) var isRunning = false
    private var renderCallbackCount: UInt64 = 0

    // MARK: - Debug

    private var lastLogTime: Date = Date()
    private let logInterval: TimeInterval = 2.0  // Log every 2 seconds
    private var healthCheckTimer: Timer?
    private var lastKnownCallbackCount: UInt64 = 0
    private var restartAttempts: Int = 0

    // MARK: - Initialization

    private init() {
        print("[AudioBridgeEngine] Initialized")
        print("[AudioBridgeEngine]   Input: \(Int(inputSampleRate)) Hz, \(inputChannels) ch, Int16")
        print("[AudioBridgeEngine]   Output: \(Int(outputSampleRate)) Hz, stereo, Float32")
    }

    // MARK: - Setup

    /// Set up the audio engine and source node
    private func setupAudioEngine() throws {
        print("[AudioBridgeEngine] Setting up audio engine...")

        // Create engine
        audioEngine = AVAudioEngine()

        guard let engine = audioEngine else {
            throw AudioBridgeError.engineCreationFailed
        }

        // Create input format (16kHz, mono, Int16)
        // Note: AVAudioSourceNode requires non-interleaved format
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: inputSampleRate,
            channels: inputChannels,
            interleaved: false  // Non-interleaved for AVAudioSourceNode
        ) else {
            throw AudioBridgeError.formatCreationFailed
        }

        inputFormat = format
        print("[AudioBridgeEngine] Input format: \(format)")

        // Create source node that pulls from our circular buffer
        sourceNode = AVAudioSourceNode(format: format) { [weak self] (isSilence, timestamp, frameCount, audioBufferList) -> OSStatus in
            guard let self = self else {
                isSilence.pointee = true
                return noErr
            }

            return self.renderCallback(
                isSilence: isSilence,
                timestamp: timestamp,
                frameCount: frameCount,
                audioBufferList: audioBufferList
            )
        }

        guard let sourceNode = sourceNode else {
            throw AudioBridgeError.sourceNodeCreationFailed
        }

        // Attach source node to engine
        engine.attach(sourceNode)

        // Connect source node to main mixer
        // AVAudioEngine will automatically handle format conversion (16kHz → 48kHz)
        let mainMixer = engine.mainMixerNode
        engine.connect(sourceNode, to: mainMixer, format: format)

        print("[AudioBridgeEngine] Audio graph connected:")
        print("[AudioBridgeEngine]   SourceNode (\(format.sampleRate) Hz)")
        print("[AudioBridgeEngine]       → MainMixer (\(mainMixer.outputFormat(forBus: 0).sampleRate) Hz)")
        print("[AudioBridgeEngine]       → Output")
    }

    // MARK: - Render Callback

    /// Track if we've ever received real samples
    private var hasReceivedRealSamples = false
    private var lastNonZeroSampleCount = 0
    private var renderBufferIDLogged = false

    /// Track when capture starts to enable aggressive logging
    private var captureHasStarted = false
    private var renderLogCountAfterCapture = 0

    /// Called by AVAudioSourceNode when it needs audio data
    /// This runs on a high-priority audio thread
    private func renderCallback(
        isSilence: UnsafeMutablePointer<ObjCBool>,
        timestamp: UnsafePointer<AudioTimeStamp>,
        frameCount: AVAudioFrameCount,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>
    ) -> OSStatus {

        renderCallbackCount += 1

        // CRITICAL DEBUG: Log every 100th callback to prove render is still running
        if renderCallbackCount % 100 == 0 {
            print("[AudioBridgeEngine] 💓 HEARTBEAT Render #\(renderCallbackCount) still running")
        }

        // Get the buffer to fill
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

        guard ablPointer.count > 0,
              let dataPointer = ablPointer[0].mData?.assumingMemoryBound(to: Int16.self) else {
            isSilence.pointee = true
            return noErr
        }

        // Log buffer identity once to verify same instance
        if !renderBufferIDLogged {
            renderBufferIDLogged = true
            let bufferID = ObjectIdentifier(circularBuffer)
            print("[AudioBridgeEngine] 📍 Render buffer ID: \(bufferID)")
        }

        // Check buffer state BEFORE read
        let availableBefore = circularBuffer.availableSamples

        // Read samples from circular buffer
        let samplesRead = circularBuffer.read(into: dataPointer, count: Int(frameCount))

        // ALWAYS log if we found samples (this is the key diagnostic)
        if availableBefore > 0 || samplesRead > 0 {
            print("[AudioBridgeEngine] 🎵 FOUND SAMPLES! Render #\(renderCallbackCount): available=\(availableBefore), read=\(samplesRead)")
        }

        // Log first few, every 500th, or after capture starts
        let shouldLog = renderCallbackCount <= 5 ||
                        (renderCallbackCount % 500 == 0) ||
                        (captureHasStarted && renderLogCountAfterCapture < 20)

        if captureHasStarted {
            renderLogCountAfterCapture += 1
        }

        if shouldLog {
            let totalWritten = circularBuffer.totalSamplesWritten
            let totalRead = circularBuffer.totalSamplesRead
            print("[AudioBridgeEngine] 🔍 Render #\(renderCallbackCount): requested=\(frameCount), available=\(availableBefore), read=\(samplesRead), written=\(totalWritten), totalRead=\(totalRead)")
        }

        // Update buffer size
        audioBufferList.pointee.mBuffers.mDataByteSize = UInt32(frameCount) * UInt32(MemoryLayout<Int16>.size)

        // Mark as silence if we didn't get any real samples
        isSilence.pointee = ObjCBool(samplesRead == 0)

        // Track when we first receive real samples
        if samplesRead > 0 && !hasReceivedRealSamples {
            hasReceivedRealSamples = true
            print("[AudioBridgeEngine] 🎵 FIRST REAL SAMPLES! Playing \(samplesRead) samples")
            print("[AudioBridgeEngine] 🎵 Buffer ID: \(ObjectIdentifier(circularBuffer))")
        }

        // Track last non-zero read
        if samplesRead > 0 {
            lastNonZeroSampleCount = samplesRead
        }

        // Periodic logging (not every callback - that would flood logs)
        periodicLog(samplesRead: samplesRead, frameCount: frameCount)

        return noErr
    }

    /// Log buffer status periodically (not on every callback)
    private func periodicLog(samplesRead: Int, frameCount: AVAudioFrameCount) {
        let now = Date()
        if now.timeIntervalSince(lastLogTime) >= logInterval {
            lastLogTime = now

            let fillPercent = Int(circularBuffer.fillLevel * 100)
            let available = circularBuffer.availableSamples

            // More detailed status
            let engineRunning = audioEngine?.isRunning ?? false
            print("[AudioBridgeEngine] 📊 Status:")
            print("[AudioBridgeEngine]    Engine running: \(engineRunning)")
            print("[AudioBridgeEngine]    Buffered: \(available) samples (\(fillPercent)%)")
            print("[AudioBridgeEngine]    Callbacks: \(renderCallbackCount)")
            print("[AudioBridgeEngine]    Last read: \(samplesRead) samples")
            print("[AudioBridgeEngine]    Has received audio: \(hasReceivedRealSamples)")

            if circularBuffer.underflowCount > 0 {
                print("[AudioBridgeEngine]    ⚠️ Underflows: \(circularBuffer.underflowCount)")
            }
            if circularBuffer.totalSamplesWritten > 0 {
                print("[AudioBridgeEngine]    Total written: \(circularBuffer.totalSamplesWritten)")
                print("[AudioBridgeEngine]    Total read: \(circularBuffer.totalSamplesRead)")
            }
        }
    }

    // MARK: - Control

    /// Start the audio engine
    func start() throws {
        guard !isRunning else {
            print("[AudioBridgeEngine] Already running")
            return
        }

        print("[AudioBridgeEngine] ▶️ Starting...")

        // Configure audio session
        try configureAudioSession()

        // Setup engine if needed
        if audioEngine == nil {
            try setupAudioEngine()
        }

        guard let engine = audioEngine else {
            throw AudioBridgeError.engineNotSetup
        }

        // Reset tracking state
        hasReceivedRealSamples = false
        lastNonZeroSampleCount = 0
        renderCallbackCount = 0
        renderBufferIDLogged = false
        captureHasStarted = false
        renderLogCountAfterCapture = 0

        // Register for audio session interruption notifications
        setupInterruptionHandling()

        // Start health check timer on main thread
        startHealthCheckTimer()

        // Prepare and start
        engine.prepare()

        do {
            try engine.start()
            isRunning = true
            print("[AudioBridgeEngine] ✅ Started successfully")
            print("[AudioBridgeEngine]    Engine.isRunning: \(engine.isRunning)")
        } catch {
            print("[AudioBridgeEngine] ❌ Failed to start: \(error)")
            throw AudioBridgeError.engineStartFailed(error)
        }
    }

    /// Start a timer to monitor engine health from main thread
    private func startHealthCheckTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.healthCheckTimer?.invalidate()
            self?.healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }

                let currentCount = self.renderCallbackCount
                let engineRunning = self.audioEngine?.isRunning ?? false
                let buffered = self.circularBuffer.availableSamples
                let written = self.circularBuffer.totalSamplesWritten

                // Safe subtraction to avoid overflow when counter resets
                let callbacksPerSecond: UInt64
                if currentCount >= self.lastKnownCallbackCount {
                    callbacksPerSecond = currentCount - self.lastKnownCallbackCount
                } else {
                    // Counter was reset (engine restart), treat as 0
                    callbacksPerSecond = currentCount
                }

                // Check if engine stopped or render callback stalled
                let needsRestart = !engineRunning ||
                                   (self.lastKnownCallbackCount > 0 && callbacksPerSecond == 0)

                if needsRestart && self.captureHasStarted {
                    // Only restart once - prevent restart loop
                    guard self.restartAttempts < 3 else {
                        if self.restartAttempts == 3 {
                            print("[AudioBridgeEngine] ❌ Max restart attempts reached. Giving up.")
                            self.restartAttempts += 1  // Prevent further logging
                        }
                        return
                    }

                    self.restartAttempts += 1
                    print("[AudioBridgeEngine] 🚨 ENGINE NEEDS RESTART (attempt \(self.restartAttempts)/3)!")
                    print("[AudioBridgeEngine] 🚨   Engine running: \(engineRunning)")
                    print("[AudioBridgeEngine] 🚨   Callbacks/sec: \(callbacksPerSecond)")
                    print("[AudioBridgeEngine] 🚨   Buffer has \(buffered) samples, \(written) total written")

                    // FULL RESET: Completely tear down and rebuild the audio graph
                    print("[AudioBridgeEngine] 🔄 Full reset and rebuild...")

                    // 1. Detach and destroy old nodes
                    if let sourceNode = self.sourceNode, let engine = self.audioEngine {
                        engine.detach(sourceNode)
                    }
                    self.audioEngine?.stop()
                    self.sourceNode = nil
                    self.audioEngine = nil

                    // 2. Wait a moment for audio system to settle
                    Thread.sleep(forTimeInterval: 0.1)

                    // 3. Reconfigure audio session with mixWithOthers to coexist with SDK
                    do {
                        let session = AVAudioSession.sharedInstance()
                        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .mixWithOthers])
                        try session.setActive(true, options: [])
                        print("[AudioBridgeEngine] ✅ Audio session reconfigured (mixWithOthers)")

                        // Log current route
                        let route = session.currentRoute
                        print("[AudioBridgeEngine] 🔊 Current route outputs:")
                        for output in route.outputs {
                            print("[AudioBridgeEngine] 🔊   - \(output.portName) (\(output.portType.rawValue))")
                        }
                    } catch {
                        print("[AudioBridgeEngine] ⚠️ Audio session reconfig failed: \(error)")
                    }

                    // 4. Rebuild audio engine from scratch
                    do {
                        try self.setupAudioEngine()
                        self.audioEngine?.prepare()
                        try self.audioEngine?.start()
                        self.isRunning = true
                        self.renderCallbackCount = 0
                        self.lastKnownCallbackCount = 0

                        // Verify and set volume
                        if let engine = self.audioEngine {
                            let mixer = engine.mainMixerNode
                            let output = engine.outputNode
                            print("[AudioBridgeEngine] ✅ Engine fully rebuilt and started!")
                            print("[AudioBridgeEngine] 🔊 Mixer volume: \(mixer.outputVolume)")
                            print("[AudioBridgeEngine] 🔊 Output format: \(output.outputFormat(forBus: 0))")

                            // Ensure volume is up
                            if mixer.outputVolume < 1.0 {
                                mixer.outputVolume = 1.0
                                print("[AudioBridgeEngine] 🔊 Set mixer volume to 1.0")
                            }
                        }
                    } catch {
                        print("[AudioBridgeEngine] ❌ Failed to rebuild engine: \(error)")
                    }
                }

                self.lastKnownCallbackCount = currentCount

                // Log health status every check
                if self.captureHasStarted {
                    print("[AudioBridgeEngine] 🏥 Health: callbacks/sec=\(callbacksPerSecond), engine=\(engineRunning), buffered=\(buffered)")
                }
            }
        }
    }

    /// Stop health check timer
    private func stopHealthCheckTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.healthCheckTimer?.invalidate()
            self?.healthCheckTimer = nil
        }
    }

    /// Set up notification handling for audio session interruptions
    private func setupInterruptionHandling() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)

        // Audio route change notification
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                return
            }

            print("[AudioBridgeEngine] 🔀 AUDIO ROUTE CHANGED!")
            print("[AudioBridgeEngine] 🔀   Reason: \(reason.rawValue) (\(self?.routeChangeReasonDescription(reason) ?? "unknown"))")

            if reason == .categoryChange {
                print("[AudioBridgeEngine] ⚠️ Category changed - this might affect our engine!")
            }
        }

        // Interruption notification
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }

            switch type {
            case .began:
                print("[AudioBridgeEngine] ⚠️ AUDIO SESSION INTERRUPTED!")
                self?.isRunning = false
            case .ended:
                print("[AudioBridgeEngine] 🔄 Audio session interruption ended")
                // Try to restart
                if let options = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
                   AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                    print("[AudioBridgeEngine] 🔄 Attempting to resume...")
                    try? self?.audioEngine?.start()
                    self?.isRunning = self?.audioEngine?.isRunning ?? false
                }
            @unknown default:
                break
            }
        }
    }

    /// Stop the audio engine
    func stop() {
        guard isRunning else {
            print("[AudioBridgeEngine] Not running")
            return
        }

        print("[AudioBridgeEngine] ⏹️ Stopping...")

        stopHealthCheckTimer()
        audioEngine?.stop()
        isRunning = false

        // Log final statistics
        print("[AudioBridgeEngine] Final stats:")
        print(circularBuffer.statisticsDescription)

        // Clear buffer
        circularBuffer.clear()
        circularBuffer.resetStatistics()

        print("[AudioBridgeEngine] ✅ Stopped")
    }

    /// Reset engine (stop, clear, prepare for restart)
    func reset() {
        stop()

        // Detach nodes
        if let sourceNode = sourceNode {
            audioEngine?.detach(sourceNode)
        }
        sourceNode = nil
        audioEngine = nil

        print("[AudioBridgeEngine] 🔄 Reset complete")
    }

    // MARK: - Audio Session

    /// Configure AVAudioSession for playback
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        do {
            // Use playAndRecord for potential future talk-back feature
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetoothA2DP]
            )

            // Request 48kHz (will be accepted by iOS)
            try session.setPreferredSampleRate(outputSampleRate)

            // Small buffer for low latency
            try session.setPreferredIOBufferDuration(0.01)  // 10ms

            try session.setActive(true)

            print("[AudioBridgeEngine] Audio session configured:")
            print("[AudioBridgeEngine]   Sample rate: \(session.sampleRate) Hz")
            print("[AudioBridgeEngine]   IO buffer: \(session.ioBufferDuration * 1000) ms")
            print("[AudioBridgeEngine]   Output channels: \(session.outputNumberOfChannels)")

        } catch {
            print("[AudioBridgeEngine] ❌ Audio session config failed: \(error)")
            throw AudioBridgeError.audioSessionConfigFailed(error)
        }
    }

    // MARK: - Input Methods (Called by SDK Hook)

    /// Push audio samples from SDK render callback
    ///
    /// Call this from the swizzled AudioUnit render callback
    /// to feed audio data into our playback pipeline.
    ///
    /// - Parameters:
    ///   - samples: Pointer to Int16 PCM samples
    ///   - count: Number of samples
    func pushSamples(_ samples: UnsafePointer<Int16>, count: Int) {
        // Signal that capture has started (for debug logging)
        if !captureHasStarted {
            captureHasStarted = true
            renderLogCountAfterCapture = 0
            print("[AudioBridgeEngine] 🎬 CAPTURE STARTED - enabling aggressive render logging")
        }
        circularBuffer.write(from: samples, count: count)
    }

    /// Push audio samples from an array (for testing)
    func pushSamples(_ samples: [Int16]) {
        circularBuffer.write(from: samples)
    }

    /// Push audio samples from AudioBufferList (common in Core Audio)
    func pushAudioBufferList(_ bufferList: UnsafePointer<AudioBufferList>, frameCount: UInt32) {
        circularBuffer.write(from: bufferList, frameCount: frameCount)
    }

    // MARK: - Helpers

    /// Description for route change reason
    private func routeChangeReasonDescription(_ reason: AVAudioSession.RouteChangeReason) -> String {
        switch reason {
        case .unknown: return "unknown"
        case .newDeviceAvailable: return "newDeviceAvailable"
        case .oldDeviceUnavailable: return "oldDeviceUnavailable"
        case .categoryChange: return "categoryChange"
        case .override: return "override"
        case .wakeFromSleep: return "wakeFromSleep"
        case .noSuitableRouteForCategory: return "noSuitableRouteForCategory"
        case .routeConfigurationChange: return "routeConfigurationChange"
        @unknown default: return "unknown(\(reason.rawValue))"
        }
    }

    // MARK: - Testing Support

    /// Generate and play a test tone (for verification without camera)
    /// - Parameters:
    ///   - frequency: Tone frequency in Hz (default: 440 Hz = A4)
    ///   - duration: Duration in seconds
    func playTestTone(frequency: Float = 440, duration: TimeInterval = 1.0) {
        print("[AudioBridgeEngine] 🔊 Playing test tone: \(frequency) Hz for \(duration)s")

        let sampleCount = Int(inputSampleRate * duration)
        var samples = [Int16](repeating: 0, count: sampleCount)

        // Generate sine wave
        for i in 0..<sampleCount {
            let phase = 2.0 * Float.pi * frequency * Float(i) / Float(inputSampleRate)
            let value = sin(phase) * 0.8  // 80% amplitude to avoid clipping
            samples[i] = Int16(value * Float(Int16.max))
        }

        // Push to buffer
        pushSamples(samples)

        print("[AudioBridgeEngine] 🔊 Test tone generated: \(sampleCount) samples")
    }
}

// MARK: - Errors

enum AudioBridgeError: Error, LocalizedError {
    case engineCreationFailed
    case formatCreationFailed
    case sourceNodeCreationFailed
    case engineNotSetup
    case engineStartFailed(Error)
    case audioSessionConfigFailed(Error)

    var errorDescription: String? {
        switch self {
        case .engineCreationFailed:
            return "Failed to create AVAudioEngine"
        case .formatCreationFailed:
            return "Failed to create audio format"
        case .sourceNodeCreationFailed:
            return "Failed to create AVAudioSourceNode"
        case .engineNotSetup:
            return "Audio engine not set up"
        case .engineStartFailed(let error):
            return "Failed to start audio engine: \(error.localizedDescription)"
        case .audioSessionConfigFailed(let error):
            return "Failed to configure audio session: \(error.localizedDescription)"
        }
    }
}
