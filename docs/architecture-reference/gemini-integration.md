# Gemini AI Integration

Documentation of the Gemini Live API integration for real-time video Q&A.

## Overview

The app integrates with Google's Gemini API for:

1. **Real-time video streaming**: Live video frames sent to Gemini for analysis
2. **Chat conversations**: Text-based Q&A with conversation history
3. **Image analysis**: Single image analysis
4. **Video analysis**: Recorded video analysis

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GeminiKeyManager                         │
│                    (API Key Storage)                        │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    GeminiConfig                             │
│                    (Configuration)                          │
└────────────────────────────┬────────────────────────────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
          ▼                  ▼                  ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ GeminiSDKService │ │ GeminiChatService│ │ StreamingService │
│ (SDK Wrapper)    │ │ (Conversations)  │ │ (Video Frames)   │
└────────┬─────────┘ └────────┬─────────┘ └────────┬─────────┘
         │                    │                    │
         │         ┌──────────┴──────────┐         │
         │         │                     │         │
         ▼         ▼                     ▼         ▼
┌───────────────────────────────────────────────────────────┐
│                 GeminiSessionManager                       │
│                 (WebSocket Connection)                     │
└────────────────────────────┬──────────────────────────────┘
                             │
                             ▼
┌───────────────────────────────────────────────────────────┐
│              Google Generative AI API                      │
│              (gemini-2.0-flash-exp)                        │
└───────────────────────────────────────────────────────────┘
```

## Components

### GeminiKeyManager

Securely stores and retrieves the API key:

```swift
// GeminiKeyManager.swift
class GeminiKeyManager {
    static let shared = GeminiKeyManager()

    private let keychain = KeychainHelper.standard
    private let apiKeyKey = "gemini_api_key"

    var apiKey: String? {
        get { keychain.read(key: apiKeyKey) }
        set {
            if let value = newValue {
                keychain.save(value, key: apiKeyKey)
            } else {
                keychain.delete(key: apiKeyKey)
            }
        }
    }

    var hasValidKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty && key.hasPrefix("AI")
    }

    func validateKey(_ key: String) async -> Bool {
        // Make a simple API call to validate
        do {
            let model = GenerativeModel(name: "gemini-2.0-flash-exp", apiKey: key)
            _ = try await model.generateContent("test")
            return true
        } catch {
            return false
        }
    }
}
```

### GeminiConfig

Configuration constants:

```swift
// GeminiConfig.swift
struct GeminiConfig {
    // Model identifiers
    static let chatModel = "gemini-2.0-flash-exp"
    static let visionModel = "gemini-2.0-flash-exp"
    static let streamingModel = "gemini-2.0-flash-exp"

    // Streaming configuration
    static let defaultFramesPerSecond = 5
    static let maxFramesPerSecond = 30
    static let minFramesPerSecond = 1

    // Image compression
    static let maxImageSize: Int = 200_000  // 200KB
    static let jpegCompression: CGFloat = 0.7

    // System instructions
    static let chatSystemInstruction = """
        You are a helpful AI assistant analyzing live video and images.
        Provide concise, conversational responses.
        Focus on what's visible and relevant to the user's questions.
        """

    static let streamingSystemInstruction = """
        You are analyzing a live video stream.
        Describe what you see briefly and answer questions about the content.
        Keep responses short and natural for voice output.
        """
}
```

### GeminiSDKService

Wrapper around the Google Generative AI SDK:

```swift
// GeminiSDKService.swift
class GeminiSDKService {
    static let shared = GeminiSDKService()

    private var model: GenerativeModel?

    private init() {
        setupModel()
    }

    private func setupModel() {
        guard let apiKey = GeminiKeyManager.shared.apiKey else { return }

        model = GenerativeModel(
            name: GeminiConfig.chatModel,
            apiKey: apiKey,
            generationConfig: GenerationConfig(
                temperature: 0.7,
                topP: 0.9,
                topK: 40,
                maxOutputTokens: 2048
            ),
            systemInstruction: ModelContent(
                role: "system",
                parts: [.text(GeminiConfig.chatSystemInstruction)]
            )
        )
    }

    // MARK: - Single Generation

    func generateContent(prompt: String) async throws -> String {
        guard let model = model else {
            throw GeminiError.notConfigured
        }

        let response = try await model.generateContent(prompt)
        return response.text ?? ""
    }

    // MARK: - Streaming Generation

    func generateContentStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let model = self.model else {
                    continuation.finish(throwing: GeminiError.notConfigured)
                    return
                }

