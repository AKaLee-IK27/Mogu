# Session Handoff

## Last Session

**Date:** 2026-06-02
**Branch:** `main` (committed and pushed)
**Work:** feat-015, the in-app uninstaller (multi-select, leftover preview, Trash routing) plus Finder-style column sorting.

## What shipped

| Commit | Summary |
|---|---|
| `4ac5645` | In-app app uninstaller with leftover preview and sortable list (one feature commit, pushed to `origin/main`) |

The commit covers: `AppInfo` source/path/requiresAdmin + `UninstallPreview` (`Models/SystemStatus.swift`); `parseUninstallPreview` + `stripControlSequences` (`Services/MoOutputParser.swift`); `streamFeeding`, `bundleRequiresAdmin`, the uninstall preview-before-delete guard (`Services/MoService.swift`); the rebuilt multi-select view with sortable columns (`Views/UninstallView.swift`); the golden fixture `Tests/MoguTests/Fixtures/uninstall-preview.txt` and its tests.

## Current State

- The Uninstall tab is a real uninstaller: select user-owned apps, preview each one's bundle + leftovers (parsed from a dry-run), confirm, and they move to the **Trash** (recoverable). It runs **unprivileged** so `~/Library` leftovers resolve in the user's context.
- **Admin-required apps** (root-owned bundles, Homebrew casks) are detected (`bundleRequiresAdmin`, mirrors Mole's `needs_sudo`) and shown **non-selectable** with an "Admin" badge, kept inline (no separate section). One admin app in an unprivileged batch would make Mole abort the whole batch, so they are deferred to the Mole CLI.
- The list **sorts** by name or size, ascending or descending, via clickable column headers (default size-descending).
- `make build`, `make app`, and `make parser-test` (17 cases) all pass. The installed `/Applications/Mogu.app` is rebuilt to match.

## Mechanism notes (non-obvious)

- Mole's uninstall has **no JSON** for the run or `--dry-run`; the preview is parsed from text (`Files to be removed:` / `◎`/`✓`/`➤`). On format drift the parse returns empty, the guard stays disarmed, and the fixture test fails loudly.
- Mole prompts twice (`read -r confirm`, then a single-key `Enter/ESC`). `streamFeeding` feeds `y\n`: the first prompt consumes the `y`, the second proceeds on EOF. Keep this **uninstall-only**; `stream`/`streamElevated` must keep `nullDevice` stdin (the `[[ -t 0 ]]` hang gotcha).

## Next Step / Open items

- **Deferred by decision:** uninstalling admin apps in-app. The viable path is an elevated run with `HOME` pinned to the real user home (plain elevated-as-root sets `$HOME=/var/root` and collapses leftover discovery, verified). Two unknowns to verify first: that `HOME`-pinned elevated removal keeps the leftovers, and that the `y` confirmation feeds through the osascript-as-root shell.
- **Deferred by decision:** an admin pre-authorize button in Permissions. macOS has no persistent admin grant for an ad-hoc-signed app; the only lever is the ~5-minute OS auth cache (opaque, unverifiable here).
- Working tree is clean after this session's commit; docs (README, CLAUDE.md, feature_list.json, progress.md, this file) updated in a follow-up commit.
