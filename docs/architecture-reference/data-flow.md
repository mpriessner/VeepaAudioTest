# Data Flow Patterns

Documentation of how data flows through the application in various scenarios.

## Complete User Session Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           APP LAUNCH                                     │
│                                                                          │
│  1. AppDelegate initializes Flutter engine (if needed)                   │
│  2. PermissionManager checks camera/mic permissions                      │
│  3. GeminiKeyManager loads API key from Keychain                        │
│  4. CameraSourceManager restores last used camera source                │
│  5. ConversationManager loads chat history from UserDefaults            │
│  6. ContentView displays main tab navigation                            │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          CAMERA TAB                                      │
│                                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────────┐  │
│  │ CameraView   │───▶│ CameraVM     │───▶│ CameraSourceManager      │  │
│  │ (SwiftUI)    │    │ (State)      │    │ → LocalCameraSource      │  │
│  │              │    │              │    │ → VeepaCameraSource       │  │
│  └──────────────┘    └──────────────┘    └──────────────────────────┘  │
│                                                                          │
│  User Actions:                                                           │
│  • Record video → Files saved to Documents/                             │
│  • Capture photo → Files saved to Documents/                            │
│  • Switch camera source (Local ↔ Veepa)                                 │
│  • Adjust zoom/focus/resolution                                         │
│  • Start/stop Gemini streaming                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        GEMINI STREAMING                                  │
│                                                                          │
│  Frame Capture:                                                          │
│  Camera → StreamingService → GeminiSessionManager → WebSocket → API     │
│                                                                          │
│  Response:                                                               │
│  API → WebSocket → GeminiSessionManager → ChatViewModel → UI + TTS      │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           CHAT TAB                                       │
│                                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────────┐  │
│  │ ChatView     │───▶│ ChatVM       │───▶│ GeminiChatService        │  │
│  │ (SwiftUI)    │    │ (State)      │    │ → Streaming responses    │  │
│  │              │◀───│              │◀───│ → Image/Video analysis   │  │
│  └──────────────┘    └──────────────┘    └──────────────────────────┘  │
│                            │                                            │
│                            ▼                                            │
│                   ┌──────────────────┐                                  │
│                   │ ConversationStore│                                  │
│                   │ (Persistence)    │                                  │
│                   └──────────────────┘                                  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         GALLERY TAB                                      │
│                                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────────┐  │
│  │ GalleryView  │───▶│ GalleryVM    │───▶│ File System              │  │
│  │ (SwiftUI)    │    │ (State)      │    │ → Documents/ directory   │  │
│  │              │    │              │    │ → Thumbnail generation   │  │
│  └──────────────┘    └──────────────┘    └──────────────────────────┘  │
│                            │                                            │
│                            ▼                                            │
│                   ┌──────────────────┐                                  │
│                   │ Upload Queue     │                                  │
│                   │ → Supabase       │                                  │
│                   └──────────────────┘                                  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Pattern 1: Local Camera Video Recording

```
┌─────────────────────────────────────────────────────────────────────────┐
│ User taps "Record" button                                               │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ CameraView                                                              │
│   Button("Record") {                                                    │
│       viewModel.startRecording()                                        │
│   }                                                                     │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ CameraViewModel                                                         │
│   func startRecording() {                                               │
│       Task {                                                            │
│           try await cameraManager.startRecordingVideo()                 │
│       }                                                                 │
│   }                                                                     │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ CameraManager                                                           │
│   func startRecordingVideo() {                                          │
│       let outputURL = generateVideoURL()  // Documents/video_*.mov      │
│       movieOutput.startRecording(to: outputURL, delegate: self)         │
│       isRecording = true                                                │
│   }                                                                     │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ AVCaptureMovieFileOutput                                                │
│   • Records video to file                                               │
│   • Calls delegate when complete                                        │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ CameraManager (delegate callback)                                       │
│   func fileOutput(_ output, didFinishRecordingTo url) {                │
│       isRecording = false                                               │
│       lastRecordedVideoURL = url                                        │
│   }                                                                     │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ CameraViewModel (@Published update)                                     │
│   • UI shows "Recording complete" toast                                 │
│   • Video available in Gallery                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Pattern 2: Veepa Camera Connection

```
┌─────────────────────────────────────────────────────────────────────────┐
│ User selects "Veepa Camera" in settings or camera selector              │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ CameraSourceManager.switchTo(.veepaWiFi)                                │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. Disconnect current source                                            │
│    LocalCameraSource.disconnect()                                       │
│    → AVCaptureSession.stopRunning()                                     │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 2. Initialize Flutter engine                                            │
│    FlutterEngineManager.initialize()                                    │
│    → FlutterEngine.run()                                                │
│    → Setup platform channels                                            │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 3. Load cached credentials                                              │
│    P2PCredentialService.loadCredentials()                               │
│    → Check Keychain for saved P2P credentials                           │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                    ┌───────────────────┴───────────────────┐
                    │                                       │
            Credentials Found                       No Credentials
                    │                                       │
                    ▼                                       ▼
