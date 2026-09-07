import SwiftUI
import VLCKit

struct LiveProgram: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let start: Date?
    let end: Date?
    let description: String

    var timeText: String {
        guard let start, let end else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

enum RecentLiveStore {
    private static let key = "recentLiveIDs"

    static func ids() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func record(_ item: MediaItem) {
        guard item.kind == .live else { return }
        var value = ids().filter { $0 != item.id }
        value.insert(item.id, at: 0)
        if value.count > 20 { value = Array(value.prefix(20)) }
        UserDefaults.standard.set(value, forKey: key)
        NotificationCenter.default.post(name: .blofyRecentLiveChanged, object: nil)
    }
}

extension Notification.Name {
    static let blofyRecentLiveChanged = Notification.Name("blofyRecentLiveChanged")
}

actor LiveEPGClient {
    static let shared = LiveEPGClient()

    func programs(for item: MediaItem, provider: Playlist?) async -> [LiveProgram] {
        guard let provider, provider.type == "xtream" else { return [] }
        let base = provider.url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var parts = URLComponents(string: base + "/player_api.php") else { return [] }
        parts.queryItems = [
            URLQueryItem(name: "username", value: provider.username),
            URLQueryItem(name: "password", value: provider.password),
            URLQueryItem(name: "action", value: "get_short_epg"),
            URLQueryItem(name: "stream_id", value: item.remoteID),
            URLQueryItem(name: "limit", value: "2")
        ]
        guard let url = parts.url else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("BLOFY PLAYER/2.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rows = root["epg_listings"] as? [[String: Any]] else { return [] }
            return rows.prefix(2).map { row in
                LiveProgram(
                    title: decodeEPGText(row["title"]) ?? "بدون عنوان",
                    start: epgDate(row["start_timestamp"], fallback: row["start"]),
                    end: epgDate(row["stop_timestamp"], fallback: row["end"]),
                    description: decodeEPGText(row["description"]) ?? ""
                )
            }
        } catch {
            return []
        }
    }

    private func decodeEPGText(_ value: Any?) -> String? {
        guard let raw = value as? String, !raw.isEmpty else { return nil }
        if let data = Data(base64Encoded: raw), let decoded = String(data: data, encoding: .utf8), !decoded.isEmpty {
            return decoded
        }
        return raw
    }

    private func epgDate(_ value: Any?, fallback: Any?) -> Date? {
        if let number = value as? NSNumber { return Date(timeIntervalSince1970: number.doubleValue) }
        if let text = value as? String, let seconds = Double(text) { return Date(timeIntervalSince1970: seconds) }
        guard let text = fallback as? String else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: text)
    }
}

struct LiveExperienceView: View {
    @EnvironmentObject var model: AppModel
    @State private var selectedCategory = "all"
    @State private var query = ""
    @State private var selectedID = ""
    @State private var recentIDs: [String] = RecentLiveStore.ids()
    @State private var programs: [LiveProgram] = []
    @State private var play: PlaybackSession?
    @StateObject private var preview = LivePreviewController()

