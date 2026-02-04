//
//  AudioHookBridge.m
//  VeepaAudioTest
//
//  Created for AudioUnit Hook implementation
//  Purpose: Objective-C runtime magic to intercept SDK's audio
//

#import "AudioHookBridge.h"
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>
#import <dlfcn.h>

// Forward declare the SDK's class
@class AppIOSPlayer;

#pragma mark - pcmp2 Function Types (Story 10.1)

/// Function pointer types for pcmp2_* SDK functions
/// These signatures are guesses based on common callback patterns - we'll experiment

// Possible listener callback signatures
typedef void (*pcmp2_listener_fn_a)(void *context, const void *data, size_t size);
typedef void (*pcmp2_listener_fn_b)(void *context, const int16_t *samples, uint32_t frameCount, uint32_t sampleRate);
typedef void (*pcmp2_listener_fn_c)(const void *data, size_t size);

// pcmp2 function pointer types
typedef void* (*pcmp2_init_fn)(void);
typedef void (*pcmp2_finalize_fn)(void *player);
typedef void (*pcmp2_setListener_fn)(void *player, void *listener);
typedef void (*pcmp2_setAudioPlayer_fn)(void *player, void *audioPlayer);
typedef void (*pcmp2_start_fn)(void *player);
typedef void (*pcmp2_stop_fn)(void *player);

// Resolved function pointers (NULL until resolved)
static pcmp2_init_fn g_pcmp2_init = NULL;
static pcmp2_finalize_fn g_pcmp2_finalize = NULL;
static pcmp2_setListener_fn g_pcmp2_setListener = NULL;
static pcmp2_setAudioPlayer_fn g_pcmp2_setAudioPlayer = NULL;
static pcmp2_start_fn g_pcmp2_start = NULL;
static pcmp2_stop_fn g_pcmp2_stop = NULL;

// pcmp2 instance created by our init
static void *g_pcmp2_instance = NULL;

#pragma mark - CGI Command Types (Story 10.2)

/// client_write_cgi function type
/// Signature: int client_write_cgi(void *client, const char *cgi)
/// Returns: bytes written or negative on error
typedef int (*client_write_cgi_fn)(void *client, const char *cgi);

// Resolved function pointer
static client_write_cgi_fn g_client_write_cgi = NULL;

/// Buffer monitoring state
static dispatch_source_t g_bufferMonitorTimer = NULL;
static uint64_t g_lastBufferWritePos = 0;

/// Test listener callback - logs when called
static void testPcmp2ListenerCallback(void *context, const void *data, size_t size) {
    NSLog(@"[PCMP2-LISTENER] 🎉 CALLBACK INVOKED! context=%p, data=%p, size=%zu", context, data, size);

    if (data && size > 0) {
        // Check for non-zero data
        const uint8_t *bytes = (const uint8_t *)data;
        int nonZeroCount = 0;
        for (size_t i = 0; i < MIN(size, 100); i++) {
            if (bytes[i] != 0) nonZeroCount++;
        }
        NSLog(@"[PCMP2-LISTENER] Non-zero bytes in first %zu: %d", MIN(size, (size_t)100), nonZeroCount);

        // Dump first 32 bytes
        NSMutableString *hexStr = [NSMutableString string];
        for (size_t i = 0; i < MIN(size, (size_t)32); i++) {
            [hexStr appendFormat:@"%02X ", bytes[i]];
        }
        NSLog(@"[PCMP2-LISTENER] First bytes: %@", hexStr);

        // Forward to AudioHookBridge if this looks like audio
        if (nonZeroCount > 10) {
            AudioHookBridge *bridge = (__bridge AudioHookBridge *)context;
            if (bridge.captureCallback) {
                // Assume data is PCM16 for now (might need adjustment)
                size_t sampleCount = size / sizeof(int16_t);
                bridge.captureCallback((const int16_t *)data, (uint32_t)sampleCount);
                NSLog(@"[PCMP2-LISTENER] Forwarded %zu samples to Swift", sampleCount);
            }
        }
    }
}

/// Alternative callback signature (no context)
static void testPcmp2ListenerCallbackNoContext(const void *data, size_t size) {
    NSLog(@"[PCMP2-LISTENER-NC] 🎉 CALLBACK (no context)! data=%p, size=%zu", data, size);
}

#pragma mark - G.711 A-law Decoder

/// G.711 A-law to 16-bit linear PCM lookup table
/// A-law is used in European telephony and many IP cameras
static const int16_t alaw_to_linear[256] = {
    -5504, -5248, -6016, -5760, -4480, -4224, -4992, -4736,
    -7552, -7296, -8064, -7808, -6528, -6272, -7040, -6784,
    -2752, -2624, -3008, -2880, -2240, -2112, -2496, -2368,
    -3776, -3648, -4032, -3904, -3264, -3136, -3520, -3392,
    -22016, -20992, -24064, -23040, -17920, -16896, -19968, -18944,
    -30208, -29184, -32256, -31232, -26112, -25088, -28160, -27136,
    -11008, -10496, -12032, -11520, -8960, -8448, -9984, -9472,
    -15104, -14592, -16128, -15616, -13056, -12544, -14080, -13568,
    -344, -328, -376, -360, -280, -264, -312, -296,
    -472, -456, -504, -488, -408, -392, -440, -424,
    -88, -72, -120, -104, -24, -8, -56, -40,
    -216, -200, -248, -232, -152, -136, -184, -168,
    -1376, -1312, -1504, -1440, -1120, -1056, -1248, -1184,
    -1888, -1824, -2016, -1952, -1632, -1568, -1760, -1696,
    -688, -656, -752, -720, -560, -528, -624, -592,
    -944, -912, -1008, -976, -816, -784, -880, -848,
    5504, 5248, 6016, 5760, 4480, 4224, 4992, 4736,
    7552, 7296, 8064, 7808, 6528, 6272, 7040, 6784,
    2752, 2624, 3008, 2880, 2240, 2112, 2496, 2368,
    3776, 3648, 4032, 3904, 3264, 3136, 3520, 3392,
    22016, 20992, 24064, 23040, 17920, 16896, 19968, 18944,
    30208, 29184, 32256, 31232, 26112, 25088, 28160, 27136,
    11008, 10496, 12032, 11520, 8960, 8448, 9984, 9472,
    15104, 14592, 16128, 15616, 13056, 12544, 14080, 13568,
    344, 328, 376, 360, 280, 264, 312, 296,
    472, 456, 504, 488, 408, 392, 440, 424,
    88, 72, 120, 104, 24, 8, 56, 40,
    216, 200, 248, 232, 152, 136, 184, 168,
    1376, 1312, 1504, 1440, 1120, 1056, 1248, 1184,
    1888, 1824, 2016, 1952, 1632, 1568, 1760, 1696,
    688, 656, 752, 720, 560, 528, 624, 592,
    944, 912, 1008, 976, 816, 784, 880, 848
};

/// Decode G.711 A-law data to 16-bit PCM
/// @param alaw Input A-law encoded bytes
/// @param pcm Output 16-bit PCM samples
/// @param count Number of samples to decode
static void decode_alaw(const uint8_t *alaw, int16_t *pcm, size_t count) {
    for (size_t i = 0; i < count; i++) {
        pcm[i] = alaw_to_linear[alaw[i]];
    }
}

#pragma mark - Voice Frame Structure

/// Structure matching the SDK's app_source_frame header
/// Based on ivar inspection: {app_source_frame="head"{...}"data"^v"size"Q...}
typedef struct {
    uint32_t start_code;
    int8_t type;
    int8_t streamid;
    uint16_t militime;
    uint32_t timestamp;
    uint32_t frameno;
    uint32_t len;
    uint8_t version;
    uint8_t resolution;
    uint8_t sessid;
    uint8_t currsit;
    uint8_t endflag;
    int8_t byzone;
    uint8_t channel;
    int8_t type1;
    int16_t sample;
    int16_t index;
} app_frame_header;

typedef struct {
    app_frame_header head;
    void *data;
    uint64_t size;
    int32_t use_flag;
    uint64_t offset;
    // ... more fields we don't need
} app_source_frame;

/// Buffer for decoded PCM samples
static int16_t *g711DecodeBuffer = NULL;
static size_t g711DecodeBufferSize = 0;

/// Last processed frame number to avoid duplicates
static uint32_t lastProcessedFrameNo = 0;

/// Timer for polling voice frames
static dispatch_source_t voiceFrameTimer = NULL;

#pragma mark - Render Notify Callback

/// Temporary buffer for format conversion (Float32 stereo → Int16 mono)
static int16_t *conversionBuffer = NULL;
static uint32_t conversionBufferSize = 0;

