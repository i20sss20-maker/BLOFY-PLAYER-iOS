#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swiftc -swift-version 5 -parse-as-library \
  "$ROOT/ios/BlofyPlayer/Models.swift" \
  "$ROOT/ios/BlofyPlayer/AppModel.swift" \
  "$ROOT/ios/BlofyPlayer/AppModelPortal.swift" \
  "$ROOT/ios/tests/CatalogIsolationTests.swift" \
  -o "$WORK/model-regressions"
"$WORK/model-regressions" "$@"

swiftc -swift-version 5 -parse-as-library \
  "$ROOT/ios/BlofyPlayer/Models.swift" \
  "$ROOT/ios/BlofyPlayer/MediaSearchEngine.swift" \
  "$ROOT/ios/tests/SearchEngineTests.swift" \
  -o "$WORK/search-regressions"
"$WORK/search-regressions"
