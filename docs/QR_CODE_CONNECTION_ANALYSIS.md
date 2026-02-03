# QR Code Camera Connection - Deep Analysis

**Project**: VeepaAudioTest
**Source**: SciSymbioLens
**Date**: 2026-02-03
**Status**: Analysis Complete - Ready for Implementation

---

## Executive Summary

The Veepa camera QR provisioning system is a **multi-stage process** that involves:
1. **QR Code Scanning** (iOS - AVFoundation)
2. **WiFi Provisioning** (5-frame animated QR sequence with specific mask patterns)
3. **Cloud API Discovery** (2-step credential fetch)
4. **P2P Connection** (Flutter SDK integration)

**Critical Discovery**: The camera requires a **specific 5-frame QR sequence** with exact mask patterns (Frame 1: Mask 4, Frame 2: Mask 2) - this cannot be skipped or simplified.

---

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. USER SCANS CAMERA QR CODE (iOS AVFoundation)                     │
│    → Extracts Virtual UID (e.g., "QW6-T..." or "OKB0379853SNLJ")    │
└─────────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 2. DETECT WIFI CREDENTIALS (iOS SystemConfiguration)                │
│    → SSID: Auto-detected                                            │
│    → BSSID: Auto-detected MAC address                               │
│    → Password: User enters manually                                 │
└─────────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 3. GENERATE 5-FRAME QR CODES (Flutter QR package)                   │
│    Frame 0: Full WiFi data (U empty) - 2 seconds                    │
│    Frame 1: Full + User ID (Mask 4 CRITICAL!) - 500ms cycle         │
│    Frame 2: BSSID + User (Mask 2 CRITICAL!) - 500ms cycle           │
│    Frame 3: SSID + Region - 500ms cycle                             │
│    Frame 4: Password + Region - 500ms cycle                         │
└─────────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 4. CAMERA SCANS QR & CONNECTS TO WIFI                               │
│    → Camera extracts WiFi credentials from 5-frame sequence         │
│    → Camera connects to WiFi network                                │
│    → Camera becomes reachable on local network                      │
└─────────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 5. CLOUD DISCOVERY (2-Step API Call)                                │
│    Step A: GET vuid.eye4.cn?vuid={virtual_uid}                      │
│           → Returns real clientId (e.g., "VSTH...")                 │
│    Step B: POST authentication.eye4.cn/getInitstring                │
│           → Returns serviceParam for P2P                            │
└─────────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 6. P2P CONNECTION (Flutter libVSTC.a SDK)                           │
│    → AppP2PApi.clientCreate(clientId)                               │
│    → Connect with serviceParam                                      │
│    → Login with password (default "888888" or "admin")              │
│    → State: disconnected → connecting → connected                   │
└─────────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 7. READY FOR AUDIO STREAMING                                        │
│    → Camera is now connected via P2P                                │
│    → Can send audio streaming commands                              │
│    → AudioUnit receives audio data                                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Key Components Analysis

### 1. QR Code Scanning (iOS)

**File**: `SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Views/Camera/CameraQRScannerView.swift`

**Technology Stack**:
- **AVFoundation Framework**: Core camera & QR detection
- **AVCaptureSession**: Manages camera input/output
- **AVCaptureMetadataOutput**: Detects QR codes (`.qr` type)
- **AVCaptureVideoPreviewLayer**: Live camera preview

**Architecture**:
```swift
CameraQRScannerView (SwiftUI)
    ↓
QRScannerRepresentable (UIViewControllerRepresentable)
    ↓
QRScannerViewController (UIViewController)
    ↓
AVCaptureSession + AVFoundation
```

**Key Code Pattern**:
```swift
// Setup camera for QR scanning
let captureSession = AVCaptureSession()
captureSession.addInput(videoInput)
captureSession.addOutput(metadataOutput)

// Configure for QR detection
metadataOutput.metadataObjectTypes = [.qr]

// Callback when QR detected
func metadataOutput(_ output: AVCaptureMetadataOutput,
                   didOutput metadataObjects: [AVMetadataObject]) {
    if let qrCode = metadataObjects.first as? AVMetadataMachineReadableCodeObject {
        let scannedString = qrCode.stringValue
        // Extract camera UID from QR code
    }
}
```

