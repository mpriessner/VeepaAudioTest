# iOS Architecture

Detailed documentation of the iOS application architecture, patterns, and design decisions.

## Architecture Pattern: MVVM

The iOS app follows the **Model-View-ViewModel (MVVM)** pattern with SwiftUI and Combine for reactive data binding.

```
┌─────────────────────────────────────────────────────────────┐
│                      SwiftUI Views                          │
│  Declarative UI components that observe ViewModels          │
└────────────────────────────┬────────────────────────────────┘
                             │
                             │ @StateObject / @ObservedObject
                             │ @Published properties
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                      ViewModels                             │
│  ObservableObject classes with @Published properties        │
│  Handle UI logic, state management, user actions            │
└────────────────────────────┬────────────────────────────────┘
                             │
                             │ Method calls, async/await
                             │ Combine publishers
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                       Services                              │
│  Business logic, API calls, data persistence                │
│  Often singletons for shared state                          │
└────────────────────────────┬────────────────────────────────┘
                             │
                             │ System APIs, SDKs
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                   System Frameworks                         │
│  AVFoundation, URLSession, Keychain, Flutter Engine         │
└─────────────────────────────────────────────────────────────┘
```

## View Layer

### ContentView (Main Navigation)

The app uses a `TabView` for main navigation with four tabs:

```swift
// ContentView.swift
TabView(selection: $selectedTab) {
    CameraView()
        .tabItem { Label("Camera", systemImage: "camera") }
        .tag(0)

    GalleryView()
        .tabItem { Label("Gallery", systemImage: "photo.stack") }
        .tag(1)

    ChatView()
        .tabItem { Label("Chat", systemImage: "message") }
        .tag(2)

    SettingsView()
        .tabItem { Label("Settings", systemImage: "gear") }
        .tag(3)
}
```

### View Hierarchy

```
ContentView
├── CameraView
│   ├── CameraPreview (Local camera) / VeepaPreviewView (External)
│   ├── ControlOverlay
│   │   ├── Zoom controls
│   │   ├── Focus indicator
│   │   └── Recording controls
│   ├── CameraDiscoveryView (sheet)
│   └── VideoStreamModeView (streaming overlay)
│
├── GalleryView
│   ├── MediaItem grid
│   ├── MediaPreviewSheet
│   └── UploadStatusBadge
│
├── ChatView / MainChatView
│   ├── Message list
│   │   ├── MessageBubble
│   │   └── ImageMessage
│   ├── Input area
│   │   ├── Text input
│   │   ├── VoiceInputButton
│   │   └── MediaAttachmentMenu
│   └── VoiceIndicator
│
└── SettingsView
    ├── API Key section
    ├── Camera settings
    ├── Upload settings
    └── About section
```

### View-ViewModel Binding

Views observe ViewModels using SwiftUI property wrappers:

```swift
// CameraView.swift
struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        ZStack {
            // Observe published properties
            if viewModel.isRecording {
                RecordingIndicator()
            }

            // Call ViewModel methods
            Button("Record") {
                viewModel.startRecording()
            }
        }
        .onAppear {
            viewModel.startCamera()
        }
    }
}
```

## ViewModel Layer

### Base Pattern

All ViewModels follow a consistent pattern:

```swift
// ViewModelProtocol.swift
protocol ViewModelProtocol: ObservableObject {
    associatedtype State
    var state: State { get }
    func onAppear()
    func onDisappear()
}

// Typical ViewModel structure
class CameraViewModel: ObservableObject {
    // MARK: - Published Properties (UI State)
    @Published var isRecording = false
    @Published var isLoading = false
    @Published var error: CameraError?
    @Published var zoomLevel: CGFloat = 1.0

    // MARK: - Dependencies
    private let cameraManager: CameraManager
    private let sourceManager: CameraSourceManager

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(
        cameraManager: CameraManager = .shared,
        sourceManager: CameraSourceManager = .shared
    ) {
        self.cameraManager = cameraManager
        self.sourceManager = sourceManager
        setupBindings()
    }

    // MARK: - Private Methods
    private func setupBindings() {
        cameraManager.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
    }

    // MARK: - Public Methods (User Actions)
    func startRecording() {
        Task { @MainActor in
            do {
                try await cameraManager.startRecordingVideo()
            } catch {
                self.error = error as? CameraError
            }
        }
    }
}
```

### Key ViewModels

| ViewModel | Responsibility |
|-----------|----------------|
| `CameraViewModel` | Camera preview, recording, capture, zoom/focus |
| `ChatViewModel` | Messages, sending, streaming responses |
| `GalleryViewModel` | Media items, selection, deletion |
| `VideoStreamViewModel` | Real-time streaming state, Gemini connection |
| `SettingsViewModel` | App settings, API key management |
| `MediaPreviewViewModel` | Single media item preview |

### Combine Integration

ViewModels use Combine for reactive updates:

