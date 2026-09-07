import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var playlists: [Playlist] = []
    @Published var selected: Playlist?
    @Published var categories: [MediaCategory] = []
    @Published var items: [MediaItem] = []
    @Published var favorites: Set<String> = []
    @Published var resume: [String: ResumeEntry] = [:]
    @Published var loading = false
    @Published var progress: Double = 0
    @Published var status = ""
    @Published var error = ""
    @Published var language = "ar"
    @Published var autoPlayLive = true
    @Published var liveFormat = "ts"
    @Published var deviceID = ""
    @Published var activationCode = ""
    @Published var activationStatus = ""
    private var loadedSource = ""

    init() {
        loadLocal()
        ensureIdentity()
    }

    private func loadLocal() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "playlists"), let value = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = value
            selected = value.first
        }
        if let data = defaults.data(forKey: "favorites"), let value = try? JSONDecoder().decode(Set<String>.self, from: data) { favorites = value }
        if let data = defaults.data(forKey: "resume"), let value = try? JSONDecoder().decode([String: ResumeEntry].self, from: data) { resume = value }
        language = defaults.string(forKey: "language") ?? "ar"
        autoPlayLive = defaults.object(forKey: "autoPlayLive") as? Bool ?? true
        liveFormat = defaults.string(forKey: "liveFormat") ?? "ts"
    }

    private func ensureIdentity() {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: "deviceID"), let code = defaults.string(forKey: "activationCode") {
            deviceID = existing
            activationCode = code
            return
        }
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var rng = SystemRandomNumberGenerator()
        let raw = String((0..<8).map { _ in alphabet.randomElement(using: &rng)! })
        deviceID = "BLOFY-\(raw.prefix(4))-\(raw.suffix(4))"
        activationCode = String(Int.random(in: 100000...999999, using: &rng))
        defaults.set(deviceID, forKey: "deviceID")
        defaults.set(activationCode, forKey: "activationCode")
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(language, forKey: "language")
        defaults.set(autoPlayLive, forKey: "autoPlayLive")
        defaults.set(liveFormat, forKey: "liveFormat")
    }

    func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlists) { UserDefaults.standard.set(data, forKey: "playlists") }
    }

    private func saveLibrary() {
        if let data = try? JSONEncoder().encode(favorites) { UserDefaults.standard.set(data, forKey: "favorites") }
        if let data = try? JSONEncoder().encode(resume) { UserDefaults.standard.set(data, forKey: "resume") }
    }

    func addPlaylist(name: String, type: String, url: String, username: String, password: String) {
        error = ""
        var normalizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedURL.contains("://") { normalizedURL = "http://" + normalizedURL }
        guard let parsed = URL(string: normalizedURL), parsed.host != nil else { error = "الرابط غير صالح"; return }
        if type == "xtream" && (username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty) {
            error = "أدخل اسم المستخدم وكلمة المرور"
            return
        }
        let provider = Playlist(
            name: name.isEmpty ? "BLOFY Playlist" : name,
            type: type,
            url: normalizedURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            liveFormat: liveFormat
        )
        playlists.append(provider)
        selected = provider
        loadedSource = ""
        savePlaylists()
    }

    func delete(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        if selected?.id == playlist.id {
            selected = playlists.first
            clearCatalog()
        }
        savePlaylists()
    }

    func choose(_ playlist: Playlist) {
        selected = playlist
        if loadedSource != sourceKey(playlist) { clearCatalog() }
    }

    func clearCatalog() {
        categories.removeAll()
        items.removeAll()
        loadedSource = ""
    }

    private func sourceKey(_ playlist: Playlist) -> String { "\(playlist.type)|\(playlist.url)|\(playlist.username)" }

    func toggleFavorite(_ item: MediaItem) {
        if favorites.contains(item.id) { favorites.remove(item.id) } else { favorites.insert(item.id) }
        saveLibrary()
    }

    func updateResume(item: MediaItem, seconds: Double, duration: Double) {
        guard item.kind == .movie || item.kind == .episode else { return }
        if duration > 0 && seconds / duration > 0.93 { resume.removeValue(forKey: item.id) }
        else if seconds >= 10 { resume[item.id] = ResumeEntry(seconds: seconds, duration: duration, item: item) }
        saveLibrary()
    }

    func loadCatalog(force: Bool = false) async {
        guard let provider = selected else { return }
        if !force && loadedSource == sourceKey(provider) && !items.isEmpty { return }
        loading = true
        error = ""
        progress = 0.02
        status = "الاتصال بالسيرفر"
        do {
            let result = try await ProviderClient.shared.loadCatalog(provider) { value, text in
                await MainActor.run { self.progress = value; self.status = text }
            }
            categories = result.0
            items = result.1
            loadedSource = sourceKey(provider)
            progress = 1
            status = "تم تحميل القوائم"
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func episodes(for series: MediaItem) async throws -> [MediaItem] {
        guard let provider = selected else { return [] }
        return try await ProviderClient.shared.loadEpisodes(series: series, provider: provider)
    }

    func detailedMovie(_ movie: MediaItem) async -> MediaItem {
        guard let provider = selected else { return movie }
        return (try? await ProviderClient.shared.movieInfo(movie: movie, provider: provider)) ?? movie
    }

    func playbackURL(for item: MediaItem) throws -> URL {
        guard let provider = selected else { throw AppError.message("لا توجد قائمة محددة") }
        if provider.type == "m3u" {
            guard let url = URL(string: item.directURL) else { throw AppError.message("رابط التشغيل غير صالح") }
            return url
        }
        let base = provider.url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let folder = item.kind == .live ? "live" : (item.kind == .episode ? "series" : "movie")
        let ext = item.kind == .live ? provider.liveFormat : (item.container.isEmpty ? "mp4" : item.container)
        let raw = "\(base)/\(folder)/\(provider.username)/\(provider.password)/\(item.remoteID).\(ext)"
        guard let url = URL(string: raw) else { throw AppError.message("تعذر تكوين رابط التشغيل") }
        return url
    }

    func setLiveFormat(_ format: String) {
        liveFormat = format
        guard var provider = selected, let index = playlists.firstIndex(where: { $0.id == provider.id }) else { saveSettings(); return }
        provider.liveFormat = format
        playlists[index] = provider
        selected = provider
        savePlaylists()
        saveSettings()
    }
}
