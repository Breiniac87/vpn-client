#!/bin/bash
set -e

DEST_DIR="bin/xray"
mkdir -p "$DEST_DIR"

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    ZIP_NAME="Xray-macos-arm64-v8a.zip"
else
    ZIP_NAME="Xray-macos-64.zip"
fi

URL="https://github.com/XTLS/Xray-core/releases/latest/download/$ZIP_NAME"

echo "⬇️ Загрузка официального Xray-core для $ARCH: $URL..."
TMP_DIR=$(mktemp -d)
curl -L -o "$TMP_DIR/xray.zip" "$URL"

echo "📦 Распаковка файлов ядра..."
unzip -q -o "$TMP_DIR/xray.zip" -d "$DEST_DIR"
rm -rf "$TMP_DIR"

chmod +x "$DEST_DIR/xray"

echo "✅ Xray-core успешно установлен в $DEST_DIR:"
ls -lh "$DEST_DIR"
"$DEST_DIR/xray" version
