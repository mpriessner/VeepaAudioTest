# ExpTube Camera Control App - Technical Implementation Document

## For Grant Application Purposes

**Document Type:** Technical Specification & Implementation Plan
**Project:** ExpTube Camera Control Application
**Prepared for:** Grant Application Technical Review
**Date:** December 2025

---

## Executive Summary

This document outlines the technical implementation plan for a dedicated camera control application designed to integrate with the ExpTube platform—an AI-powered laboratory video documentation system. The application will enable researchers to record, annotate, and automatically upload experimental procedures for AI-driven analysis and knowledge extraction.

**Primary Objective:** Build a cross-platform camera application that streamlines laboratory video documentation with one-click recording, automatic cloud upload, and seamless integration with AI processing pipelines.

---

## 1. Project Overview

### 1.1 Problem Statement

Laboratory researchers currently face significant challenges in documenting experimental procedures:

1. **Fragmented Workflow:** Recording, file management, and upload are separate manual processes
2. **Lost Institutional Knowledge:** Experimental techniques are not systematically captured
3. **Training Gaps:** New researchers lack access to standardized procedural videos
4. **Metadata Disconnect:** Videos lack structured experiment identifiers and context

### 1.2 Proposed Solution

A purpose-built camera application that:

- Provides **one-click recording** with pre-configured laboratory-optimized settings
- Enables **automatic upload** to the ExpTube platform upon recording completion
- Supports **offline operation** with queued uploads when connectivity is restored
- Captures **rich metadata** (experiment IDs, tags, descriptions) during or after recording
- Integrates with **AI processing pipelines** for automatic transcription, analysis, and knowledge graph construction

### 1.3 Target Users

| User Type | Use Case |
|-----------|----------|
| Laboratory Researchers | Recording experimental procedures for documentation and AI analysis |
| Training Coordinators | Capturing gold-standard training videos |
| QC Personnel | Documenting compliance checks and quality verification |
| Research Students | Recording thesis work and learning from institutional video library |

---

## 2. Technical Architecture

### 2.1 System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CAMERA CONTROL APPLICATION                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────────────┐   │
│  │  CAMERA MODULE  │   │   RECORDING     │   │    UPLOAD MANAGER       │   │
│  │  ─────────────  │──▶│   CONTROLLER    │──▶│    ─────────────────    │   │
│  │  • Preview      │   │   ───────────   │   │    • Queue Management   │   │
│  │  • Settings     │   │   • Start/Stop  │   │    • Retry Logic        │   │
│  │  • Focus/Zoom   │   │   • Pause       │   │    • Progress Tracking  │   │
│  │  • Exposure     │   │   • Segmentation│   │    • Offline Support    │   │
│  └─────────────────┘   └─────────────────┘   └───────────┬─────────────┘   │
│                                                           │                  │
│  ┌─────────────────┐   ┌─────────────────┐               │                  │
│  │ METADATA EDITOR │   │ SETTINGS MGR    │               │                  │
│  │ ─────────────── │   │ ─────────────── │               │                  │
│  │ • Title/Desc    │   │ • API Keys      │               │                  │
│  │ • Tags          │   │ • Server URL    │               │                  │
│  │ • Experiment ID │   │ • Video Quality │               │                  │
│  │ • Video Type    │   │ • Upload Prefs  │               │                  │
│  └─────────────────┘   └─────────────────┘               │                  │
│                                                           │                  │
└───────────────────────────────────────────────────────────┼──────────────────┘
                                                            │
                                          HTTPS + Bearer Auth
                                                            │
                                                            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            EXPTUBE PLATFORM                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                    UPLOAD API (POST /api/upload)                        │ │
│  │  ────────────────────────────────────────────────────────────────────  │ │
│  │  • Authentication: Bearer Token (API Key)                              │ │
│  │  • Content-Type: multipart/form-data                                   │ │
│  │  • Max File Size: 500MB                                                │ │
│  │  • Rate Limit: 10 uploads/hour per user                                │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                       │
│                                      ▼                                       │
│  ┌──────────────────┐  ┌───────────────────┐  ┌─────────────────────────┐  │
│  │  CLOUD STORAGE   │─▶│  AI PROCESSING    │─▶│   KNOWLEDGE GRAPH       │  │
│  │  (Supabase)      │  │  PIPELINE         │  │   & SEMANTIC SEARCH     │  │
│  └──────────────────┘  └───────────────────┘  └─────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Component Breakdown

