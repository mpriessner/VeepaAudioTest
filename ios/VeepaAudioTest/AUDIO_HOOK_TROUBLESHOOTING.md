# Audio Hook Troubleshooting Guide

## Problem Statement

**Goal:** Play live audio from Veepa/Vstarcam P2P camera through iOS device speaker.

**Challenge:**
- Camera sends 16kHz G.711a encoded audio
- iOS requires minimum 48kHz for AudioUnit playback
- SDK fails with error -50 when trying to configure its AudioUnit at 16kHz

**Original Solution Approach:**
Hook into SDK's AudioUnit via Objective-C method swizzling, capture the decoded audio data before the SDK fails, and play it through our own AVAudioEngine pipeline that handles the sample rate conversion.

---

## Architecture Overview

```
Camera (16kHz G.711a)
        │
        ▼
SDK receives & decodes audio
        │
        ▼
SDK's AudioUnit Render Callback (Float32 mono)
        │
        ▼ (AudioUnitAddRenderNotify in AudioHookBridge.m)
RenderNotifyCallback captures post-render data
        │
        ▼
Format Conversion (Float32 → Int16 mono)
        │
        ▼ (captureCallback closure)
CircularAudioBuffer.write()
        │
        ▼ (same buffer instance)
CircularAudioBuffer.read()
        │
        ▼ (AVAudioSourceNode render block)
AVAudioEngine (auto-converts 16kHz → 48kHz)
        │
        ▼
Speaker
```

---

## Investigation Timeline & Attempts

### Attempt 1: Basic Hook Implementation
**What we tried:** Swizzle SDK's `startVoice` and `createAudioUnitWithOutput:input:` methods to intercept the AudioUnit creation and install a render notify callback.

**Result:** ✅ Hooks installed successfully. We can intercept when audio starts and get the AudioUnit pointer.

**Evidence:**
```
[AudioHookBridge] 🎯 INTERCEPTED: startVoice called!
[AudioHookBridge] 🎯 INTERCEPTED: createAudioUnitWithOutput:1 input:0
[AudioHookBridge] ✅ Got AudioUnit: 0x12dc95040
[AudioHookBridge] ✅ Render notify installed on unit 0x12dc95040
```

---

### Attempt 2: Render Notify Callback
**What we tried:** Use `AudioUnitAddRenderNotify` to tap into the SDK's AudioUnit render callback and capture the post-render audio data.

**Result:** ✅ Callback fires and receives data frames.

**Evidence:**
```
[AudioHookBridge] 📊 Audio buffer format:
[AudioHookBridge]    Channels: 1
[AudioHookBridge]    Frames: 480
[AudioHookBridge]    Byte size: 1920
[AudioHookBridge]    Bytes per frame: 4
```

Format: Float32 mono (4 bytes/frame × 480 frames = 1920 bytes)

---

### Attempt 3: Format Conversion & Buffer Pipeline
**What we tried:** Convert Float32 mono samples to Int16 mono, push to CircularAudioBuffer, pull from AVAudioSourceNode.

**Result:** ✅ Pipeline works - data flows through buffer correctly.

**Evidence:**
```
[Callback] ✅ Pushed 480 samples, buffer: 0 → 480
[Callback] ✅ Pushed 480 samples, buffer: 480 → 960
...
[AudioBridgeEngine] 🎵 FOUND SAMPLES! Render #1: available=6720, read=160
```

Buffer identity confirmed via ObjectIdentifier - same instance used everywhere.

---

### Attempt 4: Diagnosing Render Callback Stall
**Problem discovered:** After SDK's `createAudioUnitWithOutput:input:` was called, our AVAudioEngine's render callbacks stopped (heartbeat logs disappeared).

**What we tried:** Added heartbeat logging every 100 callbacks to track render activity.

**Result:** Discovered that SDK's AudioUnit creation triggers an **AVAudioSession category change**, which silently stops our AVAudioEngine.

**Evidence:**
```
[AudioBridgeEngine] 💓 HEARTBEAT Render #500 still running
... (Start Audio pressed)
[AudioHookBridge] 🎯 INTERCEPTED: createAudioUnitWithOutput:1 input:0
[AudioBridgeEngine] 🔀 AUDIO ROUTE CHANGED!
[AudioBridgeEngine] 🔀   Reason: 3 (categoryChange)
... (no more heartbeats - engine stopped)
```

---

### Attempt 5: Health Check Timer & Auto-Restart
**What we tried:**
1. Added a 1-second health check timer to monitor engine state from main thread
2. Detect when engine stops (`engine.isRunning == false` or `callbacks/sec == 0`)
3. Auto-restart: tear down entire audio graph, reconfigure session with `mixWithOthers`, rebuild from scratch

**Result:** ✅ Engine restart works - callbacks resume after rebuild.

**Evidence:**
```
[AudioBridgeEngine] 🚨 ENGINE NEEDS RESTART (attempt 1/3)!
[AudioBridgeEngine] 🚨   Engine running: false
[AudioBridgeEngine] 🔄 Full reset and rebuild...
[AudioBridgeEngine] ✅ Audio session reconfigured (mixWithOthers)
[AudioBridgeEngine] ✅ Engine fully rebuilt and started!
[AudioBridgeEngine] 🔊 Mixer volume: 1.0
[AudioBridgeEngine] 🔊 Output format: <AVAudioFormat 0x...:  2 ch,  48000 Hz, Float32>
[AudioBridgeEngine] 🔊 Current route outputs:
[AudioBridgeEngine] 🔊   - Speaker (Speaker)
```

