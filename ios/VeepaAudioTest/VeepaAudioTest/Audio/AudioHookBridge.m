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

// Forward declare the SDK's class
@class AppIOSPlayer;

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

@end
