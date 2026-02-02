# Sub-Story 2.3: Update Main Dart Entry Point

**Goal**: Update lib/main.dart to handle audio method calls from iOS

**Estimated Time**: 25-30 minutes

---

## 📋 Analysis of Source Code

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

---

## 🛠️ Implementation Steps

### Step 2.3.1: Read Existing main.dart (3 min)

First, let's see what we created in Sub-Story 1.1:

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio
cat lib/main.dart
```

We created a placeholder with UI. Now we'll replace it with a headless implementation focused on P2P SDK integration.

---

### Step 2.3.2: Create Full main.dart (20 min)

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

---

### Step 2.3.3: Verify Implementation (5 min)

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

## ✅ Sub-Story 2.3 Complete Verification

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio

# Run complete Flutter check
flutter pub get
flutter analyze

# ✅ Expected output:
# "Got dependencies!"
# "No issues found!" (or only minor warnings)
```

---

## 🎯 Acceptance Criteria

- [ ] lib/main.dart updated with full method channel implementation
- [ ] Method channel name is 'com.veepatest/audio'
- [ ] flutterReady signal sent to iOS on startup
- [ ] connectWithCredentials method implemented
- [ ] Audio control methods (startAudio, stopAudio, setMute) implemented
- [ ] Video methods removed
- [ ] Comprehensive logging added
- [ ] Flutter analyze passes

---

## 🔗 Navigation

- ← Previous: [Sub-Story 2.2: Dart Bindings](sub-story-2.2-dart-bindings.md)
- → Next: Sub-Story 2.4 (Coming soon)
- ↑ Story Overview: [README.md](README.md)
