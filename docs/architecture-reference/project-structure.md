# Project Structure

Complete folder and file breakdown of the SciSymbioLens repository.

## Directory Tree

```
SciSymbioLens/
│
├── ios/                                # iOS SwiftUI Application (Primary)
│   └── SciSymbioLens/
│       ├── SciSymbioLens/              # Main app source code
│       │   ├── App/                    # Application entry point
│       │   ├── Models/                 # Data structures
│       │   ├── Protocols/              # Interface definitions
│       │   ├── Navigation/             # Navigation state
│       │   ├── Services/               # Business logic & system integrations
│       │   ├── ViewModels/             # MVVM presentation logic
│       │   ├── Views/                  # SwiftUI UI components
│       │   └── Resources/              # Assets, Info.plist, entitlements
│       │
│       ├── SciSymbioLensTests/         # Unit tests
│       ├── SciSymbioLensUITests/       # Integration tests
│       ├── VeepaSDK/                   # Veepa camera SDK (external)
│       ├── Flutter/                    # Flutter framework binaries
│       ├── project.yml                 # XcodeGen configuration
│       └── Scripts/                    # Build scripts
│
├── flutter_module/                     # Flutter Module for Veepa integration
│   └── veepa_camera/
│       ├── lib/                        # Dart source code
│       ├── test/                       # Dart unit tests
│       └── pubspec.yaml                # Flutter dependencies
│
├── backend/                            # Python FastAPI token service
│   ├── app/                            # FastAPI application
│   ├── tests/                          # Python tests
│   └── requirements.txt                # Python dependencies
│
├── docs/                               # Documentation
│   ├── architecture-reference/         # This folder
│   ├── debugging/                      # Troubleshooting guides
│   ├── stories/                        # User stories
│   ├── brief.md                        # Product brief
│   └── prd.md                          # Product requirements
│
├── .bmad-core/                         # BMAD methodology framework
├── .ralph/                             # RALPH automation scripts
├── .claude/commands/                   # Claude Code workflow definitions
├── .github/workflows/                  # GitHub Actions CI/CD
│
├── CLAUDE.md                           # Project-specific Claude instructions
├── README.md                           # Project overview
└── .gitignore
```

## Detailed Breakdown

### iOS Application (`ios/SciSymbioLens/SciSymbioLens/`)

#### App (`App/`)
Application entry points and configuration.

| File | Purpose |
|------|---------|
| `SciSymbioLensApp.swift` | SwiftUI `@main` entry point, app lifecycle |
| `AppDelegate.swift` | UIKit AppDelegate for Flutter engine setup |

#### Models (`Models/`)
Data structures used throughout the application.

| File | Purpose |
|------|---------|
| `CameraError.swift` | Enum for camera-related errors |
| `CameraSourceType.swift` | Enum: `.local` or `.veepaWiFi` |
| `ChatMessage.swift` | Chat message model (text/image/video) |
| `MediaItem.swift` | Represents captured photo/video with metadata |
| `P2PCredentials.swift` | Veepa camera P2P connection credentials |
| `UploadStatus.swift` | Enum: pending, uploading, complete, failed |
| `VideoResolution.swift` | Enum: resolution presets (720p, 1080p, 4K) |

#### Protocols (`Protocols/`)
Interface definitions for abstraction.

| File | Purpose |
|------|---------|
| `CameraSourceProtocol.swift` | Protocol for camera sources (local/Veepa) |

#### Navigation (`Navigation/`)
Navigation state management.

| File | Purpose |
|------|---------|
| `AppNavigationState.swift` | App-wide navigation state |

#### Services (`Services/`)
Business logic and system integrations.

**Root Services:**

| File | Purpose | Lines |
|------|---------|-------|
| `CameraManager.swift` | AVFoundation camera orchestration | ~907 |
| `AppSettings.swift` | User preferences persistence | ~100 |
| `ConversationStore.swift` | Chat history persistence | ~150 |
| `HapticService.swift` | Haptic feedback | ~50 |
| `PermissionManager.swift` | Camera/mic permission handling | ~100 |
| `NetworkMonitor.swift` | Network connectivity monitoring | ~80 |
| `ImageCompressor.swift` | Image compression for uploads | ~60 |
| `ThumbnailGenerator.swift` | Video thumbnail generation | ~80 |
| `LANScanner.swift` | Local network device scanning | ~120 |
| `P2PCredentialService.swift` | Veepa P2P credential management | ~100 |
| `WiFiHelper.swift` | WiFi information utilities | ~80 |
| `UploadQueue.swift` | Upload queue management | ~150 |
| `UploadStatusStore.swift` | Upload status tracking | ~100 |