| Component | Responsibility | Key Technologies |
|-----------|---------------|------------------|
| **Camera Module** | Hardware interface, preview rendering, settings control | Platform camera APIs (AVFoundation/CameraX) |
| **Recording Controller** | State machine for recording lifecycle, file management | Local file system, video encoding |
| **Upload Manager** | Queue management, network handling, retry logic | HTTP client, background services |
| **Metadata Editor** | User input for video context and classification | Form validation, local storage |
| **Settings Manager** | Secure credential storage, user preferences | Keychain/Keystore, encrypted storage |

### 2.3 Data Flow

```
1. Recording Initiation
   └─▶ Camera Module activates (preview + recording)
       └─▶ Video encoded and saved to local storage

2. Recording Completion
   └─▶ User presented with metadata entry form (optional)
       └─▶ Video + metadata queued for upload

3. Upload Processing
   └─▶ Upload Manager checks network connectivity
       └─▶ POST /api/upload with multipart/form-data
           └─▶ ExpTube validates, stores, and initiates AI processing
               └─▶ App receives success callback
                   └─▶ User notified of completion
```

---

## 3. API Integration Specification

### 3.1 Authentication

The application authenticates with ExpTube using **Bearer Token Authentication**:

- **Header Format:** `Authorization: Bearer <API_KEY>`
- **Key Acquisition:** Generated via ExpTube admin panel
- **Key Scopes:** Must include `ingest` scope for upload permissions
- **Security:** Keys stored in platform-specific secure storage (Keychain/Keystore)

### 3.2 Upload Endpoint

```http
POST /api/upload
Content-Type: multipart/form-data
Authorization: Bearer <API_KEY>
```

### 3.3 Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `video` | File | **Yes** | Video file (MP4, MOV, AVI, WebM, MPEG) |
| `title` | String | No | Video title (default: "Untitled Video") |
| `description` | String | No | Video description |
| `tags` | String | No | Comma-separated tags for categorization |
| `experiment_id` | String | No | ELN experiment reference (max 100 chars) |
| `video_type` | String | No | Classification: experiment, qc_recording, training_standard, training_attempt |
| `enable_processing` | String | No | "true" to trigger AI analysis pipeline |
| `anonymize` | String | No | "true" to blur faces in video |
| `analysis_mode` | String | No | "chemistry" or "general" |
| `processing_tier` | String | No | "quick", "standard", or "thorough" |

### 3.4 File Constraints

| Constraint | Value |
|------------|-------|
| Maximum File Size | 500 MB |
| Supported MIME Types | video/mp4, video/quicktime, video/x-msvideo, video/webm, video/mpeg |
| Supported Extensions | .mp4, .mov, .avi, .webm, .mpeg, .mpg, .m4v |
| Recommended Codec | H.264 (AVC) |
| Recommended Resolution | 1080p (1920×1080) |
| Recommended Framerate | 30 fps |

### 3.5 Response Handling

**Success Response (201 Created):**
```json
{
  "success": true,
  "video": {
    "id": "uuid-v4",
    "title": "Experiment Recording",
    "status": "ready",
    "url": "https://storage.example.com/videos/...",
    "size": 45678912,
    "uploadedAt": "2025-12-23T10:30:00Z"
  },
  "message": "Video uploaded successfully"
}
```

**Error Handling:**

| Status | Code | Handling Strategy |
|--------|------|-------------------|
| 400 | MISSING_FILE, INVALID_FILE | Display user error, prompt re-recording |
| 401 | AUTH_FAILED | Prompt API key reconfiguration |
| 413 | FILE_TOO_LARGE | Auto-segment video and retry |
| 429 | RATE_LIMIT_EXCEEDED | Queue for delayed retry |
| 500 | UPLOAD_FAILED | Exponential backoff retry |

### 3.6 Status Polling

```http
GET /api/upload/status/{videoId}
Authorization: Bearer <API_KEY>
```

Returns processing status: `uploading → ready → processing → completed`

---

## 4. Core Features Specification

### 4.1 Camera Controls

| Control | Purpose | Implementation Priority |
|---------|---------|------------------------|
| **Auto/Manual Focus** | Ensure clarity on instruments and samples | High |
| **Exposure Control** | Adapt to variable lab lighting | High |
| **White Balance** | Correct for fluorescent/LED lighting | Medium |
| **Zoom (Digital/Optical)** | Capture close-up details | Medium |
| **Resolution Selection** | 720p / 1080p / 4K options | High |
| **Framerate Selection** | 24 / 30 / 60 fps | Medium |
| **Stabilization** | Reduce hand shake | Medium |

### 4.2 Recording Features

