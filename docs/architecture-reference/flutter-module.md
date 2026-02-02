# Flutter Module Architecture

The Flutter module (`flutter_module/veepa_camera/`) provides the bridge between the iOS app and the Veepa camera SDK.

---

## CRITICAL: Flutter Build Workflow

> **WARNING FOR AI AGENTS**: When you modify Flutter/Dart code in `flutter_module/veepa_camera/`, you MUST follow this build workflow or your changes will NOT take effect in the iOS app!

### The Problem

Flutter compiles Dart code into native frameworks (`App.xcframework`). There are **TWO locations** where these frameworks exist:

1. **Build Output**: `flutter_module/veepa_camera/build/ios/framework/` - Where Flutter builds to
2. **iOS Project**: `ios/SciSymbioLens/Flutter/` - Where Xcode looks for frameworks

**Without syncing, Xcode uses STALE code!**

### Required Steps After Changing Flutter Code

```bash
# Step 1: Navigate to Flutter module
cd flutter_module/veepa_camera

# Step 2: Rebuild Flutter frameworks
flutter build ios-framework --output=build/ios/framework

# Step 3: Sync to iOS project (usually automatic, but can be done manually)
cd ../../ios/SciSymbioLens
SRCROOT="$(pwd)" CONFIGURATION="Debug" ./Scripts/sync-flutter-frameworks.sh

# Step 4: Rebuild iOS app in Xcode
```

### Automatic Sync

The sync script (`ios/SciSymbioLens/Scripts/sync-flutter-frameworks.sh`) runs automatically as an Xcode pre-build phase. However, you MUST still run `flutter build ios-framework` first!

### Verify Sync Worked

Check that timestamps match:
```bash
# These should have the same timestamp after sync:
ls -la ios/SciSymbioLens/Flutter/Debug/App.xcframework/ios-arm64/App.framework/App
ls -la flutter_module/veepa_camera/build/ios/framework/Debug/App.xcframework/ios-arm64/App.framework/App
```

### Common Mistakes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Flutter changes not visible | Didn't run `flutter build ios-framework` | Run the build command |
| Heartbeat/features not working | Framework mismatch | Check timestamps, re-sync |
| Build works but old behavior | Stale frameworks | Clean build + fresh sync |

**For detailed documentation, see**: [Flutter-iOS Integration Architecture](../architecture/flutter-ios-integration.md)

---

## Purpose

The Veepa camera SDK is primarily Flutter-based, so we embed a Flutter engine in the iOS app and communicate via platform channels. This module:

1. Wraps the Veepa SDK for camera discovery and connection
2. Handles video frame streaming from external cameras
3. Manages camera pairing/provisioning workflows
4. Provides QR code generation for WiFi configuration

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    iOS Swift Layer                          │
│  (FlutterEngineManager, Veepa*Bridge classes)              │
└────────────────────────────┬────────────────────────────────┘
                             │
                             │ Platform Channels
                             │ (Method + Event)
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Dart Layer                       │
│  (veepa_channel.dart, services)                            │
└────────────────────────────┬────────────────────────────────┘
                             │
                             │ Plugin Interface
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    Veepa Native SDK                         │
│  (libVSTC.a, VsdkPlugin)                                   │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
flutter_module/veepa_camera/
├── lib/
│   ├── main.dart                    # Entry point (headless)
│   ├── veepa_channel.dart           # Platform channel bridge
│   │
│   ├── models/
│   │   ├── connection_state.dart    # Connection state enum
│   │   ├── discovered_device.dart   # Device discovery model
│   │   └── paired_camera.dart       # Paired camera model
│   │
│   ├── services/
│   │   ├── veepa_connection_manager.dart    # Main SDK wrapper
│   │   ├── veepa_discovery_service.dart     # Device discovery
│   │   ├── veepa_frame_handler.dart         # Frame streaming
│   │   ├── camera_pairing_manager.dart      # Pairing workflow
│   │   ├── camera_connection_detector.dart  # Connection detection
│   │   ├── qr_image_generator_service.dart  # QR generation
│   │   └── wifi_qr_generator_service.dart   # WiFi config QR
│   │
│   ├── sdk/
│   │   ├── app_dart.dart            # Dart SDK wrapper
│   │   ├── app_p2p_api.dart         # P2P API wrapper
│   │   └── app_player.dart          # Player wrapper
│   │
│   ├── screens/
│   │   └── qr_provisioning_screen.dart
│   │
│   └── widgets/
│       ├── veepa_video_view.dart    # Video view widget
│       └── masked_qr_widget.dart    # QR display widget
│
├── test/                            # Dart unit tests
├── pubspec.yaml                     # Dependencies
└── README.md
```

## Platform Channel Communication

### Channel Types

1. **Method Channels**: Request-response pattern (Swift → Flutter → Swift)
2. **Event Channels**: Stream pattern (Flutter → Swift, continuous)

### Channel Definition

```dart
// veepa_channel.dart
class VeepaChannel {
  static const MethodChannel _methodChannel =
      MethodChannel('com.scisymbiolens/veepa_camera');

