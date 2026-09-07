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
                            NavigationLink { DetailsView(item: entry.item) } label: { Label(entry.item.name, systemImage: "play.circle") }
                        }
                    }
                }
                Section("المفضلة") {
                    ForEach(favoriteItems) { item in
                        NavigationLink {
                            if item.kind == .series { SeriesDetailsView(series: item) } else { DetailsView(item: item) }
                        } label: { Label(item.name, systemImage: "heart.fill") }
                    }
                }
            }.navigationTitle("مكتبتي")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Binding var showAdd: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("القوائم") {
                    ForEach(model.playlists) { playlist in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(playlist.name)
                                Text(playlist.type.uppercased()).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if model.selected?.id == playlist.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(.purple) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { model.choose(playlist); Task { await model.loadCatalog() } }
                    }
                    .onDelete { offsets in offsets.map { model.playlists[$0] }.forEach(model.delete) }
                    Button("إضافة قائمة تشغيل") { showAdd = true }
                    Button("تحديث القوائم") { Task { await model.loadCatalog(force: true) } }
                }

                Section("الجهاز والتفعيل") {
                    LabeledContent("Device ID", value: model.deviceID)
                    LabeledContent("Code", value: model.activationCode)
                    if !model.activationStatus.isEmpty { LabeledContent("الحالة", value: model.activationStatus) }
                }

                Section("التشغيل") {
                    Toggle("تشغيل البث تلقائيًا", isOn: $model.autoPlayLive)
                    Picker("صيغة البث", selection: $model.liveFormat) {
                        Text("TS").tag("ts")
                        Text("HLS / M3U8").tag("m3u8")
                    }
                    .onChange(of: model.liveFormat) { value in model.setLiveFormat(value) }
                }

                Section("اللغة") {
                    Picker("لغة التطبيق", selection: $model.language) {
                        Text("العربية").tag("ar")
                        Text("English").tag("en")
                    }
                }

                Section("حول") {
                    LabeledContent("النسخة", value: "1.0.0 iOS Full Preview")
                    Text("مشغل iOS يستخدم AVFoundation/AVPlayer لأن Media3 خاص بأندرويد.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("الإعدادات")
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
                Picker("النوع", selection: $type) {
                    Text("Xtream Codes").tag("xtream")
                    Text("M3U / M3U8").tag("m3u")
                }.pickerStyle(.segmented)
                TextField("اسم القائمة", text: $name)
                TextField(type == "xtream" ? "Server URL" : "M3U URL", text: $url)
                    .textInputAutocapitalization(.never).keyboardType(.URL)
                if type == "xtream" {
                    TextField("Username", text: $user).textInputAutocapitalization(.never)
                    SecureField("Password", text: $pass)
                }
                if !model.error.isEmpty { Text(model.error).foregroundStyle(.red) }
            }
            .navigationTitle("إضافة قائمة")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        model.addPlaylist(name: name, type: type, url: url, username: user, password: pass)
                        if model.error.isEmpty { dismiss(); Task { await model.loadCatalog(force: true) } }
                    }
                }
            }
        }
    }
}