/// C callback for AudioUnitAddRenderNotify
static OSStatus RenderNotifyCallback(
    void *inRefCon,
    AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData
) {
    // We only care about post-render (when data is available)
    if (!(*ioActionFlags & kAudioUnitRenderAction_PostRender)) {
        return noErr;
    }

    // Get our bridge instance
    AudioHookBridge *bridge = (__bridge AudioHookBridge *)inRefCon;

    // Need valid data
    if (ioData == NULL || ioData->mNumberBuffers == 0) {
        return noErr;
    }

    // Get the audio data
    AudioBuffer *buffer = &ioData->mBuffers[0];
    if (buffer->mData == NULL || buffer->mDataByteSize == 0) {
        return noErr;
    }

    // Detect format based on buffer info
    // SDK typically outputs Float32 stereo (2 channels, 32 bits per channel)
    uint32_t channels = buffer->mNumberChannels;
    if (channels == 0) channels = 2;  // Default to stereo if not set

    // Calculate frame count (inNumberFrames is the authoritative count)
    uint32_t frameCount = inNumberFrames;

    // Log format detection once
    static BOOL formatLogged = NO;
    if (!formatLogged) {
        formatLogged = YES;
        NSLog(@"[AudioHookBridge] 📊 Audio buffer format:");
        NSLog(@"[AudioHookBridge]    Channels: %u", channels);
        NSLog(@"[AudioHookBridge]    Frames: %u", frameCount);
        NSLog(@"[AudioHookBridge]    Byte size: %u", buffer->mDataByteSize);
        NSLog(@"[AudioHookBridge]    Bytes per frame: %u", frameCount > 0 ? buffer->mDataByteSize / frameCount : 0);
    }

    // Check if data is actually non-zero (not silence)
    static int sampleCheckCount = 0;
    if (sampleCheckCount < 5) {
        sampleCheckCount++;
        float *floatCheck = (float *)buffer->mData;
        float minVal = floatCheck[0], maxVal = floatCheck[0], sumAbs = 0;
        for (uint32_t i = 0; i < frameCount && i < 480; i++) {
            float val = floatCheck[i];
            if (val < minVal) minVal = val;
            if (val > maxVal) maxVal = val;
            sumAbs += fabsf(val);
        }
        float avgAbs = sumAbs / (frameCount > 0 ? frameCount : 1);
        NSLog(@"[AudioHookBridge] 📈 Sample values check #%d:", sampleCheckCount);
        NSLog(@"[AudioHookBridge]    Min: %.6f, Max: %.6f, AvgAbs: %.6f", minVal, maxVal, avgAbs);

        // RAW DATA DUMP - Show first 32 bytes as hex and first 8 float values
        NSLog(@"[AudioHookBridge] 🔬 RAW DATA DUMP (first 32 bytes as hex):");
        uint8_t *rawBytes = (uint8_t *)buffer->mData;
        NSMutableString *hexStr = [NSMutableString string];
        for (int i = 0; i < 32 && i < buffer->mDataByteSize; i++) {
            [hexStr appendFormat:@"%02X ", rawBytes[i]];
            if ((i + 1) % 16 == 0) [hexStr appendString:@"\n                                      "];
        }
        NSLog(@"[AudioHookBridge]    Hex: %@", hexStr);

        NSLog(@"[AudioHookBridge] 🔬 First 8 Float32 values:");
        for (int i = 0; i < 8 && i < frameCount; i++) {
            NSLog(@"[AudioHookBridge]    [%d] = %.10f (hex: 0x%08X)", i, floatCheck[i], *(uint32_t*)&floatCheck[i]);
        }

        if (avgAbs < 0.0001f) {
            NSLog(@"[AudioHookBridge] ⚠️ WARNING: Data appears to be SILENCE (avgAbs < 0.0001)");
            NSLog(@"[AudioHookBridge] ════════════════════════════════════════════════════════════");
            NSLog(@"[AudioHookBridge] 🛑 DIAGNOSIS: SDK's AudioUnit render buffer is EMPTY!");
            NSLog(@"[AudioHookBridge]    The SDK failed with error -50 when configuring its AudioUnit.");
            NSLog(@"[AudioHookBridge]    Because of this failure, the SDK never connects its audio");
            NSLog(@"[AudioHookBridge]    decoder output to this render buffer.");
            NSLog(@"[AudioHookBridge]    We are capturing from the WRONG place in the audio pipeline.");
            NSLog(@"[AudioHookBridge]    The decoded audio exists somewhere BEFORE this render callback.");
            NSLog(@"[AudioHookBridge] ════════════════════════════════════════════════════════════");
        } else {
            NSLog(@"[AudioHookBridge] ✅ Data contains real audio (avgAbs = %.6f)", avgAbs);
        }
    }

    // Determine if data is Float32 or Int16
    // Float32 stereo: bytesPerFrame = 4 * 2 = 8
    // Int16 stereo: bytesPerFrame = 2 * 2 = 4
    // Int16 mono: bytesPerFrame = 2
    uint32_t bytesPerFrame = frameCount > 0 ? buffer->mDataByteSize / frameCount : 0;
    BOOL isFloat32 = (bytesPerFrame >= 4 * channels);  // 4 bytes per Float32 sample per channel

    int16_t *outputSamples = NULL;
    uint32_t outputSampleCount = 0;

    if (isFloat32) {
        // Convert Float32 to Int16 mono
        // Ensure conversion buffer is large enough
        if (conversionBuffer == NULL || conversionBufferSize < frameCount) {
            if (conversionBuffer) free(conversionBuffer);
            conversionBufferSize = frameCount * 2;  // Extra room
            conversionBuffer = (int16_t *)malloc(conversionBufferSize * sizeof(int16_t));
        }

        float *floatData = (float *)buffer->mData;

        for (uint32_t i = 0; i < frameCount; i++) {
            float sample;
            if (channels >= 2) {
                // Stereo: average left and right channels
                float left = floatData[i * channels];
                float right = floatData[i * channels + 1];
                sample = (left + right) * 0.5f;
            } else {
                // Mono
                sample = floatData[i];
            }

            // Clamp and convert to Int16
            if (sample > 1.0f) sample = 1.0f;
            if (sample < -1.0f) sample = -1.0f;
            conversionBuffer[i] = (int16_t)(sample * 32767.0f);
        }

        outputSamples = conversionBuffer;
        outputSampleCount = frameCount;

        static BOOL conversionLogged = NO;
        if (!conversionLogged) {
            conversionLogged = YES;
            NSLog(@"[AudioHookBridge] 🔄 Converting Float32 %s → Int16 mono (%u frames)",
                  channels >= 2 ? "stereo" : "mono", frameCount);
        }
    } else {
        // Assume Int16 format
        int16_t *int16Data = (int16_t *)buffer->mData;

        if (channels >= 2) {
            // Stereo Int16: convert to mono
            if (conversionBuffer == NULL || conversionBufferSize < frameCount) {
                if (conversionBuffer) free(conversionBuffer);
                conversionBufferSize = frameCount * 2;
                conversionBuffer = (int16_t *)malloc(conversionBufferSize * sizeof(int16_t));
            }

            for (uint32_t i = 0; i < frameCount; i++) {
                int32_t left = int16Data[i * 2];
                int32_t right = int16Data[i * 2 + 1];
                conversionBuffer[i] = (int16_t)((left + right) / 2);
            }

            outputSamples = conversionBuffer;
            outputSampleCount = frameCount;
        } else {
            // Already Int16 mono - use directly
            outputSamples = int16Data;
            outputSampleCount = frameCount;
        }
    }

    // Update statistics via method
    [bridge incrementCapturedFrameCount:outputSampleCount];

    // Call the capture callback if set
    static BOOL callbackLogged = NO;
    if (bridge.captureCallback && outputSamples) {
        if (!callbackLogged) {
            NSLog(@"[AudioHookBridge] 📤 Calling Swift captureCallback with %u samples (converted)", outputSampleCount);
            callbackLogged = YES;
        }
        bridge.captureCallback(outputSamples, outputSampleCount);
    } else {
        static BOOL noCallbackLogged = NO;
        if (!noCallbackLogged) {
            NSLog(@"[AudioHookBridge] ⚠️ captureCallback is NULL or no samples - audio not forwarded!");
            noCallbackLogged = YES;
        }
    }

    // Limited logging
    static int logCount = 0;
    if (logCount < 20) {
        logCount++;
        NSLog(@"[AudioHookBridge] 🎤 Captured %u frames → %u Int16 mono samples (callback: %@)",
              frameCount, outputSampleCount, bridge.captureCallback ? @"SET" : @"NULL");
    } else if (logCount == 20) {
        logCount++;
        NSLog(@"[AudioHookBridge] 🔇 Silencing further capture logs...");
    }

    return noErr;
}

#pragma mark - AudioHookBridge Implementation

@implementation AudioHookBridge {
    BOOL _isHooked;
    AudioUnit _interceptedUnit;
    BOOL _renderNotifyInstalled;
}

@synthesize capturedFrameCount = _capturedFrameCount;

#pragma mark - Singleton

+ (AudioHookBridge *)shared {
    static AudioHookBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AudioHookBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isHooked = NO;
        _interceptedUnit = NULL;
        _capturedFrameCount = 0;
        _renderNotifyInstalled = NO;
        NSLog(@"[AudioHookBridge] Initialized");
    }
    return self;
}

#pragma mark - Properties

- (BOOL)isHooked {
    return _isHooked;
}

- (AudioUnit)interceptedUnit {
    return _interceptedUnit;
}

#pragma mark - Discovery

- (NSArray<NSString *> *)discoverSDKClasses {
    NSMutableArray<NSString *> *results = [NSMutableArray array];

    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 🔍 Discovering SDK Classes");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    // Check for AppIOSPlayer class
    Class playerClass = NSClassFromString(@"AppIOSPlayer");
    if (playerClass) {
        [results addObject:@"✅ AppIOSPlayer class found"];
        NSLog(@"[AudioHookBridge] ✅ AppIOSPlayer class exists");

        // List instance variables
        unsigned int ivarCount = 0;
        Ivar *ivars = class_copyIvarList(playerClass, &ivarCount);

        NSLog(@"[AudioHookBridge] Instance variables (%u):", ivarCount);
        for (unsigned int i = 0; i < ivarCount && i < 20; i++) {
            const char *name = ivar_getName(ivars[i]);
            const char *type = ivar_getTypeEncoding(ivars[i]);
            NSLog(@"[AudioHookBridge]   %s : %s", name, type);

            // Check for audio-related ivars
            if (strstr(name, "audio") != NULL || strstr(name, "voice") != NULL) {
                [results addObject:[NSString stringWithFormat:@"  Found ivar: %s", name]];
            }
        }
        free(ivars);

        // List methods
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(playerClass, &methodCount);

        NSLog(@"[AudioHookBridge] Methods (showing audio-related):");
        for (unsigned int i = 0; i < methodCount; i++) {
            SEL selector = method_getName(methods[i]);
            const char *name = sel_getName(selector);

            // Only show audio-related methods
            if (strstr(name, "audio") != NULL ||
                strstr(name, "Audio") != NULL ||
                strstr(name, "voice") != NULL ||
                strstr(name, "Voice") != NULL ||
                strstr(name, "sound") != NULL ||
                strstr(name, "mute") != NULL) {
                NSLog(@"[AudioHookBridge]   %s", name);
                [results addObject:[NSString stringWithFormat:@"  Method: %s", name]];
            }
        }
        free(methods);

    } else {
        [results addObject:@"❌ AppIOSPlayer class NOT found"];
        NSLog(@"[AudioHookBridge] ❌ AppIOSPlayer class NOT found");
    }

    // Check for other SDK classes
    NSArray *otherClasses = @[@"CameraPlayer", @"AudioPlayer", @"VoicePlayer"];
    for (NSString *className in otherClasses) {
        Class cls = NSClassFromString(className);
        if (cls) {
            [results addObject:[NSString stringWithFormat:@"✅ %@ found", className]];
            NSLog(@"[AudioHookBridge] ✅ %@ class exists", className);
        }
    }

    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    return results;
}

