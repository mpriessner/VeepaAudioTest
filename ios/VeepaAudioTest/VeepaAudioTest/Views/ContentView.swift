// ADAPTED FROM: Story 3 original ContentView structure
// Changes: Three-section layout (Connection, Audio, Debug Log)
//   - Removed video preview section
//   - Removed discovery features
//   - Pre-filled test credentials for convenience
//
// TEST CAMERA CREDENTIALS (hard-coded):
// - UID: OKB0379832YFIY (changed from OKB0401422WRKF - battery died)
// - Password: 888888
// - WiFi Password (if needed): 6wKe727e
//
// Note: Verify the UID matches your physical camera label
//
import SwiftUI

struct ContentView: View {
    // MARK: - State Management

    @StateObject private var connectionService = AudioConnectionService()
    @StateObject private var audioService = AudioStreamService()

    // Pre-filled test credentials for convenience
    // Camera: OKB0379196OXYB (current test camera - changed 2026-02-04)
    // Password: 888888 (default camera password)
    // Note: Credentials are now fetched automatically from cloud!
    @State private var uid = "OKB0379196OXYB"
    @State private var password = "888888"
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedStrategyIndex = 0

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Connection Section
                    connectionSection

                    Divider()

                    // Strategy Selection Section
                    strategySelectionSection

                    Divider()

                    // Audio Controls Section
                    audioControlsSection

                    Divider()

