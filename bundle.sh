#!/usr/bin/env bash
set -e

APP_NAME="TripGuard"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Building ${APP_NAME} in release mode..."
swift build -c release

echo "Assembling ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy Icon
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

# Generate Info.plist
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.localover.tripguard</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>TripGuard uses system automation to configure packet filtering and network rules when requested.</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>TripGuard requests administrator privileges to inspect or configure macOS packet filter (pfctl) firewall rules.</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>TripGuard monitors active network interfaces and per-application socket usage.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright (c) 2026 Hassan Elkady (local-over). MIT License.</string>
</dict>
</plist>
EOF

# Ad-hoc codesign bundle for clean macOS execution
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true

echo "Successfully created ${APP_BUNDLE}!"

echo "Creating native macOS Disk Image (${APP_NAME}.dmg)..."
rm -rf dmg_staging "${APP_NAME}.dmg"
mkdir -p dmg_staging
cp -R "${APP_BUNDLE}" dmg_staging/
ln -s /Applications dmg_staging/Applications
hdiutil create -volname "${APP_NAME}" -srcfolder dmg_staging -ov -format UDZO "${APP_NAME}.dmg"
rm -rf dmg_staging

echo "Packaging ${APP_NAME}-macos.zip..."
rm -f "${APP_NAME}-macos.zip"
zip -r -y "${APP_NAME}-macos.zip" "${APP_BUNDLE}"

echo "Successfully built ${APP_NAME}.app, ${APP_NAME}.dmg, and ${APP_NAME}-macos.zip!"
