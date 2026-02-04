# Story 10.3: Audio Packet Interception

## Parent Story
[STORY_10_BYPASS_SDK_AUDIO.md](./STORY_10_BYPASS_SDK_AUDIO.md)

## Prerequisites
- Story 10.2 completed (we know CGI command that enables audio)
- Camera is sending audio packets on P2P Channel 2

## Objective
Intercept raw G.711a audio packets from the SDK's data path before they reach the broken AudioUnit pipeline.

## Background

After sending the audio CGI command, the camera sends G.711a audio packets on P2P Channel 2. The SDK receives these packets and stores them in `voice_out_buff`, but because `startVoice()` failed, they're never played.

We need to:
1. Read directly from `voice_out_buff`, OR
2. Hook the function that writes to `voice_out_buff`, OR
3. Hook the P2P receive function for channel 2

### P2P Channel Reference
```
Channel 0: P2P_CMD_CHANNEL     - CGI commands
Channel 1: P2P_VIDEO_CHANNEL   - Video receive (working)
Channel 2: P2P_AUDIO_CHANNEL   - Audio receive (TARGET)
Channel 3: P2P_TALKCHANNEL     - Audio send (talk back)
```

---

## Implementation Tasks

### Task 1: Direct voice_out_buff Reading (Preferred)

**Goal:** Read audio data directly from the SDK's voice_out_buff ring buffer.

**Implementation:**
```objc
// Ring buffer structure: {*buff, size, r, w}
typedef struct {
    uint8_t *buff;     // Pointer to data buffer
    uint64_t size;     // Buffer size (e.g., 131072 = 128KB)
    uint64_t r;        // Read position
    uint64_t w;        // Write position
} SDKRingBuffer;

- (void)startVoiceBufferCapture {
    // Get voice_out_buff from captured player instance
    Ivar buffIvar = class_getInstanceVariable(
        object_getClass(capturedPlayerInstance), "voice_out_buff");

    if (!buffIvar) {
        NSLog(@"[CAPTURE] voice_out_buff ivar not found");
        return;
    }

    ptrdiff_t offset = ivar_getOffset(buffIvar);
    void *playerPtr = (__bridge void *)capturedPlayerInstance;
    SDKRingBuffer **buffPtrAddr = (SDKRingBuffer **)(playerPtr + offset);
    SDKRingBuffer *ringBuff = *buffPtrAddr;

    if (!ringBuff || !ringBuff->buff) {
        NSLog(@"[CAPTURE] Ring buffer not initialized");
        return;
    }

    NSLog(@"[CAPTURE] Buffer: %p, size=%llu", ringBuff->buff, ringBuff->size);

    // Start capture timer
    self.captureTimer = [NSTimer scheduledTimerWithTimeInterval:0.020  // 50Hz = 20ms
                                                         target:self
                                                       selector:@selector(captureTimerFired:)
                                                       userInfo:(__bridge id)ringBuff
                                                        repeats:YES];
}

- (void)captureTimerFired:(NSTimer *)timer {
    SDKRingBuffer *ringBuff = (__bridge SDKRingBuffer *)timer.userInfo;

    uint64_t r = ringBuff->r;
    uint64_t w = ringBuff->w;

    if (w <= r) return;  // No new data

    uint64_t available = w - r;
    NSLog(@"[CAPTURE] Available: %llu bytes (r=%llu, w=%llu)", available, r, w);

    // Read data from ring buffer (handle wrap-around)
    uint64_t readPos = r % ringBuff->size;
    uint64_t bytesToEnd = ringBuff->size - readPos;
    uint64_t toRead = MIN(available, 1024);  // Read up to 1KB at a time

    uint8_t tempBuff[1024];

    if (toRead <= bytesToEnd) {
        // No wrap needed
        memcpy(tempBuff, ringBuff->buff + readPos, toRead);
    } else {
        // Wrap around
        memcpy(tempBuff, ringBuff->buff + readPos, bytesToEnd);
        memcpy(tempBuff + bytesToEnd, ringBuff->buff, toRead - bytesToEnd);
    }

    // Update read position
    ringBuff->r = r + toRead;

    // Forward to decoder
    [self processG711aData:tempBuff length:toRead];
}

- (void)processG711aData:(const uint8_t *)g711aData length:(size_t)len {
    // Decode G.711a to PCM16
    int16_t pcmSamples[len];

    for (size_t i = 0; i < len; i++) {
        pcmSamples[i] = alaw_to_linear(g711aData[i]);
    }

    // Forward to callback
    if (self.captureCallback) {
        self.captureCallback(pcmSamples, (uint32_t)len);
    }
}
```