                    // Debug Log Section (fixed height)
                    debugLogSection
                        .frame(height: 200)
                }
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
            TextField("Camera UID (e.g., OKB0379853SNLJ)", text: $uid)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.allCharacters)
                .disabled(isConnected)
                .onChange(of: uid) { _, newValue in
                    // Validate UID format
                    if newValue.count > 20 {
                        uid = String(newValue.prefix(20))
                    }
                }

            // Password Input
            SecureField("Camera Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .disabled(isConnected)

            Text("💡 Tip: Credentials are fetched automatically from cloud!")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)

            // Connect/Disconnect Button
            Button(action: toggleConnection) {
                HStack {
                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(isConnected ? "Disconnect" : "Connect")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(connectionButtonColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isConnecting || (!isConnected && uid.isEmpty))
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

            // PROOF OF CONCEPT: Test P2P Audio Channel Read
            Divider()
                .padding(.vertical, 4)

            Text("🧪 Proof of Concept")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Test AudioBridgeEngine independently (no camera needed)
            Button(action: testAudioBridgeEngine) {
                HStack {
                    Image(systemName: "waveform.circle.fill")
                    Text("Test Audio Engine (440Hz)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.cyan)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            Text("Plays a 440Hz test tone to verify AudioBridgeEngine works")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)

            Button(action: testP2PChannelDirect) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Test P2P Channels")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isConnected ? Color.purple : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!isConnected || isConnecting)

            Text("CRITICAL TEST: Reads from P2P channels directly. Check Xcode console for results.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)

            // Test AudioUnit Hook discovery
            Button(action: testAudioHook) {
                HStack {
                    Image(systemName: "link.circle.fill")
                    Text("Test SDK Hook")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.indigo)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            Text("Discovers SDK's AppIOSPlayer and AudioUnit for hooking")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)

            // Story 10.1: Test pcmp2 Listener (FAILED - symbols not exported)
            Button(action: testPcmp2Listener) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                    Text("Test pcmp2 (Failed)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            Text("Story 10.1: FAILED - SDK doesn't export pcmp2 symbols")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)

            // Story 10.2: Test Audio CGI Commands
            Button(action: testAudioCgi) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                    Text("Test Audio CGI")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isConnected ? Color.orange : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!isConnected)

            Text("Story 10.2: Sends CGI commands + monitors buffer")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)

            // Story 10.3: P2P Audio Interception
            Button(action: testStory103) {
                HStack {
                    Image(systemName: "waveform.badge.plus")
                    Text("Test P2P Capture (10.3)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isConnected ? Color.purple : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!isConnected)

            Text("Story 10.3: Allocates buffer + CGI + P2P capture")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
    }

    // MARK: - Strategy Selection Section

    private var strategySelectionSection: some View {
        VStack(spacing: 12) {
            Text("Test Strategy")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Audio Strategy", selection: $selectedStrategyIndex) {
                ForEach(audioService.strategies.indices, id: \.self) { index in
                    Text(audioService.strategies[index].name)
                        .tag(index)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedStrategyIndex) { _, newIndex in
                audioService.currentStrategy = audioService.strategies[newIndex]
            }
            .disabled(isConnected && audioService.isPlaying)

            Text(audioService.currentStrategy.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            // Warning for swizzled strategy
            if audioService.currentStrategy.name == "Swizzled" {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Requires app restart to reset")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
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
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .onChange(of: allLogs.count) { _, _ in
                    // Auto-scroll to bottom when new log added
                    withAnimation {
                        proxy.scrollTo(allLogs.count - 1, anchor: .bottom)
                    }
                }
            }

            // Log count indicator
            HStack {
                Text("\(allLogs.count) log entries")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
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

    private var connectionButtonColor: Color {
        if isConnecting {
            return .orange
        }
        return isConnected ? .red : .blue
    }

    // MARK: - Log Helpers

    private var allLogs: [String] {
        // Combine logs from both services in chronological order
        // Both services append logs with timestamps, so simple concatenation works
        return connectionService.debugLogs + audioService.debugLogs
    }

    private func logColor(for message: String) -> Color {
        if message.contains("❌") { return .red }
        if message.contains("✅") { return .green }
        if message.contains("⚠️") { return .orange }
        if message.contains("🔌") || message.contains("🎵") { return .blue }
        return .primary
    }

    // MARK: - Actions

    private func toggleConnection() {
        Task {
            if isConnected {
                // Disconnect
                await connectionService.disconnect()
            } else {
                // Connect with automatic credential fetching (Quick Test Mode)
                await connectionService.connect(uid: uid, password: password)

                // Check for connection errors
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
                    // Stop voice frame capture first
                    AudioHookBridge.shared.stopVoiceFrameCapture()
                    try await audioService.stopAudio()
                } else {
                    // Check if hook is installed - if so, skip PreInit to avoid disrupting AudioBridgeEngine
                    if AudioHookBridge.shared.isHooked {
                        print("[ContentView] 🔗 Hook is active - starting audio WITHOUT PreInit")
                        print("[ContentView] 💡 This preserves AudioBridgeEngine's audio session")

                        // Just call startVoice directly without reconfiguring audio session
                        try await audioService.startAudioDirect()

                        // Start G.711a voice frame capture (bypasses broken AudioUnit)
                        print("[ContentView] 🎙️ Starting G.711a voice frame capture...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            AudioHookBridge.shared.startVoiceFrameCapture()
                        }
                    } else {
                        // Normal flow with PreInit strategy
                        try await audioService.startAudio()
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func testP2PAudioChannel() {
        Task {
            // Get clientPtr from connection service
            guard let clientPtr = connectionService.clientPtr else {
                errorMessage = "No active P2P connection"
                showingError = true
                return
            }

            // First, start audio streaming from camera
            // This triggers the camera to send audio on channel 2
            do {
                if !audioService.isPlaying {
                    try await audioService.startAudio()
                }
            } catch {
                errorMessage = "Failed to start audio: \(error.localizedDescription)"
                showingError = true
                return
            }

            // Run verification test instead of regular test
            // This will compare video (ch1) vs audio (ch2) to prove/disprove hypothesis
            await VSTCBridge.shared.verifyChannelStatus(clientPtr: clientPtr)
        }
    }

    /// Test P2P channels directly WITHOUT starting audio
    /// This helps determine if audio data exists on the P2P connection
    /// independently of the SDK's broken audio pipeline
    private func testP2PChannelDirect() {
        Task {
            print("[ContentView] ═══════════════════════════════════════════════")
            print("[ContentView] 🔬 P2P CHANNEL DIRECT TEST")
            print("[ContentView] ═══════════════════════════════════════════════")
            print("[ContentView] This tests P2P channels WITHOUT SDK audio start")
            print("[ContentView] Goal: Determine if audio data exists at P2P layer")

            // Get clientPtr from connection service
            guard let clientPtr = connectionService.clientPtr else {
                print("[ContentView] ❌ No active P2P connection")
                errorMessage = "No active P2P connection"
                showingError = true
                return
            }

            print("[ContentView] ✅ Client pointer: \(clientPtr)")
            print("[ContentView]")
            print("[ContentView] Phase 1: Test channels WITHOUT audio start")
            print("[ContentView] ─────────────────────────────────────────────")

            // Run verification test WITHOUT starting audio first
            await VSTCBridge.shared.verifyChannelStatus(clientPtr: clientPtr)

            print("[ContentView]")
            print("[ContentView] Phase 2: Now try with SDK audio start (triggers camera)")
            print("[ContentView] ─────────────────────────────────────────────")

            // Now start audio (this may trigger camera to send audio)
            do {
                if !audioService.isPlaying {
                    print("[ContentView] Starting audio via SDK (may trigger camera)...")
                    try await audioService.startAudio()

                    // Wait a moment for camera to start sending
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                    print("[ContentView] Audio start attempted. Testing channels again...")
                    await VSTCBridge.shared.verifyChannelStatus(clientPtr: clientPtr)
                }
            } catch {
                print("[ContentView] ⚠️ Audio start failed: \(error)")
                print("[ContentView] Testing channels anyway...")

                // Wait and test anyway
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await VSTCBridge.shared.verifyChannelStatus(clientPtr: clientPtr)
            }

            print("[ContentView] ═══════════════════════════════════════════════")
            print("[ContentView] 📊 TEST COMPLETE - Check logs above for results")
            print("[ContentView] ═══════════════════════════════════════════════")
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

    /// Test AudioBridgeEngine independently with a 440Hz sine wave
    /// This verifies our audio pipeline works without needing the camera
    private func testAudioBridgeEngine() {
        Task {
            do {
                print("[ContentView] 🧪 Testing AudioBridgeEngine...")

                let engine = AudioBridgeEngine.shared

                // Start the engine
                try engine.start()

                // Generate and play a 1-second test tone
                engine.playTestTone(frequency: 440, duration: 1.0)

                print("[ContentView] 🔊 Test tone should be playing now!")
                print("[ContentView] 💡 If you hear a 440Hz tone, AudioBridgeEngine works!")

                // Stop after 2 seconds (1s tone + 1s buffer)
                try await Task.sleep(nanoseconds: 2_000_000_000)

                engine.stop()
                print("[ContentView] ✅ AudioBridgeEngine test complete")

            } catch {
                print("[ContentView] ❌ AudioBridgeEngine test failed: \(error)")
                errorMessage = "Audio engine test failed: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    /// Test the AudioHookBridge SDK discovery and hooking
    /// This runs the Objective-C bridge to find AppIOSPlayer
    private func testAudioHook() {
        Task {
            print("[ContentView] 🔗 Testing AudioHookBridge...")

            let bridge = AudioHookBridge.shared

            // STEP 1: Start AudioBridgeEngine FIRST so it's ready to receive audio
            print("[ContentView] Step 1: Starting AudioBridgeEngine...")
            do {
                try AudioBridgeEngine.shared.start()
                print("[ContentView] ✅ AudioBridgeEngine started!")
            } catch {
                print("[ContentView] ❌ Failed to start AudioBridgeEngine: \(error)")
            }

            // STEP 2: Set up capture callback BEFORE installing swizzle
            // This ensures the callback is ready when audio starts flowing
            print("[ContentView] Step 2: Setting up capture callback...")

            // Log buffer identity for debugging
            let expectedBufferID = ObjectIdentifier(AudioBridgeEngine.shared.circularBuffer)
            print("[ContentView] 📍 Expected buffer ID: \(expectedBufferID)")

            bridge.captureCallback = { samples, count in
                // Forward captured audio to our bridge engine (runs on audio thread)
                let engine = AudioBridgeEngine.shared
                let buffer = engine.circularBuffer
                let beforeCount = buffer.availableSamples
                engine.pushSamples(samples, count: Int(count))
                let afterCount = buffer.availableSamples

                // Debug: Log occasionally to verify data flow
                struct DebugState {
                    static var logCount = 0
                    static var bufferIDLogged = false
                }

                // Log buffer ID once to verify same instance
                if !DebugState.bufferIDLogged {
                    DebugState.bufferIDLogged = true
                    let bufferID = ObjectIdentifier(buffer)
                    print("[Callback] 📍 Capture buffer ID: \(bufferID)")
                }

                if DebugState.logCount < 10 {
                    DebugState.logCount += 1
                    print("[Callback] ✅ Pushed \(count) samples, buffer: \(beforeCount) → \(afterCount)")
                } else if DebugState.logCount == 10 {
                    DebugState.logCount += 1
                    print("[Callback] 🔇 Silencing further callback logs...")
                }
            }
            print("[ContentView] ✅ Capture callback set")

            // STEP 3: Discover SDK classes (informational)
            print("[ContentView] Step 3: Discovering SDK classes...")
            let discoveries = bridge.discoverSDKClasses()
            for discovery in discoveries {
                print("[ContentView]   \(discovery)")
            }

            // STEP 4: Run self-test (informational)
            print("[ContentView] Step 4: Running self-test...")
            let testResult = bridge.runSelfTest()
            print("[ContentView] Self-test: \(testResult ? "PASSED" : "FAILED")")

            // STEP 5: Install swizzling LAST (after callback is ready)
            print("[ContentView] Step 5: Attempting swizzling...")
            let swizzleResult = bridge.installSwizzling()
            print("[ContentView] Swizzling: \(swizzleResult ? "SUCCESS" : "FAILED")")

            print("[ContentView] ✅ AudioHookBridge setup complete")
            print("[ContentView] 💡 Now press 'Start Audio' to trigger startVoice and begin capture")
            print("[ContentView] Stats: \(bridge.statisticsDescription())")
        }
    }

    /// Story 10.1: Test the pcmp2_setListener API
    /// This attempts to bypass the SDK's broken AudioUnit by using the pcmp2 listener callback
    private func testPcmp2Listener() {
        Task {
            print("[ContentView] ═══════════════════════════════════════")
            print("[ContentView] 🧪 STORY 10.1: Testing pcmp2 Listener")
            print("[ContentView] ═══════════════════════════════════════")

            let bridge = AudioHookBridge.shared

            // Step 1: Resolve pcmp2 symbols
            print("[ContentView] Step 1: Resolving pcmp2 symbols via dlsym...")
            let symbolsResolved = bridge.resolvePcmp2Symbols()
            print("[ContentView] Symbol resolution: \(symbolsResolved ? "SUCCESS ✅" : "FAILED ❌")")

            if !symbolsResolved {
                print("[ContentView] ❌ Cannot proceed - pcmp2 symbols not found")
                print("[ContentView] This means the SDK doesn't export these functions")
                print("[ContentView] Will need to try Story 10.2 (CGI Command) approach instead")
                return
            }

            // Step 2: Investigate pcmp2 in AppIOSPlayer
            print("[ContentView] Step 2: Investigating pcmp2 in AppIOSPlayer...")
            bridge.investigatePcmp2InPlayer()

            // Step 3: Set up capture callback
            print("[ContentView] Step 3: Setting up capture callback...")
            bridge.captureCallback = { samples, count in
                // Forward to AudioBridgeEngine
                let engine = AudioBridgeEngine.shared
                engine.pushSamples(samples, count: Int(count))

                struct PcmpDebug {
                    static var logCount = 0
                }
                if PcmpDebug.logCount < 10 {
                    PcmpDebug.logCount += 1
                    print("[PCMP2-CB] Received \(count) samples from pcmp2!")
                }
            }

            // Step 4: Start AudioBridgeEngine (if not already started)
            print("[ContentView] Step 4: Starting AudioBridgeEngine...")
            do {
                try AudioBridgeEngine.shared.start()
                print("[ContentView] ✅ AudioBridgeEngine started")
            } catch {
                print("[ContentView] ⚠️ AudioBridgeEngine start failed: \(error)")
            }

            // Step 5: Test pcmp2 listener
            print("[ContentView] Step 5: Testing pcmp2 listener...")
            bridge.testPcmp2Listener()

            print("[ContentView] ═══════════════════════════════════════")
            print("[ContentView] 📋 Test setup complete!")
            print("[ContentView] Next: Press 'Start Audio' to trigger SDK audio start")
            print("[ContentView] Watch for [PCMP2-LISTENER] messages in logs")
            print("[ContentView] ═══════════════════════════════════════")
        }
    }

    /// Story 10.2: Test Audio CGI Commands
    /// This sends CGI commands to the camera and monitors the buffer for audio data
    private func testAudioCgi() {
        Task {
            print("[ContentView] ═══════════════════════════════════════")
            print("[ContentView] 🚀 STORY 10.2: Testing Audio CGI Commands")
            print("[ContentView] ═══════════════════════════════════════")

            let bridge = AudioHookBridge.shared

            // Step 1: Check if we have client pointer
            guard let clientPtr = connectionService.clientPtr else {
                print("[ContentView] ❌ No client pointer - connect to camera first!")
                return
            }
            print("[ContentView] ✅ Client pointer: \(clientPtr)")

            // Step 2: Make sure SDK Hook is installed (to capture player instance)
            if !bridge.isHooked {
                print("[ContentView] Step 2: Installing SDK Hook to capture player instance...")
                let _ = bridge.installSwizzling()
            }

            // Step 3: Resolve CGI symbol
            print("[ContentView] Step 3: Resolving CGI symbol...")
            let cgiResolved = bridge.resolveCgiSymbols()
            print("[ContentView] CGI symbol resolved: \(cgiResolved ? "YES ✅" : "NO ❌")")

            if !cgiResolved {
                print("[ContentView] ❌ Cannot proceed - CGI symbol not found")
                return
            }

            // Step 4: Start audio first to get player instance captured
            print("[ContentView] Step 4: Starting SDK audio to capture player instance...")
            do {
                if !audioService.isPlaying {
                    try await audioService.startAudio()
                    // Wait for player to be captured
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
            } catch {
                print("[ContentView] ⚠️ Audio start failed: \(error) - continuing anyway")
            }

            // Step 5: Run the combined CGI + Monitor test
            print("[ContentView] Step 5: Running CGI test with buffer monitor...")
            // Convert Int to UnsafeMutableRawPointer for Obj-C method
            guard let clientRawPtr = UnsafeMutableRawPointer(bitPattern: clientPtr) else {
                print("[ContentView] ❌ Failed to convert clientPtr to pointer")
                return
            }
            bridge.testAudioCgi(withMonitor: clientRawPtr)

            print("[ContentView] ═══════════════════════════════════════")
            print("[ContentView] 📋 Test running!")
            print("[ContentView] Watch for [MONITOR] 🎉 BUFFER CHANGE! messages")
            print("[ContentView] This indicates audio data is arriving!")
            print("[ContentView] ═══════════════════════════════════════")
        }
    }

    /// Story 10.3: P2P Audio Interception Test
    /// This allocates the voice buffer, sends CGI commands, and captures audio from P2P
    private func testStory103() {
        Task {
            print("[ContentView] ═══════════════════════════════════════")
            print("[ContentView] 🚀 STORY 10.3: P2P Audio Interception Test")
            print("[ContentView] ═══════════════════════════════════════")

            let bridge = AudioHookBridge.shared

            // Step 1: Check if we have client pointer
            guard let clientPtr = connectionService.clientPtr else {
                print("[ContentView] ❌ No client pointer - connect to camera first!")
                return
            }
            print("[ContentView] ✅ Client pointer: \(clientPtr)")

            // Step 2: Install SDK Hook if not already done
            print("[ContentView] Step 2: Installing SDK Hook...")
            if !bridge.isHooked {
                let hooked = bridge.installSwizzling()
                print("[ContentView] Hook installed: \(hooked)")
            } else {
                print("[ContentView] Hook already installed")
            }

            // Step 3: Start audio briefly to capture player instance
            print("[ContentView] Step 3: Starting SDK audio to capture player instance...")
            do {
                if !audioService.isPlaying {
                    try await audioService.startAudio()
                    // Wait for player to be captured
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
            } catch {
                print("[ContentView] ⚠️ Audio start failed: \(error) - continuing anyway")
            }

            // Step 4: Run Story 10.3 test
            print("[ContentView] Step 4: Running Story 10.3 test...")
            guard let clientRawPtr = UnsafeMutableRawPointer(bitPattern: clientPtr) else {
                print("[ContentView] ❌ Failed to convert clientPtr to pointer")
                return
            }
            bridge.testStory103(clientRawPtr)

            print("[ContentView] ═══════════════════════════════════════")
            print("[ContentView] 📋 Story 10.3 test running!")
            print("[ContentView] Watch for [P2P-AUDIO] 🎉 DATA AVAILABLE! messages")
            print("[ContentView] The test will run for 30 seconds...")
            print("[ContentView] ═══════════════════════════════════════")
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
