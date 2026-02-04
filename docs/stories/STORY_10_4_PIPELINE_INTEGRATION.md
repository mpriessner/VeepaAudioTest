# Story 10.4: Pipeline Integration - End-to-End Audio Playback

## Parent Story
[STORY_10_BYPASS_SDK_AUDIO.md](./STORY_10_BYPASS_SDK_AUDIO.md)

## Prerequisites
- Story 10.3 completed (we can intercept and decode G.711a audio)
- Decoded PCM16 samples available via Swift callback

## Objective
Complete the audio pipeline: receive captured audio, buffer it properly, resample from 8kHz/16kHz to 48kHz, and play through AVAudioEngine.

## Background

We have:
- G.711a decoding working (8-bit A-law → 16-bit PCM)
- Source sample rate: 8000 Hz (G.711 standard) or 16000 Hz (SDK's target)
- iOS requirement: Minimum 48000 Hz for AVAudioEngine

### Pipeline Architecture
```
┌─────────────────┐    ┌──────────────────┐    ┌──────────────────┐    ┌─────────────┐
│ G.711a Decoder  │───▶│ CircularBuffer   │───▶│ AVAudioSourceNode│───▶│ Speaker     │
│ (8kHz/16kHz)    │    │ (stores PCM16)   │    │ (48kHz output)   │    │             │
└─────────────────┘    └──────────────────┘    └──────────────────┘    └─────────────┘
                              ▲                         │
                              │                         │
                         Write @ 8kHz           Read @ 48kHz
                                                 (resample)
```

---

## Implementation Tasks

### Task 1: Verify CircularAudioBuffer Works at 8kHz

**Goal:** Ensure our existing circular buffer handles the low sample rate input.

**Test:**
```swift
func testCircularBufferAt8kHz() {
    let buffer = CircularAudioBuffer(capacity: 8000 * 2)  // 2 seconds at 8kHz

    // Simulate 20ms of audio at 8kHz (160 samples)
    let testSamples = (0..<160).map { Int16(sin(Double($0) / 10.0) * 10000) }

    buffer.write(testSamples)
    print("Written 160 samples, available: \(buffer.availableSamples)")

    var readBuffer = [Int16](repeating: 0, count: 160)
    let read = buffer.read(&readBuffer)
    print("Read \(read) samples")

    // Verify data matches
    assert(read == 160)
    assert(readBuffer == testSamples)
}
```

**Success Criteria:**
- [ ] Buffer handles small writes (160 samples = 20ms @ 8kHz)
- [ ] No data loss on read/write cycles
- [ ] Available samples count is accurate

---

### Task 2: Implement Sample Rate Conversion

**Goal:** Resample from 8kHz (or 16kHz) to 48kHz for iOS playback.

**Approach A: Simple Linear Interpolation**
```swift
class AudioResampler {
    let inputRate: Double
    let outputRate: Double
    let ratio: Double

    init(inputRate: Double, outputRate: Double) {
        self.inputRate = inputRate
        self.outputRate = outputRate
        self.ratio = outputRate / inputRate  // e.g., 48000/8000 = 6.0
    }

    func resample(_ input: [Int16]) -> [Float] {
        let outputCount = Int(Double(input.count) * ratio)
        var output = [Float](repeating: 0, count: outputCount)

        for i in 0..<outputCount {
            let srcIndex = Double(i) / ratio
            let srcIndexInt = Int(srcIndex)
            let fraction = Float(srcIndex - Double(srcIndexInt))

            let sample1 = Float(input[srcIndexInt]) / 32768.0
            let sample2 = srcIndexInt + 1 < input.count
                ? Float(input[srcIndexInt + 1]) / 32768.0
                : sample1

            output[i] = sample1 + (sample2 - sample1) * fraction
        }

        return output
    }
}
```

**Approach B: Use Accelerate Framework (Higher Quality)**
```swift
import Accelerate

class AccelerateResampler {
    func resample(_ input: [Int16], fromRate: Double, toRate: Double) -> [Float] {
        // Convert to float
        var floatInput = input.map { Float($0) / 32768.0 }

        let ratio = toRate / fromRate
        let outputCount = Int(Double(input.count) * ratio)
        var output = [Float](repeating: 0, count: outputCount)

        // Use vDSP for high-quality interpolation
        vDSP_vgenp(&floatInput,
                   vDSP_Stride(1),
                   [Float](stride(from: 0, to: Float(floatInput.count), by: Float(1.0/ratio))),
                   vDSP_Stride(1),
                   &output,
                   vDSP_Stride(1),
                   vDSP_Length(outputCount),
                   vDSP_Length(floatInput.count))

        return output
    }
}
```

**Test:**
```swift
func testResampling() {
    let resampler = AudioResampler(inputRate: 8000, outputRate: 48000)

    // 1 second of 440Hz sine at 8kHz
    let input = (0..<8000).map { i -> Int16 in
        Int16(sin(2.0 * .pi * 440.0 * Double(i) / 8000.0) * 30000)
    }

    let output = resampler.resample(input)

    print("Input: \(input.count) samples @ 8kHz")
    print("Output: \(output.count) samples @ 48kHz")
    assert(output.count == 48000)  // 6x upsampling
}
```

**Success Criteria:**
- [ ] Output sample count = input count × (48000/8000)
- [ ] Resampled audio sounds correct (no pitch shift)
- [ ] No audible artifacts (clicking, distortion)

---

### Task 3: Configure AVAudioEngine for Capture Input

**Goal:** Set up AVAudioSourceNode to read from our circular buffer.

**Implementation:**
```swift
class AudioBridgeEngine {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let circularBuffer: CircularAudioBuffer
    private let resampler: AudioResampler

    private let inputSampleRate: Double = 8000   // G.711 source rate
    private let outputSampleRate: Double = 48000 // iOS output rate
    private let bufferFrames = 1024              // Frames per callback

    init() {
        circularBuffer = CircularAudioBuffer(capacity: Int(inputSampleRate) * 5)  // 5 sec
        resampler = AudioResampler(inputRate: inputSampleRate, outputRate: outputSampleRate)
    }

    func start() throws {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: outputSampleRate,
            channels: 1,
            interleaved: false
        )!

        sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            return self.renderCallback(frameCount: frameCount, audioBufferList: audioBufferList)
        }

        engine.attach(sourceNode!)
        engine.connect(sourceNode!, to: engine.mainMixerNode, format: format)

        try engine.start()
        print("[ENGINE] Started at \(outputSampleRate) Hz")
    }

    private func renderCallback(frameCount: UInt32, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

        // Calculate how many input samples we need for this output
        let inputSamplesNeeded = Int(Double(frameCount) * inputSampleRate / outputSampleRate)

        // Read from circular buffer
        var inputBuffer = [Int16](repeating: 0, count: inputSamplesNeeded)
        let samplesRead = circularBuffer.read(&inputBuffer, count: inputSamplesNeeded)

        if samplesRead < inputSamplesNeeded {
            // Underrun - fill remainder with silence
            print("[ENGINE] Buffer underrun: need \(inputSamplesNeeded), got \(samplesRead)")
        }

        // Resample to output rate
        let resampled = resampler.resample(Array(inputBuffer[0..<samplesRead]))

        // Copy to output buffer
        for buffer in ablPointer {
            let ptr = buffer.mData?.assumingMemoryBound(to: Float.self)
            for i in 0..<Int(frameCount) {
                if i < resampled.count {
                    ptr?[i] = resampled[i]
                } else {
                    ptr?[i] = 0  // Silence for missing samples
                }
            }
        }

        return noErr
    }

    // Called from AudioHookBridge capture callback
    func onCapturedAudio(_ samples: UnsafePointer<Int16>, count: UInt32) {
        let buffer = UnsafeBufferPointer(start: samples, count: Int(count))
        circularBuffer.write(Array(buffer))
    }
}
```

**Success Criteria:**
- [ ] AVAudioEngine starts without error
- [ ] Render callback is called regularly
- [ ] Audio plays through speaker

---

### Task 4: Handle Buffer Underrun/Overrun

**Goal:** Gracefully handle timing mismatches between capture and playback.

**Underrun (buffer empty):**
```swift
private func handleUnderrun(needed: Int, available: Int) {
    // Log but don't crash
    underrunCount += 1
    print("[ENGINE] Underrun #\(underrunCount): needed \(needed), available \(available)")

    // Options:
    // 1. Output silence (current behavior)
    // 2. Stretch existing audio (can cause artifacts)
    // 3. Request more data from capture

    // For now, just output silence for missing samples
}
```

**Overrun (buffer full):**
```swift
private func handleOverrun(toWrite: Int, capacity: Int) {
    overrunCount += 1
    print("[ENGINE] Overrun #\(overrunCount): dropping \(toWrite) samples")

    // Options:
    // 1. Drop oldest samples (keeps latency low)
    // 2. Drop new samples (preserves continuity)
    // 3. Increase buffer size

    // Clear some space
    circularBuffer.discard(toWrite)
}
```

**Success Criteria:**
- [ ] Underrun produces silence, not noise
- [ ] Overrun doesn't crash or corrupt buffer
- [ ] Audio continues after brief interruptions

---

### Task 5: Add Latency/Quality Controls

**Goal:** Allow tuning buffer size and quality parameters.

**Implementation:**
```swift
struct AudioConfig {
    var bufferDurationSeconds: Double = 0.5    // Buffer size
    var targetLatencyMs: Double = 100          // Target latency
    var resampleQuality: ResampleQuality = .linear

    enum ResampleQuality {
        case linear     // Fast, lower quality
        case sinc       // Slow, higher quality
    }
}

extension AudioBridgeEngine {
    func configure(_ config: AudioConfig) {
        // Resize buffer
        let newCapacity = Int(inputSampleRate * config.bufferDurationSeconds)
        circularBuffer.resize(capacity: newCapacity)

        // Set resampler quality
        resampler.quality = config.resampleQuality

        print("[CONFIG] Buffer: \(config.bufferDurationSeconds)s, Latency target: \(config.targetLatencyMs)ms")
    }
}
```

---

### Task 6: End-to-End Integration Test

**Goal:** Verify complete pipeline from camera to speaker.

**Test Procedure:**
1. Connect to camera
2. Send audio CGI command (Story 10.2)
3. Start capture (Story 10.3)
4. Start AVAudioEngine playback
5. Verify audio is heard

**Automated Test:**
```swift
func testEndToEndAudioPipeline() async throws {
    // Setup
    let bridge = AudioHookBridge.shared
    let engine = AudioBridgeEngine()

    // Wire up callback
    bridge.captureCallback = { samples, count in
        engine.onCapturedAudio(samples, count: count)
    }

    // Start playback
    try engine.start()

    // Connect to camera
    try await connectToCamera(uid: "OKB0379196OXYB")

    // Send audio CGI
    bridge.sendCgiCommand("audiostream.cgi?streamid=0&", toClient: clientPtr)

    // Start capture
    bridge.startVoiceBufferCapture()

    // Wait and verify
    try await Task.sleep(for: .seconds(5))

    // Check metrics
    let stats = engine.getStatistics()
    print("Samples processed: \(stats.samplesProcessed)")
    print("Underruns: \(stats.underrunCount)")
    print("Buffer level: \(stats.bufferLevelPercent)%")

    // Success if we processed > 0 samples and few underruns
    assert(stats.samplesProcessed > 40000)  // At least 5 seconds of audio
    assert(stats.underrunCount < 10)        // Few underruns
}
```

---

## UI Changes

Add playback controls:
```swift
VStack {
    HStack {
        Button(engine.isPlaying ? "Stop Playback" : "Start Playback") {
            if engine.isPlaying {
                engine.stop()
            } else {
                try? engine.start()
            }
        }

        Button("Full Pipeline") {
            // One-button to start everything
            startFullAudioPipeline()
        }
    }

    // Status indicators
    Text("Buffer: \(bufferLevelPercent)%")
    Text("Underruns: \(underrunCount)")
    Text("Latency: \(estimatedLatencyMs)ms")
}
```

---

## Verification Tests

### Test 1: Engine Starts
```
Expected:
[ENGINE] Started at 48000.0 Hz
```

### Test 2: Render Callback Active
```
Expected (continuous):
[ENGINE] Rendered 1024 frames
[ENGINE] Buffer level: 45%
```

### Test 3: Audio Audible
```
Manual verification:
- Connect to camera with microphone
- Make sound near camera
- Hear sound from iOS device speaker
```

### Test 4: Statistics
```
After 10 seconds:
Samples processed: > 80000
Underruns: < 20
Buffer level: 30-70%
```

---

## Acceptance Criteria

- [ ] AVAudioEngine plays continuously without crashes
- [ ] Audio is audible through device speaker
- [ ] Latency is acceptable (< 500ms)
- [ ] Buffer underruns are rare (< 1 per second)
- [ ] Audio quality is acceptable (no major distortion)
- [ ] Can start/stop playback reliably

## Exit Criteria

**SUCCESS:** Camera audio plays through iOS device speaker with acceptable quality

**PARTIAL SUCCESS:** Audio plays but with issues:
- High latency → Tune buffer sizes
- Frequent underruns → Increase buffer or optimize capture
- Distortion → Check decoder and resampler

---

## Estimated Duration
2-3 hours

## Risk Assessment
| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Resampling artifacts | Medium | Use Accelerate framework |
| Buffer underruns | Medium | Tune buffer sizes |
| High latency | Low | Reduce buffer, optimize path |

---

## Files to Modify

| File | Changes |
|------|---------|
| `AudioBridgeEngine.swift` | Full implementation of playback pipeline |
| `AudioResampler.swift` | New file for resampling |
| `CircularAudioBuffer.swift` | May need capacity adjustment |
| `ContentView.swift` | Add playback controls |

---

## Definition of Done

When all acceptance criteria are met:
1. Camera audio plays through iOS speaker
2. Solution is stable for extended playback
3. Code is documented and maintainable
4. Performance metrics are within acceptable bounds

This completes the Story 10 epic: **Bypass SDK Audio - Direct Camera Audio Control**
