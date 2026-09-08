#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build dist Vendor BlofyPlayer/Resources
rm -rf Vendor/VLCKit* BlofyPlayer.xcodeproj BlofyPlayer.xcworkspace Pods Podfile.lock

# Bundle the exact production BLOFY logo from the Android project so branding
# never depends on network access at runtime.
LOGO_URL="https://raw.githubusercontent.com/i20sss20-maker/BLOFY-PLAYER-2.0/rc07-commercial-stability/app/src/main/res/drawable-nodpi/blofy_logo.png"
curl -fL --retry 3 --retry-delay 2 "$LOGO_URL" -o BlofyPlayer/Resources/blofy_logo.png
[[ -s BlofyPlayer/Resources/blofy_logo.png ]]

make_icon() {
  local size="$1" out="$2" inner
  inner=$(( size * 82 / 100 ))
  cp BlofyPlayer/Resources/blofy_logo.png "build/icon-work.png"
  /usr/bin/sips -Z "$inner" "build/icon-work.png" >/dev/null
  /usr/bin/sips -p "$size" "$size" --padColor 100810 "build/icon-work.png" --out "BlofyPlayer/Resources/$out" >/dev/null
  [[ -s "BlofyPlayer/Resources/$out" ]]
}
make_icon 120 'Icon-60@2x.png'
make_icon 180 'Icon-60@3x.png'
make_icon 76 'Icon-76.png'
make_icon 152 'Icon-76@2x.png'
make_icon 167 'Icon-83.5@2x.png'
rm -f build/icon-work.png

python3 - <<'PY'
from pathlib import Path

# Live: debounce filtering and replace the long Menu with a real scrollable category sheet.
p = Path('BlofyPlayer/LiveExperienceView.swift')
s = p.read_text()
s = s.replace('    @State private var query = ""\n    @State private var selectedID = ""',
'''    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var showCategories = false
    @State private var selectedID = ""''', 1)
s = s.replace('(query.isEmpty || normalizedSearch($0.name).contains(normalizedSearch(query)))',
              '(debouncedQuery.isEmpty || normalizedSearch($0.name).contains(debouncedQuery))', 1)
s = s.replace('            .searchable(text: $query, prompt: "ابحث عن قناة")\n            .refreshable { await model.loadCatalog(force: true) }',
'''            .searchable(text: $query, prompt: "ابحث عن قناة")
            .task(id: query) {
                do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
                guard !Task.isCancelled else { return }
                debouncedQuery = normalizedSearch(query)
            }
            .refreshable { await model.loadCatalog(force: true) }
            .sheet(isPresented: $showCategories) {
                LiveCategoryBrowser(categories: categories, selected: $selectedCategory)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }''', 1)
old_menu = '''            Menu {
                Button("كل الفئات") { selectedCategory = "all" }
                ForEach(categories) { category in Button(category.name) { selectedCategory = category.key } }
            } label: {
                Label(selectedCategory == "all" ? "كل الفئات" : (categories.first { $0.key == selectedCategory }?.name ?? "الفئة"), systemImage: "line.3.horizontal.decrease.circle.fill")
                    .font(.subheadline.bold()).lineLimit(1).padding(.horizontal, 13).frame(height: 42)
                    .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(BlofyTheme.divider))
            }'''
new_button = '''            Button { showCategories = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")
                    Text(selectedCategory == "all" ? "كل الفئات" : (categories.first { $0.key == selectedCategory }?.name ?? "الفئة")).lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption2.bold()).opacity(0.7)
                }
                .font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary)
                .padding(.horizontal, 13).frame(height: 42)
                .background(BlofyTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(BlofyTheme.divider))
            }.buttonStyle(.plain)'''
if old_menu not in s:
    raise SystemExit('live category menu pattern not found')
s = s.replace(old_menu, new_button, 1)
category_sheet = '''
private struct LiveCategoryBrowser: View {
    @Environment(\\.dismiss) private var dismiss
    let categories: [MediaCategory]
    @Binding var selected: String
    @State private var query = ""
    @State private var debouncedQuery = ""

    private var filtered: [MediaCategory] {
        guard !debouncedQuery.isEmpty else { return categories }
        return categories.filter { normalizedSearch($0.name).contains(debouncedQuery) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 8) {
                    row(key: "all", name: "كل الفئات", icon: "square.grid.2x2.fill")
                    ForEach(filtered) { category in
                        row(key: category.key, name: category.name, icon: "folder.fill")
                    }
                }
                .padding(16).padding(.bottom, 36)
            }
            .background(BlofyTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("فئات البث")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "ابحث عن فئة")
            .task(id: query) {
                do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
                guard !Task.isCancelled else { return }
                debouncedQuery = normalizedSearch(query)
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("تم") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func row(key: String, name: String, icon: String) -> some View {
        Button {
            selected = key
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 28).foregroundStyle(selected == key ? .white : BlofyTheme.purpleSoft)
                Text(name).font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary).lineLimit(2)
                Spacer()
                if selected == key { Image(systemName: "checkmark.circle.fill").foregroundStyle(BlofyTheme.mint) }
                else { Image(systemName: "chevron.left").font(.caption.bold()).foregroundStyle(BlofyTheme.textMuted) }
            }
            .padding(14)
            .background(selected == key ? AnyShapeStyle(BlofyTheme.primaryGradient) : AnyShapeStyle(BlofyTheme.surface), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05)))
        }.buttonStyle(.plain)
    }
}

'''
s = s.replace('private struct LivePreviewHero: View {', category_sheet + 'private struct LivePreviewHero: View {', 1)
# Route fullscreen live playback through the dedicated channel-zapping wrapper.
s = s.replace('}) { PlayerScreen(session: $0) }', '}) { LiveFullScreenPlayer(initial: $0) }')
p.write_text(s)

