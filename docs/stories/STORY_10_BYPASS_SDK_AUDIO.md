# Story 10: Bypass SDK Audio - Direct Camera Audio Control

## Epic Overview

This is an **epic** (parent story) that contains multiple sub-stories for incremental implementation and testing.

### Sub-Stories

| Story | Description | Duration | Status |
|-------|-------------|----------|--------|
| [10.1](./STORY_10_1_PCMP2_LISTENER.md) | Investigate pcmp2_setListener API | 1-2 hours | Not Started |
| [10.2](./STORY_10_2_CGI_COMMAND.md) | Audio CGI Command Discovery | 2-3 hours | Not Started |
| [10.3](./STORY_10_3_PACKET_INTERCEPT.md) | Audio Packet Interception | 3-4 hours | Not Started |
| [10.4](./STORY_10_4_PIPELINE_INTEGRATION.md) | Pipeline Integration | 2-3 hours | Not Started |

**Recommended Order:** 10.1 → (if fails) 10.2 → 10.3 → 10.4

---

## Executive Summary

After extensive investigation (9 attempts documented in `AUDIO_HOOK_TROUBLESHOOTING.md`), we've confirmed that the SDK's audio pipeline cannot be hooked successfully because **the SDK never requests audio from the camera when `startVoice()` fails**. The SDK has "all-or-nothing" behavior.

**The solution:** Bypass the SDK's audio handling entirely and control camera audio directly.

---

## Problem Statement

### Root Cause (Confirmed)
1. SDK calls `startVoice()`
2. SDK tries to configure AudioUnit at 16kHz
3. iOS rejects with error -50 (requires minimum 48kHz)
4. SDK's `startVoice()` returns FALSE
5. **SDK never sends audio enable command to camera**
6. Camera never sends audio packets
7. All buffers remain empty

### Evidence
- `voice_in_buff`: Never allocated (NULL pointer)
- `voice_out_buff`: Allocated but r=0, w=0 (never written)
- `voice_frame`: Empty (data=NULL, size=0)
- AudioUnit render callback: Outputs silence (all zeros)

---

## Solution Architecture

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    CURRENT (BROKEN) FLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  App → startVoice() → AudioUnit config fails → ABORT           │
│                                                                 │
│  Camera never receives audio command → No audio sent            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    NEW (BYPASS) FLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. App sends audio CGI command directly to camera              │
│     └─→ camera starts sending audio on P2P Channel 2            │
│                                                                 │
│  2. App intercepts raw G.711a packets                           │
│     └─→ Hook SDK's packet receive OR use pcmp2_setListener      │
│                                                                 │
│  3. App decodes G.711a → PCM16 (16kHz mono)                     │
│     └─→ Use existing alaw_to_linear decoder                     │
│                                                                 │
│  4. App plays through AVAudioEngine                             │
│     └─→ Existing AudioBridgeEngine handles 16kHz→48kHz          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Options

### Option A: pcmp2_setListener Approach (RECOMMENDED)

**Discovery:** The SDK has a listener callback mechanism:

```
_pcmp2_init           - Initialize PCM player
_pcmp2_setListener    - Set listener callback for audio data
_pcmp2_setAudioPlayer - Set audio player instance
_pcmp2_start          - Start PCM playback
_pcmp2_stop           - Stop PCM playback
_pcmp2_finalize       - Cleanup
```

**Hypothesis:** If we can:
1. Call `pcmp2_init()` to initialize
2. Call `pcmp2_setListener()` with our callback
3. Call `pcmp2_start()` to begin receiving

The SDK might deliver decoded PCM audio to our callback, bypassing the broken AudioUnit.

**Implementation Steps:**
1. Resolve `pcmp2_*` symbols via dlsym
2. Define the listener callback signature (reverse engineer from SDK)
3. Register our listener before `startVoice()` is called
4. Receive PCM audio in our callback
5. Feed to AVAudioEngine

**Pros:**
- Uses SDK's existing infrastructure
- SDK handles G.711a decoding for us
- Minimal code changes

**Cons:**
- Need to reverse engineer listener interface
- May not work if SDK doesn't call listener when AudioUnit fails

---

### Option B: CGI Command + Packet Hook

**Approach:** Send CGI command ourselves, hook packet receive.

