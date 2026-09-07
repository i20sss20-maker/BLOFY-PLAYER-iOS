import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @State private var showAdd = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.035, green: 0.025, blue: 0.06), Color(red: 0.08, green: 0.045, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            if model.selected == nil { EmptyHome(showAdd: $showAdd) }
            else { HomeTabs(showAdd: $showAdd) }
        }
        .sheet(isPresented: $showAdd) { AddPlaylistView() }
        .preferredColorScheme(.dark)
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
                    if model.loading { ProgressView(value: model.progress) { Text(model.status) }.tint(.purple).padding(.horizontal) }
                    if !model.error.isEmpty { Text(model.error).foregroundStyle(.red).padding(.horizontal) }
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
