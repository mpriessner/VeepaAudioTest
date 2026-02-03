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
