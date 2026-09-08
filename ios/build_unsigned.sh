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

# Produce real iPhone/iPad app icons from the bundled BLOFY logo while preserving
# the logo aspect ratio on the BLOFY dark background.
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

# Route fullscreen live playback through the dedicated channel-zapping wrapper.
python3 - <<'PY'
from pathlib import Path
p = Path('BlofyPlayer/LiveExperienceView.swift')
s = p.read_text()
s = s.replace('}) { PlayerScreen(session: $0) }', '}) { LiveFullScreenPlayer(initial: $0) }')
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

NAME=BLOFY-PLAYER-iOS-0.3.0-unsigned.ipa
(cd build/package && /usr/bin/ditto -c -k --keepParent Payload "../../dist/$NAME")
shasum -a 256 "dist/$NAME" > dist/SHA256SUMS.txt
file "$APP/BlofyPlayer" | tee dist/BINARY_INFO.txt
/usr/bin/unzip -t "dist/$NAME"
printf 'Unsigned IPA created: %s\n' "$NAME"
