#!/bin/bash
# Build the Mogu app icon + sidebar logo from icon-source.png.
#
# Pipeline: a Swift/CoreGraphics compositor draws the source art onto a macOS
# squircle (light gradient background; the art is a transparent PNG so it
# composites directly over the gradient), producing a 1024 master PNG and a
# small rounded sidebar logo. sips
# fans the master out into a full AppIcon.iconset, then iconutil seals the .icns.
#
# Requires only macOS built-ins: swift, sips, iconutil. Run from repo root:
#   ./scripts/make_icon.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRC="icon-source.png"
[[ -f "$SRC" ]] || { echo "Missing $SRC (the Mogu source art)" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
MASTER="$WORK/icon_1024.png"
SIDEBAR="SidebarLogo.png"

SWIFT="$WORK/compose.swift"
cat > "$SWIFT" <<'SWIFTEOF'
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let srcPath = args[1], iconOut = args[2], sidebarOut = args[3]

func loadCGImage(_ path: String) -> CGImage {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        FileHandle.standardError.write("cannot load \(path)\n".data(using: .utf8)!); exit(1)
    }
    return img
}

func writePNG(_ image: CGImage, _ path: String) {
    guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        FileHandle.standardError.write("cannot write \(path)\n".data(using: .utf8)!); exit(1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

// Continuous-ish squircle via a circular-corner rounded rect (Apple's ratio ~0.2237).
func squircle(_ rect: CGRect) -> CGPath {
    let r = min(rect.width, rect.height) * 0.2237
    return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
}

func context(_ side: Int) -> CGContext {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    return ctx
}

let art = loadCGImage(srcPath)

func compose(side: Int, marginFrac: CGFloat) -> CGImage {
    let ctx = context(side)
    let s = CGFloat(side)
    let margin = s * marginFrac
    let tile = CGRect(x: margin, y: margin, width: s - 2*margin, height: s - 2*margin)
    let path = squircle(tile)

    // Squircle background: subtle white -> cool grey vertical gradient.
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let grad = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 1),
        CGColor(red: 0.937, green: 0.945, blue: 0.965, alpha: 1)
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    // Mogu art (transparent PNG) sits inside the squircle with a small inset so the
    // raised drill-claws don't clip at the rounded corners; the gradient shows around it.
    ctx.draw(art, in: tile.insetBy(dx: s * 0.06, dy: s * 0.06))
    ctx.restoreGState()

    // Hairline edge for definition on light Docks.
    ctx.addPath(path)
    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.06))
    ctx.setLineWidth(s * 0.004)
    ctx.strokePath()

    return ctx.makeImage()!
}

// App icon: ~9% transparent margin around the squircle (Big Sur grid feel).
writePNG(compose(side: 1024, marginFrac: 0.09), iconOut)
// Sidebar logo: tighter margin reads better at ~26pt.
writePNG(compose(side: 256, marginFrac: 0.02), sidebarOut)
SWIFTEOF

echo "=== composing master + sidebar via CoreGraphics ==="
swift "$SWIFT" "$SRC" "$MASTER" "$SIDEBAR"

echo "=== building AppIcon.iconset ==="
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
gen() { sips -z "$1" "$1" "$MASTER" --out "$ICONSET/$2" >/dev/null; }
gen 16   icon_16x16.png
gen 32   icon_16x16@2x.png
gen 32   icon_32x32.png
gen 64   icon_32x32@2x.png
gen 128  icon_128x128.png
gen 256  icon_128x128@2x.png
gen 256  icon_256x256.png
gen 512  icon_256x256@2x.png
gen 512  icon_512x512.png
cp "$MASTER" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o AppIcon.icns
cp "$MASTER" icon.png

echo ""
echo "Wrote: AppIcon.icns ($(du -h AppIcon.icns | cut -f1)), icon.png, SidebarLogo.png"
