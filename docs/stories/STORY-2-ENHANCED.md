# Story 2: P2P SDK Integration and Flutter Services (ENHANCED)

**Epic**: VeepaAudioTest - Minimal Audio Testing App
**Story**: Integrate P2P SDK and copy Flutter service layer
**Total Estimated Time**: 2-2.5 hours

---

## 📋 Story Overview

Copy the P2P SDK (libVSTC.a) and essential Flutter/iOS services from SciSymbioLens, adapting them for audio-only testing. This story establishes the communication layer between iOS and Flutter.

**What We're Building:**
- P2P SDK binary and plugin structure
- Dart FFI bindings for SDK
- Flutter engine manager (iOS side)
- Platform channel communication
- SDK symbol access bridge (VSTCBridge)

**What We're Adapting from SciSymbioLens:**
- libVSTC.a binary (45MB) - copy exactly
- app_p2p_api.dart - copy exactly (FFI bindings)
- FlutterEngineManager.swift - adapt (remove video frame handling)
- VSTCBridge.swift - copy exactly (low-level SDK access)
- VeepaConnectionBridge.swift - simplify (remove state polling)

---

## 📊 Sub-Stories Breakdown

### Sub-Story 2.1: Copy P2P SDK Binary and Plugin
⏱️ **Estimated Time**: 15-20 minutes

### Sub-Story 2.2: Copy P2P Dart Bindings
⏱️ **Estimated Time**: 20-25 minutes

### Sub-Story 2.3: Create Simplified Audio Player
⏱️ **Estimated Time**: 25-30 minutes

### Sub-Story 2.4: Copy Flutter Engine Manager
⏱️ **Estimated Time**: 25-30 minutes

### Sub-Story 2.5: Copy VSTCBridge for SDK Symbol Access
⏱️ **Estimated Time**: 15-20 minutes

### Sub-Story 2.6: Create Simplified Connection Bridge
⏱️ **Estimated Time**: 20-25 minutes

### Sub-Story 2.7: Verify Flutter-iOS Communication
⏱️ **Estimated Time**: 15-20 minutes

---

## 🔧 Sub-Story 2.1: Copy P2P SDK Binary and Plugin

**Goal**: Copy libVSTC.a and VsdkPlugin from SciSymbioLens to VeepaAudioTest

⏱️ **Estimated Time**: 15-20 minutes

### Analysis of Source Code

From `SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/`:

**Directory structure discovered**:
```
vsdk/ios/
├── Classes/
│   ├── VsdkPlugin.h          # Main plugin header (16 lines)
│   ├── VsdkPlugin.m          # Plugin registration (48 lines)
│   ├── AppP2PApiPlugin.h     # P2P API declarations (203 lines)
│   ├── AppPlayerPlugin.h     # Player API declarations (150 lines)
│   └── libVSTC.a             # Binary SDK (45MB, arm64 only)
└── vsdk.podspec              # Pod specification (23 lines)
```

**Critical details**:
- libVSTC.a is **45MB** static library
- Architecture: **arm64 only** (no simulator support - will fail on Intel Macs/simulators)
- Plugin uses **Objective-C** (not Swift) for C interop
- Headers define C function prototypes for FFI

**What to adapt:**
- ✅ Copy all headers exactly - cannot modify C function signatures
- ✅ Copy libVSTC.a exactly - binary cannot be modified
- ✏️ Adapt vsdk.podspec - update paths and dependencies

### Implementation Steps

#### Step 2.1.1: Create Plugin Directory Structure (3 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

