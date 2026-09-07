import SwiftUI
import VLCKit

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAdd = false

    var body: some View {
        ZStack {
            BlofyTheme.backgroundGradient.ignoresSafeArea()
            if model.selected == nil { EmptyHome(showAdd: $showAdd) }
            else { HomeTabs(showAdd: $showAdd) }
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

struct SyncProgressView: View {
    @EnvironmentObject var model: AppModel
    private var percent: Int { max(0, min(100, Int((model.progress * 100).rounded()))) }
    var body: some View {
        ZStack {
            BlofyTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer(); BlofyBrandMark()
                ZStack {
                    Circle().stroke(BlofyTheme.surfaceRaised, lineWidth: 11)
                    Circle().trim(from: 0, to: model.progress).stroke(BlofyTheme.primaryGradient, style: StrokeStyle(lineWidth: 11, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("\(percent)٪").font(.system(size: 40, weight: .black, design: .rounded)).monospacedDigit()
                }.frame(width: 154, height: 154)
                Text(model.status.isEmpty ? "جاري تجهيز مكتبتك" : model.status).font(.headline).foregroundStyle(BlofyTheme.textPrimary).multilineTextAlignment(.center)
                HStack(spacing: 9) { SyncStageBadge(title: "البث", done: model.progress >= 0.35); SyncStageBadge(title: "الأفلام", done: model.progress >= 0.68); SyncStageBadge(title: "المسلسلات", done: model.progress >= 0.94) }
                Text("يتم حفظ كل مرحلة تلقائيًا، وإذا خرجت من التطبيق نكمل من آخر مرحلة مكتملة.").font(.caption).foregroundStyle(BlofyTheme.textMuted).multilineTextAlignment(.center).padding(.horizontal, 34)
                Spacer()
            }.padding()
        }
    }
}

struct SyncStageBadge: View {
    let title: String; let done: Bool
    var body: some View {
        HStack(spacing: 6) { Image(systemName: done ? "checkmark.circle.fill" : "circle"); Text(title) }
            .font(.caption.weight(.bold)).foregroundStyle(done ? BlofyTheme.mint : BlofyTheme.textMuted).padding(.horizontal, 11).padding(.vertical, 8).blofyPanel(radius: 14)
    }
}

struct EmptyHome: View {
    @EnvironmentObject var model: AppModel
    @Binding var showAdd: Bool
    var body: some View {
        VStack(spacing: 18) {
            Spacer(); BlofyBrandMark()
            Text("مشغلك. مكتبتك. بطريقتك.").font(.title3.bold()).foregroundStyle(BlofyTheme.textSecondary)
            Text("أضف Xtream أو M3U وابدأ المشاهدة").font(.subheadline).foregroundStyle(BlofyTheme.textMuted)
            Button { showAdd = true } label: {
                Label("إضافة قائمة تشغيل", systemImage: "plus").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14).background(BlofyTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }.buttonStyle(.plain).foregroundStyle(.white).padding(.horizontal, 34)
            Spacer()
        }.padding().foregroundStyle(BlofyTheme.textPrimary)
    }
}

struct HomeTabs: View {
    @EnvironmentObject var model: AppModel
    @Binding var showAdd: Bool
    var body: some View {
        TabView {
            PremiumHomeView().tabItem { Label("الرئيسية", systemImage: "house.fill") }
            CatalogView(kind: .live).tabItem { Label("مباشر", systemImage: "tv.fill") }
            CatalogView(kind: .movie).tabItem { Label("أفلام", systemImage: "film.fill") }
            CatalogView(kind: .series).tabItem { Label("مسلسلات", systemImage: "play.rectangle.on.rectangle.fill") }
            MoreHubView(showAdd: $showAdd).tabItem { Label("المزيد", systemImage: "square.grid.2x2.fill") }
        }
        .tint(BlofyTheme.purpleBright)
        .task { await model.loadCatalog() }
    }
}

struct MoreHubView: View {
    @Binding var showAdd: Bool
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack { BlofyBrandMark(); Spacer(); Text("المزيد").font(.title2.bold()) }.padding(.horizontal, 16).padding(.top, 8)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MoreTile(title: "البحث", subtitle: "ابحث من أول حرف", icon: "magnifyingglass", destination: AnyView(SearchView()))
                        MoreTile(title: "مكتبتي", subtitle: "المفضلة والاستئناف", icon: "heart.fill", destination: AnyView(LibraryView()))
                        MoreTile(title: "الإعدادات", subtitle: "المحرك والبافر واللغة", icon: "gearshape.fill", destination: AnyView(SettingsView(showAdd: $showAdd)))
                        Button { showAdd = true } label: { MoreTileBody(title: "إضافة قائمة", subtitle: "Xtream أو M3U", icon: "plus.rectangle.on.folder.fill") }.buttonStyle(.plain)
                    }.padding(.horizontal, 16)
                }.padding(.bottom, 30)
            }.background(BlofyTheme.backgroundGradient).toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct MoreTile: View {
    let title: String; let subtitle: String; let icon: String; let destination: AnyView
    var body: some View { NavigationLink { destination } label: { MoreTileBody(title: title, subtitle: subtitle, icon: icon) }.buttonStyle(.plain) }
}

private struct MoreTileBody: View {
    let title: String; let subtitle: String; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.system(size: 24, weight: .semibold)).foregroundStyle(BlofyTheme.purpleBright)
            Spacer(minLength: 12)
            Text(title).font(.headline).foregroundStyle(BlofyTheme.textPrimary)
            Text(subtitle).font(.caption2).foregroundStyle(BlofyTheme.textMuted).lineLimit(2)
        }.frame(maxWidth: .infinity, minHeight: 130, alignment: .leading).padding(16).blofyPanel(radius: 22)
    }
}