| Feature | Description |
|---------|-------------|
| **One-Button Recording** | Single tap to start/stop |
| **Pause/Resume** | Pause without creating separate file |
| **Timer Display** | Real-time recording duration |
| **Storage Indicator** | Remaining device storage |
| **Audio Level Meter** | Visual audio monitoring |
| **Auto-Segmentation** | Split at 400MB boundaries automatically |

### 4.3 Recording Presets

| Preset | Resolution | FPS | Focus | Use Case |
|--------|------------|-----|-------|----------|
| **Lab Standard** | 1080p | 30 | Auto | Default for most recordings |
| **Instrument Detail** | 1080p | 30 | Manual | Reading instruments/displays |
| **Quick Capture** | 720p | 30 | Auto | Smaller files, faster upload |
| **High Detail** | 4K | 30 | Auto | Maximum quality documentation |
| **Training** | 1080p | 30 | Auto | Optimized for clarity |

### 4.4 Upload Management

| Feature | Description |
|---------|-------------|
| **Automatic Upload** | Begin upload immediately upon recording stop |
| **Background Upload** | Continue recording while previous videos upload |
| **Offline Queue** | Store uploads when network unavailable |
| **Retry Logic** | Exponential backoff with 4 retry attempts |
| **Progress Tracking** | Real-time upload progress display |
| **Pause/Cancel** | User control over individual uploads |

### 4.5 Metadata Entry

| Field | Type | Purpose |
|-------|------|---------|
| Title | Text | Video name for search and display |
| Description | Text Area | Detailed procedure description |
| Experiment ID | Text | ELN/LIMS reference number |
| Tags | Chips/Text | Comma-separated categorization |
| Video Type | Radio | experiment, qc_recording, training_standard, training_attempt |
| Processing Options | Checkboxes | Enable AI processing, face anonymization |

---

## 5. Implementation Plan

### Phase 1: Core Recording Infrastructure

**Objectives:**
- Establish camera preview and basic controls
- Implement start/stop recording with local storage
- Build settings persistence layer

**Technical Deliverables:**
- Camera preview component with resolution/quality settings
- Recording state machine (idle → recording → stopped)
- Video file encoding and local storage
- Basic settings screen (resolution, quality, storage location)
- Recording timer display

**Key Technical Tasks:**
1. Platform camera permission handling (iOS Info.plist / Android Manifest)
2. Camera session management and lifecycle
3. Video encoder configuration (H.264, AAC audio)
4. Local file system integration
5. Settings persistence (UserDefaults / SharedPreferences)

---

### Phase 2: Upload Integration

**Objectives:**
- Implement secure API key management
- Build reliable upload infrastructure with queue management
- Handle network failures gracefully

**Technical Deliverables:**
- API key configuration and secure storage
- Multipart/form-data upload client
- Upload queue with local persistence
- Background upload service
- Network state monitoring
- Upload history display

**Key Technical Tasks:**
1. Secure credential storage (Keychain / EncryptedSharedPreferences)
2. HTTP client with progress callbacks
3. SQLite/Room/CoreData for queue persistence
4. Background service implementation (WorkManager / URLSession background)
5. Network reachability monitoring
6. Retry logic with exponential backoff

---

### Phase 3: Metadata & User Experience

**Objectives:**
- Enable rich metadata capture
- Polish user interface and experience
- Implement video type classification

**Technical Deliverables:**
- Pre/post recording metadata form
- Video type selector
- Experiment ID input with validation
- Tags input component
- AI processing options
- Thumbnail capture and preview

**Key Technical Tasks:**
1. Form validation and error handling
2. Video type dropdown/radio implementation
3. Tag input component (chips UI)
4. Thumbnail extraction from video
5. Processing tier selector
6. Metadata persistence for retry scenarios

---

### Phase 4: Advanced Features & Polish

**Objectives:**
- Professional camera controls
- Advanced recording features
- Status monitoring integration

**Technical Deliverables:**
- Manual focus and exposure controls
- Recording presets management
- Pause/resume functionality
- Auto-segmentation for large files
- Processing status polling
- Video library view

**Key Technical Tasks:**
1. Camera parameter adjustment APIs
2. Preset save/load functionality
3. Recording state machine extension (pause state)
4. File segmentation at size boundaries
5. Status polling service
6. Local video browser with sync status

---

## 6. Platform-Specific Implementation

### 6.1 iOS Implementation

**Framework:** AVFoundation + SwiftUI
**Minimum Version:** iOS 15.0
**Language:** Swift

**Key Components:**
| Component | Framework/Class |
|-----------|-----------------|
| Camera Session | AVCaptureSession, AVCaptureDevice |
| Video Recording | AVAssetWriter, AVCaptureVideoDataOutput |
| Background Upload | URLSession with background configuration |
| Secure Storage | Keychain Services |
| Local Database | CoreData or SwiftData |