**G.711 A-law Decoder:**
```objc
// Standard A-law to linear conversion
static int16_t alaw_to_linear(uint8_t alaw) {
    alaw ^= 0x55;

    int sign = alaw & 0x80;
    int exponent = (alaw >> 4) & 0x07;
    int mantissa = alaw & 0x0F;

    int sample = mantissa << 4;
    sample += 8;  // Add 0.5 for rounding

    if (exponent > 0) {
        sample += 0x100;
        sample <<= (exponent - 1);
    }

    return sign ? -sample : sample;
}
```

**Test:**
1. Connect to camera
2. Send audio CGI command
3. Call `startVoiceBufferCapture()`
4. Verify samples are decoded

**Success Criteria:**
- [ ] Timer fires regularly
- [ ] Data read from buffer increases over time
- [ ] Decoded samples have reasonable amplitude (not all zeros)

---

### Task 2: Alternative - Hook app_source_voice_read

**Goal:** If direct buffer reading fails, hook the function that reads voice data.

**Investigation:**
```bash
nm -g ios/VeepaAudioTest/VeepaSDK/libVSTC.a | grep voice
# Look for: app_source_voice_read, voice_read, voice_frame_read
```

**Implementation:**
```objc
// Find and swizzle voice read function
typedef int (*voice_read_fn)(void *source, void *buffer, int size);
static voice_read_fn original_voice_read = NULL;

static int hooked_voice_read(void *source, void *buffer, int size) {
    int result = original_voice_read(source, buffer, size);

    if (result > 0) {
        NSLog(@"[VOICE-HOOK] Read %d bytes", result);

        // Forward data to our processor
        [[AudioHookBridge shared] processInterceptedVoiceData:buffer length:result];
    }

    return result;
}

- (BOOL)installVoiceReadHook {
    void *original = dlsym(RTLD_DEFAULT, "app_source_voice_read");
    if (!original) {
        NSLog(@"[VOICE-HOOK] app_source_voice_read not found");
        return NO;
    }

    // Use fishhook or similar to replace function
    // rebind_symbols((struct rebinding[]){
    //     {"app_source_voice_read", hooked_voice_read, (void **)&original_voice_read}
    // }, 1);

    return YES;
}
```

**Note:** This approach requires function hooking library like fishhook.

---

### Task 3: Alternative - Hook P2P Channel 2 Receive

**Goal:** Intercept raw P2P packets on channel 2.

**Investigation:**
```bash
nm -g ios/VeepaAudioTest/VeepaSDK/libVSTC.a | grep -E "p2p.*recv|channel.*read"
```

**Implementation:**
```objc
// Hook P2P receive to intercept audio channel
typedef int (*p2p_recv_fn)(void *handle, int channel, void *buffer, int size);
static p2p_recv_fn original_p2p_recv = NULL;

static int hooked_p2p_recv(void *handle, int channel, void *buffer, int size) {
    int result = original_p2p_recv(handle, channel, buffer, size);

    if (channel == 2 && result > 0) {  // Audio channel
        NSLog(@"[P2P-HOOK] Channel 2: %d bytes", result);
        [[AudioHookBridge shared] processRawAudioPacket:buffer length:result];
    }

    return result;
}
```

---

### Task 4: Validate Captured Audio

**Goal:** Verify captured data is valid G.711a audio.

