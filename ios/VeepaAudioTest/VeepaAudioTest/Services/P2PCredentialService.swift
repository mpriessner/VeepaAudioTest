// ADAPTED FROM: SciSymbioLens/ios/SciSymbioLens/SciSymbioLens/Services/P2PCredentialService.swift
// Changes: Replaced Logger calls with print statements
//
import Foundation

/// Service for fetching and caching P2P credentials from Veepa cloud APIs
/// These credentials are required to establish P2P connection with the camera
@MainActor
class P2PCredentialService: ObservableObject {
    // MARK: - Cloud API Endpoints

    private static let vuidLookupURL = "https://vuid.eye4.cn"
    private static let initStringURL = "https://authentication.eye4.cn/getInitstring"

    // MARK: - Published State

    @Published var isFetching = false
    @Published var fetchProgress: String = ""
    @Published var credentials: P2PCredentials?
    @Published var errorMessage: String?

    // MARK: - Fetch Credentials

    /// Fetch all credentials for a camera UID
    /// This calls two cloud APIs:
    /// 1. vuid.eye4.cn - converts virtual UID to real clientId
    /// 2. authentication.eye4.cn - gets P2P initialization string
    func fetchCredentials(cameraUid: String) async -> P2PCredentials? {
        guard !isFetching else {
            print("[P2PCredentialService] Already fetching")
            return nil
        }

        isFetching = true
        fetchProgress = "Looking up camera..."
        errorMessage = nil

        print("[P2PCredentialService] Fetching credentials for: \(cameraUid)")

        // Step 1: Fetch real clientId from virtual UID
        fetchProgress = "Resolving camera ID..."
        guard let (clientId, supplier, cluster) = await fetchClientId(virtualUid: cameraUid) else {
            isFetching = false
            return nil
        }

        print("[P2PCredentialService] Got clientId: \(clientId.prefix(8))...")

        // Step 2: Fetch serviceParam using clientId prefix
        fetchProgress = "Fetching connection key..."
        let prefix = String(clientId.prefix(4))
        guard let serviceParam = await fetchServiceParam(uidPrefix: prefix) else {
            isFetching = false
            return nil
        }

        print("[P2PCredentialService] Got serviceParam: \(serviceParam.prefix(20))...")

        // Step 3: Create and cache credentials
        let creds = P2PCredentials(
            cameraUid: cameraUid,
            clientId: clientId,
            serviceParam: serviceParam,
            password: nil, // Will be set during camera login
            cachedAt: Date(),
            supplier: supplier,
            cluster: cluster
        )

        // Validate before caching
        if let validationError = creds.validate() {
            errorMessage = "Invalid credentials: \(validationError)"
            isFetching = false
            return nil
        }

        // Cache credentials
        fetchProgress = "Saving credentials..."
        saveCredentials(creds)

        credentials = creds
        isFetching = false
        fetchProgress = "Done!"

        print("[P2PCredentialService] ✅ Successfully fetched and cached credentials")
        return creds
    }

    // MARK: - API Calls

    /// Fetch real clientId from virtual UID
    /// GET https://vuid.eye4.cn?vuid={virtualUID}
    /// Returns: { "uid": "real_client_id", "supplier": "...", "cluster": "..." }
    private func fetchClientId(virtualUid: String) async -> (clientId: String, supplier: String?, cluster: String?)? {
        guard let url = URL(string: "\(Self.vuidLookupURL)?vuid=\(virtualUid)") else {
            errorMessage = "Invalid UID format"
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid server response"
                return nil
            }

            print("[P2PCredentialService] vuid.eye4.cn HTTP \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                errorMessage = "Server error: HTTP \(httpResponse.statusCode)"
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                errorMessage = "Invalid JSON response"
                return nil
            }

            guard let uid = json["uid"] as? String, !uid.isEmpty else {
                errorMessage = "Camera not found in cloud"
                return nil
            }

            let supplier = json["supplier"] as? String
            let cluster = json["cluster"] as? String

            return (uid, supplier, cluster)

        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
            print("[P2PCredentialService] ❌ fetchClientId error: \(error)")
            return nil
        }
    }

    /// Fetch P2P service param (initialization string)
    /// POST https://authentication.eye4.cn/getInitstring
    /// Body: { "uid": ["{prefix}"] }
    /// Returns: ["service_param_string"]
    private func fetchServiceParam(uidPrefix: String) async -> String? {
        guard let url = URL(string: Self.initStringURL) else {
            errorMessage = "Invalid API URL"
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = ["uid": [uidPrefix]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid server response"
                return nil
            }

            print("[P2PCredentialService] authentication.eye4.cn HTTP \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                errorMessage = "Server error: HTTP \(httpResponse.statusCode)"
                return nil
            }

            // Response is a JSON array: ["service_param_string"]
            guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  let serviceParam = jsonArray.first as? String,
                  !serviceParam.isEmpty else {
                errorMessage = "Invalid service param response"
                return nil
            }

            return serviceParam

        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
            print("[P2PCredentialService] ❌ fetchServiceParam error: \(error)")
            return nil
        }
    }

    // MARK: - Cache Management

    /// Save credentials to UserDefaults
    func saveCredentials(_ credentials: P2PCredentials) {
        let key = P2PCredentials.storageKey(for: credentials.cameraUid)

        if let data = try? JSONEncoder().encode(credentials) {
            UserDefaults.standard.set(data, forKey: key)
            print("[P2PCredentialService] Saved to cache: \(key)")
        }
    }

    /// Load cached credentials for a camera
    func loadCredentials(cameraUid: String) -> P2PCredentials? {
        let key = P2PCredentials.storageKey(for: cameraUid)

        guard let data = UserDefaults.standard.data(forKey: key),
              let credentials = try? JSONDecoder().decode(P2PCredentials.self, from: data) else {
            return nil
        }

        print("[P2PCredentialService] Loaded from cache: \(key)")
        return credentials
    }

    /// Check if credentials exist for a camera
    func hasCredentials(cameraUid: String) -> Bool {
        loadCredentials(cameraUid: cameraUid) != nil
    }

    /// Delete cached credentials
    func deleteCredentials(cameraUid: String) {
        let key = P2PCredentials.storageKey(for: cameraUid)
        UserDefaults.standard.removeObject(forKey: key)
        print("[P2PCredentialService] Deleted from cache: \(key)")
    }

    /// Get all cached camera UIDs
    func getAllCachedCameraUIDs() -> [String] {
        let prefix = "p2p_credentials_"
        return UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    // MARK: - Reset

    func reset() {
        isFetching = false
        fetchProgress = ""
        credentials = nil
        errorMessage = nil
    }
}
