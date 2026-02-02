# Code Reuse Strategy - VeepaAudioTest

**Purpose**: Document exactly what code to copy from SciSymbioLens and what to simplify

**Source**: `/Users/mpriessner/windsurf_repos/SciSymbioLens`

---

## 🎯 Reuse Philosophy

- **Copy**: Core P2P SDK integration (camera connection, audio streaming)
- **Simplify**: Remove video, Gemini, cloud, and UI complexity
- **Estimated LOC**: ~500 lines total (vs 10,000+ in SciSymbioLens)

---

## 📋 Copy Matrix

### ✅ COPY EXACTLY (No Changes)

These files work correctly and handle critical P2P/audio functionality:

#### iOS Swift Files

| File | Source Path | Destination | LOC | Purpose |
|------|-------------|-------------|-----|---------|
| **FlutterEngineManager.swift** | `ios/SciSymbioLens/SciSymbioLens/Services/Flutter/FlutterEngineManager.swift` | `ios/VeepaAudioTest/VeepaAudioTest/Services/` | 385 | Flutter engine lifecycle, platform channels, P2P credential refresh |
| **VSTCBridge.swift** | `ios/SciSymbioLens/SciSymbioLens/Services/VSTCBridge.swift` | `ios/VeepaAudioTest/VeepaAudioTest/Services/` | 408 | Low-level SDK symbol access, session timeout configuration, keep-alive |
| **VeepaConnectionBridge.swift** | `ios/SciSymbioLens/SciSymbioLens/Services/Flutter/VeepaConnectionBridge.swift` | `ios/VeepaAudioTest/VeepaAudioTest/Services/` | ~200 | Connection state management, reconnection logic |

**Why Copy Exactly**:
- These files handle P2P SDK communication at the lowest level
- Changing them risks breaking audio functionality
- They're already debugged and tested

#### Flutter Dart Files

| File | Source Path | Destination | LOC | Purpose |
|------|-------------|-------------|-----|---------|
| **app_p2p_api.dart** | `flutter_module/veepa_camera/lib/sdk/app_p2p_api.dart` | `flutter_module/veepa_audio/lib/sdk/` | ~500 | P2P SDK FFI bindings (all native functions) |

**Why Copy Exactly**:
- Native function signatures must match SDK exactly
- Any change breaks SDK communication

---

### ✂️ COPY AND SIMPLIFY (Remove Video Logic)

These files contain both video and audio logic - extract only audio parts:

#### Flutter Dart Files

| File | Source Path | Lines to Keep | Lines to Remove | New Name |
|------|-------------|---------------|-----------------|----------|
| **app_player.dart** | `flutter_module/veepa_camera/lib/sdk/app_player.dart` | startVoice, stopVoice, setMute, clientPtr | Video rendering, texture, videoController, playVideo, stopVideo | **audio_player.dart** |
| **veepa_connection_manager.dart** | `flutter_module/veepa_camera/lib/services/veepa_connection_manager.dart` | connect, disconnect, getClientPtr | Video frame handling, provisioning, discovery | **audio_connection_manager.dart** |

#### Simplification Strategy

**app_player.dart → audio_player.dart**:
```dart
// KEEP: Audio methods
class AudioPlayer {
  final int clientPtr;

  Future<void> startVoice() async { ... }
  Future<void> stopVoice() async { ... }
  Future<void> setMute(bool muted) async { ... }
}

// REMOVE: All video methods
// - playVideo()
// - stopVideo()
// - VideoSourceType enum
// - Texture rendering
// - Frame callbacks
```

**veepa_connection_manager.dart → audio_connection_manager.dart**:
```dart
// KEEP: Connection logic
class AudioConnectionManager {
  Future<int?> connect(String uid, String serviceParam) async { ... }
  Future<void> disconnect() async { ... }
  int? get clientPtr => ...;
}

// REMOVE: Video frame events, provisioning, discovery
```

**Estimated LOC After Simplification**:
- `audio_player.dart`: ~100 lines (from 500+)
- `audio_connection_manager.dart`: ~150 lines (from 400+)

