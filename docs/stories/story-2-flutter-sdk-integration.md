# Story 2: Flutter SDK Integration and P2P Services

**Epic**: VeepaAudioTest - Minimal Audio Testing App
**Story**: Copy and integrate P2P SDK with Flutter bridges
**Estimated Time**: 1-1.5 hours

---

## 📋 Story Description

As a **developer**, I want to **integrate the Veepa P2P SDK and Flutter service layer** so that **the iOS app can establish P2P connections to the camera**.

---

## ✅ Acceptance Criteria

1. `libVSTC.a` (P2P SDK binary) is correctly integrated
2. `FlutterEngineManager.swift` is copied and compiles
3. `VSTCBridge.swift` is copied and compiles
4. `VeepaConnectionBridge.swift` is copied and compiles
5. Flutter plugin (`vsdk`) is registered correctly
6. Platform method channel communication works (ping test succeeds)
7. App can initialize Flutter engine without crashes

---

## 🔧 Implementation Steps

### Step 2.1: Copy P2P SDK Plugin (20 minutes)

The P2P SDK is distributed as a Flutter plugin called `vsdk`. Copy the entire plugin structure:

```bash
# From SciSymbioLens root
cd /Users/mpriessner/windsurf_repos/SciSymbioLens

# Copy vsdk plugin to VeepaAudioTest
cp -r flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk \
      ../VeepaAudioTest/flutter_module/veepa_audio/ios/.symlinks/plugins/

# Verify critical files exist
ls -lh ../VeepaAudioTest/flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/ios/libVSTC.a
```

**Expected Output**:
```
-rw-r--r--  1 user  staff   45M  libVSTC.a
```

**Create `flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/ios/vsdk.podspec`**:

```ruby
Pod::Spec.new do |s|
  s.name             = 'vsdk'
  s.version          = '1.0.0'
  s.summary          = 'Veepa P2P SDK for Flutter'
  s.description      = 'Native iOS bindings for VStarcam P2P SDK (libVSTC.a)'
  s.homepage         = 'https://veepa.com'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Veepa' => 'support@veepa.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.vendored_libraries = 'libVSTC.a'

  s.dependency 'Flutter'
  s.platform = :ios, '11.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
```

**Update `flutter_module/veepa_audio/pubspec.yaml`** to reference the plugin:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # P2P SDK plugin
  vsdk:
    path: ios/.symlinks/plugins/vsdk
```

**Rebuild Flutter frameworks with SDK**:
```bash
cd flutter_module/veepa_audio
flutter clean
flutter pub get
flutter build ios-framework --output=build/ios/framework

# Verify vsdk.xcframework is created
ls -lh build/ios/framework/Debug/vsdk.xcframework
```

---

### Step 2.2: Copy P2P SDK Dart Bindings (15 minutes)

Copy the Flutter SDK wrapper that provides Dart FFI bindings to libVSTC.a:

```bash
# Copy P2P API bindings
cp /Users/mpriessner/windsurf_repos/SciSymbioLens/flutter_module/veepa_camera/lib/sdk/app_p2p_api.dart \
   /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio/lib/sdk/

# Copy supporting Dart types
cp /Users/mpriessner/windsurf_repos/SciSymbioLens/flutter_module/veepa_camera/lib/sdk/app_dart.dart \
   /Users/mpriessner/windsurf_repos/VeepaAudioTest/flutter_module/veepa_audio/lib/sdk/
```

**Create simplified `lib/sdk/audio_player.dart`** (extract audio methods only):

```dart
import 'dart:ffi';
import 'app_p2p_api.dart';

/// Simplified audio player - only audio methods (no video)
class AudioPlayer {
  final int clientPtr;

  AudioPlayer(this.clientPtr);

  /// Start audio streaming from camera
  Future<int> startVoice() async {
    print('[AudioPlayer] Starting audio for clientPtr: $clientPtr');
    final result = AppP2PApi().App_SetStartVoice(clientPtr);
    print('[AudioPlayer] startVoice result: $result');
    return result;
  }

  /// Stop audio streaming
  Future<int> stopVoice() async {
    print('[AudioPlayer] Stopping audio for clientPtr: $clientPtr');
    final result = AppP2PApi().App_SetStopVoice(clientPtr);
    print('[AudioPlayer] stopVoice result: $result');
    return result;
  }

