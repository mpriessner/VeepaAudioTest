# Minimal Audio Test App - Build Instructions

**Purpose**: Create a stripped-down iOS app to test ONLY camera audio streaming (no video, no Gemini, no complex UI)

**Goal**: Determine if P2P SDK audio playback works at all on iOS

**Estimated Time**: 2-4 hours

---

## 🎯 PROJECT SCOPE

### **What to Include** ✅
- Camera onboarding (QR code scan or manual UID entry)
- P2P connection to camera
- **Audio streaming ONLY** (no video)
- Basic UI: Connect button, Audio Start/Stop, Mute button
- Audio session configuration testing
- Logging for debugging

### **What to Exclude** ❌
- Video streaming
- Video rendering/display
- Gemini AI integration
- Chat interface
- Cloud storage
- Complex navigation
- Settings screens
- Multiple camera support

---

## 📁 PROJECT STRUCTURE

```
AudioTestApp/
├── ios/
│   └── AudioTestApp/
│       ├── App/
│       │   └── AudioTestAppApp.swift          # SwiftUI entry point
│       ├── Views/
│       │   ├── ContentView.swift              # Main UI (Connect + Audio controls)
│       │   └── OnboardingView.swift           # Camera UID entry
│       ├── Services/
│       │   ├── Audio/
│       │   │   └── CameraAudioService.swift   # Audio session management
│       │   └── Flutter/
│       │       ├── FlutterEngineManager.swift # Flutter bridge
│       │       └── VSTCBridge.swift           # P2P SDK bridge
│       ├── VeepaSDK/                          # Copy from SciSymbioLens
│       │   ├── libVSTC.a
│       │   ├── VsdkPlugin.h/m
│       │   └── (other SDK files)
│       └── Resources/
│           └── Info.plist
│
└── flutter_module/
    └── audio_test/
        └── lib/
            ├── main.dart                      # Minimal Flutter app
            └── services/
                └── audio_connection_manager.dart  # P2P audio connection
```

---

## 🚀 STEP-BY-STEP IMPLEMENTATION

### **STEP 1: Copy Core Files from SciSymbioLens** (30 min)

Copy these files/folders from `/Users/mpriessner/windsurf_repos/SciSymbioLens/`:

#### **iOS Files to Copy:**
```bash
# Create new project directory
mkdir -p AudioTestApp/ios/AudioTestApp

# Copy P2P SDK
cp -r SciSymbioLens/ios/SciSymbioLens/VeepaSDK AudioTestApp/ios/AudioTestApp/

# Copy Flutter integration services
cp -r SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Services/Flutter AudioTestApp/ios/AudioTestApp/Services/

# Copy audio service (if exists - from your Solution 1 implementation)
cp -r SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Services/Audio AudioTestApp/ios/AudioTestApp/Services/

# Copy VSTCBridge
cp SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Services/VSTCBridge.swift AudioTestApp/ios/AudioTestApp/Services/

# Copy Info.plist (has required permissions)
cp SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Resources/Info.plist AudioTestApp/ios/AudioTestApp/Resources/
```

#### **Flutter Module to Copy:**
```bash
# Create Flutter module
mkdir -p AudioTestApp/flutter_module/audio_test

# Copy essential files from SciSymbioLens Flutter module
cp SciSymbioLens/flutter_module/veepa_camera/lib/services/veepa_connection_manager.dart \
   AudioTestApp/flutter_module/audio_test/lib/services/audio_connection_manager.dart

# Copy SDK bindings
cp -r SciSymbioLens/flutter_module/veepa_camera/lib/sdk AudioTestApp/flutter_module/audio_test/lib/

# Copy pubspec.yaml and modify
cp SciSymbioLens/flutter_module/veepa_camera/pubspec.yaml \
   AudioTestApp/flutter_module/audio_test/pubspec.yaml
```

---

### **STEP 2: Simplify Flutter Module** (1 hour)

**File**: `AudioTestApp/flutter_module/audio_test/lib/services/audio_connection_manager.dart`

Strip down `veepa_connection_manager.dart` to ONLY audio:

