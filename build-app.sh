#!/bin/zsh
# Builds NoirTasks.app inside the project build directory. Run:  ./build-app.sh
set -e
cd "$(dirname "$0")"

swift build -c release

APP="build/NoirTasks.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/NoirTasks "$APP/Contents/MacOS/NoirTasks"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force -s - "$APP"

echo "Built $(cd "$(dirname "$APP")" && pwd)/NoirTasks.app"