  /// Mute/unmute audio
  Future<int> setMute(bool muted) async {
    print('[AudioPlayer] Setting mute: $muted');
    final result = AppP2PApi().App_SetMute(clientPtr, muted ? 1 : 0);
    print('[AudioPlayer] setMute result: $result');
    return result;
  }

  /// Get current audio state (if SDK supports it)
  Future<bool> isAudioPlaying() async {
    // Note: SDK may not expose this, return cached state if needed
    return false; // Placeholder
  }
}
```

**Update `lib/main.dart`** to expose audio methods via method channel:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sdk/audio_player.dart';

void main() => runApp(const AudioTestApp());

class AudioTestApp extends StatefulWidget {
  const AudioTestApp({Key? key}) : super(key: key);

  @override
  State<AudioTestApp> createState() => _AudioTestAppState();
}

class _AudioTestAppState extends State<AudioTestApp> {
  static const platform = MethodChannel('com.veepatest/audio');

  AudioPlayer? _audioPlayer;
  int? _clientPtr;

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
    _signalReady();
  }

  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      print('[Flutter] Method call: ${call.method}');

      switch (call.method) {
        case 'setClientPtr':
          final ptr = call.arguments as int;
          _clientPtr = ptr;
          _audioPlayer = AudioPlayer(ptr);
          print('[Flutter] Audio player initialized with clientPtr: $ptr');
          return null;

        case 'startAudio':
          if (_audioPlayer == null) {
            throw PlatformException(code: 'NO_CLIENT', message: 'Not connected');
          }
          final result = await _audioPlayer!.startVoice();
          return result;

        case 'stopAudio':
          if (_audioPlayer == null) {
            throw PlatformException(code: 'NO_CLIENT', message: 'Not connected');
          }
          final result = await _audioPlayer!.stopVoice();
          return result;

        case 'setMute':
          final muted = call.arguments as bool;
          if (_audioPlayer == null) {
            throw PlatformException(code: 'NO_CLIENT', message: 'Not connected');
          }
          final result = await _audioPlayer!.setMute(muted);
          return result;

        default:
          throw MissingPluginException();
      }
    });
  }

  Future<void> _signalReady() async {
    try {
      await platform.invokeMethod('flutterReady');
      print('[Flutter] Ready signal sent to iOS');
    } catch (e) {
      print('[Flutter] Error signaling ready: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veepa Audio Test',
      home: Scaffold(
        appBar: AppBar(title: const Text('Audio Test (Flutter)')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Flutter Module Ready'),
              const SizedBox(height: 20),
              Text('Client Ptr: ${_clientPtr ?? "Not connected"}'),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

### Step 2.3: Copy iOS Flutter Services (30 minutes)

Copy the three critical Swift service files:

```bash
# Create Services directory
mkdir -p /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest/Services/Flutter

# Copy FlutterEngineManager
cp /Users/mpriessner/windsurf_repos/SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Services/Flutter/FlutterEngineManager.swift \
   /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest/Services/Flutter/

# Copy VSTCBridge
cp /Users/mpriessner/windsurf_repos/SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Services/VSTCBridge.swift \
   /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest/Services/

# Copy VeepaConnectionBridge
cp /Users/mpriessner/windsurf_repos/SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Services/Flutter/VeepaConnectionBridge.swift \
   /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest/Services/Flutter/
```

**Edit `FlutterEngineManager.swift`** - Update method channel name:

```swift
// Line 153-156: Update channel name to match Flutter
methodChannel = FlutterMethodChannel(
    name: "com.veepatest/audio",  // Changed from "com.scisymbiolens/veepa"
    binaryMessenger: messenger
)
```

**No changes needed** to `VSTCBridge.swift` or `VeepaConnectionBridge.swift` - they work as-is.

---

### Step 2.4: Update XcodeGen Configuration (10 minutes)

Update `ios/VeepaAudioTest/project.yml` to add the new Swift files:

```yaml
targets:
  VeepaAudioTest:
    type: application
    platform: iOS

    sources:
      - VeepaAudioTest
      - path: VeepaAudioTest/Services
        name: Services
        type: group

    # ... rest of configuration