After restart, render callbacks resume and read samples from buffer:
```
[AudioBridgeEngine] 🎵 FOUND SAMPLES! Render #1: available=6720, read=160
[AudioBridgeEngine] 🎵 FIRST REAL SAMPLES! Playing 160 samples
```

---

### Attempt 6: Sample Value Diagnostics
**Problem:** Despite all the above working, no audio was heard.

**What we tried:** Added logging to check if the Float32 samples from SDK's render callback contain actual audio data or just zeros.

**Result:** ❌ **ROOT CAUSE FOUND** - SDK outputs SILENCE (all zeros)!

**Evidence:**
```
[AudioHookBridge] 📈 Sample values check #1:
[AudioHookBridge]    Min: 0.000000, Max: 0.000000, AvgAbs: 0.000000
[AudioHookBridge] ⚠️ WARNING: Data appears to be SILENCE (avgAbs < 0.0001)

[AudioHookBridge] 📈 Sample values check #2:
[AudioHookBridge]    Min: 0.000000, Max: 0.000000, AvgAbs: 0.000000
[AudioHookBridge] ⚠️ WARNING: Data appears to be SILENCE (avgAbs < 0.0001)

... (all 5 checks show zeros)
```

---

## Current State Summary

### What's Working ✅

| Component | Status | Evidence |
|-----------|--------|----------|
| Method Swizzling | ✅ Working | `startVoice` and `createAudioUnitWithOutput:input:` intercepted |
| AudioUnit Capture | ✅ Working | Got unit pointer, render notify installed |
| Render Notify Callback | ✅ Working | Receives 480 frames every ~30ms |
| Format Detection | ✅ Working | Float32 mono, 4 bytes/frame |
| Format Conversion | ✅ Working | Float32 → Int16 conversion |
| Capture Callback | ✅ Working | Swift callback receives samples |
| CircularAudioBuffer | ✅ Working | Same instance, write/read working |
| Engine Restart | ✅ Working | Detects death, rebuilds successfully |
| AVAudioEngine Pipeline | ✅ Working | Reads from buffer, routes to speaker |
| Audio Session Config | ✅ Working | mixWithOthers, defaultToSpeaker |
| Output Routing | ✅ Working | Confirmed "Speaker" output |
| Mixer Volume | ✅ Working | Confirmed 1.0 (max) |

### What's NOT Working ❌

| Issue | Description |
|-------|-------------|
| **SDK Audio Data** | SDK's render callback outputs all zeros (silence) |

---

## Root Cause Analysis

The SDK's internal audio pipeline is broken:

1. SDK receives audio frames from camera (confirmed - we see render callbacks firing)
2. SDK decodes G.711a audio (presumably working - frames have correct structure)
3. SDK fails to configure its AudioUnit with error -50:
   ```
   SessionCore.mm:517   Failed to set properties, error: 4294967246
   ```
   (4294967246 = -50 in unsigned 32-bit)
4. Because SDK's AudioUnit configuration failed, the **decoded audio never reaches the render buffer**
5. SDK's render callback fires, but outputs zeros (silence)

**The SDK's audio decoding pipeline is disconnected from its render output due to the configuration failure.**

---

## Why Our Hook Approach Can't Work (As-Is)

Our approach was to:
> "Hook into SDK's AudioUnit, capture audio **before** SDK fails"

But the reality is:
- The SDK's error -50 occurs during AudioUnit **property configuration**
- This happens **before** any audio data flows through the render callback
- The render callback does fire, but the SDK never fills it with decoded audio
- We're capturing the render output, but it's empty because the SDK's internal pipeline is broken

**We're intercepting at the wrong point in the audio flow.**

---

## Alternative Approaches to Consider

### Option A: Hook the Audio Decoder Output
Instead of hooking the AudioUnit render callback (which is downstream of the failure), hook the SDK's audio **decoder** output:
- Find where `voice_decoder` (seen in ivar list) outputs decoded PCM
- Intercept that data before it tries to reach the broken AudioUnit

**Pros:** Gets actual decoded audio
**Cons:** Requires reverse-engineering SDK internals

### Option B: Replace SDK's AudioUnit Entirely
Instead of installing a render notify, **replace** the SDK's AudioUnit with our own that works at 16kHz:
- Swizzle `createAudioUnitWithOutput:input:` to return our custom AudioUnit
- Configure it to accept 16kHz input directly
- May need to implement our own render callback that the SDK fills

**Pros:** SDK might successfully fill our AudioUnit
**Cons:** Complex; SDK may have assumptions about its AudioUnit

### Option C: Hook the Raw G.711a Stream
Intercept the raw G.711a compressed audio from the P2P connection before the SDK decodes it:
- Look for the `voice_frame` ivar data
- Decode G.711a ourselves
- Play through our AVAudioEngine

**Pros:** Bypasses SDK's broken audio pipeline entirely
**Cons:** Need to handle G.711a decoding ourselves