**Tests:**
```objc
- (void)validateCapturedAudio:(const int16_t *)samples count:(uint32_t)count {
    // Test 1: Check for non-zero samples
    int nonZero = 0;
    int16_t maxSample = 0;
    int16_t minSample = 0;

    for (uint32_t i = 0; i < count; i++) {
        if (samples[i] != 0) nonZero++;
        if (samples[i] > maxSample) maxSample = samples[i];
        if (samples[i] < minSample) minSample = samples[i];
    }

    NSLog(@"[VALIDATE] Count: %u, NonZero: %d (%.1f%%)",
          count, nonZero, 100.0 * nonZero / count);
    NSLog(@"[VALIDATE] Range: [%d, %d]", minSample, maxSample);

    // Test 2: Check amplitude is reasonable
    // Typical speech is -10000 to +10000 range
    if (maxSample > 100 || minSample < -100) {
        NSLog(@"[VALIDATE] Amplitude looks like audio!");
    } else {
        NSLog(@"[VALIDATE] WARNING: Very low amplitude, may be silence");
    }

    // Test 3: Check for variation (not constant value)
    int16_t first = samples[0];
    BOOL allSame = YES;
    for (uint32_t i = 1; i < MIN(count, 100); i++) {
        if (samples[i] != first) {
            allSame = NO;
            break;
        }
    }

    if (allSame) {
        NSLog(@"[VALIDATE] WARNING: All samples are identical (%d)", first);
    }
}
```

---

### Task 5: Connect to Swift Callback

**Goal:** Forward captured audio to Swift/AudioBridgeEngine.

**Implementation:**
```objc
// AudioHookBridge.m
- (void)setCaptureCallback:(AudioCaptureBlock)callback {
    _captureCallback = [callback copy];
}

// Called from capture methods
- (void)forwardToSwift:(const int16_t *)samples count:(uint32_t)count {
    if (self.captureCallback) {
        self.captureCallback(samples, count);
    }
}
```

**Swift side:**
```swift
// In AudioBridgeEngine or ContentView
AudioHookBridge.shared.captureCallback = { [weak self] samples, count in
    guard let samples = samples else { return }

    // Write to circular buffer
    let buffer = UnsafeBufferPointer(start: samples, count: Int(count))
    self?.circularBuffer.write(Array(buffer))

    print("[CAPTURE] Received \(count) samples")
}
```

**Success Criteria:**
- [ ] Swift callback receives samples
- [ ] Samples appear in circular buffer
- [ ] Sample rate matches expected 8000 Hz or 16000 Hz

---

## UI Changes

Add capture controls to ContentView:
```swift
Button("Start Audio Capture") {
    AudioHookBridge.shared.startVoiceBufferCapture()
}

Button("Stop Audio Capture") {
    AudioHookBridge.shared.stopVoiceBufferCapture()
}

Text("Captured: \(capturedSampleCount) samples")
```

---

## Verification Tests

### Test 1: Buffer Reading
```
Expected:
[CAPTURE] Buffer: 0xXXXXXXXX, size=131072
[CAPTURE] Available: 320 bytes (r=0, w=320)
[CAPTURE] Available: 640 bytes (r=320, w=960)
```

### Test 2: G.711a Decoding
```
Expected:
[VALIDATE] Count: 320, NonZero: 287 (89.7%)
[VALIDATE] Range: [-4523, 5120]
[VALIDATE] Amplitude looks like audio!
```

### Test 3: Swift Callback
```
Expected:
[CAPTURE] Received 320 samples
[BUFFER] Write 320 samples, total: 320
```

---

## Acceptance Criteria

- [ ] Can read audio data from voice_out_buff ring buffer
- [ ] G.711a decoder produces valid PCM16 samples
- [ ] Samples are non-zero when audio is present
- [ ] Swift callback receives decoded samples
- [ ] Data flow is continuous (no gaps > 100ms)

## Exit Criteria

**SUCCESS:** Decoded PCM samples available in Swift → Proceed to Story 10.4

**FAILURE:**
- Buffer always empty → Check Story 10.2 CGI command
- Decoded samples always zero → Check decoder implementation
- Callback never called → Check timer/hook setup

---

## Estimated Duration
3-4 hours

## Risk Assessment
| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Buffer structure wrong | Low | Already analyzed via ivar inspection |
| Ring buffer wrap issues | Medium | Test with large data volumes |
| Timing issues | Low | Use high-frequency timer |

---

## Files to Modify

| File | Changes |
|------|---------|
| `AudioHookBridge.m` | Add buffer capture and G.711a decoder |
| `AudioHookBridge.h` | Export capture methods |
| `ContentView.swift` | Add capture control buttons |
| `AudioBridgeEngine.swift` | Add callback handler |

---

## Next Story
[Story 10.4: Pipeline Integration](./STORY_10_4_PIPELINE_INTEGRATION.md)
