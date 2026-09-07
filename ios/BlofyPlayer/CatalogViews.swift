import SwiftUI

struct CatalogView: View {
    @EnvironmentObject var model: AppModel
    let kind: ContentKind
    @State private var selectedCategory = "all"
    @State private var query = ""
    @State private var sortMode = "server"

    private var categories: [MediaCategory] { model.categories.filter { $0.kind == kind } }
    private var categoryTitle: String { selectedCategory == "all" ? "كل الفئات" : (categories.first { $0.key == selectedCategory }?.name ?? "الفئة") }
    private var shown: [MediaItem] {
        let filtered = model.items.filter {
            $0.kind == kind && (selectedCategory == "all" || $0.categoryID == selectedCategory) &&
            (query.isEmpty || normalizedSearch($0.name).contains(normalizedSearch(query)))
        }
        switch sortMode {
        case "az": return filtered.sorted { normalizedSearch($0.name) < normalizedSearch($1.name) }
        case "za": return filtered.sorted { normalizedSearch($0.name) > normalizedSearch($1.name) }
        default: return filtered
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    BlofyBrandMark(compact: true)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(kind.title).font(.title2.bold()).foregroundStyle(BlofyTheme.textPrimary)
                        Text("\(shown.count) عنصر").font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                    }
                }.padding(.horizontal, 16).padding(.top, 10)

                HStack(spacing: 9) {
                    Menu {
                        Button("كل الفئات") { selectedCategory = "all" }
                        ForEach(categories) { category in Button(category.name) { selectedCategory = category.key } }
                    } label: {
                        Label(categoryTitle, systemImage: "line.3.horizontal.decrease.circle.fill").lineLimit(1)
                    }.catalogControl()

                    Menu {
                        Button("ترتيب السيرفر") { sortMode = "server" }
                        Button("A → Z") { sortMode = "az" }
                        Button("Z → A") { sortMode = "za" }
                    } label: { Image(systemName: "arrow.up.arrow.down") }.catalogControl(compact: true)
                    Spacer()
                }.padding(.horizontal, 16).padding(.vertical, 12)

                if !model.error.isEmpty { Text(model.error).font(.caption).foregroundStyle(BlofyTheme.error).padding(.horizontal) }

                if kind == .live {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(shown) { item in
                                NavigationLink { DetailsView(item: item) } label: { LiveChannelRow(item: item) }.buttonStyle(.plain)
                            }
                        }.padding(.horizontal, 16).padding(.bottom, 30)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 13)], spacing: 18) {
                            ForEach(shown) { MediaCard(item: $0) }
                        }.padding(.horizontal, 16).padding(.bottom, 30)
                    }
                }
            }
            .background(BlofyTheme.backgroundGradient.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .searchable(text: $query, prompt: "بحث في \(kind.title)")
            .refreshable { await model.loadCatalog(force: true) }
            .animation(.easeOut(duration: 0.16), value: selectedCategory)
            .animation(.easeOut(duration: 0.16), value: sortMode)
        }
    }
}

private struct LiveChannelRow: View {
    @EnvironmentObject var model: AppModel
    let item: MediaItem
    var body: some View {
        HStack(spacing: 12) {
            if model.showChannelLogos {
                Poster(url: item.poster).frame(width: 60, height: 46).clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "tv.fill").frame(width: 60, height: 46).background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(BlofyTheme.purpleSoft)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary).lineLimit(2)
                Text("بث مباشر").font(.caption2).foregroundStyle(BlofyTheme.mint)
            }
            Spacer()
            if model.favorites.contains(item.id) { Image(systemName: "heart.fill").foregroundStyle(BlofyTheme.purpleBright) }
            Image(systemName: "play.fill").font(.caption).foregroundStyle(BlofyTheme.textSecondary)
        }
        .padding(11).background(BlofyTheme.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(BlofyTheme.divider.opacity(0.8)))
    }
}

private extension View {
    func catalogControl(compact: Bool = false) -> some View {
        self.font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary).padding(.horizontal, compact ? 12 : 14).frame(height: 42)
            .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(BlofyTheme.divider))
    }
}

