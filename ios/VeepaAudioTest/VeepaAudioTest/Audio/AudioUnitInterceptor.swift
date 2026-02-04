//
//  AudioUnitInterceptor.swift
//  VeepaAudioTest
//
//  Created for AudioUnit Hook implementation
//  Purpose: Intercept SDK's AudioUnit to tap 16kHz audio data
//
//  Strategy:
//  1. Hook AudioUnitRender to intercept when SDK calls its render callback
//  2. Copy the 16kHz audio data to our CircularAudioBuffer
//  3. Let AudioBridgeEngine play it at 48kHz
//
//  Alternative approach if render hook doesn't work:
//  - Use AudioUnitAddRenderNotify to get notified after each render
//

import Foundation
import AudioToolbox
import AVFoundation

/// Intercepts SDK's AudioUnit to capture 16kHz audio
///
/// This class hooks into the Core Audio system to:
/// 1. Detect when SDK creates its RemoteIO AudioUnit
/// 2. Install a render notify callback to tap audio data
/// 3. Forward captured audio to AudioBridgeEngine for playback
///
final class AudioUnitInterceptor {

    // MARK: - Singleton

    static let shared = AudioUnitInterceptor()

    // MARK: - State

    /// The SDK's AudioUnit that we're monitoring
    private(set) var interceptedAudioUnit: AudioUnit?

    /// Whether we've successfully installed the render tap
    private(set) var isInterceptorInstalled = false

    /// Statistics for debugging
    fileprivate(set) var capturedFrameCount: UInt64 = 0
    fileprivate(set) var lastCaptureTime: Date?

    // MARK: - Debug

    fileprivate var logCount = 0
    fileprivate let maxLogs = 20  // Limit logs to avoid flooding

    // MARK: - Initialization

    private init() {
        print("[AudioUnitInterceptor] Initialized")
    }

    // MARK: - AudioUnit Discovery

    /// Attempt to find and intercept the SDK's AudioUnit
    ///
    /// This searches through the runtime for AudioUnit instances
    /// that match the SDK's audio configuration (16kHz, mono, Int16)
    ///
    /// Note: This is a diagnostic function - actual interception
    /// happens via AudioUnitAddRenderNotify on a known AudioUnit
    func discoverAudioUnits() -> [String] {
        var discoveries: [String] = []

        print("[AudioUnitInterceptor] ═══════════════════════════════════════")
        print("[AudioUnitInterceptor] 🔍 Discovering AudioUnits...")
        print("[AudioUnitInterceptor] ═══════════════════════════════════════")

        // Check if we can find AppIOSPlayer class at runtime
        if let playerClass = NSClassFromString("AppIOSPlayer") {
            discoveries.append("Found AppIOSPlayer class: \(playerClass)")
            print("[AudioUnitInterceptor] ✅ AppIOSPlayer class exists")

            // Try to find instances - this is tricky without knowing the exact instance
            // The SDK manages its own instance lifecycle
        } else {
            discoveries.append("AppIOSPlayer class not found")
            print("[AudioUnitInterceptor] ❌ AppIOSPlayer class not found")
        }

        // Check available audio components
        var desc = AudioComponentDescription()
        desc.componentType = kAudioUnitType_Output
        desc.componentSubType = kAudioUnitSubType_RemoteIO
        desc.componentManufacturer = kAudioUnitManufacturer_Apple

        var component: AudioComponent? = AudioComponentFindNext(nil, &desc)
        while let comp = component {
            var unmanagedName: Unmanaged<CFString>?
            AudioComponentCopyName(comp, &unmanagedName)
            if let cfName = unmanagedName?.takeRetainedValue() {
                let name = cfName as String
                discoveries.append("Audio component: \(name)")
                print("[AudioUnitInterceptor]   Component: \(name)")
            }
            component = AudioComponentFindNext(comp, &desc)
        }

        print("[AudioUnitInterceptor] ═══════════════════════════════════════")

        return discoveries
    }

    // MARK: - Render Notify Installation