# Create plugin structure
mkdir -p ios/.symlinks/plugins/vsdk/ios/Classes
```

**✅ Verification:**
```bash
ls -la ios/.symlinks/plugins/vsdk/ios/
# Expected: Classes/ directory created
```

#### Step 2.1.2: Copy Plugin Headers and Binary (5 min)

**Copy from**: `SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/Classes/`

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

# Copy all plugin files
cp /Users/mpriessner/windsurf_repos/SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/Classes/VsdkPlugin.h \
   ios/.symlinks/plugins/vsdk/ios/Classes/

cp /Users/mpriessner/windsurf_repos/SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/Classes/VsdkPlugin.m \
   ios/.symlinks/plugins/vsdk/ios/Classes/

cp /Users/mpriessner/windsurf_repos/SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/Classes/AppP2PApiPlugin.h \
   ios/.symlinks/plugins/vsdk/ios/Classes/

cp /Users/mpriessner/windsurf_repos/SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/Classes/AppPlayerPlugin.h \
   ios/.symlinks/plugins/vsdk/ios/Classes/

# Copy binary SDK (45MB - may take 10-15 seconds)
echo "Copying libVSTC.a (45MB)..."
cp /Users/mpriessner/windsurf_repos/SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/Classes/libVSTC.a \
   ios/.symlinks/plugins/vsdk/ios/Classes/

echo "✅ Plugin files copied"
```

**✅ Verification:**
```bash
cd ios/.symlinks/plugins/vsdk/ios/Classes

# Verify all files present
ls -lh
# Expected:
# VsdkPlugin.h         (~1KB)
# VsdkPlugin.m         (~2KB)
# AppP2PApiPlugin.h    (~8KB)
# AppPlayerPlugin.h    (~6KB)
# libVSTC.a            (45MB)

# Verify binary is correct architecture
lipo -info libVSTC.a
# Expected: "Non-fat file: libVSTC.a is architecture: arm64"
```

#### Step 2.1.3: Create Adapted Podspec (7 min)

**Adapt from**: `SciSymbioLens/flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/vsdk.podspec`

Create `flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/ios/vsdk.podspec`:

```ruby
# ADAPTED FROM: SciSymbioLens vsdk.podspec
# Changes: Minimal - just package metadata updates
#
Pod::Spec.new do |s|
  s.name             = 'vsdk'
  s.version          = '0.0.1'
  s.summary          = 'Veepa P2P SDK Flutter plugin'
  s.description      = <<-DESC
Flutter plugin wrapping the Veepa P2P SDK (libVSTC.a) for camera communication.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Veepa' => 'sdk@veepa.com' }
  s.source           = { :path => '.' }

  # Source files
  s.source_files = 'Classes/**/*'

  # Public headers
  s.public_header_files = 'Classes/**/*.h'

  # Platform requirements
  s.platform = :ios, '12.0'

  # Link the static library
  s.vendored_libraries = 'Classes/libVSTC.a'

  # System frameworks required by libVSTC.a
  s.frameworks = [
    'AVFoundation',      # Audio/video capture
    'AudioToolbox',      # Audio processing (CRITICAL for audio)
    'VideoToolbox',      # Video decoding (SDK may still use internally)
    'CoreMedia',         # Media pipeline
    'CoreVideo'          # Video buffers
  ]

  # System libraries required by libVSTC.a
  s.libraries = [
    'z',                 # Compression
    'c++',               # C++ standard library
    'iconv',             # Character encoding
    'bz2'                # Compression
  ]

  # Dependencies
  s.dependency 'Flutter'
end
```

**✅ Verification:**
```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

# Verify podspec syntax (requires CocoaPods)
pod spec lint ios/.symlinks/plugins/vsdk/ios/vsdk.podspec --allow-warnings
# Expected: "vsdk.podspec passed validation."
# (Warnings about source being :path are OK)
```

---

### ✅ Sub-Story 2.1 Complete Verification

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/ios

# 1. All plugin files present
test -f Classes/VsdkPlugin.h && echo "✅ VsdkPlugin.h"
test -f Classes/VsdkPlugin.m && echo "✅ VsdkPlugin.m"
test -f Classes/AppP2PApiPlugin.h && echo "✅ AppP2PApiPlugin.h"
test -f Classes/AppPlayerPlugin.h && echo "✅ AppPlayerPlugin.h"
test -f Classes/libVSTC.a && echo "✅ libVSTC.a"

