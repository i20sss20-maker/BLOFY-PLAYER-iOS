import SwiftUI

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
                Spacer()
                BlofyBrandMark()
                ZStack {
                    Circle().stroke(BlofyTheme.surfaceRaised, lineWidth: 11)
                    Circle().trim(from: 0, to: model.progress)
                        .stroke(BlofyTheme.primaryGradient, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(percent)٪").font(.system(size: 40, weight: .black, design: .rounded)).monospacedDigit()
                }
                .frame(width: 154, height: 154)
                Text(model.status.isEmpty ? "جاري تجهيز مكتبتك" : model.status)
                    .font(.headline).foregroundStyle(BlofyTheme.textPrimary).multilineTextAlignment(.center)
                HStack(spacing: 9) {
                    SyncStageBadge(title: "البث", done: model.progress >= 0.35)
                    SyncStageBadge(title: "الأفلام", done: model.progress >= 0.68)
                    SyncStageBadge(title: "المسلسلات", done: model.progress >= 0.94)
                }
                Text("يتم حفظ كل مرحلة تلقائيًا، وإذا خرجت من التطبيق نكمل من آخر مرحلة مكتملة.")
                    .font(.caption).foregroundStyle(BlofyTheme.textMuted).multilineTextAlignment(.center).padding(.horizontal, 34)
                Spacer()
            }
            .padding()
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
        .font(.caption.weight(.bold))
        .foregroundStyle(done ? BlofyTheme.mint : BlofyTheme.textMuted)
        .padding(.horizontal, 11).padding(.vertical, 8)
        .blofyPanel(radius: 14)
    }
}

struct EmptyHome: View {
    @EnvironmentObject var model: AppModel
    @Binding var showAdd: Bool
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            BlofyBrandMark()
            Text("مشغلك. مكتبتك. بطريقتك.")
                .font(.title3.bold()).foregroundStyle(BlofyTheme.textSecondary)
            Text("أضف Xtream أو M3U وابدأ المشاهدة")
                .font(.subheadline).foregroundStyle(BlofyTheme.textMuted)
            Button { showAdd = true } label: {
                Label("إضافة قائمة تشغيل", systemImage: "plus")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(BlofyTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain).foregroundStyle(.white).padding(.horizontal, 34)
            if !model.playlists.isEmpty {
                Menu("اختيار قائمة محفوظة") { ForEach(model.playlists) { p in Button(p.name) { model.choose(p) } } }
                    .foregroundStyle(BlofyTheme.purpleSoft)
            }
            Spacer()
        }
        .padding().foregroundStyle(BlofyTheme.textPrimary)
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
        .tint(BlofyTheme.purpleBright)
        .task { await model.loadCatalog() }
    }
}

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    private var continueItems: [ResumeEntry] { model.resume.values.sorted { $0.updatedAt > $1.updatedAt } }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    HeroHeader()
                    if !model.error.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(model.error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(BlofyTheme.error)
                            Button("إعادة المحاولة") { Task { await model.loadCatalog() } }
                                .buttonStyle(.borderedProminent).tint(BlofyTheme.purple)
                        }.padding(16).blofyPanel(radius: 18).padding(.horizontal, 16)
                    }
                    if !continueItems.isEmpty { SectionRow(title: "متابعة المشاهدة", subtitle: "كمل من حيث توقفت", items: continueItems.map { $0.item }) }
                    SectionRow(title: "البث المباشر", subtitle: "قنواتك الآن", items: Array(model.items.filter { $0.kind == .live }.prefix(22)))
                    SectionRow(title: "أحدث الأفلام", subtitle: "من مكتبتك", items: Array(model.items.filter { $0.kind == .movie }.prefix(22)))
                    SectionRow(title: "المسلسلات", subtitle: "مواسم وحلقات", items: Array(model.items.filter { $0.kind == .series }.prefix(22)))
                }.padding(.vertical, 14)
            }
            .background(BlofyTheme.backgroundGradient)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await model.loadCatalog(force: true) }
        }
    }
}

struct HeroHeader: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                BlofyBrandMark()
                Spacer()
                Menu {
                    ForEach(model.playlists) { p in Button(p.name) { model.choose(p); Task { await model.loadCatalog() } } }
                } label: {
                    Image(systemName: "server.rack").font(.headline).frame(width: 42, height: 42)
                        .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BlofyTheme.divider))
                }
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("جاهز للمشاهدة").font(.system(size: 26, weight: .black))
                    Text(model.selected?.name ?? "").font(.subheadline).foregroundStyle(BlofyTheme.textSecondary).lineLimit(1)
                }
                Spacer()
                ZStack {
                    Circle().fill(BlofyTheme.purpleDeep.opacity(0.9))
                    Image(systemName: "play.fill").foregroundStyle(BlofyTheme.purpleBright)
                }.frame(width: 56, height: 56)
            }
            .padding(18).background(BlofyTheme.heroGradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(BlofyTheme.purpleSoft.opacity(0.24)))
        }.padding(.horizontal, 16)
    }
}

struct SectionRow: View {
    let title: String
    var subtitle: String = ""
    let items: [MediaItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title3.bold()).foregroundStyle(BlofyTheme.textPrimary)
                    if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(BlofyTheme.textMuted) }
                }
                Spacer()
            }.padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 13) { ForEach(items) { MediaCard(item: $0) } }.padding(.horizontal, 16)
            }
        }
    }
}

struct MediaCard: View {
    @EnvironmentObject var model: AppModel
    let item: MediaItem
    private var width: CGFloat { item.kind == .live ? 170 : 142 }
    private var height: CGFloat { item.kind == .live ? 102 : 208 }
    var body: some View {
        NavigationLink {
            if item.kind == .series { SeriesDetailsView(series: item) } else { DetailsView(item: item) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Poster(url: item.poster).frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(BlofyTheme.divider.opacity(0.75)))
                    if model.favorites.contains(item.id) {
                        Image(systemName: "heart.fill").font(.caption).padding(7)
                            .background(.black.opacity(0.62), in: Circle()).foregroundStyle(BlofyTheme.purpleBright).padding(6)
                    }
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
            default:
                ZStack {
                    LinearGradient(colors: [BlofyTheme.surfaceRaised, BlofyTheme.purpleDeep.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "play.rectangle.fill").font(.largeTitle).foregroundStyle(BlofyTheme.purpleSoft)
                }
            }
        }.clipped()
    }
}
