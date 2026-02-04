// COPIED EXACTLY FROM: SciSymbioLens/Services/VSTCBridge.swift
// Purpose: Advanced SDK diagnostics via dlsym symbol access
// Use: Optional - for debugging P2P session timeouts and keep-alive
//
// THIS FILE MUST BE COPIED EXACTLY - DO NOT MODIFY SYMBOL NAMES
// Symbol names must match libVSTC.a internal implementation
//
import Foundation
import Darwin

/// Bridge to internal VStarcam SDK (libVSTC.a) functions via dlsym
/// Used for Attempt #9: Prevent 3-minute P2P session timeout
///
/// SAFETY: This only reads/writes RAM values in our app's memory space.
/// It does NOT interact with camera firmware or hardware.
@MainActor
final class VSTCBridge {
    static let shared = VSTCBridge()

    // MARK: - Symbol Resolution

    /// Handle to the current process for dlsym lookups
    /// RTLD_DEFAULT (-2) searches all loaded libraries
    private let handle: UnsafeMutableRawPointer? = dlopen(nil, RTLD_LAZY | RTLD_GLOBAL)

    /// Cache of resolved symbols
    private var symbolCache: [String: UnsafeMutableRawPointer] = [:]

    private init() {
        print("[VSTCBridge] Initialized with handle: \(handle != nil ? "valid" : "nil")")
    }

    // MARK: - Symbol Discovery

    /// Attempt to resolve a symbol from libVSTC.a
    /// Returns the raw pointer if found, nil otherwise
    func resolveSymbol(_ name: String) -> UnsafeMutableRawPointer? {
        // Check cache first
        if let cached = symbolCache[name] {
            return cached
        }

        // Try to resolve via dlsym
        guard let h = handle else {
            print("[VSTCBridge] ❌ No valid handle for dlsym")
            return nil
        }

        if let ptr = dlsym(h, name) {
            symbolCache[name] = ptr
            print("[VSTCBridge] ✅ Symbol found: \(name) at \(ptr)")
            return ptr
        } else {
            print("[VSTCBridge] ❌ Symbol not found: \(name)")
            return nil
        }
    }

    /// Check if a symbol exists without caching
    func symbolExists(_ name: String) -> Bool {
        guard let h = handle else { return false }
        return dlsym(h, name) != nil
    }

    // MARK: - Session Timeout Variables

    /// The internal session alive interval in seconds (how often keep-alive is sent)
    /// Symbol: _cs2p2p_gSessAliveSec
    /// Default: 6 (keep-alive sent every 6 seconds)
    var sessionAliveSeconds: Int32 {
        get {
            guard let ptr = resolveSymbol("cs2p2p_gSessAliveSec") else {
                print("[VSTCBridge] ⚠️ Cannot read sessionAliveSeconds - symbol not found")
                return -1
            }
            let value = ptr.assumingMemoryBound(to: Int32.self).pointee
            print("[VSTCBridge] 📖 Read sessionAliveSeconds: \(value)")
            return value
        }
        set {
            guard let ptr = resolveSymbol("cs2p2p_gSessAliveSec") else {
                print("[VSTCBridge] ⚠️ Cannot write sessionAliveSeconds - symbol not found")
                return
            }
            let oldValue = ptr.assumingMemoryBound(to: Int32.self).pointee
            ptr.assumingMemoryBound(to: Int32.self).pointee = newValue
            print("[VSTCBridge] ✏️ Changed sessionAliveSeconds: \(oldValue) → \(newValue)")
        }
    }

    /// The listen timeout - possibly the actual session timeout threshold
    /// Symbol: _cs2p2p_gListenTimeOut
    var listenTimeout: Int32 {
        get {
            guard let ptr = resolveSymbol("cs2p2p_gListenTimeOut") else {
                print("[VSTCBridge] ⚠️ Cannot read listenTimeout - symbol not found")
                return -1
            }
            let value = ptr.assumingMemoryBound(to: Int32.self).pointee
            print("[VSTCBridge] 📖 Read listenTimeout: \(value)")
            return value
        }
        set {
            guard let ptr = resolveSymbol("cs2p2p_gListenTimeOut") else {
                print("[VSTCBridge] ⚠️ Cannot write listenTimeout - symbol not found")
                return
            }
            let oldValue = ptr.assumingMemoryBound(to: Int32.self).pointee
            ptr.assumingMemoryBound(to: Int32.self).pointee = newValue
            print("[VSTCBridge] ✏️ Changed listenTimeout: \(oldValue) → \(newValue)")
        }
    }