**Camera Services (`Services/Camera/`):**

| File | Purpose |
|------|---------|
| `CameraSourceManager.swift` | Manages camera source switching (singleton) |
| `LocalCameraSource.swift` | iPhone camera implementation |
| `VeepaCameraSource.swift` | External Wi-Fi camera implementation |
| `CameraManager+CameraSource.swift` | Extension for camera source protocol |

**Chat Services (`Services/Chat/`):**

| File | Purpose |
|------|---------|
| `ConversationManager.swift` | Conversation persistence and management |
| `GeminiChatService.swift` | Gemini API chat implementation |

**Gemini Services (`Services/Gemini/`):**

| File | Purpose |
|------|---------|
| `GeminiConfig.swift` | Gemini API configuration |
| `GeminiKeyManager.swift` | API key management (Keychain) |
| `GeminiSDKService.swift` | Google Generative AI SDK wrapper |
| `GeminiSessionManager.swift` | WebSocket session management |
| `GeminiWebSocketService.swift` | WebSocket connection handling |
| `StreamingService.swift` | Real-time video streaming to Gemini |
| `VideoAnalysisService.swift` | Video analysis implementation |
| `VideoUploadService.swift` | Video upload to Gemini |

**Flutter Bridge Services (`Services/Flutter/`):**

| File | Purpose |
|------|---------|
| `FlutterEngineManager.swift` | Flutter engine lifecycle (singleton) |
| `VeepaConnectionBridge.swift` | Connection state bridge |
| `VeepaDiscoveryBridge.swift` | Device discovery bridge |
| `VeepaFrameBridge.swift` | Frame/video streaming bridge |
| `VeepaProvisioningBridge.swift` | Camera pairing workflow bridge |

**Keychain Services (`Services/Keychain/`):**

| File | Purpose |
|------|---------|
| `KeychainHelper.swift` | Secure storage utilities |

**Supabase Services (`Services/Supabase/`):**

| File | Purpose |
|------|---------|
| `SupabaseConfig.swift` | Supabase configuration |
| `SupabaseManager.swift` | Supabase client management |
| `StorageService.swift` | Cloud storage operations |
| `UploadService.swift` | Upload implementation |

**Video Services (`Services/Video/`):**

| File | Purpose |
|------|---------|
| `VideoBufferService.swift` | Video frame buffering |
| `VideoBufferCaptureDelegate.swift` | AVFoundation delegate |

**Voice Services (`Services/Voice/`):**

| File | Purpose |
|------|---------|
| `VoiceEngine.swift` | Voice I/O coordination |
| `VoiceInputService.swift` | Speech recognition |
| `TextToSpeechService.swift` | Speech synthesis |

#### ViewModels (`ViewModels/`)
MVVM presentation logic.

| File | Purpose |
|------|---------|
| `CameraViewModel.swift` | Camera tab state management |
| `ChatViewModel.swift` | Chat tab state management |
| `GalleryViewModel.swift` | Gallery tab state management |
| `MediaPreviewViewModel.swift` | Media preview state |
| `SettingsViewModel.swift` | Settings tab state |
| `VideoStreamViewModel.swift` | Video streaming state |
| `ViewModelProtocol.swift` | Common ViewModel interface |

#### Views (`Views/`)
SwiftUI UI components organized by feature.

**Root Views:**

| File | Purpose |
|------|---------|
| `ContentView.swift` | Main tab navigation |
| `CameraView.swift` | Camera tab |
| `CameraPreview.swift` | Camera preview layer |
| `ControlOverlay.swift` | Camera controls overlay |
| `GalleryView.swift` | Gallery tab |
| `ChatView.swift` | Chat tab |
| `SettingsView.swift` | Settings tab |

**View Subdirectories:**

| Directory | Purpose |
|-----------|---------|
| `Analysis/` | Video analysis views |
| `Camera/` | Camera-specific views (discovery, QR scanner, Veepa) |
| `Chat/` | Chat-specific views (messages, voice) |
| `Gallery/` | Gallery-specific views |
| `History/` | Conversation history views |
| `Media/` | Media attachment views |
| `Overlay/` | Overlay components (response, streaming) |
| `Permissions/` | Permission request views |
| `Onboarding/` | Onboarding views (API key) |
| `Settings/` | Settings-specific views |
| `Upload/` | Upload progress views |
| `VideoStream/` | Video streaming mode views |

#### Resources (`Resources/`)
Application resources.

| File | Purpose |
|------|---------|
| `Info.plist` | Application configuration |
| `SciSymbioLens.entitlements` | App entitlements (camera, mic, network) |
| `Assets/` | Asset catalogs (images, colors) |

