import Foundation

enum PlaybackResolver {
    static func candidates(provider: Playlist, item: MediaItem) throws -> [URL] {
        var raw: [String] = []

        if provider.type == "m3u" {
            if let resolved = resolveInternalHost(providerBase: provider.url, source: item.directURL) { raw.append(resolved) }
            if !item.directURL.isEmpty { raw.append(item.directURL) }
            return try urls(raw)
        }

        let base = provider.url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let folder: String
        switch item.kind {
        case .live: folder = "live"
        case .episode: folder = "series"
        default: folder = "movie"
        }

        let userEncoded = encode(provider.username)
        let passEncoded = encode(provider.password)
        let idEncoded = encode(item.remoteID)
        let userRaw = provider.username
        let passRaw = provider.password
        let idRaw = item.remoteID

        if item.kind == .live {
            let ext = safeExtension(provider.liveFormat.isEmpty ? "ts" : provider.liveFormat)
            let primary = "\(base)/\(folder)/\(userEncoded)/\(passEncoded)/\(idEncoded).\(ext)"
            raw.append(primary)
            if let alternate = alternateLiveFormat(primary) { raw.append(alternate) }
        } else {
            // Xtream panels are inconsistent about the VOD/episode container extension.
            // Try the server-reported extension first, then the common commercial variants.
            var extensions: [String] = []
            let reported = safeExtension(item.container)
            for ext in [reported, "mp4", "mkv", "ts", "m3u8"] where !extensions.contains(ext) {
                extensions.append(ext)
            }

            for ext in extensions {
                raw.append("\(base)/\(folder)/\(userEncoded)/\(passEncoded)/\(idEncoded).\(ext)")
            }

            // A few Xtream-compatible panels reject percent-encoded path credentials.
            if userRaw != userEncoded || passRaw != passEncoded || idRaw != idEncoded {
                for ext in extensions.prefix(3) {
                    raw.append("\(base)/\(folder)/\(userRaw)/\(passRaw)/\(idRaw).\(ext)")
                }
            }

            // Some panels accept the stream id without a suffix.
            raw.append("\(base)/\(folder)/\(userEncoded)/\(passEncoded)/\(idEncoded)")
        }

        if let direct = resolveInternalHost(providerBase: provider.url, source: item.directURL), !direct.isEmpty {
            // Direct source should be tried early for VOD when the panel provides it.
            if item.kind == .movie || item.kind == .episode { raw.insert(direct, at: 0) }
            else { raw.append(direct) }
        } else if !item.directURL.isEmpty, !isClearlyInternalHost(of: item.directURL) {
            if item.kind == .movie || item.kind == .episode { raw.insert(item.directURL, at: 0) }
            else { raw.append(item.directURL) }
        }

        return try urls(raw)
    }

    private static func urls(_ values: [String]) throws -> [URL] {
        var seen = Set<String>()
        let result = values.compactMap { value -> URL? in
            guard let url = URL(string: value), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil else { return nil }
            guard seen.insert(url.absoluteString).inserted else { return nil }
            return url
        }
        guard !result.isEmpty else { throw AppError.message("تعذر تكوين أي مسار تشغيل صالح") }
        return result
    }

    static func alternateLiveFormat(_ value: String) -> String? {
        guard var components = URLComponents(string: value) else { return nil }
        let path = components.path
        if path.lowercased().hasSuffix(".m3u8") {
            components.path = String(path.dropLast(5)) + ".ts"
        } else if path.lowercased().hasSuffix(".ts") {
            components.path = String(path.dropLast(3)) + ".m3u8"
        } else { return nil }
        return components.url?.absoluteString
    }

    static func resolveInternalHost(providerBase: String, source: String) -> String? {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              var sourceParts = URLComponents(string: source),
              let sourceHost = sourceParts.host,
              let providerHost = URLComponents(string: providerBase)?.host else { return nil }
        if isClearlyInternal(sourceHost), !isClearlyInternal(providerHost) {
            sourceParts.host = providerHost
            return sourceParts.url?.absoluteString
        }
        return sourceParts.url?.absoluteString ?? source
    }

    static func isClearlyInternalHost(of value: String) -> Bool {
        guard let host = URLComponents(string: value)?.host else { return true }
        return isClearlyInternal(host)
    }

    static func isClearlyInternal(_ host: String) -> Bool {
        let h = host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        if h.isEmpty || h == "localhost" || h.hasSuffix(".localhost") || h.hasSuffix(".local") || h.hasSuffix(".internal") || h.hasSuffix(".lan") || h.hasSuffix(".home") || h.hasSuffix(".home.arpa") { return true }
        let parts = h.split(separator: ".").compactMap { Int($0) }
        if parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) {
            let a = parts[0], b = parts[1]
            return a == 0 || a == 10 || a == 127 || (a == 100 && (64...127).contains(b)) || (a == 169 && b == 254) || (a == 172 && (16...31).contains(b)) || (a == 192 && b == 168) || a >= 224
        }
        if h.contains(":") { return h == "::1" || h.hasPrefix("fc") || h.hasPrefix("fd") || h.hasPrefix("fe8") || h.hasPrefix("fe9") || h.hasPrefix("fea") || h.hasPrefix("feb") || h.hasPrefix("ff") }
        return !h.contains(".")
    }

    private static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))) ?? value
    }

    private static func safeExtension(_ value: String) -> String {
        let filtered = value.filter { $0.isLetter || $0.isNumber }
        return filtered.isEmpty ? "mp4" : String(filtered.prefix(8)).lowercased()
    }
}