    // MARK: - Comprehensive Timeout Configuration

    /// Try ALL possible timeout configurations
    /// Call this before connecting to the camera
    func configureExtendedTimeout(targetSeconds: Int32 = 600) {
        print("[VSTCBridge] ═══════════════════════════════════════")
        print("[VSTCBridge] 🔧 Configuring Extended Timeout (\(targetSeconds)s)")
        print("[VSTCBridge] ═══════════════════════════════════════")

        // 1. Try direct global variable: cs2p2p_gSessAliveSec
        let oldSessAlive = sessionAliveSeconds
        print("[VSTCBridge] 1️⃣ cs2p2p_gSessAliveSec: \(oldSessAlive) → \(targetSeconds)")
        sessionAliveSeconds = targetSeconds

        // 2. Try direct global variable: cs2p2p_gListenTimeOut
        let oldListenTimeout = listenTimeout
        print("[VSTCBridge] 2️⃣ cs2p2p_gListenTimeOut: \(oldListenTimeout) → \(targetSeconds)")
        listenTimeout = targetSeconds

        // 3. Try GlobalParamsSet with various keys
        let keysToSet = [
            "timeoutSec",
            "aliveTimeOut",
            "timeout",
            "sessionTimeout",
            "hbTimeout",
            "maxHBCounter",
        ]

        print("[VSTCBridge] 3️⃣ Trying GlobalParamsSet with various keys...")
        for key in keysToSet {
            let success = trySetParam(key, value: targetSeconds)
            if success {
                print("[VSTCBridge] ✅ GlobalParamsSet('\(key)', \(targetSeconds)) succeeded!")
            }
        }

        // 4. Verify final values
        print("[VSTCBridge] --- Verification ---")
        let finalSessAlive = sessionAliveSeconds
        let finalListenTimeout = listenTimeout
        print("[VSTCBridge] cs2p2p_gSessAliveSec: \(finalSessAlive)")
        print("[VSTCBridge] cs2p2p_gListenTimeOut: \(finalListenTimeout)")

        print("[VSTCBridge] ═══════════════════════════════════════")
    }

    // MARK: - P2P Keep-Alive (Phase 3)

    /// Timer for periodic P2P keep-alive
    private var keepAliveTimer: Timer?
    private var activeClientPtr: Int64 = 0
    private var keepAliveCount: Int = 0

