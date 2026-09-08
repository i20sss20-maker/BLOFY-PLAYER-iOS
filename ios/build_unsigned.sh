#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build dist Vendor BlofyPlayer/Resources
rm -rf Vendor/VLCKit* BlofyPlayer.xcodeproj BlofyPlayer.xcworkspace Pods Podfile.lock

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

# Full-screen live remains routed through the dedicated zapping wrapper.
p = Path('BlofyPlayer/LiveExperienceView.swift')
s = p.read_text()
s = s.replace('}) { PlayerScreen(session: $0) }', '}) { LiveFullScreenPlayer(initial: $0) }')
p.write_text(s)

# Catalog pages: debounce expensive filtering on very large Xtream libraries.
p = Path('BlofyPlayer/CatalogViews.swift')
s = p.read_text()
if '    @State private var debouncedQuery = ""' not in s.split('struct CatalogView: View',1)[1].split('struct DetailsView',1)[0]:
    s = s.replace('    @State private var query = ""\n    @State private var sortMode = "server"',
'''    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var sortMode = "server"''', 1)
    s = s.replace('(query.isEmpty || normalizedSearch($0.name).contains(normalizedSearch(query)))',
                  '(debouncedQuery.isEmpty || normalizedSearch($0.name).contains(debouncedQuery))', 1)
    s = s.replace('            .searchable(text: $query, prompt: "ابحث في \\(kind.title)")\n            .refreshable',
'''            .searchable(text: $query, prompt: "ابحث في \\(kind.title)")
            .task(id: query) {
                do { try await Task.sleep(nanoseconds: 320_000_000) } catch { return }
                guard !Task.isCancelled else { return }
                debouncedQuery = normalizedSearch(query)
            }
            .refreshable''', 1)

# Replace the global search view with a debounced implementation. It caps visible
# matches so typing never tries to build hundreds/thousands of rows at once.
marker = 'struct SearchView: View {'
idx = s.find(marker)
if idx == -1:
    raise SystemExit('SearchView marker not found')
search_view = r'''struct SearchView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
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
                            Text(item.name).font(.subheadline.bold()).foregroundStyle(BlofyTheme.textPrimary).lineLimit(2)
                            Text(item.kind.title).font(.caption).foregroundStyle(BlofyTheme.purpleSoft)
                        }
                    }
                }.listRowBackground(BlofyTheme.surface.opacity(0.82))
            }
            .overlay {
                if searching {
                    VStack(spacing: 10) {
                        ProgressView().tint(BlofyTheme.purpleBright)
                        Text("جاري البحث…").font(.caption).foregroundStyle(BlofyTheme.textMuted)
                    }
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
            .scrollContentBackground(.hidden)
            .background(BlofyTheme.backgroundGradient)
            .navigationTitle("البحث")
            .searchable(text: $query, prompt: "اكتب للبحث")
            .task(id: query) {
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    results = []
                    searching = false
                    return
                }
                searching = true
                do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
                guard !Task.isCancelled else { return }
                let needle = normalizedSearch(trimmed)
                let snapshot = model.items
                results = Array(snapshot.lazy.filter { normalizedSearch($0.name).contains(needle) }.prefix(120))
                searching = false
            }
        }
    }
}
'''
s = s[:idx] + search_view
s = s.replace('.title2.black()', '.title2.weight(.black)')
p.write_text(s)

# Xcode 16.4 / Swift 5 font compatibility in settings/library source.
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

NAME=BLOFY-PLAYER-iOS-0.3.4-unsigned.ipa
(cd build/package && /usr/bin/ditto -c -k --keepParent Payload "../../dist/$NAME")
shasum -a 256 "dist/$NAME" > dist/SHA256SUMS.txt
file "$APP/BlofyPlayer" | tee dist/BINARY_INFO.txt
/usr/bin/unzip -t "dist/$NAME"
printf 'Unsigned IPA created: %s\n' "$NAME"
