# Story 10.2: Audio CGI Command Discovery

## Parent Story
[STORY_10_BYPASS_SDK_AUDIO.md](./STORY_10_BYPASS_SDK_AUDIO.md)

## Prerequisites
- Story 10.1 attempted (pcmp2_setListener did not work OR we want direct control)

## Objective
Discover and send the CGI command that enables audio streaming from the camera, causing it to send audio packets on P2P Channel 2.

## Background

The root cause of the audio problem is that the SDK never sends the audio enable command to the camera when `startVoice()` fails. We need to:
1. Find the correct CGI command format
2. Send it directly via `client_write_cgi()`
3. Verify the camera starts sending audio packets

### Known Vstarcam CGI Commands (from documentation/research)
```
audiostream.cgi?streamid=X&      - Enable audio stream X
decoder_control.cgi?command=90&  - Audio on (some models)
decoder_control.cgi?command=91&  - Audio off (some models)
get_audio_status.cgi             - Query audio status
set_audio.cgi?enable=1           - Enable audio
audio.cgi?action=on              - Alternative format
```

---

## Implementation Tasks

### Task 1: Research Camera CGI Protocol

**Goal:** Find documentation or examples of Vstarcam audio CGI commands.

**Actions:**
1. Search for Vstarcam CGI documentation online
2. Check SDK source code for CGI command strings
3. Analyze network traffic from official app (if possible)
4. Examine libVSTC.a for embedded CGI strings

**Investigation via strings:**
```bash
strings ios/VeepaAudioTest/VeepaSDK/libVSTC.a | grep -i audio
strings ios/VeepaAudioTest/VeepaSDK/libVSTC.a | grep -i stream
strings ios/VeepaAudioTest/VeepaSDK/libVSTC.a | grep -i decoder
strings ios/VeepaAudioTest/VeepaSDK/libVSTC.a | grep "\.cgi"
```

**Success Criteria:**
- [ ] Documented list of potential CGI commands to try

---

### Task 2: Implement CGI Command Sender

**Goal:** Create a method to send arbitrary CGI commands via the SDK.

**Implementation:**
```objc
// In AudioHookBridge.m or new file

#include <dlfcn.h>

// client_write_cgi signature (from SDK analysis)
// Returns: number of bytes written, or negative on error
typedef int (*client_write_cgi_fn)(void *client, const char *cgi);

static client_write_cgi_fn client_write_cgi = NULL;

- (BOOL)resolveClientCgiSymbol {
    client_write_cgi = dlsym(RTLD_DEFAULT, "client_write_cgi");
    NSLog(@"[CGI] client_write_cgi: %p", client_write_cgi);
    return client_write_cgi != NULL;
}

- (int)sendCgiCommand:(NSString *)cgiCommand toClient:(void *)clientPtr {
    if (!client_write_cgi) {
        [self resolveClientCgiSymbol];
    }

    if (!client_write_cgi) {
        NSLog(@"[CGI] client_write_cgi not found");
        return -1;
    }

    const char *cgiStr = [cgiCommand UTF8String];
    NSLog(@"[CGI] Sending: %s", cgiStr);

    int result = client_write_cgi(clientPtr, cgiStr);
    NSLog(@"[CGI] Result: %d", result);

    return result;
}
```

**Test:** Call with a simple CGI command like `get_status.cgi`.

**Success Criteria:**
- [ ] `client_write_cgi` symbol resolved
- [ ] Can send CGI commands without crash
- [ ] Get response (positive return value)

---

### Task 3: Try Audio CGI Commands

**Goal:** Find the command that enables camera audio.

**Test Matrix:**

| Command | Expected Result |
|---------|-----------------|
| `audiostream.cgi?streamid=0&` | Enable audio stream 0 |
| `decoder_control.cgi?command=90&` | Audio on (protocol A) |
| `set_audio.cgi?enable=1` | Enable audio |
| `audio.cgi?action=start` | Start audio |
| `get_audio_status.cgi` | Query (baseline test) |

**Implementation:**
```objc
- (void)testAudioCgiCommands:(void *)clientPtr {
    NSArray *commands = @[
        @"get_audio_status.cgi",
        @"audiostream.cgi?streamid=0&",
        @"decoder_control.cgi?command=90&",
        @"set_audio.cgi?enable=1",
        @"audio.cgi?action=start",
        @"decoder_control.cgi?command=25&onestep=1&"  // PTZ protocol, may trigger audio
    ];

    for (NSString *cmd in commands) {
        NSLog(@"[CGI-TEST] ==========================================");
        NSLog(@"[CGI-TEST] Trying: %@", cmd);
        int result = [self sendCgiCommand:cmd toClient:clientPtr];
        NSLog(@"[CGI-TEST] Result: %d", result);

        // Wait a moment between commands
        [NSThread sleepForTimeInterval:0.5];
    }
}
```

**Verification:**
After each command, monitor P2P channel 2 for incoming data (see Task 4).

**Success Criteria:**
- [ ] Find CGI command that returns positive result
- [ ] Camera starts sending audio packets after command

---

### Task 4: Monitor P2P Channel 2 for Audio Packets

**Goal:** Detect when camera sends audio packets on channel 2.

**Approach A: Hook SDK's P2P Receive**

Find where SDK receives P2P data and log channel 2 activity:
```objc
// Look for functions like:
// - app_p2p_recv, p2p_read, channel_read
// - Any function that takes a channel parameter
```

**Approach B: Use Existing SDK Infrastructure**

Check if SDK logs channel activity that we can observe:
```objc
// Enable verbose logging (if SDK supports it)
// Check for data arriving in voice_out_buff after CGI command
```

