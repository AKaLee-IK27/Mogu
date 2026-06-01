# Session Progress Log

## Current State

**Last Updated:** 2026-05-31
**Status:** All features implemented, crash resolved, app verified running

## Completed Features

| ID | Feature | Status | Evidence |
|---|---|---|---|
| feat-003 | App Icon | done | icon.png → AppIcon.icns, bundled in build_app.sh |
| feat-004 | Auto-Refresh Status Tab | done | Timer.publish every 30s, Live badge in header |
| feat-005 | Sort/Filter Uninstall & Purge | done | SortOrder enum, .searchable on both views |
| feat-006 | Real Uninstall Execution | done | executeUninstall in MoService, confirmation dialog |
| feat-007 | Dark Mode | done | adaptive() helper, Color(light:dark:) extension |
| crash-fix | macOS 26.5 Toolbar Crash | done | 2-slot pattern with explicit IDs |

## Crash Investigation Summary

**Symptom:** SIGTRAP in `[NSToolbar _insertNewItemWithItemIdentifier:]` on macOS 26.5
**Root Cause:** Switch-based `@ToolbarContentBuilder` with 9 ToolbarItems across cases crashes during initial layout on macOS 26.5.
**Fix:** Consolidated to 2 fixed slots (`refresh`, `action`) with explicit `id:` and computed properties. No `EmptyView()` in toolbar items — use `if showAction` at ToolbarContent level.
**Hypotheses tested (all ruled out):** tint colors, EmptyView, explicit IDs on switch-based items
**Verified:** App launches and runs without crash on macOS 26.5 (25F71). Screenshot captured at 21:26.

## Files Modified

- `Sources/ContentView.swift` — 2-slot toolbar with explicit IDs, uninstall button
- `Sources/Services/MoService.swift` — executeUninstall, previewUninstall
- `Sources/Theme/DesignTokens.swift` — adaptive() helper, dark color variants, Color(light:dark:) extension
- `Sources/Views/StatusView.swift` — Timer.publish auto-refresh, Live badge
- `Sources/Views/UninstallView.swift` — SortOrder, .searchable, runTrigger, confirmation dialog
- `Sources/Views/PurgeView.swift` — SortOrder, .searchable
- `Sources/DrilburApp.swift` — Removed forced .aqua/.light
- `build_app.sh` — Bundle AppIcon.icns
- `AppIcon.icns` — Generated from icon.png

## Verification

| Check | Command | Result |
|---|---|---|
| Swift build | `make build` | ✓ |
| Test | `make test` | ✓ |
| App launch | `open /Applications/Drilbur.app` | ✓ No crash, dark mode confirmed via screenshot |
