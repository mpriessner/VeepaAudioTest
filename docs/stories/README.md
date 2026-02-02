# VeepaAudioTest User Stories

This directory contains the implementation stories for building the VeepaAudioTest app.

---

## 📖 Story Reading Order

Follow these stories **sequentially** - each builds on the previous one:

### 1. [Project Setup](story-1-project-setup.md) ⏱️ 45-60 minutes
**Goal**: Create Xcode project, Flutter module, and build infrastructure

**Deliverables**:
- Working Flutter module
- Generated Xcode project
- Build scripts
- App builds and launches

**Acceptance Criteria**:
- [x] Flutter frameworks build successfully
- [x] Xcode project generated via XcodeGen
- [x] App runs on simulator/device
- [x] Info.plist includes microphone permission

---

### 2. [Flutter SDK Integration](story-2-flutter-sdk-integration.md) ⏱️ 1-1.5 hours
**Goal**: Integrate P2P SDK and Flutter service layer

**Deliverables**:
- P2P SDK (libVSTC.a) integrated
- Flutter services copied (FlutterEngineManager, VSTCBridge)
- Platform method channel working

**Acceptance Criteria**:
- [x] vsdk.xcframework linked correctly
- [x] Flutter engine initializes
- [x] Ping test succeeds
- [x] VSTCBridge finds SDK symbols

---

### 3. [Camera Connection & Audio](story-3-camera-connection-audio.md) ⏱️ 1-1.5 hours
**Goal**: Build UI and implement audio streaming

**Deliverables**:
- Connection service (P2P connection management)
- Audio service (startVoice/stopVoice control)
- Full UI with debug logging

**Acceptance Criteria**:
- [x] Can connect to camera (get clientPtr)
- [x] Can call startVoice() API
- [x] Audio controls functional
- [x] Debug log displays all SDK interactions

---

### 4. [Testing Audio Solutions](story-4-testing-audio-solutions.md) ⏱️ 1.5-2 hours
**Goal**: Test 4 different strategies to fix AudioUnit error -50

**Deliverables**:
- 4 audio session strategies implemented
- Strategy selector UI
- Comprehensive test results
- Recommendation document

**Acceptance Criteria**:
- [x] All 4 strategies tested
- [x] Console logs captured
- [x] Results documented in TEST_RESULTS.md
- [x] Clear recommendation provided

---

## 🎯 Total Estimated Time

**Implementation**: 4-6 hours
**Testing**: 1-2 hours
**Total**: 5-8 hours

---

## 📊 Progress Tracking

Use this checklist to track overall progress:

- [ ] Story 1: Project Setup (COMPLETE)
- [ ] Story 2: SDK Integration (COMPLETE)
- [ ] Story 3: Camera Connection (COMPLETE)
- [ ] Story 4: Testing Solutions (COMPLETE)
- [ ] All tests run (COMPLETE)
- [ ] Results documented (COMPLETE)
- [ ] Recommendation written (COMPLETE)

---

## 📋 Story Dependencies

```
Story 1 (Project Setup)
    ↓
Story 2 (SDK Integration) ← depends on Story 1 build infrastructure
    ↓
Story 3 (Camera Connection) ← depends on Story 2 Flutter services
    ↓
Story 4 (Testing Solutions) ← depends on Story 3 audio service
```

**Important**: Do not skip stories - each one is required for the next.

---

## 🧪 Testing After Each Story

Each story includes a "Testing & Verification" section. **Run these tests before proceeding to the next story**.

Example from Story 1:
```bash
# Test 1: Flutter Module Builds
cd flutter_module/veepa_audio
flutter build ios-framework
# ✅ Expected: Frameworks created

# Test 2: Xcode Project Generates
cd ios/VeepaAudioTest
xcodegen generate
# ✅ Expected: .xcodeproj created

# Test 3: App Builds
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
# ✅ Expected: BUILD SUCCEEDED
```

---

## 🚨 Common Issues

### Issue: Can't find file to copy
**Solution**: Check paths in [CODE_REUSE_STRATEGY.md](../CODE_REUSE_STRATEGY.md)

### Issue: Build fails with framework errors
**Solution**: Ensure build order: Flutter → sync-frameworks → Xcode

### Issue: Flutter not ready timeout
**Solution**: Check Flutter console logs for initialization errors

### Issue: Error -50 persists in all strategies
**Status**: This may be expected - see Story 4 for next steps

---

## 📚 Related Documentation

- [Project Plan](../PROJECT_PLAN.md) - Overall timeline and scope
- [Code Reuse Strategy](../CODE_REUSE_STRATEGY.md) - What to copy from SciSymbioLens
- [Implementation Summary](../IMPLEMENTATION_SUMMARY.md) - Quick reference for AI agent
- [README](../../README.md) - Project overview

---

## 🎓 What You'll Learn

By completing these stories, you will:

1. **Understand P2P SDK integration** - How native SDKs connect to Flutter
2. **Master AVAudioSession** - Multiple configuration approaches
3. **Debug audio systematically** - Isolate and test hypotheses
4. **Extract minimal test cases** - Simplify complex projects for debugging
5. **Document technical decisions** - Clear test results and recommendations

---

## ⏭️ After Completion

### If Audio Works ✅
1. Document working strategy
2. Copy solution to SciSymbioLens
3. Test in main app with Gemini

### If Audio Fails ❌
1. You have minimal reproducible case
2. Contact SDK vendor with VeepaAudioTest
3. Explore alternatives (custom decoder, video-only mode)

---

**Ready to Start?** Open [Story 1: Project Setup](story-1-project-setup.md) 🚀
