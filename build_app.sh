#!/bin/bash
set -euo pipefail

APP="Mogu.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
RUNTIME_SRC="Vendor/Mole"
RUNTIME_DST="$RESOURCES/MoleRuntime"
BUNDLE_ID="co.greenpassport.mogu"

# Versioning — override via MOGU_VERSION / MOGU_BUILD env vars.
VERSION="${MOGU_VERSION:-1.0}"
BUILD="${MOGU_BUILD:-1}"

swift build
BIN_DIR="$(swift build --show-bin-path)"
BINARY="$BIN_DIR/Mogu"
SPARKLE_FRAMEWORK="$BIN_DIR/Sparkle.framework"

if [[ ! -x "$BINARY" ]]; then
    echo "Mogu binary not found at $BINARY" >&2
    exit 1
fi

if [[ ! -d "$RUNTIME_SRC" ]]; then
    echo "Mole submodule not initialized. Run: git submodule update --init --recursive" >&2
    exit 1
fi

# Build Go helper binaries from source (native performance)
echo "=== Building Mole Go binaries from source ==="
(cd "$RUNTIME_SRC" && make build)

if [[ ! -x "$RUNTIME_SRC/bin/status-go" || ! -x "$RUNTIME_SRC/bin/analyze-go" ]]; then
    echo "Mole build failed: status-go/analyze-go are required" >&2
    exit 1
fi

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES" "$CONTENTS/Frameworks"

cat > "$CONTENTS/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Mogu</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>Mogu</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSMainStoryboardFile</key>
    <string></string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <!-- Privacy usage descriptions for macOS 14+ -->
    <key>NSAppleEventsUsageDescription</key>
    <string>Mogu needs to analyze application data to provide system cleanup and optimization insights.</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>Mogu needs system administration access to manage application data and system caches.</string>
    <key>NSFaceIDUsageDescription</key>
    <string>Mogu uses Touch ID to confirm system-level cleanup before asking for your administrator password.</string>
    <!-- Sparkle: the appcast URL for over-the-air updates. -->
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/AKaLee-IK27/Mogu/main/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>xF+hMsszyUne0c6xUIDlClNJWVj92ZR47mEdN0hKONI=</string>
</dict>
</plist>
PLIST

cp "$BINARY" "$MACOS/Mogu"

# Fix the rpath so the bundled binary finds Sparkle.framework in @executable_path/../Frameworks
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS/Mogu" 2>/dev/null || true
# Strip the Xcode developer-tool rpath that SwiftPM leaks in (causes Xprotect warnings)
install_name_tool -delete_rpath "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-6.2/macosx" "$MACOS/Mogu" 2>/dev/null || true
install_name_tool -delete_rpath "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx" "$MACOS/Mogu" 2>/dev/null || true

# Bundle Sparkle framework (SPM dependency)
if [[ -d "$SPARKLE_FRAMEWORK" ]]; then
    rm -rf "$CONTENTS/Frameworks/Sparkle.framework"
    cp -R "$SPARKLE_FRAMEWORK" "$CONTENTS/Frameworks/"
    echo "Bundled Sparkle.framework"
else
    echo "Warning: Sparkle.framework not found at $SPARKLE_FRAMEWORK" >&2
fi

# Bundle app icon
if [[ -f "AppIcon.icns" ]]; then
    cp "AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi

# Bundle the sidebar brand mark (Mogu logo) used by ContentView's brandMark
if [[ -f "SidebarLogo.png" ]]; then
    cp "SidebarLogo.png" "$RESOURCES/SidebarLogo.png"
fi

# Bundle CHANGELOG.md for the release-notes viewer
if [[ -f "CHANGELOG.md" ]]; then
    cp "CHANGELOG.md" "$RESOURCES/CHANGELOG.md"
fi