- (BOOL)findSDKAudioUnit {
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 🔍 Searching for SDK's AudioUnit");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    Class playerClass = NSClassFromString(@"AppIOSPlayer");
    if (!playerClass) {
        NSLog(@"[AudioHookBridge] ❌ AppIOSPlayer class not found");
        return NO;
    }

    // Get the audioUnit ivar
    Ivar audioUnitIvar = class_getInstanceVariable(playerClass, "audioUnit");
    if (!audioUnitIvar) {
        NSLog(@"[AudioHookBridge] ❌ audioUnit ivar not found");
        return NO;
    }

    NSLog(@"[AudioHookBridge] ✅ audioUnit ivar found");
    NSLog(@"[AudioHookBridge]   Type: %s", ivar_getTypeEncoding(audioUnitIvar));

    // To get the actual AudioUnit value, we need an instance of AppIOSPlayer
    // This is the tricky part - we need to find where the SDK stores its instance

    // One approach: Hook into a method that uses audioUnit and capture it there
    // Another approach: Search for the instance in known locations

    // For now, we'll set up the infrastructure for when we have the instance
    NSLog(@"[AudioHookBridge] ⚠️ Need AppIOSPlayer instance to access audioUnit value");
    NSLog(@"[AudioHookBridge] ⚠️ Will install method swizzling to capture it");

    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    return NO;  // We found the class but don't have the instance yet
}

#pragma mark - Swizzling

/// Store original method implementations
static IMP originalStartVoice = NULL;
static IMP originalStopVoice = NULL;
static IMP originalCreateAudioUnit = NULL;

/// Store the AppIOSPlayer instance for delayed AudioUnit capture
static __weak id capturedPlayerInstance = nil;

/// Helper to capture AudioUnit from player instance
static void captureAudioUnitFromPlayer(id playerInstance) {
    if (!playerInstance) return;

    AudioHookBridge *bridge = [AudioHookBridge shared];

    Ivar audioUnitIvar = class_getInstanceVariable([playerInstance class], "audioUnit");
    if (audioUnitIvar) {
        void *ivarPtr = (void *)((char *)(__bridge void *)playerInstance + ivar_getOffset(audioUnitIvar));
        AudioUnit *unitPtr = (AudioUnit *)ivarPtr;
        AudioUnit unit = *unitPtr;

        if (unit != NULL && unit != bridge.interceptedUnit) {
            NSLog(@"[AudioHookBridge] ✅ Got AudioUnit: %p", unit);
            [bridge installRenderNotifyOnUnit:unit];
        } else if (unit == NULL) {
            NSLog(@"[AudioHookBridge] ⚠️ AudioUnit is still NULL");
        }
    }
}

/// Our replacement method for createAudioUnitWithOutput:input:
/// This is called when the SDK actually creates its AudioUnit
static void swizzled_createAudioUnit(id self, SEL _cmd, BOOL output, BOOL input) {
    NSLog(@"[AudioHookBridge] 🎯 INTERCEPTED: createAudioUnitWithOutput:%d input:%d", output, input);

    // Call original implementation first - this creates the AudioUnit
    if (originalCreateAudioUnit) {
        ((void (*)(id, SEL, BOOL, BOOL))originalCreateAudioUnit)(self, _cmd, output, input);
    }

    // Now the AudioUnit should exist - capture it!
    NSLog(@"[AudioHookBridge] 🔍 Checking for AudioUnit after creation...");
    captureAudioUnitFromPlayer(self);
}

/// Our replacement method for startVoice
static void swizzled_startVoice(id self, SEL _cmd) {
    NSLog(@"[AudioHookBridge] 🎯 INTERCEPTED: startVoice called!");

    // Store the player instance for later
    capturedPlayerInstance = self;

    // Call original implementation
    if (originalStartVoice) {
        ((void (*)(id, SEL))originalStartVoice)(self, _cmd);
    }

    // Try to get audioUnit immediately (might be NULL)
    captureAudioUnitFromPlayer(self);

    // Schedule delayed checks in case AudioUnit is created asynchronously
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[AudioHookBridge] 🔍 Delayed check (100ms)...");
        captureAudioUnitFromPlayer(capturedPlayerInstance);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[AudioHookBridge] 🔍 Delayed check (500ms)...");
        captureAudioUnitFromPlayer(capturedPlayerInstance);
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[AudioHookBridge] 🔍 Delayed check (1000ms)...");
        captureAudioUnitFromPlayer(capturedPlayerInstance);
    });
}

- (BOOL)installSwizzling {
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 🔀 Installing Method Swizzling");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    Class playerClass = NSClassFromString(@"AppIOSPlayer");
    if (!playerClass) {
        NSLog(@"[AudioHookBridge] ❌ AppIOSPlayer class not found");
        return NO;
    }

    BOOL swizzledStartVoice = NO;
    BOOL swizzledCreateAudioUnit = NO;

    // 1. Swizzle startVoice (to know when audio starts)
    NSArray *startMethodsToTry = @[
        @"startVoice",
        @"startAudio",
        @"enableVoice",
        @"startSound",
        @"playVoice"
    ];

    for (NSString *methodName in startMethodsToTry) {
        SEL selector = NSSelectorFromString(methodName);
        Method method = class_getInstanceMethod(playerClass, selector);

        if (method) {
            NSLog(@"[AudioHookBridge] ✅ Found start method: %@", methodName);
            originalStartVoice = method_getImplementation(method);
            method_setImplementation(method, (IMP)swizzled_startVoice);
            NSLog(@"[AudioHookBridge] 🔀 Swizzled: %@", methodName);
            swizzledStartVoice = YES;
            break;
        }
    }

    // 2. Swizzle createAudioUnitWithOutput:input: (to capture when AudioUnit is created)
    SEL createSelector = NSSelectorFromString(@"createAudioUnitWithOutput:input:");
    Method createMethod = class_getInstanceMethod(playerClass, createSelector);

    if (createMethod) {
        NSLog(@"[AudioHookBridge] ✅ Found createAudioUnitWithOutput:input:");
        originalCreateAudioUnit = method_getImplementation(createMethod);
        method_setImplementation(createMethod, (IMP)swizzled_createAudioUnit);
        NSLog(@"[AudioHookBridge] 🔀 Swizzled: createAudioUnitWithOutput:input:");
        swizzledCreateAudioUnit = YES;
    } else {
        NSLog(@"[AudioHookBridge] ⚠️ createAudioUnitWithOutput:input: not found");
    }

    if (!swizzledStartVoice && !swizzledCreateAudioUnit) {
        NSLog(@"[AudioHookBridge] ❌ No swizzleable methods found");
        NSLog(@"[AudioHookBridge] Available methods in AppIOSPlayer:");

        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(playerClass, &methodCount);
        for (unsigned int i = 0; i < methodCount && i < 30; i++) {
            NSLog(@"[AudioHookBridge]   %s", sel_getName(method_getName(methods[i])));
        }
        free(methods);

        return NO;
    }

    _isHooked = YES;
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] Summary: startVoice=%@, createAudioUnit=%@",
          swizzledStartVoice ? @"YES" : @"NO",
          swizzledCreateAudioUnit ? @"YES" : @"NO");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    return YES;
}

- (void)removeSwizzling {
    if (!_isHooked) return;

    NSLog(@"[AudioHookBridge] 🔙 Removing swizzling...");

    Class playerClass = NSClassFromString(@"AppIOSPlayer");
    if (!playerClass) return;

    // Restore original implementations
    if (originalStartVoice) {
        SEL selector = NSSelectorFromString(@"startVoice");
        Method method = class_getInstanceMethod(playerClass, selector);
        if (method) {
            method_setImplementation(method, originalStartVoice);
        }
        originalStartVoice = NULL;
    }

    _isHooked = NO;
    NSLog(@"[AudioHookBridge] ✅ Swizzling removed");
}

#pragma mark - Render Notify

- (BOOL)installRenderNotifyOnUnit:(AudioUnit)unit {
    if (unit == NULL) {
        NSLog(@"[AudioHookBridge] ❌ Cannot install render notify on NULL unit");
        return NO;
    }

    // Remove existing notify if any
    [self removeRenderNotify];

    _interceptedUnit = unit;

    // Log the format
    AudioStreamBasicDescription streamFormat;
    UInt32 propertySize = sizeof(streamFormat);

    OSStatus status = AudioUnitGetProperty(
        unit,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Output,
        1,  // Element 1 = input side of RemoteIO
        &streamFormat,
        &propertySize
    );

    if (status == noErr) {
        NSLog(@"[AudioHookBridge] AudioUnit format:");
        NSLog(@"[AudioHookBridge]   Sample rate: %.0f Hz", streamFormat.mSampleRate);
        NSLog(@"[AudioHookBridge]   Channels: %u", streamFormat.mChannelsPerFrame);
        NSLog(@"[AudioHookBridge]   Bits/channel: %u", streamFormat.mBitsPerChannel);
    }

    // Install render notify
    status = AudioUnitAddRenderNotify(
        unit,
        RenderNotifyCallback,
        (__bridge void *)self
    );

    if (status == noErr) {
        _renderNotifyInstalled = YES;
        _capturedFrameCount = 0;
        NSLog(@"[AudioHookBridge] ✅ Render notify installed on unit %p", unit);
        return YES;
    } else {
        NSLog(@"[AudioHookBridge] ❌ Failed to install render notify: %d", (int)status);
        return NO;
    }
}