**Implementation Steps:**

#### Phase 1: Send Audio Enable CGI
```swift
// Send CGI command to camera via existing clientWriteCgi
let cgi = "audiostream.cgi?streamid=0&"  // Need to find exact format
await AppP2PApi.shared.clientWriteCgi(clientPtr, cgi)
```

Common Vstarcam audio CGI commands:
- `audiostream.cgi?streamid=X&`
- `get_audio_status.cgi`
- `set_audio.cgi?enable=1`
- `decoder_control.cgi?command=90&` (audio on)
- `decoder_control.cgi?command=91&` (audio off)

#### Phase 2: Hook SDK Packet Receive
```objc
// Swizzle SDK's internal packet dispatcher
// Find method that receives P2P channel 2 data
// Intercept audio packets before SDK drops them
```

**Pros:**
- Full control over audio pipeline
- Works regardless of SDK behavior

**Cons:**
- Need to find exact CGI command format
- Need to find and hook packet receive point
- More complex implementation

---

### Option C: Force startVoice() Success (Swizzle Deeper)

**Approach:** Swizzle SDK internals to make audio pipeline work despite AudioUnit failure.

**Implementation Steps:**

1. **Hook AudioUnit creation** to return a working unit at 48kHz
2. **Hook SDK's sample rate** check to accept whatever iOS provides
3. **Hook the audio command sender** to always execute (before AudioUnit check)

**What we know:**
- `-[AppIOSPlayer startVoice]` at address 0x9254
- `-[AppIOSPlayer createAudioUnitWithOutput:input:]` already swizzled
- SDK checks AudioUnit success before continuing

**Pros:**
- SDK handles everything normally
- Minimal custom code

**Cons:**
- Requires understanding SDK's internal flow
- AudioUnit might be checked at multiple points
- Fragile if SDK updates

---

## Recommended Implementation Plan

### Phase 1: Investigate pcmp2_setListener (1-2 hours)

**Goal:** Determine if pcmp2 listener approach is viable.

**Tasks:**
1. Create test to call `pcmp2_init()` via dlsym
2. Experiment with `pcmp2_setListener()` signature
3. Try registering a callback and calling `pcmp2_start()`
4. See if callback receives any audio data

**Success Criteria:**
- pcmp2 functions callable
- Listener callback invoked with audio data

**If this fails, proceed to Phase 2.**

---

### Phase 2: Find and Send Audio CGI Command (2-3 hours)

**Goal:** Discover what CGI command enables camera audio.

**Tasks:**
1. Research Vstarcam CGI documentation
2. Try common audio CGI commands:
   - `audiostream.cgi?streamid=0&`
   - `decoder_control.cgi?command=90&`
   - `get_audio_config.cgi`
3. Monitor P2P channel 2 after sending command
4. Verify camera starts sending audio packets

**Success Criteria:**
- Find CGI command that makes camera send audio
- Verify packets arrive on channel 2

---

### Phase 3: Intercept Audio Packets (3-4 hours)

**Goal:** Receive raw G.711a audio packets.

**Approach Options:**

**Option 3A: Hook app_source_voice_read**
```objc
// The SDK has this function to read voice from source
// Swizzle it to intercept data
static void swizzled_app_source_voice_read(void *source, ...) {
    // Call original
    original_app_source_voice_read(source, ...);
    // Copy audio data for ourselves
}
```

**Option 3B: Hook packet dispatcher**
```objc
// Find where SDK dispatches P2P packets by channel
// Intercept channel 2 packets
```

**Option 3C: Use EventChannel pattern**
```dart
// If SDK has audio EventChannel like video
EventChannel _audioChannel = EventChannel("app_p2p_api_event_channel/audio");
_audioChannel.receiveBroadcastStream().listen((data) {
    // Process audio packets
});
```

**Success Criteria:**
- Receive raw G.711a bytes in our code
- Verify data is non-zero audio content

---

### Phase 4: Build Complete Pipeline (2-3 hours)

**Goal:** End-to-end audio playback.

**Components:**
1. **G.711a Decoder** - Already implemented in AudioHookBridge.m
2. **CircularAudioBuffer** - Already implemented
3. **AVAudioEngine** - Already working in AudioBridgeEngine.swift

