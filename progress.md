# Session Progress Log

## Current State

**Last Updated:** 2026-06-03
**Status:** feat-029 completed locally — Analyze screen redesign implemented and runtime-verified.

## Session 2026-06-03: Analyze Screen Design System Redesign (feat-029)

Redesigned AnalyzeView as a clearer disk-usage dashboard using the Mogu design system, without changing analyze behavior.

| ID | Feature | Verification |
|---|---|---|
| feat-029 | Analyze Screen Design System Redesign | `make build`, `make test`, `make parser-test`, `make app`; runtime screenshot `/tmp/mogu-analyze-feat029-complete.png` |

**Files changed:** 4 files
- Modified: `Sources/Views/AnalyzeView.swift`, `feature_list.json`, `progress.md`, `session-handoff.md`
- New: `design-system/mogu/pages/analyze.md`

## Session 2026-06-03: Uninstall Screen Design System Redesign (feat-028)

Redesigned UninstallView as a safer batch-selection and preview-before-uninstall surface using the Mogu design system, without changing uninstall command behavior.

| ID | Feature | Verification |
|---|---|---|
| feat-028 | Uninstall Screen Design System Redesign | `make build`, `make test`, `make parser-test`, `make app`; runtime list screenshot `/tmp/mogu-uninstall-feat028-list.png`; runtime selected-row screenshot `/tmp/mogu-uninstall-feat028-selected.png`; no Preview Uninstall or Move to Trash click |

**Files changed:** 5 files
- Modified: `Sources/Views/UninstallView.swift`, `feature_list.json`, `progress.md`, `session-handoff.md`
- New: `design-system/mogu/pages/uninstall.md`

## Session 2026-06-03: Clean Screen Design System Redesign (feat-027)

Redesigned CleanView as a preview-first cleanup dashboard using the Mogu design system, without changing cleanup command behavior.

| ID | Feature | Verification |
|---|---|---|
| feat-027 | Clean Screen Design System Redesign | `make build`, `make test`, `make parser-test`, `make app`; runtime loading screenshot `/tmp/mogu-clean-feat027-loading.png`; runtime preview screenshot `/tmp/mogu-clean-feat027-preview.png`; no destructive Clean All action clicked |

**Files changed:** 5 files
- Modified: `Sources/Views/CleanView.swift`, `feature_list.json`, `progress.md`, `session-handoff.md`
- New: `design-system/mogu/pages/clean.md`

## Session 2026-06-03: Mogu Design System Foundation (feat-026)

Created a curated native macOS design-system source of truth and applied foundational tokens to shared UI primitives.

| ID | Feature | Verification |
|---|---|---|
| feat-026 | Mogu Design System Foundation | `make build`, `make test`, `make parser-test`, `make app`; runtime screenshot `/tmp/mogu-design-system-feat026-status.png`; grep confirms no active `.toolbar` / `ToolbarItem` / `ToolbarItemGroup` / `.searchable` usage |

**Files changed:** 6 files
- Modified: `Sources/Theme/DesignTokens.swift`, `Sources/ContentView.swift`, `Sources/Views/Components/FeatureLoadingView.swift`, `Sources/Views/Components/ErrorStateView.swift`, `feature_list.json`, `progress.md`
- New: `design-system/mogu/MASTER.md`

## Session 2026-06-03: Status Dashboard Visual Polish (feat-025)

Finished the in-progress Status screen redesign and closed the live-polling safety gap.

| ID | Feature | Verification |
|---|---|---|
| feat-025 | Status Dashboard Visual Polish | `make build`, `make test`, `make app`, `make parser-test`; runtime window capture `/tmp/mogu-status-live-feat025-live.png`; active Status sampling observed `status-go` on cadence; after backgrounding, 20s sample showed no `status-go` / `mole status --json` processes |

**Key fix:** macOS `scenePhase` stayed active while another app was frontmost, so foreground gating now uses `NSApplication.didBecomeActiveNotification` / `didResignActiveNotification` in `Sources/Views/StatusView.swift`.

**Files changed:** 5 files
- Modified: `Sources/Views/StatusView.swift`, `feature_list.json`, `progress.md`, `session-handoff.md`, `plans/status-live-redesign.md`

## Session 2026-06-02: Professional Polish (feat-016 → feat-024)

Nine features across 3 tiers, all verified at runtime.