    private var categories: [MediaCategory] { model.categories.filter { $0.kind == .live } }
    private var allChannels: [MediaItem] { model.items.filter { $0.kind == .live } }
    private var shown: [MediaItem] {
        allChannels.filter {
            (selectedCategory == "all" || $0.categoryID == selectedCategory) &&
            (query.isEmpty || normalizedSearch($0.name).contains(normalizedSearch(query)))
        }
    }
    private var selected: MediaItem? {
        allChannels.first { $0.id == selectedID } ?? shown.first
    }
    private var recentChannels: [MediaItem] {
        recentIDs.compactMap { id in allChannels.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16, pinnedViews: []) {
                    HStack {
                        BlofyBrandMark(compact: true)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("البث المباشر").font(.title2.bold())
                            Text("\(shown.count) قناة").font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    if let selected {
                        LivePreviewHero(item: selected, programs: programs, preview: preview) {
                            watch(selected)
                        }
                        .padding(.horizontal, 16)
                        .task(id: selected.id) { await select(selected, autoplay: true) }
                    }

                    if !recentChannels.isEmpty {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("آخر القنوات").font(.headline.bold()).padding(.horizontal, 16)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(recentChannels.prefix(10)) { item in
                                        Button { selectedID = item.id } label: {
                                            HStack(spacing: 8) {
                                                Poster(url: item.poster).frame(width: 40, height: 32).clipShape(RoundedRectangle(cornerRadius: 8))
                                                Text(item.name).font(.caption.bold()).lineLimit(1).frame(maxWidth: 130)
                                            }
                                            .padding(.horizontal, 10).padding(.vertical, 8)
                                            .background(BlofyTheme.surfaceRaised, in: Capsule())
                                            .overlay(Capsule().stroke(BlofyTheme.divider))
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(BlofyTheme.textPrimary)
                                    }
                                }.padding(.horizontal, 16)
                            }
                        }
                    }

                    HStack(spacing: 9) {
                        Menu {
                            Button("كل الفئات") { selectedCategory = "all" }
                            ForEach(categories) { category in
                                Button(category.name) { selectedCategory = category.key }
                            }
                        } label: {
                            Label(selectedCategory == "all" ? "كل الفئات" : (categories.first { $0.key == selectedCategory }?.name ?? "الفئة"), systemImage: "line.3.horizontal.decrease.circle.fill")
                                .font(.subheadline.bold()).lineLimit(1)
                                .padding(.horizontal, 13).frame(height: 42)
                                .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(BlofyTheme.divider))
                        }
                        Spacer()
                    }.padding(.horizontal, 16)

                    LazyVStack(spacing: 8) {
                        ForEach(shown) { item in
                            LiveSmartRow(item: item, isSelected: selected?.id == item.id) {
                                selectedID = item.id
                            } watch: {
                                watch(item)
                            } favorite: {
                                model.toggleFavorite(item)
                            }
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 30)
                }
            }
            .background(BlofyTheme.backgroundGradient)
            .toolbar(.hidden, for: .navigationBar)
            .searchable(text: $query, prompt: "ابحث عن قناة")
            .refreshable { await model.loadCatalog(force: true) }
            .onAppear {
                recentIDs = RecentLiveStore.ids()
                if selectedID.isEmpty { selectedID = recentChannels.first?.id ?? allChannels.first?.id ?? "" }
            }
            .onReceive(NotificationCenter.default.publisher(for: .blofyRecentLiveChanged)) { _ in recentIDs = RecentLiveStore.ids() }
            .onDisappear { preview.stop() }
            .fullScreenCover(item: $play, onDismiss: {
                if let selected { startPreview(selected) }
            }) { PlayerScreen(session: $0) }
        }
    }

    private func select(_ item: MediaItem, autoplay: Bool) async {
        selectedID = item.id
        programs = await LiveEPGClient.shared.programs(for: item, provider: model.selected)
        if autoplay { startPreview(item) }
    }

    private func startPreview(_ item: MediaItem) {
        guard let session = try? model.makePlaybackSession(for: item), let url = session.candidates.first else { return }
        preview.start(url: url)
    }

    private func watch(_ item: MediaItem) {
        RecentLiveStore.record(item)
        preview.stop()
        do { play = try model.makePlaybackSession(for: item) }
        catch { model.error = error.localizedDescription }
    }
}

