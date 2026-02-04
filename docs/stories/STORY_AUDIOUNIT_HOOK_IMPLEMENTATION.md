# Story: AudioUnit Hook Implementation

**Story ID**: AUDIO-001
**Priority**: High
**Estimate**: 4-6 hours
**Status**: Ready for Implementation

---

## Story Description

As a developer, I want to intercept audio from the SDK's AudioUnit render callback and play it through our own AVAudioEngine, so that we can resample 16kHz camera audio to 48kHz for iOS playback.

---

## Acceptance Criteria

- [ ] Audio from camera plays through iPhone speaker
- [ ] No crashes during start/stop cycles
- [ ] Audio quality is acceptable (no major distortion)
- [ ] Latency is reasonable (< 1 second)
- [ ] Solution can be transferred to SciSymbioLens

---

## Implementation Steps

### Step 1: Create CircularAudioBuffer (30 min)

**Goal**: Build a thread-safe buffer to transfer audio between SDK callback and our playback.

**Files to Create**:
- `ios/VeepaAudioTest/VeepaAudioTest/Audio/CircularAudioBuffer.swift`

**What to Implement**:
- Ring buffer for Int16 samples
- Thread-safe write (from SDK callback thread)
- Thread-safe read (from audio render thread)
- Overflow/underflow handling

**Verification Test**:
```swift
// Unit test in Xcode
func testCircularBuffer() {
    let buffer = CircularAudioBuffer(capacity: 1024)

    // Write 500 samples
    var testData = [Int16](repeating: 0x7FFF, count: 500)
    buffer.write(from: &testData, count: 500)

    // Verify fill level
    XCTAssertEqual(buffer.availableSamples, 500)

    // Read 300 samples
    var output = [Int16](repeating: 0, count: 300)
    let read = buffer.read(into: &output, count: 300)

    XCTAssertEqual(read, 300)
    XCTAssertEqual(buffer.availableSamples, 200)
    XCTAssertEqual(output[0], 0x7FFF)
}
```

**Success Criteria**:
- [ ] Unit test passes
- [ ] No crashes with concurrent access
- [ ] Fill level reporting works

**Can proceed if**: Unit tests pass

---

### Step 2: Create AudioBridgeEngine (1 hour)

**Goal**: Build AVAudioEngine pipeline that can play 16kHz audio.

**Files to Create**:
- `ios/VeepaAudioTest/VeepaAudioTest/Audio/AudioBridgeEngine.swift`

**What to Implement**:
- AVAudioEngine with AVAudioSourceNode
- Input format: 16kHz, mono, Int16
- Output format: 48kHz, stereo, Float32 (handled by engine)
- Pull samples from CircularAudioBuffer
- Start/stop methods

**Verification Test** (Manual - no SDK needed):
```swift
// Add test button to ContentView
Button("Test Audio Engine") {
    Task {
        // Generate 1 second of 440Hz sine wave at 16kHz
        let sampleRate: Float = 16000
        let frequency: Float = 440
        var samples = [Int16]()

        for i in 0..<Int(sampleRate) {
            let sample = sin(2.0 * .pi * frequency * Float(i) / sampleRate)
            samples.append(Int16(sample * 32767))
        }

        // Push to buffer
        AudioBridgeEngine.shared.pushSamples(samples)

        // Start playback
        try? AudioBridgeEngine.shared.start()

        // Should hear 440Hz tone for 1 second
    }
}
```

**Success Criteria**:
- [ ] Engine starts without crash
- [ ] 440Hz test tone plays through speaker
- [ ] Tone sounds correct (not pitched wrong)
- [ ] Engine stops cleanly

**Can proceed if**: Test tone plays correctly at expected pitch

---

### Step 3: Verify SDK AudioUnit Exists (30 min)

**Goal**: Confirm we can access the SDK's AppIOSPlayer and its audioUnit.

**Files to Modify**:
- `ios/VeepaAudioTest/VeepaAudioTest/Strategies/AudioUnitHookStrategy.swift` (create)

**What to Implement**:
- Basic strategy shell (no swizzling yet)
- Runtime check for AppIOSPlayer class
- Log available methods/ivars