struct DetailsView: View {
    @EnvironmentObject var model: AppModel
    @State var item: MediaItem
    @State private var play: PlaybackSession?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottomLeading) {
                    Poster(url: item.poster).frame(maxWidth: .infinity).frame(height: item.kind == .live ? 240 : 390).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    LinearGradient(colors: [.clear, BlofyTheme.background.opacity(0.95)], startPoint: .center, endPoint: .bottom).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.kind.title.uppercased()).font(.caption2.bold()).tracking(1.8).foregroundStyle(BlofyTheme.purpleBright)
                        Text(item.name).font(.system(size: 30, weight: .black)).foregroundStyle(BlofyTheme.textPrimary).lineLimit(3)
                    }.padding(18)
                }
                if model.showRatings && !item.rating.isEmpty { Label(item.rating, systemImage: "star.fill").font(.subheadline.bold()).foregroundStyle(BlofyTheme.purpleSoft) }
                if !item.plot.isEmpty { Text(item.plot).font(.body).foregroundStyle(BlofyTheme.textSecondary).lineSpacing(4) }
                HStack(spacing: 11) {
                    Button { start() } label: {
                        Label(model.resume[item.id] == nil ? "تشغيل" : "استئناف", systemImage: "play.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13).background(BlofyTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }.buttonStyle(.plain).foregroundStyle(.white)
                    Button { model.toggleFavorite(item) } label: {
                        Image(systemName: model.favorites.contains(item.id) ? "heart.fill" : "heart").font(.headline).frame(width: 50, height: 50).background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }.buttonStyle(.plain).foregroundStyle(BlofyTheme.purpleSoft)
                }
            }.padding(16)
        }
        .background(BlofyTheme.backgroundGradient.ignoresSafeArea()).navigationTitle(item.name).navigationBarTitleDisplayMode(.inline)
        .task { if item.kind == .movie { item = await model.detailedMovie(item) } }
        .fullScreenCover(item: $play) { PlayerScreen(session: $0) }
    }
    private func start() { do { play = try model.makePlaybackSession(for: item) } catch { model.error = error.localizedDescription } }
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
                Poster(url: series.poster).frame(maxWidth: .infinity).frame(height: 350).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                Text(series.name).font(.system(size: 30, weight: .black)).foregroundStyle(BlofyTheme.textPrimary)
                Button { model.toggleFavorite(series) } label: { Label(model.favorites.contains(series.id) ? "إزالة من المفضلة" : "إضافة للمفضلة", systemImage: model.favorites.contains(series.id) ? "heart.fill" : "heart") }.buttonStyle(.bordered).tint(BlofyTheme.purpleBright)
                if loading { ProgressView("تحميل الحلقات…").tint(BlofyTheme.purpleBright) }
                if !error.isEmpty { Text(error).foregroundStyle(BlofyTheme.error) }
                ForEach(seasons, id: \.self) { season in
                    VStack(alignment: .leading, spacing: 10) {
                        Text("الموسم \(season)").font(.title3.bold()).foregroundStyle(BlofyTheme.textPrimary)
                        ForEach(episodes.filter { $0.season == season }) { episode in
                            NavigationLink { DetailsView(item: episode) } label: {
                                HStack(spacing: 12) {
                                    Poster(url: episode.poster).frame(width: 118, height: 70).clipShape(RoundedRectangle(cornerRadius: 12))
                                    VStack(alignment: .leading, spacing: 4) { Text("الحلقة \(episode.episode)").font(.headline).foregroundStyle(BlofyTheme.textPrimary); Text(episode.name).font(.caption).foregroundStyle(BlofyTheme.textMuted).lineLimit(2) }
                                    Spacer(); Image(systemName: "chevron.left").font(.caption).foregroundStyle(BlofyTheme.textMuted)
                                }.padding(10).blofyPanel(radius: 16)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(16)
        }
        .background(BlofyTheme.backgroundGradient.ignoresSafeArea()).navigationTitle(series.name)
        .task { do { episodes = try await model.episodes(for: series) } catch { self.error = error.localizedDescription }; loading = false }
    }
}

struct SearchView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    private var results: [MediaItem] { let needle = normalizedSearch(query); return needle.isEmpty ? [] : Array(model.items.filter { normalizedSearch($0.name).contains(needle) }.prefix(200)) }
    var body: some View {
        NavigationStack {
            List(results) { item in
                NavigationLink { if item.kind == .series { SeriesDetailsView(series: item) } else { DetailsView(item: item) } } label: {
                    HStack(spacing: 12) {
                        Poster(url: item.poster).frame(width: 62, height: 82).clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 4) { Text(item.name).foregroundStyle(BlofyTheme.textPrimary); Text(item.kind.title).font(.caption).foregroundStyle(BlofyTheme.purpleSoft) }
                    }
                }.listRowBackground(BlofyTheme.surface.opacity(0.82))
            }
            .scrollContentBackground(.hidden).background(BlofyTheme.backgroundGradient).navigationTitle("البحث").searchable(text: $query, prompt: "اكتب من أول حرف")
        }
    }
}
