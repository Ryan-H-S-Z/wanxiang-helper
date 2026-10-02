#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
APP="${1:-$HOME/Applications/万象棋升级助手.app}"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wanxiang-build.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT
mkdir -p "$APP/Contents/MacOS"
for ARCH in arm64 x86_64; do
  xcrun swiftc -swift-version 5 -O -target "$ARCH-apple-macosx13.0" App.swift Calculator.swift Equipment.swift EquipmentView.swift Recommendations.swift RecommendationView.swift LineupGuide.swift LineupGuideView.swift HeroPortrait.swift -o "$BUILD_DIR/WanxiangHelper-$ARCH" -framework AppKit -framework SwiftUI
done
xcrun lipo -create "$BUILD_DIR/WanxiangHelper-arm64" "$BUILD_DIR/WanxiangHelper-x86_64" -output "$APP/Contents/MacOS/WanxiangHelper"
mkdir -p "$APP/Contents/Resources/Equipment"
cp Resources/Equipment/catalog.json Resources/Equipment/*.webp "$APP/Contents/Resources/Equipment/"
mkdir -p "$APP/Contents/Resources/Recommendations"
cp Resources/Recommendations/*.json "$APP/Contents/Resources/Recommendations/"
mkdir -p "$APP/Contents/Resources/Heroes"
cp Resources/Heroes/* "$APP/Contents/Resources/Heroes/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/Info.plist"
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "已生成：$APP"