# 2. Binary is correct size and architecture
LIBSIZE=$(stat -f%z Classes/libVSTC.a)
if [ $LIBSIZE -gt 40000000 ]; then
  echo "✅ libVSTC.a size: $LIBSIZE bytes (correct)"
else
  echo "❌ libVSTC.a size: $LIBSIZE bytes (too small - copy failed?)"
fi

lipo -info Classes/libVSTC.a
# Expected: arm64 architecture

# 3. Podspec exists
test -f vsdk.podspec && echo "✅ vsdk.podspec"
```

**Acceptance Criteria:**
- [ ] Plugin directory structure created
- [ ] VsdkPlugin.h and .m copied
- [ ] AppP2PApiPlugin.h and AppPlayerPlugin.h copied
- [ ] libVSTC.a copied (45MB)
- [ ] Binary is arm64 architecture
- [ ] vsdk.podspec created with correct dependencies
- [ ] Podspec validates (if CocoaPods installed)

---

## 🔧 Sub-Story 2.2: Copy P2P Dart Bindings

**Goal**: Copy Dart FFI bindings that allow Dart code to call libVSTC.a functions

⏱️ **Estimated Time**: 20-25 minutes

### Analysis of Source Code

From `SciSymbioLens/flutter_module/veepa_camera/lib/sdk/`:

**Files discovered**:
- `app_p2p_api.dart` (~500 lines) - Main P2P API with FFI bindings
- `app_dart.dart` (~200 lines) - Data structures and enums
- `app_player.dart` (~350 lines) - Player controller wrapper

**Key patterns in app_p2p_api.dart**:
```dart
// Lines 1-50: FFI setup
import 'dart:ffi' as ffi;
import 'dart:io';

final DynamicLibrary _lib = Platform.isAndroid
    ? ffi.DynamicLibrary.open('libVSTC.so')
    : ffi.DynamicLibrary.process(); // iOS: libVSTC.a linked into app

// Lines 51-150: Function type definitions
typedef ClientCreate_Native = ffi.Int32 Function(ffi.Pointer<ffi.Utf8>);
typedef ClientCreate_Dart = int Function(ffi.Pointer<ffi.Utf8>);

// Lines 151-500: API class with methods
class AppP2PApi {
  late final ClientCreate_Dart clientCreate;

  AppP2PApi() {
    // Bind C functions to Dart
    clientCreate = _lib.lookupFunction<ClientCreate_Native, ClientCreate_Dart>('ClientCreate');
  }

  // Wrapper methods
  int Client_Create(String clientId) {
    final clientIdPtr = clientId.toNativeUtf8();
    final result = clientCreate(clientIdPtr);
    calloc.free(clientIdPtr);
    return result;
  }
}
```

**What to adapt:**
- ✅ Copy app_p2p_api.dart exactly - FFI signatures must match C functions
- ✅ Copy app_dart.dart exactly - data structures used throughout
- ✏️ Adapt app_player.dart - remove video methods, keep audio methods

### Implementation Steps

#### Step 2.2.1: Create SDK Directory (2 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

mkdir -p lib/sdk
```

**✅ Verification:**
```bash
ls -la lib/sdk/
# Expected: Empty directory created
```

#### Step 2.2.2: Copy P2P API Bindings (5 min)

**Copy from**: `SciSymbioLens/flutter_module/veepa_camera/lib/sdk/`

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

# Copy app_p2p_api.dart (exact copy - FFI bindings cannot change)
cp /Users/mpriessner/windsurf_repos/SciSymbioLens/flutter_module/veepa_camera/lib/sdk/app_p2p_api.dart \
   lib/sdk/

# Copy app_dart.dart (exact copy - data structures)
cp /Users/mpriessner/windsurf_repos/SciSymbioLens/flutter_module/veepa_camera/lib/sdk/app_dart.dart \
   lib/sdk/

