import SwiftUI

struct CatalogView: View {
    @EnvironmentObject var model: AppModel
    let kind: ContentKind
    @State private var selectedCategory = "all"
    @State private var query = ""
    @State private var sortMode = "server"
    @State private var showCategories = false

    private var categories: [MediaCategory] { model.categories.filter { $0.kind == kind } }
    private var categoryTitle: String {
        selectedCategory == "all" ? "كل الفئات" : (categories.first { $0.key == selectedCategory }?.name ?? "الفئة")
    }
    private var shown: [MediaItem] {
        let filtered = model.items.filter {
            $0.kind == kind &&
            (selectedCategory == "all" || $0.categoryID == selectedCategory) &&
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
                header
                controls
                if !model.error.isEmpty { errorBanner }
                content
            }
            .background(BlofyTheme.backgroundGradient.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .searchable(text: $query, prompt: "ابحث في \(kind.title)")
            .refreshable { await model.loadCatalog(force: true) }
            .sheet(isPresented: $showCategories) {
                CategoryBrowserSheet(
                    title: kind.title,
                    categories: categories,
                    selected: $selectedCategory
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BlofyBrandMark(compact: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title).font(.title2.black()).foregroundStyle(BlofyTheme.textPrimary)
                Text(model.selected?.name ?? "BLOFY").font(.caption2).foregroundStyle(BlofyTheme.textMuted).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(shown.count)").font(.title3.bold().monospacedDigit()).foregroundStyle(BlofyTheme.textPrimary)
                Text("متاح").font(.caption2).foregroundStyle(BlofyTheme.textMuted)
            }
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
    }

    private var controls: some View {
        HStack(spacing: 9) {
            Button { showCategories = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")
                    Text(categoryTitle).lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption2.bold()).opacity(0.7)
                }
                .font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary)
                .padding(.horizontal, 13).frame(height: 43)
                .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(BlofyTheme.divider))
            }
            .buttonStyle(.plain)

            Menu {
                Button("ترتيب السيرفر") { sortMode = "server" }
                Button("أبجدي A → Z") { sortMode = "az" }
                Button("أبجدي Z → A") { sortMode = "za" }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary)
                    .frame(width: 43, height: 43)
                    .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(BlofyTheme.divider))
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
    }

    private var errorBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(model.error).lineLimit(2)
        }
        .font(.caption).foregroundStyle(BlofyTheme.error)
        .padding(.horizontal, 16).padding(.bottom, 8)
    }

    @ViewBuilder private var content: some View {
        if shown.isEmpty && !model.loading {
            CatalogEmptyState(query: query) { Task { await model.loadCatalog(force: true) } }
        } else if kind == .live {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 9) {
                    ForEach(shown) { item in
                        NavigationLink { DetailsView(item: item) } label: { LiveChannelRow(item: item) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 32)
            }
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 13)], spacing: 18) {
                    ForEach(shown) { item in
                        NavigationLink {
                            if item.kind == .series { SeriesDetailsView(series: item) }
                            else { DetailsView(item: item) }
                        } label: { PremiumCatalogCard(item: item) }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 32)
            }
        }
    }
}

private struct CategoryBrowserSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let categories: [MediaCategory]
    @Binding var selected: String
    @State private var query = ""

    private var filtered: [MediaCategory] {
        guard !query.isEmpty else { return categories }
        let q = normalizedSearch(query)
        return categories.filter { normalizedSearch($0.name).contains(q) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 8) {
                    categoryRow(key: "all", name: "كل الفئات", icon: "square.grid.2x2.fill")
                    ForEach(filtered) { category in
                        categoryRow(key: category.key, name: category.name, icon: "folder.fill")
                    }
                }
                .padding(16).padding(.bottom, 20)
            }
            .background(BlofyTheme.backgroundGradient)
            .navigationTitle("فئات \(title)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "ابحث عن فئة")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("تم") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func categoryRow(key: String, name: String, icon: String) -> some View {
        Button {
            selected = key
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(selected == key ? .white : BlofyTheme.purpleSoft).frame(width: 28)
                Text(name).font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary).lineLimit(2)
                Spacer()
                if selected == key { Image(systemName: "checkmark.circle.fill").foregroundStyle(BlofyTheme.mint) }
                else { Image(systemName: "chevron.left").font(.caption.bold()).foregroundStyle(BlofyTheme.textMuted) }
            }
            .padding(14)
            .background(selected == key ? AnyShapeStyle(BlofyTheme.primaryGradient) : AnyShapeStyle(BlofyTheme.surface), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05)))
        }
        .buttonStyle(.plain)
    }
}