**Required Permissions:**
```xml
NSCameraUsageDescription - Camera access for experiment recording
NSMicrophoneUsageDescription - Audio capture for narration
NSPhotoLibraryAddUsageDescription - Optional gallery export
```

### 6.2 Android Implementation

**Framework:** CameraX + Jetpack Compose
**Minimum SDK:** API 24 (Android 7.0)
**Language:** Kotlin

**Key Components:**
| Component | Library/Class |
|-----------|---------------|
| Camera Session | CameraX CameraProvider |
| Video Recording | VideoCapture use case |
| Background Upload | WorkManager |
| Secure Storage | EncryptedSharedPreferences, Android Keystore |
| Local Database | Room Persistence Library |
| HTTP Client | Retrofit + OkHttp |

**Required Permissions:**
```xml
android.permission.CAMERA
android.permission.RECORD_AUDIO
android.permission.INTERNET
android.permission.ACCESS_NETWORK_STATE
android.permission.FOREGROUND_SERVICE
```

### 6.3 Cross-Platform Alternative

**Framework:** React Native + Expo
**Target:** iOS + Android from single codebase

**Key Packages:**
| Functionality | Package |
|---------------|---------|
| Camera | expo-camera |
| File System | expo-file-system |
| Secure Storage | expo-secure-store |
| HTTP Client | axios |
| Queue Persistence | @react-native-async-storage/async-storage |
| Network State | @react-native-community/netinfo |
| Background Tasks | expo-background-fetch |

---

## 7. Video Technical Specifications

### 7.1 Encoding Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Video Codec | H.264 (AVC) | Universal compatibility, efficient compression |
| Container | MP4 | Broad platform support |
| Video Bitrate | 8-12 Mbps (1080p) | Quality/size balance |
| Audio Codec | AAC | Standard for MP4 containers |
| Audio Bitrate | 128 kbps | Clear speech capture |
| Sample Rate | 48 kHz | Video production standard |

### 7.2 File Size Projections

| Resolution | Duration | Approximate Size | Within Limit |
|------------|----------|------------------|--------------|
| 1080p @ 30fps | 5 minutes | ~375 MB | Yes |
| 1080p @ 30fps | 8 minutes | ~500 MB | Yes (at limit) |
| 1080p @ 30fps | 10 minutes | ~750 MB | Requires segmentation |
| 720p @ 30fps | 10 minutes | ~450 MB | Yes |
| 4K @ 30fps | 3 minutes | ~900 MB | Requires segmentation |

### 7.3 Segmentation Strategy

For recordings exceeding the 500MB limit:

1. **Auto-Segment Threshold:** 400 MB (buffer for encoding overhead)
2. **Segmentation Method:** Seamless file switching at keyframe boundaries
3. **Naming Convention:** `{title}_part1.mp4`, `{title}_part2.mp4`
4. **Upload Handling:** Each segment uploaded as separate video with linked metadata

---

## 8. Reliability & Error Handling

### 8.1 Upload Retry Strategy

```
Attempt 1: Immediate
    │
    ▼ Failure
Attempt 2: +30 seconds delay
    │
    ▼ Failure
Attempt 3: +2 minutes delay
    │
    ▼ Failure
Attempt 4: +10 minutes delay
    │
    ▼ Failure
Mark as Failed → User Notification → Manual Retry Available
```

### 8.2 Offline Support Workflow

1. **Detection:** Monitor network reachability continuously
2. **Queueing:** All uploads stored in persistent local database
3. **Monitoring:** Background service watches for connectivity restoration
4. **Resumption:** FIFO queue processing when network available
5. **Partial Upload:** Support for resumable uploads where server supports

### 8.3 Error Communication

| Error Scenario | User Message | Automatic Action |
|----------------|--------------|------------------|
| No Network | "Queued for upload when connected" | Add to offline queue |
| Auth Failure | "API key invalid - check settings" | Prompt settings |
| Rate Limited | "Upload limit reached - retry in X min" | Schedule delayed retry |
| File Too Large | "Video exceeds limit - splitting" | Auto-segment |
| Server Error | "Server error - retrying" | Exponential backoff |

---

## 9. Security Implementation

### 9.1 Credential Security

| Platform | Storage Method | Encryption |
|----------|----------------|------------|
| iOS | Keychain Services | Hardware-backed |
| Android | Android Keystore + EncryptedSharedPreferences | Hardware-backed |
| Desktop | OS Credential Manager / Electron safeStorage | OS-level encryption |

### 9.2 Data Protection Checklist

