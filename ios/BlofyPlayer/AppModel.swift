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
    @Published var preferredEngine = "auto"
    @Published var bufferProfile = "balanced"
    @Published var showChannelLogos = true
    @Published var showRatings = true
    @Published var hapticsEnabled = true
    @Published var deviceID = ""
    @Published var activationCode = ""
    @Published var activationStatus = ""

    private var loadedSource = ""
    private var completedStages = Set<String>()
    private var syncGeneration = UUID()
    private var interruptedSync = false

    private struct CatalogCheckpoint: Codable {
        var source: String
        var categories: [MediaCategory]
        var items: [MediaItem]
        var completedStages: [String]
        var progress: Double
        var status: String
        var completed: Bool
        var updatedAt: Date
    }

    init() {
        loadLocal()
        ensureIdentity()
    }

    private func loadLocal() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "playlists"), let value = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = value
            if let savedID = defaults.string(forKey: "selectedPlaylistID"), let uuid = UUID(uuidString: savedID), let saved = value.first(where: { $0.id == uuid }) {
                selected = saved
            } else {
                selected = value.first
            }
        }
        if let data = defaults.data(forKey: "favorites"), let value = try? JSONDecoder().decode(Set<String>.self, from: data) { favorites = value }
        if let data = defaults.data(forKey: "resume"), let value = try? JSONDecoder().decode([String: ResumeEntry].self, from: data) { resume = value }
        language = defaults.string(forKey: "language") ?? "ar"
        autoPlayLive = defaults.object(forKey: "autoPlayLive") as? Bool ?? true
        liveFormat = defaults.string(forKey: "liveFormat") ?? "ts"
        preferredEngine = defaults.string(forKey: "preferredEngine") ?? "auto"
        bufferProfile = defaults.string(forKey: "bufferProfile") ?? "balanced"
        showChannelLogos = defaults.object(forKey: "showChannelLogos") as? Bool ?? true
        showRatings = defaults.object(forKey: "showRatings") as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: "hapticsEnabled") as? Bool ?? true
        restoreCheckpointIfPossible()
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
        let raw = String((0..<8).compactMap { _ in alphabet.randomElement(using: &rng) })
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
        defaults.set(preferredEngine, forKey: "preferredEngine")
        defaults.set(bufferProfile, forKey: "bufferProfile")
        defaults.set(showChannelLogos, forKey: "showChannelLogos")
        defaults.set(showRatings, forKey: "showRatings")
        defaults.set(hapticsEnabled, forKey: "hapticsEnabled")
    }

    func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlists) { UserDefaults.standard.set(data, forKey: "playlists") }
        if let selected { UserDefaults.standard.set(selected.id.uuidString, forKey: "selectedPlaylistID") }
        else { UserDefaults.standard.removeObject(forKey: "selectedPlaylistID") }
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
        let provider = Playlist(name: name.isEmpty ? "BLOFY Playlist" : name, type: type, url: normalizedURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")), username: username.trimmingCharacters(in: .whitespacesAndNewlines), password: password, liveFormat: liveFormat)
        playlists.append(provider)
        selected = provider
        clearCatalog()
        savePlaylists()
    }

    func delete(_ playlist: Playlist) {
        CatalogCacheStore.remove(for: playlist.id)
        UserDefaults.standard.removeObject(forKey: checkpointKey(for: playlist))
        playlists.removeAll { $0.id == playlist.id }
        if selected?.id == playlist.id {
            selected = playlists.first
            clearCatalog()
            restoreCheckpointIfPossible()
        }
        savePlaylists()
    }

    func choose(_ playlist: Playlist) {
        guard selected?.id != playlist.id else { return }
        selected = playlist
        savePlaylists()
        clearCatalog()
        restoreCheckpointIfPossible()
    }

    func clearCatalog() {
        // Invalidate callbacks before releasing the loading gate. A request from
        // the previous playlist may still finish after the user switches servers.
        syncGeneration = UUID()
        loading = false
        categories.removeAll(); items.removeAll(); completedStages.removeAll(); loadedSource = ""; progress = 0; status = ""; error = ""; interruptedSync = false
    }

    // Portal merges retain playlist IDs, but Playlist is a value type: refresh
    // the selected copy too, and never reuse an in-flight catalog after a login change.
    func updateSelectedPlaylist(_ updated: Playlist) {
        guard let current = selected, current.id == updated.id else { return }
        let connectionChanged = current.type != updated.type || current.url != updated.url ||
            current.username != updated.username || current.password != updated.password
        selected = updated
        guard connectionChanged else { return }
        clearCatalog()
        CatalogCacheStore.remove(for: updated.id)
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: checkpointKey(for: updated))
        if let legacy = defaults.data(forKey: "catalogCheckpoint"),
           let old = try? JSONDecoder().decode(CatalogCheckpoint.self, from: legacy),
           old.source == sourceKey(current) || old.source == sourceKey(updated) {
            defaults.removeObject(forKey: "catalogCheckpoint")
        }
    }

    private func sourceKey(_ playlist: Playlist) -> String { "\(playlist.type)|\(playlist.url)|\(playlist.username)" }
    private func checkpointKey(for playlist: Playlist) -> String { "catalogCheckpoint.\(playlist.id.uuidString)" }
    private func expectedStages(for provider: Playlist) -> Set<String> { provider.type == "m3u" ? ["m3u"] : [ContentKind.live.rawValue, ContentKind.movie.rawValue, ContentKind.series.rawValue] }

    private func persistCheckpoint(completed: Bool = false) {
        guard let provider = selected else { return }
        let checkpoint = CatalogCheckpoint(source: sourceKey(provider), categories: categories, items: items, completedStages: Array(completedStages), progress: progress, status: status, completed: completed, updatedAt: Date())
        guard let data = try? JSONEncoder().encode(checkpoint) else { return }
        CatalogCacheStore.save(data, for: provider.id)

        // Clean up the old heavy UserDefaults representation once disk persistence succeeds.
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: checkpointKey(for: provider))
        if let legacy = defaults.data(forKey: "catalogCheckpoint"),
           let old = try? JSONDecoder().decode(CatalogCheckpoint.self, from: legacy),
           old.source == checkpoint.source {
            defaults.removeObject(forKey: "catalogCheckpoint")
        }
    }

    private func restoreCheckpointIfPossible() {
        guard let provider = selected else { return }
        let defaults = UserDefaults.standard
        var data = CatalogCacheStore.load(for: provider.id)

        if data == nil {
            // One-time migration from older builds that stored full catalogs in UserDefaults.
            data = defaults.data(forKey: checkpointKey(for: provider))
            if data == nil, let legacy = defaults.data(forKey: "catalogCheckpoint"),
               let old = try? JSONDecoder().decode(CatalogCheckpoint.self, from: legacy),
               old.source == sourceKey(provider) {
                data = legacy
            }
            if let data {
                CatalogCacheStore.save(data, for: provider.id)
                defaults.removeObject(forKey: checkpointKey(for: provider))
                if let legacy = defaults.data(forKey: "catalogCheckpoint"),
                   let old = try? JSONDecoder().decode(CatalogCheckpoint.self, from: legacy),
                   old.source == sourceKey(provider) {
                    defaults.removeObject(forKey: "catalogCheckpoint")
                }
            }
        }

        guard let data, let checkpoint = try? JSONDecoder().decode(CatalogCheckpoint.self, from: data), checkpoint.source == sourceKey(provider) else { return }
        categories = checkpoint.categories; items = checkpoint.items; completedStages = Set(checkpoint.completedStages); progress = checkpoint.progress; status = checkpoint.status
        if checkpoint.completed || completedStages.isSuperset(of: expectedStages(for: provider)) {
            loadedSource = checkpoint.source; progress = 1; status = "القوائم جاهزة"
        } else if !items.isEmpty || !completedStages.isEmpty {
            interruptedSync = true; status = "تم استعادة التقدم المحفوظ"
        }
    }

    func toggleFavorite(_ item: MediaItem) {
        if favorites.contains(item.id) { favorites.remove(item.id) } else { favorites.insert(item.id) }
        saveLibrary()
    }

    func updateResume(item: MediaItem, seconds: Double, duration: Double) {
        guard item.kind == .movie || item.kind == .episode else { return }
        guard seconds.isFinite, duration.isFinite else { return }
        if duration > 0 && seconds / duration > 0.93 { resume.removeValue(forKey: item.id) }
        else if seconds >= 10 { resume[item.id] = ResumeEntry(seconds: max(0, seconds), duration: max(0, duration), item: item) }
        if resume.count > 250 {
            let keep = resume.values.sorted { $0.updatedAt > $1.updatedAt }.prefix(200)
            resume = Dictionary(uniqueKeysWithValues: keep.map { ($0.item.id, $0) })
        }
        saveLibrary()
    }

    func loadCatalog(force: Bool = false) async {
        guard let provider = selected else { return }
        if loading { return }
        let source = sourceKey(provider); let expected = expectedStages(for: provider)
        if !force && loadedSource == source && !items.isEmpty { return }
        if !force && completedStages.isSuperset(of: expected) && !items.isEmpty { loadedSource = source; progress = 1; status = "القوائم جاهزة"; persistCheckpoint(completed: true); return }
        if force {
            categories.removeAll(); items.removeAll(); completedStages.removeAll(); loadedSource = ""; progress = 0; status = ""
            CatalogCacheStore.remove(for: provider.id)
            UserDefaults.standard.removeObject(forKey: checkpointKey(for: provider))
        }
        loading = true; interruptedSync = false; error = ""; if progress <= 0 { progress = 0.01 }; status = completedStages.isEmpty ? "الاتصال بالسيرفر" : "متابعة التحميل من آخر مرحلة"
        let token = UUID(); syncGeneration = token
        do {
            let result = try await ProviderClient.shared.loadCatalog(provider, cachedCategories: categories, cachedItems: items, completedStages: completedStages, progress: { value, text in
                await MainActor.run { guard self.syncGeneration == token, self.selected?.id == provider.id else { return }; self.progress = max(self.progress, value); self.status = text }
            }, checkpoint: { savedCategories, savedItems, stages, value, text in
                await MainActor.run { guard self.syncGeneration == token, self.selected?.id == provider.id else { return }; self.categories = savedCategories; self.items = savedItems; self.completedStages = stages; self.progress = max(self.progress, value); self.status = text; self.persistCheckpoint(completed: false) }
            })
            guard syncGeneration == token, selected?.id == provider.id else { return }
            categories = result.0; items = result.1; completedStages = expected; loadedSource = source; progress = 1; status = "تم تحميل القوائم بالكامل"; loading = false; interruptedSync = false; persistCheckpoint(completed: true)
        } catch {
            guard syncGeneration == token, selected?.id == provider.id else { return }
            self.error = error.localizedDescription; self.status = "توقف التحميل مؤقتًا · سنكمل من آخر مرحلة محفوظة"; self.loading = false; self.interruptedSync = true; persistCheckpoint(completed: false)
        }
    }

    func pauseSyncForBackground() {
        guard loading else { return }
        syncGeneration = UUID(); loading = false; interruptedSync = true; status = "تم حفظ التقدم · نكمل عند الرجوع للتطبيق"; persistCheckpoint(completed: false)
    }

    func resumeSyncIfNeeded() async {
        guard let provider = selected else { return }
        let incomplete = !completedStages.isSuperset(of: expectedStages(for: provider))
        if interruptedSync || (incomplete && (!items.isEmpty || !completedStages.isEmpty)) { await loadCatalog() }
    }

    func episodes(for series: MediaItem) async throws -> [MediaItem] { guard let provider = selected else { return [] }; return try await ProviderClient.shared.loadEpisodes(series: series, provider: provider) }
    func detailedMovie(_ movie: MediaItem) async -> MediaItem { guard let provider = selected else { return movie }; return (try? await ProviderClient.shared.movieInfo(movie: movie, provider: provider)) ?? movie }

    func playbackURL(for item: MediaItem) throws -> URL {
        guard let provider = selected else { throw AppError.message("لا توجد قائمة محددة") }
        if provider.type == "m3u" { guard let url = URL(string: item.directURL) else { throw AppError.message("رابط التشغيل غير صالح") }; return url }
        let base = provider.url.trimmingCharacters(in: CharacterSet(charactersIn: "/")); let folder = item.kind == .live ? "live" : (item.kind == .episode ? "series" : "movie"); let ext = item.kind == .live ? provider.liveFormat : (item.container.isEmpty ? "mp4" : item.container); let raw = "\(base)/\(folder)/\(provider.username)/\(provider.password)/\(item.remoteID).\(ext)"
        guard let url = URL(string: raw) else { throw AppError.message("تعذر تكوين رابط التشغيل") }; return url
    }

    func setLiveFormat(_ format: String) {
        liveFormat = format
        guard var provider = selected, let index = playlists.firstIndex(where: { $0.id == provider.id }) else { saveSettings(); return }
        provider.liveFormat = format; playlists[index] = provider; selected = provider; savePlaylists(); saveSettings()
    }
}
