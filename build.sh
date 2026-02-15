#!/bin/bash
# Build script for AnyGif-Claude-Pet
#
# Requirements:
#   - Xcode (full installation, not just Command Line Tools)
#   - OR a matching swiftc + SDK pair
#
# If using only Command Line Tools, you may hit SDK/compiler version
# mismatches. In that case, install Xcode from the App Store and run:
#   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/Sources/AnyGifClaudePet"
BUILD_DIR="$SCRIPT_DIR/.build"

mkdir -p "$BUILD_DIR"

swiftc \
    -o "$BUILD_DIR/AnyGifClaudePet" \
    -swift-version 5 \
    -target arm64-apple-macosx13.0 \
    -framework AppKit \
    -framework ImageIO \
    -framework CoreGraphics \
    -framework UniformTypeIdentifiers \
    -framework QuartzCore \
    "$SRC_DIR/PetState.swift" \
    "$SRC_DIR/GifAnimator.swift" \
    "$SRC_DIR/GifAssignment.swift" \
    "$SRC_DIR/PetView.swift" \
    "$SRC_DIR/PetWindow.swift" \
    "$SRC_DIR/ClaudeEvent.swift" \
    "$SRC_DIR/ClaudeHookService.swift" \
    "$SRC_DIR/HookInstaller.swift" \
    "$SRC_DIR/SettingsWindowController.swift" \
    "$SRC_DIR/PetViewModel.swift" \
    "$SRC_DIR/EventLogger.swift" \
    "$SRC_DIR/GeminiAPIService.swift" \
    "$SRC_DIR/VibeSummary.swift" \
    "$SRC_DIR/VibeBubbleView.swift" \
    "$SRC_DIR/AppDelegate.swift" \
    "$SRC_DIR/main.swift"

echo "Build successful: $BUILD_DIR/AnyGifClaudePet"

# Package as .app bundle
APP_DIR="$BUILD_DIR/AnyGifClaudePet.app/Contents"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
cp "$BUILD_DIR/AnyGifClaudePet" "$APP_DIR/MacOS/AnyGifClaudePet"
cp "$SCRIPT_DIR/HookScript/claude-pet-hook.sh" "$APP_DIR/Resources/claude-pet-hook.sh"
chmod +x "$APP_DIR/Resources/claude-pet-hook.sh"

cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AnyGifClaudePet</string>
    <key>CFBundleIdentifier</key>
    <string>com.frediestom.AnyGifClaudePet</string>
    <key>CFBundleName</key>
    <string>AnyGifClaudePet</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "App bundle created: $BUILD_DIR/AnyGifClaudePet.app"
echo "Double-click to launch, or run: open $BUILD_DIR/AnyGifClaudePet.app"
