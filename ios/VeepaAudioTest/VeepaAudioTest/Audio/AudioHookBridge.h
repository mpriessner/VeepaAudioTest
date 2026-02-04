//
//  AudioHookBridge.h
//  VeepaAudioTest
//
//  Created for AudioUnit Hook implementation
//  Purpose: Objective-C bridge for method swizzling SDK's audio handling
//
//  This file provides the Objective-C runtime access needed to:
//  1. Find AppIOSPlayer instances at runtime
//  2. Swizzle audio-related methods
//  3. Install render notify callbacks on the SDK's AudioUnit
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

/// Callback block for audio data capture
typedef void (^AudioCaptureBlock)(const int16_t *samples, uint32_t count);

/// Objective-C bridge for hooking into SDK's audio handling
///
/// This class uses the Objective-C runtime to:
/// - Discover SDK's AppIOSPlayer instance
/// - Access its audioUnit property
/// - Install render notify callbacks
/// - Forward audio data to Swift code
///
@interface AudioHookBridge : NSObject

/// Shared instance
@property (class, readonly) AudioHookBridge *shared;

/// Whether hooks are currently installed
@property (nonatomic, readonly) BOOL isHooked;

/// The intercepted AudioUnit (if found)
@property (nonatomic, readonly, nullable) AudioUnit interceptedUnit;

/// Number of frames captured
@property (nonatomic, readonly) uint64_t capturedFrameCount;

/// Callback for captured audio data
@property (nonatomic, copy, nullable) AudioCaptureBlock captureCallback;

#pragma mark - Discovery

/// Attempt to find AppIOSPlayer class and its instances
/// Returns description of what was found
- (NSArray<NSString *> *)discoverSDKClasses;

/// Try to find the SDK's AudioUnit from any available AppIOSPlayer instance
/// This searches the Objective-C runtime for instances
- (BOOL)findSDKAudioUnit;

#pragma mark - Hook Installation

/// Install method swizzling on AppIOSPlayer
/// This replaces key methods to intercept audio flow
- (BOOL)installSwizzling;

/// Remove swizzling and restore original methods
- (void)removeSwizzling;

/// Install render notify on a specific AudioUnit
/// Use after findSDKAudioUnit succeeds
- (BOOL)installRenderNotifyOnUnit:(AudioUnit)unit;

/// Remove render notify
- (void)removeRenderNotify;

#pragma mark - Testing

/// Create a test AudioUnit to verify our hooking works
/// Returns YES if test passed
- (BOOL)runSelfTest;

/// Get statistics description
- (NSString *)statisticsDescription;

/// Increment captured frame count (for internal use by callback)
- (void)incrementCapturedFrameCount:(uint32_t)count;

#pragma mark - Voice Frame Direct Capture (G.711a Bypass)

/// Start polling the SDK's voice_frame directly and decoding G.711a
/// This bypasses the broken AudioUnit render callback entirely
/// Call this AFTER startVoice has been triggered (so player instance is captured)
- (void)startVoiceFrameCapture;

/// Stop voice frame capture
- (void)stopVoiceFrameCapture;

#pragma mark - pcmp2 API (Story 10.1)

/// Resolve pcmp2_* symbols from the SDK using dlsym
/// Returns YES if critical symbols (pcmp2_init, pcmp2_setListener) were found
- (BOOL)resolvePcmp2Symbols;

/// Test the pcmp2 listener by initializing and registering a callback
/// This will log when/if the callback receives audio data
- (void)testPcmp2Listener;

/// Stop pcmp2 listener test and cleanup
- (void)stopPcmp2Listener;

/// Investigate if AppIOSPlayer has pcmp2-related ivars and methods
/// Useful for understanding how the SDK uses pcmp2 internally
- (void)investigatePcmp2InPlayer;

#pragma mark - CGI Command API (Story 10.2)

/// Resolve client_write_cgi symbol from SDK
- (BOOL)resolveCgiSymbols;

/// Send a CGI command to the camera
/// @param cgiCommand The CGI command string
/// @param clientPtr The P2P client pointer from connection service
/// @return Result code (positive = success, negative = error)
- (int)sendCgiCommand:(NSString *)cgiCommand toClient:(void *)clientPtr;

/// Test various audio CGI commands to find one that enables audio
- (void)testAudioCgiCommands:(void *)clientPtr;

/// Start monitoring voice_out_buff for incoming audio data
- (void)startBufferMonitor;

/// Stop buffer monitoring
- (void)stopBufferMonitor;

/// Combined test: Send audio CGI commands and monitor buffer for response
- (void)testAudioCgiWithMonitor:(void *)clientPtr;

#pragma mark - Story 10.3: P2P Channel Audio Interception

/// Resolve CSession symbols for direct P2P channel access
/// Returns YES if key symbols (CSession_ChannelBuffer_Get, CSession_Data_Read) found
- (BOOL)resolveCSessionSymbols;

/// Manually allocate the voice_out_buff that was never initialized
/// This allows the SDK to store audio data even though startVoice() failed
- (BOOL)allocateVoiceBuffer;

/// Start direct P2P channel 2 capture
/// This reads from the P2P layer, bypassing SDK's broken audio pipeline
/// @param clientPtr The P2P client pointer
- (void)startP2PAudioCapture:(void *)clientPtr;

/// Stop P2P audio capture
- (void)stopP2PAudioCapture;

/// Run full Story 10.3 test: allocate buffer + CGI + P2P capture
- (void)testStory103:(void *)clientPtr;

@end

NS_ASSUME_NONNULL_END