struct PremiumHomeView: View {
    @EnvironmentObject var model: AppModel
    private var continueItems: [ResumeEntry] { model.resume.values.sorted { $0.updatedAt > $1.updatedAt } }
    private var liveItems: [MediaItem] { model.items.filter { $0.kind == .live } }
    private var movies: [MediaItem] { model.items.filter { $0.kind == .movie } }
    private var series: [MediaItem] { model.items.filter { $0.kind == .series } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    PremiumHeader()
                    HomeStats(live: liveItems.count, movies: movies.count, series: series.count)
                    QuickAccessRow()
                    if !model.error.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(model.error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(BlofyTheme.error)
                            Button("إعادة المحاولة") { Task { await model.loadCatalog() } }.buttonStyle(.borderedProminent).tint(BlofyTheme.purple)
                        }.padding(16).blofyPanel(radius: 18).padding(.horizontal, 16)
                    }
                    if !continueItems.isEmpty { SectionRow(title: "متابعة المشاهدة", subtitle: "كمل من حيث توقفت", items: Array(continueItems.prefix(18)).map { $0.item }) }
                    SectionRow(title: "على الهواء الآن", subtitle: "وصول سريع للقنوات", items: Array(liveItems.prefix(22)))
                    SectionRow(title: "أفلام مقترحة", subtitle: "من مكتبتك", items: Array(movies.prefix(22)))
                    SectionRow(title: "مسلسلات", subtitle: "مواسم وحلقات", items: Array(series.prefix(22)))
                }.padding(.vertical, 12)
            }
            .background(BlofyTheme.backgroundGradient).toolbar(.hidden, for: .navigationBar).refreshable { await model.loadCatalog(force: true) }
        }
    }
}

