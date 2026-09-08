import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var model: AppModel
    @State private var filter = "all"

    private var favoriteItems: [MediaItem] { model.items.filter { model.favorites.contains($0.id) } }
    private var resumeEntries: [ResumeEntry] { model.resume.values.sorted { $0.updatedAt > $1.updatedAt } }
    private var filteredFavorites: [MediaItem] {
        switch filter {
        case "live": return favoriteItems.filter { $0.kind == .live }
        case "movie": return favoriteItems.filter { $0.kind == .movie }
        case "series": return favoriteItems.filter { $0.kind == .series || $0.kind == .episode }
        default: return favoriteItems
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    HStack {
                        BlofyBrandMark()
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("مكتبتي").font(.title2.bold())
                            Text("\(favoriteItems.count) مفضلة · \(resumeEntries.count) متابعة")
                                .font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8)

                    if let latest = resumeEntries.first {
                        LibraryHero(entry: latest)
                            .padding(.horizontal, 16)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if !resumeEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("متابعة المشاهدة").font(.headline.bold())
                                Spacer()
                                Text("\(resumeEntries.count)").font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                            }.padding(.horizontal, 16)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(resumeEntries, id: \.item.id) { entry in
                                        ResumeLibraryCard(entry: entry)
                                    }
                                }.padding(.horizontal, 16)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("المفضلة").font(.headline.bold())
                            Spacer()
                            Menu {
                                Button("الكل") { withAnimation(.easeInOut(duration: 0.18)) { filter = "all" } }
                                Button("البث") { withAnimation(.easeInOut(duration: 0.18)) { filter = "live" } }
                                Button("الأفلام") { withAnimation(.easeInOut(duration: 0.18)) { filter = "movie" } }
                                Button("المسلسلات") { withAnimation(.easeInOut(duration: 0.18)) { filter = "series" } }
                            } label: {
                                Label(filterTitle, systemImage: "line.3.horizontal.decrease.circle.fill")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 11).padding(.vertical, 7)
                                    .background(BlofyTheme.surfaceRaised, in: Capsule())
                            }
                            .foregroundStyle(BlofyTheme.textPrimary)
                        }.padding(.horizontal, 16)

                        if filteredFavorites.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "heart.slash").font(.system(size: 42)).foregroundStyle(BlofyTheme.textMuted)
                                Text("ما فيه عناصر هنا").font(.headline)
                                Text("أضف قناة أو فيلم أو مسلسل للمفضلة، وبتلقاه هنا مباشرة.")
                                    .font(.caption).multilineTextAlignment(.center).foregroundStyle(BlofyTheme.textMuted)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 44).blofyPanel(radius: 22).padding(.horizontal, 16)
                            .transition(.opacity)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 12)], spacing: 14) {
                                ForEach(filteredFavorites) { item in
                                    LibraryFavoriteCard(item: item)
                                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                                }
                            }.padding(.horizontal, 16)
                        }
                    }
                }.padding(.bottom, 34)
            }
            .background(BlofyTheme.backgroundGradient)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var filterTitle: String {
        switch filter { case "live": return "البث"; case "movie": return "الأفلام"; case "series": return "المسلسلات"; default: return "الكل" }
    }
}

private struct LibraryHero: View {
    @EnvironmentObject var model: AppModel
    let entry: ResumeEntry
    @State private var play: PlaybackSession?

    private var progress: Double {
        guard entry.duration > 0 else { return 0 }
        return min(max(entry.seconds / entry.duration, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Poster(url: entry.item.poster)
                .frame(maxWidth: .infinity).frame(height: 190).clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                Text("آخر مشاهدة").font(.caption.bold()).foregroundStyle(BlofyTheme.mint)
                Text(entry.item.name).font(.title3.bold()).lineLimit(2)
                ProgressView(value: progress).tint(BlofyTheme.purpleBright)
                HStack {
                    Text("\(Int(progress * 100))٪").font(.caption2.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Button {
                        if let session = try? model.makePlaybackSession(for: entry.item) { play = session }
                    } label: {
                        Label("استئناف", systemImage: "play.fill").font(.subheadline.bold())
                            .padding(.horizontal, 14).padding(.vertical, 9).background(.white, in: Capsule()).foregroundStyle(.black)
                    }.buttonStyle(.plain)
                }
            }.padding(16)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(BlofyTheme.divider))
        .fullScreenCover(item: $play) { PlayerScreen(session: $0) }
    }
}

private struct ResumeLibraryCard: View {
    @EnvironmentObject var model: AppModel
    let entry: ResumeEntry
    @State private var play: PlaybackSession?
    private var progress: Double { entry.duration > 0 ? min(max(entry.seconds / entry.duration, 0), 1) : 0 }