**Permissions Required** (Info.plist):
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is needed to scan QR codes on your Veepa camera</string>
```

---

### 2. WiFi Detection (iOS)

**File**: `SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Services/WiFiHelper.swift`

**Technology**: SystemConfiguration Framework + CoreLocation

**Key APIs**:
```swift
import SystemConfiguration.CaptiveNetwork
import CoreLocation

// Get current WiFi info
func fetchCurrentWiFi() {
    if let interfaces = CNCopySupportedInterfaces() as? [String] {
        for interface in interfaces {
            if let info = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any] {
                let ssid = info[kCNNetworkInfoKeySSID as String] as? String
                let bssid = info[kCNNetworkInfoKeyBSSID as String] as? String
                // Use SSID and BSSID for QR generation
            }
        }
    }
}
```

**Permissions Required** (Info.plist):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location access is needed to detect your WiFi network name</string>
```

**Note**: iOS 13+ requires location permission to access WiFi SSID/BSSID.

---

### 3. QR Code Generation (5-Frame Sequence)

**File**: `SciSymbioLens/flutter_module/veepa_camera/lib/services/wifi_qr_generator_service.dart`

**Critical Implementation Details**:

#### Frame Structure (JSON Format)

```dart
// Frame 0: Full data, U empty (shown once for 2 seconds)
{"BS":"aabbccddeeff","P":"password","U":"","S":"MyNetwork"}

// Frame 1: Full data WITH user ID (V4, Mask 4 - CRITICAL!)
{"BS":"aabbccddeeff","P":"password","U":"303628825","S":"MyNetwork"}

// Frame 2: BSSID + User + Region (V3, Mask 2 - CRITICAL!)
{"BS":"aabbccddeeff","U":"303628825","A":"3"}

// Frame 3: SSID + Region (V3, auto mask)
{"S":"MyNetwork","A":"3"}

// Frame 4: Password + Region (V2, auto mask)
{"P":"password","A":"3"}
```

#### QR Configuration (Mask Patterns)

**CRITICAL**: Veepa cameras are extremely strict about QR mask patterns.

```dart
static (int typeNumber, int? maskPattern) getQrConfigForFrame(int frameIndex) {
  switch (frameIndex) {
    case 0: return (4, null);      // V4, auto mask
    case 1: return (4, 4);         // V4, MASK 4 (MUST BE 4!)
    case 2: return (3, 2);         // V3, MASK 2 (MUST BE 2!)
    case 3: return (3, null);      // V3, auto mask
    case 4: return (2, null);      // V2, auto mask
    default: return (4, null);
  }
}
```

**Why Mask Patterns Matter**:
- Standard QR libraries (iOS CIFilter, most packages) don't support mask pattern specification
- Flutter `qr` package (v3.0.0+) supports `maskPattern` parameter
- Frame 1 & 2 MUST use specified masks or camera silently rejects them
- This was discovered through reverse-engineering the official Veepa app

#### Field Encoding Rules

| Field | Description | Example | Format Rules |
|-------|-------------|---------|--------------|
| `BS` | BSSID (WiFi MAC) | `aabbccddeeff` | Lowercase, no colons |
| `P` | WiFi Password | `MyPassword123` | Case-sensitive, exact |
| `U` | Veepa User ID | `303628825` | Default 303628825 |
| `S` | WiFi SSID | `My Network` | Spaces/special chars OK |
| `A` | Region code | `3` | 3=Americas, 1=Asia, etc. |

#### Animation Timing

```
Time 0-2s:    Frame 0 (full, U empty)
Time 2-2.5s:  Frame 1 (full with U)
Time 2.5-3s:  Frame 2 (BS+U+A)
Time 3-3.5s:  Frame 3 (S+A)
Time 3.5-4s:  Frame 4 (P+A)
Time 4-4.5s:  Frame 1 (cycle repeats)
...continues cycling frames 1-4 every 500ms
```

**Implementation Note**: Frames 1-4 cycle indefinitely until camera finishes scanning.

---

### 4. Platform Channel Communication

**Channel Name**: `com.scisymbiolens/veepa` (will be `com.veepatest/audio` for VeepaAudioTest)

#### Swift → Flutter Methods