- (void)removeRenderNotify {
    if (!_renderNotifyInstalled || _interceptedUnit == NULL) {
        return;
    }

    AudioUnitRemoveRenderNotify(
        _interceptedUnit,
        RenderNotifyCallback,
        (__bridge void *)self
    );

    NSLog(@"[AudioHookBridge] ✅ Render notify removed");
    NSLog(@"[AudioHookBridge] Total captured: %llu frames", _capturedFrameCount);

    _renderNotifyInstalled = NO;
    _interceptedUnit = NULL;
}

#pragma mark - Testing

- (BOOL)runSelfTest {
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 🧪 Running Self-Test");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    // Test 1: Can we find AppIOSPlayer?
    Class playerClass = NSClassFromString(@"AppIOSPlayer");
    BOOL test1 = playerClass != nil;
    NSLog(@"[AudioHookBridge] Test 1 - AppIOSPlayer exists: %@", test1 ? @"PASS" : @"FAIL");

    // Test 2: Can we find the audioUnit ivar?
    BOOL test2 = NO;
    if (playerClass) {
        Ivar ivar = class_getInstanceVariable(playerClass, "audioUnit");
        test2 = ivar != nil;
    }
    NSLog(@"[AudioHookBridge] Test 2 - audioUnit ivar exists: %@", test2 ? @"PASS" : @"FAIL");

    // Test 3: Can we create our own RemoteIO?
    BOOL test3 = NO;
    AudioComponentDescription desc = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = kAudioUnitSubType_RemoteIO,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };

    AudioComponent component = AudioComponentFindNext(NULL, &desc);
    if (component) {
        AudioUnit testUnit = NULL;
        OSStatus status = AudioComponentInstanceNew(component, &testUnit);
        if (status == noErr && testUnit != NULL) {
            test3 = YES;
            AudioComponentInstanceDispose(testUnit);
        }
    }
    NSLog(@"[AudioHookBridge] Test 3 - RemoteIO creation: %@", test3 ? @"PASS" : @"FAIL");

    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] Result: %d/3 tests passed", (test1 ? 1 : 0) + (test2 ? 1 : 0) + (test3 ? 1 : 0));
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    return test1 && test2 && test3;
}

- (NSString *)statisticsDescription {
    return [NSString stringWithFormat:
        @"AudioHookBridge Statistics:\n"
        @"  Hooked: %@\n"
        @"  Render notify: %@\n"
        @"  Intercepted unit: %p\n"
        @"  Captured frames: %llu",
        _isHooked ? @"YES" : @"NO",
        _renderNotifyInstalled ? @"YES" : @"NO",
        _interceptedUnit,
        _capturedFrameCount
    ];
}

- (void)incrementCapturedFrameCount:(uint32_t)count {
    _capturedFrameCount += count;
}

#pragma mark - Voice Frame Direct Capture (G.711a Bypass)

/// Start polling voice_frame from the SDK player
- (void)startVoiceFrameCapture {
    if (voiceFrameTimer != NULL) {
        NSLog(@"[AudioHookBridge] Voice frame capture already running");
        return;
    }

    if (capturedPlayerInstance == nil) {
        NSLog(@"[AudioHookBridge] ❌ No player instance captured - call startVoice first");
        return;
    }

    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 🎙️ Starting Voice Frame Direct Capture");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] This bypasses the broken AudioUnit render callback");
    NSLog(@"[AudioHookBridge] Reading directly from SDK's voice_frame ivar");

    // Get the voice_frame ivar
    Class playerClass = object_getClass(capturedPlayerInstance);
    Ivar voiceFrameIvar = class_getInstanceVariable(playerClass, "voice_frame");

    if (!voiceFrameIvar) {
        NSLog(@"[AudioHookBridge] ❌ voice_frame ivar not found!");
        return;
    }

    NSLog(@"[AudioHookBridge] ✅ Found voice_frame ivar at offset %td", ivar_getOffset(voiceFrameIvar));

    // Create a high-frequency timer to poll for voice frames
    // Audio at 16kHz with 480 sample frames = ~33ms per frame
    // Poll at 10ms to catch every frame
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    voiceFrameTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);

    dispatch_source_set_timer(voiceFrameTimer,
                              dispatch_time(DISPATCH_TIME_NOW, 0),
                              10 * NSEC_PER_MSEC,  // 10ms interval
                              1 * NSEC_PER_MSEC);  // 1ms leeway

    __weak AudioHookBridge *weakSelf = self;

    dispatch_source_set_event_handler(voiceFrameTimer, ^{
        [weakSelf pollVoiceFrame:voiceFrameIvar];
    });

    dispatch_resume(voiceFrameTimer);
    NSLog(@"[AudioHookBridge] ✅ Voice frame polling started (10ms interval)");
}

/// Poll voice_frame AND upstream buffers for audio data
- (void)pollVoiceFrame:(Ivar)voiceFrameIvar {
    if (capturedPlayerInstance == nil) return;

    // Get pointer to the voice_frame struct inside the player instance
    // The ivar is embedded in the object, not a pointer to external memory
    ptrdiff_t offset = ivar_getOffset(voiceFrameIvar);
    void *playerPtr = (__bridge void *)capturedPlayerInstance;
    app_source_frame *frame = (app_source_frame *)((uint8_t *)playerPtr + offset);

    // Debug: Log voice_frame state periodically
    static int pollCount = 0;
    pollCount++;

    // Also check upstream buffers - these might have data even when voice_frame is empty!
    // The SDK might be receiving and decoding audio but dropping it because startVoice() failed
    if (pollCount <= 30 || pollCount % 100 == 0) {
        [self checkUpstreamBuffers:pollCount];
    }

    if (pollCount <= 20 || pollCount % 100 == 0) {
        NSLog(@"[AudioHookBridge] 🔍 Poll #%d: frameno=%u, data=%p, size=%llu, use_flag=%d",
              pollCount, frame->head.frameno, frame->data, frame->size, frame->use_flag);
    }

    // Check if we have new data
    if (frame->head.frameno == lastProcessedFrameNo) {
        return;  // Same frame, skip
    }

    // Check if frame has data
    if (frame->data == NULL || frame->size == 0) {
        static int noDataLogCount = 0;
        if (noDataLogCount < 5) {
            noDataLogCount++;
            NSLog(@"[AudioHookBridge] ⚠️ Frame #%u has no data (data=%p, size=%llu)",
                  frame->head.frameno, frame->data, frame->size);
        }
        return;  // No data yet
    }

    uint32_t frameNo = frame->head.frameno;
    uint64_t dataSize = frame->size;
    void *rawData = frame->data;

    // Log first few frames for debugging
    static int frameLogCount = 0;
    if (frameLogCount < 10) {
        frameLogCount++;
        NSLog(@"[AudioHookBridge] 🎙️ Voice frame #%u:", frameNo);
        NSLog(@"[AudioHookBridge]    Size: %llu bytes", dataSize);
        NSLog(@"[AudioHookBridge]    Type: %d, StreamID: %d", frame->head.type, frame->head.streamid);
        NSLog(@"[AudioHookBridge]    Timestamp: %u, Len: %u", frame->head.timestamp, frame->head.len);

        // Dump first 16 bytes of raw data
        if (rawData && dataSize >= 16) {
            uint8_t *bytes = (uint8_t *)rawData;
            NSLog(@"[AudioHookBridge]    Raw data (first 16 bytes): %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X",
                  bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                  bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]);
        }
    }

    lastProcessedFrameNo = frameNo;

    // Decode G.711a to PCM
    size_t sampleCount = dataSize;  // G.711: 1 byte = 1 sample

    // Ensure decode buffer is large enough
    if (g711DecodeBuffer == NULL || g711DecodeBufferSize < sampleCount) {
        if (g711DecodeBuffer) free(g711DecodeBuffer);
        g711DecodeBufferSize = sampleCount * 2;  // Extra room
        g711DecodeBuffer = (int16_t *)malloc(g711DecodeBufferSize * sizeof(int16_t));
    }

    // Decode!
    decode_alaw((const uint8_t *)rawData, g711DecodeBuffer, sampleCount);

    // Log decoded sample values for first few frames
    if (frameLogCount <= 10) {
        float minVal = g711DecodeBuffer[0], maxVal = g711DecodeBuffer[0], sumAbs = 0;
        for (size_t i = 0; i < sampleCount && i < 480; i++) {
            float val = g711DecodeBuffer[i];
            if (val < minVal) minVal = val;
            if (val > maxVal) maxVal = val;
            sumAbs += fabsf(val);
        }
        float avgAbs = sumAbs / (sampleCount > 0 ? sampleCount : 1);
        NSLog(@"[AudioHookBridge]    Decoded PCM: min=%.0f, max=%.0f, avgAbs=%.1f", minVal, maxVal, avgAbs);

        if (avgAbs > 100) {
            NSLog(@"[AudioHookBridge] ✅ REAL AUDIO DETECTED! avgAbs=%.1f", avgAbs);
        } else {
            NSLog(@"[AudioHookBridge] ⚠️ Decoded values are low - might be silence or wrong format");
        }
    }

    // Send to capture callback
    if (self.captureCallback) {
        self.captureCallback(g711DecodeBuffer, (uint32_t)sampleCount);
        _capturedFrameCount += sampleCount;

        static int callbackLogCount = 0;
        if (callbackLogCount < 5) {
            callbackLogCount++;
            NSLog(@"[AudioHookBridge] 📤 Sent %zu G.711a decoded samples to callback", sampleCount);
        }
    }
}