echo "✅ P2P API bindings copied"
```

**✅ Verification:**
```bash
cd lib/sdk

# Verify files present
test -f app_p2p_api.dart && echo "✅ app_p2p_api.dart"
test -f app_dart.dart && echo "✅ app_dart.dart"

# Check FFI imports present
grep "dart:ffi" app_p2p_api.dart
# Expected: "import 'dart:ffi' as ffi;"

# Check line count (approximately)
wc -l app_p2p_api.dart
# Expected: ~500 lines
```

#### Step 2.2.3: Create Simplified Audio Player (15 min)

**Adapt from**: `SciSymbioLens/flutter_module/veepa_camera/lib/sdk/app_player.dart` (350 lines)

Now we create a **simplified version** with only audio methods.

Create `flutter_module/veepa_audio/lib/sdk/audio_player.dart`:

```dart
// ADAPTED FROM: SciSymbioLens app_player.dart
// Changes: Removed video rendering, frame capture, player UI controls
//          Kept: Audio control methods (startVoice, stopVoice, setMute)
//
import 'dart:async';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

import 'app_p2p_api.dart';
import 'app_dart.dart';

/// Simplified audio player for Veepa P2P SDK
///
/// This class wraps the P2P SDK's audio streaming functions.
/// Unlike the full app_player.dart, this only handles audio (no video).
class AudioPlayer {
  final AppP2PApi _api = AppP2PApi();

  /// Client pointer from P2P SDK (must be set after connection)
  int? _clientPtr;

  /// Whether audio is currently playing
  bool _isAudioPlaying = false;

  /// Whether audio is muted
  bool _isMuted = false;

  // Getters
  bool get isAudioPlaying => _isAudioPlaying;
  bool get isMuted => _isMuted;

  /// Set the client pointer (called after P2P connection established)
  void setClientPtr(int clientPtr) {
    _clientPtr = clientPtr;
    print('[AudioPlayer] Client pointer set: $clientPtr');
  }

  /// Start audio streaming
  ///
  /// Calls App_SetStartVoice() from P2P SDK.
  /// This is where error -50 may occur if AVAudioSession not configured properly.
  Future<bool> startVoice() async {
    if (_clientPtr == null) {
      print('[AudioPlayer] ❌ Cannot start voice - no client pointer');
      return false;
    }

    if (_isAudioPlaying) {
      print('[AudioPlayer] Audio already playing');
      return true;
    }

    try {
      print('[AudioPlayer] Starting voice...');
      print('[AudioPlayer] Calling App_SetStartVoice(clientPtr: $_clientPtr)');

      final result = await _api.App_SetStartVoice(_clientPtr!);

      if (result == 0) {
        _isAudioPlaying = true;
        print('[AudioPlayer] ✅ Voice started successfully');
        return true;
      } else {
        print('[AudioPlayer] ❌ App_SetStartVoice failed with error: $result');
        return false;
      }
    } catch (e) {
      print('[AudioPlayer] ❌ Exception in startVoice: $e');
      return false;
    }
  }

  /// Stop audio streaming
  ///
  /// Calls App_SetStopVoice() from P2P SDK.
  Future<bool> stopVoice() async {
    if (_clientPtr == null) {
      print('[AudioPlayer] ❌ Cannot stop voice - no client pointer');
      return false;
    }

    if (!_isAudioPlaying) {
      print('[AudioPlayer] Audio not playing');
      return true;
    }

    try {
      print('[AudioPlayer] Stopping voice...');
      print('[AudioPlayer] Calling App_SetStopVoice(clientPtr: $_clientPtr)');

      final result = await _api.App_SetStopVoice(_clientPtr!);

      if (result == 0) {
        _isAudioPlaying = false;
        print('[AudioPlayer] ✅ Voice stopped successfully');
        return true;
      } else {
        print('[AudioPlayer] ❌ App_SetStopVoice failed with error: $result');
        return false;
      }
    } catch (e) {
      print('[AudioPlayer] ❌ Exception in stopVoice: $e');
      return false;
    }
  }