```dart
import 'package:flutter/foundation.dart';
import '../sdk/app_p2p_api.dart';
import '../sdk/app_player.dart';

/// MINIMAL audio-only connection manager
/// Based on VeepaConnectionManager but with video code removed
class AudioConnectionManager extends ChangeNotifier {
  final AppP2PApi _p2pApi = AppP2PApi();
  AppPlayerController? _playerController;

  int? _clientPtr;
  bool _isConnected = false;
  bool _audioStreamingActive = false;
  bool _audioMuted = false;

  bool get isConnected => _isConnected;
  bool get audioStreamingActive => _audioStreamingActive;
  bool get audioMuted => _audioMuted;

  /// Connect to camera (P2P only, no video)
  Future<bool> connect({
    required String cameraUid,
    required String clientId,
    required String serviceParam,
    String? password,
  }) async {
    try {
      debugPrint('[AudioTest] 🔌 Connecting to camera: $cameraUid');

      // Initialize P2P SDK
      await _p2pApi.init(serviceParam);

      // Connect to camera
      _clientPtr = await _p2pApi.connect(
        clientId: clientId,
        password: password ?? 'admin',
        connectType: 126, // P2P mode
      );

      if (_clientPtr == null || _clientPtr! <= 0) {
        debugPrint('[AudioTest] ❌ Connection failed');
        return false;
      }

      _isConnected = true;
      debugPrint('[AudioTest] ✅ Connected! ClientPtr: $_clientPtr');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[AudioTest] ❌ Connection error: $e');
      return false;
    }
  }

  /// Start AUDIO ONLY (no video)
  Future<bool> startAudio() async {
    if (!_isConnected || _clientPtr == null) {
      debugPrint('[AudioTest] ❌ Not connected');
      return false;
    }

    try {
      debugPrint('[AudioTest] 🎵 Starting audio streaming...');

      // Create player controller (for audio decoding)
      _playerController = AppPlayerController();

      // Create player with audio rate
      await _playerController!.create(
        source: _clientPtr!,
        audioRate: 8000, // 8kHz audio
        // Note: We're NOT calling play() - no video needed
      );

      // Set audio channel to receive mode
      await _playerController!.setVoiceChannel(2); // P2P_AUDIO_CHANNEL

      // Start audio playback
      final result = await _playerController!.startVoice();

      if (result) {
        _audioStreamingActive = true;
        debugPrint('[AudioTest] ✅ Audio streaming started');
        notifyListeners();
        return true;
      } else {
        debugPrint('[AudioTest] ❌ startVoice() returned false');
        return false;
      }
    } catch (e) {
      debugPrint('[AudioTest] ❌ Audio start error: $e');
      return false;
    }
  }

  /// Stop audio streaming
  Future<void> stopAudio() async {
    if (_playerController != null && _audioStreamingActive) {
      await _playerController!.stopVoice();
      _audioStreamingActive = false;
      _audioMuted = false;
      debugPrint('[AudioTest] 🔇 Audio stopped');
      notifyListeners();
    }
  }

  /// Toggle mute
  Future<void> toggleMute() async {
    if (!_audioStreamingActive || _playerController == null) return;

    if (_audioMuted) {
      await _playerController!.startVoice();
      _audioMuted = false;
      debugPrint('[AudioTest] 🔊 Unmuted');
    } else {
      await _playerController!.stopVoice();
      _audioMuted = true;
      debugPrint('[AudioTest] 🔇 Muted');
    }
    notifyListeners();
  }

  /// Disconnect
  Future<void> disconnect() async {
    await stopAudio();

    if (_playerController != null) {
      _playerController!.dispose();
      _playerController = null;
    }

    if (_clientPtr != null) {
      await _p2pApi.disconnect(_clientPtr!);
      _clientPtr = null;
    }

    _isConnected = false;
    debugPrint('[AudioTest] 🔌 Disconnected');
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
```

