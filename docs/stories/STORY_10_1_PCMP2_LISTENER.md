# Story 10.1: Investigate pcmp2_setListener API

## Parent Story
[STORY_10_BYPASS_SDK_AUDIO.md](./STORY_10_BYPASS_SDK_AUDIO.md)

## Objective
Determine if the SDK's `pcmp2_setListener()` function can deliver audio data to our callback, bypassing the broken AudioUnit pipeline.

## Background

The SDK exports these PCM player functions:
```
_pcmp2_init           - Initialize PCM player
_pcmp2_setListener    - Set listener callback for audio data
_pcmp2_setAudioPlayer - Set audio player instance
_pcmp2_start          - Start playback
_pcmp2_stop           - Stop playback
_pcmp2_finalize       - Cleanup
```

**Hypothesis:** If we register a listener callback via `pcmp2_setListener()`, the SDK might deliver decoded PCM audio directly to us, even when AudioUnit fails.

---

## Implementation Tasks

### Task 1: Resolve pcmp2 Symbols via dlsym

**Goal:** Access pcmp2_* functions at runtime.

**Implementation:**
```objc
// In AudioHookBridge.m
#include <dlfcn.h>

// Function pointer types (signatures to be determined)
typedef void* (*pcmp2_init_fn)(void);
typedef void (*pcmp2_finalize_fn)(void *player);
typedef void (*pcmp2_setListener_fn)(void *player, void *listener);
typedef void (*pcmp2_start_fn)(void *player);
typedef void (*pcmp2_stop_fn)(void *player);

// Resolved function pointers
static pcmp2_init_fn pcmp2_init = NULL;
static pcmp2_finalize_fn pcmp2_finalize = NULL;
static pcmp2_setListener_fn pcmp2_setListener = NULL;
static pcmp2_start_fn pcmp2_start = NULL;
static pcmp2_stop_fn pcmp2_stop = NULL;

- (BOOL)resolvePcmp2Symbols {
    pcmp2_init = dlsym(RTLD_DEFAULT, "pcmp2_init");
    pcmp2_finalize = dlsym(RTLD_DEFAULT, "pcmp2_finalize");
    pcmp2_setListener = dlsym(RTLD_DEFAULT, "pcmp2_setListener");
    pcmp2_start = dlsym(RTLD_DEFAULT, "pcmp2_start");
    pcmp2_stop = dlsym(RTLD_DEFAULT, "pcmp2_stop");

    NSLog(@"[PCMP2] pcmp2_init: %p", pcmp2_init);
    NSLog(@"[PCMP2] pcmp2_setListener: %p", pcmp2_setListener);
    NSLog(@"[PCMP2] pcmp2_start: %p", pcmp2_start);

    return (pcmp2_init != NULL && pcmp2_setListener != NULL);
}
```

**Test:** Button in UI that calls `resolvePcmp2Symbols()` and logs results.

**Success Criteria:**
- [ ] All pcmp2 function pointers are non-NULL
- [ ] Logged addresses match expected SDK memory range

---

### Task 2: Determine Listener Callback Signature

**Goal:** Reverse engineer the expected callback signature for `pcmp2_setListener()`.

**Approaches:**

1. **Disassemble pcmp2_setListener:**
   ```bash
   nm -g ios/VeepaAudioTest/VeepaSDK/libVSTC.a | grep pcmp2
   # Then use otool or Hopper to examine the function
   ```

2. **Try common callback signatures:**
   ```objc
   // Signature A: Simple data callback
   typedef void (*pcmp2_listener_a)(void *context, const void *data, size_t size);

   // Signature B: Structured callback with format info
   typedef void (*pcmp2_listener_b)(void *context, const int16_t *samples,
                                     uint32_t frameCount, uint32_t sampleRate);

   // Signature C: Block-based callback
   typedef void (^pcmp2_listener_block)(const void *data, size_t size);
   ```

3. **Check if it's an Objective-C delegate pattern:**
   ```objc
   // The listener might be an object with a method like:
   // - (void)pcmPlayer:(id)player didReceiveAudio:(NSData *)data;
   ```

**Test:** Create test listener implementations and call `pcmp2_setListener()` with each.

**Success Criteria:**
- [ ] Listener callback is invoked
- [ ] Callback receives data (any data, even silence)

---

### Task 3: Register Listener and Test

**Goal:** Successfully register a listener and receive audio callbacks.

