#!/bin/bash
set -e

echo "🔨 Building MedReminder..."

SDK_PATH=$(xcrun --show-sdk-path)

# Compile
mkdir -p build .build/ModuleCache
swiftc \
    -swift-version 5 \
    -target arm64-apple-macosx14.0 \
    -sdk "$SDK_PATH" \
    -module-cache-path .build/ModuleCache \
    -Xcc -fmodules-cache-path=.build/ModuleCache \
    -framework Cocoa \
    -framework SwiftUI \
    -framework UserNotifications \
    -O \
    -o build/MedReminder \
    Sources/*.swift

# Create .app bundle
APP="build/MedReminder.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

mv build/MedReminder "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon"
cp Resources/*.png "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc sign
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo ""
echo "✅ 构建完成: $APP"
echo "   运行: open $APP"
echo "   安装到系统: ./build.sh --install"
echo ""

if [ "$1" = "--install" ] || [ "$1" = "-i" ]; then
    echo "📦 正在安装到 /Applications/MedReminder.app..."
    pkill -f MedReminder 2>/dev/null || true
    sleep 0.5
    rm -rf /Applications/MedReminder.app
    cp -R "$APP" /Applications/MedReminder.app
    echo "🚀 启动最新版本..."
    open /Applications/MedReminder.app
fi
