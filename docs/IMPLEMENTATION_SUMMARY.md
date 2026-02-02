# VeepaAudioTest - Implementation Summary for Your Coding AI

**Purpose**: Quick reference guide for another AI agent to implement this project

**Estimated Time**: 4-6 hours total

---

## 🎯 What You're Building

A **minimal iOS app** that tests ONLY Veepa camera audio streaming. No video, no Gemini AI, no complexity - just:
1. Connect to camera via P2P
2. Call startVoice() / stopVoice()
3. Test 4 different AVAudioSession configurations
4. Document which one fixes AudioUnit error -50

---

## 📁 Project Location

```
/Users/mpriessner/windsurf_repos/VeepaAudioTest/
```

All code should go here.

---

## 🗂️ Key Documentation Files

### Start Here
1. **[README.md](../README.md)** - Project overview, what's included/excluded
2. **[PROJECT_PLAN.md](PROJECT_PLAN.md)** - Complete implementation timeline
3. **[CODE_REUSE_STRATEGY.md](CODE_REUSE_STRATEGY.md)** - Exactly what to copy from SciSymbioLens

### Implementation Stories (Follow in Order)
1. **[story-1-project-setup.md](stories/story-1-project-setup.md)** - Create Xcode project + Flutter module
2. **[story-2-flutter-sdk-integration.md](stories/story-2-flutter-sdk-integration.md)** - Copy P2P SDK and services
3. **[story-3-camera-connection-audio.md](stories/story-3-camera-connection-audio.md)** - Build UI and connection logic
4. **[story-4-testing-audio-solutions.md](stories/story-4-testing-audio-solutions.md)** - Test 4 audio strategies

### Reference Documentation
- **[audio_references/AUDIO_DOCUMENTATION_REFERENCES.md](audio_references/AUDIO_DOCUMENTATION_REFERENCES.md)** - Official SDK docs
- **Source Code**: `/Users/mpriessner/windsurf_repos/SciSymbioLens` - Copy components from here

---

## 🚀 Quick Implementation Guide

### Step 1: Read the Plan (10 minutes)
```bash
# Read these files first
cat /Users/mpriessner/windsurf_repos/VeepaAudioTest/README.md
cat /Users/mpriessner/windsurf_repos/VeepaAudioTest/docs/PROJECT_PLAN.md
cat /Users/mpriessner/windsurf_repos/VeepaAudioTest/docs/CODE_REUSE_STRATEGY.md
```

### Step 2: Follow Stories Sequentially (4-6 hours)
Each story has:
- Clear acceptance criteria
- Step-by-step bash commands
- Complete code snippets
- Testing procedures

**Do NOT skip ahead** - each story builds on the previous one.

### Step 3: Document Results (30 minutes)
After completing all stories:
- Test all 4 audio strategies
- Capture console logs
- Fill out `ios/VeepaAudioTest/Resources/TEST_RESULTS.md`
- Provide clear recommendation

---

## 📋 Implementation Checklist

Copy this checklist and mark items as complete:

### Phase 1: Project Setup ⏱️ 45-60 min
- [ ] Create Flutter module `flutter_module/veepa_audio/`
- [ ] Write `pubspec.yaml` with dependencies
- [ ] Create `lib/main.dart` placeholder
- [ ] Create XcodeGen `project.yml`
- [ ] Create `sync-flutter-frameworks.sh` build script
- [ ] Create iOS app structure (VeepaAudioTestApp.swift, ContentView.swift)
- [ ] Create `Info.plist` with microphone permission
- [ ] Run `xcodegen generate`
- [ ] Run `flutter build ios-framework`
- [ ] Run `bash Scripts/sync-flutter-frameworks.sh`
- [ ] Verify app builds: `xcodebuild -project VeepaAudioTest.xcodeproj -scheme VeepaAudioTest -destination 'platform=iOS Simulator,name=iPhone 15' build`
- [ ] **Story 1 Complete** ✅