  /// Set mute state
  ///
  /// Calls App_SetMute() from P2P SDK.
  Future<bool> setMute(bool muted) async {
    if (_clientPtr == null) {
      print('[AudioPlayer] ❌ Cannot set mute - no client pointer');
      return false;
    }

    try {
      print('[AudioPlayer] Setting mute: $muted');
      print('[AudioPlayer] Calling App_SetMute(clientPtr: $_clientPtr, muted: ${muted ? 1 : 0})');

      final result = await _api.App_SetMute(_clientPtr!, muted ? 1 : 0);

      if (result == 0) {
        _isMuted = muted;
        print('[AudioPlayer] ✅ Mute set to: $muted');
        return true;
      } else {
        print('[AudioPlayer] ❌ App_SetMute failed with error: $result');
        return false;
      }
    } catch (e) {
      print('[AudioPlayer] ❌ Exception in setMute: $e');
      return false;
    }
  }

  /// Cleanup (called when disconnecting)
  Future<void> dispose() async {
    if (_isAudioPlaying) {
      await stopVoice();
    }
    _clientPtr = null;
    print('[AudioPlayer] Disposed');
  }
}
```

**Key adaptations from source**:
- ❌ Removed: Video rendering, frame capture, player UI callbacks
- ❌ Removed: Video status handling, resolution changes
- ✅ Kept: startVoice(), stopVoice(), setMute() methods
- ✅ Enhanced: Added detailed logging for debugging audio issues

**✅ Verification:**
```bash
cd lib/sdk

# Verify file created
test -f audio_player.dart && echo "✅ audio_player.dart created"

# Check for key methods
grep "startVoice()" audio_player.dart
grep "stopVoice()" audio_player.dart
grep "setMute" audio_player.dart
# ✅ Expected: All three methods found

# Check for removed video methods (should NOT exist)
! grep -q "startVideo" audio_player.dart && echo "✅ Video methods removed"
! grep -q "captureFrame" audio_player.dart && echo "✅ Frame capture removed"
```

---

### ✅ Sub-Story 2.2 Complete Verification

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

# 1. SDK directory created
test -d lib/sdk && echo "✅ SDK directory exists"

# 2. P2P API files present
test -f lib/sdk/app_p2p_api.dart && echo "✅ app_p2p_api.dart"
test -f lib/sdk/app_dart.dart && echo "✅ app_dart.dart"
test -f lib/sdk/audio_player.dart && echo "✅ audio_player.dart"

# 3. Flutter analyze (should pass)
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio
flutter analyze lib/sdk/
# Expected: No issues found (or only warnings about missing imports - OK for now)
```

**Acceptance Criteria:**
- [ ] lib/sdk/ directory created
- [ ] app_p2p_api.dart copied (exact copy, ~500 lines)
- [ ] app_dart.dart copied (exact copy, ~200 lines)
- [ ] audio_player.dart created (adapted, ~150 lines)
- [ ] audio_player.dart has startVoice(), stopVoice(), setMute() methods
- [ ] audio_player.dart does NOT have video methods
- [ ] Flutter analyze shows no errors

---

## 🔧 Sub-Story 2.3: Update Main Dart Entry Point

**Goal**: Update lib/main.dart to handle audio method calls from iOS

⏱️ **Estimated Time**: 25-30 minutes

### Analysis of Source Code

From `SciSymbioLens/flutter_module/veepa_camera/lib/main.dart`:

**Key patterns discovered** (from 882-line architecture doc analysis):
- Lines 1-50: Imports and global variables
- Lines 51-100: Method channel setup in main()
- Lines 101-300: Method call handler (handles iOS → Flutter calls)
- Lines 301-500: P2P connection logic
- Lines 501-882: Video streaming, provisioning, discovery (NOT needed)