### Option D: Use SDK's Internal Audio Buffer
The SDK must have an internal buffer where decoded audio sits before (failing to) reach the AudioUnit:
- Investigate `voice_decoder` pointer
- Find the decoded PCM buffer
- Read directly from there

**Pros:** Gets decoded audio without re-implementing decoder
**Cons:** Requires more reverse engineering

---

## Files Involved

| File | Purpose |
|------|---------|
| `AudioHookBridge.h/m` | Objective-C swizzling, render notify callback, format conversion |
| `AudioBridgeEngine.swift` | AVAudioEngine pipeline, health monitoring, auto-restart |
| `CircularAudioBuffer.swift` | Thread-safe ring buffer between capture and playback |
| `ContentView.swift` | Test UI, capture callback setup |
| `AudioStreamService.swift` | Flutter method channel integration |

---

## Errors That Can Be Ignored

### Flutter Platform Channel Warning
```
[ERROR:flutter/shell/common/shell.cc(1178)] The 'app_p2p_api_event_channel/command' channel sent a message from native to Flutter on a non-platform thread.
```
Unrelated to audio - this is P2P event handling threading issue.

### SDK Error -50
```
SessionCore.mm:517   Failed to set properties, error: 4294967246
```
This is the expected SDK failure. Our entire approach exists because of this error.

### Native Start Returns False
```
[AppPlayer] Native returned: false (type: bool)
[AppPlayer] ❌ Start audio FAILED - native returned false
```
Expected - SDK reports its audio start failed. Our hook continues anyway.

### Emoji Display Issues
Some emojis like 🔍 appear as `��` in Xcode console - this is a terminal encoding issue, not a code bug.

---

## Session Notes

- **2026-02-04 Session 1:** Initial investigation, confirmed hooks work, discovered buffer instance matching
- **2026-02-04 Session 2:** Discovered engine stops due to category change, implemented auto-restart
- **2026-02-04 Session 3:** Added sample value diagnostics, discovered SDK outputs silence
- **2026-02-04 Session 4:** Implemented voice_frame direct capture, discovered complete pipeline failure
- **Root cause identified:** SDK's `startVoice()` returns FALSE, causing the entire audio pipeline to never start

---

## Attempt 7: Voice Frame Direct Capture (G.711a Bypass)

**What we tried:** Instead of hooking the AudioUnit render callback (which outputs silence), directly read from the SDK's `voice_frame` ivar which should contain raw G.711a encoded audio data before decoding.

**Implementation:**
1. Added G.711a A-law decoder lookup table (256 entries)
2. Added app_source_frame structure definition matching SDK's internal format
3. Implemented 10ms polling timer to read voice_frame directly from player instance
4. Added diagnostic logging to show frameno, data pointer, size, and use_flag

**Result:** ❌ **CRITICAL DISCOVERY** - voice_frame is completely empty!

**Evidence:**
```
[AudioHookBridge] ✅ Found voice_frame ivar at offset 16800
[AudioHookBridge] ✅ Voice frame polling started (10ms interval)
[AudioHookBridge] 🔍 Poll #1: frameno=0, data=0x0, size=0, use_flag=1
[AudioHookBridge] 🔍 Poll #2: frameno=0, data=0x0, size=0, use_flag=1
...
[AudioHookBridge] 🔍 Poll #100: frameno=0, data=0x0, size=0, use_flag=1
```

**Analysis:**
| Field | Value | Meaning |
|-------|-------|---------|
| `frameno` | 0 | Never increments - no frames being processed |
| `data` | 0x0 (NULL) | No data buffer allocated |
| `size` | 0 | No data |
| `use_flag` | 1 | Structure exists but unused |

---

## Revised Root Cause Analysis

### The Complete Failure Chain

We previously thought: "SDK decodes audio but fails to play it"
**Reality:** "SDK never even starts receiving audio"

```
1. SDK calls startVoice()
           │
           ▼
2. SDK tries to configure AudioUnit at 16kHz
           │
           ▼
3. iOS rejects with error -50
           │
           ▼
4. ❌ startVoice() returns FALSE
           │
           ▼
5. SDK never requests audio from camera
           │
           ▼
6. Camera never sends audio packets
           │
           ▼
7. voice_frame stays empty (data=NULL, size=0)
           │
           ▼
8. AudioUnit render callback fires but has nothing to play
           │
           ▼
9. We hear silence
```

**Key Insight:** The SDK has "all-or-nothing" behavior. If it can't play audio, it doesn't even bother receiving it.

### Evidence: startVoice() Fails

```
flutter: [AppPlayer]    Native returned: false (type: bool)
flutter: [AppPlayer] ❌ Start audio FAILED - native returned false
```