  static const EventChannel _discoveryEvents =
      EventChannel('com.scisymbiolens/veepa_discovery_events');

  static const EventChannel _connectionEvents =
      EventChannel('com.scisymbiolens/veepa_connection_events');

  static const EventChannel _frameEvents =
      EventChannel('com.scisymbiolens/veepa_frame_events');

  static const EventChannel _provisioningEvents =
      EventChannel('com.scisymbiolens/veepa_provisioning_events');
}
```

### Method Channel API

```dart
// Available methods
class VeepaChannel {
  // Discovery
  Future<void> startDiscovery() async {
    await _methodChannel.invokeMethod('startDiscovery');
  }

  Future<void> stopDiscovery() async {
    await _methodChannel.invokeMethod('stopDiscovery');
  }

  Future<List<DiscoveredDevice>> getDiscoveredDevices() async {
    final result = await _methodChannel.invokeMethod('getDiscoveredDevices');
    return (result as List).map((e) => DiscoveredDevice.fromJson(e)).toList();
  }

  // Connection
  Future<void> connectToCamera(String deviceId, P2PCredentials credentials) async {
    await _methodChannel.invokeMethod('connectToCamera', {
      'deviceId': deviceId,
      'username': credentials.username,
      'password': credentials.password,
    });
  }

  Future<void> disconnect() async {
    await _methodChannel.invokeMethod('disconnect');
  }

  // Streaming
  Future<void> startStreaming() async {
    await _methodChannel.invokeMethod('startStreaming');
  }

  Future<void> stopStreaming() async {
    await _methodChannel.invokeMethod('stopStreaming');
  }

  // Provisioning
  Future<String> generateProvisioningQR(WiFiConfig config) async {
    return await _methodChannel.invokeMethod('generateProvisioningQR', {
      'ssid': config.ssid,
      'password': config.password,
    });
  }
}
```

### Event Channel Streams

```dart
// Event streams
class VeepaChannel {
  // Discovery events
  Stream<DiscoveredDevice> get discoveryStream {
    return _discoveryEvents.receiveBroadcastStream()
        .map((event) => DiscoveredDevice.fromJson(event));
  }

  // Connection state events
  Stream<ConnectionState> get connectionStream {
    return _connectionEvents.receiveBroadcastStream()
        .map((event) => ConnectionState.fromString(event['state']));
  }

  // Frame events (video frames as bytes)
  Stream<Uint8List> get frameStream {
    return _frameEvents.receiveBroadcastStream()
        .map((event) => event as Uint8List);
  }

  // Provisioning status events
  Stream<ProvisioningStatus> get provisioningStream {
    return _provisioningEvents.receiveBroadcastStream()
        .map((event) => ProvisioningStatus.fromJson(event));
  }
}
```

## iOS Bridge Classes

### FlutterEngineManager

Manages the Flutter engine lifecycle:

```swift
// FlutterEngineManager.swift
class FlutterEngineManager {
    static let shared = FlutterEngineManager()

    private var flutterEngine: FlutterEngine?
    private var isInitialized = false

    func initialize() {
        guard !isInitialized else { return }

        flutterEngine = FlutterEngine(name: "veepa_camera")
        flutterEngine?.run()

        // Register plugins
        GeneratedPluginRegistrant.register(with: flutterEngine!)

        setupChannels()
        isInitialized = true
    }

