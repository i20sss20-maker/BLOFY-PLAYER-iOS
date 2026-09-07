import SwiftUI

struct CatalogView: View {
    @EnvironmentObject var model: AppModel
    let kind: ContentKind
    @State private var selectedCategory = "all"
    @State private var query = ""

    private var categories: [MediaCategory] { model.categories.filter { $0.kind == kind } }
    private var shown: [MediaItem] {
        model.items.filter {
            $0.kind == kind &&
            (selectedCategory == "all" || $0.categoryID == selectedCategory) &&
            (query.isEmpty || normalizedSearch($0.name).contains(normalizedSearch(query)))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button("الكل") { selectedCategory = "all" }.buttonStyle(.borderedProminent).tint(selectedCategory == "all" ? .purple : .gray)
                        ForEach(categories) { category in
                            Button(category.name) { selectedCategory = category.key }
                                .buttonStyle(.bordered)
                                .tint(selectedCategory == category.key ? .purple : .secondary)
                        }
                    }.padding()
                }
                if model.loading { ProgressView(value: model.progress).tint(.purple).padding() }
                if !model.error.isEmpty { Text(model.error).foregroundStyle(.red).padding() }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 18) {
                        ForEach(shown) { MediaCard(item: $0) }
                    }.padding()
                }
            }
            .navigationTitle(kind.title)
            .searchable(text: $query, prompt: "بحث في \(kind.title)")
            .refreshable { await model.loadCatalog(force: true) }
        }
    }
}

struct DetailsView: View {
    @EnvironmentObject var model: AppModel
    @State var item: MediaItem
    @State private var play: PlaybackSession?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Poster(url: item.poster).frame(maxWidth: .infinity).frame(height: item.kind == .live ? 260 : 420).clipShape(RoundedRectangle(cornerRadius: 22))
                Text(item.name).font(.largeTitle.bold())
                if !item.rating.isEmpty { Label(item.rating, systemImage: "star.fill").foregroundStyle(.yellow) }
                if !item.plot.isEmpty { Text(item.plot).foregroundStyle(.secondary) }
                HStack {
                    Button { start() } label: {
                        Label(model.resume[item.id] == nil ? "تشغيل" : "استئناف", systemImage: "play.fill")
                    }.buttonStyle(.borderedProminent).tint(.purple)
                    Button { model.toggleFavorite(item) } label: {
                        Label(model.favorites.contains(item.id) ? "إزالة من المفضلة" : "المفضلة", systemImage: model.favorites.contains(item.id) ? "heart.fill" : "heart")
                    }.buttonStyle(.bordered)
                }
            }.padding()
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { if item.kind == .movie { item = await model.detailedMovie(item) } }
        .fullScreenCover(item: $play) { PlayerScreen(session: $0) }
    }

    private func start() {
        do { play = try model.makePlaybackSession(for: item) }
        catch { model.error = error.localizedDescription }
    }
}

struct SeriesDetailsView: View {
    @EnvironmentObject var model: AppModel
    let series: MediaItem
    @State private var episodes: [MediaItem] = []
    @State private var loading = true
    @State private var error = ""

    private var seasons: [Int] { Array(Set(episodes.map { $0.season })).sorted() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Poster(url: series.poster).frame(maxWidth: .infinity).frame(height: 360).clipShape(RoundedRectangle(cornerRadius: 22))
                Text(series.name).font(.largeTitle.bold())
                Button { model.toggleFavorite(series) } label: {
                    Label(model.favorites.contains(series.id) ? "إزالة من المفضلة" : "المفضلة", systemImage: model.favorites.contains(series.id) ? "heart.fill" : "heart")
                }.buttonStyle(.bordered)
                if loading { ProgressView("تحميل الحلقات…") }
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
                ForEach(seasons, id: \.self) { season in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("الموسم \(season)").font(.title2.bold())
                        ForEach(episodes.filter { $0.season == season }) { episode in
                            NavigationLink { DetailsView(item: episode) } label: {
                                HStack {
                                    Poster(url: episode.poster).frame(width: 120, height: 72).clipShape(RoundedRectangle(cornerRadius: 9))
                                    VStack(alignment: .leading) {
                                        Text("الحلقة \(episode.episode)").font(.headline)
                                        Text(episode.name).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Spacer()
                                }.padding(.vertical, 5)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding()
        }
        .navigationTitle(series.name)
        .task {
            do { episodes = try await model.episodes(for: series) }
            catch { self.error = error.localizedDescription }
            loading = false
        }
    }
}

struct SearchView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    private var results: [MediaItem] {
        let needle = normalizedSearch(query)
        return needle.isEmpty ? [] : Array(model.items.filter { normalizedSearch($0.name).contains(needle) }.prefix(200))
    }

    var body: some View {
        NavigationStack {
            List(results) { item in
                NavigationLink {
                    if item.kind == .series { SeriesDetailsView(series: item) } else { DetailsView(item: item) }
                } label: {
                    HStack {
                        Poster(url: item.poster).frame(width: 64, height: 82).clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading) { Text(item.name); Text(item.kind.title).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle("البحث")
            .searchable(text: $query, prompt: "اكتب من أول حرف")
        }
    }
}
