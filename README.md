# Mogu

A minimal macOS GUI for [Mole](https://github.com/tw93/Mole) — the open-source system cleaner. Mogu is a friendly mole that digs through your Mac to clean caches, uninstall apps, and reclaim disk space, wrapping the `mo` CLI in a native SwiftUI app.

Built with SwiftUI for macOS, with a navy/indigo accent, adaptive light/dark theming, and a preview-before-delete safety model.

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 6.3+ and Go 1.21+ (only to build from source; the runtime is bundled)
- No separate Mole CLI install required — Mogu bundles a pinned Mole runtime.

## Features

| Panel | Description |
|---|---|
| **Status** | Live system monitoring — CPU, memory, disk, battery, network, top processes |
| **Clean** | Preview and execute deep cleanup of caches, logs, browser leftovers |
| **Uninstall** | Browse installed apps with sizes and related files |
| **Optimize** | One-click system optimization — rebuild caches, refresh services |
| **Analyze** | Visual disk usage breakdown with large-file detection |
| **Purge** | Find and clean project build artifacts (`node_modules`, `target`, etc.) |
| **Permissions** | Explains the minimal permission model; surfaces optional Full Disk Access |

## Permissions

Mogu needs **no permission to start** — no prompt on launch or tab switch. When you
choose to run a **Clean** or **Optimize**, it requests your administrator password
**up front** (admin-first). Granting it cleans user-owned items in your own context,
then system-level items with elevation; cancelling falls back to the unprivileged
run. Full Disk Access is **optional** — it only quiets the per-folder prompts during
home-directory scans. Nothing is stored and nothing runs in the background.

## Safety

All destructive operations (clean, optimize, purge) **preview first** with `--dry-run`
before anything is deleted — the app never runs a destructive command without showing
what will be affected. Preview-before-delete is enforced at both the unprivileged and
elevated tiers.

Mogu builds Mole from the `Vendor/Mole` git submodule and bundles it into
`Mogu.app/Contents/Resources/MoleRuntime`, so Homebrew Mole updates do not change app
behavior.

## Building

```bash
# First clone only: pull the bundled Mole runtime
git submodule update --init --recursive

# Compile the Swift executable
make build

# Build + sign the app bundle with the pinned Mole runtime (needs Go 1.21+)
make app

open Mogu.app
```

`make parser-test` runs the regression suite that guards the fragile text parsers
against golden fixtures.

## Architecture

```
Sources/
  MoguApp.swift               # App entry point
  ContentView.swift           # Sidebar navigation + action wiring
  Models/
    SystemStatus.swift        # Data models for mo command output
    StatusHistory.swift       # Rolling history for the Status charts
    ProcessStep.swift         # Optimize stream parser (StepStreamParser)
    Permission.swift          # Permission kinds + copy
  Services/
    MoService.swift           # Async actor wrapping the bundled `mo` CLI
    MoOutputParser.swift      # Unit-testable text parsers for no-JSON commands
    PermissionsService.swift  # Probes admin / Full Disk Access state
  Theme/
    DesignTokens.swift        # Typography, navy/indigo accent, spacing, radii
  Views/
    StatusView.swift          # System health dashboard
    CleanView.swift           # Deep cleanup with category selection
    UninstallView.swift       # App browser with size info
    OptimizeView.swift        # System optimization runner
    AnalyzeView.swift         # Disk usage visualization
    PurgeView.swift           # Project artifact cleanup
    PermissionsView.swift     # Permission model explainer
    Components/
      ErrorStateView.swift    # Shared error + retry state
      StatusCharts.swift      # Charts for the Status dashboard
```

The app icon and sidebar brand mark are generated from `icon-source.png` by
`scripts/make_icon.sh`.

## License

MIT
