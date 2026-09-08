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
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 22) {
                    HStack {
                        BlofyBrandMark(compact: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("مكتبتي").font(.title2.black())
                            Text("محفوظاتك ومتابعة المشاهدة").font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.top, 8)

                    if let latest = resumeEntries.first { LibraryHero(entry: latest).padding(.horizontal, 16) }

                    if !resumeEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("متابعة المشاهدة").font(.headline.bold()).padding(.horizontal, 16)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(resumeEntries, id: \.item.id) { ResumeLibraryCard(entry: $0) }
                                }.padding(.horizontal, 16)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("المفضلة").font(.headline.bold())
                            Spacer()
                            Menu {
                                Button("الكل") { filter = "all" }
                                Button("البث") { filter = "live" }
                                Button("الأفلام") { filter = "movie" }
                                Button("المسلسلات") { filter = "series" }
                            } label: {
                                Label(filterTitle, systemImage: "line.3.horizontal.decrease.circle.fill")
                                    .font(.caption.bold()).padding(.horizontal, 11).padding(.vertical, 7)
                                    .background(BlofyTheme.surfaceRaised, in: Capsule())
                            }.foregroundStyle(BlofyTheme.textPrimary)
                        }.padding(.horizontal, 16)

                        if filteredFavorites.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "heart.slash").font(.system(size: 40)).foregroundStyle(BlofyTheme.textMuted)
                                Text("المفضلة فارغة").font(.headline)
                                Text("أضف ما يعجبك وبتلقاه هنا مباشرة.").font(.caption).foregroundStyle(BlofyTheme.textMuted)
                            }.frame(maxWidth: .infinity).padding(.vertical, 40).blofyPanel(radius: 22).padding(.horizontal, 16)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 12)], spacing: 14) {
                                ForEach(filteredFavorites) { LibraryFavoriteCard(item: $0) }
                            }.padding(.horizontal, 16)
                        }
                    }
                }.padding(.bottom, 34)
            }
            .background(BlofyTheme.backgroundGradient).toolbar(.hidden, for: .navigationBar)
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
    private var progress: Double { entry.duration > 0 ? min(max(entry.seconds / entry.duration, 0), 1) : 0 }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Poster(url: entry.item.poster).frame(maxWidth: .infinity).frame(height: 190).clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
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
                        Label("استئناف", systemImage: "play.fill").font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 9).background(.white, in: Capsule()).foregroundStyle(.black)
                    }.buttonStyle(.plain)
                }
            }.padding(16)
        }
        .frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.06)))
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
                    Image(systemName: "heart.fill").font(.caption.bold()).frame(width: 32, height: 32).background(.black.opacity(0.7), in: Circle()).foregroundStyle(BlofyTheme.purpleSoft)
                }.buttonStyle(.plain).padding(7)
            }
            Text(item.name).font(.caption.bold()).foregroundStyle(BlofyTheme.textPrimary).lineLimit(2)
            Text(item.kind.title).font(.caption2).foregroundStyle(BlofyTheme.textMuted)
            if item.kind != .series {
                Button {
                    if let session = try? model.makePlaybackSession(for: item) { play = session }
                } label: {
                    Label("تشغيل", systemImage: "play.fill").font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 8).background(BlofyTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(.white)
                }.buttonStyle(.plain)
            }
        }
        .padding(10).blofyPanel(radius: 18)
        .fullScreenCover(item: $play) { PlayerScreen(session: $0) }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Binding var showAdd: Bool
    @AppStorage("blofyThemeStyle") private var themeStyle = "signature"

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    settingsHeader

                    SettingsCard(title: "التجربة", subtitle: "اضبط التطبيق بالطريقة اللي تناسبك", icon: "sparkles") {
                        SettingToggleRow(title: "شعارات القنوات", subtitle: "إظهار شعار القناة في القوائم", icon: "photo", isOn: $model.showChannelLogos)
                        Divider().overlay(BlofyTheme.divider)
                        SettingToggleRow(title: "التقييمات", subtitle: "إظهار تقييم المحتوى إذا كان متوفر", icon: "star.fill", isOn: $model.showRatings)
                        Divider().overlay(BlofyTheme.divider)
                        SettingToggleRow(title: "التشغيل التلقائي للبث", subtitle: "ابدأ القناة بسرعة عند الدخول", icon: "bolt.fill", isOn: $model.autoPlayLive)
                        Divider().overlay(BlofyTheme.divider)
                        SettingToggleRow(title: "الاهتزازات", subtitle: "ردود فعل خفيفة أثناء الاستخدام", icon: "iphone.radiowaves.left.and.right", isOn: $model.hapticsEnabled)
                    }

                    SettingsCard(title: "مظهر BLOFY", subtitle: "كلها بنفس الهوية، باختلاف الجو العام", icon: "paintpalette.fill") {
                        Picker("الثيم", selection: $themeStyle) {
                            Text("BLOFY").tag("signature")
                            Text("Midnight").tag("midnight")
                            Text("Graphite").tag("graphite")
                        }.pickerStyle(.segmented)
                        HStack(spacing: 8) {
                            ThemeDot(style: "signature", selected: themeStyle == "signature")
                            ThemeDot(style: "midnight", selected: themeStyle == "midnight")
                            ThemeDot(style: "graphite", selected: themeStyle == "graphite")
                        }
                    }

                    SettingsCard(title: "المشاهدة", subtitle: "الصوت والترجمة والصورة", icon: "play.rectangle.fill") {
                        SettingsLink(title: "تفضيلات المشاهدة", subtitle: "الصوت · الترجمة · حجم الترجمة · العرض", icon: "slider.horizontal.3") {
                            PlayerAdvancedSettingsView()
                        }
                    }

                    SettingsCard(title: "القوائم والسيرفرات", subtitle: "إدارة المحتوى المرتبط بجهازك", icon: "server.rack") {
                        ForEach(model.playlists) { playlist in
                            Button {
                                model.choose(playlist)
                                Task { await model.loadCatalog() }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "server.rack").foregroundStyle(BlofyTheme.purpleSoft).frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name).foregroundStyle(BlofyTheme.textPrimary)
                                        Text(model.selected?.id == playlist.id ? "متصل الآن" : "جاهز للتبديل").font(.caption2).foregroundStyle(model.selected?.id == playlist.id ? BlofyTheme.mint : BlofyTheme.textMuted)
                                    }
                                    Spacer()
                                    if model.selected?.id == playlist.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(BlofyTheme.mint) }
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Divider().overlay(BlofyTheme.divider)
                        }
                        HStack(spacing: 10) {
                            Button { showAdd = true } label: { Label("إضافة", systemImage: "plus") }.blofyAction(primary: true)
                            Button { Task { await model.loadCatalog(force: true) } } label: { Label("تحديث المحتوى", systemImage: "arrow.clockwise") }.blofyAction()
                        }
                    }

                    SettingsCard(title: "اللغة", subtitle: "لغة واجهة التطبيق", icon: "globe") {
                        Picker("لغة التطبيق", selection: $model.language) {
                            Text("العربية").tag("ar")
                            Text("English").tag("en")
                        }.pickerStyle(.segmented)
                    }

                    SettingsCard(title: "متقدم", subtitle: "خيارات لا تحتاج تغيرها غالبًا", icon: "gearshape.2.fill") {
                        SettingsLink(title: "إعدادات الاتصال والتشغيل", subtitle: "للمستخدم المتقدم فقط", icon: "wrench.and.screwdriver.fill") {
                            TechnicalPlaybackSettingsView()
                        }
                    }

                    SettingsCard(title: "الجهاز", subtitle: "بيانات جهاز BLOFY", icon: "qrcode") {
                        SettingValueRow(title: "رقم الجهاز", value: model.deviceID)
                        Divider().overlay(BlofyTheme.divider)
                        SettingValueRow(title: "رمز الدخول", value: model.activationCode)
                        if !model.activationStatus.isEmpty {
                            Divider().overlay(BlofyTheme.divider)
                            SettingValueRow(title: "الحالة", value: model.activationStatus)
                        }
                    }

                    SettingsCard(title: "حول BLOFY", subtitle: "BLOFY PLAYER", icon: "info.circle.fill") {
                        SettingValueRow(title: "الإصدار", value: versionLabel)
                        Text("BLOFY PLAYER مصمم لتجربة مشاهدة بسيطة وسريعة، بدون إظهار التفاصيل التقنية للمستخدم إلا عند الحاجة.")
                            .font(.caption).foregroundStyle(BlofyTheme.textMuted)
                    }
                }.padding(.bottom, 32)
            }
            .background(BlofyTheme.backgroundGradient).toolbar(.hidden, for: .navigationBar)
            .onDisappear { model.saveSettings() }
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 12) {
            BlofyBrandMark(compact: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("الإعدادات").font(.title2.black())
                Text("كل شيء في مكان واضح").font(.caption2).foregroundStyle(BlofyTheme.textMuted)
            }
            Spacer()
        }.padding(.horizontal, 16).padding(.top, 8)
    }
}

struct TechnicalPlaybackSettingsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                SettingsCard(title: "المحرك", subtitle: "اتركه تلقائيًا إلا إذا كنت تعرف المطلوب", icon: "cpu") {
                    Picker("المحرك", selection: $model.preferredEngine) {
                        Text("تلقائي").tag("auto")
                        Text("Apple").tag("apple")
                        Text("VLC").tag("vlc")
                    }.pickerStyle(.segmented)
                }
                SettingsCard(title: "استقرار التشغيل", subtitle: "اختر حسب سرعة واتصال السيرفر", icon: "waveform.path.ecg") {
                    Picker("البافر", selection: $model.bufferProfile) {
                        Text("سريع").tag("fast")
                        Text("متوازن").tag("balanced")
                        Text("مستقر").tag("stable")
                    }.pickerStyle(.segmented)
                }
                SettingsCard(title: "صيغة البث", subtitle: "لا تغيرها إلا إذا كان السيرفر يتطلب ذلك", icon: "antenna.radiowaves.left.and.right") {
                    Picker("صيغة البث", selection: $model.liveFormat) {
                        Text("TS").tag("ts")
                        Text("HLS").tag("m3u8")
                    }.pickerStyle(.segmented)
                    .onChange(of: model.liveFormat) { model.setLiveFormat($0) }
                }
            }.padding(.vertical, 16)
        }
        .background(BlofyTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("متقدم")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.saveSettings() }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                Image(systemName: icon).font(.headline).foregroundStyle(BlofyTheme.purpleBright).frame(width: 30, height: 30).background(BlofyTheme.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(BlofyTheme.textPrimary)
                    Text(subtitle).font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                }
            }
            content
        }.padding(16).blofyPanel(radius: 22).padding(.horizontal, 16)
    }
}