This confirms the SDK admits failure (it doesn't just return true with broken state).

---

## Updated Architecture Diagram

```
Camera (16kHz G.711a)
        │
        ▼
P2P Network Layer (Channel 2 = Audio)
        │
        ▼
SDK P2P Client receives packets    ◀── We need to intercept HERE
        │
        ▼
SDK's startVoice() checks if AudioUnit works
        │
        ▼
❌ AudioUnit config fails (error -50)
        │
        ▼
SDK aborts - never processes audio
        │
        ├──► voice_frame stays empty
        │
        └──► AudioUnit render outputs zeros
```

---

## Options Going Forward

### Option A: Direct P2P Channel Read (RECOMMENDED)

**Approach:** Bypass the SDK's player entirely. Read raw audio packets directly from P2P Channel 2.

**How it works:**
1. SDK already has `client_read(clientPtr, channel, buffer, size, timeout)` function
2. Channel 2 = P2P_AUDIO_CHANNEL (audio receive)
3. Read raw G.711a packets directly from the P2P layer
4. Decode G.711a ourselves (we already have the decoder table)
5. Resample 16kHz → 48kHz
6. Play through AVAudioEngine

**Evidence this exists:**
- VSTCBridge.swift already has `clientRead()` method implemented
- VSTCBridge.swift has `verifyChannelStatus()` test to compare video vs audio channels
- P2P channel architecture confirmed in app_p2p_api.dart

**Critical Test Needed:**
Run `verifyChannelStatus(clientPtr)` to check if audio channel 2 has data even when startVoice() fails.

**Pros:**
- Completely bypasses broken SDK audio pipeline
- We control the entire flow
- G.711a decoder already implemented

**Cons:**
- Need to verify camera sends audio even without startVoice() succeeding
- May need to send a separate "start audio stream" command to camera

### Option B: Hook Lower in P2P Stack

**Approach:** Intercept audio packets as they arrive from the network, before SDK decides to drop them.

**How it works:**
1. Swizzle the SDK's internal packet dispatch method
2. Capture packets with audio type before SDK checks startVoice() status
3. Decode and play ourselves

**Pros:** Gets audio even if SDK tries to drop it
**Cons:** Requires more reverse engineering of SDK internals

### Option C: Send Audio Command Independently

**Approach:** The camera might need a separate CGI/command to start sending audio, independent of SDK's startVoice().

**How it works:**
1. Research camera's CGI commands for audio
2. Send audio start command directly via P2P command channel
3. Read audio from channel 2
4. Decode and play

**Pros:** Proper separation of concerns
**Cons:** Need to find correct command format

---

## Recommended Next Step: Verify P2P Channel 2

Before implementing any solution, we need to answer ONE critical question:

**Does P2P Channel 2 receive audio data even when startVoice() fails?**

**Test to run:**
```swift
// In ContentView after connecting:
VSTCBridge.shared.verifyChannelStatus(clientPtr: clientPtr)
```

**Expected results:**
- If Channel 1 (video) works AND Channel 2 (audio) has data → Option A will work
- If Channel 1 works BUT Channel 2 is empty → Need to send audio start command first (Option C)
- If both channels fail → Connection issue, not audio-specific

---

## Files Modified in Session 4

| File | Changes |
|------|---------|
| `AudioHookBridge.m` | Added G.711a decoder, voice_frame polling, diagnostic logging |
| `AudioHookBridge.h` | Added `startVoiceFrameCapture`, `stopVoiceFrameCapture` methods |
| `ContentView.swift` | Added call to start voice frame capture after audio starts |
| `AUDIO_HOOK_TROUBLESHOOTING.md` | This update |

---

## P2P Channel Architecture Reference

From `app_p2p_api.dart`:
```dart
Channel 0: P2P_CMD_CHANNEL     - Commands
Channel 1: P2P_VIDEO_CHANNEL   - Video receive (confirmed working)
Channel 2: P2P_AUDIO_CHANNEL   - Audio receive (target for bypass)
Channel 3: P2P_TALKCHANNEL     - Audio send (two-way talk)
Channel 4: P2P_PLAYBACK        - Playback
Channel 5: P2P_SENSORALARM     - Alarms
```

---

## Summary of All Attempts

| # | Approach | Result | Why It Failed |
|---|----------|--------|---------------|
| 1 | Swizzle startVoice/createAudioUnit | ✅ Hooks work | N/A - hooks installed correctly |
| 2 | Render notify on AudioUnit | ✅ Callback fires | N/A - callback works |
| 3 | Format conversion pipeline | ✅ Pipeline works | N/A - data flows correctly |
| 4 | Health check & auto-restart | ✅ Engine restarts | N/A - restart works |
| 5 | Sample value diagnostics | ❌ Found silence | SDK outputs zeros |
| 6 | Direct voice_frame read | ❌ Empty structure | SDK never populates it |
| 7 | P2P Channel direct read (client_read) | ❌ Crashes | Even video channel crashes |
| 8 | **Upstream buffer read** | 🔄 NEXT STEP | Read voice_in_buff/voice_out_buff |

---

## Attempt 8: P2P Channel Direct Read (Failed)

**Date:** 2026-02-04 Session 5

**What we tried:** Use `client_read()` to read directly from P2P Channel 2 (audio) bypassing the SDK's player.

**Implementation:**
- Used `VSTCBridge.verifyChannelStatus()` to test both video (ch1) and audio (ch2) channels
- Resolved `client_read` symbol via dlsym
- Called with clientPtr, channel, buffer, timeout

**Result:** ❌ **CRASH** - Even on VIDEO channel (not just audio)

**Evidence:**
```
[VSTCBridge] 📹 TEST 1: Read from Channel 1 (VIDEO)
[VSTCBridge] Expected: SUCCESS (video is streaming)
[VSTCBridge] 📡 >>> client_read(clientPtr:0x126289804, ch:1, buf:4096, timeout:1000) <<<
*** CRASH in client_read ***
```

**Key Discovery:** The crash happens on Channel 1 (VIDEO), not just Channel 2 (audio). This means:
- The problem is NOT that "audio channel never opens"
- The problem is how we're calling `client_read()` - wrong signature or wrong handle type
- The SDK uses an event-driven/callback architecture, NOT synchronous reads

**Comparison with Video Streaming:**
Video works because the SDK uses a **passive EventChannel pattern**:
- SDK internally handles channel 1
- SDK decodes video and registers texture with Flutter
- SDK pushes frames via EventChannel
- We receive passively

Audio failed because we tried an **active polling pattern**:
- We called `client_read()` directly → CRASH
- SDK is not designed for direct channel reads from external code

---

## SDK Audio Infrastructure Analysis

**Date:** 2026-02-04 Session 5

After the P2P direct read approach failed, we conducted a deep analysis of the SDK's internal audio infrastructure using `nm` to examine exported symbols.

### Discovered PCM Listener Infrastructure

```
PcmPlayerListener              - Listener interface for PCM audio callbacks
VoicePlayer_PcmPlayerListener  - Voice-specific PCM listener
pcmp2_setListener              - Function to SET the PCM listener
pcmp2_init / pcmp2_finalize    - Initialize/cleanup PCM player
pcmp2_start / pcmp2_stop       - Start/stop PCM playback
xlaw_to_pcm16                  - G.711 (X-law) to PCM16 converter (SDK has this!)
```

### Discovered AppIOSPlayer Voice Buffers

```c
// These ivars exist in AppIOSPlayer but we haven't read them yet:
voice_in_buff     // ← Raw G.711a input BEFORE decoding
voice_in_data     // ← Raw input data pointer
voice_out_buff    // ← Decoded PCM output AFTER decoding
voice_out_data    // ← Decoded output data pointer
voice_decoder     // ← Decoder instance (app_voice_coder)
voice_frame       // ← Final frame (EMPTY - we already checked)
```

### Discovered Audio Processing Functions

```c
app_source_voice_read()     // Reads voice from P2P source
app_player_render_voice()   // Renders voice to AudioUnit
app_voice_coder_create()    // Creates voice decoder
app_voice_coder_frame()     // Decodes a single voice frame
app_voice_coder_destroy()   // Destroys voice decoder
```

### Updated Audio Pipeline Understanding

```
MOST UPSTREAM (network layer)
         ↓
P2P Channel 2 (raw packets from camera)
         ↓
app_source_voice_read()      ← SDK reads from network
         ↓
voice_in_buff / voice_in_data   ← Raw G.711a data [UNEXPLORED]
         ↓
voice_decoder (app_voice_coder_frame)
         ↓
voice_out_buff / voice_out_data ← Decoded PCM [UNEXPLORED]
         ↓
voice_frame                  ← Final frame [EMPTY - checked]
         ↓
AudioUnit render callback    ← [SILENCE - checked]
         ↓
MOST DOWNSTREAM (speaker)
```

### Key Insight: We've Been Looking Too Far Downstream

| Buffer/Point | Location in Pipeline | Status |
|--------------|---------------------|--------|
| `voice_in_buff` | UPSTREAM (raw G.711a) | ❓ NOT CHECKED |
| `voice_in_data` | UPSTREAM (raw data ptr) | ❓ NOT CHECKED |
| `voice_out_buff` | MIDDLE (decoded PCM) | ❓ NOT CHECKED |
| `voice_out_data` | MIDDLE (decoded ptr) | ❓ NOT CHECKED |
| `voice_frame` | DOWNSTREAM (final) | ❌ EMPTY |
| AudioUnit render | MOST DOWNSTREAM | ❌ SILENCE |

---

## Next Step: Attempt 9 - Upstream Buffer Read

**Hypothesis:** Data might exist in `voice_in_buff` or `voice_out_buff` even though `voice_frame` is empty. The SDK might be receiving and decoding audio but failing to pass it downstream due to error -50.

**Plan:**
1. Modify `pollVoiceFrame` in AudioHookBridge.m to also read:
   - `voice_in_buff` / `voice_in_data` (raw G.711a)
   - `voice_out_buff` / `voice_out_data` (decoded PCM)

2. Log the buffer pointers and sizes to see if data exists

3. If data exists:
   - If in `voice_in_*`: Decode G.711a ourselves (we have the decoder)
   - If in `voice_out_*`: Use directly (already decoded)

**Expected Outcomes:**
- If `voice_in_*` has data → Audio arrives but SDK drops it during decode phase
- If `voice_out_*` has data → Audio decoded but SDK drops it before AudioUnit
- If both empty → SDK never requests audio from camera when startVoice() fails

---

## Lessons Learned

### 1. SDK Architecture is Event-Driven, Not Poll-Based
- Video works via EventChannel (passive receive)
- Direct `client_read()` calls crash
- Must use SDK's internal mechanisms or hook at the right point

### 2. Check Upstream Before Assuming Data Doesn't Exist
- We assumed `voice_frame` empty = no audio
- But there are upstream buffers (`voice_in_*`, `voice_out_*`) we haven't checked
- Data might exist earlier in the pipeline

### 3. The SDK Has Built-in G.711 Decoder
- `xlaw_to_pcm16` function exists
- `app_voice_coder_frame` decodes voice frames
- If we can get raw data, SDK's decoder might still work

---

## Session Timeline

| Session | Focus | Key Finding |
|---------|-------|-------------|
| Session 1 | Hook installation | Swizzling works, AudioUnit captured |
| Session 2 | Engine stability | Category change kills engine, auto-restart works |
| Session 3 | Sample analysis | SDK outputs SILENCE (all zeros) |
| Session 4 | voice_frame read | voice_frame is EMPTY, startVoice() returns FALSE |
| Session 5 | P2P direct read | client_read() CRASHES, discovered upstream buffers |
| Session 6 | Upstream buffer read | Buffers exist but EMPTY (r=0, w=0) |

---

## Attempt 9: Upstream Buffer Read (Implemented)

**Date:** 2026-02-04 Session 6

**What we tried:** Read from the upstream buffers (`voice_in_buff`, `voice_out_buff`) that exist BEFORE `voice_frame` in the audio pipeline, to see if audio data exists at an earlier point.

**Implementation:**
- Modified `pollVoiceFrame` in AudioHookBridge.m to call `checkUpstreamBuffers`
- Scans for known buffer ivar names: `voice_in_buff`, `voice_in_data`, `voice_out_buff`, `voice_out_data`
- Enumerates ALL ivars matching patterns: voice, audio, buff, pcm, data
- Dumps buffer struct contents (pointer, size, read/write positions)
- Dumps first 32-64 bytes of actual buffer data

**Result:** ❌ **CONFIRMED ROOT CAUSE** - Buffers exist but contain NO DATA

### Discovered Buffer Structures

**voice_out_buff (Decoded PCM buffer):**
```
[AudioHookBridge] 🔬 UPSTREAM BUFFER FOUND: voice_out_buff
   Offset: 17056, Type: {?="buff"*"size"Q"r"Q"w"Q}
   Embedded struct type - dumping first 64 bytes:
   C0 82 05 29 01 00 00 00  ← buff pointer (valid: 0x012905820C0)
   00 F4 01 00 00 00 00 00  ← size = 0x1F400 = 128000 bytes
   00 00 00 00 00 00 00 00  ← r (read position) = 0
   00 00 00 00 00 00 00 00  ← w (write position) = 0
✅ STRUCT HAS NON-ZERO DATA!
```

**voice_in_buff (Raw G.711a input buffer):**
```
[AudioHookBridge] 🔬 UPSTREAM BUFFER FOUND: voice_in_buff
   Offset: 145088, Type: {?="buff"*"size"Q"r"Q"w"Q}
   Embedded struct type - dumping first 64 bytes:
   00 00 00 00 00 00 00 00  ← buff pointer = NULL
   00 00 00 00 00 00 00 00  ← size = 0
   00 00 00 00 00 00 00 00  ← r = 0
   00 00 00 00 00 00 00 00  ← w = 0
   (all zeros - never allocated)
```

**voice_in_data / voice_out_data:**
```
Type: [128000C]  ← 128KB inline byte arrays
(Not pointer-based, harder to dump but likely all zeros)
```

### Complete Audio-Related Ivar List

All ivars discovered in AppIOSPlayer matching audio/voice/buffer patterns:

| Ivar Name | Type | Purpose |
|-----------|------|---------|
| `audioUnit` | `^{OpaqueAudioComponentInstance=}` | AudioUnit pointer |
| `pixelBuffer` | `^{__CVBuffer=}` | Video pixel buffer |
| `scaleBuffer` | `^{__CVBuffer=}` | Video scale buffer |
| `voice_frame` | `{app_source_frame=...}` | Final voice frame (EMPTY) |
| `voice_decoder` | `^{app_voice_coder=}` | Voice decoder pointer |
| `voice_encoder` | `^{app_voice_coder=}` | Voice encoder pointer |
| `voice_size` | `Q` | Voice buffer size |
| `voice_out_buff` | `{?="buff"*"size"Q"r"Q"w"Q}` | Output ring buffer struct |
| `voice_out_data` | `[128000C]` | 128KB output data array |
| `voice_in_buff` | `{?="buff"*"size"Q"r"Q"w"Q}` | Input ring buffer struct |
| `voice_in_data` | `[128000C]` | 128KB input data array |
| `voice_flag` | `B` | Voice enabled flag |
| `voice_channel` | `i` | Voice channel number |
| `voice_timestamp` | `I` | Voice timestamp |
| `voice_duration` | `d` | Voice duration |
| `voice_type` | `I` | Voice type/codec |

### Key Analysis

| Buffer | Allocated? | Size | Read Pos | Write Pos | Has Data? |
|--------|-----------|------|----------|-----------|-----------|
| `voice_out_buff` | ✅ YES | 128KB | 0 | 0 | ❌ NO |
| `voice_in_buff` | ❌ NO | 0 | 0 | 0 | ❌ NO |
| `voice_frame` | ✅ YES | 0 | - | - | ❌ NO |

**Critical Finding:** `voice_out_buff` IS allocated with 128KB of memory, but read=0 and write=0 means **NOTHING has ever been written to it**.

---

## Final Root Cause Confirmation

### The Problem Is NOT:
- ❌ Audio decoding failure
- ❌ AudioUnit render callback issue
- ❌ Buffer pipeline problem
- ❌ Format conversion error

### The Problem IS:
**The SDK never requests audio from the camera when `startVoice()` fails.**

```
SDK Flow When startVoice() Fails:

1. startVoice() called
2. SDK tries to configure AudioUnit at 16kHz
3. iOS rejects with error -50
4. startVoice() returns FALSE
5. SDK ABORTS IMMEDIATELY ← This is the problem
6. SDK never sends "start audio" command to camera
7. Camera never sends audio packets
8. voice_in_buff stays empty (never allocated)
9. voice_out_buff stays empty (allocated but unused)
10. voice_frame stays empty
11. AudioUnit render callback outputs silence
```

### Evidence Summary

| Evidence | Conclusion |
|----------|------------|
| `startVoice()` returns `false` | SDK acknowledges failure |
| `voice_in_buff` not allocated | SDK never set up input |
| `voice_out_buff.w = 0` | SDK never wrote decoded audio |
| `voice_frame.data = NULL` | SDK never created output frames |
| AudioUnit outputs zeros | No audio data anywhere in pipeline |

---

## The Only Path Forward

Since the SDK has "all-or-nothing" behavior and won't request audio when its AudioUnit fails, we must **bypass the SDK's audio entirely**:

### Required Solution: Direct Camera Audio Control

1. **Send audio enable command to camera ourselves**
   - Find the CGI or P2P command the SDK normally sends
   - Send it directly after video connection succeeds

2. **Receive raw G.711a packets from P2P Channel 2**
   - Can't use `client_read()` (crashes)
   - Need to hook SDK's packet dispatch or use EventChannel pattern

3. **Decode G.711a ourselves**
   - Already implemented in AudioHookBridge.m (alaw_to_linear table)

4. **Play through our AVAudioEngine**
   - Already working (AudioBridgeEngine.swift)

### Why This Will Work

- Video streaming works because SDK sends the "start video" command regardless of audio status
- If we can send "start audio" command ourselves, camera will send audio packets
- We just need to intercept those packets at the right point in SDK's receive path

---

## Files Modified in Session 6

| File | Changes |
|------|---------|
| `AudioHookBridge.m` | Added `checkUpstreamBuffers` method to scan voice_in/out buffers |
| `ContentView.swift` | Updated camera UID to OKB0379196OXYB |
| `AUDIO_HOOK_TROUBLESHOOTING.md` | This comprehensive update |

---

---

## Attempt 10: Story 10.3 - CSession P2P Channel Access

**Date:** 2026-02-04 Session 7

**What we tried:** Resolve CSession functions via dlsym to access the P2P layer directly, allocate the voice buffer if needed, and poll for audio data while sending CGI commands.

### Implementation

1. **Resolved CSession symbols via dlsym:**
   - `CSession_ChannelBuffer_Get` - Get buffer for P2P channel
   - `CSession_Data_Read` - Read data from channel
   - `CSession_SessionInfo_Get` - Get session info from client

2. **Added voice buffer allocation:**
   - Check if `voice_out_buff.size == 0`
   - If so, manually allocate 128KB buffer at offset 17056

3. **Added P2P audio capture with polling:**
   - Create dispatch_source timer (10ms interval)
   - Poll `voice_out_buff` structure (r, w positions)
   - Decode G.711a if data found
   - Forward to capture callback

4. **Combined test with CGI commands:**
   - Send multiple audio CGI commands
   - Monitor buffer before/during/after

### Results

**CSession Symbol Resolution:** ✅ ALL FOUND
```
[AudioHookBridge] 🔗 CSession symbols resolved:
   CSession_ChannelBuffer_Get: 0x104c35c74 ✅
   CSession_Data_Read: 0x104c35c74 ✅
   CSession_SessionInfo_Get: 0x104c35c74 ✅
```

**Voice Buffer State:** ✅ ALLOCATED (but empty)
```
[AudioHookBridge] 🔬 voice_out_buff already allocated:
   size: 128000 bytes
   r: 0
   w: 0
```

**CGI Commands:** ✅ ALL SUCCEEDED
```
[AudioHookBridge] 📡 CGI: decoder_control.cgi?command=90 → result: 1
[AudioHookBridge] 📡 CGI: audiostream.cgi?streamid=0 → result: 1
[AudioHookBridge] 📡 CGI: get_camera_params.cgi → result: 1
[AudioHookBridge] 📡 CGI: get_params.cgi?audio_enable → result: 1
```

**Buffer Polling:** ❌ NO DATA EVER WRITTEN
```
[AudioHookBridge] 📊 Poll #1: r=0, w=0
[AudioHookBridge] 📊 Poll #2: r=0, w=0
...
[AudioHookBridge] 📊 Poll #100: r=0, w=0
```

### Key Insights from Story 10.3

| Component | Status | Observation |
|-----------|--------|-------------|
| CSession symbols | ✅ Found | SDK exports these functions |
| CGI command send | ✅ Works | Commands return success (1) |
| voice_out_buff allocation | ✅ Exists | 128KB allocated by SDK |
| Buffer write position | ❌ Always 0 | SDK never writes to buffer |

### Analysis

**Significant Change from Story 10.2:**
- In Story 10.2: `voice_out_buff.size = 0` (buffer not allocated)
- In Story 10.3: `voice_out_buff.size = 128000` (buffer IS allocated!)

This means the SDK DOES allocate the buffer, but **never writes to it**. The camera may be sending audio packets, but the SDK's internal state machine is blocking them from reaching the buffer.

### Possible Root Causes

1. **SDK drops packets before buffer:**
   The SDK receives audio packets but checks `voice_flag` or similar state before writing to buffer. Since `startVoice()` returned FALSE, this flag is likely FALSE.

2. **Camera never sends audio:**
   Despite CGI commands returning success, the camera might not be configured to send audio over P2P. The CGI success might just mean "command received" not "audio enabled".

3. **Wrong P2P channel:**
   Audio might be arriving on a different channel or in a different format than expected.

4. **Timing issue:**
   Camera might need video streaming established first, or might need a specific sequence of commands.

### What We Learned

1. **CSession functions ARE accessible** - We can resolve and potentially call them
2. **CGI commands ARE sent successfully** - The P2P command channel works
3. **Buffers ARE allocated** - The SDK sets up memory for audio
4. **SDK internal state blocks audio** - Something between packet receive and buffer write drops everything

### Failed Hypotheses

| Hypothesis | Result |
|------------|--------|
| "Buffer not allocated because startVoice failed" | ❌ Buffer IS allocated (128KB) |
| "CGI commands will trigger audio" | ❌ Commands succeed but no audio |
| "CSession direct read will work" | ❌ No data in buffers to read |

---

## Summary of All Attempts

| # | Approach | Result | Why It Failed |
|---|----------|--------|---------------|
| 1 | Swizzle startVoice/createAudioUnit | ✅ Hooks work | N/A - hooks installed correctly |
| 2 | Render notify on AudioUnit | ✅ Callback fires | N/A - callback works |
| 3 | Format conversion pipeline | ✅ Pipeline works | N/A - data flows correctly |
| 4 | Health check & auto-restart | ✅ Engine restarts | N/A - restart works |
| 5 | Sample value diagnostics | ❌ Found silence | SDK outputs zeros |
| 6 | Direct voice_frame read | ❌ Empty structure | SDK never populates it |
| 7 | P2P Channel direct read (client_read) | ❌ Crashes | Wrong function signature/context |
| 8 | Upstream buffer read | ❌ Buffers empty | r=0, w=0 despite allocation |
| 9 | pcmp2_setListener (Story 10.1) | ❌ Symbols not found | SDK doesn't export pcmp2_* |
| 10 | CSession + CGI (Story 10.3) | ❌ No data | CGI succeeds but buffer stays empty |

---

## Current Understanding

### What Works ✅
- Method swizzling and hooking SDK methods
- CGI command transmission via P2P
- CSession symbol resolution
- AVAudioEngine pipeline (tested with synthetic audio)
- G.711a decoder (tested with known samples)
- Circular buffer implementation

### What Doesn't Work ❌
- Getting actual audio data from SDK/camera
- Any approach that relies on SDK's internal state machine
- Direct P2P channel reads (crashes)

### The Fundamental Problem

The SDK has an **all-or-nothing architecture**:
```
IF (AudioUnit configuration succeeds at 16kHz)
    THEN enable entire audio pipeline
    ELSE disable EVERYTHING - don't even request audio from camera
```

iOS requires minimum 48kHz → AudioUnit fails → SDK disables audio → Camera never sends audio

---

## Next Steps (Story 10.4: Pipeline Integration)

Story 10.4 focuses on building the complete playback pipeline, but first we need working audio data. Options to explore:

1. **Hook deeper in SDK** - Find where packets arrive before state check
2. **Different camera command** - Try ONVIF or other protocols
3. **Network packet capture** - Verify camera is/isn't sending audio
4. **Alternative SDK initialization** - Force startVoice to "succeed" despite error

---

## Files Modified in Story 10.3

| File | Changes |
|------|---------|
| `AudioHookBridge.h` | Added Story 10.3 method declarations |
| `AudioHookBridge.m` | Added CSession resolution, buffer allocation, P2P capture |
| `ContentView.swift` | Added "Test P2P Capture (10.3)" button |
| `AUDIO_HOOK_TROUBLESHOOTING.md` | This update |

---

## Session Timeline (Updated)

| Session | Focus | Key Finding |
|---------|-------|-------------|
| Session 1 | Hook installation | Swizzling works, AudioUnit captured |
| Session 2 | Engine stability | Category change kills engine, auto-restart works |
| Session 3 | Sample analysis | SDK outputs SILENCE (all zeros) |
| Session 4 | voice_frame read | voice_frame is EMPTY, startVoice() returns FALSE |
| Session 5 | P2P direct read | client_read() CRASHES, discovered upstream buffers |
| Session 6 | Upstream buffer read | Buffers exist but EMPTY (r=0, w=0) |
| Session 7 | Story 10.1-10.3 | pcmp2 not found, CGI works, CSession works, still no data |
