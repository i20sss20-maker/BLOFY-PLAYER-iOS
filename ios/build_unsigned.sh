#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build dist
ruby generate_project.rb
xcodebuild -project BlofyPlayer.xcodeproj -scheme BlofyPlayer -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build 2>&1 | tee build/xcodebuild.log
APP=build/DerivedData/Build/Products/Release-iphoneos/BlofyPlayer.app
[[ -d "$APP" && -s "$APP/BlofyPlayer" ]]
xcrun lipo "$APP/BlofyPlayer" -verify_arch arm64
rm -rf build/package && mkdir -p build/package/Payload
cp -R "$APP" build/package/Payload/
rm -rf build/package/Payload/BlofyPlayer.app/_CodeSignature
rm -f build/package/Payload/BlofyPlayer.app/embedded.mobileprovision
NAME=BLOFY-PLAYER-iOS-0.1.0-unsigned.ipa
(cd build/package && /usr/bin/ditto -c -k --keepParent Payload "../../dist/$NAME")
shasum -a 256 "dist/$NAME" > dist/SHA256SUMS.txt
file "$APP/BlofyPlayer" | tee dist/BINARY_INFO.txt
/usr/bin/unzip -t "dist/$NAME"
printf 'Unsigned IPA created: %s\n' "$NAME"