    /// Install a render notify callback on the given AudioUnit
    ///
    /// This is the primary method to capture audio from the SDK's AudioUnit.
    /// The callback will be invoked after each render cycle.
    ///
    /// - Parameter audioUnit: The AudioUnit to tap (SDK's RemoteIO unit)
    /// - Returns: true if successfully installed
    @discardableResult
    func installRenderNotify(on audioUnit: AudioUnit) -> Bool {
        print("[AudioUnitInterceptor] ═══════════════════════════════════════")
        print("[AudioUnitInterceptor] 📌 Installing Render Notify")
        print("[AudioUnitInterceptor] ═══════════════════════════════════════")

        // Store reference
        interceptedAudioUnit = audioUnit

        // Get current format info for logging
        var streamFormat = AudioStreamBasicDescription()
        var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)

        let formatStatus = AudioUnitGetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            1,  // Element 1 = input (microphone) side of RemoteIO
            &streamFormat,
            &propertySize
        )

        if formatStatus == noErr {
            print("[AudioUnitInterceptor] AudioUnit format:")
            print("[AudioUnitInterceptor]   Sample rate: \(streamFormat.mSampleRate) Hz")
            print("[AudioUnitInterceptor]   Channels: \(streamFormat.mChannelsPerFrame)")
            print("[AudioUnitInterceptor]   Bits/channel: \(streamFormat.mBitsPerChannel)")
            print("[AudioUnitInterceptor]   Format flags: \(streamFormat.mFormatFlags)")
        } else {
            print("[AudioUnitInterceptor] ⚠️ Could not get format: \(formatStatus)")
        }

        // Install render notify callback
        let status = AudioUnitAddRenderNotify(
            audioUnit,
            renderNotifyCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )

        if status == noErr {
            isInterceptorInstalled = true
            capturedFrameCount = 0
            print("[AudioUnitInterceptor] ✅ Render notify installed successfully")
        } else {
            isInterceptorInstalled = false
            print("[AudioUnitInterceptor] ❌ Failed to install render notify: \(status)")
        }

        print("[AudioUnitInterceptor] ═══════════════════════════════════════")

        return status == noErr
    }

    /// Remove the render notify callback
    func removeRenderNotify() {
        guard let audioUnit = interceptedAudioUnit else { return }

        print("[AudioUnitInterceptor] 🔌 Removing render notify...")

        let status = AudioUnitRemoveRenderNotify(
            audioUnit,
            renderNotifyCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )

        if status == noErr {
            print("[AudioUnitInterceptor] ✅ Render notify removed")
        } else {
            print("[AudioUnitInterceptor] ⚠️ Remove status: \(status)")
        }

        isInterceptorInstalled = false
        interceptedAudioUnit = nil

        // Log final stats
        print("[AudioUnitInterceptor] Final stats: \(capturedFrameCount) frames captured")
    }

    // MARK: - Manual AudioUnit Creation (Fallback)

    /// Create our own AudioUnit that mimics the SDK's configuration
    ///
    /// This is a fallback if we can't intercept the SDK's unit directly.
    /// We create a unit that accepts 16kHz input and hooks into it.
    ///
    /// - Returns: The created AudioUnit, or nil on failure
    func createInterceptorUnit() -> AudioUnit? {
        print("[AudioUnitInterceptor] 🔧 Creating interceptor AudioUnit...")

        // Describe RemoteIO
        var desc = AudioComponentDescription()
        desc.componentType = kAudioUnitType_Output
        desc.componentSubType = kAudioUnitSubType_RemoteIO
        desc.componentManufacturer = kAudioUnitManufacturer_Apple
        desc.componentFlags = 0
        desc.componentFlagsMask = 0

        guard let component = AudioComponentFindNext(nil, &desc) else {
            print("[AudioUnitInterceptor] ❌ RemoteIO component not found")
            return nil
        }

        var audioUnit: AudioUnit?
        var status = AudioComponentInstanceNew(component, &audioUnit)

        guard status == noErr, let unit = audioUnit else {
            print("[AudioUnitInterceptor] ❌ Failed to create AudioUnit: \(status)")
            return nil
        }

        // Configure for 16kHz mono input (matching SDK)
        var streamFormat = AudioStreamBasicDescription()
        streamFormat.mSampleRate = 16000
        streamFormat.mFormatID = kAudioFormatLinearPCM
        streamFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        streamFormat.mBytesPerPacket = 2
        streamFormat.mFramesPerPacket = 1
        streamFormat.mBytesPerFrame = 2
        streamFormat.mChannelsPerFrame = 1
        streamFormat.mBitsPerChannel = 16

        // Set the format on the input scope
        status = AudioUnitSetProperty(
            unit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            0,  // Element 0 = output (speaker) side
            &streamFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )

        if status != noErr {
            print("[AudioUnitInterceptor] ⚠️ Format set returned: \(status)")
            // Continue anyway - this might fail with error -50
        }

        // Initialize
        status = AudioUnitInitialize(unit)

        if status == noErr {
            print("[AudioUnitInterceptor] ✅ Interceptor unit created and initialized")
            return unit
        } else {
            print("[AudioUnitInterceptor] ❌ Initialize failed: \(status)")
            AudioComponentInstanceDispose(unit)
            return nil
        }
    }

    // MARK: - Statistics

    /// Get statistics as a formatted string
    var statisticsDescription: String {
        let lastCapture = lastCaptureTime.map {
            DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .medium)
        } ?? "never"

        return """
        AudioUnitInterceptor Statistics:
          Installed: \(isInterceptorInstalled)
          Captured frames: \(capturedFrameCount)
          Last capture: \(lastCapture)
        """
    }
}