---

### 🔧 COPY BUILD CONFIGURATION (Essential)

These files ensure Flutter frameworks are linked correctly:

| File | Source Path | Destination | Purpose |
|------|-------------|-------------|---------|
| **sync-flutter-frameworks.sh** | `ios/SciSymbioLens/Scripts/sync-flutter-frameworks.sh` | `ios/VeepaAudioTest/Scripts/` | Copies Flutter.xcframework and plugins to Xcode project |
| **project.yml** (partial) | `ios/SciSymbioLens/project.yml` | `ios/VeepaAudioTest/project.yml` | XcodeGen config for framework linking (Flutter, libVSTC.a) |

**Critical Build Steps**:
1. Flutter must be built first: `cd flutter_module/veepa_audio && flutter build ios-framework`
2. Frameworks must be synced: `bash Scripts/sync-flutter-frameworks.sh`
3. Xcode project must be generated: `xcodegen generate`

---

### 📦 COPY BINARIES (Required for P2P SDK)

These are pre-compiled binaries from the Veepa SDK:

| File | Source Path | Destination | Purpose |
|------|-------------|-------------|---------|
| **libVSTC.a** | `flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/libVSTC.a` | `flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/ios/` | P2P SDK static library (audio + video) |
| **VsdkPlugin.m** | `flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk/ios/Classes/` | `flutter_module/veepa_audio/ios/.symlinks/plugins/vsdk/ios/Classes/` | Flutter plugin registration for SDK |

**Note**: The SDK is monolithic (audio + video in one library). We cannot extract just audio.

---

### 🆕 CREATE NEW (Simplified Versions)

These are new, minimal files for the test app:

#### iOS Swift Files

| File | Destination | LOC | Purpose |
|------|-------------|-----|---------|
| **ContentView.swift** | `ios/VeepaAudioTest/VeepaAudioTest/Views/` | ~150 | Simple UI: Connect button, Start/Stop Audio, Mute, Debug log |
| **VeepaAudioTestApp.swift** | `ios/VeepaAudioTest/VeepaAudioTest/` | ~50 | App entry point, Flutter engine initialization |

**ContentView.swift Structure**:
```swift
struct ContentView: View {
    @State private var uid: String = ""
    @State private var isConnected = false
    @State private var isAudioPlaying = false
    @State private var debugLog: [String] = []

    var body: some View {
        VStack {
            // Connection
            TextField("Camera UID", text: $uid)
            Button("Connect") { connect() }

            // Audio Controls
            Button(isAudioPlaying ? "Stop Audio" : "Start Audio") { toggleAudio() }
            Button("Mute") { mute() }

            // Debug Log
            ScrollView {
                Text(debugLog.joined(separator: "\n"))
            }
        }
    }
}
```

#### Flutter Dart Files

| File | Destination | LOC | Purpose |
|------|-------------|-----|---------|
| **main.dart** | `flutter_module/veepa_audio/lib/` | ~100 | Entry point, method channel setup |
| **audio_manager.dart** | `flutter_module/veepa_audio/lib/services/` | ~200 | High-level audio streaming API (wraps AudioPlayer) |

---

### ❌ DO NOT COPY (Excluded Complexity)

These files are NOT needed for audio-only testing:

#### iOS Swift Files (Excluded)
- ❌ All ViewModels (CameraViewModel, GeminiViewModel, ChatViewModel, etc.)
- ❌ Gemini services (GeminiWebSocketService, GeminiSessionManager)
- ❌ Camera capture (CameraManager, LocalCameraSource, CameraSourceManager)
- ❌ Cloud storage (SupabaseStorageService, UploadQueue)
- ❌ Video views (VeepaPreviewView, CameraPreviewView)
- ❌ Provisioning UI (VeepaProvisioningView, VeepaProvisioningViewModel)

#### Flutter Dart Files (Excluded)
- ❌ Video rendering widgets
- ❌ Frame processing
- ❌ Discovery/provisioning flows
- ❌ Any state management (Provider, Riverpod)

