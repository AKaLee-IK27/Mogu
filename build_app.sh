#!/bin/bash
set -euo pipefail

APP="MoleMac.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
RUNTIME_SRC="Vendor/Mole"
RUNTIME_DST="$RESOURCES/MoleRuntime"
BUNDLE_ID="com.mole.molemac"

swift build
BIN_DIR="$(swift build --show-bin-path)"
BINARY="$BIN_DIR/MoleMac"

if [[ ! -x "$BINARY" ]]; then
    echo "MoleMac binary not found at $BINARY" >&2
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
mkdir -p "$MACOS" "$RESOURCES"

cat > "$CONTENTS/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MoleMac</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>MoleMac</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSMainStoryboardFile</key>
    <string></string>
    <key>CFBundleSignature</key>
    <string>????</string>
</dict>
</plist>
PLIST

cp "$BINARY" "$MACOS/MoleMac"

# Bundle app icon
if [[ -f "AppIcon.icns" ]]; then
    cp "AppIcon.icns" "$RESOURCES/AppIcon.icns"
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
ENTITLEMENTS="MoleMac.entitlements"

# Step 1: Remove Go's default linker signature so our ad-hoc sign takes effect.
# Go linker embeds a signature with Identifier=a.out, which causes macOS TCC
# to treat status-go/analyze-go as separate untrusted processes.
codesign --remove-signature "$RUNTIME_DST/bin/status-go" 2>/dev/null || true
codesign --remove-signature "$RUNTIME_DST/bin/analyze-go" 2>/dev/null || true

# Step 2: Re-sign Go binaries with the same bundle identifier as the main app.
# This makes them part of the same code signature domain so TCC permissions
# are shared between parent app and child processes.
codesign --force --sign - \
    --identifier "${BUNDLE_ID}.status-go" \
    --options runtime \
    "$RUNTIME_DST/bin/status-go"

codesign --force --sign - \
    --identifier "${BUNDLE_ID}.analyze-go" \
    --options runtime \
    "$RUNTIME_DST/bin/analyze-go"

# Step 3: Sign the main executable (replaces SwiftPM's ad-hoc signature)
codesign --force --sign - \
    --identifier "${BUNDLE_ID}" \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    "$MACOS/MoleMac"

# Step 4: Deep-sign the entire bundle to seal Resources and include nested binaries
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
    pkill -f "${APP}/Contents/MacOS/MoleMac" 2>/dev/null || true
    sleep 1

    rm -rf "$INSTALL_DIR/$APP"
    cp -R "$APP" "$INSTALL_DIR/"
    echo "Installed to $INSTALL_DIR/$APP"
    echo ""
    echo "Grant Full Disk Access once in:"
    echo "  System Settings > Privacy & Security > Full Disk Access"
    echo "  -> Add /Applications/MoleMac.app"
fi
