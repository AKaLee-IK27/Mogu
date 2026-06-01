# Session Progress Log

## Current State

**Last Updated:** 2026-06-02
**Status:** feat-015 (in-app uninstaller + sortable list) shipped on `main` (commit `4ac5645`, pushed). App is **Mogu** (renamed from Drilbur; env vars `MOGU_SCREEN` / `MOGU_MO_PATH`).

## Session 2026-06-02: In-app uninstaller + sortable list (feat-015)

Turned the read-only Uninstall browser into a working multi-select uninstaller, then added column sorting. One commit, pushed to `main`.

| Area | What changed | Verification |
|---|---|---|
| Model | `AppInfo` + `source`/`path`/`requiresAdmin`; `UninstallPreview` | builds |
| Parser | `MoOutputParser.parseUninstallPreview` (glyph block + ANSI strip) | golden fixture `uninstall-preview.txt`, 5 new tests |
| Service | `streamFeeding` (fed `y\n`, uninstall-only); `bundleRequiresAdmin`; preview-before-delete guard | `make parser-test` 17/17 |
| View | multi-select + admin-deferred rows, confirm sheet, streamed execute, sortable columns | real uninstall of a disposable bundle → Trash, exit 0, no hang |

**Verification highlights:** fed `y\n` drives Mole's two uninstall prompts (proven on dry-run single + multi-app); a real execute removed a dummy app + leftover into `~/.Trash`; admin detection matches `stat` (user-owned selectable, root-owned flagged); app launches to the Uninstall screen and renders (checkboxes, Admin badges, size-descending sort).

**Adversarial review:** 25-agent multi-dimension review returned 12 confirmed findings, all triaged. Fixed the real ones (preview/execute selection re-validation, live admin re-check, sheet-state ordering, banner-flicker fold, missing-terminator test, README locale note). Refuted one HIGH by primary source: "admin detection misses system leftovers" is moot because Mole forces `system_files=""` before its `needs_sudo` check (`batch.sh:517`).

**Deferred (discussed, not built):** uninstalling admin apps in-app (needs elevated run with `$HOME` pinned + verification), and an admin pre-authorize button in Permissions (macOS has no persistent admin grant for an ad-hoc-signed app).

## Session 2026-06-01 — Drilbur rename + 4 next tasks

App renamed **MoleMac → Drilbur**, plus four follow-on tasks. One commit per feature; all verified.

| ID | Feature | Verification |
|---|---|---|
| feat-010 | Analyze decode fix (`isDir` optional) | Root cause confirmed vs real mo (`large_files[]` omit `is_dir`); `5d4e1c9` |
| feat-009 | Rename → Drilbur (`co.greenpassport.drilbur`) | Zero residue, MoleRuntime intact, signed valid, runtime title/sidebar/menu "Drilbur"; `a2fbfae` |
| feat-011 | Parser-resilience harness | `MoOutputParser` extracted + `DrilburTests` (8 tests, `make parser-test`); drift mutation fails the golden test; `dada995` |
| feat-013 | Shared error-state UX | `ErrorStateView` (msg + Retry) across 5 tabs; forced-failure + normal-path screenshots; `912aadd` |
| feat-012 | FDA not-granted check | Resolved, no code change: new bundle id = no FDA by default; `open`-launched Permissions card reads "Not granted"; probe already on system `/Library` path |

**Key learning:** verify FDA state via `open` (LaunchServices), never by direct-exec'ing the bundle
binary from a terminal — the child inherits the terminal's FDA (TCC responsible-process attribution).

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