**Justification**: These add 9,000+ lines of code unrelated to audio testing.

---

## 🔀 Migration Path

### Step 1: Copy Core Services (30 minutes)
```bash
# From SciSymbioLens root
cp ios/SciSymbioLens/SciSymbioLens/Services/Flutter/FlutterEngineManager.swift \
   ../VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest/Services/

cp ios/SciSymbioLens/SciSymbioLens/Services/VSTCBridge.swift \
   ../VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest/Services/

cp ios/SciSymbioLens/SciSymbioLens/Services/Flutter/VeepaConnectionBridge.swift \
   ../VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest/Services/
```

### Step 2: Copy Flutter SDK Bindings (15 minutes)
```bash
cp flutter_module/veepa_camera/lib/sdk/app_p2p_api.dart \
   ../VeepaAudioTest/flutter_module/veepa_audio/lib/sdk/
```

### Step 3: Simplify Flutter Player (45 minutes)
```bash
# Copy and manually edit to remove video logic
cp flutter_module/veepa_camera/lib/sdk/app_player.dart \
   ../VeepaAudioTest/flutter_module/veepa_audio/lib/sdk/audio_player.dart

# Edit audio_player.dart:
# - Remove all video-related enums (VideoSourceType)
# - Remove playVideo, stopVideo methods
# - Keep only: startVoice, stopVoice, setMute
```

### Step 4: Copy Build Configuration (20 minutes)
```bash
cp ios/SciSymbioLens/Scripts/sync-flutter-frameworks.sh \
   ../VeepaAudioTest/ios/VeepaAudioTest/Scripts/

# Copy relevant parts of project.yml (framework linking section)
```

### Step 5: Copy SDK Binaries (10 minutes)
```bash
# After building Flutter module in SciSymbioLens
cp -r flutter_module/veepa_camera/ios/.symlinks/plugins/vsdk \
      ../VeepaAudioTest/flutter_module/veepa_audio/ios/.symlinks/plugins/
```

### Step 6: Create New UI (1 hour)
- Write `ContentView.swift` from scratch
- Write `VeepaAudioTestApp.swift` entry point
- Write simplified `main.dart` for Flutter

**Total Estimated Time**: 2.5-3 hours

---

## 📊 Code Size Comparison

| Component | SciSymbioLens | VeepaAudioTest | Reduction |
|-----------|---------------|----------------|-----------|
| iOS Swift | ~8,000 LOC | ~1,200 LOC | -85% |
| Flutter Dart | ~2,500 LOC | ~600 LOC | -76% |
| **Total** | **~10,500 LOC** | **~1,800 LOC** | **-83%** |

---

## 🧪 Verification Checklist

After copying, verify:

- [ ] FlutterEngineManager compiles without errors
- [ ] VSTCBridge resolves SDK symbols (test with diagnostics)
- [ ] Flutter engine initializes and responds to ping
- [ ] Connection to camera succeeds (get valid clientPtr)
- [ ] startVoice() is callable (may fail with error -50, but must be callable)

---

## 📚 Key Dependencies

The copied code has these dependencies:

### iOS (Swift)
- `import Flutter` - Flutter framework
- `import Darwin` - For dlsym symbol resolution
- `import AVFoundation` - For AVAudioSession

### Flutter (Dart)
- `import 'dart:ffi'` - For native SDK calls
- `import 'package:flutter/services.dart'` - For method channels

---

## 🎯 Success Metrics

**Code Reuse Success** means:
- ✅ App compiles and runs
- ✅ Can connect to camera (get clientPtr)
- ✅ Can call startVoice() (even if it returns error -50)
- ✅ Debug logs show detailed audio session state

**Code Reuse Failure** means:
- ❌ Compilation errors due to missing dependencies
- ❌ Crashes when calling Flutter methods
- ❌ Cannot establish P2P connection

---

**Next Step**: See `docs/PROJECT_PLAN.md` for step-by-step implementation instructions.
