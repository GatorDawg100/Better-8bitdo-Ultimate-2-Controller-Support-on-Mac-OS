#!/usr/bin/env bash
set -e

echo "=== Building ControllerTester for macOS (Release) ==="
swift build -c release

BUILD_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="ControllerTester.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "=== Creating macOS App Bundle ==="
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${BUILD_DIR}/ControllerTester" "${MACOS_DIR}/ControllerTester"

# Create Info.plist with GameController metadata
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>ControllerTester</string>
    <key>CFBundleIdentifier</key>
    <string>com.deenleibovici.ControllerTester</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Controller Tester</string>
    <key>CFBundleDisplayName</key>
    <string>Controller Tester</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>GCSupportsControllerUserInteraction</key>
    <true/>
    <key>GCSupportedGameControllers</key>
    <array>
        <dict>
            <key>ProfileName</key>
            <string>ExtendedGamepad</string>
        </dict>
        <dict>
            <key>ProfileName</key>
            <string>MicroGamepad</string>
        </dict>
        <dict>
            <key>ProfileName</key>
            <string>DirectionalGamepad</string>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "=== Packaging Complete! ==="
echo "Application created at: $(pwd)/${APP_DIR}"
echo "You can launch it directly with: open ControllerTester.app"