┌──────────────────────────────────┐   ┌──────────────────────────────────┐
│ 4a. Connect with credentials     │   │ 4b. Start provisioning workflow  │
│     VeepaConnectionBridge        │   │     VeepaProvisioningBridge      │
│     .connect(credentials)        │   │     → Show QR scanner            │
└─────────────────┬────────────────┘   │     → Scan camera QR             │
                  │                     │     → Generate WiFi config QR    │
                  │                     │     → Camera connects to WiFi    │
                  │                     │     → Save credentials           │
                  │                     └─────────────────┬────────────────┘
                  │                                       │
                  └───────────────────┬───────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 5. Establish connection via Flutter                                     │
│    VeepaConnectionManager (Dart)                                        │
│    → CameraDevice.connect()                                             │
│    → P2P handshake                                                      │
│    → Connection state: .connected                                       │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 6. Start frame streaming                                                │
│    VeepaFrameBridge.startStreaming()                                    │
│    → Veepa SDK sends video frames                                       │
│    → Frames arrive via EventChannel                                     │
│    → Buffered for preview and AI                                        │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 7. Frames available                                                     │
│    VeepaCameraSource.getLatestFrame() → Data                            │
│    → Used for camera preview                                            │
│    → Used for Gemini streaming                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Pattern 3: Real-Time Video Streaming to Gemini

