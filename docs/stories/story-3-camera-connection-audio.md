# Story 3: Camera Connection and Audio Streaming

**Epic**: VeepaAudioTest - Minimal Audio Testing App
**Story**: Implement camera connection and audio playback
**Estimated Time**: 1-1.5 hours

---

## 📋 Story Description

As a **developer**, I want to **connect to the Veepa camera via P2P and start audio streaming** so that **I can test if the basic audio API works before trying advanced solutions**.

---

## ✅ Acceptance Criteria

1. User can enter camera UID and serviceParam manually
2. App establishes P2P connection and gets valid clientPtr
3. "Start Audio" button calls `startVoice()` and logs the result
4. "Stop Audio" button calls `stopVoice()` and logs the result
5. All SDK calls and responses are logged to debug console
6. Connection state is displayed in UI
7. Audio errors (including error -50) are captured and displayed

---

## 🔧 Implementation Steps

### Step 3.1: Create Connection Service (30 minutes)

Create `ios/VeepaAudioTest/VeepaAudioTest/Services/AudioConnectionService.swift`:

```swift
import Foundation

@MainActor
final class AudioConnectionService: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var clientPtr: Int? = nil
    @Published var debugLogs: [String] = []

    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case error(String)

        var description: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .error(let msg): return "Error: \(msg)"
            }
        }
    }

    private let flutterEngine = FlutterEngineManager.shared
    private let connectionBridge = VeepaConnectionBridge.shared

    func connect(uid: String, serviceParam: String) async {
        log("🔌 Connecting to camera...")
        log("   UID: \(uid)")
        log("   ServiceParam: \(serviceParam.prefix(20))...")

        connectionState = .connecting

        do {
            // Initialize Flutter if needed
            if !flutterEngine.isFlutterReady {
                log("   Initializing Flutter engine...")
                try await flutterEngine.initializeAndWaitForReady(timeout: 10.0)
                log("   ✅ Flutter ready")
            }

            // Connect via VeepaConnectionBridge
            log("   Establishing P2P connection...")
            try await connectionBridge.connect(uid: uid, serviceParam: serviceParam)

            // Get clientPtr
            guard let ptr = connectionBridge.clientPtr else {
                throw NSError(domain: "AudioTest", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Connection succeeded but clientPtr is nil"
                ])
            }

            clientPtr = ptr
            connectionState = .connected
            log("   ✅ Connected! clientPtr: \(ptr)")

            // Notify Flutter of clientPtr
            try await flutterEngine.invoke("setClientPtr", arguments: ptr)
            log("   ✅ Flutter notified of clientPtr")

        } catch {
            connectionState = .error(error.localizedDescription)
            log("   ❌ Connection failed: \(error.localizedDescription)")
        }
    }

    func disconnect() async {
        log("🔌 Disconnecting...")

        do {
            try await connectionBridge.disconnect()
            clientPtr = nil
            connectionState = .disconnected
            log("   ✅ Disconnected")
        } catch {
            log("   ❌ Disconnect error: \(error.localizedDescription)")
        }
    }

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)"
        debugLogs.append(entry)
        print(entry)
    }
}
```

---

### Step 3.2: Create Audio Service (20 minutes)

Create `ios/VeepaAudioTest/VeepaAudioTest/Services/AudioStreamService.swift`:

