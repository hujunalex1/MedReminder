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
echo "   打包成 DMG: ./build.sh --dmg"
echo ""

if [ "$1" = "--install" ] || [ "$1" = "-i" ]; then
    echo "📦 正在安装到 /Applications/MedReminder.app..."
    pkill -f MedReminder 2>/dev/null || true
    sleep 0.5
    rm -rf /Applications/MedReminder.app
    cp -R "$APP" /Applications/MedReminder.app
    echo "🚀 启动最新版本..."
    open /Applications/MedReminder.app
elif [ "$1" = "--dmg" ] || [ "$1" = "-d" ]; then
    echo "💿 正在打包为 DMG 安装镜像..."
    DMG_DIR="build/dmg_staging"
    DMG_OUT="build/MedReminder.dmg"
    rm -rf "$DMG_DIR" "$DMG_OUT"
    mkdir -p "$DMG_DIR"
    cp -R "$APP" "$DMG_DIR/"
    ln -s /Applications "$DMG_DIR/Applications"
    hdiutil create -volname "MedReminder" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_OUT"
    rm -rf "$DMG_DIR"
    echo ""
    echo "🎉 DMG 打包完成: $DMG_OUT"
    echo "   文件大小: $(du -sh "$DMG_OUT" | awk '{print $1}')"
    echo "   双击打开即可拖拽安装到 Applications！"
fi