                do {
                    let stream = model.generateContentStream(prompt)
                    for try await chunk in stream {
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

    // MARK: - Image Analysis

    func analyzeImage(_ imageData: Data, prompt: String) async throws -> String {
        guard let model = model else {
            throw GeminiError.notConfigured
        }

        let compressedData = compressImage(imageData)

        let response = try await model.generateContent(
            prompt,
            ModelContent.Part.data(mimetype: "image/jpeg", compressedData)
        )

        return response.text ?? ""
    }

    // MARK: - Video Analysis

    func analyzeVideo(url: URL, prompt: String) async throws -> String {
        guard let model = model else {
            throw GeminiError.notConfigured
        }

        let videoData = try Data(contentsOf: url)

        let response = try await model.generateContent(
            prompt,
            ModelContent.Part.data(mimetype: "video/mp4", videoData)
        )

        return response.text ?? ""
    }

    // MARK: - Private Methods

    private func compressImage(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }

        var compression: CGFloat = GeminiConfig.jpegCompression
        var compressedData = image.jpegData(compressionQuality: compression) ?? data

        // Reduce quality until under size limit
        while compressedData.count > GeminiConfig.maxImageSize && compression > 0.1 {
            compression -= 0.1
            compressedData = image.jpegData(compressionQuality: compression) ?? data
        }

        return compressedData
    }
}
```

### GeminiChatService

Handles conversation with history:

```swift
// GeminiChatService.swift
class GeminiChatService {
    static let shared = GeminiChatService()

    private var model: GenerativeModel?
    private var chat: Chat?

    private init() {
        setupModel()
    }

    private func setupModel() {
        guard let apiKey = GeminiKeyManager.shared.apiKey else { return }

        model = GenerativeModel(
            name: GeminiConfig.chatModel,
            apiKey: apiKey,
            systemInstruction: ModelContent(
                role: "system",
                parts: [.text(GeminiConfig.chatSystemInstruction)]
            )
        )
    }

    // MARK: - Chat

    func startNewChat(history: [ChatMessage] = []) {
        guard let model = model else { return }

        // Convert app messages to SDK format
        let sdkHistory = history.map { message -> ModelContent in
            ModelContent(
                role: message.role == .user ? "user" : "model",
                parts: convertContentToParts(message.content)
            )
        }

        chat = model.startChat(history: sdkHistory)
    }

    func sendMessage(_ text: String) async throws -> String {
        guard let chat = chat else {
            throw GeminiError.noChatSession
        }

        let response = try await chat.sendMessage(text)
        return response.text ?? ""
    }

