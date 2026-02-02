# Sub-Story 2.2: Copy P2P Dart Bindings

**Goal**: Copy Dart FFI bindings that allow Dart code to call libVSTC.a functions

**Estimated Time**: 20-25 minutes

---

## 📋 Analysis of Source Code

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

---

## 🛠️ Implementation Steps

### Step 2.2.1: Create SDK Directory (2 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

mkdir -p lib/sdk
```

**✅ Verification:**
```bash
ls -la lib/sdk/
# Expected: Empty directory created
```

---

### Step 2.2.2: Copy P2P API Bindings (5 min)

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

---

### Step 2.2.3: Create Simplified Audio Player (15 min)

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

## ✅ Sub-Story 2.2 Complete Verification

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

# 1. SDK directory created
test -d lib/sdk && echo "✅ SDK directory exists"

# 2. P2P API files present
test -f lib/sdk/app_p2p_api.dart && echo "✅ app_p2p_api.dart"
test -f lib/sdk/app_dart.dart && echo "✅ app_dart.dart"
test -f lib/sdk/audio_player.dart && echo "✅ audio_player.dart"

# 3. Flutter analyze (should pass)
flutter analyze lib/sdk/
# Expected: No issues found (or only warnings about missing imports - OK for now)
```

---

## 🎯 Acceptance Criteria

- [ ] lib/sdk/ directory created
- [ ] app_p2p_api.dart copied (exact copy, ~500 lines)
- [ ] app_dart.dart copied (exact copy, ~200 lines)
- [ ] audio_player.dart created (adapted, ~150 lines)
- [ ] audio_player.dart has startVoice(), stopVoice(), setMute() methods
- [ ] audio_player.dart does NOT have video methods
- [ ] Flutter analyze shows no errors

---

## 🔗 Navigation

- ← Previous: [Sub-Story 2.1: Copy SDK Binary](sub-story-2.1-copy-sdk-binary.md)
- → Next: [Sub-Story 2.3: Main Dart](sub-story-2.3-main-dart.md)
- ↑ Story Overview: [README.md](README.md)
