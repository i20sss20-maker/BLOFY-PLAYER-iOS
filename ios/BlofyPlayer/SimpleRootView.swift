import SwiftUI
import VLCKit

struct SimpleRootView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAdd = false
    @State private var tab = 0
    let onLogout: () -> Void

    var body: some View {
        ZStack {
            BlofyTheme.backgroundGradient.ignoresSafeArea()

            if model.selected == nil {
                EmptyHome(showAdd: $showAdd)
            } else {
                TabView(selection: $tab) {
                    SimpleHomeView(tab: $tab, showAdd: $showAdd, onLogout: onLogout)
                        .tabItem { Label("الرئيسية", systemImage: "house.fill") }
                        .tag(0)

                    LiveExperienceView()
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
                .toolbarBackground(BlofyTheme.backgroundRaised, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            }
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
    let onLogout: () -> Void
    @State private var showLogoutConfirm = false

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
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    ServerHeader(showLogoutConfirm: $showLogoutConfirm)

                    SimpleHeroCard(tab: $tab)

                    HStack(spacing: 9) {
                        SimpleStat(value: liveCount, title: "قناة", icon: "tv.fill")
                        SimpleStat(value: movieCount, title: "فيلم", icon: "film.fill")
                        SimpleStat(value: seriesCount, title: "مسلسل", icon: "play.rectangle.on.rectangle.fill")
                    }
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("استكشف BLOFY")
                            .font(.title3.bold())
                            .foregroundStyle(BlofyTheme.textPrimary)
                            .padding(.horizontal, 16)

                        HStack(spacing: 10) {
                            SimpleLaunchButton(title: "البث", subtitle: "شاهد الآن", icon: "tv.fill") { tab = 1 }
                            SimpleLaunchButton(title: "الأفلام", subtitle: "مكتبتك", icon: "film.fill") { tab = 2 }
                            SimpleLaunchButton(title: "المسلسلات", subtitle: "المواسم", icon: "play.rectangle.on.rectangle.fill") { tab = 3 }
                        }
                        .padding(.horizontal, 16)
                    }

                    if !continueItems.isEmpty {
                        SimpleSection(title: "متابعة المشاهدة", subtitle: "كمل من آخر نقطة", items: continueItems)
                    }
                    if !movies.isEmpty {
                        SimpleSection(title: "أفلام", subtitle: "اختيارات من السيرفر", items: movies)
                    }
                    if !series.isEmpty {
                        SimpleSection(title: "مسلسلات", subtitle: "مواسم وحلقات", items: series)
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
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
                .padding(.vertical, 12)
            }
            .background(BlofyTheme.backgroundGradient)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await model.loadCatalog(force: true) }
            .alert("تسجيل الخروج؟", isPresented: $showLogoutConfirm) {
                Button("إلغاء", role: .cancel) {}
                Button("تسجيل خروج", role: .destructive) { onLogout() }
            } message: {
                Text("بنرجع لصفحة الدخول فقط. السيرفرات والمفضلة والتقدم المحفوظ ما راح تنحذف.")
            }
        }
    }
}

private struct ServerHeader: View {
    @EnvironmentObject var model: AppModel
    @Binding var showLogoutConfirm: Bool