**Critical method channel pattern**:
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Method channel setup
  platform.setMethodCallHandler(_handleMethodCall);

  // Signal iOS that Flutter is ready
  platform.invokeMethod('flutterReady');

  runApp(Container()); // Headless - no UI
}
```

**What to adapt:**
- ✅ Keep: Method channel setup, flutterReady signal
- ✅ Keep: Audio methods (startAudio, stopAudio, setMute)
- ❌ Remove: Video streaming, provisioning, discovery
- ❌ Remove: MaterialApp (headless service, no UI needed)

### Implementation Steps

#### Step 2.3.1: Read Existing main.dart (3 min)

First, let's see what we created in Sub-Story 1.1:

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio
cat lib/main.dart
```

We created a placeholder. Now we'll replace it with the full implementation.

#### Step 2.3.2: Create Full main.dart (20 min)

**Adapt from**: `SciSymbioLens/flutter_module/veepa_camera/lib/main.dart`

Replace `flutter_module/veepa_audio/lib/main.dart`:

```dart
// ADAPTED FROM: SciSymbioLens lib/main.dart
// Changes: Removed video streaming, provisioning, discovery
//          Kept: Method channel, audio control, P2P connection
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sdk/app_p2p_api.dart';
import 'sdk/app_dart.dart';
import 'sdk/audio_player.dart';

// Method channel for iOS ↔ Flutter communication
const platform = MethodChannel('com.veepatest/audio');

// Global instances
AppP2PApi? _p2pApi;
AudioPlayer? _audioPlayer;
int? _clientPtr;

void main() {
  // Ensure Flutter bindings initialized
  WidgetsFlutterBinding.ensureInitialized();

  print('[VeepaAudio] Flutter main() starting...');

  // Initialize P2P API
  try {
    _p2pApi = AppP2PApi();
    _audioPlayer = AudioPlayer();
    print('[VeepaAudio] ✅ P2P API and AudioPlayer initialized');
  } catch (e) {
    print('[VeepaAudio] ❌ Failed to initialize P2P API: $e');
  }

  // Set up method call handler (iOS will call these methods)
  platform.setMethodCallHandler(_handleMethodCall);
  print('[VeepaAudio] ✅ Method call handler registered');

  // Signal to iOS that Flutter is ready
  // CRITICAL: iOS waits for this signal before calling methods
  try {
    platform.invokeMethod('flutterReady');
    print('[VeepaAudio] ✅ Sent flutterReady signal to iOS');
  } catch (e) {
    print('[VeepaAudio] ❌ Failed to send flutterReady: $e');
  }

  // Run headless app (no UI)
  runApp(Container());
  print('[VeepaAudio] ✅ Flutter engine running (headless mode)');
}

/// Handle method calls from iOS
Future<dynamic> _handleMethodCall(MethodCall call) async {
  print('[VeepaAudio] ← Received method call: ${call.method}');

  try {
    switch (call.method) {
      // ===== Ping Test =====
      case 'ping':
        print('[VeepaAudio] → Responding to ping with pong');
        return 'pong';

      // ===== P2P Connection =====
      case 'connectWithCredentials':
        return await _connectWithCredentials(call.arguments);

      case 'disconnect':
        return await _disconnect();

      // ===== Audio Control =====
      case 'setClientPtr':
        return _setClientPtr(call.arguments);

      case 'startAudio':
        return await _startAudio();

      case 'stopAudio':
        return await _stopAudio();

      case 'setMute':
        return await _setMute(call.arguments);

      // ===== Utility =====
      default:
        print('[VeepaAudio] ❌ Unknown method: ${call.method}');
        throw PlatformException(
          code: 'UNKNOWN_METHOD',
          message: 'Method ${call.method} not implemented',
        );
    }
  } catch (e) {
    print('[VeepaAudio] ❌ Error handling ${call.method}: $e');
    rethrow;
  }
}

// ===== P2P Connection Methods =====

Future<Map<String, dynamic>> _connectWithCredentials(dynamic arguments) async {
  print('[VeepaAudio] _connectWithCredentials called');

  if (_p2pApi == null) {
    return {'success': false, 'error': 'P2P API not initialized'};
  }

  try {
    final Map<String, dynamic> args = Map<String, dynamic>.from(arguments);
    final String cameraUid = args['cameraUid'] as String;
    final String clientId = args['clientId'] as String;
    final String serviceParam = args['serviceParam'] as String;
    final String password = args['password'] as String? ?? 'admin';

    print('[VeepaAudio] Connecting to camera UID: $cameraUid');
    print('[VeepaAudio] Client ID: $clientId');
    print('[VeepaAudio] Service param length: ${serviceParam.length} chars');

    // Step 1: Create P2P client
    print('[VeepaAudio] Step 1: Creating P2P client...');
    final clientPtr = await _p2pApi!.Client_Create(clientId);

    if (clientPtr == 0) {
      print('[VeepaAudio] ❌ Client_Create failed (returned 0)');
      return {'success': false, 'error': 'Failed to create P2P client'};
    }

    print('[VeepaAudio] ✅ Client created with pointer: $clientPtr');
    _clientPtr = clientPtr;

    // Step 2: Connect to camera
    print('[VeepaAudio] Step 2: Connecting to camera...');
    final connectType = 63; // LAN mode (or 126 for P2P/router mode)
    final connectResult = await _p2pApi!.Client_Connect(
      clientPtr,
      serviceParam,
      connectType,
    );

    if (connectResult != ClientConnectState.CONNECT_STATUS_ONLINE.index) {
      print('[VeepaAudio] ❌ Connection failed with status: $connectResult');
      return {
        'success': false,
        'error': 'Connection failed (status $connectResult)',
      };
    }

    print('[VeepaAudio] ✅ Connected successfully');

    // Step 3: Login
    print('[VeepaAudio] Step 3: Logging in with password...');
    final loginResult = await _p2pApi!.Client_Login(
      clientPtr,
      'admin', // Default username
      password,
    );

    if (!loginResult) {
      print('[VeepaAudio] ❌ Login failed');
      return {'success': false, 'error': 'Authentication failed'};
    }

    print('[VeepaAudio] ✅ Login successful');

    // Step 4: Set client pointer in audio player
    _audioPlayer?.setClientPtr(clientPtr);

    return {
      'success': true,
      'clientPtr': clientPtr,
    };
  } catch (e) {
    print('[VeepaAudio] ❌ Exception in _connectWithCredentials: $e');
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}

Future<bool> _disconnect() async {
  print('[VeepaAudio] _disconnect called');

  // Stop audio if playing
  if (_audioPlayer != null) {
    await _audioPlayer!.dispose();
  }

  // Disconnect P2P client
  if (_clientPtr != null && _p2pApi != null) {
    try {
      await _p2pApi!.Client_Disconnect(_clientPtr!);
      print('[VeepaAudio] ✅ Client disconnected');
    } catch (e) {
      print('[VeepaAudio] ❌ Error disconnecting: $e');
    }
    _clientPtr = null;
  }

  return true;
}

// ===== Audio Control Methods =====

dynamic _setClientPtr(dynamic arguments) {
  if (arguments is int) {
    _clientPtr = arguments;
    _audioPlayer?.setClientPtr(arguments);
    print('[VeepaAudio] ✅ Client pointer set: $arguments');
    return null;
  } else {
    throw PlatformException(
      code: 'INVALID_ARGUMENT',
      message: 'setClientPtr expects int argument',
    );
  }
}

Future<bool> _startAudio() async {
  print('[VeepaAudio] _startAudio called');

  if (_audioPlayer == null) {
    print('[VeepaAudio] ❌ AudioPlayer not initialized');
    return false;
  }

  final result = await _audioPlayer!.startVoice();

  if (result) {
    print('[VeepaAudio] ✅ Audio started successfully');
  } else {
    print('[VeepaAudio] ❌ Audio start failed');
  }

  return result;
}

Future<bool> _stopAudio() async {
  print('[VeepaAudio] _stopAudio called');

  if (_audioPlayer == null) {
    print('[VeepaAudio] ❌ AudioPlayer not initialized');
    return false;
  }

  final result = await _audioPlayer!.stopVoice();

  if (result) {
    print('[VeepaAudio] ✅ Audio stopped successfully');
  } else {
    print('[VeepaAudio] ❌ Audio stop failed');
  }

  return result;
}

Future<bool> _setMute(dynamic arguments) async {
  print('[VeepaAudio] _setMute called with: $arguments');

  if (_audioPlayer == null) {
    print('[VeepaAudio] ❌ AudioPlayer not initialized');
    return false;
  }

  if (arguments is! bool) {
    throw PlatformException(
      code: 'INVALID_ARGUMENT',
      message: 'setMute expects bool argument',
    );
  }

  final result = await _audioPlayer!.setMute(arguments);

  if (result) {
    print('[VeepaAudio] ✅ Mute set to: $arguments');
  } else {
    print('[VeepaAudio] ❌ Set mute failed');
  }

  return result;
}
```

