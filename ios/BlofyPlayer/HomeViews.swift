import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAdd = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.035, green: 0.025, blue: 0.06), Color(red: 0.08, green: 0.045, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            if model.selected == nil { EmptyHome(showAdd: $showAdd) }
            else { HomeTabs(showAdd: $showAdd) }

            if model.loading {
                SyncProgressView()
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .sheet(isPresented: $showAdd) { AddPlaylistView() }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background, .inactive:
                model.pauseSyncForBackground()
            case .active:
                Task { await model.resumeSyncIfNeeded() }
            @unknown default:
                break
            }
        }
    }
}

struct SyncProgressView: View {
    @EnvironmentObject var model: AppModel

    private var percent: Int {
        max(0, min(100, Int((model.progress * 100).rounded())))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 66, weight: .semibold))
                    .foregroundStyle(.purple)

                Text("تحميل القوائم")
                    .font(.system(size: 30, weight: .black))

                Text("\(percent)٪")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .monospacedDigit()

                ProgressView(value: model.progress)
                    .tint(.purple)
                    .scaleEffect(x: 1, y: 2.2, anchor: .center)
                    .padding(.horizontal, 34)

                Text(model.status.isEmpty ? "جاري تجهيز البيانات" : model.status)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                Text("إذا خرجت من التطبيق ورجعت، نكمل من آخر مرحلة محفوظة بدون إعادة القوائم المكتملة.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 28)

                HStack(spacing: 18) {
                    SyncStageBadge(title: "البث", done: model.progress >= 0.35)
                    SyncStageBadge(title: "الأفلام", done: model.progress >= 0.68)
                    SyncStageBadge(title: "المسلسلات", done: model.progress >= 0.94)
                }
                .padding(.top, 6)
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.vertical, 28)
        }
    }
}

struct SyncStageBadge: View {
    let title: String
    let done: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(done ? Color.green : Color.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.06), in: Capsule())
    }
}

struct EmptyHome: View {
    @EnvironmentObject var model: AppModel
    @Binding var showAdd: Bool

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Text("BLOFY PLAYER").font(.system(size: 38, weight: .black))
            Image(systemName: "play.rectangle.fill").font(.system(size: 64)).foregroundStyle(.purple)
            Text("أضف قائمة Xtream أو M3U").foregroundStyle(.secondary)
            Button("إضافة قائمة تشغيل") { showAdd = true }.buttonStyle(.borderedProminent).tint(.purple)
            if !model.playlists.isEmpty {
                Menu("اختيار قائمة") { ForEach(model.playlists) { p in Button(p.name) { model.choose(p) } } }
            }
            Spacer()
        }.foregroundStyle(.white).padding()
    }
}

struct HomeTabs: View {
    @EnvironmentObject var model: AppModel
    @Binding var showAdd: Bool

    var body: some View {
        TabView {
            HomeView().tabItem { Label("الرئيسية", systemImage: "house.fill") }
            CatalogView(kind: .live).tabItem { Label("البث", systemImage: "tv.fill") }
            CatalogView(kind: .movie).tabItem { Label("الأفلام", systemImage: "film.fill") }
            CatalogView(kind: .series).tabItem { Label("المسلسلات", systemImage: "play.rectangle.on.rectangle.fill") }
            SearchView().tabItem { Label("بحث", systemImage: "magnifyingglass") }
            LibraryView().tabItem { Label("مكتبتي", systemImage: "heart.fill") }
            SettingsView(showAdd: $showAdd).tabItem { Label("الإعدادات", systemImage: "gearshape.fill") }
        }
        .tint(.purple)
        .task { await model.loadCatalog() }
    }
}

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    private var continueItems: [ResumeEntry] { model.resume.values.sorted { $0.updatedAt > $1.updatedAt } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    HeroHeader()
                    if !model.error.isEmpty {
                        VStack(spacing: 10) {
                            Text(model.error).foregroundStyle(.red)
                            Button("متابعة التحميل") { Task { await model.loadCatalog() } }
                                .buttonStyle(.borderedProminent).tint(.purple)
                        }
                        .padding(.horizontal)
                    }
                    if !continueItems.isEmpty { SectionRow(title: "متابعة المشاهدة", items: continueItems.map { $0.item }) }
                    SectionRow(title: "البث المباشر", items: Array(model.items.filter { $0.kind == .live }.prefix(18)))
                    SectionRow(title: "أحدث الأفلام", items: Array(model.items.filter { $0.kind == .movie }.prefix(18)))
                    SectionRow(title: "المسلسلات", items: Array(model.items.filter { $0.kind == .series }.prefix(18)))
                }.padding(.vertical, 18)
            }
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await model.loadCatalog(force: true) }
        }
    }
}

struct HeroHeader: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("BLOFY PLAYER").font(.system(size: 32, weight: .black))
                Text(model.selected?.name ?? "").foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                ForEach(model.playlists) { p in Button(p.name) { model.choose(p); Task { await model.loadCatalog() } } }
            } label: { Label("القائمة", systemImage: "server.rack") }.buttonStyle(.bordered)
        }.padding(.horizontal)
    }
}

struct SectionRow: View {
    let title: String
    let items: [MediaItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold()).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) { ForEach(items) { MediaCard(item: $0) } }.padding(.horizontal)
            }
        }
    }
}

struct MediaCard: View {
    @EnvironmentObject var model: AppModel
    let item: MediaItem
    var body: some View {
        NavigationLink {
            if item.kind == .series { SeriesDetailsView(series: item) } else { DetailsView(item: item) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Poster(url: item.poster)
                        .frame(width: 150, height: item.kind == .live ? 90 : 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    if model.favorites.contains(item.id) {
                        Image(systemName: "heart.fill").padding(7).background(.black.opacity(0.6), in: Circle()).foregroundStyle(.pink).padding(6)
                    }
                }
                Text(item.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(2).frame(width: 150, alignment: .leading)
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
            default: ZStack { Color.white.opacity(0.07); Image(systemName: "play.rectangle.fill").font(.largeTitle).foregroundStyle(.purple) }
            }
        }.clipped()
    }
}