- API keys encrypted at rest using platform secure storage
- All network communication over HTTPS/TLS 1.3
- Video files stored in app-private directories
- No plaintext credential logging
- Credential clearing on logout/app uninstall
- Optional biometric authentication for app access

### 9.3 Network Security

- Certificate pinning for ExpTube API endpoints
- Request signing for upload integrity verification
- Timeout handling to prevent hanging connections
- No sensitive data in URL parameters

---

## 10. Testing Strategy

### 10.1 Unit Testing

| Component | Test Coverage |
|-----------|---------------|
| Upload Client | Mock API responses, error codes, retry logic |
| Queue Manager | Add/remove/persist/restore operations |
| Settings Manager | Secure storage read/write, default values |
| File Handler | Size validation, segmentation boundaries |
| Metadata Validator | Required fields, character limits, format validation |

### 10.2 Integration Testing

| Scenario | Validation |
|----------|------------|
| Full Upload Flow | Record → Metadata → Upload → Verify in ExpTube |
| Network Failure | Upload → Disconnect → Reconnect → Resume |
| Rate Limiting | Hit limit → Queue → Wait → Auto-retry |
| Large File Handling | 600MB file → Auto-segment → Upload both parts |
| Background Upload | Start upload → Switch apps → Return → Verify completion |

### 10.3 End-to-End Testing

| Test Case | Steps |
|-----------|-------|
| Happy Path | Launch → Record 1 min → Add metadata → Upload → Verify processing started |
| Offline Recording | Airplane mode → Record → Add metadata → Go online → Auto-upload |
| Long Recording | Record 15 min → Auto-segment → Upload queue → All parts successful |
| Settings Persistence | Configure API key → Kill app → Relaunch → Verify key retained |

---

## 11. Resource Requirements

### 11.1 Development Team

| Role | Responsibility | Effort |
|------|----------------|--------|
| Mobile Developer (iOS) | Native iOS implementation | Full |
| Mobile Developer (Android) | Native Android implementation | Full |
| Backend Integration | API integration, testing | Partial |
| UI/UX Designer | Interface design, usability | Partial |
| QA Engineer | Testing strategy, execution | Partial |

*Alternative: 1-2 cross-platform developers using React Native*

### 11.2 Infrastructure Requirements

| Resource | Purpose |
|----------|---------|
| Development Devices | iOS + Android physical devices for camera testing |
| CI/CD Pipeline | Automated builds, testing, deployment |
| Test ExpTube Instance | Isolated environment for integration testing |
| App Store Accounts | Apple Developer Program, Google Play Console |

### 11.3 Dependencies

| Dependency | Type | Notes |
|------------|------|-------|
| ExpTube Platform | External | Upload API, authentication system |
| Cloud Storage | External | Supabase storage for uploaded videos |
| AI Processing Pipeline | External | Optional video analysis |

---

## 12. Success Metrics

### 12.1 Technical Metrics

| Metric | Target |
|--------|--------|
| Upload Success Rate | >99% (with retries) |
| App Crash Rate | <0.1% of sessions |
| Recording Start Latency | <500ms from button press |
| Upload Speed | Within 10% of theoretical bandwidth |
| Offline Queue Recovery | 100% of queued items uploaded |

### 12.2 User Experience Metrics

| Metric | Target |
|--------|--------|
| Time to First Recording | <30 seconds from install |
| Metadata Entry Time | <60 seconds average |
| Upload Completion Notification | 100% delivery |

---

## 13. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Platform API Changes | Low | High | Abstract camera interfaces, monitor deprecation notices |
| Network Reliability | Medium | Medium | Robust retry logic, offline support |
| Storage Constraints | Medium | Medium | Clear storage indicators, auto-cleanup options |
| Large File Handling | Low | High | Auto-segmentation, compression options |
| Authentication Issues | Low | High | Clear error messaging, easy reconfiguration |

---

## 14. Conclusion

The ExpTube Camera Control App represents a focused solution to the challenges of laboratory video documentation. By combining professional camera controls, seamless cloud integration, and robust offline support, the application will enable researchers to capture and share experimental knowledge efficiently.

The phased implementation approach allows for:
1. **Early validation** of core recording functionality
2. **Incremental feature delivery** with user feedback
3. **Risk mitigation** through staged integration
4. **Quality assurance** at each phase

The technical architecture leverages proven platform technologies while maintaining flexibility for future enhancements including multi-camera support, real-time streaming, and advanced AI integration.

---

## Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | December 2025 | Technical Team | Initial document creation |

---

*This document provides complete technical specifications for implementing the ExpTube Camera Control Application. It is intended for grant application technical review and development team reference.*
