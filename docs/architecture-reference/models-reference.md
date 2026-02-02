# Models Reference

Complete reference for all data models used in the application.

## Model Organization

```
Models/
├── Core Models
│   ├── CameraSourceType
│   ├── CameraError
│   ├── VideoResolution
│   └── MediaItem
│
├── Chat Models
│   ├── ChatMessage
│   └── ChatMessageContent
│
├── Veepa Camera Models
│   ├── P2PCredentials
│   ├── VeepaDevice
│   ├── VeepaConnectionState
│   └── ProvisioningState
│
├── Upload Models
│   ├── UploadStatus
│   └── UploadQueueItem
│
└── Protocol Models
    ├── CameraSourceProtocol
    ├── CameraSourceState
    └── CameraCapabilities
```

---

## Core Models

### CameraSourceType

**Location**: `Models/CameraSourceType.swift`
**Purpose**: Enumerate available camera sources

```swift
enum CameraSourceType: String, Codable, CaseIterable {
    case local       // Built-in iPhone camera
    case veepaWiFi   // External Veepa Wi-Fi camera

    var displayName: String {
        switch self {
        case .local: return "iPhone Camera"
        case .veepaWiFi: return "Veepa Wi-Fi Camera"
        }
    }

    var icon: String {
        switch self {
        case .local: return "iphone"
        case .veepaWiFi: return "wifi"
        }
    }
}
```

---

### CameraError

**Location**: `Models/CameraError.swift`
**Purpose**: Camera-related error types

```swift
enum CameraError: LocalizedError {
    case permissionDenied
    case deviceNotFound
    case inputConfigurationFailed
    case outputConfigurationFailed
    case sessionStartFailed
    case sessionAlreadyRunning
    case sessionNotRunning
    case configurationFailed
    case recordingFailed
    case captureFailed
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera permission was denied. Please enable in Settings."
        case .deviceNotFound:
            return "No camera device found."
        case .inputConfigurationFailed:
            return "Failed to configure camera input."
        case .outputConfigurationFailed:
            return "Failed to configure camera output."
        case .sessionStartFailed:
            return "Failed to start camera session."
        case .sessionAlreadyRunning:
            return "Camera session is already running."
        case .sessionNotRunning:
            return "Camera session is not running."
        case .configurationFailed:
            return "Failed to configure camera settings."
        case .recordingFailed:
            return "Failed to record video."
        case .captureFailed:
            return "Failed to capture photo."
        case .unknown(let error):
            return "Camera error: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Go to Settings > Privacy > Camera and enable access."
        case .deviceNotFound:
            return "Ensure a camera is available on this device."
        default:
            return "Try restarting the app."
        }
    }
}
```

---

### VideoResolution

**Location**: `Models/VideoResolution.swift`
**Purpose**: Video resolution presets

```swift
enum VideoResolution: String, Codable, CaseIterable {
    case hd720 = "720p"
    case hd1080 = "1080p"
    case uhd4K = "4K"

    var displayName: String {
        rawValue
    }

    var dimensions: (width: Int, height: Int) {
        switch self {
        case .hd720: return (1280, 720)
        case .hd1080: return (1920, 1080)
        case .uhd4K: return (3840, 2160)
        }
    }

    var sessionPreset: AVCaptureSession.Preset {
        switch self {
        case .hd720: return .hd1280x720
        case .hd1080: return .hd1920x1080
        case .uhd4K: return .hd4K3840x2160
        }
    }

    var estimatedBitrate: Int {  // bits per second
        switch self {
        case .hd720: return 5_000_000   // 5 Mbps
        case .hd1080: return 10_000_000  // 10 Mbps
        case .uhd4K: return 35_000_000   // 35 Mbps
        }
    }
}
```

---

### MediaItem

**Location**: `Models/MediaItem.swift`
**Purpose**: Represents captured media (photo or video)