    var body: some View {
        Button {
            if let session = try? model.makePlaybackSession(for: entry.item) { play = session }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .bottomLeading) {
                    Poster(url: entry.item.poster).frame(width: 152, height: 92).clipShape(RoundedRectangle(cornerRadius: 14))
                    ProgressView(value: progress).tint(BlofyTheme.purpleBright).padding(8)
                }
                Text(entry.item.name).font(.caption.bold()).foregroundStyle(BlofyTheme.textPrimary).lineLimit(1).frame(width: 152, alignment: .leading)
                Text("متابعة من \(Int(progress * 100))٪").font(.caption2).foregroundStyle(BlofyTheme.textMuted)
            }
        }.buttonStyle(.plain).fullScreenCover(item: $play) { PlayerScreen(session: $0) }
    }
}

private struct LibraryFavoriteCard: View {
    @EnvironmentObject var model: AppModel
    let item: MediaItem
    @State private var play: PlaybackSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Poster(url: item.poster).aspectRatio(0.72, contentMode: .fill).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 16))
                Button { model.toggleFavorite(item) } label: {
                    Image(systemName: "heart.fill").font(.caption.bold()).frame(width: 32, height: 32)
                        .background(.black.opacity(0.7), in: Circle()).foregroundStyle(BlofyTheme.purpleSoft)
                }.buttonStyle(.plain).padding(7)
            }
            Text(item.name).font(.caption.bold()).foregroundStyle(BlofyTheme.textPrimary).lineLimit(2)
            Text(item.kind.title).font(.caption2).foregroundStyle(BlofyTheme.textMuted)
            if item.kind != .series {
                Button {
                    if let session = try? model.makePlaybackSession(for: item) { play = session }
                } label: { Label("تشغيل", systemImage: "play.fill").font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 8).background(BlofyTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(.white) }
                    .buttonStyle(.plain)
            }
        }
        .padding(10).background(BlofyTheme.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(BlofyTheme.divider))
        .fullScreenCover(item: $play) { PlayerScreen(session: $0) }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Binding var showAdd: Bool

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack { BlofyBrandMark(); Spacer(); Text("الإعدادات").font(.title2.bold()) }
                        .padding(.horizontal, 16).padding(.top, 8)

                    SettingsCard(title: "القوائم", icon: "server.rack") {
                        ForEach(model.playlists) { playlist in
                            Button {
                                model.choose(playlist)
                                Task { await model.loadCatalog() }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: playlist.type == "m3u" ? "list.bullet.rectangle" : "server.rack")
                                        .foregroundStyle(BlofyTheme.purpleSoft).frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name).foregroundStyle(BlofyTheme.textPrimary)
                                        Text(playlist.type.uppercased()).font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                                    }
                                    Spacer()
                                    if model.selected?.id == playlist.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(BlofyTheme.mint) }
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Divider().overlay(BlofyTheme.divider)
                        }
                        HStack(spacing: 10) {
                            Button { showAdd = true } label: { Label("إضافة قائمة", systemImage: "plus") }.blofyAction(primary: true)
                            Button { Task { await model.loadCatalog(force: true) } } label: { Label("تحديث", systemImage: "arrow.clockwise") }.blofyAction()
                        }
                    }

                    SettingsCard(title: "التشغيل", icon: "play.rectangle.fill") {
                        SettingPickerRow(title: "المحرك", subtitle: "اختيار المحرك المناسب تلقائيًا أو يدويًا") {
                            Picker("المحرك", selection: $model.preferredEngine) {
                                Text("تلقائي").tag("auto")
                                Text("Apple").tag("apple")
                                Text("VLC").tag("vlc")
                            }.pickerStyle(.segmented)
                        }
                        Divider().overlay(BlofyTheme.divider)
                        SettingPickerRow(title: "البافر", subtitle: "سريع للقنوات أو مستقر للاتصالات الضعيفة") {
                            Picker("البافر", selection: $model.bufferProfile) {
                                Text("سريع").tag("fast")
                                Text("متوازن").tag("balanced")
                                Text("مستقر").tag("stable")
                            }.pickerStyle(.segmented)
                        }
                        Divider().overlay(BlofyTheme.divider)
                        SettingPickerRow(title: "صيغة البث", subtitle: "TS أو HLS حسب السيرفر") {
                            Picker("صيغة البث", selection: $model.liveFormat) {
                                Text("TS").tag("ts")
                                Text("HLS").tag("m3u8")
                            }.pickerStyle(.segmented)
                        }
                        .onChange(of: model.liveFormat) { model.setLiveFormat($0) }
                        Divider().overlay(BlofyTheme.divider)
                        SettingToggleRow(title: "تشغيل البث تلقائيًا", icon: "bolt.fill", isOn: $model.autoPlayLive)
                        Divider().overlay(BlofyTheme.divider)
                        NavigationLink {
                            PlayerAdvancedSettingsView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "slider.horizontal.3").foregroundStyle(BlofyTheme.purpleBright).frame(width: 30)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("إعدادات المشغل المتقدمة").font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary)
                                    Text("الصوت · الترجمة · السرعة · نسبة العرض").font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                                }
                                Spacer()
                                Image(systemName: "chevron.left").font(.caption.bold()).foregroundStyle(BlofyTheme.textMuted)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }

                    SettingsCard(title: "المظهر والتجربة", icon: "sparkles") {
                        SettingToggleRow(title: "إظهار شعارات القنوات", icon: "photo", isOn: $model.showChannelLogos)
                        Divider().overlay(BlofyTheme.divider)
                        SettingToggleRow(title: "إظهار التقييمات", icon: "star.fill", isOn: $model.showRatings)
                        Divider().overlay(BlofyTheme.divider)
                        SettingToggleRow(title: "الاهتزازات اللمسية", icon: "iphone.radiowaves.left.and.right", isOn: $model.hapticsEnabled)
                    }

                    SettingsCard(title: "اللغة", icon: "globe") {
                        Picker("لغة التطبيق", selection: $model.language) {
                            Text("العربية").tag("ar")
                            Text("English").tag("en")
                        }.pickerStyle(.segmented)
                    }

                    SettingsCard(title: "الجهاز والتفعيل", icon: "qrcode") {
                        SettingValueRow(title: "Device ID", value: model.deviceID)
                        Divider().overlay(BlofyTheme.divider)
                        SettingValueRow(title: "Code", value: model.activationCode)
                        if !model.activationStatus.isEmpty {
                            Divider().overlay(BlofyTheme.divider)
                            SettingValueRow(title: "الحالة", value: model.activationStatus)
                        }
                    }

                    SettingsCard(title: "حول BLOFY", icon: "info.circle.fill") {
                        SettingValueRow(title: "النسخة", value: versionLabel)
                        Text("محرك هجين Apple + VLC، بث سريع، EPG، مفضلة، متابعة مشاهدة، صوت وترجمة وتحكم متقدم.")
                            .font(.caption).foregroundStyle(BlofyTheme.textMuted).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(BlofyTheme.backgroundGradient)
            .toolbar(.hidden, for: .navigationBar)
            .onDisappear { model.saveSettings() }
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(BlofyTheme.textPrimary)
            content
        }
        .padding(16).blofyPanel(radius: 22).padding(.horizontal, 16)
    }
}

