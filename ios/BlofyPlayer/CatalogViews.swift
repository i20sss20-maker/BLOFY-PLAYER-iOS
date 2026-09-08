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

                if shown.isEmpty && !model.loading {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: query.isEmpty ? "rectangle.stack.badge.minus" : "magnifyingglass")
                            .font(.system(size: 40, weight: .semibold)).foregroundStyle(BlofyTheme.textMuted)
                        Text(query.isEmpty ? "ما فيه محتوى في هذه الفئة" : "ما لقينا نتائج")
                            .font(.headline).foregroundStyle(BlofyTheme.textPrimary)
                        Text(query.isEmpty ? "جرّب فئة ثانية أو حدّث القوائم." : "جرّب كتابة اسم مختلف أو امسح البحث.")
                            .font(.caption).foregroundStyle(BlofyTheme.textMuted).multilineTextAlignment(.center)
                        if query.isEmpty {
                            Button("تحديث القوائم") { Task { await model.loadCatalog(force: true) } }
                                .font(.subheadline.bold()).foregroundStyle(.white)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(BlofyTheme.primaryGradient, in: Capsule())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                } else if kind == .live {
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
    @State private var loadingDetail = false
    @State private var preparingPlayback = false

    private var resumeEntry: ResumeEntry? { model.resume[item.id] }
    private var resumeProgress: Double {
        guard let r = resumeEntry, r.duration > 0 else { return 0 }
        return min(max(r.seconds / r.duration, 0), 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottomLeading) {
                    Poster(url: item.poster)
                        .frame(maxWidth: .infinity)
                        .frame(height: item.kind == .live ? 250 : 420)
                        .clipped()
                    LinearGradient(colors: [.clear, BlofyTheme.background.opacity(0.98)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.kind.title.uppercased()).font(.caption2.bold()).tracking(1.8).foregroundStyle(BlofyTheme.purpleBright)
                        Text(item.name).font(.system(size: 31, weight: .black)).foregroundStyle(BlofyTheme.textPrimary).lineLimit(3)
                        HStack(spacing: 10) {
                            if model.showRatings && !item.rating.isEmpty {
                                Label(item.rating, systemImage: "star.fill").font(.caption.bold()).foregroundStyle(BlofyTheme.purpleSoft)
                            }
                            if !item.container.isEmpty && item.kind != .live {
                                Text(item.container.uppercased()).font(.caption2.bold()).padding(.horizontal, 8).padding(.vertical, 5).background(BlofyTheme.surfaceRaised, in: Capsule()).foregroundStyle(BlofyTheme.textSecondary)
                            }
                        }
                    }.padding(18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                if loadingDetail {
                    HStack(spacing: 9) {
                        ProgressView().tint(BlofyTheme.purpleBright)
                        Text("جاري تحميل تفاصيل الفيلم…").font(.caption).foregroundStyle(BlofyTheme.textMuted)
                    }
                }

                if let r = resumeEntry, r.duration > 0 {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Text("متابعة المشاهدة").font(.subheadline.bold()); Spacer(); Text("\(Int(resumeProgress * 100))٪").font(.caption).foregroundStyle(BlofyTheme.textMuted) }
                        ProgressView(value: resumeProgress).tint(BlofyTheme.purpleBright)
                    }
                    .padding(14).blofyPanel(radius: 17)
                }

                if !item.plot.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("القصة").font(.headline).foregroundStyle(BlofyTheme.textPrimary)
                        Text(item.plot).font(.body).foregroundStyle(BlofyTheme.textSecondary).lineSpacing(4)
                    }
                }

                HStack(spacing: 11) {
                    Button { Task { await start() } } label: {
                        HStack(spacing: 9) {
                            if preparingPlayback { ProgressView().tint(.white) }
                            else { Image(systemName: resumeEntry == nil ? "play.fill" : "arrow.clockwise") }
                            Text(preparingPlayback ? "جاري تجهيز التشغيل…" : (resumeEntry == nil ? "تشغيل الآن" : "استئناف"))
                        }
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(BlofyTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                    .buttonStyle(.plain).foregroundStyle(.white).disabled(preparingPlayback)
                    Button { model.toggleFavorite(item) } label: {
                        Image(systemName: model.favorites.contains(item.id) ? "heart.fill" : "heart")
                            .font(.headline).frame(width: 52, height: 52)
                            .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }.buttonStyle(.plain).foregroundStyle(BlofyTheme.purpleSoft)
                }
            }.padding(16)
        }
        .background(BlofyTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle(item.name).navigationBarTitleDisplayMode(.inline)
        .task {
            guard item.kind == .movie else { return }
            loadingDetail = true
            item = await model.detailedMovie(item)
            loadingDetail = false
        }
        .fullScreenCover(item: $play) { PlayerScreen(session: $0) }
    }

    @MainActor
    private func start() async {
        guard !preparingPlayback else { return }
        preparingPlayback = true
        defer { preparingPlayback = false }

        if item.kind == .movie {
            let detailed = await model.detailedMovie(item)
            item = detailed
        }

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
    @State private var selectedSeason: Int?
    @State private var play: PlaybackSession?
    @State private var preparingEpisodeID: String?

    private var seasons: [Int] { Array(Set(episodes.map { $0.season })).sorted() }
    private var visibleEpisodes: [MediaItem] {
        guard let selectedSeason else { return episodes }
        return episodes.filter { $0.season == selectedSeason }
    }
    private var resumableEpisode: MediaItem? {
        let saved = episodes.compactMap { ep -> (MediaItem, Date)? in
            guard let r = model.resume[ep.id] else { return nil }
            return (ep, r.updatedAt)
        }
        return saved.sorted { $0.1 > $1.1 }.first?.0
    }
    private var nextEpisode: MediaItem? {
        if let resumableEpisode { return resumableEpisode }
        return episodes.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottomLeading) {
                    Poster(url: series.poster).frame(maxWidth: .infinity).frame(height: 370).clipped()
                    LinearGradient(colors: [.clear, BlofyTheme.background.opacity(0.98)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("SERIES").font(.caption2.bold()).tracking(1.8).foregroundStyle(BlofyTheme.purpleBright)
                        Text(series.name).font(.system(size: 31, weight: .black)).foregroundStyle(BlofyTheme.textPrimary).lineLimit(3)
                        if !seasons.isEmpty { Text("\(seasons.count) موسم · \(episodes.count) حلقة").font(.caption).foregroundStyle(BlofyTheme.textMuted) }
                    }.padding(18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                if let nextEpisode {
                    Button { start(nextEpisode) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(resumableEpisode == nil ? "ابدأ المشاهدة" : "استئناف المسلسل").font(.headline)
                                Text("الموسم \(nextEpisode.season) · الحلقة \(nextEpisode.episode)").font(.caption).opacity(0.8)
                            }
                            Spacer()
                            if preparingEpisodeID == nextEpisode.id { ProgressView().tint(.white) }
                            else { Image(systemName: "play.fill") }
                        }
                        .padding(15).background(BlofyTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous)).foregroundStyle(.white)
                    }.buttonStyle(.plain).disabled(preparingEpisodeID != nil)
                }

                HStack(spacing: 10) {
                    Button { model.toggleFavorite(series) } label: {
                        Label(model.favorites.contains(series.id) ? "في المفضلة" : "إضافة للمفضلة", systemImage: model.favorites.contains(series.id) ? "heart.fill" : "heart")
                            .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain).foregroundStyle(BlofyTheme.textPrimary)
                }

                if loading { ProgressView("تحميل الحلقات…").tint(BlofyTheme.purpleBright) }
                if !error.isEmpty { Text(error).foregroundStyle(BlofyTheme.error) }

                if !loading && episodes.isEmpty && error.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "rectangle.stack.badge.minus").font(.title).foregroundStyle(BlofyTheme.textMuted)
                        Text("ما لقينا حلقات لهذا المسلسل").font(.headline)
                        Text("قد يكون السيرفر ما رجع بيانات الحلقات حاليًا.").font(.caption).foregroundStyle(BlofyTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 32).blofyPanel(radius: 18)
                }

                if !seasons.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(seasons, id: \.self) { season in
                                Button { withAnimation(.easeOut(duration: 0.15)) { selectedSeason = season } } label: {
                                    Text("الموسم \(season)").font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 9)
                                        .background((selectedSeason == season ? BlofyTheme.purple : BlofyTheme.surfaceRaised), in: Capsule())
                                        .foregroundStyle(.white)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }

                LazyVStack(spacing: 10) {
                    ForEach(visibleEpisodes) { episode in
                        Button { start(episode) } label: {
                            HStack(spacing: 12) {
                                ZStack(alignment: .bottomLeading) {
                                    Poster(url: episode.poster).frame(width: 126, height: 76).clipShape(RoundedRectangle(cornerRadius: 12))
                                    if let r = model.resume[episode.id], r.duration > 0 {
                                        ProgressView(value: min(max(r.seconds / r.duration, 0), 1)).tint(BlofyTheme.purpleBright).frame(width: 118).padding(4)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("الحلقة \(episode.episode)").font(.headline).foregroundStyle(BlofyTheme.textPrimary)
                                    Text(episode.name).font(.caption).foregroundStyle(BlofyTheme.textMuted).lineLimit(2)
                                    if model.resume[episode.id] != nil { Text("متابعة").font(.caption2.bold()).foregroundStyle(BlofyTheme.mint) }
                                }
                                Spacer()
                                if preparingEpisodeID == episode.id { ProgressView().tint(BlofyTheme.purpleSoft) }
                                else { Image(systemName: "play.circle.fill").font(.title3).foregroundStyle(BlofyTheme.purpleSoft) }
                            }
                            .padding(10).blofyPanel(radius: 16)
                        }.buttonStyle(.plain).disabled(preparingEpisodeID != nil)
                    }
                }
            }.padding(16)
        }
        .background(BlofyTheme.backgroundGradient.ignoresSafeArea()).navigationTitle(series.name).navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                episodes = try await model.episodes(for: series)
                selectedSeason = seasons.first
            } catch { self.error = error.localizedDescription }
            loading = false
        }
        .fullScreenCover(item: $play) { PlayerScreen(session: $0) }
    }

    private func start(_ episode: MediaItem) {
        guard preparingEpisodeID == nil else { return }
        preparingEpisodeID = episode.id
        defer { preparingEpisodeID = nil }
        do { play = try model.makePlaybackSession(for: episode) }
        catch { self.error = error.localizedDescription }
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
            .overlay {
                if query.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.system(size: 34)).foregroundStyle(BlofyTheme.textMuted)
                        Text("ابدأ الكتابة للبحث").font(.headline).foregroundStyle(BlofyTheme.textPrimary)
                        Text("يظهر البحث من أول حرف في البث والأفلام والمسلسلات.").font(.caption).foregroundStyle(BlofyTheme.textMuted).multilineTextAlignment(.center)
                    }.padding(.horizontal, 34)
                } else if results.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass.circle").font(.system(size: 34)).foregroundStyle(BlofyTheme.textMuted)
                        Text("ما لقينا نتائج").font(.headline).foregroundStyle(BlofyTheme.textPrimary)
                        Text("جرّب اسمًا مختلفًا.").font(.caption).foregroundStyle(BlofyTheme.textMuted)
                    }
                }
            }
            .scrollContentBackground(.hidden).background(BlofyTheme.backgroundGradient).navigationTitle("البحث").searchable(text: $query, prompt: "اكتب من أول حرف")
        }
    }
}