private struct SettingToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 11) {
                Image(systemName: icon).frame(width: 26).foregroundStyle(BlofyTheme.purpleSoft)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary)
                    Text(subtitle).font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                }
            }
        }.tint(BlofyTheme.purpleBright)
    }
}

private struct SettingsLink<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder let destination: Destination
    var body: some View {
        NavigationLink { destination } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(BlofyTheme.purpleBright).frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary)
                    Text(subtitle).font(.caption2).foregroundStyle(BlofyTheme.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.left").font(.caption.bold()).foregroundStyle(BlofyTheme.textMuted)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

private struct SettingValueRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack { Text(title).foregroundStyle(BlofyTheme.textSecondary); Spacer(); Text(value).font(.caption.monospaced()).foregroundStyle(BlofyTheme.purpleSoft).lineLimit(1) }
    }
}

private struct ThemeDot: View {
    let style: String
    let selected: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13).fill(themeGradient).frame(height: 54)
            if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(.white).shadow(radius: 3) }
        }
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(selected ? Color.white.opacity(0.55) : Color.white.opacity(0.08), lineWidth: selected ? 1.5 : 1))
        .frame(maxWidth: .infinity)
    }
    private var themeGradient: LinearGradient {
        switch style {
        case "midnight": return LinearGradient(colors: [Color(red: 8/255, green: 17/255, blue: 34/255), Color(red: 112/255, green: 94/255, blue: 238/255)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "graphite": return LinearGradient(colors: [Color(red: 24/255, green: 24/255, blue: 29/255), Color(red: 142/255, green: 108/255, blue: 201/255)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(colors: [Color(red: 18/255, green: 11/255, blue: 28/255), Color(red: 174/255, green: 105/255, blue: 255/255)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
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
                    Picker("النوع", selection: $type) { Text("Xtream").tag("xtream"); Text("M3U").tag("m3u") }.pickerStyle(.segmented)
                }.listRowBackground(BlofyTheme.surface.opacity(0.86))
                Section("بيانات القائمة") {
                    TextField("اسم القائمة", text: $name)
                    TextField(type == "xtream" ? "رابط السيرفر" : "رابط القائمة", text: $url).textInputAutocapitalization(.never).keyboardType(.URL)
                    if type == "xtream" {
                        TextField("اسم المستخدم", text: $user).textInputAutocapitalization(.never)
                        SecureField("كلمة المرور", text: $pass)
                    }
                    if !model.error.isEmpty { Text(model.error).foregroundStyle(BlofyTheme.error) }
                }.listRowBackground(BlofyTheme.surface.opacity(0.86))
            }
            .scrollContentBackground(.hidden).background(BlofyTheme.backgroundGradient).navigationTitle("إضافة قائمة")
            .toolbarBackground(BlofyTheme.backgroundRaised, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() }.foregroundStyle(BlofyTheme.textSecondary) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        model.addPlaylist(name: name, type: type, url: url, username: user, password: pass)
                        if model.error.isEmpty { dismiss(); Task { await model.loadCatalog(force: true) } }
                    }.foregroundStyle(BlofyTheme.purpleBright).fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { model.error = "" }
    }
}
