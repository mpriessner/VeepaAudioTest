# SciSymbioLens Architecture Reference

This folder contains comprehensive documentation of the SciSymbioLens codebase architecture, designed to help future developers and AI assistants understand the system's implementation details.

## Document Index

| Document | Description |
|----------|-------------|
| [project-structure.md](project-structure.md) | Complete folder and file breakdown |
| [ios-architecture.md](ios-architecture.md) | iOS app architecture (MVVM, SwiftUI) |
| [flutter-module.md](flutter-module.md) | Flutter module for Veepa camera integration |
| [camera-system.md](camera-system.md) | Multi-camera architecture (iPhone + Veepa) |
| [gemini-integration.md](gemini-integration.md) | Gemini AI integration for real-time video Q&A |
| [data-flow.md](data-flow.md) | Data flow patterns and user session workflows |
| [services-reference.md](services-reference.md) | Complete reference for all service classes |
| [viewmodels-reference.md](viewmodels-reference.md) | ViewModel layer documentation |
| [models-reference.md](models-reference.md) | Data model definitions |
| [veepa-sdk-reference.md](veepa-sdk-reference.md) | Veepa camera SDK reference |

---

## CRITICAL NOTES FOR AI AGENTS

### Flutter Build Workaround (MUST READ)

When modifying Flutter/Dart code in `flutter_module/veepa_camera/`, you **MUST** follow a specific build workflow:

```bash
# 1. Build Flutter frameworks
cd flutter_module/veepa_camera
flutter build ios-framework --output=build/ios/framework

# 2. Frameworks auto-sync on next Xcode build, OR manually sync:
cd ../../ios/SciSymbioLens
SRCROOT="$(pwd)" CONFIGURATION="Debug" ./Scripts/sync-flutter-frameworks.sh

# 3. Rebuild iOS app
```

**Why?** Flutter builds to one location, Xcode looks in another. Without this step, your Flutter changes will NOT appear in the iOS app.

**Full documentation**: [flutter-module.md](flutter-module.md#critical-flutter-build-workflow) and [Flutter-iOS Integration](../architecture/flutter-ios-integration.md)

### Simulator Limitation

The Veepa SDK (`libVSTC.a`) only supports **physical iOS devices**. Simulator builds will fail for Veepa-related code.

---

## Project Overview

**SciSymbioLens** is an iOS camera application with Gemini Live API integration for real-time multimodal video Q&A. The app supports both the built-in iPhone camera and external Wi-Fi cameras (Veepa) for scientific observation and AI-assisted analysis.

### Key Features

1. **Multi-Camera Support**
   - Built-in iPhone camera (AVFoundation)
   - External Veepa Wi-Fi camera (via Flutter SDK)

2. **Real-Time AI Analysis**
   - Gemini Live API integration for video streaming
   - Chat interface for Q&A about video content
   - Voice input/output support

3. **Media Management**
   - Photo and video capture
   - Gallery with upload status tracking
   - Cloud storage (Supabase)

4. **Conversation History**
   - Persistent chat history
   - Support for text, image, and video messages

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      SwiftUI Views                          │
│  (ContentView, CameraView, ChatView, GalleryView, etc.)    │
└────────────┬────────────────────────────────────┬───────────┘
             │                                    │
             ▼                                    ▼
    ┌────────────────────┐          ┌────────────────────┐
    │   ViewModels       │          │  Published Props   │
    │  (ObservableObj)   │◄─────────│  (Combine)         │
    │                    │  Binding │                    │
    │ • CameraViewModel  │          └────────────────────┘
    │ • ChatViewModel    │
    │ • GalleryViewModel │
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────┐
    │     Services       │
    │  (Business Logic)  │
    │                    │
    │ • CameraManager    │
    │ • GeminiServices   │
    │ • ChatServices     │
    │ • StorageServices  │
    └────────┬───────────┘
             │
             ▼
    ┌────────────────────────────────────┐
    │    System Frameworks & APIs         │
    │ • AVFoundation (Camera)             │
    │ • URLSession (Network)              │
    │ • Gemini SDK (AI)                   │
    │ • Supabase (Cloud)                  │
    │ • Flutter (Veepa SDK bridge)        │
    └────────────────────────────────────┘
```

## Tech Stack

### iOS App
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (iOS 17+)
- **Camera**: AVFoundation
- **Architecture**: MVVM with Combine
- **AI**: Google Generative AI SDK
- **Storage**: Supabase
- **Testing**: XCTest, XCUITest

### Flutter Module
- **Purpose**: Veepa camera SDK integration
- **Communication**: Platform Channels (Method/Event)
- **Dependencies**: Veepa SDK, network_info_plus, shared_preferences

### Backend (Token Service)
- **Framework**: FastAPI (Python)
- **Purpose**: Secure Gemini API key management

## Component Dependencies

```
                    ┌─────────────────┐
                    │  SwiftUI Views  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   ViewModels    │
                    │ (Combine bound) │
                    └────────┬────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
     ┌────▼────┐      ┌─────▼──────┐    ┌──────▼──────┐
     │ Camera  │      │  Gemini    │    │   Voice     │
     │ Services│      │  Services  │    │  Services   │
     └────┬────┘      └─────┬──────┘    └──────┬──────┘
          │                 │                  │
          │       ┌─────────┴──────────┐       │
          │       │                    │       │
     ┌────▼────┐  │          ┌─────────▼──────▼──────┐
     │ Flutter │  │          │  Network & Storage    │
     │ Engine  │  │          │  • URLSession (APIs)  │
     │ Manager │  │          │  • Supabase (Cloud)   │
     └────┬────┘  │          │  • Keychain (Keys)    │
          │       │          └────────────────────────┘
          │  ┌────▼──────────┐
          │  │ Veepa SDK    │
          └─►│ (Native iOS) │
             └──────────────┘
```

## Key Design Decisions

1. **Protocol-Based Camera Abstraction**: `CameraSourceProtocol` enables seamless switching between local and external cameras.

2. **Flutter for Veepa Integration**: The Veepa SDK is primarily Flutter-based, so we embed a Flutter engine and communicate via platform channels.

3. **Streaming Architecture**: Real-time video streaming to Gemini uses WebSocket connections with frame rate control and compression.

4. **Offline-First Upload**: Failed uploads are persisted and retried automatically.

5. **Secure Key Storage**: API keys stored in iOS Keychain, never in app binary.

## Known Limitations & Future Improvements

### Current Limitations
- Veepa camera auto-reconnect has a ~3 minute timeout issue (see `docs/debugging/`)
- iOS 17+ required (no backwards compatibility)
- Single conversation context (no multiple conversations)

### Potential Improvements
- Multiple conversation support
- Background video streaming
- iPad optimization
- Batch upload for multiple files
- Offline AI analysis with on-device models

## Related Documentation

- [Product Brief](../brief.md) - Project vision and scope
- [PRD](../prd.md) - Detailed requirements
- [Debugging Guides](../debugging/) - Troubleshooting documentation
- [Veepa Official Documentation](/Users/mpriessner/windsurf_repos/VeepaCameraPOC/docs/official_documentation/) - External reference

---

*Last updated: January 2026*
