// ADAPTED FROM: Story 3 original ContentView structure
// Changes: Three-section layout (Connection, Audio, Debug Log)
//   - Removed video preview section
//   - Removed discovery features
//   - Pre-filled test credentials for convenience
//
// TEST CAMERA CREDENTIALS (hard-coded):
// - UID: OKB0379853SNLJ
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
    // Camera: OKB0379853SNLJ (test camera from SciSymbioLens)
    // WiFi: 6wKe727e (if needed for provisioning)
    @State private var uid = "OKB0379853SNLJ"
    @State private var serviceParam = "888888"
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedStrategyIndex = 0

    // MARK: - Body

    var body: some View {
        NavigationView {
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
                .onChange(of: uid) { _, newValue in
                    // Validate UID format (15 characters with dashes)
                    if newValue.count > 18 {
                        uid = String(newValue.prefix(18))
                    }
                }

            // Service Param Input
            TextField("Service Param (from authentication API)", text: $serviceParam)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .autocorrectionDisabled(true)
                .disabled(isConnected)

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
            .disabled(isConnecting || (!isConnected && (uid.isEmpty || serviceParam.isEmpty)))
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
                // Connect
                await connectionService.connect(uid: uid, serviceParam: serviceParam)

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

// MARK: - Preview

#Preview {
    ContentView()
}