### Phase 2: SDK Integration ⏱️ 1-1.5 hours
- [ ] Copy vsdk plugin from SciSymbioLens
- [ ] Verify `libVSTC.a` exists (45MB file)
- [ ] Copy `app_p2p_api.dart` from SciSymbioLens
- [ ] Copy `app_dart.dart` from SciSymbioLens
- [ ] Create simplified `audio_player.dart`
- [ ] Update `main.dart` with method channel handlers
- [ ] Copy `FlutterEngineManager.swift` from SciSymbioLens
- [ ] Update method channel name to `com.veepatest/audio`
- [ ] Copy `VSTCBridge.swift` from SciSymbioLens
- [ ] Copy `VeepaConnectionBridge.swift` from SciSymbioLens
- [ ] Rebuild Flutter frameworks: `flutter build ios-framework`
- [ ] Sync frameworks: `bash Scripts/sync-flutter-frameworks.sh`
- [ ] Verify app builds with frameworks
- [ ] Test Flutter initialization in UI
- [ ] Verify ping works
- [ ] Run VSTCBridge diagnostics
- [ ] **Story 2 Complete** ✅

### Phase 3: Camera Connection & Audio ⏱️ 1-1.5 hours
- [ ] Create `AudioConnectionService.swift`
- [ ] Create `AudioStreamService.swift`
- [ ] Update `ContentView.swift` with full UI:
  - [ ] Connection section (UID + serviceParam inputs)
  - [ ] Audio controls section (Start/Stop/Mute)
  - [ ] Debug log section (scrollable text view)
- [ ] Test connection to camera (need real UID + serviceParam)
- [ ] Verify clientPtr is received
- [ ] Test `startVoice()` - expect error -50
- [ ] Test `stopVoice()`
- [ ] Test `setMute()`
- [ ] Capture all console logs
- [ ] **Story 3 Complete** ✅

### Phase 4: Audio Solutions Testing ⏱️ 1.5-2 hours
- [ ] Create `AudioSessionStrategy.swift` with protocol
- [ ] Implement `BaselineStrategy`
- [ ] Implement `PreInitializeStrategy`
- [ ] Implement `SwizzledStrategy`
- [ ] Implement `LockedSessionStrategy`
- [ ] Update `AudioStreamService` to use strategies
- [ ] Add strategy picker to ContentView
- [ ] Create `TEST_RESULTS.md` template
- [ ] Test Baseline strategy (expect error -50)
- [ ] Test Pre-Initialize strategy
- [ ] Test Swizzled strategy
- [ ] Test Locked strategy
- [ ] Document all results
- [ ] Write recommendation
- [ ] **Story 4 Complete** ✅

### Final Deliverables
- [ ] App builds and runs without crashes
- [ ] Can connect to camera
- [ ] All 4 strategies tested
- [ ] Console logs captured for each strategy
- [ ] `TEST_RESULTS.md` filled out with results
- [ ] Clear recommendation provided

---

## 💡 Key Implementation Tips

### 1. Always Copy Paths Exactly
The stories provide full paths like:
```bash
cp /Users/mpriessner/windsurf_repos/SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Services/Flutter/FlutterEngineManager.swift \
   /Users/mpriessner/windsurf_repos/VeepaAudioTest/ios/VeepaAudioTest/VeepaAudioTest/Services/Flutter/
```

**DO NOT modify these paths** - they are correct.

### 2. Build Order Matters
Always build in this order:
```bash
# 1. Flutter first
cd flutter_module/veepa_audio
flutter build ios-framework

# 2. Then sync frameworks
cd ../../ios/VeepaAudioTest
bash Scripts/sync-flutter-frameworks.sh

# 3. Then iOS
xcodebuild -project VeepaAudioTest.xcodeproj -scheme VeepaAudioTest build
```

### 3. Test After Each Story
Don't wait until the end - verify each story's acceptance criteria before moving on.

### 4. Debug Logs Are Critical
Every service includes comprehensive logging. **Do not remove these** - they're essential for diagnosing audio issues.

### 5. Physical Device Required
Audio testing **must** be done on a real iPhone. Simulator audio doesn't match device behavior.

---

## 🎯 Success Metrics

### Minimum Success ✅
- App builds and runs
- Can establish P2P connection
- Can call startVoice() API
- All strategies tested and documented

This is success **even if audio fails** - you've created a minimal reproducible case.