```swift
// Generate QR frame data
engineManager.invoke("generateQrFrames", arguments: [
    "ssid": ssid,
    "password": password,
    "bssid": bssid,
    "userId": "303628825",  // Default Veepa user ID
    "region": "3"           // Americas
])

// Generate QR images (PNG base64)
engineManager.invoke("generateQrImages", arguments: [
    "ssid": ssid,
    "password": password,
    "bssid": bssid
])

// Start provisioning flow
engineManager.invoke("startProvisioning", arguments: [
    "ssid": ssid,
    "password": password,
    "bssid": bssid,
    "deviceId": virtualUid
])

// Connect to camera after provisioning
engineManager.invoke("connectWithCredentials", arguments: [
    "cameraUid": credentials.cameraUid,
    "clientId": credentials.clientId,
    "serviceParam": credentials.serviceParam,
    "password": "888888"
])
```

#### Flutter → Swift Events

```dart
// Send provisioning events back to Swift
platform.invokeMethod('provisioningEvent', {
  'type': 'stateChange',
  'state': 'showingQr',  // idle, showingQr, searchingCamera, etc.
  'data': null
});

platform.invokeMethod('provisioningEvent', {
  'type': 'qrFramesGenerated',
  'data': {
    'frames': ['base64png1', 'base64png2', ...],
    'configs': [
      {'version': 4, 'maskPattern': null},
      {'version': 4, 'maskPattern': 4},
      ...
    ]
  }
});

platform.invokeMethod('provisioningEvent', {
  'type': 'cameraFound',
  'data': {'uid': 'OKB0379853SNLJ'}
});

platform.invokeMethod('provisioningEvent', {
  'type': 'pairingComplete',
  'data': null
});

platform.invokeMethod('provisioningEvent', {
  'type': 'error',
  'data': {'message': 'Camera not found after 60 seconds'}
});
```

---

### 5. P2P Credential Fetching (Cloud APIs)

**File**: `SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Services/P2PCredentialService.swift`

#### Two-Step API Process

**Step 1: Virtual UID → Real Client ID**

```swift
// API Endpoint
GET https://vuid.eye4.cn?vuid={virtualUID}

// Example Request
GET https://vuid.eye4.cn?vuid=OKB0379853SNLJ

// Example Response
{
  "uid": "VSTH12345678ABCD",
  "supplier": "Veepa",
  "cluster": "cn-north"
}
```

**Step 2: Client ID Prefix → Service Param**

```swift
// API Endpoint
POST https://authentication.eye4.cn/getInitstring

// Request Body
{
  "uid": ["VSTH"]  // First 4 chars of clientId
}

// Example Response
[
  "VSTC1234567890ABCDEF..."  // Long base64-like string
]
```

#### P2PCredentials Model

```swift
struct P2PCredentials: Codable {
    let cameraUid: String          // Virtual UID from QR (e.g., "OKB0379853SNLJ")
    let clientId: String           // Real device ID (e.g., "VSTH12345678ABCD")
    let serviceParam: String       // P2P init string (e.g., "VSTC1234567890...")
    var password: String?          // Camera password (e.g., "888888" or "admin")
    let cachedAt: Date            // When cached in UserDefaults
    let supplier: String?          // "Veepa"
    let cluster: String?           // "cn-north", "us-west", etc.

    var isValid: Bool {
        !cameraUid.isEmpty && !clientId.isEmpty && !serviceParam.isEmpty
    }
}
```

#### Caching Strategy

```swift
// Cache credentials in UserDefaults
UserDefaults.standard.set(encodedCredentials, forKey: "p2p_credentials_\(cameraUid)")

// Credentials are valid for:
// - Until app restart (in-memory cache)
// - 24 hours (UserDefaults cache)
// - Until P2P connection timeout (3 minutes idle)
```

**Note**: Service param becomes stale after 3-minute idle timeout. Re-fetch on connection failure.

---

### 6. P2P Connection Flow (Flutter)

**File**: `SciSymbioLens/flutter_module/veepa_camera/lib/services/veepa_connection_manager.dart`

#### Connection State Machine

```dart
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  streaming,
  reconnecting,
  error
}
```

#### Connection Sequence

```dart
// 1. Create P2P client
AppP2PApi.clientCreate(
  clientId: credentials.clientId,
  initString: credentials.serviceParam,
  password: credentials.password ?? "888888"
);

// 2. Connect with type
AppP2PApi.connectWithType(
  connectType: 63  // 63 = LAN, 126 = P2P/Router (cloud-assisted)
);

// 3. Wait for connection callbacks
// Flutter native code handles P2P state changes via callbacks:
// - onConnecting
// - onConnected
// - onDisconnected
// - onError

// 4. Once connected, can send commands
AppP2PApi.sendCommand("get_status.cgi");
AppP2PApi.sendCommand("livestream.cgi?stream=0");  // Start audio/video
```

