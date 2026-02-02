# Services Reference

Complete reference for all service classes in the application.

## Service Categories

```
Services/
├── Core Infrastructure
├── Camera Services
├── AI/ML Services (Gemini)
├── Flutter Bridge Services
├── Data & Storage Services
└── Voice Services
```

---

## Core Infrastructure Services

### CameraManager

**Location**: `Services/CameraManager.swift`
**Type**: Singleton (`CameraManager.shared`)
**Purpose**: Low-level AVFoundation camera orchestration

**Published Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `isRecording` | `Bool` | Whether video recording is active |
| `isSessionRunning` | `Bool` | Whether camera session is running |
| `zoomLevel` | `CGFloat` | Current zoom level (1.0 = no zoom) |
| `focusPoint` | `CGPoint?` | Current focus point |
| `lastCapturedPhotoURL` | `URL?` | URL of last captured photo |
| `lastRecordedVideoURL` | `URL?` | URL of last recorded video |
| `error` | `CameraError?` | Current error state |

**Key Methods**:
```swift
// Session Management
func configureSession() async throws
func startSession()
func stopSession()

// Recording
func startRecordingVideo() async throws
func stopRecordingVideo() async

// Photo Capture
func capturePhoto() async throws -> URL

// Camera Controls
func setZoom(_ factor: CGFloat)
func focus(at point: CGPoint)
func setResolution(_ resolution: VideoResolution) throws
func switchCamera() throws
```

---

### PermissionManager

**Location**: `Services/PermissionManager.swift`
**Type**: Singleton
**Purpose**: System permission handling

**Published Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `cameraPermission` | `PermissionStatus` | Camera permission state |
| `microphonePermission` | `PermissionStatus` | Microphone permission state |
| `photoLibraryPermission` | `PermissionStatus` | Photo library permission state |

**Key Methods**:
```swift
func checkPermissions()
func requestCameraPermission() async -> Bool
func requestMicrophonePermission() async -> Bool
func requestPhotoLibraryPermission() async -> Bool
func openSettings()
```

---

### NetworkMonitor

**Location**: `Services/NetworkMonitor.swift`
**Type**: Singleton
**Purpose**: Network connectivity monitoring

**Published Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `isConnected` | `Bool` | Whether network is available |
| `connectionType` | `ConnectionType` | WiFi, cellular, or none |

**Key Methods**:
```swift
func startMonitoring()
func stopMonitoring()
```

---

### AppSettings

**Location**: `Services/AppSettings.swift`
**Type**: ObservableObject (used with `@StateObject`)
**Purpose**: User preferences persistence

**Properties (using @AppStorage)**:
| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `videoResolution` | `VideoResolution` | `.hd1080` | Recording resolution |
| `framesPerSecond` | `Int` | `5` | Streaming FPS |
| `autoUpload` | `Bool` | `false` | Auto-upload enabled |
| `voiceEnabled` | `Bool` | `true` | TTS enabled |
| `lastCameraSource` | `CameraSourceType` | `.local` | Last used source |

---

### HapticService

**Location**: `Services/HapticService.swift`
**Type**: Static methods
**Purpose**: Haptic feedback

**Methods**:
```swift
static func lightImpact()
static func mediumImpact()
static func heavyImpact()
static func success()
static func warning()
static func error()
static func selection()
```

---

## Camera Services

### CameraSourceManager

**Location**: `Services/Camera/CameraSourceManager.swift`
**Type**: Singleton (`CameraSourceManager.shared`)
**Purpose**: Multi-camera source management and switching

**Published Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `currentSourceType` | `CameraSourceType` | Currently active source |
| `state` | `CameraSourceState` | Connection state |
| `error` | `CameraError?` | Current error |

**Key Methods**:
```swift
func switchTo(_ sourceType: CameraSourceType) async throws
func getLatestFrame() async -> Data?
var currentSource: CameraSourceProtocol? { get }
```

---

### LocalCameraSource

**Location**: `Services/Camera/LocalCameraSource.swift`
**Type**: Class implementing `CameraSourceProtocol`
**Purpose**: iPhone built-in camera implementation

**Key Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `state` | `CameraSourceState` | Connection state |
| `capabilities` | `CameraCapabilities` | Supported features |
| `captureSession` | `AVCaptureSession?` | Direct session access |