### Ideal Success 🌟
- Audio plays in at least one strategy
- Error -50 resolved
- Clear solution for SciSymbioLens

---

## 🚨 Common Pitfalls to Avoid

### ❌ Don't Skip Story 1
Even though it's "just setup", it establishes critical build configuration. Skipping ahead will cause compiler errors.

### ❌ Don't Simplify Flutter Services
`FlutterEngineManager.swift`, `VSTCBridge.swift`, and `VeepaConnectionBridge.swift` should be **copied exactly** with no modifications (except the method channel name in FlutterEngineManager).

### ❌ Don't Mix Strategies
When testing, restart the app between strategies to avoid state contamination (especially for Swizzled strategy).

### ❌ Don't Test Without Real Camera
P2P connections require actual camera hardware. Mock/simulated connections won't work.

---

## 📊 Code Size Reference

| Component | Lines of Code |
|-----------|---------------|
| **Copied from SciSymbioLens** | ~1,500 |
| **New/Simplified** | ~900 |
| **Total** | **~2,400** |

Compare to SciSymbioLens: **10,500 lines** (77% reduction)

---

## 🔍 Testing Camera Credentials

You'll need:
1. **Camera UID**: 15-character ID (format: `ABCD-123456-ABCDE`)
2. **Service Param**: Base64 string from authentication API

To get serviceParam:
```bash
# Extract first 4 chars of UID
UID_PREFIX="ABCD"

# Call authentication API
curl -X POST https://authentication.eye4.cn/getInitstring \
  -H "Content-Type: application/json" \
  -d "{\"uid\": [\"$UID_PREFIX\"]}"

# Response: ["eyJhbGci...long_base64_string"]
```

The serviceParam expires after ~10 minutes, so fetch fresh for each test session.

---

## 📞 Where to Get Help

### If You Get Stuck
1. Check the story's "Common Issues" section
2. Review the CODE_REUSE_STRATEGY.md for file locations
3. Look at SciSymbioLens source code for reference
4. Verify build order (Flutter → sync → iOS)

### If Audio Fails in All Strategies
This is actually **valuable**! You've created a minimal reproducible case. Package the entire VeepaAudioTest folder and:
1. Document the issue in TEST_RESULTS.md
2. Include console logs for all strategies
3. Provide to SDK vendor or consider alternative approaches

---

## ⏭️ After Completion

### If Audio Works ✅
1. Document the working strategy in detail
2. Copy solution to SciSymbioLens
3. Test in main app
4. Update SciSymbioLens documentation

### If Audio Fails ❌
1. You have a complete minimal reproducible case
2. Comprehensive diagnostic data
3. Can make informed decision:
   - Contact SDK vendor
   - Implement custom decoder
   - Ship video-only mode

---

## 📚 File Reference Quick Links

All files are in `/Users/mpriessner/windsurf_repos/VeepaAudioTest/docs/`:

- `README.md` - Project overview
- `PROJECT_PLAN.md` - Complete timeline
- `CODE_REUSE_STRATEGY.md` - What to copy
- `stories/story-1-project-setup.md` - Story 1
- `stories/story-2-flutter-sdk-integration.md` - Story 2
- `stories/story-3-camera-connection-audio.md` - Story 3
- `stories/story-4-testing-audio-solutions.md` - Story 4
- `audio_references/AUDIO_DOCUMENTATION_REFERENCES.md` - SDK docs

Source code to copy from:
- `/Users/mpriessner/windsurf_repos/SciSymbioLens/`

---

## ✅ Final Checklist

Before you start:
- [ ] I have read the README.md
- [ ] I have read the PROJECT_PLAN.md
- [ ] I have read the CODE_REUSE_STRATEGY.md
- [ ] I understand this is a 4-6 hour project
- [ ] I have access to a physical iPhone for testing
- [ ] I have a Veepa camera with UID
- [ ] I can fetch serviceParam from authentication API

Ready to begin? Start with [Story 1: Project Setup](stories/story-1-project-setup.md) 🚀

---

**Created**: 2026-02-02
**For**: AI coding agent implementation
**Estimated Completion**: 4-6 hours