#### Connection Types

| Type | Mode | Use Case | Requirements |
|------|------|----------|--------------|
| 63 | LAN Direct | Same WiFi network | Fast, reliable |
| 126 | P2P/Router | Cloud-assisted hole-punching | Works across networks |
| Others | Various fallback modes | Documented in SDK | Rarely needed |

**Recommended**: Use `63` for initial connection (same network), `126` for reconnection (may be different network).

---

### 7. Complete iOS Implementation Files

For VeepaAudioTest, we need to adapt these files from SciSymbioLens:

#### iOS Swift Files (7 files)

1. **CameraQRScannerView.swift** (QR scanning UI)
   - Path: `ios/SciSymbioLens/SciSymbioLens/Views/Camera/CameraQRScannerView.swift`
   - Lines: 267 lines
   - Purpose: AVFoundation QR scanner wrapper
   - Changes needed: Minimal - just namespace changes

2. **VeepaProvisioningView.swift** (Main provisioning UI)
   - Path: `ios/SciSymbioLens/SciSymbioLens/Views/Camera/VeepaProvisioningView.swift`
   - Lines: 500+ lines
   - Purpose: Complete provisioning flow UI
   - Changes needed: Remove video streaming parts, keep audio focus

3. **VeepaProvisioningBridge.swift** (Platform channel bridge)
   - Path: `ios/SciSymbioLens/SciSymbioLens/Services/Flutter/VeepaProvisioningBridge.swift`
   - Lines: 350+ lines
   - Purpose: Swift ↔ Flutter communication for provisioning
   - Changes needed: Update channel name to `com.veepatest/audio`

4. **P2PCredentialService.swift** (Cloud API client)
   - Path: `ios/SciSymbioLens/SciSymbioLens/Services/P2PCredentialService.swift`
   - Lines: 200+ lines
   - Purpose: Fetch credentials from vuid.eye4.cn & authentication.eye4.cn
   - Changes needed: None - can copy as-is

5. **P2PCredentials.swift** (Data model)
   - Path: `ios/SciSymbioLens/SciSymbioLens/Models/P2PCredentials.swift`
   - Lines: 80 lines
   - Purpose: Codable model for P2P credentials
   - Changes needed: None - copy as-is

6. **WiFiHelper.swift** (WiFi detection)
   - Path: `ios/SciSymbioLens/SciSymbioLens/Services/WiFiHelper.swift`
   - Lines: 120 lines
   - Purpose: Detect current WiFi SSID & BSSID
   - Changes needed: None - copy as-is

7. **VeepaConnectionBridge.swift** (Already exists)
   - Path: Already in VeepaAudioTest
   - Purpose: Connection management bridge
   - Changes needed: Already adapted from SciSymbioLens

#### Flutter Dart Files (4 files)

1. **qr_provisioning_screen.dart** (UI)
   - Path: `flutter_module/veepa_camera/lib/screens/qr_provisioning_screen.dart`
   - Lines: 600+ lines
   - Purpose: Flutter UI for QR provisioning
   - Changes needed: Remove video parts, keep audio focus

2. **wifi_qr_generator_service.dart** (QR generation)
   - Path: `flutter_module/veepa_camera/lib/services/wifi_qr_generator_service.dart`
   - Lines: 300+ lines
   - Purpose: Generate 5-frame QR sequence with mask patterns
   - Changes needed: None - CRITICAL component, copy exactly

3. **camera_pairing_manager.dart** (State management)
   - Path: `flutter_module/veepa_camera/lib/services/camera_pairing_manager.dart`
   - Lines: 400+ lines
   - Purpose: Manage provisioning state machine
   - Changes needed: Simplify for audio-only use case

4. **veepa_connection_manager.dart** (Already exists)
   - Path: Already in VeepaAudioTest Flutter module
   - Purpose: P2P connection management
   - Changes needed: Already adapted from SciSymbioLens

---

## Implementation Strategy for VeepaAudioTest

### Phase 1: Foundation (1-2 hours)
- [ ] Copy P2PCredentials.swift model
- [ ] Copy P2PCredentialService.swift (cloud API client)
- [ ] Copy WiFiHelper.swift (WiFi detection)
- [ ] Update Info.plist permissions (camera, location)

