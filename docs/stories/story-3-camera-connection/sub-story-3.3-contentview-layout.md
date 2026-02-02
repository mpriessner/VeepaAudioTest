# Sub-Story 3.3: ContentView Layout Structure

**Goal**: Create SwiftUI ContentView with three-section layout and proper state management

**Estimated Time**: 25-30 minutes

---

## 📋 Analysis of Source Code

From Story 3 original ContentView structure:
- Three main sections: Connection, Audio Controls, Debug Log
- Uses @StateObject for services (maintains lifecycle)
- Uses @State for UI-only state (text inputs, alerts)
- Dividers separate sections visually
- NavigationView wrapper for title

**What to adapt:**
- ✅ Copy three-section layout pattern
- ✅ Use @StateObject for AudioConnectionService and AudioStreamService
- ✅ Add @State for UID, serviceParam, error handling
- ✅ Add NavigationView wrapper
- ❌ Remove: Video preview section, discovery features

---

## 🛠️ Implementation Steps

### Step 3.3.1: Create Views Directory (2 min)

```bash
cd /Users/mpriessner/windsurf_repos/VeepaAudioTest

# Create Views directory
mkdir -p ios/VeepaAudioTest/VeepaAudioTest/Views
```

**✅ Verification:**
```bash
ls -la ios/VeepaAudioTest/VeepaAudioTest/Views/
# Expected: Empty directory created
```

---

### Step 3.3.2: Create ContentView.swift Skeleton (20 min)

Create `ios/VeepaAudioTest/VeepaAudioTest/Views/ContentView.swift`:

```swift
// ADAPTED FROM: Story 3 original ContentView structure
import SwiftUI

struct ContentView: View {
    // MARK: - State Management

    @StateObject private var connectionService = AudioConnectionService()
    @StateObject private var audioService = AudioStreamService()

    @State private var uid = ""
    @State private var serviceParam = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connection Section
                connectionSection

                Divider()

                // Audio Controls Section
                audioControlsSection

                Divider()

                // Debug Log Section
                debugLogSection
            }
            .navigationTitle("Veepa Audio Test")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { showingError = false }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        VStack(spacing: 12) {
            Text("Connection")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Connection Status
            HStack {
                Circle()
                    .fill(connectionStatusColor)
                    .frame(width: 12, height: 12)
                Text(connectionService.connectionState.description)
                    .font(.subheadline)
                Spacer()
            }

            // UID Input (will implement in 3.4)
            TextField("Camera UID", text: $uid)
                .textFieldStyle(.roundedBorder)
                .disabled(isConnected)

            // Service Param Input (will implement in 3.4)
            TextField("Service Param", text: $serviceParam)
                .textFieldStyle(.roundedBorder)
                .disabled(isConnected)

            // Connect Button Placeholder (will implement in 3.4)
            Button(action: toggleConnection) {
                Text(isConnected ? "Disconnect" : "Connect")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isConnected ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(isConnecting || uid.isEmpty || serviceParam.isEmpty)
        }
        .padding()
    }

    // MARK: - Audio Controls Section

    private var audioControlsSection: some View {
        VStack(spacing: 12) {
            Text("Audio Controls")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Audio Status (will implement in 3.5)
            HStack {
                Image(systemName: audioService.isPlaying ? "speaker.wave.3.fill" : "speaker.slash.fill")
                    .foregroundColor(audioService.isPlaying ? .green : .gray)
                Text(audioService.isPlaying ? "Playing" : "Stopped")
                    .font(.subheadline)
                Spacer()
            }

            // Placeholder buttons (will implement in 3.5)
            Button(action: toggleAudio) {
                Text(audioService.isPlaying ? "Stop Audio" : "Start Audio")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(!isConnected)
        }
        .padding()
    }

    // MARK: - Debug Log Section

    private var debugLogSection: some View {
        VStack(spacing: 8) {
            Text("Debug Log")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                // Will implement scrollable log in 3.6
                Text("Debug logs will appear here...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(maxHeight: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding()
    }

    // MARK: - Helper Properties

    private var isConnected: Bool {
        if case .connected = connectionService.connectionState {
            return true
        }
        return false
    }

    private var isConnecting: Bool {
        if case .connecting = connectionService.connectionState {
            return true
        }
        return false
    }

    private var connectionStatusColor: Color {
        switch connectionService.connectionState {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }

    // MARK: - Action Placeholders (will implement in 3.4 and 3.5)

    private func toggleConnection() {
        // Will implement in 3.4
        print("toggleConnection called")
    }

    private func toggleAudio() {
        // Will implement in 3.5
        print("toggleAudio called")
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest

# Regenerate Xcode project
xcodegen generate

# Build
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# Expected: BUILD SUCCEEDED
```

---

### Step 3.3.3: Add Views to XcodeGen Config (5 min)

Update `ios/VeepaAudioTest/project.yml`:

```yaml
# In targets → VeepaAudioTest → sources:
sources:
  - path: VeepaAudioTest
    name: App
    type: group
  - path: VeepaAudioTest/Services
    name: Services
    type: group
  - path: VeepaAudioTest/Views  # ADD THIS
    name: Views
    type: group
```

**✅ Verification:**
```bash
cd ios/VeepaAudioTest
xcodegen generate

# Check that Views group appears in project
grep -r "Views" VeepaAudioTest.xcodeproj/project.pbxproj
# Expected: Views group and ContentView.swift referenced
```

---

### Step 3.3.4: Test in Simulator (3 min)

```bash
cd ios/VeepaAudioTest

# Build and run in simulator
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
# Expected: BUILD SUCCEEDED

# Open in Xcode to run
open VeepaAudioTest.xcodeproj
# In Xcode: Select iPhone 15 simulator, press Cmd+R
# Expected: App launches, shows three sections with placeholder UI
```

---

## ✅ Sub-Story 3.3 Complete Verification

Run all checks:

```bash
cd ios/VeepaAudioTest

# 1. File exists
ls -la VeepaAudioTest/Views/ContentView.swift
# ✅ Expected: File present

# 2. Has three section methods
grep -n "connectionSection" VeepaAudioTest/Views/ContentView.swift
grep -n "audioControlsSection" VeepaAudioTest/Views/ContentView.swift
grep -n "debugLogSection" VeepaAudioTest/Views/ContentView.swift
# ✅ Expected: All three sections found

# 3. Has state management
grep -n "@StateObject" VeepaAudioTest/Views/ContentView.swift
grep -n "@State" VeepaAudioTest/Views/ContentView.swift
# ✅ Expected: Both decorators found

# 4. Compiles and runs
xcodegen generate
xcodebuild -project VeepaAudioTest.xcodeproj \
  -scheme VeepaAudioTest \
  -sdk iphonesimulator \
  build
# ✅ Expected: BUILD SUCCEEDED
```

---

## 🎯 Acceptance Criteria

- [ ] ContentView.swift created with three sections
- [ ] VStack with Dividers between sections
- [ ] @StateObject for services (connectionService, audioService)
- [ ] @State for UI state (uid, serviceParam, error alerts)
- [ ] NavigationView wrapper with title
- [ ] Helper properties (isConnected, isConnecting, connectionStatusColor)
- [ ] Action placeholders (toggleConnection, toggleAudio)
- [ ] File compiles without errors

---

## 🔗 Navigation

- ← Previous: [Sub-Story 3.2: Audio Stream Service](sub-story-3.2-audio-stream-service.md)
- → Next: [Sub-Story 3.4: Connection Controls](sub-story-3.4-connection-controls.md)
- ↑ Story Overview: [README.md](README.md)
