# VeepaAudioTest - Complete Project Plan

**Purpose**: Comprehensive implementation guide for building a minimal audio test app

**Goal**: Isolate and fix AudioUnit error -50 in Veepa camera audio streaming

**Estimated Total Time**: 4-6 hours (build) + 1-2 hours (testing)

---

## 🎯 Project Overview

### Why This Project?

The main SciSymbioLens app has 10,000+ lines of code with:
- Video streaming
- Gemini AI integration
- Complex MVVM architecture
- Cloud storage
- Multiple camera sources

This makes debugging audio issues extremely difficult. **VeepaAudioTest** strips everything down to:
- ✅ Just camera connection
- ✅ Just audio streaming
- ✅ Just essential services
- ✅ ~1,800 lines of code (83% reduction)

This allows **faster iteration** and provides a **minimal reproducible case** for the SDK vendor if needed.

---

## 📊 Project Scope

### In Scope ✅
- Manual camera connection (UID + serviceParam entry)
- P2P connection establishment
- Audio streaming (startVoice, stopVoice, setMute)
- AVAudioSession configuration testing
- 4 different audio session strategies
- Comprehensive debug logging
- Error capture and documentation

### Out of Scope ❌
- Video streaming/rendering
- Gemini AI integration
- Camera discovery/provisioning
- Cloud storage/uploads
- Photo/video capture
- Complex navigation/state management
- User authentication

---

## 🗓️ Implementation Timeline

### Phase 1: Project Setup (45-60 minutes)
**Goal**: Working iOS app with Flutter integration

1. Create Flutter module (`veepa_audio`)
2. Set up XcodeGen configuration
3. Create build scripts
4. Generate Xcode project
5. Verify app builds and launches

**Deliverable**: Empty app that builds successfully

**Story**: [story-1-project-setup.md](stories/story-1-project-setup.md)

---

### Phase 2: SDK Integration (1-1.5 hours)
**Goal**: P2P SDK integrated and callable from iOS

1. Copy P2P SDK plugin (`libVSTC.a`)
2. Copy Flutter SDK bindings (`app_p2p_api.dart`)
3. Copy iOS Flutter services (FlutterEngineManager, VSTCBridge)
4. Update build configuration
5. Test Flutter engine initialization

**Deliverable**: Flutter engine responds to ping, VSTCBridge finds SDK symbols

**Story**: [story-2-flutter-sdk-integration.md](stories/story-2-flutter-sdk-integration.md)

---

### Phase 3: Camera Connection & Audio (1-1.5 hours)
**Goal**: Connect to camera and call audio APIs

1. Create connection service (manages P2P connection)
2. Create audio streaming service (startVoice, stopVoice)
3. Build UI (connection form, audio controls, debug log)
4. Test camera connection
5. Test audio streaming (expect error -50 initially)

**Deliverable**: App can connect to camera and call startVoice()

**Story**: [story-3-camera-connection-audio.md](stories/story-3-camera-connection-audio.md)

---

### Phase 4: Audio Solutions Testing (1.5-2 hours)
**Goal**: Test 4 strategies to fix error -50

1. Implement AudioSessionStrategy protocol
2. Create 4 strategies:
   - Baseline (standard setup)
   - Pre-Initialize (before Flutter)
   - Swizzled (force 8kHz format)
   - Locked (prevent SDK changes)
3. Add strategy selector UI
4. Run comprehensive tests
5. Document results

**Deliverable**: Clear answer on which strategy works (or confirmation all fail)

**Story**: [story-4-testing-audio-solutions.md](stories/story-4-testing-audio-solutions.md)

---

## 📦 Code Reuse from SciSymbioLens

### Copy Exactly (No Changes)

| Component | Source | LOC | Purpose |
|-----------|--------|-----|---------|
| FlutterEngineManager.swift | `Services/Flutter/` | 385 | Flutter engine lifecycle |
| VSTCBridge.swift | `Services/` | 408 | SDK symbol access |
| VeepaConnectionBridge.swift | `Services/Flutter/` | 200 | P2P connection |
| app_p2p_api.dart | `flutter_module/veepa_camera/lib/sdk/` | 500 | P2P FFI bindings |
| libVSTC.a | `ios/.symlinks/plugins/vsdk/ios/` | - | P2P SDK binary |

**Total**: ~1,500 lines copied as-is