# Catalog + global search: debounce expensive normalization/filtering on large provider libraries.
p = Path('BlofyPlayer/CatalogViews.swift')
s = p.read_text()
s = s.replace('    @State private var query = ""\n    @State private var sortMode = "server"',
'''    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var sortMode = "server"''', 1)
s = s.replace('(query.isEmpty || normalizedSearch($0.name).contains(normalizedSearch(query)))',
              '(debouncedQuery.isEmpty || normalizedSearch($0.name).contains(debouncedQuery))', 1)
s = s.replace('            .searchable(text: $query, prompt: "ابحث في \\(kind.title)")\n            .refreshable',
'''            .searchable(text: $query, prompt: "ابحث في \\(kind.title)")
            .task(id: query) {
                do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
                guard !Task.isCancelled else { return }
                debouncedQuery = normalizedSearch(query)
            }
            .refreshable''', 1)
marker = 'struct SearchView: View {'
idx = s.find(marker)
if idx == -1:
    raise SystemExit('SearchView marker not found')
search_view = r'''struct SearchView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var results: [MediaItem] = []
    @State private var searching = false

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
                if searching {
                    VStack(spacing: 10) { ProgressView().tint(BlofyTheme.purpleBright); Text("جاري البحث…").font(.caption).foregroundStyle(BlofyTheme.textMuted) }
                } else if query.isEmpty {
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
            .task(id: query) {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    debouncedQuery = ""; results = []; searching = false; return
                }
                searching = true
                do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
                guard !Task.isCancelled else { return }
                let needle = normalizedSearch(query)
                debouncedQuery = needle
                let snapshot = model.items
                let found = snapshot.lazy.filter { normalizedSearch($0.name).contains(needle) }.prefix(120)
                results = Array(found)
                searching = false
            }
        }
    }
}
'''
s = s[:idx] + search_view
# Xcode 16.4 / Swift 5 compatibility.
s = s.replace('.title2.black()', '.title2.weight(.black)')
p.write_text(s)

p = Path('BlofyPlayer/LibrarySettingsViews.swift')
s = p.read_text().replace('.title2.black()', '.title2.weight(.black)')
p.write_text(s)
PY

VLC_ZIP="build/VLCKit.zip"
VLC_URL="https://download.videolan.org/cocoapods/unstable/VLCKit-4.0-20260805-1123.zip"
if [[ ! -s "$VLC_ZIP" ]]; then
  curl -fL --retry 3 --retry-delay 2 "$VLC_URL" -o "$VLC_ZIP"
fi
/usr/bin/unzip -tq "$VLC_ZIP" >/dev/null
rm -rf build/vlckit-unpack && mkdir -p build/vlckit-unpack
/usr/bin/unzip -q "$VLC_ZIP" -d build/vlckit-unpack
VLC_XCFRAMEWORK="$(find build/vlckit-unpack -name 'VLCKit.xcframework' -type d | head -n 1)"
[[ -n "$VLC_XCFRAMEWORK" && -d "$VLC_XCFRAMEWORK" ]]
cp -R "$VLC_XCFRAMEWORK" Vendor/VLCKit.xcframework

ruby generate_project.rb
xcodebuild -project BlofyPlayer.xcodeproj -scheme BlofyPlayer -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build 2>&1 | tee build/xcodebuild.log

APP=build/DerivedData/Build/Products/Release-iphoneos/BlofyPlayer.app
[[ -d "$APP" && -s "$APP/BlofyPlayer" ]]
[[ -s "$APP/blofy_logo.png" ]]
[[ -s "$APP/Icon-60@2x.png" && -s "$APP/Icon-60@3x.png" ]]
[[ -s "$APP/Frameworks/VLCKit.framework/VLCKit" ]]
xcrun lipo "$APP/BlofyPlayer" -verify_arch arm64
xcrun lipo "$APP/Frameworks/VLCKit.framework/VLCKit" -verify_arch arm64

rm -rf build/package && mkdir -p build/package/Payload
cp -R "$APP" build/package/Payload/
rm -rf build/package/Payload/BlofyPlayer.app/_CodeSignature
rm -f build/package/Payload/BlofyPlayer.app/embedded.mobileprovision

NAME=BLOFY-PLAYER-iOS-0.3.3-unsigned.ipa
(cd build/package && /usr/bin/ditto -c -k --keepParent Payload "../../dist/$NAME")
shasum -a 256 "dist/$NAME" > dist/SHA256SUMS.txt
file "$APP/BlofyPlayer" | tee dist/BINARY_INFO.txt
/usr/bin/unzip -t "dist/$NAME"
printf 'Unsigned IPA created: %s\n' "$NAME"