/// Check upstream buffers for audio data
/// These buffers exist BEFORE voice_frame in the pipeline and might have data
/// even when voice_frame is empty (if startVoice() failed)
- (void)checkUpstreamBuffers:(int)pollCount {
    if (capturedPlayerInstance == nil) return;

    Class playerClass = object_getClass(capturedPlayerInstance);
    void *playerPtr = (__bridge void *)capturedPlayerInstance;

    // Buffer names found via nm analysis of libVSTC.a:
    // voice_in_buff / voice_in_data - raw G.711a from network
    // voice_out_buff / voice_out_data - decoded PCM ready for playback
    NSArray *bufferIvarNames = @[
        @"voice_in_buff", @"voice_in_data",
        @"voice_out_buff", @"voice_out_data",
        @"audioBuffer", @"voiceBuffer", @"pcmBuffer",
        @"inBuffer", @"outBuffer"
    ];

    static BOOL foundAnyBuffer = NO;
    static NSMutableSet *checkedIvars = nil;
    if (checkedIvars == nil) {
        checkedIvars = [NSMutableSet set];
    }

    for (NSString *ivarName in bufferIvarNames) {
        // Only log each ivar check once
        if ([checkedIvars containsObject:ivarName]) continue;

        Ivar ivar = class_getInstanceVariable(playerClass, [ivarName UTF8String]);
        if (!ivar) {
            if (pollCount == 1) {
                NSLog(@"[AudioHookBridge] ⚠️ Upstream ivar '%@' not found", ivarName);
            }
            [checkedIvars addObject:ivarName];
            continue;
        }

        // Found an ivar - let's see what's in it
        ptrdiff_t offset = ivar_getOffset(ivar);
        const char *typeEncoding = ivar_getTypeEncoding(ivar);

        NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
        NSLog(@"[AudioHookBridge] 🔬 UPSTREAM BUFFER FOUND: %@", ivarName);
        NSLog(@"[AudioHookBridge]    Offset: %td, Type: %s", offset, typeEncoding);

        // Try to interpret based on type
        void *ivarPtr = (uint8_t *)playerPtr + offset;

        // Check if it's a pointer type (^v, ^c, etc.)
        if (typeEncoding && typeEncoding[0] == '^') {
            void **ptrValue = (void **)ivarPtr;
            void *actualPtr = *ptrValue;

            if (actualPtr != NULL) {
                NSLog(@"[AudioHookBridge]    Pointer value: %p", actualPtr);
                foundAnyBuffer = YES;

                // Try to dump first 32 bytes if the pointer looks valid
                // (This is risky - could crash if pointer is invalid)
                @try {
                    uint8_t *bytes = (uint8_t *)actualPtr;
                    NSMutableString *hexStr = [NSMutableString string];
                    BOOL hasNonZero = NO;
                    for (int i = 0; i < 32; i++) {
                        [hexStr appendFormat:@"%02X ", bytes[i]];
                        if (bytes[i] != 0) hasNonZero = YES;
                        if ((i + 1) % 16 == 0 && i < 31) {
                            [hexStr appendString:@"\n                                      "];
                        }
                    }
                    NSLog(@"[AudioHookBridge]    First 32 bytes: %@", hexStr);

                    if (hasNonZero) {
                        NSLog(@"[AudioHookBridge] ✅ BUFFER HAS NON-ZERO DATA!");
                    } else {
                        NSLog(@"[AudioHookBridge] ⚠️ Buffer contains all zeros");
                    }
                } @catch (NSException *e) {
                    NSLog(@"[AudioHookBridge]    ⚠️ Could not read pointer contents: %@", e.reason);
                }
            } else {
                NSLog(@"[AudioHookBridge]    Pointer is NULL");
            }
        }
        // Check if it might be an embedded struct (buffer inline)
        else if (typeEncoding && strchr(typeEncoding, '{') != NULL) {
            NSLog(@"[AudioHookBridge]    Embedded struct type - dumping first 64 bytes:");

            uint8_t *bytes = (uint8_t *)ivarPtr;
            NSMutableString *hexStr = [NSMutableString string];
            BOOL hasNonZero = NO;
            for (int i = 0; i < 64; i++) {
                [hexStr appendFormat:@"%02X ", bytes[i]];
                if (bytes[i] != 0) hasNonZero = YES;
                if ((i + 1) % 16 == 0 && i < 63) {
                    [hexStr appendString:@"\n                                      "];
                }
            }
            NSLog(@"[AudioHookBridge]    %@", hexStr);

            if (hasNonZero) {
                NSLog(@"[AudioHookBridge] ✅ STRUCT HAS NON-ZERO DATA!");
                foundAnyBuffer = YES;
            }
        }
        // For simple types (int, etc.) that might be buffer sizes
        else if (typeEncoding && (typeEncoding[0] == 'Q' || typeEncoding[0] == 'I' || typeEncoding[0] == 'i')) {
            uint64_t *intValue = (uint64_t *)ivarPtr;
            NSLog(@"[AudioHookBridge]    Integer value: %llu", *intValue);
        }

        NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
        [checkedIvars addObject:ivarName];
    }

    // On first poll, also enumerate ALL ivars that might be audio-related
    if (pollCount == 1) {
        NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
        NSLog(@"[AudioHookBridge] 🔍 Scanning ALL ivars for audio/voice/buffer patterns:");
        NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

        unsigned int ivarCount = 0;
        Ivar *ivars = class_copyIvarList(playerClass, &ivarCount);

        for (unsigned int i = 0; i < ivarCount; i++) {
            const char *name = ivar_getName(ivars[i]);
            const char *type = ivar_getTypeEncoding(ivars[i]);

            // Look for audio/voice/buffer related ivars
            if (strstr(name, "voice") != NULL ||
                strstr(name, "Voice") != NULL ||
                strstr(name, "audio") != NULL ||
                strstr(name, "Audio") != NULL ||
                strstr(name, "buff") != NULL ||
                strstr(name, "Buff") != NULL ||
                strstr(name, "pcm") != NULL ||
                strstr(name, "PCM") != NULL ||
                strstr(name, "data") != NULL) {

                NSLog(@"[AudioHookBridge]   📌 %s : %s", name, type);
            }
        }
        free(ivars);
        NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    }
}

/// Stop voice frame polling
- (void)stopVoiceFrameCapture {
    if (voiceFrameTimer != NULL) {
        dispatch_source_cancel(voiceFrameTimer);
        voiceFrameTimer = NULL;
        NSLog(@"[AudioHookBridge] ✅ Voice frame capture stopped");
    }

    if (g711DecodeBuffer) {
        free(g711DecodeBuffer);
        g711DecodeBuffer = NULL;
        g711DecodeBufferSize = 0;
    }

    lastProcessedFrameNo = 0;
}

#pragma mark - pcmp2 API (Story 10.1)

/// Resolve pcmp2_* symbols from the SDK using dlsym
- (BOOL)resolvePcmp2Symbols {
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 🔍 Story 10.1: Resolving pcmp2 Symbols");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    // Use RTLD_DEFAULT to search all loaded libraries
    g_pcmp2_init = (pcmp2_init_fn)dlsym(RTLD_DEFAULT, "pcmp2_init");
    g_pcmp2_finalize = (pcmp2_finalize_fn)dlsym(RTLD_DEFAULT, "pcmp2_finalize");
    g_pcmp2_setListener = (pcmp2_setListener_fn)dlsym(RTLD_DEFAULT, "pcmp2_setListener");
    g_pcmp2_setAudioPlayer = (pcmp2_setAudioPlayer_fn)dlsym(RTLD_DEFAULT, "pcmp2_setAudioPlayer");
    g_pcmp2_start = (pcmp2_start_fn)dlsym(RTLD_DEFAULT, "pcmp2_start");
    g_pcmp2_stop = (pcmp2_stop_fn)dlsym(RTLD_DEFAULT, "pcmp2_stop");

    NSLog(@"[PCMP2] pcmp2_init:          %p %s", g_pcmp2_init, g_pcmp2_init ? "✅" : "❌");
    NSLog(@"[PCMP2] pcmp2_finalize:      %p %s", g_pcmp2_finalize, g_pcmp2_finalize ? "✅" : "❌");
    NSLog(@"[PCMP2] pcmp2_setListener:   %p %s", g_pcmp2_setListener, g_pcmp2_setListener ? "✅" : "❌");
    NSLog(@"[PCMP2] pcmp2_setAudioPlayer:%p %s", g_pcmp2_setAudioPlayer, g_pcmp2_setAudioPlayer ? "✅" : "❌");
    NSLog(@"[PCMP2] pcmp2_start:         %p %s", g_pcmp2_start, g_pcmp2_start ? "✅" : "❌");
    NSLog(@"[PCMP2] pcmp2_stop:          %p %s", g_pcmp2_stop, g_pcmp2_stop ? "✅" : "❌");

    // Also try some alternative symbol names
    if (!g_pcmp2_init) {
        NSLog(@"[PCMP2] Trying alternative symbol names...");

        void *alt1 = dlsym(RTLD_DEFAULT, "_pcmp2_init");
        void *alt2 = dlsym(RTLD_DEFAULT, "Pcmp2_init");
        void *alt3 = dlsym(RTLD_DEFAULT, "pcmp_init");
        void *alt4 = dlsym(RTLD_DEFAULT, "pcm_player_init");

        NSLog(@"[PCMP2]   _pcmp2_init:       %p", alt1);
        NSLog(@"[PCMP2]   Pcmp2_init:        %p", alt2);
        NSLog(@"[PCMP2]   pcmp_init:         %p", alt3);
        NSLog(@"[PCMP2]   pcm_player_init:   %p", alt4);
    }

    BOOL success = (g_pcmp2_init != NULL && g_pcmp2_setListener != NULL);

    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[PCMP2] Resolution result: %s", success ? "SUCCESS ✅" : "FAILED ❌");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    return success;
}