    private func setupChannels() {
        guard let engine = flutterEngine else { return }

        // Set up method channel
        let methodChannel = FlutterMethodChannel(
            name: "com.scisymbiolens/veepa_camera",
            binaryMessenger: engine.binaryMessenger
        )

        // Set up event channels
        let discoveryChannel = FlutterEventChannel(
            name: "com.scisymbiolens/veepa_discovery_events",
            binaryMessenger: engine.binaryMessenger
        )

        // ... configure handlers
    }

    func shutdown() {
        flutterEngine?.destroyContext()
        flutterEngine = nil
        isInitialized = false
    }
}
```

### VeepaDiscoveryBridge

Handles device discovery:

```swift
// VeepaDiscoveryBridge.swift
class VeepaDiscoveryBridge: ObservableObject {
    @Published var discoveredDevices: [VeepaDevice] = []
    @Published var isDiscovering = false

    private var eventSink: FlutterEventSink?

    func startDiscovery() {
        isDiscovering = true
        FlutterEngineManager.shared.methodChannel?.invokeMethod(
            "startDiscovery",
            arguments: nil
        )
    }

    func stopDiscovery() {
        isDiscovering = false
        FlutterEngineManager.shared.methodChannel?.invokeMethod(
            "stopDiscovery",
            arguments: nil
        )
    }

    // Event sink receives discovered devices
    func onListen(arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        return nil
    }

    func handleDiscoveredDevice(_ device: [String: Any]) {
        let veepaDevice = VeepaDevice(
            id: device["id"] as? String ?? "",
            name: device["name"] as? String ?? "",
            ipAddress: device["ipAddress"] as? String ?? ""
        )
        DispatchQueue.main.async {
            self.discoveredDevices.append(veepaDevice)
        }
    }
}
```

### VeepaConnectionBridge

Manages connection state:

```swift
// VeepaConnectionBridge.swift
class VeepaConnectionBridge: ObservableObject {
    @Published var connectionState: VeepaConnectionState = .disconnected
    @Published var connectedDevice: VeepaDevice?
    @Published var error: VeepaConnectionError?

    func connect(device: VeepaDevice, credentials: P2PCredentials) async throws {
        connectionState = .connecting

        FlutterEngineManager.shared.methodChannel?.invokeMethod(
            "connectToCamera",
            arguments: [
                "deviceId": device.id,
                "username": credentials.username,
                "password": credentials.password
            ]
        ) { [weak self] result in
            if let error = result as? FlutterError {
                self?.connectionState = .disconnected
                self?.error = .connectionFailed(error.message ?? "Unknown error")
            }
        }
    }

    func disconnect() {
        FlutterEngineManager.shared.methodChannel?.invokeMethod(
            "disconnect",
            arguments: nil
        )
        connectionState = .disconnected
        connectedDevice = nil
    }

    // Handle connection state updates from Flutter
    func handleConnectionStateUpdate(_ state: String) {
        DispatchQueue.main.async {
            switch state {
            case "connecting":
                self.connectionState = .connecting
            case "connected":
                self.connectionState = .connected
            case "disconnected":
                self.connectionState = .disconnected
            case "error":
                self.connectionState = .error
            default:
                break
            }
        }
    }
}
```

### VeepaFrameBridge

Handles video frame streaming:

```swift
// VeepaFrameBridge.swift
class VeepaFrameBridge: ObservableObject {
    @Published var latestFrame: Data?
    @Published var isStreaming = false
    @Published var frameRate: Double = 0

    private var frameBuffer: Data?
    private var lastFrameTime: Date?

    func startStreaming() {
        isStreaming = true
        FlutterEngineManager.shared.methodChannel?.invokeMethod(
            "startStreaming",
            arguments: nil
        )
    }

    func stopStreaming() {
        isStreaming = false
        FlutterEngineManager.shared.methodChannel?.invokeMethod(
            "stopStreaming",
            arguments: nil
        )
    }

    // Handle incoming frames from Flutter
    func handleFrame(_ frameData: FlutterStandardTypedData) {
        let data = frameData.data

        // Calculate frame rate
        if let lastTime = lastFrameTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            frameRate = 1.0 / elapsed
        }
        lastFrameTime = Date()

        // Update buffer
        DispatchQueue.main.async {
            self.frameBuffer = data
            self.latestFrame = data
        }
    }

    func getLatestFrame() -> Data? {
        return frameBuffer
    }
}
```

### VeepaProvisioningBridge

Handles camera pairing workflow:

```swift
// VeepaProvisioningBridge.swift
class VeepaProvisioningBridge: ObservableObject {
    @Published var provisioningState: ProvisioningState = .idle
    @Published var qrCodeData: Data?

