import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var model: AppModel
    private var favoriteItems: [MediaItem] { model.items.filter { model.favorites.contains($0.id) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    HStack { BlofyBrandMark(); Spacer(); Text("مكتبتي").font(.title2.bold()) }
                        .padding(.horizontal, 16).padding(.top, 8)
                    if !model.resume.isEmpty {
                        SectionRow(title: "متابعة المشاهدة", subtitle: "كمل من حيث توقفت", items: model.resume.values.sorted { $0.updatedAt > $1.updatedAt }.map { $0.item })
                    }
                    if favoriteItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "heart.slash").font(.system(size: 42)).foregroundStyle(BlofyTheme.textMuted)
                            Text("ما عندك مفضلة إلى الآن").font(.headline)
                            Text("اضغط القلب على أي فيلم أو مسلسل أو قناة").font(.caption).foregroundStyle(BlofyTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 44).blofyPanel(radius: 22).padding(.horizontal, 16)
                    } else {
                        SectionRow(title: "المفضلة", subtitle: "وصول سريع", items: favoriteItems)
                    }
                }.padding(.bottom, 30)
            }
            .background(BlofyTheme.backgroundGradient)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Binding var showAdd: Bool

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
                        SettingValueRow(title: "النسخة", value: "2.2 iOS Commercial Preview")
                        Text("محرك هجين Apple + VLC، مع تحكم بالصوت والترجمة والاستئناف والمفضلة وتحميل محفوظ.")
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
        }.preferredColorScheme(.dark)
    }
}