**Key Methods**:
```swift
func connect() async throws
func disconnect()
func startStreaming() async throws
func stopStreaming()
func getLatestFrame() async -> Data?
func setFrameRate(_ fps: Int) throws
```

---

### VeepaCameraSource

**Location**: `Services/Camera/VeepaCameraSource.swift`
**Type**: Class implementing `CameraSourceProtocol`
**Purpose**: External Veepa Wi-Fi camera implementation

**Key Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `state` | `CameraSourceState` | Connection state |
| `capabilities` | `CameraCapabilities` | Limited feature set |
| `captureSession` | `AVCaptureSession?` | Always nil (no direct session) |

**Key Methods**:
```swift
func connect() async throws  // Uses cached P2P credentials
func disconnect()
func startStreaming() async throws  // Via Flutter bridge
func stopStreaming()
func getLatestFrame() async -> Data?  // From Flutter frame buffer
```

---

## AI/ML Services (Gemini)

### GeminiKeyManager

**Location**: `Services/Gemini/GeminiKeyManager.swift`
**Type**: Singleton (`GeminiKeyManager.shared`)
**Purpose**: Secure API key storage

**Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `apiKey` | `String?` | Stored API key (Keychain) |
| `hasValidKey` | `Bool` | Whether key appears valid |

**Methods**:
```swift
func validateKey(_ key: String) async -> Bool
func clearKey()
```

---

### GeminiConfig

**Location**: `Services/Gemini/GeminiConfig.swift`
**Type**: Struct with static constants
**Purpose**: Configuration values

**Constants**:
```swift
static let chatModel = "gemini-2.0-flash-exp"
static let visionModel = "gemini-2.0-flash-exp"
static let streamingModel = "gemini-2.0-flash-exp"
static let defaultFramesPerSecond = 5
static let maxFramesPerSecond = 30
static let minFramesPerSecond = 1
static let maxImageSize: Int = 200_000
static let jpegCompression: CGFloat = 0.7
static let chatSystemInstruction: String
static let streamingSystemInstruction: String
```

---

### GeminiSDKService

**Location**: `Services/Gemini/GeminiSDKService.swift`
**Type**: Singleton (`GeminiSDKService.shared`)
**Purpose**: Google Generative AI SDK wrapper

**Methods**:
```swift
// Text generation
func generateContent(prompt: String) async throws -> String

// Streaming generation
func generateContentStream(prompt: String) -> AsyncThrowingStream<String, Error>

// Image analysis
func analyzeImage(_ imageData: Data, prompt: String) async throws -> String

// Video analysis
func analyzeVideo(url: URL, prompt: String) async throws -> String
```

---

### GeminiChatService

**Location**: `Services/Gemini/GeminiChatService.swift`
**Type**: Singleton (`GeminiChatService.shared`)
**Purpose**: Conversation management with history

**Methods**:
```swift
// Session management
func startNewChat(history: [ChatMessage])

// Messaging
func sendMessage(_ text: String) async throws -> String
func streamMessage(_ text: String) -> AsyncThrowingStream<String, Error>

// Multimodal
func sendWithImage(_ imageData: Data, caption: String?) async throws -> String
func sendWithVideo(url: URL, caption: String?) async throws -> String
```

---

### GeminiSessionManager

**Location**: `Services/Gemini/GeminiSessionManager.swift`
**Type**: Singleton (`GeminiSessionManager.shared`)
**Purpose**: WebSocket session for real-time streaming

**Published Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `isConnected` | `Bool` | WebSocket connected |
| `isStreaming` | `Bool` | Streaming active |
| `latestResponse` | `String` | Current response text |
| `error` | `GeminiError?` | Current error |

**Methods**:
```swift
func startSession() async throws
func endSession()
func submitFrame(_ imageData: Data) async
func submitText(_ text: String) async
```

---

### StreamingService

**Location**: `Services/Gemini/StreamingService.swift`
**Type**: Singleton (`StreamingService.shared`)
**Purpose**: Real-time video streaming to Gemini

**Published Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `isStreaming` | `Bool` | Streaming active |
| `frameRate` | `Int` | Current FPS setting |
| `framesSubmitted` | `Int` | Total frames sent |
| `error` | `Error?` | Current error |

**Methods**:
```swift
func startStreaming() async throws
func stopStreaming()
func setFrameRate(_ fps: Int)
```

---

### VideoAnalysisService