private struct PremiumHeader: View {
    @EnvironmentObject var model: AppModel
    @State private var play: PlaybackSession?
    private var featured: MediaItem? { model.items.first(where: { $0.kind == .live }) ?? model.items.first(where: { $0.kind == .movie }) }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                BlofyBrandMark()
                Spacer()
                Menu { ForEach(model.playlists) { p in Button(p.name) { model.choose(p); Task { await model.loadCatalog() } } } } label: {
                    HStack(spacing: 7) { Image(systemName: "server.rack"); Text(model.selected?.name ?? "").font(.caption.bold()).lineLimit(1) }
                        .padding(.horizontal, 11).padding(.vertical, 9).background(BlofyTheme.surfaceRaised, in: Capsule()).overlay(Capsule().stroke(BlofyTheme.divider))
                }.foregroundStyle(BlofyTheme.textSecondary)
            }

            ZStack(alignment: .bottomLeading) {
                if let featured, featured.kind == .live {
                    HomeLivePreview(item: featured).frame(height: 242)
                } else if let featured {
                    Poster(url: featured.poster).frame(maxWidth: .infinity).frame(height: 242)
                } else {
                    LinearGradient(colors: [BlofyTheme.purpleDeep, BlofyTheme.surfaceRaised], startPoint: .topLeading, endPoint: .bottomTrailing).frame(height: 242)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.2), BlofyTheme.background.opacity(0.96)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        Circle().fill(BlofyTheme.mint).frame(width: 7, height: 7)
                        Text(featured?.kind == .live ? "معاينة مباشرة" : "BLOFY PLAYER").font(.caption.bold()).foregroundStyle(BlofyTheme.mint)
                    }
                    Text(featured?.name ?? "جاهز للمشاهدة").font(.system(size: 25, weight: .black)).lineLimit(2)
                    Text(model.selected?.name ?? "").font(.caption).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                    HStack(spacing: 10) {
                        if let featured {
                            Button {
                                if let session = try? model.makePlaybackSession(for: featured) { play = session }
                            } label: { Label("شاهد الآن", systemImage: "play.fill").font(.subheadline.bold()).padding(.horizontal, 15).padding(.vertical, 10).background(.white, in: Capsule()).foregroundStyle(.black) }
                            .buttonStyle(.plain)
                        }
                        NavigationLink { CatalogView(kind: .live) } label: {
                            Label("كل القنوات", systemImage: "tv").font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 10).background(.black.opacity(0.45), in: Capsule()).foregroundStyle(.white)
                        }.buttonStyle(.plain)
                    }
                }.padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(BlofyTheme.purpleSoft.opacity(0.28)))
            .shadow(color: BlofyTheme.purple.opacity(0.18), radius: 22, y: 12)
        }
        .padding(.horizontal, 16)
        .fullScreenCover(item: $play) { PlayerScreen(session: $0) }
    }
}

private struct HomeLivePreview: View {
    @EnvironmentObject var model: AppModel
    let item: MediaItem
    @StateObject private var preview = HomePreviewBox()

    var body: some View {
        ZStack {
            VLCPreviewSurface(player: preview.player)
            if !preview.ready { Poster(url: item.poster).opacity(0.82) }
            VStack { HStack { Spacer(); Label("LIVE", systemImage: "dot.radiowaves.left.and.right").font(.caption2.bold()).padding(.horizontal, 9).padding(.vertical, 6).background(.red.opacity(0.82), in: Capsule()).padding(12) }; Spacer() }
        }
        .task(id: item.id) {
            if let session = try? model.makePlaybackSession(for: item), let url = session.candidates.first { preview.start(url: url) }
        }
        .onDisappear { preview.stop() }
    }
}

private struct VLCPreviewSurface: UIViewRepresentable {
    let player: VLCMediaPlayer
    func makeUIView(context: Context) -> UIView { let view = UIView(); view.backgroundColor = .black; player.drawable = view; return view }
    func updateUIView(_ uiView: UIView, context: Context) { if (player.drawable as AnyObject?) !== uiView { player.drawable = uiView } }
}