```swift
import Foundation
import AVFoundation

@MainActor
final class AudioStreamService: ObservableObject {
    @Published var isPlaying = false
    @Published var isMuted = false
    @Published var debugLogs: [String] = []

    private let flutterEngine = FlutterEngineManager.shared
    private var audioSession: AVAudioSession?

    enum AudioError: Error, LocalizedError {
        case notConnected
        case flutterError(String)

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "Camera not connected (no clientPtr)"
            case .flutterError(let msg):
                return "Flutter error: \(msg)"
            }
        }
    }

    func startAudio() async throws {
        log("🎵 Starting audio...")

        // Configure AVAudioSession
        try configureAudioSession()

        // Call Flutter method
        do {
            let result = try await flutterEngine.invoke("startAudio")
            log("   startVoice result: \(result ?? "nil")")

            isPlaying = true
            log("   ✅ Audio started")

        } catch {
            log("   ❌ startAudio failed: \(error.localizedDescription)")
            throw error
        }
    }

    func stopAudio() async throws {
        log("🛑 Stopping audio...")

        do {
            let result = try await flutterEngine.invoke("stopAudio")
            log("   stopVoice result: \(result ?? "nil")")

            isPlaying = false
            log("   ✅ Audio stopped")

            // Deactivate audio session
            deactivateAudioSession()

        } catch {
            log("   ❌ stopAudio failed: \(error.localizedDescription)")
            throw error
        }
    }

    func setMute(_ muted: Bool) async throws {
        log("🔇 Setting mute: \(muted)")

        do {
            let result = try await flutterEngine.invoke("setMute", arguments: muted)
            log("   setMute result: \(result ?? "nil")")

            isMuted = muted
            log("   ✅ Mute set to \(muted)")

        } catch {
            log("   ❌ setMute failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - AVAudioSession Configuration

    private func configureAudioSession() throws {
        log("   Configuring AVAudioSession...")

        let session = AVAudioSession.sharedInstance()
        audioSession = session

        do {
            // Set category to playAndRecord with defaultToSpeaker
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setMode(.videoChat)
            try session.setActive(true)

            log("   ✅ AVAudioSession configured")
            log("      Category: \(session.category.rawValue)")
            log("      Mode: \(session.mode.rawValue)")
            log("      SampleRate: \(session.sampleRate) Hz")
            log("      IOBufferDuration: \(session.ioBufferDuration * 1000) ms")

        } catch {
            log("   ❌ AVAudioSession configuration failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func deactivateAudioSession() {
        log("   Deactivating AVAudioSession...")

        do {
            try audioSession?.setActive(false, options: .notifyOthersOnDeactivation)
            log("   ✅ AVAudioSession deactivated")
        } catch {
            log("   ⚠️ AVAudioSession deactivation warning: \(error.localizedDescription)")
        }
    }

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)"
        debugLogs.append(entry)
        print(entry)
    }
}
```

---

### Step 3.3: Update ContentView UI (30 minutes)

Replace `ios/VeepaAudioTest/VeepaAudioTest/Views/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var connectionService = AudioConnectionService()
    @StateObject private var audioService = AudioStreamService()

    @State private var uid = ""
    @State private var serviceParam = ""
    @State private var showingError = false
    @State private var errorMessage = ""

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

            // UID Input
            TextField("Camera UID (e.g., ABCD-123456-ABCDE)", text: $uid)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.allCharacters)
                .disabled(isConnected)

            // Service Param Input
            TextField("Service Param (from authentication API)", text: $serviceParam)
                .textFieldStyle(.roundedBorder)
                .disabled(isConnected)

            // Connect/Disconnect Button
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

    // MARK: - Debug Log Section

    private var debugLogSection: some View {
        VStack(spacing: 8) {
            Text("Debug Log")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(allLogs.indices, id: \.self) { index in
                            Text(allLogs[index])
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(logColor(for: allLogs[index]))
                                .id(index)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .onChange(of: allLogs.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(allLogs.count - 1, anchor: .bottom)
                    }
                }
            }
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

    private var allLogs: [String] {
        connectionService.debugLogs + audioService.debugLogs
    }

    private func logColor(for message: String) -> Color {
        if message.contains("❌") { return .red }
        if message.contains("✅") { return .green }
        if message.contains("⚠️") { return .orange }
        return .primary
    }

    // MARK: - Actions

    private func toggleConnection() {
        Task {
            if isConnected {
                await connectionService.disconnect()
            } else {
                await connectionService.connect(uid: uid, serviceParam: serviceParam)
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
}

#Preview {
    ContentView()
}
```

---

### Step 3.4: Test Connection and Audio (20 minutes)