### Phase 2: QR Scanning (1-2 hours)
- [ ] Copy CameraQRScannerView.swift
- [ ] Test QR scanning with sample camera QR code
- [ ] Extract virtual UID from scanned code

### Phase 3: QR Generation (Flutter) (2-3 hours)
- [ ] Copy wifi_qr_generator_service.dart
- [ ] Add `qr` package dependency (v3.0.0+)
- [ ] Test 5-frame generation with mask patterns
- [ ] Verify Frame 1 Mask 4, Frame 2 Mask 2

### Phase 4: Provisioning Bridge (2-3 hours)
- [ ] Copy VeepaProvisioningBridge.swift
- [ ] Update platform channel to `com.veepatest/audio`
- [ ] Implement method handlers (generateQrImages, startProvisioning)
- [ ] Test Swift ↔ Flutter communication

### Phase 5: Provisioning UI (2-3 hours)
- [ ] Copy VeepaProvisioningView.swift
- [ ] Simplify: Remove video streaming parts
- [ ] Keep: QR display, camera detection, success overlay
- [ ] Test complete provisioning flow

### Phase 6: Integration & Testing (2-3 hours)
- [ ] Connect provisioning to AudioConnectionService
- [ ] Test full flow: QR scan → provision → connect → audio
- [ ] Verify credentials cached correctly
- [ ] Test reconnection after app restart

**Total Estimated Time**: 10-16 hours

---

## Critical Success Factors

### ✅ Must-Have Features
1. **Exact 5-frame QR sequence** with mask patterns
2. **Cloud API credential fetching** (2-step process)
3. **WiFi SSID/BSSID detection** with proper permissions
4. **Platform channel communication** (Swift ↔ Flutter)
5. **Credential caching** in UserDefaults

### ⚠️ Common Pitfalls to Avoid
1. **Wrong mask patterns** → Camera silently rejects QR codes
2. **Standard iOS QR generation** → Cannot specify mask patterns (must use Flutter)
3. **Missing location permission** → WiFi SSID/BSSID unavailable on iOS 13+
4. **BSSID formatting** → Must be lowercase, no colons
5. **Service param expiry** → Re-fetch on timeout (3 minutes idle)
6. **Connection type 63 vs 126** → Use 63 for LAN, 126 for P2P across networks

### 🔍 Testing Checklist
- [ ] QR scanning works on physical camera QR code
- [ ] WiFi SSID/BSSID detected correctly
- [ ] 5-frame QR sequence displays properly
- [ ] Camera successfully scans QR and connects to WiFi
- [ ] Cloud APIs return valid credentials
- [ ] P2P connection establishes successfully
- [ ] Credentials persist across app restarts
- [ ] Audio streaming works after QR provisioning

---

## Alternative: Skip QR Provisioning for Testing

If QR provisioning is too complex for initial audio testing, you can:

### Quick Test Mode (Manual Entry)
1. **Keep current UI**: Pre-filled UID and password
2. **Fetch credentials manually**: Call cloud APIs with hard-coded UID
3. **Connect directly**: Use P2PCredentials without provisioning

**Trade-off**:
- ✅ Faster to implement (1-2 hours vs 10-16 hours)
- ✅ Good enough for audio testing
- ❌ Camera must already be on WiFi (manual setup via official app)
- ❌ Not a complete end-to-end flow

### Implementation for Quick Test Mode
```swift
// In AudioConnectionService.swift
func connectWithManualCredentials(uid: String, password: String) async {
    // Step 1: Fetch credentials from cloud
    let credentials = await P2PCredentialService.fetchCredentials(uid: uid)

    // Step 2: Connect via existing VeepaConnectionBridge
    await VeepaConnectionBridge.connectWithCredentials(credentials, password: password)

    // Step 3: Start audio streaming
    // ... existing code ...
}
```

**Recommendation**: Implement Quick Test Mode first to verify audio works, then add QR provisioning later if needed.

---

## Next Steps

**Ready for Implementation**: All analysis complete.

**When user asks to implement**:
1. Confirm: Full QR provisioning OR Quick Test Mode?
2. If Full: Follow Phase 1-6 implementation plan
3. If Quick: Implement manual credential fetch (1-2 hours)

**Decision Point**: Ask user which approach they prefer.
