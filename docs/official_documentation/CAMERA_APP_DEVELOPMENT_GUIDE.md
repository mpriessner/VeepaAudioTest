# ExpTube Camera Control App Development Guide

## Technical Specification for AI Agent Implementation

**Document Purpose:** Development Guide for Camera Control App AI Agent
**Version:** 1.0
**Last Updated:** December 2025
**Target Platforms:** iOS, Android, Desktop (Windows/Mac/Linux)

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [System Integration Architecture](#2-system-integration-architecture)
3. [ExpTube Upload API Specification](#3-exptube-upload-api-specification)
4. [Camera Control Requirements](#4-camera-control-requirements)
5. [Implementation Plan](#5-implementation-plan)
6. [Platform-Specific Considerations](#6-platform-specific-considerations)
7. [User Interface Requirements](#7-user-interface-requirements)
8. [Technical Specifications](#8-technical-specifications)
9. [Error Handling & Reliability](#9-error-handling--reliability)
10. [Security Requirements](#10-security-requirements)
11. [Testing Strategy](#11-testing-strategy)
12. [Recommended Technology Stack](#12-recommended-technology-stack)

---

## 1. Project Overview

### 1.1 Purpose

Build a dedicated camera control application that enables laboratory researchers to:
1. **Record** experimental procedures with controlled camera settings
2. **Capture** high-quality video optimized for AI analysis
3. **Upload** recordings automatically to ExpTube platform
4. **Monitor** upload and processing status
5. **Tag** videos with metadata during or after recording

### 1.2 Key Value Propositions

| Feature | Benefit |
|---------|---------|
| **One-Click Recording** | Start recording with pre-configured optimal settings |
| **Auto-Upload** | Videos automatically upload when recording ends |
| **Background Processing** | Continue recording while previous videos upload |
| **Offline Support** | Queue uploads when network is unavailable |
| **Metadata Entry** | Add experiment details before/during/after recording |
| **Camera Controls** | Professional recording settings for lab environments |

### 1.3 Target Users

- Laboratory researchers recording experiments
- Training coordinators capturing standard procedures
- QC personnel documenting compliance checks
- Research students recording thesis work

### 1.4 Integration Target

The app integrates exclusively with **ExpTube** - the AI-powered laboratory video documentation platform (see `OVERVIEW.md` for full platform details).

---

## 2. System Integration Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Camera Control App                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐  │
│  │  Camera Module   │    │  Recording       │    │  Upload Manager  │  │
│  │  ──────────────  │───▶│  Controller      │───▶│  ──────────────  │  │
│  │  - Preview       │    │  ──────────────  │    │  - Queue Mgmt    │  │
│  │  - Settings      │    │  - Start/Stop    │    │  - Retry Logic   │  │
│  │  - Focus/Zoom    │    │  - Pause/Resume  │    │  - Progress      │  │
│  │  - Exposure      │    │  - Segment       │    │  - Status        │  │
│  └──────────────────┘    └──────────────────┘    └────────┬─────────┘  │
│                                                            │            │
│  ┌──────────────────┐    ┌──────────────────┐              │            │
│  │  Metadata        │    │  Settings        │              │            │
│  │  Editor          │    │  Manager         │              │            │
│  │  ──────────────  │    │  ──────────────  │              │            │
│  │  - Title/Desc    │    │  - API Keys      │              │            │
│  │  - Tags          │    │  - Server URL    │              │            │
│  │  - Experiment ID │    │  - Video Quality │              │            │
│  │  - Video Type    │    │  - Upload Prefs  │              │            │
│  └──────────────────┘    └──────────────────┘              │            │
│                                                            │            │
└────────────────────────────────────────────────────────────┼────────────┘
                                                             │
                                                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         ExpTube Platform                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                      Upload API (POST /api/upload)                │   │
│  │  ────────────────────────────────────────────────────────────    │   │
│  │  Authentication: Bearer Token (API Key)                          │   │
│  │  Content-Type: multipart/form-data                               │   │
│  │  Max File Size: 500MB                                            │   │
│  │  Rate Limit: 10 uploads/hour                                     │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                     │                                    │
│                                     ▼                                    │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐   │
│  │  Supabase        │    │  AI Processing   │    │  Knowledge       │   │
│  │  Storage         │───▶│  Pipeline        │───▶│  Graph           │   │
│  └──────────────────┘    └──────────────────┘    └──────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow

```
1. User starts recording
   └─▶ Camera Module captures video
       └─▶ Video saved to local storage
           └─▶ User stops recording
               └─▶ Metadata form presented (optional)
                   └─▶ Upload Manager queues upload
                       └─▶ POST /api/upload (multipart/form-data)
                           └─▶ ExpTube stores & processes video
                               └─▶ Status callback (optional WebSocket)
                                   └─▶ App displays completion notification
```

---

## 3. ExpTube Upload API Specification

### 3.1 Authentication

**Method**: Bearer Token Authentication

**Header**: `Authorization: Bearer YOUR_API_KEY`

**API Key Acquisition**:
- Generated via ExpTube admin panel or SQL command
- Keys have scopes (must include `ingest`)
- Keys can have expiration dates
- Keys are tied to specific users

### 3.2 Upload Endpoint

```http
POST /api/upload
Content-Type: multipart/form-data
Authorization: Bearer YOUR_API_KEY
```

### 3.3 Request Parameters

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `video` | File | **Yes** | Video file (MP4, MOV, AVI, WebM, MPEG) |
| `title` | String | No | Video title (default: "Untitled Video") |
| `description` | String | No | Video description |
| `tags` | String | No | Comma-separated tags |
| `thumbnail` | File | No | JPEG thumbnail image |
| `experiment_id` | String | No | ELN experiment reference (max 100 chars) |
| `is_public` | String | No | "true" or "false" (default: false) |
| `enable_processing` | String | No | "true" to trigger AI processing |
| `video_type` | String | No | Video type (see below) |
| `anonymize` | String | No | "true" to blur faces |
| `analysis_mode` | String | No | "chemistry" or "general" |
| `processing_tier` | String | No | "quick", "standard", or "thorough" |
| `gemini_model` | String | No | AI model selection |
| `duration_seconds` | String | No | Pre-calculated duration (optional) |

**Video Type Options**:
- `experiment` - Standard experiment recording (default)
- `qc_recording` - Quality control verification
- `training_standard` - Gold-standard training video
- `training_attempt` - Trainee attempt video

### 3.4 File Requirements

| Requirement | Value |
|-------------|-------|
| **Maximum Size** | 500 MB |
| **Allowed MIME Types** | video/mp4, video/quicktime, video/x-msvideo, video/webm, video/mpeg |
| **Allowed Extensions** | .mp4, .mov, .avi, .webm, .mpeg, .mpg, .m4v |
| **Recommended Codec** | H.264 (best compatibility) |
| **Recommended Resolution** | 1080p (1920x1080) |
| **Recommended Framerate** | 30 fps |

### 3.5 Success Response (201 Created)

```json
{
  "success": true,
  "video": {
    "id": "469943b8-c426-43d2-b6e0-4a3a08d995c5",
    "title": "Chemistry Lab Experiment",
    "status": "ready",
    "url": "https://example.supabase.co/storage/v1/object/public/raw-videos/...",
    "thumbnail_url": "https://example.supabase.co/storage/v1/object/public/thumbnails/...",
    "size": 45678912,
    "type": "video/mp4",
    "uploadedAt": "2025-10-21T19:23:45.123Z",
    "is_public": false,
    "duration_seconds": 187
  },
  "message": "Video uploaded successfully"
}
```

### 3.6 Error Responses

| Status | Code | Description |
|--------|------|-------------|
| 400 | `MISSING_FILE` | No video file provided |
| 400 | `INVALID_FILE` | Invalid file format |
| 400 | `INVALID_FILE_TYPE` | Unsupported MIME type |
| 400 | `INVALID_FORMAT` | Not multipart/form-data |
| 401 | `AUTH_FAILED` | Invalid or missing API key |
| 413 | `FILE_TOO_LARGE` | File exceeds 500MB |
| 429 | `RATE_LIMIT_EXCEEDED` | Too many uploads (10/hour) |
| 500 | `UPLOAD_FAILED` | Storage error |
| 500 | `DB_INSERT_FAILED` | Database error |
| 500 | `INTERNAL_ERROR` | Unexpected error |

### 3.7 Status Check Endpoint

```http
GET /api/upload/status/{videoId}
Authorization: Bearer YOUR_API_KEY
```

**Response**:
```json
{
  "success": true,
  "data": {
    "videoId": "469943b8-c426-43d2-b6e0-4a3a08d995c5",
    "title": "Chemistry Lab Experiment",
    "status": "processing",
    "processing": {
      "status": "running",
      "progress": 45,
      "currentStep": "Pass 4: Video Summarization"
    }
  }
}
```

**Status Values**:
- `uploading` - File being uploaded
- `ready` - Upload complete, awaiting processing
- `processing` - AI pipeline running
- `completed` - All processing done
- `failed` - Error occurred

### 3.8 Rate Limits

| Endpoint | Limit | Window |
|----------|-------|--------|
| `POST /api/upload` | 10 requests | 1 hour |
| `GET /api/upload/status/*` | Unlimited | - |

---

## 4. Camera Control Requirements

### 4.1 Essential Camera Controls

| Control | Purpose | Priority |
|---------|---------|----------|
| **Focus** | Manual/Auto focus for instrument readings | High |
| **Exposure** | Adjust for lab lighting conditions | High |
| **White Balance** | Correct for fluorescent/LED lighting | Medium |
| **Zoom** | Capture close-up details | Medium |
| **Resolution** | 720p/1080p/4K selection | High |
| **Framerate** | 24/30/60 fps selection | Medium |
| **Stabilization** | Reduce hand shake | Medium |
| **Flash/Light** | Toggle device light for dark areas | Low |

### 4.2 Recording Features

| Feature | Description | Priority |
|---------|-------------|----------|
| **Start/Stop** | Single button recording control | High |
| **Pause/Resume** | Pause without creating new file | High |
| **Timer Display** | Show recording duration | High |
| **Storage Indicator** | Show remaining storage space | High |
| **Audio Levels** | Visual audio level meter | Medium |
| **Grid Overlay** | Rule of thirds composition guide | Low |
| **Timestamp Overlay** | Burn timestamp into video | Medium |

### 4.3 Video Segmentation

**Purpose**: Handle long recordings (lab experiments can be 30+ minutes)

**Options**:
1. **Single File** - Record entire session as one file (up to 500MB)
2. **Auto-Segment** - Split at 500MB boundaries automatically
3. **Manual Segment** - User triggers segment break (creates separate videos)

**Recommendation**: Auto-segment at 400MB with seamless continuation

### 4.4 Presets

Pre-configured settings for common scenarios:

| Preset | Resolution | FPS | Focus | Notes |
|--------|------------|-----|-------|-------|
| **Lab Standard** | 1080p | 30 | Auto | Default for most recordings |
| **Instrument Detail** | 1080p | 30 | Manual | For reading instruments |
| **Quick Capture** | 720p | 30 | Auto | Smaller files, faster upload |
| **High Detail** | 4K | 30 | Auto | Maximum quality |
| **Training** | 1080p | 30 | Auto | Optimized for clarity |

---

## 5. Implementation Plan

### 5.1 Phase 1: Core Recording (Week 1-2)

**Deliverables**:
- [ ] Camera preview with basic controls
- [ ] Start/Stop recording functionality
- [ ] Local video storage
- [ ] Basic settings screen (resolution, quality)
- [ ] Recording timer display

**Technical Tasks**:
1. Set up project with camera permissions
2. Implement camera preview component
3. Create recording state machine
4. Implement video file saving
5. Build settings storage (local preferences)

### 5.2 Phase 2: Upload Integration (Week 3-4)

**Deliverables**:
- [ ] API key configuration screen
- [ ] Upload manager with queue
- [ ] Upload progress display
- [ ] Retry logic for failed uploads
- [ ] Offline queue support

**Technical Tasks**:
1. Implement secure API key storage
2. Build multipart/form-data upload client
3. Create upload queue with persistence
4. Implement background upload service
5. Handle network state changes
6. Build upload history screen

### 5.3 Phase 3: Metadata & Polish (Week 5-6)

**Deliverables**:
- [ ] Pre/post recording metadata form
- [ ] Video type selection
- [ ] Experiment ID entry
- [ ] Tags input
- [ ] Processing options selection

**Technical Tasks**:
1. Build metadata form UI
2. Implement form validation
3. Add video type selector
4. Create tag input component
5. Add processing tier selector
6. Implement thumbnail capture

### 5.4 Phase 4: Advanced Features (Week 7-8)

**Deliverables**:
- [ ] Camera presets
- [ ] Manual focus/exposure controls
- [ ] Recording pause/resume
- [ ] Auto-segmentation
- [ ] Status polling for uploaded videos

**Technical Tasks**:
1. Implement camera parameter controls
2. Build preset management
3. Add pause/resume to recording state machine
4. Implement file segmentation logic
5. Create status polling service
6. Build video library view

---

## 6. Platform-Specific Considerations

### 6.1 iOS (Swift/SwiftUI)

**Framework**: AVFoundation

**Key Classes**:
- `AVCaptureSession` - Camera session management
- `AVCaptureDevice` - Camera hardware access
- `AVCaptureVideoDataOutput` - Frame processing
- `AVAssetWriter` - Video file writing
- `URLSession` - Network uploads

**Permissions Required**:
```xml
<key>NSCameraUsageDescription</key>
<string>ExpTube Camera needs camera access to record experiments</string>
<key>NSMicrophoneUsageDescription</key>
<string>ExpTube Camera needs microphone access to record audio</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>ExpTube Camera saves recordings to your library</string>
```

**iOS-Specific Features**:
- Background upload with `URLSession` background configuration
- iCloud Keychain for API key storage
- Control Center recording indicator
- Picture-in-Picture for preview while using other apps

### 6.2 Android (Kotlin/Jetpack Compose)

**Framework**: CameraX (recommended) or Camera2

**Key Classes**:
- `CameraProvider` - Camera lifecycle management
- `ImageCapture` - Still image capture
- `VideoCapture` - Video recording
- `WorkManager` - Background upload queue
- `EncryptedSharedPreferences` - Secure key storage

**Permissions Required**:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

**Android-Specific Features**:
- WorkManager for reliable background uploads
- Foreground service for long recordings
- Android Keystore for API key encryption
- MediaStore for video gallery integration

### 6.3 Cross-Platform (React Native / Flutter)

**React Native**:
- `react-native-camera` or `expo-camera`
- `react-native-video` for playback
- `react-native-fs` for file system
- `react-native-background-upload` for uploads

**Flutter**:
- `camera` package for recording
- `video_player` for playback
- `path_provider` for file storage
- `dio` for uploads with progress
- `workmanager` for background tasks

### 6.4 Desktop (Electron)

**Framework**: Electron with Web APIs

**Key Technologies**:
- `navigator.mediaDevices.getUserMedia()` - Camera access
- `MediaRecorder` API - Video recording
- `IndexedDB` - Local queue storage
- `node:fs` - File system access
- `axios` or `fetch` - HTTP uploads

**Platform Integration**:
- System tray icon for background recording
- Native notifications
- File drag-and-drop from video library
- Global keyboard shortcuts

---

## 7. User Interface Requirements

### 7.1 Main Recording Screen

```
┌────────────────────────────────────────────────────┐
│ ┌────────────────────────────────────────────────┐ │
│ │                                                │ │
│ │                                                │ │
│ │              CAMERA PREVIEW                    │ │
│ │              (Full Screen)                     │ │
│ │                                                │ │
│ │                                                │ │
│ └────────────────────────────────────────────────┘ │
│                                                    │
│  [Focus]  [Exposure]  [Zoom]        00:00:00      │
│                                                    │
│  ┌──────────────────────────────────────────────┐ │
│  │         ◉  RECORD / ■ STOP                    │ │
│  └──────────────────────────────────────────────┘ │
│                                                    │
│  [Settings]              [Library]    [Uploads]  │
└────────────────────────────────────────────────────┘
```

### 7.2 Metadata Entry Screen

```
┌────────────────────────────────────────────────────┐
│  ← Back            Video Details           Upload │
├────────────────────────────────────────────────────┤
│                                                    │
│  [   Thumbnail Preview   ]                         │
│                                                    │
│  Title *                                           │
│  ┌────────────────────────────────────────────────┐│
│  │ Synthesis of Compound X                        ││
│  └────────────────────────────────────────────────┘│
│                                                    │
│  Description                                       │
│  ┌────────────────────────────────────────────────┐│
│  │ Recrystallization procedure for...            ││
│  └────────────────────────────────────────────────┘│
│                                                    │
│  Experiment ID (ELN Reference)                    │
│  ┌────────────────────────────────────────────────┐│
│  │ EXP-2025-0142                                  ││
│  └────────────────────────────────────────────────┘│
│                                                    │
│  Tags (comma-separated)                            │
│  ┌────────────────────────────────────────────────┐│
│  │ synthesis, recrystallization, organic          ││
│  └────────────────────────────────────────────────┘│
│                                                    │
│  Video Type                                        │
│  ○ Experiment  ○ QC Recording  ○ Training Standard │
│                                                    │
│  Processing Options                                │
│  ☑ Enable AI Processing                           │
│  ☐ Anonymize Faces                                │
│  Tier: [Standard ▼]                               │
│                                                    │
│  ┌────────────────────────────────────────────────┐│
│  │              UPLOAD NOW                        ││
│  └────────────────────────────────────────────────┘│
│                                                    │
│  ┌────────────────────────────────────────────────┐│
│  │            Save for Later                      ││
│  └────────────────────────────────────────────────┘│
│                                                    │
└────────────────────────────────────────────────────┘
```

### 7.3 Upload Queue Screen

```
┌────────────────────────────────────────────────────┐
│  ← Back              Uploads                       │
├────────────────────────────────────────────────────┤
│                                                    │
│  In Progress                                       │
│  ┌──────────────────────────────────────────────┐ │
│  │ 🎬 Synthesis of Compound X                    │ │
│  │ ████████████░░░░░░░░░ 67%    45 MB / 67 MB   │ │
│  │ [Pause] [Cancel]                              │ │
│  └──────────────────────────────────────────────┘ │
│                                                    │
│  Queued (2)                                        │
│  ┌──────────────────────────────────────────────┐ │
│  │ 🎬 HPLC Calibration                          │ │
│  │ Waiting...                           32 MB   │ │
│  └──────────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────────┐ │
│  │ 🎬 Lab Tour                                  │ │
│  │ Waiting...                           89 MB   │ │
│  └──────────────────────────────────────────────┘ │
│                                                    │
│  Completed (12)                           [Clear] │
│  ┌──────────────────────────────────────────────┐ │
│  │ ✅ NMR Analysis              Dec 20, 2:34 PM │ │
│  │ ✅ Titration Demo            Dec 20, 1:15 PM │ │
│  │ ⚠️ Failed - Network Error   Dec 19, 4:45 PM │ │
│  │   [Retry]                                     │ │
│  └──────────────────────────────────────────────┘ │
│                                                    │
└────────────────────────────────────────────────────┘
```

### 7.4 Settings Screen

```
┌────────────────────────────────────────────────────┐
│  ← Back              Settings                      │
├────────────────────────────────────────────────────┤
│                                                    │
│  ACCOUNT                                           │
│  ──────────────────────────────────────────────── │
│  ExpTube Server                                    │
│  https://exptube.example.com                    > │
│                                                    │
│  API Key                                           │
│  ●●●●●●●●●●●●●●●●                    [Edit] [Test] │
│                                                    │
│  RECORDING                                         │
│  ──────────────────────────────────────────────── │
│  Default Quality                                   │
│  1080p (Recommended)                            > │
│                                                    │
│  Default Video Type                                │
│  Experiment                                      > │
│                                                    │
│  Auto-Upload After Recording                       │
│  [ON ─────●]                                       │
│                                                    │
│  UPLOAD                                            │
│  ──────────────────────────────────────────────── │
│  Upload on WiFi Only                               │
│  [●───── OFF]                                      │
│                                                    │
│  Retry Failed Uploads Automatically                │
│  [ON ─────●]                                       │
│                                                    │
│  STORAGE                                           │
│  ──────────────────────────────────────────────── │
│  Delete After Upload                               │
│  [●───── OFF]                                      │
│                                                    │
│  Storage Used: 2.3 GB                              │
│  [Clear All Local Videos]                          │
│                                                    │
│  ABOUT                                             │
│  ──────────────────────────────────────────────── │
│  Version 1.0.0                                     │
│  [Privacy Policy]  [Terms of Service]              │
│                                                    │
└────────────────────────────────────────────────────┘
```

---

## 8. Technical Specifications

### 8.1 Video Encoding

| Parameter | Recommended Value | Notes |
|-----------|-------------------|-------|
| Codec | H.264 (AVC) | Best compatibility with ExpTube |
| Container | MP4 | Universal support |
| Bitrate | 8-12 Mbps (1080p) | Balance of quality/size |
| Audio Codec | AAC | Standard for MP4 |
| Audio Bitrate | 128 kbps | Clear speech capture |
| Sample Rate | 48 kHz | Standard for video |

### 8.2 File Size Estimation

| Resolution | Duration | Approx. Size | Fits in Limit? |
|------------|----------|--------------|----------------|
| 1080p | 5 min | ~375 MB | ✅ Yes |
| 1080p | 10 min | ~750 MB | ❌ Segment |
| 720p | 10 min | ~450 MB | ✅ Yes |
| 4K | 5 min | ~1.5 GB | ❌ Segment |

### 8.3 Network Requirements

| Scenario | Upload Time (500 MB) |
|----------|---------------------|
| WiFi (50 Mbps) | ~80 seconds |
| WiFi (20 Mbps) | ~200 seconds |
| 4G LTE (20 Mbps) | ~200 seconds |
| 4G (5 Mbps) | ~800 seconds |

### 8.4 Local Storage

**Minimum Requirements**:
- 1 GB free space for app + cache
- Additional space equal to 2x longest expected recording

**Storage Strategy**:
1. Record to temp directory
2. Move to app documents after recording
3. Delete after confirmed upload (optional)
4. Queue management persisted to database

---

## 9. Error Handling & Reliability

### 9.1 Upload Retry Strategy

```
Initial Upload Attempt
        │
        ▼
    Success? ──Yes──▶ Done (Mark Complete)
        │
       No
        │
        ▼
  Retry #1 (Immediate)
        │
        ▼
    Success? ──Yes──▶ Done
        │
       No
        │
        ▼
  Retry #2 (After 30 seconds)
        │
        ▼
    Success? ──Yes──▶ Done
        │
       No
        │
        ▼
  Retry #3 (After 2 minutes)
        │
        ▼
    Success? ──Yes──▶ Done
        │
       No
        │
        ▼
  Retry #4 (After 10 minutes)
        │
        ▼
    Success? ──Yes──▶ Done
        │
       No
        │
        ▼
  Mark as Failed (Notify User)
  [Manual Retry Available]
```

### 9.2 Error Messages

| Error Code | User Message | Action |
|------------|--------------|--------|
| `AUTH_FAILED` | "API key invalid. Please check settings." | Open settings |
| `RATE_LIMIT_EXCEEDED` | "Upload limit reached. Retry in X minutes." | Queue for later |
| `FILE_TOO_LARGE` | "Video too large. Split into segments." | Offer segmentation |
| `NETWORK_ERROR` | "No internet connection. Queued for later." | Add to offline queue |
| `SERVER_ERROR` | "Server error. Will retry automatically." | Schedule retry |

### 9.3 Offline Support

**Behavior**:
1. Detect offline state via network reachability
2. Queue all uploads to local database
3. Monitor for connectivity changes
4. Resume uploads when online
5. Maintain order (FIFO)
6. Handle partial uploads (resume from last byte if supported)

---

## 10. Security Requirements

### 10.1 API Key Storage

| Platform | Secure Storage Method |
|----------|----------------------|
| iOS | Keychain Services |
| Android | EncryptedSharedPreferences / Keystore |
| Desktop | OS Credential Manager / Electron safeStorage |

### 10.2 Data Protection

- [ ] Encrypt API key at rest
- [ ] Never log API key in plaintext
- [ ] Use HTTPS for all API communications
- [ ] Clear credentials on logout
- [ ] Implement biometric lock option (optional)

### 10.3 Video Privacy

- [ ] Store videos in app-private directory
- [ ] Don't expose videos to system media gallery (optional)
- [ ] Secure delete option (overwrite before delete)
- [ ] No analytics on video content

---

## 11. Testing Strategy

### 11.1 Unit Tests

| Component | Tests |
|-----------|-------|
| Upload Client | Mock API responses, retry logic |
| Queue Manager | Add/remove/persist/restore |
| Settings Manager | Save/load API key, preferences |
| File Handler | Size validation, segmentation |

### 11.2 Integration Tests

| Scenario | Test |
|----------|------|
| Full Upload | Record → Metadata → Upload → Success |
| Network Failure | Upload → Disconnect → Reconnect → Resume |
| Rate Limit | Hit limit → Queue → Wait → Retry |
| Large File | 600MB file → Auto-segment → Upload both |

### 11.3 End-to-End Tests

| Test | Steps |
|------|-------|
| Happy Path | Launch → Record 1 min → Add title → Upload → Verify in ExpTube |
| Offline | Airplane mode → Record → Queue → Online → Auto-upload |
| Background | Record → Switch apps → Return → Verify recording continued |

---

## 12. Recommended Technology Stack

### 12.1 Cross-Platform (Recommended for Speed)

**Framework**: React Native with Expo

**Packages**:
```json
{
  "expo-camera": "Camera preview and recording",
  "expo-media-library": "Save to gallery",
  "expo-file-system": "File operations",
  "expo-secure-store": "API key storage",
  "axios": "HTTP client with progress",
  "@react-native-async-storage/async-storage": "Queue persistence",
  "@react-native-community/netinfo": "Network state",
  "react-native-background-fetch": "Background sync"
}
```

**Pros**:
- Single codebase for iOS + Android
- Fast development with Expo
- Good camera support
- Active community

**Cons**:
- Slightly less native performance
- Some advanced camera features require ejecting

### 12.2 Native iOS (Best iOS Experience)

**Language**: Swift
**UI Framework**: SwiftUI
**Minimum iOS**: 15.0

**Key Frameworks**:
- AVFoundation (camera/recording)
- URLSession (uploads)
- CoreData (queue persistence)
- KeychainAccess (API key)
- Combine (reactive patterns)

### 12.3 Native Android (Best Android Experience)

**Language**: Kotlin
**UI Framework**: Jetpack Compose
**Minimum SDK**: 24 (Android 7.0)

**Key Libraries**:
- CameraX (camera/recording)
- Retrofit + OkHttp (uploads)
- Room (queue persistence)
- WorkManager (background uploads)
- DataStore (preferences)

### 12.4 Desktop (Electron)

**Framework**: Electron + React

**Key Packages**:
```json
{
  "electron": "Desktop framework",
  "react": "UI library",
  "webcamjs": "Camera access (alternative: native MediaRecorder)",
  "axios": "HTTP uploads",
  "better-sqlite3": "Local queue database",
  "keytar": "Secure credential storage"
}
```

---

## Appendix A: Sample Upload Code

### JavaScript/TypeScript (React Native / Web)

```typescript
interface UploadOptions {
  file: File | Blob;
  title: string;
  description?: string;
  tags?: string;
  experimentId?: string;
  videoType?: 'experiment' | 'qc_recording' | 'training_standard' | 'training_attempt';
  enableProcessing?: boolean;
  onProgress?: (progress: number) => void;
}

async function uploadToExpTube(options: UploadOptions): Promise<UploadResult> {
  const {
    file,
    title,
    description = '',
    tags = '',
    experimentId,
    videoType = 'experiment',
    enableProcessing = true,
    onProgress
  } = options;

  const formData = new FormData();
  formData.append('video', file);
  formData.append('title', title);
  formData.append('description', description);
  formData.append('tags', tags);
  formData.append('video_type', videoType);
  formData.append('enable_processing', String(enableProcessing));

  if (experimentId) {
    formData.append('experiment_id', experimentId);
  }

  const apiKey = await getSecureApiKey(); // From secure storage

  const response = await fetch(`${SERVER_URL}/api/upload`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`
    },
    body: formData
  });

  if (!response.ok) {
    const error = await response.json();
    throw new UploadError(error.code, error.error);
  }

  return await response.json();
}
```

### Swift (iOS)

```swift
func uploadToExpTube(
    videoURL: URL,
    title: String,
    experimentId: String?,
    onProgress: @escaping (Double) -> Void
) async throws -> UploadResult {

    let boundary = UUID().uuidString
    var request = URLRequest(url: URL(string: "\(serverURL)/api/upload")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()

    // Add video file
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"video\"; filename=\"video.mp4\"\r\n")
    body.append("Content-Type: video/mp4\r\n\r\n")
    body.append(try Data(contentsOf: videoURL))
    body.append("\r\n")

    // Add title
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"title\"\r\n\r\n")
    body.append(title)
    body.append("\r\n")

    // Add experiment ID if provided
    if let expId = experimentId {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"experiment_id\"\r\n\r\n")
        body.append(expId)
        body.append("\r\n")
    }

    body.append("--\(boundary)--\r\n")

    request.httpBody = body

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw UploadError.invalidResponse
    }

    if httpResponse.statusCode == 201 {
        return try JSONDecoder().decode(UploadResult.self, from: data)
    } else {
        let error = try JSONDecoder().decode(ErrorResponse.self, from: data)
        throw UploadError.serverError(error.code, error.error)
    }
}
```

---

## Appendix B: ExpTube Platform Context

For full platform understanding, refer to:

- **OVERVIEW.md** - Complete platform technical overview
- **docs/api/upload-api.md** - Detailed upload API documentation
- **docs/architecture.md** - System architecture
- **processing/README.md** - AI processing pipeline details

---

## Document Metadata

| Field | Value |
|-------|-------|
| Document Type | Camera App Development Guide |
| Target Audience | AI Agent / Developer building camera app |
| Related Platform | ExpTube (see OVERVIEW.md) |
| API Version | 1.0 |
| Last Updated | December 2025 |

---

*This document provides complete specifications for building a camera control app that integrates with the ExpTube laboratory video platform. The implementing AI agent should use this as the primary reference for API integration, feature requirements, and implementation planning.*