| ID | Feature | Verification |
|---|---|---|
| feat-016 | About Mogu Window | Custom sheet with logo, version, Mole credit, MIT license, GitHub link |
| feat-017 | First-Run Onboarding | 3-card modal on first launch, AppStorage skip, re-triggable via Help menu |
| feat-018 | Sparkle Update Framework | Sparkle 2.9.2 via SPM, rpath fixed, bundled in Contents/Frameworks, appcast placeholder |
| feat-019 | App Preferences Window | ⌘, opens settings: auto-update toggle, launch-at-login, version display |
| feat-020 | Menu Commands & Shortcuts | Navigate menu (⌘1-⌘7), Help (Show Onboarding, GitHub), File (Share Mogu), Edit (standard) |
| feat-021 | Window State Restoration | AppStorage lastSelectedTab, MOGU_SCREEN override still works |
| feat-022 | Dock Menu | Right-click Dock icon: Refresh Status, Quick Clean (notification bridge) |
| feat-023 | Share Sheet | File > Share Mogu → NSSharingServicePicker with GitHub URL |
| feat-024 | Release Notes | CHANGELOG.md bundled, version-bump detection via AppStorage lastSeenVersion |

**Verification highlights:** `make build` + `make app` + `make parser-test` (17/17) all pass. Runtime verified via screenshots: onboarding modal on first launch, About Mogu custom sheet, Preferences window with settings, Navigate menu with tab shortcuts, Status dashboard with Live badge. Sparkle rpath fixed via `install_name_tool`.

**Files changed:** 9 files (4 modified, 4 new, 1 tracking)
- Modified: `Package.swift`, `Sources/MoguApp.swift`, `Sources/ContentView.swift`, `build_app.sh`
- New: `Sources/Views/Components/OnboardingView.swift`, `Sources/Views/Components/ReleaseNotesView.swift`, `Sources/Views/SettingsView.swift`, `CHANGELOG.md`

## Completed Features

| ID | Feature | Status | Evidence |
|---|---|---|---|
| feat-001 | Project Verification Baseline | done | make build + make test pass |
| feat-002 | Build Mole from Source | done | Vendor/Mole submodule, Go binaries |
| feat-003 | App Icon | done | AppIcon.icns from icon-source.png |
| feat-004 | Auto-Refresh Status Tab | done | 30s timer, Live badge |
| feat-005 | Sort/Filter Uninstall & Purge | done | SortOrder enum, .searchable |
| feat-006 | Real Uninstall Execution | done | executeUninstall + confirmation |
| feat-007 | Dark Mode | done | adaptive() helper, light/dark tokens |
| feat-008 | Permissions / FDA Finish | done | Analyze preflight banner |
| feat-009 | Rename App to Mogu | done | co.greenpassport.mogu, all strings updated |
| feat-010 | Analyze Decode Fix | done | DiskEntry.isDir optional |
| feat-011 | Parser-Resilience Harness | done | 17 tests, golden fixtures |
| feat-012 | FDA Not-Granted Check | done | LaunchServices probe verified |
| feat-013 | Consistent Error-State UX | done | ErrorStateView across 5 tabs |
| feat-014 | Mogu Personalization | done | Drilbur icon, navy accent, sidebar mark |
| feat-015 | In-App Uninstaller | done | Multi-select, preview, admin-deferred, sortable |
| feat-016 | About Mogu Window | done | Custom sheet with Mole credit |
| feat-017 | First-Run Onboarding | done | 3-card modal, AppStorage |
| feat-018 | Sparkle Update Framework | done | SPM, rpath fixed, appcast placeholder |
| feat-019 | App Preferences Window | done | ⌘, settings with 2 toggles + version |
| feat-020 | Menu Commands & Shortcuts | done | Navigate ⌘1-⌘7, Help, Share |
| feat-021 | Window State Restoration | done | AppStorage lastSelectedTab |
| feat-022 | Dock Menu | done | Refresh Status, Quick Clean |
| feat-023 | Share Sheet | done | NSSharingServicePicker |
| feat-024 | Release Notes | done | CHANGELOG bundled, version detection |
| feat-025 | Status Dashboard Visual Polish | done | Runtime-verified live dashboard + foreground-gated polling |
| feat-026 | Mogu Design System Foundation | done | Curated design-system/mogu/MASTER.md + shared tokens/primitives |
| feat-027 | Clean Screen Design System Redesign | done | Runtime-verified Clean loading + preview dashboard |
| feat-028 | Uninstall Screen Design System Redesign | done | Runtime-verified Uninstall list + selected-row state |
| feat-029 | Analyze Screen Design System Redesign | done | Runtime-verified Analyze completed dashboard |
