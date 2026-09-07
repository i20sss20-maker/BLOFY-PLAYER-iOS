import SwiftUI
import VLCKit

struct SimpleRootView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAdd = false
    @State private var tab = 0

    var body: some View {
        ZStack {
            BlofyTheme.backgroundGradient.ignoresSafeArea()

            if model.selected == nil {
                EmptyHome(showAdd: $showAdd)
            } else {
                TabView(selection: $tab) {
                    SimpleHomeView(tab: $tab, showAdd: $showAdd)
                        .tabItem { Label("الرئيسية", systemImage: "house.fill") }
                        .tag(0)

                    CatalogView(kind: .live)
                        .tabItem { Label("مباشر", systemImage: "tv.fill") }
                        .tag(1)

                    CatalogView(kind: .movie)
                        .tabItem { Label("أفلام", systemImage: "film.fill") }
                        .tag(2)

                    CatalogView(kind: .series)
                        .tabItem { Label("مسلسلات", systemImage: "play.rectangle.on.rectangle.fill") }
                        .tag(3)

                    MoreHubView(showAdd: $showAdd)
                        .tabItem { Label("المزيد", systemImage: "ellipsis.circle.fill") }
                        .tag(4)
                }
                .tint(BlofyTheme.purpleBright)
                .task { await model.loadCatalog() }
            }

            if model.loading { SyncProgressView().transition(.opacity).zIndex(20) }
        }
        .sheet(isPresented: $showAdd) { AddPlaylistView() }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background, .inactive: model.pauseSyncForBackground()
            case .active: Task { await model.resumeSyncIfNeeded() }
            @unknown default: break
            }
        }
    }
}

private struct SimpleHomeView: View {
    @EnvironmentObject var model: AppModel
    @Binding var tab: Int
    @Binding var showAdd: Bool

    private var continueItems: [MediaItem] {
        Array(model.resume.values.sorted { $0.updatedAt > $1.updatedAt }.map(\.item).prefix(12))
    }
    private var movies: [MediaItem] { Array(model.items.filter { $0.kind == .movie }.prefix(18)) }
    private var series: [MediaItem] { Array(model.items.filter { $0.kind == .series }.prefix(18)) }
    private var liveCount: Int { model.items.reduce(0) { $1.kind == .live ? $0 + 1 : $0 } }
    private var movieCount: Int { model.items.reduce(0) { $1.kind == .movie ? $0 + 1 : $0 } }
    private var seriesCount: Int { model.items.reduce(0) { $1.kind == .series ? $0 + 1 : $0 } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        BlofyBrandMark()
                        Spacer()
                        NavigationLink { SearchView() } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.headline)
                                .frame(width: 44, height: 44)
                                .background(BlofyTheme.surfaceRaised, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(BlofyTheme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    SimpleHeroCard(tab: $tab)

                    HStack(spacing: 8) {
                        SimpleStat(value: liveCount, title: "قناة")
                        SimpleStat(value: movieCount, title: "فيلم")
                        SimpleStat(value: seriesCount, title: "مسلسل")
                    }
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("وش تبي تشاهد؟")
                            .font(.title3.bold())
                            .foregroundStyle(BlofyTheme.textPrimary)
                            .padding(.horizontal, 16)

                        HStack(spacing: 10) {
                            SimpleLaunchButton(title: "البث", subtitle: "القنوات", icon: "tv.fill") { tab = 1 }
                            SimpleLaunchButton(title: "الأفلام", subtitle: "المكتبة", icon: "film.fill") { tab = 2 }
                            SimpleLaunchButton(title: "المسلسلات", subtitle: "الحلقات", icon: "play.rectangle.on.rectangle.fill") { tab = 3 }
                        }
                        .padding(.horizontal, 16)
                    }

                    HStack(spacing: 10) {
                        NavigationLink { SearchView() } label: {
                            SimpleUtilityButton(title: "بحث", icon: "magnifyingglass")
                        }
                        NavigationLink { LibraryView() } label: {
                            SimpleUtilityButton(title: "مكتبتي", icon: "heart.fill")
                        }
                        Button { tab = 4 } label: {
                            SimpleUtilityButton(title: "المزيد", icon: "ellipsis")
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)

                    if !continueItems.isEmpty {
                        SectionRow(title: "متابعة المشاهدة", subtitle: "كمل من حيث وقفت", items: continueItems)
                    }
                    if !movies.isEmpty {
                        SectionRow(title: "أفلام", subtitle: "وصول سريع لمكتبتك", items: movies)
                    }
                    if !series.isEmpty {
                        SectionRow(title: "مسلسلات", subtitle: "مواسم وحلقات", items: series)
                    }

                    if !model.error.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(model.error).font(.caption).lineLimit(2)
                            Spacer()
                            Button("إعادة") { Task { await model.loadCatalog() } }
                        }
                        .foregroundStyle(BlofyTheme.error)
                        .padding(14)
                        .blofyPanel(radius: 16)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 30)
            }
            .background(BlofyTheme.backgroundGradient)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await model.loadCatalog(force: true) }
        }
    }
}