    enum ProvisioningState {
        case idle
        case generatingQR
        case waitingForScan
        case connecting
        case completed
        case failed(String)
    }

    func startProvisioning(wifiConfig: WiFiConfig) {
        provisioningState = .generatingQR

        FlutterEngineManager.shared.methodChannel?.invokeMethod(
            "generateProvisioningQR",
            arguments: [
                "ssid": wifiConfig.ssid,
                "password": wifiConfig.password
            ]
        ) { [weak self] result in
            if let qrData = result as? FlutterStandardTypedData {
                self?.qrCodeData = qrData.data
                self?.provisioningState = .waitingForScan
            } else if let error = result as? FlutterError {
                self?.provisioningState = .failed(error.message ?? "QR generation failed")
            }
        }
    }

    func handleProvisioningUpdate(_ status: [String: Any]) {
        DispatchQueue.main.async {
            let state = status["state"] as? String ?? ""
            switch state {
            case "scanning":
                self.provisioningState = .waitingForScan
            case "connecting":
                self.provisioningState = .connecting
            case "completed":
                self.provisioningState = .completed
            case "failed":
                let message = status["message"] as? String ?? "Unknown error"
                self.provisioningState = .failed(message)
            default:
                break
            }
        }
    }
}
```

## Flutter Services

### VeepaConnectionManager

Main wrapper around the Veepa SDK:

```dart
// veepa_connection_manager.dart
class VeepaConnectionManager {
  static final VeepaConnectionManager _instance = VeepaConnectionManager._internal();
  factory VeepaConnectionManager() => _instance;
  VeepaConnectionManager._internal();

  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  Stream<ConnectionState> get connectionStateStream => _connectionStateController.stream;

  CameraDevice? _currentDevice;
  ConnectionState _state = ConnectionState.disconnected;

  Future<void> connect(String deviceId, String username, String password) async {
    _state = ConnectionState.connecting;
    _connectionStateController.add(_state);

    try {
      _currentDevice = CameraDevice(
        id: deviceId,
        name: deviceId,
        username: username,
        password: password,
      );

      final result = await _currentDevice!.connect();

      if (result == CameraConnectState.connected) {
        _state = ConnectionState.connected;
      } else {
        _state = ConnectionState.disconnected;
        throw VeepaConnectionException('Connection failed: $result');
      }
    } catch (e) {
      _state = ConnectionState.error;
      _connectionStateController.add(_state);
      rethrow;
    }

    _connectionStateController.add(_state);
  }

  Future<void> disconnect() async {
    await _currentDevice?.disconnect();
    _currentDevice = null;
    _state = ConnectionState.disconnected;
    _connectionStateController.add(_state);
  }

  Future<void> startStreaming() async {
    if (_currentDevice == null) {
      throw StateError('Not connected to any device');
    }
    await _currentDevice!.startStream();
    _state = ConnectionState.streaming;
    _connectionStateController.add(_state);
  }

  Future<void> stopStreaming() async {
    await _currentDevice?.stopStream();
    _state = ConnectionState.connected;
    _connectionStateController.add(_state);
  }

  void dispose() {
    _connectionStateController.close();
  }
}
```

### VeepaDiscoveryService

Handles LAN device discovery:

```dart
// veepa_discovery_service.dart
class VeepaDiscoveryService {
  final _discoveredDevicesController = StreamController<DiscoveredDevice>.broadcast();
  Stream<DiscoveredDevice> get discoveredDevicesStream => _discoveredDevicesController.stream;

  final List<DiscoveredDevice> _devices = [];
  bool _isDiscovering = false;

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    _isDiscovering = true;
    _devices.clear();

    // Use Veepa SDK discovery
    final scanner = VeepaDeviceScanner();
    scanner.onDeviceFound = (device) {
      final discoveredDevice = DiscoveredDevice(
        id: device.id,
        name: device.alias ?? device.id,
        ipAddress: device.ipAddress,
        model: device.model,
      );

      if (!_devices.any((d) => d.id == discoveredDevice.id)) {
        _devices.add(discoveredDevice);
        _discoveredDevicesController.add(discoveredDevice);
      }
    };