**Location**: `Services/Gemini/VideoAnalysisService.swift`
**Type**: Class
**Purpose**: Recorded video analysis

**Methods**:
```swift
func analyzeVideo(at url: URL, prompt: String) async throws -> String
func analyzeVideoWithProgress(at url: URL, prompt: String, progressHandler: @escaping (Double) -> Void) async throws -> String
```

---

### VideoUploadService

**Location**: `Services/Gemini/VideoUploadService.swift`
**Type**: Class
**Purpose**: Video upload to Gemini for processing

**Methods**:
```swift
func uploadVideo(at url: URL) async throws -> String  // Returns file reference
func deleteUploadedVideo(_ reference: String) async throws
```

---

## Flutter Bridge Services

### FlutterEngineManager

**Location**: `Services/Flutter/FlutterEngineManager.swift`
**Type**: Singleton (`FlutterEngineManager.shared`)
**Purpose**: Flutter engine lifecycle management

**Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `isInitialized` | `Bool` | Engine running |
| `methodChannel` | `FlutterMethodChannel?` | Main method channel |

**Methods**:
```swift
func initialize()
func shutdown()
func setupChannels()
```

---

### VeepaDiscoveryBridge

**Location**: `Services/Flutter/VeepaDiscoveryBridge.swift`
**Type**: ObservableObject
**Purpose**: Device discovery via Flutter

**Published Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `discoveredDevices` | `[VeepaDevice]` | Found devices |
| `isDiscovering` | `Bool` | Discovery in progress |

**Methods**:
```swift
func startDiscovery()
func stopDiscovery()
func clearDevices()
```

---

### VeepaConnectionBridge

**Location**: `Services/Flutter/VeepaConnectionBridge.swift`
**Type**: ObservableObject
**Purpose**: Connection state management

**Published Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `connectionState` | `VeepaConnectionState` | Current state |
| `connectedDevice` | `VeepaDevice?` | Connected device |
| `error` | `VeepaConnectionError?` | Current error |

**Methods**:
```swift
func connect(device: VeepaDevice, credentials: P2PCredentials) async throws
func disconnect()
func reconnect() async throws
```

---

### VeepaFrameBridge

**Location**: `Services/Flutter/VeepaFrameBridge.swift`
**Type**: ObservableObject
**Purpose**: Video frame streaming from Veepa

**Published Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `latestFrame` | `Data?` | Most recent frame |
| `isStreaming` | `Bool` | Streaming active |
| `frameRate` | `Double` | Actual FPS |

**Methods**:
```swift
func startStreaming()
func stopStreaming()
func getLatestFrame() -> Data?
```

---

### VeepaProvisioningBridge

**Location**: `Services/Flutter/VeepaProvisioningBridge.swift`
**Type**: ObservableObject
**Purpose**: Camera pairing workflow

**Published Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `provisioningState` | `ProvisioningState` | Current state |
| `qrCodeData` | `Data?` | Generated QR image |

**Methods**:
```swift
func startProvisioning(wifiConfig: WiFiConfig)
func cancelProvisioning()
```

---

## Data & Storage Services

### ConversationStore

**Location**: `Services/ConversationStore.swift`
**Type**: Class
**Purpose**: Chat history persistence

**Methods**:
```swift
func loadMessages() -> [ChatMessage]
func saveMessage(_ message: ChatMessage)
func saveMessages(_ messages: [ChatMessage])
func clearConversation()
```

---

### P2PCredentialService

**Location**: `Services/P2PCredentialService.swift`
**Type**: Singleton (`P2PCredentialService.shared`)
**Purpose**: Veepa P2P credential management

**Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `lastConnectedDevice` | `VeepaDevice?` | Last device |

**Methods**:
```swift
func saveCredentials(_ credentials: P2PCredentials, for device: VeepaDevice)
func loadCredentials() -> P2PCredentials?
func clearCredentials()
```

---

### UploadQueue

**Location**: `Services/UploadQueue.swift`
**Type**: Class
**Purpose**: Upload queue management with persistence

**Methods**:
```swift
func addItem(_ item: MediaItem)
func removeItem(_ id: UUID)
func getNextPending() -> MediaItem?
func markCompleted(_ id: UUID, url: URL)
func markFailed(_ id: UUID, error: Error)
func retryFailed(_ id: UUID)
func getAllItems() -> [UploadQueueItem]
```

---

### UploadStatusStore

