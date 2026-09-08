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
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)

                    if !continueItems.isEmpty {
                        SimpleSection(title: "متابعة المشاهدة", items: continueItems)
                    }
                    if !movies.isEmpty {
                        SimpleSection(title: "أفلام", items: movies)
                    }
                    if !series.isEmpty {
                        SimpleSection(title: "مسلسلات", items: series)
                    }
                }
                .padding(.vertical, 12)
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
    @State private var play: PlaybackSession?

    private var featured: MediaItem? {
        model.items.first(where: { $0.kind == .live }) ?? model.items.first(where: { $0.kind == .movie })
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let featured {
                Poster(url: featured.poster)
            } else {
                LinearGradient(colors: [BlofyTheme.purpleDeep, BlofyTheme.surfaceRaised], startPoint: .topLeading, endPoint: .bottomTrailing)
            }

            LinearGradient(colors: [.clear, .black.opacity(0.18), BlofyTheme.background.opacity(0.96)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 8) {
                Text(featured?.kind == .live ? "البث المباشر" : "BLOFY PLAYER")
                    .font(.caption.bold())
                    .foregroundStyle(BlofyTheme.mint)
                Text(featured?.name ?? model.selected?.name ?? "جاهز للمشاهدة")
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(BlofyTheme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    if let featured {
                        Button {
                            if featured.kind == .live {
                                tab = 1
                            } else if let session = try? model.makePlaybackSession(for: featured) {
                                play = session
                            }
                        } label: {
                            Label(featured.kind == .live ? "فتح البث" : "شاهد الآن", systemImage: "play.fill")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 15)
                                .padding(.vertical, 10)
                                .background(.white, in: Capsule())
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
        }
        .frame(height: 238)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(BlofyTheme.purpleSoft.opacity(0.24)))
        .shadow(color: BlofyTheme.purple.opacity(0.15), radius: 20, y: 10)
        .padding(.horizontal, 16)
        .fullScreenCover(item: $play) { PlayerScreen(session: $0) }
    }
}

private struct SimpleStat: View {
    let value: Int
    let title: String
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.headline.bold()).monospacedDigit().foregroundStyle(BlofyTheme.textPrimary)
            Text(title).font(.caption2).foregroundStyle(BlofyTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .blofyPanel(radius: 14)
    }
}

private struct SimpleLaunchButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2).foregroundStyle(BlofyTheme.purpleBright)
                Text(title).font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary)
                Text(subtitle).font(.caption2).foregroundStyle(BlofyTheme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .blofyPanel(radius: 18)
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
        .padding(.vertical, 10)
        .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BlofyTheme.divider))
    }
}

private struct SimpleSection: View {
    let title: String
    let items: [MediaItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.bold())
                .foregroundStyle(BlofyTheme.textPrimary)
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 11) {
                    ForEach(items) { item in
                        NavigationLink {
                            if item.kind == .series { SeriesDetailsView(series: item) }
                            else { DetailsView(item: item) }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Poster(url: item.poster)
                                    .frame(width: 132, height: 178)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                Text(item.name)
                                    .font(.caption.bold())
                                    .foregroundStyle(BlofyTheme.textPrimary)
                                    .lineLimit(1)
                                    .frame(width: 132, alignment: .leading)
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