    await scanner.startScan(timeout: Duration(seconds: 10));
  }

  Future<void> stopDiscovery() async {
    _isDiscovering = false;
  }

  List<DiscoveredDevice> getDiscoveredDevices() {
    return List.unmodifiable(_devices);
  }

  void dispose() {
    _discoveredDevicesController.close();
  }
}
```

### VeepaFrameHandler

Handles video frame processing:

```dart
// veepa_frame_handler.dart
class VeepaFrameHandler {
  final _frameController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get frameStream => _frameController.stream;

  Uint8List? _latestFrame;
  int _frameCount = 0;
  DateTime? _lastFrameTime;

  void handleFrame(Uint8List frameData) {
    _latestFrame = frameData;
    _frameCount++;
    _lastFrameTime = DateTime.now();

    _frameController.add(frameData);
  }

  Uint8List? getLatestFrame() => _latestFrame;

  double getFrameRate() {
    if (_lastFrameTime == null) return 0;
    // Calculate based on recent frames
    return _frameCount / (DateTime.now().difference(_lastFrameTime!).inSeconds + 1);
  }

  void reset() {
    _latestFrame = null;
    _frameCount = 0;
    _lastFrameTime = null;
  }

  void dispose() {
    _frameController.close();
  }
}
```

## Data Models

### ConnectionState

```dart
// connection_state.dart
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  streaming,
  error;

  static ConnectionState fromString(String value) {
    return ConnectionState.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ConnectionState.disconnected,
    );
  }
}
```

### DiscoveredDevice

```dart
// discovered_device.dart
class DiscoveredDevice {
  final String id;
  final String name;
  final String ipAddress;
  final String? model;
  final DateTime discoveredAt;

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    this.model,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) {
    return DiscoveredDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      ipAddress: json['ipAddress'] as String,
      model: json['model'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ipAddress': ipAddress,
      'model': model,
    };
  }
}
```

### PairedCamera

```dart
// paired_camera.dart
class PairedCamera {
  final String id;
  final String name;
  final String username;
  final String password;
  final DateTime pairedAt;

  PairedCamera({
    required this.id,
    required this.name,
    required this.username,
    required this.password,
    DateTime? pairedAt,
  }) : pairedAt = pairedAt ?? DateTime.now();

  factory PairedCamera.fromJson(Map<String, dynamic> json) {
    return PairedCamera(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      pairedAt: DateTime.parse(json['pairedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'password': password,
      'pairedAt': pairedAt.toIso8601String(),
    };
  }
}
```

## Dependencies

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter

  # QR code generation
  qr: ^3.0.0

  # Image processing
  image: ^4.0.0

  # Local storage
  shared_preferences: ^2.2.0

  # Network info
  network_info_plus: ^5.0.0

  # Veepa SDK (local path)
  veepa_sdk:
    path: ../veepa_sdk
```

## Build Configuration

The Flutter module is built as an AAR/framework and embedded in the iOS app:

```bash
# Build Flutter module
cd flutter_module/veepa_camera
flutter build ios-framework --output=../../ios/SciSymbioLens/Flutter

# Sync frameworks (custom script)
./ios/SciSymbioLens/Scripts/sync-flutter-frameworks.sh
```

## Error Handling

```dart
// Custom exceptions
class VeepaConnectionException implements Exception {
  final String message;
  VeepaConnectionException(this.message);

  @override
  String toString() => 'VeepaConnectionException: $message';
}

class VeepaDiscoveryException implements Exception {
  final String message;
  VeepaDiscoveryException(this.message);
}

class VeepaStreamingException implements Exception {
  final String message;
  VeepaStreamingException(this.message);
}
```

## Testing

```dart
// veepa_connection_manager_test.dart
void main() {
  group('VeepaConnectionManager', () {
    late VeepaConnectionManager manager;

    setUp(() {
      manager = VeepaConnectionManager();
    });

    test('initial state is disconnected', () {
      expect(manager.state, ConnectionState.disconnected);
    });

    test('connect changes state to connecting then connected', () async {
      final states = <ConnectionState>[];
      manager.connectionStateStream.listen(states.add);

      await manager.connect('device123', 'admin', '888888');

      expect(states, [
        ConnectionState.connecting,
        ConnectionState.connected,
      ]);
    });
  });
}
```

---

*Last updated: January 2026*