# Copy only the runtime artifacts (not .git, source, docs, tests)
mkdir -p "$RUNTIME_DST/bin" "$RUNTIME_DST/lib"
cp "$RUNTIME_SRC/mo" "$RUNTIME_DST/mo"
cp "$RUNTIME_SRC/mole" "$RUNTIME_DST/mole"
cp -R "$RUNTIME_SRC/bin" "$RUNTIME_DST/"
cp -R "$RUNTIME_SRC/lib" "$RUNTIME_DST/"
if [[ -f "$RUNTIME_SRC/VERSION" ]]; then cp "$RUNTIME_SRC/VERSION" "$RUNTIME_DST/VERSION"; fi
if [[ -f "$RUNTIME_SRC/LICENSE" ]]; then cp "$RUNTIME_SRC/LICENSE" "$RUNTIME_DST/LICENSE"; fi
chmod +x "$RUNTIME_DST/mo" "$RUNTIME_DST/mole" "$RUNTIME_DST"/bin/*

# Entitlements file lives in repo root
ENTITLEMENTS="Mogu.entitlements"

# Step 1: Remove Go's default linker signature so our ad-hoc sign takes effect.
# Go linker embeds a signature with Identifier=a.out, which causes macOS TCC
# to treat status-go/analyze-go as separate untrusted processes.
codesign --remove-signature "$RUNTIME_DST/bin/status-go" 2>/dev/null || true
codesign --remove-signature "$RUNTIME_DST/bin/analyze-go" 2>/dev/null || true

# Step 2: Re-sign Go binaries with the SAME bundle identifier as the main app.
# This makes them part of the same code signature domain so TCC permissions
# are shared between parent app and child processes (one signature domain for
# the app and the elevated `mo` it runs).
codesign --force --sign - \
    --identifier "${BUNDLE_ID}" \
    --options runtime \
    "$RUNTIME_DST/bin/status-go"

codesign --force --sign - \
    --identifier "${BUNDLE_ID}" \
    --options runtime \
    "$RUNTIME_DST/bin/analyze-go"

# Step 2b: Sign the shell scripts (mo, mole) with the same identifier.
# macOS 26.5 TCC requires all child processes to share the parent's code
# signature domain to inherit any TCC permissions the user grants the app.
codesign --force --sign - \
    --identifier "${BUNDLE_ID}" \
    --options runtime \
    "$RUNTIME_DST/mo"

codesign --force --sign - \
    --identifier "${BUNDLE_ID}" \
    --options runtime \
    "$RUNTIME_DST/mole"

# Sign all shell scripts in bin/
for script in "$RUNTIME_DST"/bin/*.sh; do
    if [[ -f "$script" ]]; then
        codesign --force --sign - \
            --identifier "${BUNDLE_ID}" \
            --options runtime \
            "$script"
    fi
done

# Step 3: Sign Sparkle framework
codesign --force --sign - \
    --identifier "${BUNDLE_ID}" \
    --options runtime \
    "$CONTENTS/Frameworks/Sparkle.framework"

# Step 4: Sign the main executable (replaces SwiftPM's ad-hoc signature)
codesign --force --sign - \
    --identifier "${BUNDLE_ID}" \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    "$MACOS/Mogu"

# Step 5: Deep-sign the entire bundle to seal Resources and include nested binaries
# in the Sealed Resources list. --deep handles mo, mole, and shell scripts.
codesign --force --deep --sign - \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    "$APP"

RUNTIME_VERSION="unknown"
if [[ -f "$RUNTIME_DST/VERSION" ]]; then
    RUNTIME_VERSION="$(tr -d '\n' < "$RUNTIME_DST/VERSION")"
elif [[ -f "$RUNTIME_DST/mole" ]]; then
    RUNTIME_VERSION="$(grep '^VERSION="' "$RUNTIME_DST/mole" | head -1 | sed 's/VERSION="\(.*\)"/\1/')"
fi

# Verify
codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 || true

echo ""
echo "App bundle created at $APP"
echo "Bundled Mole runtime: $RUNTIME_VERSION"

# Install to /Applications for persistent TCC permissions
INSTALL_DIR="/Applications"
if [[ -d "$INSTALL_DIR" ]]; then
    # Kill running instance
    pkill -f "${APP}/Contents/MacOS/Mogu" 2>/dev/null || true
    sleep 1

    rm -rf "$INSTALL_DIR/$APP"
    cp -R "$APP" "$INSTALL_DIR/"
    echo "Installed to $INSTALL_DIR/$APP"
    echo ""
    echo "Mogu needs no permissions to start. It asks for your administrator"
    echo "password only for system cleanup or protected app uninstall."
fi
