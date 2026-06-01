# Handoff: Phase 2 — Touch ID confirmation gate (LAContext)

**Owner:** Claude subagent (executor, in herdr pane) · **Controller/verifier:** Claude (main session)
**Branch:** `feat/phase2-touchid` (already checked out)
**Status:** Approved. Builds on the shipped Phase 1 minimal-permissions model (already on `main`).
**Verification gate:** runtime launch + behavior, NOT `make build` alone.

---

## Context (read first)

Phase 1 (already shipped) made Clean/Optimize run **unprivileged first**, then offer a
**progressive admin escalation** for system-level items via `streamElevated` (osascript
"with administrator privileges" → admin **password**). Phase 2 adds a **Touch ID confirmation
gate** in front of that escalation.

**Design truth — do not change it:** the Touch ID here is a **confirmation gate only**, NOT
biometric elevation. macOS still requires the admin **password** to actually run the system
cleanup as root (we deliberately avoid `pam_tid`/`sudo_local` and privileged helpers because
they break on managed/MDM devices). So the flow is: **Touch ID confirm → (existing) password
elevation**. Touch ID does not replace the password. This is intentional and approved.

---

## Scope

### 1. New file: `Sources/Services/BiometricGate.swift`
A small `LocalAuthentication` helper:
- `import LocalAuthentication`
- An `enum BiometricGate` (or struct) with one async static method, e.g.
  `static func confirm(reason: String) async -> Bool`.
- Implementation:
  - Create `let context = LAContext()`.
  - If `context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error:)` is **false**
    (no Touch ID hardware / not enrolled), **return `true`** — i.e. NO dead-end: fall straight
    through to the password elevation. (Do NOT block the user just because biometrics are absent.)
  - Otherwise `evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)`
    via the async/continuation API. Return `true` on success.
  - On failure: distinguish **user cancel / user-fallback** (`LAError.userCancel`,
    `.systemCancel`, `.userFallback`, `.appCancel`) → return `false` (abort the escalation, no
    password prompt). Any other error → return `true` (fall through to password rather than
    dead-ending). Keep it simple and documented.
- Must run on the main actor where it touches UI timing, but `evaluatePolicy` itself is fine off-main;
  wrap with a continuation. Keep it self-contained.

### 2. Wire the gate at the escalation ENTRY (one Touch ID, upfront)
- `Sources/Views/CleanView.swift:234` — the "Clean system items too (requires admin)" button
  currently does `Task { await previewElevatedClean() }`. Change to:
  `Task { if await BiometricGate.confirm(reason: "Confirm to preview and clean system-level items") { await previewElevatedClean() } }`
- `Sources/Views/OptimizeView.swift:142` — the "Optimize system items too (requires admin)" button
  currently does `Task { await previewElevatedOptimize() }`. Apply the same gate with reason
  "Confirm to preview and optimize system-level items".
- Gate the **entry** only (before the elevated dry-run preview). Do NOT add a second Touch ID before
  the execute step — one biometric confirmation when the user opts into the admin flow is enough.
- If `confirm` returns `false` (user cancelled biometric), simply do nothing (no error banner needed,
  or set a soft `resultMessage`). Do NOT proceed to the password flow.

### 3. Info.plist: `NSFaceIDUsageDescription`
- `build_app.sh` builds `Info.plist` via a heredoc (around line 38, alongside the existing
  `NSAppleEventsUsageDescription` / `NSSystemAdministrationUsageDescription` keys). Add:
  `<key>NSFaceIDUsageDescription</key>`
  `<string>Drilbur uses Touch ID to confirm system-level cleanup before asking for your administrator password.</string>`
  (Touch ID on Macs is gated by this Face ID usage key.)

## NON-SCOPE
- No `pam_tid` / `sudo_local` changes, no privileged helper / SMAppService, no `sudo`-based elevation.
- Do NOT change the existing Phase 1 escalation logic, the skip-marker detection, the
  preview-before-delete guards, or `streamElevated`/`stream`.
- Do NOT touch Status files, the Permissions model, or `Vendor/`.
- Do NOT add a second Touch ID prompt before the execute step.

## Crash guards (MANDATORY — macOS 26.5 SIGTRAP)
No `.toolbar` / `ToolbarItem` / `ToolbarItemGroup`, no `.searchable`. Use `DesignTokens`.

## STOP RULE
A clean `swift build` is NOT done. When it builds, STOP and report to the controller (Claude main
session). The controller runs runtime verification (the Touch ID prompt appears on tapping the
escalation; cancelling it aborts without a password prompt; unavailable biometrics fall through).

## Verification (controller runs; for your awareness)
- `make app`, launch app. Tap "Clean system items too (requires admin)" → a **Touch ID** prompt
  appears with the configured reason. Approve → proceeds to the elevated dry-run (password) flow.
  Cancel → escalation aborts, NO password dialog.
- No crash; `LocalAuthentication` links (it's a system framework — `import` is enough with SwiftPM).

## Rollback
Additive: a new file + 2 one-line call-site wraps + 1 Info.plist key. Revert to drop Phase 2 cleanly.

## Known UX note (out of scope, for the controller — do not fix here)
The Phase 1 escalation already prompts the admin password twice (once for the elevated dry-run
preview, once for the elevated execute) because separate osascript invocations don't share auth.
Phase 2 adds one Touch ID at entry. Reducing the password count would require a cached sudo session
(rejected for managed-device compatibility). Leave as-is.