```swift
struct MediaItem: Identifiable, Codable, Equatable {
    let id: UUID
    let type: MediaType
    let fileURL: URL
    let thumbnailURL: URL?
    let createdAt: Date
    var uploadStatus: UploadStatus
    var cloudURL: URL?
    var metadata: MediaMetadata?

    enum MediaType: String, Codable {
        case photo
        case video
    }

    struct MediaMetadata: Codable {
        let duration: TimeInterval?  // For videos
        let dimensions: CGSize?
        let fileSize: Int64
    }

    init(
        id: UUID = UUID(),
        type: MediaType,
        fileURL: URL,
        thumbnailURL: URL? = nil,
        createdAt: Date = Date(),
        uploadStatus: UploadStatus = .pending,
        cloudURL: URL? = nil,
        metadata: MediaMetadata? = nil
    ) {
        self.id = id
        self.type = type
        self.fileURL = fileURL
        self.thumbnailURL = thumbnailURL
        self.createdAt = createdAt
        self.uploadStatus = uploadStatus
        self.cloudURL = cloudURL
        self.metadata = metadata
    }

    var isVideo: Bool { type == .video }
    var isPhoto: Bool { type == .photo }
    var isUploaded: Bool { uploadStatus == .completed }
}
```

---

## Chat Models

### ChatMessage

**Location**: `Models/ChatMessage.swift`
**Purpose**: Represents a conversation message

```swift
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: Role
    let content: Content
    let timestamp: Date

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    enum Content: Codable, Equatable {
        case text(String)
        case image(Data, caption: String?)
        case video(URL, caption: String?)

        var textContent: String? {
            switch self {
            case .text(let text): return text
            case .image(_, let caption): return caption
            case .video(_, let caption): return caption
            }
        }

        var hasMedia: Bool {
            switch self {
            case .text: return false
            case .image, .video: return true
            }
        }
    }

    init(
        id: UUID = UUID(),
        role: Role,
        content: Content,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    // Convenience initializers
    static func userText(_ text: String) -> ChatMessage {
        ChatMessage(role: .user, content: .text(text))
    }

    static func assistantText(_ text: String) -> ChatMessage {
        ChatMessage(role: .assistant, content: .text(text))
    }

    static func userImage(_ data: Data, caption: String? = nil) -> ChatMessage {
        ChatMessage(role: .user, content: .image(data, caption: caption))
    }

    static func userVideo(_ url: URL, caption: String? = nil) -> ChatMessage {
        ChatMessage(role: .user, content: .video(url, caption: caption))
    }
}
```

---

## Veepa Camera Models

### P2PCredentials

**Location**: `Models/P2PCredentials.swift`
**Purpose**: Veepa camera P2P connection credentials

```swift
struct P2PCredentials: Codable, Equatable {
    let deviceId: String
    let username: String
    let password: String
    let pairedAt: Date

    init(
        deviceId: String,
        username: String = "admin",
        password: String = "888888",
        pairedAt: Date = Date()
    ) {
        self.deviceId = deviceId
        self.username = username
        self.password = password
        self.pairedAt = pairedAt
    }

    // Default credentials
    static func defaultCredentials(for deviceId: String) -> P2PCredentials {
        P2PCredentials(
            deviceId: deviceId,
            username: "admin",
            password: "888888"
        )
    }
}
```

---

### VeepaDevice

**Location**: Used in bridge classes
**Purpose**: Discovered Veepa camera device

```swift
struct VeepaDevice: Identifiable, Codable, Equatable {
    let id: String       // Device VUID (e.g., "VP0191279WWIS")
    let name: String     // Display name / alias
    let ipAddress: String
    let model: String?
    let discoveredAt: Date

    init(
        id: String,
        name: String? = nil,
        ipAddress: String,
        model: String? = nil,
        discoveredAt: Date = Date()
    ) {
        self.id = id
        self.name = name ?? id
        self.ipAddress = ipAddress
        self.model = model
        self.discoveredAt = discoveredAt
    }

    var displayName: String {
        name.isEmpty ? id : name
    }
}
```

---

### VeepaConnectionState

**Location**: Used in bridge classes
**Purpose**: Veepa camera connection state

```swift
enum VeepaConnectionState: String, Codable {
    case disconnected
    case connecting
    case connected
    case streaming
    case error
    case reconnecting

    var isActive: Bool {
        self == .connected || self == .streaming
    }

    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .streaming: return "Streaming"
        case .error: return "Error"
        case .reconnecting: return "Reconnecting..."
        }
    }

    var icon: String {
        switch self {
        case .disconnected: return "wifi.slash"
        case .connecting, .reconnecting: return "wifi.exclamationmark"
        case .connected: return "wifi"
        case .streaming: return "video.fill"
        case .error: return "exclamationmark.triangle"
        }
    }
}
```

