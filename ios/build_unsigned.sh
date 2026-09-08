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

# Keep the live page source stable while routing fullscreen live playback through
# the dedicated channel-zapping wrapper at build time.
python3 - <<'PY'
from pathlib import Path
p = Path('BlofyPlayer/LiveExperienceView.swift')
s = p.read_text()
s = s.replace('}) { PlayerScreen(session: $0) }', '}) { LiveFullScreenPlayer(initial: $0) }')
p.write_text(s)
PY

# Some Xtream VOD endpoints start correctly but stop responding after an in-place
# seek. Patch PlayerBox at build time so seeks are verified and, when necessary,
# the same source is reopened at the requested position before trying fallback.
python3 - <<'PY'
from pathlib import Path
p = Path('BlofyPlayer/PlayerScreen.swift')
s = p.read_text()
anchor = '    private var didApplyTrackPreferences = false\n'
insert = '''    private var didApplyTrackPreferences = false
    private var seekGeneration = 0
    private var currentPlaybackURL: URL?
'''
if anchor not in s:
    raise SystemExit('PlayerBox property anchor not found')
s = s.replace(anchor, insert, 1)

s = s.replace('''        let resume = isLive ? 0 : (keepPosition ? current : requestedStart); let url = candidates[index]
''', '''        let resume = isLive ? 0 : (keepPosition ? current : requestedStart); let url = candidates[index]
        currentPlaybackURL = url
''', 1)
s = s.replace('''        vlcTried.insert(url.absoluteString); openedAt = Date(); lastAdvanceAt = Date(); lastPosition = -1; statusText = "تشغيل بمحرك VLC…"
''', '''        vlcTried.insert(url.absoluteString); currentPlaybackURL = url; openedAt = Date(); lastAdvanceAt = Date(); lastPosition = -1; statusText = "تشغيل بمحرك VLC…"
''', 1)

old = '''    func seek(by delta: Double) { guard !isLive else { return }; seek(to: max(0, duration > 0 ? min(duration, current + delta) : current + delta)) }
    func seek(to seconds: Double) {
        guard !isLive else { return }; let target = max(0, duration > 0 ? min(duration, seconds) : seconds); current = target
        if engine == .apple { player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: CMTime(seconds: 0.25, preferredTimescale: 600), toleranceAfter: CMTime(seconds: 0.25, preferredTimescale: 600)) }
        else { vlcPlayer.time = VLCTime(int: Int32(target * 1000)) }
    }
'''
new = '''    func seek(by delta: Double) { guard !isLive else { return }; seek(to: max(0, duration > 0 ? min(duration, current + delta) : current + delta)) }
    func seek(to seconds: Double) {
        guard !isLive, !switching else { return }
        let target = max(0, duration > 0 ? min(duration, seconds) : seconds)
        current = target
        seekGeneration += 1
        let generation = seekGeneration
        statusText = "جاري الانتقال…"
        lastAdvanceAt = Date()
        lastPosition = -1

        if engine == .apple {
            let time = CMTime(seconds: target, preferredTimescale: 600)
            player.seek(to: time, toleranceBefore: CMTime(seconds: 0.5, preferredTimescale: 600), toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 600)) { [weak self] finished in
                Task { @MainActor in
                    guard let self, generation == self.seekGeneration else { return }
                    if finished {
                        self.player.playImmediately(atRate: self.rate)
                        self.isPlaying = true
                        self.lastAdvanceAt = Date()
                    }
                }
            }
        } else {
            vlcPlayer.time = VLCTime(int: Int32(target * 1000))
            if !vlcPlayer.isPlaying { vlcPlayer.play(); vlcPlayer.rate = rate }
            isPlaying = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            Task { @MainActor in self?.verifySeek(target: target, generation: generation) }
        }
    }

    private func verifySeek(target: Double, generation: Int) {
        guard !isLive, generation == seekGeneration, !switching else { return }
        let tolerance = max(5.0, min(12.0, duration * 0.01))
        let movedNearTarget = abs(current - target) <= tolerance
        if movedNearTarget && isPlaying {
            statusText = ""
            return
        }

        statusText = "إعادة فتح الفيديو من الموضع…"
        current = target
        requestedStart = target
        lastAdvanceAt = Date()
        lastPosition = -1

        if engine == .apple {
            if candidates.indices.contains(candidateIndex) {
                playApple(at: candidateIndex, keepPosition: true)
            } else if preferredEngine != "apple" {
                tryVLCFallback()
            }
        } else if let url = currentPlaybackURL {
            vlcPlayer.stop()
            playVLC(url: url, keepPosition: true)
        } else {
            tryVLCFallback()
        }
    }
'''
if old not in s:
    raise SystemExit('seek block not found')
s = s.replace(old, new, 1)

s = s.replace('''        player.pause(); player.replaceCurrentItem(with: nil); vlcPlayer.stop(); candidates = []; switching = false; isPlaying = false
''', '''        player.pause(); player.replaceCurrentItem(with: nil); vlcPlayer.stop(); candidates = []; currentPlaybackURL = nil; switching = false; isPlaying = false
''', 1)
p.write_text(s)
PY

VLC_ZIP="build/VLCKit.zip"
VLC_URL="https://download.videolan.org/cocoapods/unstable/VLCKit-4.0-20260805-1123.zip"
curl -fL --retry 3 --retry-delay 2 "$VLC_URL" -o "$VLC_ZIP"
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
xcrun lipo "$APP/BlofyPlayer" -verify_arch arm64
rm -rf build/package && mkdir -p build/package/Payload
cp -R "$APP" build/package/Payload/
rm -rf build/package/Payload/BlofyPlayer.app/_CodeSignature
rm -f build/package/Payload/BlofyPlayer.app/embedded.mobileprovision
NAME=BLOFY-PLAYER-iOS-0.2.3-unsigned.ipa
(cd build/package && /usr/bin/ditto -c -k --keepParent Payload "../../dist/$NAME")
shasum -a 256 "dist/$NAME" > dist/SHA256SUMS.txt
file "$APP/BlofyPlayer" | tee dist/BINARY_INFO.txt
/usr/bin/unzip -t "dist/$NAME"
printf 'Unsigned IPA created: %s\n' "$NAME"
