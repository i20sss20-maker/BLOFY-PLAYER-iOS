import Foundation

actor PortalClient {
    static let shared = PortalClient()
    static let baseURL = "https://blofy-player-2-0.vercel.app"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 18
        config.timeoutIntervalForResource = 35
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    private func post(path: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: Self.baseURL + path) else { throw AppError.message("رابط خدمة BLOFY غير صالح") }

        var lastError: Error?
        for attempt in 0..<3 {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("BLOFY-PLAYER-iOS/\(appVersion) (\(buildNumber))", forHTTPHeaderField: "User-Agent")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw AppError.message("تعذر الاتصال بخدمة BLOFY")
                }

                if (200...299).contains(http.statusCode) {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        throw AppError.message("استجابة خدمة BLOFY غير صالحة")
                    }
                    return json
                }

                if http.statusCode == 429 || (500...599).contains(http.statusCode) {
                    lastError = AppError.message("خدمة BLOFY مشغولة مؤقتًا")
                    if attempt < 2 {
                        try? await Task.sleep(nanoseconds: UInt64(450_000_000 * (attempt + 1)))
                        continue
                    }
                }
                throw AppError.message("تعذر الاتصال بخدمة BLOFY")
            } catch {
                lastError = error
                if attempt < 2, let urlError = error as? URLError,
                   [.timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost].contains(urlError.code) {
                    try? await Task.sleep(nanoseconds: UInt64(450_000_000 * (attempt + 1)))
                    continue
                }
                throw error
            }
        }
        throw lastError ?? AppError.message("تعذر الاتصال بخدمة BLOFY")
    }

    func checkActivation(deviceID: String, code: String) async throws -> (status: String, expiresAt: Double?) {
        let json = try await post(path: "/api/v1/activation/check", body: [
            "deviceId": deviceID,
            "activationCode": code,
            "appVersion": "\(appVersion)-ios",
            "buildNumber": buildNumber,
            "platform": "ios"
        ])
        let status = (json["status"] as? String ?? "unknown").lowercased()
        let expires = (json["expiresAt"] as? NSNumber)?.doubleValue
        return (status, expires)
    }

    func portalPlaylists(deviceID: String, code: String) async throws -> [Playlist] {
        let json = try await post(path: "/api/v1/portal/playlists/list", body: ["deviceId": deviceID, "activationCode": code])
        guard let rows = json["items"] as? [[String: Any]] else { throw AppError.message("تعذر قراءة قوائم الموقع") }
        return rows.compactMap { row in
            guard let type = row["providerType"] as? String,
                  let base = row["baseUrl"] as? String,
                  ["xtream", "m3u"].contains(type.lowercased()) else { return nil }
            let name = (row["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "BLOFY Playlist"
            let user = row["username"] as? String ?? ""
            let pass = row["password"] as? String ?? ""
            return Playlist(name: name, type: type.lowercased(), url: base, username: user, password: pass, liveFormat: "ts")
        }
    }

    static func activationPortalURL(deviceID: String, code: String) -> URL? {
        var components = URLComponents(string: baseURL)
        components?.fragment = "deviceId=\(deviceID)&code=\(code)"
        return components?.url
    }
}