### Simplified/New Code

| Component | Destination | LOC | Purpose |
|-----------|-------------|-----|---------|
| audio_player.dart | `flutter_module/veepa_audio/lib/sdk/` | 100 | Audio-only wrapper |
| main.dart | `flutter_module/veepa_audio/lib/` | 100 | Flutter entry point |
| AudioConnectionService.swift | `Services/` | 100 | Connection management |
| AudioStreamService.swift | `Services/` | 150 | Audio control + strategies |
| AudioSessionStrategy.swift | `Services/` | 250 | 4 test strategies |
| ContentView.swift | `Views/` | 200 | Full UI |

**Total**: ~900 lines new/simplified code

**Grand Total**: ~2,400 lines (vs 10,500 in SciSymbioLens = 77% reduction)

---

## 🧪 Testing Strategy

### Test Matrix

Each test mode will be run with these scenarios:

| Scenario | Configuration | Expected Outcome |
|----------|---------------|------------------|
| **Baseline** | Standard AVAudioSession setup | Error -50 (baseline for comparison) |
| **Pre-Initialize** | Set 8kHz sample rate before Flutter starts | May fix error -50 if timing issue |
| **Swizzled** | Force 8kHz via method swizzling | May fix error -50 if format negotiation issue |
| **Locked** | Lock audio session configuration | May fix error -50 if SDK override issue |

### Test Procedure

For **each strategy**:
1. Restart app (clean state)
2. Select strategy
3. Enter camera UID and serviceParam
4. Connect to camera
5. Start audio
6. Record:
   - ✅/❌ Audio played?
   - Error code (if any)
   - Full console logs
   - AVAudioSession final state
7. Stop audio
8. Disconnect

### Documentation

Results documented in: `ios/VeepaAudioTest/Resources/TEST_RESULTS.md`

---

## 🎯 Success Criteria

### Minimum Success ✅
- [ ] App builds and runs without crashes
- [ ] Can establish P2P connection to camera
- [ ] Can call startVoice() API
- [ ] All 4 strategies tested and documented
- [ ] Comprehensive diagnostic logs captured

### Ideal Success 🌟
- [ ] Audio plays successfully in at least one strategy
- [ ] Error -50 resolved
- [ ] Solution documented for SciSymbioLens implementation
- [ ] Audio works reliably (can start/stop multiple times)

### Valuable Failure ⚠️
Even if audio fails in all strategies:
- ✅ We have minimal reproducible case for SDK vendor
- ✅ We have comprehensive diagnostic data
- ✅ We can make informed decision on next steps:
  - Contact vendor with test app
  - Implement custom AudioUnit decoder
  - Ship video-only mode

---

## 📚 Key Documentation

### For Implementation
- [README.md](../README.md) - Project overview and structure
- [CODE_REUSE_STRATEGY.md](CODE_REUSE_STRATEGY.md) - What to copy from SciSymbioLens
- [stories/story-1-project-setup.md](stories/story-1-project-setup.md) - Story 1
- [stories/story-2-flutter-sdk-integration.md](stories/story-2-flutter-sdk-integration.md) - Story 2
- [stories/story-3-camera-connection-audio.md](stories/story-3-camera-connection-audio.md) - Story 3
- [stories/story-4-testing-audio-solutions.md](stories/story-4-testing-audio-solutions.md) - Story 4

### For Reference
- [audio_references/AUDIO_DOCUMENTATION_REFERENCES.md](audio_references/AUDIO_DOCUMENTATION_REFERENCES.md) - Official SDK docs
- [audio_references/MINIMAL_AUDIO_TEST_APP_INSTRUCTIONS.md](audio_references/MINIMAL_AUDIO_TEST_APP_INSTRUCTIONS.md) - Original instructions

---

## 🛠️ Development Environment

### Required Tools
- Xcode 15.0+ (iOS 17+ SDK)
- Flutter 3.0+ (`flutter doctor` must pass)
- XcodeGen (`brew install xcodegen`)
- Git
- Physical iOS device (audio testing requires hardware)

