# ViewModels Reference

Complete reference for all ViewModel classes in the application.

## ViewModel Overview

ViewModels follow the MVVM pattern, acting as the bridge between Views (SwiftUI) and Services (business logic). They:

1. Hold UI state as `@Published` properties
2. Expose methods for user actions
3. Subscribe to service updates via Combine
4. Handle async operations with proper error handling

---

## CameraViewModel

**Location**: `ViewModels/CameraViewModel.swift`
**Purpose**: State management for camera tab

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `isRecording` | `Bool` | Video recording state |
| `isSessionRunning` | `Bool` | Camera session active |
| `zoomLevel` | `CGFloat` | Current zoom (1.0+) |
| `focusPoint` | `CGPoint?` | Current focus point |
| `resolution` | `VideoResolution` | Selected resolution |
| `lastCapturedPhotoURL` | `URL?` | Last photo URL |
| `lastRecordedVideoURL` | `URL?` | Last video URL |
| `error` | `CameraError?` | Current error |
| `showPhotoSuccess` | `Bool` | Photo capture toast |
| `showRecordingComplete` | `Bool` | Recording complete toast |

### Methods

```swift
// Lifecycle
func onAppear()
func onDisappear()

// Recording
func startRecording()
func stopRecording()
func toggleRecording()

// Photo Capture
func capturePhoto()

// Camera Controls
func setZoom(_ level: CGFloat)
func focus(at point: CGPoint)
func setResolution(_ resolution: VideoResolution)
func switchCamera()

// Error Handling
func clearError()
```

### Dependencies

- `CameraManager`
- `CameraSourceManager`

### Usage Example

```swift
struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        ZStack {
            CameraPreview(session: viewModel.captureSession)

            VStack {
                // Recording indicator
                if viewModel.isRecording {
                    RecordingIndicator()
                }

                Spacer()

                // Controls
                HStack {
                    Button(action: viewModel.capturePhoto) {
                        Image(systemName: "camera")
                    }

                    Button(action: viewModel.toggleRecording) {
                        Image(systemName: viewModel.isRecording ? "stop.circle" : "record.circle")
                    }
                }
            }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }
}
```

---

## ChatViewModel

**Location**: `ViewModels/ChatViewModel.swift`
**Purpose**: State management for chat tab

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `messages` | `[ChatMessage]` | Conversation history |
| `inputText` | `String` | Current input text |
| `isLoading` | `Bool` | Waiting for response |
| `isStreaming` | `Bool` | Response streaming |
| `streamingResponse` | `String` | Current streaming text |
| `pendingImage` | `Data?` | Image to send |
| `pendingVideo` | `URL?` | Video to send |
| `error` | `GeminiError?` | Current error |

### Methods

```swift
// Lifecycle
func onAppear()
func onDisappear()

// Messaging
func sendMessage()
func sendMessage(_ text: String)
func sendImageMessage(_ imageData: Data, caption: String?)
func sendVideoMessage(_ videoURL: URL, caption: String?)

// Media Attachment
func attachImage(_ data: Data)
func attachVideo(_ url: URL)
func clearAttachment()

// History
func clearConversation()
func loadConversation()

// Error Handling
func clearError()
```

### Dependencies

- `GeminiChatService`
- `ConversationStore`
- `VoiceEngine`

### Usage Example

```swift
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        VStack {
            // Message list
            ScrollView {
                ForEach(viewModel.messages) { message in
                    MessageBubble(message: message)
                }

                // Streaming response
                if viewModel.isStreaming {
                    MessageBubble(
                        message: ChatMessage(
                            role: .assistant,
                            content: .text(viewModel.streamingResponse)
                        )
                    )
                }
            }

            // Input area
            HStack {
                TextField("Message", text: $viewModel.inputText)

                Button(action: viewModel.sendMessage) {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
            }
        }
        .onAppear { viewModel.onAppear() }
    }
}
```

---

## VideoStreamViewModel

