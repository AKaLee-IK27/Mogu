# Handoff: Finish & land the Permissions / Full Disk Access feature

**Owner:** Pi-Permissions (execution, in worktree) · **Controller/verifier:** Claude
**Status:** Approved, awaiting base commit
**Worktree:** `../mole-mac-perms` on branch `feat/permissions-finish` (branched from a WIP base containing Status + Permissions)
**Verification gate:** runtime launch + screenshot, incl. the FDA not-granted branch (NOT `make build` alone)

---

## Context: this feature is ~80% built, not half-built

Already wired and working:
- `PermissionsView` — dedicated 7th sidebar tab (3 cards: Full Disk Access, Administrator, Automation).
- `PreflightBanner` — used in `CleanView` and `OptimizeView`.
- `StepStreamParser` / `ProcessStep` — drive Optimize's live step list.
- `PermissionsService` — FDA probe + Settings deep links + `requirements(for:)`.

## Scope — close 3 gaps, then it's done

1. **Analyze preflight banner.** `PermissionsService.requirements(for: .analyze)` returns `[.fullDiskAccess]`, but `AnalyzeView` shows **no** banner (Clean + Optimize do). Add it for consistency.
2. **FDA probe — verify-then-fix (CONDITIONAL).** See below. Do NOT blindly "fix" it.
3. **Track it.** Add `feature_list.json` entry with evidence; refresh `session-handoff.md` (it predates this feature).

## Non-scope (do NOT do)

- **Do NOT add step-UI to Clean.** Clean uses the `~/.config/mole/clean-list.txt` side-file
  preview model, not the streamed `➤`/`→` step model Optimize uses. This is by design
  (CLAUDE.md). Leaving Clean without a step list is correct, not a gap.
- No new permission kinds beyond the existing three.
- Do NOT touch Status work (`StatusView.swift`, `StatusHistory.swift`, `StatusCharts.swift`,
  Status parts of `SystemStatus.swift`/`ContentView.swift`). That's Pi-Status's domain.

---

## Task 1 — Analyze preflight banner

- `Sources/Views/AnalyzeView.swift`: add `@ObservedObject var permissions: PermissionsService`
  property; add `PreflightBanner(item: .analyze, permissions: permissions)` near the top of the
  body, matching how `CleanView` (line ~22) and `OptimizeView` (line ~19) do it.
- `Sources/ContentView.swift`: pass `permissions: permissions` into the `AnalyzeView(...)`
  constructor (the `.analyze` `StickyTab`, ~line 145). This is the ONLY ContentView edit.

## Task 2 — FDA probe: verify-then-fix (do NOT assume a bug)

Current probe (`PermissionsService.probeFullDiskAccess`) reads:
`~/Library/Application Support/com.apple.TCC/TCC.db` — a standard FDA-detection method that
**may be correct**. It cannot be confirmed broken from an FDA-enabled shell.

**Verifier (Claude) runs the discriminating test:** toggle Full Disk Access OFF for the app in
System Settings, relaunch, read the Permissions tab badge.
- Badge reads **"Not granted"** → probe is correct. **Make NO change.**
- Badge still reads **"Granted"** → false positive. THEN repoint the probe to the system path
  `/Library/Application Support/com.apple.TCC/TCC.db` (unambiguously requires FDA), and re-test.

Pi: leave the probe as-is unless the verifier reports a false positive.

## Task 3 — Tracking

- `feature_list.json`: add an entry for this feature (id, title, status, files, evidence).
  Match the existing entry schema in that file.
- `session-handoff.md`: refresh — it currently describes feat-003..007 and predates Permissions.

---

## Crash guards (MANDATORY — macOS 26.5 SIGTRAP)

- No `.toolbar` / `ToolbarItem` / `ToolbarItemGroup`. No `.searchable`.
- Use `DesignTokens`, no hardcoded colors.

## Verification (runtime — compile is NOT sufficient)

1. `make app`, launch to Clean / Optimize / **Analyze** — confirm the preflight banner shows the
   correct permission pills on each. Screenshot Analyze.
2. **Not-granted branch:** toggle FDA OFF, relaunch, confirm Permissions tab + banners read
   "Not granted". (This path can't be exercised from an FDA-enabled dev shell — must be explicit.)
3. No crash on launch or tab switch.

`make build` / `make test` is a necessary compile gate but NOT sufficient.

## Rollback

Additive UI + tracking docs + (conditional) one-line probe path swap. Revert `AnalyzeView.swift`
and the `ContentView` arg; no data touched.

## Most fragile assumption

Assumes the existing FDA probe is correct until the no-FDA test says otherwise. Encoding a "fix"
without that test risks breaking a working probe.

## Merge-back

Branch `feat/permissions-finish` was based on a commit already containing Pi-Status's `ContentView`
gate, so merging to `main` should not conflict on `ContentView.swift` (this branch only adds the
`AnalyzeView` constructor arg). If `main` gained Status fixes that touched `ContentView`, resolve in
favor of keeping BOTH the gate and the new `permissions:` arg.
