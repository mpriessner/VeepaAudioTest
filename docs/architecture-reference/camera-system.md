# Camera System Architecture

The app supports multiple camera sources through a protocol-based abstraction layer.

## Multi-Camera Design

### Challenge

Support both the built-in iPhone camera AND external Wi-Fi cameras (Veepa) with a unified interface.

### Solution

Protocol-based abstraction with two concrete implementations:

```
CameraSourceProtocol (Interface)
    ├── LocalCameraSource (iPhone camera via AVFoundation)
    └── VeepaCameraSource (External Wi-Fi camera via Flutter/Veepa SDK)
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    CameraSourceManager                      │
│                    (Singleton - Source Switching)           │
└────────────────────────────┬────────────────────────────────┘
                             │
              ┌──────────────┼──────────────┐
              │                             │
              ▼                             ▼
┌─────────────────────────┐   ┌─────────────────────────┐
│   LocalCameraSource     │   │   VeepaCameraSource     │
│   (AVFoundation)        │   │   (Flutter Bridge)      │
└────────────┬────────────┘   └────────────┬────────────┘
             │                             │
             ▼                             ▼
┌─────────────────────────┐   ┌─────────────────────────┐
│   AVCaptureSession      │   │   FlutterEngineManager  │
│   AVCaptureDevice       │   │   Veepa SDK             │
│   AVCaptureOutput       │   │   Platform Channels     │
└─────────────────────────┘   └─────────────────────────┘
```

## CameraSourceProtocol

The protocol defines the contract for all camera sources:

```swift
// CameraSourceProtocol.swift
protocol CameraSourceProtocol: AnyObject {
    // MARK: - State
    var state: CameraSourceState { get }
    var statePublisher: AnyPublisher<CameraSourceState, Never> { get }

    // MARK: - Capabilities
    var capabilities: CameraCapabilities { get }

    // MARK: - Lifecycle
    func connect() async throws
    func disconnect()

    // MARK: - Streaming
    func startStreaming() async throws
    func stopStreaming()

    // MARK: - Frame Capture
    func getLatestFrame() async -> Data?

    // MARK: - Configuration
    func setFrameRate(_ fps: Int) throws

    // MARK: - Preview (Optional - only for local camera)
    var captureSession: AVCaptureSession? { get }
}

enum CameraSourceState: String {
    case disconnected
    case connecting
    case connected
    case streaming
    case error
}

struct CameraCapabilities {
    let supportsZoom: Bool
    let supportsFocus: Bool
    let supportsFlash: Bool
    let supportsRecording: Bool
    let supportsPhotoCapture: Bool
    let maxFrameRate: Int
    let availableResolutions: [VideoResolution]
}
```

## CameraSourceManager

Singleton that manages camera source switching:

```swift
// CameraSourceManager.swift
class CameraSourceManager: ObservableObject {
    static let shared = CameraSourceManager()

    // MARK: - Published Properties
    @Published private(set) var currentSourceType: CameraSourceType = .local
    @Published private(set) var state: CameraSourceState = .disconnected
    @Published private(set) var error: CameraError?

    // MARK: - Sources
    private var localSource: LocalCameraSource?
    private var veepaSource: VeepaCameraSource?

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupLocalSource()
    }

    // MARK: - Public API

    var currentSource: CameraSourceProtocol? {
        switch currentSourceType {
        case .local:
            return localSource
        case .veepaWiFi:
            return veepaSource
        }
    }

    func switchTo(_ sourceType: CameraSourceType) async throws {
        // Disconnect current source
        currentSource?.disconnect()

        currentSourceType = sourceType
        state = .connecting

        // Connect new source
        switch sourceType {
        case .local:
            try await setupAndConnectLocal()
        case .veepaWiFi:
            try await setupAndConnectVeepa()
        }
    }

    func getLatestFrame() async -> Data? {
        return await currentSource?.getLatestFrame()
    }

    // MARK: - Private Methods

    private func setupLocalSource() {
        localSource = LocalCameraSource()
        bindSourceState(localSource!)
    }

    private func setupAndConnectLocal() async throws {
        if localSource == nil {
            setupLocalSource()
        }
        try await localSource?.connect()
    }

    private func setupAndConnectVeepa() async throws {
        if veepaSource == nil {
            veepaSource = VeepaCameraSource()
            bindSourceState(veepaSource!)
        }
        try await veepaSource?.connect()
    }

    private func bindSourceState(_ source: CameraSourceProtocol) {
        source.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.state = newState
            }
            .store(in: &cancellables)
    }
}
```