**Verification Test** (Manual - needs camera connection):
```swift
// Add to AudioUnitHookStrategy
func diagnoseSDK() {
    // Check if AppIOSPlayer exists
    if let playerClass = NSClassFromString("AppIOSPlayer") {
        print("[Hook] ✅ AppIOSPlayer class found")

        // List methods
        var methodCount: UInt32 = 0
        if let methods = class_copyMethodList(playerClass, &methodCount) {
            print("[Hook] Found \(methodCount) methods:")
            for i in 0..<Int(methodCount) {
                let selector = method_getName(methods[i])
                print("[Hook]   - \(NSStringFromSelector(selector))")
            }
            free(methods)
        }

        // Check for audioUnit ivar
        if let ivar = class_getInstanceVariable(playerClass, "audioUnit") {
            print("[Hook] ✅ audioUnit ivar found at offset \(ivar_getOffset(ivar))")
        } else {
            print("[Hook] ❌ audioUnit ivar NOT found")
        }
    } else {
        print("[Hook] ❌ AppIOSPlayer class NOT found")
    }
}
```

**Test Procedure**:
1. Connect to camera
2. Start audio (SDK will fail, that's ok)
3. Call `diagnoseSDK()`
4. Check logs

**Success Criteria**:
- [ ] AppIOSPlayer class found
- [ ] audioUnit ivar found
- [ ] Methods like `createAudioUnitWithOutput:input:` visible

**Can proceed if**: AppIOSPlayer and audioUnit ivar are accessible

**STOP if**: Class or ivar not found → need alternative approach

---

### Step 4: Implement Method Swizzling (1 hour)

**Goal**: Swizzle SDK's AudioUnit creation to capture the AudioUnit reference.

**Files to Modify**:
- `ios/VeepaAudioTest/VeepaAudioTest/Strategies/AudioUnitHookStrategy.swift`

**What to Implement**:
- Swizzle `createAudioUnitWithOutput:input:`
- In swizzled method: call original, then capture audioUnit ivar
- Store AudioUnit reference for later use

**Verification Test**:
```
1. Connect to camera
2. Start audio with AudioUnitHook strategy
3. Check logs for:
   [Hook] 🎣 Intercepted createAudioUnitWithOutput:true input:false
   [Hook] ✅ Captured AudioUnit: <pointer>
```

**Success Criteria**:
- [ ] Swizzle installs without crash
- [ ] Original method still called (SDK doesn't break)
- [ ] AudioUnit reference captured

**Can proceed if**: AudioUnit captured successfully

**STOP if**: Swizzle crashes or AudioUnit is nil → try alternative hook point

---

### Step 5: Install Render Notify Tap (1 hour)

**Goal**: Tap into SDK's AudioUnit to receive audio samples.

**Files to Modify**:
- `ios/VeepaAudioTest/VeepaAudioTest/Strategies/AudioUnitHookStrategy.swift`

**What to Implement**:
- Call `AudioUnitAddRenderNotify()` on captured AudioUnit
- In callback: extract audio samples from AudioBufferList
- Push samples to CircularAudioBuffer
- Log sample reception

**Verification Test**:
```
1. Connect to camera
2. Start audio with AudioUnitHook strategy
3. Check logs for:
   [Hook] ✅ Render notify tap installed
   [Hook] 📥 Received 160 frames (callback #1)
   [Hook] 📥 Received 160 frames (callback #2)
   ...
```

**Key Question to Answer**:
- Does the render callback fire even though SDK's playback fails?
- What format are the samples in? (Should be 16kHz Int16)

**Success Criteria**:
- [ ] Render notify installs without crash
- [ ] Callback fires repeatedly
- [ ] Samples are non-zero (actual audio data)
- [ ] Sample format is 16kHz Int16

**Can proceed if**: We receive audio samples in callback

**STOP if**: Callback never fires → SDK might not reach render stage due to error -50

---

### Step 6: Connect Pipeline & Test Audio (1 hour)

**Goal**: Wire everything together and hear audio.

**Files to Modify**:
- `ios/VeepaAudioTest/VeepaAudioTest/Strategies/AudioUnitHookStrategy.swift`
- `ios/VeepaAudioTest/VeepaAudioTest/Services/AudioStreamService.swift`

**What to Implement**:
- In render callback: push samples to AudioBridgeEngine
- Start AudioBridgeEngine when audio starts
- Stop AudioBridgeEngine when audio stops
- Add AudioUnitHookStrategy to strategy list

**Verification Test**:
```
1. Connect to camera
2. Select "AudioUnit Hook" strategy
3. Tap "Start Audio"
4. Listen for audio from speaker
```

**Success Criteria**:
- [ ] Audio plays from speaker
- [ ] Audio is intelligible (can hear environment sounds)
- [ ] No major distortion or artifacts
- [ ] Can stop and restart without crash

**CELEBRATE if**: Audio works! 🎉

---

### Step 7: Polish & Edge Cases (30 min)

**Goal**: Handle edge cases and improve stability.

**What to Implement**:
- Handle disconnect gracefully
- Handle start/stop cycles (10x test)
- Buffer underrun handling (silence instead of glitch)
- Logging cleanup (reduce verbosity)

**Verification Tests**:
- [ ] Start/stop 10 times without crash
- [ ] Disconnect and reconnect works
- [ ] No memory leaks (Instruments check)
- [ ] Audio plays for 10+ minutes continuously

---

## Risk Points & Fallbacks

### Risk 1: AppIOSPlayer class not accessible
**Detection**: Step 3 fails
**Fallback**: Use fishhook to intercept `AudioUnitRender` C function

### Risk 2: AudioUnit ivar not found
**Detection**: Step 3 fails
**Fallback**: Swizzle a different method, or find AudioUnit through method return value

### Risk 3: Swizzle crashes app
**Detection**: Step 4 fails
**Fallback**: Try swizzling different method, or use fishhook

### Risk 4: Render callback never fires
**Detection**: Step 5 fails
**Fallback**: The SDK might abort before reaching render stage. Would need to:
- Hook earlier in pipeline (during decode)
- Or intercept P2P audio channel differently

### Risk 5: Samples are wrong format
**Detection**: Step 5 - samples are garbled
**Fallback**: Adjust input format in AudioBridgeEngine

---

## Decision Points

After each step, decide:

| Outcome | Action |
|---------|--------|
| Step passes | Continue to next step |
| Step fails, fallback exists | Try fallback, then continue |
| Step fails, no fallback | Stop, reassess approach |

---

## Files Summary

### New Files to Create
```
ios/VeepaAudioTest/VeepaAudioTest/
├── Audio/
│   ├── CircularAudioBuffer.swift    (Step 1)
│   └── AudioBridgeEngine.swift      (Step 2)
└── Strategies/
    └── AudioUnitHookStrategy.swift  (Steps 3-6)
```

### Files to Modify
```
ios/VeepaAudioTest/VeepaAudioTest/
├── Services/
│   └── AudioStreamService.swift     (Step 6 - add strategy)
└── Views/
    └── ContentView.swift            (Step 2 - test button)
```

---

## Time Estimates

| Step | Task | Time | Cumulative |
|------|------|------|------------|
| 1 | CircularAudioBuffer | 30 min | 30 min |
| 2 | AudioBridgeEngine | 1 hour | 1.5 hours |
| 3 | Verify SDK access | 30 min | 2 hours |
| 4 | Method swizzling | 1 hour | 3 hours |
| 5 | Render notify tap | 1 hour | 4 hours |
| 6 | Connect & test | 1 hour | 5 hours |
| 7 | Polish | 30 min | 5.5 hours |

**Total**: ~5.5 hours (with buffer for debugging)

---

## Definition of Done

- [ ] Audio plays from camera through iPhone speaker
- [ ] Start/stop works reliably (10 cycles)
- [ ] No crashes in normal use
- [ ] Code is documented
- [ ] Debugging log updated with results

---

**Created**: 2026-02-04
**Author**: Claude Code
**Ready to Start**: Yes - begin with Step 1