// MARK: - Render Notify Callback

/// C-style callback for AudioUnitAddRenderNotify
///
/// This is called before and after each render cycle.
/// We capture the audio data in the kAudioUnitRenderAction_PostRender phase.
private let renderNotifyCallback: AURenderCallback = { (
    inRefCon: UnsafeMutableRawPointer,
    ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    inTimeStamp: UnsafePointer<AudioTimeStamp>,
    inBusNumber: UInt32,
    inNumberFrames: UInt32,
    ioData: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus in

    // Get our interceptor instance
    let interceptor = Unmanaged<AudioUnitInterceptor>.fromOpaque(inRefCon).takeUnretainedValue()

    // We only care about post-render (when data is available)
    let flags = ioActionFlags.pointee
    guard flags.contains(.unitRenderAction_PostRender) else {
        return noErr
    }

    // Need valid data
    guard let bufferList = ioData else {
        return noErr
    }

    // Get the audio data
    let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
    guard ablPointer.count > 0,
          let audioData = ablPointer[0].mData?.assumingMemoryBound(to: Int16.self) else {
        return noErr
    }

    // Push to our audio bridge
    let engine = AudioBridgeEngine.shared
    engine.pushSamples(audioData, count: Int(inNumberFrames))

    // Update statistics
    interceptor.capturedFrameCount += UInt64(inNumberFrames)
    interceptor.lastCaptureTime = Date()

    // Limited logging to avoid performance impact
    if interceptor.logCount < interceptor.maxLogs {
        interceptor.logCount += 1
        print("[AudioUnitInterceptor] 🎤 Captured \(inNumberFrames) frames from bus \(inBusNumber)")
    } else if interceptor.logCount == interceptor.maxLogs {
        interceptor.logCount += 1
        print("[AudioUnitInterceptor] 🔇 Silencing further capture logs...")
    }

    return noErr
}

// MARK: - Method Swizzling Support

extension AudioUnitInterceptor {

    /// Install method swizzling to intercept AudioUnit creation
    ///
    /// This swizzles key Core Audio functions to detect when the SDK
    /// creates its AudioUnit, allowing us to install our tap.
    ///
    /// CAUTION: Method swizzling is powerful but risky. This should
    /// only be used for debugging/development purposes.
    ///
    /// Swizzled functions:
    /// - AudioUnitSetProperty: To detect format configuration
    /// - AudioUnitRender: To intercept render calls (if needed)
    ///
    static func installSwizzling() {
        print("[AudioUnitInterceptor] ═══════════════════════════════════════")
        print("[AudioUnitInterceptor] 🔀 Installing Method Swizzling")
        print("[AudioUnitInterceptor] ═══════════════════════════════════════")

        // Note: Core Audio C functions can't be swizzled directly
        // We need to use a different approach - see AudioHookBridge.m

        // For now, just log that we would install swizzling
        // The actual implementation requires Objective-C interop

        print("[AudioUnitInterceptor] ⚠️ C function swizzling requires fishhook/Substitute")
        print("[AudioUnitInterceptor] ⚠️ Or Objective-C method swizzling on AppIOSPlayer")
        print("[AudioUnitInterceptor] ═══════════════════════════════════════")
    }
}
