# VeepaAudioTest

**Purpose**: Minimal iOS app to test ONLY Veepa camera audio streaming (no video, no Gemini, no complex UI)

**Goal**: Determine if the P2P SDK audio playback works at all on iOS and identify the root cause of AudioUnit error -50

**Status**: 🚧 Initial Setup

---

## 🎯 What This Project Tests

### Included ✅
- Veepa camera WiFi connection and P2P setup
- Audio streaming initialization (startVoice/stopVoice)
- AVAudioSession configuration testing
- Multiple audio session approaches (pre-initialize, swizzling, locked session)
- Debug logging for audio errors

### Excluded ❌
- No video streaming or rendering
- No Gemini AI integration
- No chat interface
- No cloud storage
- No complex navigation

---

## 📁 Project Structure

```
VeepaAudioTest/
├── README.md                          # This file
├── docs/
│   ├── PROJECT_PLAN.md                # Implementation roadmap
│   ├── CODE_REUSE_STRATEGY.md         # What to copy from SciSymbioLens
│   ├── stories/                       # User stories for implementation
│   │   ├── story-1-project-setup.md
│   │   ├── story-2-flutter-integration.md
│   │   ├── story-3-audio-streaming.md
│   │   └── story-4-testing-solutions.md
│   └── audio_references/              # Copied from SciSymbioLens
│       ├── AUDIO_DOCUMENTATION_REFERENCES.md
│       └── MINIMAL_AUDIO_TEST_APP_INSTRUCTIONS.md
├── ios/
│   └── VeepaAudioTest/                # Xcode project (to be created)
│       ├── VeepaAudioTest.xcodeproj
│       ├── VeepaAudioTest/            # iOS app source
│       │   ├── Services/
│       │   │   ├── FlutterEngineManager.swift (copied from SciSymbioLens)
│       │   │   └── VSTCBridge.swift (copied from SciSymbioLens)
│       │   ├── Views/
│       │   │   └── ContentView.swift (simplified UI)
│       │   └── Info.plist
│       └── Scripts/
│           └── sync-flutter-frameworks.sh (copied from SciSymbioLens)
└── flutter_module/
    └── veepa_audio/                   # Minimal Flutter module (audio-only)
        ├── lib/
        │   ├── main.dart
        │   ├── sdk/
        │   │   ├── app_player.dart (simplified)
        │   │   └── app_p2p_api.dart (copied from SciSymbioLens)
        │   └── services/
        │       └── audio_manager.dart (new - audio-only logic)
        └── pubspec.yaml
```

---

## 🔧 What Gets Copied from SciSymbioLens

### Essential Components (Must Copy)
1. **Flutter Services** (for P2P SDK communication):
   - `FlutterEngineManager.swift` - Flutter engine lifecycle
   - `VSTCBridge.swift` - Low-level SDK symbol access
   - `VeepaConnectionBridge.swift` - Connection management
   - `app_p2p_api.dart` - P2P SDK bindings

2. **Build Configuration**:
   - `sync-flutter-frameworks.sh` - Script to link Flutter frameworks
   - Flutter framework binaries (from SciSymbioLens build)
   - `libVSTC.a` - P2P SDK static library

3. **Audio Documentation**:
   - All files from `docs/stories/epic-20-camera-audio/`
   - Official SDK docs with audio references

### Simplified Components (Stripped Down)
1. **iOS UI**:
   - Single `ContentView.swift` with:
     - Connection status display
     - "Connect to Camera" button (manual UID entry)
     - "Start Audio" / "Stop Audio" buttons
     - "Mute" button
     - Debug log text view

2. **Flutter Module**:
   - Remove video rendering logic
   - Keep only audio streaming methods (startVoice, stopVoice, setMute)
   - Remove provisioning/discovery (use manual UID entry instead)

### Not Copied (Excluded)
- Gemini AI services
- Video rendering views
- Cloud storage services
- Chat/conversation management
- Camera capture (photos/videos)
- Any MVVM ViewModels (direct service access instead)

---

## 🧪 Test Scenarios

The app will test 3 different audio configurations:

### Scenario A: Baseline (Expected to Fail)
- Standard AVAudioSession setup
- Call startVoice() directly
- **Expected Result**: Error -50 (kAudioUnitErr_FormatNotSupported)

### Scenario B: Pre-Initialize Audio Session
- Configure AVAudioSession BEFORE Flutter engine starts
- Set `.playAndRecord` mode with `.defaultToSpeaker`
- **Expected Result**: Might fix error -50 if timing is the issue

### Scenario C: Method Swizzling
- Swizzle AVAudioSession methods to intercept SDK calls
- Force audio format to 8kHz mono PCM
- **Expected Result**: Might fix error -50 if format negotiation is the issue

---

## 📊 Success Criteria

### ✅ Success
- Audio plays from camera without error -50
- Debug logs show successful AudioUnit initialization
- Can start/stop audio multiple times without crashes

### ⚠️ Partial Success
- Error -50 persists, but we identify root cause from logs
- Audio works in one scenario but not others

### ❌ Failure
- Error -50 persists in all scenarios
- No additional diagnostic information gained

**Next Steps After Testing**:
- If audio works: Copy solution back to SciSymbioLens
- If audio fails: Contact SDK vendor with minimal reproducible case OR implement custom AudioUnit decoder

---

## 🚀 Getting Started

See `docs/PROJECT_PLAN.md` for step-by-step implementation instructions.

**Estimated Time**: 2-4 hours to build + 1-2 hours to test

---

## 📚 Related Documentation

- **Source Project**: `/Users/mpriessner/windsurf_repos/SciSymbioLens`
- **Audio Investigation**: `docs/audio_references/AUDIO_DOCUMENTATION_REFERENCES.md`
- **Implementation Guide**: `docs/PROJECT_PLAN.md`
- **User Stories**: `docs/stories/`

---

**Created**: 2026-02-02
**Status**: Planning Phase