---

### VeepaConnectionError

**Location**: Used in bridge classes
**Purpose**: Veepa connection error types

```swift
enum VeepaConnectionError: LocalizedError {
    case noCredentials
    case noDevice
    case connectionFailed(String)
    case streamingFailed(String)
    case timeout
    case maxReconnectAttemptsExceeded
    case authenticationFailed
    case deviceOffline

    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "No saved credentials found. Please pair the camera first."
        case .noDevice:
            return "No device selected. Please select a camera."
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .streamingFailed(let message):
            return "Streaming failed: \(message)"
        case .timeout:
            return "Connection timed out."
        case .maxReconnectAttemptsExceeded:
            return "Maximum reconnection attempts exceeded."
        case .authenticationFailed:
            return "Authentication failed. Check credentials."
        case .deviceOffline:
            return "Device is offline or unreachable."
        }
    }
}
```

---

### ProvisioningState

**Location**: Used in `VeepaProvisioningBridge`
**Purpose**: Camera pairing workflow state

```swift
enum ProvisioningState {
    case idle
    case scanningDeviceQR
    case generatingWiFiQR
    case waitingForScan
    case connectingToWiFi
    case discoveringDevice
    case connectingToDevice
    case completed(VeepaDevice)
    case failed(ProvisioningError)

    var isInProgress: Bool {
        switch self {
        case .idle, .completed, .failed: return false
        default: return true
        }
    }

    var displayText: String {
        switch self {
        case .idle: return "Ready to pair"
        case .scanningDeviceQR: return "Scan camera QR code"
        case .generatingWiFiQR: return "Generating WiFi QR..."
        case .waitingForScan: return "Show QR to camera"
        case .connectingToWiFi: return "Camera connecting to WiFi..."
        case .discoveringDevice: return "Finding camera on network..."
        case .connectingToDevice: return "Connecting to camera..."
        case .completed: return "Pairing complete!"
        case .failed(let error): return "Failed: \(error.localizedDescription)"
        }
    }
}

enum ProvisioningError: LocalizedError {
    case invalidQRCode
    case wifiConnectionFailed
    case deviceNotFound
    case connectionFailed(String)
    case timeout
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidQRCode: return "Invalid QR code scanned."
        case .wifiConnectionFailed: return "Camera failed to connect to WiFi."
        case .deviceNotFound: return "Camera not found on network."
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .timeout: return "Operation timed out."
        case .cancelled: return "Pairing was cancelled."
        }
    }
}
```

---

## Upload Models

### UploadStatus

**Location**: `Models/UploadStatus.swift`
**Purpose**: Upload state tracking

```swift
enum UploadStatus: String, Codable, Equatable {
    case pending
    case uploading
    case completed
    case failed

    var displayText: String {
        switch self {
        case .pending: return "Pending"
        case .uploading: return "Uploading..."
        case .completed: return "Uploaded"
        case .failed: return "Failed"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .uploading: return "arrow.up.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .gray
        case .uploading: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}
```

---

### UploadQueueItem

**Location**: Used in `UploadQueue`
**Purpose**: Upload queue item with retry tracking

```swift
struct UploadQueueItem: Identifiable, Codable {
    let id: UUID
    let mediaItemId: UUID
    let fileURL: URL
    var status: UploadStatus
    var retryCount: Int
    var lastError: String?
    let createdAt: Date
    var lastAttemptAt: Date?

    init(
        id: UUID = UUID(),
        mediaItemId: UUID,
        fileURL: URL,
        status: UploadStatus = .pending,
        retryCount: Int = 0,
        lastError: String? = nil,
        createdAt: Date = Date(),
        lastAttemptAt: Date? = nil
    ) {
        self.id = id
        self.mediaItemId = mediaItemId
        self.fileURL = fileURL
        self.status = status
        self.retryCount = retryCount
        self.lastError = lastError
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
    }

    var canRetry: Bool {
        status == .failed && retryCount < 3
    }

    mutating func markFailed(error: String) {
        status = .failed
        lastError = error
        retryCount += 1
        lastAttemptAt = Date()
    }

    mutating func markUploading() {
        status = .uploading
        lastAttemptAt = Date()
    }

    mutating func markCompleted() {
        status = .completed
        lastAttemptAt = Date()
    }
}
```