**File**: `AudioTestApp/flutter_module/audio_test/lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/audio_connection_manager.dart';

void main() {
  runApp(const AudioTestApp());
}

class AudioTestApp extends StatefulWidget {
  const AudioTestApp({Key? key}) : super(key: key);

  @override
  State<AudioTestApp> createState() => _AudioTestAppState();
}

class _AudioTestAppState extends State<AudioTestApp> {
  final AudioConnectionManager _audioManager = AudioConnectionManager();
  static const MethodChannel _channel = MethodChannel('com.audiotest/audio');

  @override
  void initState() {
    super.initState();
    // Signal to iOS that Flutter is ready
    _channel.invokeMethod('flutterReady');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Test',
      home: Scaffold(
        appBar: AppBar(title: const Text('P2P Audio Test')),
        body: Center(
          child: Text('Audio Test Module (Headless)'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioManager.dispose();
    super.dispose();
  }
}
```

---

### **STEP 3: Create iOS SwiftUI Interface** (1 hour)

**File**: `AudioTestApp/ios/AudioTestApp/App/AudioTestAppApp.swift`

```swift
import SwiftUI
import AVFoundation

@main
struct AudioTestAppApp: App {
    init() {
        // Pre-initialize audio session (Solution 5 from TECHNICAL_SOLUTIONS.md)
        preInitializeAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func preInitializeAudioSession() {
        print("[App] 🎵 Pre-initializing audio session...")

        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            try audioSession.setPreferredSampleRate(8000)

            print("[App] ✅ Audio session pre-initialized")
        } catch {
            print("[App] ⚠️ Pre-initialization failed: \(error)")
        }
    }
}
```

