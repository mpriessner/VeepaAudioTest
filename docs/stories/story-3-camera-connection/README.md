# Story 3: Camera Connection & Audio UI

**Epic**: VeepaAudioTest - Minimal Audio Testing App
**Total Estimated Time**: 2-3 hours
**Status**: 🚧 In Progress

---

## 📋 Story Overview

Build the iOS UI layer that connects to the camera via P2P and provides audio streaming controls. This story implements the user-facing interface for testing audio playback from Veepa cameras.

**What We're Building:**
- AudioConnectionService for P2P connection management
- AudioStreamService for audio playback control
- SwiftUI ContentView with three sections:
  - Connection controls (UID, serviceParam, connect/disconnect)
  - Audio controls (start/stop, mute, volume indicator)
  - Debug log view (scrollable console with timestamps)
- Complete iOS app UI ready for testing

**What We're Adapting from SciSymbioLens:**
- Service architecture pattern (ObservableObject, @Published state)
- AVAudioSession configuration approach
- Debug logging patterns
- NOT copying: Video rendering, discovery UI, provisioning flows

---

## 📊 Sub-Stories

Work through these sequentially. Each sub-story is a separate file with detailed instructions.

### ✅ Sub-Story 3.1: Audio Connection Service
⏱️ **20-25 minutes** | 📄 [sub-story-3.1-audio-connection-service.md](sub-story-3.1-audio-connection-service.md)

Create AudioConnectionService that wraps VeepaConnectionBridge for SwiftUI integration.

**Acceptance Criteria:**
- [ ] AudioConnectionService.swift created (~120 lines)
- [ ] ObservableObject with @Published state
- [ ] ConnectionState enum (disconnected, connecting, connected, error)
- [ ] connect(uid:serviceParam:) async method
- [ ] disconnect() async method
- [ ] Debug logging to published array
- [ ] File compiles without errors

---

### ✅ Sub-Story 3.2: Audio Stream Service
⏱️ **20-25 minutes** | 📄 [sub-story-3.2-audio-stream-service.md](sub-story-3.2-audio-stream-service.md)

Create AudioStreamService that wraps Flutter audio methods (startVoice, stopVoice, setMute).

**Acceptance Criteria:**
- [ ] AudioStreamService.swift created (~120 lines)
- [ ] ObservableObject with @Published state (isPlaying, isMuted)
- [ ] startAudio() async throws method
- [ ] stopAudio() async throws method
- [ ] setMute(_:) async throws method
- [ ] AVAudioSession configuration in startAudio
- [ ] Debug logging to published array
- [ ] File compiles without errors

---

### ✅ Sub-Story 3.3: ContentView Layout Structure
⏱️ **25-30 minutes** | 📄 [sub-story-3.3-contentview-layout.md](sub-story-3.3-contentview-layout.md)

Create SwiftUI ContentView with three-section layout and proper state management.

**Acceptance Criteria:**
- [ ] ContentView.swift created with three sections
- [ ] VStack with Dividers between sections
- [ ] @StateObject for services
- [ ] @State for UI state (uid, serviceParam, error alerts)
- [ ] NavigationView wrapper
- [ ] File compiles without errors

---

### ✅ Sub-Story 3.4: Connection Controls Implementation
⏱️ **20-25 minutes** | 📄 [sub-story-3.4-connection-controls.md](sub-story-3.4-connection-controls.md)

Implement connection section UI with UID/serviceParam inputs and connect/disconnect button.

**Acceptance Criteria:**
- [ ] Connection status indicator with color coding
- [ ] UID TextField (disabled when connected)
- [ ] ServiceParam TextField (disabled when connected)
- [ ] Connect/Disconnect button (color changes with state)
- [ ] Button disabled during connection or with empty inputs
- [ ] toggleConnection() action implemented
- [ ] UI updates reactively to connection state

---

### ✅ Sub-Story 3.5: Audio Controls Implementation
⏱️ **15-20 minutes** | 📄 [sub-story-3.5-audio-controls.md](sub-story-3.5-audio-controls.md)

Implement audio controls section with start/stop and mute buttons.