private struct LivePreviewHero: View {
    let item: MediaItem
    let programs: [LiveProgram]
    @ObservedObject var preview: LivePreviewController
    let watch: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LiveVLCPreviewSurface(player: preview.player)
                    .frame(height: 210)
                if !preview.ready {
                    Poster(url: item.poster).frame(maxWidth: .infinity).frame(height: 210)
                    ZStack { Color.black.opacity(0.32); ProgressView().tint(BlofyTheme.purpleBright) }
                }
                LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Circle().fill(.red).frame(width: 7, height: 7)
                        Text("LIVE").font(.caption2.bold())
                    }
                    Text(item.name).font(.title3.bold()).lineLimit(2)
                    if let now = programs.first {
                        Text(now.title).font(.caption).foregroundStyle(.white.opacity(0.78)).lineLimit(1)
                    }
                }.padding(14)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    if let now = programs.first {
                        Text("الآن · \(now.timeText)").font(.caption2.bold()).foregroundStyle(BlofyTheme.mint)
                        Text(now.title).font(.subheadline.bold()).lineLimit(1)
                    } else {
                        Text("دليل البرامج غير متوفر").font(.caption).foregroundStyle(BlofyTheme.textMuted)
                    }
                    if programs.count > 1 {
                        let next = programs[1]
                        Text("التالي · \(next.timeText) · \(next.title)").font(.caption2).foregroundStyle(BlofyTheme.textMuted).lineLimit(1)
                    }
                }
                Spacer()
                Button(action: watch) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.headline.bold()).frame(width: 44, height: 44)
                        .background(BlofyTheme.primaryGradient, in: Circle()).foregroundStyle(.white)
                }.buttonStyle(.plain)
            }.padding(12)
        }
        .background(BlofyTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(BlofyTheme.divider))
    }
}

private struct LiveSmartRow: View {
    @EnvironmentObject var model: AppModel
    let item: MediaItem
    let isSelected: Bool
    let select: () -> Void
    let watch: () -> Void
    let favorite: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Button(action: select) {
                HStack(spacing: 11) {
                    Poster(url: item.poster).frame(width: 56, height: 43).clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name).font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary).lineLimit(2)
                        Text(isSelected ? "قيد المعاينة" : "بث مباشر").font(.caption2).foregroundStyle(isSelected ? BlofyTheme.mint : BlofyTheme.textMuted)
                    }
                }
            }.buttonStyle(.plain)
            Spacer()
            Button(action: favorite) {
                Image(systemName: model.favorites.contains(item.id) ? "heart.fill" : "heart")
                    .frame(width: 34, height: 34).foregroundStyle(BlofyTheme.purpleSoft)
            }.buttonStyle(.plain)
            Button(action: watch) {
                Image(systemName: "play.fill").font(.caption.bold()).frame(width: 36, height: 36)
                    .background(isSelected ? BlofyTheme.primaryGradient : LinearGradient(colors: [BlofyTheme.surfaceRaised, BlofyTheme.surfaceRaised], startPoint: .leading, endPoint: .trailing), in: Circle())
                    .foregroundStyle(.white)
            }.buttonStyle(.plain)
        }
        .padding(10)
        .background(isSelected ? BlofyTheme.surfaceFocused.opacity(0.72) : BlofyTheme.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? BlofyTheme.purpleBright.opacity(0.6) : BlofyTheme.divider.opacity(0.8)))
    }
}

private struct LiveVLCPreviewSurface: UIViewRepresentable {
    let player: VLCMediaPlayer
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        player.drawable = view
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        if (player.drawable as AnyObject?) !== uiView { player.drawable = uiView }
    }
}

@MainActor
final class LivePreviewController: ObservableObject {
    let player = VLCMediaPlayer()
    @Published var ready = false
    private var timer: Timer?
    private var currentURL: URL?

    func start(url: URL) {
        if currentURL == url, player.isPlaying { return }
        stop()
        currentURL = url
        guard let media = VLCMedia(url: url) else { return }
        media.addOptions(["network-caching": 650, "no-audio": 1, "http-user-agent": "BLOFY PLAYER/2.0"])
        player.media = media
        player.play()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.player.isPlaying { self.ready = true }
            }
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        player.stop(); ready = false; currentURL = nil
    }
}
