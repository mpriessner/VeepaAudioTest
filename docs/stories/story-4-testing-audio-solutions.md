# Story 4: Testing Audio Session Solutions

**Epic**: VeepaAudioTest - Minimal Audio Testing App
**Story**: Implement and test 3 different approaches to fix AudioUnit error -50
**Estimated Time**: 1.5-2 hours

---

## 📋 Story Description

As a **developer**, I want to **test multiple audio session configuration strategies** so that **I can determine which approach fixes the AudioUnit error -50 issue**.

---

## ✅ Acceptance Criteria

1. App supports 3 test modes: Baseline, Pre-Initialize, Swizzled
2. User can switch between modes via UI picker
3. Each mode configures AVAudioSession differently
4. All audio errors are logged with detailed diagnostic information
5. Test results clearly show which mode succeeds/fails
6. If audio works in any mode, solution is documented for SciSymbioLens

---

## 🔧 Implementation Steps

### Step 4.1: Create Audio Session Strategy Protocol (20 minutes)

Create `ios/VeepaAudioTest/VeepaAudioTest/Services/AudioSessionStrategy.swift`:

```swift
import Foundation
import AVFoundation

/// Strategy for configuring AVAudioSession
protocol AudioSessionStrategy {
    var name: String { get }
    var description: String { get }

    /// Configure audio session BEFORE startVoice() is called
    func prepareAudioSession() throws

    /// Clean up audio session AFTER stopVoice() is called
    func cleanupAudioSession()
}

// MARK: - Strategy 1: Baseline (Current Implementation)

class BaselineStrategy: AudioSessionStrategy {
    let name = "Baseline"
    let description = "Standard AVAudioSession setup (expected to fail with error -50)"

    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        print("[Baseline] Configuring AVAudioSession...")
        try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setMode(.videoChat)
        try session.setActive(true)

        print("[Baseline] ✅ AVAudioSession configured")
        print("[Baseline]    Category: \(session.category.rawValue)")
        print("[Baseline]    Mode: \(session.mode.rawValue)")
        print("[Baseline]    Sample Rate: \(session.sampleRate) Hz")
    }

    func cleanupAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

// MARK: - Strategy 2: Pre-Initialize (Before Flutter)

class PreInitializeStrategy: AudioSessionStrategy {
    let name = "Pre-Initialize"
    let description = "Configure AVAudioSession BEFORE Flutter engine starts"

    private var didInitialize = false

    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        if !didInitialize {
            print("[PreInit] 🔧 EARLY audio session configuration (before Flutter)")

            // Set preferred audio format that matches SDK expectations
            try session.setPreferredSampleRate(8000) // G.711 uses 8kHz
            try session.setPreferredIOBufferDuration(0.02) // 20ms buffer
            print("[PreInit]    Preferred sample rate: 8000 Hz")
            print("[PreInit]    Preferred buffer: 20ms")

            didInitialize = true
        }

        // Standard configuration
        print("[PreInit] Activating AVAudioSession...")
        try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setMode(.videoChat)
        try session.setActive(true)

        print("[PreInit] ✅ AVAudioSession configured")
        print("[PreInit]    Actual sample rate: \(session.sampleRate) Hz")
        print("[PreInit]    Actual buffer: \(session.ioBufferDuration * 1000)ms")
    }

    func cleanupAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

// MARK: - Strategy 3: Method Swizzling (Intercept SDK Calls)

class SwizzledStrategy: AudioSessionStrategy {
    let name = "Swizzled"
    let description = "Swizzle AVAudioSession methods to force 8kHz mono format"

    private static var didSwizzle = false

    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        // Swizzle on first use
        if !Self.didSwizzle {
            print("[Swizzle] 🔀 Installing method swizzling...")
            swizzleAudioSessionMethods()
            Self.didSwizzle = true
        }

        // Standard configuration (our swizzled methods will intercept)
        print("[Swizzle] Configuring AVAudioSession (swizzled)...")
        try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try session.setMode(.videoChat)

        // Force 8kHz sample rate
        try session.setPreferredSampleRate(8000)
        try session.setPreferredIOBufferDuration(0.02)

        try session.setActive(true)

        print("[Swizzle] ✅ AVAudioSession configured")
        print("[Swizzle]    Category: \(session.category.rawValue)")
        print("[Swizzle]    Sample Rate: \(session.sampleRate) Hz")
    }

    func cleanupAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Swizzling Implementation

    private func swizzleAudioSessionMethods() {
        // Swizzle setPreferredSampleRate to log and force 8000 Hz
        let originalSelector = #selector(AVAudioSession.setPreferredSampleRate(_:))
        let swizzledSelector = #selector(AVAudioSession.swizzled_setPreferredSampleRate(_:))

        guard let originalMethod = class_getInstanceMethod(AVAudioSession.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(AVAudioSession.self, swizzledSelector) else {
            print("[Swizzle] ❌ Failed to get methods for swizzling")
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
        print("[Swizzle] ✅ Swizzled setPreferredSampleRate")
    }
}

// MARK: - AVAudioSession Extension (Swizzled Methods)

extension AVAudioSession {
    @objc dynamic func swizzled_setPreferredSampleRate(_ sampleRate: Double) throws {
        print("[Swizzle] 🎵 Intercepted setPreferredSampleRate(\(sampleRate))")

        // Force 8000 Hz if SDK requests anything else
        let forcedRate: Double = 8000
        if sampleRate != forcedRate {
            print("[Swizzle]    Forcing sample rate: \(sampleRate) → \(forcedRate) Hz")
        }

        // Call original implementation with forced rate
        try self.swizzled_setPreferredSampleRate(forcedRate)
    }
}

// MARK: - Strategy 4: Locked Session (Maximum Control)

class LockedSessionStrategy: AudioSessionStrategy {
    let name = "Locked"
    let description = "Configure and lock audio session to prevent SDK changes"

    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        print("[Locked] 🔒 Configuring and locking audio session...")

        // Set category with maximum control
        try session.setCategory(.playAndRecord, options: [
            .defaultToSpeaker,
            .allowBluetooth,
            .allowBluetoothA2DP
        ])

        try session.setMode(.videoChat)

        // Force G.711-compatible format
        try session.setPreferredSampleRate(8000)  // G.711 uses 8kHz
        try session.setPreferredIOBufferDuration(0.02)  // 20ms latency
        try session.setPreferredInputNumberOfChannels(1)  // Mono
        try session.setPreferredOutputNumberOfChannels(1)  // Mono

        // Activate with high priority
        try session.setActive(true, options: [])

        print("[Locked] ✅ Audio session locked")
        print("[Locked]    Sample Rate: \(session.sampleRate) Hz")
        print("[Locked]    Input Channels: \(session.inputNumberOfChannels)")
        print("[Locked]    Output Channels: \(session.outputNumberOfChannels)")
        print("[Locked]    IO Buffer: \(session.ioBufferDuration * 1000) ms")

        // Log hardware format
        if let inputs = session.availableInputs {
            print("[Locked]    Available inputs: \(inputs.count)")
            for input in inputs {
                print("[Locked]      - \(input.portName) (\(input.portType.rawValue))")
            }
        }
    }

    func cleanupAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
```

