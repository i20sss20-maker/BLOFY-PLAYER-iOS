import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var model: AppModel
    private var favoriteItems: [MediaItem] {
        let ids = model.favorites
        return model.items.filter { ids.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !model.resume.isEmpty {
                    Section("متابعة المشاهدة") {
                        ForEach(model.resume.values.sorted { $0.updatedAt > $1.updatedAt }, id: \.item.id) { entry in
                            NavigationLink { DetailsView(item: entry.item) } label: {
                                HStack(spacing: 12) {
                                    Poster(url: entry.item.poster).frame(width: 58, height: 74).clipShape(RoundedRectangle(cornerRadius: 10))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.item.name).foregroundStyle(BlofyTheme.textPrimary).lineLimit(2)
                                        Text("استئناف").font(.caption.bold()).foregroundStyle(BlofyTheme.purpleSoft)
                                    }
                                }
                            }.listRowBackground(BlofyTheme.surface.opacity(0.86))
                        }
                    }
                }
                Section("المفضلة") {
                    ForEach(favoriteItems) { item in
                        NavigationLink {
                            if item.kind == .series { SeriesDetailsView(series: item) } else { DetailsView(item: item) }
                        } label: {
                            HStack(spacing: 12) {
                                Poster(url: item.poster).frame(width: 58, height: 74).clipShape(RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name).foregroundStyle(BlofyTheme.textPrimary).lineLimit(2)
                                    Text(item.kind.title).font(.caption).foregroundStyle(BlofyTheme.textMuted)
                                }
                                Spacer()
                                Image(systemName: "heart.fill").foregroundStyle(BlofyTheme.purpleBright)
                            }
                        }.listRowBackground(BlofyTheme.surface.opacity(0.86))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BlofyTheme.backgroundGradient)
            .navigationTitle("مكتبتي")
            .toolbarBackground(BlofyTheme.backgroundRaised, for: .navigationBar)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Binding var showAdd: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack { BlofyBrandMark(); Spacer() }
                        .padding(.vertical, 8)
                        .listRowBackground(BlofyTheme.surface.opacity(0.9))
                }

                Section("القوائم") {
                    ForEach(model.playlists) { playlist in
                        HStack {
                            Image(systemName: playlist.type == "m3u" ? "list.bullet.rectangle" : "server.rack")
                                .foregroundStyle(BlofyTheme.purpleSoft)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(playlist.name).foregroundStyle(BlofyTheme.textPrimary)
                                Text(playlist.type.uppercased()).font(.caption).foregroundStyle(BlofyTheme.textMuted)
                            }
                            Spacer()
                            if model.selected?.id == playlist.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(BlofyTheme.mint) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { model.choose(playlist); Task { await model.loadCatalog() } }
                        .listRowBackground(BlofyTheme.surface.opacity(0.86))
                    }
                    .onDelete { offsets in offsets.map { model.playlists[$0] }.forEach(model.delete) }
                    Button { showAdd = true } label: { Label("إضافة قائمة تشغيل", systemImage: "plus.circle.fill") }.foregroundStyle(BlofyTheme.purpleBright)
                    Button { Task { await model.loadCatalog(force: true) } } label: { Label("تحديث القوائم", systemImage: "arrow.clockwise") }.foregroundStyle(BlofyTheme.purpleSoft)
                }

                Section("الجهاز والتفعيل") {
                    LabeledContent("Device ID", value: model.deviceID)
                    LabeledContent("Code", value: model.activationCode)
                    if !model.activationStatus.isEmpty { LabeledContent("الحالة", value: model.activationStatus) }
                }
                .listRowBackground(BlofyTheme.surface.opacity(0.86))

                Section("التشغيل") {
                    Toggle("تشغيل البث تلقائيًا", isOn: $model.autoPlayLive).tint(BlofyTheme.purpleBright)
                    Picker("صيغة البث", selection: $model.liveFormat) {
                        Text("TS").tag("ts")
                        Text("HLS / M3U8").tag("m3u8")
                    }
                    .onChange(of: model.liveFormat) { value in model.setLiveFormat(value) }
                    LabeledContent("محرك iPhone", value: "Auto · Apple + VLC")
                }
                .listRowBackground(BlofyTheme.surface.opacity(0.86))

                Section("اللغة") {
                    Picker("لغة التطبيق", selection: $model.language) {
                        Text("العربية").tag("ar")
                        Text("English").tag("en")
                    }
                }
                .listRowBackground(BlofyTheme.surface.opacity(0.86))

                Section("حول") {
                    LabeledContent("النسخة", value: "2.0 iOS Hybrid")
                    Text("BLOFY يختار AVPlayer للمحتوى المتوافق مع iPhone ويستخدم VLCKit تلقائيًا للبث والصيغ الأوسع أو عند فشل المسار الأساسي.")
                        .font(.footnote).foregroundStyle(BlofyTheme.textMuted)
                }
                .listRowBackground(BlofyTheme.surface.opacity(0.86))
            }
            .scrollContentBackground(.hidden)
            .background(BlofyTheme.backgroundGradient)
            .navigationTitle("الإعدادات")
            .toolbarBackground(BlofyTheme.backgroundRaised, for: .navigationBar)
            .onDisappear { model.saveSettings() }
        }
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
                Section {
                    HStack { Spacer(); BlofyBrandMark(); Spacer() }.padding(.vertical, 8)
                }.listRowBackground(BlofyTheme.surface.opacity(0.9))

                Section("نوع القائمة") {
                    Picker("النوع", selection: $type) {
                        Text("Xtream Codes").tag("xtream")
                        Text("M3U / M3U8").tag("m3u")
                    }.pickerStyle(.segmented)
                }.listRowBackground(BlofyTheme.surface.opacity(0.86))

                Section("بيانات القائمة") {
                    TextField("اسم القائمة", text: $name)
                    TextField(type == "xtream" ? "Server URL" : "M3U URL", text: $url)
                        .textInputAutocapitalization(.never).keyboardType(.URL)
                    if type == "xtream" {
                        TextField("Username", text: $user).textInputAutocapitalization(.never)
                        SecureField("Password", text: $pass)
                    }
                    if !model.error.isEmpty { Text(model.error).foregroundStyle(BlofyTheme.error) }
                }.listRowBackground(BlofyTheme.surface.opacity(0.86))
            }
            .scrollContentBackground(.hidden)
            .background(BlofyTheme.backgroundGradient)
            .navigationTitle("إضافة قائمة")
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
    }
}