/// Test the pcmp2 listener by initializing and registering a callback
- (void)testPcmp2Listener {
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 🧪 Story 10.1: Testing pcmp2 Listener");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    // First resolve symbols if not done
    if (g_pcmp2_init == NULL) {
        if (![self resolvePcmp2Symbols]) {
            NSLog(@"[PCMP2] ❌ Cannot test - symbols not resolved");
            return;
        }
    }

    // Try to initialize pcmp2
    if (g_pcmp2_init) {
        NSLog(@"[PCMP2] Calling pcmp2_init()...");
        g_pcmp2_instance = g_pcmp2_init();
        NSLog(@"[PCMP2] pcmp2_init returned: %p", g_pcmp2_instance);

        if (g_pcmp2_instance == NULL) {
            NSLog(@"[PCMP2] ⚠️ pcmp2_init returned NULL - trying to continue anyway");
        }
    }

    // Try to set listener with our callback
    if (g_pcmp2_setListener) {
        NSLog(@"[PCMP2] Calling pcmp2_setListener with our callback...");

        // Try signature A: (player, callback) where callback is (context, data, size)
        // We pass our bridge as the 'listener' which might be called with (context, data, size)
        g_pcmp2_setListener(g_pcmp2_instance, (void *)testPcmp2ListenerCallback);
        NSLog(@"[PCMP2] Listener set (signature A - function pointer)");

        // Note: If the SDK expects an object/delegate pattern, this won't work
        // We'd need to create an Objective-C object that conforms to some protocol
    }

    // Try to set audio player (might be required)
    if (g_pcmp2_setAudioPlayer && capturedPlayerInstance) {
        NSLog(@"[PCMP2] Calling pcmp2_setAudioPlayer with captured player instance...");
        g_pcmp2_setAudioPlayer(g_pcmp2_instance, (__bridge void *)capturedPlayerInstance);
        NSLog(@"[PCMP2] Audio player set");
    }

    // Try to start
    if (g_pcmp2_start) {
        NSLog(@"[PCMP2] Calling pcmp2_start()...");
        g_pcmp2_start(g_pcmp2_instance);
        NSLog(@"[PCMP2] pcmp2_start called");
    }

    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[PCMP2] Test setup complete - waiting for callbacks...");
    NSLog(@"[PCMP2] If successful, you'll see [PCMP2-LISTENER] messages");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
}

/// Stop pcmp2 listener test
- (void)stopPcmp2Listener {
    NSLog(@"[PCMP2] Stopping pcmp2 listener...");

    if (g_pcmp2_stop && g_pcmp2_instance) {
        g_pcmp2_stop(g_pcmp2_instance);
        NSLog(@"[PCMP2] pcmp2_stop called");
    }

    if (g_pcmp2_finalize && g_pcmp2_instance) {
        g_pcmp2_finalize(g_pcmp2_instance);
        NSLog(@"[PCMP2] pcmp2_finalize called");
    }

    g_pcmp2_instance = NULL;
    NSLog(@"[PCMP2] ✅ Listener stopped");
}

/// Investigate if AppIOSPlayer has pcmp2-related ivars
- (void)investigatePcmp2InPlayer {
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 🔍 Investigating pcmp2 in AppIOSPlayer");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    Class playerClass = NSClassFromString(@"AppIOSPlayer");
    if (!playerClass) {
        NSLog(@"[PCMP2] ❌ AppIOSPlayer class not found");
        return;
    }

    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList(playerClass, &ivarCount);

    NSLog(@"[PCMP2] Searching %u ivars for pcmp2/pcm/player/listener patterns...", ivarCount);

    for (unsigned int i = 0; i < ivarCount; i++) {
        const char *name = ivar_getName(ivars[i]);
        const char *type = ivar_getTypeEncoding(ivars[i]);

        // Look for pcm/player/listener related ivars
        if (strstr(name, "pcm") != NULL ||
            strstr(name, "pcmp") != NULL ||
            strstr(name, "PCM") != NULL ||
            strstr(name, "player") != NULL ||
            strstr(name, "Player") != NULL ||
            strstr(name, "listener") != NULL ||
            strstr(name, "Listener") != NULL ||
            strstr(name, "callback") != NULL ||
            strstr(name, "delegate") != NULL) {

            NSLog(@"[PCMP2] 📌 Found: %s : %s", name, type);

            // If we have a captured instance, try to read the value
            if (capturedPlayerInstance) {
                ptrdiff_t offset = ivar_getOffset(ivars[i]);
                void *playerPtr = (__bridge void *)capturedPlayerInstance;
                void *ivarPtr = (uint8_t *)playerPtr + offset;

                if (type && type[0] == '^') {
                    // It's a pointer
                    void **ptrValue = (void **)ivarPtr;
                    NSLog(@"[PCMP2]       Value: %p", *ptrValue);
                } else if (type && type[0] == '@') {
                    // It's an object
                    id objValue = (__bridge id)(*(void **)ivarPtr);
                    NSLog(@"[PCMP2]       Object: %@", objValue);
                }
            }
        }
    }

    free(ivars);

    // Also check methods
    NSLog(@"[PCMP2] Searching methods for pcmp2/listener patterns...");

    unsigned int methodCount;
    Method *methods = class_copyMethodList(playerClass, &methodCount);

    for (unsigned int i = 0; i < methodCount; i++) {
        SEL selector = method_getName(methods[i]);
        const char *name = sel_getName(selector);

        if (strstr(name, "pcm") != NULL ||
            strstr(name, "PCM") != NULL ||
            strstr(name, "listener") != NULL ||
            strstr(name, "Listener") != NULL ||
            strstr(name, "callback") != NULL ||
            strstr(name, "delegate") != NULL) {

            NSLog(@"[PCMP2] 📌 Method: %s", name);
        }
    }

    free(methods);

    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
}

#pragma mark - CGI Command API (Story 10.2)

/// Resolve client_write_cgi symbol from SDK
- (BOOL)resolveCgiSymbols {
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 🔍 Story 10.2: Resolving CGI Symbols");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    g_client_write_cgi = (client_write_cgi_fn)dlsym(RTLD_DEFAULT, "client_write_cgi");

    NSLog(@"[CGI] client_write_cgi: %p %s", g_client_write_cgi, g_client_write_cgi ? "✅" : "❌");

    if (!g_client_write_cgi) {
        // Try with underscore prefix
        g_client_write_cgi = (client_write_cgi_fn)dlsym(RTLD_DEFAULT, "_client_write_cgi");
        NSLog(@"[CGI] _client_write_cgi: %p %s", g_client_write_cgi, g_client_write_cgi ? "✅" : "❌");
    }

    BOOL success = (g_client_write_cgi != NULL);
    NSLog(@"[CGI] Resolution result: %s", success ? "SUCCESS ✅" : "FAILED ❌");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    return success;
}

/// Send a CGI command to the camera
/// @param cgiCommand The CGI command string (e.g., "decoder_control.cgi?command=90&")
/// @param clientPtr The P2P client pointer from connection service
/// @return Result code (positive = bytes written, negative = error)
- (int)sendCgiCommand:(NSString *)cgiCommand toClient:(void *)clientPtr {
    NSLog(@"[CGI] ─────────────────────────────────────────────");
    NSLog(@"[CGI] Sending: %@", cgiCommand);
    NSLog(@"[CGI] Client: %p", clientPtr);

    if (!g_client_write_cgi) {
        if (![self resolveCgiSymbols]) {
            NSLog(@"[CGI] ❌ client_write_cgi not resolved");
            return -1;
        }
    }

    if (!clientPtr) {
        NSLog(@"[CGI] ❌ clientPtr is NULL - not connected?");
        return -2;
    }

    const char *cgiStr = [cgiCommand UTF8String];
    int result = g_client_write_cgi(clientPtr, cgiStr);

    NSLog(@"[CGI] Result: %d %s", result, result >= 0 ? "✅" : "❌");
    NSLog(@"[CGI] ─────────────────────────────────────────────");

    return result;
}

/// Test various audio CGI commands to find the one that enables audio
/// @param clientPtr The P2P client pointer
- (void)testAudioCgiCommands:(void *)clientPtr {
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 🧪 Story 10.2: Testing Audio CGI Commands");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    if (!clientPtr) {
        NSLog(@"[CGI] ❌ No client pointer - connect to camera first!");
        return;
    }

    // Common Vstarcam audio CGI commands to try
    NSArray *commands = @[
        @"get_status.cgi",                    // Basic status check
        @"decoder_control.cgi?command=90&",   // Audio ON (some models)
        @"decoder_control.cgi?command=91&",   // Audio OFF (some models)
        @"audiostream.cgi?streamid=0&",       // Enable audio stream 0
        @"set_audio.cgi?enable=1",            // Enable audio
        @"audio.cgi?action=start",            // Start audio
        @"get_audio_status.cgi",              // Query audio status
        @"decoder_control.cgi?command=25&onestep=1&",  // PTZ command (might trigger audio)
    ];

    for (NSString *cmd in commands) {
        NSLog(@"[CGI-TEST] ══════════════════════════════════════════");
        NSLog(@"[CGI-TEST] Trying: %@", cmd);

        int result = [self sendCgiCommand:cmd toClient:clientPtr];
        NSLog(@"[CGI-TEST] Result: %d", result);

        // Small delay between commands
        [NSThread sleepForTimeInterval:0.3];
    }

    NSLog(@"[CGI-TEST] ══════════════════════════════════════════");
    NSLog(@"[CGI-TEST] All commands sent - check buffer monitor for results");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
}