```swift
// ChatViewModel.swift
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming = false
    @Published var streamingResponse = ""

    private let geminiService: GeminiChatService
    private var streamingTask: Task<Void, Never>?

    func sendMessage(_ text: String) async {
        let userMessage = ChatMessage(role: .user, content: .text(text))
        messages.append(userMessage)

        isStreaming = true
        streamingResponse = ""

        // Stream response chunks
        for await chunk in geminiService.streamChat(text, history: messages) {
            streamingResponse += chunk
        }

        // Finalize response
        let assistantMessage = ChatMessage(role: .assistant, content: .text(streamingResponse))
        messages.append(assistantMessage)

        isStreaming = false
        streamingResponse = ""
    }
}
```

## Service Layer

### Service Categories

```
Services/
├── Core Infrastructure
│   ├── CameraManager         # AVFoundation camera
│   ├── PermissionManager     # System permissions
│   ├── NetworkMonitor        # Connectivity
│   └── KeychainHelper        # Secure storage
│
├── Camera Sources
│   ├── CameraSourceManager   # Source switching
│   ├── LocalCameraSource     # iPhone camera
│   └── VeepaCameraSource     # External camera
│
├── AI/ML
│   ├── GeminiKeyManager      # API key management
│   ├── GeminiSDKService      # SDK wrapper
│   ├── GeminiChatService     # Chat implementation
│   ├── GeminiSessionManager  # WebSocket sessions
│   └── StreamingService      # Video streaming
│
├── Flutter Bridge
│   ├── FlutterEngineManager  # Flutter runtime
│   ├── VeepaDiscoveryBridge  # Device discovery
│   ├── VeepaConnectionBridge # Connection state
│   ├── VeepaFrameBridge      # Frame capture
│   └── VeepaProvisioningBridge # Pairing
│
├── Data & Storage
│   ├── ConversationStore     # Chat persistence
│   ├── UploadQueue           # Upload queue
│   ├── SupabaseManager       # Cloud storage
│   └── StorageService        # Storage operations
│
└── Voice
    ├── VoiceEngine           # Voice coordination
    ├── VoiceInputService     # Speech-to-text
    └── TextToSpeechService   # Text-to-speech
```

### Singleton Pattern

Many services use the singleton pattern for shared state:

```swift
// CameraSourceManager.swift
class CameraSourceManager: ObservableObject {
    static let shared = CameraSourceManager()

    @Published private(set) var currentSource: CameraSourceType = .local
    @Published private(set) var state: CameraSourceState = .disconnected

    private var localSource: LocalCameraSource?
    private var veepaSource: VeepaCameraSource?

    private init() {
        // Private initializer for singleton
    }

    func switchTo(_ sourceType: CameraSourceType) async throws {
        // Disconnect current
        await currentCameraSource?.disconnect()

        // Connect new
        currentSource = sourceType
        try await currentCameraSource?.connect()
    }

    var currentCameraSource: CameraSourceProtocol? {
        switch currentSource {
        case .local: return localSource
        case .veepaWiFi: return veepaSource
        }
    }
}
```

### Dependency Injection

Services are injected into ViewModels for testability:

```swift
// With dependency injection
class ChatViewModel: ObservableObject {
    private let geminiService: GeminiChatService
    private let conversationManager: ConversationManager

    init(
        geminiService: GeminiChatService = GeminiChatService.shared,
        conversationManager: ConversationManager = .shared
    ) {
        self.geminiService = geminiService
        self.conversationManager = conversationManager
    }
}

// In tests
let mockService = MockGeminiChatService()
let viewModel = ChatViewModel(geminiService: mockService)
```

## Model Layer

### Core Models

```swift
// CameraSourceType.swift
enum CameraSourceType: String, Codable {
    case local
    case veepaWiFi
}

// CameraError.swift
enum CameraError: LocalizedError {
    case permissionDenied
    case deviceNotFound
    case inputConfigurationFailed
    case outputConfigurationFailed
    case sessionStartFailed
    case sessionAlreadyRunning
    case configurationFailed
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera permission denied"
        // ... etc
        }
    }
}

// ChatMessage.swift
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    let content: Content
    let timestamp: Date

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    enum Content: Codable {
        case text(String)
        case image(Data, caption: String?)
        case video(URL, caption: String?)
    }
}

// MediaItem.swift
struct MediaItem: Identifiable, Codable {
    let id: UUID
    let type: MediaType
    let url: URL
    let thumbnail: Data?
    let createdAt: Date
    var uploadStatus: UploadStatus

    enum MediaType: String, Codable {
        case photo
        case video
    }
}
```

### State Management

Application state is distributed across:

1. **ViewModels**: UI state, user interactions
2. **Services**: Business logic state, connections
3. **UserDefaults**: Persisted preferences
4. **Keychain**: Secure credentials

```swift
// AppSettings.swift - Preferences
class AppSettings: ObservableObject {
    @AppStorage("videoResolution") var videoResolution: VideoResolution = .hd1080
    @AppStorage("autoUpload") var autoUpload = false
    @AppStorage("framesPerSecond") var framesPerSecond = 5
}

// GeminiKeyManager.swift - Secure storage
class GeminiKeyManager {
    static let shared = GeminiKeyManager()

    private let keychain = KeychainHelper.standard

    var apiKey: String? {
        get { keychain.read(key: "gemini_api_key") }
        set {
            if let value = newValue {
                keychain.save(value, key: "gemini_api_key")
            } else {
                keychain.delete(key: "gemini_api_key")
            }
        }
    }
}
```

