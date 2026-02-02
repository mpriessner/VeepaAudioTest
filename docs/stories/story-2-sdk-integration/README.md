# Story 2: P2P SDK Integration and Flutter Services

**Epic**: VeepaAudioTest - Minimal Audio Testing App
**Total Estimated Time**: 2-2.5 hours
**Status**: 🚧 In Progress

---

## 📋 Story Overview

Copy the P2P SDK (libVSTC.a) and essential Flutter/iOS services from SciSymbioLens, adapting them for audio-only testing. This story establishes the communication layer between iOS and Flutter.

**What We're Building:**
- P2P SDK binary and plugin structure
- Dart FFI bindings for SDK
- Flutter engine manager (iOS side)
- Platform channel communication
- SDK symbol access bridge (VSTCBridge)

**What We're Adapting from SciSymbioLens:**
- libVSTC.a binary (45MB) - copy exactly
- app_p2p_api.dart - copy exactly (FFI bindings)
- FlutterEngineManager.swift - adapt (remove video frame handling)
- VSTCBridge.swift - copy exactly (low-level SDK access)
- VeepaConnectionBridge.swift - simplify (remove state polling)

---

## 📊 Sub-Stories

Work through these sequentially. Each sub-story is a separate file with detailed instructions.

### ✅ Sub-Story 2.1: Copy P2P SDK Binary and Plugin
⏱️ **15-20 minutes** | 📄 [sub-story-2.1-copy-sdk-binary.md](sub-story-2.1-copy-sdk-binary.md)

Copy libVSTC.a and VsdkPlugin from SciSymbioLens to VeepaAudioTest.

**Acceptance Criteria:**
- [ ] Plugin directory structure created
- [ ] VsdkPlugin header and implementation copied
- [ ] AppP2PApiPlugin header copied
- [ ] AppPlayerPlugin header copied
- [ ] libVSTC.a copied (45MB)
- [ ] Binary is arm64 architecture
- [ ] vsdk.podspec created with correct dependencies

---

### ✅ Sub-Story 2.2: Copy P2P Dart Bindings
⏱️ **20-25 minutes** | 📄 [sub-story-2.2-dart-bindings.md](sub-story-2.2-dart-bindings.md)

Copy Dart FFI bindings that allow Dart code to call libVSTC.a functions.

**Acceptance Criteria:**
- [ ] lib/sdk/ directory created
- [ ] app_p2p_api.dart copied (exact copy)
- [ ] app_dart.dart copied (exact copy)
- [ ] audio_player.dart created (adapted)
- [ ] Audio methods implemented (startVoice, stopVoice, setMute)
- [ ] Video methods removed
- [ ] Flutter analyze passes

---

### ✅ Sub-Story 2.3: Update Main Dart Entry Point
⏱️ **25-30 minutes** | 📄 [sub-story-2.3-main-dart.md](sub-story-2.3-main-dart.md)

Update lib/main.dart to handle audio method calls from iOS.

**Acceptance Criteria:**
- [ ] lib/main.dart updated with full method channel implementation
- [ ] Method channel name is 'com.veepatest/audio'
- [ ] flutterReady signal sent to iOS on startup
- [ ] connectWithCredentials method implemented
- [ ] Audio control methods implemented
- [ ] Video methods removed
- [ ] Flutter analyze passes

---

### ✅ Sub-Story 2.4: Copy Flutter Engine Manager
⏱️ **25-30 minutes** | 📄 [sub-story-2.4-flutter-engine-manager.md](sub-story-2.4-flutter-engine-manager.md)

Copy FlutterEngineManager.swift to handle Flutter engine lifecycle and method channel communication.

**Acceptance Criteria:**
- [ ] Services/Flutter/ directory created
- [ ] FlutterEngineManager.swift created (~220 lines)
- [ ] Channel name changed to "com.veepatest/audio"
- [ ] Plugin registration (VsdkPlugin) present
- [ ] flutterReady signal handling present
- [ ] VSTC diagnostics removed
- [ ] Video/provisioning event channels removed
- [ ] Credential refresh helpers removed
- [ ] File compiles without errors
- [ ] Xcode project includes new file

---

### ✅ Sub-Story 2.5: Copy VSTCBridge for SDK Symbol Access
⏱️ **15-20 minutes** | 📄 [sub-story-2.5-vstc-bridge.md](sub-story-2.5-vstc-bridge.md)

Copy VSTCBridge.swift for low-level SDK access and symbol introspection.

**Acceptance Criteria:**
- [ ] VSTCBridge.swift copied (exact copy, ~290 lines)
- [ ] Symbol access functions present (dlsym, listAvailableSymbols)
- [ ] Diagnostics methods present (runDiagnostics, checkVSTCHealth)
- [ ] File compiles without errors
- [ ] Xcode project includes new file

---

### ✅ Sub-Story 2.6: Create Simplified Connection Bridge
⏱️ **20-25 minutes** | 📄 [sub-story-2.6-connection-bridge.md](sub-story-2.6-connection-bridge.md)

Adapt VeepaConnectionBridge.swift for simplified P2P connection management (audio testing only).

**Acceptance Criteria:**
- [ ] VeepaConnectionBridge.swift created (~238 lines)
- [ ] P2P connection method (connectWithCredentials) present
- [ ] P2PCredentials struct present
- [ ] Disconnect method present
- [ ] State enum simplified to 4 states (idle, connecting, connected, error)
- [ ] Error handling present
- [ ] State polling removed (startStatePolling, stopStatePolling, refreshState)
- [ ] Auto-reconnect removed (retry method)
- [ ] Discovery connection removed (connect(to device))
- [ ] Streaming methods removed (startStreaming, stopStreaming)
- [ ] File compiles without errors
- [ ] Xcode project includes new file

---

### ✅ Sub-Story 2.7: Verify Flutter-iOS Communication
⏱️ **15-20 minutes** | 📄 [sub-story-2.7-verify-communication.md](sub-story-2.7-verify-communication.md)

Test complete Flutter ↔ iOS communication pipeline and verify all Story 2 components work end-to-end.

**Acceptance Criteria:**
- [ ] Flutter engine initializes without errors
- [ ] VsdkPlugin registers successfully
- [ ] Method channel communication works
- [ ] flutterReady signal received by iOS
- [ ] Ping test passes (iOS → Flutter → iOS)
- [ ] Method invocation works both directions
- [ ] All bridges compile and link
- [ ] Complete build succeeds
- [ ] All Story 2 verification checks pass

---

## 🎯 Story 2 Complete Checklist

**Check all before proceeding to Story 3:**

### P2P SDK Integration
- [ ] libVSTC.a binary copied and linked
- [ ] Plugin structure in place
- [ ] Dart FFI bindings working

### Flutter Services
- [ ] Flutter engine manager implemented
- [ ] Method channel communication working
- [ ] Audio control methods functional

### iOS Services
- [ ] VSTCBridge for SDK access
- [ ] Connection bridge implemented
- [ ] Complete build succeeds

---

## 🎉 Story 2 Deliverables

Once complete, you will have:
- ✅ P2P SDK integrated into Flutter plugin
- ✅ Dart FFI bindings for SDK calls
- ✅ Flutter-iOS communication layer
- ✅ Audio control methods functional
- ✅ Project ready for UI development

**Next**: Proceed to [Story 3: iOS UI Development](../story-3-ios-ui/README.md)

---

**Created**: 2026-02-02
**Based on**: DEEP_CODE_ANALYSIS.md (4,000+ lines analyzed)
**Source**: SciSymbioLens codebase
