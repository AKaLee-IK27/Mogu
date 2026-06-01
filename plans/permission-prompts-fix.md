# Handoff: Kill the permission-prompt storm — lazy tabs + optional FDA

**Owner:** Pi (executor) · **Controller/verifier:** Claude
**Branch:** `feat/permission-prompts-fix` (checked out)
**Status:** Approved. Two phases, both in this handoff. Do A then B.
**Verification gate:** runtime launch + behavior, NOT `make build` alone.

---

## Root cause (confirmed)

`StickyTab.body` renders `content()` **unconditionally**, and `ContentView.tabContainer`
puts all six tabs in a ZStack — so **every tab's `.task` fires at launch**.
`AnalyzeView.task` runs `mo analyze ~` (`getAnalysis(NSHomeDirectory())`), traversing
Desktop/Documents/Downloads/Music/Pictures — all TCC-protected — so macOS fires a
"Files & Folders" prompt per folder **at startup, before the user does anything**.
Dropping Full Disk Access in the minimal-permissions work removed the one-grant fix.

---

## PHASE A — Lazy-load tabs (kills the startup storm)

Defer each tab's content (and its `.task`) until the tab is first activated; keep it alive
after (sticky), so re-switching does not reload.

- `Sources/ContentView.swift`, `struct StickyTab`: add `let isActive: Bool`. Change `body` to
  render content only when active-or-already-loaded:
  ```
  var body: some View {
      Group {
          if isActive || loadedTabs.contains(key) {
              content()
          } else {
              Color.clear
          }
      }
      .onChange(of: isActive) { _, active in if active { loadedTabs.insert(key) } }
      .onAppear { if isActive { loadedTabs.insert(key) } }
  }
  ```
- `Sources/ContentView.swift`, `tabView(for:)`: pass `isActive: selectedItem == item` to **all six**
  `StickyTab(...)` call sites (status/clean/uninstall/analyze/optimize/purge/permissions — note
  there are 7 cases incl. permissions).
- Result: at launch only the default-selected tab (Status, or `MOLEMAC_SCREEN`) runs its `mo`
  call. Other tabs render `Color.clear` until first opened. No home-dir scan / no prompt storm
  at startup. (This also retires the "six `mo` calls at launch" gotcha.)
- Do NOT remove the StatusView `isActive` polling gate — it stays; StickyTab's `isActive` is the
  same `selectedItem == .status`, they coexist.

## PHASE B — Re-introduce Full Disk Access as OPTIONAL

Admin stays the only thing for elevation. FDA returns as an **optional, never-required**
convenience that silences the per-folder prompts when scanning.

- `Sources/Models/Permission.swift`: add back a `.fullDiskAccess` case to `PermissionKind`
  (keep `.administrator`; do NOT add `.automation`). Give it:
  - `title` = "Full Disk Access"
  - `icon` = "externaldrive.fill"
  - `why` = "Lets Mole scan your home folder quietly — macOS won't ask for each folder
    (Desktop, Documents, Downloads, …). Optional; the app works without it, you'll just see a
    per-folder prompt the first time you scan each one."
  - `settingsURL` = `URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")`
    (administrator's settingsURL stays `nil`).
- `Sources/Services/PermissionsService.swift`:
  - Add `@Published private(set) var fullDiskAccess: PermissionStatus = .unknown`; set it in
    `refresh()` via a probe.
  - **Probe (use the RELIABLE path):** attempt to read the **system** TCC database
    `/Library/Application Support/com.apple.TCC/TCC.db` (NOT the user-level
    `~/Library/...` one — that can read without FDA and give a false "granted"). Reading the
    system TCC.db succeeds only with FDA. Pattern: `fileExists` → `FileHandle(forReadingFrom:)`
    → `read(upToCount: 1)`; success → `.granted`, thrown error → `.notGranted`, missing → `.unknown`.
  - `status(for:)`: `.fullDiskAccess` → `fullDiskAccess`; `.administrator` → `.promptsWhenNeeded`.
  - `requirements(for:)`: leave unchanged (FDA is NOT required — clean/optimize → `[.administrator]`,
    rest → `[]`). FDA is surfaced separately, not as a requirement.
- `Sources/Views/PermissionsView.swift`: keep the "no permissions required to start" framing; add an
  **Optional** FDA card showing live status (granted / not granted), the `why`, and an "Open in
  System Settings" button (`permissions` + the FDA `settingsURL`). Match the existing card styling /
  DesignTokens. (You may add an Administrator optional card too if it reads well, but FDA is the point.)
- `Sources/Views/AnalyzeView.swift`: AnalyzeView already takes nothing for permissions now. Add
  `@ObservedObject var permissions: PermissionsService` back, and when
  `permissions.status(for: .fullDiskAccess) != .granted`, show a one-line hint banner near the top:
  "Grant Full Disk Access to scan without per-folder prompts" + an "Open Settings" affordance
  (reuse `PreflightBanner` styling or a small inline banner). Pass `permissions:` into AnalyzeView
  from `ContentView.swift`'s `.analyze` StickyTab.

## CLAUDE.md updates (part of the work)
- The permissions paragraph currently says "`PermissionKind` is `.administrator` only (optional)."
  Update to: "`.administrator` (for elevation) + `.fullDiskAccess` (optional; granting it silences
  the per-folder TCC 'Files & Folders' prompts during home-dir scanning; probed via the system
  `/Library/Application Support/com.apple.TCC/TCC.db`)."
- The Critical Gotchas note "every view's `.task` fires at launch (six `mo` calls on startup)" is
  now FALSE — update to: "tabs lazy-load via `StickyTab` (`isActive || loadedTabs`); only the
  active tab runs its `mo` call. Switching keeps a tab loaded (sticky)."

## NON-SCOPE
- Do NOT change what `analyze` scans (still the full home dir; FDA is the quiet path, not a scope cut).
- Do NOT make FDA required, and do NOT re-add Automation or any pam_tid/helper.
- Do NOT touch Status polling/gating, the elevation flow, or Vendor/.

## Crash guards (MANDATORY — macOS 26.5 SIGTRAP)
No `.toolbar` / `ToolbarItem` / `ToolbarItemGroup`, no `.searchable`. Use `DesignTokens`.

## STOP RULE
A clean `swift build` is NOT done. When it builds, STOP and report (files changed + how you wired
the lazy gate and the FDA probe). The controller runs runtime verification.

## Verification (controller runs)
- **Phase A:** launch app; Activity Monitor shows only `status-go` at startup (no `analyze`/`purge`/
  `optimize`/etc.); **no TCC prompts on launch**. Open Analyze → the scan runs then.
- **Phase B:** Permissions tab shows the optional FDA card with correct status. Manual (controller,
  can't be done from an FDA-enabled shell): toggle FDA off → relaunch → probe reads "Not granted"
  and the Analyze hint shows; grant FDA → Analyze scans silently.
- `make test` + no crash on any tab.

## Rollback
Pure UI/model. Revert the files; no data/migration. Phases revert independently.
