# Sub-Story 3.5: Audio Controls Implementation

**Goal**: Implement audio controls section with start/stop and mute buttons

**Estimated Time**: 15-20 minutes

---

## 📋 Analysis of Source Code

From Story 3 original ContentView audio controls:
- Audio status indicator (playing/stopped)
- Start/Stop button with dynamic label and icon
- Mute/Unmute button (only enabled when playing)
- Buttons disabled when not connected
- Error handling for audio operations

**What to adapt:**
- ✅ Copy button layout patterns
- ✅ Implement toggleAudio() and toggleMute() actions
- ✅ Add proper error alerts
- ✅ Dynamic button states
- ❌ Remove: Volume slider, speaker selection

---

## 🛠️ Implementation Steps

### Step 3.5.1: Update audioControlsSection in ContentView (12 min)

Open `ios/VeepaAudioTest/VeepaAudioTest/Views/ContentView.swift` and replace the `audioControlsSection` implementation:

```swift
// MARK: - Audio Controls Section

private var audioControlsSection: some View {
    VStack(spacing: 12) {
        Text("Audio Controls")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)

        // Audio Status
        HStack {
            Image(systemName: audioService.isPlaying ? "speaker.wave.3.fill" : "speaker.slash.fill")
                .foregroundColor(audioService.isPlaying ? .green : .gray)
            Text(audioService.isPlaying ? "Playing" : "Stopped")
                .font(.subheadline)
            Spacer()
        }

        // Start/Stop Audio Button
        Button(action: toggleAudio) {
            HStack {
                Image(systemName: audioService.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                Text(audioService.isPlaying ? "Stop Audio" : "Start Audio")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isConnected ? Color.green : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(!isConnected || isConnecting)

        // Mute Button
        Button(action: toggleMute) {
            HStack {
                Image(systemName: audioService.isMuted ? "speaker.slash.fill" : "speaker.fill")
                Text(audioService.isMuted ? "Unmute" : "Mute")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isConnected && audioService.isPlaying ? Color.orange : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(!isConnected || !audioService.isPlaying)
    }
    .padding()
}
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest

# Build to check for syntax errors
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

### Step 3.5.2: Implement Audio Action Methods (6 min)

Add the `toggleAudio()` and `toggleMute()` methods to ContentView (replace placeholders):

```swift
// MARK: - Actions

private func toggleConnection() {
    Task {
        if isConnected {
            await connectionService.disconnect()
        } else {
            await connectionService.connect(uid: uid, serviceParam: serviceParam)

            if case .error(let message) = connectionService.connectionState {
                errorMessage = message
                showingError = true
            }
        }
    }
}

private func toggleAudio() {
    Task {
        do {
            if audioService.isPlaying {
                try await audioService.stopAudio()
            } else {
                try await audioService.startAudio()
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

private func toggleMute() {
    Task {
        do {
            try await audioService.setMute(!audioService.isMuted)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest

# Verify all three action methods exist
grep -n "private func toggleConnection" VeepaAudioTest/Views/ContentView.swift
grep -n "private func toggleAudio" VeepaAudioTest/Views/ContentView.swift
grep -n "private func toggleMute" VeepaAudioTest/Views/ContentView.swift
# Expected: All three methods found

# Build
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

### Step 3.5.3: Test Audio Controls UI (4 min)

```bash
cd ios/VeepaAudioTest

# Run in simulator
open VeepaAudioTest.xcodeproj
# In Xcode: Press Cmd+R

# Manual test checklist:
# 1. Audio controls section is visible
# 2. Start Audio button is disabled (gray) when disconnected
# 3. Mute button is disabled when not playing
# 4. After entering connection credentials:
#    - Start Audio button becomes enabled (green)
# 5. Tapping Start Audio attempts to start audio
# 6. If audio starts, Mute button becomes enabled (orange)
```

**Expected UI Behavior:**
- Not connected → Start Audio disabled (gray), Mute disabled (gray)
- Connected but not playing → Start Audio enabled (green), Mute disabled (gray)
- Connected and playing → Stop Audio enabled (green), Mute enabled (orange)
- Muted → Mute button shows "Unmute" with speaker.slash icon

---

## ✅ Sub-Story 3.5 Complete Verification

Run all checks:

```bash
cd ios/VeepaAudioTest

# 1. Verify audio controls section updated
grep -A 40 "private var audioControlsSection" VeepaAudioTest/Views/ContentView.swift
# ✅ Expected: See Start/Stop and Mute buttons

# 2. Verify action methods
grep -A 12 "private func toggleAudio" VeepaAudioTest/Views/ContentView.swift
grep -A 10 "private func toggleMute" VeepaAudioTest/Views/ContentView.swift
# ✅ Expected: See async Task implementations with error handling

# 3. Build succeeds
xcodegen generate
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# ✅ Expected: BUILD SUCCEEDED
```

---

## 🎯 Acceptance Criteria

- [ ] Audio status indicator (playing/stopped with icon)
- [ ] Start/Stop Audio button (changes label and icon)
- [ ] Mute/Unmute button (shows correct icon)
- [ ] Buttons disabled when not connected
- [ ] Mute button only enabled when audio is playing
- [ ] toggleAudio() action implemented with error handling
- [ ] toggleMute() action implemented with error handling
- [ ] Error alerts displayed on audio failures

---

## 🚨 Testing Notes

**At this stage (without real camera connection):**
- Buttons will be disabled until connection succeeds
- This is correct behavior
- Full testing requires completing Sub-Story 3.8 (end-to-end test)

**With real camera connection:**
- Start Audio will call FlutterEngineManager.invoke("startAudio")
- Will either:
  - ✅ Start audio playback (success case)
  - ❌ Show error alert with "Error -50" (expected failure case)

---

## 🔗 Navigation

- ← Previous: [Sub-Story 3.4: Connection Controls](sub-story-3.4-connection-controls.md)
- → Next: [Sub-Story 3.6: Debug Log View](sub-story-3.6-debug-log-view.md)
- ↑ Story Overview: [README.md](README.md)