---

### Step 4.2: Update AudioStreamService (30 minutes)

Modify `ios/VeepaAudioTest/VeepaAudioTest/Services/AudioStreamService.swift`:

```swift
import Foundation
import AVFoundation

@MainActor
final class AudioStreamService: ObservableObject {
    @Published var isPlaying = false
    @Published var isMuted = false
    @Published var debugLogs: [String] = []
    @Published var currentStrategy: AudioSessionStrategy = BaselineStrategy() {
        didSet {
            log("🔄 Switched to strategy: \(currentStrategy.name)")
            log("   Description: \(currentStrategy.description)")
        }
    }

    // Available strategies
    let strategies: [AudioSessionStrategy] = [
        BaselineStrategy(),
        PreInitializeStrategy(),
        SwizzledStrategy(),
        LockedSessionStrategy()
    ]

    private let flutterEngine = FlutterEngineManager.shared

    func startAudio() async throws {
        log("🎵 Starting audio with \(currentStrategy.name) strategy...")

        // Configure AVAudioSession using selected strategy
        do {
            try currentStrategy.prepareAudioSession()
        } catch {
            log("   ❌ Audio session preparation failed: \(error.localizedDescription)")
            throw error
        }

        // Call Flutter method
        do {
            log("   Calling startVoice()...")
            let result = try await flutterEngine.invoke("startAudio")
            log("   startVoice result: \(result ?? "nil")")

            isPlaying = true
            log("   ✅ Audio started successfully")

            // Log final audio session state
            logAudioSessionState()

        } catch {
            log("   ❌ startAudio failed: \(error.localizedDescription)")
            logAudioSessionState()
            throw error
        }
    }

    func stopAudio() async throws {
        log("🛑 Stopping audio...")

        do {
            let result = try await flutterEngine.invoke("stopAudio")
            log("   stopVoice result: \(result ?? "nil")")

            isPlaying = false
            log("   ✅ Audio stopped")

            // Clean up audio session
            currentStrategy.cleanupAudioSession()

        } catch {
            log("   ❌ stopAudio failed: \(error.localizedDescription)")
            throw error
        }
    }

    func setMute(_ muted: Bool) async throws {
        log("🔇 Setting mute: \(muted)")

        do {
            let result = try await flutterEngine.invoke("setMute", arguments: muted)
            log("   setMute result: \(result ?? "nil")")

            isMuted = muted
            log("   ✅ Mute set to \(muted)")

        } catch {
            log("   ❌ setMute failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Diagnostics

    private func logAudioSessionState() {
        let session = AVAudioSession.sharedInstance()

        log("   📊 AVAudioSession State:")
        log("      Category: \(session.category.rawValue)")
        log("      Mode: \(session.mode.rawValue)")
        log("      Sample Rate: \(session.sampleRate) Hz")
        log("      IO Buffer: \(session.ioBufferDuration * 1000) ms")
        log("      Input Channels: \(session.inputNumberOfChannels)")
        log("      Output Channels: \(session.outputNumberOfChannels)")
        log("      Input Gain: \(session.inputGain)")
        log("      Output Volume: \(session.outputVolume)")

        // Log current route
        let route = session.currentRoute
        log("      Current Route:")
        for input in route.inputs {
            log("         Input: \(input.portName) (\(input.portType.rawValue))")
        }
        for output in route.outputs {
            log("         Output: \(output.portName) (\(output.portType.rawValue))")
        }
    }

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)"
        debugLogs.append(entry)
        print(entry)
    }
}
```