@MainActor
private final class HomePreviewBox: ObservableObject {
    let player = VLCMediaPlayer()
    @Published var ready = false
    private var timer: Timer?
    func start(url: URL) {
        stop()
        guard let media = VLCMedia(url: url) else { return }
        media.addOptions(["network-caching": 700, "no-audio": 1, "http-user-agent": "BLOFY PLAYER/2.0"])
        player.media = media; player.play()
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in Task { @MainActor in if let self, self.player.isPlaying { self.ready = true } } }
    }
    func stop() { timer?.invalidate(); timer = nil; player.stop(); ready = false }
}

private struct HomeStats: View {
    let live: Int; let movies: Int; let series: Int
    var body: some View {
        HStack(spacing: 10) {
            StatPill(value: live, title: "قناة", icon: "dot.radiowaves.left.and.right")
            StatPill(value: movies, title: "فيلم", icon: "film")
            StatPill(value: series, title: "مسلسل", icon: "play.rectangle.on.rectangle")
        }.padding(.horizontal, 16)
    }
}

private struct StatPill: View {
    let value: Int; let title: String; let icon: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(BlofyTheme.purpleBright)
            VStack(alignment: .leading, spacing: 0) { Text("\(value)").font(.subheadline.bold()).monospacedDigit(); Text(title).font(.caption2).foregroundStyle(BlofyTheme.textMuted) }
        }.frame(maxWidth: .infinity).padding(.vertical, 11).blofyPanel(radius: 16)
    }
}

private struct QuickAccessRow: View {
    var body: some View {
        HStack(spacing: 10) {
            NavigationLink { SearchView() } label: { QuickChip(title: "بحث", icon: "magnifyingglass") }
            NavigationLink { LibraryView() } label: { QuickChip(title: "مفضلتي", icon: "heart.fill") }
            NavigationLink { PlayerAdvancedSettingsView() } label: { QuickChip(title: "المشغل", icon: "slider.horizontal.3") }
            Spacer(minLength: 0)
        }.padding(.horizontal, 16)
    }
}

private struct QuickChip: View {
    let title: String; let icon: String
    var body: some View {
        Label(title, systemImage: icon).font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary).padding(.horizontal, 13).padding(.vertical, 10)
            .background(BlofyTheme.surfaceRaised, in: Capsule()).overlay(Capsule().stroke(BlofyTheme.divider))
    }
}

struct SectionRow: View {
    let title: String; var subtitle: String = ""; let items: [MediaItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) { VStack(alignment: .leading, spacing: 2) { Text(title).font(.title3.bold()).foregroundStyle(BlofyTheme.textPrimary); if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(BlofyTheme.textMuted) } }; Spacer() }.padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) { LazyHStack(spacing: 13) { ForEach(items) { MediaCard(item: $0) } }.padding(.horizontal, 16) }
        }
    }
}

struct MediaCard: View {
    @EnvironmentObject var model: AppModel
    let item: MediaItem
    private var width: CGFloat { item.kind == .live ? 170 : 142 }
    private var height: CGFloat { item.kind == .live ? 102 : 208 }
    var body: some View {
        NavigationLink { if item.kind == .series { SeriesDetailsView(series: item) } else { DetailsView(item: item) } } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Poster(url: item.poster).frame(width: width, height: height).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 18).stroke(BlofyTheme.divider.opacity(0.75)))
                    if model.favorites.contains(item.id) { Image(systemName: "heart.fill").font(.caption).padding(7).background(.black.opacity(0.62), in: Circle()).foregroundStyle(BlofyTheme.purpleBright).padding(6) }
                }
                Text(item.name).font(.subheadline.weight(.semibold)).foregroundStyle(BlofyTheme.textPrimary).lineLimit(2).frame(width: width, alignment: .leading)
            }
        }.buttonStyle(.plain)
    }
}

struct Poster: View {
    let url: String
    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            default: ZStack { LinearGradient(colors: [BlofyTheme.surfaceRaised, BlofyTheme.purpleDeep.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing); Image(systemName: "play.rectangle.fill").font(.largeTitle).foregroundStyle(BlofyTheme.purpleSoft) }
            }
        }.clipped()
    }
}