---

## Protocol Models

### CameraSourceProtocol

**Location**: `Protocols/CameraSourceProtocol.swift`
**Purpose**: Interface for camera sources

```swift
protocol CameraSourceProtocol: AnyObject {
    // State
    var state: CameraSourceState { get }
    var statePublisher: AnyPublisher<CameraSourceState, Never> { get }

    // Capabilities
    var capabilities: CameraCapabilities { get }

    // Lifecycle
    func connect() async throws
    func disconnect()

    // Streaming
    func startStreaming() async throws
    func stopStreaming()

    // Frame Capture
    func getLatestFrame() async -> Data?

    // Configuration
    func setFrameRate(_ fps: Int) throws

    // Preview (optional - only for local camera)
    var captureSession: AVCaptureSession? { get }
}
```

---

### CameraSourceState

**Location**: `Protocols/CameraSourceProtocol.swift`
**Purpose**: Camera source connection state

```swift
enum CameraSourceState: String, Codable {
    case disconnected
    case connecting
    case connected
    case streaming
    case error

    var isActive: Bool {
        self == .connected || self == .streaming
    }

    var canStartStreaming: Bool {
        self == .connected
    }
}
```

---

### CameraCapabilities

**Location**: `Protocols/CameraSourceProtocol.swift`
**Purpose**: Describes camera source capabilities

```swift
struct CameraCapabilities {
    let supportsZoom: Bool
    let supportsFocus: Bool
    let supportsFlash: Bool
    let supportsRecording: Bool
    let supportsPhotoCapture: Bool
    let maxFrameRate: Int
    let availableResolutions: [VideoResolution]

    // Preset for local camera
    static let localCamera = CameraCapabilities(
        supportsZoom: true,
        supportsFocus: true,
        supportsFlash: true,
        supportsRecording: true,
        supportsPhotoCapture: true,
        maxFrameRate: 60,
        availableResolutions: [.hd720, .hd1080, .uhd4K]
    )

    // Preset for Veepa camera
    static let veepaCamera = CameraCapabilities(
        supportsZoom: false,
        supportsFocus: false,
        supportsFlash: false,
        supportsRecording: false,
        supportsPhotoCapture: false,
        maxFrameRate: 30,
        availableResolutions: [.hd720, .hd1080]
    )
}
```

---

## Gemini Models

### GeminiError

**Location**: `Services/Gemini/`
**Purpose**: Gemini API error types

```swift
enum GeminiError: LocalizedError {
    case notConfigured
    case invalidApiKey
    case noChatSession
    case connectionError(String)
    case apiError(String)
    case rateLimitExceeded
    case contentFiltered
    case modelNotFound
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Gemini API is not configured. Please add your API key in Settings."
        case .invalidApiKey:
            return "Invalid API key. Please check your key in Settings."
        case .noChatSession:
            return "No active chat session. Please start a new conversation."
        case .connectionError(let message):
            return "Connection error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait a moment."
        case .contentFiltered:
            return "Content was filtered by safety settings."
        case .modelNotFound:
            return "The specified model was not found."
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
```

---

## WiFi Configuration Models

### WiFiConfig

**Location**: Used in provisioning
**Purpose**: WiFi configuration for Veepa camera

```swift
struct WiFiConfig: Codable {
    let ssid: String
    let password: String
    let bssid: String?
    let region: String

    init(
        ssid: String,
        password: String,
        bssid: String? = nil,
        region: String = "1"
    ) {
        self.ssid = ssid
        self.password = password
        self.bssid = bssid
        self.region = region
    }

    // Generate QR code JSON content
    var qrContent: String {
        var json: [String: String] = [
            "RS": ssid,
            "P": password,
            "A": region
        ]
        if let bssid = bssid {
            json["BS"] = bssid
        }
        return try! JSONEncoder().encode(json).base64EncodedString()
    }
}
```

---

## Type Aliases

Common type aliases used throughout the codebase:

```swift
// Combine
typealias AnyCancellable = Combine.AnyCancellable

// Completion handlers
typealias VoidCompletion = () -> Void
typealias ResultCompletion<T> = (Result<T, Error>) -> Void
typealias ErrorCompletion = (Error?) -> Void

// Image data
typealias ImageData = Data
typealias FrameData = Data
```

---

*Last updated: January 2026*