```
┌─────────────────────────────────────────────────────────────────────────┐
│ User taps "Start Streaming" button                                      │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ VideoStreamViewModel.startStreaming()                                   │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. Start Gemini session                                                 │
│    GeminiSessionManager.startSession()                                  │
│    → Create WebSocket connection                                        │
│    → Connect to Gemini Live API                                         │
│    → Setup response handlers                                            │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 2. Start streaming service                                              │
│    StreamingService.startStreaming()                                    │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 3. STREAMING LOOP (runs until stopped)                                  │
│    ┌─────────────────────────────────────────────────────────────────┐ │
│    │ a. Get frame from camera source                                 │ │
│    │    let frame = await cameraSourceManager.getLatestFrame()       │ │
│    └─────────────────────────────┬───────────────────────────────────┘ │
│                                  │                                      │
│    ┌─────────────────────────────▼───────────────────────────────────┐ │
│    │ b. Compress frame                                               │ │
│    │    • Convert to JPEG                                            │ │
│    │    • Reduce quality until < 200KB                               │ │
│    └─────────────────────────────┬───────────────────────────────────┘ │
│                                  │                                      │
│    ┌─────────────────────────────▼───────────────────────────────────┐ │
│    │ c. Submit to Gemini                                             │ │
│    │    • Base64 encode                                              │ │
│    │    • Send via WebSocket                                         │ │
│    │    sessionManager.submitFrame(compressedData)                   │ │
│    └─────────────────────────────┬───────────────────────────────────┘ │
│                                  │                                      │
│    ┌─────────────────────────────▼───────────────────────────────────┐ │
│    │ d. Rate limiting                                                │ │
│    │    • Sleep for (1 / framesPerSecond) seconds                    │ │
│    │    • Default: 5 FPS = 200ms between frames                      │ │
│    └─────────────────────────────┬───────────────────────────────────┘ │
│                                  │                                      │
│                          Loop continues                                 │
└─────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ (Concurrent)
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 4. RESPONSE HANDLING (runs concurrently)                                │
│    ┌─────────────────────────────────────────────────────────────────┐ │
│    │ a. Receive WebSocket message                                    │ │
│    │    GeminiSessionManager receives response                       │ │
│    └─────────────────────────────┬───────────────────────────────────┘ │
│                                  │                                      │
│    ┌─────────────────────────────▼───────────────────────────────────┐ │
│    │ b. Parse response chunks                                        │ │
│    │    • Extract text content                                       │ │
│    │    • Update latestResponse                                      │ │
│    └─────────────────────────────┬───────────────────────────────────┘ │
│                                  │                                      │
│    ┌─────────────────────────────▼───────────────────────────────────┐ │
│    │ c. Update UI                                                    │ │
│    │    ChatViewModel.streamingResponse updated                      │ │
│    │    SwiftUI view refreshes                                       │ │
│    └─────────────────────────────┬───────────────────────────────────┘ │
│                                  │                                      │
│    ┌─────────────────────────────▼───────────────────────────────────┐ │
│    │ d. Text-to-Speech                                               │ │
│    │    • Detect complete sentences                                  │ │
│    │    • Speak each sentence immediately                            │ │
│    │    VoiceEngine.speak(sentence)                                  │ │
│    └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

## Pattern 4: Chat with Image/Video Attachment

```
┌─────────────────────────────────────────────────────────────────────────┐
│ User selects image/video and types message                              │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ ChatView                                                                │
│   User selects media via MediaAttachmentMenu                            │
│   User types caption/question                                           │
│   User taps Send                                                        │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ ChatViewModel                                                           │
│   1. Create user message with image/video content                       │
│      let message = ChatMessage(                                         │
│          role: .user,                                                   │
│          content: .image(imageData, caption: text)                      │
│      )                                                                  │
│   2. Append to messages array                                           │
│   3. Save to ConversationStore                                          │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ GeminiChatService.sendWithImage(imageData, caption)                     │
│   1. Compress image if needed                                           │
│   2. Create multimodal message with chat history                        │
│   3. Send to Gemini SDK                                                 │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Google Generative AI SDK                                                │
│   chat.sendMessage([                                                    │
│       .text(caption),                                                   │
│       .data(mimetype: "image/jpeg", imageData)                          │
│   ])                                                                    │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Response Stream                                                         │
│   for try await chunk in stream {                                       │
│       chatViewModel.streamingResponse += chunk.text                     │
│   }                                                                     │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ ChatViewModel (on response complete)                                    │
│   1. Create assistant message                                           │
│      let response = ChatMessage(                                        │
│          role: .assistant,                                              │
│          content: .text(streamingResponse)                              │
│      )                                                                  │
│   2. Append to messages                                                 │
│   3. Save to ConversationStore                                          │
│   4. Reset streaming state                                              │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ SwiftUI View Update                                                     │
│   • ChatView shows new messages                                         │
│   • MessageBubble displays assistant response                           │
│   • VoiceEngine speaks response (if enabled)                            │
└─────────────────────────────────────────────────────────────────────────┘
```

## Pattern 5: Media Upload to Cloud

```
┌─────────────────────────────────────────────────────────────────────────┐
│ User captures/records media OR selects "Upload" in gallery              │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ UploadQueue.addItem(mediaItem)                                          │
│   1. Create UploadItem with file URL                                    │
│   2. Set status = .pending                                              │
│   3. Persist to UserDefaults                                            │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ UploadService.processQueue()                                            │
│   1. Get next pending item                                              │
│   2. Set status = .uploading                                            │
│   3. Update UploadStatusStore                                           │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ StorageService.upload(fileURL)                                          │
│   1. Read file data                                                     │
│   2. Generate unique storage path                                       │
│   3. Upload to Supabase Storage                                         │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                    ┌───────────────────┴───────────────────┐
                    │                                       │
               Success                                   Failure
                    │                                       │
                    ▼                                       ▼
┌──────────────────────────────────┐   ┌──────────────────────────────────┐
│ UploadService (success)          │   │ UploadService (failure)          │
│   1. Get public URL              │   │   1. Set status = .failed        │
│   2. Set status = .completed     │   │   2. Increment retry count       │
│   3. Save URL to MediaItem       │   │   3. Keep in queue for retry     │
│   4. Remove from queue           │   │   4. Persist error message       │
└─────────────────┬────────────────┘   └─────────────────┬────────────────┘
                  │                                       │
                  └───────────────────┬───────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ UploadStatusStore (publish update)                                      │