**Prepare Test Credentials**:
1. Get camera UID from camera label or provisioning process
2. Get serviceParam by calling authentication API:

```bash
curl -X POST https://authentication.eye4.cn/getInitstring \
  -H "Content-Type: application/json" \
  -d '{"uid": ["ABCD"]}' # First 4 chars of UID

# Response: ["long_base64_service_param_string"]
```

**Run Tests**:

1. **Test Connection**:
   - Enter UID and serviceParam
   - Tap "Connect"
   - ✅ **Expected**: Status changes to "Connected", clientPtr logged

2. **Test Audio Start**:
   - Tap "Start Audio"
   - ✅ **Expected**: One of:
     - Audio plays from camera (SUCCESS!)
     - Error -50 logged (expected failure, but demonstrates SDK is being called)

3. **Test Audio Stop**:
   - Tap "Stop Audio"
   - ✅ **Expected**: stopVoice() result logged

4. **Test Mute**:
   - Tap "Mute"
   - ✅ **Expected**: setMute(true) result logged

---

## 🧪 Testing & Verification

### Test 1: Connection Succeeds
```
Debug Log Output:
[10:30:15] 🔌 Connecting to camera...
[10:30:15]    UID: ABCD-123456-ABCDE
[10:30:15]    ServiceParam: eyJhbGciOiJIUzI1NiIsIn...
[10:30:16]    ✅ Flutter ready
[10:30:17]    Establishing P2P connection...
[10:30:20]    ✅ Connected! clientPtr: 123456789
[10:30:20]    ✅ Flutter notified of clientPtr
```

### Test 2: Audio Start Called
```
Debug Log Output:
[10:30:25] 🎵 Starting audio...
[10:30:25]    Configuring AVAudioSession...
[10:30:25]    ✅ AVAudioSession configured
[10:30:25]       Category: AVAudioSessionCategoryPlayAndRecord
[10:30:25]       Mode: AVAudioSessionModeVideoChat
[10:30:25]       SampleRate: 48000.0 Hz
[10:30:25]       IOBufferDuration: 10.0 ms
[10:30:26]    startVoice result: 0
[10:30:26]    ✅ Audio started
```

OR (expected failure):

```
[10:30:26]    ❌ startAudio failed: Error -50 (kAudioUnitErr_FormatNotSupported)
```

### Test 3: Audio Plays (Success Case)
- ✅ Hear audio from camera through iPhone speaker
- ✅ No crashes
- ✅ Can start/stop multiple times

### Test 4: Error -50 (Expected Failure Case)
- ✅ Error is logged with full details
- ✅ App doesn't crash
- ✅ Can disconnect and reconnect

---

## 📊 Deliverables

After completing this story:

- [x] `AudioConnectionService.swift` - P2P connection management
- [x] `AudioStreamService.swift` - Audio playback control with AVAudioSession
- [x] `ContentView.swift` - Full UI with connection, audio controls, and debug log
- [x] Can connect to camera and get clientPtr
- [x] Can call startVoice() and capture result/error
- [x] All SDK interactions are logged
- [x] Audio either works OR error -50 is clearly documented

---

## 🚨 Common Issues

### Issue 1: Connection timeout
**Error**: `P2P connection timeout`
**Fix**:
1. Verify camera is powered on and on same WiFi
2. Check UID is correct (15 characters)
3. Verify serviceParam is fresh (expires after ~10 minutes)

### Issue 2: clientPtr is 0
**Error**: `clientPtr is nil or 0`
**Fix**: Connection failed - check camera network connectivity

### Issue 3: Error -50 (Expected)
**Error**: `kAudioUnitErr_FormatNotSupported`
**Status**: This is the expected failure we're investigating!
**Next Step**: Proceed to Story 4 to test solutions

---

## ⏭️ Next Story

**Story 4**: Testing Audio Session Solutions

This story implements 3 different approaches to fix error -50:
- Pre-initialize audio session
- Method swizzling
- Locked audio session configuration