**Location**: `Services/UploadStatusStore.swift`
**Type**: ObservableObject
**Purpose**: Upload status tracking and notification

**Published Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `statuses` | `[UUID: UploadStatus]` | Status per item |

**Methods**:
```swift
func getStatus(for id: UUID) -> UploadStatus
func updateStatus(_ id: UUID, status: UploadStatus)
func clearCompleted()
```

---

### SupabaseManager

**Location**: `Services/Supabase/SupabaseManager.swift`
**Type**: Singleton
**Purpose**: Supabase client management

**Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `client` | `SupabaseClient` | Supabase SDK client |
| `isConfigured` | `Bool` | Whether configured |

**Methods**:
```swift
func configure(url: String, key: String)
```

---

### StorageService

**Location**: `Services/Supabase/StorageService.swift`
**Type**: Class
**Purpose**: Cloud storage operations

**Methods**:
```swift
func upload(fileURL: URL, bucket: String, path: String) async throws -> URL
func download(bucket: String, path: String) async throws -> Data
func delete(bucket: String, path: String) async throws
func getPublicURL(bucket: String, path: String) -> URL?
```

---

### UploadService

**Location**: `Services/Supabase/UploadService.swift`
**Type**: Class
**Purpose**: High-level upload orchestration

**Methods**:
```swift
func uploadMedia(_ item: MediaItem) async throws -> URL
func processQueue() async
func retryFailedUploads() async
```

---

## Voice Services

### VoiceEngine

**Location**: `Services/Voice/VoiceEngine.swift`
**Type**: Singleton (`VoiceEngine.shared`)
**Purpose**: Voice I/O coordination

**Published Properties**:
| Property | Type | Description |
|----------|------|-------------|
| `isListening` | `Bool` | Recording voice input |
| `isSpeaking` | `Bool` | Playing TTS output |
| `transcribedText` | `String` | Current transcription |

**Methods**:
```swift
func startListening()
func stopListening()
func speak(_ text: String)
func stopSpeaking()
func pauseSpeaking()
func resumeSpeaking()
```

---

### VoiceInputService

**Location**: `Services/Voice/VoiceInputService.swift`
**Type**: Class
**Purpose**: Speech-to-text implementation

**Methods**:
```swift
func startRecognition() throws
func stopRecognition()
var transcriptionStream: AsyncStream<String> { get }
```

---

### TextToSpeechService

**Location**: `Services/Voice/TextToSpeechService.swift`
**Type**: Class
**Purpose**: Text-to-speech implementation

**Methods**:
```swift
func speak(_ text: String)
func stop()
func pause()
func resume()
var rate: Float { get set }  // 0.0 - 1.0
var volume: Float { get set }  // 0.0 - 1.0
```

---

## Utility Services

### ImageCompressor

**Location**: `Services/ImageCompressor.swift`
**Type**: Static methods
**Purpose**: Image compression utilities

**Methods**:
```swift
static func compress(_ image: UIImage, maxSize: Int) -> Data
static func compress(_ data: Data, maxSize: Int) -> Data
static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage
```

---

### ThumbnailGenerator

**Location**: `Services/ThumbnailGenerator.swift`
**Type**: Static methods
**Purpose**: Video thumbnail generation

**Methods**:
```swift
static func generateThumbnail(for videoURL: URL, at time: CMTime) async -> UIImage?
static func generateThumbnail(for videoURL: URL) async -> UIImage?  // Uses first frame
```

---

### LANScanner

**Location**: `Services/LANScanner.swift`
**Type**: Class
**Purpose**: Local network device scanning

**Methods**:
```swift
func scan(timeout: TimeInterval) async -> [LANDevice]
func cancelScan()
```

---

### WiFiHelper

**Location**: `Services/WiFiHelper.swift`
**Type**: Static methods
**Purpose**: WiFi information utilities

**Methods**:
```swift
static func getCurrentSSID() -> String?
static func getCurrentBSSID() -> String?
static func isConnectedToWiFi() -> Bool
```

---

### KeychainHelper

**Location**: `Services/Keychain/KeychainHelper.swift`
**Type**: Singleton (`KeychainHelper.standard`)
**Purpose**: Keychain access wrapper

**Methods**:
```swift
func save(_ value: String, key: String)
func read(key: String) -> String?
func delete(key: String)
func exists(key: String) -> Bool
```

---

*Last updated: January 2026*