    var body: some View {
        HStack(spacing: 12) {
            BlofyBrandMark(compact: true)

            Menu {
                if model.playlists.count > 1 {
                    ForEach(model.playlists) { playlist in
                        Button {
                            guard playlist.id != model.selected?.id else { return }
                            model.choose(playlist)
                            Task { await model.loadCatalog() }
                        } label: {
                            if playlist.id == model.selected?.id {
                                Label(playlist.name, systemImage: "checkmark.circle.fill")
                            } else {
                                Label(playlist.name, systemImage: "server.rack")
                            }
                        }
                    }
                    Divider()
                }
                Button(role: .destructive) { showLogoutConfirm = true } label: {
                    Label("تسجيل الخروج", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.selected?.name ?? "BLOFY Server")
                            .font(.subheadline.bold())
                            .foregroundStyle(BlofyTheme.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Circle().fill(BlofyTheme.mint).frame(width: 6, height: 6)
                            Text(model.playlists.count > 1 ? "متصل · اضغط لتبديل السيرفر" : "متصل وجاهز")
                                .font(.caption2.bold())
                                .foregroundStyle(BlofyTheme.textMuted)
                        }
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2.bold())
                        .foregroundStyle(BlofyTheme.textMuted)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            NavigationLink { SearchView() } label: {
                HeaderCircle(icon: "magnifyingglass", tint: BlofyTheme.textPrimary)
            }
            .buttonStyle(.plain)

            Button { showLogoutConfirm = true } label: {
                HeaderCircle(icon: "person.crop.circle", tint: BlofyTheme.purpleSoft)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}

private struct HeaderCircle: View {
    let icon: String
    let tint: Color
    var body: some View {
        Image(systemName: icon)
            .font(.headline)
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(BlofyTheme.surfaceRaised, in: Circle())
            .overlay(Circle().stroke(BlofyTheme.divider))
    }
}

private struct SimpleHeroCard: View {
    @EnvironmentObject var model: AppModel
    @Binding var tab: Int
    @State private var play: PlaybackSession?

    private var featured: MediaItem? {
        model.items.first(where: { $0.kind == .live }) ?? model.items.first(where: { $0.kind == .movie })
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let featured, featured.kind == .live {
                SimpleLivePreview(item: featured)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let featured {
                Poster(url: featured.poster)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                BlofyTheme.heroGradient
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.14), BlofyTheme.background.opacity(0.98)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Circle().fill(BlofyTheme.mint).frame(width: 7, height: 7)
                    Text(featured?.kind == .live ? "معاينة مباشرة" : "مختار لك")
                        .font(.caption.bold())
                        .foregroundStyle(BlofyTheme.mint)
                }

                Text(featured?.name ?? "جاهز للمشاهدة")
                    .font(.system(size: 27, weight: .black))
                    .foregroundStyle(BlofyTheme.textPrimary)
                    .lineLimit(2)

                if let server = model.selected?.name {
                    Text(server)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(1)
                }

                if let featured {
                    HStack(spacing: 10) {
                        Button {
                            if featured.kind == .live {
                                tab = 1
                            } else if let session = try? model.makePlaybackSession(for: featured) {
                                play = session
                            }
                        } label: {
                            Label(featured.kind == .live ? "فتح البث" : "شاهد الآن", systemImage: "play.fill")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)
                                .background(.white, in: Capsule())
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)

                        if featured.kind == .live {
                            Text("بدون صوت")
                                .font(.caption2.bold())
                                .foregroundStyle(.white.opacity(0.72))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(.black.opacity(0.36), in: Capsule())
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(height: 252)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(BlofyTheme.purpleSoft.opacity(0.18)))
        .shadow(color: .black.opacity(0.28), radius: 22, y: 14)
        .padding(.horizontal, 16)
        .fullScreenCover(item: $play) { PlayerScreen(session: $0) }
    }
}

private struct SimpleLivePreview: View {
    @EnvironmentObject var model: AppModel
    let item: MediaItem
    @StateObject private var box = SimplePreviewBox()

    var body: some View {
        ZStack {
            SimplePreviewSurface(player: box.player)
            if !box.ready {
                Poster(url: item.poster)
                    .opacity(0.88)
            }
            VStack {
                HStack {
                    Spacer()
                    Label("LIVE", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.84), in: Capsule())
                        .padding(12)
                }
                Spacer()
            }
        }
        .task(id: item.id) {
            guard let session = try? model.makePlaybackSession(for: item), let url = session.candidates.first else { return }
            box.start(url: url)
        }
        .onDisappear { box.stop() }
    }
}

private struct SimplePreviewSurface: UIViewRepresentable {
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
private final class SimplePreviewBox: ObservableObject {
    let player = VLCMediaPlayer()
    @Published var ready = false
    private var timer: Timer?

    func start(url: URL) {
        stop()
        guard let media = VLCMedia(url: url) else { return }
        media.addOptions([
            "network-caching": 650,
            "no-audio": 1,
            "http-user-agent": "BLOFY PLAYER/0.3"
        ])
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
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(BlofyTheme.purpleBright)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)").font(.subheadline.bold()).monospacedDigit().foregroundStyle(BlofyTheme.textPrimary)
                Text(title).font(.caption2).foregroundStyle(BlofyTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 11)
        .blofyPanel(radius: 15)
    }
}

private struct SimpleLaunchButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                ZStack {
                    Circle().fill(BlofyTheme.purple.opacity(0.15)).frame(width: 40, height: 40)
                    Image(systemName: icon).font(.headline).foregroundStyle(BlofyTheme.purpleBright)
                }
                Text(title).font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary)
                Text(subtitle).font(.caption2).foregroundStyle(BlofyTheme.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .blofyPanel(radius: 19)
        }
        .buttonStyle(.plain)
    }
}

private struct SimpleUtilityButton: View {
    let title: String
    let icon: String
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.caption.bold())
        .foregroundStyle(BlofyTheme.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BlofyTheme.divider))
    }
}

private struct SimpleSection: View {
    let title: String
    let subtitle: String
    let items: [MediaItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(BlofyTheme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(BlofyTheme.textMuted)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink {
                            if item.kind == .series { SeriesDetailsView(series: item) }
                            else { DetailsView(item: item) }
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                Poster(url: item.poster)
                                    .frame(width: 138, height: 188)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(BlofyTheme.divider))
                                Text(item.name)
                                    .font(.caption.bold())
                                    .foregroundStyle(BlofyTheme.textPrimary)
                                    .lineLimit(1)
                                    .frame(width: 138, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
