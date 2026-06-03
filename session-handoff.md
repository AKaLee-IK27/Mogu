# Session Handoff

## Last Session

**Date:** 2026-06-03
**Branch:** `main`
**Work:** feat-025, Status dashboard visual polish and live-polling gating fix.

## What changed

- Finished the in-progress `Sources/Views/StatusView.swift` dashboard polish: hero health card, adaptive metric rows, CPU/memory/storage cards, live sparklines, per-core strip, memory breakdown, proxy/live badges, and stable top-process rows.
- Fixed the macOS foreground-gating bug: `scenePhase` stayed active while another app was frontmost, so Status polling now follows `NSApplication.didBecomeActiveNotification` / `didResignActiveNotification`.
- Updated tracking/docs: `feature_list.json`, `progress.md`, and `plans/status-live-redesign.md` now reflect feat-025 and current `MOGU_SCREEN` / `Mogu.app` launch instructions.

## Verification

All verification passed in this session:

```bash
make build
make test
make app
make parser-test
```

Runtime verification:

- Launched with `open --env MOGU_SCREEN=status /Applications/Mogu.app`.
- Captured Status window evidence at `/tmp/mogu-status-live-feat025-live.png`.
- Active Status sampling observed `status-go` / `mole status --json` spawning on the live cadence.
- After backgrounding Mogu, a 20-second sample showed no `status-go` / `mole status --json` processes.

## Current State

- Status tab is visually polished and live-updating when Mogu is frontmost.
- Polling stops when Mogu is backgrounded. Earlier tab-switch verification also settled to no `status-go` processes after leaving Status.
- The installed `/Applications/Mogu.app` was rebuilt from the current source.

## Next Step / Open items

- Post-implementation `/check` completed in-session; no unresolved feat-025 blocker.
- If ready, commit the feat-025 diff.
- Unrelated follow-up observed during runtime verification: first-run onboarding dismissal does not appear to persist `hasSeenOnboarding`; left out of scope for feat-025.