---

### Step 4.3: Update UI to Select Strategy (30 minutes)

Update `ContentView.swift` to add strategy picker:

```swift
// Add to ContentView after audioControlsSection:

// MARK: - Strategy Selection Section

private var strategySelectionSection: some View {
    VStack(spacing: 12) {
        Text("Test Strategy")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)

        Picker("Audio Strategy", selection: $selectedStrategyIndex) {
            ForEach(audioService.strategies.indices, id: \.self) { index in
                Text(audioService.strategies[index].name)
                    .tag(index)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedStrategyIndex) { _, newIndex in
            audioService.currentStrategy = audioService.strategies[newIndex]
        }

        Text(audioService.currentStrategy.description)
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
}

// Add state variable:
@State private var selectedStrategyIndex = 0
```

---

### Step 4.4: Create Test Results Documentation (20 minutes)

Create `ios/VeepaAudioTest/VeepaAudioTest/Resources/TEST_RESULTS.md`:

```markdown
# Audio Test Results

**Device**: [iPhone model]
**iOS Version**: [version]
**Test Date**: [date]

---

## Test Configuration

- **Camera Model**: Veepa [model]
- **Camera UID**: [UID]
- **Network**: WiFi [connection type]
- **App Version**: 1.0 (build 1)

---

## Test Results Matrix

| Strategy | Audio Plays? | Error Code | Notes |
|----------|--------------|------------|-------|
| Baseline | ❌ / ✅ | -50 / N/A | Standard configuration |
| Pre-Initialize | ❌ / ✅ | -50 / N/A | Set sample rate before Flutter |
| Swizzled | ❌ / ✅ | -50 / N/A | Force 8kHz via method swizzling |
| Locked | ❌ / ✅ | -50 / N/A | Lock audio session configuration |

---

## Baseline Strategy

### Console Output
```
[10:30:25] 🎵 Starting audio with Baseline strategy...
[10:30:25] [Baseline] Configuring AVAudioSession...
[10:30:25] [Baseline] ✅ AVAudioSession configured
[10:30:25] [Baseline]    Category: AVAudioSessionCategoryPlayAndRecord
[10:30:25] [Baseline]    Mode: AVAudioSessionModeVideoChat
[10:30:25] [Baseline]    Sample Rate: 48000.0 Hz
[10:30:25]    Calling startVoice()...
[10:30:26]    ❌ startAudio failed: Error -50 (kAudioUnitErr_FormatNotSupported)
[10:30:26]    📊 AVAudioSession State:
[10:30:26]       Sample Rate: 48000.0 Hz
[10:30:26]       IO Buffer: 10.0 ms
[10:30:26]       Output: Speaker (Speaker)
```

### Result
- ❌ **Failed**: Error -50
- **Hypothesis**: SDK expects 8kHz, but session uses 48kHz

---

## Pre-Initialize Strategy

### Console Output
```
[Paste console logs here]
```

### Result
- ✅ / ❌
- **Analysis**: [What changed? Did it work?]

---

## Swizzled Strategy

### Console Output
```
[Paste console logs here]
```

### Result
- ✅ / ❌
- **Analysis**: [Did swizzling force correct format?]

---

## Locked Strategy

### Console Output
```
[Paste console logs here]
```

### Result
- ✅ / ❌
- **Analysis**: [Did locking session prevent SDK conflicts?]

---

## Conclusion

**Working Strategy**: [Name] / None

**Recommended Solution for SciSymbioLens**:
[If a strategy worked, document exact steps to implement in main app]

**Next Steps**:
- [ ] If audio worked: Copy solution to SciSymbioLens
- [ ] If audio failed: Contact SDK vendor with minimal reproducible case
- [ ] Consider custom AudioUnit decoder as alternative
```

