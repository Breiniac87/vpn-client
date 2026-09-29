#!/bin/bash
set -e

if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
elif [ -d "/Library/Developer/CommandLineTools" ]; then
    export DEVELOPER_DIR="/Library/Developer/CommandLineTools"
fi

if [ "$1" == "--clean" ] || [ "$1" == "-c" ]; then
    ./scripts/clean_data.sh
fi

echo "🔨 Сборка X-project через Swift Package Manager..."
swift build -c debug

APP_DIR="build/X-project.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "📦 Копирование бинарного файла приложения..."
cp .build/debug/X-project "$MACOS_DIR/X-project"
chmod +x "$MACOS_DIR/X-project"

if [ -d "bin/xray" ]; then
    echo "⚡️ Встраивание Xray-core и гео-баз в Resources/xray..."
    mkdir -p "$RESOURCES_DIR/xray"
    cp -R bin/xray/* "$RESOURCES_DIR/xray/"
    chmod +x "$RESOURCES_DIR/xray/xray"
fi

if [ -f "Resources/AppIcon.icns" ]; then
    echo "🎨 Встраивание иконки приложения AppIcon.icns и AppIcon.png..."
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    if [ -f "Resources/AppIcon.png" ]; then
        cp "Resources/AppIcon.png" "$RESOURCES_DIR/AppIcon.png"
    fi
fi

echo "📝 Генерация Info.plist..."
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>X-project</string>
    <key>CFBundleIdentifier</key>
    <string>com.xproject.client</string>
    <key>CFBundleName</key>
    <string>X-project</string>
    <key>CFBundleDisplayName</key>
    <string>X-project</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>2.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 X-project. All rights reserved.</string>
</dict>
</plist>
EOF

touch "$APP_DIR"
if [ -f "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R "$APP_DIR" 2>/dev/null || true
fi

echo "✅ Бандл успешно собран в: $APP_DIR"
