# Session Progress Log

## Current State

**Last Updated:** 2026-05-31
**Active Feature:** feat-003 through feat-007 — All 5 features implemented

## Completed Sub-Tasks This Session

| ID | Sub-Task | Status | Notes |
|---|---|---|---|
| feat-003 | App Icon | done | icon.png → AppIcon.icns, bundled in build_app.sh |
| feat-004 | Auto-Refresh Status Tab | done | Timer.publish every 30s, Live badge in header |
| feat-005 | Sort/Filter Uninstall & Purge | done | SortOrder enum, .searchable on both views |
| feat-006 | Real Uninstall Execution | done | executeUninstall in MoService, confirmation dialog |
| feat-007 | Dark Mode | done | adaptive() helper, Color(light:dark:) extension, removed forced .aqua |
| crash-fix | Toolbar crash on macOS 26.5 | done | Root cause: EmptyView in ToolbarItem. Fix: switch-based pattern |

## Crash Investigation

**Symptom:** SIGTRAP in `[NSToolbar _insertNewItemWithItemIdentifier:]` on app launch (macOS 26.5)

**Root Cause:** Restructured toolbar used 2 fixed slots with computed properties returning `EmptyView()` for some tabs. macOS 26.5's AppKit crashes when resolving `EmptyView()` inside a `ToolbarItem` during initial layout.

**Resolution:** Reverted to original switch-based pattern with explicit `ToolbarItem` per case, no `EmptyView()`, plus explicit `id:` parameters.

## Verification Evidence

| Check | Command | Output | Pass? |
|---|---|---|---|
| Swift build | `make build` | Build complete! | ✓ |
| Test | `make test` | Build passed | ✓ |
| App launch | `open /Applications/MoleMac.app` | No crash reports after 21:12 | ✓ |
| Dark mode | System theme toggle | App follows system theme | ✓ |

## Files Modified

- `Sources/ContentView.swift` — Toolbar with explicit IDs, uninstall button, runTrigger
- `Sources/Services/MoService.swift` — executeUninstall, previewUninstall
- `Sources/Theme/DesignTokens.swift` — adaptive() helper, dark color variants, Color(light:dark:) extension
- `Sources/Views/StatusView.swift` — Timer.publish auto-refresh, Live badge
- `Sources/Views/UninstallView.swift` — SortOrder, .searchable, runTrigger, confirmation dialog, executeUninstall
- `Sources/Views/PurgeView.swift` — SortOrder, .searchable
- `Sources/MoleMacApp.swift` — Removed forced .aqua/.light
- `build_app.sh` — Bundle AppIcon.icns
- `AppIcon.icns` — Generated from icon.png