**Integration:**
```swift
// In packet receive hook:
func onAudioPacketReceived(_ g711aData: Data) {
    // Decode G.711a to PCM16
    let pcm16 = G711aDecoder.decode(g711aData)

    // Write to buffer
    circularBuffer.write(pcm16)

    // AVAudioEngine reads from buffer automatically
}
```

**Success Criteria:**
- Audio plays through speaker
- No dropouts or glitches

---

## Technical Details

### SDK Symbols Available

```c
// PCM Player Functions
_pcmp2_init()                    // Initialize PCM player
_pcmp2_finalize()                // Cleanup
_pcmp2_setListener(listener)     // Set callback for audio data
_pcmp2_setAudioPlayer(player)    // Set audio player instance
_pcmp2_start()                   // Start playback
_pcmp2_stop()                    // Stop playback

// App Player Functions
_app_player_render_voice()       // Renders voice to AudioUnit
_app_player_set_voice_channel()  // Set voice channel

// Source Functions
_app_source_voice_read()         // Reads voice from P2P source (assumed)

// P2P Functions
_client_write_cgi()              // Send CGI command
_client_write()                  // Write to P2P channel
```

### Key Files to Modify

| File | Changes |
|------|---------|
| `AudioHookBridge.m` | Add pcmp2 listener registration or packet hook |
| `AudioHookBridge.h` | Export new methods |
| `ContentView.swift` | Add "Send Audio CGI" test button |
| `VSTCBridge.swift` | Add pcmp2 symbol resolution |
| `AudioBridgeEngine.swift` | (minimal changes - already working) |

### P2P Channel Reference

```
Channel 0: P2P_CMD_CHANNEL     - CGI commands
Channel 1: P2P_VIDEO_CHANNEL   - Video receive (working)
Channel 2: P2P_AUDIO_CHANNEL   - Audio receive (TARGET)
Channel 3: P2P_TALKCHANNEL     - Audio send (talk back)
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| pcmp2 listener doesn't work | Medium | Low | Fall back to CGI+hook approach |
| CGI command format unknown | Medium | Medium | Research Vstarcam docs, try common formats |
| Packet hook crashes | Low | Medium | Careful memory management, test on device |
| Audio quality poor | Low | Low | Already have working decode + playback |

---

## Success Metrics

1. **Camera sends audio packets** - Verified via logs showing channel 2 data
2. **App receives audio data** - Non-zero bytes in our callback
3. **Audio decodes correctly** - PCM samples have reasonable amplitude
4. **Audio plays through speaker** - User can hear camera audio

---

## Estimated Timeline

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 1: pcmp2 investigation | 1-2 hours | 1-2 hours |
| Phase 2: CGI command discovery | 2-3 hours | 3-5 hours |
| Phase 3: Packet interception | 3-4 hours | 6-9 hours |
| Phase 4: Pipeline integration | 2-3 hours | 8-12 hours |

**Total: 8-12 hours** (pessimistic estimate, could be faster if pcmp2 works)

---

## Acceptance Criteria

- [ ] Camera audio plays through iOS device speaker
- [ ] No dependency on SDK's broken AudioUnit pipeline
- [ ] Works with existing camera (OKB0379196OXYB)
- [ ] Audio quality is acceptable (no major distortion)
- [ ] Solution is documented and maintainable

---

## Related Files

- `ios/VeepaAudioTest/AUDIO_HOOK_TROUBLESHOOTING.md` - Complete investigation history
- `ios/VeepaAudioTest/VeepaAudioTest/Audio/AudioHookBridge.m` - Current hook implementation
- `ios/VeepaAudioTest/VeepaAudioTest/Audio/AudioBridgeEngine.swift` - AVAudioEngine pipeline
- `flutter_module/veepa_audio/lib/sdk/app_p2p_api.dart` - P2P API (has clientWriteCgi)

---

## Next Action

**Start with [Story 10.1](./STORY_10_1_PCMP2_LISTENER.md):** Create a test to call `pcmp2_setListener()` and see if we can receive audio callbacks. This is the least invasive approach and might work with minimal changes.

Each sub-story has:
- Clear acceptance criteria
- Specific tests to verify success
- Exit criteria (what to do if it fails)
- Estimated duration

Implement stories one at a time, verifying each before proceeding.
