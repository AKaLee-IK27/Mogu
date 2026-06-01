# Session Handoff

## Last Session

**Date:** 2026-06-01
**Feature:** feat-008 — Permissions / Full Disk Access Finish
**Status:** Implementation complete + controller runtime-verified (Analyze banner). FDA not-granted branch deferred to a documented manual check.

## Current State

- Analyze now receives the shared `PermissionsService` and renders `PreflightBanner(item: .analyze, permissions: permissions)` below its header, matching Clean and Optimize.
- `ContentView.swift` was changed only at the `.analyze` `AnalyzeView(...)` constructor to pass `permissions: permissions`.
- `feature_list.json` has a `feat-008` entry tracking the Permissions finish work.
- `PermissionsService.probeFullDiskAccess` was intentionally left unchanged pending the controller's no-FDA runtime test.

## Verification State

- `swift build` passes (implementer + controller).
- Controller runtime verification (built `.app` from this branch, launched to Analyze):
  1. ✅ Analyze preflight banner renders ("Uses: Full Disk Access"), matching Clean/Optimize. No crash.
  2. ⏳ **MANUAL CHECK (deferred to maintainer):** FDA not-granted branch — see below.
  3. ✅ No launch or tab-switch crash observed.

### MANUAL CHECK — FDA "Not granted" branch

The probe cannot be exercised from an FDA-enabled environment (it reads "Granted"). Run once:
1. System Settings → Privacy & Security → Full Disk Access → toggle **Drilbur OFF** (or remove it).
2. Relaunch Drilbur → open the **Permissions** tab.
3. Expected: Full Disk Access card reads **"Not granted"** (amber); Clean/Optimize/Analyze preflight
   banners show the FDA pill with a warning dot.
4. If it still reads **"Granted"** → probe is a false-positive: repoint
   `PermissionsService.probeFullDiskAccess` from `~/Library/Application Support/com.apple.TCC/TCC.db`
   to the system path `/Library/Application Support/com.apple.TCC/TCC.db`, rebuild, re-test.
5. Re-enable FDA afterward.

## Separate finding (NOT this feature — pre-existing, unfixed)

- The **Analyze data path** shows a decode error at runtime ("The data couldn't be read because it is
  missing") — a Codable failure in the analyze result. This feature never touched `AnalysisResult` or
  `MoService.getAnalysis`, so it is pre-existing. Reported, not fixed. Worth a separate `/hunt`.

## Blockers

- None in implementation scope.
- FDA probe path must not change unless the manual check above reports a false-positive "Granted".

## Build note (controller, temporary)

- To build this worktree's `.app`, `Vendor/Mole` was symlinked to the main checkout's built submodule
  (worktrees don't auto-populate submodules). **Remove that symlink before committing** so the
  submodule gitlink is not replaced — the diff should stay at the 4 source/tracking files only.

## Files Changed This Session

- `Sources/Views/AnalyzeView.swift`
- `Sources/ContentView.swift`
- `feature_list.json`
- `session-handoff.md`

## Guardrails Preserved

- No `.toolbar`, `ToolbarItem`, `ToolbarItemGroup`, or `.searchable` added.
- No Clean step-UI added.
- No Status files changed.
- No hardcoded colors added; banner uses existing `PreflightBanner` and design tokens.

## Next Step

1. Maintainer runs the FDA not-granted manual check above.
2. Reorganize history: the local base commit `e96bb8c` mixes Status + Permissions. Split into clean
   commits before any push; merge `feat/permissions-finish` into `main` (no `ContentView` conflict
   expected — this branch only adds the `AnalyzeView` constructor arg).
3. Optional Status hardening: let a completed status decode assign even if the poll task was cancelled
   (StatusView lines ~513/521), to remove the first-launch "Reading system data…" edge on focus-steal.
4. Separate `/hunt` for the pre-existing Analyze decode error.