private struct CatalogEmptyState: View {
    let query: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 13) {
            Spacer()
            Image(systemName: query.isEmpty ? "rectangle.stack.badge.minus" : "magnifyingglass")
                .font(.system(size: 42, weight: .semibold)).foregroundStyle(BlofyTheme.textMuted)
            Text(query.isEmpty ? "ما فيه محتوى هنا" : "ما لقينا نتائج").font(.headline).foregroundStyle(BlofyTheme.textPrimary)
            Text(query.isEmpty ? "جرّب فئة ثانية أو حدّث المحتوى." : "جرّب اسمًا مختلفًا.")
                .font(.caption).foregroundStyle(BlofyTheme.textMuted).multilineTextAlignment(.center)
            if query.isEmpty {
                Button("تحديث المحتوى", action: retry).font(.subheadline.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 17).padding(.vertical, 10).background(BlofyTheme.primaryGradient, in: Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

private struct LiveChannelRow: View {
    @EnvironmentObject var model: AppModel
    let item: MediaItem
    var body: some View {
        HStack(spacing: 12) {
            if model.showChannelLogos {
                Poster(url: item.poster).frame(width: 62, height: 48).clipShape(RoundedRectangle(cornerRadius: 11))
            } else {
                Image(systemName: "tv.fill").frame(width: 62, height: 48)
                    .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 11)).foregroundStyle(BlofyTheme.purpleSoft)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary).lineLimit(2)
                HStack(spacing: 5) {
                    Circle().fill(BlofyTheme.mint).frame(width: 5, height: 5)
                    Text("مباشر الآن").font(.caption2.bold()).foregroundStyle(BlofyTheme.mint)
                }
            }
            Spacer()
            if model.favorites.contains(item.id) { Image(systemName: "heart.fill").foregroundStyle(BlofyTheme.purpleBright) }
            Image(systemName: "play.circle.fill").font(.title3).foregroundStyle(BlofyTheme.textSecondary)
        }
        .padding(11).blofyPanel(radius: 16)
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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                hero
                actionBar
                if loadingDetail {
                    HStack(spacing: 9) { ProgressView().tint(BlofyTheme.purpleBright); Text("جاري تجهيز التفاصيل…").font(.caption).foregroundStyle(BlofyTheme.textMuted) }
                }
                if let r = resumeEntry, r.duration > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("متابعة المشاهدة", systemImage: "clock.arrow.circlepath").font(.subheadline.bold())
                            Spacer()
                            Text("\(Int(resumeProgress * 100))٪").font(.caption.bold().monospacedDigit()).foregroundStyle(BlofyTheme.textMuted)
                        }
                        ProgressView(value: resumeProgress).tint(BlofyTheme.purpleBright)
                    }.padding(14).blofyPanel(radius: 17)
                }
                if !item.plot.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("القصة", systemImage: "text.alignright").font(.headline.bold()).foregroundStyle(BlofyTheme.textPrimary)
                        Text(item.plot).font(.body).foregroundStyle(BlofyTheme.textSecondary).lineSpacing(5)
                    }.padding(16).blofyPanel(radius: 19)
                }
            }
            .padding(16).padding(.bottom, 10)
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

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Poster(url: item.poster).frame(maxWidth: .infinity).frame(height: item.kind == .live ? 260 : 410).clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.16), BlofyTheme.background.opacity(0.99)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    if item.kind == .live { Circle().fill(BlofyTheme.mint).frame(width: 6, height: 6) }
                    Text(item.kind == .live ? "مباشر" : "BLOFY").font(.caption2.bold()).tracking(1.4).foregroundStyle(item.kind == .live ? BlofyTheme.mint : BlofyTheme.purpleBright)
                }
                Text(item.name).font(.system(size: 30, weight: .black)).foregroundStyle(BlofyTheme.textPrimary).lineLimit(3)
                HStack(spacing: 8) {
                    if model.showRatings && !item.rating.isEmpty {
                        Label(item.rating, systemImage: "star.fill").font(.caption.bold()).foregroundStyle(BlofyTheme.purpleSoft)
                    }
                    if resumeEntry != nil { Label("متابعة", systemImage: "clock.fill").font(.caption.bold()).foregroundStyle(BlofyTheme.mint) }
                }
            }.padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 27).stroke(Color.white.opacity(0.06)))
    }

    private var actionBar: some View {
        HStack(spacing: 11) {
            Button { Task { await start() } } label: {
                HStack(spacing: 9) {
                    if preparingPlayback { ProgressView().tint(.white) }
                    else { Image(systemName: resumeEntry == nil ? "play.fill" : "arrow.clockwise") }
                    Text(preparingPlayback ? "جاري التجهيز…" : (resumeEntry == nil ? "تشغيل" : "استئناف"))
                }
                .font(.headline).frame(maxWidth: .infinity).frame(height: 54)
                .background(BlofyTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 17))
            }
            .buttonStyle(.plain).foregroundStyle(.white).disabled(preparingPlayback)

            Button { model.toggleFavorite(item) } label: {
                Image(systemName: model.favorites.contains(item.id) ? "heart.fill" : "heart")
                    .font(.headline).frame(width: 54, height: 54)
                    .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(BlofyTheme.divider))
            }
            .buttonStyle(.plain).foregroundStyle(BlofyTheme.purpleSoft)
        }
    }

    @MainActor private func start() async {
        guard !preparingPlayback else { return }
        preparingPlayback = true
        defer { preparingPlayback = false }
        if item.kind == .movie { item = await model.detailedMovie(item) }
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
        episodes.compactMap { ep -> (MediaItem, Date)? in
            guard let r = model.resume[ep.id] else { return nil }
            return (ep, r.updatedAt)
        }.sorted { $0.1 > $1.1 }.first?.0
    }
    private var nextEpisode: MediaItem? { resumableEpisode ?? episodes.first }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                seriesHero
                if let nextEpisode { resumeButton(nextEpisode) }
                favoriteButton
                if loading { HStack { ProgressView().tint(BlofyTheme.purpleBright); Text("جاري تحميل الحلقات…").font(.caption).foregroundStyle(BlofyTheme.textMuted) } }
                if !error.isEmpty { Text(error).foregroundStyle(BlofyTheme.error) }
                if !loading && episodes.isEmpty && error.isEmpty { emptyEpisodes }
                if !seasons.isEmpty { seasonPicker }
                LazyVStack(spacing: 10) {
                    ForEach(visibleEpisodes) { episode in
                        EpisodeRow(episode: episode, resume: model.resume[episode.id], loading: preparingEpisodeID == episode.id) { start(episode) }
                            .disabled(preparingEpisodeID != nil)
                    }
                }
            }
            .padding(16).padding(.bottom, 10)
        }
        .background(BlofyTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle(series.name).navigationBarTitleDisplayMode(.inline)
        .task {
            do { episodes = try await model.episodes(for: series); selectedSeason = seasons.first }
            catch { self.error = error.localizedDescription }
            loading = false
        }
        .fullScreenCover(item: $play) { PlayerScreen(session: $0) }
    }

    private var seriesHero: some View {
        ZStack(alignment: .bottomLeading) {
            Poster(url: series.poster).frame(maxWidth: .infinity).frame(height: 370).clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.18), BlofyTheme.background.opacity(0.99)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                Text("BLOFY SERIES").font(.caption2.bold()).tracking(1.6).foregroundStyle(BlofyTheme.purpleBright)
                Text(series.name).font(.system(size: 30, weight: .black)).foregroundStyle(BlofyTheme.textPrimary).lineLimit(3)
                if !episodes.isEmpty { Text("\(seasons.count) موسم · \(episodes.count) حلقة").font(.caption).foregroundStyle(BlofyTheme.textMuted) }
            }.padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 27).stroke(Color.white.opacity(0.06)))
    }

    private func resumeButton(_ episode: MediaItem) -> some View {
        Button { start(episode) } label: {
            HStack(spacing: 12) {
                Image(systemName: resumableEpisode == nil ? "play.fill" : "arrow.clockwise").frame(width: 36, height: 36).background(.white.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(resumableEpisode == nil ? "ابدأ المشاهدة" : "استئناف المسلسل").font(.headline)
                    Text("الموسم \(episode.season) · الحلقة \(episode.episode)").font(.caption).opacity(0.82)
                }
                Spacer()
                if preparingEpisodeID == episode.id { ProgressView().tint(.white) }
                else { Image(systemName: "chevron.left").font(.caption.bold()) }
            }
            .padding(14).background(BlofyTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 19)).foregroundStyle(.white)
        }
        .buttonStyle(.plain).disabled(preparingEpisodeID != nil)
    }

    private var favoriteButton: some View {
        Button { model.toggleFavorite(series) } label: {
            Label(model.favorites.contains(series.id) ? "في المفضلة" : "إضافة للمفضلة", systemImage: model.favorites.contains(series.id) ? "heart.fill" : "heart")
                .font(.subheadline.bold()).frame(maxWidth: .infinity).frame(height: 48)
                .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(BlofyTheme.divider))
        }.buttonStyle(.plain).foregroundStyle(BlofyTheme.textPrimary)
    }

    private var emptyEpisodes: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.stack.badge.minus").font(.title).foregroundStyle(BlofyTheme.textMuted)
            Text("ما لقينا حلقات").font(.headline)
            Text("جرّب تحديث المحتوى أو المحاولة لاحقًا.").font(.caption).foregroundStyle(BlofyTheme.textMuted)
        }.frame(maxWidth: .infinity).padding(.vertical, 32).blofyPanel(radius: 18)
    }

    private var seasonPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("المواسم").font(.headline.bold()); Spacer(); Text("\(visibleEpisodes.count) حلقة").font(.caption2).foregroundStyle(BlofyTheme.textMuted) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(seasons, id: \.self) { season in
                        Button { withAnimation(.easeOut(duration: 0.16)) { selectedSeason = season } } label: {
                            Text("الموسم \(season)").font(.caption.bold()).foregroundStyle(.white)
                                .padding(.horizontal, 14).frame(height: 38)
                                .background(selectedSeason == season ? AnyShapeStyle(BlofyTheme.primaryGradient) : AnyShapeStyle(BlofyTheme.surfaceRaised), in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func start(_ episode: MediaItem) {
        guard preparingEpisodeID == nil else { return }
        preparingEpisodeID = episode.id
        defer { preparingEpisodeID = nil }
        do { play = try model.makePlaybackSession(for: episode) }
        catch { self.error = error.localizedDescription }
    }
}

private struct EpisodeRow: View {
    let episode: MediaItem
    let resume: ResumeEntry?
    let loading: Bool
    let action: () -> Void
    private var progress: Double {
        guard let resume, resume.duration > 0 else { return 0 }
        return min(max(resume.seconds / resume.duration, 0), 1)
    }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomLeading) {
                    Poster(url: episode.poster).frame(width: 132, height: 80).clipShape(RoundedRectangle(cornerRadius: 13))
                    if progress > 0 { ProgressView(value: progress).tint(BlofyTheme.purpleBright).frame(width: 120).padding(6) }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("الحلقة \(episode.episode)").font(.headline).foregroundStyle(BlofyTheme.textPrimary)
                    Text(episode.name).font(.caption).foregroundStyle(BlofyTheme.textMuted).lineLimit(2)
                    if progress > 0 { Text("متابعة من \(Int(progress * 100))٪").font(.caption2.bold()).foregroundStyle(BlofyTheme.mint) }
                }
                Spacer()
                if loading { ProgressView().tint(BlofyTheme.purpleSoft) }
                else { Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(BlofyTheme.purpleSoft) }
            }.padding(10).blofyPanel(radius: 16)
        }.buttonStyle(.plain)
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
                    if item.kind == .series { SeriesDetailsView(series: item) }
                    else { DetailsView(item: item) }
                } label: {
                    HStack(spacing: 12) {
                        Poster(url: item.poster).frame(width: 62, height: 82).clipShape(RoundedRectangle(cornerRadius: 11))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name).font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary)
                            Text(item.kind.title).font(.caption).foregroundStyle(BlofyTheme.purpleSoft)
                        }
                    }
                }.listRowBackground(BlofyTheme.surface.opacity(0.82))
            }
            .overlay {
                if query.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.system(size: 34)).foregroundStyle(BlofyTheme.textMuted)
                        Text("ابحث عن أي محتوى").font(.headline).foregroundStyle(BlofyTheme.textPrimary)
                        Text("اكتب اسم القناة أو الفيلم أو المسلسل.").font(.caption).foregroundStyle(BlofyTheme.textMuted)
                    }
                } else if results.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass.circle").font(.system(size: 34)).foregroundStyle(BlofyTheme.textMuted)
                        Text("ما لقينا نتائج").font(.headline).foregroundStyle(BlofyTheme.textPrimary)
                    }
                }
            }
            .scrollContentBackground(.hidden).background(BlofyTheme.backgroundGradient)
            .navigationTitle("البحث").searchable(text: $query, prompt: "اكتب للبحث")
        }
    }
}