**Implementation for monitoring voice_out_buff:**
```objc
- (void)monitorVoiceBufferForChanges:(int)durationSeconds client:(void *)clientPtr {
    // Get initial state
    Ivar buffIvar = class_getInstanceVariable(object_getClass(capturedPlayerInstance), "voice_out_buff");
    ptrdiff_t buffOffset = ivar_getOffset(buffIvar);
    void *playerPtr = (__bridge void *)capturedPlayerInstance;

    // Read buffer pointer
    void **buffPtrAddr = (void **)(playerPtr + buffOffset);
    void *buffPtr = *buffPtrAddr;

    if (!buffPtr) {
        NSLog(@"[MONITOR] voice_out_buff is NULL");
        return;
    }

    // Buffer structure: {*buff, size, r, w}
    uint64_t lastR = 0, lastW = 0;
    uint64_t *rPtr = (uint64_t *)(buffPtr + sizeof(void *) + sizeof(uint64_t));
    uint64_t *wPtr = (uint64_t *)(buffPtr + sizeof(void *) + 2 * sizeof(uint64_t));

    lastR = *rPtr;
    lastW = *wPtr;
    NSLog(@"[MONITOR] Initial: r=%llu, w=%llu", lastR, lastW);

    for (int i = 0; i < durationSeconds * 10; i++) {
        [NSThread sleepForTimeInterval:0.1];

        uint64_t currentR = *rPtr;
        uint64_t currentW = *wPtr;

        if (currentW != lastW) {
            NSLog(@"[MONITOR] CHANGE! r=%llu→%llu, w=%llu→%llu (+%llu bytes)",
                  lastR, currentR, lastW, currentW, currentW - lastW);
            lastR = currentR;
            lastW = currentW;
        }
    }

    NSLog(@"[MONITOR] Finished monitoring");
}
```

**Success Criteria:**
- [ ] Can detect when audio data arrives in buffer
- [ ] Identify which CGI command triggers audio

---

### Task 5: Verify Audio Packet Format

**Goal:** Confirm received data is G.711a audio.

**Verification:**
```objc
- (void)analyzeAudioPacket:(const uint8_t *)data length:(size_t)len {
    NSLog(@"[AUDIO-PKT] Length: %zu bytes", len);

    // G.711a characteristics:
    // - 8-bit samples (one byte per sample)
    // - 8000 Hz sample rate typically
    // - Values should be distributed around 0x55 (silence in A-law)

    // Check byte distribution
    int histogram[256] = {0};
    for (size_t i = 0; i < len; i++) {
        histogram[data[i]]++;
    }

    // Find most common values
    int max1 = 0, max2 = 0;
    uint8_t val1 = 0, val2 = 0;
    for (int i = 0; i < 256; i++) {
        if (histogram[i] > max1) {
            max2 = max1; val2 = val1;
            max1 = histogram[i]; val1 = i;
        } else if (histogram[i] > max2) {
            max2 = histogram[i]; val2 = i;
        }
    }

    NSLog(@"[AUDIO-PKT] Most common: 0x%02X (%d times), 0x%02X (%d times)",
          val1, max1, val2, max2);

    // 0x55 or 0xD5 are silence in A-law
    if (val1 == 0x55 || val1 == 0xD5) {
        NSLog(@"[AUDIO-PKT] Appears to be silence (G.711a)");
    } else {
        NSLog(@"[AUDIO-PKT] Contains audio data");
    }
}
```

**Success Criteria:**
- [ ] Data has expected G.711a characteristics
- [ ] Can distinguish silence from actual audio

---

## UI Changes

Add CGI test buttons to ContentView:
```swift
Button("Test Audio CGI") {
    // Send audio enable CGI commands and monitor buffer
    AudioHookBridge.shared.testAudioCgiCommands(clientPtr)
}

Button("Monitor Buffer") {
    // Watch voice_out_buff for changes
    AudioHookBridge.shared.monitorVoiceBufferForChanges(10, client: clientPtr)
}
```

---

## Verification Tests

### Test 1: CGI Symbol Resolution
```
Expected:
[CGI] client_write_cgi: 0x1XXXXXXXX (non-null)
```

### Test 2: CGI Command Execution
```
Expected:
[CGI] Sending: get_audio_status.cgi
[CGI] Result: XX (positive = success)
```

### Test 3: Buffer Change Detection
```
Expected (after successful audio CGI):
[MONITOR] Initial: r=0, w=0
[MONITOR] CHANGE! r=0→0, w=0→320 (+320 bytes)
[MONITOR] CHANGE! r=0→0, w=320→640 (+320 bytes)
...
```

---

## Acceptance Criteria

- [ ] `client_write_cgi` symbol resolved and callable
- [ ] Found CGI command that enables camera audio
- [ ] Verified audio data arrives in buffer after CGI command
- [ ] Documented the correct CGI command format

## Exit Criteria

**SUCCESS:** Camera sends audio packets after CGI command → Proceed to Story 10.3

**FAILURE:** No CGI command triggers audio packets → Research alternative approaches:
- Analyze official Vstarcam app network traffic
- Contact camera manufacturer
- Try different P2P protocol commands

---

## Estimated Duration
2-3 hours

## Risk Assessment
| Risk | Likelihood | Mitigation |
|------|------------|------------|
| CGI format unknown | Medium | Try multiple formats, research docs |
| Camera ignores command | Low | Camera responds to video, should respond to audio |
| Buffer monitoring misses data | Low | Poll frequently, log all changes |

---

## Files to Modify

| File | Changes |
|------|---------|
| `AudioHookBridge.m` | Add CGI send and buffer monitor methods |
| `AudioHookBridge.h` | Export new methods |
| `ContentView.swift` | Add CGI test buttons |

---

## Next Story
If successful: [Story 10.3: Audio Packet Interception](./STORY_10_3_PACKET_INTERCEPT.md)