## LocalCameraSource

Implementation using AVFoundation:

```swift
// LocalCameraSource.swift
class LocalCameraSource: CameraSourceProtocol {
    // MARK: - State
    private let stateSubject = CurrentValueSubject<CameraSourceState, Never>(.disconnected)
    var state: CameraSourceState { stateSubject.value }
    var statePublisher: AnyPublisher<CameraSourceState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    // MARK: - Capabilities
    var capabilities: CameraCapabilities {
        CameraCapabilities(
            supportsZoom: true,
            supportsFocus: true,
            supportsFlash: true,
            supportsRecording: true,
            supportsPhotoCapture: true,
            maxFrameRate: 60,
            availableResolutions: [.hd720, .hd1080, .uhd4K]
        )
    }

    // MARK: - AVFoundation
    private(set) var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var movieOutput: AVCaptureMovieFileOutput?

    // MARK: - Frame Buffer
    private var latestFrame: Data?
    private let frameQueue = DispatchQueue(label: "com.scisymbiolens.framequeue")

    // MARK: - Lifecycle

    func connect() async throws {
        stateSubject.send(.connecting)

        // Check permission
        guard await checkCameraPermission() else {
            throw CameraError.permissionDenied
        }

        // Configure session
        try await configureSession()

        stateSubject.send(.connected)
    }

    func disconnect() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        photoOutput = nil
        movieOutput = nil
        stateSubject.send(.disconnected)
    }

    // MARK: - Streaming

    func startStreaming() async throws {
        guard state == .connected || state == .streaming else {
            throw CameraError.sessionNotRunning
        }

        if captureSession?.isRunning == false {
            captureSession?.startRunning()
        }

        stateSubject.send(.streaming)
    }

    func stopStreaming() {
        captureSession?.stopRunning()
        stateSubject.send(.connected)
    }

    // MARK: - Frame Capture

    func getLatestFrame() async -> Data? {
        return await withCheckedContinuation { continuation in
            frameQueue.async {
                continuation.resume(returning: self.latestFrame)
            }
        }
    }

    // MARK: - Configuration

    func setFrameRate(_ fps: Int) throws {
        guard let device = AVCaptureDevice.default(for: .video) else {
            throw CameraError.deviceNotFound
        }

        try device.lockForConfiguration()
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        device.unlockForConfiguration()
    }

    // MARK: - Private Methods

    private func checkCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func configureSession() async throws {
        let session = AVCaptureSession()
        session.beginConfiguration()

        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            throw CameraError.inputConfigurationFailed
        }
        session.addInput(videoInput)

        // Add video output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
        guard session.canAddOutput(videoOutput) else {
            throw CameraError.outputConfigurationFailed
        }
        session.addOutput(videoOutput)
        self.videoOutput = videoOutput

        // Add photo output
        let photoOutput = AVCapturePhotoOutput()
        guard session.canAddOutput(photoOutput) else {
            throw CameraError.outputConfigurationFailed
        }
        session.addOutput(photoOutput)
        self.photoOutput = photoOutput

        // Add movie output
        let movieOutput = AVCaptureMovieFileOutput()
        guard session.canAddOutput(movieOutput) else {
            throw CameraError.outputConfigurationFailed
        }
        session.addOutput(movieOutput)
        self.movieOutput = movieOutput

        session.commitConfiguration()
        self.captureSession = session
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension LocalCameraSource: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        let uiImage = UIImage(cgImage: cgImage)
        latestFrame = uiImage.jpegData(compressionQuality: 0.7)
    }
}
```

## VeepaCameraSource

Implementation using Flutter bridge:

```swift
// VeepaCameraSource.swift
class VeepaCameraSource: CameraSourceProtocol {
    // MARK: - State
    private let stateSubject = CurrentValueSubject<CameraSourceState, Never>(.disconnected)
    var state: CameraSourceState { stateSubject.value }
    var statePublisher: AnyPublisher<CameraSourceState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    // MARK: - Capabilities
    var capabilities: CameraCapabilities {
        CameraCapabilities(
            supportsZoom: false,  // Veepa cameras have limited zoom
            supportsFocus: false,
            supportsFlash: false,
            supportsRecording: false,  // Recording done via streaming
            supportsPhotoCapture: false,
            maxFrameRate: 30,
            availableResolutions: [.hd720, .hd1080]
        )
    }

    // MARK: - No AVCaptureSession (frames come from Flutter)
    var captureSession: AVCaptureSession? { nil }

    // MARK: - Dependencies
    private let connectionBridge: VeepaConnectionBridge
    private let frameBridge: VeepaFrameBridge
    private let credentialService: P2PCredentialService

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Auto-reconnect
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    init(
        connectionBridge: VeepaConnectionBridge = VeepaConnectionBridge(),
        frameBridge: VeepaFrameBridge = VeepaFrameBridge(),
        credentialService: P2PCredentialService = .shared
    ) {
        self.connectionBridge = connectionBridge
        self.frameBridge = frameBridge
        self.credentialService = credentialService

        setupBindings()
    }

    // MARK: - Lifecycle

    func connect() async throws {
        stateSubject.send(.connecting)

        // Ensure Flutter engine is running
        FlutterEngineManager.shared.initialize()

        // Load cached credentials
        guard let credentials = credentialService.loadCredentials() else {
            throw VeepaConnectionError.noCredentials
        }

        // Get last connected device
        guard let device = credentialService.lastConnectedDevice else {
            throw VeepaConnectionError.noDevice
        }

        // Connect via Flutter bridge
        try await connectionBridge.connect(device: device, credentials: credentials)

        stateSubject.send(.connected)
        reconnectAttempts = 0
    }

    func disconnect() {
        reconnectTask?.cancel()
        connectionBridge.disconnect()
        frameBridge.stopStreaming()
        stateSubject.send(.disconnected)
    }

    // MARK: - Streaming

    func startStreaming() async throws {
        guard state == .connected else {
            throw CameraError.sessionNotRunning
        }

        frameBridge.startStreaming()
        stateSubject.send(.streaming)
    }

    func stopStreaming() {
        frameBridge.stopStreaming()
        if connectionBridge.connectionState == .connected {
            stateSubject.send(.connected)
        }
    }

    // MARK: - Frame Capture

    func getLatestFrame() async -> Data? {
        return frameBridge.getLatestFrame()
    }

    // MARK: - Configuration

    func setFrameRate(_ fps: Int) throws {
        // Veepa SDK may have limited frame rate control
        // This is a no-op or sends command to device
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Monitor connection state from bridge
        connectionBridge.$connectionState
            .sink { [weak self] bridgeState in
                self?.handleBridgeStateChange(bridgeState)
            }
            .store(in: &cancellables)
    }

    private func handleBridgeStateChange(_ bridgeState: VeepaConnectionState) {
        switch bridgeState {
        case .disconnected:
            if state == .streaming || state == .connected {
                // Unexpected disconnect - attempt reconnect
                attemptReconnect()
            }
        case .connecting:
            stateSubject.send(.connecting)
        case .connected:
            stateSubject.send(.connected)
        case .error:
            stateSubject.send(.error)
            attemptReconnect()
        }
    }

    private func attemptReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            stateSubject.send(.error)
            return
        }

        reconnectTask?.cancel()
        reconnectTask = Task {
            reconnectAttempts += 1
            let delay = UInt64(pow(2.0, Double(reconnectAttempts))) * 1_000_000_000
            try? await Task.sleep(nanoseconds: delay)

            guard !Task.isCancelled else { return }

            do {
                try await connect()
            } catch {
                // Will trigger another reconnect via state change
            }
        }
    }
}
```

## CameraManager (AVFoundation Layer)

Lower-level camera orchestration for the local camera:

```swift
// CameraManager.swift (simplified)
class CameraManager: NSObject, ObservableObject {
    static let shared = CameraManager()

    // MARK: - Published State
    @Published var isRecording = false
    @Published var isSessionRunning = false
    @Published var zoomLevel: CGFloat = 1.0
    @Published var focusPoint: CGPoint?
    @Published var lastCapturedPhotoURL: URL?
    @Published var lastRecordedVideoURL: URL?
    @Published var error: CameraError?

    // MARK: - AVFoundation
    let session = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()

    // MARK: - Queues
    private let sessionQueue = DispatchQueue(label: "com.scisymbiolens.camera.session")

    // MARK: - Session Management

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                }
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }

    // MARK: - Recording

    func startRecordingVideo() async throws {
        guard !isRecording else {
            throw CameraError.sessionAlreadyRunning
        }

        let outputURL = generateVideoURL()

        sessionQueue.async { [weak self] in
            self?.movieOutput.startRecording(to: outputURL, recordingDelegate: self!)
        }

        await MainActor.run {
            isRecording = true
        }
    }

    func stopRecordingVideo() async {
        sessionQueue.async { [weak self] in
            self?.movieOutput.stopRecording()
        }
    }

    // MARK: - Photo Capture

    func capturePhoto() async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let settings = AVCapturePhotoSettings()
            // Configure settings...

            self.photoCaptureCompletion = { result in
                continuation.resume(with: result)
            }

            sessionQueue.async {
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    // MARK: - Zoom

    func setZoom(_ factor: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }

        let clampedFactor = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor))

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedFactor
            device.unlockForConfiguration()

            DispatchQueue.main.async {
                self.zoomLevel = clampedFactor
            }
        } catch {
            self.error = .configurationFailed
        }
    }

    // MARK: - Focus

    func focus(at point: CGPoint) {
        guard let device = videoDeviceInput?.device,
              device.isFocusPointOfInterestSupported else { return }

        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
            device.unlockForConfiguration()

            DispatchQueue.main.async {
                self.focusPoint = point
            }
        } catch {
            self.error = .configurationFailed
        }
    }

    // MARK: - Resolution

    func setResolution(_ resolution: VideoResolution) throws {
        guard let device = videoDeviceInput?.device else {
            throw CameraError.deviceNotFound
        }

        session.beginConfiguration()

        switch resolution {
        case .hd720:
            session.sessionPreset = .hd1280x720
        case .hd1080:
            session.sessionPreset = .hd1920x1080
        case .uhd4K:
            session.sessionPreset = .hd4K3840x2160
        }

        session.commitConfiguration()
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isRecording = false

            if let error = error {
                self.error = .unknown(error)
            } else {
                self.lastRecordedVideoURL = outputFileURL
            }
        }
    }
}
```

## Camera Source Switching Flow

```
User selects Veepa camera
         │
         ▼
┌─────────────────────────────────────────┐
│ CameraSourceManager.switchTo(.veepaWiFi)│
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Disconnect current source               │
│ (LocalCameraSource.disconnect())        │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Initialize Flutter if needed            │
│ (FlutterEngineManager.initialize())     │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Load cached P2P credentials             │
│ (P2PCredentialService.loadCredentials())│
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Connect via Flutter bridge              │
│ (VeepaConnectionBridge.connect())       │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Start frame streaming                   │
│ (VeepaFrameBridge.startStreaming())     │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Frames available for preview/AI         │
└─────────────────────────────────────────┘
```

## Veepa Camera Provisioning

First-time pairing workflow:

```
User scans camera QR code
         │
         ▼
┌─────────────────────────────────────────┐
│ Parse device info from QR               │
│ (Device ID, type, capabilities)         │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Generate WiFi config QR                 │
│ (VeepaProvisioningBridge)               │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ User shows QR to camera                 │
│ (Camera connects to WiFi network)       │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Camera appears on LAN                   │
│ (VeepaDiscoveryBridge detects it)       │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Establish P2P connection                │
│ (Username: admin, Password: 888888)     │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Store credentials for future use        │
│ (P2PCredentialService.saveCredentials())│
└─────────────────────────────────────────┘
```

## Frame Capture Pipeline

### Local Camera

```
AVCaptureSession
    │
    ▼ (CMSampleBuffer)
AVCaptureVideoDataOutputSampleBufferDelegate
    │
    ▼ (Convert to Data)
LocalCameraSource.latestFrame
    │
    ▼ (getLatestFrame())
CameraSourceManager
    │
    ▼
StreamingService (for Gemini)
```

### Veepa Camera

```
Veepa SDK (Flutter)
    │
    ▼ (Uint8List via EventChannel)
VeepaFrameBridge
    │
    ▼ (Store in buffer)
VeepaCameraSource.getLatestFrame()
    │
    ▼
CameraSourceManager
    │
    ▼
StreamingService (for Gemini)
```

## Error Handling

```swift
// CameraError.swift
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
            return "Unknown camera error: \(error.localizedDescription)"
        }
    }
}

// VeepaConnectionError.swift
enum VeepaConnectionError: LocalizedError {
    case noCredentials
    case noDevice
    case connectionFailed(String)
    case streamingFailed(String)
    case timeout
    case maxReconnectAttemptsExceeded

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
        }
    }
}
```

## Performance Characteristics

| Metric | Local Camera | Veepa Camera |
|--------|--------------|--------------|
| Preview Latency | <50ms | 100-200ms |
| Frame Rate | Up to 60 fps | Up to 30 fps |
| Resolution | Up to 4K | Up to 1080p |
| Connection Time | Immediate | 2-5 seconds |
| Auto-reconnect | N/A | Yes (with backoff) |

---

*Last updated: January 2026*