/// Start monitoring voice_out_buff for incoming audio data
/// This detects when the camera starts sending audio after a CGI command
- (void)startBufferMonitor {
    if (g_bufferMonitorTimer != NULL) {
        NSLog(@"[MONITOR] Buffer monitor already running");
        return;
    }

    if (capturedPlayerInstance == nil) {
        NSLog(@"[MONITOR] ❌ No player instance - call 'Test SDK Hook' first to capture it");
        return;
    }

    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 📊 Starting Buffer Monitor");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    // Get voice_out_buff ivar
    Class playerClass = object_getClass(capturedPlayerInstance);
    Ivar buffIvar = class_getInstanceVariable(playerClass, "voice_out_buff");

    if (!buffIvar) {
        NSLog(@"[MONITOR] ❌ voice_out_buff ivar not found");
        return;
    }

    NSLog(@"[MONITOR] ✅ Found voice_out_buff ivar");

    // Create timer to poll buffer every 100ms
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    g_bufferMonitorTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);

    dispatch_source_set_timer(g_bufferMonitorTimer,
                              dispatch_time(DISPATCH_TIME_NOW, 0),
                              100 * NSEC_PER_MSEC,  // 100ms interval
                              10 * NSEC_PER_MSEC);  // 10ms leeway

    __weak AudioHookBridge *weakSelf = self;
    ptrdiff_t offset = ivar_getOffset(buffIvar);

    dispatch_source_set_event_handler(g_bufferMonitorTimer, ^{
        [weakSelf pollVoiceOutBuffer:offset];
    });

    dispatch_resume(g_bufferMonitorTimer);
    g_lastBufferWritePos = 0;

    NSLog(@"[MONITOR] ✅ Buffer monitor started (100ms interval)");
    NSLog(@"[MONITOR] Watching for changes to voice_out_buff.w (write position)");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
}

/// Poll voice_out_buff for changes
- (void)pollVoiceOutBuffer:(ptrdiff_t)offset {
    if (capturedPlayerInstance == nil) return;

    void *playerPtr = (__bridge void *)capturedPlayerInstance;
    void **buffPtrAddr = (void **)(playerPtr + offset);
    void *buffPtr = *buffPtrAddr;

    if (!buffPtr) {
        static BOOL loggedNull = NO;
        if (!loggedNull) {
            loggedNull = YES;
            NSLog(@"[MONITOR] ⚠️ voice_out_buff pointer is NULL");
        }
        return;
    }

    // Buffer structure: {*buff, size, r, w}
    // Offsets: buff=0, size=8, r=16, w=24
    uint64_t *sizePtr = (uint64_t *)(buffPtr + sizeof(void *));
    uint64_t *rPtr = (uint64_t *)(buffPtr + sizeof(void *) + sizeof(uint64_t));
    uint64_t *wPtr = (uint64_t *)(buffPtr + sizeof(void *) + 2 * sizeof(uint64_t));

    uint64_t size = *sizePtr;
    uint64_t r = *rPtr;
    uint64_t w = *wPtr;

    static int pollCount = 0;
    pollCount++;

    // Log initial state once
    static BOOL initialLogged = NO;
    if (!initialLogged) {
        initialLogged = YES;
        NSLog(@"[MONITOR] Buffer: ptr=%p, size=%llu, r=%llu, w=%llu", buffPtr, size, r, w);
    }

    // Check for changes
    if (w != g_lastBufferWritePos) {
        uint64_t bytesWritten = w - g_lastBufferWritePos;
        NSLog(@"[MONITOR] 🎉 BUFFER CHANGE! w: %llu → %llu (+%llu bytes)", g_lastBufferWritePos, w, bytesWritten);
        NSLog(@"[MONITOR] Current state: r=%llu, w=%llu, available=%llu bytes", r, w, w - r);

        // Read and analyze the new data
        if (bytesWritten > 0 && bytesWritten < size) {
            void **dataPtr = (void **)buffPtr;
            uint8_t *data = (uint8_t *)*dataPtr;

            if (data) {
                uint64_t readPos = g_lastBufferWritePos % size;
                NSLog(@"[MONITOR] First 16 bytes at offset %llu:", readPos);

                NSMutableString *hexStr = [NSMutableString string];
                for (int i = 0; i < MIN(16, bytesWritten); i++) {
                    [hexStr appendFormat:@"%02X ", data[(readPos + i) % size]];
                }
                NSLog(@"[MONITOR]   %@", hexStr);
            }
        }

        g_lastBufferWritePos = w;
    }

    // Periodic status log
    if (pollCount % 100 == 0) {
        NSLog(@"[MONITOR] Poll #%d: r=%llu, w=%llu, available=%llu", pollCount, r, w, w - r);
    }
}

/// Stop buffer monitoring
- (void)stopBufferMonitor {
    if (g_bufferMonitorTimer != NULL) {
        dispatch_source_cancel(g_bufferMonitorTimer);
        g_bufferMonitorTimer = NULL;
        NSLog(@"[MONITOR] ✅ Buffer monitor stopped");
    }
}

/// Combined test: Send audio CGI and monitor buffer for response
- (void)testAudioCgiWithMonitor:(void *)clientPtr {
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 🚀 Story 10.2: Full Audio CGI Test");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    // Start buffer monitor first
    [self startBufferMonitor];

    // Wait a moment for monitor to initialize
    [NSThread sleepForTimeInterval:0.2];

    // Test audio CGI commands
    [self testAudioCgiCommands:clientPtr];

    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] Monitor is watching for buffer changes...");
    NSLog(@"[AudioHookBridge] Look for [MONITOR] 🎉 BUFFER CHANGE! messages");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
}

#pragma mark - Story 10.3: P2P Channel Audio Interception

/// CSession function pointer types
typedef void* (*CSession_ChannelBuffer_Get_fn)(void *session, int channel);
typedef int (*CSession_Data_Read_fn)(void *session, int channel, void *buffer, int size);
typedef void* (*CSession_SessionInfo_Get_fn)(void *client);

/// Resolved function pointers
static CSession_ChannelBuffer_Get_fn g_CSession_ChannelBuffer_Get = NULL;
static CSession_Data_Read_fn g_CSession_Data_Read = NULL;
static CSession_SessionInfo_Get_fn g_CSession_SessionInfo_Get = NULL;

/// P2P audio capture state
static dispatch_source_t g_p2pAudioTimer = NULL;
static void *g_p2pClientPtr = NULL;
static uint8_t *g_allocatedVoiceBuffer = NULL;
static size_t g_allocatedVoiceBufferSize = 0;

/// Resolve CSession symbols for direct P2P channel access
- (BOOL)resolveCSessionSymbols {
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 🔍 Story 10.3: Resolving CSession Symbols");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    // Try to resolve CSession functions
    g_CSession_ChannelBuffer_Get = (CSession_ChannelBuffer_Get_fn)dlsym(RTLD_DEFAULT, "CSession_ChannelBuffer_Get");
    g_CSession_Data_Read = (CSession_Data_Read_fn)dlsym(RTLD_DEFAULT, "CSession_Data_Read");
    g_CSession_SessionInfo_Get = (CSession_SessionInfo_Get_fn)dlsym(RTLD_DEFAULT, "CSession_SessionInfo_Get");

    NSLog(@"[CSESSION] CSession_ChannelBuffer_Get: %p %s",
          g_CSession_ChannelBuffer_Get, g_CSession_ChannelBuffer_Get ? "✅" : "❌");
    NSLog(@"[CSESSION] CSession_Data_Read: %p %s",
          g_CSession_Data_Read, g_CSession_Data_Read ? "✅" : "❌");
    NSLog(@"[CSESSION] CSession_SessionInfo_Get: %p %s",
          g_CSession_SessionInfo_Get, g_CSession_SessionInfo_Get ? "✅" : "❌");

    // Also try with underscore prefix
    if (!g_CSession_ChannelBuffer_Get) {
        g_CSession_ChannelBuffer_Get = (CSession_ChannelBuffer_Get_fn)dlsym(RTLD_DEFAULT, "_CSession_ChannelBuffer_Get");
        if (g_CSession_ChannelBuffer_Get) NSLog(@"[CSESSION] Found _CSession_ChannelBuffer_Get: %p ✅", g_CSession_ChannelBuffer_Get);
    }
    if (!g_CSession_Data_Read) {
        g_CSession_Data_Read = (CSession_Data_Read_fn)dlsym(RTLD_DEFAULT, "_CSession_Data_Read");
        if (g_CSession_Data_Read) NSLog(@"[CSESSION] Found _CSession_Data_Read: %p ✅", g_CSession_Data_Read);
    }
    if (!g_CSession_SessionInfo_Get) {
        g_CSession_SessionInfo_Get = (CSession_SessionInfo_Get_fn)dlsym(RTLD_DEFAULT, "_CSession_SessionInfo_Get");
        if (g_CSession_SessionInfo_Get) NSLog(@"[CSESSION] Found _CSession_SessionInfo_Get: %p ✅", g_CSession_SessionInfo_Get);
    }

    BOOL success = (g_CSession_ChannelBuffer_Get != NULL || g_CSession_Data_Read != NULL);
    NSLog(@"[CSESSION] Resolution result: %s", success ? "SUCCESS ✅" : "PARTIAL/FAILED");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    return success;
}