private struct SimpleHeroCard: View {
    @EnvironmentObject var model: AppModel
    @Binding var tab: Int
    @StateObject private var preview = SimpleHomePreviewBox()
    @State private var play: PlaybackSession?

    private var featured: MediaItem? {
        model.items.first(where: { $0.kind == .live && !$0.poster.isEmpty }) ?? model.items.first(where: { $0.kind == .live })
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let item = featured {
                    ZStack {
                        SimpleVLCPreviewSurface(player: preview.player)
                        if !preview.ready { Poster(url: item.poster).opacity(0.88) }
                    }
                } else {
                    BlofyTheme.heroGradient
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 232)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.28), .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Circle().fill(BlofyTheme.mint).frame(width: 7, height: 7)
                    Text(preview.ready ? "معاينة مباشرة" : "BLOFY PLAYER")
                        .font(.caption.bold())
                        .foregroundStyle(preview.ready ? BlofyTheme.mint : BlofyTheme.purpleSoft)
                }
                Text(featured?.name ?? "جاهز للمشاهدة")
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(model.selected?.name ?? "")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                HStack(spacing: 9) {
                    if let featured {
                        Button {
                            if let session = try? model.makePlaybackSession(for: featured) { play = session }
                        } label: {
                            Label("شاهد الآن", systemImage: "play.fill")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 15)
                                .padding(.vertical, 10)
                                .background(.white, in: Capsule())
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)
                    }
                    Button { tab = 1 } label: {
                        Label("كل القنوات", systemImage: "tv")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 13)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.45), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
        .frame(height: 232)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(BlofyTheme.purpleSoft.opacity(0.22)))
        .shadow(color: BlofyTheme.purple.opacity(0.15), radius: 18, y: 8)
        .padding(.horizontal, 16)
        .task(id: featured?.id) {
            preview.stop()
            guard let featured,
                  let session = try? model.makePlaybackSession(for: featured),
                  let url = session.candidates.first else { return }
            preview.start(url: url)
        }
        .onDisappear { preview.stop() }
        .fullScreenCover(item: $play) { PlayerScreen(session: $0) }
    }
}

private struct SimpleVLCPreviewSurface: UIViewRepresentable {
    let player: VLCMediaPlayer
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        player.drawable = view
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        if (player.drawable as AnyObject?) !== uiView { player.drawable = uiView }
    }
}

@MainActor
private final class SimpleHomePreviewBox: ObservableObject {
    let player = VLCMediaPlayer()
    @Published var ready = false
    private var timer: Timer?

    func start(url: URL) {
        stop()
        guard let media = VLCMedia(url: url) else { return }
        media.addOptions(["network-caching": 650, "no-audio": 1, "http-user-agent": "BLOFY PLAYER/2.0"])
        player.media = media
        player.play()
        timer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.player.isPlaying { self.ready = true }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        player.stop()
        ready = false
    }
}

private struct SimpleStat: View {
    let value: Int
    let title: String
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.headline.bold()).foregroundStyle(BlofyTheme.textPrimary).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(BlofyTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(BlofyTheme.surfaceRaised.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BlofyTheme.divider))
    }
}

private struct SimpleLaunchButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(BlofyTheme.purpleBright)
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(BlofyTheme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(BlofyTheme.textMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 118)
            .blofyPanel(radius: 20)
        }
        .buttonStyle(.plain)
    }
}

private struct SimpleUtilityButton: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.bold())
            .foregroundStyle(BlofyTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(BlofyTheme.divider))
    }
}