**File**: `AudioTestApp/ios/AudioTestApp/Views/ContentView.swift`

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AudioTestViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Camera Info Section
                GroupBox(label: Label("Camera", systemImage: "video")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("UID:")
                            TextField("Camera UID", text: $viewModel.cameraUid)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                        }

                        HStack {
                            Text("Password:")
                            SecureField("Password", text: $viewModel.password)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding()

                // Connection Status
                HStack {
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    Text(viewModel.isConnected ? "Connected" : "Disconnected")
                        .font(.headline)
                }

                // Connect Button
                Button(action: {
                    if viewModel.isConnected {
                        viewModel.disconnect()
                    } else {
                        viewModel.connect()
                    }
                }) {
                    Label(
                        viewModel.isConnected ? "Disconnect" : "Connect",
                        systemImage: viewModel.isConnected ? "antenna.radiowaves.left.and.right.slash" : "antenna.radiowaves.left.and.right"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isConnected ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isConnecting)
                .padding(.horizontal)

                Divider()

                // Audio Controls (only when connected)
                if viewModel.isConnected {
                    VStack(spacing: 20) {
                        // Audio Status
                        HStack {
                            Image(systemName: viewModel.audioStreamingActive ? "speaker.wave.3.fill" : "speaker.slash.fill")
                                .foregroundColor(viewModel.audioStreamingActive ? .green : .gray)
                            Text(viewModel.audioStreamingActive ? "Audio Active" : "Audio Stopped")
                                .font(.headline)
                        }

                        // Start/Stop Audio Button
                        Button(action: {
                            if viewModel.audioStreamingActive {
                                viewModel.stopAudio()
                            } else {
                                viewModel.startAudio()
                            }
                        }) {
                            Label(
                                viewModel.audioStreamingActive ? "Stop Audio" : "Start Audio",
                                systemImage: viewModel.audioStreamingActive ? "stop.fill" : "play.fill"
                            )
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.audioStreamingActive ? Color.orange : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)

                        // Mute Button (only when audio active)
                        if viewModel.audioStreamingActive {
                            Button(action: {
                                viewModel.toggleMute()
                            }) {
                                Label(
                                    viewModel.audioMuted ? "Unmute" : "Mute",
                                    systemImage: viewModel.audioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
                                )
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(viewModel.audioMuted ? Color.gray : Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                Spacer()

                // Debug Logs
                ScrollView {
                    Text(viewModel.debugLog)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 150)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding()
            }
            .navigationTitle("P2P Audio Test")
        }
    }
}

// MARK: - ViewModel

@MainActor
class AudioTestViewModel: ObservableObject {
    @Published var cameraUid = "OKB0379853SNLJ" // Default test camera
    @Published var password = "888888"
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var audioStreamingActive = false
    @Published var audioMuted = false
    @Published var debugLog = ""

    private let flutterManager = FlutterEngineManager.shared

    init() {
        // Initialize Flutter engine
        flutterManager.initialize()
        log("Flutter engine initialized")
    }

    func connect() {
        isConnecting = true
        log("🔌 Connecting to \(cameraUid)...")

        Task {
            do {
                // Wait for Flutter ready
                try await flutterManager.initializeAndWaitForReady()

                // Call Flutter to connect
                let result = await flutterManager.invoke("connect", arguments: [
                    "cameraUid": cameraUid,
                    "password": password
                ])

                if let success = result as? Bool, success {
                    isConnected = true
                    log("✅ Connected successfully!")
                } else {
                    log("❌ Connection failed")
                }
            } catch {
                log("❌ Error: \(error.localizedDescription)")
            }

            isConnecting = false
        }
    }

    func disconnect() {
        Task {
            await flutterManager.invoke("disconnect")
            isConnected = false
            audioStreamingActive = false
            audioMuted = false
            log("🔌 Disconnected")
        }
    }

    func startAudio() {
        log("🎵 Starting audio...")

        Task {
            let result = await flutterManager.invoke("startAudio")

            if let success = result as? Bool, success {
                audioStreamingActive = true
                log("✅ Audio started!")
            } else {
                log("❌ Audio start failed")
            }
        }
    }

    func stopAudio() {
        Task {
            await flutterManager.invoke("stopAudio")
            audioStreamingActive = false
            audioMuted = false
            log("🔇 Audio stopped")
        }
    }

    func toggleMute() {
        Task {
            await flutterManager.invoke("toggleMute")
            audioMuted.toggle()
            log(audioMuted ? "🔇 Muted" : "🔊 Unmuted")
        }
    }

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugLog += "[\(timestamp)] \(message)\n"
        print("[AudioTest] \(message)")
    }
}
```

---

### **STEP 4: Configure Xcode Project** (30 min)

**File**: `AudioTestApp/ios/AudioTestApp/project.yml` (XcodeGen)

```yaml
name: AudioTestApp
options:
  bundleIdPrefix: com.yourcompany
  deploymentTarget:
    iOS: 17.0

targets:
  AudioTestApp:
    type: application
    platform: iOS
    sources:
      - AudioTestApp
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.yourcompany.audiotestapp
      INFOPLIST_FILE: AudioTestApp/Resources/Info.plist
      SWIFT_VERSION: 5.9
    dependencies:
      - framework: Flutter/Debug/Flutter.xcframework
        embed: true
      - sdk: AVFoundation.framework
    preBuildScripts:
      - name: Build Flutter Module
        script: |
          cd ../flutter_module/audio_test
          flutter build ios-framework --output=../../ios/AudioTestApp/Flutter/Debug
```

**File**: `AudioTestApp/ios/AudioTestApp/Resources/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSMicrophoneUsageDescription</key>
    <string>AudioTestApp needs microphone access to test camera audio streaming</string>
    <key>NSCameraUsageDescription</key>
    <string>AudioTestApp needs camera access for QR code scanning</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>AudioTestApp needs local network access to connect to your camera</string>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
</plist>
```

---

### **STEP 5: Build & Test** (30 min)

```bash
# Navigate to iOS folder
cd AudioTestApp/ios/AudioTestApp

# Generate Xcode project
xcodegen generate

# Build Flutter module
cd ../../flutter_module/audio_test
flutter build ios-framework --output=../../ios/AudioTestApp/Flutter/Debug

# Open Xcode
cd ../../ios/AudioTestApp
open AudioTestApp.xcodeproj

# Build and run on device
# (Use Cmd+R in Xcode)
```

---

## 🧪 TESTING PROCEDURE

### **Test 1: Baseline (No Audio Config)**
1. Run app on physical iPhone
2. Enter camera UID: `OKB0379853SNLJ`
3. Tap "Connect"
4. Wait for green "Connected" status
5. Tap "Start Audio"
6. **Check logs for error -50**
7. **Listen for audio from camera**

**Expected Result**: Error -50 occurs, no audio

---

### **Test 2: With Solution 5 (Pre-Initialize)**
Already implemented in `AudioTestAppApp.swift`

1. Run app
2. Connect to camera
3. Start audio
4. **Check if error -50 is gone**
5. **Listen for audio**

**Expected Result**: May fix error -50, or may still fail

---

### **Test 3: Add Solution 1 (Method Swizzling)**
If Test 2 fails:

1. Copy `AVAudioSessionInterceptor.swift` from `TECHNICAL_SOLUTIONS.md`
2. Add to `FlutterEngineManager.registerPlugins()`:
   ```swift
   AVAudioSessionInterceptor.install()
   ```
3. Rebuild and test
4. **Check logs for interceptor messages**
5. **Listen for audio**

**Expected Result**: Error -50 should be caught and fixed by interceptor

---

## 📊 SUCCESS CRITERIA

### **Minimum Success** ✅
- [ ] App connects to camera (green status)
- [ ] "Start Audio" button executes without crash
- [ ] No error -50 in logs
- [ ] Logs show: `voice=VoiceStatus.PLAY`

### **Full Success** ✅✅✅
- [ ] All of the above PLUS:
- [ ] **Hear audio from camera on iPhone speaker**
- [ ] Mute/unmute works
- [ ] Audio continues for >5 minutes without disconnect

### **Failure Indicators** ❌
- [ ] Error -50 still occurs despite interceptor
- [ ] No audio plays even when `voice=VoiceStatus.PLAY`
- [ ] App crashes when starting audio
- [ ] Connection drops immediately

---

## 🎯 WHAT THIS TEST WILL PROVE

### **If Audio Works** ✅
**Conclusion**: SDK audio playback IS functional on iOS
**Action**: Copy working configuration back to SciSymbioLens
**Root Cause**: Main app has some conflict (Gemini voice? Video rendering?)

### **If Audio Still Fails** ❌
**Conclusion**: SDK audio playback is broken on iOS
**Action**:
1. Contact SDK vendor with minimal reproducible case
2. Implement Solution 4 (AudioUnit with custom decoder)
3. OR ship video-only mode

---

## 📝 DELIVERABLES

After building and testing, provide:

1. **Test Results**:
   ```markdown
   ## AudioTestApp Results

   ### Test 1 (Baseline)
   - Connection: [Success/Fail]
   - Error -50: [Yes/No]
   - Audio Plays: [Yes/No]

   ### Test 2 (Pre-Initialize)
   - Error -50: [Yes/No]
   - Audio Plays: [Yes/No]

   ### Test 3 (Swizzling)
   - Interceptor Active: [Yes/No]
   - Fallback Strategy Used: [strategy name]
   - Audio Plays: [Yes/No]

   ### Conclusion
   [What did we learn?]
   ```

2. **Xcode Console Logs** (full output from audio start)

3. **Recommendation**: What to do next?

---

## 🚀 QUICK START CHECKLIST

- [ ] Copy VeepaSDK folder
- [ ] Copy Flutter module and simplify to audio-only
- [ ] Create iOS SwiftUI interface
- [ ] Configure XcodeGen project
- [ ] Build Flutter framework
- [ ] Generate Xcode project
- [ ] Run on physical device
- [ ] Test baseline (expect error -50)
- [ ] Test with pre-initialization
- [ ] Test with swizzling if needed
- [ ] Document results

**Estimated Time**: 2-4 hours total

---

## 📚 REFERENCES

- Technical Solutions: `TECHNICAL_SOLUTIONS.md`
- Troubleshooting Log: `AUDIO_TROUBLESHOOTING.md`
- Investigation Plan: `AUDIO_NEXT_STEPS.md`
- SciSymbioLens Source: `/Users/mpriessner/windsurf_repos/SciSymbioLens/`

---

**This minimal test app will definitively answer: "Does SDK audio work on iOS?"**

If YES → Fix main app configuration
If NO → SDK is broken, need workaround or vendor fix
