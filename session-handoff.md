# Session Handoff

## Last Session

**Date:** 2026-06-01
**Branch:** `feat/drilbur-and-next-tasks`
**Work:** feat-009 … feat-013 (rename + 4 next tasks). All five done and verified.

## What shipped (one commit each)

| Feat | Commit | Summary |
|---|---|---|
| feat-010 | `5d4e1c9` | Analyze decode fix — `large_files[]` omit `is_dir`, made `DiskEntry.isDir` optional |
| feat-009 | `a2fbfae` | Rename app **MoleMac → Drilbur** (bundle id `co.greenpassport.drilbur`) |
| feat-011 | `dada995` | Parser-resilience harness: `MoOutputParser` + `DrilburTests` XCTest target |
| feat-013 | `912aadd` | Shared `ErrorStateView` (message + Retry) across the 5 mo-backed tabs |
| feat-012 | (this) | FDA not-granted check resolved — no code change needed |

## Current State

- App is **Drilbur** everywhere (window title, menu bar, sidebar brand; "Powered by bundled Mole"
  kept). The upstream Mole CLI / `mo` / `MoleRuntime/` path are deliberately unchanged.
- Env vars are `DRILBUR_SCREEN` / `DRILBUR_MO_PATH`.
- One test target exists now: `DrilburTests` (`make parser-test`), guarding the text parsers.
  `make test` is still build-only.
- `make build`, `make app`, and `make parser-test` (8/8) all pass. Bundle signs valid +
  satisfies its Designated Requirement.

## FDA not-granted check — RESOLVED (was the feat-008 manual check)

- The Drilbur rename gave the app a **new bundle id with no FDA grant**, so "not granted" is the
  default — no manual System Settings revoke was needed.
- Launched via LaunchServices (`open --env DRILBUR_SCREEN=permissions /Applications/Drilbur.app`,
  i.e. Drilbur as its own responsible process), the **Permissions card correctly reads "Not granted"**.
- The probe path needs **no repoint** — `PermissionsService.probeFullDiskAccess` already reads the
  system `/Library/Application Support/com.apple.TCC/TCC.db` (repointed in `c4fd444`).
- **Gotcha for future verification:** direct-exec'ing the bundle binary from an FDA-enabled terminal
  makes Drilbur *inherit* the terminal's FDA (TCC responsible-process attribution) → false "Granted".
  Always verify FDA state with `open` (LaunchServices), not by running the `MacOS/Drilbur` binary
  from a shell.

## Verification highlights (runtime, screenshots)

- Rename: window title / menu bar / sidebar all "Drilbur"; deep-link works; no crash.
- Error UX: forced a mo failure → Status tab shows `ErrorStateView` (triangle, "Something went wrong",
  message, Retry); normal launch shows the full Status dashboard (error state is conditional).
- Analyze: loaded a 161 GB / 163k-file analysis with no decode error (confirms feat-010 in the bundle).

## Next Step / Open items

- Branch `feat/drilbur-and-next-tasks` is ready to merge into `main` (not yet pushed).
- Optional: regenerate `Tests/DrilburTests/Fixtures/purge.txt` from a machine that actually has
  purgeable project artifacts (current one is format-verified, not a live capture — see Fixtures/README.md).
- Optional Status hardening: let a completed status decode assign even if the poll task was cancelled
  (first-launch "Reading system data…" edge on focus-steal).