/// Manually allocate the voice_out_buff buffer
- (BOOL)allocateVoiceBuffer {
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 🔧 Story 10.3: Allocating Voice Buffer");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    if (capturedPlayerInstance == nil) {
        NSLog(@"[ALLOC] ❌ No player instance captured - call startVoice first");
        return NO;
    }

    Class playerClass = object_getClass(capturedPlayerInstance);
    void *playerPtr = (__bridge void *)capturedPlayerInstance;

    // Get voice_out_buff ivar
    Ivar buffIvar = class_getInstanceVariable(playerClass, "voice_out_buff");
    if (!buffIvar) {
        NSLog(@"[ALLOC] ❌ voice_out_buff ivar not found");
        return NO;
    }

    ptrdiff_t offset = ivar_getOffset(buffIvar);
    NSLog(@"[ALLOC] voice_out_buff offset: %td", offset);

    // The buffer structure is: {*buff, size, r, w}
    // We need to read/write the first two fields (buff pointer and size)

    // Read current state
    uint8_t *structBase = (uint8_t *)playerPtr + offset;
    void **buffPtrField = (void **)structBase;
    uint64_t *sizeField = (uint64_t *)(structBase + sizeof(void *));
    uint64_t *rField = (uint64_t *)(structBase + sizeof(void *) + sizeof(uint64_t));
    uint64_t *wField = (uint64_t *)(structBase + sizeof(void *) + sizeof(uint64_t) * 2);

    NSLog(@"[ALLOC] Current state: buff=%p, size=%llu, r=%llu, w=%llu",
          *buffPtrField, *sizeField, *rField, *wField);

    // If size is 0, we need to allocate
    if (*sizeField == 0) {
        // Allocate a reasonable buffer (128KB = 128 * 1024)
        size_t bufferSize = 131072;  // 128KB, typical audio buffer size

        // Free previous allocation if any
        if (g_allocatedVoiceBuffer) {
            free(g_allocatedVoiceBuffer);
        }

        g_allocatedVoiceBuffer = (uint8_t *)calloc(bufferSize, 1);
        g_allocatedVoiceBufferSize = bufferSize;

        if (g_allocatedVoiceBuffer == NULL) {
            NSLog(@"[ALLOC] ❌ Failed to allocate %zu bytes", bufferSize);
            return NO;
        }

        NSLog(@"[ALLOC] ✅ Allocated %zu bytes at %p", bufferSize, g_allocatedVoiceBuffer);

        // Write to the SDK's buffer structure
        // WARNING: This is risky! The SDK might not expect this buffer
        *buffPtrField = g_allocatedVoiceBuffer;
        *sizeField = bufferSize;
        *rField = 0;
        *wField = 0;

        NSLog(@"[ALLOC] ✅ Updated SDK's voice_out_buff:");
        NSLog(@"[ALLOC]    buff=%p, size=%llu, r=%llu, w=%llu",
              *buffPtrField, *sizeField, *rField, *wField);

        return YES;
    } else {
        NSLog(@"[ALLOC] Buffer already has size=%llu - no allocation needed", *sizeField);
        return YES;
    }
}

/// Start direct P2P channel 2 capture
- (void)startP2PAudioCapture:(void *)clientPtr {
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 🎙️ Story 10.3: Starting P2P Audio Capture");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    if (g_p2pAudioTimer != NULL) {
        NSLog(@"[P2P-AUDIO] Already running");
        return;
    }

    g_p2pClientPtr = clientPtr;

    // Create timer to poll for audio data
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    g_p2pAudioTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);

    dispatch_source_set_timer(g_p2pAudioTimer,
                              dispatch_time(DISPATCH_TIME_NOW, 0),
                              20 * NSEC_PER_MSEC,   // 20ms interval (50Hz)
                              1 * NSEC_PER_MSEC);   // 1ms leeway

    __weak AudioHookBridge *weakSelf = self;
    static int pollCount = 0;
    pollCount = 0;

    dispatch_source_set_event_handler(g_p2pAudioTimer, ^{
        pollCount++;
        [weakSelf pollP2PAudioChannel:pollCount];
    });

    dispatch_resume(g_p2pAudioTimer);
    NSLog(@"[P2P-AUDIO] ✅ Capture started (20ms interval)");
}

/// Poll P2P channel 2 for audio data
- (void)pollP2PAudioChannel:(int)pollCount {
    if (capturedPlayerInstance == nil) return;

    Class playerClass = object_getClass(capturedPlayerInstance);
    void *playerPtr = (__bridge void *)capturedPlayerInstance;

    // Read voice_out_buff state
    Ivar buffIvar = class_getInstanceVariable(playerClass, "voice_out_buff");
    if (!buffIvar) return;

    ptrdiff_t offset = ivar_getOffset(buffIvar);
    uint8_t *structBase = (uint8_t *)playerPtr + offset;

    void **buffPtrField = (void **)structBase;
    uint64_t *sizeField = (uint64_t *)(structBase + sizeof(void *));
    uint64_t *rField = (uint64_t *)(structBase + sizeof(void *) + sizeof(uint64_t));
    uint64_t *wField = (uint64_t *)(structBase + sizeof(void *) + sizeof(uint64_t) * 2);

    uint8_t *buff = (uint8_t *)*buffPtrField;
    uint64_t size = *sizeField;
    uint64_t r = *rField;
    uint64_t w = *wField;

    // Log periodically
    if (pollCount <= 10 || pollCount % 50 == 0) {
        NSLog(@"[P2P-AUDIO] Poll #%d: buff=%p, size=%llu, r=%llu, w=%llu",
              pollCount, buff, size, r, w);
    }

    // Check for new data
    if (w <= r || buff == NULL || size == 0) {
        return;  // No new data
    }

    // We have data!
    uint64_t available = w - r;

    NSLog(@"[P2P-AUDIO] 🎉 DATA AVAILABLE! %llu bytes (r=%llu, w=%llu)", available, r, w);

    // Read and decode the data
    uint64_t toRead = MIN(available, (uint64_t)4096);  // Max 4KB at a time
    uint64_t readPos = r % size;

    // Handle wrap-around
    uint8_t tempBuffer[4096];
    uint64_t bytesToEnd = size - readPos;

    if (toRead <= bytesToEnd) {
        memcpy(tempBuffer, buff + readPos, toRead);
    } else {
        memcpy(tempBuffer, buff + readPos, bytesToEnd);
        memcpy(tempBuffer + bytesToEnd, buff, toRead - bytesToEnd);
    }

    // Update read position
    *rField = r + toRead;

    // Analyze the data
    int nonZero = 0;
    for (uint64_t i = 0; i < toRead && i < 100; i++) {
        if (tempBuffer[i] != 0) nonZero++;
    }

    NSLog(@"[P2P-AUDIO] Read %llu bytes, non-zero in first 100: %d", toRead, nonZero);

    // Dump first 32 bytes
    NSMutableString *hexStr = [NSMutableString string];
    for (int i = 0; i < MIN(32, (int)toRead); i++) {
        [hexStr appendFormat:@"%02X ", tempBuffer[i]];
    }
    NSLog(@"[P2P-AUDIO] Data: %@", hexStr);

    // If it looks like G.711a audio, decode it
    if (nonZero > 20) {
        size_t sampleCount = toRead;  // G.711: 1 byte = 1 sample
        int16_t *pcmBuffer = (int16_t *)malloc(sampleCount * sizeof(int16_t));

        if (pcmBuffer) {
            // Decode G.711a
            decode_alaw(tempBuffer, pcmBuffer, sampleCount);

            // Calculate stats
            int16_t minVal = pcmBuffer[0], maxVal = pcmBuffer[0];
            float sumAbs = 0;
            for (size_t i = 0; i < sampleCount && i < 480; i++) {
                if (pcmBuffer[i] < minVal) minVal = pcmBuffer[i];
                if (pcmBuffer[i] > maxVal) maxVal = pcmBuffer[i];
                sumAbs += fabsf((float)pcmBuffer[i]);
            }
            float avgAbs = sumAbs / (sampleCount > 0 ? sampleCount : 1);

            NSLog(@"[P2P-AUDIO] Decoded PCM: min=%d, max=%d, avgAbs=%.1f", minVal, maxVal, avgAbs);

            if (avgAbs > 100) {
                NSLog(@"[P2P-AUDIO] ✅ REAL AUDIO DETECTED! Forwarding to callback...");

                // Forward to Swift callback
                if (self.captureCallback) {
                    self.captureCallback(pcmBuffer, (uint32_t)sampleCount);
                    _capturedFrameCount += sampleCount;
                }
            }

            free(pcmBuffer);
        }
    }
}

/// Stop P2P audio capture
- (void)stopP2PAudioCapture {
    if (g_p2pAudioTimer != NULL) {
        dispatch_source_cancel(g_p2pAudioTimer);
        g_p2pAudioTimer = NULL;
        NSLog(@"[P2P-AUDIO] ✅ Capture stopped");
    }
    g_p2pClientPtr = NULL;
}

/// Run full Story 10.3 test
- (void)testStory103:(void *)clientPtr {
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 🚀 STORY 10.3: P2P Audio Interception Test");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    // Step 1: Resolve CSession symbols (informational)
    [self resolveCSessionSymbols];

    // Step 2: Allocate voice buffer (if size=0)
    BOOL allocated = [self allocateVoiceBuffer];
    if (!allocated) {
        NSLog(@"[10.3] ⚠️ Buffer allocation failed or not needed");
    }

    // Step 3: Send audio CGI commands
    NSLog(@"[10.3] Sending audio CGI commands...");
    [self testAudioCgiCommands:clientPtr];

    // Step 4: Start P2P audio capture
    [self startP2PAudioCapture:clientPtr];

    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");
    NSLog(@"[AudioHookBridge] 📋 Story 10.3 test running!");
    NSLog(@"[AudioHookBridge] Watch for [P2P-AUDIO] 🎉 DATA AVAILABLE! messages");
    NSLog(@"[AudioHookBridge] The test will run for 30 seconds...");
    NSLog(@"[AudioHookBridge] ═══════════════════════════════════════");

    // Schedule auto-stop after 30 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self stopP2PAudioCapture];
        NSLog(@"[10.3] ✅ Test completed (30 second timeout)");
        NSLog(@"[10.3] Captured frames: %llu", self.capturedFrameCount);
    });
}

@end