### Project Structure
```
VeepaAudioTest/
├── README.md
├── docs/
│   ├── PROJECT_PLAN.md (this file)
│   ├── CODE_REUSE_STRATEGY.md
│   ├── stories/
│   │   ├── story-1-project-setup.md
│   │   ├── story-2-flutter-sdk-integration.md
│   │   ├── story-3-camera-connection-audio.md
│   │   └── story-4-testing-audio-solutions.md
│   └── audio_references/
│       └── AUDIO_DOCUMENTATION_REFERENCES.md
├── flutter_module/
│   └── veepa_audio/
│       ├── lib/
│       │   ├── main.dart
│       │   ├── sdk/
│       │   │   ├── app_p2p_api.dart
│       │   │   └── audio_player.dart
│       │   └── services/
│       └── pubspec.yaml
└── ios/
    └── VeepaAudioTest/
        ├── project.yml (XcodeGen config)
        ├── Scripts/
        │   └── sync-flutter-frameworks.sh
        └── VeepaAudioTest/
            ├── Services/
            │   ├── Flutter/
            │   │   ├── FlutterEngineManager.swift
            │   │   └── VeepaConnectionBridge.swift
            │   ├── VSTCBridge.swift
            │   ├── AudioConnectionService.swift
            │   ├── AudioStreamService.swift
            │   └── AudioSessionStrategy.swift
            ├── Views/
            │   └── ContentView.swift
            └── VeepaAudioTestApp.swift
```

---

## 🚀 Quick Start

### 1. Clone and Setup
```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest

# Install dependencies
brew install xcodegen
flutter doctor
```

### 2. Follow Stories in Order
1. [Story 1: Project Setup](stories/story-1-project-setup.md) - 45-60 min
2. [Story 2: SDK Integration](stories/story-2-flutter-sdk-integration.md) - 1-1.5 hours
3. [Story 3: Camera Connection](stories/story-3-camera-connection-audio.md) - 1-1.5 hours
4. [Story 4: Testing Solutions](stories/story-4-testing-audio-solutions.md) - 1.5-2 hours

### 3. Test and Document
- Run all 4 audio strategies
- Capture console logs
- Document results in `TEST_RESULTS.md`

---

## 🎓 Learning Outcomes

By completing this project, you will:

1. **Understand P2P SDK Integration**: How Flutter FFI bridges to native SDK
2. **Master AVAudioSession**: Different configuration strategies and their effects
3. **Debug Audio Issues**: Systematic approach to isolating audio problems
4. **Code Reuse Strategy**: How to extract essential code from complex projects
5. **Minimal Reproducible Cases**: How to create focused test apps for debugging

---

## 📊 Progress Tracking

### Story Completion
- [ ] Story 1: Project Setup
- [ ] Story 2: SDK Integration
- [ ] Story 3: Camera Connection & Audio
- [ ] Story 4: Testing Solutions

### Testing Completion
- [ ] Baseline strategy tested
- [ ] Pre-Initialize strategy tested
- [ ] Swizzled strategy tested
- [ ] Locked strategy tested
- [ ] Results documented in TEST_RESULTS.md

### Final Deliverables
- [ ] Working test app
- [ ] Comprehensive test results
- [ ] Console logs for all strategies
- [ ] Recommendation for SciSymbioLens

---

## 🔄 Next Steps After Testing

### If Audio Works ✅
1. Document working strategy in detail
2. Copy solution to SciSymbioLens codebase
3. Test in main app (with Gemini integration)
4. Verify audio works reliably
5. Update SciSymbioLens documentation

### If Audio Fails ❌
1. Package VeepaAudioTest as ZIP
2. Write detailed bug report for SDK vendor:
   - Complete source code
   - Comprehensive logs
   - Steps to reproduce
   - Device/iOS version
3. Explore alternatives:
   - Custom AudioUnit decoder (2-3 days of work)
   - Video-only mode (disable audio feature)
   - Alternative camera SDK

---

## 📞 Support Resources

### SciSymbioLens Source
- Path: `/Users/mpriessner/windsurf_repos/SciSymbioLens`
- Main app with full implementation

### Official Documentation
- See: `docs/audio_references/AUDIO_DOCUMENTATION_REFERENCES.md`
- 4 key documents with audio information

### SDK Vendor
- If audio fails, contact vendor with VeepaAudioTest project
- Provide: Source code + logs + TEST_RESULTS.md

---

**Ready to Begin?** Start with [Story 1: Project Setup](stories/story-1-project-setup.md)

---

**Created**: 2026-02-02
**Status**: Ready for Implementation
**Priority**: High (Blocking SciSymbioLens audio feature)