### iOS Tests

#### Unit Tests (`SciSymbioLensTests/`)

| Directory | Purpose |
|-----------|---------|
| `Camera/` | Camera service tests |
| `Chat/` | Chat service tests |
| `Flutter/` | Flutter bridge tests |
| `Gemini/` | Gemini service tests |
| `Gallery/` | Gallery tests |
| `Upload/` | Upload tests |
| `Voice/` | Voice tests |
| `Streaming/` | Streaming tests |
| `Supabase/` | Supabase tests |

#### UI Tests (`SciSymbioLensUITests/`)
Integration and UI automation tests.

### Veepa SDK (`VeepaSDK/`)
External Veepa camera SDK files.

| File | Purpose |
|------|---------|
| `libVSTC.a` | Static library |
| `VsdkPlugin.h/m` | Flutter plugin interface |
| `AppP2PApiPlugin.h` | P2P API interface |
| `AppPlayerPlugin.h` | Player interface |

### Flutter Frameworks (`Flutter/`)
Pre-built Flutter framework binaries.

| Framework | Purpose |
|-----------|---------|
| `Flutter.xcframework` | Flutter engine |
| `App.xcframework` | Flutter app module |
| `FlutterPluginRegistrant.xcframework` | Plugin registration |
| `network_info_plus.xcframework` | Network info plugin |
| `shared_preferences_foundation.xcframework` | Preferences plugin |

---

### Flutter Module (`flutter_module/veepa_camera/`)

#### Source Code (`lib/`)

| File/Directory | Purpose |
|----------------|---------|
| `main.dart` | Entry point (headless) |
| `veepa_channel.dart` | Platform channel bridge to Swift |
| `models/` | Data models (connection_state, discovered_device, paired_camera) |
| `services/` | Business logic (connection, discovery, frames, pairing) |
| `sdk/` | Veepa SDK Dart wrappers |
| `screens/` | QR provisioning screen |
| `widgets/` | Video view, QR widgets |

#### Key Services

| File | Purpose |
|------|---------|
| `veepa_connection_manager.dart` | Veepa SDK wrapper (~500 lines) |
| `veepa_discovery_service.dart` | LAN device discovery |
| `veepa_frame_handler.dart` | Video frame handling |
| `camera_pairing_manager.dart` | Camera pairing workflow |
| `camera_connection_detector.dart` | Connection state detection |
| `qr_image_generator_service.dart` | QR code generation |
| `wifi_qr_generator_service.dart` | WiFi config QR generation |

---

### Backend (`backend/`)

#### Application (`app/`)

| File | Purpose |
|------|---------|
| `__init__.py` | Package initialization |
| `main.py` | FastAPI app entry point |
| `config.py` | Environment configuration |

#### Routers (`app/routers/`)

| File | Purpose |
|------|---------|
| `health.py` | Health check endpoint |
| `token.py` | Gemini token generation |

#### Tests (`tests/`)

| File | Purpose |
|------|---------|
| `test_health.py` | Health endpoint tests |
| `test_token.py` | Token endpoint tests |
| `test_deployment.py` | Deployment verification |

---

### Documentation (`docs/`)

| Path | Purpose |
|------|---------|
| `architecture-reference/` | This documentation |
| `debugging/` | Troubleshooting guides |
| `stories/` | User stories for development |
| `brief.md` | Product brief |
| `prd.md` | Product requirements document |

---

### Configuration Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Claude Code project instructions |
| `README.md` | Project overview |
| `.gitignore` | Git ignore rules |
| `ios/SciSymbioLens/project.yml` | XcodeGen project configuration |
| `flutter_module/veepa_camera/pubspec.yaml` | Flutter dependencies |
| `backend/requirements.txt` | Python dependencies |
| `backend/pyproject.toml` | Python project configuration |

---

### Build & CI

| Path | Purpose |
|------|---------|
| `.github/workflows/` | GitHub Actions CI/CD |
| `ios/SciSymbioLens/Scripts/` | Build helper scripts |
| `.bmad-core/` | BMAD methodology files |
| `.ralph/` | RALPH automation scripts |
| `.claude/commands/` | Claude Code workflows |

---

## File Count Summary

| Component | Files | Lines (approx) |
|-----------|-------|----------------|
| iOS Source | ~80 | ~15,000 |
| iOS Tests | ~40 | ~5,000 |
| Flutter Module | ~20 | ~3,000 |
| Backend | ~10 | ~500 |
| Documentation | ~15 | ~2,000 |
| Configuration | ~10 | ~500 |
| **Total** | **~175** | **~26,000** |

---

*Last updated: January 2026*