**Implementation:**
```objc
// Test listener callback
static void testPcmp2Listener(void *context, const void *data, size_t size) {
    NSLog(@"[PCMP2-LISTENER] Received %zu bytes!", size);

    // Check if data is non-zero
    const uint8_t *bytes = data;
    int nonZeroCount = 0;
    for (size_t i = 0; i < MIN(size, 100); i++) {
        if (bytes[i] != 0) nonZeroCount++;
    }
    NSLog(@"[PCMP2-LISTENER] Non-zero bytes in first 100: %d", nonZeroCount);
}

- (void)testPcmp2Listener {
    if (![self resolvePcmp2Symbols]) {
        NSLog(@"[PCMP2] Failed to resolve symbols");
        return;
    }

    // Try to initialize and register listener
    void *player = pcmp2_init ? pcmp2_init() : NULL;
    NSLog(@"[PCMP2] pcmp2_init returned: %p", player);

    if (pcmp2_setListener && player) {
        pcmp2_setListener(player, testPcmp2Listener);
        NSLog(@"[PCMP2] Listener registered");
    }

    if (pcmp2_start && player) {
        pcmp2_start(player);
        NSLog(@"[PCMP2] pcmp2_start called");
    }
}
```

**Test:**
1. Connect to camera
2. Call `testPcmp2Listener()`
3. Trigger `startVoice()` on SDK
4. Check logs for listener invocations

**Success Criteria:**
- [ ] Listener callback is invoked at least once
- [ ] Data received is non-zero (actual audio, not silence)

---

### Task 4: Analyze pcmp2 Relationship to SDK

**Goal:** Understand how pcmp2 relates to AppIOSPlayer.

**Questions to answer:**
1. Does AppIOSPlayer use pcmp2 internally?
2. Does pcmp2 get audio from the same source as voice_frame?
3. Is pcmp2 initialized before or after startVoice()?

**Investigation:**
```objc
// Check if AppIOSPlayer has pcmp2-related ivars
- (void)investigatePcmp2InPlayer {
    Class playerClass = NSClassFromString(@"AppIOSPlayer");
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList(playerClass, &ivarCount);

    for (unsigned int i = 0; i < ivarCount; i++) {
        const char *name = ivar_getName(ivars[i]);
        const char *type = ivar_getTypeEncoding(ivars[i]);

        if (strstr(name, "pcm") || strstr(name, "pcmp") ||
            strstr(name, "player") || strstr(name, "listener")) {
            NSLog(@"[PCMP2-IVAR] %s : %s", name, type);
        }
    }
    free(ivars);
}
```

**Success Criteria:**
- [ ] Understand relationship between pcmp2 and AppIOSPlayer
- [ ] Know when/how pcmp2 is initialized by SDK

---

## UI Changes

Add a "Test pcmp2" button to ContentView:
```swift
Button("Test pcmp2 Listener") {
    AudioHookBridge.shared.testPcmp2Listener()
}
```

---

## Verification Tests

### Test 1: Symbol Resolution
```
Expected log output:
[PCMP2] pcmp2_init: 0x1XXXXXXXX (non-null)
[PCMP2] pcmp2_setListener: 0x1XXXXXXXX (non-null)
[PCMP2] pcmp2_start: 0x1XXXXXXXX (non-null)
```

### Test 2: Listener Registration
```
Expected log output:
[PCMP2] pcmp2_init returned: 0xXXXXXXXX (non-null)
[PCMP2] Listener registered
[PCMP2] pcmp2_start called
```

### Test 3: Audio Data Received
```
Expected log output (after startVoice):
[PCMP2-LISTENER] Received XXX bytes!
[PCMP2-LISTENER] Non-zero bytes in first 100: XX (> 0)
```

---

## Acceptance Criteria

- [ ] `resolvePcmp2Symbols()` finds all pcmp2 function pointers
- [ ] Listener callback signature determined
- [ ] `testPcmp2Listener()` method implemented and callable from UI
- [ ] Test results logged and documented

## Exit Criteria

**SUCCESS:** Listener receives non-zero audio data → Proceed to integrate with AudioBridgeEngine

**FAILURE:** Any of:
- pcmp2 symbols not found
- Listener never called
- Listener only receives silence/zeros

If FAILURE → Proceed to [Story 10.2: Audio CGI Command Discovery](./STORY_10_2_CGI_COMMAND.md)

---

## Estimated Duration
1-2 hours

## Risk Assessment
| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Symbols not exported | Low | Already found via nm |
| Wrong callback signature | Medium | Try multiple signatures |
| Listener not called | High | This is why we're testing |

---

## Files to Modify

| File | Changes |
|------|---------|
| `AudioHookBridge.m` | Add pcmp2 symbol resolution and test methods |
| `AudioHookBridge.h` | Export new methods |
| `ContentView.swift` | Add "Test pcmp2" button |

---

## Next Story
If successful: Integrate pcmp2 audio with AudioBridgeEngine
If failed: [Story 10.2: Audio CGI Command Discovery](./STORY_10_2_CGI_COMMAND.md)