## Async/Await Pattern

The app uses Swift's modern concurrency throughout:

```swift
// Async service methods
class GeminiSDKService {
    func generateContent(prompt: String) async throws -> String {
        let response = try await model.generateContent(prompt)
        return response.text ?? ""
    }

    func generateContentStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in model.generateContentStream(prompt) {
                        if let text = chunk.text {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// ViewModel usage
class ChatViewModel: ObservableObject {
    @MainActor
    func sendMessage(_ text: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await geminiService.generateContent(prompt: text)
            messages.append(ChatMessage(role: .assistant, content: .text(response)))
        } catch {
            self.error = error
        }
    }
}
```

## Error Handling

### Error Types

```swift
// Domain-specific errors
enum CameraError: LocalizedError { ... }
enum GeminiError: LocalizedError { ... }
enum UploadError: LocalizedError { ... }
enum VeepaConnectionError: LocalizedError { ... }
```

### Error Propagation

```swift
// Service layer throws errors
class CameraManager {
    func startRecordingVideo() async throws {
        guard hasPermission else {
            throw CameraError.permissionDenied
        }
        // ...
    }
}

// ViewModel catches and exposes to UI
class CameraViewModel: ObservableObject {
    @Published var error: CameraError?

    func startRecording() {
        Task { @MainActor in
            do {
                try await cameraManager.startRecordingVideo()
            } catch let cameraError as CameraError {
                self.error = cameraError
            } catch {
                self.error = .unknown(error)
            }
        }
    }
}

// View displays error
struct CameraView: View {
    @StateObject var viewModel = CameraViewModel()

    var body: some View {
        // ...
        .alert(
            "Error",
            isPresented: .constant(viewModel.error != nil),
            presenting: viewModel.error
        ) { _ in
            Button("OK") { viewModel.error = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}
```

## Navigation

### Navigation State

```swift
// AppNavigationState.swift
class AppNavigationState: ObservableObject {
    @Published var selectedTab: Tab = .camera
    @Published var presentedSheet: Sheet?
    @Published var navigationPath = NavigationPath()

    enum Tab: Int {
        case camera = 0
        case gallery = 1
        case chat = 2
        case settings = 3
    }

    enum Sheet: Identifiable {
        case cameraDiscovery
        case mediaPreview(MediaItem)
        case videoAnalysis(URL)

        var id: String { ... }
    }
}
```

### Deep Linking

```swift
// Handle deep links in SciSymbioLensApp.swift
@main
struct SciSymbioLensApp: App {
    @StateObject private var navigationState = AppNavigationState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(navigationState)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Parse URL and update navigation state
    }
}
```

## Testing Architecture

### Unit Test Structure

```swift
// CameraViewModelTests.swift
class CameraViewModelTests: XCTestCase {
    var viewModel: CameraViewModel!
    var mockCameraManager: MockCameraManager!

    override func setUp() {
        super.setUp()
        mockCameraManager = MockCameraManager()
        viewModel = CameraViewModel(cameraManager: mockCameraManager)
    }

    func testStartRecording_Success() async {
        // Given
        mockCameraManager.shouldSucceed = true

        // When
        await viewModel.startRecording()

        // Then
        XCTAssertTrue(viewModel.isRecording)
        XCTAssertNil(viewModel.error)
    }

    func testStartRecording_PermissionDenied() async {
        // Given
        mockCameraManager.errorToThrow = .permissionDenied

        // When
        await viewModel.startRecording()

        // Then
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertEqual(viewModel.error, .permissionDenied)
    }
}
```

### Mock Objects

```swift
// MockCameraManager.swift
class MockCameraManager: CameraManagerProtocol {
    var shouldSucceed = true
    var errorToThrow: CameraError?
    var startRecordingCalled = false

    func startRecordingVideo() async throws {
        startRecordingCalled = true
        if let error = errorToThrow {
            throw error
        }
    }
}
```

## Performance Considerations

### Main Thread Safety

```swift
// Always update @Published on main thread
class CameraViewModel: ObservableObject {
    @MainActor
    func updateState() {
        // Safe to modify @Published properties
        self.isRecording = true
    }

    // Or use receive(on:)
    private func setupBindings() {
        service.$state
            .receive(on: DispatchQueue.main)
            .assign(to: &$state)
    }
}
```

### Memory Management

```swift
// Proper cancellable cleanup
class ChatViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private var streamingTask: Task<Void, Never>?

    deinit {
        streamingTask?.cancel()
        cancellables.removeAll()
    }
}
```

### Lazy Loading

```swift
// Lazy initialization for heavy services
class FlutterEngineManager {
    private lazy var flutterEngine: FlutterEngine = {
        let engine = FlutterEngine(name: "veepa_camera")
        engine.run()
        return engine
    }()

    func initialize() {
        // Engine created on first access
        _ = flutterEngine
    }
}
```

---

*Last updated: January 2026*