**Key adaptations**:
- ✅ Kept: Method channel pattern, flutterReady signal
- ✅ Kept: P2P connection (connectWithCredentials, disconnect)
- ✅ Kept: Audio control (startAudio, stopAudio, setMute)
- ❌ Removed: Video streaming, provisioning, discovery (800+ lines removed!)
- ✅ Enhanced: Comprehensive logging for debugging

**✅ Verification:**
```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

# 1. File updated
test -f lib/main.dart && echo "✅ main.dart exists"

# 2. Check for key method channel setup
grep "platform.setMethodCallHandler" lib/main.dart
grep "platform.invokeMethod('flutterReady')" lib/main.dart
# ✅ Expected: Both found

# 3. Check for audio methods
grep "_startAudio()" lib/main.dart
grep "_stopAudio()" lib/main.dart
grep "_setMute" lib/main.dart
# ✅ Expected: All three found

# 4. Verify video methods removed
! grep -q "startVideo" lib/main.dart && echo "✅ Video methods removed"
! grep -q "captureFrame" lib/main.dart && echo "✅ Frame capture removed"

# 5. Flutter analyze
flutter analyze lib/main.dart
# Expected: No errors (warnings about missing implementations are OK)
```

---

### ✅ Sub-Story 2.3 Complete Verification

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

# Run complete Flutter check
flutter pub get
flutter analyze

# ✅ Expected output:
# "Got dependencies!"
# "No issues found!" (or only minor warnings)
```

**Acceptance Criteria:**
- [ ] lib/main.dart updated with full method channel implementation
- [ ] Method channel name is 'com.veepatest/audio'
- [ ] flutterReady signal sent to iOS on startup
- [ ] connectWithCredentials method implemented
- [ ] Audio control methods (startAudio, stopAudio, setMute) implemented
- [ ] Video methods removed
- [ ] Comprehensive logging added
- [ ] Flutter analyze passes

---

---

## 🔧 Sub-Story 2.4: Copy Flutter Engine Manager

**Goal**: Copy FlutterEngineManager.swift to handle Flutter engine lifecycle and method channel communication

⏱️ **Estimated Time**: 25-30 minutes

### Analysis of Source Code

From `SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Services/Flutter/FlutterEngineManager.swift` (385 lines):

**Key sections discovered**:
- Lines 1-24: Class definition, singleton pattern, published properties
- Lines 25-63: Engine initialization and plugin registration
- Lines 64-104: VSTC diagnostics (for timeout investigation)
