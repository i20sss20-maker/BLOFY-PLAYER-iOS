import SwiftUI

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

                    HeroHeader()

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
