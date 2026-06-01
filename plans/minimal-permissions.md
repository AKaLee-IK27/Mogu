# Handoff: Minimal-permissions, works-everywhere model

**Owner:** Pi (execution) · **Controller/verifier:** Claude
**Branch:** `feat/minimal-permissions`
**Status:** Approved. **Pi executes PHASE 1 only.** Phase 2 (Touch ID) is a later, separate handoff.
**Verification gate:** runtime launch + behavior, NOT `make build` alone.

---

## Goal

Stop *requiring* any permission. The app must be useful on a **standard / company-managed
(non-admin) account with zero auth**, and reach system-level cleanup only when an admin is present.
Drop Full Disk Access and Automation entirely.

## Why (the bug being fixed)

Today Clean/Optimize **always** run via `streamElevated` (whole `mo` as root via osascript), so a
**non-admin user cannot run them at all**. Mole itself already supports graceful degradation
(`lib/clean/system.sh` = "requires sudo"; `clean.sh:983` and `optimize.sh:303` skip the system tier
cleanly when there's no sudo session). The GUI bypasses that by elevating the whole process. The fix:
run unprivileged first, offer elevation progressively.

This also fixes a latent **preview-before-delete** violation (CLAUDE.md invariant): today the preview
is unprivileged (user-level only) but execution is elevated (deletes system items never previewed).

---

## PHASE 1 SCOPE (do this now)

### 1. Permission model → Administrator only, optional
- `Sources/Models/Permission.swift`: reduce `PermissionKind` to `.administrator` only. Remove
  `.fullDiskAccess` and `.automation` cases (and their `icon`/`why`/`settingsURL`). Keep
  `PermissionStatus`.
- `Sources/Services/PermissionsService.swift`: remove `@Published fullDiskAccess` and
  `probeFullDiskAccess()`. `requirements(for:)` → `.clean`/`.optimize` return `[.administrator]`;
  `.analyze`/`.status`/`.purge`/`.uninstall`/`.permissions` return `[]`. `status(for:)` →
  `.administrator` = `.promptsWhenNeeded`.

### 2. Clean/Optimize → unprivileged-first + progressive escalation
Replace the always-elevated execute with this flow (keep preview-before-delete):

```
preview (stream, --dry-run)  →  user confirms  →  EXECUTE UNPRIVILEGED (stream, no --dry-run)
                                                       │  cleans user-owned; mo skips system
                                                       └─ output has skip marker?
                                                            → show "Clean system items too (requires admin)"
[escalate] → ELEVATED DRY-RUN (streamElevated, --dry-run)  ← shows system items (preview-before-delete!)
                  → user confirms → ELEVATED EXECUTE (streamElevated)  ← password dialog, runs as root
```

- `Sources/Views/CleanView.swift` — `runClean()`: change the execute from `streamElevated(["clean"])`
  to `stream(["clean"])`. Detect the skip marker in the streamed lines:
  **literal string `System-level cleanup skipped, requires sudo`** (from `clean.sh:983`). When present,
  surface a "Clean system items too — requires admin" button whose handler runs
  `streamElevated(["clean","--dry-run"])` (preview), then on confirm `streamElevated(["clean"])`.
- `Sources/Views/OptimizeView.swift` — `runOptimizeRun()`: change execute from
  `streamElevated(["optimize"])` to `stream(["optimize"])`. Detect skipped system steps via the
  existing `StepStreamParser` (`step.state == .skipped && step.requiresAdmin`). When any exist, surface
  the same escalation: `streamElevated(["optimize","--dry-run"])` preview → confirm →
  `streamElevated(["optimize"])`.
- **Do NOT shortcut the escalation into a bare elevated execute** — the elevated dry-run preview is
  required (preview-before-delete).

### 3. UI reframe
- `Sources/Views/PermissionsView.swift`: replace the 3 cards with ONE honest card —
  *"No permissions required to start. Administrator (password) is optional, requested only when you
  choose to clean system-level items. Nothing is stored; nothing runs in the background."* Remove the
  FDA/Automation cards and the System-Settings deep link. Update `PreflightBanner` to show only the
  admin pill (or an "optional admin" info note) where relevant.
- `Sources/Views/AnalyzeView.swift`: **remove** the `PreflightBanner` and the `permissions`
  property (analyze is read-only/unprivileged, needs no permission).
- `Sources/ContentView.swift`: remove the `permissions: permissions` argument from the `AnalyzeView(...)`
  constructor (this reverts the recently-added C3 banner — intentional).

## NON-SCOPE (Phase 1)
- **No Touch ID / `LAContext`** — that's Phase 2.
- **No** `pam_tid` / `sudo_local` changes, **no** privileged helper / SMAppService.
- **No** admin-group detection (`id -Gn`) — progressive disclosure makes it unnecessary; a non-admin
  who taps escalate just gets a failed/cancelled auth and the step stays skipped.
- Do not touch Status files or the Mole `Vendor/` submodule.

## Crash guards (MANDATORY — macOS 26.5 SIGTRAP)
No `.toolbar` / `ToolbarItem` / `ToolbarItemGroup`, no `.searchable`. Use `DesignTokens`.

## Verify early (Pi, before claiming build-done)
- Confirm `NONINTERACTIVE=1` unprivileged execute does NOT hang on `clean.sh:943`'s interactive
  "Enter/Space" prompt — i.e. `stream(["clean"])` completes and skips the system section. Test:
  `NONINTERACTIVE=1 LC_ALL=C /Applications/Drilbur.app/Contents/Resources/MoleRuntime/mo clean --dry-run`
  as the normal user (dry-run is safe) and confirm it returns and prints the skip marker.
- Confirm the skip-marker string matches verbatim (string match; fragile to Mole output changes, same
  class as existing text parsers).

## STOP RULE
A clean `swift build` is NOT done. When it builds, STOP and report to Claude (controller). Claude runs
the runtime verification:
- Launch app; Clean/Optimize run unprivileged with NO password prompt; user-level cleanup completes.
- The "Clean system items too (requires admin)" escalation appears, and the elevated path shows a
  dry-run preview BEFORE the password dialog.
- Permissions tab shows the single reframed card; Analyze has no permission banner.
- No crash.

## Rollback
Pure app-side UI/behavior. Revert the listed files; `stream`/`streamElevated` already exist. No data.

---

## PHASE 2 (LATER — do NOT start now)

Add an `LAContext` (`.deviceOwnerAuthenticationWithBiometrics`, fallback `.deviceOwnerAuthentication`)
**confirmation** prompt before the elevated dry-run on the escalation path. Success → proceed to the
password elevation; failure/unavailable → fall through to the password dialog (no dead-end). New small
`Sources/Services/BiometricGate.swift`, plus `NSFaceIDUsageDescription` in `build_app.sh`'s Info.plist.
**Note:** this Touch ID is a *confirmation gate only* — the admin password still performs the actual
elevation (no PAM/helper, to preserve managed-device compatibility).