**Location**: `ViewModels/VideoStreamViewModel.swift`
**Purpose**: State management for real-time video streaming to Gemini

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `isStreaming` | `Bool` | Streaming active |
| `isConnected` | `Bool` | Gemini session connected |
| `frameRate` | `Int` | Current FPS setting |
| `framesSubmitted` | `Int` | Total frames sent |
| `latestResponse` | `String` | Current AI response |
| `error` | `Error?` | Current error |

### Methods

```swift
// Streaming Control
func startStreaming()
func stopStreaming()
func toggleStreaming()

// Configuration
func setFrameRate(_ fps: Int)

// Text Input (during streaming)
func sendTextPrompt(_ text: String)

// Error Handling
func clearError()
```

### Dependencies

- `StreamingService`
- `GeminiSessionManager`
- `CameraSourceManager`

### Usage Example

```swift
struct VideoStreamModeView: View {
    @StateObject private var viewModel = VideoStreamViewModel()

    var body: some View {
        VStack {
            // Camera preview
            CameraPreview()

            // AI Response overlay
            if !viewModel.latestResponse.isEmpty {
                ResponseOverlay(text: viewModel.latestResponse)
            }

            // Controls
            HStack {
                Slider(value: Binding(
                    get: { Double(viewModel.frameRate) },
                    set: { viewModel.setFrameRate(Int($0)) }
                ), in: 1...30)

                Button(action: viewModel.toggleStreaming) {
                    Image(systemName: viewModel.isStreaming ? "stop.fill" : "play.fill")
                }
            }
        }
    }
}
```

---

## GalleryViewModel

**Location**: `ViewModels/GalleryViewModel.swift`
**Purpose**: State management for gallery tab

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `mediaItems` | `[MediaItem]` | All media items |
| `selectedItem` | `MediaItem?` | Currently selected |
| `isLoading` | `Bool` | Loading items |
| `uploadStatuses` | `[UUID: UploadStatus]` | Upload status map |
| `error` | `Error?` | Current error |

### Methods

```swift
// Lifecycle
func onAppear()
func refreshItems()

// Selection
func selectItem(_ item: MediaItem)
func clearSelection()

// Actions
func deleteItem(_ item: MediaItem)
func uploadItem(_ item: MediaItem)
func retryUpload(_ item: MediaItem)
func sendToChat(_ item: MediaItem)

// Error Handling
func clearError()
```

### Dependencies

- `UploadQueue`
- `UploadStatusStore`
- `UploadService`

### Usage Example

```swift
struct GalleryView: View {
    @StateObject private var viewModel = GalleryViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                    ForEach(viewModel.mediaItems) { item in
                        MediaItemCell(item: item)
                            .overlay(alignment: .topTrailing) {
                                UploadStatusBadge(
                                    status: viewModel.uploadStatuses[item.id] ?? .pending
                                )
                            }
                            .onTapGesture {
                                viewModel.selectItem(item)
                            }
                    }
                }
            }
            .sheet(item: $viewModel.selectedItem) { item in
                MediaPreviewSheet(item: item)
            }
        }
        .onAppear { viewModel.onAppear() }
    }
}
```

---

## MediaPreviewViewModel

**Location**: `ViewModels/MediaPreviewViewModel.swift`
**Purpose**: State management for single media item preview

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `mediaItem` | `MediaItem` | The media item |
| `isPlaying` | `Bool` | Video playback state |
| `uploadStatus` | `UploadStatus` | Upload status |
| `analysisResult` | `String?` | AI analysis result |
| `isAnalyzing` | `Bool` | Analysis in progress |
| `error` | `Error?` | Current error |

### Methods

```swift
// Video Playback
func play()
func pause()
func seek(to time: CMTime)

// Actions
func upload()
func delete()
func analyzeWithGemini(prompt: String)
func sendToChat()

// Sharing
func share()
func saveToPhotos()

// Error Handling
func clearError()
```

### Dependencies

- `UploadService`
- `GeminiSDKService`
- `VideoAnalysisService`

---

## SettingsViewModel