    func streamMessage(_ text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let chat = self.chat else {
                    continuation.finish(throwing: GeminiError.noChatSession)
                    return
                }

                do {
                    let stream = chat.sendMessageStream(text)
                    for try await chunk in stream {
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

    // MARK: - Image/Video in Chat

    func sendWithImage(_ imageData: Data, caption: String?) async throws -> String {
        guard let chat = chat else {
            throw GeminiError.noChatSession
        }

        let compressedData = compressImage(imageData)
        let prompt = caption ?? "What do you see in this image?"

        let response = try await chat.sendMessage([
            .text(prompt),
            .data(mimetype: "image/jpeg", compressedData)
        ])

        return response.text ?? ""
    }

    func sendWithVideo(url: URL, caption: String?) async throws -> String {
        guard let chat = chat else {
            throw GeminiError.noChatSession
        }

        let videoData = try Data(contentsOf: url)
        let prompt = caption ?? "Analyze this video."

        let response = try await chat.sendMessage([
            .text(prompt),
            .data(mimetype: "video/mp4", videoData)
        ])

        return response.text ?? ""
    }

    // MARK: - Private Methods

    private func convertContentToParts(_ content: ChatMessageContent) -> [ModelContent.Part] {
        switch content {
        case .text(let text):
            return [.text(text)]
        case .image(let data, let caption):
            var parts: [ModelContent.Part] = []
            if let caption = caption {
                parts.append(.text(caption))
            }
            parts.append(.data(mimetype: "image/jpeg", data))
            return parts
        case .video(let url, let caption):
            var parts: [ModelContent.Part] = []
            if let caption = caption {
                parts.append(.text(caption))
            }
            if let data = try? Data(contentsOf: url) {
                parts.append(.data(mimetype: "video/mp4", data))
            }
            return parts
        }
    }

    private func compressImage(_ data: Data) -> Data {
        // Same compression logic as GeminiSDKService
        guard let image = UIImage(data: data) else { return data }
        return image.jpegData(compressionQuality: 0.7) ?? data
    }
}
```

### GeminiSessionManager

Manages WebSocket sessions for real-time streaming:

```swift
// GeminiSessionManager.swift
class GeminiSessionManager: ObservableObject {
    static let shared = GeminiSessionManager()

    // MARK: - Published State
    @Published var isConnected = false
    @Published var isStreaming = false
    @Published var latestResponse: String = ""
    @Published var error: GeminiError?

    // MARK: - WebSocket
    private var webSocketService: GeminiWebSocketService?
    private var sessionId: String?

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Session Management

    func startSession() async throws {
        guard let apiKey = GeminiKeyManager.shared.apiKey else {
            throw GeminiError.notConfigured
        }

        webSocketService = GeminiWebSocketService(apiKey: apiKey)

        try await webSocketService?.connect()

        setupResponseHandler()
        isConnected = true
    }

    func endSession() {
        webSocketService?.disconnect()
        webSocketService = nil
        isConnected = false
        isStreaming = false
    }

    // MARK: - Frame Submission

    func submitFrame(_ imageData: Data) async {
        guard isConnected, let service = webSocketService else { return }

        let base64 = imageData.base64EncodedString()

        let message: [String: Any] = [
            "type": "realtime_input",
            "media_chunks": [
                [
                    "mime_type": "image/jpeg",
                    "data": base64
                ]
            ]
        ]

        do {
            try await service.send(message)
        } catch {
            self.error = .connectionError(error.localizedDescription)
        }
    }

    func submitText(_ text: String) async {
        guard isConnected, let service = webSocketService else { return }

        let message: [String: Any] = [
            "type": "realtime_input",
            "text": text
        ]

        do {
            try await service.send(message)
        } catch {
            self.error = .connectionError(error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    private func setupResponseHandler() {
        webSocketService?.responsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                self?.handleResponse(response)
            }
            .store(in: &cancellables)
    }

    private func handleResponse(_ response: [String: Any]) {
        guard let type = response["type"] as? String else { return }

        switch type {
        case "content_part":
            if let text = response["text"] as? String {
                latestResponse += text
            }
        case "turn_complete":
            // Response finished
            isStreaming = false
        case "error":
            if let message = response["message"] as? String {
                error = .apiError(message)
            }
        default:
            break
        }
    }
}
```

### StreamingService

Handles real-time video streaming to Gemini:

```swift
// StreamingService.swift
class StreamingService: ObservableObject {
    static let shared = StreamingService()

    // MARK: - Published State
    @Published var isStreaming = false
    @Published var frameRate: Int = GeminiConfig.defaultFramesPerSecond
    @Published var framesSubmitted: Int = 0
    @Published var error: Error?

    // MARK: - Dependencies
    private let sessionManager: GeminiSessionManager
    private let cameraSourceManager: CameraSourceManager

    // MARK: - Streaming State
    private var streamingTask: Task<Void, Never>?
    private var lastFrameTime: Date?

    init(
        sessionManager: GeminiSessionManager = .shared,
        cameraSourceManager: CameraSourceManager = .shared
    ) {
        self.sessionManager = sessionManager
        self.cameraSourceManager = cameraSourceManager
    }

    // MARK: - Public API

    func startStreaming() async throws {
        guard !isStreaming else { return }

        // Ensure Gemini session is active
        if !sessionManager.isConnected {
            try await sessionManager.startSession()
        }

        isStreaming = true
        framesSubmitted = 0

        streamingTask = Task {
            await streamingLoop()
        }
    }

    func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
    }

    func setFrameRate(_ fps: Int) {
        frameRate = max(
            GeminiConfig.minFramesPerSecond,
            min(fps, GeminiConfig.maxFramesPerSecond)
        )
    }

    // MARK: - Private Methods

    private func streamingLoop() async {
        let frameInterval = 1.0 / Double(frameRate)

        while !Task.isCancelled && isStreaming {
            do {
                // Get frame from current camera source
                guard let frameData = await cameraSourceManager.getLatestFrame() else {
                    try await Task.sleep(nanoseconds: UInt64(frameInterval * 1_000_000_000))
                    continue
                }

                // Compress frame
                let compressedData = compressFrame(frameData)

                // Submit to Gemini
                await sessionManager.submitFrame(compressedData)
                framesSubmitted += 1

                // Rate limiting
                let elapsed = lastFrameTime.map { Date().timeIntervalSince($0) } ?? frameInterval
                let sleepTime = max(0, frameInterval - elapsed)
                try await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))

                lastFrameTime = Date()

            } catch is CancellationError {
                break
            } catch {
                self.error = error
                // Continue despite errors
            }
        }
    }

    private func compressFrame(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }

        // Start with default compression
        var compression = GeminiConfig.jpegCompression
        var compressedData = image.jpegData(compressionQuality: compression) ?? data

        // Reduce quality until under size limit
        while compressedData.count > GeminiConfig.maxImageSize && compression > 0.1 {
            compression -= 0.1
            compressedData = image.jpegData(compressionQuality: compression) ?? data
        }

        return compressedData
    }
}
```

## Data Flow

### Real-Time Streaming

```
Camera Source (Local/Veepa)
         │
         ▼ (Frame Data)
┌─────────────────────────────────────────┐
│ StreamingService                        │
│ • Rate limiting (1-30 FPS)              │
│ • Frame compression (<200KB JPEG)       │
└─────────────────────────────────────────┘
         │
         ▼ (Compressed Frame)
┌─────────────────────────────────────────┐
│ GeminiSessionManager                    │
│ • Base64 encode                         │
│ • WebSocket message                     │
└─────────────────────────────────────────┘
         │
         ▼ (WebSocket)
┌─────────────────────────────────────────┐
│ Gemini Live API                         │
│ • Process video frames                  │
│ • Generate responses                    │
└─────────────────────────────────────────┘
         │
         ▼ (Response Stream)
┌─────────────────────────────────────────┐
│ GeminiSessionManager                    │
│ • Parse response chunks                 │
│ • Publish to UI                         │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ ChatViewModel                           │
│ • Display response                      │
│ • Trigger TTS                           │
└─────────────────────────────────────────┘
```

### Chat Conversation

```
User Input (Text/Image/Video)
         │
         ▼
┌─────────────────────────────────────────┐
│ ChatViewModel                           │
│ • Add to messages                       │
│ • Call chat service                     │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ GeminiChatService                       │
│ • Include conversation history          │
│ • Stream response                       │
└─────────────────────────────────────────┘
         │
         ▼ (SDK Call)
┌─────────────────────────────────────────┐
│ Google Generative AI SDK                │
│ • model.sendMessageStream()             │
└─────────────────────────────────────────┘
         │
         ▼ (Response Chunks)
┌─────────────────────────────────────────┐
│ ChatViewModel                           │
│ • Accumulate chunks                     │
│ • Detect sentences for TTS              │
│ • Save to conversation                  │
└─────────────────────────────────────────┘
```

## Error Handling

```swift
// GeminiError.swift
enum GeminiError: LocalizedError {
    case notConfigured
    case invalidApiKey
    case noChatSession
    case connectionError(String)
    case apiError(String)
    case rateLimitExceeded
    case contentFiltered
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
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
```

## Voice Integration

Responses can be spoken using Text-to-Speech:

```swift
// In ChatViewModel
func handleStreamingChunk(_ chunk: String) {
    streamingResponse += chunk

    // Detect complete sentences
    if let sentenceEnd = detectSentenceEnd(in: streamingResponse) {
        let sentence = String(streamingResponse.prefix(sentenceEnd + 1))
        streamingResponse = String(streamingResponse.dropFirst(sentenceEnd + 1))

        // Speak the sentence
        voiceEngine.speak(sentence)
    }
}

private func detectSentenceEnd(in text: String) -> Int? {
    let sentenceEnders: [Character] = [".", "!", "?"]

    for (index, char) in text.enumerated() {
        if sentenceEnders.contains(char) {
            // Check it's not a decimal point or abbreviation
            if index + 1 >= text.count || text[text.index(text.startIndex, offsetBy: index + 1)].isWhitespace {
                return index
            }
        }
    }
    return nil
}
```

## Performance Optimization

### Frame Rate Control

```swift
// User can adjust frame rate based on needs
class StreamingService {
    func setFrameRate(_ fps: Int) {
        // Lower FPS = less API usage, lower cost
        // Higher FPS = more responsive, higher cost
        frameRate = max(1, min(fps, 30))
    }
}
```

### Image Compression

```swift
// Frames are compressed to minimize bandwidth
private func compressFrame(_ data: Data) -> Data {
    guard let image = UIImage(data: data) else { return data }

    // Target: <200KB per frame
    var compression: CGFloat = 0.7
    var result = image.jpegData(compressionQuality: compression)!

    while result.count > 200_000 && compression > 0.1 {
        compression -= 0.1
        result = image.jpegData(compressionQuality: compression)!
    }

    return result
}
```

### Connection Management

```swift
// Reuse WebSocket connection across streaming sessions
class GeminiSessionManager {
    func startSession() async throws {
        // Only create new connection if not already connected
        guard !isConnected else { return }
        // ...
    }
}
```

## Security

### API Key Storage

- Stored in iOS Keychain (encrypted)
- Never included in app binary
- Never logged in plaintext

### Network Security

- All API calls over HTTPS
- WebSocket uses WSS (secure)
- Certificate pinning (optional)

---

*Last updated: January 2026*
