import Foundation
import UIKit
import CryptoKit

// MARK: - Models (tetap kompatibel dengan UI lama)

struct LicenseState: Codable {
    let key: String
    let expiresAt: Date
    let activatedAt: Date

    var isValid: Bool {
        Date() < expiresAt
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0)
    }
}

// MARK: - KeyAuth Config
// Di-port dari KeyAuth_KeyVault (1).cs -> Swift.
// ⚠️ SECRET KAMU SUDAH BOCOR DI CHAT — regenerate di dashboard KeyAuth setelah tes!

enum KeyAuthConfig {
    static let name = "PHONE CIT"
    static let ownerid = "0145869089"
    static let secret = "b463cc80d279c84d1963c1bc11ced231f7d947df45ae1355fae5a4eb860e2f68"
    static let version = "1.0"
    static let apiURL = "https://www.keyauth-manager.online/api/1.3/"
}

// MARK: - LicenseService (KeyAuth)

final class LicenseService: ObservableObject {

    static let shared = LicenseService()

    @Published var licenseState: LicenseState?
    @Published var isChecking = false
    @Published var lastError: String?

    private let stateKey = "regsxd_license_state"
    private let deviceID: String = {
        if let saved = UserDefaults.standard.string(forKey: "regsxd_device_id") {
            return saved
        }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: "regsxd_device_id")
        return id
    }()

    // KeyAuth session
    private var sessionid: String?
    private var sentKey: String?
    private var enckeyFull: String?
    private var initialized = false

    private init() {
        loadSavedState()
    }

    // MARK: - Public (API sama seperti sebelumnya, UI tidak perlu diubah)

    /// Validate key via KeyAuth: init() -> license(key)
    func validate(key: String) async -> Bool {
        await MainActor.run { isChecking = true; lastError = nil }

        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            await MainActor.run { isChecking = false; lastError = "Key kosong" }
            return false
        }

        do {
            try await ensureInit()

            let resp = try await keyAuthRequest(type: "license", extra: [
                "key": cleanKey,
                "hwid": deviceID
            ])

            guard let success = resp["success"] as? Bool, success else {
                let msg = (resp["message"] as? String) ?? "Invalid License Key."
                await MainActor.run {
                    isChecking = false
                    lastError = msg
                    licenseState = nil
                }
                clearState()
                return false
            }

            // Ambil expiry dari info.subscriptions[0].expiry (unix seconds, bisa String/Int)
            let expiresAt = Self.parseExpiry(from: resp) ?? Date().addingTimeInterval(86400)

            let state = LicenseState(key: cleanKey.uppercased(), expiresAt: expiresAt, activatedAt: Date())
            saveState(state)
            await MainActor.run { self.licenseState = state; isChecking = false }
            return true

        } catch {
            // Offline fallback — pakai cache kalau masih valid
            if let cached = licenseState, cached.isValid {
                await MainActor.run { isChecking = false }
                return true
            }
            await MainActor.run {
                isChecking = false
                lastError = (error as? LocalizedError)?.errorDescription ?? "Network error. Check your connection."
            }
            return false
        }
    }

    func logout() {
        clearState()
        DispatchQueue.main.async { self.licenseState = nil }
        // session tetap, tidak perlu re-init. Kalau mau force: initialized = false
    }

    // MARK: - KeyAuth core (port dari api.cs)

    private func ensureInit() async throws {
        if initialized, sessionid != nil { return }

        let newSentKey = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16))
        // C#: Guid.NewGuid().ToString().Substring(0,16) — 16 char pertama
        let fullUUID = UUID().uuidString // xxxxxxxx-xxxx-...
        let csharpStyle = String(fullUUID.prefix(16))
        sentKey = csharpStyle.isEmpty ? newSentKey : csharpStyle
        enckeyFull = "\(sentKey!)-\(KeyAuthConfig.secret)"

        let resp = try await keyAuthRequest(type: "init", extra: [
            "ver": KeyAuthConfig.version,
            "enckey": sentKey!
        ], isInit: true)

        if let success = resp["success"] as? Bool, success == false,
           let msg = resp["message"] as? String, msg.contains("not found") {
            throw KeyAuthError.appNotFound
        }

        guard let sid = resp["sessionid"] as? String, !sid.isEmpty else {
            throw KeyAuthError.noSession
        }
        sessionid = sid
        initialized = true
    }

    /// POST form-urlencoded ke KeyAuth, return JSON dict. Sekalian sigCheck kalau ada header signature.
    private func keyAuthRequest(type: String, extra: [String: String], isInit: Bool = false) async throws -> [String: Any] {
        guard let url = URL(string: KeyAuthConfig.apiURL) else {
            throw KeyAuthError.badURL
        }

        var params: [String: String] = [
            "type": type,
            "name": KeyAuthConfig.name,
            "ownerid": KeyAuthConfig.ownerid
        ]
        for (k, v) in extra { params[k] = v }
        if !isInit {
            guard let sid = sessionid else { throw KeyAuthError.noSession }
            params["sessionid"] = sid
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = params.map { k, v in
            "\(k)=\(v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v)"
        }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw KeyAuthError.network
        }

        let raw = String(data: data, encoding: .utf8) ?? ""

        // sigCheck (opsional — skip kalau server custom tidak kirim signature)
        if let sig = http.value(forHTTPHeaderField: "signature") ?? http.value(forHTTPHeaderField: "Signature"),
           let full = enckeyFull {
            let hmacKey: String = isInit ? KeyAuthConfig.secret : full
            let computed = Self.hmacSHA256(key: hmacKey, message: raw)
            if computed.lowercased() != sig.lowercased() {
                throw KeyAuthError.badSignature
            }
        }

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KeyAuthError.badResponse(raw)
        }
        return obj
    }

    // MARK: - Helpers

    static func hmacSHA256(key: String, message: String) -> String {
        let keyData = Data(key.utf8)
        let msgData = Data(message.utf8)
        let mac = HMAC<SHA256>.authenticationCode(for: msgData, using: SymmetricKey(data: keyData))
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    /// subscriptions[0].expiry bisa String ("1735689600") atau Int. Return Date atau nil.
    static func parseExpiry(from resp: [String: Any]) -> Date? {
        guard let info = resp["info"] as? [String: Any],
              let subs = info["subscriptions"] as? [[String: Any]],
              let first = subs.first else { return nil }

        var seconds: TimeInterval?
        if let s = first["expiry"] as? String { seconds = TimeInterval(s) }
        else if let i = first["expiry"] as? Int { seconds = TimeInterval(i) }
        else if let i64 = first["expiry"] as? Int64 { seconds = TimeInterval(i64) }
        else if let d = first["expiry"] as? Double { seconds = d }

        guard let sec = seconds, sec > 0 else { return nil }
        return Date(timeIntervalSince1970: sec)
    }

    // MARK: - Cache

    private func saveState(_ state: LicenseState) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: stateKey)
        }
    }

    private func loadSavedState() {
        guard let data = UserDefaults.standard.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(LicenseState.self, from: data),
              state.isValid else {
            clearState()
            return
        }
        licenseState = state
    }

    private func clearState() {
        UserDefaults.standard.removeObject(forKey: stateKey)
    }
}

enum KeyAuthError: LocalizedError {
    case badURL, network, appNotFound, noSession, badSignature, badResponse(String)
    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid KeyAuth URL"
        case .network: return "Network error. Check your connection."
        case .appNotFound: return "Application not found (cek name/ownerid)"
        case .noSession: return "Gagal init session KeyAuth"
        case .badSignature: return "Signature check gagal (session tampered)"
        case .badResponse(let r): return r.isEmpty ? "Invalid server response" : r
        }
    }
}