    /// Start sending P2P keep-alive packets every 30 seconds
    /// This calls the internal Send_Pkt_Alive function directly
    func startP2PKeepAlive(clientPtr: Int64) {
        stopP2PKeepAlive()

        activeClientPtr = clientPtr
        keepAliveCount = 0

        print("[VSTCBridge] 🔄 Starting P2P Keep-Alive for clientPtr: \(clientPtr)")

        // Send immediately, then every 30 seconds
        sendP2PKeepAlive()

        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendP2PKeepAlive()
        }
    }

    /// Stop the P2P keep-alive timer
    func stopP2PKeepAlive() {
        if keepAliveTimer != nil {
            print("[VSTCBridge] 🛑 Stopping P2P Keep-Alive (sent \(keepAliveCount) packets)")
        }
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        activeClientPtr = 0
        keepAliveCount = 0
    }

    /// Send a single P2P keep-alive packet
    /// NOTE: Send_Pkt_Alive crashes with clientPtr - needs session context, not clientPtr
    /// Trying CSession_Maintain as alternative
    private func sendP2PKeepAlive() {
        guard activeClientPtr != 0 else {
            print("[VSTCBridge] ⚠️ No active clientPtr for keep-alive")
            return
        }

        keepAliveCount += 1
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)

        // DISABLED: Send_Pkt_Alive crashes - wrong signature/parameters
        // The function needs a session context pointer, not clientPtr
        // Crash occurred in XQ_UdpPktSend
        /*
        typealias SendPktAliveType = @convention(c) (Int64) -> Int32
        if let ptr = resolveSymbol("Send_Pkt_Alive") {
            let sendFunc = unsafeBitCast(ptr, to: SendPktAliveType.self)
            let result = sendFunc(activeClientPtr)
            print("[VSTCBridge] 💓 Send_Pkt_Alive result: \(result)")
        }
        */

        // Try CSession_Maintain as alternative
        typealias CSessionMaintainType = @convention(c) (Int64) -> Int32
        if let ptr = resolveSymbol("CSession_Maintain") {
            let maintainFunc = unsafeBitCast(ptr, to: CSessionMaintainType.self)
            let result = maintainFunc(activeClientPtr)
            print("[VSTCBridge] 💓 P2P KEEP-ALIVE #\(keepAliveCount) at \(timestamp) - CSession_Maintain(\(activeClientPtr)) = \(result)")
        } else {
            print("[VSTCBridge] 💓 P2P KEEP-ALIVE #\(keepAliveCount) at \(timestamp) - No function available")
        }
    }

    /// Alternative: Try calling CSession_Maintain
    func tryCSessionMaintain(clientPtr: Int64) -> Int32 {
        typealias CSessionMaintainType = @convention(c) (Int64) -> Int32

        guard let ptr = resolveSymbol("CSession_Maintain") else {
            print("[VSTCBridge] ❌ CSession_Maintain symbol not found")
            return -1
        }

        let maintainFunc = unsafeBitCast(ptr, to: CSessionMaintainType.self)
        let result = maintainFunc(clientPtr)

        print("[VSTCBridge] 🔧 CSession_Maintain(clientPtr: \(clientPtr)) = \(result)")
        return result
    }

    // MARK: - Diagnostics

    /// Run comprehensive diagnostics to discover available SDK symbols
    func runDiagnostics() -> VSTCDiagnostics {
        print("[VSTCBridge] ═══════════════════════════════════════")
        print("[VSTCBridge] 🔍 Running SDK Symbol Diagnostics")
        print("[VSTCBridge] ═══════════════════════════════════════")

        var diag = VSTCDiagnostics()

        // Primary targets
        let primarySymbols = [
            "cs2p2p_gSessAliveSec",      // Session timeout variable
            "GlobalParamsGet",            // Config getter
            "GlobalParamsSet",            // Config setter
            "Send_Pkt_Alive",             // Keep-alive packet sender
        ]

        // Secondary/diagnostic symbols
        let secondarySymbols = [
            "GlobalParams_Init",
            "GlobalParams_DeInit",
            "P2P_APIVersionGet",
            "P2P_DevHbInfGet",
            "CSession_Maintain",
            "CSession_Alive_Deal",
            "_sessionAliveKeep",
            "_HB_Reset",
            "create_P2pAlive",
            "Send_Pkt_AliveAck",
            "cs2p2p_gListenTimeOut",
        ]

        print("[VSTCBridge] --- Primary Symbols ---")
        for symbol in primarySymbols {
            let found = symbolExists(symbol)
            diag.symbolResults[symbol] = found
            print("[VSTCBridge] \(found ? "✅" : "❌") \(symbol)")
        }

        print("[VSTCBridge] --- Secondary Symbols ---")
        for symbol in secondarySymbols {
            let found = symbolExists(symbol)
            diag.symbolResults[symbol] = found
            print("[VSTCBridge] \(found ? "✅" : "❌") \(symbol)")
        }

        // Try to read the session timeout value
        print("[VSTCBridge] --- Value Read Test ---")
        let timeoutValue = sessionAliveSeconds
        diag.sessionAliveValue = timeoutValue
        if timeoutValue >= 0 {
            print("[VSTCBridge] ✅ sessionAliveSeconds = \(timeoutValue)")
        } else {
            print("[VSTCBridge] ❌ Could not read sessionAliveSeconds")
        }

        print("[VSTCBridge] ═══════════════════════════════════════")
        print("[VSTCBridge] 📊 Summary: \(diag.foundCount)/\(diag.totalCount) symbols found")
        print("[VSTCBridge] ═══════════════════════════════════════")

        return diag
    }

    // MARK: - GlobalParams API (Alternative Approach)

    /// Try to call GlobalParamsGet with a key
    /// Returns (success, value) tuple
    func tryGetParam(_ key: String) -> (success: Bool, value: Int32) {
        // Function signature: int GlobalParamsGet(const char* key, int* value)
        typealias GlobalParamsGetType = @convention(c) (UnsafePointer<CChar>, UnsafeMutablePointer<Int32>) -> Int32

        guard let ptr = resolveSymbol("GlobalParamsGet") else {
            return (false, 0)
        }

        let getFunc = unsafeBitCast(ptr, to: GlobalParamsGetType.self)
        var value: Int32 = 0

        let result = key.withCString { keyPtr in
            getFunc(keyPtr, &value)
        }

        let success = result == 0
        print("[VSTCBridge] GlobalParamsGet('\(key)') = \(value), result: \(result) (\(success ? "success" : "failed"))")
        return (success, value)
    }

    /// Try to call GlobalParamsSet with a key and value
    /// Returns success boolean
    func trySetParam(_ key: String, value: Int32) -> Bool {
        // Function signature: int GlobalParamsSet(const char* key, int value)
        typealias GlobalParamsSetType = @convention(c) (UnsafePointer<CChar>, Int32) -> Int32

        guard let ptr = resolveSymbol("GlobalParamsSet") else {
            return false
        }

        let setFunc = unsafeBitCast(ptr, to: GlobalParamsSetType.self)

        let result = key.withCString { keyPtr in
            setFunc(keyPtr, value)
        }

        let success = result == 0
        print("[VSTCBridge] GlobalParamsSet('\(key)', \(value)) result: \(result) (\(success ? "success" : "failed"))")
        return success
    }

    /// Try multiple parameter keys to find valid ones
    func discoverParams() -> [String: Int32] {
        let keysToTry = [
            "timeoutSec",
            "aliveTimeOut",
            "timeout",
            "sessionTimeout",
            "keepAlive",
            "hbTimeout",
            "sendInterval",
            "maxHBCounter",
        ]

        var found: [String: Int32] = [:]

        print("[VSTCBridge] --- Discovering Parameters ---")
        for key in keysToTry {
            let (success, value) = tryGetParam(key)
            if success {
                found[key] = value
                print("[VSTCBridge] ✅ Found param '\(key)' = \(value)")
            }
        }

        if found.isEmpty {
            print("[VSTCBridge] ❌ No parameters found via GlobalParamsGet")
        }

        return found
    }

    // MARK: - P2P Audio Channel Reading (PROOF OF CONCEPT)

    /// Read raw data from a P2P channel
    ///
    /// This is the low-level function to read data from P2P channels.
    /// For audio, use channel 2 (P2P_AUDIO_CHANNEL)
    ///
    /// Native signature: int client_read(void* clientPtr, int channel, char* buffer, int bufferSize, int timeout)
    ///
    /// @param clientPtr P2P client pointer (as Int, will be cast to pointer)
    /// @param channel Channel number (2 = audio)
    /// @param bufferSize Size of buffer to allocate
    /// @param timeout Timeout in milliseconds
    /// @returns (bytesRead, buffer) where bytesRead > 0 on success, negative on error
    /// Read raw data from a P2P channel
    ///
    /// ATTEMPT #7: Using client_read (internal API) with Pointer Type
    /// Previous attempts:
    ///   - P2P_Read(Int32) crashed at call site
    ///   - P2P_Read(pointer) called successfully but crashed inside (wrong handle type)
    /// NEW: Try client_read which should accept CLIENT handle, not SESSION handle
    ///
    /// See AUDIO_DEBUGGING_LOG.md for full history
    func clientRead(clientPtr: Int, channel: Int, bufferSize: Int, timeout: Int) -> (Int32, [UInt8]) {
        print("[VSTCBridge] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("[VSTCBridge] 🔍 ATTEMPT #7: client_read() with Pointer Type")
        print("[VSTCBridge] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Try client_read - internal function that should work with CLIENT handle
        // P2P_Read expects SESSION handle, client_read expects CLIENT handle
        // Signature: int client_read(void* clientPtr, int channel, char* buffer, int size, int timeout)
        typealias ClientReadType = @convention(c) (UnsafeMutableRawPointer, Int32, UnsafeMutablePointer<UInt8>, Int32, Int32) -> Int32

        print("[VSTCBridge] Step 1: Resolving client_read symbol...")
        guard let funcPtr = resolveSymbol("client_read") else {
            print("[VSTCBridge] ❌ FAILED: client_read symbol not found")
            return (-1, [])
        }
        print("[VSTCBridge] ✅ Symbol resolved at: \(funcPtr)")

        print("[VSTCBridge] Step 2: Casting to function pointer...")
        let readFunc = unsafeBitCast(funcPtr, to: ClientReadType.self)
        print("[VSTCBridge] ✅ Function pointer ready")

        print("[VSTCBridge] Step 3: Allocating buffer (\(bufferSize) bytes)...")
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        print("[VSTCBridge] ✅ Buffer allocated")

        print("[VSTCBridge] Step 4: Preparing parameters...")
        guard let sessionPtr = UnsafeMutableRawPointer(bitPattern: clientPtr) else {
            print("[VSTCBridge] ❌ Failed to convert clientPtr \(clientPtr) to pointer")
            return (-1, [])
        }
        print("[VSTCBridge]    Original clientPtr: \(clientPtr) (0x\(String(clientPtr, radix: 16)))")
        print("[VSTCBridge]    Converted to pointer: \(sessionPtr)")
        print("[VSTCBridge]    Channel: \(channel)")
        print("[VSTCBridge]    Buffer size: \(bufferSize)")
        print("[VSTCBridge]    Timeout: \(timeout) ms")

        print("[VSTCBridge] Step 5: Calling client_read...")
        print("[VSTCBridge] 📡 >>> client_read(clientPtr:\(sessionPtr), ch:\(channel), buf:\(bufferSize), timeout:\(timeout)) <<<")

        // CRITICAL POINT: If this crashes, we never see "Step 6"
        let bytesRead = buffer.withUnsafeMutableBufferPointer { bufferPtr in
            readFunc(sessionPtr, Int32(channel), bufferPtr.baseAddress!, Int32(bufferSize), Int32(timeout))
        }

        // IF WE SEE THIS LOG, THE FUNCTION DIDN'T CRASH!
        print("[VSTCBridge] 🎉 Step 6: client_read RETURNED! Result: \(bytesRead) bytes")
        print("[VSTCBridge] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        if bytesRead > 0 {
            // Return only the bytes that were actually read
            return (bytesRead, Array(buffer.prefix(Int(bytesRead))))
        } else {
            // Error codes:
            // -1: Not connected
            // -3: Timeout
            // -5: Invalid parameter
            // -11: Invalid connection
            // -12: Remote closed
            // -13: Timeout closed
            return (bytesRead, [])
        }
    }

    /// VERIFICATION TEST: Compare channel 1 (video) vs channel 2 (audio)
    ///
    /// This test will prove or disprove the hypothesis that channel 2 never opens
    /// by comparing it against channel 1 which we know works (video is streaming)
    ///
    /// @param clientPtr P2P client pointer from connection
    func verifyChannelStatus(clientPtr: Int) async {
        print("[VSTCBridge] ═══════════════════════════════════════")
        print("[VSTCBridge] 🔬 HYPOTHESIS VERIFICATION TEST")
        print("[VSTCBridge] ═══════════════════════════════════════")
        print("[VSTCBridge] Testing: Does channel 2 actually work?")
        print("[VSTCBridge] Method: Compare video (ch1) vs audio (ch2)")
        print("[VSTCBridge] ═══════════════════════════════════════")

        // Test 1: Read from channel 1 (VIDEO) - should work
        print("[VSTCBridge]")
        print("[VSTCBridge] 📹 TEST 1: Read from Channel 1 (VIDEO)")
        print("[VSTCBridge] Expected: SUCCESS (video is streaming)")
        let (videoBytes, videoBuffer) = clientRead(clientPtr: clientPtr, channel: 1, bufferSize: 4096, timeout: 1000)

        if videoBytes > 0 {
            print("[VSTCBridge] ✅ Channel 1 (VIDEO) works: \(videoBytes) bytes")
            print("[VSTCBridge] Data preview: \(videoBuffer.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))")
        } else {
            print("[VSTCBridge] ❌ Channel 1 (VIDEO) failed: \(videoBytes)")
        }

        // Test 2: Read from channel 2 (AUDIO) with LONG timeout
        print("[VSTCBridge]")
        print("[VSTCBridge] 🎵 TEST 2: Read from Channel 2 (AUDIO)")
        print("[VSTCBridge] Using 5 second timeout (give it time)")
        print("[VSTCBridge] Expected: TIMEOUT or CRASH (if hypothesis correct)")

        let (audioBytes, audioBuffer) = clientRead(clientPtr: clientPtr, channel: 2, bufferSize: 512, timeout: 5000)

        if audioBytes > 0 {
            print("[VSTCBridge] ✅ Channel 2 (AUDIO) works: \(audioBytes) bytes")
            print("[VSTCBridge] Data preview: \(audioBuffer.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))")
            print("[VSTCBridge] 🎉 HYPOTHESIS WRONG - Channel 2 IS working!")
        } else {
            print("[VSTCBridge] ❌ Channel 2 (AUDIO) failed: \(audioBytes)")
            if audioBytes == -3 {
                print("[VSTCBridge] Timeout - no data received in 5 seconds")
            }
        }

        // Test 3: Check SDK symbols for status functions
        print("[VSTCBridge]")
        print("[VSTCBridge] 🔍 TEST 3: Check SDK Status Symbols")
        let hasCheckBuffer = symbolExists("client_check_buffer")
        let hasGetStatus = symbolExists("app_player_get_status")
        let hasChannelStatus = symbolExists("P2P_CheckChannelStatus")

        print("[VSTCBridge] client_check_buffer: \(hasCheckBuffer ? "✅ Found" : "❌ Not found")")
        print("[VSTCBridge] app_player_get_status: \(hasGetStatus ? "✅ Found" : "❌ Not found")")
        print("[VSTCBridge] P2P_CheckChannelStatus: \(hasChannelStatus ? "✅ Found" : "❌ Not found")")

        // Test 4: Try reading audio multiple times with patience
        print("[VSTCBridge]")
        print("[VSTCBridge] 🔁 TEST 4: Multiple Audio Reads (patient)")
        print("[VSTCBridge] Trying 5 reads with 2 second timeout each")

        var successCount = 0
        for i in 1...5 {
            let (bytes, _) = clientRead(clientPtr: clientPtr, channel: 2, bufferSize: 512, timeout: 2000)
            if bytes > 0 {
                successCount += 1
                print("[VSTCBridge] [\(i)/5] ✅ Read \(bytes) bytes")
            } else {
                print("[VSTCBridge] [\(i)/5] ❌ Error: \(bytes)")
            }

            if i < 5 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s between attempts
            }
        }

        print("[VSTCBridge] ═══════════════════════════════════════")
        print("[VSTCBridge] 📊 VERIFICATION RESULTS:")
        print("[VSTCBridge] ═══════════════════════════════════════")
        print("[VSTCBridge] Video Channel (1): \(videoBytes > 0 ? "✅ WORKS" : "❌ FAILED")")
        print("[VSTCBridge] Audio Channel (2): \(audioBytes > 0 ? "✅ WORKS" : "❌ FAILED")")
        print("[VSTCBridge] Audio Success Rate: \(successCount)/5")
        print("[VSTCBridge]")

        if videoBytes > 0 && audioBytes <= 0 {
            print("[VSTCBridge] 🎯 HYPOTHESIS CONFIRMED:")
            print("[VSTCBridge] - Video channel works (SDK is active)")
            print("[VSTCBridge] - Audio channel doesn't work (stream not active)")
            print("[VSTCBridge] - Proves: Channel 2 never actually opened")
            print("[VSTCBridge] - Reason: Error -50 prevented audio stream start")
        } else if videoBytes > 0 && audioBytes > 0 {
            print("[VSTCBridge] 🤔 HYPOTHESIS WRONG:")
            print("[VSTCBridge] - Both channels work!")
            print("[VSTCBridge] - Audio stream IS active")
            print("[VSTCBridge] - Need to investigate why previous attempts crashed")
        } else if videoBytes <= 0 {
            print("[VSTCBridge] ⚠️ INCONCLUSIVE:")
            print("[VSTCBridge] - Video channel also failed")
            print("[VSTCBridge] - May be connection issue, not audio-specific")
        }

        print("[VSTCBridge] ═══════════════════════════════════════")
    }

    /// Test reading audio from P2P channel 2
    ///
    /// PROOF OF CONCEPT - Attempt #7: client_read with Pointer Type
    ///
    /// This attempts to verify:
    /// 1. client_read() works with CLIENT handle (not SESSION handle)
    /// 2. Camera is sending audio data on channel 2
    /// 3. We can receive raw G.711a packets
    ///
    /// HISTORY: See AUDIO_DEBUGGING_LOG.md for previous 6 failed attempts
    ///
    /// @param clientPtr P2P client pointer from connection
    /// @param readCount Number of reads to attempt (default: 10)
    /// @param readInterval Delay between reads in seconds (default: 0.5)
    func testAudioChannelRead(clientPtr: Int, readCount: Int = 10, readInterval: TimeInterval = 0.5) async {
        print("[VSTCBridge] ═══════════════════════════════════════")
        print("[VSTCBridge] 🧪 POC TEST - P2P AUDIO CHANNEL READ")
        print("[VSTCBridge] ═══════════════════════════════════════")
        print("[VSTCBridge] ATTEMPT #7: Using client_read() with Pointer Type")
        print("[VSTCBridge] Client Ptr: \(clientPtr) (0x\(String(clientPtr, radix: 16)))")
        print("[VSTCBridge] Channel: 2 (P2P_AUDIO_CHANNEL)")
        print("[VSTCBridge] Read Count: \(readCount)")
        print("[VSTCBridge] Interval: \(readInterval)s")
        print("[VSTCBridge]")
        print("[VSTCBridge] CHANGE: Using client_read (CLIENT handle) not P2P_Read (SESSION handle)")
        print("[VSTCBridge] Reason: P2P_Read crashed inside - expected SESSION, we have CLIENT")
        print("[VSTCBridge] IF THIS CRASHES:")
        print("[VSTCBridge]   - Try AudioUnit hook approach next")
        print("[VSTCBridge] ═══════════════════════════════════════")

        var successCount = 0
        var totalBytesRead = 0

        for i in 1...readCount {
            // Use smaller buffer and shorter timeout to be safe
            let (bytesRead, buffer) = clientRead(clientPtr: clientPtr, channel: 2, bufferSize: 512, timeout: 100)

            if bytesRead > 0 {
                successCount += 1
                totalBytesRead += Int(bytesRead)

                // Show first few bytes as hex
                let preview = buffer.prefix(min(16, buffer.count)).map { String(format: "%02X", $0) }.joined(separator: " ")
                print("[VSTCBridge] [\(i)/\(readCount)] ✅ Read \(bytesRead) bytes: [\(preview)...]")
            } else {
                let errorMsg: String
                switch bytesRead {
                case -1: errorMsg = "Not connected"
                case -3: errorMsg = "Timeout (no data)"
                case -5: errorMsg = "Invalid parameter"
                case -11: errorMsg = "Invalid connection"
                case -12: errorMsg = "Remote closed"
                case -13: errorMsg = "Timeout closed"
                default: errorMsg = "Unknown error"
                }
                print("[VSTCBridge] [\(i)/\(readCount)] ❌ Error: \(bytesRead) (\(errorMsg))")
            }

            // Wait before next read
            if i < readCount {
                try? await Task.sleep(nanoseconds: UInt64(readInterval * 1_000_000_000))
            }
        }

        print("[VSTCBridge] ═══════════════════════════════════════")
        print("[VSTCBridge] 📊 RESULTS:")
        print("[VSTCBridge]    Success Rate: \(successCount)/\(readCount) (\(successCount * 100 / readCount)%)")
        print("[VSTCBridge]    Total Bytes: \(totalBytesRead)")
        print("[VSTCBridge]    Avg Per Read: \(successCount > 0 ? totalBytesRead / successCount : 0) bytes")
        print("[VSTCBridge] ═══════════════════════════════════════")

        if successCount > 0 {
            print("[VSTCBridge] ✅ PROOF OF CONCEPT SUCCESS!")
            print("[VSTCBridge] Camera IS sending audio data on channel 2")
            print("[VSTCBridge] → Next: Implement full custom audio bridge")
            print("[VSTCBridge]    1. G.711a decoder")
            print("[VSTCBridge]    2. Sample rate converter (8kHz → 48kHz)")
            print("[VSTCBridge]    3. AVAudioEngine playback")
        } else {
            print("[VSTCBridge] ❌ PROOF OF CONCEPT FAILED")
            print("[VSTCBridge] No audio data received from camera")
            print("[VSTCBridge] → Possible causes:")
            print("[VSTCBridge]    1. Camera not streaming audio (need to call start_voice first?)")
            print("[VSTCBridge]    2. Wrong channel number")
            print("[VSTCBridge]    3. P2P connection issue")
        }
    }
}

// MARK: - Diagnostics Result

struct VSTCDiagnostics {
    var symbolResults: [String: Bool] = [:]
    var sessionAliveValue: Int32 = -1

    var foundCount: Int {
        symbolResults.values.filter { $0 }.count
    }

    var totalCount: Int {
        symbolResults.count
    }

    var canReadSessionAlive: Bool {
        sessionAliveValue >= 0
    }

    var hasGlobalParamsAPI: Bool {
        (symbolResults["GlobalParamsGet"] ?? false) && (symbolResults["GlobalParamsSet"] ?? false)
    }

    var hasSendPktAlive: Bool {
        symbolResults["Send_Pkt_Alive"] ?? false
    }
}
