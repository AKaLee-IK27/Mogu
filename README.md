# MoleMac

A minimal macOS GUI application for [Mole](https://github.com/tw93/Mole) - the open-source system cleaner.

Built with SwiftUI and designed following [Taste Skill](https://github.com/leonxlnx/taste-skill) principles: premium typography, spacious layout, single accent color, no emojis in UI, editorial aesthetics.

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 6.3+ (for building from source)
- No separate Mole CLI install required; MoleMac bundles a pinned Mole runtime.

## Features

| Panel | Description |
|---|---|
| **Status** | Live system monitoring - CPU, memory, disk, battery, network, top processes |
| **Clean** | Preview and execute deep cleanup of caches, logs, browser leftovers |
| **Uninstall** | Browse installed apps with sizes and related files |
| **Optimize** | One-click system optimization - rebuild caches, refresh services |
| **Analyze** | Visual disk usage breakdown with large file detection |
| **Purge** | Find and clean project build artifacts (node_modules, target, etc.) |

## Design Principles

Applied from Taste Skill:

- **No emojis** in code or UI - clean SVG primitives only
- **Off-black** instead of pure black for text
- **Single accent color** (electric blue `#2563eb`) - no purple AI glow
- **Spacious, editorial layout** inspired by Linear/Notion
- **Monospace for data** - sizes, percentages, paths
- **Proper spacing scale** - 4/8/16/24/32/48px
- **Subtle borders** instead of heavy shadows
- **Progressive disclosure** - detail appears when needed

## Building

```bash
# Build Swift executable
make build

# Build the app bundle with the pinned Mole runtime
make app

open MoleMac.app
```

## Architecture

```
Sources/
  MoleMacApp.swift          # App entry point
  ContentView.swift          # Main layout with sidebar navigation
  Models/
    SystemStatus.swift       # Data models for all mo command outputs
  Services/
    MoService.swift          # Async wrapper for the bundled Mole runtime
  Theme/
    DesignTokens.swift       # Typography, colors, spacing, radii
  Views/
    StatusView.swift         # System health dashboard
    CleanView.swift          # Deep cleanup with category selection
    UninstallView.swift      # App browser with size info
    OptimizeView.swift       # System optimization runner
    AnalyzeView.swift        # Disk usage visualization
    PurgeView.swift          # Project artifact cleanup
```

## Safety

All destructive operations (clean, uninstall, purge) preview data first using `--dry-run` before execution. The app never runs destructive commands without showing what will be affected.

MoleMac uses the pinned runtime under `Vendor/MoleRuntime` and bundles it into `MoleMac.app/Contents/Resources/MoleRuntime`, so Homebrew Mole updates do not change app behavior.

## License

MIT
