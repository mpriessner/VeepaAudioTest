// ADAPTED FROM: SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Models/P2PCredentials.swift
// Changes: None - copied as-is for Quick Test Mode
//
import Foundation

/// Credentials needed for P2P connection to Veepa camera
/// These are fetched from cloud APIs after camera WiFi provisioning
struct P2PCredentials: Codable {
    /// Virtual UID from camera QR code (e.g., "QW6-T..." or "OKB0379853SNLJ")
    let cameraUid: String

    /// Real device ID from cloud (e.g., "VSTH...")
    let clientId: String

    /// P2P initialization/encryption string from cloud
    let serviceParam: String

    /// Camera login password (usually "888888" or "admin")
    var password: String?

    /// When credentials were cached
    let cachedAt: Date

    /// Cloud service metadata
    let supplier: String?
    let cluster: String?

    // MARK: - Validation

    var isValid: Bool {
        !cameraUid.isEmpty && !clientId.isEmpty && !serviceParam.isEmpty
    }

    func validate() -> String? {
        if cameraUid.isEmpty { return "Camera UID is empty" }
        if clientId.isEmpty { return "Client ID is empty" }
        if clientId.count < 5 { return "Client ID too short" }
        if serviceParam.isEmpty { return "Service param is empty" }
        if serviceParam.count < 20 { return "Service param too short" }
        return nil
    }

    // MARK: - Cache Info

    var cacheAge: TimeInterval {
        Date().timeIntervalSince(cachedAt)
    }

    var cacheAgeDescription: String {
        let age = cacheAge
        if age < 60 { return "just now" }
        if age < 3600 { return "\(Int(age / 60)) min ago" }
        if age < 86400 { return "\(Int(age / 3600)) hours ago" }
        return "\(Int(age / 86400)) days ago"
    }

    // MARK: - Display Helpers

    var maskedClientId: String {
        guard clientId.count > 8 else { return "****" }
        let prefix = String(clientId.prefix(4))
        let suffix = String(clientId.suffix(4))
        return "\(prefix)...\(suffix)"
    }

    var maskedServiceParam: String {
        guard serviceParam.count > 8 else { return "****" }
        let prefix = String(serviceParam.prefix(4))
        let suffix = String(serviceParam.suffix(4))
        return "\(prefix)...\(suffix)"
    }

    // MARK: - Prefix Extraction

    /// Extract prefix for serviceParam lookup (first 4 chars of clientId)
    var clientIdPrefix: String {
        if clientId.count >= 4 {
            return String(clientId.prefix(4))
        }
        return clientId
    }
}

// MARK: - Storage Key

extension P2PCredentials {
    static func storageKey(for cameraUid: String) -> String {
        "p2p_credentials_\(cameraUid)"
    }
}