│   1. Update status for item                                             │
│   2. Notify subscribers (Combine)                                       │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ GalleryView                                                             │
│   • UploadStatusBadge shows current status                              │
│   • Green checkmark for completed                                       │
│   • Red X for failed (with retry option)                                │
└─────────────────────────────────────────────────────────────────────────┘
```

## Pattern 6: Voice Input/Output

```
┌─────────────────────────────────────────────────────────────────────────┐
│ User taps microphone button                                             │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ VOICE INPUT                                                             │
│                                                                          │
│   VoiceInputButton tapped                                               │
│         │                                                                │
│         ▼                                                                │
│   VoiceEngine.startListening()                                          │
│         │                                                                │
│         ▼                                                                │
│   VoiceInputService                                                     │
│   • SFSpeechRecognizer starts                                           │
│   • Audio session configured                                            │
│   • Recognition task running                                            │
│         │                                                                │
│         ▼                                                                │
│   Real-time transcription                                               │
│   • Partial results update UI                                           │
│   • VoiceIndicator shows listening state                                │
│         │                                                                │
│         ▼                                                                │
│   User stops speaking (silence detection) or taps button                │
│         │                                                                │
│         ▼                                                                │
│   Final transcription → ChatViewModel.inputText                         │
│         │                                                                │
│         ▼                                                                │
│   Send message to Gemini                                                │
└───────────────────────────────────────┬─────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ VOICE OUTPUT                                                            │
│                                                                          │
│   Gemini response streaming                                             │
│         │                                                                │
│         ▼                                                                │
│   ChatViewModel detects complete sentences                              │
│         │                                                                │
│         ▼                                                                │
│   VoiceEngine.speak(sentence)                                           │
│         │                                                                │
│         ▼                                                                │
│   TextToSpeechService                                                   │
│   • AVSpeechSynthesizer configured                                      │
│   • Utterance queued                                                    │
│         │                                                                │
│         ▼                                                                │
│   Audio output                                                          │
│   • Sentence spoken aloud                                               │
│   • VoiceIndicator shows speaking state                                 │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Persistence Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          PERSISTENCE LAYERS                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ KEYCHAIN (Secure, Encrypted)                                    │   │
│  │   • Gemini API Key                                              │   │
│  │   • Supabase credentials                                        │   │
│  │   • Veepa P2P credentials                                       │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ USERDEFAULTS (App Preferences)                                  │   │
│  │   • Video resolution setting                                    │   │
│  │   • Frame rate setting                                          │   │
│  │   • Auto-upload toggle                                          │   │
│  │   • Last camera source                                          │   │
│  │   • Chat history (JSON encoded)                                 │   │
│  │   • Upload queue (JSON encoded)                                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ FILE SYSTEM (Documents/)                                        │   │
│  │   • Captured videos (video_*.mov)                               │   │
│  │   • Captured photos (photo_*.jpg)                               │   │
│  │   • Thumbnails (thumb_*.jpg)                                    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ CLOUD (Supabase)                                                │   │
│  │   • Uploaded videos                                             │   │
│  │   • Uploaded photos                                             │   │
│  │   • Metadata (optional)                                         │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## State Management Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          STATE PROPAGATION                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  SERVICE LAYER                                                          │
│  (Business Logic State)                                                 │
│                                                                          │
│  CameraManager              GeminiSessionManager       NetworkMonitor   │
│  @Published isRecording     @Published isConnected     @Published      │
│  @Published zoomLevel       @Published latestResponse  isConnected     │
│       │                            │                        │          │
│       │                            │                        │          │
│       ▼                            ▼                        ▼          │
│  ─────────────────────────────────────────────────────────────────     │
│                        Combine Publishers                               │
│  ─────────────────────────────────────────────────────────────────     │
│       │                            │                        │          │
│       ▼                            ▼                        ▼          │
│                                                                          │
│  VIEWMODEL LAYER                                                        │
│  (UI State)                                                             │
│                                                                          │
│  CameraViewModel            ChatViewModel              SettingsViewModel│
│  @Published isRecording     @Published messages        @Published       │
│  @Published zoomLevel       @Published isStreaming     settings         │
│       │                            │                        │          │
│       │                            │                        │          │
│       ▼                            ▼                        ▼          │
│  ─────────────────────────────────────────────────────────────────     │
│                        SwiftUI Bindings                                 │
│                        @StateObject / @ObservedObject                   │
│  ─────────────────────────────────────────────────────────────────     │
│       │                            │                        │          │
│       ▼                            ▼                        ▼          │
│                                                                          │
│  VIEW LAYER                                                             │
│  (UI Rendering)                                                         │
│                                                                          │
│  CameraView                 ChatView                   SettingsView     │
│  • RecordingIndicator       • MessageList              • Toggles        │
│  • ZoomSlider               • InputField               • Pickers        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

*Last updated: January 2026*