private struct SettingToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: icon).foregroundStyle(BlofyTheme.textSecondary)
        }.tint(BlofyTheme.purpleBright)
    }
}

private struct SettingPickerRow<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary)
            Text(subtitle).font(.caption2).foregroundStyle(BlofyTheme.textMuted)
            content
        }
    }
}

private struct SettingValueRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack { Text(title).foregroundStyle(BlofyTheme.textSecondary); Spacer(); Text(value).font(.caption.monospaced()).foregroundStyle(BlofyTheme.purpleSoft).lineLimit(1) }
    }
}

private extension View {
    func blofyAction(primary: Bool = false) -> some View {
        self.font(.subheadline.bold()).foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 10)
            .background(primary ? AnyShapeStyle(BlofyTheme.primaryGradient) : AnyShapeStyle(BlofyTheme.surfaceRaised), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct AddPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: AppModel
    @State private var name = ""
    @State private var type = "xtream"
    @State private var url = ""
    @State private var user = ""
    @State private var pass = ""

    var body: some View {
        NavigationStack {
            Form {
                Section { HStack { Spacer(); BlofyBrandMark(); Spacer() }.padding(.vertical, 8) }.listRowBackground(BlofyTheme.surface.opacity(0.9))
                Section("نوع القائمة") {
                    Picker("النوع", selection: $type) { Text("Xtream Codes").tag("xtream"); Text("M3U / M3U8").tag("m3u") }.pickerStyle(.segmented)
                }.listRowBackground(BlofyTheme.surface.opacity(0.86))
                Section("بيانات القائمة") {
                    TextField("اسم القائمة", text: $name)
                    TextField(type == "xtream" ? "Server URL" : "M3U URL", text: $url).textInputAutocapitalization(.never).keyboardType(.URL)
                    if type == "xtream" { TextField("Username", text: $user).textInputAutocapitalization(.never); SecureField("Password", text: $pass) }
                    if !model.error.isEmpty { Text(model.error).foregroundStyle(BlofyTheme.error) }
                }.listRowBackground(BlofyTheme.surface.opacity(0.86))
            }
            .scrollContentBackground(.hidden).background(BlofyTheme.backgroundGradient).navigationTitle("إضافة قائمة")
            .toolbarBackground(BlofyTheme.backgroundRaised, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() }.foregroundStyle(BlofyTheme.textSecondary) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") { model.addPlaylist(name: name, type: type, url: url, username: user, password: pass); if model.error.isEmpty { dismiss(); Task { await model.loadCatalog(force: true) } } }
                        .foregroundStyle(BlofyTheme.purpleBright).fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { model.error = "" }
    }
}