**Acceptance Criteria:**
- [ ] Audio status indicator (playing/stopped)
- [ ] Start/Stop Audio button (changes label and icon)
- [ ] Mute/Unmute button
- [ ] Buttons disabled when not connected
- [ ] toggleAudio() action implemented
- [ ] toggleMute() action implemented
- [ ] Error alerts displayed on audio failures

---

### ✅ Sub-Story 3.6: Debug Log View Implementation
⏱️ **15-20 minutes** | 📄 [sub-story-3.6-debug-log-view.md](sub-story-3.6-debug-log-view.md)

Implement scrollable debug log view that combines logs from both services.

**Acceptance Criteria:**
- [ ] ScrollView with LazyVStack for performance
- [ ] Auto-scroll to bottom on new log entries
- [ ] Monospaced font for logs
- [ ] Color coding (red for errors, green for success, orange for warnings)
- [ ] Timestamps in all log entries
- [ ] allLogs computed property merges service logs
- [ ] logColor() helper for syntax coloring

---

### ✅ Sub-Story 3.7: Integrate Services with AppDelegate
⏱️ **20-25 minutes** | 📄 [sub-story-3.7-integrate-services.md](sub-story-3.7-integrate-services.md)

Wire up services to ContentView and update AppDelegate to use SwiftUI lifecycle.

**Acceptance Criteria:**
- [ ] VeepaAudioTestApp.swift created with @main
- [ ] WindowGroup with ContentView
- [ ] Services properly injected
- [ ] Info.plist has required keys (UILaunchScreen, etc.)
- [ ] App compiles and launches
- [ ] All UI elements render correctly

---

### ✅ Sub-Story 3.8: End-to-End Connection and Audio Test
⏱️ **25-30 minutes** | 📄 [sub-story-3.8-end-to-end-test.md](sub-story-3.8-end-to-end-test.md)

Test complete flow: connect to camera, start audio, verify logging, handle errors.

**Acceptance Criteria:**
- [ ] Can retrieve camera credentials (UID + serviceParam)
- [ ] Can enter credentials in UI
- [ ] Connection succeeds and shows "Connected" status
- [ ] ClientPtr is logged
- [ ] Start Audio button becomes enabled
- [ ] Can call startVoice() and see result logged
- [ ] Error -50 OR audio playback captured in logs
- [ ] Can stop audio and disconnect
- [ ] All debug logs are comprehensive and useful

---

## 🎯 Story 3 Complete Checklist

**Check all before proceeding to Story 4:**

### Connection Management
- [ ] Can connect to camera via P2P
- [ ] Connection state displays correctly
- [ ] ClientPtr is obtained and logged
- [ ] Can disconnect cleanly

### Audio Controls
- [ ] Can start audio stream
- [ ] Can stop audio stream
- [ ] Can toggle mute
- [ ] Buttons enable/disable correctly

### UI & Logging
- [ ] All three UI sections render
- [ ] Debug logs display with timestamps
- [ ] Color coding helps identify issues
- [ ] Auto-scroll keeps latest logs visible

### Error Handling
- [ ] Connection errors are caught and displayed
- [ ] Audio errors (including error -50) are logged
- [ ] App doesn't crash on errors
- [ ] Can retry after errors

---

## 🎉 Story 3 Deliverables

Once complete, you will have:
- ✅ Complete iOS UI for audio testing
- ✅ P2P connection working end-to-end
- ✅ Audio control methods callable from UI
- ✅ Comprehensive debug logging
- ✅ Ready to test audio solutions in Story 4

**Next**: Proceed to [Story 4: Testing Audio Solutions](../story-4-testing-strategies/README.md)

---

## 🚨 Expected Outcomes

At the end of Story 3, one of two things will happen:

### Outcome A: Audio Works! 🎉
- You hear audio from the camera through your iPhone
- Logs show "✅ Audio started successfully"
- No error -50
- **Result**: Skip to documenting the solution for SciSymbioLens

### Outcome B: Error -50 Occurs (Expected) ⚠️
- Logs show "❌ startAudio failed: Error -50 (kAudioUnitErr_FormatNotSupported)"
- No audio is heard
- App doesn't crash
- **Result**: Proceed to Story 4 to test alternative audio session configurations

---

**Created**: 2026-02-02
**Based on**: story-3-camera-connection-audio.md original story
**Source**: SciSymbioLens codebase patterns
