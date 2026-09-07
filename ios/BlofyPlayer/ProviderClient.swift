import Foundation

actor ProviderClient {
    static let shared = ProviderClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 35
        config.timeoutIntervalForResource = 180
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 5
        return URLSession(configuration: config)
    }()

    private func requestData(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("BLOFY-PLAYER-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json,text/plain,*/*", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AppError.message("السيرفر رفض الطلب")
        }
        return data
    }

    private func apiURL(_ provider: Playlist, action: String? = nil, extra: [String: String] = [:]) throws -> URL {
        let base = provider.url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: base + "/player_api.php") else {
            throw AppError.message("رابط السيرفر غير صالح")
        }
        var query = [
            URLQueryItem(name: "username", value: provider.username),
            URLQueryItem(name: "password", value: provider.password)
        ]
        if let action { query.append(URLQueryItem(name: "action", value: action)) }
        extra.sorted(by: { $0.key < $1.key }).forEach { query.append(URLQueryItem(name: $0.key, value: $0.value)) }
        components.queryItems = query
        guard let url = components.url else { throw AppError.message("تعذر تكوين طلب السيرفر") }
        return url
    }

    func loadCatalog(_ provider: Playlist, progress: @escaping @Sendable (Double, String) async -> Void) async throws -> ([MediaCategory], [MediaItem]) {
        if provider.type == "m3u" { return try await loadM3U(provider, progress: progress) }

        await progress(0.04, "التحقق من الاشتراك")
        let authData = try await requestData(apiURL(provider))
        guard let root = try JSONSerialization.jsonObject(with: authData) as? [String: Any],
              let info = root["user_info"] as? [String: Any] else {
            throw AppError.message("استجابة Xtream غير صحيحة")
        }
        let auth = string(info["auth"])
        let status = string(info["status"]).lowercased()
        guard auth == "1" || auth == "true", !["expired", "disabled", "banned"].contains(status) else {
            throw AppError.message("بيانات الاشتراك غير صحيحة أو الاشتراك منتهي")
        }

        var categories: [MediaCategory] = []
        var items: [MediaItem] = []
        let jobs: [(ContentKind, String, String)] = [
            (.live, "get_live_categories", "get_live_streams"),
            (.movie, "get_vod_categories", "get_vod_streams"),
            (.series, "get_series_categories", "get_series")
        ]

        for (index, job) in jobs.enumerated() {
            let (kind, categoryAction, itemAction) = job
            await progress(0.12 + Double(index) * 0.27, "تحميل \(kind.title)")
            let categoryData = try await requestData(apiURL(provider, action: categoryAction))
            let itemData = try await requestData(apiURL(provider, action: itemAction))

            if let rows = try JSONSerialization.jsonObject(with: categoryData) as? [[String: Any]] {
                for row in rows {
                    let key = string(row["category_id"])
                    guard !key.isEmpty else { continue }
                    categories.append(MediaCategory(key: key, name: first(string(row["category_name"]), key), kind: kind))
                }
            }

            guard let rows = try JSONSerialization.jsonObject(with: itemData) as? [[String: Any]] else {
                throw AppError.message("تعذر قراءة \(kind.title)")
            }
            for row in rows {
                let remote = string(row[kind == .series ? "series_id" : "stream_id"])
                guard !remote.isEmpty else { continue }
                let category = first(string(row["category_id"]), "uncategorized")
                items.append(MediaItem(
                    id: "\(kind.rawValue):\(remote)",
                    remoteID: remote,
                    kind: kind,
                    name: first(string(row["name"]), remote),
                    categoryID: category,
                    poster: first(string(row["stream_icon"]), string(row["cover"])),
                    container: first(string(row["container_extension"]), "mp4"),
                    directURL: string(row["direct_source"]),
                    plot: string(row["plot"]),
                    rating: first(string(row["rating"]), string(row["rating_5based"]))
                ))
            }
        }

        for item in items where !categories.contains(where: { $0.kind == item.kind && $0.key == item.categoryID }) {
            categories.append(MediaCategory(key: item.categoryID, name: "بدون تصنيف", kind: item.kind))
        }
        guard !items.isEmpty else { throw AppError.message("السيرفر أعاد قوائم فارغة") }
        await progress(0.96, "تجهيز الواجهة")
        return (categories, items)
    }

    func loadEpisodes(series: MediaItem, provider: Playlist) async throws -> [MediaItem] {
        guard provider.type == "xtream" else { return [] }
        let data = try await requestData(apiURL(provider, action: "get_series_info", extra: ["series_id": series.remoteID]))
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], let raw = root["episodes"] else {
            throw AppError.message("تعذر قراءة حلقات المسلسل")
        }
        var output: [MediaItem] = []
        if let dictionary = raw as? [String: Any] {
            let keys = dictionary.keys.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
            for key in keys {
                if let rows = dictionary[key] as? [[String: Any]] { appendEpisodes(rows, seasonKey: key, series: series, output: &output) }
            }
        } else if let rows = raw as? [[String: Any]] {
            appendEpisodes(rows, seasonKey: "1", series: series, output: &output)
        }
        return output.sorted { $0.season == $1.season ? $0.episode < $1.episode : $0.season < $1.season }
    }

    private func appendEpisodes(_ rows: [[String: Any]], seasonKey: String, series: MediaItem, output: inout [MediaItem]) {
        for (index, row) in rows.enumerated() {
            let remote = first(string(row["id"]), string(row["stream_id"]))
            guard !remote.isEmpty else { continue }
            let info = row["info"] as? [String: Any] ?? [:]
            let season = Int(first(string(row["season"]), seasonKey)) ?? 1
            let episode = Int(string(row["episode_num"])) ?? index + 1
            output.append(MediaItem(
                id: "episode:\(remote)", remoteID: remote, kind: .episode,
                name: first(string(row["title"]), "\(series.name) · S\(season) E\(episode)"),
                categoryID: series.categoryID, poster: first(string(info["movie_image"]), series.poster),
                container: first(string(row["container_extension"]), string(info["container_extension"]), "mp4"),
                directURL: string(row["direct_source"]), plot: string(info["plot"]), seriesID: series.id,
                season: season, episode: episode
            ))
        }
    }

    func movieInfo(movie: MediaItem, provider: Playlist) async throws -> MediaItem {
        guard provider.type == "xtream" else { return movie }
        let data = try await requestData(apiURL(provider, action: "get_vod_info", extra: ["vod_id": movie.remoteID]))
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return movie }
        let info = root["info"] as? [String: Any] ?? [:]
        let movieData = root["movie_data"] as? [String: Any] ?? [:]
        var result = movie
        result.plot = first(string(info["plot"]), string(info["description"]), movie.plot)
        result.poster = first(string(info["movie_image"]), movie.poster)
        result.rating = first(string(info["rating"]), movie.rating)
        result.container = first(string(movieData["container_extension"]), movie.container)
        return result
    }

    private func loadM3U(_ provider: Playlist, progress: @escaping @Sendable (Double, String) async -> Void) async throws -> ([MediaCategory], [MediaItem]) {
        guard let url = URL(string: provider.url) else { throw AppError.message("رابط M3U غير صالح") }
        await progress(0.15, "تحميل M3U")
        let data = try await requestData(url)
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw AppError.message("ترميز M3U غير مدعوم")
        }
        var categories: [MediaCategory] = []
        var items: [MediaItem] = []
        var name = ""
        var group = "بدون تصنيف"
        var logo = ""
        var seenCategories = Set<String>()
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = String(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("#EXTINF:") {
                name = line.split(separator: ",", maxSplits: 1).last.map(String.init) ?? "Stream"
                group = attribute("group-title", in: line) ?? "بدون تصنيف"
                logo = attribute("tvg-logo", in: line) ?? ""
                continue
            }
            if line.isEmpty || line.hasPrefix("#") { continue }
            let clean = line.split(separator: "|", maxSplits: 1).first.map(String.init) ?? line
            guard let streamURL = URL(string: clean) else { continue }
            let ext = streamURL.pathExtension.lowercased()
            let kind: ContentKind = ["mp4", "mkv", "avi", "mov", "m4v", "webm"].contains(ext) ? .movie : .live
            let categoryMarker = "\(kind.rawValue):\(group)"
            if seenCategories.insert(categoryMarker).inserted { categories.append(MediaCategory(key: group, name: group, kind: kind)) }
            items.append(MediaItem(id: "m3u:\(clean)", remoteID: clean, kind: kind, name: name.isEmpty ? streamURL.lastPathComponent : name, categoryID: group, poster: logo, container: ext.isEmpty ? "mp4" : ext, directURL: clean))
            name = ""; logo = ""
        }
        guard !items.isEmpty else { throw AppError.message("قائمة M3U فارغة أو غير صالحة") }
        await progress(0.95, "تجهيز القوائم")
        return (categories, items)
    }

    private func attribute(_ name: String, in line: String) -> String? {
        let token = "\(name)=\""
        guard let range = line.range(of: token) else { return nil }
        let tail = line[range.upperBound...]
        guard let end = tail.firstIndex(of: "\"") else { return nil }
        return String(tail[..<end])
    }

    private func string(_ value: Any?) -> String {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return ""
    }

    private func first(_ values: String...) -> String { values.first(where: { !$0.isEmpty }) ?? "" }
}