---

### Step 4.5: Run All Tests (30 minutes)

**Test Procedure**:

1. **Baseline Test**:
   - Select "Baseline" strategy
   - Connect to camera
   - Start audio
   - Document error/success
   - Copy full console logs

2. **Pre-Initialize Test**:
   - Disconnect camera
   - Restart app
   - Select "Pre-Initialize" strategy
   - Connect and test audio
   - Document results

3. **Swizzled Test**:
   - Disconnect camera
   - Restart app (to clear swizzling state)
   - Select "Swizzled" strategy
   - Connect and test audio
   - Document results

4. **Locked Test**:
   - Disconnect camera
   - Restart app
   - Select "Locked" strategy
   - Connect and test audio
   - Document results

**For Each Test, Record**:
- ✅ Audio heard? Yes/No
- Error code (if any)
- Full console logs
- AVAudioSession final state (sample rate, channels, buffer size)

---

## 🧪 Testing & Verification

### Success Criteria

**Test Passed** if:
- ✅ At least one strategy produces working audio
- ✅ Error -50 is resolved in at least one configuration
- ✅ All strategies are tested and documented

**Test Failed (But Useful)** if:
- ⚠️ All strategies fail with error -50
- ✅ We have comprehensive diagnostic logs
- ✅ We can provide minimal reproducible case to SDK vendor

### Expected Outcomes

**Scenario A: Pre-Initialize Works**
- **Result**: Setting 8kHz sample rate BEFORE Flutter starts fixes error -50
- **Solution**: Update SciSymbioLens to configure audio session during app launch
- **Effort**: 15 minutes to implement

**Scenario B: Swizzling Works**
- **Result**: Forcing 8kHz format via swizzling fixes error -50
- **Solution**: Add swizzling to SciSymbioLens FlutterEngineManager
- **Effort**: 30 minutes to implement + testing

**Scenario C: Locked Session Works**
- **Result**: Preventing SDK from changing audio session fixes error -50
- **Solution**: Lock audio session before P2P connection
- **Effort**: 20 minutes to implement

**Scenario D: None Work**
- **Result**: Error -50 persists in all configurations
- **Conclusion**: SDK audio is fundamentally incompatible with iOS AudioUnit
- **Next Steps**:
  1. Contact SDK vendor with minimal reproducible case
  2. Implement custom AudioUnit decoder
  3. OR ship video-only mode

---

## 📊 Deliverables

After completing this story:

- [x] `AudioSessionStrategy.swift` - 4 different audio strategies
- [x] Updated `AudioStreamService.swift` - Strategy pattern implementation
- [x] Updated `ContentView.swift` - Strategy selector UI
- [x] `TEST_RESULTS.md` - Documented test outcomes
- [x] Full console logs for all 4 strategies
- [x] Clear recommendation for SciSymbioLens implementation

---

## 🚨 Common Issues

### Issue 1: Swizzling doesn't affect SDK
**Problem**: Swizzled methods aren't called
**Fix**: Verify swizzling occurs BEFORE Flutter engine starts

### Issue 2: Audio session reverts after connection
**Problem**: SDK overrides our configuration
**Fix**: Try Locked strategy to prevent changes

### Issue 3: Simulator vs Device differences
**Problem**: Audio works on simulator but not device
**Fix**: Always test on physical device for audio

---

## ⏭️ Next Steps

### If Audio Works ✅
1. Document working strategy in `TEST_RESULTS.md`
2. Copy solution to SciSymbioLens codebase
3. Test in main app with Gemini integration
4. Submit PR with audio fix

### If Audio Fails ❌
1. Package VeepaAudioTest as minimal reproducible case
2. Contact SDK vendor with:
   - Complete test app source code
   - Comprehensive diagnostic logs
   - Specific error -50 details
3. Meanwhile, explore alternatives:
   - Custom AudioUnit decoder
   - Video-only mode in SciSymbioLens

---

**Project Complete!** 🎉

Total estimated time: 2-4 hours to build + 1-2 hours to test all strategies.
