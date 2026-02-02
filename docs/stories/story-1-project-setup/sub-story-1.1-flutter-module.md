# Sub-Story 1.1: Flutter Module Structure

**Goal**: Create minimal Flutter module with correct directory layout for P2P SDK plugin

**Estimated Time**: 20-25 minutes

---

## 📋 Analysis of Source Code

From `SciSymbioLens/flutter_module/veepa_camera/`:
- Has `pubspec.yaml` with dependencies
- Has `lib/main.dart` entry point
- Has `lib/sdk/` for P2P bindings
- Has nested plugin structure: `ios/.symlinks/plugins/vsdk/`

**What to adapt:**
- ✅ Copy pubspec structure, but remove video-related dependencies
- ✅ Create method channel setup in main.dart
- ✅ Prepare plugin directory structure
- ❌ Remove: video rendering, discovery, provisioning

---

## 🛠️ Implementation Steps

### Step 1.1.1: Create Module (5 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest

# Create Flutter module structure
mkdir -p flutter_module
cd flutter_module
flutter create --template=module veepa_audio
cd veepa_audio
```

**✅ Verification:**
```bash
# Should see Flutter module structure
ls -la
# Expected output:
# .android/
# .ios/
# lib/
# pubspec.yaml
# test/
```

---

### Step 1.1.2: Create pubspec.yaml (5 min)

**Adapt from**: `SciSymbioLens/flutter_module/veepa_camera/pubspec.yaml`

Create `flutter_module/veepa_audio/pubspec.yaml`:

```yaml
name: veepa_audio
description: Minimal Flutter module for Veepa camera audio testing
publish_to: 'none'

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # ADAPTED: Only ffi dependency for P2P SDK bindings
  ffi: ^2.0.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0

# ADAPTED: flutter block for plugin configuration
flutter:
  module:
    androidX: true
    androidPackage: com.veepatest.audio
    iosBundleIdentifier: com.veepatest.audio
```

**✅ Verification:**
```bash
flutter pub get
# Expected: Resolving dependencies... Got dependencies!
```

---

### Step 1.1.3: Create main.dart with Method Channel (10 min)

**Adapt from**: `SciSymbioLens/flutter_module/veepa_camera/lib/main.dart`

Key adaptations:
- Keep: Method channel setup, flutterReady signal
- Remove: Video widgets, state management
- Add: Audio-specific method handlers (startAudio, stopAudio, setMute)

Create `flutter_module/veepa_audio/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AudioTestApp());

class AudioTestApp extends StatefulWidget {
  const AudioTestApp({Key? key}) : super(key: key);

  @override
  State<AudioTestApp> createState() => _AudioTestAppState();
}

class _AudioTestAppState extends State<AudioTestApp> {
  // ADAPTED: Match SciSymbioLens channel name pattern
  static const platform = MethodChannel('com.veepatest/audio');

  int? _clientPtr;
  String _statusMessage = 'Flutter module initialized';

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
    _signalReady();
  }

  /// ADAPTED FROM: SciSymbioLens FlutterEngineManager communication pattern
  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      print('[Flutter] Method call received: ${call.method}');

      switch (call.method) {
        case 'setClientPtr':
          // Called by iOS when P2P connection succeeds
          final ptr = call.arguments as int;
          setState(() {
            _clientPtr = ptr;
            _statusMessage = 'Connected (clientPtr: $ptr)';
          });
          print('[Flutter] Audio player initialized with clientPtr: $ptr');
          return null;

        case 'startAudio':
          // Will be implemented in Story 2 with actual P2P SDK calls
          print('[Flutter] startAudio called (stub - will implement in Story 2)');
          setState(() => _statusMessage = 'Audio started (stub)');
          return 0; // Success

        case 'stopAudio':
          print('[Flutter] stopAudio called (stub - will implement in Story 2)');
          setState(() => _statusMessage = 'Audio stopped (stub)');
          return 0;

        case 'setMute':
          final muted = call.arguments as bool;
          print('[Flutter] setMute($muted) called (stub)');
          setState(() => _statusMessage = 'Mute: $muted (stub)');
          return 0;

        default:
          print('[Flutter] Unknown method: ${call.method}');
          throw MissingPluginException('Method ${call.method} not implemented');
      }
    });
  }

  /// ADAPTED FROM: SciSymbioLens FlutterEngineManager ready signal
  /// This is critical - iOS waits for this signal before calling methods
  Future<void> _signalReady() async {
    try {
      await platform.invokeMethod('flutterReady');
      print('[Flutter] ✅ Ready signal sent to iOS');
      setState(() => _statusMessage = 'Flutter ready');
    } catch (e) {
      print('[Flutter] ❌ Error signaling ready: $e');
      setState(() => _statusMessage = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veepa Audio Test',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mic,
                size: 64,
                color: Colors.white70,
              ),
              const SizedBox(height: 20),
              Text(
                'Audio Test Module',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _statusMessage,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              if (_clientPtr != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Client Ptr: $_clientPtr',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

**✅ Verification:**
```bash
# Check for syntax errors
flutter analyze lib/main.dart
# Expected: No issues found!
```

---

### Step 1.1.4: Create Plugin Directory Structure (5 min)

The P2P SDK (libVSTC.a) will live in a Flutter plugin structure:

```bash
cd flutter_module/veepa_audio

# Create plugin structure (matching SciSymbioLens layout)
mkdir -p ios/.symlinks/plugins/vsdk/ios/Classes

# Create placeholder file (will copy actual SDK in Story 2)
touch ios/.symlinks/plugins/vsdk/ios/Classes/.gitkeep

# Verify structure
tree ios/.symlinks/plugins/
# Expected:
# ios/.symlinks/plugins/
# └── vsdk/
#     └── ios/
#         └── Classes/
#             └── .gitkeep
```

**✅ Verification:**
```bash
ls -la ios/.symlinks/plugins/vsdk/ios/Classes/
# Should see .gitkeep file
```

---

## ✅ Sub-Story 1.1 Complete Verification

Run all checks:

```bash
cd flutter_module/veepa_audio

# 1. Dependencies resolved
flutter pub get
# ✅ Expected: "Got dependencies!"

# 2. No analysis issues
flutter analyze
# ✅ Expected: "No issues found!"

# 3. Plugin structure exists
ls -la ios/.symlinks/plugins/vsdk/ios/
# ✅ Expected: See Classes/ directory

# 4. Main.dart compiles
flutter build ios-framework --no-codesign --output=build/test
# ✅ Expected: BUILD SUCCEEDED (but no SDK yet, that's ok)
```

---

## 🎯 Acceptance Criteria

- [ ] Flutter module created with correct structure
- [ ] pubspec.yaml has ffi dependency
- [ ] main.dart implements method channel with flutterReady signal
- [ ] Plugin directory structure created
- [ ] `flutter pub get` succeeds
- [ ] `flutter analyze` shows no issues

---

## 🔗 Navigation

- → Next: [Sub-Story 1.2: SDK Plugin](sub-story-1.2-sdk-plugin.md)
- ↑ Story Overview: [README.md](README.md)