```

**Regenerate Xcode project**:
```bash
cd ios/VeepaAudioTest
xcodegen generate
```

---

### Step 2.5: Rebuild and Test Integration (15 minutes)

```bash
# Rebuild Flutter frameworks (now with vsdk)
cd flutter_module/veepa_audio
flutter clean
flutter pub get
flutter build ios-framework --output=build/ios/framework

# Sync to iOS project
cd ../../ios/VeepaAudioTest
bash Scripts/sync-flutter-frameworks.sh

# Build iOS app
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

**Expected Output**:
```
** BUILD SUCCEEDED **
```

---

## 🧪 Testing & Verification

### Test 1: Flutter Frameworks Include SDK
```bash
cd flutter_module/veepa_audio/build/ios/framework/Debug
ls -lh vsdk.xcframework
```
✅ **Expected**: `vsdk.xcframework` directory exists (~45MB)

### Test 2: Xcode Project Links Frameworks
Open `VeepaAudioTest.xcodeproj` and verify:
- ✅ `Flutter.xcframework` in "Frameworks and Libraries"
- ✅ `vsdk.xcframework` in "Frameworks and Libraries"

### Test 3: Swift Services Compile
```bash
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```
✅ **Expected**: No compilation errors

### Test 4: Flutter Engine Initializes
Add to `ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @State private var statusMessage = "Initializing..."

    var body: some View {
        VStack(spacing: 20) {
            Text("Veepa Audio Test")
                .font(.largeTitle)
                .padding()

            Text(statusMessage)
                .foregroundColor(.gray)
                .padding()

            Button("Initialize Flutter") {
                initializeFlutter()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)

            Spacer()
        }
        .padding()
    }

    private func initializeFlutter() {
        Task {
            do {
                FlutterEngineManager.shared.initialize()
                try await FlutterEngineManager.shared.initializeAndWaitForReady(timeout: 10.0)
                statusMessage = "✅ Flutter Ready"

                // Test ping
                let pong = try await FlutterEngineManager.shared.ping()
                statusMessage += "\nPing: \(pong)"

            } catch {
                statusMessage = "❌ Error: \(error.localizedDescription)"
            }
        }
    }
}
```

Run app and tap "Initialize Flutter":
✅ **Expected**: Status shows "✅ Flutter Ready"

### Test 5: VSTCBridge Diagnostics
Add to `initializeFlutter()`:

```swift
// After Flutter ready
let diagnostics = VSTCBridge.shared.runDiagnostics()
print("[Test] Found \(diagnostics.foundCount)/\(diagnostics.totalCount) SDK symbols")
```

✅ **Expected**: Console shows discovered SDK symbols (e.g., "✅ cs2p2p_gSessAliveSec")

---

## 📊 Deliverables

After completing this story:

- [x] `flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/` - P2P SDK plugin
- [x] `flutter_module/veepa_audio/lib/sdk/app_p2p_api.dart` - P2P FFI bindings
- [x] `flutter_module/veepa_audio/lib/sdk/audio_player.dart` - Audio streaming API
- [x] `ios/VeepaAudioTest/VeepaAudioTest/Services/Flutter/FlutterEngineManager.swift`
- [x] `ios/VeepaAudioTest/VeepaAudioTest/Services/VSTCBridge.swift`
- [x] `ios/VeepaAudioTest/VeepaAudioTest/Services/Flutter/VeepaConnectionBridge.swift`
- [x] App builds successfully with all frameworks linked
- [x] Flutter engine initializes and responds to ping
- [x] VSTCBridge can access SDK symbols

---

## 🚨 Common Issues

### Issue 1: libVSTC.a not found during build
**Error**: `library not found for -lVSTC`
**Fix**:
1. Verify `libVSTC.a` exists in `flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/ios/`
2. Rebuild Flutter frameworks: `flutter build ios-framework`
3. Re-sync: `bash Scripts/sync-flutter-frameworks.sh`

### Issue 2: VsdkPlugin registration fails
**Error**: `Failed to get registrar for VsdkPlugin`
**Fix**: Ensure `vsdk.podspec` is correctly configured and `flutter pub get` was run

### Issue 3: Flutter not ready timeout
**Error**: `Timeout waiting for Flutter ready signal`
**Fix**: Check Flutter console logs - `flutterReady` method call may be failing

---

## ⏭️ Next Story

**Story 3**: Camera Connection and Audio Streaming

This story adds:
- Manual UID entry for camera connection
- P2P connection establishment
- Audio start/stop functionality