**Location**: `ViewModels/SettingsViewModel.swift`
**Purpose**: State management for settings tab

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `apiKey` | `String` | Gemini API key (masked) |
| `hasValidApiKey` | `Bool` | Key validation status |
| `videoResolution` | `VideoResolution` | Recording resolution |
| `framesPerSecond` | `Int` | Streaming FPS |
| `autoUpload` | `Bool` | Auto-upload enabled |
| `voiceEnabled` | `Bool` | TTS enabled |
| `currentCameraSource` | `CameraSourceType` | Active source |
| `connectedVeepaDevice` | `VeepaDevice?` | Connected device |
| `isValidatingKey` | `Bool` | Key validation in progress |
| `error` | `Error?` | Current error |

### Methods

```swift
// API Key
func saveApiKey(_ key: String)
func validateApiKey() async
func clearApiKey()

// Camera Settings
func setResolution(_ resolution: VideoResolution)
func setFrameRate(_ fps: Int)
func setCameraSource(_ source: CameraSourceType)

// Upload Settings
func setAutoUpload(_ enabled: Bool)
func clearUploadQueue()

// Voice Settings
func setVoiceEnabled(_ enabled: Bool)

// Veepa Camera
func disconnectVeepaCamera()
func forgetVeepaCamera()

// App Management
func clearConversationHistory()
func clearAllData()
```

### Dependencies

- `GeminiKeyManager`
- `AppSettings`
- `CameraSourceManager`
- `VeepaConnectionBridge`
- `UploadQueue`
- `ConversationStore`

### Usage Example

```swift
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            Section("Gemini API") {
                SecureField("API Key", text: $viewModel.apiKey)

                Button("Validate") {
                    Task { await viewModel.validateApiKey() }
                }
                .disabled(viewModel.isValidatingKey)

                if viewModel.hasValidApiKey {
                    Label("Valid", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            Section("Camera") {
                Picker("Resolution", selection: $viewModel.videoResolution) {
                    ForEach(VideoResolution.allCases, id: \.self) { res in
                        Text(res.displayName).tag(res)
                    }
                }

                Stepper("FPS: \(viewModel.framesPerSecond)",
                        value: $viewModel.framesPerSecond, in: 1...30)
            }

            Section("Upload") {
                Toggle("Auto-upload", isOn: $viewModel.autoUpload)
            }
        }
    }
}
```

---

## ViewModelProtocol

**Location**: `ViewModels/ViewModelProtocol.swift`
**Purpose**: Common interface for ViewModels

### Definition

```swift
protocol ViewModelProtocol: ObservableObject {
    associatedtype State

    var state: State { get }

    func onAppear()
    func onDisappear()
}

// Extension with default implementations
extension ViewModelProtocol {
    func onAppear() {}
    func onDisappear() {}
}
```

---

## Common Patterns

### Async Operation Pattern

```swift
class SomeViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?

    func performAction() {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }

            do {
                try await someService.doSomething()
            } catch {
                self.error = error
            }
        }
    }
}
```

### Combine Binding Pattern

```swift
class SomeViewModel: ObservableObject {
    @Published var state: SomeState = .initial

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        SomeService.shared.$state
            .receive(on: DispatchQueue.main)
            .assign(to: &$state)

        // Or with sink for more control
        SomeService.shared.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.handleStateChange(newState)
            }
            .store(in: &cancellables)
    }
}
```

### Dependency Injection Pattern

```swift
class SomeViewModel: ObservableObject {
    private let service: SomeService
    private let otherService: OtherService

    // Default initializer for production
    init(
        service: SomeService = .shared,
        otherService: OtherService = .shared
    ) {
        self.service = service
        self.otherService = otherService
    }

    // In tests
    // let mockService = MockSomeService()
    // let viewModel = SomeViewModel(service: mockService)
}
```

### Error Display Pattern

```swift
struct SomeView: View {
    @StateObject var viewModel = SomeViewModel()

    var body: some View {
        content
            .alert(
                "Error",
                isPresented: .init(
                    get: { viewModel.error != nil },
                    set: { if !$0 { viewModel.clearError() } }
                ),
                presenting: viewModel.error
            ) { _ in
                Button("OK") { viewModel.clearError() }
            } message: { error in
                Text(error.localizedDescription)
            }
    }
}
```

---

*Last updated: January 2026*
